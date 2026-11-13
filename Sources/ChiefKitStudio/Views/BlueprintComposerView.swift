#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct BlueprintComposerView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme
    let domain: BlueprintDomain

    @State private var interactiveItems: [(id: String, title: String, detail: String, badge: String)] = []
    @State private var localCopilotNote = "On-device copilot ready · 0 cloud calls"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            layerSelectorCard
            liveArchitecturePreviewCard
        }
        .onAppear {
            syncSeedItems()
        }
        .onChange(of: domain) { _ in
            syncSeedItems()
        }
    }

    private func syncSeedItems() {
        interactiveItems = domain.sampleItems.enumerated().map { idx, item in
            ("seed-\(idx)", item.title, item.detail, item.badge)
        }
        localCopilotNote = "Indexed \(interactiveItems.count) \(domain.entityName) records locally"
    }

    private var layerSelectorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Full-Stack Architecture Layers",
                        subtitle: "Toggle packages to synthesize cohesive multi-layer SwiftUI + Reducer + Flow + @Test code."
                    )
                    Spacer()
                    PillLabel(
                        title: "\(viewModel.blueprintConfig.enabledLayers.count)/\(BlueprintLayer.allCases.count) layers",
                        systemImage: "square.3.layers.3d.down.right"
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 8)], spacing: 8) {
                    ForEach(BlueprintLayer.allCases) { layer in
                        let active = viewModel.blueprintConfig.isEnabled(layer)
                        Button {
                            viewModel.blueprintConfig.toggle(layer)
                            viewModel.aiOverriddenCode.removeValue(forKey: .blueprint(domain))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(active ? theme.primary.swiftUIColor : .secondary)
                                Image(systemName: layer.symbolName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(layer.title)
                                    .font(.caption.weight(active ? .semibold : .regular))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                active ? theme.primary.swiftUIColor.opacity(0.14) : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.rightInspectorTab = .code
                        viewModel.codePreviewMode = .tests
                    } label: {
                        Label("Inspect @Test Suite", systemImage: "checkmark.seal")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        viewModel.isProjectGeneratorPresented = true
                    } label: {
                        Label("Export Full Blueprint Project…", systemImage: "hammer.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var liveArchitecturePreviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(domain.title, systemImage: domain.symbolName)
                        .font(.title3.weight(.bold))

                    Spacer()

                    Button {
                        let next = interactiveItems.count + 1
                        interactiveItems.insert(
                            (
                                "item-\(UUID().uuidString.prefix(6))",
                                "New \(domain.entityName) #\(next)",
                                "Dispatched via SwiftState .addSampleItem action",
                                "New"
                            ),
                            at: 0
                        )
                        viewModel.incrementCounter()
                    } label: {
                        Label("Add \(domain.entityName)", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                ForEach(interactiveItems, id: \.id) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.primary.swiftUIColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.primary.swiftUIColor.opacity(0.12), in: Capsule())

                        Button {
                            interactiveItems.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusSmall)))
                }

                if viewModel.blueprintConfig.isEnabled(.localAICopilot) {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(theme.success.swiftUIColor)
                        Text(localCopilotNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Run Copilot Audit") {
                            viewModel.runLocalAI()
                        }
                        .font(.caption)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .background(theme.success.swiftUIColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PinnedSnippetPreviewView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme
    let snippetID: UUID

    var body: some View {
        GlassCard {
            if let snippet = viewModel.pinnedSnippet(for: snippetID) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(snippet.title, systemImage: "pin.fill")
                            .font(.title3.weight(.bold))
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.deletePinnedSnippet(snippet.id)
                        } label: {
                            Label("Unpin", systemImage: "trash")
                                .font(.caption)
                        }
                        .controlSize(.small)
                    }

                    Text(snippet.notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    CodeBlockView(text: snippet.swiftUICode)
                        .frame(minHeight: 300)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Pinned snippet is no longer available.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
