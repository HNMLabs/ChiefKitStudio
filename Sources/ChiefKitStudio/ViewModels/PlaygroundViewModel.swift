#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitAST
import ChiefKitBlueprints
import ChiefKitDesignSystem
import ChiefKitSecurity
import ChiefKitStudioCore
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class PlaygroundViewModel: ObservableObject {
    // MARK: - Navigation, Blueprints & Custom Snippets
    @Published var selection: NavigationSelection = .package(.swiftBlocks)
    @Published var selectedCategory: ExampleCategory = .all
    @Published var searchText = ""
    @Published var blueprintConfig = BlueprintConfiguration()
    @Published var activeEnterpriseLayers: Set<EnterpriseLayerKind> = Set(EnterpriseLayerKind.allCases)
    @Published var pinnedSnippets: [SavedSnippet] = []

    // MARK: - Right Inspector & Code Panel
    @Published var rightInspectorTab: RightInspectorTab = .code
    @Published var codePreviewMode: CodePreviewMode = .swiftUI
    @Published var tokenExportFormat: TokenExportFormat = .swiftBlocks
    @Published var aiOverriddenCode: [NavigationSelection: String] = [:]
    @Published var generatedUnitTestsBySelection: [NavigationSelection: String] = [:]

    // MARK: - SwiftBlocks Drag-and-Drop Canvas + Undo/Redo
    @Published var canvasDocument: CanvasDocument
    @Published var canvasHistory = CanvasHistoryStack()
    @Published var selectedCanvasNodeID: UUID?
    @Published var snapCanvasToGrid = true
    @Published var canvasLayoutMode: CanvasCodeLayoutMode = .adaptiveStacks
    @Published var focusSelectedNodeCode = false
    @Published var autoCraftPrompt = ""

    // MARK: - Theme & Token Explorer
    @Published var themeTokens = StudioThemeTokens()
    @Published var activeThemePreset: StudioThemePreset = .chiefKitBlue

    // MARK: - SwiftState & Time-Travel Store
    @Published var counter = 0
    @Published var isLoading = false
    @Published var loadedMessage: String?
    @Published var cartItems: [CartDemoItem] = PlaygroundViewModel.defaultCartItems
    @Published var promoApplied = false
    @Published var timeline: [TimelineEvent] = []
    @Published var stateHistory: [StateSnapshot] = []
    @Published var currentHistoryIndex = 0
    @Published var isTimeTravelVisible = false
    @Published var isReplayingHistory = false
    private var isScrubbingTimeTravel = false

    // MARK: - NotebookFlowKit Runner & Visual Builder
    @Published var flowJSON = DemoLibrary.defaultFlowJSON
    @Published var activeFlowStepIndex = 0
    @Published var flowAnswers: [String: String] = [:]

    // MARK: - CoreLocalAIKit On-Device Assistant
    @Published var aiPrompt = ""
    @Published var aiBackendMode: LocalAIBackendMode = .naturalLanguageAST
    @Published var isAIRunning = false
    @Published var latestAIResponse: LocalAIResponse?
    @Published var aiHistory: [LocalAIResponse] = []
    private let aiEngine = LocalAIEngine()

    // MARK: - Preview Modes, Command Palette & Sheets
    @Published var previewConfig = PreviewConfiguration()
    @Published var isCommandPalettePresented = false
    @Published var commandPaletteQuery = ""
    @Published var isProjectGeneratorPresented = false
    @Published var statusMessage = "Ready — Explore 8 Studio 3.0 Workbenches, 28 Enterprise Blueprints, or press ⌘K"

    static let defaultCartItems: [CartDemoItem] = [
        CartDemoItem(id: "pro-seat", name: "ChiefKit Team Seat", price: 29, quantity: 2),
        CartDemoItem(id: "ai-pack", name: "On-Device CoreML Pack", price: 19, quantity: 1)
    ]

    init() {
        let starterDoc = CanvasDocument.starter(radius: 12)
        self.canvasDocument = starterDoc
        self.selectedCanvasNodeID = starterDoc.nodes.first?.id

        let initialSnapshot = StateSnapshot(
            index: 0,
            action: ".initial",
            summary: "count: 0 · cart: 3 items",
            counter: 0,
            isLoading: false,
            loadedMessage: nil,
            cartItems: Self.defaultCartItems,
            promoApplied: false,
            activeFlowStepIndex: 0
        )
        self.stateHistory = [initialSnapshot]
        self.timeline = [
            TimelineEvent(action: ".initial", state: "count: 0")
        ]
    }

    // MARK: - Enterprise Blueprint Layer Controls

    var orderedEnterpriseLayers: [EnterpriseLayerKind] {
        let ordered = EnterpriseLayerKind.allCases.filter { activeEnterpriseLayers.contains($0) }
        return ordered.isEmpty ? [.swiftBlocksUI] : ordered
    }

    func toggleEnterpriseLayer(_ layer: EnterpriseLayerKind) {
        if activeEnterpriseLayers.contains(layer) {
            if activeEnterpriseLayers.count > 1 {
                activeEnterpriseLayers.remove(layer)
            }
        } else {
            activeEnterpriseLayers.insert(layer)
        }
        statusMessage = "Enterprise Blueprint layers: \(orderedEnterpriseLayers.count)/\(EnterpriseLayerKind.allCases.count) active"
    }

    // MARK: - Filtered Sidebar Collections

    var filteredWorkbenches: [StudioWorkbenchKind] {
        StudioWorkbenchKind.allCases.filter { wb in
            let categoryMatch = selectedCategory == .all || wb.category == selectedCategory
            return categoryMatch && matches(wb.title, wb.subtitle, wb.category.rawValue)
        }
    }

    var filteredPackages: [PackageDemo] {
        PackageDemo.allCases.filter { pkg in
            let categoryMatch = selectedCategory == .all || pkg.category == selectedCategory
            return categoryMatch && matches(pkg.title, pkg.purpose, pkg.highlightedAPIs.joined(separator: " "))
        }
    }

    var filteredEnterpriseBlueprints: [EnterpriseBlueprintSpec] {
        EnterpriseBlueprintCatalog.allSpecs.filter { spec in
            let categoryMatch = selectedCategory == .all || selectedCategory == .blueprints
            let platforms = spec.supportedPlatforms.map(\.displayName).joined(separator: " ")
            return categoryMatch && matches(
                spec.title,
                spec.subtitle,
                spec.vertical.title,
                spec.id.rawValue,
                platforms
            )
        }
    }

    var filteredBlueprints: [BlueprintDomain] {
        BlueprintDomain.allCases.filter { domain in
            let categoryMatch = selectedCategory == .all || selectedCategory == .blueprints
            return categoryMatch && matches(domain.title, domain.summary, domain.entityName)
        }
    }

    var filteredTemplates: [TemplateKind] {
        TemplateKind.allCases.filter { kind in
            let categoryMatch = selectedCategory == .all || kind.category == selectedCategory
            return categoryMatch && matches(kind.title, kind.summary, kind.category.rawValue)
        }
    }

    var filteredPinnedSnippets: [SavedSnippet] {
        pinnedSnippets.filter { snippet in
            let categoryMatch = selectedCategory == .all || snippet.category == selectedCategory
            return categoryMatch && matches(snippet.title, snippet.notes)
        }
    }

    func pinnedSnippet(for id: UUID) -> SavedSnippet? {
        pinnedSnippets.first { $0.id == id }
    }

    var selectionDisplayTitle: String {
        switch selection {
        case .savedSnippet(let id):
            return pinnedSnippet(for: id)?.title ?? selection.title
        case .enterpriseBlueprint(let rawID):
            if let bpID = EnterpriseBlueprintID(rawValue: rawID) {
                return EnterpriseBlueprintCatalog.spec(for: bpID).title
            }
            return selection.title
        default:
            return selection.title
        }
    }

    var selectionSubtitle: String {
        switch selection {
        case .savedSnippet(let id):
            return pinnedSnippet(for: id)?.notes ?? selection.subtitle
        case .enterpriseBlueprint(let rawID):
            if let bpID = EnterpriseBlueprintID(rawValue: rawID) {
                let spec = EnterpriseBlueprintCatalog.spec(for: bpID)
                return "\(spec.vertical.title) — \(spec.subtitle)"
            }
            return selection.subtitle
        default:
            return selection.subtitle
        }
    }

    // MARK: - What You're Learning Metadata

    var currentLearningHeadline: String {
        switch selection {
        case .package(let pkg):
            return pkg.learningHeadline
        case .workbench(let wb):
            return workbenchLearningHeadline(for: wb)
        case .template(let kind):
            return DemoLibrary.templateExample(for: kind, theme: themeTokens).explanation
        case .blueprint(let domain):
            return "Compose a cohesive multi-package \(domain.title) architecture uniting SwiftBlocks, SwiftState, NotebookFlowKit, and CoreLocalAIKit."
        case .enterpriseBlueprint(let rawID):
            let bpID = EnterpriseBlueprintID(rawValue: rawID) ?? .neobankMultiCurrencyTreasury
            let spec = EnterpriseBlueprintCatalog.spec(for: bpID)
            return "Explore and export the 8-layer \(spec.title) (\(spec.vertical.title)) enterprise blueprint into a 14-file Swift 6 workspace."
        case .savedSnippet(let id):
            return pinnedSnippet(for: id)?.notes ?? "Custom SwiftUI snippet saved to your ChiefKit Studio workspace."
        }
    }

    var currentLearningPoints: [String] {
        switch selection {
        case .package(let pkg):
            return pkg.learningKeyPoints
        case .workbench(let wb):
            return workbenchLearningPoints(for: wb)
        case .template(let kind):
            return DemoLibrary.templateExample(for: kind, theme: themeTokens).learningPoints
        case .blueprint:
            return [
                "Toggle architectural layers (UI, Store, Onboarding, Local AI, @Test) and watch code adapt live",
                "Export the entire multi-layer blueprint with bundled tests in one click (⌘⇧E)",
                "Save your tailored blueprint & tokens into a portable .chiefkit workspace (⌘S)"
            ]
        case .enterpriseBlueprint(let rawID):
            let bpID = EnterpriseBlueprintID(rawValue: rawID) ?? .neobankMultiCurrencyTreasury
            let spec = EnterpriseBlueprintCatalog.spec(for: bpID)
            return [
                "Inspect \(spec.domainEntities.count) SwiftData @Model entities, \(spec.reducerActions.count) deterministic Reducer actions, and \(spec.apiEndpoints.count) REST endpoints",
                "Toggle any of the 8 enterprise layers (SwiftBlocks UI, Reducer, SwiftData, REST API, Onboarding, Local AI, Privacy, @Test)",
                "Export a complete 14-file Swift 6 SwiftPM package (~saves \(spec.complexityTier.estimatedWeeksSaved) engineering weeks) in one click"
            ]
        case .savedSnippet:
            return [
                "Edit or enhance pinned snippets using CoreLocalAIKit in the right inspector",
                "Compare baseline vs enhanced code in the Live Diff tab",
                "Persist pinned snippets across sessions with Save Workspace (.chiefkit)"
            ]
        }
    }

    var currentHighlightedAPIs: [String] {
        switch selection {
        case .package(let pkg):
            return pkg.highlightedAPIs
        case .workbench(let wb):
            return workbenchHighlightedAPIs(for: wb)
        case .template(let kind):
            return DemoLibrary.templateExample(for: kind, theme: themeTokens).highlightedAPIs
        case .blueprint:
            return ["EDKSurface", "Reducer", "NotebookFlowView", "NLLanguageRecognizer", "@Test"]
        case .enterpriseBlueprint(let rawID):
            let bpID = EnterpriseBlueprintID(rawValue: rawID) ?? .neobankMultiCurrencyTreasury
            let spec = EnterpriseBlueprintCatalog.spec(for: bpID)
            let entityName = spec.domainEntities.first?.name ?? "@Model"
            return [entityName, "BlueprintWorkspaceExporter", "@Model", "PrivacyInfo.xcprivacy", "@Test"]
        case .savedSnippet:
            return ["View", "EDKTheme", "@ScaledMetric"]
        }
    }

    private func workbenchLearningHeadline(for wb: StudioWorkbenchKind) -> String {
        switch wb {
        case .astCompiler:
            return "Tokenize, parse, refactor, audit across 38 static rules, and round-trip SwiftUI views to and from the visual canvas."
        case .animationAndPhysics:
            return "Solve analytical and 4th-order Runge-Kutta (RK4) spring equations, sculpt cubic-bezier curves, and emit PhaseAnimator/KeyframeAnimator code."
        case .multiArtboardAndSVG:
            return "Compare responsive layouts across 5 Apple device viewports with deterministic auto-layout solving and 42 W3C SVG vector shapes."
        case .componentCatalog64:
            return "Browse all 64 SwiftBlocks 3.0 components backed by OKLCH perceptual tonal scales, APCA Lc contrast, CVD simulation, and 8 token targets."
        case .dataAndAPISchema:
            return "Model 3NF relational schemas and compile SwiftData @Model, SQLite3 STRICT DDL, CoreData XML, OpenAPI 3.1, GraphQL, and mock HTTP responses."
        case .localizationCatalog:
            return "Author Apple .xcstrings String Catalogs across 10 locales with CLDR plural rules, pseudolocalization stress modes, RTL mirroring, and typed L10n."
        case .securityAndEphemeris:
            return "Combine NIST/RFC pure-Swift SHA-2/HKDF/XChaCha20-Poly1305 vaults, Shamir GF(256) secret sharing, 30 OWASP rules, and EphemerisCore planetary TOTP."
        case .performanceProfiler:
            return "Simulate 60Hz, 90Hz visionOS, and 120Hz ProMotion frame budgets, patch Metal offscreen compositing hazards, and graph @Observable blast radius."
        }
    }

    private func workbenchLearningPoints(for wb: StudioWorkbenchKind) -> [String] {
        switch wb {
        case .astCompiler:
            return [
                "Run 6 deterministic AST refactoring passes (@Observable migration, tokenizing magic literals, VoiceOver injection)",
                "Import arbitrary SwiftUI VStack/HStack/ZStack hierarchies onto the interactive SwiftBlocks Canvas",
                "Evaluate Halstead volume, cyclomatic/cognitive complexity, and synthesize @Test suites automatically"
            ]
        case .animationAndPhysics:
            return [
                "Compare closed-form damped harmonic oscillator curves against numerical RK4 integration with air drag",
                "Scrub multi-track KeyframeTimeline animations combining spring, cubic-bezier, linear, and discrete steps",
                "Export ready-to-paste SwiftUI PhaseAnimator, KeyframeAnimator, or calibrated .spring(...) modifiers"
            ]
        case .multiArtboardAndSVG:
            return [
                "Solve constraint layouts simultaneously on iPhone 16 Pro, iPad Pro 13\", MacBook Pro 16\", Vision Pro & Watch Ultra 2",
                "Inspect ASCII/SVG layout wireframes, overflow warnings, and Compact vs Regular size-class adaptations",
                "Parse W3C SVG path commands (M/L/H/V/C/S/Q/T/A/Z) and emit normalized SwiftUI Shape structs"
            ]
        case .componentCatalog64:
            return [
                "Filter 64 accessible SwiftBlocks across Primitives, Inputs, Navigation, Data, Charts, Commerce, AI & Spatial",
                "Verify perceptual lightness across 11 OKLCH tonal stops (50–950), APCA Lc contrast, and 7 color-blindness matrices",
                "Compile semantic design tokens simultaneously to SwiftUI, UIKit, AppKit, W3C JSON, CSS, Tailwind, Compose & Asset Catalog"
            ]
        case .dataAndAPISchema:
            return [
                "Switch between 6 domain ER schemas and inspect 3NF normalization scores and missing foreign-key index advisories",
                "Synthesize SwiftData @Model classes, SQLite3 STRICT WAL migrations, OpenAPI 3.1 JSON, and GraphQL SDL",
                "Dispatch simulated REST requests against deterministic CRUD endpoints with realistic latency and JSON payloads"
            ]
        case .localizationCatalog:
            return [
                "Extract translatable SwiftUI Text/Button/Label literals directly into an Apple Xcode 15+ .xcstrings catalog",
                "Test Arabic/Hebrew RTL layout mirroring, CLDR plural categories, and Accented/Expanded/RTL pseudolocalization",
                "Audit format-specifier parity (%lld, %@) across locales and generate compile-time-safe enum L10n accessors"
            ]
        case .securityAndEphemeris:
            return [
                "Compute live 9-body planetary ephemerides (VSOP87/Meeus) + geodetic topocentric coordinates for Celestial-TOTP auth",
                "Seal portable .chiefkit.vault payloads with PBKDF2 + XChaCha20-Poly1305 and split keys into 3-of-5 Shamir GF(256) shares",
                "Scan Swift code against 30 OWASP Mobile Top 10 rules and auto-infer App Store PrivacyInfo.xcprivacy XML"
            ]
        case .performanceProfiler:
            return [
                "Break down per-frame CPU view diffing, layout passes, CoreAnimation commits, and Metal GPU offscreen passes",
                "Auto-patch .shadow/.blur/.mask GPU compositing hazards with .drawingGroup() and equatable subview boundaries",
                "Analyze @State, @Environment, and @Observable read/write dependencies to minimize view invalidation blast radius"
            ]
        }
    }

    private func workbenchHighlightedAPIs(for wb: StudioWorkbenchKind) -> [String] {
        switch wb {
        case .astCompiler:
            return ["ChiefKitASTModule", "ASTCanvasBridge", "ASTTransformationEngine", "ASTStaticAuditEngine", "ASTTestSynthesizer"]
        case .animationAndPhysics:
            return ["SpringParameters", "RK4SpringIntegrator", "CubicBezierCurve", "AnimationTimeline", "PhaseAnimator"]
        case .multiArtboardAndSVG:
            return ["ArtboardDevicePreset", "AutoLayoutConstraintSolver", "SVGPathEngine", "ChiefKitVectorIcon", "Shape"]
        case .componentCatalog64:
            return ["SwiftBlockCatalog", "OKLCHColor", "APCAEvaluation", "ColorBlindnessKind", "DesignTokenCompiler"]
        case .dataAndAPISchema:
            return ["DataSchemaWorkspace", "PersistenceCodeSynthesizer", "APISpecAndMockEngine", "@Model", "OpenAPI 3.1"]
        case .localizationCatalog:
            return ["LocalizationCatalog", "StringCatalogCompiler", "Pseudolocalizer", "CLDRPluralCategory", "L10n"]
        case .securityAndEphemeris:
            return ["EphemerisSkySnapshot", "EphemerisEntropyProtocol", "EncryptedWorkspaceVault", "ShamirSecretSharing", "StaticSecurityScanner"]
        case .performanceProfiler:
            return ["FrameBudgetProfiler", "DisplayRefreshTarget", "FlamegraphNode", "StateInvalidationAnalyzer", "@Observable"]
        }
    }

    // MARK: - Live Code Generation, Diff & Quality Scorecard

    var hasAIOverrideForCurrentSelection: Bool {
        aiOverriddenCode[selection] != nil
    }

    var selectedCanvasNode: CanvasNode? {
        guard let selectedCanvasNodeID else { return nil }
        return canvasDocument.nodes.first { $0.id == selectedCanvasNodeID }
    }

    var baselineSwiftUICode: String {
        switch selection {
        case .package(.swiftBlocks):
            return canvasDocument.generateSwiftUICode(
                theme: themeTokens,
                layoutMode: canvasLayoutMode,
                focusedNodeID: selectedCanvasNodeID,
                focusSelectedOnly: focusSelectedNodeCode
            )
        case .package(.swiftState):
            return DemoLibrary.liveSwiftStateCode(
                counter: counter,
                isLoading: isLoading,
                loadedMessage: loadedMessage
            )
        case .package(.notebookFlowKit):
            let title = (try? FlowDefinition.decode(flowJSON).get().title) ?? "Launch Onboarding"
            return DemoLibrary.notebookUsageCode(flowTitle: title)
        case .package(.coreLocalAIKit):
            return DemoLibrary.coreLocalAIKitUsageCode
        case .workbench(let wb):
            return baselineWorkbenchCode(for: wb)
        case .template(let kind):
            return DemoLibrary.templateExample(for: kind, theme: themeTokens).swiftUICode
        case .blueprint(let domain):
            return blueprintConfig.synthesizeSwiftUICode(for: domain, theme: themeTokens)
        case .enterpriseBlueprint(let rawID):
            let bpID = EnterpriseBlueprintID(rawValue: rawID) ?? .neobankMultiCurrencyTreasury
            let spec = EnterpriseBlueprintCatalog.spec(for: bpID)
            return spec.synthesizeSwiftUIView(theme: themeTokens, layers: orderedEnterpriseLayers)
        case .savedSnippet(let id):
            return pinnedSnippet(for: id)?.swiftUICode ?? "// Snippet not found"
        }
    }

    private func baselineWorkbenchCode(for wb: StudioWorkbenchKind) -> String {
        switch wb {
        case .astCompiler:
            return ASTCanvasBridge.exportToFormattedSwift(
                document: canvasDocument,
                structName: "ASTLabCanvasView",
                theme: themeTokens
            ).formattedSource
        case .animationAndPhysics:
            return AnimationTimeline.synthesizePhaseAnimatorCode(
                structName: "LiquidGlassPhaseBanner",
                spring: .snappy
            )
        case .multiArtboardAndSVG:
            return ChiefKitVectorIcon.liquidGlassCube.emitSwiftUIShape(structName: "LiquidGlassCubeShape")
        case .componentCatalog64:
            return SwiftBlockCatalog.synthesizeCode(
                for: .virtualCardGlassView,
                theme: themeTokens,
                variant: "glass",
                state: .hovered
            )
        case .dataAndAPISchema:
            return PersistenceCodeSynthesizer.synthesize(
                workspace: .preset(.fintechDoubleEntry),
                backend: .swiftData
            ).sourceCode
        case .localizationCatalog:
            return StringCatalogCompiler.synthesizeL10nSwiftEnum(
                from: StudioBuiltInTranslations.catalog(for: .studioCoreUI),
                enumName: "L10n"
            )
        case .securityAndEphemeris:
            return EphemerisAuthenticatorCodeSynthesizer.synthesizeSwift6ActorSource(
                actorName: "CelestialSessionAuthenticator",
                config: .highSecurityGeodetic30s
            )
        case .performanceProfiler:
            return canvasDocument.generateSwiftUICode(
                theme: themeTokens,
                layoutMode: canvasLayoutMode,
                focusedNodeID: nil,
                focusSelectedOnly: false
            )
        }
    }

    var selectedSwiftUICode: String {
        if let overridden = aiOverriddenCode[selection] {
            return overridden
        }
        if case .package(.coreLocalAIKit) = selection, let latest = latestAIResponse {
            return latest.generatedCode
        }
        return baselineSwiftUICode
    }

    var selectedUnitTestsCode: String {
        if let customTests = generatedUnitTestsBySelection[selection] {
            return customTests
        }
        switch selection {
        case .blueprint(let domain):
            return blueprintConfig.synthesizeSwiftTests(for: domain)
        case .enterpriseBlueprint(let rawID):
            let bpID = EnterpriseBlueprintID(rawValue: rawID) ?? .neobankMultiCurrencyTreasury
            return EnterpriseBlueprintCatalog.spec(for: bpID).synthesizeSwiftTests()
        case .workbench(.astCompiler):
            return ASTTestSynthesizer.synthesize(
                source: baselineSwiftUICode,
                moduleUnderTest: "ChiefKitApp",
                framework: .swiftTesting
            ).generatedCode
        case .workbench(.securityAndEphemeris):
            return SecurityAuditReportSynthesizer.synthesizeSecurityRegressionTestSuite(
                workspaceName: "ChiefKitSecurityVault",
                ephemerisConfig: .highSecurityGeodetic30s
            )
        default:
            return """
            import Testing

            @Suite("\(selectionDisplayTitle) Verification")
            struct GeneratedQuickTests {
                @Test("Theme primary token satisfies WCAG contrast check")
                func primaryTokenContrast() {
                    let ratio = \(String(format: "%.2f", themeTokens.contrastReport.primaryOnSurfaceRatio))
                    #expect(ratio >= 3.0)
                }
            }
            """
        }
    }

    var currentDiffReport: DiffReport {
        CodeDiffEngine.diff(original: baselineSwiftUICode, updated: selectedSwiftUICode)
    }

    var currentQualityReport: CodeQualityReport {
        CodeQualityAnalyzer.analyze(code: selectedSwiftUICode, theme: themeTokens)
    }

    var selectedDependencyCode: String {
        DemoLibrary.packageSnippet(for: selection, blueprint: blueprintConfig)
    }

    var selectedDataPreview: String {
        switch selection {
        case .package(.swiftState), .template(.shoppingCartStore), .template(.apiLoadingState):
            return stateJSONPreview
        case .package(.notebookFlowKit), .template(.onboardingFlow), .template(.quizFlow):
            return flowJSON
        case .blueprint(let domain):
            return blueprintConfig.synthesizeFlowJSON(for: domain)
        case .enterpriseBlueprint(let rawID):
            let bpID = EnterpriseBlueprintID(rawValue: rawID) ?? .neobankMultiCurrencyTreasury
            return EnterpriseBlueprintCatalog.spec(for: bpID).synthesizeOnboardingFlowJSON()
        case .workbench(let wb):
            return workbenchDataPreview(for: wb)
        case .package(.swiftBlocks):
            return canvasJSONPreview
        case .package(.coreLocalAIKit):
            return aiTelemetryJSONPreview
        case .template(let kind):
            return DemoLibrary.templateExample(for: kind, theme: themeTokens).explanation
        case .savedSnippet(let id):
            return pinnedSnippet(for: id)?.notes ?? "{}"
        }
    }

    private func workbenchDataPreview(for wb: StudioWorkbenchKind) -> String {
        switch wb {
        case .astCompiler:
            let snap = ChiefKitASTModule.analyzePipeline(source: selectedSwiftUICode, theme: themeTokens)
            return prettyJSON([
                "tokens": snap.tokenSummary.totalTokens,
                "viewNodes": snap.sourceFile.allViewNodes().count,
                "auditScore": snap.auditReport.overallScore,
                "rulesEvaluated": snap.auditReport.totalRuleCount,
                "maintainabilityGrade": snap.metricsReport.maintainabilityGrade
            ])
        case .animationAndPhysics:
            let spring = SpringAnalysisReport(parameters: .snappy)
            return prettyJSON([
                "regime": spring.regime.rawValue,
                "settlingDurationSec": spring.settlingDurationSeconds,
                "peakOvershootPercent": spring.peakOvershootPercent,
                "rk4AnalyticalRMSError": spring.rk4AnalyticalRMSError
            ])
        case .multiArtboardAndSVG:
            return prettyJSON([
                "artboardPresets": ArtboardDevicePreset.allCases.map(\.displayName),
                "svgCatalogCount": ChiefKitVectorIcon.allCases.count,
                "canvasNodes": canvasDocument.nodes.count
            ])
        case .componentCatalog64:
            return DesignTokenCompiler.compile(tokens: themeTokens, target: .w3cJSON, namespace: "ChiefKit")
        case .dataAndAPISchema:
            let service = APIServiceSpec.deriveCRUDService(from: .preset(.fintechDoubleEntry))
            return APISpecAndMockEngine.compileOpenAPI31JSON(service)
        case .localizationCatalog:
            let catalog = StudioBuiltInTranslations.catalog(for: .studioCoreUI)
            return (try? catalog.encodeXCStringsJSON()) ?? "{}"
        case .securityAndEphemeris:
            let manifest = ApplePrivacyManifestBuilder.inferCompliantManifest(fromSwiftSources: [selectedSwiftUICode])
            return manifest.compilePrivacyInfoPlistXML()
        case .performanceProfiler:
            let profile = FrameBudgetProfiler.profile(
                swiftUISource: selectedSwiftUICode,
                canvas: canvasDocument,
                theme: themeTokens,
                target: .proMotion120Hz
            )
            return prettyJSON([
                "target": profile.target.rawValue,
                "budgetMs": profile.budgetMs,
                "totalFrameTimeMs": profile.totalFrameTimeMs,
                "meetsFrameBudget": profile.meetsFrameBudget,
                "grade": profile.performanceGrade
            ])
        }
    }

    var codePanelText: String {
        switch codePreviewMode {
        case .swiftUI:
            return selectedSwiftUICode
        case .diff:
            return currentDiffReport.unifiedPatch
        case .tests:
            return selectedUnitTestsCode
        case .package:
            return selectedDependencyCode
        case .theme:
            return themeTokens.exportedCode(in: tokenExportFormat)
        case .data:
            return selectedDataPreview
        }
    }

    var stateJSONPreview: String {
        let cartTotal = computedCartTotal
        let dict: [String: Any] = [
            "count": counter,
            "isLoading": isLoading,
            "message": loadedMessage ?? NSNull(),
            "promoApplied": promoApplied,
            "cartTotalUSD": cartTotal,
            "cartItemCount": cartItems.reduce(0) { $0 + $1.quantity },
            "historyStep": "\(currentHistoryIndex + 1)/\(stateHistory.count)",
            "activeFlowStep": activeFlowStepIndex
        ]
        return prettyJSON(dict)
    }

    var canvasJSONPreview: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(canvasDocument),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "{}"
    }

    var aiTelemetryJSONPreview: String {
        let dict: [String: Any] = [
            "engine": aiBackendMode.rawValue,
            "networkCalls": 0,
            "appleIntelligenceCompiled": LocalAIEngine.isAppleIntelligenceCompiled,
            "historyRuns": aiHistory.count,
            "qualityScore": currentQualityReport.overallScore,
            "lastDetectedLanguage": latestAIResponse?.detectedLanguage ?? "Auto (EN / TR)"
        ]
        return prettyJSON(dict)
    }

    var computedCartSubtotal: Int {
        cartItems.reduce(0) { $0 + ($1.price * $1.quantity) }
    }

    var computedCartTotal: Int {
        let sub = computedCartSubtotal
        return promoApplied ? Int((Double(sub) * 0.80).rounded()) : sub
    }

    // MARK: - Navigation Actions

    func select(_ nextSelection: NavigationSelection) {
        selection = nextSelection
        if case .blueprint(let domain) = nextSelection {
            blueprintConfig.domain = domain
        }
        statusMessage = "Showing \(selectionDisplayTitle)"
    }

    func revertAIOverride() {
        aiOverriddenCode.removeValue(forKey: selection)
        statusMessage = "Restored baseline \(selectionDisplayTitle) code"
    }

    // MARK: - Custom Pinned Snippets & Workspace (.chiefkit) Persistence

    func pinCurrentSnippet() {
        let title = "\(selectionDisplayTitle) #\(pinnedSnippets.count + 1)"
        let snippet = SavedSnippet(
            title: title,
            notes: "Pinned from \(selectionDisplayTitle) · Quality \(currentQualityReport.overallScore)/100 (\(currentQualityReport.gradeBadge))",
            category: selection.category == .all ? .designSystem : selection.category,
            swiftUICode: selectedSwiftUICode
        )
        pinnedSnippets.insert(snippet, at: 0)
        statusMessage = "Pinned '\(title)' to My Snippets"
    }

    func deletePinnedSnippet(_ id: UUID) {
        pinnedSnippets.removeAll { $0.id == id }
        if selection == .savedSnippet(id) {
            selection = .package(.swiftBlocks)
        }
        statusMessage = "Removed pinned snippet"
    }

    func makeWorkspaceSnapshot() -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            selection: selection,
            canvasDocument: canvasDocument,
            themeTokens: themeTokens,
            activeThemePreset: activeThemePreset,
            flowJSON: flowJSON,
            counter: counter,
            cartItems: cartItems,
            promoApplied: promoApplied,
            blueprintConfig: blueprintConfig,
            pinnedSnippets: pinnedSnippets
        )
    }

    func applyWorkspaceSnapshot(_ snapshot: WorkspaceSnapshot) {
        selection = snapshot.selection
        canvasDocument = snapshot.canvasDocument
        selectedCanvasNodeID = snapshot.canvasDocument.nodes.first?.id
        canvasHistory.clear()
        themeTokens = snapshot.themeTokens
        activeThemePreset = snapshot.activeThemePreset
        flowJSON = snapshot.flowJSON
        counter = snapshot.counter
        cartItems = snapshot.cartItems
        promoApplied = snapshot.promoApplied
        blueprintConfig = snapshot.blueprintConfig
        pinnedSnippets = snapshot.pinnedSnippets
        clearStateHistory()
    }

    func saveWorkspaceToDisk() {
        do {
            if let url = try ExportService.saveWorkspace(makeWorkspaceSnapshot()) {
                statusMessage = "Saved workspace to \(url.lastPathComponent)"
            }
        } catch {
            statusMessage = "Workspace save failed: \(error.localizedDescription)"
        }
    }

    func loadWorkspaceFromDisk() {
        do {
            if let loaded = try ExportService.openWorkspace() {
                applyWorkspaceSnapshot(loaded.snapshot)
                statusMessage = "Loaded workspace \(loaded.url.lastPathComponent)"
            }
        } catch {
            statusMessage = "Workspace open failed: \(error.localizedDescription)"
        }
    }

    // MARK: - SwiftBlocks Canvas Actions + Undo/Redo + Alignment

    var canUndoCanvas: Bool { canvasHistory.canUndo }
    var canRedoCanvas: Bool { canvasHistory.canRedo }

    func undoCanvas() {
        guard let prev = canvasHistory.undo(current: canvasDocument) else { return }
        canvasDocument = prev
        if let id = selectedCanvasNodeID, !canvasDocument.nodes.contains(where: { $0.id == id }) {
            selectedCanvasNodeID = canvasDocument.nodes.last?.id
        }
        statusMessage = "Undid canvas edit"
    }

    func redoCanvas() {
        guard let next = canvasHistory.redo(current: canvasDocument) else { return }
        canvasDocument = next
        statusMessage = "Redid canvas edit"
    }

    func recordCanvasUndoCheckpoint() {
        canvasHistory.recordBeforeMutation(canvasDocument)
    }

    func addPaletteItem(_ item: CanvasPaletteItem, at point: CGPoint? = nil) {
        recordCanvasUndoCheckpoint()
        var node = item.makeNode(defaultRadius: themeTokens.radiusMedium)
        if let point {
            let rawFrame = CanvasFrame(
                x: Double(point.x) - node.frame.width / 2,
                y: Double(point.y) - node.frame.height / 2,
                width: node.frame.width,
                height: node.frame.height
            )
            node.frame = snapCanvasToGrid
                ? rawFrame.movedBy(dx: 0, dy: 0, snapToGrid: true)
                : rawFrame
        } else {
            let offset = Double(canvasDocument.nodes.count % 5) * 20.0
            node.frame.x += offset
            node.frame.y += offset
        }
        canvasDocument.nodes.append(node)
        selectedCanvasNodeID = node.id
        statusMessage = "Added \(item.kind.paletteTitle) to canvas"
    }

    @discardableResult
    func handleCanvasDrop(payload: String, at location: CGPoint, canvasSize: CGSize) -> Bool {
        if payload.hasPrefix("palette:") {
            let id = String(payload.dropFirst("palette:".count))
            if let item = CanvasPaletteItem.library.first(where: { $0.id == id }) {
                addPaletteItem(item, at: location)
                if let lastID = canvasDocument.nodes.last?.id,
                   let idx = canvasDocument.nodes.firstIndex(where: { $0.id == lastID }) {
                    canvasDocument.nodes[idx].frame = canvasDocument.nodes[idx].frame.clamped(to: canvasSize)
                }
                return true
            }
        }
        return false
    }

    func applyAutoCraftPreset(_ preset: CanvasAutoCraftPreset) {
        recordCanvasUndoCheckpoint()
        let built = preset.buildNodes(radius: themeTokens.radiusMedium)
        canvasDocument.nodes = built
        selectedCanvasNodeID = built.first?.id
        aiOverriddenCode.removeValue(forKey: .package(.swiftBlocks))
        statusMessage = "Auto-crafted '\(preset.rawValue)' (\(built.count) blocks)"
    }

    func runAutoCraftFromPrompt() {
        let text = autoCraftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            applyAutoCraftPreset(.glassDashboard)
            return
        }
        let lower = text.lowercased()
        if lower.contains("login") || lower.contains("auth") || lower.contains("sign") || lower.contains("giriş") {
            applyAutoCraftPreset(.authCard)
        } else if lower.contains("onboard") || lower.contains("welcome") || lower.contains("karşılama") {
            applyAutoCraftPreset(.onboardingStack)
        } else if lower.contains("price") || lower.contains("upgrade") || lower.contains("pro") || lower.contains("fiyat") {
            applyAutoCraftPreset(.pricingBanner)
        } else {
            recordCanvasUndoCheckpoint()
            var custom = CanvasAutoCraftPreset.glassDashboard.buildNodes(radius: themeTokens.radiusMedium)
            if !custom.isEmpty {
                custom[0].title = String(text.prefix(34))
            }
            canvasDocument.nodes = custom
            selectedCanvasNodeID = custom.first?.id
            statusMessage = "Crafted layout for \"\(text)\""
        }
    }

    func selectCanvasNode(_ id: UUID?) {
        selectedCanvasNodeID = id
        if let node = selectedCanvasNode {
            statusMessage = "Selected \(node.kind.paletteTitle): \"\(node.title)\""
        }
    }

    func updateCanvasNodeFrame(id: UUID, frame: CanvasFrame) {
        guard let index = canvasDocument.nodes.firstIndex(where: { $0.id == id }),
              !canvasDocument.nodes[index].isLocked else { return }
        canvasDocument.nodes[index].frame = frame
    }

    func updateSelectedCanvasNode(_ mutate: (inout CanvasNode) -> Void) {
        guard let id = selectedCanvasNodeID,
              let index = canvasDocument.nodes.firstIndex(where: { $0.id == id }) else { return }
        recordCanvasUndoCheckpoint()
        mutate(&canvasDocument.nodes[index])
    }

    func alignSelectedCanvasNode(_ axis: CanvasAlignmentAxis, canvasSize: CGSize) {
        guard let id = selectedCanvasNodeID else { return }
        recordCanvasUndoCheckpoint()
        canvasDocument.alignNode(id: id, axis: axis, canvasSize: canvasSize)
        statusMessage = "Aligned selected block (\(axis.rawValue))"
    }

    func autoTidyCanvas(maxWidth: Double = 640) {
        guard !canvasDocument.nodes.isEmpty else { return }
        recordCanvasUndoCheckpoint()
        canvasDocument.autoTidyGrid(maxWidth: maxWidth, spacing: Double(themeTokens.spacingMD))
        statusMessage = "Auto-tidied \(canvasDocument.nodes.count) blocks to responsive grid"
    }

    func toggleLockSelectedCanvasNode() {
        guard let id = selectedCanvasNodeID,
              let idx = canvasDocument.nodes.firstIndex(where: { $0.id == id }) else { return }
        recordCanvasUndoCheckpoint()
        canvasDocument.nodes[idx].isLocked.toggle()
        let locked = canvasDocument.nodes[idx].isLocked
        statusMessage = locked ? "Locked block position" : "Unlocked block position"
    }

    func duplicateSelectedCanvasNode() {
        guard let node = selectedCanvasNode else { return }
        recordCanvasUndoCheckpoint()
        var copy = node
        copy.id = UUID()
        copy.isLocked = false
        copy.frame = copy.frame.movedBy(dx: 24, dy: 24, snapToGrid: snapCanvasToGrid)
        canvasDocument.nodes.append(copy)
        selectedCanvasNodeID = copy.id
        statusMessage = "Duplicated \(node.kind.paletteTitle)"
    }

    func bringSelectedNodeToFront() {
        guard let id = selectedCanvasNodeID else { return }
        recordCanvasUndoCheckpoint()
        canvasDocument.moveLayer(id: id, direction: 1)
        statusMessage = "Moved block forward"
    }

    func sendSelectedNodeBackward() {
        guard let id = selectedCanvasNodeID else { return }
        recordCanvasUndoCheckpoint()
        canvasDocument.moveLayer(id: id, direction: -1)
        statusMessage = "Moved block backward"
    }

    func deleteSelectedCanvasNode() {
        guard let id = selectedCanvasNodeID else { return }
        recordCanvasUndoCheckpoint()
        canvasDocument.nodes.removeAll { $0.id == id }
        selectedCanvasNodeID = canvasDocument.nodes.last?.id
        statusMessage = "Removed selected block"
    }

    func clearCanvas() {
        recordCanvasUndoCheckpoint()
        canvasDocument.nodes.removeAll()
        selectedCanvasNodeID = nil
        statusMessage = "Cleared SwiftBlocks canvas"
    }

    // MARK: - Theme & Token Explorer + WCAG Auto-Fix

    func applyThemePreset(_ preset: StudioThemePreset) {
        activeThemePreset = preset
        themeTokens = preset.tokens
        for idx in canvasDocument.nodes.indices where canvasDocument.nodes[idx].kind != .badge {
            canvasDocument.nodes[idx].cornerRadius = preset.tokens.radiusMedium
        }
        statusMessage = "Applied '\(preset.rawValue)' design tokens"
    }

    func autoFixThemeContrast() {
        themeTokens.autoFixPrimaryContrast()
        let ratio = String(format: "%.2f", themeTokens.contrastReport.primaryOnSurfaceRatio)
        statusMessage = "Auto-adjusted Primary Accent to \(themeTokens.primary.hexString) (\(ratio):1 WCAG AA)"
    }

    // MARK: - SwiftState & Time-Travel Actions

    func incrementCounter() {
        counter += 1
        recordStateMutation(action: ".increment")
    }

    func decrementCounter() {
        counter -= 1
        recordStateMutation(action: ".decrement")
    }

    func addCounterStep(_ delta: Int) {
        counter += delta
        recordStateMutation(action: delta >= 0 ? ".add(\(delta))" : ".subtract(\(abs(delta)))")
    }

    func runAsyncSimulation() {
        guard !isLoading else { return }
        isLoading = true
        loadedMessage = nil
        recordStateMutation(action: ".loadButtonTapped")

        Task {
            try? await Task.sleep(for: .milliseconds(850))
            loadedMessage = "Payload #\(counter) synced at \(TimestampClockFormatting.hmsString(from: Date()))"
            isLoading = false
            recordStateMutation(action: ".responseReceived")
        }
    }

    func adjustCartQuantity(itemID: String, delta: Int) {
        guard let idx = cartItems.firstIndex(where: { $0.id == itemID }) else { return }
        let nextQty = max(0, min(20, cartItems[idx].quantity + delta))
        cartItems[idx].quantity = nextQty
        recordStateMutation(action: ".cartQty(\"\(itemID)\", \(nextQty))")
    }

    func togglePromoCode() {
        promoApplied.toggle()
        recordStateMutation(action: promoApplied ? ".applyPromo(\"CHIEF20\")" : ".removePromo")
    }

    var canUndoHistory: Bool {
        currentHistoryIndex > 0
    }

    var canRedoHistory: Bool {
        currentHistoryIndex < stateHistory.count - 1
    }

    func undoHistory() {
        guard canUndoHistory else { return }
        scrubHistory(to: currentHistoryIndex - 1)
    }

    func redoHistory() {
        guard canRedoHistory else { return }
        scrubHistory(to: currentHistoryIndex + 1)
    }

    func scrubHistory(to index: Int) {
        guard stateHistory.indices.contains(index) else { return }
        isScrubbingTimeTravel = true
        let snap = stateHistory[index]
        counter = snap.counter
        isLoading = snap.isLoading
        loadedMessage = snap.loadedMessage
        cartItems = snap.cartItems
        promoApplied = snap.promoApplied
        activeFlowStepIndex = snap.activeFlowStepIndex
        currentHistoryIndex = index
        isScrubbingTimeTravel = false
        statusMessage = "Time-Travel → Step \(index + 1)/\(stateHistory.count) (\(snap.action))"
    }

    func replayHistory() {
        guard !isReplayingHistory, stateHistory.count > 1 else { return }
        isReplayingHistory = true
        scrubHistory(to: 0)

        Task {
            for step in 1..<stateHistory.count {
                try? await Task.sleep(for: .milliseconds(360))
                if !isReplayingHistory { break }
                scrubHistory(to: step)
            }
            isReplayingHistory = false
            statusMessage = "Finished replaying \(stateHistory.count) state transitions"
        }
    }

    func clearStateHistory() {
        let base = StateSnapshot(
            index: 0,
            action: ".baseline",
            summary: "count: \(counter) · total: $\(computedCartTotal)",
            counter: counter,
            isLoading: isLoading,
            loadedMessage: loadedMessage,
            cartItems: cartItems,
            promoApplied: promoApplied,
            activeFlowStepIndex: activeFlowStepIndex
        )
        stateHistory = [base]
        currentHistoryIndex = 0
        statusMessage = "Cleared time-travel history"
    }

    private func recordStateMutation(action: String) {
        guard !isScrubbingTimeTravel else { return }

        if currentHistoryIndex < stateHistory.count - 1 {
            stateHistory.removeSubrange((currentHistoryIndex + 1)...)
        }

        let summary = "count: \(counter) · $\(computedCartTotal)"
        let nextIndex = stateHistory.count
        let snapshot = StateSnapshot(
            index: nextIndex,
            action: action,
            summary: summary,
            counter: counter,
            isLoading: isLoading,
            loadedMessage: loadedMessage,
            cartItems: cartItems,
            promoApplied: promoApplied,
            activeFlowStepIndex: activeFlowStepIndex
        )

        stateHistory.append(snapshot)
        if stateHistory.count > 50 {
            stateHistory.removeFirst()
            stateHistory = stateHistory.enumerated().map { idx, item in
                StateSnapshot(
                    id: item.id,
                    index: idx,
                    action: item.action,
                    summary: item.summary,
                    timestamp: item.timestamp,
                    counter: item.counter,
                    isLoading: item.isLoading,
                    loadedMessage: item.loadedMessage,
                    cartItems: item.cartItems,
                    promoApplied: item.promoApplied,
                    activeFlowStepIndex: item.activeFlowStepIndex
                )
            }
        }
        currentHistoryIndex = stateHistory.count - 1

        timeline.insert(
            TimelineEvent(action: action, state: summary),
            at: 0
        )
        if timeline.count > 12 {
            timeline.removeLast()
        }
    }

    // MARK: - NotebookFlowKit Interactive Stepper & Visual Screen Builder

    func advanceFlow(action: String, pageID: String, totalPages: Int) {
        flowAnswers[pageID] = action
        if activeFlowStepIndex < max(0, totalPages - 1) {
            activeFlowStepIndex += 1
        } else {
            activeFlowStepIndex = 0
        }
        recordStateMutation(action: ".flowAction(\"\(action)\")")
        statusMessage = "Flow answer '\(action)' recorded"
    }

    func restartFlow() {
        activeFlowStepIndex = 0
        flowAnswers.removeAll()
        recordStateMutation(action: ".flowRestart")
        statusMessage = "Restarted NotebookFlow preview"
    }

    func mutateFlowDefinition(_ transform: (inout FlowDefinition) -> Void) {
        guard var def = try? FlowDefinition.decode(flowJSON).get() else { return }
        transform(&def)
        flowJSON = def.encodedPrettyJSON()
    }

    func addVisualFlowPage() {
        mutateFlowDefinition { def in
            let idx = def.pages.count + 1
            def.pages.append(
                FlowPage(
                    id: "step_\(idx)",
                    title: "New Step \(idx)",
                    body: "Describe what the user learns or configures on this screen.",
                    style: idx == 1 ? "hero" : "choice",
                    actions: ["Continue"]
                )
            )
        }
        statusMessage = "Added screen to NotebookFlow"
    }

    func removeVisualFlowPage(at index: Int) {
        mutateFlowDefinition { def in
            guard def.pages.count > 1, def.pages.indices.contains(index) else { return }
            def.pages.remove(at: index)
        }
        activeFlowStepIndex = max(0, activeFlowStepIndex - 1)
        statusMessage = "Removed screen from NotebookFlow"
    }

    func moveVisualFlowPage(at index: Int, direction: Int) {
        mutateFlowDefinition { def in
            let target = index + direction
            guard def.pages.indices.contains(index), def.pages.indices.contains(target) else { return }
            def.pages.swapAt(index, target)
        }
        statusMessage = "Reordered NotebookFlow screen"
    }

    // MARK: - CoreLocalAIKit Assistant Actions

    func runLocalAI(preset: LocalAIPromptPreset? = nil) {
        guard !isAIRunning else { return }
        if let preset {
            aiPrompt = preset.promptText
        }

        rightInspectorTab = .assistant
        isAIRunning = true
        let promptToRun = aiPrompt
        let preferredKind = preset?.kind
        let backend = aiBackendMode
        let codeSnapshot = selectedSwiftUICode
        let titleSnapshot = selectionDisplayTitle
        let tokensSnapshot = themeTokens

        Task {
            let response = await aiEngine.run(
                prompt: promptToRun,
                preferredTask: preferredKind,
                backend: backend,
                currentCode: codeSnapshot,
                selectionTitle: titleSnapshot,
                theme: tokensSnapshot
            )
            latestAIResponse = response
            aiHistory.insert(response, at: 0)
            if aiHistory.count > 15 {
                aiHistory.removeLast()
            }
            isAIRunning = false
            statusMessage = "CoreLocalAIKit completed in \(String(format: "%.1f", response.latencyMilliseconds)) ms (On-Device)"
        }
    }

    func applyAIResponse(_ response: LocalAIResponse) {
        guard let payload = response.applyPayload else { return }
        switch payload {
        case .swiftUICode(let code):
            aiOverriddenCode[selection] = code
            rightInspectorTab = .code
            codePreviewMode = .diff
            statusMessage = "Applied CoreLocalAIKit code (\(response.diffReport.summaryBadge) lines)"

        case .notebookFlowJSON(let newJSON, _):
            flowJSON = newJSON
            activeFlowStepIndex = 0
            flowAnswers.removeAll()
            selection = .package(.notebookFlowKit)
            rightInspectorTab = .code
            codePreviewMode = .data
            statusMessage = "Loaded AI-generated Onboarding Flow into NotebookFlowKit"

        case .canvasNodes(let nodes):
            recordCanvasUndoCheckpoint()
            canvasDocument.nodes = nodes
            selectedCanvasNodeID = nodes.first?.id
            selection = .package(.swiftBlocks)
            rightInspectorTab = .code
            codePreviewMode = .swiftUI
            statusMessage = "Placed \(nodes.count) AI-composed blocks onto SwiftBlocks Canvas"

        case .unitTestSuite(let testCode):
            generatedUnitTestsBySelection[selection] = testCode
            rightInspectorTab = .code
            codePreviewMode = .tests
            statusMessage = "Loaded generated @Test suite into Live Code → Tests"
        }
    }

    func runStudioSelfCheck() {
        Task {
            let report = await MasterSuiteRunner.runFullMasterSelfCheck()
            statusMessage = "Master Self-Check: \(report.passedCount)/\(report.steps.count) subsystems passed in \(String(format: "%.1f", report.durationMilliseconds)) ms"
        }
    }

    // MARK: - Reset & Export Actions

    func resetDemo() {
        counter = 0
        isLoading = false
        loadedMessage = nil
        cartItems = Self.defaultCartItems
        promoApplied = false
        flowJSON = DemoLibrary.defaultFlowJSON
        activeFlowStepIndex = 0
        flowAnswers.removeAll()
        themeTokens = StudioThemeTokens()
        activeThemePreset = .chiefKitBlue
        activeEnterpriseLayers = Set(EnterpriseLayerKind.allCases)
        let starter = CanvasDocument.starter(radius: 12)
        canvasDocument = starter
        canvasHistory.clear()
        selectedCanvasNodeID = starter.nodes.first?.id
        aiOverriddenCode.removeAll()
        clearStateHistory()
        timeline = [TimelineEvent(action: ".reset", state: "count: 0")]
        statusMessage = "Workspace reset to defaults"
    }

    func copySwiftUICode() {
        ExportService.copyToClipboard(selectedSwiftUICode)
        statusMessage = "Copied live SwiftUI code to clipboard"
    }

    func copyPackageDependency() {
        ExportService.copyToClipboard(selectedDependencyCode)
        statusMessage = "Copied Package.swift dependency snippet"
    }

    func copyPackageSnippetBundle() {
        let bundle = ExportService.buildPackageSnippetBundle(
            title: selectionDisplayTitle,
            dependencySnippet: selectedDependencyCode,
            themeSnippet: themeTokens.swiftBlocksThemeSnippet,
            swiftUICode: selectedSwiftUICode
        )
        ExportService.copyToClipboard(bundle)
        statusMessage = "Copied self-contained Package Snippet to clipboard"
    }

    func exportPackageSnippetFile() {
        let bundle = ExportService.buildPackageSnippetBundle(
            title: selectionDisplayTitle,
            dependencySnippet: selectedDependencyCode,
            themeSnippet: themeTokens.swiftBlocksThemeSnippet,
            swiftUICode: selectedSwiftUICode
        )
        let cleanName = selectionDisplayTitle.replacingOccurrences(of: " ", with: "")
        do {
            let url = try ExportService.export(
                text: bundle,
                suggestedFileName: "\(cleanName)Snippet.swift",
                panelTitle: "Export as Package Snippet"
            )
            statusMessage = url == nil ? "Snippet export cancelled" : "Exported \(cleanName)Snippet.swift"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func copyNotebookUsageCode() {
        let title = (try? FlowDefinition.decode(flowJSON).get().title) ?? "Launch Onboarding"
        ExportService.copyToClipboard(DemoLibrary.notebookUsageCode(flowTitle: title))
        statusMessage = "Copied NotebookFlowKit host SwiftUI"
    }

    func exportFlowJSON() {
        do {
            let url = try ExportService.export(
                text: flowJSON,
                suggestedFileName: "NotebookFlow.json",
                panelTitle: "Export NotebookFlow JSON"
            )
            statusMessage = url == nil ? "Export cancelled" : "Exported NotebookFlow.json"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func exportSelectedExample() {
        let fileName = "\(selectionDisplayTitle.replacingOccurrences(of: " ", with: "")).swift"
        do {
            let url = try ExportService.export(
                text: selectedSwiftUICode,
                suggestedFileName: fileName,
                panelTitle: "Export SwiftUI View"
            )
            statusMessage = url == nil ? "Export cancelled" : "Exported \(fileName)"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func openInXcode() {
        statusMessage = ExportService.openWorkspaceInXcode()
    }

    func openDMGDownload() {
        ExportService.openURL(ExportService.dmgDownloadURLString)
        statusMessage = "Opened macOS DMG download page in browser"
    }

    // MARK: - Command Palette (⌘K)

    var allCommandItems: [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []

        for wb in StudioWorkbenchKind.allCases {
            let shortcut: String?
            switch wb {
            case .astCompiler: shortcut = "⌥⌘1"
            case .componentCatalog64: shortcut = "⌥⌘2"
            case .securityAndEphemeris: shortcut = "⌥⌘3"
            case .performanceProfiler: shortcut = "⌥⌘4"
            default: shortcut = "Studio 3.0"
            }
            items.append(
                CommandPaletteItem(
                    id: "nav-wb-\(wb.rawValue)",
                    title: "Workbench: \(wb.title)",
                    subtitle: wb.subtitle,
                    symbolName: wb.symbolName,
                    shortcutHint: shortcut,
                    section: .navigation,
                    action: .navigate(.workbench(wb))
                )
            )
        }

        for pkg in PackageDemo.allCases {
            items.append(
                CommandPaletteItem(
                    id: "nav-pkg-\(pkg.rawValue)",
                    title: "Open \(pkg.title) Playground",
                    subtitle: pkg.purpose,
                    symbolName: pkg.symbolName,
                    shortcutHint: nil,
                    section: .navigation,
                    action: .navigate(.package(pkg))
                )
            )
        }

        for spec in EnterpriseBlueprintCatalog.allSpecs {
            items.append(
                CommandPaletteItem(
                    id: "nav-ebp-\(spec.id.rawValue)",
                    title: "Enterprise Blueprint: \(spec.title)",
                    subtitle: "\(spec.vertical.title) — \(spec.subtitle)",
                    symbolName: spec.sfSymbol,
                    shortcutHint: "14-File",
                    section: .navigation,
                    action: .navigate(.enterpriseBlueprint(spec.id.rawValue))
                )
            )
        }

        for bp in BlueprintDomain.allCases {
            items.append(
                CommandPaletteItem(
                    id: "nav-bp-\(bp.rawValue)",
                    title: "Classic Blueprint: \(bp.title)",
                    subtitle: bp.summary,
                    symbolName: bp.symbolName,
                    shortcutHint: "Full-Stack",
                    section: .navigation,
                    action: .navigate(.blueprint(bp))
                )
            )
        }

        for tpl in TemplateKind.allCases {
            items.append(
                CommandPaletteItem(
                    id: "nav-tpl-\(tpl.rawValue)",
                    title: "Example: \(tpl.title)",
                    subtitle: "\(tpl.category.rawValue) — \(tpl.summary)",
                    symbolName: tpl.symbolName,
                    shortcutHint: nil,
                    section: .navigation,
                    action: .navigate(.template(tpl))
                )
            )
        }

        for preset in LocalAIPromptPreset.presets {
            items.append(
                CommandPaletteItem(
                    id: "ai-\(preset.id)",
                    title: "CoreLocalAIKit: \(preset.buttonTitle)",
                    subtitle: "\(preset.promptText) (\(preset.turkishHint))",
                    symbolName: preset.kind.symbolName,
                    shortcutHint: "On-Device",
                    section: .localAI,
                    action: .runAIPreset(preset.kind)
                )
            )
        }

        items.append(contentsOf: [
            CommandPaletteItem(
                id: "ws-undo",
                title: "Undo Canvas Change",
                subtitle: "Revert last SwiftBlocks canvas block edit",
                symbolName: "arrow.uturn.backward",
                shortcutHint: "⌘Z",
                section: .workspace,
                action: .undoCanvas
            ),
            CommandPaletteItem(
                id: "ws-redo",
                title: "Redo Canvas Change",
                subtitle: "Reapply undone SwiftBlocks canvas edit",
                symbolName: "arrow.uturn.forward",
                shortcutHint: "⇧⌘Z",
                section: .workspace,
                action: .redoCanvas
            ),
            CommandPaletteItem(
                id: "ws-contrast",
                title: "Auto-Fix Token WCAG Contrast",
                subtitle: "Ensure Primary Accent meets ≥ 4.5:1 WCAG AA against surface",
                symbolName: "wand.and.rays",
                shortcutHint: "WCAG AA",
                section: .workspace,
                action: .autoFixContrast
            ),
            CommandPaletteItem(
                id: "ws-tokens",
                title: "Open Theme & Token Explorer",
                subtitle: "Customize colors, spacing, corner radius, Liquid Glass, and W3C JSON",
                symbolName: "slider.horizontal.3",
                shortcutHint: nil,
                section: .workspace,
                action: .openInspectorTab(.tokens)
            ),
            CommandPaletteItem(
                id: "ws-timetravel",
                title: "Toggle State Time-Travel Debugger",
                subtitle: "Scrub backward and forward through recorded state transitions",
                symbolName: "clock.arrow.circlepath",
                shortcutHint: "⌘T",
                section: .workspace,
                action: .toggleTimeTravel
            ),
            CommandPaletteItem(
                id: "ws-dark",
                title: "Toggle Light / Dark Preview Appearance",
                subtitle: "Switch active preview color scheme immediately",
                symbolName: "moon.stars.fill",
                shortcutHint: nil,
                section: .workspace,
                action: .toggleDarkAppearance
            ),
            CommandPaletteItem(
                id: "ws-ax",
                title: "Toggle Accessibility X-Ray Overlay",
                subtitle: "Inspect VoiceOver labels, focus badges, and contrast ratios",
                symbolName: "figure.roll",
                shortcutHint: nil,
                section: .workspace,
                action: .toggleAccessibilityOverlay
            ),
            CommandPaletteItem(
                id: "ws-glass",
                title: "Toggle Liquid Glass Surface Effect",
                subtitle: "Enable or disable specular frosted glass on SwiftBlocks surfaces",
                symbolName: "sparkles",
                shortcutHint: nil,
                section: .workspace,
                action: .toggleLiquidGlass
            ),
            CommandPaletteItem(
                id: "ws-selfcheck",
                title: "Run 16-Subsystem Master Self-Check",
                subtitle: "Verify AST, OKLCH/APCA, 64 SwiftBlocks, ChaCha20 Vault, EphemerisCore & 28 Blueprints",
                symbolName: "checkmark.shield.fill",
                shortcutHint: "⌥⌘R",
                section: .workspace,
                action: .runSelfCheck
            ),
            CommandPaletteItem(
                id: "exp-pin",
                title: "Pin Current Design to My Snippets",
                subtitle: "Save active SwiftUI source into sidebar custom snippets",
                symbolName: "pin.fill",
                shortcutHint: "⌘D",
                section: .export,
                action: .pinCurrentSnippet
            ),
            CommandPaletteItem(
                id: "exp-save-ws",
                title: "Save Workspace (.chiefkit)…",
                subtitle: "Persist canvas, theme tokens, flow JSON, blueprints & snippets",
                symbolName: "externaldrive.badge.checkmark",
                shortcutHint: "⌘S",
                section: .export,
                action: .saveWorkspace
            ),
            CommandPaletteItem(
                id: "exp-load-ws",
                title: "Open Workspace (.chiefkit)…",
                subtitle: "Restore a previously saved ChiefKit Studio session",
                symbolName: "folder",
                shortcutHint: "⌘O",
                section: .export,
                action: .loadWorkspace
            ),
            CommandPaletteItem(
                id: "exp-proj",
                title: "One-Click Project Generator…",
                subtitle: "Export ready-to-run Package.swift + unit tests and open in Xcode",
                symbolName: "hammer.fill",
                shortcutHint: "⌘⇧E",
                section: .export,
                action: .openProjectGenerator
            ),
            CommandPaletteItem(
                id: "exp-copy",
                title: "Copy Live SwiftUI Code",
                subtitle: "Copy current SwiftUI source to macOS clipboard",
                symbolName: "doc.on.doc",
                shortcutHint: "⌘⇧C",
                section: .export,
                action: .copySwiftUICode
            ),
            CommandPaletteItem(
                id: "exp-snippet",
                title: "Export as Package Snippet…",
                subtitle: "Save SwiftUI view + Package.swift dependency + EDKTheme tokens",
                symbolName: "shippingbox.and.arrow.backward",
                shortcutHint: nil,
                section: .export,
                action: .exportPackageSnippet
            ),
            CommandPaletteItem(
                id: "exp-xcode",
                title: "Open Workspace in Xcode",
                subtitle: "Launch Xcode directly with Package.swift",
                symbolName: "wrench.and.screwdriver.fill",
                shortcutHint: nil,
                section: .export,
                action: .openInXcode
            ),
            CommandPaletteItem(
                id: "exp-reset",
                title: "Reset Playground State & Canvas",
                subtitle: "Restore default tokens, canvas blocks, and state history",
                symbolName: "arrow.counterclockwise",
                shortcutHint: nil,
                section: .export,
                action: .resetPlayground
            )
        ])

        return items
    }

    var filteredCommandItems: [CommandPaletteItem] {
        let q = commandPaletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return allCommandItems }
        return allCommandItems.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.subtitle.localizedCaseInsensitiveContains(q)
                || $0.section.rawValue.localizedCaseInsensitiveContains(q)
        }
    }

    func executeCommand(_ item: CommandPaletteItem) {
        isCommandPalettePresented = false
        commandPaletteQuery = ""

        switch item.action {
        case .navigate(let target):
            select(target)
        case .runAIPreset(let kind):
            let preset = LocalAIPromptPreset.presets.first { $0.kind == kind }
            runLocalAI(preset: preset)
        case .openInspectorTab(let tab):
            rightInspectorTab = tab
        case .toggleTimeTravel:
            isTimeTravelVisible.toggle()
        case .toggleDarkAppearance:
            previewConfig.appearance = previewConfig.appearance == .dark ? .light : .dark
        case .toggleAccessibilityOverlay:
            previewConfig.showAccessibilityOverlay.toggle()
        case .toggleLiquidGlass:
            themeTokens.isLiquidGlassEnabled.toggle()
        case .autoFixContrast:
            autoFixThemeContrast()
        case .undoCanvas:
            undoCanvas()
        case .redoCanvas:
            redoCanvas()
        case .pinCurrentSnippet:
            pinCurrentSnippet()
        case .saveWorkspace:
            saveWorkspaceToDisk()
        case .loadWorkspace:
            loadWorkspaceFromDisk()
        case .runSelfCheck:
            runStudioSelfCheck()
        case .openProjectGenerator:
            isProjectGeneratorPresented = true
        case .copySwiftUICode:
            copySwiftUICode()
        case .exportPackageSnippet:
            exportPackageSnippetFile()
        case .openInXcode:
            openInXcode()
        case .resetPlayground:
            resetDemo()
        }
    }

    // MARK: - Helpers

    private func matches(_ fields: String...) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func prettyJSON(_ dictionary: [String: Any]) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }
}
#endif
