#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct WhatYouLearnCard: View {
    @Environment(\.studioTheme) private var theme
    let headline: String
    let points: [String]
    let highlightedAPIs: [String]
    let onAskAI: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(theme.primary.swiftUIColor)

                Text("What You're Learning")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    onAskAI()
                } label: {
                    Label("Explain / Enhance with Local AI", systemImage: "sparkles")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }

            Text(headline)
                .font(.callout)
                .foregroundStyle(.secondary)

            if isExpanded {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(theme.success.swiftUIColor)
                                .padding(.top, 2)

                            Text(point)
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.88))
                        }
                    }
                }
                .padding(.top, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(highlightedAPIs, id: \.self) { api in
                            Text(api)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(theme.primary.swiftUIColor.opacity(0.10), in: Capsule())
                                .foregroundStyle(theme.primary.swiftUIColor)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            theme.primary.swiftUIColor.opacity(0.05),
            in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous)
                .stroke(theme.primary.swiftUIColor.opacity(0.22), lineWidth: 1)
        }
    }
}
#endif
