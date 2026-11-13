#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct LocalAIAssistantPanel: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @State private var showDiffInAssistant = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerBanner
                quickCommandsSection
                promptEditorSection

                if let response = viewModel.latestAIResponse {
                    responseSection(response)
                } else {
                    emptyStateSection
                }
            }
            .padding(14)
        }
    }

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("CoreLocalAIKit", systemImage: "cpu.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)

                Spacer()

                Label("100% On-Device", systemImage: "lock.shield.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(viewModel.themeTokens.success.swiftUIColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(viewModel.themeTokens.success.swiftUIColor.opacity(0.12), in: Capsule())
            }

            Picker("Engine", selection: $viewModel.aiBackendMode) {
                ForEach(LocalAIBackendMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .controlSize(.small)

            Text("Zero cloud APIs · Understands English & Turkish commands")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var quickCommandsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("One-Click Commands")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 6)], spacing: 6) {
                ForEach(LocalAIPromptPreset.presets) { preset in
                    Button {
                        viewModel.runLocalAI(preset: preset)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: preset.kind.symbolName)
                                .font(.caption2)
                                .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)
                            Text(preset.buttonTitle)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .help(preset.turkishHint)
                }
            }
        }
    }

    private var promptEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Prompt (EN / TR)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $viewModel.aiPrompt)
                .font(.system(size: 12.5, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(height: 74)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator.opacity(0.40), lineWidth: 1)
                }

            HStack {
                Text("Target: \(viewModel.selectionDisplayTitle)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    viewModel.runLocalAI()
                } label: {
                    HStack(spacing: 5) {
                        if viewModel.isAIRunning {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(viewModel.isAIRunning ? "Analyzing…" : "Run Local AI")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.themeTokens.primary.swiftUIColor)
                .controlSize(.small)
                .disabled(viewModel.isAIRunning)
            }
        }
    }

    private func responseSection(_ response: LocalAIResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack {
                Label(response.taskKind.title, systemImage: response.taskKind.symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)

                Spacer()

                Text("\(response.detectedLanguage) · \(String(format: "%.1f", response.latencyMilliseconds))ms")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let fallback = response.fallbackNotice {
                Text(fallback)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(7)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
            }

            Text(response.summary)
                .font(.caption)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(response.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(viewModel.themeTokens.primary.swiftUIColor.opacity(0.12), in: Capsule())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(response.findings, id: \.self) { finding in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(viewModel.themeTokens.success.swiftUIColor)
                            .padding(.top, 2)
                        Text(finding)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                if response.applyPayload != nil {
                    Button {
                        viewModel.applyAIResponse(response)
                    } label: {
                        Label("Apply to Playground", systemImage: "arrow.down.doc.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.themeTokens.primary.swiftUIColor)
                    .controlSize(.small)
                }

                Toggle(isOn: $showDiffInAssistant) {
                    Text("Diff (\(response.diffReport.summaryBadge))")
                        .font(.caption2.weight(.medium))
                }
                .toggleStyle(.button)
                .controlSize(.small)

                Button {
                    ExportService.copyToClipboard(response.generatedCode)
                    viewModel.statusMessage = "Copied CoreLocalAIKit code"
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .controlSize(.small)
            }

            CodeBlockView(
                text: showDiffInAssistant ? response.diffReport.unifiedPatch : response.generatedCode,
                showLineNumbers: !showDiffInAssistant
            )
            .frame(height: 220)
        }
    }

    private var emptyStateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Try asking in English or Turkish:")
                .font(.caption.weight(.semibold))
            Text("• \"Bu SwiftState örneğini daha iyi yaz\"")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("• \"Bu view'a accessibility ekle\"")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("• \"Bu ekran için birim testleri üret\"")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("• \"Yeni onboarding flow üret\"")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}
#endif
