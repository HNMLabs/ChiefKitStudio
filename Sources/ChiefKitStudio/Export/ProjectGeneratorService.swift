#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitBlueprints
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
        revealOrOpenInXcode(projectFolder: projectFolder, openInXcode: config.openInXcodeAfterExport)
        return projectFolder
    }

    @MainActor
    static func chooseDirectoryAndGenerateEnterpriseBlueprint(
        request: BlueprintExportRequest,
        openInXcodeAfterExport: Bool
    ) throws -> BlueprintExportResult? {
        let panel = NSOpenPanel()
        panel.title = "Choose Destination Folder for \(request.resolvedTargetName) (14-File Enterprise Workspace)"
        panel.prompt = "Generate 14-File Workspace"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let parentDirectory = panel.url else {
            return nil
        }

        let result = try BlueprintWorkspaceExporter.exportToDisk(
            request: request,
            destinationParentDirectory: parentDirectory,
            overwriteExisting: true
        )
        revealOrOpenInXcode(projectFolder: result.rootDirectoryURL, openInXcode: openInXcodeAfterExport)
        return result
    }

    static func previewFileTree(for config: ProjectGenerationConfig) -> [String] {
        ProjectGeneratorCore.previewFileTree(for: config)
    }

    static func previewEnterpriseFileTree(for request: BlueprintExportRequest) -> [String] {
        BlueprintWorkspaceExporter.previewFileTree(for: request)
    }

    @MainActor
    private static func revealOrOpenInXcode(projectFolder: URL, openInXcode: Bool) {
        if openInXcode {
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
    }
}
#endif
