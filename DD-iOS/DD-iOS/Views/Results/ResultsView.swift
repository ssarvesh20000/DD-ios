import SwiftUI
import UIKit

struct ResultsView: View {
    let image: UIImage
    @State private var viewModel = DamageDetectionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Annotated image with bounding boxes
                GeometryReader { geo in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()

                        if case .damageFound(let detections) = viewModel.state {
                            ForEach(detections) { detection in
                                BoundingBoxOverlay(
                                    detection: detection,
                                    imageSize: image.size,
                                    viewSize: geo.size
                                )
                            }
                        }

                        if viewModel.state == .analyzing {
                            AnalyzingOverlay()
                        }
                    }
                }
                .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Status / results
                Group {
                    switch viewModel.state {
                    case .idle:
                        EmptyView()
                    case .analyzing:
                        AnalysisLogView()
                    case .noDamage:
                        Label("No damage detected", systemImage: "checkmark.seal.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    case .damageFound(let detections):
                        detectionsList(detections)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .damageFound = viewModel.state {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("Damage Report", image: Image(uiImage: image)))
                }
            }
        }
        .task {
            await viewModel.analyze(image: image)
        }
    }

    private func detectionsList(_ detections: [Detection]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Damage Found")
                .font(.title3.bold())

            ForEach(detections) { detection in
                HStack {
                    Circle()
                        .fill(colorForLabel(detection.label))
                        .frame(width: 12, height: 12)

                    Text(detection.label.capitalized)
                        .font(.body.bold())

                    Spacer()

                    Text("\(Int(detection.confidence * 100))%")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct BoundingBoxOverlay: View {
    let detection: Detection
    let imageSize: CGSize
    let viewSize: CGSize

    var body: some View {
        let displayRect = mapToView()

        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(colorForLabel(detection.label), lineWidth: 2.5)
                .frame(width: displayRect.width, height: displayRect.height)

            Text("\(detection.label) \(Int(detection.confidence * 100))%")
                .font(.caption2.bold())
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(colorForLabel(detection.label))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .offset(y: -20)
        }
        .position(x: displayRect.midX, y: displayRect.midY)
    }

    private func mapToView() -> CGRect {
        let scaleX = viewSize.width
        let scaleY = viewSize.width * (imageSize.height / imageSize.width)
        let offsetY = (viewSize.height - scaleY) / 2

        return CGRect(
            x: detection.boundingBox.origin.x * scaleX,
            y: detection.boundingBox.origin.y * scaleY + offsetY,
            width: detection.boundingBox.width * scaleX,
            height: detection.boundingBox.height * scaleY
        )
    }
}

func colorForLabel(_ label: String) -> Color {
    switch label {
    case "dent": return .orange
    case "scratch": return .red
    case "crack": return .purple
    case "glass shatter": return .blue
    case "lamp broken": return .yellow
    case "tire flat": return .brown
    default: return .gray
    }
}

#Preview {
    NavigationStack {
        ResultsView(image: UIImage(systemName: "car")!)
    }
}
