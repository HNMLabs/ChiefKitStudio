import Foundation

// MARK: - Runtime Values, Field Kinds & Validation Rules

public enum FlowRuntimeValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public static func infer(from raw: String) -> FlowRuntimeValue {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "true" { return .bool(true) }
        if trimmed.lowercased() == "false" { return .bool(false) }
        if let num = Double(trimmed) { return .number(num) }
        return .string(raw)
    }

    public var stringRepresentation: String {
        switch self {
        case .string(let s): s
        case .number(let n): n.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int64(n))" : "\(n)"
        case .bool(let b): b ? "true" : "false"
        case .null: ""
        }
    }

    public var numericValue: Double? {
        switch self {
        case .number(let n): n
        case .string(let s): Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
        case .bool(let b): b ? 1.0 : 0.0
        case .null: nil
        }
    }

    public var boolValue: Bool {
        switch self {
        case .bool(let b): b
        case .number(let n): n != 0
        case .string(let s): !s.isEmpty && s.lowercased() != "false" && s != "0"
        case .null: false
        }
    }
}

public enum FlowFieldKind: Codable, Hashable, Sendable {
    case text
    case email
    case phoneE164
    case iban
    case integer
    case decimal
    case booleanToggle
    case singleChoice([String])
    case ratingScale(min: Int, max: Int)
}

public enum FlowValidationRule: Codable, Hashable, Sendable {
    case required
    case email
    case iban
    case phoneE164
    case minLength(Int)
    case maxLength(Int)
    case numericRange(min: Double, max: Double)
    case regex(pattern: String, message: String)

    /// Returns `nil` when `rawInput` satisfies the rule, or an actionable error message on failure.
    public func validate(_ rawInput: String) -> String? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

        switch self {
        case .required:
            return trimmed.isEmpty ? "This field is required." : nil

        case .email:
            guard !trimmed.isEmpty else { return nil }
            let emailPattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
            return Self.matchesRegex(trimmed, pattern: emailPattern) ? nil : "Enter a valid email address."

        case .phoneE164:
            guard !trimmed.isEmpty else { return nil }
            let e164Pattern = #"^\+[1-9]\d{6,14}$"#
            return Self.matchesRegex(trimmed, pattern: e164Pattern) ? nil : "Enter an international E.164 phone number (e.g. +14155552671)."

        case .iban:
            guard !trimmed.isEmpty else { return nil }
            return Self.validateISO13616IBAN(trimmed) ? nil : "Invalid IBAN checksum or country format."

        case .minLength(let minChars):
            return rawInput.count < minChars ? "Must be at least \(minChars) characters." : nil

        case .maxLength(let maxChars):
            return rawInput.count > maxChars ? "Must be at most \(maxChars) characters." : nil

        case .numericRange(let minVal, let maxVal):
            guard !trimmed.isEmpty else { return nil }
            guard let numeric = Double(trimmed) else {
                return "Enter a numeric value between \(minVal) and \(maxVal)."
            }
            if numeric < minVal || numeric > maxVal {
                return "Value must be between \(minVal) and \(maxVal)."
            }
            return nil

        case .regex(let pattern, let message):
            guard !trimmed.isEmpty else { return nil }
            return Self.matchesRegex(trimmed, pattern: pattern) ? nil : message
        }
    }

    private static func matchesRegex(_ input: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.firstMatch(in: input, range: range) != nil
    }

    /// Performs official ISO 13616 IBAN rearrangement and Modulo-97 verification.
    private static func validateISO13616IBAN(_ raw: String) -> Bool {
        let compact = raw.replacingOccurrences(of: " ", with: "").uppercased()
        guard compact.count >= 15 && compact.count <= 34 else { return false }
        let chars = Array(compact)
        guard chars[0].isLetter && chars[1].isLetter && chars[2].isNumber && chars[3].isNumber else {
            return false
        }
        let rearranged = String(chars[4...]) + String(chars[0..<4])
        var remainder = 0
        for ch in rearranged {
            if let digit = ch.wholeNumberValue {
                remainder = (remainder * 10 + digit) % 97
            } else if let ascii = ch.asciiValue, ascii >= 65 && ascii <= 90 {
                let mapped = Int(ascii - 55) // 'A' -> 10 ... 'Z' -> 35
                remainder = (remainder * 100 + mapped) % 97
            } else {
                return false
            }
        }
        return remainder == 1
    }
}

// MARK: - Conditional Flow Specification Models

public struct FlowFieldSpec: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var placeholder: String
    public var kind: FlowFieldKind
    public var defaultValue: String?
    public var validationRules: [FlowValidationRule]

    public init(
        id: String,
        label: String,
        placeholder: String = "",
        kind: FlowFieldKind = .text,
        defaultValue: String? = nil,
        validationRules: [FlowValidationRule] = []
    ) {
        self.id = id
        self.label = label
        self.placeholder = placeholder
        self.kind = kind
        self.defaultValue = defaultValue
        self.validationRules = validationRules
    }
}

public struct FlowBranchRule: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var predicateExpression: String
    public var targetStepID: String
    public var summary: String

    public init(
        id: String,
        predicateExpression: String,
        targetStepID: String,
        summary: String = ""
    ) {
        self.id = id
        self.predicateExpression = predicateExpression
        self.targetStepID = targetStepID
        self.summary = summary
    }
}

public struct FlowStepSpec: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var markdownBody: String
    public var isTerminalCompletion: Bool
    public var fields: [FlowFieldSpec]
    public var branches: [FlowBranchRule]
    public var fallbackNextStepID: String?

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        markdownBody: String = "",
        isTerminalCompletion: Bool = false,
        fields: [FlowFieldSpec] = [],
        branches: [FlowBranchRule] = [],
        fallbackNextStepID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.markdownBody = markdownBody
        self.isTerminalCompletion = isTerminalCompletion
        self.fields = fields
        self.branches = branches
        self.fallbackNextStepID = fallbackNextStepID
    }
}

public struct ConditionalFlowSpec: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var version: String
    public var entryStepID: String
    public var steps: [FlowStepSpec]
    public var initialVariables: [String: FlowRuntimeValue]

    public init(
        id: String,
        title: String,
        version: String = "3.0",
        entryStepID: String,
        steps: [FlowStepSpec],
        initialVariables: [String: FlowRuntimeValue] = [:]
    ) {
        self.id = id
        self.title = title
        self.version = version
        self.entryStepID = entryStepID
        self.steps = steps
        self.initialVariables = initialVariables
    }

    public func step(withID stepID: String) -> FlowStepSpec? {
        steps.first { $0.id == stepID }
    }

    public static func upgrade(from legacy: FlowDefinition) -> ConditionalFlowSpec {
        let converted: [FlowStepSpec] = legacy.pages.enumerated().map { idx, page in
            let nextID = (idx + 1 < legacy.pages.count) ? legacy.pages[idx + 1].id : nil
            let isLast = (idx == legacy.pages.count - 1) || page.style.lowercased() == "completion"
            return FlowStepSpec(
                id: page.id,
                title: page.title,
                subtitle: page.style.capitalized,
                markdownBody: page.body,
                isTerminalCompletion: isLast && nextID == nil,
                fields: [],
                branches: [],
                fallbackNextStepID: nextID
            )
        }
        return ConditionalFlowSpec(
            id: SchemaNamingHelpers.snakeCase(legacy.title.isEmpty ? "flow" : legacy.title),
            title: legacy.title,
            entryStepID: converted.first?.id ?? "start",
            steps: converted
        )
    }

    public func toLegacyFlowDefinition() -> FlowDefinition {
        FlowDefinition(
            title: title,
            pages: steps.map { step in
                FlowPage(
                    id: step.id,
                    title: step.title,
                    body: step.markdownBody.isEmpty ? step.subtitle : step.markdownBody,
                    style: step.isTerminalCompletion ? "completion" : "card",
                    actions: step.isTerminalCompletion ? ["Finish"] : ["Continue"]
                )
            }
        )
    }

    public static let enterpriseQualificationSample = ConditionalFlowSpec(
        id: "enterprise_onboarding_v3",
        title: "ChiefKit Cloud & Treasury Qualification",
        entryStepID: "profile_intake",
        steps: [
            FlowStepSpec(
                id: "profile_intake",
                title: "Tell us about your team",
                subtitle: "Role & technical readiness assessment",
                markdownBody: "We tailor SDK templates and compliance controls based on your role.",
                fields: [
                    FlowFieldSpec(id: "work_email", label: "Work Email", placeholder: "alex@company.com", kind: .email, validationRules: [.required, .email]),
                    FlowFieldSpec(id: "role", label: "Primary Role", kind: .singleChoice(["engineer", "designer", "finance", "pm"]), defaultValue: "engineer", validationRules: [.required]),
                    FlowFieldSpec(id: "score", label: "Readiness Score (0-100)", kind: .integer, defaultValue: "85", validationRules: [.required, .numericRange(min: 0, max: 100)])
                ],
                branches: [
                    FlowBranchRule(id: "br_eng_fasttrack", predicateExpression: "answers[\"role\"] == \"engineer\" && score >= 80", targetStepID: "sdk_fast_track", summary: "Senior engineer fast-track"),
                    FlowBranchRule(id: "br_treasury", predicateExpression: "answers[\"role\"] == \"finance\"", targetStepID: "payout_iban_step", summary: "Treasury IBAN setup")
                ],
                fallbackNextStepID: "guided_tour"
            ),
            FlowStepSpec(
                id: "sdk_fast_track",
                title: "Swift 6 SDK Fast-Track",
                subtitle: "Direct CLI & Package.swift setup",
                markdownBody: "Your readiness score unlocked instant Xcode workspace generation.",
                fallbackNextStepID: "complete_launch"
            ),
            FlowStepSpec(
                id: "payout_iban_step",
                title: "Settlement Bank Account",
                subtitle: "ISO 13616 IBAN & E.164 Security Alert Phone",
                markdownBody: "Configure verified treasury settlement details.",
                fields: [
                    FlowFieldSpec(id: "settlement_iban", label: "Corporate IBAN", placeholder: "DE89370400440532013000", kind: .iban, validationRules: [.required, .iban]),
                    FlowFieldSpec(id: "alert_phone", label: "Security SMS Phone", placeholder: "+14155552671", kind: .phoneE164, validationRules: [.required, .phoneE164])
                ],
                fallbackNextStepID: "complete_launch"
            ),
            FlowStepSpec(
                id: "guided_tour",
                title: "Interactive Visual Canvas Tour",
                subtitle: "Compose Liquid Glass screens without boilerplate",
                markdownBody: "Explore prebuilt blocks and live localization previews.",
                fallbackNextStepID: "complete_launch"
            ),
            FlowStepSpec(
                id: "complete_launch",
                title: "Workspace Provisioned",
                subtitle: "Ready to ship",
                markdownBody: "All checks passed. Export your native ChiefKit bundle anytime.",
                isTerminalCompletion: true
            )
        ],
        initialVariables: ["score": .number(85)]
    )
}

// MARK: - Boolean Predicate Expression Parser & Evaluator

public enum FlowPredicateExpressionError: Error, LocalizedError, Equatable, Sendable {
    case unexpectedCharacter(String)
    case unexpectedToken(String)
    case unterminatedStringLiteral

    public var errorDescription: String? {
        switch self {
        case .unexpectedCharacter(let c): "Unexpected character in predicate: '\(c)'"
        case .unexpectedToken(let t): "Unexpected token in predicate: '\(t)'"
        case .unterminatedStringLiteral: "Unterminated string literal in predicate."
        }
    }
}

public enum FlowExpressionEvaluator {
    private enum Token: Equatable {
        case identifier(String)
        case stringLiteral(String)
        case numberLiteral(Double)
        case boolLiteral(Bool)
        case lBracket
        case rBracket
        case lParen
        case rParen
        case andAnd
        case orOr
        case bang
        case eq
        case neq
        case gte
        case lte
        case gt
        case lt
        case containsOp
    }

    public static func evaluate(
        predicate: String,
        answers: [String: String],
        variables: [String: FlowRuntimeValue] = [:]
    ) throws -> Bool {
        let trimmed = predicate.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let tokens = try tokenize(trimmed)
        var parser = Parser(tokens: tokens, answers: answers, variables: variables)
        let outcome = try parser.parseOrExpression()
        if parser.hasRemaining {
            throw FlowPredicateExpressionError.unexpectedToken("\(parser.peekDescription)")
        }
        return outcome
    }

    private static func tokenize(_ source: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(source)
        var i = 0

        while i < chars.count {
            let ch = chars[i]
            if ch.isWhitespace {
                i += 1
                continue
            }
            if ch == "[" { tokens.append(.lBracket); i += 1; continue }
            if ch == "]" { tokens.append(.rBracket); i += 1; continue }
            if ch == "(" { tokens.append(.lParen); i += 1; continue }
            if ch == ")" { tokens.append(.rParen); i += 1; continue }

            if ch == "&" && i + 1 < chars.count && chars[i + 1] == "&" {
                tokens.append(.andAnd); i += 2; continue
            }
            if ch == "|" && i + 1 < chars.count && chars[i + 1] == "|" {
                tokens.append(.orOr); i += 2; continue
            }
            if ch == "=" && i + 1 < chars.count && chars[i + 1] == "=" {
                tokens.append(.eq); i += 2; continue
            }
            if ch == "!" && i + 1 < chars.count && chars[i + 1] == "=" {
                tokens.append(.neq); i += 2; continue
            }
            if ch == ">" && i + 1 < chars.count && chars[i + 1] == "=" {
                tokens.append(.gte); i += 2; continue
            }
            if ch == "<" && i + 1 < chars.count && chars[i + 1] == "=" {
                tokens.append(.lte); i += 2; continue
            }
            if ch == ">" { tokens.append(.gt); i += 1; continue }
            if ch == "<" { tokens.append(.lt); i += 1; continue }
            if ch == "!" { tokens.append(.bang); i += 1; continue }

            if ch == "\"" || ch == "'" {
                let quote = ch
                i += 1
                var buf: [Character] = []
                var closed = false
                while i < chars.count {
                    if chars[i] == "\\" && i + 1 < chars.count {
                        buf.append(chars[i + 1])
                        i += 2
                    } else if chars[i] == quote {
                        closed = true
                        i += 1
                        break
                    } else {
                        buf.append(chars[i])
                        i += 1
                    }
                }
                guard closed else { throw FlowPredicateExpressionError.unterminatedStringLiteral }
                tokens.append(.stringLiteral(String(buf)))
                continue
            }

            if ch.isNumber || (ch == "-" && i + 1 < chars.count && chars[i + 1].isNumber) {
                let start = i
                i += 1
                while i < chars.count && (chars[i].isNumber || chars[i] == ".") {
                    i += 1
                }
                let rawNum = String(chars[start..<i])
                guard let val = Double(rawNum) else {
                    throw FlowPredicateExpressionError.unexpectedToken(rawNum)
                }
                tokens.append(.numberLiteral(val))
                continue
            }

            if ch.isLetter || ch == "_" {
                let start = i
                while i < chars.count && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_") {
                    i += 1
                }
                let word = String(chars[start..<i])
                switch word {
                case "true": tokens.append(.boolLiteral(true))
                case "false": tokens.append(.boolLiteral(false))
                case "AND": tokens.append(.andAnd)
                case "OR": tokens.append(.orOr)
                case "contains": tokens.append(.containsOp)
                default: tokens.append(.identifier(word))
                }
                continue
            }

            throw FlowPredicateExpressionError.unexpectedCharacter(String(ch))
        }

        return tokens
    }

    private struct Parser {
        let tokens: [Token]
        let answers: [String: String]
        let variables: [String: FlowRuntimeValue]
        var index: Int = 0

        var hasRemaining: Bool { index < tokens.count }
        var peekDescription: String { index < tokens.count ? "\(tokens[index])" : "EOF" }

        mutating func parseOrExpression() throws -> Bool {
            var lhs = try parseAndExpression()
            while index < tokens.count && tokens[index] == .orOr {
                index += 1
                let rhs = try parseAndExpression()
                lhs = lhs || rhs
            }
            return lhs
        }

        mutating func parseAndExpression() throws -> Bool {
            var lhs = try parseUnaryExpression()
            while index < tokens.count && tokens[index] == .andAnd {
                index += 1
                let rhs = try parseUnaryExpression()
                lhs = lhs && rhs
            }
            return lhs
        }

        mutating func parseUnaryExpression() throws -> Bool {
            if index < tokens.count && tokens[index] == .bang {
                index += 1
                return !(try parseUnaryExpression())
            }
            if index < tokens.count && tokens[index] == .lParen {
                index += 1
                let inner = try parseOrExpression()
                guard index < tokens.count && tokens[index] == .rParen else {
                    throw FlowPredicateExpressionError.unexpectedToken(peekDescription)
                }
                index += 1
                return inner
            }
            return try parseComparison()
        }

        mutating func parseComparison() throws -> Bool {
            let lhs = try parseValueOperand()
            guard index < tokens.count else {
                return lhs.boolValue
            }
            let op = tokens[index]
            switch op {
            case .eq, .neq, .gte, .lte, .gt, .lt, .containsOp:
                index += 1
                let rhs = try parseValueOperand()
                return compare(lhs: lhs, op: op, rhs: rhs)
            default:
                return lhs.boolValue
            }
        }

        mutating func parseValueOperand() throws -> FlowRuntimeValue {
            guard index < tokens.count else {
                throw FlowPredicateExpressionError.unexpectedToken("EOF")
            }
            let tok = tokens[index]
            index += 1

            switch tok {
            case .stringLiteral(let s):
                return .string(s)
            case .numberLiteral(let n):
                return .number(n)
            case .boolLiteral(let b):
                return .bool(b)
            case .identifier(let ident):
                // Support `answers["role"]` or `vars["tier"]` subscript lookup
                if index < tokens.count && tokens[index] == .lBracket {
                    index += 1
                    guard index < tokens.count, case .stringLiteral(let subKey) = tokens[index] else {
                        throw FlowPredicateExpressionError.unexpectedToken(peekDescription)
                    }
                    index += 1
                    guard index < tokens.count && tokens[index] == .rBracket else {
                        throw FlowPredicateExpressionError.unexpectedToken(peekDescription)
                    }
                    index += 1
                    if ident == "answers" {
                        return answers[subKey].map(FlowRuntimeValue.infer) ?? .null
                    }
                    return variables[subKey] ?? answers[subKey].map(FlowRuntimeValue.infer) ?? .null
                }
                if let ans = answers[ident] {
                    return FlowRuntimeValue.infer(from: ans)
                }
                if let v = variables[ident] {
                    return v
                }
                return .null
            default:
                throw FlowPredicateExpressionError.unexpectedToken("\(tok)")
            }
        }

        private func compare(lhs: FlowRuntimeValue, op: Token, rhs: FlowRuntimeValue) -> Bool {
            switch op {
            case .eq:
                if let ln = lhs.numericValue, let rn = rhs.numericValue { return abs(ln - rn) < 1e-9 }
                return lhs.stringRepresentation == rhs.stringRepresentation
            case .neq:
                if let ln = lhs.numericValue, let rn = rhs.numericValue { return abs(ln - rn) >= 1e-9 }
                return lhs.stringRepresentation != rhs.stringRepresentation
            case .gte:
                guard let ln = lhs.numericValue, let rn = rhs.numericValue else {
                    return lhs.stringRepresentation >= rhs.stringRepresentation
                }
                return ln >= rn
            case .lte:
                guard let ln = lhs.numericValue, let rn = rhs.numericValue else {
                    return lhs.stringRepresentation <= rhs.stringRepresentation
                }
                return ln <= rn
            case .gt:
                guard let ln = lhs.numericValue, let rn = rhs.numericValue else {
                    return lhs.stringRepresentation > rhs.stringRepresentation
                }
                return ln > rn
            case .lt:
                guard let ln = lhs.numericValue, let rn = rhs.numericValue else {
                    return lhs.stringRepresentation < rhs.stringRepresentation
                }
                return ln < rn
            case .containsOp:
                return lhs.stringRepresentation.localizedCaseInsensitiveContains(rhs.stringRepresentation)
            default:
                return false
            }
        }
    }
}

// MARK: - Path Explorer, Step Evaluator & Jupyter .ipynb Exporter

public struct FlowStepEvaluationOutcome: Codable, Hashable, Sendable {
    public var stepID: String
    public var isValid: Bool
    public var fieldErrors: [String: String]
    public var matchedBranchID: String?
    public var resolvedNextStepID: String?
    public var reachedTerminalCompletion: Bool
}

public struct FlowExecutionPath: Identifiable, Codable, Hashable, Sendable {
    public var id: String { stepIDs.joined(separator: "->") }
    public var stepIDs: [String]
    public var predicatesTraversed: [String]
    public var terminatesCleanly: Bool
}

public struct FlowPathExplorationReport: Codable, Hashable, Sendable {
    public var reachablePaths: [FlowExecutionPath]
    public var unreachableStepIDs: [String]
    public var deadEndStepIDs: [String]
    public var cyclicStepPaths: [[String]]
    public var brokenTargetReferences: [String]
}

public enum NotebookFlowRuntimeEngine {

    public static func evaluateStep(
        in flow: ConditionalFlowSpec,
        stepID: String,
        answers: [String: String],
        variables: [String: FlowRuntimeValue] = [:]
    ) -> FlowStepEvaluationOutcome {
        guard let step = flow.step(withID: stepID) else {
            return FlowStepEvaluationOutcome(
                stepID: stepID,
                isValid: false,
                fieldErrors: ["_step": "Unknown step ID '\(stepID)'."],
                matchedBranchID: nil,
                resolvedNextStepID: nil,
                reachedTerminalCompletion: false
            )
        }

        var errors: [String: String] = [:]
        for field in step.fields {
            let input = answers[field.id] ?? field.defaultValue ?? ""
            for rule in field.validationRules {
                if let failure = rule.validate(input) {
                    errors[field.id] = failure
                    break
                }
            }
        }

        guard errors.isEmpty else {
            return FlowStepEvaluationOutcome(
                stepID: stepID,
                isValid: false,
                fieldErrors: errors,
                matchedBranchID: nil,
                resolvedNextStepID: nil,
                reachedTerminalCompletion: false
            )
        }

        if step.isTerminalCompletion {
            return FlowStepEvaluationOutcome(
                stepID: stepID,
                isValid: true,
                fieldErrors: [:],
                matchedBranchID: nil,
                resolvedNextStepID: nil,
                reachedTerminalCompletion: true
            )
        }

        var mergedVars = flow.initialVariables
        for (k, v) in variables { mergedVars[k] = v }

        for branch in step.branches {
            if (try? FlowExpressionEvaluator.evaluate(predicate: branch.predicateExpression, answers: answers, variables: mergedVars)) == true {
                return FlowStepEvaluationOutcome(
                    stepID: stepID,
                    isValid: true,
                    fieldErrors: [:],
                    matchedBranchID: branch.id,
                    resolvedNextStepID: branch.targetStepID,
                    reachedTerminalCompletion: false
                )
            }
        }

        return FlowStepEvaluationOutcome(
            stepID: stepID,
            isValid: true,
            fieldErrors: [:],
            matchedBranchID: nil,
            resolvedNextStepID: step.fallbackNextStepID,
            reachedTerminalCompletion: false
        )
    }

    /// Headless static + symbolic graph explorer finding all reachable paths, dead ends, cycles, and orphans.
    public static func exploreAllPaths(
        in flow: ConditionalFlowSpec,
        maxDepth: Int = 24
    ) -> FlowPathExplorationReport {
        let stepMap = Dictionary(uniqueKeysWithValues: flow.steps.map { ($0.id, $0) })
        var reachableSet = Set<String>()
        var deadEnds = Set<String>()
        var brokenTargets = Set<String>()
        var cycles: [[String]] = []
        var completedPaths: [FlowExecutionPath] = []

        func dfs(currentID: String, path: [String], predicates: [String]) {
            guard let step = stepMap[currentID] else {
                brokenTargets.insert(currentID)
                completedPaths.append(FlowExecutionPath(stepIDs: path, predicatesTraversed: predicates, terminatesCleanly: false))
                return
            }

            reachableSet.insert(currentID)

            if path.count > maxDepth {
                completedPaths.append(FlowExecutionPath(stepIDs: path, predicatesTraversed: predicates, terminatesCleanly: false))
                return
            }

            if step.isTerminalCompletion {
                completedPaths.append(FlowExecutionPath(stepIDs: path, predicatesTraversed: predicates, terminatesCleanly: true))
                return
            }

            var outgoing: [(target: String, label: String)] = step.branches.map {
                ($0.targetStepID, $0.predicateExpression)
            }
            if let fallback = step.fallbackNextStepID {
                outgoing.append((fallback, step.branches.isEmpty ? "unconditional" : "else_fallback"))
            }

            if outgoing.isEmpty {
                deadEnds.insert(currentID)
                completedPaths.append(FlowExecutionPath(stepIDs: path, predicatesTraversed: predicates, terminatesCleanly: false))
                return
            }

            for edge in outgoing {
                if let cycleStart = path.firstIndex(of: edge.target) {
                    let loopSlice = Array(path[cycleStart...]) + [edge.target]
                    cycles.append(loopSlice)
                } else {
                    dfs(
                        currentID: edge.target,
                        path: path + [edge.target],
                        predicates: predicates + [edge.label]
                    )
                }
            }
        }

        if !flow.entryStepID.isEmpty {
            dfs(currentID: flow.entryStepID, path: [flow.entryStepID], predicates: [])
        }

        let unreachable = flow.steps.map(\.id).filter { !reachableSet.contains($0) }
        return FlowPathExplorationReport(
            reachablePaths: completedPaths,
            unreachableStepIDs: unreachable,
            deadEndStepIDs: deadEnds.sorted(),
            cyclicStepPaths: cycles,
            brokenTargetReferences: brokenTargets.sorted()
        )
    }

    // MARK: - Jupyter .ipynb v4 JSON Notebook Exporter

    public static func exportJupyterNotebookJSON(_ flow: ConditionalFlowSpec) -> String {
        let report = exploreAllPaths(in: flow)
        var cells: [[String: Any]] = []

        // Cell 1: Header & Mermaid topology overview
        var mermaidLines = ["```mermaid", "flowchart TD"]
        for step in flow.steps {
            let shape = step.isTerminalCompletion ? "([\"\(step.title)\"])" : "[\"\(step.title)\"]"
            mermaidLines.append("    \(step.id)\(shape)")
            for br in step.branches {
                let sanitizedPred = br.predicateExpression.replacingOccurrences(of: "\"", with: "'")
                mermaidLines.append("    \(step.id) -->|\"\(sanitizedPred)\"| \(br.targetStepID)")
            }
            if let fb = step.fallbackNextStepID {
                let edgeLabel = step.branches.isEmpty ? "next" : "fallback"
                mermaidLines.append("    \(step.id) -->|\"\(edgeLabel)\"| \(fb)")
            }
        }
        mermaidLines.append("```")

        cells.append(markdownCell(lines: [
            "# \(flow.title) (`\(flow.id)` · v\(flow.version))\n",
            "Exported by **ChiefKit Studio 3.0 — NotebookFlowKit Runtime**.\n",
            "- **Entry Step:** `\(flow.entryStepID)`\n",
            "- **Total Screens:** \(flow.steps.count)\n",
            "- **Reachable Execution Paths:** \(report.reachablePaths.count)\n",
            "\n",
            mermaidLines.joined(separator: "\n")
        ]))

        // Cell 2: Python simulation harness cell
        cells.append(codeCell(lines: [
            "# Interactive NotebookFlowKit Simulation Context\n",
            "answers = {}\n",
            "flow_metadata = {\n",
            "    'id': '\(flow.id)',\n",
            "    'entry_step_id': '\(flow.entryStepID)',\n",
            "    'step_count': \(flow.steps.count)\n",
            "}\n",
            "print(f\"Loaded ChiefKit Flow: {flow_metadata['id']} ({flow_metadata['step_count']} steps)\")"
        ]))

        // Per-step Markdown + Executable Specification Cell pairs
        for (idx, step) in flow.steps.enumerated() {
            var md: [String] = [
                "## Step \(idx + 1): \(step.title) (`\(step.id)`)\n",
                step.subtitle.isEmpty ? "" : "*\(step.subtitle)*\n\n",
                step.markdownBody.isEmpty ? "" : "\(step.markdownBody)\n"
            ].filter { !$0.isEmpty }

            if !step.fields.isEmpty {
                md.append("\n### Input Fields\n")
                for f in step.fields {
                    md.append("- **`\(f.id)`** (\(f.label)) — \(f.validationRules.count) validation rule(s)\n")
                }
            }
            cells.append(markdownCell(lines: md))

            var pyLines: [String] = [
                "step_\(SchemaNamingHelpers.snakeCase(step.id)) = {\n",
                "    'id': '\(step.id)',\n",
                "    'terminal': \(step.isTerminalCompletion ? "True" : "False"),\n",
                "    'fields': [\(step.fields.map { "'\($0.id)'" }.joined(separator: ", "))],\n",
                "    'branches': [\n"
            ]
            for br in step.branches {
                let esc = br.predicateExpression.replacingOccurrences(of: "'", with: "\\'")
                pyLines.append("        {'predicate': '\(esc)', 'target': '\(br.targetStepID)'},\n")
            }
            pyLines.append("    ],\n")
            pyLines.append("    'fallback_next': \(step.fallbackNextStepID.map { "'\($0)'" } ?? "None")\n")
            pyLines.append("}")
            cells.append(codeCell(lines: pyLines))
        }

        let notebookRoot: [String: Any] = [
            "cells": cells,
            "metadata": [
                "chiefkit_flow_id": flow.id,
                "kernelspec": [
                    "display_name": "Python 3 (ChiefKit NotebookFlow)",
                    "language": "python",
                    "name": "python3"
                ],
                "language_info": [
                    "name": "python",
                    "version": "3.12"
                ]
            ],
            "nbformat": 4,
            "nbformat_minor": 5
        ]

        guard JSONSerialization.isValidJSONObject(notebookRoot),
              let data = try? JSONSerialization.data(withJSONObject: notebookRoot, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func markdownCell(lines: [String]) -> [String: Any] {
        [
            "cell_type": "markdown",
            "metadata": [String: Any](),
            "source": lines
        ]
    }

    private static func codeCell(lines: [String]) -> [String: Any] {
        [
            "cell_type": "code",
            "execution_count": NSNull(),
            "metadata": [String: Any](),
            "outputs": [[String: Any]](),
            "source": lines
        ]
    }
}
