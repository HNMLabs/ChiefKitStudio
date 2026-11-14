import ChiefKitStudioCore
import Foundation

// MARK: - Source Positions & Spans

/// Represents a 1-indexed line/column coordinate and 0-indexed UTF-8 byte offset in Swift source text.
public struct SourcePosition: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let line: Int
    public let column: Int
    public let utf8Offset: Int

    public init(line: Int, column: Int, utf8Offset: Int) {
        self.line = max(1, line)
        self.column = max(1, column)
        self.utf8Offset = max(0, utf8Offset)
    }

    public static let start = SourcePosition(line: 1, column: 1, utf8Offset: 0)
    public static let zero = SourcePosition(line: 1, column: 1, utf8Offset: 0)

    public var description: String {
        "\(line):\(column)"
    }

    public static func < (lhs: SourcePosition, rhs: SourcePosition) -> Bool {
        if lhs.utf8Offset != rhs.utf8Offset { return lhs.utf8Offset < rhs.utf8Offset }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        return lhs.column < rhs.column
    }

    /// Returns a new position after advancing across a single Swift `Character`.
    public func advanced(by character: Character) -> SourcePosition {
        let byteLen = character.utf8.count
        if character == "\n" || character == "\r\n" {
            return SourcePosition(line: line + 1, column: 1, utf8Offset: utf8Offset + byteLen)
        }
        return SourcePosition(line: line, column: column + 1, utf8Offset: utf8Offset + byteLen)
    }

    /// Returns a new position after advancing across an arbitrary string slice.
    public func advanced(across text: Substring) -> SourcePosition {
        var pos = self
        for ch in text {
            pos = pos.advanced(by: ch)
        }
        return pos
    }

    /// Returns a new position on the same line shifted horizontally by `columns` and `utf8Bytes`.
    public func advancedColumns(_ columns: Int, utf8Bytes: Int) -> SourcePosition {
        SourcePosition(line: line, column: column + max(0, columns), utf8Offset: utf8Offset + max(0, utf8Bytes))
    }
}

/// Half-open `[start, end)` span locating a lexical token, trivia run, or AST construct in source code.
public struct SourceSpan: Codable, Hashable, Sendable, CustomStringConvertible {
    public let start: SourcePosition
    public let end: SourcePosition

    public init(start: SourcePosition, end: SourcePosition) {
        if end < start {
            self.start = start
            self.end = start
        } else {
            self.start = start
            self.end = end
        }
    }

    public static let zero = SourceSpan(start: .zero, end: .zero)

    public var description: String {
        if start.line == end.line { return "\(start.line):\(start.column)-\(end.column)" }
        return "\(start.description)-\(end.description)"
    }

    public var lineCount: Int {
        max(1, end.line - start.line + 1)
    }

    public var byteLength: Int {
        max(0, end.utf8Offset - start.utf8Offset)
    }

    public var isEmpty: Bool {
        start.utf8Offset == end.utf8Offset
    }

    public func contains(_ position: SourcePosition) -> Bool {
        position >= start && position <= end
    }

    public func overlaps(_ other: SourceSpan) -> Bool {
        start <= other.end && other.start <= end
    }

    public func merged(with other: SourceSpan) -> SourceSpan {
        SourceSpan(start: min(start, other.start), end: max(end, other.end))
    }

    /// Safely slices the substring covered by this UTF-8 span from the original source string.
    public func extractSubstring(from source: String) -> String {
        let utf8View = source.utf8
        guard start.utf8Offset >= 0,
              end.utf8Offset <= utf8View.count,
              start.utf8Offset <= end.utf8Offset else { return "" }
        let startIdx = utf8View.index(utf8View.startIndex, offsetBy: start.utf8Offset)
        let endIdx = utf8View.index(utf8View.startIndex, offsetBy: end.utf8Offset)
        return String(decoding: utf8View[startIdx..<endIdx], as: UTF8.self)
    }
}

// MARK: - Lexical Trivia

/// Categorizes whitespace, line breaks, and structured comments attached to Swift tokens.
public enum TriviaKind: String, Codable, Hashable, CaseIterable, Sendable {
    case spaces
    case tabs
    case newlines
    case carriageReturnNewlines
    case lineComment
    case docLineComment
    case blockComment
    case docBlockComment
    case shebang
    case unexpectedText
}

/// A single contiguous run of trivia preserved before or after a `SwiftToken`.
public struct TriviaPiece: Codable, Hashable, Sendable {
    public let kind: TriviaKind
    public let text: String
    public let span: SourceSpan

    public init(kind: TriviaKind, text: String, span: SourceSpan = .zero) {
        self.kind = kind
        self.text = text
        self.span = span
    }

    public var isWhitespace: Bool {
        switch kind {
        case .spaces, .tabs, .newlines, .carriageReturnNewlines:
            return true
        default:
            return false
        }
    }

    public var isNewline: Bool {
        kind == .newlines || kind == .carriageReturnNewlines
    }

    public var isComment: Bool {
        switch kind {
        case .lineComment, .docLineComment, .blockComment, .docBlockComment:
            return true
        default:
            return false
        }
    }

    public var isDocComment: Bool {
        kind == .docLineComment || kind == .docBlockComment
    }

    public var newlineCount: Int {
        switch kind {
        case .newlines:
            return text.count
        case .carriageReturnNewlines:
            return text.filter { $0 == "\n" }.count
        case .blockComment, .docBlockComment, .unexpectedText:
            return text.filter { $0 == "\n" }.count
        default:
            return 0
        }
    }

    /// Strips comment delimiters (`//`, `///`, `/* ... */`, `/** ... */`) and returns trimmed prose.
    public var commentBody: String? {
        switch kind {
        case .docLineComment:
            let stripped = text.hasPrefix("///") ? String(text.dropFirst(3)) : text
            return stripped.trimmingCharacters(in: .whitespaces)
        case .lineComment:
            let stripped = text.hasPrefix("//") ? String(text.dropFirst(2)) : text
            return stripped.trimmingCharacters(in: .whitespaces)
        case .docBlockComment:
            var body = text
            if body.hasPrefix("/**") { body = String(body.dropFirst(3)) }
            if body.hasSuffix("*/") { body = String(body.dropLast(2)) }
            return body.trimmingCharacters(in: .whitespacesAndNewlines)
        case .blockComment:
            var body = text
            if body.hasPrefix("/*") { body = String(body.dropFirst(2)) }
            if body.hasSuffix("*/") { body = String(body.dropLast(2)) }
            return body.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return nil
        }
    }
}

// MARK: - Swift 6 Keywords

/// Complete set of Swift 6 declaration, statement, expression, and concurrency keywords.
public enum SwiftKeyword: String, Codable, Hashable, CaseIterable, Sendable {
    // Declarations
    case `import`
    case `struct`
    case `class`
    case actor
    case `enum`
    case `protocol`
    case `extension`
    case `func`
    case initializer = "init"
    case `deinit`
    case `subscript`
    case `typealias`
    case `associatedtype`
    case `var`
    case `let`
    case `case`
    case indirect
    case macro
    case `operator`
    case precedenceGroup = "precedencegroup"

    // Access Control & Modifiers
    case `public`
    case `private`
    case `fileprivate`
    case `internal`
    case package
    case open
    case `static`
    case final
    case override
    case mutating
    case nonmutating
    case nonisolated
    case isolated
    case sending
    case consuming
    case borrowing
    case `inout`
    case lazy
    case weak
    case unowned
    case convenience
    case required
    case optional

    // Effects & Concurrency
    case async
    case `throws`
    case `rethrows`
    case await
    case `try`

    // Control Flow
    case `if`
    case `else`
    case `guard`
    case `switch`
    case `default`
    case `for`
    case `in`
    case `while`
    case `repeat`
    case `do`
    case `catch`
    case `break`
    case `continue`
    case `fallthrough`
    case `return`
    case `throw`
    case `defer`
    case `where`

    // Expressions & Existentials / Generics
    case `self`
    case `Self`
    case `super`
    case `nil`
    case `true`
    case `false`
    case `as`
    case `is`
    case some
    case any
    case each

    // Accessors
    case get
    case set
    case willSet
    case didSet

    public var isTypeDeclarationIntroducer: Bool {
        switch self {
        case .struct, .class, .actor, .enum, .protocol, .extension:
            return true
        default:
            return false
        }
    }

    public var isDeclarationIntroducer: Bool {
        if isTypeDeclarationIntroducer { return true }
        switch self {
        case .import, .func, .initializer, .deinit, .subscript, .typealias, .associatedtype, .var, .let, .case, .macro:
            return true
        default:
            return false
        }
    }

    public var isAccessControl: Bool {
        switch self {
        case .open, .public, .package, .internal, .fileprivate, .private:
            return true
        default:
            return false
        }
    }

    public var isDeclarationModifier: Bool {
        if isAccessControl { return true }
        switch self {
        case .static, .final, .override, .mutating, .nonmutating, .nonisolated, .isolated,
             .lazy, .weak, .unowned, .convenience, .required, .optional, .indirect,
             .sending, .consuming, .borrowing:
            return true
        default:
            return false
        }
    }

    public var isControlFlow: Bool {
        switch self {
        case .if, .else, .guard, .switch, .default, .for, .in, .while, .repeat,
             .do, .catch, .break, .continue, .fallthrough, .return, .throw, .defer:
            return true
        default:
            return false
        }
    }

    public var isEffectSpecifier: Bool {
        switch self {
        case .async, .throws, .rethrows, .await, .try:
            return true
        default:
            return false
        }
    }

    /// Contextual keywords that may also legitimately appear as member or parameter names in SwiftUI.
    public var canBeUsedAsContextualIdentifier: Bool {
        switch self {
        case .actor, .package, .open, .final, .override, .mutating, .nonmutating,
             .nonisolated, .isolated, .sending, .consuming, .borrowing, .lazy, .weak,
             .unowned, .convenience, .required, .optional, .indirect, .macro,
             .precedenceGroup, .async, .await, .some, .any, .each, .get, .set,
             .willSet, .didSet:
            return true
        default:
            return false
        }
    }
}

// MARK: - Attributes & Directives

/// Models Swift 6 attributes, SwiftUI property wrappers, Observation macros, and Swift Testing annotations.
public enum SwiftAttributeKind: Codable, Hashable, Sendable {
    // SwiftUI Property Wrappers
    case state
    case binding
    case stateObject
    case observedObject
    case environmentObject
    case environment
    case focusState
    case namespace
    case scaledMetric
    case appStorage
    case sceneStorage

    // Observation & Combine
    case observable
    case bindable
    case observationTracked
    case observationIgnored
    case published

    // Swift 6 Concurrency & Builders
    case mainActor
    case globalActor(String)
    case sendable
    case preconcurrency
    case unchecked
    case viewBuilder
    case resultBuilder
    case escaping
    case autoclosure
    case discardableResult
    case available
    case objc

    // Swift 6 Testing Framework
    case test
    case suite
    case tag

    // User-defined or module-specific attribute
    case custom(String)

    public init(name: String) {
        let trimmed = name.hasPrefix("@") ? String(name.dropFirst()) : name
        switch trimmed {
        case "State": self = .state
        case "Binding": self = .binding
        case "StateObject": self = .stateObject
        case "ObservedObject": self = .observedObject
        case "EnvironmentObject": self = .environmentObject
        case "Environment": self = .environment
        case "FocusState": self = .focusState
        case "Namespace": self = .namespace
        case "ScaledMetric": self = .scaledMetric
        case "AppStorage": self = .appStorage
        case "SceneStorage": self = .sceneStorage
        case "Observable": self = .observable
        case "Bindable": self = .bindable
        case "ObservationTracked": self = .observationTracked
        case "ObservationIgnored": self = .observationIgnored
        case "Published": self = .published
        case "MainActor": self = .mainActor
        case "Sendable": self = .sendable
        case "preconcurrency": self = .preconcurrency
        case "unchecked": self = .unchecked
        case "ViewBuilder": self = .viewBuilder
        case "resultBuilder": self = .resultBuilder
        case "escaping": self = .escaping
        case "autoclosure": self = .autoclosure
        case "discardableResult": self = .discardableResult
        case "available": self = .available
        case "objc": self = .objc
        case "Test": self = .test
        case "Suite": self = .suite
        case "Tag": self = .tag
        default:
            if trimmed.hasSuffix("Actor") && trimmed != "MainActor" {
                self = .globalActor(trimmed)
            } else {
                self = .custom(trimmed)
            }
        }
    }

    public var canonicalName: String {
        switch self {
        case .state: return "State"
        case .binding: return "Binding"
        case .stateObject: return "StateObject"
        case .observedObject: return "ObservedObject"
        case .environmentObject: return "EnvironmentObject"
        case .environment: return "Environment"
        case .focusState: return "FocusState"
        case .namespace: return "Namespace"
        case .scaledMetric: return "ScaledMetric"
        case .appStorage: return "AppStorage"
        case .sceneStorage: return "SceneStorage"
        case .observable: return "Observable"
        case .bindable: return "Bindable"
        case .observationTracked: return "ObservationTracked"
        case .observationIgnored: return "ObservationIgnored"
        case .published: return "Published"
        case .mainActor: return "MainActor"
        case .globalActor(let actorName): return actorName
        case .sendable: return "Sendable"
        case .preconcurrency: return "preconcurrency"
        case .unchecked: return "unchecked"
        case .viewBuilder: return "ViewBuilder"
        case .resultBuilder: return "resultBuilder"
        case .escaping: return "escaping"
        case .autoclosure: return "autoclosure"
        case .discardableResult: return "discardableResult"
        case .available: return "available"
        case .objc: return "objc"
        case .test: return "Test"
        case .suite: return "Suite"
        case .tag: return "Tag"
        case .custom(let raw): return raw
        }
    }

    public var formattedAttribute: String {
        "@\(canonicalName)"
    }

    public var isSwiftUIPropertyWrapper: Bool {
        switch self {
        case .state, .binding, .stateObject, .observedObject, .environmentObject,
             .environment, .focusState, .namespace, .scaledMetric, .appStorage,
             .sceneStorage, .bindable, .published:
            return true
        default:
            return false
        }
    }

    public var isLegacyCombineWrapper: Bool {
        switch self {
        case .stateObject, .observedObject, .environmentObject, .published:
            return true
        default:
            return false
        }
    }

    public var isConcurrencyAttribute: Bool {
        switch self {
        case .mainActor, .globalActor, .sendable, .preconcurrency, .unchecked:
            return true
        default:
            return false
        }
    }

    public var isTestingAttribute: Bool {
        switch self {
        case .test, .suite, .tag:
            return true
        default:
            return false
        }
    }
}

/// Models Swift compiler directives and freestanding pound macros (`#if`, `#Preview`, `#expect`, etc.).
public enum SwiftDirectiveKind: String, Codable, Hashable, CaseIterable, Sendable {
    case poundIf = "#if"
    case poundElseif = "#elseif"
    case poundElse = "#else"
    case poundEndif = "#endif"
    case preview = "#Preview"
    case expect = "#expect"
    case require = "#require"
    case available = "#available"
    case unavailable = "#unavailable"
    case warning = "#warning"
    case error = "#error"
    case sourceLocation = "#sourceLocation"
    case file = "#file"
    case fileID = "#fileID"
    case filePath = "#filePath"
    case line = "#line"
    case column = "#column"
    case function = "#function"
    case selector = "#selector"
    case keyPath = "#keyPath"
    case colorLiteral = "#colorLiteral"
    case externalMacro = "#externalMacro"
    case unknown = "#unknown"

    public init(directiveName: String) {
        let normalized = directiveName.hasPrefix("#") ? directiveName : "#\(directiveName)"
        if let exact = SwiftDirectiveKind(rawValue: normalized) {
            self = exact
        } else {
            self = .unknown
        }
    }

    public var isConditionalCompilation: Bool {
        switch self {
        case .poundIf, .poundElseif, .poundElse, .poundEndif:
            return true
        default:
            return false
        }
    }

    public var isTestingMacro: Bool {
        self == .expect || self == .require
    }

    public var isPreviewMacro: Bool {
        self == .preview
    }
}

// MARK: - Literals, Operators & Punctuation

/// Radix base of a Swift integer or floating-point literal.
public enum NumericRadix: String, Codable, Hashable, CaseIterable, Sendable {
    case decimal
    case binary
    case octal
    case hexadecimal

    public var base: Int {
        switch self {
        case .decimal: return 10
        case .binary: return 2
        case .octal: return 8
        case .hexadecimal: return 16
        }
    }

    public var literalPrefix: String {
        switch self {
        case .decimal: return ""
        case .binary: return "0b"
        case .octal: return "0o"
        case .hexadecimal: return "0x"
        }
    }
}

/// Whitespace-determined fixity of a Swift operator token.
public enum SwiftOperatorFixity: String, Codable, Hashable, CaseIterable, Sendable {
    case infix
    case prefix
    case postfix
}

/// Structural punctuation delimiters and separators in Swift grammar.
public enum SwiftPunctuation: String, Codable, Hashable, CaseIterable, Sendable {
    case leftParen = "("
    case rightParen = ")"
    case leftBrace = "{"
    case rightBrace = "}"
    case leftBracket = "["
    case rightBracket = "]"
    case comma = ","
    case colon = ":"
    case semicolon = ";"
    case period = "."
    case ellipsis = "..."
    case halfOpenRange = "..<"
    case atSign = "@"
    case pound = "#"
    case questionMark = "?"
    case exclamationMark = "!"
    case arrow = "->"
    case equal = "="
    case backslash = "\\"
    case ampersand = "&"
    case backtick = "`"
}

// MARK: - Token Kind & Token

/// Discriminated union representing every lexical token produced by `SwiftLexer`.
public enum SwiftTokenKind: Codable, Hashable, Sendable {
    case keyword(SwiftKeyword)
    case identifier(String, isBackticked: Bool)
    case dollarIdentifier(String)
    case integerLiteral(raw: String, value: Int64?, radix: NumericRadix)
    case floatingLiteral(raw: String, value: Double?, radix: NumericRadix)
    case stringLiteral(raw: String, value: String, isMultiline: Bool, rawDelimiterCount: Int)
    case interpolatedStringSegment(raw: String, expressions: [String], isMultiline: Bool, rawDelimiterCount: Int)
    case booleanLiteral(Bool)
    case nilLiteral
    case attribute(SwiftAttributeKind)
    case directive(SwiftDirectiveKind)
    case operatorSymbol(String, fixity: SwiftOperatorFixity)
    case punctuation(SwiftPunctuation)
    case eof
    case unknown(String)

    public var categoryLabel: String {
        switch self {
        case .keyword: return "keyword"
        case .identifier: return "identifier"
        case .dollarIdentifier: return "dollarIdentifier"
        case .integerLiteral: return "integerLiteral"
        case .floatingLiteral: return "floatingLiteral"
        case .stringLiteral: return "stringLiteral"
        case .interpolatedStringSegment: return "interpolatedString"
        case .booleanLiteral: return "booleanLiteral"
        case .nilLiteral: return "nilLiteral"
        case .attribute: return "attribute"
        case .directive: return "directive"
        case .operatorSymbol: return "operator"
        case .punctuation: return "punctuation"
        case .eof: return "eof"
        case .unknown: return "unknown"
        }
    }

    public var isLiteral: Bool {
        switch self {
        case .integerLiteral, .floatingLiteral, .stringLiteral, .interpolatedStringSegment, .booleanLiteral, .nilLiteral:
            return true
        default:
            return false
        }
    }
}

/// Immutable, trivia-carrying Swift 6 lexical token with exact UTF-8 source coordinates.
public struct SwiftToken: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let kind: SwiftTokenKind
    public let text: String
    public let span: SourceSpan
    public let leadingTrivia: [TriviaPiece]
    public let trailingTrivia: [TriviaPiece]

    public init(
        id: Int,
        kind: SwiftTokenKind,
        text: String,
        span: SourceSpan,
        leadingTrivia: [TriviaPiece] = [],
        trailingTrivia: [TriviaPiece] = []
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.span = span
        self.leadingTrivia = leadingTrivia
        self.trailingTrivia = trailingTrivia
    }

    public var isEOF: Bool {
        if case .eof = kind { return true }
        return false
    }

    public var hasLeadingNewline: Bool {
        leadingTrivia.contains { $0.isNewline || $0.newlineCount > 0 }
    }

    public var leadingBlankLineCount: Int {
        let totalNewlines = leadingTrivia.reduce(0) { $0 + $1.newlineCount }
        return max(0, totalNewlines - 1)
    }

    /// Concatenated documentation prose (`///` or `/** ... */`) immediately preceding this token.
    public var leadingDocComment: String? {
        let docs = leadingTrivia.compactMap { piece -> String? in
            guard piece.isDocComment else { return nil }
            return piece.commentBody
        }
        guard !docs.isEmpty else { return nil }
        return docs.joined(separator: "\n")
    }

    /// All comment texts (both standard and doc) attached as leading trivia.
    public var leadingComments: [String] {
        leadingTrivia.compactMap { $0.commentBody }
    }

    /// Extracts an identifier name if this token is an identifier or a contextual keyword.
    public var identifierOrContextualName: String? {
        switch kind {
        case .identifier(let name, _):
            return name
        case .keyword(let kw) where kw.canBeUsedAsContextualIdentifier:
            return kw.rawValue
        default:
            return nil
        }
    }

    /// Extracts an identifier or ANY keyword raw name (useful after `.` member access such as `.default` or `.init`).
    public var memberIdentifierName: String? {
        switch kind {
        case .identifier(let name, _):
            return name
        case .keyword(let kw):
            return kw.rawValue
        default:
            return nil
        }
    }

    public func isKeyword(_ expected: SwiftKeyword) -> Bool {
        if case .keyword(let actual) = kind { return actual == expected }
        return false
    }

    public func isPunctuation(_ expected: SwiftPunctuation) -> Bool {
        if case .punctuation(let actual) = kind { return actual == expected }
        return false
    }

    public func isOperator(_ expected: String) -> Bool {
        if case .operatorSymbol(let actual, _) = kind { return actual == expected }
        if expected == "=" && isPunctuation(.equal) {
            return true
        }
        if expected == "!" && isPunctuation(.exclamationMark) {
            return true
        }
        if expected == "?" && isPunctuation(.questionMark) {
            return true
        }
        if expected == "..." && isPunctuation(.ellipsis) {
            return true
        }
        if expected == "..<" && isPunctuation(.halfOpenRange) {
            return true
        }
        return false
    }
}

// MARK: - Lexical Diagnostics & Token Stream Statistics

/// Severity level of an issue encountered during lexical scanning.
public enum LexicalDiagnosticSeverity: String, Codable, Hashable, CaseIterable, Sendable {
    case warning
    case error
}

/// Diagnostic emitted by `SwiftLexer` when recovering from malformed literals, comments, or characters.
public struct LexicalDiagnostic: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let severity: LexicalDiagnosticSeverity
    public let message: String
    public let span: SourceSpan
    public let recoveryHint: String?

    public init(
        id: UUID = UUID(),
        severity: LexicalDiagnosticSeverity,
        message: String,
        span: SourceSpan,
        recoveryHint: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.span = span
        self.recoveryHint = recoveryHint
    }
}

/// Aggregated lexical statistics and histograms over a tokenized Swift source file.
public struct TokenStreamSummary: Codable, Equatable, Sendable {
    public let totalTokens: Int
    public let keywordCount: Int
    public let identifierCount: Int
    public let literalCount: Int
    public let attributeCount: Int
    public let directiveCount: Int
    public let operatorCount: Int
    public let punctuationCount: Int
    public let commentCount: Int
    public let docCommentCount: Int
    public let diagnosticCount: Int
    public let totalLines: Int
    public let uniqueIdentifiers: [String]
    public let distinctAttributes: [String]
    public let keywordHistogram: [String: Int]
    public let operatorHistogram: [String: Int]

    public init(tokens: [SwiftToken], diagnostics: [LexicalDiagnostic] = []) {
        var keywords = 0
        var identifiers = 0
        var literals = 0
        var attributes = 0
        var directives = 0
        var operators = 0
        var punctuations = 0
        var comments = 0
        var docComments = 0
        var maxLine = 1

        var idSet = Set<String>()
        var attrSet = Set<String>()
        var kwHist: [String: Int] = [:]
        var opHist: [String: Int] = [:]

        for token in tokens {
            maxLine = max(maxLine, token.span.end.line)

            for piece in token.leadingTrivia {
                if piece.isComment { comments += 1 }
                if piece.isDocComment { docComments += 1 }
            }
            for piece in token.trailingTrivia {
                if piece.isComment { comments += 1 }
                if piece.isDocComment { docComments += 1 }
            }

            switch token.kind {
            case .keyword(let kw):
                keywords += 1
                kwHist[kw.rawValue, default: 0] += 1
            case .identifier(let name, _):
                identifiers += 1
                idSet.insert(name)
            case .dollarIdentifier(let name):
                identifiers += 1
                idSet.insert(name)
            case .integerLiteral, .floatingLiteral, .stringLiteral, .interpolatedStringSegment, .booleanLiteral, .nilLiteral:
                literals += 1
            case .attribute(let attr):
                attributes += 1
                attrSet.insert(attr.formattedAttribute)
            case .directive:
                directives += 1
            case .operatorSymbol(let sym, _):
                operators += 1
                opHist[sym, default: 0] += 1
            case .punctuation:
                punctuations += 1
            case .eof, .unknown:
                break
            }
        }

        // Exclude trailing synthetic EOF token from substantive count
        let nonEOFCount = tokens.filter { !$0.isEOF }.count

        self.totalTokens = nonEOFCount
        self.keywordCount = keywords
        self.identifierCount = identifiers
        self.literalCount = literals
        self.attributeCount = attributes
        self.directiveCount = directives
        self.operatorCount = operators
        self.punctuationCount = punctuations
        self.commentCount = comments
        self.docCommentCount = docComments
        self.diagnosticCount = diagnostics.count
        self.totalLines = maxLine
        self.uniqueIdentifiers = idSet.sorted()
        self.distinctAttributes = attrSet.sorted()
        self.keywordHistogram = kwHist
        self.operatorHistogram = opHist
    }
}
