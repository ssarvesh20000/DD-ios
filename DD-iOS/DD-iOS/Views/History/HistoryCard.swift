import SwiftUI

struct HistoryCard: View {
    let onTap: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var theme: DDTheme { DDTheme(scheme: scheme) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.bg)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(theme.secondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("HISTORY")
                        .font(.system(.caption2, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(theme.secondary)
                    Text("No scans yet").font(.system(size: 15, weight: .semibold))
                    Text("Your analyzed photos will appear here")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondary.opacity(0.7))
            }
            .padding(14)
            .background(theme.card)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
