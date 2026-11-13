#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitStudioCore
import Foundation

enum ProjectGeneratorService {
    @MainActor
    static func chooseDirectoryAndGenerate(config: ProjectGenerationConfig) throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Destination Folder for \(config.cleanTargetName)"
        panel.prompt = "Generate Project"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let parentDirectory = panel.url else {
            return nil
        }

        let projectFolder = try ProjectGeneratorCore.writeProject(config: config, inside: parentDirectory)

        if config.openInXcodeAfterExport {
            let packageFile = projectFolder.appendingPathComponent("Package.swift")
            let xcodeApp = URL(fileURLWithPath: "/Applications/Xcode.app")
            if FileManager.default.fileExists(atPath: xcodeApp.path) {
                NSWorkspace.shared.open(
                    [packageFile],
                    withApplicationAt: xcodeApp,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                NSWorkspace.shared.open(packageFile)
            }
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([projectFolder])
        }

        return projectFolder
    }

    static func previewFileTree(for config: ProjectGenerationConfig) -> [String] {
        ProjectGeneratorCore.previewFileTree(for: config)
    }
}
#endif
