import Foundation

public enum RightInspectorTab: String, CaseIterable, Identifiable, Sendable {
    case code = "Live Code"
    case assistant = "Local AI"
    case tokens = "Tokens"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .code: "curlybraces"
        case .assistant: "sparkles"
        case .tokens: "slider.horizontal.3"
        }
    }
}

public enum LocalAIBackendMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case naturalLanguageAST = "On-Device NLP + AST"
    case appleIntelligence = "Apple Intelligence (Core AI)"

    public var id: String { rawValue }

    public var shortBadge: String {
        switch self {
        case .naturalLanguageAST: "NaturalLanguage"
        case .appleIntelligence: "FoundationModels"
        }
    }
}

public enum LocalAITaskKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case refactorSwiftState
    case addAccessibility
    case performanceAudit
    case generateOnboardingFlow
    case composeCanvasBlocks
    case generateSwiftTests
    case customAnalysis

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .refactorSwiftState: "Refactor SwiftState"
        case .addAccessibility: "Add Accessibility"
        case .performanceAudit: "Performance Audit"
        case .generateOnboardingFlow: "New Onboarding Flow"
        case .composeCanvasBlocks: "Compose Blocks"
        case .generateSwiftTests: "Generate Swift Tests"
        case .customAnalysis: "Code Analysis"
        }
    }

    public var symbolName: String {
        switch self {
        case .refactorSwiftState: "arrow.triangle.2.circlepath"
        case .addAccessibility: "figure.roll"
        case .performanceAudit: "speedometer"
        case .generateOnboardingFlow: "sparkles.rectangle.stack"
        case .composeCanvasBlocks: "square.grid.3x3.topleft.filled"
        case .generateSwiftTests: "checkmark.seal"
        case .customAnalysis: "wand.and.stars"
        }
    }
}

public struct LocalAIPromptPreset: Identifiable, Hashable, Sendable {
    public var id: String { kind.rawValue }
    public let kind: LocalAITaskKind
    public let buttonTitle: String
    public let promptText: String
    public let turkishHint: String

    public init(kind: LocalAITaskKind, buttonTitle: String, promptText: String, turkishHint: String) {
        self.kind = kind
        self.buttonTitle = buttonTitle
        self.promptText = promptText
        self.turkishHint = turkishHint
    }

    public static let presets: [LocalAIPromptPreset] = [
        LocalAIPromptPreset(
            kind: .refactorSwiftState,
            buttonTitle: "Improve SwiftState",
            promptText: "Refactor this SwiftState example with cancellation, typed errors, and Sendable actions.",
            turkishHint: "Bu SwiftState örneğini daha iyi yaz"
        ),
        LocalAIPromptPreset(
            kind: .addAccessibility,
            buttonTitle: "Add Accessibility",
            promptText: "Add VoiceOver labels, hints, Dynamic Type support, and accessible grouping to this view.",
            turkishHint: "Bu view'a accessibility ekle"
        ),
        LocalAIPromptPreset(
            kind: .performanceAudit,
            buttonTitle: "Performance Tips",
            promptText: "Analyze this SwiftUI view for body recomputation, identity stability, and rendering performance.",
            turkishHint: "Performance önerisi ver"
        ),
        LocalAIPromptPreset(
            kind: .generateOnboardingFlow,
            buttonTitle: "New Onboarding Flow",
            promptText: "Generate a new 4-step NotebookFlowKit onboarding flow for an AI developer workspace.",
            turkishHint: "Yeni onboarding flow üret"
        ),
        LocalAIPromptPreset(
            kind: .composeCanvasBlocks,
            buttonTitle: "Compose Canvas UI",
            promptText: "Compose a Liquid Glass analytics dashboard with KPI metrics and primary action buttons.",
            turkishHint: "Yeni Liquid Glass kart ekranı üret"
        ),
        LocalAIPromptPreset(
            kind: .generateSwiftTests,
            buttonTitle: "Generate @Test Suite",
            promptText: "Generate a Swift Testing (@Test) unit test suite covering state transitions, edge cases, and flow decoding.",
            turkishHint: "Bu ekran için birim testleri üret"
        )
    ]
}

public enum LocalAIApplyPayload: Hashable, Sendable {
    case swiftUICode(String)
    case notebookFlowJSON(flowJSON: String, hostSwiftUI: String)
    case canvasNodes([CanvasNode])
    case unitTestSuite(String)
}

public struct LocalAIResponse: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let prompt: String
    public let taskKind: LocalAITaskKind
    public let backendUsed: String
    public let detectedLanguage: String
    public let latencyMilliseconds: Double
    public let summary: String
    public let findings: [String]
    public let tags: [String]
    public let generatedCode: String
    public let diffReport: DiffReport
    public let applyPayload: LocalAIApplyPayload?
    public let fallbackNotice: String?
    private let createdAt_: Date

    public init(
        id: UUID = UUID(),
        prompt: String,
        taskKind: LocalAITaskKind,
        backendUsed: String,
        detectedLanguage: String,
        latencyMilliseconds: Double,
        summary: String,
        findings: [String],
        tags: [String],
        generatedCode: String,
        diffReport: DiffReport,
        applyPayload: LocalAIApplyPayload?,
        fallbackNotice: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.taskKind = taskKind
        self.backendUsed = backendUsed
        self.detectedLanguage = detectedLanguage
        self.latencyMilliseconds = latencyMilliseconds
        self.summary = summary
        self.findings = findings
        self.tags = tags
        self.generatedCode = generatedCode
        self.diffReport = diffReport
        self.applyPayload = applyPayload
        self.fallbackNotice = fallbackNotice
        self.createdAt_ = createdAt
    }

    public var timestampText: String {
        TimestampClockFormatting.hmsString(from: createdAt_)
    }
}
