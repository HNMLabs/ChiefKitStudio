import Foundation

public struct QualityDimensionScore: Identifiable, Codable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let score: Int
    public let symbolName: String

    public init(name: String, score: Int, symbolName: String) {
        self.name = name
        self.score = min(max(0, score), 100)
        self.symbolName = symbolName
    }
}

public struct CodeQualityReport: Codable, Equatable, Sendable {
    public let overallScore: Int
    public let accessibilityScore: Int
    public let concurrencyScore: Int
    public let tokenAdoptionScore: Int
    public let testabilityScore: Int
    public let lineCount: Int
    public let recommendations: [String]

    public var gradeBadge: String {
        switch overallScore {
        case 90...100: "A+"
        case 80..<90: "A"
        case 70..<80: "B+"
        case 60..<70: "B"
        default: "C"
        }
    }

    public var dimensions: [QualityDimensionScore] {
        [
            QualityDimensionScore(name: "A11y", score: accessibilityScore, symbolName: "figure.roll"),
            QualityDimensionScore(name: "Swift 6", score: concurrencyScore, symbolName: "bolt.shield"),
            QualityDimensionScore(name: "Tokens", score: tokenAdoptionScore, symbolName: "paintbrush"),
            QualityDimensionScore(name: "Testable", score: testabilityScore, symbolName: "checkmark.seal")
        ]
    }
}

public enum CodeQualityAnalyzer {
    public static func analyze(code: String, theme: StudioThemeTokens = StudioThemeTokens()) -> CodeQualityReport {
        let lines = code.isEmpty ? [] : code.components(separatedBy: "\n")
        var recommendations: [String] = []

        // 1. Accessibility Readiness
        var a11y = 55
        if code.contains(".accessibilityLabel") {
            a11y += 18
        } else {
            recommendations.append("Add .accessibilityLabel(...) to interactive buttons and icon controls.")
        }
        if code.contains(".accessibilityHint") || code.contains(".accessibilityAddTraits") {
            a11y += 15
        } else {
            recommendations.append("Include .accessibilityAddTraits(.isHeader) on primary screen titles.")
        }
        if code.contains("@ScaledMetric") || code.contains(".font(.") {
            a11y += 12
        }
        let lightContrast = theme.contrastReport.primaryOnSurfaceLevel.passesAA
        if !lightContrast {
            a11y = max(35, a11y - 12)
            recommendations.append("Primary token contrast on light surface is below 4.5:1 — click Auto-Fix in Tokens.")
        }
        a11y = min(100, a11y)

        // 2. Swift 6 Strict Concurrency & Safety
        var concurrency = 68
        if code.contains("Sendable") {
            concurrency += 16
        } else if code.contains("struct ") && !code.contains(": View") {
            recommendations.append("Mark domain models and action enums as Sendable for Swift 6 isolation.")
        }
        if code.contains("@MainActor") || code.contains("@State") || code.contains("@StateStore") {
            concurrency += 10
        }
        if !code.contains("DispatchQueue.main.async") && !code.contains("!") {
            concurrency += 6
        }
        concurrency = min(100, concurrency)

        // 3. Design System & Token Adoption
        var tokens = 58
        if code.contains("EDKSurface") || code.contains("EDKButton") || code.contains("EDKTheme") {
            tokens += 24
        } else {
            recommendations.append("Wrap raw containers in EDKSurface / EDKButton to inherit live design tokens.")
        }
        if code.contains("cornerRadius") || code.contains("spacing:") {
            tokens += 10
        }
        if code.contains("edkLiquidGlass") || code.contains("Material") {
            tokens += 8
        }
        tokens = min(100, tokens)

        // 4. Testability & Unidirectional Architecture
        var testability = 62
        if code.contains("Reducer") || code.contains("Equatable") || code.contains("NotebookFlowView") {
            testability += 22
        } else {
            recommendations.append("Extract state mutations into an Equatable Reducer or generate a @Test suite.")
        }
        if lines.count <= 180 {
            testability += 16
        } else {
            testability += 6
        }
        testability = min(100, testability)

        let overall = Int((Double(a11y + concurrency + tokens + testability) / 4.0).rounded())

        return CodeQualityReport(
            overallScore: overall,
            accessibilityScore: a11y,
            concurrencyScore: concurrency,
            tokenAdoptionScore: tokens,
            testabilityScore: testability,
            lineCount: lines.count,
            recommendations: Array(recommendations.prefix(3))
        )
    }
}
