#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct CodePreviewPanel: View {
    @ObservedObject var viewModel: PlaygroundViewModel

    var body: some View {
        VStack(spacing: 0) {
            inspectorModeHeader
            Divider()

            switch viewModel.rightInspectorTab {
            case .code:
                liveCodeTabContent
            case .assistant:
                LocalAIAssistantPanel(viewModel: viewModel)
            case .tokens:
                ThemeExplorerPanel(viewModel: viewModel)
            }
        }
        .background(.bar)
    }

    private var inspectorModeHeader: some View {
        HStack(spacing: 8) {
            Picker("Inspector", selection: $viewModel.rightInspectorTab) {
                ForEach(RightInspectorTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbolName)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var liveCodeTabContent: some View {
        let quality = viewModel.currentQualityReport
        let diff = viewModel.currentDiffReport

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Source Mode", selection: $viewModel.codePreviewMode) {
                    ForEach(CodePreviewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // Real-Time Code Quality Scorecard Bar
                HStack(spacing: 8) {
                    Text("\(quality.gradeBadge) · \(quality.overallScore)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(viewModel.themeTokens.primary.swiftUIColor, in: Capsule())

                    ForEach(quality.dimensions) { dim in
                        Text("\(dim.name) \(dim.score)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if diff.hasChanges {
                        Text(diff.summaryBadge)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(viewModel.themeTokens.success.swiftUIColor)
                    }
                }

                if viewModel.codePreviewMode == .theme {
                    Picker("Token Format", selection: $viewModel.tokenExportFormat) {
                        ForEach(TokenExportFormat.allCases) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    Button {
                        ExportService.copyToClipboard(viewModel.codePanelText)
                        viewModel.statusMessage = "Copied \(viewModel.codePreviewMode.rawValue) to clipboard"
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.themeTokens.primary.swiftUIColor)
                    .controlSize(.small)

                    Button {
                        viewModel.exportPackageSnippetFile()
                    } label: {
                        Label("Export Snippet", systemImage: "shippingbox.and.arrow.backward")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if viewModel.hasAIOverrideForCurrentSelection {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)
                        Text("Enhanced by CoreLocalAIKit (\(diff.summaryBadge))")
                            .font(.caption2.weight(.semibold))
                        Spacer()
                        Button("View Diff") {
                            viewModel.codePreviewMode = .diff
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)

                        Button("Revert") {
                            viewModel.revertAIOverride()
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(viewModel.themeTokens.danger.swiftUIColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(viewModel.themeTokens.primary.swiftUIColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(12)

            Divider()

            if viewModel.codePreviewMode == .diff {
                DiffLinesScrollView(diff: diff)
                    .padding(12)
            } else {
                CodeBlockView(text: viewModel.codePanelText)
                    .padding(12)
            }
        }
    }
}

private struct DiffLinesScrollView: View {
    let diff: DiffReport

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            if !diff.hasChanges {
                VStack(alignment: .leading, spacing: 6) {
                    Label("No Active Diff", systemImage: "checkmark.circle")
                        .font(.callout.weight(.semibold))
                    Text("Run a CoreLocalAIKit refactor or accessibility command in the 'Local AI' tab to inspect line-by-line additions and removals here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(diff.lines) { line in
                        HStack(spacing: 8) {
                            Text(line.kind.prefixSymbol)
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(color(for: line.kind))
                                .frame(width: 12)

                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(color(for: line.kind))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(background(for: line.kind))
                    }
                }
                .padding(8)
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator.opacity(0.45), lineWidth: 1)
        }
    }

    private func color(for kind: DiffLineKind) -> Color {
        switch kind {
        case .added: .green
        case .removed: .red
        case .unchanged: .primary
        }
    }

    private func background(for kind: DiffLineKind) -> Color {
        switch kind {
        case .added: Color.green.opacity(0.11)
        case .removed: Color.red.opacity(0.11)
        case .unchanged: Color.clear
        }
    }
}
#endif
