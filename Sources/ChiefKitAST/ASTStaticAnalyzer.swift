#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Audit Categories, Severities & 38 Rule Identifiers

/// High-level engineering quality pillar for static AST diagnostics.
public enum ASTAuditCategory: String, Codable, Hashable, CaseIterable, Sendable {
    case concurrency = "Swift 6 Concurrency"
    case accessibility = "Accessibility & VoiceOver"
    case designTokens = "EDK Design Tokens"
    case performance = "SwiftUI Performance"
    case safetyAndState = "Architecture & Safety"
}

/// Severity level of a static AST diagnostic.
public enum ASTDiagnosticSeverity: String, Codable, Hashable, Comparable, CaseIterable, Sendable {
    case info
    case warning
    case error

    private var rank: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        }
    }

    public static func < (lhs: ASTDiagnosticSeverity, rhs: ASTDiagnosticSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Complete catalog of 38 static lint, accessibility, design-token, performance, and Swift 6 concurrency rules.
public enum ASTAuditRuleID: String, Codable, Hashable, CaseIterable, Sendable {
    // Swift 6 Concurrency (8 rules)
    case missingSendableOnPublicValueType = "CK-CONC-001"
    case classMissingActorIsolationOrFinalSendable = "CK-CONC-002"
    case uncheckedSendableConformance = "CK-CONC-003"
    case legacyDispatchQueueMainAsync = "CK-CONC-004"
    case detachedTaskLosesIsolation = "CK-CONC-005"
    case mutableStaticSharedState = "CK-CONC-006"
    case nonisolatedUnsafeUsage = "CK-CONC-007"
    case asyncViewTaskMissingCancellationCheck = "CK-CONC-008"

    // Accessibility & Dynamic Type (9 rules)
    case buttonMissingAccessibilityLabel = "CK-A11Y-001"
    case toggleMissingAccessibilityLabel = "CK-A11Y-002"
    case textFieldMissingAccessibilityLabel = "CK-A11Y-003"
    case imageMissingAccessibilityAnnotation = "CK-A11Y-004"
    case fixedFontSizeBlocksDynamicType = "CK-A11Y-005"
    case smallInteractiveHitTarget = "CK-A11Y-006"
    case headingMissingHeaderTrait = "CK-A11Y-007"
    case tapGestureMissingButtonTrait = "CK-A11Y-008"
    case lowThemePrimaryContrast = "CK-A11Y-009"

    // Design System & EDK Tokens (6 rules)
    case hardcodedPaddingLiteral = "CK-TOKN-001"
    case hardcodedCornerRadiusLiteral = "CK-TOKN-002"
    case rawColorInitializerOrHex = "CK-TOKN-003"
    case hardcodedStackSpacingLiteral = "CK-TOKN-004"
    case deprecatedCornerRadiusModifier = "CK-TOKN-005"
    case rawMaterialInsteadOfLiquidGlass = "CK-TOKN-006"

    // SwiftUI Rendering Performance (7 rules)
    case anyViewTypeErasure = "CK-PERF-001"
    case geometryReaderInsideScrollContainer = "CK-PERF-002"
    case deepViewHierarchyNesting = "CK-PERF-003"
    case eagerStackWithForEachInScrollView = "CK-PERF-004"
    case unstableForEachIdentitySelf = "CK-PERF-005"
    case heavyFormatterAllocatedInViewBody = "CK-PERF-006"
    case excessiveModifierChainOnSingleView = "CK-PERF-007"

    // State Architecture & Runtime Safety (8 rules)
    case legacyObservableObjectPattern = "CK-SAFE-001"
    case forceUnwrapOperator = "CK-SAFE-002"
    case forceTryTrapHazard = "CK-SAFE-003"
    case forceCastTrapHazard = "CK-SAFE-004"
    case emptyCatchBlock = "CK-SAFE-005"
    case stateMutationInsideViewBody = "CK-SAFE-006"
    case publicMutableStateWrapper = "CK-SAFE-007"
    case excessiveLocalStateInView = "CK-SAFE-008"

    public var category: ASTAuditCategory {
        if rawValue.hasPrefix("CK-CONC-") { return .concurrency }
        if rawValue.hasPrefix("CK-A11Y-") { return .accessibility }
        if rawValue.hasPrefix("CK-TOKN-") { return .designTokens }
        if rawValue.hasPrefix("CK-PERF-") { return .performance }
        return .safetyAndState
    }

    public var defaultSeverity: ASTDiagnosticSeverity {
        switch self {
        case .stateMutationInsideViewBody, .forceTryTrapHazard, .geometryReaderInsideScrollContainer,
             .mutableStaticSharedState, .emptyCatchBlock:
            return .error
        case .missingSendableOnPublicValueType, .classMissingActorIsolationOrFinalSendable,
             .uncheckedSendableConformance, .legacyDispatchQueueMainAsync, .detachedTaskLosesIsolation,
             .nonisolatedUnsafeUsage, .buttonMissingAccessibilityLabel, .toggleMissingAccessibilityLabel,
             .textFieldMissingAccessibilityLabel, .imageMissingAccessibilityAnnotation,
             .fixedFontSizeBlocksDynamicType, .smallInteractiveHitTarget, .tapGestureMissingButtonTrait,
             .lowThemePrimaryContrast, .rawColorInitializerOrHex, .anyViewTypeErasure,
             .deepViewHierarchyNesting, .eagerStackWithForEachInScrollView,
             .heavyFormatterAllocatedInViewBody, .legacyObservableObjectPattern,
             .forceUnwrapOperator, .forceCastTrapHazard, .publicMutableStateWrapper:
            return .warning
        default:
            return .info
        }
    }
}

// MARK: - Diagnostic & Audit Report Models

/// Actionable static analysis diagnostic pinpointing an AST construct, rule ID, and automated fix suggestion.
public struct ASTDiagnostic: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let ruleID: ASTAuditRuleID
    public let category: ASTAuditCategory
    public let severity: ASTDiagnosticSeverity
    public let title: String
    public let message: String
    public let remediation: String
    public let symbolName: String?
    public let span: SourceSpan

    public init(
        id: UUID = UUID(),
        ruleID: ASTAuditRuleID,
        severity: ASTDiagnosticSeverity? = nil,
        title: String,
        message: String,
        remediation: String,
        symbolName: String? = nil,
        span: SourceSpan = .zero
    ) {
        self.id = id
        self.ruleID = ruleID
        self.category = ruleID.category
        self.severity = severity ?? ruleID.defaultSeverity
        self.title = title
        self.message = message
        self.remediation = remediation
        self.symbolName = symbolName
        self.span = span
    }
}

/// Complete audit scorecard and diagnostic list emitted by `ASTStaticAnalyzer`.
public struct ASTAuditReport: Codable, Equatable, Sendable {
    public let diagnostics: [ASTDiagnostic]
    public let overallScore: Int
    public let categoryScores: [String: Int]
    public let errorCount: Int
    public let warningCount: Int
    public let infoCount: Int
    public let passedRuleCount: Int
    public let totalRuleCount: Int

    public init(diagnostics: [ASTDiagnostic]) {
        let sorted = diagnostics.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return $0.span.start < $1.span.start
        }
        self.diagnostics = sorted
        self.errorCount = sorted.filter { $0.severity == .error }.count
        self.warningCount = sorted.filter { $0.severity == .warning }.count
        self.infoCount = sorted.filter { $0.severity == .info }.count

        let triggeredRules = Set(sorted.map(\.ruleID))
        let allRules = ASTAuditRuleID.allCases
        self.totalRuleCount = allRules.count
        self.passedRuleCount = max(0, allRules.count - triggeredRules.count)

        var catScores: [String: Int] = [:]
        var scoreSum = 0
        for cat in ASTAuditCategory.allCases {
            let catDiags = sorted.filter { $0.category == cat }
            let penalty = catDiags.reduce(0) { acc, d in
                switch d.severity {
                case .error: return acc + 18
                case .warning: return acc + 8
                case .info: return acc + 3
                }
            }
            let s = max(0, min(100, 100 - penalty))
            catScores[cat.rawValue] = s
            scoreSum += s
        }
        self.categoryScores = catScores
        self.overallScore = scoreSum / max(1, ASTAuditCategory.allCases.count)
    }

    public func score(for category: ASTAuditCategory) -> Int {
        categoryScores[category.rawValue] ?? 100
    }
}

// MARK: - Static AST Analyzer Engine

/// Runs all 38 Swift 6 concurrency, VoiceOver accessibility, EDK token, performance, and safety lint passes.
public enum ASTStaticAnalyzer: Sendable {
    public static func analyze(
        source: String,
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> ASTAuditReport {
        let ast = SwiftUIParser.parse(source: source)
        return analyze(ast: ast, theme: theme)
    }

    public static func analyze(
        ast: SwiftSourceFile,
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> ASTAuditReport {
        var runner = AuditRunner(theme: theme)
        runner.inspectSourceFile(ast)
        return ASTAuditReport(diagnostics: runner.diagnostics)
    }
}

// MARK: - Internal Rule Visitor

private struct AuditRunner {
    let theme: StudioThemeTokens
    var diagnostics: [ASTDiagnostic] = []

    let heavyTypes: Set<String> = [
        "DateFormatter", "NumberFormatter", "ISO8601DateFormatter",
        "MeasurementFormatter", "JSONDecoder", "JSONEncoder", "NSRegularExpression"
    ]

    init(theme: StudioThemeTokens) {
        self.theme = theme
    }

    mutating func emit(
        _ rule: ASTAuditRuleID,
        title: String,
        message: String,
        remediation: String,
        symbol: String? = nil,
        span: SourceSpan = .zero
    ) {
        diagnostics.append(ASTDiagnostic(ruleID: rule, title: title, message: message, remediation: remediation, symbolName: symbol, span: span))
    }

    mutating func inspectSourceFile(_ file: SwiftSourceFile) {
        // Theme WCAG contrast check
        let contrast = theme.contrastReport
        if !contrast.primaryOnSurfaceLevel.passesAA {
            emit(
                .lowThemePrimaryContrast,
                title: "Low Primary-on-Surface WCAG Contrast",
                message: String(format: "Theme primary color contrast ratio is %.2f:1 (< 4.5:1 AA minimum).", contrast.primaryOnSurfaceRatio),
                remediation: "Run StudioThemeTokens.autoFixPrimaryContrast() or darken primary token."
            )
        }

        for prop in file.topLevelProperties {
            inspectProperty(prop, enclosingType: nil)
        }
        for fn in file.topLevelFunctions {
            inspectFunction(fn, enclosingType: nil)
        }
        for typeDecl in file.allTypesFlattened() {
            inspectType(typeDecl)
        }
        for preview in file.previews {
            for viewNode in preview.viewNodes {
                inspectViewSubtree(viewNode, enclosingType: nil, stateVarNames: [], depth: 1, insideScrollContainer: false)
            }
        }
    }

    mutating func inspectType(_ decl: SwiftTypeDecl) {
        // CK-CONC-001: Public struct/enum missing Sendable
        if decl.accessLevel.isPubliclyVisible && decl.kind.isValueType && !decl.isSwiftUIView && !decl.conformsToSendable {
            emit(
                .missingSendableOnPublicValueType,
                title: "Public Value Type Missing 'Sendable'",
                message: "Public \(decl.kind.rawValue) '\(decl.name)' does not explicitly conform to 'Sendable'.",
                remediation: "Add ': Sendable' conformance to '\(decl.name)' for cross-module Swift 6 concurrency safety.",
                symbol: decl.name,
                span: decl.span
            )
        }

        // CK-CONC-002: Class missing @MainActor or final + Sendable
        if decl.kind == .class && !decl.isMainActorIsolated && !(decl.isFinal && decl.conformsToSendable) {
            emit(
                .classMissingActorIsolationOrFinalSendable,
                title: "Class Missing Isolation or 'final Sendable'",
                message: "Class '\(decl.name)' lacks '@MainActor' isolation and is not 'final' + 'Sendable'.",
                remediation: "Annotate '\(decl.name)' with '@MainActor', convert to an 'actor', or mark 'final' with immutable 'Sendable' properties.",
                symbol: decl.name,
                span: decl.span
            )
        }

        // CK-CONC-003: @unchecked Sendable
        if decl.conformances.contains(where: { $0.contains("@unchecked") && $0.contains("Sendable") })
            || decl.attributes.contains(where: { $0.kind == .unchecked }) {
            emit(
                .uncheckedSendableConformance,
                title: "'@unchecked Sendable' Opts Out of Compiler Checking",
                message: "Type '\(decl.name)' uses '@unchecked Sendable', bypassing Swift 6 data-race verification.",
                remediation: "Replace manual lock synchronization with an 'actor' or 'Mutex' and remove '@unchecked'.",
                symbol: decl.name,
                span: decl.span
            )
        }

        // CK-SAFE-001: Legacy ObservableObject
        if decl.isLegacyObservableObject {
            emit(
                .legacyObservableObjectPattern,
                title: "Legacy 'ObservableObject' Conformance",
                message: "Type '\(decl.name)' conforms to Combine's 'ObservableObject' instead of Swift Observation.",
                remediation: "Apply the '.migrateToObservableMacro' transformation pass to upgrade '\(decl.name)' to '@Observable'.",
                symbol: decl.name,
                span: decl.span
            )
        }

        let stateVars = Set(
            decl.properties
                .filter { $0.hasWrapper(.state) || $0.hasWrapper(.stateObject) }
                .map(\.name)
        )

        // CK-SAFE-008: Excessive @State in a single View (> 5)
        if decl.isSwiftUIView && stateVars.count > 5 {
            emit(
                .excessiveLocalStateInView,
                title: "High Local '@State' Coupling (\(stateVars.count) properties)",
                message: "View '\(decl.name)' manages \(stateVars.count) separate '@State' properties directly.",
                remediation: "Apply '.liftStateToSwiftStateReducer' to consolidate state into a testable State + Action Reducer.",
                symbol: decl.name,
                span: decl.span
            )
        }

        for prop in decl.properties {
            inspectProperty(prop, enclosingType: decl, stateVarNames: stateVars)
        }
        for fn in decl.functions {
            inspectFunction(fn, enclosingType: decl)
        }
    }

    mutating func inspectProperty(
        _ prop: SwiftPropertyDecl,
        enclosingType: SwiftTypeDecl?,
        stateVarNames: Set<String> = []
    ) {
        let qualifiedSymbol = enclosingType.map { "\($0.name).\(prop.name)" } ?? prop.name

        // CK-CONC-006: Mutable static var without @MainActor
        if prop.isStatic && !prop.isLet && !(enclosingType?.isMainActorIsolated ?? false) {
            let hasUnsafe = prop.attributes.contains { $0.rawName == "nonisolated" && $0.arguments.contains("unsafe") }
            if !hasUnsafe {
                emit(
                    .mutableStaticSharedState,
                    title: "Unisolated Mutable 'static var'",
                    message: "Mutable static property '\(qualifiedSymbol)' is a data-race error under Swift 6 strict concurrency.",
                    remediation: "Convert 'static var' to 'static let' or isolate '\(qualifiedSymbol)' to '@MainActor'.",
                    symbol: qualifiedSymbol,
                    span: prop.span
                )
            }
        }

        // CK-CONC-007: nonisolated(unsafe)
        if prop.attributes.contains(where: { $0.rawName == "nonisolated" && $0.arguments.contains("unsafe") }) {
            emit(
                .nonisolatedUnsafeUsage,
                title: "'nonisolated(unsafe)' Disables Data-Race Protection",
                message: "Property '\(qualifiedSymbol)' bypasses Swift 6 concurrency isolation via 'nonisolated(unsafe)'.",
                remediation: "Prefer 'let' constants, actor isolation, or 'Synchronization.Mutex'.",
                symbol: qualifiedSymbol,
                span: prop.span
            )
        }

        // CK-SAFE-001: Legacy @Published / @StateObject / @ObservedObject / @EnvironmentObject
        for wrapper in prop.wrappers where wrapper.kind.isLegacyCombineWrapper {
            emit(
                .legacyObservableObjectPattern,
                title: "Legacy '@\(wrapper.wrapperName)' Property Wrapper",
                message: "Property '\(qualifiedSymbol)' uses Combine-era '@\(wrapper.wrapperName)'.",
                remediation: "Migrate to '@Observable' with '@State', '@Bindable', or '@Environment'.",
                symbol: qualifiedSymbol,
                span: prop.span
            )
        }

        // CK-SAFE-007: Public @State or @StateObject
        if prop.accessLevel.isPubliclyVisible && (prop.hasWrapper(.state) || prop.hasWrapper(.stateObject)) {
            emit(
                .publicMutableStateWrapper,
                title: "View-Local '@State' Declared Public",
                message: "Property '\(qualifiedSymbol)' exposes view-owned '@State' publicly.",
                remediation: "Declare '@State' and '@StateObject' properties 'private' so SwiftUI owns storage lifecycle.",
                symbol: qualifiedSymbol,
                span: prop.span
            )
        }

        if let initExpr = prop.initializer {
            inspectExpression(initExpr, symbol: qualifiedSymbol, span: prop.span, inViewBody: false)
        }

        for stmt in prop.computedStatements {
            inspectStatement(stmt, symbol: qualifiedSymbol, inViewBody: prop.name == "body", stateVars: stateVarNames, span: prop.span)
        }

        for rootView in prop.computedViewBody {
            let maxDepth = rootView.maxDepth
            if maxDepth > 7 {
                emit(
                    .deepViewHierarchyNesting,
                    title: "Deep SwiftUI View Nesting (Depth \(maxDepth))",
                    message: "View hierarchy in '\(qualifiedSymbol)' nests \(maxDepth) levels deep (recommended <= 7).",
                    remediation: "Apply '.extractSubview' to split deeply nested containers into composable subviews.",
                    symbol: qualifiedSymbol,
                    span: rootView.span
                )
            }
            inspectViewSubtree(rootView, enclosingType: enclosingType, stateVarNames: stateVarNames, depth: 1, insideScrollContainer: false)
        }
    }

    mutating func inspectFunction(_ fn: SwiftFunctionDecl, enclosingType: SwiftTypeDecl?) {
        let sym = enclosingType.map { "\($0.name).\(fn.name)" } ?? fn.name
        for stmt in fn.statements {
            inspectStatement(stmt, symbol: sym, inViewBody: false, stateVars: [], span: fn.span)
        }
        for viewNode in fn.viewBody {
            inspectViewSubtree(viewNode, enclosingType: enclosingType, stateVarNames: [], depth: 1, insideScrollContainer: false)
        }
    }

    // MARK: View Hierarchy Lint Rules

    mutating func inspectViewSubtree(
        _ node: SwiftViewNode,
        enclosingType: SwiftTypeDecl?,
        stateVarNames: Set<String>,
        depth: Int,
        insideScrollContainer: Bool
    ) {
        let sym = enclosingType.map { "\($0.name).\(node.componentName)" } ?? node.componentName
        let hasA11yLabel = node.hasModifier("accessibilityLabel")
        let hasA11yHidden = node.hasModifier("accessibilityHidden")
        let hasScaledMetric = enclosingType?.properties.contains(where: { $0.hasWrapper(.scaledMetric) }) ?? false

        // CK-PERF-001: AnyView type erasure
        if node.componentName == "AnyView" {
            emit(
                .anyViewTypeErasure,
                title: "'AnyView' Type Erasure Degrades Diffing",
                message: "'AnyView' erases structural view identity in '\(enclosingType?.name ?? "View")', forcing O(n) subtree recreation.",
                remediation: "Replace 'AnyView' with '@ViewBuilder' conditional branches or 'Group'.",
                symbol: sym,
                span: node.span
            )
        }

        // CK-PERF-002: GeometryReader inside ScrollView / List
        if node.containerKind == .geometryReader && insideScrollContainer {
            emit(
                .geometryReaderInsideScrollContainer,
                title: "'GeometryReader' Nested Inside Scroll Container",
                message: "'GeometryReader' inside a 'ScrollView' or 'List' collapses intrinsic height and causes layout loops.",
                remediation: "Use '.visualEffect', '.onGeometryChange', or '.containerRelativeFrame' instead of nested 'GeometryReader'.",
                symbol: sym,
                span: node.span
            )
        }

        // CK-PERF-004: Eager VStack/HStack with ForEach inside ScrollView
        if insideScrollContainer && (node.containerKind == .vStack || node.containerKind == .hStack) {
            if node.children.contains(where: { $0.containerKind == .forEach }) {
                emit(
                    .eagerStackWithForEachInScrollView,
                    title: "Eager '\(node.componentName)' Wrapping 'ForEach' in 'ScrollView'",
                    message: "'\(node.componentName)' eagerly instantiates every 'ForEach' row upfront inside 'ScrollView'.",
                    remediation: "Switch '\(node.componentName)' to 'Lazy\(node.componentName)' for on-demand cell virtualization.",
                    symbol: sym,
                    span: node.span
                )
            }
        }

        // CK-PERF-005: ForEach(..., id: \.self) or .indices
        if node.containerKind == .forEach {
            if let idArg = node.argument(labeled: "id"), idArg.renderedDescription.contains(".self") {
                emit(
                    .unstableForEachIdentitySelf,
                    title: "'ForEach' Uses 'id: \\.self' Identity",
                    message: "'id: \\.self' breaks animations and crashes when duplicate values appear in the collection.",
                    remediation: "Conform row models to 'Identifiable' with a stable 'id' property.",
                    symbol: sym,
                    span: node.span
                )
            }
            if let dataArg = node.arguments.first?.value, dataArg.renderedDescription.hasSuffix(".indices") {
                emit(
                    .unstableForEachIdentitySelf,
                    title: "'ForEach' Iterates Over '.indices'",
                    message: "'ForEach(items.indices)' uses non-constant range indices, causing stale cell state on deletion.",
                    remediation: "Iterate directly over 'Identifiable' elements instead of '.indices'.",
                    symbol: sym,
                    span: node.span
                )
            }
        }

        // CK-PERF-007: Excessive modifiers on single node
        if node.modifiers.count > 8 {
            emit(
                .excessiveModifierChainOnSingleView,
                title: "Long Modifier Chain (\(node.modifiers.count) modifiers)",
                message: "'\(node.componentName)' chains \(node.modifiers.count) modifiers on one view node.",
                remediation: "Extract reusable styling into a custom 'ViewModifier' or 'EDKSurface' preset.",
                symbol: sym,
                span: node.span
            )
        }

        // CK-A11Y-001 / 002 / 003 / 004: Accessibility annotations
        if (node.componentName == "Button" || node.componentName == "EDKButton") && !hasA11yLabel {
            emit(
                .buttonMissingAccessibilityLabel,
                title: "Interactive '\(node.componentName)' Missing '.accessibilityLabel'",
                message: "'\(node.componentName)' does not declare an explicit VoiceOver '.accessibilityLabel(...)'.",
                remediation: "Apply '.injectVoiceOverAndDynamicType' or add '.accessibilityLabel(\"...\")'.",
                symbol: sym,
                span: node.span
            )
        } else if node.componentName == "Toggle" && !hasA11yLabel {
            emit(
                .toggleMissingAccessibilityLabel,
                title: "'Toggle' Missing Explicit Accessibility Label",
                message: "'Toggle' in '\(enclosingType?.name ?? "View")' lacks '.accessibilityLabel' or '.accessibilityHint'.",
                remediation: "Add '.accessibilityLabel' and '.accessibilityHint' describing what toggling changes.",
                symbol: sym,
                span: node.span
            )
        } else if (node.componentName == "TextField" || node.componentName == "SecureField") && !hasA11yLabel {
            emit(
                .textFieldMissingAccessibilityLabel,
                title: "'\(node.componentName)' Missing '.accessibilityLabel'",
                message: "Input field '\(node.firstUnlabeledStringArgument ?? node.componentName)' relies solely on placeholder text for VoiceOver.",
                remediation: "Attach '.accessibilityLabel(\"...\")' so VoiceOver announces field purpose even when non-empty.",
                symbol: sym,
                span: node.span
            )
        } else if node.componentName == "Image" && !hasA11yLabel && !hasA11yHidden {
            emit(
                .imageMissingAccessibilityAnnotation,
                title: "'Image' Missing VoiceOver Label or Decorative Hidden Flag",
                message: "'Image' does not specify '.accessibilityLabel(...)' or '.accessibilityHidden(true)'.",
                remediation: "Add '.accessibilityLabel' for meaningful icons or '.accessibilityHidden(true)' for decorative art.",
                symbol: sym,
                span: node.span
            )
        }

        // CK-TOKN-004: Hardcoded numeric stack spacing
        if (node.containerKind == .vStack || node.containerKind == .hStack),
           let spacingVal = node.argument(labeled: "spacing")?.doubleValue,
           spacingVal > 0 {
            let standardSpacings: Set<Int> = [
                Int(theme.spacingXS), Int(theme.spacingSM), Int(theme.spacingMD), Int(theme.spacingLG)
            ]
            if !standardSpacings.contains(Int(spacingVal.rounded())) {
                emit(
                    .hardcodedStackSpacingLiteral,
                    title: "Non-Token Stack Spacing (\(Int(spacingVal)))",
                    message: "'\(node.componentName)(spacing: \(Int(spacingVal)))' uses an off-grid spacing literal.",
                    remediation: "Use 'theme.spacingXS/SM/MD/LG' or run '.tokenizeMagicLiterals'.",
                    symbol: sym,
                    span: node.span
                )
            }
        }

        // Inspect arguments & modifiers on this view node
        for arg in node.arguments {
            inspectExpression(arg.value, symbol: sym, span: node.span, inViewBody: true)
        }

        inspectViewModifiers(node: node, symbol: sym, hasScaledMetric: hasScaledMetric, stateVars: stateVarNames)

        // Inspect Button action statements (NOT inside pure render expression, so state mutations ARE valid here!)
        for stmt in node.actionStatements {
            inspectStatement(stmt, symbol: sym, inViewBody: false, stateVars: stateVarNames, span: node.span)
        }

        let nextInsideScroll = insideScrollContainer || node.containerKind == .scrollView || node.containerKind == .list
        for child in node.children {
            inspectViewSubtree(child, enclosingType: enclosingType, stateVarNames: stateVarNames, depth: depth + 1, insideScrollContainer: nextInsideScroll)
        }
        for child in node.elseChildren {
            inspectViewSubtree(child, enclosingType: enclosingType, stateVarNames: stateVarNames, depth: depth + 1, insideScrollContainer: nextInsideScroll)
        }
        for c in node.switchCases {
            for child in c.viewChildren {
                inspectViewSubtree(child, enclosingType: enclosingType, stateVarNames: stateVarNames, depth: depth + 1, insideScrollContainer: nextInsideScroll)
            }
        }
    }

    mutating func inspectViewModifiers(
        node: SwiftViewNode,
        symbol: String,
        hasScaledMetric: Bool,
        stateVars: Set<String>
    ) {
        let isInteractive = node.containerKind == .button
            || node.componentName == "Toggle"
            || node.componentName == "TextField"
            || node.hasModifier("onTapGesture")

        for mod in node.modifiers {
            // CK-TOKN-001: Hardcoded .padding(24)
            if mod.name == "padding",
               let numericArg = mod.arguments.last,
               numericArg.value.doubleValue != nil {
                emit(
                    .hardcodedPaddingLiteral,
                    title: "Hardcoded '.padding' Numeric Literal",
                    message: "'.padding(\(numericArg.value.renderedDescription))' uses a magic number instead of an EDK spacing token.",
                    remediation: "Replace with '.padding(theme.spacingMD)' or apply '.tokenizeMagicLiterals'.",
                    symbol: symbol,
                    span: mod.span
                )
            }

            // CK-TOKN-005 & CK-TOKN-002: .cornerRadius(...)
            if mod.name == "cornerRadius" {
                emit(
                    .deprecatedCornerRadiusModifier,
                    title: "Deprecated '.cornerRadius' Modifier",
                    message: "'.cornerRadius' clips via offscreen rasterization and is deprecated in modern SwiftUI.",
                    remediation: "Wrap in 'EDKSurface' or use '.clipShape(.rect(cornerRadius: theme.radiusMedium))'.",
                    symbol: symbol,
                    span: mod.span
                )
                if mod.arguments.first?.value.doubleValue != nil {
                    emit(
                        .hardcodedCornerRadiusLiteral,
                        title: "Hardcoded Corner Radius Literal",
                        message: "Corner radius uses a raw number instead of 'theme.radiusSmall/Medium/Large'.",
                        remediation: "Tokenize corner radii using 'StudioThemeTokens'.",
                        symbol: symbol,
                        span: mod.span
                    )
                }
            }

            // CK-TOKN-006: Raw .ultraThinMaterial without .edkLiquidGlass
            if mod.name == "background",
               mod.arguments.contains(where: { $0.value.renderedDescription.contains("Material") }),
               !node.hasModifier("edkLiquidGlass"),
               node.componentName != "Label" {
                emit(
                    .rawMaterialInsteadOfLiquidGlass,
                    title: "Raw SwiftUI Material Without '.edkLiquidGlass'",
                    message: "Raw material background bypasses theme frost and specular rim tokens.",
                    remediation: "Use 'EDKSurface(variant: .glass)' or '.edkLiquidGlass(cornerRadius:)'.",
                    symbol: symbol,
                    span: mod.span
                )
            }

            // CK-A11Y-005: Fixed .font(.system(size: ...)) without @ScaledMetric
            if mod.name == "font",
               let firstVal = mod.arguments.first?.value,
               firstVal.renderedDescription.contains("system(size:") && !hasScaledMetric {
                emit(
                    .fixedFontSizeBlocksDynamicType,
                    title: "Fixed Font Point Size Ignores Dynamic Type",
                    message: "'.font(\(firstVal.renderedDescription))' does not scale for Dynamic Type accessibility sizes.",
                    remediation: "Use semantic text styles ('.headline', '.title2') or bind size to '@ScaledMetric'.",
                    symbol: symbol,
                    span: mod.span
                )
            }

            // CK-A11Y-006: Interactive tap target < 44pt
            if mod.name == "frame" && isInteractive {
                let w = mod.arguments.first(where: { $0.label == "width" })?.value.doubleValue
                let h = mod.arguments.first(where: { $0.label == "height" })?.value.doubleValue
                if (w != nil && w! < 44) || (h != nil && h! < 44) {
                    emit(
                        .smallInteractiveHitTarget,
                        title: "Interactive Hit Target Smaller Than 44×44 pt",
                        message: "Interactive control '\(node.componentName)' specifies a frame dimension below Apple HIG's 44pt minimum.",
                        remediation: "Increase frame to >= 44pt or attach '.contentShape(Rectangle())' with adequate padding.",
                        symbol: symbol,
                        span: mod.span
                    )
                }
            }

            // CK-A11Y-007: Heading Text missing .isHeader trait
            if mod.name == "font" && node.componentName == "Text" {
                let desc = mod.arguments.first?.value.renderedDescription ?? ""
                if (desc.contains("largeTitle") || desc.contains(".title")) && !node.hasModifier("accessibilityAddTraits") {
                    emit(
                        .headingMissingHeaderTrait,
                        title: "Heading 'Text' Missing '.isHeader' Accessibility Trait",
                        message: "Title text '\(node.firstUnlabeledStringArgument ?? "Heading")' lacks '.accessibilityAddTraits(.isHeader)'.",
                        remediation: "Add '.accessibilityAddTraits(.isHeader)' for VoiceOver rotor heading navigation.",
                        symbol: symbol,
                        span: mod.span
                    )
                }
            }

            // CK-A11Y-008: .onTapGesture without .isButton trait
            if mod.name == "onTapGesture" && !node.hasModifier("accessibilityAddTraits") {
                emit(
                    .tapGestureMissingButtonTrait,
                    title: "'.onTapGesture' Missing Button Accessibility Trait",
                    message: "'.onTapGesture' on '\(node.componentName)' is invisible to VoiceOver button navigation and keyboard focus.",
                    remediation: "Prefer a semantic 'Button' / 'EDKButton' or add '.accessibilityAddTraits(.isButton)'.",
                    symbol: symbol,
                    span: mod.span
                )
            }

            // CK-CONC-008: .task { ... } with long loop / async work lacking Task.checkCancellation
            if mod.name == "task", let closure = mod.trailingClosure, !closure.statements.isEmpty {
                let bodyText = closure.rawBody
                if bodyText.contains("while ") && !bodyText.contains("isCancelled") && !bodyText.contains("checkCancellation") {
                    emit(
                        .asyncViewTaskMissingCancellationCheck,
                        title: "Loop Inside '.task' Without Cancellation Check",
                        message: "Async loop inside '.task' does not check 'Task.isCancelled' when view disappears.",
                        remediation: "Check '!Task.isCancelled' or call 'try Task.checkCancellation()' inside '.task' loops.",
                        symbol: symbol,
                        span: mod.span
                    )
                }
            }

            for arg in mod.arguments {
                inspectExpression(arg.value, symbol: symbol, span: mod.span, inViewBody: true)
            }
            if let closure = mod.trailingClosure {
                let closureIsLifecycle = mod.name == "onAppear" || mod.name == "task" || mod.name == "onTapGesture" || mod.name == "onChange"
                for stmt in closure.statements {
                    inspectStatement(stmt, symbol: symbol, inViewBody: !closureIsLifecycle, stateVars: stateVars, span: mod.span)
                }
            }
        }
    }

    // MARK: Statement & Expression Hazards

    mutating func inspectStatement(
        _ stmt: SwiftStatement,
        symbol: String,
        inViewBody: Bool,
        stateVars: Set<String>,
        span: SourceSpan
    ) {
        switch stmt {
        case .variableDecl(let prop):
            if let initExpr = prop.initializer {
                inspectExpression(initExpr, symbol: symbol, span: prop.span, inViewBody: inViewBody)
            }
        case .assignment(let target, _, let value):
            if inViewBody {
                let mutatedIDs = target.allReferencedIdentifiers()
                if !mutatedIDs.isDisjoint(with: stateVars) {
                    emit(
                        .stateMutationInsideViewBody,
                        title: "Direct '@State' Mutation During 'body' Evaluation",
                        message: "Mutating '@State' ('\(target.renderedDescription)') synchronously inside 'body' triggers undefined runtime invalidation loops.",
                        remediation: "Move state mutations into button actions, '.onAppear', '.task', or a pure 'Reducer'.",
                        symbol: symbol,
                        span: span
                    )
                }
            }
            inspectExpression(target, symbol: symbol, span: span, inViewBody: inViewBody)
            inspectExpression(value, symbol: symbol, span: span, inViewBody: inViewBody)

        case .expression(let expr), .throwStmt(let expr):
            inspectExpression(expr, symbol: symbol, span: span, inViewBody: inViewBody)
        case .returnStmt(let expr):
            if let expr { inspectExpression(expr, symbol: symbol, span: span, inViewBody: inViewBody) }
        case .ifStmt(_, let thenB, let elseB):
            for s in thenB { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: span) }
            for s in elseB { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: span) }
        case .guardStmt(_, let elseB):
            for s in elseB { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: span) }
        case .switchStmt(let subj, let cases):
            inspectExpression(subj, symbol: symbol, span: span, inViewBody: inViewBody)
            for c in cases {
                for s in c.statements { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: span) }
            }
        case .forLoop(_, let seq, let body):
            inspectExpression(seq, symbol: symbol, span: span, inViewBody: inViewBody)
            for s in body { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: span) }
        case .whileLoop(let cond, let body):
            inspectExpression(cond, symbol: symbol, span: span, inViewBody: inViewBody)
            for s in body { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: span) }
        case .doCatch(let doBody, let catches):
            for s in doBody { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: span) }
            for c in catches {
                if c.statements.isEmpty {
                    emit(
                        .emptyCatchBlock,
                        title: "Empty 'catch' Block Swallows Errors Silently",
                        message: "An empty 'catch { }' clause in '\(symbol)' discards thrown errors without logging or recovery.",
                        remediation: "Surface an error state to the user or log the failure via structured telemetry.",
                        symbol: symbol,
                        span: c.span
                    )
                }
                for s in c.statements { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: c.span) }
            }
        case .deferStmt(let body):
            for s in body { inspectStatement(s, symbol: symbol, inViewBody: inViewBody, stateVars: stateVars, span: span) }
        case .breakStmt, .continueStmt:
            break
        }
    }

    mutating func inspectExpression(_ expr: SwiftExpr, symbol: String, span: SourceSpan, inViewBody: Bool) {
        if expr.containsForceUnwrap {
            emit(
                .forceUnwrapOperator,
                title: "Force-Unwrap '!' Runtime Trap Hazard",
                message: "Expression in '\(symbol)' uses postfix '!' force-unwrapping.",
                remediation: "Unwrap safely using 'guard let', 'if let', or nil-coalescing '??'.",
                symbol: symbol,
                span: span
            )
        }
        if expr.containsForceTry {
            emit(
                .forceTryTrapHazard,
                title: "'try!' Unrecoverable Runtime Crash Hazard",
                message: "'try!' in '\(symbol)' terminates the process if an error is thrown.",
                remediation: "Propagate errors with 'throws' / 'do-catch' or degrade gracefully with 'try?'.",
                symbol: symbol,
                span: span
            )
        }
        if expr.containsForceCast {
            emit(
                .forceCastTrapHazard,
                title: "'as!' Forced Downcast Hazard",
                message: "Forced cast 'as!' in '\(symbol)' traps at runtime on type mismatch.",
                remediation: "Use conditional cast 'as?' with 'guard let'.",
                symbol: symbol,
                span: span
            )
        }

        visitCallSites(in: expr, symbol: symbol, span: span, inViewBody: inViewBody)
    }

    mutating func visitCallSites(in expr: SwiftExpr, symbol: String, span: SourceSpan, inViewBody: Bool) {
        switch expr {
        case .call(let callee, let args, let closure):
            let calleeDesc = callee.renderedDescription
            if calleeDesc == "DispatchQueue.main.async" {
                emit(
                    .legacyDispatchQueueMainAsync,
                    title: "Legacy 'DispatchQueue.main.async' Hop",
                    message: "'DispatchQueue.main.async' in '\(symbol)' bypasses structured concurrency cancellation and '@MainActor' checking.",
                    remediation: "Annotate the method with '@MainActor' or use 'MainActor.run' inside structured 'Task'.",
                    symbol: symbol,
                    span: span
                )
            }
            if calleeDesc == "Task.detached" {
                emit(
                    .detachedTaskLosesIsolation,
                    title: "'Task.detached' Drops Actor Isolation & Priority",
                    message: "'Task.detached' in '\(symbol)' discards caller actor context, priority, and task-local values.",
                    remediation: "Prefer 'Task { ... }' or move background CPU work into a dedicated 'nonisolated' async function.",
                    symbol: symbol,
                    span: span
                )
            }
            if inViewBody && heavyTypes.contains(calleeDesc) {
                emit(
                    .heavyFormatterAllocatedInViewBody,
                    title: "Expensive '\(calleeDesc)()' Allocated Inside 'body'",
                    message: "Instantiating '\(calleeDesc)()' during view body evaluation adds per-frame heap allocation overhead.",
                    remediation: "Use Swift's 'FormatStyle' API (e.g. '.formatted(.currency(code:))') or cache a static formatter.",
                    symbol: symbol,
                    span: span
                )
            }
            if calleeDesc == "Color" && args.contains(where: { $0.label == "red" }) && inViewBody {
                emit(
                    .rawColorInitializerOrHex,
                    title: "Hardcoded 'Color(red:green:blue:)' in View",
                    message: "Raw RGB color literal in '\(symbol)' bypasses 'EDKTheme' dark-mode and contrast tokens.",
                    remediation: "Apply '.tokenizeMagicLiterals' to map raw RGB colors to 'theme.colors.*'.",
                    symbol: symbol,
                    span: span
                )
            }
            if calleeDesc == "#colorLiteral" {
                emit(
                    .rawColorInitializerOrHex,
                    title: "'#colorLiteral' Hardcoded in Source",
                    message: "'#colorLiteral' in '\(symbol)' is not theme-adaptive.",
                    remediation: "Replace '#colorLiteral' with semantic 'EDKTheme' palette tokens.",
                    symbol: symbol,
                    span: span
                )
            }
            for arg in args {
                visitCallSites(in: arg.value, symbol: symbol, span: span, inViewBody: inViewBody)
            }
            if let closure {
                for stmt in closure.statements {
                    inspectStatement(stmt, symbol: symbol, inViewBody: false, stateVars: [], span: span)
                }
            }
        case .memberAccess(let base, _):
            visitCallSites(in: base, symbol: symbol, span: span, inViewBody: inViewBody)
        case .binaryOp(let l, _, let r):
            visitCallSites(in: l, symbol: symbol, span: span, inViewBody: inViewBody)
            visitCallSites(in: r, symbol: symbol, span: span, inViewBody: inViewBody)
        case .ternary(let c, let t, let e):
            visitCallSites(in: c, symbol: symbol, span: span, inViewBody: inViewBody)
            visitCallSites(in: t, symbol: symbol, span: span, inViewBody: inViewBody)
            visitCallSites(in: e, symbol: symbol, span: span, inViewBody: inViewBody)
        default:
            break
        }
    }
}
