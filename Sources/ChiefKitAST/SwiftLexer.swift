import ChiefKitStudioCore
import Foundation

// MARK: - Lexer Configuration & Result

/// Configuration options controlling `SwiftLexer` scanning and recovery behavior.
public struct SwiftLexerOptions: Codable, Hashable, Sendable {
    public var preserveTrivia: Bool
    public var decodeEscapeSequences: Bool
    public var recoverFromUnterminatedLiterals: Bool
    public var maxTokenLimit: Int

    public init(
        preserveTrivia: Bool = true,
        decodeEscapeSequences: Bool = true,
        recoverFromUnterminatedLiterals: Bool = true,
        maxTokenLimit: Int = 250_000
    ) {
        self.preserveTrivia = preserveTrivia
        self.decodeEscapeSequences = decodeEscapeSequences
        self.recoverFromUnterminatedLiterals = recoverFromUnterminatedLiterals
        self.maxTokenLimit = max(128, maxTokenLimit)
    }

    public static let standard = SwiftLexerOptions()
}

/// Complete output of `SwiftLexer.tokenize(_:options:)`, pairing the token stream with diagnostics and statistics.
public struct SwiftLexResult: Codable, Equatable, Sendable {
    public let tokens: [SwiftToken]
    public let diagnostics: [LexicalDiagnostic]
    public let summary: TokenStreamSummary
    public let sourceLengthUTF8: Int

    public init(
        tokens: [SwiftToken],
        diagnostics: [LexicalDiagnostic],
        summary: TokenStreamSummary,
        sourceLengthUTF8: Int
    ) {
        self.tokens = tokens
        self.diagnostics = diagnostics
        self.summary = summary
        self.sourceLengthUTF8 = sourceLengthUTF8
    }
}

// MARK: - Swift 6 Lexical Scanner

/// Pure, `Sendable` character-scanner lexer for Swift 6 and SwiftUI source files.
public enum SwiftLexer: Sendable {
    /// Tokenizes a Swift source string into a complete `SwiftLexResult` ending with an explicit `.eof` token.
    public static func tokenize(
        _ source: String,
        options: SwiftLexerOptions = .standard
    ) -> SwiftLexResult {
        var scanner = ScannerState(source: source, options: options)
        return scanner.scanAll()
    }

    /// Convenience helper returning `[SwiftToken]` directly.
    public static func tokens(
        from source: String,
        options: SwiftLexerOptions = .standard
    ) -> [SwiftToken] {
        tokenize(source, options: options).tokens
    }
}

// MARK: - Internal Character Scanner State Machine

private struct ScannerState {
    let characters: [Character]
    let sourceUTF8Length: Int
    let options: SwiftLexerOptions

    var index: Int = 0
    var position: SourcePosition = .start
    var diagnostics: [LexicalDiagnostic] = []
    var nextTokenID: Int = 0

    init(source: String, options: SwiftLexerOptions) {
        self.characters = Array(source)
        self.sourceUTF8Length = source.utf8.count
        self.options = options
    }

    var isAtEnd: Bool {
        index >= characters.count
    }

    func peek(offset: Int = 0) -> Character? {
        let target = index + offset
        guard target >= 0 && target < characters.count else { return nil }
        return characters[target]
    }

    func peekPrevious() -> Character? {
        guard index > 0 && (index - 1) < characters.count else { return nil }
        return characters[index - 1]
    }

    @discardableResult
    mutating func advance() -> Character? {
        guard index < characters.count else { return nil }
        let ch = characters[index]
        index += 1
        position = position.advanced(by: ch)
        return ch
    }

    mutating func advance(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            if advance() == nil { break }
        }
    }

    func sliceText(from startIndex: Int, to endIndex: Int) -> String {
        guard startIndex >= 0, endIndex <= characters.count, startIndex <= endIndex else { return "" }
        return String(characters[startIndex..<endIndex])
    }

    // MARK: Main Loop

    mutating func scanAll() -> SwiftLexResult {
        var tokens: [SwiftToken] = []
        tokens.reserveCapacity(min(options.maxTokenLimit, max(16, characters.count / 5)))

        while !isAtEnd && tokens.count < options.maxTokenLimit {
            let leading = scanTrivia(stopAtNewline: false)
            if isAtEnd {
                let eofSpan = SourceSpan(start: position, end: position)
                let eofToken = SwiftToken(
                    id: nextTokenID,
                    kind: .eof,
                    text: "",
                    span: eofSpan,
                    leadingTrivia: options.preserveTrivia ? leading : [],
                    trailingTrivia: []
                )
                tokens.append(eofToken)
                nextTokenID += 1
                break
            }

            let tokenStartPos = position
            let tokenStartIdx = index
            let kind = scanNextTokenKind()
            let tokenEndPos = position
            let rawText = sliceText(from: tokenStartIdx, to: index)
            let trailing = scanTrivia(stopAtNewline: true)

            let token = SwiftToken(
                id: nextTokenID,
                kind: kind,
                text: rawText,
                span: SourceSpan(start: tokenStartPos, end: tokenEndPos),
                leadingTrivia: options.preserveTrivia ? leading : [],
                trailingTrivia: options.preserveTrivia ? trailing : []
            )
            tokens.append(token)
            nextTokenID += 1
        }

        if tokens.last?.isEOF != true {
            let eofSpan = SourceSpan(start: position, end: position)
            tokens.append(SwiftToken(id: nextTokenID, kind: .eof, text: "", span: eofSpan))
        }

        let summary = TokenStreamSummary(tokens: tokens, diagnostics: diagnostics)
        return SwiftLexResult(tokens: tokens, diagnostics: diagnostics, summary: summary, sourceLengthUTF8: sourceUTF8Length)
    }

    // MARK: Trivia Scanning

    mutating func scanTrivia(stopAtNewline: Bool) -> [TriviaPiece] {
        var pieces: [TriviaPiece] = []

        // Support `#!` shebang on the very first byte of a script file
        if index == 0 && peek() == "#" && peek(offset: 1) == "!" {
            let startPos = position
            let startIdx = index
            while let ch = peek(), ch != "\n" && ch != "\r\n" {
                advance()
            }
            let text = sliceText(from: startIdx, to: index)
            pieces.append(TriviaPiece(kind: .shebang, text: text, span: SourceSpan(start: startPos, end: position)))
        }

        while let ch = peek() {
            if ch == " " {
                let startPos = position
                let startIdx = index
                while peek() == " " { advance() }
                pieces.append(
                    TriviaPiece(kind: .spaces, text: sliceText(from: startIdx, to: index), span: SourceSpan(start: startPos, end: position))
                )
            } else if ch == "\t" {
                let startPos = position
                let startIdx = index
                while peek() == "\t" { advance() }
                pieces.append(
                    TriviaPiece(kind: .tabs, text: sliceText(from: startIdx, to: index), span: SourceSpan(start: startPos, end: position))
                )
            } else if ch == "\n" {
                if stopAtNewline { break }
                let startPos = position
                let startIdx = index
                while peek() == "\n" { advance() }
                pieces.append(
                    TriviaPiece(kind: .newlines, text: sliceText(from: startIdx, to: index), span: SourceSpan(start: startPos, end: position))
                )
            } else if ch == "\r\n" || ch == "\r" {
                if stopAtNewline { break }
                let startPos = position
                let startIdx = index
                while let c = peek(), c == "\r\n" || c == "\r" || c == "\n" {
                    advance()
                }
                pieces.append(
                    TriviaPiece(
                        kind: .carriageReturnNewlines,
                        text: sliceText(from: startIdx, to: index),
                        span: SourceSpan(start: startPos, end: position)
                    )
                )
            } else if ch == "/" && peek(offset: 1) == "/" {
                let startPos = position
                let startIdx = index
                let isDoc = peek(offset: 2) == "/" && peek(offset: 3) != "/"
                while let c = peek(), c != "\n" && c != "\r\n" && c != "\r" {
                    advance()
                }
                pieces.append(
                    TriviaPiece(
                        kind: isDoc ? .docLineComment : .lineComment,
                        text: sliceText(from: startIdx, to: index),
                        span: SourceSpan(start: startPos, end: position)
                    )
                )
            } else if ch == "/" && peek(offset: 1) == "*" {
                let piece = scanNestedBlockComment()
                pieces.append(piece)
                if stopAtNewline && piece.newlineCount > 0 { break }
            } else { break }
        }

        return pieces
    }

    mutating func scanNestedBlockComment() -> TriviaPiece {
        let startPos = position
        let startIdx = index
        let isDoc = peek(offset: 2) == "*" && peek(offset: 3) != "/"
        advance(count: 2) // consume `/*`
        var depth = 1

        while !isAtEnd && depth > 0 {
            if peek() == "/" && peek(offset: 1) == "*" {
                depth += 1
                advance(count: 2)
            } else if peek() == "*" && peek(offset: 1) == "/" {
                depth -= 1
                advance(count: 2)
            } else { advance() }
        }

        let endPos = position
        if depth > 0 {
            diagnostics.append(
                LexicalDiagnostic(
                    severity: .error,
                    message: "Unterminated block comment (remaining nesting depth: \(depth)).",
                    span: SourceSpan(start: startPos, end: endPos),
                    recoveryHint: "Insert matching '*/' delimiter(s) to close the block comment."
                )
            )
        }

        return TriviaPiece(
            kind: isDoc ? .docBlockComment : .blockComment,
            text: sliceText(from: startIdx, to: index),
            span: SourceSpan(start: startPos, end: endPos)
        )
    }

    // MARK: Token Dispatch

    mutating func scanNextTokenKind() -> SwiftTokenKind {
        guard let ch = peek() else { return .eof }

        // 1. Raw string literal: `#"..."#` or `#"""..."""#`
        if ch == "#" {
            let poundCount = countConsecutivePounds()
            if poundCount > 0 && peek(offset: poundCount) == "\"" {
                return scanStringOrMultilineLiteral(rawDelimiterCount: poundCount)
            }
            return scanDirectiveOrPoundPunctuation()
        }

        // 2. Standard or multiline string literal
        if ch == "\"" {
            return scanStringOrMultilineLiteral(rawDelimiterCount: 0)
        }

        // 3. Attribute `@State`, `@MainActor`, or standalone `@`
        if ch == "@" {
            if let next = peek(offset: 1), isIdentifierHead(next) {
                advance() // `@`
                let identStart = index
                while let c = peek(), isIdentifierContinuation(c) {
                    advance()
                }
                let attrName = sliceText(from: identStart, to: index)
                return .attribute(SwiftAttributeKind(name: attrName))
            }
            advance()
            return .punctuation(.atSign)
        }

        // 4. Backticked identifier `` `default` ``
        if ch == "`" {
            return scanBacktickedIdentifier()
        }

        // 5. Dollar identifier `$0`, `$email`
        if ch == "$" {
            let startIdx = index
            advance()
            if let next = peek(), isIdentifierContinuation(next) || next.isNumber {
                while let c = peek(), isIdentifierContinuation(c) || c.isNumber {
                    advance()
                }
                return .dollarIdentifier(sliceText(from: startIdx, to: index))
            }
            return .unknown("$")
        }

        // 6. Numeric literal (`0`...`9`)
        if isASCIIDigit(ch) { return scanNumericLiteral() }

        // 7. Identifier or Keyword
        if isIdentifierHead(ch) { return scanIdentifierOrKeyword() }

        // 8. Structural single-character punctuation
        switch ch {
        case "(":
            advance()
            return .punctuation(.leftParen)
        case ")":
            advance()
            return .punctuation(.rightParen)
        case "{":
            advance()
            return .punctuation(.leftBrace)
        case "}":
            advance()
            return .punctuation(.rightBrace)
        case "[":
            advance()
            return .punctuation(.leftBracket)
        case "]":
            advance()
            return .punctuation(.rightBracket)
        case ",":
            advance()
            return .punctuation(.comma)
        case ":":
            advance()
            return .punctuation(.colon)
        case ";":
            advance()
            return .punctuation(.semicolon)
        case "\\":
            advance()
            return .punctuation(.backslash)
        default:
            break
        }

        // 9. Dots, ranges, or custom dot-operators (`...`, `..<`, `.`)
        if ch == "." {
            if peek(offset: 1) == "." && peek(offset: 2) == "." {
                let fixity = computeOperatorFixity(startIndex: index, length: 3)
                advance(count: 3)
                if fixity == .infix { return .punctuation(.ellipsis) }
                return .operatorSymbol("...", fixity: fixity)
            }
            if peek(offset: 1) == "." && peek(offset: 2) == "<" {
                advance(count: 3)
                return .punctuation(.halfOpenRange)
            }
            advance()
            return .punctuation(.period)
        }

        // 10. Operators & operator-like punctuation (`->`, `=`, `?`, `!`, `&`, `+`, `==`, etc.)
        if isOperatorHead(ch) { return scanOperatorOrSpecialPunctuation() }

        // 11. Unexpected character recovery
        let badStart = position
        let unexpected = advance() ?? ch
        diagnostics.append(
            LexicalDiagnostic(
                severity: .warning,
                message: "Unexpected character '\(unexpected)' in Swift source.",
                span: SourceSpan(start: badStart, end: position),
                recoveryHint: "Remove or escape unsupported character."
            )
        )
        return .unknown(String(unexpected))
    }

    // MARK: Directives (`#if`, `#Preview`, `#expect`, ...)

    func countConsecutivePounds() -> Int {
        var count = 0
        while peek(offset: count) == "#" {
            count += 1
        }
        return count
    }

    mutating func scanDirectiveOrPoundPunctuation() -> SwiftTokenKind {
        advance() // `#`
        guard let next = peek(), isIdentifierHead(next) else { return .punctuation(.pound) }
        let nameStart = index
        while let c = peek(), isIdentifierContinuation(c) {
            advance()
        }
        let name = sliceText(from: nameStart, to: index)
        let directive = SwiftDirectiveKind(directiveName: "#\(name)")
        return .directive(directive)
    }

    // MARK: Backticked Identifiers, Identifiers & Keywords

    mutating func scanBacktickedIdentifier() -> SwiftTokenKind {
        let startPos = position
        advance() // opening `
        let identStart = index
        while let c = peek(), c != "`" && c != "\n" && c != "\r\n" {
            advance()
        }
        let name = sliceText(from: identStart, to: index)
        if peek() == "`" {
            advance()
            if name.isEmpty {
                diagnostics.append(
                    LexicalDiagnostic(
                        severity: .error,
                        message: "Empty escaped identifier ````.",
                        span: SourceSpan(start: startPos, end: position),
                        recoveryHint: "Provide a valid identifier inside backticks."
                    )
                )
            }
            return .identifier(name, isBackticked: true)
        } else {
            diagnostics.append(
                LexicalDiagnostic(
                    severity: .error,
                    message: "Unterminated backticked identifier '\(name)'.",
                    span: SourceSpan(start: startPos, end: position),
                    recoveryHint: "Close escaped identifier with a matching backtick '`'."
                )
            )
            return .identifier(name, isBackticked: true)
        }
    }

    mutating func scanIdentifierOrKeyword() -> SwiftTokenKind {
        let startIdx = index
        while let c = peek(), isIdentifierContinuation(c) {
            advance()
        }
        let word = sliceText(from: startIdx, to: index)

        if word == "true" {
            return .booleanLiteral(true)
        }
        if word == "false" {
            return .booleanLiteral(false)
        }
        if word == "nil" {
            return .nilLiteral
        }
        if let kw = SwiftKeyword(rawValue: word) { return .keyword(kw) }
        return .identifier(word, isBackticked: false)
    }

    // MARK: String, Raw String, Multiline String & String Interpolation

    mutating func scanStringOrMultilineLiteral(rawDelimiterCount: Int) -> SwiftTokenKind {
        let startPos = position
        let startIdx = index

        if rawDelimiterCount > 0 {
            advance(count: rawDelimiterCount)
        }

        let isMultiline = peek() == "\"" && peek(offset: 1) == "\"" && peek(offset: 2) == "\""
        if isMultiline {
            advance(count: 3)
        } else {
            advance() // single `"`
        }

        var decodedChars: [Character] = []
        var interpolations: [String] = []
        var terminatedCleanly = false

        while !isAtEnd {
            // Check closing delimiter
            if isMultiline {
                if peek() == "\"" && peek(offset: 1) == "\"" && peek(offset: 2) == "\""
                    && hasMatchingTrailingPounds(atOffset: 3, count: rawDelimiterCount) {
                    advance(count: 3 + rawDelimiterCount)
                    terminatedCleanly = true
                    break
                }
            } else {
                if peek() == "\"" && hasMatchingTrailingPounds(atOffset: 1, count: rawDelimiterCount) {
                    advance(count: 1 + rawDelimiterCount)
                    terminatedCleanly = true
                    break
                }
                if let c = peek(), (c == "\n" || c == "\r\n" || c == "\r") {
                    // Single-line string cannot span an unescaped newline
                    break
                }
            }

            // Check escape or interpolation `\` + N `#`s
            if peek() == "\\" && hasMatchingTrailingPounds(atOffset: 1, count: rawDelimiterCount) {
                advance(count: 1 + rawDelimiterCount) // consume `\` and `#`s
                if peek() == "(" {
                    let exprText = scanBalancedInterpolationExpression()
                    interpolations.append(exprText)
                    decodedChars.append(contentsOf: "\\(\(exprText))")
                    continue
                }
                if let escaped = decodeEscapeSequence() {
                    decodedChars.append(escaped)
                }
                continue
            }

            if let regular = advance() {
                decodedChars.append(regular)
            }
        }

        let rawSlice = sliceText(from: startIdx, to: index)
        if !terminatedCleanly {
            diagnostics.append(
                LexicalDiagnostic(
                    severity: .error,
                    message: isMultiline
                        ? "Unterminated multiline string literal."
                        : "Unterminated string literal before end of line.",
                    span: SourceSpan(start: startPos, end: position),
                    recoveryHint: isMultiline
                        ? "Close multiline string with \"\"\"\(String(repeating: "#", count: rawDelimiterCount))."
                        : "Close string literal with \"\(String(repeating: "#", count: rawDelimiterCount))."
                )
            )
        }

        var decodedValue = String(decodedChars)
        if isMultiline {
            decodedValue = normalizeMultilineIndentation(decodedValue)
        }

        if !interpolations.isEmpty {
            return .interpolatedStringSegment(
                raw: rawSlice,
                expressions: interpolations,
                isMultiline: isMultiline,
                rawDelimiterCount: rawDelimiterCount
            )
        }

        return .stringLiteral(
            raw: rawSlice,
            value: options.decodeEscapeSequences ? decodedValue : rawSlice,
            isMultiline: isMultiline,
            rawDelimiterCount: rawDelimiterCount
        )
    }

    func hasMatchingTrailingPounds(atOffset offset: Int, count: Int) -> Bool {
        guard count > 0 else { return true }
        for i in 0..<count {
            if peek(offset: offset + i) != "#" {
                return false
            }
        }
        return true
    }

    mutating func scanBalancedInterpolationExpression() -> String {
        advance() // consume opening `(`
        let exprStartIdx = index
        var parenDepth = 1

        while !isAtEnd && parenDepth > 0 {
            guard let ch = peek() else { break }

            // Skip nested raw string literals (`#"..."#` or `#"""..."""#`) inside interpolation
            if ch == "#" {
                let pounds = countConsecutivePounds()
                if pounds > 0 && peek(offset: pounds) == "\"" {
                    _ = scanStringOrMultilineLiteral(rawDelimiterCount: pounds)
                    continue
                }
            }

            // Skip nested single-line or multiline (`"""..."""`) string literals inside interpolation
            if ch == "\"" {
                _ = scanStringOrMultilineLiteral(rawDelimiterCount: 0)
                continue
            }

            // Skip single-line or nested block comments inside multiline interpolation expressions
            if ch == "/" && peek(offset: 1) == "/" {
                while let sc = peek(), sc != "\n" && sc != "\r\n" && sc != "\r" {
                    advance()
                }
                continue
            }
            if ch == "/" && peek(offset: 1) == "*" {
                advance(count: 2)
                var cDepth = 1
                while !isAtEnd && cDepth > 0 {
                    if peek() == "/" && peek(offset: 1) == "*" {
                        cDepth += 1
                        advance(count: 2)
                    } else if peek() == "*" && peek(offset: 1) == "/" {
                        cDepth -= 1
                        advance(count: 2)
                    } else {
                        advance()
                    }
                }
                continue
            }

            if ch == "(" {
                parenDepth += 1
                advance()
            } else if ch == ")" {
                parenDepth -= 1
                if parenDepth == 0 {
                    let exprText = sliceText(from: exprStartIdx, to: index)
                    advance() // consume closing `)`
                    return exprText
                }
                advance()
            } else {
                advance()
            }
        }

        return sliceText(from: exprStartIdx, to: index)
    }

    mutating func decodeEscapeSequence() -> Character? {
        guard let esc = advance() else { return nil }
        switch esc {
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"
        case "0": return "\0"
        case "\\": return "\\"
        case "\"": return "\""
        case "'": return "'"
        case "u":
            if peek() == "{" {
                advance()
                let hexStart = index
                while let hc = peek(), isHexDigit(hc) {
                    advance()
                }
                let hexDigits = sliceText(from: hexStart, to: index)
                if peek() == "}" {
                    advance()
                }
                if let codePoint = UInt32(hexDigits, radix: 16),
                   let scalar = UnicodeScalar(codePoint) {
                    return Character(scalar)
                }
            }
            return "?"
        default:
            return esc
        }
    }

    func normalizeMultilineIndentation(_ body: String) -> String {
        var lines = body.components(separatedBy: "\n")
        // Per Swift spec, leading newline right after opening `"""` is stripped
        if lines.first?.isEmpty == true {
            lines.removeFirst()
        }
        guard let closingLine = lines.last else { return body }
        let indentPrefix = closingLine.prefix { $0 == " " || $0 == "\t" }
        // Closing delimiter line itself is stripped if only whitespace
        if closingLine.allSatisfy({ $0 == " " || $0 == "\t" }) {
            lines.removeLast()
        }
        guard !indentPrefix.isEmpty else {
            return lines.joined(separator: "\n")
        }
        let stripped = lines.map { line -> String in
            if line.isEmpty { return "" }
            if line.hasPrefix(indentPrefix) {
                return String(line.dropFirst(indentPrefix.count))
            }
            return line
        }
        return stripped.joined(separator: "\n")
    }

    // MARK: Numeric Literals (Hex, Binary, Octal, Decimal, Scientific, Underscored)

    mutating func scanNumericLiteral() -> SwiftTokenKind {
        let startPos = position
        let startIdx = index

        if peek() == "0", let second = peek(offset: 1) {
            if second == "x" || second == "X" {
                advance(count: 2)
                return scanHexadecimalNumber(startIdx: startIdx, startPos: startPos)
            }
            if second == "b" || second == "B" {
                advance(count: 2)
                return scanRadixInteger(radix: .binary, startIdx: startIdx, startPos: startPos, validator: isBinaryDigit)
            }
            if second == "o" || second == "O" {
                advance(count: 2)
                return scanRadixInteger(radix: .octal, startIdx: startIdx, startPos: startPos, validator: isOctalDigit)
            }
        }

        return scanDecimalNumber(startIdx: startIdx, startPos: startPos)
    }

    mutating func scanRadixInteger(
        radix: NumericRadix,
        startIdx: Int,
        startPos: SourcePosition,
        validator: (Character) -> Bool
    ) -> SwiftTokenKind {
        let digitsStart = index
        while let ch = peek(), validator(ch) || ch == "_" {
            advance()
        }
        let rawDigits = sliceText(from: digitsStart, to: index)
        let cleaned = rawDigits.replacingOccurrences(of: "_", with: "")
        let rawLiteral = sliceText(from: startIdx, to: index)

        if cleaned.isEmpty {
            diagnostics.append(
                LexicalDiagnostic(
                    severity: .error,
                    message: "Missing \(radix.rawValue) digits after '\(radix.literalPrefix)' prefix.",
                    span: SourceSpan(start: startPos, end: position),
                    recoveryHint: "Add valid base-\(radix.base) digits after '\(radix.literalPrefix)'."
                )
            )
            return .integerLiteral(raw: rawLiteral, value: nil, radix: radix)
        }

        let parsed = Int64(cleaned, radix: radix.base)
        return .integerLiteral(raw: rawLiteral, value: parsed, radix: radix)
    }

    mutating func scanHexadecimalNumber(startIdx: Int, startPos: SourcePosition) -> SwiftTokenKind {
        let intDigitsStart = index
        while let ch = peek(), isHexDigit(ch) || ch == "_" {
            advance()
        }
        var isFloat = false

        // Hex fraction `.digits`
        if peek() == ".", let afterDot = peek(offset: 1), isHexDigit(afterDot) {
            isFloat = true
            advance() // `.`
            while let ch = peek(), isHexDigit(ch) || ch == "_" {
                advance()
            }
        }

        // Hex binary exponent `p` / `P`
        if let expChar = peek(), expChar == "p" || expChar == "P" {
            isFloat = true
            advance()
            if let sign = peek(), sign == "+" || sign == "-" {
                advance()
            }
            let expStart = index
            while let ch = peek(), isASCIIDigit(ch) || ch == "_" {
                advance()
            }
            if index == expStart {
                diagnostics.append(
                    LexicalDiagnostic(
                        severity: .error,
                        message: "Hexadecimal floating-point literal requires decimal exponent digits after '\(expChar)'.",
                        span: SourceSpan(start: startPos, end: position),
                        recoveryHint: "Provide exponent digits, e.g. '0x1.fp2'."
                    )
                )
            }
        }

        let rawLiteral = sliceText(from: startIdx, to: index)
        let cleanedBody = sliceText(from: intDigitsStart, to: index).replacingOccurrences(of: "_", with: "")

        if cleanedBody.isEmpty {
            diagnostics.append(
                LexicalDiagnostic(
                    severity: .error,
                    message: "Missing hexadecimal digits after '0x' prefix.",
                    span: SourceSpan(start: startPos, end: position),
                    recoveryHint: "Provide hexadecimal digits 0-9 or A-F."
                )
            )
            return .integerLiteral(raw: rawLiteral, value: nil, radix: .hexadecimal)
        }

        if isFloat {
            let cleanedFull = rawLiteral.replacingOccurrences(of: "_", with: "")
            return .floatingLiteral(raw: rawLiteral, value: Double(cleanedFull), radix: .hexadecimal)
        }

        let intVal: Int64?
        if let signed = Int64(cleanedBody, radix: 16) {
            intVal = signed
        } else if let unsigned = UInt64(cleanedBody, radix: 16) {
            intVal = Int64(bitPattern: unsigned)
        } else {
            intVal = nil
        }
        return .integerLiteral(raw: rawLiteral, value: intVal, radix: .hexadecimal)
    }

    mutating func scanDecimalNumber(startIdx: Int, startPos: SourcePosition) -> SwiftTokenKind {
        while let ch = peek(), isASCIIDigit(ch) || ch == "_" {
            advance()
        }
        var isFloat = false

        // Decimal fraction `.digits` (must be followed by a digit so `5.description` or `1...5` stays an integer!)
        if peek() == ".", let afterDot = peek(offset: 1), isASCIIDigit(afterDot) {
            isFloat = true
            advance() // `.`
            while let ch = peek(), isASCIIDigit(ch) || ch == "_" {
                advance()
            }
        }

        // Scientific exponent `e` / `E`
        if let expChar = peek(), expChar == "e" || expChar == "E" {
            isFloat = true
            advance()
            if let sign = peek(), sign == "+" || sign == "-" {
                advance()
            }
            let expStart = index
            while let ch = peek(), isASCIIDigit(ch) || ch == "_" {
                advance()
            }
            if index == expStart {
                diagnostics.append(
                    LexicalDiagnostic(
                        severity: .error,
                        message: "Floating-point literal missing exponent digits after '\(expChar)'.",
                        span: SourceSpan(start: startPos, end: position),
                        recoveryHint: "Provide exponent digits, e.g. '1.25e-3'."
                    )
                )
            }
        }

        let rawLiteral = sliceText(from: startIdx, to: index)
        let cleaned = rawLiteral.replacingOccurrences(of: "_", with: "")

        if isFloat {
            return .floatingLiteral(raw: rawLiteral, value: Double(cleaned), radix: .decimal)
        }
        return .integerLiteral(raw: rawLiteral, value: Int64(cleaned), radix: .decimal)
    }

    // MARK: Operators & Special Punctuation

    mutating func scanOperatorOrSpecialPunctuation() -> SwiftTokenKind {
        let opStartIdx = index

        // Consume maximal operator character run while stopping before `//` or `/*` comments
        while let ch = peek(), isOperatorContinuation(ch) {
            if ch == "/" && (peek(offset: 1) == "/" || peek(offset: 1) == "*") {
                break
            }
            // Postfix `!` or `?` immediately followed by `.` or `(` or `[` (e.g. `value!.name`, `opt?.count`, `try? foo()`)
            // should remain a single-character operator/punctuation rather than merging with unrelated symbols.
            if index > opStartIdx && (characters[opStartIdx] == "?" || characters[opStartIdx] == "!") {
                // Allow `??`, `!=`, `!==`, `?=`, etc., only when the second char is `=` or `?`
                if ch != "=" && ch != "?" {
                    break
                }
            }
            advance()
        }

        let opString = sliceText(from: opStartIdx, to: index)
        let fixity = computeOperatorFixity(startIndex: opStartIdx, length: index - opStartIdx)

        switch opString {
        case "=":
            return .punctuation(.equal)
        case "->":
            return .punctuation(.arrow)
        case "&" where fixity == .prefix:
            return .punctuation(.ampersand)
        case "?" where fixity != .infix:
            return .punctuation(.questionMark)
        case "?":
            return .punctuation(.questionMark)
        case "!" where fixity != .infix:
            if fixity == .postfix {
                return .operatorSymbol("!", fixity: .postfix)
            }
            return .operatorSymbol("!", fixity: .prefix)
        default:
            return .operatorSymbol(opString, fixity: fixity)
        }
    }

    func computeOperatorFixity(startIndex: Int, length: Int) -> SwiftOperatorFixity {
        let prevChar: Character? = startIndex > 0 ? characters[startIndex - 1] : nil
        let nextIndex = startIndex + length
        let nextChar: Character? = nextIndex < characters.count ? characters[nextIndex] : nil

        let leftBound = prevChar != nil && !isOperatorBoundaryLeft(prevChar!)
        let rightBound = nextChar != nil && !isOperatorBoundaryRight(nextChar!)

        switch (leftBound, rightBound) {
        case (true, true), (false, false):
            return .infix
        case (true, false):
            return .postfix
        case (false, true):
            return .prefix
        }
    }

    // MARK: Character Classification Predicates

    func isASCIIDigit(_ c: Character) -> Bool {
        c >= "0" && c <= "9"
    }

    func isBinaryDigit(_ c: Character) -> Bool {
        c == "0" || c == "1"
    }

    func isOctalDigit(_ c: Character) -> Bool {
        c >= "0" && c <= "7"
    }

    func isHexDigit(_ c: Character) -> Bool {
        (c >= "0" && c <= "9") || (c >= "a" && c <= "f") || (c >= "A" && c <= "F")
    }

    func isIdentifierHead(_ c: Character) -> Bool {
        if c == "_" { return true }
        if (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") { return true }
        if c.isLetter { return true }
        return false
    }

    func isIdentifierContinuation(_ c: Character) -> Bool {
        if isIdentifierHead(c) || isASCIIDigit(c) { return true }
        if c.isNumber { return true }
        return false
    }

    func isOperatorHead(_ c: Character) -> Bool {
        switch c {
        case "/", "=", "-", "+", "!", "*", "%", "<", ">", "&", "|", "^", "~", "?":
            return true
        default:
            return false
        }
    }

    func isOperatorContinuation(_ c: Character) -> Bool {
        isOperatorHead(c)
    }

    func isOperatorBoundaryLeft(_ c: Character) -> Bool {
        switch c {
        case " ", "\t", "\n", "\r", "\r\n", "(", "[", "{", ",", ";", ":":
            return true
        default:
            return false
        }
    }

    func isOperatorBoundaryRight(_ c: Character) -> Bool {
        switch c {
        case " ", "\t", "\n", "\r", "\r\n", ")", "]", "}", ",", ";", ":", ".":
            return true
        default:
            return false
        }
    }
}
