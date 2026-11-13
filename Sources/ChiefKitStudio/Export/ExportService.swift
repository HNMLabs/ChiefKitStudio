#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitStudioCore
import Foundation

enum ExportService {
    static let dmgDownloadURLString = "https://hnmlabs.com/downloads.php"
    static let studioRepoURLString = "https://github.com/HNMLabs/ChiefKitStudio"

    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @MainActor
    static func export(
        text: String,
        suggestedFileName: String,
        panelTitle: String = "Export Example File"
    ) throws -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFileName
        panel.canCreateDirectories = true
        panel.title = panelTitle

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @MainActor
    static func saveWorkspace(_ snapshot: WorkspaceSnapshot) throws -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MyStudioSession.chiefkit"
        panel.canCreateDirectories = true
        panel.title = "Save ChiefKit Studio Workspace (.chiefkit)"

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        try snapshot.save(to: url)
        return url
    }

    @MainActor
    static func openWorkspace() throws -> (snapshot: WorkspaceSnapshot, url: URL)? {
        let panel = NSOpenPanel()
        panel.title = "Open ChiefKit Studio Workspace (.chiefkit)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let loaded = try WorkspaceSnapshot.load(from: url)
        return (loaded, url)
    }

    static func buildPackageSnippetBundle(
        title: String,
        dependencySnippet: String,
        themeSnippet: String,
        swiftUICode: String
    ) -> String {
        let commentedDeps = dependencySnippet
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "// \($0)" }
            .joined(separator: "\n")

        return """
        // ============================================================================
        // ChiefKit Studio — Package Snippet Export (\(title))
        // Add the following to your Package.swift:
        // ----------------------------------------------------------------------------
        \(commentedDeps)
        // ============================================================================

        \(themeSnippet)

        // MARK: - \(title)

        \(swiftUICode)
        """
    }

    static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func openWorkspaceInXcode() -> String {
        let fileManager = FileManager.default
        let currentDirPackage = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("Package.swift")

        if fileManager.fileExists(atPath: currentDirPackage.path) {
            let xcodeURL = URL(fileURLWithPath: "/Applications/Xcode.app")
            if fileManager.fileExists(atPath: xcodeURL.path) {
                NSWorkspace.shared.open(
                    [currentDirPackage],
                    withApplicationAt: xcodeURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                NSWorkspace.shared.open(currentDirPackage)
            }
            return "Opened Package.swift in Xcode"
        }

        let panel = NSOpenPanel()
        panel.title = "Select Package.swift or Xcode Project to Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedURL = panel.url {
            NSWorkspace.shared.open(selectedURL)
            return "Opened \(selectedURL.lastPathComponent) in Xcode"
        }
        return "Tip: Use 'Generate Project' (⌘⇧E) to export and open in Xcode"
    }
}
#endif
