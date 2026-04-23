import SwiftUI
import UIKit
import CoreML
import Vision

struct Detection: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect // normalized 0..1 coordinates (origin top-left)
}

enum DetectionState: Equatable {
    case idle
    case analyzing
    case noDamage
    case damageFound([Detection])

    static func == (lhs: DetectionState, rhs: DetectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.analyzing, .analyzing), (.noDamage, .noDamage):
            return true
        case let (.damageFound(a), .damageFound(b)):
            return a.map(\.id) == b.map(\.id)
        default:
            return false
        }
    }
}

@Observable
class DamageDetectionViewModel {
    var state: DetectionState = .idle

    private var classifierModel: VNCoreMLModel?
    private var detectorModel: VNCoreMLModel?

    init() {
        let computeUnits: MLComputeUnits
        #if targetEnvironment(simulator)
        computeUnits = .cpuOnly
        #else
        computeUnits = .all
        #endif

        do {
            let classifierConfig = MLModelConfiguration()
            classifierConfig.computeUnits = computeUnits
            let classifier = try DamageClassifier(configuration: classifierConfig)
            classifierModel = try VNCoreMLModel(for: classifier.model)

            let detectorConfig = MLModelConfiguration()
            detectorConfig.computeUnits = computeUnits
            let detector = try DamageDetector(configuration: detectorConfig)
            detectorModel = try VNCoreMLModel(for: detector.model)
        } catch {
            print("[DD] Failed to load CoreML models: \(error)")
        }
    }

    func analyze(image: UIImage) async {
        state = .analyzing

        guard let cgImage = Self.forceCGImage(from: image) else {
            print("[DD] Could not get CGImage from UIImage")
            state = .noDamage
            return
        }

        print("[DD] Got CGImage: \(cgImage.width)x\(cgImage.height)")

        // Step 1: Run classifier
        let classifierResult = await runClassifier(on: cgImage)
        print("[DD] Classifier result: \(classifierResult)")

        switch classifierResult {
        case .noDamage:
            state = .noDamage
            return
        case .hasDamage, .error:
            break
        }

        // Step 2: Run detector
        let detections = await runDetector(on: cgImage)

        if detections.isEmpty {
            state = .noDamage
        } else {
            state = .damageFound(detections)
        }
    }

    // MARK: - Classifier

    private enum ClassifierResult {
        case hasDamage, noDamage, error
    }

    private func runClassifier(on cgImage: CGImage) async -> ClassifierResult {
        guard let model = classifierModel else {
            print("[DD] Classifier model not loaded")
            return .error
        }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    print("[DD] Classifier request error: \(error)")
                    continuation.resume(returning: .error)
                    return
                }

                guard let results = request.results, !results.isEmpty else {
                    print("[DD] Classifier returned no results")
                    continuation.resume(returning: .error)
                    return
                }

                print("[DD] Classifier result types: \(results.map { type(of: $0) })")

                // Try 1: Raw feature value (single logit)
                if let featureResults = results as? [VNCoreMLFeatureValueObservation],
                   let multiArray = featureResults.first?.featureValue.multiArrayValue {
                    let logit = multiArray[0].floatValue
                    let sigmoid = 1.0 / (1.0 + exp(-logit))
                    print("[DD] Classifier logit=\(logit) sigmoid=\(sigmoid)")
                    // damage=0, no_damage=1 → sigmoid < 0.5 means damage
                    let hasDamage = sigmoid < 0.5
                    print("[DD] Classifier logit=\(logit) sigmoid=\(sigmoid) → \(hasDamage ? "damage" : "no_damage")")
                    continuation.resume(returning: hasDamage ? .hasDamage : .noDamage)
                    return
                }

                // Try 2: Classification observation (if model is wrapped as classifier)
                if let classResults = results as? [VNClassificationObservation],
                   let top = classResults.first {
                    print("[DD] Classifier top label=\(top.identifier) confidence=\(top.confidence)")
                    let isDamage = top.identifier.lowercased().contains("damage") && !top.identifier.lowercased().contains("no")
                        || top.identifier == "0"
                    continuation.resume(returning: isDamage ? .hasDamage : .noDamage)
                    return
                }

                // Unknown result format — log and fail-open
                print("[DD] Classifier unknown result format: \(results)")
                continuation.resume(returning: .error)
            }

            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[DD] Classifier perform error: \(error)")
                continuation.resume(returning: .error)
            }
        }
    }

    // MARK: - Detector

    private func runDetector(on cgImage: CGImage) async -> [Detection] {
        guard let model = detectorModel else {
            print("[DD] Detector model not loaded")
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    print("[DD] Detector request error: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                guard let results = request.results else {
                    print("[DD] Detector returned no results")
                    continuation.resume(returning: [])
                    return
                }

                print("[DD] Detector result count=\(results.count) types=\(results.prefix(1).map { type(of: $0) })")

                guard let observations = results as? [VNRecognizedObjectObservation] else {
                    print("[DD] Detector results not VNRecognizedObjectObservation: \(results.prefix(1))")
                    continuation.resume(returning: [])
                    return
                }

                let detections = observations.compactMap { observation -> Detection? in
                    guard let topLabel = observation.labels.first else { return nil }

                    // Vision gives boundingBox with origin at bottom-left — flip Y for top-left
                    let box = observation.boundingBox
                    let flipped = CGRect(
                        x: box.origin.x,
                        y: 1.0 - box.origin.y - box.height,
                        width: box.width,
                        height: box.height
                    )

                    return Detection(
                        label: topLabel.identifier,
                        confidence: topLabel.confidence,
                        boundingBox: flipped
                    )
                }

                print("[DD] Detector found \(detections.count) detections: \(detections.map { "\($0.label) \(Int($0.confidence * 100))%" })")
                continuation.resume(returning: detections)
            }

            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[DD] Detector perform error: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Helpers

    private static func forceCGImage(from image: UIImage) -> CGImage? {
        if let cg = image.cgImage { return cg }
        // Redraw to produce a CGImage (handles HEIC, CIImage-backed, etc.)
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: size))
        let redrawn = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return redrawn?.cgImage
    }
}
