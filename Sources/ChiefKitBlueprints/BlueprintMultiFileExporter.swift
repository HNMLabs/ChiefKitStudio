#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Export Configuration & Dependency Strategy

/// Controls whether exported SwiftPM workspaces compile 100% offline or declare remote HNMLabs SwiftPM packages.
public enum BlueprintDependencyStrategy: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case standaloneOffline = "Standalone Swift 6 (Compiles Offline Immediately)"
    case chiefKitEcosystemSPM = "HNMLabs Ecosystem Dependencies (SwiftBlocks / SwiftState / NotebookFlowKit)"

    public var id: String { rawValue }
}

/// Logical architectural role of a generated file inside an exported ChiefKit workspace.
public enum BlueprintGeneratedFileCategory: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case manifest
    case documentation
    case gitConfig
    case appEntryPoint
    case domainModels
    case stateReducer
    case persistence
    case networking
    case views
    case resources
    case unitTests

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .manifest: return "SwiftPM Manifest"
        case .documentation: return "Architecture README"
        case .gitConfig: return "Git Ignore Rules"
        case .appEntryPoint: return "App Entry & Theme"
        case .domainModels: return "Domain Value Models"
        case .stateReducer: return "Deterministic Reducer & Store"
        case .persistence: return "SwiftData & SQLite WAL"
        case .networking: return "Async REST API Actor"
        case .views: return "SwiftUI Workbench View"
        case .resources: return "Bundled App Resources"
        case .unitTests: return "Swift Testing (@Test) Suite"
        }
    }
}

/// Complete configuration payload for exporting a 14-file Swift 6 blueprint package.
public struct BlueprintExportRequest: Codable, Equatable, Hashable, Sendable {
    public var blueprintID: EnterpriseBlueprintID
    public var customAppName: String?
    public var bundleIdentifier: String?
    public var theme: StudioThemeTokens
    public var enabledLayers: [EnterpriseLayerKind]
    public var targetPlatforms: [TargetApplePlatform]
    public var dependencyStrategy: BlueprintDependencyStrategy

    public init(
        blueprintID: EnterpriseBlueprintID,
        customAppName: String? = nil,
        bundleIdentifier: String? = nil,
        theme: StudioThemeTokens? = nil,
        enabledLayers: [EnterpriseLayerKind] = EnterpriseLayerKind.allCases,
        targetPlatforms: [TargetApplePlatform]? = nil,
        dependencyStrategy: BlueprintDependencyStrategy = .standaloneOffline
    ) {
        let spec = EnterpriseBlueprintCatalog.spec(for: blueprintID)
        self.blueprintID = blueprintID
        self.customAppName = customAppName
        self.bundleIdentifier = bundleIdentifier
        self.theme = theme ?? spec.vertical.recommendedThemePreset.tokens
        self.enabledLayers = enabledLayers.isEmpty ? [.swiftBlocksUI, .swiftStateReducer] : enabledLayers
        self.targetPlatforms = (targetPlatforms?.isEmpty == false)
            ? targetPlatforms!
            : spec.supportedPlatforms
        self.dependencyStrategy = dependencyStrategy
    }

    /// Sanitized PascalCase Swift module/executable identifier.
    public var resolvedTargetName: String {
        guard let custom = customAppName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !custom.isEmpty else {
            return blueprintID.defaultAppTargetName
        }
        let parts = custom
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { fragment -> String in
                fragment.prefix(1).uppercased() + fragment.dropFirst()
            }
        let candidate = parts.joined()
        if candidate.isEmpty {
            return blueprintID.defaultAppTargetName
        }
        if let first = candidate.first, first.isNumber {
            return "App\(candidate)"
        }
        return candidate
    }

    /// Reverse-DNS Apple bundle identifier.
    public var resolvedBundleIdentifier: String {
        if let custom = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return blueprintID.defaultBundleIdentifier
    }

    public func isLayerEnabled(_ layer: EnterpriseLayerKind) -> Bool {
        enabledLayers.contains(layer)
    }
}

// MARK: - In-Memory Generated File & Workspace Bundle

/// Single synthesized file ready to be previewed in ChiefKit Studio or written to disk.
public struct BlueprintGeneratedFile: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { relativePath }
    public let relativePath: String
    public let category: BlueprintGeneratedFileCategory
    public let content: String

    public init(
        relativePath: String,
        category: BlueprintGeneratedFileCategory,
        content: String
    ) {
        self.relativePath = relativePath
        self.category = category
        self.content = content
    }

    public var byteCount: Int {
        content.utf8.count
    }

    public var lineCount: Int {
        guard !content.isEmpty else { return 0 }
        return content.reduce(into: 1) { count, ch in
            if ch == "\n" { count += 1 }
        }
    }

    public var fileName: String {
        (relativePath as NSString).lastPathComponent
    }
}

/// Complete 14-file in-memory representation of a generated Swift 6 blueprint package.
public struct BlueprintGeneratedWorkspace: Codable, Equatable, Hashable, Sendable {
    public let blueprintID: EnterpriseBlueprintID
    public let vertical: EnterpriseVertical
    public let targetName: String
    public let bundleIdentifier: String
    public let enabledLayers: [EnterpriseLayerKind]
    public let targetPlatforms: [TargetApplePlatform]
    public let files: [BlueprintGeneratedFile]

    public init(
        blueprintID: EnterpriseBlueprintID,
        vertical: EnterpriseVertical,
        targetName: String,
        bundleIdentifier: String,
        enabledLayers: [EnterpriseLayerKind],
        targetPlatforms: [TargetApplePlatform],
        files: [BlueprintGeneratedFile]
    ) {
        self.blueprintID = blueprintID
        self.vertical = vertical
        self.targetName = targetName
        self.bundleIdentifier = bundleIdentifier
        self.enabledLayers = enabledLayers
        self.targetPlatforms = targetPlatforms
        self.files = files
    }

    public var totalLinesOfCode: Int {
        files.reduce(0) { $0 + $1.lineCount }
    }

    public var totalBytes: Int {
        files.reduce(0) { $0 + $1.byteCount }
    }

    public var swiftSourceFiles: [BlueprintGeneratedFile] {
        files.filter { $0.relativePath.hasSuffix(".swift") }
    }

    public var resourceFiles: [BlueprintGeneratedFile] {
        files.filter { $0.category == .resources }
    }

    public func file(at relativePath: String) -> BlueprintGeneratedFile? {
        files.first { $0.relativePath == relativePath }
    }
}

/// Disk export receipt returned after writing all 14 package files to the filesystem.
public struct BlueprintExportResult: Equatable, Sendable {
    public let rootDirectoryURL: URL
    public let workspace: BlueprintGeneratedWorkspace
    public let writtenFileURLs: [URL]

    public init(
        rootDirectoryURL: URL,
        workspace: BlueprintGeneratedWorkspace,
        writtenFileURLs: [URL]
    ) {
        self.rootDirectoryURL = rootDirectoryURL
        self.workspace = workspace
        self.writtenFileURLs = writtenFileURLs
    }
}

public enum BlueprintExportError: Error, LocalizedError, Equatable, Sendable {
    case destinationAlreadyExists(String)
    case invalidRelativePath(String)
    case fileWriteFailed(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .destinationAlreadyExists(let path):
            return "Export target directory already exists at \(path) and overwriteExisting is false."
        case .invalidRelativePath(let rel):
            return "Refused unsafe relative export path '\(rel)'."
        case .fileWriteFailed(let path, let reason):
            return "Failed writing '\(path)': \(reason)"
        }
    }
}

// MARK: - Multi-File Swift 6 Workspace Exporter

/// Synthesizes and writes any of the 28 Enterprise Blueprints into a structured 14-file Swift 6 SwiftPM package.
public enum BlueprintWorkspaceExporter: Sendable {
    /// Every exported workspace produces a deterministic 14-file multi-directory layout.
    public static let canonicalFileCount: Int = 14

    /// Returns the ordered relative file paths that will be generated for `request`.
    public static func previewFileTree(for request: BlueprintExportRequest) -> [String] {
        let app = request.resolvedTargetName
        return [
            "Package.swift",
            "README.md",
            ".gitignore",
            "Sources/\(app)/\(app)App.swift",
            "Sources/\(app)/Models/DomainModels.swift",
            "Sources/\(app)/State/AppReducer.swift",
            "Sources/\(app)/Persistence/PersistenceSchema.swift",
            "Sources/\(app)/Networking/APIClient.swift",
            "Sources/\(app)/Views/RootWorkbenchView.swift",
            "Sources/\(app)/Resources/onboarding-flow.json",
            "Sources/\(app)/Resources/design-tokens.w3c.json",
            "Sources/\(app)/Resources/PrivacyInfo.xcprivacy",
            "Sources/\(app)/Resources/Localizable.xcstrings",
            "Tests/\(app)Tests/\(app)Tests.swift"
        ]
    }

    /// Synthesizes all 14 files in memory for instant inspection, diffing, or validation.
    public static func generateWorkspace(
        for blueprintID: EnterpriseBlueprintID,
        theme: StudioThemeTokens? = nil,
        layers: [EnterpriseLayerKind] = EnterpriseLayerKind.allCases,
        platforms: [TargetApplePlatform]? = nil,
        dependencyStrategy: BlueprintDependencyStrategy = .standaloneOffline
    ) -> BlueprintGeneratedWorkspace {
        let request = BlueprintExportRequest(
            blueprintID: blueprintID,
            theme: theme,
            enabledLayers: layers,
            targetPlatforms: platforms,
            dependencyStrategy: dependencyStrategy
        )
        return generateWorkspace(request: request)
    }

    /// Synthesizes all 14 files in memory from a strongly-typed `BlueprintExportRequest`.
    public static func generateWorkspace(request: BlueprintExportRequest) -> BlueprintGeneratedWorkspace {
        let spec = EnterpriseBlueprintCatalog.spec(for: request.blueprintID)
        let app = request.resolvedTargetName
        let bundleID = request.resolvedBundleIdentifier

        let packageSwift = renderPackageSwift(spec: spec, request: request, targetName: app)
        let readmeMD = renderReadmeMarkdown(spec: spec, request: request, targetName: app, bundleID: bundleID)
        let gitignore = renderGitignore()
        let appEntrySwift = renderAppEntryAndThemeSwift(spec: spec, request: request, targetName: app)
        let domainModelsSwift = spec.synthesizeDomainModels(
            includeSecurityHelpers: true
        )
        let reducerSwift = renderStateLayerSwift(spec: spec, request: request)
        let persistenceSwift = renderPersistenceLayerSwift(spec: spec, request: request)
        let networkingSwift = renderNetworkingLayerSwift(spec: spec, request: request)
        let rootViewSwift = renderRootWorkbenchViewSwift(spec: spec, request: request)
        let onboardingJSON = spec.synthesizeOnboardingFlowJSON()
        let w3cTokensJSON = request.theme.w3cDesignTokensJSON
        let privacyXML = spec.synthesizePrivacyManifestXML()
        let xcstringsJSON = spec.synthesizeLocalizableStringsCatalogJSON()
        let unitTestsSwift = renderTestsSuiteSwift(spec: spec, request: request, targetName: app)

        let files: [BlueprintGeneratedFile] = [
            BlueprintGeneratedFile(
                relativePath: "Package.swift",
                category: .manifest,
                content: packageSwift
            ),
            BlueprintGeneratedFile(
                relativePath: "README.md",
                category: .documentation,
                content: readmeMD
            ),
            BlueprintGeneratedFile(
                relativePath: ".gitignore",
                category: .gitConfig,
                content: gitignore
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/\(app)App.swift",
                category: .appEntryPoint,
                content: appEntrySwift
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/Models/DomainModels.swift",
                category: .domainModels,
                content: domainModelsSwift
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/State/AppReducer.swift",
                category: .stateReducer,
                content: reducerSwift
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/Persistence/PersistenceSchema.swift",
                category: .persistence,
                content: persistenceSwift
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/Networking/APIClient.swift",
                category: .networking,
                content: networkingSwift
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/Views/RootWorkbenchView.swift",
                category: .views,
                content: rootViewSwift
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/Resources/onboarding-flow.json",
                category: .resources,
                content: onboardingJSON
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/Resources/design-tokens.w3c.json",
                category: .resources,
                content: w3cTokensJSON
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/Resources/PrivacyInfo.xcprivacy",
                category: .resources,
                content: privacyXML
            ),
            BlueprintGeneratedFile(
                relativePath: "Sources/\(app)/Resources/Localizable.xcstrings",
                category: .resources,
                content: xcstringsJSON
            ),
            BlueprintGeneratedFile(
                relativePath: "Tests/\(app)Tests/\(app)Tests.swift",
                category: .unitTests,
                content: unitTestsSwift
            )
        ]

        return BlueprintGeneratedWorkspace(
            blueprintID: spec.id,
            vertical: spec.vertical,
            targetName: app,
            bundleIdentifier: bundleID,
            enabledLayers: request.enabledLayers,
            targetPlatforms: request.targetPlatforms,
            files: files
        )
    }

    /// Writes a complete 14-file Swift 6 SwiftPM package to `destinationParentDirectory/<TargetName>`.
    @discardableResult
    public static func exportToDisk(
        blueprintID: EnterpriseBlueprintID,
        theme: StudioThemeTokens? = nil,
        layers: [EnterpriseLayerKind] = EnterpriseLayerKind.allCases,
        platforms: [TargetApplePlatform]? = nil,
        dependencyStrategy: BlueprintDependencyStrategy = .standaloneOffline,
        destinationParentDirectory: URL,
        overwriteExisting: Bool = true
    ) throws -> BlueprintExportResult {
        let request = BlueprintExportRequest(
            blueprintID: blueprintID,
            theme: theme,
            enabledLayers: layers,
            targetPlatforms: platforms,
            dependencyStrategy: dependencyStrategy
        )
        return try exportToDisk(
            request: request,
            destinationParentDirectory: destinationParentDirectory,
            overwriteExisting: overwriteExisting
        )
    }

    /// Writes a configured `BlueprintExportRequest` to disk and returns the export receipt.
    @discardableResult
    public static func exportToDisk(
        request: BlueprintExportRequest,
        destinationParentDirectory: URL,
        overwriteExisting: Bool = true
    ) throws -> BlueprintExportResult {
        let fm = FileManager.default
        let workspace = generateWorkspace(request: request)
        let rootURL = destinationParentDirectory.appendingPathComponent(workspace.targetName, isDirectory: true)

        if fm.fileExists(atPath: rootURL.path) {
            if overwriteExisting {
                try fm.removeItem(at: rootURL)
            } else {
                throw BlueprintExportError.destinationAlreadyExists(rootURL.path)
            }
        }

        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var writtenURLs: [URL] = []
        writtenURLs.reserveCapacity(workspace.files.count)

        for file in workspace.files {
            guard !file.relativePath.contains(".."), !file.relativePath.hasPrefix("/") else {
                throw BlueprintExportError.invalidRelativePath(file.relativePath)
            }
            let fileURL = rootURL.appendingPathComponent(file.relativePath, isDirectory: false)
            let parentDir = fileURL.deletingLastPathComponent()
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
            do {
                try file.content.write(to: fileURL, atomically: true, encoding: .utf8)
                writtenURLs.append(fileURL)
            } catch {
                throw BlueprintExportError.fileWriteFailed(
                    path: fileURL.path,
                    reason: error.localizedDescription
                )
            }
        }

        return BlueprintExportResult(
            rootDirectoryURL: rootURL,
            workspace: workspace,
            writtenFileURLs: writtenURLs
        )
    }

    // MARK: - Private File Renderers

    private static func renderPackageSwift(
        spec: EnterpriseBlueprintSpec,
        request: BlueprintExportRequest,
        targetName: String
    ) -> String {
        var seenClauses: [String] = []
        for platform in request.targetPlatforms {
            if let clause = platform.spmPlatformClause, !seenClauses.contains(clause) {
                seenClauses.append(clause)
            }
        }
        if seenClauses.isEmpty {
            seenClauses = [".macOS(.v14)", ".iOS(.v17)"]
        }
        let platformsBody = seenClauses.map { "        \($0)" }.joined(separator: ",\n")

        switch request.dependencyStrategy {
        case .standaloneOffline:
            return """
            // swift-tools-version: 6.0
            import PackageDescription

            #if os(macOS)
            let appResources: [Resource] = [.process("Resources")]
            #else
            let appResources: [Resource] = [.copy("Resources")]
            #endif

            let package = Package(
                name: "\(targetName)",
                defaultLocalization: "en",
                platforms: [
            \(platformsBody)
                ],
                products: [
                    .executable(name: "\(targetName)", targets: ["\(targetName)"])
                ],
                targets: [
                    .executableTarget(
                        name: "\(targetName)",
                        path: "Sources/\(targetName)",
                        resources: appResources
                    ),
                    .testTarget(
                        name: "\(targetName)Tests",
                        dependencies: ["\(targetName)"],
                        path: "Tests/\(targetName)Tests"
                    )
                ]
            )
            """

        case .chiefKitEcosystemSPM:
            let externalPackages = spec
                .requiredPackages(for: request.enabledLayers)
                .filter { $0 != .coreLocalAIKit }

            if externalPackages.isEmpty {
                var offlineReq = request
                offlineReq.dependencyStrategy = .standaloneOffline
                return renderPackageSwift(spec: spec, request: offlineReq, targetName: targetName)
            }

            let depEntries = externalPackages
                .map { "        \($0.packageDependencySnippet)" }
                .joined(separator: ",\n")
            let targetProducts = externalPackages
                .map { "                \($0.targetDependencySnippet)" }
                .joined(separator: ",\n")

            return """
            // swift-tools-version: 6.0
            import PackageDescription

            #if os(macOS)
            let appResources: [Resource] = [.process("Resources")]
            #else
            let appResources: [Resource] = [.copy("Resources")]
            #endif

            let package = Package(
                name: "\(targetName)",
                defaultLocalization: "en",
                platforms: [
            \(platformsBody)
                ],
                products: [
                    .executable(name: "\(targetName)", targets: ["\(targetName)"])
                ],
                dependencies: [
            \(depEntries)
                ],
                targets: [
                    .executableTarget(
                        name: "\(targetName)",
                        dependencies: [
            \(targetProducts)
                        ],
                        path: "Sources/\(targetName)",
                        resources: appResources
                    ),
                    .testTarget(
                        name: "\(targetName)Tests",
                        dependencies: ["\(targetName)"],
                        path: "Tests/\(targetName)Tests"
                    )
                ]
            )
            """
        }
    }

    private static func renderGitignore() -> String {
        """
        .DS_Store
        .build/
        .swiftpm/
        DerivedData/
        xcuserdata/
        *.xcworkspace/xcuserdata/
        *.xcodeproj/xcuserdata/
        *.sqlite-shm
        *.sqlite-wal
        """
    }

    private static func renderAppEntryAndThemeSwift(
        spec: EnterpriseBlueprintSpec,
        request: BlueprintExportRequest,
        targetName: String
    ) -> String {
        let tokens = request.theme
        let wcag = tokens.contrastReport
        return """
        import Foundation
        #if canImport(SwiftUI)
        import SwiftUI
        #endif

        // MARK: - \(spec.title) — Exported Design Tokens & Entry Point
        // Bundle ID: \(request.resolvedBundleIdentifier)
        // WCAG Primary/Surface Ratio: \(String(format: "%.2f:1", wcag.primaryOnSurfaceRatio)) (\(wcag.primaryOnSurfaceLevel.rawValue))

        public struct \(targetName)DesignTokens: Codable, Equatable, Sendable {
            public let primaryHex: String
            public let secondaryHex: String
            public let successHex: String
            public let warningHex: String
            public let dangerHex: String
            public let surfaceHex: String
            public let radiusSmall: Double
            public let radiusMedium: Double
            public let radiusLarge: Double
            public let isLiquidGlassEnabled: Bool

            public init(
                primaryHex: String = "\(tokens.primary.hexString)",
                secondaryHex: String = "\(tokens.secondary.hexString)",
                successHex: String = "\(tokens.success.hexString)",
                warningHex: String = "\(tokens.warning.hexString)",
                dangerHex: String = "\(tokens.danger.hexString)",
                surfaceHex: String = "\(tokens.surface.hexString)",
                radiusSmall: Double = \(Int(tokens.radiusSmall.rounded())),
                radiusMedium: Double = \(Int(tokens.radiusMedium.rounded())),
                radiusLarge: Double = \(Int(tokens.radiusLarge.rounded())),
                isLiquidGlassEnabled: Bool = \(tokens.isLiquidGlassEnabled)
            ) {
                self.primaryHex = primaryHex
                self.secondaryHex = secondaryHex
                self.successHex = successHex
                self.warningHex = warningHex
                self.dangerHex = dangerHex
                self.surfaceHex = surfaceHex
                self.radiusSmall = radiusSmall
                self.radiusMedium = radiusMedium
                self.radiusLarge = radiusLarge
                self.isLiquidGlassEnabled = isLiquidGlassEnabled
            }

            public static let active = \(targetName)DesignTokens()
        }

        #if canImport(SwiftUI)
        @main
        struct \(targetName)Application: App {
            var body: some Scene {
                WindowGroup("\(spec.title)") {
                    \(spec.typePrefix)WorkbenchView()
                }
            }
        }
        #else
        @main
        enum \(targetName)HeadlessBootstrap {
            static func main() {
                let state = \(spec.typePrefix)State()
                print("[\(targetName)] Headless Swift 6 verification ready — KPIs: \\(state.kpiSnapshots.count)")
            }
        }
        #endif
        """
    }

    private static func renderStateLayerSwift(
        spec: EnterpriseBlueprintSpec,
        request: BlueprintExportRequest
    ) -> String {
        if request.isLayerEnabled(.swiftStateReducer) {
            return spec.synthesizeReducerAndStore()
        }

        let stateProps = spec.stateProperties.map { prop in
            "    public var \(prop.name): \(prop.swiftType) = \(prop.initialValueLiteral)"
        }.joined(separator: "\n")

        return """
        import Foundation
        import Observation

        // Minimal state container synthesized when .swiftStateReducer layer is toggled off.
        public struct \(spec.typePrefix)State: Codable, Equatable, Sendable {
        \(stateProps)
            public var kpiSnapshots: [WorkbenchKPISnapshot] = WorkbenchKPISnapshot.defaultMetrics
            public var previewRows: [WorkbenchPreviewRow] = WorkbenchPreviewRow.seededRows
            public var hasCompletedOnboarding: Bool = true
            public var isSyncingRemote: Bool = false
            public var lastAuditMessage: String = "Minimal state container active"
            public var mutationCounter: Int = 0

            public init() {}

        \(spec.customStateComputedSwift.indented(by: 4))
        }

        public enum \(spec.typePrefix)Action: Equatable, Sendable {
            case completeOnboarding
        }

        public enum \(spec.typePrefix)Reducer: Sendable {
            @discardableResult
            public static func reduce(
                state: inout \(spec.typePrefix)State,
                action: \(spec.typePrefix)Action
            ) -> \(spec.typePrefix)AuditSeal {
                state.mutationCounter += 1
                switch action {
                case .completeOnboarding:
                    state.hasCompletedOnboarding = true
                }
                return \(spec.typePrefix)AuditSeal(payload: "minimal:\\(state.mutationCounter)")
            }
        }

        @MainActor
        @Observable
        public final class \(spec.typePrefix)Store {
            public private(set) var state = \(spec.typePrefix)State()
            public private(set) var history: [\(spec.typePrefix)State] = []

            public init() {}

            public func send(_ action: \(spec.typePrefix)Action) {
                history.append(state)
                _ = \(spec.typePrefix)Reducer.reduce(state: &state, action: action)
            }

            public func undoLastTransition() {
                guard let prev = history.popLast() else { return }
                state = prev
            }
        }
        """
    }

    private static func renderPersistenceLayerSwift(
        spec: EnterpriseBlueprintSpec,
        request: BlueprintExportRequest
    ) -> String {
        if request.isLayerEnabled(.swiftDataPersistence) {
            return spec.synthesizeSwiftDataModels()
        }

        return """
        import Foundation

        // Ephemeral in-memory repository synthesized when .swiftDataPersistence layer is toggled off.
        public actor \(spec.typePrefix)LocalRepository {
            private var snapshotsByKey: [String: Data] = [:]
            private let encoder = JSONEncoder()
            private let decoder = JSONDecoder()

            public init() {}

            public func save<T: Codable & Sendable>(_ value: T, key: String) throws {
                snapshotsByKey[key] = try encoder.encode(value)
            }

            public func load<T: Codable & Sendable>(_ type: T.Type, key: String) throws -> T? {
                guard let data = snapshotsByKey[key] else { return nil }
                return try decoder.decode(T.self, from: data)
            }
        }
        """
    }

    private static func renderNetworkingLayerSwift(
        spec: EnterpriseBlueprintSpec,
        request: BlueprintExportRequest
    ) -> String {
        if request.isLayerEnabled(.restAPIClient) {
            return spec.synthesizeAPIClient()
        }

        return """
        import Foundation

        // Offline-only loopback stub synthesized when .restAPIClient layer is toggled off.
        public actor \(spec.typePrefix)APIClient {
            public let useOfflinePreviewStubs: Bool = true

            public init() {}
        }
        """
    }

    private static func renderRootWorkbenchViewSwift(
        spec: EnterpriseBlueprintSpec,
        request: BlueprintExportRequest
    ) -> String {
        var effectiveLayers = request.enabledLayers
        if !request.isLayerEnabled(.swiftStateReducer) {
            // Avoid emitting custom reducer action sample buttons when minimal store is selected.
            return """
            #if canImport(SwiftUI)
            import SwiftUI

            public struct \(spec.typePrefix)WorkbenchView: View {
                @State private var store = \(spec.typePrefix)Store()

                public init() {}

                public var body: some View {
                    List(store.state.previewRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.headline).font(.headline)
                            Text(row.subheadline).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("\(spec.title)")
                }
            }
            #endif
            """
        }

        if !effectiveLayers.contains(.swiftBlocksUI) {
            effectiveLayers.append(.swiftBlocksUI)
        }
        let rawView = spec.synthesizeSwiftUIView(theme: request.theme, layers: effectiveLayers)
        return """
        #if canImport(SwiftUI)
        \(rawView)
        #endif
        """
    }

    private static func renderTestsSuiteSwift(
        spec: EnterpriseBlueprintSpec,
        request: BlueprintExportRequest,
        targetName: String
    ) -> String {
        if request.isLayerEnabled(.swiftTestingSuite) && request.isLayerEnabled(.swiftStateReducer) {
            return spec
                .synthesizeSwiftTests()
                .replacingOccurrences(
                    of: "@testable import \(spec.typePrefix)",
                    with: "@testable import \(targetName)"
                )
        }

        return """
        import Foundation
        import Testing
        @testable import \(targetName)

        @Suite("\(spec.title) Smoke Verification")
        struct \(targetName)SmokeTests {
            @Test("Design tokens and seeded domain rows initialize cleanly")
            func smokeTokensAndRows() {
                let tokens = \(targetName)DesignTokens.active
                #expect(tokens.primaryHex.hasPrefix("#"))
                #expect(WorkbenchPreviewRow.seededRows.isEmpty == false)
            }
        }
        """
    }

    private static func renderReadmeMarkdown(
        spec: EnterpriseBlueprintSpec,
        request: BlueprintExportRequest,
        targetName: String,
        bundleID: String
    ) -> String {
        let platformBadges = request.targetPlatforms.map { "`\($0.displayName)`" }.joined(separator: " · ")
        let layerLines = request.enabledLayers.map { "- **\($0.title)** — \($0.subtitle)" }.joined(separator: "\n")
        let entityLines = spec.domainEntities.map { "- `\($0.name)` (`\($0.tableName)`) — \($0.summary)" }.joined(separator: "\n")
        let endpointLines = spec.apiEndpoints.map { "- `\($0.method.rawValue) \($0.path)` -> `\($0.responseType)` — \($0.summary)" }.joined(separator: "\n")
        let securityLines = spec.securityPostureHighlights.map { "- \($0)" }.joined(separator: "\n")
        let complianceList = spec.vertical.complianceStandards.joined(separator: " · ")

        return """
        # \(spec.title) (`\(targetName)`)

        > \(spec.subtitle)

        Generated by **ChiefKit Studio 3.0 Enterprise Blueprints** (`\(spec.id.rawValue)`).

        - **Industry Vertical**: \(spec.vertical.title) / *\(spec.vertical.turkishTitle)*
        - **Complexity Tier**: `\(spec.complexityTier.rawValue)`
        - **Bundle Identifier**: `\(bundleID)`
        - **Target Platforms**: \(platformBadges)
        - **Standards Alignment**: \(complianceList)
        - **Primary Theme Hex**: `\(request.theme.primary.hexString)` (Liquid Glass: `\(request.theme.isLiquidGlassEnabled)`)

        ## Build & Verify

        ```bash
        swift build
        swift test
        ```

        Open `Package.swift` directly in Xcode 16+ to run on Apple platforms.

        ## 14-File Swift 6 Package Structure

        - `Package.swift` — Swift 6.0 strict-concurrency manifest
        - `README.md` — Architecture & operations documentation
        - `.gitignore` — Build & SQLite WAL ignore rules
        - `Sources/\(targetName)/\(targetName)App.swift` — `@main` app entry point & design token constants
        - `Sources/\(targetName)/Models/DomainModels.swift` — `Sendable` domain structs & computed domain math
        - `Sources/\(targetName)/State/AppReducer.swift` — Deterministic reducer, `@Observable` store & undo history
        - `Sources/\(targetName)/Persistence/PersistenceSchema.swift` — SwiftData `@Model` classes & SQLite WAL DDL
        - `Sources/\(targetName)/Networking/APIClient.swift` — `Sendable` `URLSession` actor with offline preview stubs
        - `Sources/\(targetName)/Views/RootWorkbenchView.swift` — Tokenized SwiftUI workbench & on-device copilot
        - `Sources/\(targetName)/Resources/onboarding-flow.json` — Validated NotebookFlowKit onboarding topology
        - `Sources/\(targetName)/Resources/design-tokens.w3c.json` — Portable W3C Design Tokens JSON
        - `Sources/\(targetName)/Resources/PrivacyInfo.xcprivacy` — App Store privacy manifest (`NSPrivacyTracking = false`)
        - `Sources/\(targetName)/Resources/Localizable.xcstrings` — Bilingual English (`en`) + Turkish (`tr`) String Catalog
        - `Tests/\(targetName)Tests/\(targetName)Tests.swift` — Swift Testing (`@Suite` / `@Test`) verification suite

        ## Enabled Architectural Layers

        \(layerLines)

        ## Domain Entities & Persistence Tables

        \(entityLines)

        ## Typed REST API Endpoints

        \(endpointLines)

        ## Security & Privacy Posture

        \(securityLines)

        ## Architecture Topology

        ```mermaid
        \(spec.synthesizeMermaidArchitecture())
        ```
        """
    }
}
