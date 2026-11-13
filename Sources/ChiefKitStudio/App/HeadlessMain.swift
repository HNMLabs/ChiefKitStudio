#if !(canImport(SwiftUI) && canImport(AppKit))
import ChiefKitStudioCore
import Foundation

@main
struct ChiefKitStudioHeadlessCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.contains("--version") || args.contains("-v") {
            print("ChiefKit Studio 2.5 (ChiefKitStudioCore Cross-Platform Engine)")
            return
        }

        if let exportIdx = args.firstIndex(of: "--export-demo"), exportIdx + 1 < args.count {
            let outPath = args[exportIdx + 1]
            let outURL = URL(fileURLWithPath: outPath, isDirectory: true)
            let theme = StudioThemePreset.liquidGlass26.tokens
            let canvas = CanvasDocument.starter(radius: theme.radiusMedium)
            let code = canvas.generateSwiftUICode(
                theme: theme,
                layoutMode: .adaptiveStacks,
                focusedNodeID: nil,
                focusSelectedOnly: false
            )
            let config = ProjectGenerationConfig(
                projectName: "ChiefKitExportedDemo",
                bundleIdentifier: "com.hnmlabs.exporteddemo",
                dependencyMode: .standaloneReady,
                includeUnitTests: true,
                openInXcodeAfterExport: false,
                selection: .package(.swiftBlocks),
                requiredPackages: [.swiftBlocks],
                swiftUICode: code,
                themeTokens: theme,
                flowJSON: DemoLibrary.defaultFlowJSON
            )
            do {
                let created = try ProjectGeneratorCore.writeProject(config: config, inside: outURL)
                print("Exported starter project to: \(created.path)")
            } catch {
                FileHandle.standardError.write(Data("Export failed: \(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
            return
        }

        // Default or --self-check: run complete end-to-end diagnostic suite
        let report = await StudioSelfCheckRunner.runAll()
        print(report.formattedSummary)
        if !report.allPassed {
            Foundation.exit(1)
        }
    }
}
#endif
