import ChiefKitStudioCore
import Foundation

// MARK: - Structural Source Verification Models

/// Structural fault categories verified by `ASTSourceVerifier` on Linux and macOS.
public enum SourceVerificationIssueKind: String, Codable, Hashable, CaseIterable, Sendable {
    case unbalancedBraces
    case unbalancedParentheses
    case unbalancedBrackets
    case unterminatedStringLiteral
    case unterminatedBlockComment
    case unbalancedConditionalCompilation
    case invalidConditionalDirectiveOrder
    case duplicateTypeDeclaration
    case missingSwiftUIViewBody
    case fileSystemReadError
}

/// Pinpoints a structural syntax, delimiter, directive, or SwiftUI contract issue in a Swift file.
public struct SourceVerificationIssue: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let kind: SourceVerificationIssueKind
    public let severity: ASTDiagnosticSeverity
    public let filePath: String?
    public let message: String
    public let span: SourceSpan

    public init(
        id: UUID = UUID(),
        kind: SourceVerificationIssueKind,
        severity: ASTDiagnosticSeverity = .error,
        filePath: String? = nil,
        message: String,
        span: SourceSpan = .zero
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.filePath = filePath
        self.message = message
        self.span = span
    }
}

/// Structural verification report for a single `.swift` source file.
public struct SourceVerificationReport: Codable, Equatable, Sendable {
    public let filePath: String?
    public let isValid: Bool
    public let issues: [SourceVerificationIssue]
    public let declaredTypes: [String]
    public let verifiedSwiftUIViews: [String]
    public let conditionalCompilationBlockCount: Int
    public let matchedBracePairs: Int
    public let matchedParenPairs: Int
    public let matchedBracketPairs: Int
    public let lineCount: Int

    public init(
        filePath: String?,
        issues: [SourceVerificationIssue],
        declaredTypes: [String],
        verifiedSwiftUIViews: [String],
        conditionalCompilationBlockCount: Int,
        matchedBracePairs: Int,
        matchedParenPairs: Int,
        matchedBracketPairs: Int,
        lineCount: Int
    ) {
        self.filePath = filePath
        self.issues = issues
        self.isValid = !issues.contains { $0.severity == .error }
        self.declaredTypes = declaredTypes
        self.verifiedSwiftUIViews = verifiedSwiftUIViews
        self.conditionalCompilationBlockCount = conditionalCompilationBlockCount
        self.matchedBracePairs = matchedBracePairs
        self.matchedParenPairs = matchedParenPairs
        self.matchedBracketPairs = matchedBracketPairs
        self.lineCount = max(1, lineCount)
    }
}

/// Aggregated verification report across all `.swift` files inside a directory tree.
public struct DirectoryVerificationReport: Codable, Equatable, Sendable {
    public let directoryPath: String
    public let isValid: Bool
    public let fileReports: [SourceVerificationReport]
    public let crossFileDuplicateTypes: [String]
    public let totalFilesVerified: Int
    public let totalLinesVerified: Int
    public let totalErrorCount: Int

    public init(
        directoryPath: String,
        fileReports: [SourceVerificationReport],
        crossFileDuplicateTypes: [String],
        extraErrors: [SourceVerificationIssue] = []
    ) {
        self.directoryPath = directoryPath
        self.fileReports = fileReports
        self.crossFileDuplicateTypes = crossFileDuplicateTypes
        self.totalFilesVerified = fileReports.count
        self.totalLinesVerified = fileReports.reduce(0) { $0 + $1.lineCount }
        let fileErrors = fileReports.reduce(0) { acc, r in
            acc + r.issues.filter { $0.severity == .error }.count
        }
        self.totalErrorCount = fileErrors + extraErrors.count + crossFileDuplicateTypes.count
        self.isValid = self.totalErrorCount == 0
    }
}

// MARK: - Cross-Platform Swift Source Structural Verifier

/// Statically validates delimiter balance, string/comment termination, `#if/#elseif/#else/#endif` blocks, duplicate types, and SwiftUI `View` `body` contracts on any OS.
public enum ASTSourceVerifier: Sendable {
    /// Verifies a single Swift source string structurally (including code gated behind `#if canImport(SwiftUI)`).
    public static func verifySource(
        code: String,
        filePath: String? = nil
    ) -> SourceVerificationReport {
        var issues: [SourceVerificationIssue] = []
        let lineCount = max(1, code.isEmpty ? 1 : code.components(separatedBy: "\n").count)

        // 1. Lexical tokenization + string / block-comment termination verification
        let lexed = SwiftLexer.tokenize(code)
        for diag in lexed.diagnostics where diag.severity == .error {
            let issueKind: SourceVerificationIssueKind
            if diag.message.localizedCaseInsensitiveContains("comment") {
                issueKind = .unterminatedBlockComment
            } else {
                issueKind = .unterminatedStringLiteral
            }
            issues.append(
                SourceVerificationIssue(
                    kind: issueKind,
                    severity: .error,
                    filePath: filePath,
                    message: diag.message,
                    span: diag.span
                )
            )
        }

        // 2. Token-stream delimiter (`{}`, `()`, `[]`) & `#if / #elseif / #else / #endif` state-machine verification
        let delimiterStats = verifyDelimitersAndDirectives(
            tokens: lexed.tokens,
            filePath: filePath,
            issuesOut: &issues
        )

        // 3. AST-level duplicate nominal type check & SwiftUI `View` `var body` contract verification
        let ast = SwiftUIParser.parse(tokens: lexed.tokens, sourceLengthLines: lineCount, filePath: filePath)
        let (declaredTypes, verifiedViews) = verifyTypeAndViewContracts(
            ast: ast,
            filePath: filePath,
            issuesOut: &issues
        )

        return SourceVerificationReport(
            filePath: filePath,
            issues: issues,
            declaredTypes: declaredTypes,
            verifiedSwiftUIViews: verifiedViews,
            conditionalCompilationBlockCount: delimiterStats.conditionalBlockCount,
            matchedBracePairs: delimiterStats.bracePairs,
            matchedParenPairs: delimiterStats.parenPairs,
            matchedBracketPairs: delimiterStats.bracketPairs,
            lineCount: lineCount
        )
    }

    /// Recursively verifies all `.swift` files inside `directoryURL`.
    public static func verifyDirectory(
        at directoryURL: URL,
        recursive: Bool = true
    ) -> DirectoryVerificationReport {
        verifyDirectory(at: directoryURL.path, recursive: recursive)
    }

    /// Recursively verifies all `.swift` files inside `directoryPath` and checks cross-file nominal type collisions.
    public static func verifyDirectory(
        at directoryPath: String,
        recursive: Bool = true
    ) -> DirectoryVerificationReport {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directoryPath, isDirectory: &isDir), isDir.boolValue else {
            let missingIssue = SourceVerificationIssue(
                kind: .fileSystemReadError,
                severity: .error,
                filePath: directoryPath,
                message: "Directory does not exist or is not a folder: \(directoryPath)"
            )
            return DirectoryVerificationReport(
                directoryPath: directoryPath,
                fileReports: [],
                crossFileDuplicateTypes: [],
                extraErrors: [missingIssue]
            )
        }

        var swiftPaths: [String] = []
        if recursive {
            if let enumerator = fm.enumerator(atPath: directoryPath) {
                while let rel = enumerator.nextObject() as? String {
                    if rel.hasSuffix(".swift") && !rel.contains("/.build/") {
                        let joined = (directoryPath as NSString).appendingPathComponent(rel)
                        swiftPaths.append(joined)
                    }
                }
            }
        } else if let items = try? fm.contentsOfDirectory(atPath: directoryPath) {
            for item in items where item.hasSuffix(".swift") {
                swiftPaths.append((directoryPath as NSString).appendingPathComponent(item))
            }
        }

        swiftPaths.sort()

        var fileReports: [SourceVerificationReport] = []
        // Track top-level nominal types across files along with their conditional compilation branch key
        var crossFileTypeLocations: [String: Set<String>] = [:]
        var allExtensionBodies = Set<String>()

        // First collect all Swift ASTs & per-file structural reports
        var parsedASTsByPath: [(String, SwiftSourceFile)] = []
        for path in swiftPaths {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
                let errReport = SourceVerificationReport(
                    filePath: path,
                    issues: [
                        SourceVerificationIssue(
                            kind: .fileSystemReadError,
                            severity: .error,
                            filePath: path,
                            message: "Unable to read UTF-8 source file at \(path)."
                        )
                    ],
                    declaredTypes: [],
                    verifiedSwiftUIViews: [],
                    conditionalCompilationBlockCount: 0,
                    matchedBracePairs: 0,
                    matchedParenPairs: 0,
                    matchedBracketPairs: 0,
                    lineCount: 1
                )
                fileReports.append(errReport)
                continue
            }

            let ast = SwiftUIParser.parse(source: content, filePath: path)
            parsedASTsByPath.append((path, ast))
            for ext in ast.types where ext.kind == .extension {
                if ext.properties.contains(where: { $0.name == "body" }) {
                    allExtensionBodies.insert(ext.name)
                }
            }
        }

        for path in swiftPaths {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            var report = verifySource(code: content, filePath: path)

            // Filter out false-positive missingSwiftUIViewBody if `var body` is supplied by an extension in a sibling file
            if !allExtensionBodies.isEmpty {
                let filteredIssues = report.issues.filter { issue in
                    guard issue.kind == .missingSwiftUIViewBody else { return true }
                    return !allExtensionBodies.contains { viewName in issue.message.contains("'\(viewName)'") }
                }
                report = SourceVerificationReport(
                    filePath: report.filePath,
                    issues: filteredIssues,
                    declaredTypes: report.declaredTypes,
                    verifiedSwiftUIViews: report.verifiedSwiftUIViews,
                    conditionalCompilationBlockCount: report.conditionalCompilationBlockCount,
                    matchedBracePairs: report.matchedBracePairs,
                    matchedParenPairs: report.matchedParenPairs,
                    matchedBracketPairs: report.matchedBracketPairs,
                    lineCount: report.lineCount
                )
            }
            fileReports.append(report)
        }

        // Cross-file nominal duplicate check (respecting `#if` platform branches and `private`/`fileprivate` visibility)
        var crossDuplicates = Set<String>()
        for (path, ast) in parsedASTsByPath {
            for topDecl in ast.types where topDecl.kind != .extension {
                guard topDecl.accessLevel != .private && topDecl.accessLevel != .fileprivate else { continue }
                let scopeKey = "\(topDecl.name)|\(topDecl.conditionalDirective ?? "unconditional")"
                crossFileTypeLocations[scopeKey, default: []].insert(path)
                if (crossFileTypeLocations[scopeKey]?.count ?? 0) > 1 {
                    crossDuplicates.insert(topDecl.name)
                }
            }
        }

        return DirectoryVerificationReport(
            directoryPath: directoryPath,
            fileReports: fileReports,
            crossFileDuplicateTypes: crossDuplicates.sorted()
        )
    }

    // MARK: Delimiter & Conditional Compilation Verifier

    private struct DelimiterSummary {
        var bracePairs: Int = 0
        var parenPairs: Int = 0
        var bracketPairs: Int = 0
        var conditionalBlockCount: Int = 0
    }

    private struct OpenDelimiter {
        let symbol: SwiftPunctuation
        let span: SourceSpan
    }

    private struct ActivePoundIf {
        let startSpan: SourceSpan
        var seenElse: Bool
    }

    private static func verifyDelimitersAndDirectives(
        tokens: [SwiftToken],
        filePath: String?,
        issuesOut: inout [SourceVerificationIssue]
    ) -> DelimiterSummary {
        var summary = DelimiterSummary()
        var delimStack: [OpenDelimiter] = []
        var poundIfStack: [ActivePoundIf] = []

        for tok in tokens where !tok.isEOF {
            // Also verify balanced parentheses inside string interpolations `\(...)`
            if case .interpolatedStringSegment(_, let exprStrings, _, _) = tok.kind {
                for exprStr in exprStrings {
                    let subLex = SwiftLexer.tokenize(exprStr)
                    var subIssues: [SourceVerificationIssue] = []
                    _ = verifyDelimitersAndDirectives(tokens: subLex.tokens, filePath: filePath, issuesOut: &subIssues)
                    for sub in subIssues {
                        issuesOut.append(
                            SourceVerificationIssue(
                                kind: sub.kind,
                                severity: sub.severity,
                                filePath: filePath,
                                message: "Inside string interpolation: \(sub.message)",
                                span: tok.span
                            )
                        )
                    }
                }
            }

            if case .directive(let dirKind) = tok.kind {
                switch dirKind {
                case .poundIf:
                    poundIfStack.append(ActivePoundIf(startSpan: tok.span, seenElse: false))
                case .poundElseif:
                    if poundIfStack.isEmpty {
                        issuesOut.append(
                            SourceVerificationIssue(
                                kind: .unbalancedConditionalCompilation,
                                filePath: filePath,
                                message: "Encountered '#elseif' without an opening '#if'.",
                                span: tok.span
                            )
                        )
                    } else if poundIfStack[poundIfStack.count - 1].seenElse {
                        issuesOut.append(
                            SourceVerificationIssue(
                                kind: .invalidConditionalDirectiveOrder,
                                filePath: filePath,
                                message: "'#elseif' cannot appear after '#else' in the same conditional block.",
                                span: tok.span
                            )
                        )
                    }
                case .poundElse:
                    if poundIfStack.isEmpty {
                        issuesOut.append(
                            SourceVerificationIssue(
                                kind: .unbalancedConditionalCompilation,
                                filePath: filePath,
                                message: "Encountered '#else' without an opening '#if'.",
                                span: tok.span
                            )
                        )
                    } else if poundIfStack[poundIfStack.count - 1].seenElse {
                        issuesOut.append(
                            SourceVerificationIssue(
                                kind: .invalidConditionalDirectiveOrder,
                                filePath: filePath,
                                message: "Duplicate '#else' clause inside the same '#if' block.",
                                span: tok.span
                            )
                        )
                    } else {
                        poundIfStack[poundIfStack.count - 1].seenElse = true
                    }
                case .poundEndif:
                    if poundIfStack.popLast() != nil {
                        summary.conditionalBlockCount += 1
                    } else {
                        issuesOut.append(
                            SourceVerificationIssue(
                                kind: .unbalancedConditionalCompilation,
                                filePath: filePath,
                                message: "Orphan '#endif' without a matching '#if'.",
                                span: tok.span
                            )
                        )
                    }
                default:
                    break
                }
            }

            guard case .punctuation(let punct) = tok.kind else { continue }
            switch punct {
            case .leftBrace, .leftParen, .leftBracket:
                delimStack.append(OpenDelimiter(symbol: punct, span: tok.span))
            case .rightBrace:
                matchClosing(.rightBrace, expectedOpen: .leftBrace, kind: .unbalancedBraces, span: tok.span, filePath: filePath, stack: &delimStack, pairsCounter: &summary.bracePairs, issuesOut: &issuesOut)
            case .rightParen:
                matchClosing(.rightParen, expectedOpen: .leftParen, kind: .unbalancedParentheses, span: tok.span, filePath: filePath, stack: &delimStack, pairsCounter: &summary.parenPairs, issuesOut: &issuesOut)
            case .rightBracket:
                matchClosing(.rightBracket, expectedOpen: .leftBracket, kind: .unbalancedBrackets, span: tok.span, filePath: filePath, stack: &delimStack, pairsCounter: &summary.bracketPairs, issuesOut: &issuesOut)
            default:
                break
            }
        }

        for unclosed in delimStack {
            let kind: SourceVerificationIssueKind
            switch unclosed.symbol {
            case .leftBrace: kind = .unbalancedBraces
            case .leftParen: kind = .unbalancedParentheses
            default: kind = .unbalancedBrackets
            }
            issuesOut.append(
                SourceVerificationIssue(
                    kind: kind,
                    filePath: filePath,
                    message: "Unclosed '\(unclosed.symbol.rawValue)' opened at \(unclosed.span.start).",
                    span: unclosed.span
                )
            )
        }

        for unclosedIf in poundIfStack {
            issuesOut.append(
                SourceVerificationIssue(
                    kind: .unbalancedConditionalCompilation,
                    filePath: filePath,
                    message: "Unclosed '#if' directive opened at \(unclosedIf.startSpan.start) (missing '#endif').",
                    span: unclosedIf.startSpan
                )
            )
        }

        return summary
    }

    private static func matchClosing(
        _ closing: SwiftPunctuation,
        expectedOpen: SwiftPunctuation,
        kind: SourceVerificationIssueKind,
        span: SourceSpan,
        filePath: String?,
        stack: inout [OpenDelimiter],
        pairsCounter: inout Int,
        issuesOut: inout [SourceVerificationIssue]
    ) {
        guard let top = stack.last else {
            issuesOut.append(
                SourceVerificationIssue(
                    kind: kind,
                    filePath: filePath,
                    message: "Unexpected closing '\(closing.rawValue)' with no matching '\(expectedOpen.rawValue)'.",
                    span: span
                )
            )
            return
        }
        if top.symbol == expectedOpen {
            _ = stack.popLast()
            pairsCounter += 1
        } else {
            _ = stack.popLast()
            issuesOut.append(
                SourceVerificationIssue(
                    kind: kind,
                    filePath: filePath,
                    message: "Mismatched closing '\(closing.rawValue)'; expected closure for '\(top.symbol.rawValue)' opened at \(top.span.start).",
                    span: span
                )
            )
        }
    }

    // MARK: Duplicate Type & SwiftUI `View` Body Contract Verification

    private static func verifyTypeAndViewContracts(
        ast: SwiftSourceFile,
        filePath: String?,
        issuesOut: inout [SourceVerificationIssue]
    ) -> (declaredTypes: [String], verifiedViews: [String]) {
        var declaredNames: [String] = []
        var verifiedViews: [String] = []
        var seenScopedNominalKeys = Set<String>()

        let extensionBodyProviders = Set(
            ast.types
                .filter { $0.kind == .extension && $0.properties.contains(where: { $0.name == "body" }) }
                .map(\.name)
        )

        func inspectLevel(_ types: [SwiftTypeDecl], parentQualifier: String?) {
            for decl in types {
                let qualified = parentQualifier.map { "\($0).\(decl.name)" } ?? decl.name
                if decl.kind != .extension {
                    declaredNames.append(qualified)
                    let scopeKey = "\(qualified)|\(decl.conditionalDirective ?? "unconditional")"
                    if !seenScopedNominalKeys.insert(scopeKey).inserted {
                        issuesOut.append(
                            SourceVerificationIssue(
                                kind: .duplicateTypeDeclaration,
                                filePath: filePath,
                                message: "Duplicate nominal \(decl.kind.rawValue) declaration '\(qualified)' in the same compilation scope.",
                                span: decl.span
                            )
                        )
                    }
                }

                // Check SwiftUI `View` `var body` requirement on concrete structs/classes
                if (decl.kind == .struct || decl.kind == .class) && decl.conformances.contains("View") {
                    let hasBodyDirectly = decl.properties.contains { $0.name == "body" }
                    let hasBodyViaExtension = extensionBodyProviders.contains(decl.name) || extensionBodyProviders.contains(qualified)
                    if hasBodyDirectly || hasBodyViaExtension {
                        verifiedViews.append(qualified)
                    } else {
                        issuesOut.append(
                            SourceVerificationIssue(
                                kind: .missingSwiftUIViewBody,
                                filePath: filePath,
                                message: "SwiftUI View '\(qualified)' conforms to 'View' but does not declare a 'var body: some View' property.",
                                span: decl.span
                            )
                        )
                    }
                }

                inspectLevel(decl.nestedTypes, parentQualifier: qualified)
            }
        }

        inspectLevel(ast.types, parentQualifier: nil)
        return (declaredNames, verifiedViews)
    }
}
