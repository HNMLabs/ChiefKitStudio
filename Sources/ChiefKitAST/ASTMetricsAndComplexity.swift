import ChiefKitStudioCore
import Foundation

// MARK: - Halstead, Complexity & Maintainability Models

/// Risk tier for McCabe cyclomatic or Sonar cognitive complexity scores.
public enum ComplexityRiskRating: String, Codable, Hashable, CaseIterable, Sendable {
    case low = "Low Risk"
    case moderate = "Moderate Risk"
    case high = "High Risk"
    case veryHigh = "Very High Risk"

    public static func evaluate(cyclomatic: Int, cognitive: Int) -> ComplexityRiskRating {
        let score = max(cyclomatic, cognitive)
        switch score {
        case ..<11: return .low
        case 11..<21: return .moderate
        case 21..<40: return .high
        default: return .veryHigh
        }
    }
}

/// Complete Halstead software science metrics computed from lexical operators and operands.
public struct HalsteadMetrics: Codable, Equatable, Sendable {
    public let distinctOperators: Int
    public let distinctOperands: Int
    public let totalOperators: Int
    public let totalOperands: Int
    public let vocabulary: Int
    public let programLength: Int
    public let calculatedLength: Double
    public let volume: Double
    public let difficulty: Double
    public let effort: Double
    public let timeToProgramSeconds: Double
    public let estimatedBugs: Double

    public init(distinctOperators: Int, distinctOperands: Int, totalOperators: Int, totalOperands: Int) {
        let n1 = max(0, distinctOperators)
        let n2 = max(0, distinctOperands)
        let bigN1 = max(0, totalOperators)
        let bigN2 = max(0, totalOperands)

        let vocab = n1 + n2
        let length = bigN1 + bigN2
        let log2n1 = n1 > 0 ? log2(Double(n1)) : 0.0
        let log2n2 = n2 > 0 ? log2(Double(n2)) : 0.0
        let calcLen = Double(n1) * log2n1 + Double(n2) * log2n2
        let vol = vocab > 0 ? Double(length) * log2(Double(vocab)) : 0.0
        let diff = (n1 > 0 && n2 > 0) ? (Double(n1) / 2.0) * (Double(bigN2) / Double(n2)) : 0.0
        let eff = diff * vol

        self.distinctOperators = n1
        self.distinctOperands = n2
        self.totalOperators = bigN1
        self.totalOperands = bigN2
        self.vocabulary = vocab
        self.programLength = length
        self.calculatedLength = calcLen
        self.volume = vol
        self.difficulty = diff
        self.effort = eff
        self.timeToProgramSeconds = eff / 18.0
        self.estimatedBugs = vol / 3000.0
    }
}

/// Complexity breakdown for a single function, initializer, or computed property.
public struct FunctionComplexityProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: String { qualifiedName }
    public let qualifiedName: String
    public let cyclomaticComplexity: Int
    public let cognitiveComplexity: Int
    public let statementCount: Int
    public let maxNestingDepth: Int
    public let parameterCount: Int
    public let riskRating: ComplexityRiskRating

    public init(
        qualifiedName: String,
        cyclomaticComplexity: Int,
        cognitiveComplexity: Int,
        statementCount: Int,
        maxNestingDepth: Int,
        parameterCount: Int
    ) {
        self.qualifiedName = qualifiedName
        self.cyclomaticComplexity = max(1, cyclomaticComplexity)
        self.cognitiveComplexity = max(0, cognitiveComplexity)
        self.statementCount = max(0, statementCount)
        self.maxNestingDepth = max(0, maxNestingDepth)
        self.parameterCount = max(0, parameterCount)
        self.riskRating = ComplexityRiskRating.evaluate(
            cyclomatic: cyclomaticComplexity,
            cognitive: cognitiveComplexity
        )
    }
}

/// Structural SwiftUI layout & state-coupling profile for a single `View` declaration.
public struct ViewComplexityProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: String { viewName }
    public let viewName: String
    public let totalViewNodes: Int
    public let maxViewTreeDepth: Int
    public let totalModifiers: Int
    public let modifierPerViewRatio: Double
    public let conditionalBranches: Int
    public let statePropertyCount: Int
    public let bindingPropertyCount: Int
    public let stateCouplingScore: Double

    public init(
        viewName: String,
        totalViewNodes: Int,
        maxViewTreeDepth: Int,
        totalModifiers: Int,
        conditionalBranches: Int,
        statePropertyCount: Int,
        bindingPropertyCount: Int
    ) {
        self.viewName = viewName
        self.totalViewNodes = max(0, totalViewNodes)
        self.maxViewTreeDepth = max(0, maxViewTreeDepth)
        self.totalModifiers = max(0, totalModifiers)
        self.modifierPerViewRatio = totalViewNodes > 0 ? Double(totalModifiers) / Double(totalViewNodes) : 0.0
        self.conditionalBranches = max(0, conditionalBranches)
        self.statePropertyCount = max(0, statePropertyCount)
        self.bindingPropertyCount = max(0, bindingPropertyCount)

        // State-coupling score in [0, 100]: higher indicates heavier mutable state density
        let rawCoupling = Double(statePropertyCount) * 14.0
            + Double(bindingPropertyCount) * 9.0
            + Double(conditionalBranches) * 6.5
        self.stateCouplingScore = min(100.0, max(0.0, rawCoupling))
    }
}

/// Comprehensive software engineering metrics report for a Swift 6 / SwiftUI file.
public struct ASTMetricsReport: Codable, Equatable, Sendable {
    public let physicalLines: Int
    public let logicalCodeLines: Int
    public let commentLines: Int
    public let blankLines: Int
    public let cyclomaticComplexityTotal: Int
    public let cyclomaticComplexityAverage: Double
    public let cognitiveComplexityTotal: Int
    public let halstead: HalsteadMetrics
    public let viewTreeDepth: Int
    public let modifierPerViewRatio: Double
    public let stateCouplingScore: Double
    public let maintainabilityIndex: Double
    public let functionProfiles: [FunctionComplexityProfile]
    public let viewProfiles: [ViewComplexityProfile]

    public var maintainabilityGrade: String {
        switch maintainabilityIndex {
        case 85...: return "A (Highly Maintainable)"
        case 70..<85: return "B (Healthy)"
        case 50..<70: return "C (Moderate Debt)"
        default: return "D (Refactor Recommended)"
        }
    }
}

// MARK: - AST Metrics & Complexity Calculator Engine

/// Computes McCabe cyclomatic complexity, Sonar cognitive complexity, Halstead metrics, view ratios, and SEI maintainability index.
public enum ASTMetricsAndComplexity: Sendable {
    public static func analyze(source: String) -> ASTMetricsReport {
        let lex = SwiftLexer.tokenize(source)
        let ast = SwiftUIParser.parse(tokens: lex.tokens, sourceLengthLines: countPhysicalLines(source))
        return analyze(ast: ast, tokens: lex.tokens, rawSource: source)
    }

    public static func analyze(
        ast: SwiftSourceFile,
        tokens: [SwiftToken],
        rawSource: String? = nil
    ) -> ASTMetricsReport {
        let halstead = computeHalstead(from: tokens)
        let (physLines, codeLines, commentLines, blankLines) = computeLineBreakdown(rawSource: rawSource, tokens: tokens, fallbackLines: ast.lineCount)

        var fnProfiles: [FunctionComplexityProfile] = []
        var viewProfiles: [ViewComplexityProfile] = []

        for fn in ast.topLevelFunctions {
            fnProfiles.append(profileFunction(fn, typePrefix: nil))
        }

        for typeDecl in ast.allTypesFlattened() {
            for fn in typeDecl.functions {
                fnProfiles.append(profileFunction(fn, typePrefix: typeDecl.name))
            }
            for prop in typeDecl.properties where prop.isComputed && prop.computedViewBody.isEmpty {
                let (cyc, cog, stmts, depth) = measureStatements(prop.computedStatements)
                fnProfiles.append(
                    FunctionComplexityProfile(
                        qualifiedName: "\(typeDecl.name).\(prop.name)",
                        cyclomaticComplexity: cyc,
                        cognitiveComplexity: cog,
                        statementCount: stmts,
                        maxNestingDepth: depth,
                        parameterCount: 0
                    )
                )
            }
            if typeDecl.isSwiftUIView {
                let vp = profileViewType(typeDecl)
                viewProfiles.append(vp)
                // Also include `body` complexity in function profiles
                let (vCyc, vCog) = measureViewBranches(typeDecl.bodyViewNodes, nesting: 0)
                fnProfiles.append(
                    FunctionComplexityProfile(
                        qualifiedName: "\(typeDecl.name).body",
                        cyclomaticComplexity: 1 + vCyc,
                        cognitiveComplexity: vCog,
                        statementCount: vp.totalViewNodes,
                        maxNestingDepth: vp.maxViewTreeDepth,
                        parameterCount: 0
                    )
                )
            }
        }

        let cycTotal = max(1, fnProfiles.reduce(0) { $0 + $1.cyclomaticComplexity })
        let cycAvg = fnProfiles.isEmpty ? 1.0 : Double(cycTotal) / Double(fnProfiles.count)
        let cogTotal = fnProfiles.reduce(0) { $0 + $1.cognitiveComplexity }

        let maxViewDepth = viewProfiles.map(\.maxViewTreeDepth).max() ?? 0
        let totalViews = viewProfiles.reduce(0) { $0 + $1.totalViewNodes }
        let totalMods = viewProfiles.reduce(0) { $0 + $1.totalModifiers }
        let modRatio = totalViews > 0 ? Double(totalMods) / Double(totalViews) : 0.0
        let avgCoupling = viewProfiles.isEmpty
            ? 0.0
            : viewProfiles.reduce(0.0) { $0 + $1.stateCouplingScore } / Double(viewProfiles.count)

        let maintainability = computeMaintainabilityIndex(
            halsteadVolume: halstead.volume,
            cyclomaticAverage: cycAvg,
            logicalLOC: max(1, codeLines),
            commentRatio: physLines > 0 ? Double(commentLines) / Double(physLines) : 0.0
        )

        return ASTMetricsReport(
            physicalLines: physLines,
            logicalCodeLines: codeLines,
            commentLines: commentLines,
            blankLines: blankLines,
            cyclomaticComplexityTotal: cycTotal,
            cyclomaticComplexityAverage: cycAvg,
            cognitiveComplexityTotal: cogTotal,
            halstead: halstead,
            viewTreeDepth: maxViewDepth,
            modifierPerViewRatio: modRatio,
            stateCouplingScore: avgCoupling,
            maintainabilityIndex: maintainability,
            functionProfiles: fnProfiles,
            viewProfiles: viewProfiles
        )
    }

    // MARK: Halstead Calculation

    private static func computeHalstead(from tokens: [SwiftToken]) -> HalsteadMetrics {
        var operatorSet = Set<String>()
        var operandSet = Set<String>()
        var totalOps = 0
        var totalOpds = 0

        for tok in tokens where !tok.isEOF {
            switch tok.kind {
            case .keyword(let kw):
                if kw == .self || kw == .Self || kw == .super {
                    operandSet.insert(kw.rawValue)
                    totalOpds += 1
                } else {
                    operatorSet.insert(kw.rawValue)
                    totalOps += 1
                }
            case .operatorSymbol(let sym, _):
                operatorSet.insert(sym)
                totalOps += 1
            case .punctuation(let punct):
                switch punct {
                case .leftParen, .leftBrace, .leftBracket, .period, .comma, .colon, .arrow, .equal, .questionMark, .ellipsis, .halfOpenRange:
                    operatorSet.insert(punct.rawValue)
                    totalOps += 1
                default:
                    break
                }
            case .attribute(let attr):
                operatorSet.insert(attr.formattedAttribute)
                totalOps += 1
            case .directive(let dir):
                operatorSet.insert(dir.rawValue)
                totalOps += 1
            case .identifier(let name, _):
                operandSet.insert(name)
                totalOpds += 1
            case .dollarIdentifier(let name):
                operandSet.insert(name)
                totalOpds += 1
            case .integerLiteral(let raw, _, _), .floatingLiteral(let raw, _, _):
                operandSet.insert(raw)
                totalOpds += 1
            case .stringLiteral(_, let val, _, _):
                operandSet.insert("\"\(val)\"")
                totalOpds += 1
            case .interpolatedStringSegment(let raw, _, _, _):
                operandSet.insert(raw)
                totalOpds += 1
            case .booleanLiteral(let b):
                operandSet.insert(b ? "true" : "false")
                totalOpds += 1
            case .nilLiteral:
                operandSet.insert("nil")
                totalOpds += 1
            case .eof, .unknown:
                break
            }
        }

        return HalsteadMetrics(
            distinctOperators: operatorSet.count,
            distinctOperands: operandSet.count,
            totalOperators: totalOps,
            totalOperands: totalOpds
        )
    }

    // MARK: Cyclomatic & Cognitive Complexity Visitors

    private static func profileFunction(_ fn: SwiftFunctionDecl, typePrefix: String?) -> FunctionComplexityProfile {
        let qName = typePrefix.map { "\($0).\(fn.name)" } ?? fn.name
        if !fn.viewBody.isEmpty {
            let (vCyc, vCog) = measureViewBranches(fn.viewBody, nesting: 0)
            let depth = fn.viewBody.map(\.maxDepth).max() ?? 1
            let count = fn.viewBody.reduce(0) { $0 + $1.totalNodeCount }
            return FunctionComplexityProfile(
                qualifiedName: qName,
                cyclomaticComplexity: 1 + vCyc,
                cognitiveComplexity: vCog,
                statementCount: count,
                maxNestingDepth: depth,
                parameterCount: fn.parameters.count
            )
        }

        let (cyc, cog, stmtCount, maxDepth) = measureStatements(fn.statements)
        return FunctionComplexityProfile(
            qualifiedName: qName,
            cyclomaticComplexity: cyc,
            cognitiveComplexity: cog,
            statementCount: stmtCount,
            maxNestingDepth: maxDepth,
            parameterCount: fn.parameters.count
        )
    }

    private static func measureStatements(_ statements: [SwiftStatement]) -> (cyc: Int, cog: Int, count: Int, depth: Int) {
        var cyc = 1
        var cog = 0
        var count = 0
        var deepest = 0

        func walk(_ stmts: [SwiftStatement], nesting: Int) {
            for stmt in stmts {
                count += 1
                deepest = max(deepest, nesting + 1)
                switch stmt {
                case .ifStmt(let cond, let thenB, let elseB):
                    let boolOps = countBooleanOperators(in: cond)
                    cyc += 1 + boolOps
                    cog += (1 + nesting) + boolOps
                    walk(thenB, nesting: nesting + 1)
                    if !elseB.isEmpty {
                        cog += 1
                        walk(elseB, nesting: nesting + 1)
                    }
                case .guardStmt(let cond, let elseB):
                    let boolOps = countBooleanOperators(in: cond)
                    cyc += 1 + boolOps
                    cog += (1 + nesting) + boolOps
                    walk(elseB, nesting: nesting + 1)
                case .switchStmt(let subj, let cases):
                    let exprOps = countExprDecisionPoints(subj)
                    cyc += exprOps
                    cog += (1 + nesting) + exprOps
                    for c in cases {
                        if !c.isDefault { cyc += max(1, c.patterns.count) }
                        walk(c.statements, nesting: nesting + 1)
                    }
                case .forLoop(_, let seq, let body):
                    cyc += 1 + countExprDecisionPoints(seq)
                    cog += (1 + nesting)
                    walk(body, nesting: nesting + 1)
                case .whileLoop(let cond, let body):
                    let d = countExprDecisionPoints(cond)
                    cyc += 1 + d
                    cog += (1 + nesting) + d
                    walk(body, nesting: nesting + 1)
                case .doCatch(let doB, let catches):
                    walk(doB, nesting: nesting + 1)
                    for c in catches {
                        cyc += 1
                        cog += (1 + nesting)
                        walk(c.statements, nesting: nesting + 1)
                    }
                case .variableDecl(let prop):
                    if let initExpr = prop.initializer {
                        let d = countExprDecisionPoints(initExpr)
                        cyc += d
                        cog += d
                    }
                case .assignment(_, _, let val), .expression(let val), .throwStmt(let val):
                    let d = countExprDecisionPoints(val)
                    cyc += d
                    cog += d
                case .returnStmt(let expr):
                    if let expr {
                        let d = countExprDecisionPoints(expr)
                        cyc += d
                        cog += d
                    }
                case .deferStmt(let body):
                    walk(body, nesting: nesting + 1)
                case .breakStmt, .continueStmt:
                    break
                }
            }
        }

        walk(statements, nesting: 0)
        return (cyc, cog, count, deepest)
    }

    private static func measureViewBranches(_ nodes: [SwiftViewNode], nesting: Int) -> (cyc: Int, cog: Int) {
        var cyc = 0
        var cog = 0

        for node in nodes {
            if !node.actionStatements.isEmpty {
                let (aCyc, aCog, _, _) = measureStatements(node.actionStatements)
                cyc += max(0, aCyc - 1)
                cog += aCog
            }
            for mod in node.modifiers {
                if let stmts = mod.trailingClosure?.statements, !stmts.isEmpty {
                    let (mCyc, mCog, _, _) = measureStatements(stmts)
                    cyc += max(0, mCyc - 1)
                    cog += mCog
                }
            }
            if node.containerKind == .conditionalIf {
                let bOps = countBooleanOperators(in: node.conditionDescription ?? "")
                cyc += 1 + bOps
                cog += (1 + nesting) + bOps
                let (c1, g1) = measureViewBranches(node.children, nesting: nesting + 1)
                cyc += c1; cog += g1
                if !node.elseChildren.isEmpty {
                    cog += 1
                    let (c2, g2) = measureViewBranches(node.elseChildren, nesting: nesting + 1)
                    cyc += c2; cog += g2
                }
            } else if node.containerKind == .conditionalSwitch {
                cog += 1 + nesting
                for c in node.switchCases {
                    if !c.isDefault { cyc += 1 }
                    let (cs, gs) = measureViewBranches(c.viewChildren, nesting: nesting + 1)
                    cyc += cs; cog += gs
                }
            } else {
                if node.containerKind == .forEach {
                    cyc += 1
                    cog += 1 + nesting
                }
                let (cChild, gChild) = measureViewBranches(node.children, nesting: nesting)
                cyc += cChild; cog += gChild
            }
        }
        return (cyc, cog)
    }

    private static func profileViewType(_ decl: SwiftTypeDecl) -> ViewComplexityProfile {
        let roots = decl.bodyViewNodes
        let totalNodes = roots.reduce(0) { $0 + $1.totalNodeCount }
        let maxDepth = roots.map(\.maxDepth).max() ?? 0
        let totalMods = roots.reduce(0) { $0 + $1.totalModifierCount }
        let (branchCount, _) = measureViewBranches(roots, nesting: 0)

        let stateCount = decl.properties.filter {
            $0.hasWrapper(.state) || $0.hasWrapper(.stateObject) || $0.hasWrapper(.appStorage)
        }.count
        let bindingCount = decl.properties.filter {
            $0.hasWrapper(.binding) || $0.hasWrapper(.bindable) || $0.hasWrapper(.observedObject) || $0.hasWrapper(.environment)
        }.count

        return ViewComplexityProfile(
            viewName: decl.name,
            totalViewNodes: totalNodes,
            maxViewTreeDepth: maxDepth,
            totalModifiers: totalMods,
            conditionalBranches: branchCount,
            statePropertyCount: stateCount,
            bindingPropertyCount: bindingCount
        )
    }

    private static func countBooleanOperators(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let ands = text.components(separatedBy: "&&").count - 1
        let ors = text.components(separatedBy: "||").count - 1
        let coalesces = text.components(separatedBy: "??").count - 1
        return max(0, ands + ors + coalesces)
    }

    private static func countExprDecisionPoints(_ expr: SwiftExpr) -> Int {
        switch expr {
        case .binaryOp(let l, let op, let r):
            let selfPoint = (op == "&&" || op == "||" || op == "??") ? 1 : 0
            return selfPoint + countExprDecisionPoints(l) + countExprDecisionPoints(r)
        case .ternary(let c, let t, let e):
            return 1 + countExprDecisionPoints(c) + countExprDecisionPoints(t) + countExprDecisionPoints(e)
        case .call(let callee, let args, _):
            return countExprDecisionPoints(callee) + args.reduce(0) { $0 + countExprDecisionPoints($1.value) }
        default:
            return 0
        }
    }

    // MARK: Maintainability Index (0–100) & Line Breakdown

    private static func computeMaintainabilityIndex(
        halsteadVolume: Double,
        cyclomaticAverage: Double,
        logicalLOC: Int,
        commentRatio: Double
    ) -> Double {
        let safeVol = max(1.0, halsteadVolume)
        let safeLOC = max(1.0, Double(logicalLOC))
        // Classic SEI Maintainability Index normalized to [0, 100] with optional comment clarity bonus
        let rawSEI = 171.0 - 5.2 * log(safeVol) - 0.23 * cyclomaticAverage - 16.2 * log(safeLOC)
        let commentBonus = min(12.0, 50.0 * sin(sqrt(max(0.0, 2.4 * commentRatio))))
        let normalized = ((rawSEI + commentBonus) / 171.0) * 100.0
        return min(100.0, max(0.0, (normalized * 10.0).rounded() / 10.0))
    }

    private static func countPhysicalLines(_ s: String) -> Int {
        s.isEmpty ? 1 : s.components(separatedBy: "\n").count
    }

    private static func computeLineBreakdown(
        rawSource: String?,
        tokens: [SwiftToken],
        fallbackLines: Int
    ) -> (physical: Int, code: Int, comment: Int, blank: Int) {
        if let rawSource {
            let lines = rawSource.components(separatedBy: "\n")
            var code = 0
            var comments = 0
            var blanks = 0
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.isEmpty {
                    blanks += 1
                } else if t.hasPrefix("//") || t.hasPrefix("/*") || t.hasPrefix("*") {
                    comments += 1
                } else {
                    code += 1
                }
            }
            return (max(1, lines.count), code, comments, blanks)
        }

        let summary = TokenStreamSummary(tokens: tokens)
        let phys = max(fallbackLines, summary.totalLines)
        let comm = summary.commentCount
        let code = max(1, phys - comm)
        return (phys, code, comm, 0)
    }
}
