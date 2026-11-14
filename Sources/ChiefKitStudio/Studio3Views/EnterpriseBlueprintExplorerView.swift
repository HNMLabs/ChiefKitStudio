#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitBlueprints
import ChiefKitStudioCore
import SwiftUI

struct EnterpriseBlueprintExplorerView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    let initialBlueprintRawID: String?

    private enum BlueprintSourceTab: String, CaseIterable, Identifiable {
        case unifiedUI = "SwiftUI + Shell"
        case reducer = "Reducer & Store"
        case swiftData = "SwiftData @Model"
        case apiClient = "REST API Client"
        case onboardingJSON = "Onboarding JSON"
        case privacyXML = "PrivacyInfo.xcprivacy"
        case unitTests = "@Test Suite"
        case mermaid = "Mermaid Graph"

        var id: String { rawValue }
    }

    @State private var selectedVerticalFilter: EnterpriseVertical?
    @State private var selectedPlatformFilter: TargetApplePlatform?
    @State private var activeBlueprintID: EnterpriseBlueprintID = .neobankMultiCurrencyTreasury
    @State private var selectedSourceTab: BlueprintSourceTab = .unifiedUI
    @State private var dependencyStrategy: BlueprintDependencyStrategy = .standaloneOffline
    @State private var liveRecords: [BlueprintSampleRecord] = []
    @State private var lastDispatchedActionLog: String?

    init(viewModel: PlaygroundViewModel, initialBlueprintRawID: String? = nil) {
        self.viewModel = viewModel
        self.initialBlueprintRawID = initialBlueprintRawID
    }

    private var orderedEnabledLayers: [EnterpriseLayerKind] {
        let current = EnterpriseLayerKind.allCases.filter { viewModel.activeEnterpriseLayers.contains($0) }
        return current.isEmpty ? [.swiftBlocksUI] : current
    }

    private var filteredBlueprints: [EnterpriseBlueprintSpec] {
        EnterpriseBlueprintCatalog.filter(
            vertical: selectedVerticalFilter,
            platform: selectedPlatformFilter
        )
    }

    private var currentSpec: EnterpriseBlueprintSpec {
        EnterpriseBlueprintCatalog.spec(for: activeBlueprintID)
    }

    var body: some View {
        let spec = currentSpec
        let validation = BlueprintArchitectureValidator.validate(spec, theme: theme)

        VStack(alignment: .leading, spacing: 16) {
            verticalAndCatalogSelectorCard(spec: spec, validation: validation)
            eightLayerArchitectureToggleCard(spec: spec)
            kpiAndInteractiveDomainCard(spec: spec)
            multiLayerSourceSwitcherCard(spec: spec)
        }
        .onAppear {
            syncFromExternalSelection(initialBlueprintRawID)
        }
        .onChange(of: initialBlueprintRawID) { nextRaw in
            syncFromExternalSelection(nextRaw)
        }
        .onChange(of: activeBlueprintID) { nextID in
            let spec = EnterpriseBlueprintCatalog.spec(for: nextID)
            liveRecords = spec.sampleRecords
            lastDispatchedActionLog = nil
        }
    }

    // MARK: - 1. 9-Vertical & 28-Blueprint Catalog Bar

    private func verticalAndCatalogSelectorCard(
        spec: EnterpriseBlueprintSpec,
        validation: BlueprintSpecValidationReport
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SectionTitle(
                        "\(spec.vertical.title) — \(spec.title)",
                        subtitle: spec.subtitle
                    )
                    Spacer()
                    PillLabel(
                        title: "\(spec.complexityTier.rawValue) · Saves ~\(spec.complexityTier.estimatedWeeksSaved)w",
                        systemImage: validation.isValid ? "checkmark.seal.fill" : "exclamationmark.triangle"
                    )
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterChip(label: "All 9 Verticals (28)", symbol: "square.grid.2x2", isSelected: selectedVerticalFilter == nil) {
                            selectedVerticalFilter = nil
                        }
                        ForEach(EnterpriseVertical.allCases) { vertical in
                            filterChip(
                                label: vertical.title,
                                symbol: vertical.sfSymbol,
                                isSelected: selectedVerticalFilter == vertical
                            ) {
                                selectedVerticalFilter = vertical
                                if let firstInVertical = vertical.blueprintIDs.first {
                                    selectBlueprint(firstInVertical)
                                }
                            }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterChip(label: "All Platforms", symbol: "apple.logo", isSelected: selectedPlatformFilter == nil) {
                            selectedPlatformFilter = nil
                        }
                        ForEach(TargetApplePlatform.allCases) { platform in
                            filterChip(
                                label: platform.displayName,
                                symbol: platform.sfSymbol,
                                isSelected: selectedPlatformFilter == platform
                            ) {
                                selectedPlatformFilter = platform
                            }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredBlueprints) { item in
                            let isCurrent = item.id == activeBlueprintID
                            Button {
                                selectBlueprint(item.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.sfSymbol)
                                    Text(item.title)
                                        .font(.caption.weight(isCurrent ? .bold : .medium))
                                }
                                .foregroundStyle(isCurrent ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    isCurrent ? theme.primary.swiftUIColor : Color.secondary.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach(spec.supportedPlatforms) { platform in
                        Label(platform.displayName, systemImage: platform.sfSymbol)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(theme.primary.swiftUIColor.opacity(0.11), in: Capsule())
                            .foregroundStyle(theme.primary.swiftUIColor)
                    }
                    Spacer()
                    Text("\(validation.synthesizedSwiftLineCount) Swift LOC · \(validation.detectedTestCount) @Tests · \(validation.exportedFileCount) Workspace Files")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. 8-Layer Enterprise Architecture Toggle Matrix & 14-File Exporter

    private func eightLayerArchitectureToggleCard(spec: EnterpriseBlueprintSpec) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "8-Layer Enterprise Architecture & 14-File SwiftPM Exporter",
                        subtitle: "Toggle architectural layers and export a complete standalone or ecosystem-linked Swift 6 workspace."
                    )
                    Spacer()
                    PillLabel(
                        title: "\(orderedEnabledLayers.count)/\(EnterpriseLayerKind.allCases.count) Layers",
                        systemImage: "square.3.layers.3d.down.right"
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 195), spacing: 8)], spacing: 8) {
                    ForEach(EnterpriseLayerKind.allCases) { layer in
                        let enabled = viewModel.activeEnterpriseLayers.contains(layer)
                        Button {
                            viewModel.toggleEnterpriseLayer(layer)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(enabled ? theme.primary.swiftUIColor : .secondary)
                                Image(systemName: layer.sfSymbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(layer.title)
                                    .font(.caption.weight(enabled ? .semibold : .regular))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                enabled ? theme.primary.swiftUIColor.opacity(0.13) : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    Picker("Dependencies", selection: $dependencyStrategy) {
                        ForEach(BlueprintDependencyStrategy.allCases) { strat in
                            Text(strat.rawValue).tag(strat)
                        }
                    }
                    .frame(maxWidth: 330)
                    .controlSize(.small)

                    Spacer()

                    Button {
                        export14FileWorkspace(for: spec)
                    } label: {
                        Label("Export 14-File SwiftPM Workspace…", systemImage: "shippingbox.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. Live KPI Cards, Domain Entities & Reducer Simulation

    private func kpiAndInteractiveDomainCard(spec: EnterpriseBlueprintSpec) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 8)], spacing: 8) {
                    ForEach(spec.kpiMetrics) { kpi in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: kpi.sfSymbol)
                                    .foregroundStyle(theme.primary.swiftUIColor)
                                Text(kpi.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Text(kpi.value)
                                .font(.title3.weight(.bold))
                            Text(kpi.delta)
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(kpi.isFavorable ? theme.success.swiftUIColor : theme.warning.swiftUIColor)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9))
                    }
                }

                HStack(spacing: 8) {
                    Text("Dispatch Reducer Actions:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(spec.reducerActions.prefix(4)) { action in
                        Button(action.buttonTitle ?? action.caseDeclaration) {
                            lastDispatchedActionLog = "Dispatched .\(action.caseDeclaration) — \(action.summary)"
                            viewModel.statusMessage = "Blueprint Reducer: .\(action.caseDeclaration)"
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                }

                if let actionNote = lastDispatchedActionLog {
                    Text(actionNote)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.primary.swiftUIColor)
                }

                ForEach(liveRecords) { rec in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.headline)
                                .font(.callout.weight(.semibold))
                            Text(rec.subheadline)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rec.trailingMetric)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Text(rec.statusTag)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(theme.primary.swiftUIColor.opacity(0.13), in: Capsule())
                            .foregroundStyle(theme.primary.swiftUIColor)
                    }
                    .padding(9)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 12) {
                    Text("Entities: \(spec.domainEntities.map(\.name).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Endpoints: \(spec.apiEndpoints.count) · EN/TR Keys: \(spec.localizationKeysTR_EN.count)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. 8-Mode Layer Source Code Switcher

    private func multiLayerSourceSwitcherCard(spec: EnterpriseBlueprintSpec) -> some View {
        let displayedCode = sourceCode(for: spec, tab: selectedSourceTab)

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "Multi-Layer Source Explorer",
                        subtitle: "Inspect synthesized SwiftUI, Reducer, SwiftData @Model, REST Client, Flow JSON, Privacy & @Tests."
                    )
                    Spacer()
                    Button {
                        viewModel.aiOverriddenCode[viewModel.selection] = displayedCode
                        viewModel.rightInspectorTab = .code
                        viewModel.codePreviewMode = .swiftUI
                        viewModel.statusMessage = "Loaded \(spec.title) (\(selectedSourceTab.rawValue)) into Live Code"
                    } label: {
                        Label("Pin Tab in Inspector", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(BlueprintSourceTab.allCases) { tab in
                            let active = selectedSourceTab == tab
                            Button {
                                selectedSourceTab = tab
                            } label: {
                                Text(tab.rawValue)
                                    .font(.caption.weight(active ? .bold : .medium))
                                    .foregroundStyle(active ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        active ? theme.primary.swiftUIColor : Color.secondary.opacity(0.11),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                CodeBlockView(text: displayedCode)
                    .frame(minHeight: 230, maxHeight: 330)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func syncFromExternalSelection(_ rawID: String?) {
        if let rawID, let resolved = EnterpriseBlueprintID(rawValue: rawID) {
            activeBlueprintID = resolved
            liveRecords = EnterpriseBlueprintCatalog.spec(for: resolved).sampleRecords
        } else if liveRecords.isEmpty {
            liveRecords = currentSpec.sampleRecords
        }
    }

    private func selectBlueprint(_ id: EnterpriseBlueprintID) {
        activeBlueprintID = id
        if case .enterpriseBlueprint = viewModel.selection {
            viewModel.select(.enterpriseBlueprint(id.rawValue))
        } else {
            viewModel.statusMessage = "Inspecting Enterprise Blueprint: \(EnterpriseBlueprintCatalog.spec(for: id).title)"
        }
    }

    private func sourceCode(for spec: EnterpriseBlueprintSpec, tab: BlueprintSourceTab) -> String {
        switch tab {
        case .unifiedUI:
            return spec.synthesizeSwiftUIView(theme: theme, layers: orderedEnabledLayers)
        case .reducer:
            return spec.synthesizeReducerAndStore()
        case .swiftData:
            return spec.synthesizeSwiftDataModels()
        case .apiClient:
            return spec.synthesizeAPIClient()
        case .onboardingJSON:
            return spec.synthesizeOnboardingFlowJSON()
        case .privacyXML:
            return spec.synthesizePrivacyManifestXML()
        case .unitTests:
            return spec.synthesizeSwiftTests()
        case .mermaid:
            return spec.synthesizeMermaidArchitecture()
        }
    }

    private func export14FileWorkspace(for spec: EnterpriseBlueprintSpec) {
        let panel = NSOpenPanel()
        panel.title = "Choose Destination Folder for \(spec.id.defaultAppTargetName) (14-File Workspace)"
        panel.prompt = "Export 14-File Workspace"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let parentFolder = panel.url else { return }

        do {
            let result = try BlueprintWorkspaceExporter.exportToDisk(
                blueprintID: spec.id,
                theme: theme,
                layers: orderedEnabledLayers,
                platforms: spec.supportedPlatforms,
                dependencyStrategy: dependencyStrategy,
                destinationParentDirectory: parentFolder
            )
            NSWorkspace.shared.activateFileViewerSelecting([result.rootDirectoryURL])
            viewModel.statusMessage = "Exported \(result.writtenFileURLs.count) files (\(result.workspace.totalLinesOfCode) LOC) to \(result.rootDirectoryURL.lastPathComponent)"
        } catch {
            viewModel.statusMessage = "Blueprint export failed: \(error.localizedDescription)"
        }
    }

    private func filterChip(
        label: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.caption2.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    isSelected ? theme.primary.swiftUIColor : Color.secondary.opacity(0.11),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}
#endif
