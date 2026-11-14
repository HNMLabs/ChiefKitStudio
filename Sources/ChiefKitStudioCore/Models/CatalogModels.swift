import Foundation

public enum ExampleCategory: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case all = "All"
    case blueprints = "Blueprints"
    case designSystem = "Design System"
    case state = "State"
    case onboarding = "Onboarding"
    case forms = "Forms"
    case localAI = "Local AI"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .all: "square.grid.2x2"
        case .blueprints: "square.3.layers.3d.down.right"
        case .designSystem: "paintbrush.pointed"
        case .state: "point.3.connected.trianglepath.dotted"
        case .onboarding: "sparkles.rectangle.stack"
        case .forms: "checklist"
        case .localAI: "brain.head.profile"
        }
    }
}

public enum PackageDemo: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case swiftBlocks
    case swiftState
    case notebookFlowKit
    case coreLocalAIKit

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .swiftBlocks: "SwiftBlocks"
        case .swiftState: "SwiftState"
        case .notebookFlowKit: "NotebookFlowKit"
        case .coreLocalAIKit: "CoreLocalAIKit"
        }
    }

    public var repositoryURL: String {
        switch self {
        case .swiftBlocks: "https://github.com/HNMLabs/SwiftBlocks.git"
        case .swiftState: "https://github.com/HNMLabs/SwiftState.git"
        case .notebookFlowKit: "https://github.com/HNMLabs/NotebookFlowKit.git"
        case .coreLocalAIKit: "https://github.com/HNMLabs/CoreLocalAIKit.git"
        }
    }

    public var webURL: String {
        repositoryURL.replacingOccurrences(of: ".git", with: "")
    }

    public var packageIdentity: String {
        switch self {
        case .swiftBlocks: "SwiftBlocks"
        case .swiftState: "SwiftState"
        case .notebookFlowKit: "NotebookFlowKit"
        case .coreLocalAIKit: "CoreLocalAIKit"
        }
    }

    public var purpose: String {
        switch self {
        case .swiftBlocks:
            "Interactive drag-and-drop canvas, Liquid Glass surfaces, alignment tools, and tokenized design-system blocks."
        case .swiftState:
            "Predictable unidirectional state, async effects, middleware, and time-travel debugging."
        case .notebookFlowKit:
            "Portable JSON-driven onboarding, visual step builder, topology validation, and conditional flows."
        case .coreLocalAIKit:
            "100% on-device Swift code analysis, accessibility auditing, @Test synthesis, and natural-language UI generation."
        }
    }

    public var symbolName: String {
        switch self {
        case .swiftBlocks: "square.grid.3x3.topleft.filled"
        case .swiftState: "point.3.connected.trianglepath.dotted"
        case .notebookFlowKit: "rectangle.on.rectangle.angled"
        case .coreLocalAIKit: "cpu.fill"
        }
    }

    public var category: ExampleCategory {
        switch self {
        case .swiftBlocks: .designSystem
        case .swiftState: .state
        case .notebookFlowKit: .onboarding
        case .coreLocalAIKit: .localAI
        }
    }

    public var learningHeadline: String {
        switch self {
        case .swiftBlocks:
            "Compose layouts visually with EDKDesignCanvas, align & auto-tidy blocks with undo/redo, customize tokens live, and export clean SwiftUI."
        case .swiftState:
            "Drive UI from pure Reducers and async Effects while scrubbing through every state transition with TimeTravelStore."
        case .notebookFlowKit:
            "Author multi-step product flows visually or in JSON with live graph validation and typed completion events."
        case .coreLocalAIKit:
            "Run private, zero-latency NLP analysis, SwiftUI refactoring, unified diffs, and @Test generation locally."
        }
    }

    public var learningKeyPoints: [String] {
        switch self {
        case .swiftBlocks:
            [
                "Drag & drop palette blocks, align edges, auto-tidy grid, and undo/redo (⌘Z / ⇧⌘Z)",
                "Select any canvas node to inspect variants, lock state, sizing, and live SwiftUI output",
                "Apply EDKTheme tokens with live WCAG 2.1 contrast auditing and W3C/CSS export"
            ]
        case .swiftState:
            [
                "Model domain state as Equatable, Codable, and Sendable value types",
                "Dispatch explicit actions and isolate async side-effects inside .run { send in }",
                "Scrub backward/forward in the floating Time-Travel Debugger (⌘T)"
            ]
        case .notebookFlowKit:
            [
                "Build onboarding, surveys, and quizzes with the Visual Step Builder or raw JSON",
                "Validate screen IDs, actions, and topology edges automatically in real time",
                "Combine with Local AI to synthesize new flows from a single prompt"
            ]
        case .coreLocalAIKit:
            [
                "Zero cloud calls, zero API keys — powered by Apple NaturalLanguage & FoundationModels",
                "Supports both English and Turkish prompts, including instant Swift Testing (@Test) generation",
                "Inspect side-by-side line diffs before applying AI changes to the playground"
            ]
        }
    }

    public var highlightedAPIs: [String] {
        switch self {
        case .swiftBlocks:
            ["EDKDesignCanvas", "EDKSurface", "EDKButton", "EDKTheme", ".edkLiquidGlass"]
        case .swiftState:
            ["Store<S>", "TimeTravelStore<S>", "Reducer", "@StateStore", "TimeTravelDebuggerView"]
        case .notebookFlowKit:
            ["NotebookFlowView", "NotebookFlow", "FlowScreen", "FlowResult"]
        case .coreLocalAIKit:
            ["LocalAIEngine", "NaturalLanguageService", "SystemLanguageModel", "CodeDiffEngine"]
        }
    }

    public var packageDependencySnippet: String {
        """
        .package(url: "\(repositoryURL)", branch: "main")
        """
    }

    public var targetDependencySnippet: String {
        """
        .product(name: "\(title)", package: "\(packageIdentity)")
        """
    }
}

public enum TemplateKind: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case loginFlow
    case onboardingFlow
    case settingsScreen
    case apiLoadingState
    case quizFlow
    case liquidGlassDashboard
    case multiStepProfileForm
    case shoppingCartStore
    case aiAccessibilityAudit

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .loginFlow: "Login & Passkey Form"
        case .onboardingFlow: "Product Launch Onboarding"
        case .settingsScreen: "Tokenized Settings Surface"
        case .apiLoadingState: "Async Resource State"
        case .quizFlow: "Branching Quiz Flow"
        case .liquidGlassDashboard: "Liquid Glass KPI Wall"
        case .multiStepProfileForm: "Workspace Setup Form"
        case .shoppingCartStore: "Undoable Cart Reducer"
        case .aiAccessibilityAudit: "AI-Audited Accessible Card"
        }
    }

    public var symbolName: String {
        switch self {
        case .loginFlow: "person.badge.key"
        case .onboardingFlow: "sparkles.rectangle.stack"
        case .settingsScreen: "gearshape.2"
        case .apiLoadingState: "arrow.down.doc"
        case .quizFlow: "questionmark.app"
        case .liquidGlassDashboard: "rectangle.3.group.bubble.left"
        case .multiStepProfileForm: "list.clipboard"
        case .shoppingCartStore: "cart.badge.plus"
        case .aiAccessibilityAudit: "figure.roll"
        }
    }

    public var category: ExampleCategory {
        switch self {
        case .loginFlow, .multiStepProfileForm:
            return .forms
        case .onboardingFlow, .quizFlow:
            return .onboarding
        case .settingsScreen, .liquidGlassDashboard:
            return .designSystem
        case .apiLoadingState, .shoppingCartStore:
            return .state
        case .aiAccessibilityAudit:
            return .localAI
        }
    }

    public var summary: String {
        switch self {
        case .loginFlow:
            "Authentication form with inline validation, Touch ID toggle, and SwiftState submission."
        case .onboardingFlow:
            "Multi-step JSON welcome flow with persona selection and live completion payload."
        case .settingsScreen:
            "Grouped macOS/iOS preferences built from tokenized SwiftBlocks surfaces."
        case .apiLoadingState:
            "Explicit idle, loading, loaded, empty, and error retry transitions via Reducer."
        case .quizFlow:
            "Interactive knowledge check with live score tracking and JSON-driven questions."
        case .liquidGlassDashboard:
            "Specular Liquid Glass cards, metric pills, and live EDKTheme token responsiveness."
        case .multiStepProfileForm:
            "Validated multi-field team setup form with live role picker and instant state sync."
        case .shoppingCartStore:
            "Add/remove items, apply promo codes, and scrub cart state in the Time-Travel Debugger."
        case .aiAccessibilityAudit:
            "VoiceOver labels, Dynamic Type scaling, and CoreLocalAIKit accessibility heuristics."
        }
    }
}

public struct TemplateExample: Identifiable, Hashable, Sendable {
    public var id: TemplateKind { kind }
    public let kind: TemplateKind
    public let explanation: String
    public let learningPoints: [String]
    public let highlightedAPIs: [String]
    public let requiredPackages: [PackageDemo]
    public let swiftUICode: String

    public init(
        kind: TemplateKind,
        explanation: String,
        learningPoints: [String],
        highlightedAPIs: [String],
        requiredPackages: [PackageDemo],
        swiftUICode: String
    ) {
        self.kind = kind
        self.explanation = explanation
        self.learningPoints = learningPoints
        self.highlightedAPIs = highlightedAPIs
        self.requiredPackages = requiredPackages
        self.swiftUICode = swiftUICode
    }

    public var dependencySnippet: String {
        let packages = requiredPackages
            .map(\.packageDependencySnippet)
            .joined(separator: ",\n")

        let products = requiredPackages
            .map(\.targetDependencySnippet)
            .joined(separator: ",\n")

        return """
        // Package.swift
        dependencies: [
        \(packages.indented(by: 4))
        ],
        targets: [
            .target(
                name: "YourApp",
                dependencies: [
        \(products.indented(by: 12))
                ]
            )
        ]
        """
    }
}

public struct SavedSnippet: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var category: ExampleCategory
    public var swiftUICode: String
    public var createdAtTimestamp: Double

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String,
        category: ExampleCategory = .designSystem,
        swiftUICode: String,
        createdAtTimestamp: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.swiftUICode = swiftUICode
        self.createdAtTimestamp = createdAtTimestamp
    }
}

public enum StudioWorkbenchKind: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case astCompiler
    case animationAndPhysics
    case multiArtboardAndSVG
    case componentCatalog64
    case dataAndAPISchema
    case localizationCatalog
    case securityAndEphemeris
    case performanceProfiler

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .astCompiler: "SwiftUI AST & Refactoring Lab"
        case .animationAndPhysics: "Spring Physics & Keyframe Studio"
        case .multiArtboardAndSVG: "Multi-Artboard, Auto-Layout & SVG"
        case .componentCatalog64: "SwiftBlocks 3.0 Catalog (64)"
        case .dataAndAPISchema: "ER Data Schema, SQLite & OpenAPI"
        case .localizationCatalog: "String Catalog (.xcstrings) & RTL"
        case .securityAndEphemeris: "EphemerisCore & ChaCha20 Vault"
        case .performanceProfiler: "120Hz ProMotion & Invalidation Profiler"
        }
    }

    public var subtitle: String {
        switch self {
        case .astCompiler:
            "Bidirectional SwiftUI lexer/parser, 38 static audit rules, 6 AST refactoring passes, and @Test synthesis."
        case .animationAndPhysics:
            "Analytical + RK4 spring physics, cubic-bezier curves, multi-track keyframes, and PhaseAnimator synthesis."
        case .multiArtboardAndSVG:
            "Multi-device artboards, deterministic auto-layout solver, and 42 W3C SVG vector paths."
        case .componentCatalog64:
            "64 production SwiftBlocks 3.0 components, OKLCH/APCA perceptual color science, and 8-target token export."
        case .dataAndAPISchema:
            "Visual Entity-Relationship modeler compiling SwiftData @Model, strict SQLite DDL, OpenAPI 3.1, and GraphQL."
        case .localizationCatalog:
            "Apple .xcstrings String Catalog editor, CLDR plurals, format checker, pseudolocalization, and RTL preview."
        case .securityAndEphemeris:
            "Pure-Swift SHA-2/HKDF/ChaCha20-Poly1305 vault, EphemerisCore planetary auth, OWASP & PrivacyInfo.xcprivacy."
        case .performanceProfiler:
            "120Hz ProMotion frame-budget simulator, GPU offscreen hazard detector, and @Observable invalidation graph."
        }
    }

    public var symbolName: String {
        switch self {
        case .astCompiler: "chevron.left.forwardslash.chevron.right"
        case .animationAndPhysics: "waveform.path.ecg"
        case .multiArtboardAndSVG: "rectangle.3.group"
        case .componentCatalog64: "square.grid.3x3.fill"
        case .dataAndAPISchema: "cylinder.split.1x2.fill"
        case .localizationCatalog: "globe"
        case .securityAndEphemeris: "lock.shield.fill"
        case .performanceProfiler: "gauge.with.needle.fill"
        }
    }

    public var category: ExampleCategory {
        switch self {
        case .astCompiler, .securityAndEphemeris: .localAI
        case .animationAndPhysics, .multiArtboardAndSVG, .componentCatalog64: .designSystem
        case .dataAndAPISchema, .performanceProfiler: .state
        case .localizationCatalog: .forms
        }
    }
}

public enum NavigationSelection: Hashable, Codable, Sendable {
    case package(PackageDemo)
    case workbench(StudioWorkbenchKind)
    case template(TemplateKind)
    case blueprint(BlueprintDomain)
    case enterpriseBlueprint(String)
    case savedSnippet(UUID)

    public var title: String {
        switch self {
        case .package(let package): package.title
        case .workbench(let wb): wb.title
        case .template(let template): template.title
        case .blueprint(let domain): domain.title
        case .enterpriseBlueprint(let rawID): rawID
        case .savedSnippet: "Pinned Snippet"
        }
    }

    public var subtitle: String {
        switch self {
        case .package(let package): package.purpose
        case .workbench(let wb): wb.subtitle
        case .template(let template): template.summary
        case .blueprint(let domain): domain.summary
        case .enterpriseBlueprint: "8-layer enterprise full-stack ChiefKit Studio 3.0 architecture."
        case .savedSnippet: "Custom developer snippet pinned inside this ChiefKit workspace."
        }
    }

    public var symbolName: String {
        switch self {
        case .package(let package): package.symbolName
        case .workbench(let wb): wb.symbolName
        case .template(let template): template.symbolName
        case .blueprint(let domain): domain.symbolName
        case .enterpriseBlueprint: "building.2.crop.circle.fill"
        case .savedSnippet: "pin.fill"
        }
    }

    public var category: ExampleCategory {
        switch self {
        case .package(let package): package.category
        case .workbench(let wb): wb.category
        case .template(let template): template.category
        case .blueprint, .enterpriseBlueprint: .blueprints
        case .savedSnippet: .designSystem
        }
    }

    public var sanitizedProjectName: String {
        let raw = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
        return raw.isEmpty ? "ChiefKitSampleApp" : "\(raw)App"
    }
}

public enum CodePreviewMode: String, CaseIterable, Identifiable, Sendable {
    case swiftUI = "SwiftUI"
    case diff = "Diff"
    case tests = "Tests"
    case package = "Package.swift"
    case theme = "Tokens"
    case data = "State / JSON"

    public var id: String { rawValue }
}
