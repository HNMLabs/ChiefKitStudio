#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct ProjectGeneratorSheet: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var bundleIdentifier: String = "com.hnmlabs.ChiefKitStarter"
    @State private var dependencyMode: ProjectDependencyMode = .standaloneReady
    @State private var includeUnitTests = true
    @State private var openInXcodeAfterExport = true
    @State private var errorMessage: String?

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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ChiefKitLogoView(size: 40, cornerRadius: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text("One-Click Project Generator")
                        .font(.title3.weight(.bold))
                    Text("Export '\(viewModel.selectionDisplayTitle)' + W3C Design Tokens + Unit Tests as a SwiftPM / Xcode app.")
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
                    Picker("Mode", selection: $dependencyMode) {
                        ForEach(ProjectDependencyMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Include Automated Unit Tests Target (Tests/<App>Tests)", isOn: $includeUnitTests)
                    .font(.callout)

                Toggle("Open generated Package.swift in Xcode automatically", isOn: $openInXcodeAfterExport)
                    .font(.callout)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Generated File Structure")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(ProjectGeneratorService.previewFileTree(for: currentConfig), id: \.self) { path in
                        HStack(spacing: 6) {
                            Image(systemName: path.hasSuffix(".json") ? "curlybraces" : (path.contains("Tests/") ? "checkmark.seal" : "doc.text"))
                                .font(.caption2)
                                .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)
                            Text(path)
                                .font(.system(size: 11.5, design: .monospaced))
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(width: 550)
        .onAppear {
            projectName = viewModel.selection.sanitizedProjectName
            bundleIdentifier = "com.hnmlabs.\(viewModel.selection.sanitizedProjectName.lowercased())"
        }
    }

    private func generateProject() {
        do {
            if let folder = try ProjectGeneratorService.chooseDirectoryAndGenerate(config: currentConfig) {
                viewModel.statusMessage = "Generated project at \(folder.lastPathComponent)"
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
