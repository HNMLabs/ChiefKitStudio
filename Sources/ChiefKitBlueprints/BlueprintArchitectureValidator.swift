import ChiefKitStudioCore
import Foundation

// MARK: - Validation Severity, Categories & Diagnostics

public enum BlueprintValidationSeverity: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case error
    case warning
    case info
}

public enum BlueprintValidationCategory: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case catalogCoverage
    case domainSchema
    case stateReducer
    case networkingAPI
    case onboardingFlow
    case swiftSyntaxBalance
    case testSuiteCoverage
    case localizationTR_EN
    case privacySecurity
    case workspaceExportLayout
}

public struct BlueprintValidationIssue: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let blueprintID: EnterpriseBlueprintID?
    public let severity: BlueprintValidationSeverity
    public let category: BlueprintValidationCategory
    public let artifactName: String
    public let message: String

    public init(
        id: String,
        blueprintID: EnterpriseBlueprintID?,
        severity: BlueprintValidationSeverity,
        category: BlueprintValidationCategory,
        artifactName: String,
        message: String
    ) {
        self.id = id
        self.blueprintID = blueprintID
        self.severity = severity
        self.category = category
        self.artifactName = artifactName
        self.message = message
    }
}

/// Lexical delimiter balance audit result for a synthesized Swift 6 source file.
public struct SwiftDelimiterBalanceResult: Codable, Equatable, Hashable, Sendable {
    public let curlyDelta: Int
    public let parenDelta: Int
    public let bracketDelta: Int
    public let hasNegativeNesting: Bool
    public let hasUnterminatedLiteralOrComment: Bool
    public let firstAnomalyLine: Int?

    public init(
        curlyDelta: Int,
        parenDelta: Int,
        bracketDelta: Int,
        hasNegativeNesting: Bool,
        hasUnterminatedLiteralOrComment: Bool,
        firstAnomalyLine: Int?
    ) {
        self.curlyDelta = curlyDelta
        self.parenDelta = parenDelta
        self.bracketDelta = bracketDelta
        self.hasNegativeNesting = hasNegativeNesting
        self.hasUnterminatedLiteralOrComment = hasUnterminatedLiteralOrComment
        self.firstAnomalyLine = firstAnomalyLine
    }

    public var isBalanced: Bool {
        curlyDelta == 0 &&
        parenDelta == 0 &&
        bracketDelta == 0 &&
        !hasNegativeNesting &&
        !hasUnterminatedLiteralOrComment
    }
}

// MARK: - Per-Blueprint & Full-Catalog Validation Reports

public struct BlueprintSpecValidationReport: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: EnterpriseBlueprintID { blueprintID }
    public let blueprintID: EnterpriseBlueprintID
    public let title: String
    public let vertical: EnterpriseVertical
    public let entityCount: Int
    public let statePropertyCount: Int
    public let reducerActionCount: Int
    public let endpointCount: Int
    public let onboardingPageCount: Int
    public let localizedKeyCount: Int
    public let detectedTestCount: Int
    public let exportedFileCount: Int
    public let synthesizedSwiftLineCount: Int
    public let issues: [BlueprintValidationIssue]

    public init(
        blueprintID: EnterpriseBlueprintID,
        title: String,
        vertical: EnterpriseVertical,
        entityCount: Int,
        statePropertyCount: Int,
        reducerActionCount: Int,
        endpointCount: Int,
        onboardingPageCount: Int,
        localizedKeyCount: Int,
        detectedTestCount: Int,
        exportedFileCount: Int,
        synthesizedSwiftLineCount: Int,
        issues: [BlueprintValidationIssue]
    ) {
        self.blueprintID = blueprintID
        self.title = title
        self.vertical = vertical
        self.entityCount = entityCount
        self.statePropertyCount = statePropertyCount
        self.reducerActionCount = reducerActionCount
        self.endpointCount = endpointCount
        self.onboardingPageCount = onboardingPageCount
        self.localizedKeyCount = localizedKeyCount
        self.detectedTestCount = detectedTestCount
        self.exportedFileCount = exportedFileCount
        self.synthesizedSwiftLineCount = synthesizedSwiftLineCount
        self.issues = issues
    }

    public var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    public var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    public var isValid: Bool {
        errorCount == 0
    }
}

public struct BlueprintCatalogValidationReport: Codable, Equatable, Sendable {
    public let expectedBlueprintCount: Int
    public let auditedBlueprintCount: Int
    public let verticalCount: Int
    public let reports: [BlueprintSpecValidationReport]
    public let catalogIssues: [BlueprintValidationIssue]

    public init(
        expectedBlueprintCount: Int = EnterpriseBlueprintID.allCases.count,
        auditedBlueprintCount: Int,
        verticalCount: Int = EnterpriseVertical.allCases.count,
        reports: [BlueprintSpecValidationReport],
        catalogIssues: [BlueprintValidationIssue]
    ) {
        self.expectedBlueprintCount = expectedBlueprintCount
        self.auditedBlueprintCount = auditedBlueprintCount
        self.verticalCount = verticalCount
        self.reports = reports
        self.catalogIssues = catalogIssues
    }

    public var totalErrors: Int {
        let catalogErrs = catalogIssues.filter { $0.severity == .error }.count
        return catalogErrs + reports.reduce(0) { $0 + $1.errorCount }
    }

    public var totalWarnings: Int {
        let catalogWarns = catalogIssues.filter { $0.severity == .warning }.count
        return catalogWarns + reports.reduce(0) { $0 + $1.warningCount }
    }

    public var totalSynthesizedSwiftLines: Int {
        reports.reduce(0) { $0 + $1.synthesizedSwiftLineCount }
    }

    public var totalDetectedTests: Int {
        reports.reduce(0) { $0 + $1.detectedTestCount }
    }

    public var isValid: Bool {
        totalErrors == 0 && auditedBlueprintCount == expectedBlueprintCount
    }

    public func report(for id: EnterpriseBlueprintID) -> BlueprintSpecValidationReport? {
        reports.first { $0.blueprintID == id }
    }

    /// Formats a concise GitHub-flavored Markdown audit report for CI logs or ChiefKit Studio UI.
    public func formattedMarkdownSummary() -> String {
        let headerStatus = isValid ? "PASS (0 Errors)" : "FAIL (\(totalErrors) Errors)"
        let rows = reports.map { rep in
            let badge = rep.isValid ? "PASS" : "FAIL (\(rep.errorCount))"
            return "| `\(rep.blueprintID.rawValue)` | \(rep.vertical.title) | \(rep.entityCount) | \(rep.reducerActionCount) | \(rep.endpointCount) | \(rep.detectedTestCount) | \(rep.localizedKeyCount) | \(badge) |"
        }.joined(separator: "\n")

        return """
        # ChiefKit 3.0 Enterprise Blueprints — Architecture Audit

        - **Status**: **\(headerStatus)**
        - **Blueprints Audited**: \(auditedBlueprintCount) / \(expectedBlueprintCount) across \(verticalCount) verticals
        - **Warnings**: \(totalWarnings)
        - **Total Synthesized Swift Lines**: \(totalSynthesizedSwiftLines)
        - **Total `@Test` Assertions Verified**: \(totalDetectedTests)

        | Blueprint ID | Vertical | Entities | Actions | Endpoints | `@Test`s | TR/EN Keys | Result |
        | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
        \(rows)
        """
    }
}

// MARK: - Enterprise Blueprint Architecture Validator

/// Static architecture, syntax, onboarding topology, localization, and test-coverage auditor for all 28 blueprints.
public enum BlueprintArchitectureValidator: Sendable {
    /// Required action verbs on the terminal onboarding page of every blueprint.
    public static let terminalActionKeywords: [String] = [
        "Finish",
        "Complete",
        "Start",
        "Launch"
    ]

    /// Audits all 28 registered `EnterpriseBlueprintSpec` blueprints and catalog-wide invariants.
    public static func validateAll(
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> BlueprintCatalogValidationReport {
        let specs = EnterpriseBlueprintCatalog.allSpecs
        var catalogIssues: [BlueprintValidationIssue] = []

        // 1. Verify exact 1-to-1 coverage of all 28 EnterpriseBlueprintID cases.
        let registeredIDs = Set(specs.map(\.id))
        for expectedID in EnterpriseBlueprintID.allCases where !registeredIDs.contains(expectedID) {
            catalogIssues.append(
                BlueprintValidationIssue(
                    id: "missing-spec-\(expectedID.rawValue)",
                    blueprintID: expectedID,
                    severity: .error,
                    category: .catalogCoverage,
                    artifactName: "EnterpriseBlueprintCatalog",
                    message: "Missing blueprint specification for EnterpriseBlueprintID.\(expectedID.rawValue)."
                )
            )
        }

        if specs.count != EnterpriseBlueprintID.allCases.count {
            catalogIssues.append(
                BlueprintValidationIssue(
                    id: "duplicate-or-missing-count",
                    blueprintID: nil,
                    severity: .error,
                    category: .catalogCoverage,
                    artifactName: "EnterpriseBlueprintCatalog",
                    message: "Expected \(EnterpriseBlueprintID.allCases.count) specs, found \(specs.count)."
                )
            )
        }

        // 2. Verify unique defaultAppTargetName and defaultBundleIdentifier across all 28 blueprints.
        var seenTargets = Set<String>()
        var seenBundles = Set<String>()
        for spec in specs {
            let target = spec.id.defaultAppTargetName
            if !seenTargets.insert(target).inserted {
                catalogIssues.append(
                    BlueprintValidationIssue(
                        id: "dup-target-\(target)",
                        blueprintID: spec.id,
                        severity: .error,
                        category: .catalogCoverage,
                        artifactName: "EnterpriseBlueprintID.defaultAppTargetName",
                        message: "Duplicate defaultAppTargetName '\(target)' detected."
                    )
                )
            }
            let bundle = spec.id.defaultBundleIdentifier
            if !seenBundles.insert(bundle).inserted {
                catalogIssues.append(
                    BlueprintValidationIssue(
                        id: "dup-bundle-\(bundle)",
                        blueprintID: spec.id,
                        severity: .error,
                        category: .catalogCoverage,
                        artifactName: "EnterpriseBlueprintID.defaultBundleIdentifier",
                        message: "Duplicate defaultBundleIdentifier '\(bundle)' detected."
                    )
                )
            }
        }

        // 3. Verify every vertical has at least 3 blueprints.
        for vertical in EnterpriseVertical.allCases {
            let count = specs.filter { $0.vertical == vertical }.count
            if count < 3 {
                catalogIssues.append(
                    BlueprintValidationIssue(
                        id: "vertical-underpopulated-\(vertical.rawValue)",
                        blueprintID: nil,
                        severity: .error,
                        category: .catalogCoverage,
                        artifactName: vertical.rawValue,
                        message: "Vertical '\(vertical.title)' has \(count) blueprints; expected at least 3."
                    )
                )
            }
        }

        let perSpecReports = specs.map { validate($0, theme: theme) }
        return BlueprintCatalogValidationReport(
            expectedBlueprintCount: EnterpriseBlueprintID.allCases.count,
            auditedBlueprintCount: specs.count,
            verticalCount: EnterpriseVertical.allCases.count,
            reports: perSpecReports,
            catalogIssues: catalogIssues
        )
    }

    /// Audits a blueprint looked up by `EnterpriseBlueprintID`.
    public static func validate(
        id: EnterpriseBlueprintID,
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> BlueprintSpecValidationReport {
        validate(EnterpriseBlueprintCatalog.spec(for: id), theme: theme)
    }

    /// Runs deep multi-layer validation against a single `EnterpriseBlueprintSpec`.
    public static func validate(
        _ spec: EnterpriseBlueprintSpec,
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> BlueprintSpecValidationReport {
        var issues: [BlueprintValidationIssue] = []

        // 1. Vertical consistency & non-empty metadata
        if spec.id.vertical != spec.vertical {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-vertical-mismatch",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .catalogCoverage,
                    artifactName: "EnterpriseBlueprintSpec.vertical",
                    message: "Spec vertical '\(spec.vertical.rawValue)' mismatches ID vertical '\(spec.id.vertical.rawValue)'."
                )
            )
        }

        if spec.supportedPlatforms.isEmpty {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-empty-platforms",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .catalogCoverage,
                    artifactName: "supportedPlatforms",
                    message: "Blueprint declares zero supported Apple platforms."
                )
            )
        }

        // 2. Domain Entities & SQLite Schema Checks
        if spec.domainEntities.isEmpty {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-no-entities",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .domainSchema,
                    artifactName: "domainEntities",
                    message: "Blueprint must define at least one domain entity."
                )
            )
        }

        var entityNames = Set<String>()
        for entity in spec.domainEntities {
            if !entityNames.insert(entity.name).inserted {
                issues.append(
                    BlueprintValidationIssue(
                        id: "\(spec.id.rawValue)-dup-entity-\(entity.name)",
                        blueprintID: spec.id,
                        severity: .error,
                        category: .domainSchema,
                        artifactName: entity.name,
                        message: "Duplicate domain entity '\(entity.name)'."
                    )
                )
            }
            if entity.fields.isEmpty || !entity.fields.contains(where: { $0.name == "id" }) {
                issues.append(
                    BlueprintValidationIssue(
                        id: "\(spec.id.rawValue)-entity-missing-id-\(entity.name)",
                        blueprintID: spec.id,
                        severity: .error,
                        category: .domainSchema,
                        artifactName: entity.name,
                        message: "Domain entity '\(entity.name)' must include an 'id' primary key field."
                    )
                )
            }
            if entity.computedHelpersSwift.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(
                    BlueprintValidationIssue(
                        id: "\(spec.id.rawValue)-entity-empty-helpers-\(entity.name)",
                        blueprintID: spec.id,
                        severity: .warning,
                        category: .domainSchema,
                        artifactName: entity.name,
                        message: "Domain entity '\(entity.name)' has no domain-specific computed helpers."
                    )
                )
            }
        }

        // 3. State Properties & Reducer Actions
        if spec.stateProperties.isEmpty {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-no-state-props",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .stateReducer,
                    artifactName: "stateProperties",
                    message: "Blueprint must define domain-specific state properties."
                )
            )
        }

        if spec.reducerActions.isEmpty {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-no-actions",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .stateReducer,
                    artifactName: "reducerActions",
                    message: "Blueprint must define domain-specific reducer actions."
                )
            )
        }

        for action in spec.reducerActions where action.mutationBodySwift.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-empty-reducer-body-\(action.caseDeclaration)",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .stateReducer,
                    artifactName: "AppReducer.swift",
                    message: "Reducer action '\(action.caseDeclaration)' has an empty mutation body."
                )
            )
        }

        // 4. REST API Endpoints & KPIs
        if spec.apiEndpoints.isEmpty {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-no-endpoints",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .networkingAPI,
                    artifactName: "APIClient.swift",
                    message: "Blueprint must define at least one typed REST API endpoint."
                )
            )
        }

        for endpoint in spec.apiEndpoints where !endpoint.path.hasPrefix("/") {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-bad-endpoint-path-\(endpoint.methodName)",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .networkingAPI,
                    artifactName: "APIClient.swift",
                    message: "Endpoint '\(endpoint.methodName)' path '\(endpoint.path)' must begin with '/'."
                )
            )
        }

        // 5. Onboarding FlowDefinition JSON Decoding & Validation
        let flowJSON = spec.synthesizeOnboardingFlowJSON()
        switch FlowDefinition.decode(flowJSON) {
        case .failure(let error):
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-flow-decode-failed",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .onboardingFlow,
                    artifactName: "onboarding-flow.json",
                    message: "FlowDefinition.decode failed: \(error.localizedDescription)"
                )
            )
        case .success(let decodedFlow):
            let diagnostics = decodedFlow.validate()
            for diag in diagnostics where diag.severity == .error || diag.severity == .warning {
                let mappedSeverity: BlueprintValidationSeverity = (diag.severity == .error) ? .error : .warning
                issues.append(
                    BlueprintValidationIssue(
                        id: "\(spec.id.rawValue)-flow-\(diag.id)",
                        blueprintID: spec.id,
                        severity: mappedSeverity,
                        category: .onboardingFlow,
                        artifactName: "onboarding-flow.json",
                        message: diag.message
                    )
                )
            }

            if let lastPage = decodedFlow.pages.last {
                let matchesTerminalVerb = lastPage.actions.contains { actionLabel in
                    terminalActionKeywords.contains { keyword in
                        actionLabel.localizedCaseInsensitiveContains(keyword)
                    }
                }
                if !matchesTerminalVerb {
                    issues.append(
                        BlueprintValidationIssue(
                            id: "\(spec.id.rawValue)-flow-terminal-verb",
                            blueprintID: spec.id,
                            severity: .error,
                            category: .onboardingFlow,
                            artifactName: "onboarding-flow.json",
                            message: "Final onboarding page '\(lastPage.id)' actions \(lastPage.actions) must include Finish, Complete, Start, or Launch."
                        )
                    )
                }
            }
        }

        // 6. Bilingual TR / EN Localization Audit + Valid JSON Catalog
        if spec.localizationKeysTR_EN.count < 4 {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-few-l10n-keys",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .localizationTR_EN,
                    artifactName: "Localizable.xcstrings",
                    message: "Expected at least 4 bilingual TR/EN localization keys, found \(spec.localizationKeysTR_EN.count)."
                )
            )
        }

        var seenLocalizationKeys = Set<String>()
        for pair in spec.localizationKeysTR_EN {
            if !seenLocalizationKeys.insert(pair.key).inserted {
                issues.append(
                    BlueprintValidationIssue(
                        id: "\(spec.id.rawValue)-dup-l10n-\(pair.key)",
                        blueprintID: spec.id,
                        severity: .error,
                        category: .localizationTR_EN,
                        artifactName: "Localizable.xcstrings",
                        message: "Duplicate localization key '\(pair.key)'."
                    )
                )
            }
            if pair.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                pair.tr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(
                    BlueprintValidationIssue(
                        id: "\(spec.id.rawValue)-blank-l10n-\(pair.key)",
                        blueprintID: spec.id,
                        severity: .error,
                        category: .localizationTR_EN,
                        artifactName: "Localizable.xcstrings",
                        message: "Localization key '\(pair.key)' has blank English or Turkish translation."
                    )
                )
            }
        }

        let xcstringsData = Data(spec.synthesizeLocalizableStringsCatalogJSON().utf8)
        if (try? JSONSerialization.jsonObject(with: xcstringsData)) == nil {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-invalid-xcstrings-json",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .localizationTR_EN,
                    artifactName: "Localizable.xcstrings",
                    message: "Synthesized Localizable.xcstrings is not valid JSON."
                )
            )
        }

        // 7. Privacy Manifest Audit
        if spec.privacyAPICategories.isEmpty {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-missing-privacy-categories",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .privacySecurity,
                    artifactName: "PrivacyInfo.xcprivacy",
                    message: "Blueprint must declare Apple required-reason privacy API categories."
                )
            )
        }

        // 8. Full 14-File Workspace Generation & Balanced Delimiter Audit across ALL Swift files
        let workspace = BlueprintWorkspaceExporter.generateWorkspace(
            for: spec.id,
            theme: theme,
            layers: EnterpriseLayerKind.allCases
        )

        if workspace.files.count != BlueprintWorkspaceExporter.canonicalFileCount {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-file-count",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .workspaceExportLayout,
                    artifactName: "BlueprintWorkspaceExporter",
                    message: "Expected \(BlueprintWorkspaceExporter.canonicalFileCount) files, generated \(workspace.files.count)."
                )
            )
        }

        var synthesizedSwiftLines = 0
        for swiftFile in workspace.swiftSourceFiles {
            synthesizedSwiftLines += swiftFile.lineCount
            let balance = auditSwiftDelimiterBalance(in: swiftFile.content)
            if !balance.isBalanced {
                let lineInfo = balance.firstAnomalyLine.map { " near line \($0)" } ?? ""
                issues.append(
                    BlueprintValidationIssue(
                        id: "\(spec.id.rawValue)-unbalanced-\(swiftFile.fileName)",
                        blueprintID: spec.id,
                        severity: .error,
                        category: .swiftSyntaxBalance,
                        artifactName: swiftFile.relativePath,
                        message: "Unbalanced Swift delimiters\(lineInfo) (curly: \(balance.curlyDelta), paren: \(balance.parenDelta), bracket: \(balance.bracketDelta))."
                    )
                )
            }
        }

        // Also verify unified preview syntax balance
        let unifiedPreview = spec.synthesizeUnifiedPreview(theme: theme, layers: EnterpriseLayerKind.allCases)
        let unifiedBalance = auditSwiftDelimiterBalance(in: unifiedPreview)
        if !unifiedBalance.isBalanced {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-unbalanced-unified-preview",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .swiftSyntaxBalance,
                    artifactName: "UnifiedPreview.swift",
                    message: "Unified preview has unbalanced Swift delimiters."
                )
            )
        }

        // 9. @Test Coverage Presence Audit
        let testsCode = spec.synthesizeSwiftTests()
        let detectedTests = countSwiftTestingMacros(in: testsCode)
        if !testsCode.contains("@Suite") || detectedTests < 4 || !testsCode.contains("#expect(") {
            issues.append(
                BlueprintValidationIssue(
                    id: "\(spec.id.rawValue)-insufficient-tests",
                    blueprintID: spec.id,
                    severity: .error,
                    category: .testSuiteCoverage,
                    artifactName: "Tests/\(spec.typePrefix)Tests.swift",
                    message: "Expected @Suite, #expect(...), and >= 4 @Test functions (found \(detectedTests))."
                )
            )
        }

        return BlueprintSpecValidationReport(
            blueprintID: spec.id,
            title: spec.title,
            vertical: spec.vertical,
            entityCount: spec.domainEntities.count,
            statePropertyCount: spec.stateProperties.count,
            reducerActionCount: spec.reducerActions.count,
            endpointCount: spec.apiEndpoints.count,
            onboardingPageCount: spec.onboardingPages.count,
            localizedKeyCount: spec.localizationKeysTR_EN.count,
            detectedTestCount: detectedTests,
            exportedFileCount: workspace.files.count,
            synthesizedSwiftLineCount: synthesizedSwiftLines,
            issues: issues
        )
    }

    // MARK: - Lexical Swift Delimiter Balance Scanner

    /// Audits `{}` / `()` / `[]` balance across Swift source while respecting comments, strings, and `\(...)` interpolations.
    public static func auditSwiftDelimiterBalance(in source: String) -> SwiftDelimiterBalanceResult {
        enum LexMode {
            case code
            case lineComment
            case blockComment(depth: Int)
            case singleLineString
            case multilineString
            case interpolation(parenDepth: Int)
        }

        let chars = Array(source)
        let n = chars.count
        var i = 0
        var line = 1

        var curly = 0
        var paren = 0
        var bracket = 0
        var hasNegative = false
        var hasUnterminatedSingleLine = false
        var firstAnomaly: Int?
        var modeStack: [LexMode] = [.code]

        func recordNegativeIfNeeded() {
            if curly < 0 || paren < 0 || bracket < 0 {
                hasNegative = true
                if firstAnomaly == nil {
                    firstAnomaly = line
                }
            }
        }

        while i < n {
            let ch = chars[i]
            if ch == "\n" {
                line += 1
            }

            let currentMode = modeStack[modeStack.count - 1]
            switch currentMode {
            case .code:
                if ch == "/" && i + 1 < n && chars[i + 1] == "/" {
                    modeStack.append(.lineComment)
                    i += 2
                    continue
                }
                if ch == "/" && i + 1 < n && chars[i + 1] == "*" {
                    modeStack.append(.blockComment(depth: 1))
                    i += 2
                    continue
                }
                if ch == "\"" && i + 2 < n && chars[i + 1] == "\"" && chars[i + 2] == "\"" {
                    modeStack.append(.multilineString)
                    i += 3
                    continue
                }
                if ch == "\"" {
                    modeStack.append(.singleLineString)
                    i += 1
                    continue
                }
                switch ch {
                case "{": curly += 1
                case "}": curly -= 1; recordNegativeIfNeeded()
                case "(": paren += 1
                case ")": paren -= 1; recordNegativeIfNeeded()
                case "[": bracket += 1
                case "]": bracket -= 1; recordNegativeIfNeeded()
                default: break
                }
                i += 1

            case .lineComment:
                if ch == "\n" {
                    _ = modeStack.popLast()
                }
                i += 1

            case .blockComment(let depth):
                if ch == "/" && i + 1 < n && chars[i + 1] == "*" {
                    modeStack[modeStack.count - 1] = .blockComment(depth: depth + 1)
                    i += 2
                    continue
                }
                if ch == "*" && i + 1 < n && chars[i + 1] == "/" {
                    if depth <= 1 {
                        _ = modeStack.popLast()
                    } else {
                        modeStack[modeStack.count - 1] = .blockComment(depth: depth - 1)
                    }
                    i += 2
                    continue
                }
                i += 1

            case .singleLineString:
                if ch == "\\" && i + 1 < n {
                    if chars[i + 1] == "(" {
                        modeStack.append(.interpolation(parenDepth: 1))
                        paren += 1
                        i += 2
                        continue
                    }
                    i += 2
                    continue
                }
                if ch == "\"" {
                    _ = modeStack.popLast()
                } else if ch == "\n" {
                    hasUnterminatedSingleLine = true
                    if firstAnomaly == nil { firstAnomaly = line - 1 }
                    _ = modeStack.popLast()
                }
                i += 1

            case .multilineString:
                if ch == "\\" && i + 1 < n {
                    if chars[i + 1] == "(" {
                        modeStack.append(.interpolation(parenDepth: 1))
                        paren += 1
                        i += 2
                        continue
                    }
                    i += 2
                    continue
                }
                if ch == "\"" && i + 2 < n && chars[i + 1] == "\"" && chars[i + 2] == "\"" {
                    _ = modeStack.popLast()
                    i += 3
                    continue
                }
                i += 1

            case .interpolation(let interpDepth):
                if ch == "/" && i + 1 < n && chars[i + 1] == "/" {
                    modeStack.append(.lineComment)
                    i += 2
                    continue
                }
                if ch == "/" && i + 1 < n && chars[i + 1] == "*" {
                    modeStack.append(.blockComment(depth: 1))
                    i += 2
                    continue
                }
                if ch == "\"" && i + 2 < n && chars[i + 1] == "\"" && chars[i + 2] == "\"" {
                    modeStack.append(.multilineString)
                    i += 3
                    continue
                }
                if ch == "\"" {
                    modeStack.append(.singleLineString)
                    i += 1
                    continue
                }
                switch ch {
                case "{": curly += 1
                case "}": curly -= 1; recordNegativeIfNeeded()
                case "[": bracket += 1
                case "]": bracket -= 1; recordNegativeIfNeeded()
                case "(":
                    paren += 1
                    modeStack[modeStack.count - 1] = .interpolation(parenDepth: interpDepth + 1)
                case ")":
                    paren -= 1
                    recordNegativeIfNeeded()
                    if interpDepth <= 1 {
                        _ = modeStack.popLast()
                    } else {
                        modeStack[modeStack.count - 1] = .interpolation(parenDepth: interpDepth - 1)
                    }
                default:
                    break
                }
                i += 1
            }
        }

        let endedCleanly: Bool
        if modeStack.count == 1, case .code = modeStack[0] {
            endedCleanly = true
        } else if modeStack.count == 2, case .code = modeStack[0], case .lineComment = modeStack[1] {
            endedCleanly = true
        } else {
            endedCleanly = false
        }

        let hasLiteralAnomaly = !endedCleanly || hasUnterminatedSingleLine
        if (hasLiteralAnomaly || curly != 0 || paren != 0 || bracket != 0) && firstAnomaly == nil {
            firstAnomaly = line
        }

        return SwiftDelimiterBalanceResult(
            curlyDelta: curly,
            parenDelta: paren,
            bracketDelta: bracket,
            hasNegativeNesting: hasNegative,
            hasUnterminatedLiteralOrComment: hasLiteralAnomaly,
            firstAnomalyLine: firstAnomaly
        )
    }

    private static func countSwiftTestingMacros(in source: String) -> Int {
        source
            .components(separatedBy: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("@Test")
            }
            .count
    }
}
