import SwiftUI

struct AnalyzingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .background(.ultraThinMaterial.opacity(0.3))

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.3)
                Text("Analyzing image…")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.opacity)
    }
}
