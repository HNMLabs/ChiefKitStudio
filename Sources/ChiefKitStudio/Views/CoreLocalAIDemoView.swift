#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct CoreLocalAIDemoView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            privacyHeroCard
            commandGridCard

            if let response = viewModel.latestAIResponse {
                latestResultCard(response)
            }
        }
    }

    private var privacyHeroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("100% On-Device Local AI Runtime", systemImage: "lock.shield.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.success.swiftUIColor)

                    Spacer()

                    PillLabel(title: "0 Cloud Calls", systemImage: "wifi.slash")
                }

                Text(LocalAIEngine.appleIntelligenceStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Picker("Backend", selection: $viewModel.aiBackendMode) {
                        ForEach(LocalAIBackendMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .frame(maxWidth: 320)

                    Spacer()

                    Button {
                        viewModel.rightInspectorTab = .assistant
                    } label: {
                        Label("Focus Right Assistant Panel", systemImage: "sidebar.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var commandGridCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    "Interactive Developer Commands (English & Turkish)",
                    subtitle: "Click any command or type a custom prompt in English or Turkish."
                )

                HStack(spacing: 8) {
                    TextField(
                        "Try: \"Bu view'a accessibility ekle\" or \"Yeni onboarding flow üret\"…",
                        text: $viewModel.aiPrompt
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.runLocalAI()
                    }

                    Button {
                        viewModel.runLocalAI()
                    } label: {
                        Label(viewModel.isAIRunning ? "Running…" : "Run Locally", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .disabled(viewModel.isAIRunning)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(LocalAIPromptPreset.presets) { preset in
                        Button {
                            viewModel.runLocalAI(preset: preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: preset.kind.symbolName)
                                        .foregroundStyle(theme.primary.swiftUIColor)
                                    Text(preset.buttonTitle)
                                        .font(.callout.weight(.semibold))
                                    Spacer()
                                }
                                Text("\"\(preset.turkishHint)\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func latestResultCard(_ response: LocalAIResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(response.taskKind.title, systemImage: response.taskKind.symbolName)
                        .font(.headline)

                    Spacer()

                    Text("\(response.detectedLanguage) · \(String(format: "%.1f", response.latencyMilliseconds)) ms")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(response.summary)
                    .font(.callout)

                ForEach(response.findings, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.caption)
                            .foregroundStyle(theme.primary.swiftUIColor)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    if response.applyPayload != nil {
                        Button {
                            viewModel.applyAIResponse(response)
                        } label: {
                            Label("Apply to Playground", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primary.swiftUIColor)
                    }

                    Button {
                        ExportService.copyToClipboard(response.generatedCode)
                        viewModel.statusMessage = "Copied CoreLocalAIKit output"
                    } label: {
                        Label("Copy Output", systemImage: "doc.on.doc")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
