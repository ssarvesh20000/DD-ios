# DamageDoctor iOS

A fast, on‑device app that detects visible car damage in a photo.

## What it does
- Take or pick a car photo.
- The app locates any damage and labels it (dent, scratch, crack, glass shatter, lamp broken, tire flat), drawing bounding boxes with confidence scores.
- If nothing is detected above the confidence threshold, the image is reported as undamaged.
- Runs entirely on your device — your photos aren't sent anywhere.

## How it works
- Image input via camera, photo library, or Files.
- A YOLO‑style detector (`DamageDetector.mlpackage`) returns bounding boxes, labels, and confidences for specific damage types.
- If no boxes are returned above the confidence threshold, the image is reported as undamaged.
- Vision + Core ML handle preprocessing/inference; results are normalized to [0..1] with top‑left origin for overlays.
- SwiftUI drives the UI with light/dark theming; async/await wraps Vision requests; state updates trigger the results view.

## Quick start
- Open in Xcode and run on a physical device (recommended). Grant camera/photo access.
- Capture or pick a photo; analysis runs automatically on the Results screen.

## Testing
- `DD-iOSTests/DetectorBenchmarkTests.swift` runs the detector across a bundled image set and writes a CSV (`cardd_ios_benchmark.csv`) to the temporary directory for offline analysis.
- `DD-iOSUITests/DamageDoctorFlowUITests.swift` covers the Home → Results / History flow using the views' accessibility identifiers. It needs a UI Testing Bundle target named `DD-iOSUITests` (not in the project yet). Results tests inject a photo with the Debug-only `DD_UITEST_IMAGE` launch environment variable (simulator only).

## Limitations & potential solutions
- iOS version vs APIs: `@Observable` requires iOS 17+. If targeting older iOS, switch to `ObservableObject` and adjust navigation/sharing APIs; otherwise set min iOS to 17.
- Box alignment with Vision scaling: Using `.scaleFill` can crop; switch to `.scaleFit` or account for crop offsets when mapping boxes to the displayed image.
- Sharing annotated image: Render the overlay into a new image (e.g., `ImageRenderer`) and share that instead of the original.
- Performance on older devices: Consider a smaller detector input or model quantization.
- History persistence: `HistoryView` is a placeholder — wire up a SwiftData / Core Data store so prior scans land there with source image, detections, and timestamp.
- Analysis log: `AnalysisLogView` entries are currently scripted — wire them through `DamageDetectionViewModel` so they reflect real pipeline events.
- CI: Add a simple CI pipeline (Xcode Cloud or GitHub Actions) around the existing benchmark test.
