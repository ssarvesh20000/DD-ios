import SwiftUI

struct LogEntry: Identifiable {
    let id = UUID()
    let text: String
    let isSuccess: Bool
    let appearDelay: Double
}

// TODO: wire log entries through `DamageDetectionViewModel` so they reflect real
// pipeline events instead of being scripted. Recommended shape:
//   @Observable class DamageDetectionViewModel {
//       var state: DetectionState = .idle
//       var log: [LogEntry] = []
//       // append entries at each stage of analyze()
//   }
// Then `AnalysisLogView` takes `entries: [LogEntry]` as a parameter.
struct AnalysisLogView: View {
    @Environment(\.colorScheme) private var scheme
    private var theme: DDTheme { DDTheme(scheme: scheme) }

    let entries: [LogEntry] = [
        .init(text: "Preprocess · 640×480",   isSuccess: false, appearDelay: 0.0),
        .init(text: "Detector · YOLOv8n",     isSuccess: false, appearDelay: 0.35),
        .init(text: "Found dent · 86%",       isSuccess: true,  appearDelay: 0.75),
        .init(text: "Found scratch · 71%",    isSuccess: true,  appearDelay: 1.25),
    ]

    @State private var visibleCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOG")
                .font(.system(.caption2, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(theme.secondary.opacity(0.7))
                .padding(.bottom, 2)

            ForEach(entries.prefix(visibleCount)) { entry in
                HStack(spacing: 10) {
                    Text(entry.isSuccess ? "✓" : "›")
                        .foregroundStyle(entry.isSuccess ? .green : theme.secondary)
                        .frame(width: 10, alignment: .leading)
                    Text(entry.text)
                        .foregroundStyle(entry.isSuccess ? theme.text : theme.secondary)
                    Spacer()
                }
                .font(.system(size: 12, design: .monospaced))
                .transition(.opacity.combined(with: .offset(y: 4)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            for (i, e) in entries.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + e.appearDelay) {
                    withAnimation(.easeOut(duration: 0.3)) { visibleCount = i + 1 }
                }
            }
        }
    }
}
