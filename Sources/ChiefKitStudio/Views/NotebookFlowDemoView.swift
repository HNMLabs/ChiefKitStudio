#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

private enum FlowEditorMode: String, CaseIterable, Identifiable {
    case visual = "Visual Builder"
    case json = "Raw JSON"

    var id: String { rawValue }
}

struct NotebookFlowDemoView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme
    @State private var showAllScreens = false
    @State private var editorMode: FlowEditorMode = .visual

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            topologyAndValidationBanner

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    editorCard
                    previewCard
                }

                VStack(alignment: .leading, spacing: 18) {
                    editorCard
                    previewCard
                }
            }
        }
    }

    @ViewBuilder
    private var topologyAndValidationBanner: some View {
        if case .success(let flow) = FlowDefinition.decode(viewModel.flowJSON) {
            let issues = flow.validate().filter { $0.severity != .valid }
            let edges = flow.topologyEdges

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Flow Topology & Static Validator", systemImage: "point.3.filled.connected.trianglepath.dotted")
                            .font(.headline)
                        Spacer()
                        if issues.isEmpty {
                            Label("\(flow.pages.count) screens · Valid", systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.success.swiftUIColor)
                        } else {
                            Label("\(issues.count) issue(s)", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.warning.swiftUIColor)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(flow.pages.enumerated()), id: \.offset) { idx, page in
                                HStack(spacing: 6) {
                                    Button {
                                        viewModel.activeFlowStepIndex = idx
                                        showAllScreens = false
                                    } label: {
                                        Text("\(idx + 1). \(page.id)")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 5)
                                            .background(
                                                viewModel.activeFlowStepIndex == idx
                                                    ? theme.primary.swiftUIColor.opacity(0.20)
                                                    : Color.secondary.opacity(0.10),
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    if idx < edges.count {
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if !issues.isEmpty {
                        ForEach(issues) { diag in
                            HStack(spacing: 6) {
                                Image(systemName: diag.severity == .error ? "xmark.octagon.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(diag.severity == .error ? theme.danger.swiftUIColor : theme.warning.swiftUIColor)
                                    .font(.caption)
                                Text(diag.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var editorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Picker("Editor", selection: $editorMode) {
                        ForEach(FlowEditorMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Spacer()

                    Button {
                        let preset = LocalAIPromptPreset.presets.first { $0.kind == .generateOnboardingFlow }
                        viewModel.runLocalAI(preset: preset)
                    } label: {
                        Label("AI Flow", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                if editorMode == .visual, case .success(let flow) = FlowDefinition.decode(viewModel.flowJSON) {
                    visualBuilderContent(flow)
                } else {
                    TextEditor(text: $viewModel.flowJSON)
                        .font(.system(.callout, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 360)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.separator.opacity(0.35), lineWidth: 1)
                        }
                }

                HStack(spacing: 8) {
                    Button {
                        viewModel.addVisualFlowPage()
                    } label: {
                        Label("Add Screen", systemImage: "plus")
                    }

                    Button {
                        viewModel.exportFlowJSON()
                    } label: {
                        Label("Export JSON", systemImage: "square.and.arrow.down")
                    }

                    Spacer()

                    Button("Reset Flow") {
                        viewModel.restartFlow()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func visualBuilderContent(_ flow: FlowDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                "Flow Title",
                text: Binding(
                    get: { flow.title },
                    set: { newTitle in viewModel.mutateFlowDefinition { $0.title = newTitle } }
                )
            )
            .textFieldStyle(.roundedBorder)
            .font(.headline)

            ForEach(Array(flow.pages.enumerated()), id: \.offset) { idx, page in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Step \(idx + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.primary.swiftUIColor)

                        TextField(
                            "id",
                            text: Binding(
                                get: { page.id },
                                set: { v in viewModel.mutateFlowDefinition { if $0.pages.indices.contains(idx) { $0.pages[idx].id = v } } }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 110)

                        Spacer()

                        Button {
                            viewModel.moveVisualFlowPage(at: idx, direction: -1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .controlSize(.mini)
                        .disabled(idx == 0)

                        Button {
                            viewModel.moveVisualFlowPage(at: idx, direction: 1)
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .controlSize(.mini)
                        .disabled(idx == flow.pages.count - 1)

                        Button(role: .destructive) {
                            viewModel.removeVisualFlowPage(at: idx)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .controlSize(.mini)
                        .disabled(flow.pages.count <= 1)
                    }

                    TextField(
                        "Screen Headline",
                        text: Binding(
                            get: { page.title },
                            set: { v in viewModel.mutateFlowDefinition { if $0.pages.indices.contains(idx) { $0.pages[idx].title = v } } }
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        "Actions (comma-separated)",
                        text: Binding(
                            get: { page.actions.joined(separator: ", ") },
                            set: { raw in
                                let parsed = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                                viewModel.mutateFlowDefinition {
                                    if $0.pages.indices.contains(idx) {
                                        $0.pages[idx].actions = parsed.isEmpty ? ["Continue"] : parsed
                                    }
                                }
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var previewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle("Interactive Flow Runner", subtitle: "Step through screens or inspect all pages.")
                    Spacer()
                    Toggle("All Pages", isOn: $showAllScreens)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                switch FlowDefinition.decode(viewModel.flowJSON) {
                case .success(let flow):
                    if showAllScreens {
                        AllPagesFlowPreview(definition: flow)
                    } else {
                        InteractiveStepFlowPreview(viewModel: viewModel, definition: flow)
                    }
                case .failure(let error):
                    VStack(alignment: .leading, spacing: 10) {
                        Label("JSON Syntax Error", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(theme.danger.swiftUIColor)
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InteractiveStepFlowPreview: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme
    let definition: FlowDefinition

    var body: some View {
        let pages = definition.pages
        let safeIndex = min(max(0, viewModel.activeFlowStepIndex), max(0, pages.count - 1))

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(definition.title)
                    .font(.title3.weight(.bold))
                Spacer()
                if !pages.isEmpty {
                    Text("Step \(safeIndex + 1) of \(pages.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.primary.swiftUIColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.primary.swiftUIColor.opacity(0.12), in: Capsule())
                }
            }

            if !pages.isEmpty {
                let page = pages[safeIndex]

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.16))
                        Capsule()
                            .fill(theme.primary.swiftUIColor)
                            .frame(width: proxy.size.width * CGFloat(safeIndex + 1) / CGFloat(max(1, pages.count)))
                    }
                }
                .frame(height: 6)

                VStack(alignment: .leading, spacing: 14) {
                    PillLabel(title: page.style.uppercased(), systemImage: "sparkles")

                    Text(page.title)
                        .font(.title2.weight(.bold))

                    Text(page.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(page.actions, id: \.self) { action in
                            Button {
                                viewModel.advanceFlow(
                                    action: action,
                                    pageID: page.id,
                                    totalPages: pages.count
                                )
                            } label: {
                                HStack {
                                    Text(action)
                                        .font(.callout.weight(.semibold))
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(theme.primary.swiftUIColor.opacity(0.14), in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusSmall)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
            }

            if !viewModel.flowAnswers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Captured FlowResult Answers")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.flowAnswers.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(viewModel.flowAnswers[key] ?? "")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
    }
}

private struct AllPagesFlowPreview: View {
    @Environment(\.studioTheme) private var theme
    let definition: FlowDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(definition.title)
                .font(.title3.weight(.semibold))

            ForEach(Array(definition.pages.enumerated()), id: \.offset) { index, page in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(theme.primary.swiftUIColor, in: Circle())

                        Text(page.title)
                            .font(.headline)

                        Spacer()

                        Text(page.style)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(page.body)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(page.actions, id: \.self) { action in
                            Text(action)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.primary.swiftUIColor.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
    }
}
#endif
