#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitBlueprints
import ChiefKitStudioCore
import SwiftUI

struct ProjectGeneratorSheet: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var bundleIdentifier: String = "com.hnmlabs.ChiefKitStarter"
    @State private var dependencyMode: ProjectDependencyMode = .standaloneReady
    @State private var enterpriseDependencyStrategy: BlueprintDependencyStrategy = .standaloneOffline
    @State private var includeUnitTests = true
    @State private var openInXcodeAfterExport = true
    @State private var errorMessage: String?

    private var activeEnterpriseBlueprintID: EnterpriseBlueprintID? {
        guard case .enterpriseBlueprint(let rawID) = viewModel.selection else { return nil }
        return EnterpriseBlueprintID(rawValue: rawID) ?? .neobankMultiCurrencyTreasury
    }

    private var currentEnterpriseRequest: BlueprintExportRequest? {
        guard let bpID = activeEnterpriseBlueprintID else { return nil }
        let spec = EnterpriseBlueprintCatalog.spec(for: bpID)
        var layers = viewModel.orderedEnterpriseLayers
        if includeUnitTests && !layers.contains(.swiftTestingSuite) {
            layers.append(.swiftTestingSuite)
        } else if !includeUnitTests {
            layers.removeAll { $0 == .swiftTestingSuite }
        }
        return BlueprintExportRequest(
            blueprintID: bpID,
            customAppName: projectName,
            bundleIdentifier: bundleIdentifier,
            theme: viewModel.themeTokens,
            enabledLayers: layers,
            targetPlatforms: spec.supportedPlatforms,
            dependencyStrategy: enterpriseDependencyStrategy
        )
    }

    private var currentConfig: ProjectGenerationConfig {
        let includeFlow: String?
        switch viewModel.selection {
        case .package(.notebookFlowKit), .template(.onboardingFlow), .template(.quizFlow):
            includeFlow = viewModel.flowJSON
        case .blueprint(let domain):
            includeFlow = viewModel.blueprintConfig.synthesizeFlowJSON(for: domain)
        default:
            includeFlow = nil
        }

        return ProjectGenerationConfig(
            projectName: projectName.isEmpty ? viewModel.selection.sanitizedProjectName : projectName,
            bundleIdentifier: bundleIdentifier,
            dependencyMode: dependencyMode,
            includeUnitTests: includeUnitTests,
            openInXcodeAfterExport: openInXcodeAfterExport,
            selection: viewModel.selection,
            requiredPackages: DemoLibrary.requiredPackages(for: viewModel.selection, blueprint: viewModel.blueprintConfig),
            swiftUICode: viewModel.selectedSwiftUICode,
            unitTestsCode: viewModel.generatedUnitTestsBySelection[viewModel.selection],
            themeTokens: viewModel.themeTokens,
            flowJSON: includeFlow
        )
    }

    private var previewPaths: [String] {
        if let enterpriseReq = currentEnterpriseRequest {
            return ProjectGeneratorService.previewEnterpriseFileTree(for: enterpriseReq)
        }
        return ProjectGeneratorService.previewFileTree(for: currentConfig)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ChiefKitLogoView(size: 40, cornerRadius: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activeEnterpriseBlueprintID != nil ? "14-File Enterprise Workspace Generator" : "One-Click Project Generator")
                        .font(.title3.weight(.bold))
                    Text(
                        activeEnterpriseBlueprintID != nil
                            ? "Export '\(viewModel.selectionDisplayTitle)' with 8 architectural layers, PrivacyInfo.xcprivacy, .xcstrings, W3C tokens & @Tests."
                            : "Export '\(viewModel.selectionDisplayTitle)' + W3C Design Tokens + Unit Tests as a SwiftPM / Xcode app."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Text("Project Name")
                        .font(.callout.weight(.medium))
                    TextField("ChiefKitStarterApp", text: $projectName)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Bundle ID")
                        .font(.callout.weight(.medium))
                    TextField("com.hnmlabs.starter", text: $bundleIdentifier)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Package Mode")
                        .font(.callout.weight(.medium))
                    if activeEnterpriseBlueprintID != nil {
                        Picker("Strategy", selection: $enterpriseDependencyStrategy) {
                            ForEach(BlueprintDependencyStrategy.allCases) { strat in
                                Text(strat.rawValue).tag(strat)
                            }
                        }
                        .labelsHidden()
                    } else {
                        Picker("Mode", selection: $dependencyMode) {
                            ForEach(ProjectDependencyMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Include Automated Unit Tests Target (Tests/<App>Tests)", isOn: $includeUnitTests)
                    .font(.callout)

                Toggle("Open generated Package.swift in Xcode automatically", isOn: $openInXcodeAfterExport)
                    .font(.callout)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Generated File Structure (\(previewPaths.count) files)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(previewPaths, id: \.self) { path in
                            HStack(spacing: 6) {
                                Image(systemName: iconForPath(path))
                                    .font(.caption2)
                                    .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)
                                Text(path)
                                    .font(.system(size: 11.5, design: .monospaced))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 195)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    generateProject()
                } label: {
                    Label(
                        openInXcodeAfterExport ? "Generate & Open in Xcode…" : "Generate Project Folder…",
                        systemImage: "hammer.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.themeTokens.primary.swiftUIColor)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 590)
        .onAppear {
            if let bpID = activeEnterpriseBlueprintID {
                projectName = bpID.defaultAppTargetName
                bundleIdentifier = bpID.defaultBundleIdentifier
            } else {
                projectName = viewModel.selection.sanitizedProjectName
                bundleIdentifier = "com.hnmlabs.\(viewModel.selection.sanitizedProjectName.lowercased())"
            }
        }
    }

    private func iconForPath(_ path: String) -> String {
        if path.hasSuffix(".json") || path.hasSuffix(".xcstrings") {
            return "curlybraces"
        } else if path.hasSuffix(".xcprivacy") {
            return "hand.raised.fill"
        } else if path.contains("Tests/") {
            return "checkmark.seal"
        } else {
            return "doc.text"
        }
    }

    private func generateProject() {
        do {
            if let enterpriseReq = currentEnterpriseRequest {
                if let result = try ProjectGeneratorService.chooseDirectoryAndGenerateEnterpriseBlueprint(
                    request: enterpriseReq,
                    openInXcodeAfterExport: openInXcodeAfterExport
                ) {
                    viewModel.statusMessage = "Exported \(result.writtenFileURLs.count)-file workspace (\(result.workspace.totalLinesOfCode) LOC) to \(result.rootDirectoryURL.lastPathComponent)"
                    dismiss()
                }
            } else if let folder = try ProjectGeneratorService.chooseDirectoryAndGenerate(config: currentConfig) {
                viewModel.statusMessage = "Generated project at \(folder.lastPathComponent)"
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
