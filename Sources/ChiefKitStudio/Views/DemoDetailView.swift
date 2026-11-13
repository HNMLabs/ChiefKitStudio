#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct DemoDetailView: View {
    @ObservedObject var viewModel: PlaygroundViewModel

    var body: some View {
        VStack(spacing: 0) {
            PreviewToolbarView(viewModel: viewModel)

            ScrollView {
                VStack(alignment: .leading, spacing: viewModel.themeTokens.spacingMD) {
                    HeaderView(viewModel: viewModel)

                    WhatYouLearnCard(
                        headline: viewModel.currentLearningHeadline,
                        points: viewModel.currentLearningPoints,
                        highlightedAPIs: viewModel.currentHighlightedAPIs,
                        onAskAI: {
                            viewModel.rightInspectorTab = .assistant
                            viewModel.runLocalAI()
                        }
                    )

                    if viewModel.previewConfig.showAccessibilityOverlay {
                        AccessibilityOverlayView(
                            selectionTitle: viewModel.selectionDisplayTitle,
                            dynamicType: viewModel.previewConfig.dynamicType,
                            onRunAIAudit: {
                                let preset = LocalAIPromptPreset.presets.first { $0.kind == .addAccessibility }
                                viewModel.runLocalAI(preset: preset)
                            }
                        )
                    }

                    previewViewportContainer {
                        switch viewModel.selection {
                        case .package(.swiftBlocks):
                            SwiftBlocksDemoView(viewModel: viewModel)
                        case .package(.swiftState):
                            SwiftStateDemoView(viewModel: viewModel)
                        case .package(.notebookFlowKit):
                            NotebookFlowDemoView(viewModel: viewModel)
                        case .package(.coreLocalAIKit):
                            CoreLocalAIDemoView(viewModel: viewModel)
                        case .template(let template):
                            TemplateDemoView(viewModel: viewModel, template: template)
                        case .blueprint(let domain):
                            BlueprintComposerView(viewModel: viewModel, domain: domain)
                        case .savedSnippet(let id):
                            PinnedSnippetPreviewView(viewModel: viewModel, snippetID: id)
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .environment(\.dynamicTypeSize, viewModel.previewConfig.dynamicType.dynamicTypeSize)
            .modifier(OptionalColorSchemeModifier(scheme: viewModel.previewConfig.appearance.colorScheme))
            .background(.background)
        }
        .studioTheme(viewModel.themeTokens)
    }

    @ViewBuilder
    private func previewViewportContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let maxWidth = viewModel.previewConfig.viewport.maxWidth {
            VStack(spacing: 8) {
                HStack {
                    Label(
                        "Viewport Frame: \(Int(maxWidth)) pt",
                        systemImage: viewModel.previewConfig.viewport.symbolName
                    )
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Reset Fluid") {
                        viewModel.previewConfig.viewport = .fluid
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)
                }
                .frame(maxWidth: maxWidth)

                content()
                    .frame(maxWidth: maxWidth, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            .foregroundStyle(.secondary.opacity(0.35))
                    )
            }
            .frame(maxWidth: .infinity)
        } else {
            content()
        }
    }
}

private struct OptionalColorSchemeModifier: ViewModifier {
    let scheme: ColorScheme?

    func body(content: Content) -> some View {
        if let scheme {
            content.environment(\.colorScheme, scheme)
        } else {
            content
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var viewModel: PlaygroundViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                titleCluster
                Spacer()
                quickHeaderButtons
            }

            VStack(alignment: .leading, spacing: 10) {
                titleCluster
                quickHeaderButtons
            }
        }
    }

    private var titleCluster: some View {
        HStack(alignment: .top, spacing: 14) {
            ChiefKitLogoView(size: 48, cornerRadius: 11)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(viewModel.selectionDisplayTitle)
                        .font(.title.weight(.bold))

                    PillLabel(
                        title: viewModel.selection.category.rawValue,
                        systemImage: viewModel.selection.category.symbolName
                    )
                }

                Text(viewModel.selection.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickHeaderButtons: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.pinCurrentSnippet()
            } label: {
                Label("Pin Snippet", systemImage: "pin")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .help("Save current SwiftUI code to My Pinned Snippets (⌘D)")

            Button {
                viewModel.openInXcode()
            } label: {
                Label("Open in Xcode", systemImage: "wrench.and.screwdriver")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.isProjectGeneratorPresented = true
            } label: {
                Label("Generate Project", systemImage: "hammer.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.themeTokens.primary.swiftUIColor)
        }
    }
}
#endif
