import SwiftUI

// TODO: wire up a persistent store (SwiftData / Core Data) so prior scans land here.
// Each entry should carry the source image, detections, and timestamp.
struct HistoryView: View {
    @Environment(\.colorScheme) private var scheme
    private var theme: DDTheme { DDTheme(scheme: scheme) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(theme.secondary)

                Text("No scans yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.text)

                Text("Your analyzed photos will appear here once you start inspecting.")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
