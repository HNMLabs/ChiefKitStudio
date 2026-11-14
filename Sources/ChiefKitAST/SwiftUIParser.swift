import ChiefKitStudioCore
import Foundation

// MARK: - Recursive-Descent Swift 6 & SwiftUI Parser

/// Recursive-descent parser turning Swift 6 lexical tokens or raw source code into a typed `SwiftSourceFile` AST.
public enum SwiftUIParser: Sendable {
    /// Lexes and parses a Swift 6 / SwiftUI source string into a `SwiftSourceFile`.
    public static func parse(source: String, filePath: String? = nil) -> SwiftSourceFile {
        let lexed = SwiftLexer.tokenize(source)
        let lineCount = max(1, source.isEmpty ? 1 : source.components(separatedBy: "\n").count)
        var parser = ParserState(tokens: lexed.tokens, lexicalDiagnostics: lexed.diagnostics, filePath: filePath, lineCount: lineCount)
        return parser.parseSourceFile()
    }

    /// Parses a pre-tokenized `[SwiftToken]` stream directly into a `SwiftSourceFile`.
    public static func parse(
        tokens: [SwiftToken],
        sourceLengthLines: Int = 0,
        filePath: String? = nil
    ) -> SwiftSourceFile {
        let computedLines = sourceLengthLines > 0
            ? sourceLengthLines
            : max(1, tokens.last?.span.end.line ?? 1)
        var parser = ParserState(tokens: tokens, lexicalDiagnostics: [], filePath: filePath, lineCount: computedLines)
        return parser.parseSourceFile()
    }
}

// MARK: - Internal Recursive-Descent Parser State

private struct ConditionalDirectiveFrame {
    var rootCondition: String
    var activeCondition: String
    var elseIfConditions: [String] = []
    var hasElse: Bool = false
    var startPos: SourcePosition
}

private struct DeclarationHeader {
    var attributes: [SwiftAttributeNode] = []
    var wrappers: [SwiftPropertyWrapper] = []
    var accessLevel: SwiftAccessLevel = .internal
    var isStatic: Bool = false
    var isFinal: Bool = false
    var isMutating: Bool = false
    var docComment: String?
    var startPos: SourcePosition
}

private struct ParserState {
    let tokens: [SwiftToken]
    let filePath: String?
    let lineCount: Int

    var cursor: Int = 0
    var diagnostics: [ParseDiagnostic] = []
    var conditionalStack: [ConditionalDirectiveFrame] = []
    var completedConditionalBlocks: [SwiftConditionalCompilationBlock] = []

    init(
        tokens: [SwiftToken],
        lexicalDiagnostics: [LexicalDiagnostic],
        filePath: String?,
        lineCount: Int
    ) {
        self.tokens = tokens.isEmpty
            ? [SwiftToken(id: 0, kind: .eof, text: "", span: .zero)]
            : tokens
        self.filePath = filePath
        self.lineCount = lineCount
        self.diagnostics = lexicalDiagnostics.map { lexDiag in
            ParseDiagnostic(severity: lexDiag.severity == .error ? .error : .warning, message: lexDiag.message, span: lexDiag.span)
        }
    }

    // MARK: Cursor Primitives

    var current: SwiftToken {
        guard cursor < tokens.count else { return tokens[tokens.count - 1] }
        return tokens[cursor]
    }

    var isAtEnd: Bool {
        current.isEOF
    }

    func peek(offset: Int = 1) -> SwiftToken {
        let idx = cursor + offset
        guard idx >= 0 && idx < tokens.count else { return tokens[tokens.count - 1] }
        return tokens[idx]
    }

    @discardableResult
    mutating func advance() -> SwiftToken {
        let tok = current
        if cursor < tokens.count - 1 {
            cursor += 1
        }
        return tok
    }

    var activeConditionalSummary: String? {
        guard !conditionalStack.isEmpty else { return nil }
        return conditionalStack.map(\.activeCondition).joined(separator: " && ")
    }

    mutating func consumeIfKeyword(_ kw: SwiftKeyword) -> Bool {
        if current.isKeyword(kw) {
            advance()
            return true
        }
        return false
    }

    mutating func consumeIfPunctuation(_ punct: SwiftPunctuation) -> Bool {
        if current.isPunctuation(punct) {
            advance()
            return true
        }
        return false
    }

    mutating func expectPunctuation(_ punct: SwiftPunctuation, context: String) -> Bool {
        if current.isPunctuation(punct) {
            advance()
            return true
        }
        diagnostics.append(
            ParseDiagnostic(
                severity: .error,
                message: "Expected '\(punct.rawValue)' \(context), found '\(current.text)'.",
                span: current.span,
                expected: punct.rawValue,
                found: current.text
            )
        )
        return false
    }

    // MARK: Top-Level File Parsing

    mutating func parseSourceFile() -> SwiftSourceFile {
        var imports: [SwiftImportDecl] = []
        var types: [SwiftTypeDecl] = []
        var topLevelProperties: [SwiftPropertyDecl] = []
        var topLevelFunctions: [SwiftFunctionDecl] = []
        var previews: [SwiftPreviewDecl] = []

        while !isAtEnd {
            let savedCursor = cursor
            consumeOptionalSemicolons()
            if isAtEnd { break }

            // Handle `#if / #elseif / #else / #endif` and `#Preview`
            if case .directive(let dirKind) = current.kind {
                if dirKind.isConditionalCompilation {
                    handleConditionalDirective(dirKind)
                    continue
                }
                if dirKind == .preview {
                    previews.append(parsePreviewDeclaration())
                    continue
                }
            }

            let header = parseDeclarationHeader()

            if current.isKeyword(.import) {
                imports.append(parseImportDecl(header: header))
            } else if let typeKind = currentTypeKind() {
                types.append(parseTypeDecl(kind: typeKind, header: header))
            } else if current.isKeyword(.var) || current.isKeyword(.let) {
                topLevelProperties.append(parsePropertyDecl(header: header, enclosingIsProtocol: false))
            } else if current.isKeyword(.func) || current.isKeyword(.initializer) {
                topLevelFunctions.append(parseFunctionDecl(header: header, enclosingIsProtocol: false))
            } else if current.isKeyword(.typealias) {
                skipTypealiasDeclaration()
            } else {
                // Top-level expression or unexpected token: recover gracefully
                synchronizeTopLevel()
            }

            if cursor == savedCursor && !isAtEnd { advance() }
        }

        // Record any unclosed `#if` blocks with a diagnostic
        while let unclosed = conditionalStack.popLast() {
            let span = SourceSpan(start: unclosed.startPos, end: current.span.end)
            diagnostics.append(
                ParseDiagnostic(
                    severity: .error,
                    message: "Unclosed '#if \(unclosed.rootCondition)' conditional compilation block.",
                    span: span,
                    expected: "#endif",
                    found: "EOF"
                )
            )
            completedConditionalBlocks.append(
                SwiftConditionalCompilationBlock(
                    condition: unclosed.rootCondition,
                    elseIfConditions: unclosed.elseIfConditions,
                    hasElse: unclosed.hasElse,
                    span: span
                )
            )
        }

        return SwiftSourceFile(
            filePath: filePath,
            imports: imports,
            types: types,
            topLevelProperties: topLevelProperties,
            topLevelFunctions: topLevelFunctions,
            previews: previews,
            conditionalBlocks: completedConditionalBlocks,
            diagnostics: diagnostics,
            lineCount: lineCount
        )
    }

    mutating func consumeOptionalSemicolons() {
        while current.isPunctuation(.semicolon) {
            advance()
        }
    }

    // MARK: Conditional Compilation Directives (`#if`, `#elseif`, `#else`, `#endif`)

    mutating func handleConditionalDirective(_ kind: SwiftDirectiveKind) {
        let dirToken = advance()
        switch kind {
        case .poundIf:
            let condText = collectRestOfDirectiveLine(directiveLine: dirToken.span.start.line)
            conditionalStack.append(ConditionalDirectiveFrame(rootCondition: condText, activeCondition: condText, startPos: dirToken.span.start))
        case .poundElseif:
            let condText = collectRestOfDirectiveLine(directiveLine: dirToken.span.start.line)
            if !conditionalStack.isEmpty {
                conditionalStack[conditionalStack.count - 1].elseIfConditions.append(condText)
                conditionalStack[conditionalStack.count - 1].activeCondition = condText
            } else {
                diagnostics.append(
                    ParseDiagnostic(
                        severity: .error,
                        message: "Unexpected '#elseif' without matching '#if'.",
                        span: dirToken.span,
                        expected: "#if",
                        found: "#elseif"
                    )
                )
            }
        case .poundElse:
            if !conditionalStack.isEmpty {
                let root = conditionalStack[conditionalStack.count - 1].rootCondition
                conditionalStack[conditionalStack.count - 1].hasElse = true
                conditionalStack[conditionalStack.count - 1].activeCondition = "!(\(root))"
            } else {
                diagnostics.append(
                    ParseDiagnostic(
                        severity: .error,
                        message: "Unexpected '#else' without matching '#if'.",
                        span: dirToken.span,
                        expected: "#if",
                        found: "#else"
                    )
                )
            }
        case .poundEndif:
            if let completed = conditionalStack.popLast() {
                completedConditionalBlocks.append(
                    SwiftConditionalCompilationBlock(
                        condition: completed.rootCondition,
                        elseIfConditions: completed.elseIfConditions,
                        hasElse: completed.hasElse,
                        span: SourceSpan(start: completed.startPos, end: dirToken.span.end)
                    )
                )
            } else {
                diagnostics.append(
                    ParseDiagnostic(
                        severity: .error,
                        message: "Unexpected '#endif' without matching '#if'.",
                        span: dirToken.span,
                        expected: "declaration",
                        found: "#endif"
                    )
                )
            }
        default:
            break
        }
    }

    mutating func collectRestOfDirectiveLine(directiveLine: Int) -> String {
        var parts: [String] = []
        while !isAtEnd && current.span.start.line == directiveLine && !current.hasLeadingNewline {
            parts.append(current.text)
            advance()
        }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    // MARK: `#Preview` Macro

    mutating func parsePreviewDeclaration() -> SwiftPreviewDecl {
        let startPos = current.span.start
        advance() // `#Preview`
        var title: String?
        if current.isPunctuation(.leftParen) {
            let args = parseArgumentList()
            title = args.first?.value.stringLiteralValue
        }
        var viewNodes: [SwiftViewNode] = []
        if current.isPunctuation(.leftBrace) {
            viewNodes = parseViewBuilderBlock()
        }
        let endPos = previousTokenEnd(fallback: startPos)
        return SwiftPreviewDecl(title: title, viewNodes: viewNodes, statements: [], span: SourceSpan(start: startPos, end: endPos))
    }

    // MARK: Attributes, Wrappers & Modifiers Header

    mutating func parseDeclarationHeader() -> DeclarationHeader {
        let firstDoc = current.leadingDocComment
        var header = DeclarationHeader(docComment: firstDoc, startPos: current.span.start)

        while !isAtEnd {
            if case .attribute(let attrKind) = current.kind {
                let attrSpanStart = current.span.start
                let rawName = current.text.hasPrefix("@") ? String(current.text.dropFirst()) : current.text
                if header.docComment == nil { header.docComment = current.leadingDocComment }
                advance()

                var modArgs: [SwiftModifierArg] = []
                var rawArgs: [String] = []
                if current.isPunctuation(.leftParen) && !current.hasLeadingNewline {
                    modArgs = parseArgumentList()
                    rawArgs = modArgs.map(\.renderedSource)
                }
                let attrSpan = SourceSpan(start: attrSpanStart, end: previousTokenEnd(fallback: attrSpanStart))

                if attrKind.isSwiftUIPropertyWrapper {
                    header.wrappers.append(SwiftPropertyWrapper(kind: attrKind, arguments: modArgs, span: attrSpan))
                }
                header.attributes.append(SwiftAttributeNode(kind: attrKind, rawName: rawName, arguments: rawArgs, span: attrSpan))
                continue
            }

            if case .keyword(let kw) = current.kind, kw.isDeclarationModifier {
                if header.docComment == nil { header.docComment = current.leadingDocComment }
                advance()
                if let access = SwiftAccessLevel(keyword: kw) {
                    header.accessLevel = access
                    // Handle `private(set)` / `public(set)`
                    if current.isPunctuation(.leftParen) {
                        _ = collectBalancedParenthesesText()
                    }
                } else if kw == .static {
                    header.isStatic = true
                } else if kw == .final {
                    header.isFinal = true
                } else if kw == .mutating {
                    header.isMutating = true
                } else if kw == .nonisolated && current.isPunctuation(.leftParen) {
                    let inner = collectBalancedParenthesesText()
                    header.attributes.append(SwiftAttributeNode(kind: .custom("nonisolated"), rawName: "nonisolated", arguments: [inner]))
                }
                continue
            }

            break
        }

        return header
    }

    func currentTypeKind() -> SwiftTypeKind? {
        if case .keyword(let kw) = current.kind { return SwiftTypeKind(keyword: kw) }
        return nil
    }

    // MARK: Import Declarations

    mutating func parseImportDecl(header: DeclarationHeader) -> SwiftImportDecl {
        let startPos = header.startPos
        advance() // `import`

        var importKind: String?
        if case .keyword(let kw) = current.kind,
           kw.isTypeDeclarationIntroducer || kw == .func || kw == .var || kw == .let || kw == .typealias {
            importKind = kw.rawValue
            advance()
        }

        let moduleName = current.memberIdentifierName ?? "UnknownModule"
        if current.memberIdentifierName != nil { advance() }

        var subpath: [String] = []
        while current.isPunctuation(.period) {
            advance()
            if let nextPart = current.memberIdentifierName {
                subpath.append(nextPart)
                advance()
            } else { break }
        }

        let isExported = header.attributes.contains { $0.rawName == "_exported" }
        let isPreconcurrency = header.attributes.contains { $0.kind == .preconcurrency }
        let endPos = previousTokenEnd(fallback: startPos)

        return SwiftImportDecl(
            moduleName: moduleName,
            subpath: subpath,
            importKind: importKind,
            isExported: isExported,
            isPreconcurrency: isPreconcurrency,
            conditionalDirective: activeConditionalSummary,
            span: SourceSpan(start: startPos, end: endPos)
        )
    }

    // MARK: Type Declarations (`struct`, `class`, `actor`, `enum`, `protocol`, `extension`)

    mutating func parseTypeDecl(kind: SwiftTypeKind, header: DeclarationHeader) -> SwiftTypeDecl {
        let startPos = header.startPos
        advance() // consume `struct` / `class` / `actor` / `enum` / `protocol` / `extension`

        var typeName = current.memberIdentifierName ?? "AnonymousType"
        if current.memberIdentifierName != nil { advance() }
        // Qualified extension names like `extension Outer.Inner`
        while current.isPunctuation(.period), let part = peek().memberIdentifierName {
            advance() // `.`
            typeName += ".\(part)"
            advance()
        }

        let generics = parseOptionalGenericParameterList()
        let conformances = parseOptionalInheritanceClause()
        skipOptionalWhereClause()

        var properties: [SwiftPropertyDecl] = []
        var functions: [SwiftFunctionDecl] = []
        var enumCases: [SwiftEnumCaseDecl] = []
        var nestedTypes: [SwiftTypeDecl] = []

        if expectPunctuation(.leftBrace, context: "opening body of \(kind.rawValue) '\(typeName)'") {
            while !isAtEnd && !current.isPunctuation(.rightBrace) {
                let memberLoopStart = cursor
                consumeOptionalSemicolons()
                if current.isPunctuation(.rightBrace) || isAtEnd { break }

                if case .directive(let dirKind) = current.kind, dirKind.isConditionalCompilation {
                    handleConditionalDirective(dirKind)
                    continue
                }

                let memberHeader = parseDeclarationHeader()

                if current.isKeyword(.case) {
                    enumCases.append(contentsOf: parseEnumCaseElements(header: memberHeader))
                } else if current.isKeyword(.var) || current.isKeyword(.let) {
                    properties.append(parsePropertyDecl(header: memberHeader, enclosingIsProtocol: kind == .protocol))
                } else if current.isKeyword(.func) || current.isKeyword(.initializer) {
                    functions.append(parseFunctionDecl(header: memberHeader, enclosingIsProtocol: kind == .protocol))
                } else if current.isKeyword(.deinit) {
                    skipDeinitOrSubscript()
                } else if current.isKeyword(.subscript) {
                    skipDeinitOrSubscript()
                } else if let nestedKind = currentTypeKind() {
                    nestedTypes.append(parseTypeDecl(kind: nestedKind, header: memberHeader))
                } else if current.isKeyword(.typealias) || current.isKeyword(.associatedtype) {
                    skipTypealiasDeclaration()
                } else {
                    synchronizeInsideTypeBody()
                }

                if cursor == memberLoopStart && !isAtEnd && !current.isPunctuation(.rightBrace) { advance() }
            }
            _ = consumeIfPunctuation(.rightBrace)
        }

        let endPos = previousTokenEnd(fallback: startPos)
        return SwiftTypeDecl(
            name: typeName,
            kind: kind,
            accessLevel: header.accessLevel,
            isFinal: header.isFinal,
            attributes: header.attributes,
            genericParameters: generics,
            conformances: conformances,
            properties: properties,
            functions: functions,
            enumCases: enumCases,
            nestedTypes: nestedTypes,
            docComment: header.docComment,
            conditionalDirective: activeConditionalSummary,
            span: SourceSpan(start: startPos, end: endPos)
        )
    }

    mutating func parseOptionalGenericParameterList() -> [String] {
        guard current.isOperator("<") else { return [] }
        advance() // `<`
        var params: [String] = []
        var currentParam = ""
        var depth = 1

        while !isAtEnd && depth > 0 {
            if current.isOperator("<") {
                depth += 1
                currentParam += "<"
                advance()
            } else if current.isOperator(">") {
                depth -= 1
                if depth > 0 { currentParam += ">" }
                advance()
            } else if current.isOperator(">>") {
                // Nested generic close `>>`
                depth = max(0, depth - 2)
                advance()
            } else if depth == 1 && current.isPunctuation(.comma) {
                let trimmed = currentParam.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { params.append(trimmed) }
                currentParam = ""
                advance()
            } else {
                if !currentParam.isEmpty && current.text != ":" {
                    currentParam += " "
                }
                currentParam += current.text
                advance()
            }
        }

        let trimmed = currentParam.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { params.append(trimmed) }
        return params
    }

    mutating func parseOptionalInheritanceClause() -> [String] {
        guard consumeIfPunctuation(.colon) else { return [] }
        var conformances: [String] = []
        var currentItem = ""
        var angleDepth = 0

        while !isAtEnd {
            if angleDepth == 0 && (current.isPunctuation(.leftBrace) || current.isKeyword(.where)) { break }
            if current.isOperator("<") {
                angleDepth += 1
                currentItem += "<"
                advance()
            } else if current.isOperator(">") && angleDepth > 0 {
                angleDepth -= 1
                currentItem += ">"
                advance()
            } else if angleDepth == 0 && current.isPunctuation(.comma) {
                let cleaned = currentItem.trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { conformances.append(cleaned) }
                currentItem = ""
                advance()
            } else {
                if !currentItem.isEmpty && !currentItem.hasSuffix("@") && current.text != "." {
                    currentItem += " "
                }
                currentItem += current.text
                advance()
            }
        }

        let cleaned = currentItem.trimmingCharacters(in: .whitespaces)
        if !cleaned.isEmpty { conformances.append(cleaned) }
        return conformances
    }

    mutating func skipOptionalWhereClause() {
        guard current.isKeyword(.where) else { return }
        advance()
        while !isAtEnd && !current.isPunctuation(.leftBrace) && !current.hasLeadingNewline {
            advance()
        }
        while !isAtEnd && !current.isPunctuation(.leftBrace) && !current.isKeyword(.struct) && !current.isKeyword(.func) {
            if current.isPunctuation(.semicolon) { break }
            advance()
        }
    }

    // MARK: Enum Cases

    mutating func parseEnumCaseElements(header: DeclarationHeader) -> [SwiftEnumCaseDecl] {
        let startPos = header.startPos
        advance() // `case`
        var cases: [SwiftEnumCaseDecl] = []

        while !isAtEnd {
            let caseStart = current.span.start
            guard let caseName = current.memberIdentifierName else { break }
            advance()

            var assocParams: [SwiftParameter] = []
            if current.isPunctuation(.leftParen) {
                assocParams = parseParameterList()
            }

            var rawValue: SwiftExpr?
            if consumeIfPunctuation(.equal) {
                rawValue = parseExpression(allowTrailingClosure: false)
            }

            let caseSpan = SourceSpan(start: cases.isEmpty ? startPos : caseStart, end: previousTokenEnd(fallback: caseStart))
            cases.append(
                SwiftEnumCaseDecl(
                    name: caseName,
                    rawValue: rawValue,
                    associatedValues: assocParams,
                    docComment: cases.isEmpty ? header.docComment : nil,
                    span: caseSpan
                )
            )

            if !consumeIfPunctuation(.comma) { break }
        }

        return cases
    }

    // MARK: Property Declarations & `var body: some View`

    mutating func parsePropertyDecl(header: DeclarationHeader, enclosingIsProtocol: Bool) -> SwiftPropertyDecl {
        let startPos = header.startPos
        let isLet = current.isKeyword(.let)
        advance() // `var` or `let`

        let propName = current.memberIdentifierName ?? "_"
        if current.memberIdentifierName != nil { advance() }

        var typeAnnotation: String?
        if consumeIfPunctuation(.colon) {
            typeAnnotation = parseTypeAnnotationString()
        }

        var initializer: SwiftExpr?
        if consumeIfPunctuation(.equal) {
            initializer = parseExpression(allowTrailingClosure: true)
        }

        var isComputed = false
        var computedViewBody: [SwiftViewNode] = []
        var computedStatements: [SwiftStatement] = []

        if current.isPunctuation(.leftBrace) {
            if enclosingIsProtocol {
                // Protocol requirement `{ get set }`
                _ = collectBalancedBracesText()
            } else if initializer != nil {
                // Stored property observer `{ didSet { ... } willSet { ... } }`
                _ = collectBalancedBracesText()
            } else {
                isComputed = true
                let isViewBody = propName == "body"
                    || (typeAnnotation?.contains("View") == true)
                    || header.attributes.contains { $0.kind == .viewBuilder }

                if isViewBody {
                    computedViewBody = parseViewBuilderBlock()
                } else {
                    computedStatements = parseAccessorOrStatementBlock()
                }
            }
        }

        let endPos = previousTokenEnd(fallback: startPos)
        return SwiftPropertyDecl(
            name: propName,
            isLet: isLet,
            accessLevel: header.accessLevel,
            isStatic: header.isStatic,
            typeAnnotation: typeAnnotation,
            initializer: initializer,
            wrappers: header.wrappers,
            attributes: header.attributes,
            isComputed: isComputed,
            computedViewBody: computedViewBody,
            computedStatements: computedStatements,
            docComment: header.docComment,
            span: SourceSpan(start: startPos, end: endPos)
        )
    }

    mutating func parseTypeAnnotationString() -> String {
        var parts: [String] = []
        var parenDepth = 0
        var bracketDepth = 0
        var angleDepth = 0

        while !isAtEnd {
            if parenDepth == 0 && bracketDepth == 0 && angleDepth == 0 {
                if current.isPunctuation(.equal)
                    || current.isPunctuation(.leftBrace)
                    || current.isPunctuation(.comma)
                    || current.isPunctuation(.rightParen)
                    || current.isKeyword(.where) {
                    break
                }
                if current.hasLeadingNewline { break }
            }

            if current.isPunctuation(.leftParen) { parenDepth += 1 }
            else if current.isPunctuation(.rightParen) { parenDepth = max(0, parenDepth - 1) }
            else if current.isPunctuation(.leftBracket) { bracketDepth += 1 }
            else if current.isPunctuation(.rightBracket) { bracketDepth = max(0, bracketDepth - 1) }
            else if current.isOperator("<") { angleDepth += 1 }
            else if current.isOperator(">") && angleDepth > 0 { angleDepth -= 1 }

            parts.append(current.text)
            advance()
        }

        return normalizeTypeSpacing(parts)
    }

    func normalizeTypeSpacing(_ parts: [String]) -> String {
        var out = ""
        for (idx, part) in parts.enumerated() {
            if idx == 0 {
                out += part
                continue
            }
            let prev = parts[idx - 1]
            let noSpaceBefore = part == "?" || part == "!" || part == ">" || part == "]" || part == ")" || part == "," || part == ":" || part == "."
            let noSpaceAfterPrev = prev == "<" || prev == "[" || prev == "(" || prev == "." || prev == "@"
            if part == "->" || prev == "->" || prev == "some" || prev == "any" || prev == "inout" || prev == "," || prev == ":" {
                out += " " + part
            } else if noSpaceBefore || noSpaceAfterPrev {
                out += part
            } else {
                out += " " + part
            }
        }
        return out
    }

    // MARK: Function & Initializer Declarations

    mutating func parseFunctionDecl(header: DeclarationHeader, enclosingIsProtocol: Bool) -> SwiftFunctionDecl {
        let startPos = header.startPos
        let isInit = current.isKeyword(.initializer)
        var funcName = "init"

        if isInit {
            advance()
            // Failable `init?` or `init!`
            if current.isOperator("?") || current.isOperator("!") || current.isPunctuation(.questionMark) {
                funcName += current.text
                advance()
            }
        } else {
            advance() // `func`
            if let ident = current.memberIdentifierName {
                funcName = ident
                advance()
            } else if case .operatorSymbol(let op, _) = current.kind {
                funcName = op
                advance()
            }
        }

        let generics = parseOptionalGenericParameterList()
        let parameters = current.isPunctuation(.leftParen) ? parseParameterList() : []

        var isAsync = false
        var isThrows = false
        while !isAtEnd {
            if consumeIfKeyword(.async) {
                isAsync = true
            } else if consumeIfKeyword(.throws) || consumeIfKeyword(.rethrows) {
                isThrows = true
                if current.isPunctuation(.leftParen) {
                    _ = collectBalancedParenthesesText() // Swift 6 typed throws `throws(MyError)`
                }
            } else { break }
        }

        var returnType: String?
        if consumeIfPunctuation(.arrow) {
            returnType = parseTypeAnnotationString()
        }

        skipOptionalWhereClause()

        var statements: [SwiftStatement] = []
        var viewBody: [SwiftViewNode] = []

        if !enclosingIsProtocol && current.isPunctuation(.leftBrace) {
            let isViewBuilderFunc = header.attributes.contains { $0.kind == .viewBuilder }
                || (returnType?.contains("some View") == true)
            if isViewBuilderFunc {
                viewBody = parseViewBuilderBlock()
            } else {
                statements = parseStatementBlock()
            }
        }

        let endPos = previousTokenEnd(fallback: startPos)
        return SwiftFunctionDecl(
            name: funcName,
            isInitializer: isInit,
            accessLevel: header.accessLevel,
            isStatic: header.isStatic,
            isMutating: header.isMutating,
            isAsync: isAsync,
            isThrows: isThrows,
            genericParameters: generics,
            parameters: parameters,
            returnType: returnType,
            attributes: header.attributes,
            statements: statements,
            viewBody: viewBody,
            docComment: header.docComment,
            span: SourceSpan(start: startPos, end: endPos)
        )
    }

    mutating func parseParameterList() -> [SwiftParameter] {
        guard consumeIfPunctuation(.leftParen) else { return [] }
        var params: [SwiftParameter] = []

        while !isAtEnd && !current.isPunctuation(.rightParen) {
            let loopStart = cursor
            var paramAttrs: [SwiftAttributeNode] = []
            while case .attribute(let attrKind) = current.kind {
                let raw = current.text.hasPrefix("@") ? String(current.text.dropFirst()) : current.text
                advance()
                var args: [String] = []
                if current.isPunctuation(.leftParen) {
                    args = parseArgumentList().map(\.renderedSource)
                }
                paramAttrs.append(SwiftAttributeNode(kind: attrKind, rawName: raw, arguments: args))
            }

            // Support unnamed associated value parameters like `case loaded([Item])`
            var externalLabel: String?
            var internalName = "_"
            var typeName = "Any"
            var isInout = false

            if let firstIdent = current.memberIdentifierName {
                if peek().isPunctuation(.colon) {
                    internalName = firstIdent
                    advance() // name
                    advance() // `:`
                    if consumeIfKeyword(.inout) { isInout = true }
                    // Consume any parameter-type attributes like `@escaping` or `@Sendable`
                    while case .attribute = current.kind {
                        advance()
                    }
                    typeName = parseParameterTypeString()
                } else if let secondIdent = peek().memberIdentifierName, peek(offset: 2).isPunctuation(.colon) {
                    externalLabel = firstIdent
                    internalName = secondIdent
                    advance() // external
                    advance() // internal
                    advance() // `:`
                    if consumeIfKeyword(.inout) { isInout = true }
                    while case .attribute = current.kind {
                        advance()
                    }
                    typeName = parseParameterTypeString()
                } else {
                    // Unnamed enum case payload type
                    typeName = parseParameterTypeString()
                }
            } else {
                typeName = parseParameterTypeString()
            }

            var isVariadic = false
            if current.isPunctuation(.ellipsis) || current.isOperator("...") {
                isVariadic = true
                advance()
            }

            var defaultValue: SwiftExpr?
            if consumeIfPunctuation(.equal) {
                defaultValue = parseExpression(allowTrailingClosure: false)
            }

            params.append(
                SwiftParameter(
                    externalLabel: externalLabel,
                    internalName: internalName,
                    typeName: typeName,
                    isInout: isInout,
                    isVariadic: isVariadic,
                    defaultValue: defaultValue,
                    attributes: paramAttrs
                )
            )

            if !consumeIfPunctuation(.comma) { break }
            if cursor == loopStart { advance() }
        }

        _ = consumeIfPunctuation(.rightParen)
        return params
    }

    mutating func parseParameterTypeString() -> String {
        var parts: [String] = []
        var parenDepth = 0
        var bracketDepth = 0
        var angleDepth = 0

        while !isAtEnd {
            if parenDepth == 0 && bracketDepth == 0 && angleDepth == 0 {
                if current.isPunctuation(.comma)
                    || current.isPunctuation(.rightParen)
                    || current.isPunctuation(.equal)
                    || current.isPunctuation(.ellipsis) {
                    break
                }
            }
            if current.isPunctuation(.leftParen) { parenDepth += 1 }
            else if current.isPunctuation(.rightParen) { parenDepth = max(0, parenDepth - 1) }
            else if current.isPunctuation(.leftBracket) { bracketDepth += 1 }
            else if current.isPunctuation(.rightBracket) { bracketDepth = max(0, bracketDepth - 1) }
            else if current.isOperator("<") { angleDepth += 1 }
            else if current.isOperator(">") && angleDepth > 0 { angleDepth -= 1 }

            parts.append(current.text)
            advance()
        }
        return normalizeTypeSpacing(parts)
    }

    // MARK: `@ViewBuilder` View Hierarchy Recursive-Descent Parser

    mutating func parseViewBuilderBlock() -> [SwiftViewNode] {
        guard expectPunctuation(.leftBrace, context: "opening @ViewBuilder block") else {
            return []
        }

        // Optional closure signature inside `@ViewBuilder` closure (e.g. `ForEach(items) { item in ... }`)
        skipOptionalClosureParameterHeader()

        // Unwrap explicit `get { ... }` inside computed `var body: some View { get { ... } }`
        if current.isKeyword(.get) && peek().isPunctuation(.leftBrace) {
            advance()
            let inner = parseViewBuilderBlock()
            while !isAtEnd && !current.isPunctuation(.rightBrace) {
                advance()
            }
            _ = consumeIfPunctuation(.rightBrace)
            return inner
        }

        let nodes = parseViewBuilderList()
        _ = consumeIfPunctuation(.rightBrace)
        return nodes
    }

    mutating func parseViewBuilderList() -> [SwiftViewNode] {
        var nodes: [SwiftViewNode] = []

        while !isAtEnd && !current.isPunctuation(.rightBrace) {
            // Stop at `case` or `default` when inside a `@ViewBuilder` `switch` case
            if current.isKeyword(.case) || current.isKeyword(.default) { break }

            let iterStart = cursor
            consumeOptionalSemicolons()
            if current.isPunctuation(.rightBrace) || isAtEnd { break }

            if case .directive(let dirKind) = current.kind, dirKind.isConditionalCompilation {
                handleConditionalDirective(dirKind)
                continue
            }

            if current.isKeyword(.return) { advance() }

            // Local binding inside `@ViewBuilder` (`let columns = [...]`)
            if current.isKeyword(.let) || current.isKeyword(.var) {
                _ = parsePropertyDecl(header: DeclarationHeader(startPos: current.span.start), enclosingIsProtocol: false)
                continue
            }

            if current.isKeyword(.if) {
                nodes.append(parseConditionalViewIf())
            } else if current.isKeyword(.switch) {
                nodes.append(parseConditionalViewSwitch())
            } else if let viewNode = parsePrimaryViewNode() {
                nodes.append(viewNode)
            } else {
                // Skip unrecognized token inside view builder with recovery
                advance()
            }

            if cursor == iterStart && !isAtEnd && !current.isPunctuation(.rightBrace) { advance() }
        }

        return nodes
    }

    mutating func parseConditionalViewIf() -> SwiftViewNode {
        let startPos = current.span.start
        advance() // `if`
        let condText = collectConditionUntilLeftBrace()
        let thenChildren = current.isPunctuation(.leftBrace) ? parseViewBuilderBlock() : []
        var elseChildren: [SwiftViewNode] = []

        if consumeIfKeyword(.else) {
            if current.isKeyword(.if) {
                elseChildren = [parseConditionalViewIf()]
            } else if current.isPunctuation(.leftBrace) {
                elseChildren = parseViewBuilderBlock()
            }
        }

        var node = SwiftViewNode(
            componentName: "if",
            containerKind: .conditionalIf,
            children: thenChildren,
            elseChildren: elseChildren,
            conditionDescription: condText,
            span: SourceSpan(start: startPos, end: previousTokenEnd(fallback: startPos))
        )
        node.modifiers = parseChainedViewModifiers()
        node.span = SourceSpan(start: startPos, end: previousTokenEnd(fallback: startPos))
        return node
    }

    mutating func parseConditionalViewSwitch() -> SwiftViewNode {
        let startPos = current.span.start
        advance() // `switch`
        let subjectText = collectConditionUntilLeftBrace()
        var switchCases: [SwiftSwitchCase] = []

        if consumeIfPunctuation(.leftBrace) {
            while !isAtEnd && !current.isPunctuation(.rightBrace) {
                let loopStart = cursor
                if consumeIfKeyword(.case) {
                    let patternText = collectSwitchCasePatternUntilColon()
                    let children = parseViewBuilderList()
                    switchCases.append(
                        SwiftSwitchCase(
                            patterns: patternText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                            isDefault: false,
                            viewChildren: children
                        )
                    )
                } else if consumeIfKeyword(.default) {
                    _ = consumeIfPunctuation(.colon)
                    let children = parseViewBuilderList()
                    switchCases.append(SwiftSwitchCase(patterns: ["default"], isDefault: true, viewChildren: children))
                } else { advance() }
                if cursor == loopStart { advance() }
            }
            _ = consumeIfPunctuation(.rightBrace)
        }

        var node = SwiftViewNode(
            componentName: "switch",
            containerKind: .conditionalSwitch,
            switchCases: switchCases,
            conditionDescription: subjectText,
            span: SourceSpan(start: startPos, end: previousTokenEnd(fallback: startPos))
        )
        node.modifiers = parseChainedViewModifiers()
        return node
    }

    mutating func parsePrimaryViewNode() -> SwiftViewNode? {
        let startPos = current.span.start

        // Handle standalone Color/ShapeStyle or View component identifier (e.g. `Text`, `VStack`, `Color.clear`)
        guard let headIdent = current.memberIdentifierName else { return nil }
        advance()

        var componentName = headIdent
        // Support qualified names like `Color.red` or `SwiftUI.Text` when NOT a modifier chain
        while current.isPunctuation(.period) && !current.hasLeadingNewline {
            guard let nextMember = peek().memberIdentifierName else { break }
            // If `headIdent` was already initialized with `(`, `.` starts modifiers; here we have not seen `(` or `{` yet!
            // If `headIdent` is a namespace/type like `Color`, `Color.red` is the component before modifiers.
            if componentName == "Color" || componentName == "LinearGradient" || componentName == "RoundedRectangle" {
                advance() // `.`
                advance() // member
                componentName += ".\(nextMember)"
            } else { break }
        }

        // Optional generic specialization e.g. `ColorPicker<Text>(...)`
        _ = parseOptionalGenericParameterList()

        var args: [SwiftModifierArg] = []
        if current.isPunctuation(.leftParen) && !current.hasLeadingNewline {
            args = parseArgumentList()
        }

        var children: [SwiftViewNode] = []
        var actionStatements: [SwiftStatement] = []

        // Extract `action:` argument closure if passed inside parentheses `Button(action: { ... })`
        if (componentName == "Button" || componentName == "EDKButton"),
           let actionArg = args.first(where: { $0.label == "action" }),
           case .closure(let actionClosure) = actionArg.value {
            actionStatements.append(contentsOf: actionClosure.statements)
        }

        // Trailing closure(s)
        if current.isPunctuation(.leftBrace) {
            let isButtonWithTitleArg = (componentName == "Button" || componentName == "EDKButton")
                && !args.isEmpty
                && args.first?.label != "action"

            if isButtonWithTitleArg {
                actionStatements = parseStatementBlock()
            } else if (componentName == "Button" || componentName == "EDKButton") && args.isEmpty {
                // Check if followed by `label: { ... }`
                let firstBlockTokens = cursor
                let tentativeStatements = parseStatementBlock()
                if current.memberIdentifierName == "label" && peek().isPunctuation(.colon) && peek(offset: 2).isPunctuation(.leftBrace) {
                    actionStatements = tentativeStatements
                    advance() // `label`
                    advance() // `:`
                    children = parseViewBuilderBlock()
                } else {
                    // Re-parse as view builder if it was a single-closure view container
                    cursor = firstBlockTokens
                    actionStatements = parseStatementBlock()
                }
            } else {
                children = parseViewBuilderBlock()

                // Support multi-trailing closures like `NavigationSplitView { ... } content: { ... } detail: { ... }`
                while let trailingLabel = current.memberIdentifierName,
                      peek().isPunctuation(.colon),
                      peek(offset: 2).isPunctuation(.leftBrace) {
                    advance() // label
                    advance() // `:`
                    if trailingLabel == "action" {
                        actionStatements.append(contentsOf: parseStatementBlock())
                    } else {
                        children.append(contentsOf: parseViewBuilderBlock())
                    }
                }
            }
        }

        let modifiers = parseChainedViewModifiers()
        let endPos = previousTokenEnd(fallback: startPos)
        let containerKind = SwiftViewContainerKind.classify(componentName: componentName, hasViewChildren: !children.isEmpty)

        return SwiftViewNode(
            componentName: componentName,
            containerKind: containerKind,
            arguments: args,
            children: children,
            actionStatements: actionStatements,
            modifiers: modifiers,
            span: SourceSpan(start: startPos, end: endPos)
        )
    }

    mutating func parseChainedViewModifiers() -> [SwiftModifierCall] {
        var modifiers: [SwiftModifierCall] = []

        while current.isPunctuation(.period),
              let modName = peek().memberIdentifierName {
            // Ensure this is a modifier call `.foo(...)` or `.foo { ... }`
            let afterName = peek(offset: 2)
            let isCallOrClosure = afterName.isPunctuation(.leftParen) || afterName.isPunctuation(.leftBrace)
            guard isCallOrClosure else { break }

            let modStart = current.span.start
            advance() // `.`
            advance() // modifier name

            var args: [SwiftModifierArg] = []
            if current.isPunctuation(.leftParen) {
                args = parseArgumentList()
            }

            var trailingClosure: SwiftClosureExpr?
            if current.isPunctuation(.leftBrace) {
                trailingClosure = parseClosureExpr(preferViewBuilder: isViewContentModifier(modName))
            }

            let modEnd = previousTokenEnd(fallback: modStart)
            modifiers.append(
                SwiftModifierCall(name: modName, arguments: args, trailingClosure: trailingClosure, span: SourceSpan(start: modStart, end: modEnd))
            )
        }

        return modifiers
    }

    func isViewContentModifier(_ modifierName: String) -> Bool {
        switch modifierName {
        case "overlay", "background", "sheet", "popover", "fullScreenCover",
             "toolbar", "safeAreaInset", "contextMenu", "mask":
            return true
        default:
            return false
        }
    }

    // MARK: Argument Lists & Closures

    mutating func parseArgumentList() -> [SwiftModifierArg] {
        guard consumeIfPunctuation(.leftParen) else { return [] }
        var args: [SwiftModifierArg] = []

        while !isAtEnd && !current.isPunctuation(.rightParen) {
            let loopStart = cursor
            var label: String?
            if let ident = current.memberIdentifierName, peek().isPunctuation(.colon) {
                label = ident
                advance() // label
                advance() // `:`
            }
            let expr = parseExpression(allowTrailingClosure: true)
            args.append(SwiftModifierArg(label: label, value: expr))

            if !consumeIfPunctuation(.comma) { break }
            if cursor == loopStart { advance() }
        }

        _ = consumeIfPunctuation(.rightParen)
        return args
    }

    mutating func parseClosureExpr(preferViewBuilder: Bool) -> SwiftClosureExpr {
        guard current.isPunctuation(.leftBrace) else { return SwiftClosureExpr() }
        let bodyStartCursor = cursor + 1
        advance() // `{`

        let (captures, params) = parseOptionalClosureHeader()

        var viewChildren: [SwiftViewNode] = []
        var statements: [SwiftStatement] = []

        if preferViewBuilder {
            viewChildren = parseViewBuilderList()
        } else {
            statements = parseStatementList()
        }

        let bodyEndCursor = cursor
        let rawBody = renderTokenSlice(from: bodyStartCursor, to: bodyEndCursor)
        _ = consumeIfPunctuation(.rightBrace)

        return SwiftClosureExpr(captureList: captures, parameters: params, statements: statements, viewChildren: viewChildren, rawBody: rawBody)
    }

    mutating func skipOptionalClosureParameterHeader() {
        _ = parseOptionalClosureHeader()
    }

    mutating func parseOptionalClosureHeader() -> (captures: [String], params: [String]) {
        let saved = cursor
        var captures: [String] = []
        var params: [String] = []

        // Capture list `[weak self, count]` followed eventually by `in`
        if current.isPunctuation(.leftBracket) {
            advance()
            var currentCap = ""
            while !isAtEnd && !current.isPunctuation(.rightBracket) {
                if current.isPunctuation(.comma) {
                    let trimmed = currentCap.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { captures.append(trimmed) }
                    currentCap = ""
                } else {
                    currentCap += (currentCap.isEmpty ? "" : " ") + current.text
                }
                advance()
            }
            let trimmed = currentCap.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { captures.append(trimmed) }
            _ = consumeIfPunctuation(.rightBracket)
        }

        // Look ahead on the same header for `in` before `{` or `;` or newline-after-statement
        var scanIdx = cursor
        var foundInAt: Int?
        var parenDepth = 0
        while scanIdx < tokens.count {
            let tok = tokens[scanIdx]
            if tok.isEOF || tok.isPunctuation(.rightBrace) || tok.isPunctuation(.leftBrace) { break }
            if tok.isPunctuation(.leftParen) { parenDepth += 1 }
            else if tok.isPunctuation(.rightParen) { parenDepth = max(0, parenDepth - 1) }
            else if parenDepth == 0 && tok.isKeyword(.in) {
                foundInAt = scanIdx
                break
            }
            if scanIdx - cursor > 24 { break }
            scanIdx += 1
        }

        guard let inIndex = foundInAt else {
            cursor = saved
            return ([], [])
        }

        while cursor < inIndex {
            if let ident = current.memberIdentifierName, !current.isPunctuation(.colon) {
                params.append(ident)
            }
            advance()
        }
        _ = consumeIfKeyword(.in)
        return (captures, params)
    }

    // MARK: Precedence-Climbing Expression Parser

    mutating func parseExpression(allowTrailingClosure: Bool = true) -> SwiftExpr {
        parseTernaryExpression(allowTrailingClosure: allowTrailingClosure)
    }

    mutating func parseTernaryExpression(allowTrailingClosure: Bool) -> SwiftExpr {
        let condition = parseBinaryExpression(minPrecedence: 1, allowTrailingClosure: allowTrailingClosure)
        if current.isPunctuation(.questionMark) && !current.hasLeadingNewline {
            advance() // `?`
            let thenExpr = parseExpression(allowTrailingClosure: allowTrailingClosure)
            _ = consumeIfPunctuation(.colon)
            let elseExpr = parseExpression(allowTrailingClosure: allowTrailingClosure)
            return .ternary(condition: condition, thenExpr: thenExpr, elseExpr: elseExpr)
        }
        return condition
    }

    mutating func parseBinaryExpression(minPrecedence: Int, allowTrailingClosure: Bool) -> SwiftExpr {
        var left = parsePrefixExpression(allowTrailingClosure: allowTrailingClosure)

        while !isAtEnd {
            // Handle `as`, `as?`, `as!`, `is` type cast operators (precedence 3)
            if minPrecedence <= 3 && (current.isKeyword(.as) || current.isKeyword(.is)) {
                var castOp = current.text
                advance()
                if castOp == "as" && (current.isOperator("?") || current.isOperator("!") || current.isPunctuation(.questionMark)) {
                    castOp += current.text
                    advance()
                }
                let targetType = parseParameterTypeString()
                left = .typeCast(expr: left, op: castOp, targetType: targetType)
                continue
            }

            guard let (opSymbol, prec) = currentBinaryOperator(), prec >= minPrecedence else { break }
            advance()
            let right = parseBinaryExpression(minPrecedence: prec + 1, allowTrailingClosure: allowTrailingClosure)
            left = .binaryOp(lhs: left, op: opSymbol, rhs: right)
        }

        return left
    }

    func currentBinaryOperator() -> (String, Int)? {
        if current.isPunctuation(.ellipsis) { return ("...", 4) }
        if current.isPunctuation(.halfOpenRange) { return ("..<", 4) }

        guard case .operatorSymbol(let op, let fixity) = current.kind, fixity == .infix else { return nil }
        // Exclude assignment operators from pure expression binary climbing so statements can handle `=` / `+=`
        if op == "=" || op == "+=" || op == "-=" || op == "*=" || op == "/=" {
            return nil
        }
        switch op {
        case "||": return (op, 1)
        case "&&": return (op, 2)
        case "==", "!=", "<", "<=", ">", ">=", "===", "!==": return (op, 3)
        case "??": return (op, 4)
        case "...", "..<": return (op, 4)
        case "+", "-", "|", "^": return (op, 5)
        case "*", "/", "%", "&", "<<", ">>": return (op, 6)
        default: return (op, 5)
        }
    }

    mutating func parsePrefixExpression(allowTrailingClosure: Bool) -> SwiftExpr {
        if consumeIfKeyword(.try) {
            var mode: SwiftTryMode = .regular
            if current.isOperator("?") || current.isPunctuation(.questionMark) {
                mode = .optional
                advance()
            } else if current.isOperator("!") || current.isPunctuation(.exclamationMark) {
                mode = .forced
                advance()
            }
            let inner = parsePrefixExpression(allowTrailingClosure: allowTrailingClosure)
            return .tryExpr(mode: mode, expr: inner)
        }

        if consumeIfKeyword(.await) {
            let inner = parsePrefixExpression(allowTrailingClosure: allowTrailingClosure)
            return .awaitExpr(inner)
        }

        if current.isPunctuation(.ampersand) {
            advance()
            let inner = parsePrefixExpression(allowTrailingClosure: allowTrailingClosure)
            return .prefixOp(op: "&", operand: inner)
        }

        if case .operatorSymbol(let op, let fixity) = current.kind,
           fixity == .prefix || op == "-" || op == "!" || op == "~" {
            advance()
            let operand = parsePrefixExpression(allowTrailingClosure: allowTrailingClosure)
            return .prefixOp(op: op, operand: operand)
        }

        return parsePostfixExpression(allowTrailingClosure: allowTrailingClosure)
    }

    mutating func parsePostfixExpression(allowTrailingClosure: Bool) -> SwiftExpr {
        var expr = parsePrimaryExpression()

        while !isAtEnd {
            if current.isPunctuation(.period) {
                if let member = peek().memberIdentifierName {
                    advance() // `.`
                    advance() // member
                    expr = .memberAccess(base: expr, member: member)
                    continue
                }
                // Tuple numeric index `.0`
                if case .integerLiteral(let raw, _, _) = peek().kind {
                    advance()
                    advance()
                    expr = .memberAccess(base: expr, member: raw)
                    continue
                }
                break
            }

            if current.isPunctuation(.leftParen) && !current.hasLeadingNewline {
                let modArgs = parseArgumentList()
                let callArgs = modArgs.map { SwiftCallArgument(label: $0.label, value: $0.value) }
                var trailing: SwiftClosureExpr?
                if allowTrailingClosure && current.isPunctuation(.leftBrace) && !current.hasLeadingNewline {
                    trailing = parseClosureExpr(preferViewBuilder: false)
                }
                expr = .call(callee: expr, arguments: callArgs, trailingClosure: trailing)
                continue
            }

            if allowTrailingClosure && current.isPunctuation(.leftBrace) && !current.hasLeadingNewline {
                // Do not greedily consume `{` if `expr` is a condition of `if`/`while`/`guard`/`switch`/`for`
                let trailing = parseClosureExpr(preferViewBuilder: false)
                expr = .call(callee: expr, arguments: [], trailingClosure: trailing)
                continue
            }

            if current.isPunctuation(.leftBracket) && !current.hasLeadingNewline {
                advance() // `[`
                let indexExpr = parseExpression(allowTrailingClosure: false)
                _ = consumeIfPunctuation(.rightBracket)
                expr = .call(
                    callee: .memberAccess(base: expr, member: "subscript"),
                    arguments: [SwiftCallArgument(value: indexExpr)],
                    trailingClosure: nil
                )
                continue
            }

            if case .operatorSymbol(let op, .postfix) = current.kind {
                advance()
                expr = .postfixOp(operand: expr, op: op)
                continue
            }

            if current.isPunctuation(.questionMark) && !current.hasLeadingNewline {
                // Check if postfix optional chain `foo?.bar` vs ternary `cond ? a : b`
                if peek().isPunctuation(.period) || peek().isPunctuation(.leftBracket) || peek().isPunctuation(.leftParen) {
                    advance()
                    expr = .postfixOp(operand: expr, op: "?")
                    continue
                }
            }

            break
        }

        return expr
    }

    mutating func parsePrimaryExpression() -> SwiftExpr {
        switch current.kind {
        case .integerLiteral(let raw, let val, _):
            advance()
            return .literal(.integer(val ?? 0, raw: raw))

        case .floatingLiteral(let raw, let val, _):
            advance()
            return .literal(.float(val ?? 0.0, raw: raw))

        case .stringLiteral(_, let value, _, _):
            advance()
            return .literal(.string(value))

        case .interpolatedStringSegment(let raw, let expressions, _, _):
            advance()
            return .literal(.interpolatedString(raw: raw, expressions: expressions))

        case .booleanLiteral(let flag):
            advance()
            return .literal(.boolean(flag))

        case .nilLiteral:
            advance()
            return .literal(.nil)

        case .dollarIdentifier(let name):
            advance()
            return .dollarBinding(name)

        case .identifier(let name, _):
            advance()
            return .identifier(name)

        case .keyword(let kw) where kw == .self || kw == .Self || kw == .super || kw.canBeUsedAsContextualIdentifier:
            advance()
            return .identifier(kw.rawValue)

        case .punctuation(.period):
            advance()
            let member = current.memberIdentifierName ?? "unknown"
            if current.memberIdentifierName != nil { advance() }
            return .implicitMember(member)

        case .punctuation(.backslash):
            // KeyPath `\Root.path.leaf` or `\.dismiss`
            advance()
            var root: String?
            if let ident = current.memberIdentifierName {
                root = ident
                advance()
            }
            var path: [String] = []
            while consumeIfPunctuation(.period) {
                if let segment = current.memberIdentifierName {
                    path.append(segment)
                    advance()
                } else { break }
            }
            return .keyPath(root: root, path: path)

        case .punctuation(.leftBracket):
            return parseArrayOrDictionaryLiteral()

        case .punctuation(.leftParen):
            return parseParenthesizedOrTupleExpr()

        case .punctuation(.leftBrace):
            return .closure(parseClosureExpr(preferViewBuilder: false))

        case .directive(let dir):
            let name = current.text
            advance()
            if current.isPunctuation(.leftParen) {
                let args = parseArgumentList().map { SwiftCallArgument(label: $0.label, value: $0.value) }
                return .call(callee: .identifier(name), arguments: args, trailingClosure: nil)
            }
            return .identifier(dir.rawValue)

        default:
            let rawText = current.text
            advance()
            return .raw(rawText)
        }
    }

    mutating func parseArrayOrDictionaryLiteral() -> SwiftExpr {
        advance() // `[`
        if consumeIfPunctuation(.colon) {
            _ = consumeIfPunctuation(.rightBracket)
            return .dictionary([])
        }
        if consumeIfPunctuation(.rightBracket) { return .array([]) }

        let first = parseExpression(allowTrailingClosure: false)
        if consumeIfPunctuation(.colon) {
            // Dictionary `[first: firstVal, ...]`
            let firstVal = parseExpression(allowTrailingClosure: false)
            var entries = [SwiftDictionaryEntry(key: first, value: firstVal)]
            while consumeIfPunctuation(.comma) {
                if current.isPunctuation(.rightBracket) { break }
                let k = parseExpression(allowTrailingClosure: false)
                _ = consumeIfPunctuation(.colon)
                let v = parseExpression(allowTrailingClosure: false)
                entries.append(SwiftDictionaryEntry(key: k, value: v))
            }
            _ = consumeIfPunctuation(.rightBracket)
            return .dictionary(entries)
        } else {
            var items = [first]
            while consumeIfPunctuation(.comma) {
                if current.isPunctuation(.rightBracket) { break }
                items.append(parseExpression(allowTrailingClosure: false))
            }
            _ = consumeIfPunctuation(.rightBracket)
            return .array(items)
        }
    }

    mutating func parseParenthesizedOrTupleExpr() -> SwiftExpr {
        advance() // `(`
        if consumeIfPunctuation(.rightParen) { return .tuple([]) }

        var elements: [SwiftTupleElement] = []
        while !isAtEnd && !current.isPunctuation(.rightParen) {
            let loopStart = cursor
            var label: String?
            if let ident = current.memberIdentifierName, peek().isPunctuation(.colon) {
                label = ident
                advance()
                advance()
            }
            let val = parseExpression(allowTrailingClosure: true)
            elements.append(SwiftTupleElement(label: label, value: val))
            if !consumeIfPunctuation(.comma) { break }
            if cursor == loopStart { advance() }
        }
        _ = consumeIfPunctuation(.rightParen)

        if elements.count == 1 && elements[0].label == nil { return elements[0].value }
        return .tuple(elements)
    }

    // MARK: Imperative Statement Block Parser

    mutating func parseAccessorOrStatementBlock() -> [SwiftStatement] {
        guard expectPunctuation(.leftBrace, context: "opening computed property block") else { return [] }
        var stmts: [SwiftStatement] = []
        if current.isKeyword(.get) && peek().isPunctuation(.leftBrace) {
            advance()
            stmts.append(contentsOf: parseStatementBlock())
            while !isAtEnd && !current.isPunctuation(.rightBrace) {
                advance()
            }
        } else {
            stmts = parseStatementList()
        }
        _ = consumeIfPunctuation(.rightBrace)
        return stmts
    }

    mutating func parseStatementBlock() -> [SwiftStatement] {
        guard expectPunctuation(.leftBrace, context: "opening statement block") else { return [] }
        skipOptionalClosureParameterHeader()
        let stmts = parseStatementList()
        _ = consumeIfPunctuation(.rightBrace)
        return stmts
    }

    mutating func parseStatementList() -> [SwiftStatement] {
        var stmts: [SwiftStatement] = []

        while !isAtEnd && !current.isPunctuation(.rightBrace) {
            if current.isKeyword(.case) || current.isKeyword(.default) { break }
            let iterStart = cursor
            consumeOptionalSemicolons()
            if current.isPunctuation(.rightBrace) || isAtEnd { break }

            if case .directive(let dirKind) = current.kind, dirKind.isConditionalCompilation {
                handleConditionalDirective(dirKind)
                continue
            }

            if current.isKeyword(.let) || current.isKeyword(.var) {
                let decl = parsePropertyDecl(header: DeclarationHeader(startPos: current.span.start), enclosingIsProtocol: false)
                stmts.append(.variableDecl(decl))
            } else if consumeIfKeyword(.return) {
                if current.isPunctuation(.rightBrace) || current.isPunctuation(.semicolon) || current.hasLeadingNewline {
                    stmts.append(.returnStmt(nil))
                } else {
                    stmts.append(.returnStmt(parseExpression(allowTrailingClosure: true)))
                }
            } else if consumeIfKeyword(.throw) {
                stmts.append(.throwStmt(parseExpression(allowTrailingClosure: false)))
            } else if consumeIfKeyword(.break) {
                stmts.append(.breakStmt)
            } else if consumeIfKeyword(.continue) {
                stmts.append(.continueStmt)
            } else if consumeIfKeyword(.defer) {
                stmts.append(.deferStmt(parseStatementBlock()))
            } else if consumeIfKeyword(.if) {
                stmts.append(parseIfStatement())
            } else if consumeIfKeyword(.guard) {
                let cond = collectConditionUntilKeyword(.else)
                _ = consumeIfKeyword(.else)
                let elseBody = parseStatementBlock()
                stmts.append(.guardStmt(condition: cond, elseBody: elseBody))
            } else if consumeIfKeyword(.switch) {
                stmts.append(parseSwitchStatement())
            } else if consumeIfKeyword(.for) {
                let pattern = collectConditionUntilKeyword(.in)
                _ = consumeIfKeyword(.in)
                let seq = parseExpression(allowTrailingClosure: false)
                if current.isKeyword(.where) {
                    _ = collectConditionUntilLeftBrace()
                }
                let body = parseStatementBlock()
                stmts.append(.forLoop(pattern: pattern, sequence: seq, body: body))
            } else if consumeIfKeyword(.while) {
                let cond = parseExpression(allowTrailingClosure: false)
                let body = parseStatementBlock()
                stmts.append(.whileLoop(condition: cond, body: body))
            } else if consumeIfKeyword(.do) {
                stmts.append(parseDoCatchStatement())
            } else {
                let lhs = parseExpression(allowTrailingClosure: true)
                if let assignOp = currentAssignmentOperator() {
                    advance()
                    let rhs = parseExpression(allowTrailingClosure: true)
                    stmts.append(.assignment(target: lhs, op: assignOp, value: rhs))
                } else {
                    stmts.append(.expression(lhs))
                }
            }

            if cursor == iterStart && !isAtEnd && !current.isPunctuation(.rightBrace) { advance() }
        }

        return stmts
    }

    func currentAssignmentOperator() -> String? {
        if current.isPunctuation(.equal) { return "=" }
        if case .operatorSymbol(let op, _) = current.kind,
           op == "+=" || op == "-=" || op == "*=" || op == "/=" {
            return op
        }
        return nil
    }

    mutating func parseIfStatement() -> SwiftStatement {
        let cond = collectConditionUntilLeftBrace()
        let thenBody = current.isPunctuation(.leftBrace) ? parseStatementBlock() : []
        var elseBody: [SwiftStatement] = []
        if consumeIfKeyword(.else) {
            if consumeIfKeyword(.if) {
                elseBody = [parseIfStatement()]
            } else if current.isPunctuation(.leftBrace) {
                elseBody = parseStatementBlock()
            }
        }
        return .ifStmt(condition: cond, thenBody: thenBody, elseBody: elseBody)
    }

    mutating func parseSwitchStatement() -> SwiftStatement {
        let subject = parseExpression(allowTrailingClosure: false)
        var cases: [SwiftSwitchCase] = []
        if consumeIfPunctuation(.leftBrace) {
            while !isAtEnd && !current.isPunctuation(.rightBrace) {
                let loopStart = cursor
                if consumeIfKeyword(.case) {
                    let patternText = collectSwitchCasePatternUntilColon()
                    let stmts = parseStatementList()
                    cases.append(
                        SwiftSwitchCase(
                            patterns: patternText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                            isDefault: false,
                            statements: stmts
                        )
                    )
                } else if consumeIfKeyword(.default) {
                    _ = consumeIfPunctuation(.colon)
                    let stmts = parseStatementList()
                    cases.append(SwiftSwitchCase(patterns: ["default"], isDefault: true, statements: stmts))
                } else { advance() }
                if cursor == loopStart { advance() }
            }
            _ = consumeIfPunctuation(.rightBrace)
        }
        return .switchStmt(subject: subject, cases: cases)
    }

    mutating func parseDoCatchStatement() -> SwiftStatement {
        let doBody = parseStatementBlock()
        var catches: [SwiftCatchClause] = []
        while consumeIfKeyword(.catch) {
            let catchStart = previousTokenEnd(fallback: current.span.start)
            var pattern: String?
            if !current.isPunctuation(.leftBrace) {
                pattern = collectConditionUntilLeftBrace()
            }
            let bodySpanEnd = current.span.end
            let catchStmts = current.isPunctuation(.leftBrace) ? parseStatementBlock() : []
            catches.append(
                SwiftCatchClause(
                    pattern: pattern,
                    statements: catchStmts,
                    span: SourceSpan(start: catchStart, end: previousTokenEnd(fallback: bodySpanEnd))
                )
            )
        }
        return .doCatch(doBody: doBody, catches: catches)
    }

    // MARK: Synchronization & Helper Collectors

    mutating func collectConditionUntilLeftBrace() -> String {
        var parts: [String] = []
        var parenDepth = 0
        while !isAtEnd {
            if parenDepth == 0 && current.isPunctuation(.leftBrace) { break }
            if current.isPunctuation(.leftParen) { parenDepth += 1 }
            else if current.isPunctuation(.rightParen) { parenDepth = max(0, parenDepth - 1) }
            parts.append(current.text)
            advance()
        }
        return parts.joined(separator: " ")
    }

    mutating func collectConditionUntilKeyword(_ stopKeyword: SwiftKeyword) -> String {
        var parts: [String] = []
        while !isAtEnd && !current.isKeyword(stopKeyword) && !current.isPunctuation(.leftBrace) {
            parts.append(current.text)
            advance()
        }
        return parts.joined(separator: " ")
    }

    mutating func collectSwitchCasePatternUntilColon() -> String {
        var parts: [String] = []
        while !isAtEnd && !current.isPunctuation(.colon) && !current.isPunctuation(.rightBrace) {
            parts.append(current.text)
            advance()
        }
        _ = consumeIfPunctuation(.colon)
        return parts.joined(separator: " ")
    }

    mutating func collectBalancedParenthesesText() -> String {
        guard consumeIfPunctuation(.leftParen) else { return "" }
        let startIdx = cursor
        var depth = 1
        while !isAtEnd && depth > 0 {
            if current.isPunctuation(.leftParen) { depth += 1 }
            else if current.isPunctuation(.rightParen) {
                depth -= 1
                if depth == 0 {
                    let text = renderTokenSlice(from: startIdx, to: cursor)
                    advance()
                    return text
                }
            }
            advance()
        }
        return renderTokenSlice(from: startIdx, to: cursor)
    }

    mutating func collectBalancedBracesText() -> String {
        guard consumeIfPunctuation(.leftBrace) else { return "" }
        let startIdx = cursor
        var depth = 1
        while !isAtEnd && depth > 0 {
            if current.isPunctuation(.leftBrace) { depth += 1 }
            else if current.isPunctuation(.rightBrace) {
                depth -= 1
                if depth == 0 {
                    let text = renderTokenSlice(from: startIdx, to: cursor)
                    advance()
                    return text
                }
            }
            advance()
        }
        return renderTokenSlice(from: startIdx, to: cursor)
    }

    func renderTokenSlice(from startIdx: Int, to endIdx: Int) -> String {
        guard startIdx >= 0, endIdx <= tokens.count, startIdx < endIdx else { return "" }
        var out = ""
        for i in startIdx..<endIdx {
            let tok = tokens[i]
            if i > startIdx {
                if tok.hasLeadingNewline {
                    out += "\n"
                } else if tok.leadingTrivia.contains(where: { $0.kind == .spaces || $0.kind == .tabs }) {
                    out += " "
                }
            }
            out += tok.text
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func skipTypealiasDeclaration() {
        advance()
        while !isAtEnd && !current.hasLeadingNewline && !current.isPunctuation(.semicolon) && !current.isPunctuation(.rightBrace) {
            advance()
        }
    }

    mutating func skipDeinitOrSubscript() {
        advance()
        if current.isPunctuation(.leftParen) {
            _ = collectBalancedParenthesesText()
        }
        if consumeIfPunctuation(.arrow) {
            _ = parseTypeAnnotationString()
        }
        if current.isPunctuation(.leftBrace) {
            _ = collectBalancedBracesText()
        }
    }

    mutating func synchronizeTopLevel() {
        let badTok = current
        diagnostics.append(
            ParseDiagnostic(
                severity: .warning,
                message: "Unexpected top-level token '\(badTok.text)'; synchronizing to next declaration.",
                span: badTok.span,
                expected: "declaration",
                found: badTok.text
            )
        )
        advance()
        while !isAtEnd {
            if case .keyword(let kw) = current.kind, kw.isDeclarationIntroducer || kw.isAccessControl { break }
            if case .attribute = current.kind { break }
            if case .directive = current.kind { break }
            advance()
        }
    }

    mutating func synchronizeInsideTypeBody() {
        let badTok = current
        diagnostics.append(
            ParseDiagnostic(
                severity: .warning,
                message: "Unexpected token '\(badTok.text)' inside type body; recovering.",
                span: badTok.span,
                expected: "member declaration",
                found: badTok.text
            )
        )
        advance()
        while !isAtEnd && !current.isPunctuation(.rightBrace) {
            if case .keyword(let kw) = current.kind, kw.isDeclarationIntroducer || kw.isAccessControl { break }
            if case .attribute = current.kind { break }
            if case .directive = current.kind { break }
            advance()
        }
    }

    func previousTokenEnd(fallback: SourcePosition) -> SourcePosition {
        guard cursor > 0 && cursor - 1 < tokens.count else { return fallback }
        return tokens[cursor - 1].span.end
    }
}
