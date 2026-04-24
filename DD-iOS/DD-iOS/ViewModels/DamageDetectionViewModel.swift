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

    private var detectorModel: VNCoreMLModel?

    init() {
        let computeUnits: MLComputeUnits
        #if targetEnvironment(simulator)
        computeUnits = .cpuOnly
        #else
        computeUnits = .all
        #endif

        do {
            let detectorConfig = MLModelConfiguration()
            detectorConfig.computeUnits = computeUnits
            let detector = try DamageDetector(configuration: detectorConfig)
            detectorModel = try VNCoreMLModel(for: detector.model)
        } catch {
            print("[DD] Failed to load CoreML detector model: \(error)")
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

        let detections = await runDetector(on: cgImage)

        if detections.isEmpty {
            state = .noDamage
        } else {
            state = .damageFound(detections)
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
