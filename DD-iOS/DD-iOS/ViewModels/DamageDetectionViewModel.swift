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

        // Letterbox to the model's 640x640 input the same way ultralytics does
        // (keep aspect ratio, pad with gray 114) instead of stretching.
        let sourceSize = Letterbox.pixelSize(of: image)
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            print("[DD] Image has zero size")
            state = .noDamage
            return
        }
        let geometry = LetterboxGeometry(sourceSize: sourceSize, targetSide: Self.modelInputSide)
        guard let letterboxed = Letterbox.render(image, geometry: geometry) else {
            print("[DD] Could not render letterboxed CGImage")
            state = .noDamage
            return
        }

        print("[DD] Source \(Int(sourceSize.width))x\(Int(sourceSize.height)) -> letterboxed \(letterboxed.width)x\(letterboxed.height), content \(geometry.contentRect)")

        let detections = await runDetector(on: letterboxed, geometry: geometry)

        if detections.isEmpty {
            state = .noDamage
        } else {
            state = .damageFound(detections)
        }
    }

    
    // MARK: - Detector

    /// DamageDetector.mlpackage input size (640x640).
    static let modelInputSide: CGFloat = 640

    /// `cgImage` must already be letterboxed to a square; boxes are mapped back
    /// to the original image with `geometry`.
    private func runDetector(on cgImage: CGImage, geometry: LetterboxGeometry) async -> [Detection] {
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

                    // Vision gives boundingBox with origin at bottom-left — flip Y for top-left,
                    // then undo the letterbox padding/scale to get original-image coordinates
                    let flipped = Letterbox.topLeftFromVision(observation.boundingBox)
                    guard let box = geometry.unletterbox(flipped) else { return nil }

                    return Detection(
                        label: topLabel.identifier,
                        confidence: topLabel.confidence,
                        boundingBox: box
                    )
                }

                print("[DD] Detector found \(detections.count) detections: \(detections.map { "\($0.label) \(Int($0.confidence * 100))%" })")
                continuation.resume(returning: detections)
            }

            // The input is already a 640x640 square, so scaleFill is a no-op resize
            // (no stretching, no cropping). Letterboxing happened in analyze().
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
}
