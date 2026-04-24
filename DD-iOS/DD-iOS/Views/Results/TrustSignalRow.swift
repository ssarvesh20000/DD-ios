import SwiftUI

struct TrustSignal: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

struct TrustSignalRow: View {
    let signals: [TrustSignal] = [
        .init(icon: "bolt.fill",      title: "1.2s",      subtitle: "avg. scan"),
        .init(icon: "shield.fill",    title: "On-device", subtitle: "CoreML"),
        .init(icon: "lock.fill",      title: "Private",   subtitle: "no upload"),
    ]

    @Environment(\.colorScheme) private var scheme
    private var theme: DDTheme { DDTheme(scheme: scheme) }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(signals) { s in
                VStack(spacing: 6) {
                    Image(systemName: s.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text(s.title).font(.system(size: 13, weight: .semibold))
                    Text(s.subtitle).font(.system(size: 11)).foregroundStyle(theme.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(theme.card)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
