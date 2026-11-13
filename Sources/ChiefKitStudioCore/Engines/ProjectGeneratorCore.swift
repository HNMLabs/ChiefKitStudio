import Foundation

public enum ProjectDependencyMode: String, CaseIterable, Identifiable, Sendable {
    case standaloneReady = "Standalone Starter (Compiles Offline Immediately)"
    case fullSPM = "HNMLabs SwiftPM Dependencies (SwiftBlocks / SwiftState / NotebookFlowKit)"

    public var id: String { rawValue }
}

public struct ProjectGenerationConfig: Sendable {
    public var projectName: String
    public var bundleIdentifier: String
    public var dependencyMode: ProjectDependencyMode
    public var includeUnitTests: Bool
    public var openInXcodeAfterExport: Bool
    public var selection: NavigationSelection
    public var requiredPackages: [PackageDemo]
    public var swiftUICode: String
    public var unitTestsCode: String?
    public var themeTokens: StudioThemeTokens
    public var flowJSON: String?

    public init(
        projectName: String,
        bundleIdentifier: String,
        dependencyMode: ProjectDependencyMode,
        includeUnitTests: Bool = true,
        openInXcodeAfterExport: Bool = true,
        selection: NavigationSelection,
        requiredPackages: [PackageDemo],
        swiftUICode: String,
        unitTestsCode: String? = nil,
        themeTokens: StudioThemeTokens,
        flowJSON: String? = nil
    ) {
        self.projectName = projectName
        self.bundleIdentifier = bundleIdentifier
        self.dependencyMode = dependencyMode
        self.includeUnitTests = includeUnitTests
        self.openInXcodeAfterExport = openInXcodeAfterExport
        self.selection = selection
        self.requiredPackages = requiredPackages
        self.swiftUICode = swiftUICode
        self.unitTestsCode = unitTestsCode
        self.themeTokens = themeTokens
        self.flowJSON = flowJSON
    }

    public var cleanTargetName: String {
        let filtered = projectName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
        return filtered.isEmpty ? "ChiefKitStarterApp" : filtered
    }
}

public enum ProjectGeneratorCore {
    @discardableResult
    public static func writeProject(config: ProjectGenerationConfig, inside parentDirectory: URL) throws -> URL {
        let fm = FileManager.default
        let targetName = config.cleanTargetName
        let rootDir = parentDirectory.appendingPathComponent(targetName, isDirectory: true)
        let sourcesDir = rootDir
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)
        let resourcesDir = sourcesDir.appendingPathComponent("Resources", isDirectory: true)

        try fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        // 1. Package.swift
        let packageSwift = makePackageSwift(config: config, targetName: targetName)
        try packageSwift.write(
            to: rootDir.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        // 2. .gitignore
        let gitignore = """
        .DS_Store
        .build/
        .swiftpm/
        DerivedData/
        *.xcodeproj/project.xcworkspace/
        *.xcodeproj/xcuserdata/
        """
        try gitignore.write(
            to: rootDir.appendingPathComponent(".gitignore"),
            atomically: true,
            encoding: .utf8
        )

        // 3. App Entry Point
        let appSwift = """
        import SwiftUI

        @main
        struct \(targetName)App: App {
            var body: some Scene {
                WindowGroup("\(config.projectName)") {
                    GeneratedRootHostView()
                        .frame(minWidth: 640, minHeight: 480)
                }
            }
        }
        """
        try appSwift.write(
            to: sourcesDir.appendingPathComponent("\(targetName)App.swift"),
            atomically: true,
            encoding: .utf8
        )

        // 4. ThemeTokens.swift + W3C tokens.json
        let themeFileContent: String
        switch config.dependencyMode {
        case .fullSPM:
            themeFileContent = config.themeTokens.swiftBlocksThemeSnippet
        case .standaloneReady:
            themeFileContent = makeStandaloneCompatAndTheme(tokens: config.themeTokens)
        }
        try themeFileContent.write(
            to: sourcesDir.appendingPathComponent("ThemeTokens.swift"),
            atomically: true,
            encoding: .utf8
        )

        // 5. GeneratedPlaygroundView.swift
        let sanitizedViewCode = prepareViewCode(config: config)
        try sanitizedViewCode.write(
            to: sourcesDir.appendingPathComponent("GeneratedPlaygroundView.swift"),
            atomically: true,
            encoding: .utf8
        )

        // 6. Optional flow.json resource + W3C Design Tokens
        try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        try config.themeTokens.w3cDesignTokensJSON.write(
            to: resourcesDir.appendingPathComponent("design-tokens.w3c.json"),
            atomically: true,
            encoding: .utf8
        )
        if let flowJSON = config.flowJSON {
            try flowJSON.write(
                to: resourcesDir.appendingPathComponent("flow.json"),
                atomically: true,
                encoding: .utf8
            )
        }

        // 7. Optional Unit Test Suite
        if config.includeUnitTests {
            let testsDir = rootDir
                .appendingPathComponent("Tests", isDirectory: true)
                .appendingPathComponent("\(targetName)Tests", isDirectory: true)
            try fm.createDirectory(at: testsDir, withIntermediateDirectories: true)
            let suiteCode = config.unitTestsCode ?? defaultTestSuite(for: config, targetName: targetName)
            try suiteCode.write(
                to: testsDir.appendingPathComponent("\(targetName)Tests.swift"),
                atomically: true,
                encoding: .utf8
            )
        }

        // 8. README.md
        let testNote = config.includeUnitTests
            ? "- `Tests/\(targetName)Tests/\(targetName)Tests.swift` — Automated unit tests (`swift test`)"
            : ""
        let readme = """
        # \(config.projectName)

        Generated with **ChiefKit Studio** from example: **\(config.selection.title)**.

        ## Quick Start

        Open `Package.swift` directly in Xcode:

        ```bash
        open Package.swift
        ```

        Or build, test, and launch from Terminal:

        ```bash
        swift test
        swift run
        ```

        ## Included Files

        - `Package.swift` — SwiftPM manifest (\(config.dependencyMode.rawValue))
        - `Sources/\(targetName)/\(targetName)App.swift` — App entry point
        - `Sources/\(targetName)/GeneratedPlaygroundView.swift` — Exported ChiefKit view
        - `Sources/\(targetName)/ThemeTokens.swift` — Customized design tokens (`\(config.themeTokens.primary.hexString)`)
        - `Sources/\(targetName)/Resources/design-tokens.w3c.json` — Portable W3C Design Tokens
        \(testNote)
        """
        try readme.write(
            to: rootDir.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )

        return rootDir
    }

    public static func previewFileTree(for config: ProjectGenerationConfig) -> [String] {
        let t = config.cleanTargetName
        var files = [
            "\(t)/Package.swift",
            "\(t)/README.md",
            "\(t)/.gitignore",
            "\(t)/Sources/\(t)/\(t)App.swift",
            "\(t)/Sources/\(t)/GeneratedPlaygroundView.swift",
            "\(t)/Sources/\(t)/ThemeTokens.swift",
            "\(t)/Sources/\(t)/Resources/design-tokens.w3c.json"
        ]
        if config.flowJSON != nil {
            files.append("\(t)/Sources/\(t)/Resources/flow.json")
        }
        if config.includeUnitTests {
            files.append("\(t)/Tests/\(t)Tests/\(t)Tests.swift")
        }
        return files
    }

    private static func makePackageSwift(config: ProjectGenerationConfig, targetName: String) -> String {
        let testTargetBlock = config.includeUnitTests ? """
        ,
                .testTarget(
                    name: "\(targetName)Tests",
                    dependencies: ["\(targetName)"],
                    path: "Tests/\(targetName)Tests"
                )
        """ : ""

        switch config.dependencyMode {
        case .standaloneReady:
            return """
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "\(targetName)",
                platforms: [
                    .macOS(.v13),
                    .iOS(.v16)
                ],
                products: [
                    .executable(name: "\(targetName)", targets: ["\(targetName)"])
                ],
                targets: [
                    .executableTarget(
                        name: "\(targetName)",
                        path: "Sources/\(targetName)",
                        resources: [.process("Resources")]
                    )\(testTargetBlock)
                ]
            )
            """

        case .fullSPM:
            let spmPackages = config.requiredPackages.filter { $0 != .coreLocalAIKit }
            let depsBody = spmPackages
                .map { "        \($0.packageDependencySnippet)" }
                .joined(separator: ",\n")
            let targetDepsBody = spmPackages
                .map { "                \($0.targetDependencySnippet)" }
                .joined(separator: ",\n")

            return """
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "\(targetName)",
                platforms: [
                    .macOS(.v14),
                    .iOS(.v17)
                ],
                products: [
                    .executable(name: "\(targetName)", targets: ["\(targetName)"])
                ],
                dependencies: [
            \(depsBody)
                ],
                targets: [
                    .executableTarget(
                        name: "\(targetName)",
                        dependencies: [
            \(targetDepsBody)
                        ],
                        path: "Sources/\(targetName)",
                        resources: [.process("Resources")]
                    )\(testTargetBlock)
                ]
            )
            """
        }
    }

    private static func prepareViewCode(config: ProjectGenerationConfig) -> String {
        var code = config.swiftUICode
        if config.dependencyMode == .standaloneReady {
            code = code
                .replacingOccurrences(of: "import SwiftBlocks\n", with: "")
                .replacingOccurrences(of: "import SwiftState\n", with: "")
                .replacingOccurrences(of: "import NotebookFlowKit\n", with: "")
                .replacingOccurrences(of: "import CoreLocalAIKit\n", with: "")
        }

        let detectedStructName = firstViewStructName(in: code)
        let hostCall: String
        if let structName = detectedStructName {
            if code.contains("let flowJSON: String") && !code.contains("let flowJSON: String =") {
                hostCall = "\(structName)(flowJSON: sampleBundledFlowJSON)"
            } else if code.contains("let quizJSON: String") {
                hostCall = "\(structName)(quizJSON: sampleBundledFlowJSON)"
            } else {
                hostCall = "\(structName)()"
            }
        } else {
            hostCall = "Text(\"Generated from ChiefKit Studio\").padding(24)"
        }

        let escapedJSON = (config.flowJSON ?? "{}")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        return """
        \(code)

        // MARK: - Host Wrapper

        let sampleBundledFlowJSON = "\(escapedJSON)"

        struct GeneratedRootHostView: View {
            var body: some View {
                \(hostCall)
                    .padding(20)
            }
        }
        """
    }

    public static func firstViewStructName(in code: String) -> String? {
        for line in code.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("struct "), trimmed.contains(": View") {
                let afterStruct = trimmed.dropFirst("struct ".count)
                let name = afterStruct.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                if !name.isEmpty {
                    return String(name)
                }
            }
        }
        return nil
    }

    private static func defaultTestSuite(for config: ProjectGenerationConfig, targetName: String) -> String {
        """
        import XCTest

        final class \(targetName)Tests: XCTestCase {
            func testThemeTokenHexIsWellFormed() {
                let primaryHex = "\(config.themeTokens.primary.hexString)"
                XCTAssertTrue(primaryHex.hasPrefix("#"))
                XCTAssertEqual(primaryHex.count, 7)
            }

            func testSelectionMetadataIsPresent() {
                let exportedTitle = "\(config.selection.title.replacingOccurrences(of: "\"", with: "\\\""))"
                XCTAssertFalse(exportedTitle.isEmpty)
            }
        }
        """
    }

    private static func makeStandaloneCompatAndTheme(tokens: StudioThemeTokens) -> String {
        """
        import SwiftUI

        // Lightweight standalone compatibility layer generated by ChiefKit Studio
        enum EDKVariant: String {
            case primary, secondary, glass, success, warning, danger, light, dark
        }

        enum EDKComponentSize: String {
            case small, medium, large
        }

        struct StudioTheme {
            let primary = \(tokens.primary.swiftInitializer)
            let secondary = \(tokens.secondary.swiftInitializer)
            let success = \(tokens.success.swiftInitializer)
            let warning = \(tokens.warning.swiftInitializer)
            let danger = \(tokens.danger.swiftInitializer)
            let surface = \(tokens.surface.swiftInitializer)
        }

        let studioTheme = StudioTheme()

        struct EDKButton: View {
            let title: String
            let variant: EDKVariant
            let size: EDKComponentSize
            let action: () -> Void

            init(_ title: String, variant: EDKVariant = .primary, size: EDKComponentSize = .medium, action: @escaping () -> Void) {
                self.title = title
                self.variant = variant
                self.size = size
                self.action = action
            }

            var body: some View {
                Button(title, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(studioTheme.primary)
            }
        }

        struct EDKSurface<Content: View>: View {
            let variant: EDKVariant
            let cornerRadius: CGFloat
            let content: Content

            init(variant: EDKVariant = .glass, cornerRadius: CGFloat = \(Int(tokens.radiusMedium.rounded())), @ViewBuilder content: () -> Content) {
                self.variant = variant
                self.cornerRadius = cornerRadius
                self.content = content()
            }

            var body: some View {
                content
                    .padding(\(Int(tokens.spacingMD)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }

        extension View {
            func edkTheme(_ theme: StudioTheme) -> some View { self }
            func edkLiquidGlass(cornerRadius: CGFloat) -> some View { self }
        }
        """
    }
}
