import ChiefKitAST
import ChiefKitStudioCore
import Foundation
import Testing
import XCTest

// MARK: - Swift 6 Testing (@Suite / @Test) for ChiefKitAST 3.0

@Suite("ChiefKitAST 3.0 — Lexer, Parser, Formatter, Analyzer & Refactoring Suite")
struct ASTCompilerEngineSwiftTestingSuite {
    @Test("ChiefKitASTModule exposes 3.0.0 metadata, 38 audit rules, and unified compilation snapshot")
    func modulePipelineSnapshot() {
        #expect(ChiefKitASTModule.version == "3.0.0")
        #expect(ChiefKitASTModule.supportedAuditRuleCount == 38)
        #expect(ASTAuditRuleID.allCases.count == 38)

        let source = """
        import SwiftUI

        @MainActor
        public struct TelemetryOverviewView: View, Sendable {
            @State private var isExpanded: Bool = false

            public var body: some View {
                VStack(spacing: EDKSpacing.md) {
                    Text("ChiefKit Studio 3.0")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Button("Toggle Inspector") {
                        isExpanded.toggle()
                    }
                    .accessibilityLabel("Toggle Inspector Panel")
                }
                .padding(EDKSpacing.lg)
            }
        }
        """

        let snapshot = ChiefKitASTModule.analyzePipeline(
            source: source,
            filePath: "TelemetryOverviewView.swift",
            theme: StudioThemePreset.liquidGlass26.tokens
        )

        #expect(snapshot.verificationReport.isValid)
        #expect(snapshot.verificationReport.verifiedSwiftUIViews.contains("TelemetryOverviewView"))
        #expect(snapshot.tokenSummary.keywordCount > 5)
        #expect(snapshot.sourceFile.primaryViewType?.name == "TelemetryOverviewView")
        #expect(snapshot.auditReport.errorCount == 0)
        #expect(snapshot.auditReport.overallScore >= 80)
        #expect(snapshot.metricsReport.physicalLines >= 15)
        #expect(snapshot.symbolGraph.nodes.contains(where: { $0.name == "TelemetryOverviewView" && $0.kind == .swiftUIView }))
    }

    @Test("SwiftLexer tokenizes nested block comments, raw strings, multiline strings, and interpolations")
    func lexerCommentsAndStringForms() throws {
        let code = #"""
        /// Top-level doc comment for View
        /* Outer comment /* deeply /* nested */ block */ still outer */
        let rawText = #"Line1\n"Quoted"\#(1 + 2)Raw"#
        let customRaw = ##"Contains "# inside double-pound raw"##
        let multiline = """
            Alpha Line
            Beta Line
            """
        let interpolated = "Hello \(userName), total is \(price * 2)"
        """#

        let lexed = SwiftLexer.tokenize(code)
        #expect(lexed.diagnostics.isEmpty)
        #expect(lexed.summary.commentCount >= 2)
        #expect(lexed.summary.docCommentCount >= 1)

        let firstToken = try #require(lexed.tokens.first)
        #expect(firstToken.leadingDocComment?.contains("Top-level doc comment") == true)
        #expect(firstToken.leadingComments.count >= 2)

        var sawDoublePoundRaw = false
        var sawMultiline = false
        var sawInterpolated = false

        for token in lexed.tokens {
            switch token.kind {
            case .stringLiteral(_, let decoded, let isMultiline, let rawCount):
                if rawCount == 2 {
                    sawDoublePoundRaw = true
                    #expect(decoded.contains("\"#"))
                }
                if isMultiline {
                    sawMultiline = true
                    #expect(decoded.contains("Alpha Line"))
                    #expect(decoded.contains("Beta Line"))
                }
            case .interpolatedStringSegment(_, let exprs, _, _):
                sawInterpolated = true
                #expect(!exprs.isEmpty)
            default:
                break
            }
        }

        #expect(sawDoublePoundRaw)
        #expect(sawMultiline)
        #expect(sawInterpolated)
    }

    @Test("SwiftLexer parses hex, binary, octal, underscored numbers, attributes, and compiler directives")
    func lexerNumericRadicesAttributesAndDirectives() {
        let code = """
        #if os(macOS)
        @MainActor @Observable
        public final class MetricsModel {
            let hexMask = 0xFF_00_AA
            let hexFloat = 0x1.8p3
            let binaryFlags = 0b1010_0101
            let octalPerms = 0o755
            let largeDecimal = 1_250_000
            let scientific = 6.022_140e23
            let `class` = "escapedKeyword"
        }
        #else
        #warning("Fallback platform")
        #endif
        #Preview("Metrics Card") {
            EmptyView()
        }
        """

        let lexed = SwiftLexer.tokenize(code)
        #expect(lexed.diagnostics.isEmpty)

        var radices: Set<NumericRadix> = []
        var intValues: [Int64] = []
        var floatCount = 0
        var sawBacktickedClass = false
        var attributes: [SwiftAttributeKind] = []
        var directives: [SwiftDirectiveKind] = []

        for token in lexed.tokens {
            switch token.kind {
            case .integerLiteral(_, let val, let radix):
                radices.insert(radix)
                if let val { intValues.append(val) }
            case .floatingLiteral(_, _, let radix):
                radices.insert(radix)
                floatCount += 1
            case .identifier(let name, let backticked):
                if name == "class" && backticked {
                    sawBacktickedClass = true
                }
            case .attribute(let attr):
                attributes.append(attr)
            case .directive(let dir):
                directives.append(dir)
            default:
                break
            }
        }

        #expect(radices.contains(.hexadecimal))
        #expect(radices.contains(.binary))
        #expect(radices.contains(.octal))
        #expect(radices.contains(.decimal))
        #expect(intValues.contains(0xFF00AA))
        #expect(intValues.contains(0b10100101))
        #expect(intValues.contains(0o755))
        #expect(intValues.contains(1_250_000))
        #expect(floatCount == 2)
        #expect(sawBacktickedClass)
        #expect(attributes.contains(where: { $0.isConcurrencyAttribute }))
        #expect(attributes.contains(where: { $0.canonicalName == "Observable" }))
        #expect(directives.contains(.poundIf))
        #expect(directives.contains(.poundElse))
        #expect(directives.contains(.warning))
        #expect(directives.contains(.poundEndif))
        #expect(directives.contains(where: { $0.isPreviewMacro }))
    }

    @Test(
        "SwiftFormatterEngine is strictly idempotent across all 3 formatting presets",
        arguments: [
            SwiftFormatConfig.chiefKitStandard,
            SwiftFormatConfig.compact,
            SwiftFormatConfig.strictWrappedModifiers
        ]
    )
    func formatterPresetIdempotency(config: SwiftFormatConfig) {
        let messySource = """
        import SwiftUI
        import Foundation
        import Combine



        public struct   UnformattedDashboardView : View, Sendable {
        @State private var selectedFilter: String = "All"
        @State private var unreadCount: Int = 4

        public var body: some View {
        NavigationStack {
        VStack(alignment: .leading, spacing: 12) {
        HStack {
        Text("Executive Metrics").font(.title2).fontWeight(.bold).foregroundStyle(.primary).padding(.horizontal, 8)
        Spacer()
        Button("Refresh") { unreadCount += 1 }.buttonStyle(.borderedProminent).controlSize(.regular).accessibilityLabel("Refresh Metrics")
        }
        if unreadCount > 0 {
        Text("Unread alerts: \\(unreadCount)").padding(8).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
        Text("All clear")
        }
        }
        .padding(16)
        .navigationTitle("Dashboard")
        }
        }
        }
        """

        let firstPass = SwiftFormatterEngine.format(source: messySource, config: config)
        let secondPass = SwiftFormatterEngine.format(source: firstPass.formattedSource, config: config)

        #expect(firstPass.formattedSource == secondPass.formattedSource)
        #expect(!secondPass.wasModified)
        #expect(secondPass.changedLineCount == 0)

        let verification = ASTSourceVerifier.verifySource(code: firstPass.formattedSource)
        #expect(verification.isValid)
    }

    @Test(
        "ASTTestSynthesizer emits valid test suites across Swift Testing, XCTest, and Dual targets",
        arguments: ASTTestFrameworkTarget.allCases
    )
    func testSynthesizerFrameworks(target: ASTTestFrameworkTarget) {
        let appSource = """
        import Foundation
        import SwiftUI

        public enum PaymentFilter: String, CaseIterable, Codable, Sendable {
            case all
            case settled
            case pending
        }

        public struct PaymentInvoice: Codable, Equatable, Sendable {
            public var title: String
            public var amount: Double
            public var isPaid: Bool
        }

        public struct PaymentReducer: Sendable {
            public struct State: Equatable, Sendable {
                public var count: Int = 0
                public var isLoading: Bool = false
            }

            public enum Action: Equatable, Sendable {
                case increment
                case reset
                case setLoading(Bool)
            }

            public static func reduce(state: inout State, action: Action) {
                switch action {
                case .increment:
                    state.count += 1
                case .reset:
                    state.count = 0
                case .setLoading(let flag):
                    state.isLoading = flag
                }
            }
        }

        public struct PaymentSummaryView: View {
            @State private var searchQuery: String = ""

            public var body: some View {
                VStack {
                    Text("Invoices")
                    TextField("Search", text: $searchQuery)
                        .accessibilityLabel("Search Invoices")
                    Button("Reload") {}
                        .accessibilityLabel("Reload Invoices")
                }
            }
        }
        """

        let synthesized = ASTTestSynthesizer.synthesize(
            source: appSource,
            moduleUnderTest: "FinanceDomain",
            framework: target
        )

        #expect(synthesized.totalTestCount >= 3)
        #expect(synthesized.totalAssertionCount >= 3)
        #expect(!synthesized.descriptors.isEmpty)
        #expect(!synthesized.coveredSymbols.isEmpty)

        switch target {
        case .swiftTesting:
            #expect(synthesized.generatedCode.contains("import Testing"))
            #expect(synthesized.generatedCode.contains("@Suite"))
            #expect(synthesized.generatedCode.contains("@Test"))
            #expect(synthesized.generatedCode.contains("#expect("))
        case .xcTest:
            #expect(synthesized.generatedCode.contains("import XCTest"))
            #expect(synthesized.generatedCode.contains("XCTestCase"))
            #expect(synthesized.generatedCode.contains("func test"))
        case .both:
            #expect(synthesized.generatedCode.contains("import Testing"))
            #expect(synthesized.generatedCode.contains("import XCTest"))
            #expect(synthesized.generatedCode.contains("@Suite"))
            #expect(synthesized.generatedCode.contains("XCTestCase"))
        }

        let verification = ASTSourceVerifier.verifySource(code: synthesized.generatedCode)
        #expect(verification.isValid)
    }
}

// MARK: - XCTest Suite for Deep Parser, Canvas Bridge, Static Analyzer, Refactoring & Verifier

final class ASTCompilerEngineXCTests: XCTestCase {
    func testLexerUnterminatedRecoveryAndTokenLimitOptions() {
        let brokenSource = """
        let ok = 42
        /* Unterminated comment at EOF
        """
        let recovered = SwiftLexer.tokenize(
            brokenSource,
            options: SwiftLexerOptions(
                preserveTrivia: true,
                decodeEscapeSequences: true,
                recoverFromUnterminatedLiterals: true,
                maxTokenLimit: 500
            )
        )
        XCTAssertFalse(recovered.diagnostics.isEmpty)
        XCTAssertEqual(recovered.tokens.last?.kind, .eof)

        let longInput = Array(repeating: "let item = 42;", count: 60).joined(separator: " ")
        let capped = SwiftLexer.tokenize(
            longInput,
            options: SwiftLexerOptions(
                preserveTrivia: false,
                decodeEscapeSequences: true,
                recoverFromUnterminatedLiterals: true,
                maxTokenLimit: 128
            )
        )
        XCTAssertLessThanOrEqual(capped.tokens.count, 129)
        XCTAssertTrue(capped.tokens.last?.isEOF == true)
    }

    func testSourcePositionAndSpanOperations() {
        let code = "struct Box {\n    let width = 100\n}"
        let lexed = SwiftLexer.tokenize(code)
        guard let structTok = lexed.tokens.first(where: { $0.isKeyword(.struct) }),
              let boxTok = lexed.tokens.first(where: { $0.identifierOrContextualName == "Box" }) else {
            XCTFail("Expected struct Box tokens")
            return
        }

        XCTAssertTrue(structTok.span.start < boxTok.span.start)
        let merged = structTok.span.merged(with: boxTok.span)
        XCTAssertTrue(merged.contains(structTok.span.start))
        XCTAssertTrue(merged.overlaps(boxTok.span))
        XCTAssertEqual(merged.extractSubstring(from: code), "struct Box")
    }

    func testSwiftUIParserComplexViewBuilderHierarchyAndPreviews() {
        let complexViewSource = """
        import Foundation
        import SwiftUI

        #if canImport(SwiftUI)
        @MainActor
        public struct EnterpriseWorkspaceSplitView: View, Sendable {
            @State private var selectedSection: String = "Overview"
            @State private var showInspector: Bool = true
            @Binding public var filterQuery: String
            private let categories: [String] = ["Overview", "Security", "Metrics"]

            public var body: some View {
                NavigationSplitView {
                    List {
                        ForEach(categories, id: \\.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                Text(item)
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .navigationTitle("Workspace")
                } detail: {
                    VStack(alignment: .leading, spacing: 16) {
                        if showInspector {
                            HStack {
                                Text("Active: \\(selectedSection)")
                                    .font(.title2)
                                    .bold()
                                Spacer()
                                Button("Hide") {
                                    showInspector = false
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            Text("Inspector Hidden")
                                .foregroundStyle(.secondary)
                        }

                        switch selectedSection {
                        case "Security":
                            Label("Vault Locked", systemImage: "lock.shield")
                        default:
                            Label("All Systems Nominal", systemImage: "checkmark.seal")
                        }
                    }
                    .padding(20)
                    .background(.regularMaterial)
                }
            }
        }

        #Preview("Split Workspace") {
            EnterpriseWorkspaceSplitView(filterQuery: .constant(""))
        }
        #endif
        """

        let ast = SwiftUIParser.parse(source: complexViewSource, filePath: "EnterpriseWorkspaceSplitView.swift")
        XCTAssertTrue(ast.diagnostics.filter { $0.severity == .error }.isEmpty)
        XCTAssertEqual(ast.imports.count, 2)
        XCTAssertEqual(ast.conditionalBlocks.count, 1)
        XCTAssertEqual(ast.previews.count, 1)
        XCTAssertEqual(ast.previews.first?.title, "Split Workspace")

        guard let viewType = ast.primaryViewType else {
            XCTFail("Expected EnterpriseWorkspaceSplitView primaryViewType")
            return
        }
        XCTAssertEqual(viewType.name, "EnterpriseWorkspaceSplitView")
        XCTAssertTrue(viewType.isSwiftUIView)
        XCTAssertTrue(viewType.isMainActorIsolated)
        XCTAssertTrue(viewType.conformsToSendable)
        XCTAssertGreaterThanOrEqual(viewType.properties.count, 5)

        let rootNodes = viewType.bodyViewNodes
        XCTAssertEqual(rootNodes.count, 1)
        let splitNode = rootNodes[0]
        XCTAssertEqual(splitNode.componentName, "NavigationSplitView")
        XCTAssertEqual(splitNode.containerKind, .navigationSplitView)
        XCTAssertGreaterThan(splitNode.totalNodeCount, 8)
        XCTAssertGreaterThanOrEqual(splitNode.maxDepth, 4)
        XCTAssertGreaterThan(splitNode.totalModifierCount, 4)

        let flattened = splitNode.flattenedNodes()
        let componentNames = Set(flattened.map(\.componentName))
        XCTAssertTrue(componentNames.contains("List"))
        XCTAssertTrue(componentNames.contains("ForEach"))
        XCTAssertTrue(componentNames.contains("VStack"))
        XCTAssertTrue(componentNames.contains("HStack"))
        XCTAssertTrue(componentNames.contains("Button"))
        XCTAssertTrue(flattened.contains(where: { $0.containerKind == .conditionalIf && !$0.elseChildren.isEmpty }))
        XCTAssertTrue(flattened.contains(where: { $0.containerKind == .conditionalSwitch && $0.switchCases.count == 2 }))
    }

    func testASTCanvasBridgeBidirectionalImportAndExportRoundTrips() {
        let swiftUISource = """
        import SwiftUI

        struct CheckoutBlocksScreen: View {
            @State private var customerEmail: String = ""
            @State private var expressShipping: Bool = true

            var body: some View {
                VStack(spacing: 16) {
                    Text("Order Summary")
                        .font(.title2)
                    EDKBadge("VIP Tier")
                    TextField("Email Address", text: $customerEmail)
                    Toggle("Express Delivery", isOn: $expressShipping)
                    HStack(spacing: 12) {
                        Button("Apply Promo") {}
                        Button("Pay Now") {}
                    }
                    Spacer()
                }
                .padding(20)
            }
        }
        """

        let imported = ASTCanvasBridge.importToCanvas(source: swiftUISource, canvasWidth: 640)
        XCTAssertEqual(imported.structName, "CheckoutBlocksScreen")
        XCTAssertGreaterThanOrEqual(imported.importedNodeCount, 5)
        XCTAssertEqual(imported.document.nodes.count, imported.importedNodeCount)

        // Verify adaptive stacks export produces valid Swift 6 source and round-trips cleanly
        let adaptiveExport = ASTCanvasBridge.exportToFormattedSwift(
            document: imported.document,
            structName: "CheckoutBlocksScreen",
            theme: StudioThemePreset.midnightViolet.tokens,
            layoutMode: .adaptiveStacks,
            formatConfig: .chiefKitStandard
        )
        XCTAssertEqual(adaptiveExport.nodeCount, imported.importedNodeCount)
        XCTAssertTrue(adaptiveExport.formattedSource.contains("struct CheckoutBlocksScreen: View"))
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: adaptiveExport.formattedSource).isValid)

        // Verify positioned canvas export also produces valid Swift 6 source
        let positionedExport = ASTCanvasBridge.exportToFormattedSwift(
            document: imported.document,
            structName: "PositionedCheckoutScreen",
            theme: StudioThemePreset.liquidGlass26.tokens,
            layoutMode: .positionedCanvas,
            formatConfig: .compact
        )
        XCTAssertTrue(positionedExport.formattedSource.contains("struct PositionedCheckoutScreen: View"))
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: positionedExport.formattedSource).isValid)

        // Re-importing the exported SwiftUI preserves non-empty canvas representation
        let reimported = ASTCanvasBridge.importToCanvas(source: adaptiveExport.formattedSource, canvasWidth: 640)
        XCTAssertGreaterThanOrEqual(reimported.importedNodeCount, 4)
        XCTAssertEqual(reimported.structName, "CheckoutBlocksScreen")
    }

    func testASTStaticAnalyzerDetectsConcurrencyAccessibilityTokensPerformanceAndSafetyViolations() {
        let problematicSource = """
        import SwiftUI

        public struct UnsendablePayload {
            public var title: String
        }

        public class LegacyStore: ObservableObject {
            public static var sharedCache: [String] = []
            @Published public var items: [String] = []

            public func refresh() {
                DispatchQueue.main.async {
                    Task.detached {
                        print("detached")
                    }
                }
                do {
                    let data = try! Data(contentsOf: URL(string: "https://example.com")!)
                    let casted = (data as! NSData)
                    _ = casted
                } catch {
                }
            }
        }

        public struct ProblematicDashboardView: View {
            public @State var f1: String = ""
            @State private var f2: String = ""
            @State private var f3: String = ""
            @State private var f4: String = ""
            @State private var f5: String = ""
            @State private var f6: String = ""
            @State private var enabled: Bool = false

            public var body: some View {
                ScrollView {
                    GeometryReader { proxy in
                        VStack(spacing: 17) {
                            ForEach(["A", "B"], id: \\.self) { entry in
                                AnyView(Text(entry))
                                VStack {
                                    Image(systemName: "bell")
                                    Text(entry)
                                        .font(.system(size: 15))
                                        .onTapGesture {
                                            f2 = "mutated"
                                        }
                                    TextField("Enter code", text: $f1)
                                    Toggle("Enable", isOn: $enabled)
                                    Button("Submit") {
                                        let df = DateFormatter()
                                        _ = df.string(from: Date())
                                    }
                                    .frame(width: 24, height: 24)
                                }
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .foregroundStyle(Color(red: 0.2, green: 0.3, blue: 0.8))
                            }
                        }
                    }
                }
            }
        }
        """

        var lowContrastTheme = StudioThemeTokens()
        lowContrastTheme.primary = RGBAColor(red: 0.92, green: 0.92, blue: 0.92)
        lowContrastTheme.surface = RGBAColor(red: 0.96, green: 0.96, blue: 0.96)

        let report = ASTStaticAnalyzer.analyze(source: problematicSource, theme: lowContrastTheme)
        let ruleIDs = Set(report.diagnostics.map(\.ruleID))

        // Concurrency rules
        XCTAssertTrue(ruleIDs.contains(.missingSendableOnPublicValueType))
        XCTAssertTrue(ruleIDs.contains(.legacyDispatchQueueMainAsync))
        XCTAssertTrue(ruleIDs.contains(.detachedTaskLosesIsolation))
        XCTAssertTrue(ruleIDs.contains(.mutableStaticSharedState))

        // Accessibility & VoiceOver rules
        XCTAssertTrue(ruleIDs.contains(.buttonMissingAccessibilityLabel))
        XCTAssertTrue(ruleIDs.contains(.toggleMissingAccessibilityLabel))
        XCTAssertTrue(ruleIDs.contains(.textFieldMissingAccessibilityLabel))
        XCTAssertTrue(ruleIDs.contains(.imageMissingAccessibilityAnnotation))
        XCTAssertTrue(ruleIDs.contains(.fixedFontSizeBlocksDynamicType))
        XCTAssertTrue(ruleIDs.contains(.lowThemePrimaryContrast))

        // Design Token rules
        XCTAssertTrue(ruleIDs.contains(.hardcodedPaddingLiteral))
        XCTAssertTrue(ruleIDs.contains(.hardcodedStackSpacingLiteral))
        XCTAssertTrue(ruleIDs.contains(.deprecatedCornerRadiusModifier) || ruleIDs.contains(.hardcodedCornerRadiusLiteral))
        XCTAssertTrue(ruleIDs.contains(.rawMaterialInsteadOfLiquidGlass))

        // Performance rules
        XCTAssertTrue(ruleIDs.contains(.anyViewTypeErasure))
        XCTAssertTrue(ruleIDs.contains(.geometryReaderInsideScrollContainer))
        XCTAssertTrue(ruleIDs.contains(.eagerStackWithForEachInScrollView))
        XCTAssertTrue(ruleIDs.contains(.unstableForEachIdentitySelf))

        // Architecture & Safety rules
        XCTAssertTrue(ruleIDs.contains(.legacyObservableObjectPattern))
        XCTAssertTrue(ruleIDs.contains(.forceUnwrapOperator))
        XCTAssertTrue(ruleIDs.contains(.forceTryTrapHazard))
        XCTAssertTrue(ruleIDs.contains(.forceCastTrapHazard))
        XCTAssertTrue(ruleIDs.contains(.emptyCatchBlock))
        XCTAssertTrue(ruleIDs.contains(.publicMutableStateWrapper))

        XCTAssertGreaterThan(report.errorCount, 0)
        XCTAssertGreaterThan(report.warningCount, 5)
        for category in ASTAuditCategory.allCases {
            XCTAssertLessThan(report.score(for: category), 100, "Expected deductions in \(category.rawValue)")
        }
    }

    func testAllSixASTTransformationEnginePassesAndMultiPassPipeline() {
        // 1. .extractSubview
        let extractInput = """
        import SwiftUI

        struct ParentAccountView: View {
            var body: some View {
                VStack(spacing: 16) {
                    Text("Account Header")
                    HStack(spacing: 8) {
                        Text("Balance")
                        Text("$4,200.00")
                    }
                }
            }
        }
        """
        let extracted = ASTTransformationEngine.apply(
            pass: .extractSubview(targetNodeName: "HStack", newStructName: "AccountBalanceRow"),
            to: extractInput
        )
        XCTAssertTrue(extracted.didModify)
        XCTAssertTrue(extracted.formattedSource.contains("struct AccountBalanceRow: View"))
        XCTAssertTrue(extracted.formattedSource.contains("AccountBalanceRow("))
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: extracted.formattedSource).isValid)

        // 2. .migrateToObservableMacro
        let legacyCombineSource = """
        import Combine
        import SwiftUI

        final class CartViewModel: ObservableObject {
            @Published var itemCount: Int = 0
            @Published var couponCode: String = ""
        }

        struct CartHostView: View {
            @StateObject private var viewModel = CartViewModel()

            var body: some View {
                Text("Items: \\(viewModel.itemCount)")
            }
        }
        """
        let migrated = ASTTransformationEngine.apply(pass: .migrateToObservableMacro, to: legacyCombineSource)
        XCTAssertTrue(migrated.didModify)
        XCTAssertTrue(migrated.formattedSource.contains("@Observable"))
        XCTAssertFalse(migrated.formattedSource.contains("@Published"))
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: migrated.formattedSource).isValid)

        // 3. .tokenizeMagicLiterals
        let magicLiteralsSource = """
        import SwiftUI

        struct PromoCardView: View {
            var body: some View {
                VStack(spacing: 16) {
                    Text("Summer Offer")
                        .padding(16)
                        .cornerRadius(12)
                }
            }
        }
        """
        let tokenized = ASTTransformationEngine.apply(
            pass: .tokenizeMagicLiterals,
            to: magicLiteralsSource,
            theme: StudioThemePreset.liquidGlass26.tokens
        )
        XCTAssertTrue(tokenized.didModify)
        XCTAssertFalse(tokenized.edits.isEmpty)
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: tokenized.formattedSource).isValid)

        // 4. .injectVoiceOverAndDynamicType
        let inaccessibleSource = """
        import SwiftUI

        struct QuickActionsView: View {
            @State private var query: String = ""
            @State private var notificationsOn: Bool = true

            var body: some View {
                VStack {
                    Image(systemName: "sparkles")
                    Text("Quick Actions")
                        .font(.system(size: 22))
                    TextField("Search actions", text: $query)
                    Toggle("Enable Alerts", isOn: $notificationsOn)
                    Button("Execute") {}
                }
            }
        }
        """
        let accessible = ASTTransformationEngine.apply(pass: .injectVoiceOverAndDynamicType, to: inaccessibleSource)
        XCTAssertTrue(accessible.didModify)
        XCTAssertTrue(accessible.formattedSource.contains("accessibilityLabel"))
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: accessible.formattedSource).isValid)

        // 5. .liftStateToSwiftStateReducer
        let localStateSource = """
        import SwiftUI

        struct CounterPanelView: View {
            @State private var count: Int = 0
            @State private var isSaving: Bool = false

            var body: some View {
                VStack {
                    Text("Count: \\(count)")
                    Button("Save") {
                        isSaving = true
                    }
                }
            }
        }
        """
        let lifted = ASTTransformationEngine.apply(pass: .liftStateToSwiftStateReducer, to: localStateSource)
        XCTAssertTrue(lifted.didModify)
        XCTAssertTrue(lifted.formattedSource.contains("State") && lifted.formattedSource.contains("Action"))
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: lifted.formattedSource).isValid)

        // 6. .instrumentTimelineTelemetry
        let uninstrumentedSource = """
        import SwiftUI

        struct AnalyticsFeedView: View {
            var body: some View {
                VStack {
                    Text("Live Stream")
                }
            }
        }
        """
        let instrumented = ASTTransformationEngine.apply(pass: .instrumentTimelineTelemetry, to: uninstrumentedSource)
        XCTAssertTrue(instrumented.didModify)
        XCTAssertFalse(instrumented.edits.isEmpty)
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: instrumented.formattedSource).isValid)

        // Multi-pass pipeline execution
        let pipelined = ASTTransformationEngine.applyPipeline(
            passes: [
                .tokenizeMagicLiterals,
                .injectVoiceOverAndDynamicType,
                .instrumentTimelineTelemetry
            ],
            to: inaccessibleSource
        )
        XCTAssertTrue(pipelined.didModify)
        XCTAssertGreaterThanOrEqual(pipelined.edits.count, 3)
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: pipelined.formattedSource).isValid)
    }

    func testASTMetricsAndComplexityHalsteadCyclomaticAndViewProfiles() {
        let algorithmicSource = """
        import Foundation
        import SwiftUI

        // Computes risk tier across multiple nested conditions
        public struct RiskCalculator {
            public static func score(amount: Double, retries: Int, vip: Bool, country: String) -> Int {
                guard amount > 0 else { return 0 }
                var points = 10
                if amount > 10_000 {
                    if retries > 3 {
                        points += 50
                    } else if !vip {
                        points += 25
                    }
                }
                switch country {
                case "TR", "DE":
                    points += 5
                case "US":
                    points += 8
                default:
                    points += 15
                }
                for step in 0..<retries {
                    if step % 2 == 0 {
                        points += 2
                    }
                }
                return points
            }
        }

        public struct RiskBadgeView: View {
            @State private var expanded: Bool = false
            @Binding public var currentScore: Int

            public var body: some View {
                VStack(spacing: 8) {
                    if currentScore > 40 {
                        Text("High Risk")
                            .font(.headline)
                            .foregroundStyle(.red)
                    } else {
                        Text("Standard Risk")
                            .font(.subheadline)
                    }
                }
                .padding(12)
            }
        }
        """

        let metrics = ASTMetricsAndComplexity.analyze(source: algorithmicSource)
        XCTAssertGreaterThan(metrics.physicalLines, 35)
        XCTAssertGreaterThan(metrics.logicalCodeLines, 20)
        XCTAssertGreaterThanOrEqual(metrics.commentLines, 1)
        XCTAssertGreaterThanOrEqual(metrics.cyclomaticComplexityTotal, 6)
        XCTAssertGreaterThanOrEqual(metrics.cognitiveComplexityTotal, 6)

        XCTAssertEqual(metrics.halstead.vocabulary, metrics.halstead.distinctOperators + metrics.halstead.distinctOperands)
        XCTAssertEqual(metrics.halstead.programLength, metrics.halstead.totalOperators + metrics.halstead.totalOperands)
        XCTAssertGreaterThan(metrics.halstead.volume, 0)
        XCTAssertGreaterThan(metrics.halstead.effort, 0)
        XCTAssertGreaterThanOrEqual(metrics.maintainabilityIndex, 0)
        XCTAssertLessThanOrEqual(metrics.maintainabilityIndex, 100)
        XCTAssertFalse(metrics.maintainabilityGrade.isEmpty)

        XCTAssertEqual(metrics.functionProfiles.count, 2)
        XCTAssertEqual(metrics.functionProfiles.first?.parameterCount, 4)
        XCTAssertGreaterThanOrEqual(metrics.functionProfiles.first?.maxNestingDepth ?? 0, 2)

        XCTAssertEqual(metrics.viewProfiles.count, 1)
        let viewProfile = metrics.viewProfiles[0]
        XCTAssertEqual(viewProfile.viewName, "RiskBadgeView")
        XCTAssertEqual(viewProfile.statePropertyCount, 1)
        XCTAssertEqual(viewProfile.bindingPropertyCount, 1)
        XCTAssertGreaterThanOrEqual(viewProfile.conditionalBranches, 1)
    }

    func testASTSymbolGraphBuilderCycleDetectionTopologicalOrderAndMermaidExports() throws {
        let acyclicFiles: [(filePath: String, code: String)] = [
            (
                "Domain.swift",
                """
                import Foundation

                public protocol IdentifiableEntity: Sendable {
                    var id: UUID { get }
                }

                public struct LedgerItem: IdentifiableEntity {
                    public let id: UUID
                }
                """
            ),
            (
                "Presentation.swift",
                """
                import SwiftUI

                @Observable
                public final class LedgerStore {
                    public var selectedItem: LedgerItem?
                }

                public struct LedgerScreen: View {
                    public var store: LedgerStore
                    public var body: some View {
                        LedgerRowView()
                    }
                }

                public struct LedgerRowView: View {
                    public var body: some View {
                        Text("Row")
                    }
                }
                """
            )
        ]

        let dagGraph = ASTSymbolGraphBuilder.build(from: acyclicFiles)
        XCTAssertGreaterThanOrEqual(dagGraph.nodes.count, 5)
        XCTAssertTrue(dagGraph.detectCycles().isEmpty)
        let topo = dagGraph.topologicalOrder()
        XCTAssertEqual(topo.count, dagGraph.nodes.count)

        let screenOutgoing = dagGraph.outgoingEdges(from: "LedgerScreen")
        XCTAssertTrue(screenOutgoing.contains(where: { $0.targetID == "LedgerRowView" && $0.kind == .rendersChildView }))
        XCTAssertTrue(screenOutgoing.contains(where: { $0.targetID == "LedgerStore" && $0.kind == .composesProperty }))

        let classDiagram = dagGraph.exportMermaidClassDiagram()
        XCTAssertTrue(classDiagram.contains("classDiagram"))
        XCTAssertTrue(classDiagram.contains("LedgerScreen"))

        let flowchart = dagGraph.exportMermaidFlowchartTD()
        XCTAssertTrue(flowchart.contains("flowchart TD"))
        XCTAssertTrue(flowchart.contains("renders"))

        let jsonIndex = dagGraph.exportJSONIndex(prettyPrinted: true)
        let jsonData = try XCTUnwrap(jsonIndex.data(using: .utf8))
        let parsedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        XCTAssertNotNil(parsedJSON["nodes"])
        XCTAssertNotNil(parsedJSON["edges"])

        // Cyclic graph detection (NodeA <-> NodeB)
        let cyclicSource = """
        struct NodeA {
            var partner: NodeB?
        }
        struct NodeB {
            var owner: NodeA?
        }
        """
        let cyclicGraph = ASTSymbolGraphBuilder.build(from: cyclicSource)
        let cycles = cyclicGraph.detectCycles()
        XCTAssertFalse(cycles.isEmpty, "Expected mutual composition cycle between NodeA and NodeB")
    }

    func testASTSourceVerifierNegativeDiagnosticsAndLiveRepositoryDirectories() {
        // 1. Negative cases: unbalanced braces, invalid #else order, duplicate nominal type, missing View body
        let unbalancedBrace = ASTSourceVerifier.verifySource(code: "struct Broken {\n    let x = 1\n")
        XCTAssertFalse(unbalancedBrace.isValid)
        XCTAssertTrue(unbalancedBrace.issues.contains(where: { $0.kind == .unbalancedBraces }))

        let invalidDirective = ASTSourceVerifier.verifySource(code: "#else\nlet x = 1\n#endif")
        XCTAssertFalse(invalidDirective.isValid)
        XCTAssertTrue(
            invalidDirective.issues.contains(where: {
                $0.kind == .invalidConditionalDirectiveOrder || $0.kind == .unbalancedConditionalCompilation
            })
        )

        let duplicateAndMissingBody = ASTSourceVerifier.verifySource(
            code: """
            import SwiftUI
            struct GhostView: View {
                let title: String
            }
            struct GhostView {
                let count: Int
            }
            """
        )
        XCTAssertFalse(duplicateAndMissingBody.isValid)
        XCTAssertTrue(duplicateAndMissingBody.issues.contains(where: { $0.kind == .duplicateTypeDeclaration }))
        XCTAssertTrue(duplicateAndMissingBody.issues.contains(where: { $0.kind == .missingSwiftUIViewBody }))

        // 2. Live repository directory verification across Sources/ChiefKitAST and Sources/ChiefKitStudioCore
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let astDir = repoRoot.appendingPathComponent("Sources/ChiefKitAST")
        let astReport = ASTSourceVerifier.verifyDirectory(at: astDir, recursive: true)
        XCTAssertTrue(
            astReport.isValid,
            "Sources/ChiefKitAST failed structural verification: \(astReport.fileReports.flatMap(\.issues).map(\.message))"
        )
        XCTAssertGreaterThanOrEqual(astReport.totalFilesVerified, 10)
        XCTAssertGreaterThan(astReport.totalLinesVerified, 3_000)
        XCTAssertEqual(astReport.totalErrorCount, 0)
        XCTAssertTrue(astReport.crossFileDuplicateTypes.isEmpty)

        let coreDir = repoRoot.appendingPathComponent("Sources/ChiefKitStudioCore")
        let coreReport = ASTSourceVerifier.verifyDirectory(at: coreDir, recursive: true)
        XCTAssertTrue(
            coreReport.isValid,
            "Sources/ChiefKitStudioCore failed structural verification: \(coreReport.fileReports.flatMap(\.issues).map(\.message))"
        )
        XCTAssertGreaterThanOrEqual(coreReport.totalFilesVerified, 15)
        XCTAssertEqual(coreReport.totalErrorCount, 0)
    }
}
