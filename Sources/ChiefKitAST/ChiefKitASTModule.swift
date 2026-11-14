import ChiefKitStudioCore
import Foundation

/// Full-stack end-to-end AST compilation, audit, metrics, symbol-graph, and verification snapshot for a SwiftUI source buffer.
public struct ChiefKitASTCompilationSnapshot: Codable, Equatable, Sendable {
    public let tokenSummary: TokenStreamSummary
    public let sourceFile: SwiftSourceFile
    public let auditReport: ASTAuditReport
    public let metricsReport: ASTMetricsReport
    public let symbolGraph: SymbolGraph
    public let verificationReport: SourceVerificationReport

    public init(
        tokenSummary: TokenStreamSummary,
        sourceFile: SwiftSourceFile,
        auditReport: ASTAuditReport,
        metricsReport: ASTMetricsReport,
        symbolGraph: SymbolGraph,
        verificationReport: SourceVerificationReport
    ) {
        self.tokenSummary = tokenSummary
        self.sourceFile = sourceFile
        self.auditReport = auditReport
        self.metricsReport = metricsReport
        self.symbolGraph = symbolGraph
        self.verificationReport = verificationReport
    }
}

/// Entry-point facade for the ChiefKit Studio 3.0 Swift 6 AST Compiler & Static Analysis Engine.
public enum ChiefKitASTModule: Sendable {
    public static let version = "3.0.0"

    public static var supportedAuditRuleCount: Int {
        ASTAuditRuleID.allCases.count
    }

    /// Executes the full lex -> parse -> audit -> metrics -> symbol-graph -> verify compiler pipeline in a single call.
    public static func analyzePipeline(
        source: String,
        filePath: String? = nil,
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> ChiefKitASTCompilationSnapshot {
        let lexed = SwiftLexer.tokenize(source)
        let lineCount = max(1, source.isEmpty ? 1 : source.components(separatedBy: "\n").count)
        let ast = SwiftUIParser.parse(tokens: lexed.tokens, sourceLengthLines: lineCount, filePath: filePath)
        let audit = ASTStaticAnalyzer.analyze(ast: ast, theme: theme)
        let metrics = ASTMetricsAndComplexity.analyze(ast: ast, tokens: lexed.tokens, rawSource: source)
        let graph = ASTSymbolGraphBuilder.build(from: [ast])
        let verification = ASTSourceVerifier.verifySource(code: source, filePath: filePath)

        return ChiefKitASTCompilationSnapshot(
            tokenSummary: lexed.summary,
            sourceFile: ast,
            auditReport: audit,
            metricsReport: metrics,
            symbolGraph: graph,
            verificationReport: verification
        )
    }
}
