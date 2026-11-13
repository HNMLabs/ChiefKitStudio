#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct AccessibilityOverlayView: View {
    let selectionTitle: String
    let dynamicType: PreviewDynamicType
    let onRunAIAudit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Accessibility X-Ray Active", systemImage: "figure.roll")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.indigo, in: Capsule())

                auditBadge("Contrast: AA+ Pass", icon: "eye.fill", color: .green)
                auditBadge("Hit Targets ≥ 44×44pt", icon: "hand.tap.fill", color: .blue)
                auditBadge("Scale: \(dynamicType.rawValue)", icon: "textformat.size", color: .orange)

                Spacer()

                Button {
                    onRunAIAudit()
                } label: {
                    Label("Auto-Inject VoiceOver Labels", systemImage: "sparkles")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.small)
            }

            HStack(spacing: 12) {
                rotorStep(index: 1, role: "Header", label: "\"\(selectionTitle)\"")
                rotorStep(index: 2, role: "Interactive Surface", label: "Grouped Controls (.contain)")
                rotorStep(index: 3, role: "Primary Action", label: "Keyboard & VoiceOver Focusable")
            }
        }
        .padding(10)
        .background(Color.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                .foregroundStyle(Color.indigo.opacity(0.65))
        }
    }

    private func auditBadge(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func rotorStep(index: Int, role: String, label: String) -> some View {
        HStack(spacing: 5) {
            Text("#\(index)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 0) {
                Text(role)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}
#endif
