# DamageDoctor iOS

A fast, on‑device app that detects visible car damage in a photo.

## What it does
- Take or pick a car photo.
- The app quickly checks if any damage is likely.
- If so, it locates and labels damage (e.g., dent, scratch) and draws boxes.
- Runs entirely on your device — your photos aren’t sent anywhere.

## How it works
- Image input via camera, photo library, or Files.
- Stage 1: A small classifier (MobileNetV3) decides “damage” vs “no damage.” If no damage → stop early.
- Stage 2: A YOLO‑style detector returns bounding boxes, labels, and confidences for specific damage types.
- Vision + Core ML handle preprocessing/inference; results are normalized to [0..1] with top‑left origin for overlays.
- SwiftUI drives the UI; async/await wraps Vision requests; state updates trigger the results view.

## Quick start
- Open in Xcode and run on a physical device (recommended). Grant camera/photo access.
- Capture or pick a photo; analysis runs automatically on the Results screen.

## Limitations & potential solutions
- Classifier threshold/doc drift: Verify label/threshold convention and make the threshold configurable.
- iOS version vs APIs: If targeting older iOS, replace `@Observable` with `ObservableObject` and adjust navigation/sharing APIs; otherwise set min iOS to 17.
- Box alignment with Vision scaling: Using `.scaleFill` can crop; switch to `.scaleFit` or account for crop offsets when mapping boxes to the displayed image.
- Sharing annotated image: Render the overlay into a new image (e.g., `ImageRenderer`) and share that instead of the original.
- Performance on older devices: Consider smaller detector input, model quantization, and keep the classifier gate.
- Testing & CI: Add unit/snapshot tests (e.g., box mapping) and a simple CI pipeline (Xcode Cloud or GitHub Actions).




Update_I:
- Image input via camera, photo library, or Files.
- A YOLO-style detector returns bounding boxes, labels, and confidences for specific damage types.
- If no boxes are returned above the confidence threshold, the image is reported as undamaged.
- Vision + Core ML handle preprocessing/inference; results are normalized to [0..1] with top-left origin for overlays.
- SwiftUI drives the UI; async/await wraps Vision requests; state updates trigger the results view.
