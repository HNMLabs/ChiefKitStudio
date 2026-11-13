#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct CodeBlockView: View {
    let text: String
    var showLineNumbers: Bool = true

    @State private var didCopy = false

    private var lines: [String] {
        text.components(separatedBy: "\n")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: 12) {
                    if showLineNumbers {
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(1...max(1, lines.count), id: \.self) { lineNumber in
                                Text("\(lineNumber)")
                                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.leading, 12)

                        Divider()
                            .padding(.vertical, 10)
                    }

                    Text(text)
                        .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .padding(.leading, showLineNumbers ? 0 : 14)
                        .padding(.trailing, 42)
                }
            }

            HStack(spacing: 6) {
                Text("\(lines.count)L")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())

                Button {
                    ExportService.copyToClipboard(text)
                    didCopy = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1200))
                        didCopy = false
                    }
                } label: {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.38), lineWidth: 1)
        }
    }
}
#endif
