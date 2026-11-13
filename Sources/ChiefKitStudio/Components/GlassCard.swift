#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.studioTheme) private var theme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let radius = CGFloat(theme.radiusMedium)
        content
            .padding(theme.spacingMD)
            .background {
                if theme.isLiquidGlassEnabled {
                    ZStack {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.primary.swiftUIColor.opacity(theme.glassFrost * 0.14),
                                        Color.white.opacity(theme.glassFrost * 0.10),
                                        theme.secondary.swiftUIColor.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(
                        color: theme.primary.swiftUIColor.opacity(0.10 * theme.glassFrost),
                        radius: 12,
                        x: 0,
                        y: 5
                    )
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
            .overlay {
                if theme.isLiquidGlassEnabled {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.65 * theme.specularRim),
                                    theme.primary.swiftUIColor.opacity(0.35 * theme.specularRim),
                                    Color.secondary.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(.separator.opacity(0.35), lineWidth: 1)
                }
            }
    }
}

struct PillLabel: View {
    @Environment(\.studioTheme) private var theme
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(theme.primary.swiftUIColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(theme.primary.swiftUIColor.opacity(0.11), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.primary.swiftUIColor.opacity(0.22), lineWidth: 0.8)
            }
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
