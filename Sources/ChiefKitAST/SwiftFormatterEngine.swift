import ChiefKitStudioCore
import Foundation

// MARK: - Formatter Configuration & Result

/// Configuration parameters governing `SwiftFormatterEngine` AST pretty-printing and token formatting.
public struct SwiftFormatConfig: Codable, Hashable, Sendable {
    public var indentWidth: Int
    public var useTabs: Bool
    public var maxLineLength: Int
    public var sortImports: Bool
    public var modifierChainWrapThreshold: Int
    public var normalizeTrailingClosures: Bool
    public var maxConsecutiveBlankLines: Int
    public var alignDocComments: Bool
    public var insertFinalNewline: Bool

    public init(
        indentWidth: Int = 4,
        useTabs: Bool = false,
        maxLineLength: Int = 100,
        sortImports: Bool = true,
        modifierChainWrapThreshold: Int = 2,
        normalizeTrailingClosures: Bool = true,
        maxConsecutiveBlankLines: Int = 1,
        alignDocComments: Bool = true,
        insertFinalNewline: Bool = true
    ) {
        self.indentWidth = max(1, min(8, indentWidth))
        self.useTabs = useTabs
        self.maxLineLength = max(40, maxLineLength)
        self.sortImports = sortImports
        self.modifierChainWrapThreshold = max(1, modifierChainWrapThreshold)
        self.normalizeTrailingClosures = normalizeTrailingClosures
        self.maxConsecutiveBlankLines = max(0, min(4, maxConsecutiveBlankLines))
        self.alignDocComments = alignDocComments
        self.insertFinalNewline = insertFinalNewline
    }

    public static let chiefKitStandard = SwiftFormatConfig()
    public static let compact = SwiftFormatConfig(indentWidth: 2, maxLineLength: 120, modifierChainWrapThreshold: 3, maxConsecutiveBlankLines: 1)
    public static let strictWrappedModifiers = SwiftFormatConfig(
        indentWidth: 4,
        maxLineLength: 96,
        modifierChainWrapThreshold: 1,
        maxConsecutiveBlankLines: 1
    )

    public func indentUnit(level: Int) -> String {
        guard level > 0 else { return "" }
        if useTabs { return String(repeating: "\t", count: level) }
        return String(repeating: " ", count: level * indentWidth)
    }
}

/// Structured result returned by `SwiftFormatterEngine.format(source:config:)`.
public struct SwiftFormatResult: Codable, Equatable, Sendable {
    public let formattedSource: String
    public let wasModified: Bool
    public let changedLineCount: Int
    public let sortedImportCount: Int
    public let wrappedModifierChains: Int

    public init(
        formattedSource: String,
        wasModified: Bool,
        changedLineCount: Int,
        sortedImportCount: Int,
        wrappedModifierChains: Int
    ) {
        self.formattedSource = formattedSource
        self.wasModified = wasModified
        self.changedLineCount = changedLineCount
        self.sortedImportCount = sortedImportCount
        self.wrappedModifierChains = wrappedModifierChains
    }
}

// MARK: - Swift 6 AST Pretty-Printer & Token-Aware Formatter

/// Idempotent AST pretty-printer and token-aware source formatter for Swift 6 and SwiftUI.
public enum SwiftFormatterEngine: Sendable {
    /// Formats raw Swift source code idempotently while preserving comments, directives, and semantics.
    public static func format(
        source: String,
        config: SwiftFormatConfig = .chiefKitStandard
    ) -> SwiftFormatResult {
        var pipeline = SourceFormatPipeline(config: config)
        let formatted = pipeline.formatSource(source)
        let originalLines = source.components(separatedBy: "\n")
        let formattedLines = formatted.components(separatedBy: "\n")
        let maxCount = max(originalLines.count, formattedLines.count)
        var changed = 0
        for idx in 0..<maxCount {
            let lhs = idx < originalLines.count ? originalLines[idx] : nil
            let rhs = idx < formattedLines.count ? formattedLines[idx] : nil
            if lhs != rhs { changed += 1 }
        }
        return SwiftFormatResult(
            formattedSource: formatted,
            wasModified: formatted != source,
            changedLineCount: changed,
            sortedImportCount: pipeline.sortedImportCount,
            wrappedModifierChains: pipeline.wrappedModifierChains
        )
    }

    /// Convenience helper returning the formatted Swift string directly.
    public static func formatCode(
        _ source: String,
        config: SwiftFormatConfig = .chiefKitStandard
    ) -> String {
        format(source: source, config: config).formattedSource
    }

    /// Pretty-prints a typed `SwiftSourceFile` AST into idiomatic, formatted Swift 6 source code.
    public static func format(
        ast: SwiftSourceFile,
        config: SwiftFormatConfig = .chiefKitStandard
    ) -> String {
        let printer = ASTPrettyPrinter(config: config)
        let rawPrinted = printer.printSourceFile(ast)
        return format(source: rawPrinted, config: config).formattedSource
    }

    /// Pretty-prints a single `SwiftViewNode` subtree at a given indentation level.
    public static func formatViewNode(
        _ node: SwiftViewNode,
        indentLevel: Int = 0,
        config: SwiftFormatConfig = .chiefKitStandard
    ) -> String {
        let printer = ASTPrettyPrinter(config: config)
        return printer.printViewNode(node, level: indentLevel)
    }
}

// MARK: - Token-Aware Idempotent Source Formatting Pipeline

private struct SourceFormatPipeline {
    let config: SwiftFormatConfig
    var sortedImportCount: Int = 0
    var wrappedModifierChains: Int = 0

    init(config: SwiftFormatConfig) {
        self.config = config
    }

    mutating func formatSource(_ input: String) -> String {
        let normalizedLineEndings = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let trimmedTrailing = normalizedLineEndings
            .components(separatedBy: "\n")
            .map { line -> String in
                var s = line
                while let last = s.last, last == " " || last == "\t" {
                    s.removeLast()
                }
                return s
            }

        let importSorted = config.sortImports ? sortTopLevelImportRuns(trimmedTrailing) : trimmedTrailing
        let modifierWrapped = wrapLongSingleLineModifierChains(importSorted)
        let indented = reindentLinesPreservingStringsAndComments(modifierWrapped)
        let collapsed = collapseBlankLines(indented)

        var output = collapsed.joined(separator: "\n").trimmingCharacters(in: .newlines)
        if config.insertFinalNewline && !output.isEmpty {
            output.append("\n")
        }
        return output
    }

    mutating func sortTopLevelImportRuns(_ lines: [String]) -> [String] {
        var result: [String] = []
        var idx = 0

        while idx < lines.count {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            if isSimpleImportLine(trimmed) {
                var run: [String] = []
                while idx < lines.count {
                    let candidate = lines[idx].trimmingCharacters(in: .whitespaces)
                    if isSimpleImportLine(candidate) {
                        run.append(candidate)
                        idx += 1
                    } else if candidate.isEmpty && idx + 1 < lines.count && isSimpleImportLine(lines[idx + 1].trimmingCharacters(in: .whitespaces)) {
                        idx += 1
                    } else { break }
                }
                let uniqueSorted = Array(Set(run)).sorted { lhs, rhs in
                    importModuleKey(lhs) < importModuleKey(rhs)
                }
                sortedImportCount += uniqueSorted.count
                result.append(contentsOf: uniqueSorted)
            } else {
                result.append(lines[idx])
                idx += 1
            }
        }
        return result
    }

    func isSimpleImportLine(_ trimmed: String) -> Bool {
        trimmed.hasPrefix("import ")
            || trimmed.hasPrefix("@preconcurrency import ")
            || trimmed.hasPrefix("@_exported import ")
    }

    func importModuleKey(_ line: String) -> String {
        line.components(separatedBy: " ").last ?? line
    }

    mutating func wrapLongSingleLineModifierChains(_ lines: [String]) -> [String] {
        var out: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") || trimmed.hasPrefix("\"") {
                out.append(line)
                continue
            }

            let normalizedLine = config.normalizeTrailingClosures
                ? normalizeInlineEmptyClosure(line)
                : line

            let splitPoints = findChainedModifierDots(in: normalizedLine)
            if splitPoints.count >= config.modifierChainWrapThreshold
                && (normalizedLine.count > config.maxLineLength || config.modifierChainWrapThreshold == 1) {
                wrappedModifierChains += 1
                let chars = Array(normalizedLine)
                var prev = 0
                for (segIdx, dotIdx) in splitPoints.enumerated() {
                    let rawSeg = String(chars[prev..<dotIdx])
                    let slice = rawSeg.trimmingCharacters(in: .whitespaces)
                    if segIdx == 0 {
                        var headSeg = rawSeg
                        while let last = headSeg.last, last == " " || last == "\t" { headSeg.removeLast() }
                        out.append(headSeg)
                    } else {
                        out.append("    " + slice)
                    }
                    prev = dotIdx
                }
                let tail = String(chars[prev..<chars.count]).trimmingCharacters(in: .whitespaces)
                out.append("    " + tail)
            } else {
                out.append(normalizedLine)
            }
        }

        return out
    }

    func normalizeInlineEmptyClosure(_ line: String) -> String {
        guard !line.contains("\""), line.contains(")"), line.contains("{") else { return line }
        let chars = Array(line)
        var out: [Character] = []
        out.reserveCapacity(chars.count + 2)
        var i = 0
        while i < chars.count {
            if chars[i] == ")" {
                var j = i + 1
                while j < chars.count && (chars[j] == " " || chars[j] == "\t") { j += 1 }
                if j < chars.count && chars[j] == "{" {
                    var k = j + 1
                    while k < chars.count && (chars[k] == " " || chars[k] == "\t") { k += 1 }
                    if k < chars.count && chars[k] == "}" {
                        out.append(contentsOf: ") { }")
                        i = k + 1
                        continue
                    }
                }
            }
            out.append(chars[i])
            i += 1
        }
        return String(out)
    }

    /// Finds top-level `.modifier(...)` call boundaries on a single line (paren/brace/bracket depth == 0, outside strings).
    func findChainedModifierDots(in line: String) -> [Int] {
        let chars = Array(line)
        var dots: [Int] = []
        var parenDepth = 0
        var braceDepth = 0
        var bracketDepth = 0
        var inString = false
        var seenPrimaryCallClose = false
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\" {
                    i += 2
                    continue
                }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                break
            }
            if c == "\"" {
                inString = true
                i += 1
                continue
            }
            if c == "(" { parenDepth += 1 }
            else if c == ")" {
                parenDepth = max(0, parenDepth - 1)
                if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 {
                    seenPrimaryCallClose = true
                }
            } else if c == "{" { braceDepth += 1 }
            else if c == "}" {
                braceDepth = max(0, braceDepth - 1)
                if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 {
                    seenPrimaryCallClose = true
                }
            } else if c == "[" { bracketDepth += 1 }
            else if c == "]" { bracketDepth = max(0, bracketDepth - 1) }
            else if c == "." && seenPrimaryCallClose && parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 {
                // Verify `.identifier(` follows
                var j = i + 1
                while j < chars.count && (chars[j].isLetter || chars[j].isNumber || chars[j] == "_") {
                    j += 1
                }
                if j > i + 1 && j < chars.count && (chars[j] == "(" || chars[j] == " ") {
                    dots.append(i)
                }
            }
            i += 1
        }
        return dots
    }

    func reindentLinesPreservingStringsAndComments(_ lines: [String]) -> [String] {
        var output: [String] = []
        var braceLevel = 0
        var modifierClosureLevels: [Int] = []
        var inMultilineString = false
        var inBlockComment = 0
        var previousEndedWithViewExpr = false

        for rawLine in lines {
            if inMultilineString {
                output.append(rawLine)
                if rawLine.contains("\"\"\"") { inMultilineString = false }
                continue
            }
            if inBlockComment > 0 {
                output.append(rawLine)
                inBlockComment += countSubstrings("/*", in: rawLine) - countSubstrings("*/", in: rawLine)
                inBlockComment = max(0, inBlockComment)
                continue
            }

            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                output.append("")
                previousEndedWithViewExpr = false
                continue
            }

            if trimmed.hasPrefix("#if") || trimmed.hasPrefix("#elseif") || trimmed.hasPrefix("#else") || trimmed.hasPrefix("#endif") {
                output.append(trimmed)
                continue
            }

            let leadingCloseCount = countLeadingCloseDelimiters(trimmed)
            var closedModifierClosure = false
            let nextLevelAfterLeadingClose = max(0, braceLevel - leadingCloseCount)
            while let topModLevel = modifierClosureLevels.last, nextLevelAfterLeadingClose <= topModLevel {
                if nextLevelAfterLeadingClose == topModLevel && leadingCloseCount > 0 {
                    closedModifierClosure = true
                }
                _ = modifierClosureLevels.popLast()
            }

            var effectiveLevel = nextLevelAfterLeadingClose + modifierClosureLevels.count + (closedModifierClosure ? 1 : 0)

            if (trimmed.hasPrefix("case ") || trimmed.hasPrefix("default:") || trimmed == "default :")
                && trimmed.contains(":")
                && !trimmed.contains("{") {
                effectiveLevel = max(0, effectiveLevel - 1)
            }

            let isLeadingModifierLine = trimmed.hasPrefix(".") && !trimmed.hasPrefix("...") && !trimmed.hasPrefix("..<")
            let isIndentedModifier = isLeadingModifierLine && previousEndedWithViewExpr
            let appliedLevel = isIndentedModifier ? effectiveLevel + 1 : effectiveLevel

            let formattedContent: String
            if config.alignDocComments && trimmed.hasPrefix("///") {
                let body = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                formattedContent = body.isEmpty ? "///" : "/// \(body)"
            } else {
                formattedContent = trimmed
            }

            output.append(config.indentUnit(level: appliedLevel) + formattedContent)

            let preDeltaLevel = braceLevel
            let delta = computeDelimiterDelta(in: trimmed, multilineStringOut: &inMultilineString, blockCommentOut: &inBlockComment)
            if isIndentedModifier && delta > 0 {
                modifierClosureLevels.append(preDeltaLevel)
            }
            braceLevel = max(0, braceLevel + delta)

            if isLeadingModifierLine {
                previousEndedWithViewExpr = !trimmed.hasSuffix("{")
            } else if closedModifierClosure {
                previousEndedWithViewExpr = true
            } else {
                previousEndedWithViewExpr = !trimmed.hasPrefix("//")
                    && !trimmed.hasPrefix("@")
                    && !trimmed.hasSuffix("{")
                    && !trimmed.hasSuffix(",")
                    && (trimmed.hasSuffix(")") || trimmed.hasSuffix("}") || trimmed.first?.isUppercase == true)
            }
        }

        return output
    }

    func countLeadingCloseDelimiters(_ trimmed: String) -> Int {
        var count = 0
        for ch in trimmed {
            if ch == "}" || ch == ")" || ch == "]" {
                count += 1
            } else { break }
        }
        return count
    }

    func computeDelimiterDelta(
        in trimmed: String,
        multilineStringOut: inout Bool,
        blockCommentOut: inout Int
    ) -> Int {
        let chars = Array(trimmed)
        var delta = 0
        var i = 0
        var inString = false

        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\" {
                    i += 2
                    continue
                }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                break
            }
            if c == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
                blockCommentOut += 1
                i += 2
                while i + 1 < chars.count {
                    if chars[i] == "*" && chars[i + 1] == "/" {
                        blockCommentOut -= 1
                        i += 2
                        break
                    }
                    i += 1
                }
                continue
            }
            if c == "\"" && i + 2 < chars.count && chars[i + 1] == "\"" && chars[i + 2] == "\"" {
                i += 3
                var closedSameLine = false
                while i + 2 < chars.count {
                    if chars[i] == "\"" && chars[i + 1] == "\"" && chars[i + 2] == "\"" {
                        closedSameLine = true
                        i += 3
                        break
                    }
                    i += 1
                }
                if !closedSameLine {
                    multilineStringOut = true
                    break
                }
                continue
            }
            if c == "\"" {
                inString = true
                i += 1
                continue
            }
            if c == "{" || c == "(" || c == "[" {
                delta += 1
            } else if c == "}" || c == ")" || c == "]" {
                delta -= 1
            }
            i += 1
        }
        return delta
    }

    func countSubstrings(_ needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return haystack.components(separatedBy: needle).count - 1
    }

    func collapseBlankLines(_ lines: [String]) -> [String] {
        var out: [String] = []
        var blankRun = 0
        for line in lines {
            if line.isEmpty {
                // Suppress blank lines immediately after an opening `{`
                if let prev = out.last, prev.trimmingCharacters(in: .whitespaces).hasSuffix("{") {
                    continue
                }
                blankRun += 1
                if blankRun <= config.maxConsecutiveBlankLines {
                    out.append("")
                }
            } else {
                // Suppress blank lines immediately before a closing `}`
                if line.trimmingCharacters(in: .whitespaces) == "}", out.last == "" {
                    out.removeLast()
                }
                blankRun = 0
                out.append(line)
            }
        }
        return out
    }
}

// MARK: - Typed AST Pretty-Printer

private struct ASTPrettyPrinter {
    let config: SwiftFormatConfig

    func printSourceFile(_ file: SwiftSourceFile) -> String {
        var sections: [String] = []

        if !file.imports.isEmpty {
            let importsToPrint = config.sortImports
                ? file.imports.sorted { $0.fullModulePath < $1.fullModulePath }
                : file.imports

            var importLines: [String] = []
            for imp in importsToPrint {
                var prefix = ""
                if imp.isExported { prefix += "@_exported " }
                if imp.isPreconcurrency { prefix += "@preconcurrency " }
                let kindPart = imp.importKind.map { "\($0) " } ?? ""
                let line = "\(prefix)import \(kindPart)\(imp.fullModulePath)"
                if let cond = imp.conditionalDirective {
                    importLines.append("#if \(cond)\n\(line)\n#endif")
                } else {
                    importLines.append(line)
                }
            }
            sections.append(importLines.joined(separator: "\n"))
        }

        if !file.topLevelProperties.isEmpty {
            let props = file.topLevelProperties.map { printPropertyDecl($0, level: 0) }
            sections.append(props.joined(separator: "\n"))
        }

        for typeDecl in file.types {
            sections.append(printTypeDecl(typeDecl, level: 0))
        }

        for fn in file.topLevelFunctions {
            sections.append(printFunctionDecl(fn, level: 0))
        }

        for preview in file.previews {
            sections.append(printPreviewDecl(preview, level: 0))
        }

        return sections.joined(separator: "\n\n")
    }

    func printDocComment(_ doc: String?, level: Int) -> [String] {
        guard let doc, !doc.isEmpty else { return [] }
        let indent = config.indentUnit(level: level)
        return doc.components(separatedBy: "\n").map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "\(indent)///" : "\(indent)/// \(trimmed)"
        }
    }

    func printTypeDecl(_ decl: SwiftTypeDecl, level: Int) -> String {
        let indent = config.indentUnit(level: level)
        var lines: [String] = []

        if let cond = decl.conditionalDirective, level == 0 {
            lines.append("#if \(cond)")
        }

        lines.append(contentsOf: printDocComment(decl.docComment, level: level))

        for attr in decl.attributes {
            lines.append("\(indent)\(attr.renderedSource)")
        }

        var headerParts: [String] = []
        if let access = decl.accessLevel.explicitSourcePrefix {
            headerParts.append(access)
        }
        if decl.isFinal && decl.kind == .class {
            headerParts.append("final")
        }
        headerParts.append(decl.kind.rawValue)

        let genericPart = decl.genericParameters.isEmpty
            ? ""
            : "<\(decl.genericParameters.joined(separator: ", "))>"
        let conformancePart = decl.conformances.isEmpty
            ? ""
            : ": \(decl.conformances.joined(separator: ", "))"

        headerParts.append("\(decl.name)\(genericPart)\(conformancePart)")
        lines.append("\(indent)\(headerParts.joined(separator: " ")) {")

        var bodyChunks: [String] = []

        for nested in decl.nestedTypes {
            bodyChunks.append(printTypeDecl(nested, level: level + 1))
        }

        if !decl.enumCases.isEmpty {
            let caseLines = decl.enumCases.map { printEnumCase($0, level: level + 1) }
            bodyChunks.append(caseLines.joined(separator: "\n"))
        }

        let storedProps = decl.properties.filter { !$0.isComputed }
        if !storedProps.isEmpty {
            bodyChunks.append(storedProps.map { printPropertyDecl($0, level: level + 1) }.joined(separator: "\n"))
        }

        let computedProps = decl.properties.filter { $0.isComputed }
        for prop in computedProps {
            bodyChunks.append(printPropertyDecl(prop, level: level + 1))
        }

        for fn in decl.functions {
            bodyChunks.append(printFunctionDecl(fn, level: level + 1))
        }

        if !bodyChunks.isEmpty {
            lines.append(bodyChunks.joined(separator: "\n\n"))
        }

        lines.append("\(indent)}")
        if decl.conditionalDirective != nil && level == 0 {
            lines.append("#endif")
        }
        return lines.joined(separator: "\n")
    }

    func printEnumCase(_ c: SwiftEnumCaseDecl, level: Int) -> String {
        let indent = config.indentUnit(level: level)
        var lines = printDocComment(c.docComment, level: level)
        var text = "\(indent)case \(c.name)"
        if !c.associatedValues.isEmpty {
            let params = c.associatedValues.map { p -> String in
                if p.internalName == "_" && p.externalLabel == nil {
                    return p.typeName
                }
                let label = p.externalLabel ?? p.internalName
                return "\(label): \(p.typeName)"
            }.joined(separator: ", ")
            text += "(\(params))"
        }
        if let raw = c.rawValue {
            text += " = \(raw.renderedDescription)"
        }
        lines.append(text)
        return lines.joined(separator: "\n")
    }

    func printPropertyDecl(_ prop: SwiftPropertyDecl, level: Int) -> String {
        let indent = config.indentUnit(level: level)
        var lines = printDocComment(prop.docComment, level: level)

        // Render non-wrapper attributes on preceding lines, and wrappers inline
        let nonWrapperAttrs = prop.attributes.filter { !$0.kind.isSwiftUIPropertyWrapper }
        for attr in nonWrapperAttrs {
            lines.append("\(indent)\(attr.renderedSource)")
        }

        var tokens: [String] = []
        for wrapper in prop.wrappers {
            if wrapper.arguments.isEmpty {
                tokens.append("@\(wrapper.wrapperName)")
            } else {
                let args = wrapper.arguments.map(\.renderedSource).joined(separator: ", ")
                tokens.append("@\(wrapper.wrapperName)(\(args))")
            }
        }
        if let access = prop.accessLevel.explicitSourcePrefix {
            tokens.append(access)
        }
        if prop.isStatic {
            tokens.append("static")
        }
        tokens.append(prop.isLet ? "let" : "var")

        var nameAndType = prop.name
        if let typeAnn = prop.typeAnnotation {
            nameAndType += ": \(typeAnn)"
        }
        tokens.append(nameAndType)

        if let initExpr = prop.initializer {
            tokens.append("= \(initExpr.renderedDescription)")
        }

        let declHead = "\(indent)\(tokens.joined(separator: " "))"

        if prop.isComputed {
            lines.append("\(declHead) {")
            if !prop.computedViewBody.isEmpty {
                for node in prop.computedViewBody {
                    lines.append(printViewNode(node, level: level + 1))
                }
            } else {
                for stmt in prop.computedStatements {
                    lines.append(printStatement(stmt, level: level + 1))
                }
            }
            lines.append("\(indent)}")
        } else {
            lines.append(declHead)
        }

        return lines.joined(separator: "\n")
    }

    func printFunctionDecl(_ fn: SwiftFunctionDecl, level: Int) -> String {
        let indent = config.indentUnit(level: level)
        var lines = printDocComment(fn.docComment, level: level)

        for attr in fn.attributes {
            lines.append("\(indent)\(attr.renderedSource)")
        }

        var head: [String] = []
        if let access = fn.accessLevel.explicitSourcePrefix {
            head.append(access)
        }
        if fn.isStatic { head.append("static") }
        if fn.isMutating { head.append("mutating") }

        let genericStr = fn.genericParameters.isEmpty ? "" : "<\(fn.genericParameters.joined(separator: ", "))>"
        let paramStr = fn.parameters.map(printParameter).joined(separator: ", ")

        if fn.isInitializer {
            head.append("\(fn.name)\(genericStr)(\(paramStr))")
        } else {
            head.append("func \(fn.name)\(genericStr)(\(paramStr))")
        }

        if fn.isAsync { head.append("async") }
        if fn.isThrows { head.append("throws") }
        if let ret = fn.returnType {
            head.append("-> \(ret)")
        }

        lines.append("\(indent)\(head.joined(separator: " ")) {")
        if !fn.viewBody.isEmpty {
            for node in fn.viewBody {
                lines.append(printViewNode(node, level: level + 1))
            }
        } else {
            for stmt in fn.statements {
                lines.append(printStatement(stmt, level: level + 1))
            }
        }
        lines.append("\(indent)}")
        return lines.joined(separator: "\n")
    }

    func printParameter(_ param: SwiftParameter) -> String {
        var parts: [String] = param.attributes.map(\.renderedSource)
        if let ext = param.externalLabel {
            parts.append("\(ext) \(param.internalName):")
        } else {
            parts.append("\(param.internalName):")
        }
        if param.isInout {
            parts.append("inout")
        }
        var typePart = param.typeName
        if param.isVariadic { typePart += "..." }
        parts.append(typePart)
        if let def = param.defaultValue {
            parts.append("= \(def.renderedDescription)")
        }
        return parts.joined(separator: " ")
    }

    func printViewNode(_ node: SwiftViewNode, level: Int) -> String {
        let indent = config.indentUnit(level: level)
        var lines: [String] = []

        if node.containerKind == .conditionalIf {
            let cond = node.conditionDescription ?? "true"
            lines.append("\(indent)if \(cond) {")
            for child in node.children {
                lines.append(printViewNode(child, level: level + 1))
            }
            if !node.elseChildren.isEmpty {
                lines.append("\(indent)} else {")
                for child in node.elseChildren {
                    lines.append(printViewNode(child, level: level + 1))
                }
            }
            lines.append("\(indent)}")
            appendModifiers(node.modifiers, to: &lines, baseLevel: level)
            return lines.joined(separator: "\n")
        }

        if node.containerKind == .conditionalSwitch {
            let subj = node.conditionDescription ?? "state"
            lines.append("\(indent)switch \(subj) {")
            for c in node.switchCases {
                let pat = c.isDefault ? "default:" : "case \(c.patterns.joined(separator: ", ")):"
                lines.append("\(indent)\(pat)")
                for child in c.viewChildren {
                    lines.append(printViewNode(child, level: level + 1))
                }
            }
            lines.append("\(indent)}")
            appendModifiers(node.modifiers, to: &lines, baseLevel: level)
            return lines.joined(separator: "\n")
        }

        let argList = node.arguments.map(\.renderedSource).joined(separator: ", ")
        let hasTrailing = !node.children.isEmpty || !node.actionStatements.isEmpty || node.containerKind == .button

        var head = "\(indent)\(node.componentName)"
        if !node.arguments.isEmpty || !hasTrailing {
            head += "(\(argList))"
        }

        if !node.children.isEmpty {
            lines.append("\(head) {")
            for child in node.children {
                lines.append(printViewNode(child, level: level + 1))
            }
            lines.append("\(indent)}")
        } else if !node.actionStatements.isEmpty {
            lines.append("\(head) {")
            for stmt in node.actionStatements {
                lines.append(printStatement(stmt, level: level + 1))
            }
            lines.append("\(indent)}")
        } else if node.containerKind == .button {
            lines.append("\(head) { }")
        } else {
            lines.append(head)
        }

        appendModifiers(node.modifiers, to: &lines, baseLevel: level)
        return lines.joined(separator: "\n")
    }

    func appendModifiers(_ modifiers: [SwiftModifierCall], to lines: inout [String], baseLevel: Int) {
        guard !modifiers.isEmpty else { return }
        let modIndent = config.indentUnit(level: baseLevel + 1)

        for mod in modifiers {
            let argStr = mod.arguments.map(\.renderedSource).joined(separator: ", ")
            if let closure = mod.trailingClosure {
                let callPart = mod.arguments.isEmpty ? ".\(mod.name)" : ".\(mod.name)(\(argStr))"
                if !closure.viewChildren.isEmpty {
                    lines.append("\(modIndent)\(callPart) {")
                    for child in closure.viewChildren {
                        lines.append(printViewNode(child, level: baseLevel + 2))
                    }
                    lines.append("\(modIndent)}")
                } else if !closure.statements.isEmpty {
                    lines.append("\(modIndent)\(callPart) {")
                    for stmt in closure.statements {
                        lines.append(printStatement(stmt, level: baseLevel + 2))
                    }
                    lines.append("\(modIndent)}")
                } else if !closure.rawBody.isEmpty {
                    lines.append("\(modIndent)\(callPart) { \(closure.rawBody) }")
                } else {
                    lines.append("\(modIndent)\(callPart) { }")
                }
            } else {
                lines.append("\(modIndent).\(mod.name)(\(argStr))")
            }
        }
    }

    func printStatement(_ stmt: SwiftStatement, level: Int) -> String {
        let indent = config.indentUnit(level: level)
        switch stmt {
        case .variableDecl(let prop):
            return printPropertyDecl(prop, level: level)
        case .assignment(let target, let op, let value):
            return "\(indent)\(target.renderedDescription) \(op) \(value.renderedDescription)"
        case .expression(let expr):
            return "\(indent)\(expr.renderedDescription)"
        case .returnStmt(let expr):
            if let expr { return "\(indent)return \(expr.renderedDescription)" }
            return "\(indent)return"
        case .throwStmt(let expr):
            return "\(indent)throw \(expr.renderedDescription)"
        case .ifStmt(let cond, let thenBody, let elseBody):
            var lines = ["\(indent)if \(cond) {"]
            lines.append(contentsOf: thenBody.map { printStatement($0, level: level + 1) })
            if !elseBody.isEmpty {
                lines.append("\(indent)} else {")
                lines.append(contentsOf: elseBody.map { printStatement($0, level: level + 1) })
            }
            lines.append("\(indent)}")
            return lines.joined(separator: "\n")
        case .guardStmt(let cond, let elseBody):
            var lines = ["\(indent)guard \(cond) else {"]
            lines.append(contentsOf: elseBody.map { printStatement($0, level: level + 1) })
            lines.append("\(indent)}")
            return lines.joined(separator: "\n")
        case .switchStmt(let subject, let cases):
            var lines = ["\(indent)switch \(subject.renderedDescription) {"]
            for c in cases {
                let pat = c.isDefault ? "default:" : "case \(c.patterns.joined(separator: ", ")):"
                lines.append("\(indent)\(pat)")
                lines.append(contentsOf: c.statements.map { printStatement($0, level: level + 1) })
            }
            lines.append("\(indent)}")
            return lines.joined(separator: "\n")
        case .forLoop(let pattern, let seq, let body):
            var lines = ["\(indent)for \(pattern) in \(seq.renderedDescription) {"]
            lines.append(contentsOf: body.map { printStatement($0, level: level + 1) })
            lines.append("\(indent)}")
            return lines.joined(separator: "\n")
        case .whileLoop(let cond, let body):
            var lines = ["\(indent)while \(cond.renderedDescription) {"]
            lines.append(contentsOf: body.map { printStatement($0, level: level + 1) })
            lines.append("\(indent)}")
            return lines.joined(separator: "\n")
        case .doCatch(let doBody, let catches):
            var lines = ["\(indent)do {"]
            lines.append(contentsOf: doBody.map { printStatement($0, level: level + 1) })
            for c in catches {
                let catchHeader = c.pattern.map { "catch \($0)" } ?? "catch"
                lines.append("\(indent)} \(catchHeader) {")
                lines.append(contentsOf: c.statements.map { printStatement($0, level: level + 1) })
            }
            lines.append("\(indent)}")
            return lines.joined(separator: "\n")
        case .deferStmt(let body):
            var lines = ["\(indent)defer {"]
            lines.append(contentsOf: body.map { printStatement($0, level: level + 1) })
            lines.append("\(indent)}")
            return lines.joined(separator: "\n")
        case .breakStmt:
            return "\(indent)break"
        case .continueStmt:
            return "\(indent)continue"
        }
    }

    func printPreviewDecl(_ preview: SwiftPreviewDecl, level: Int) -> String {
        let indent = config.indentUnit(level: level)
        let titlePart = preview.title.map { "\"\($0)\"" } ?? ""
        let header = titlePart.isEmpty ? "#Preview {" : "#Preview(\(titlePart)) {"
        var lines = ["\(indent)\(header)"]
        for node in preview.viewNodes {
            lines.append(printViewNode(node, level: level + 1))
        }
        lines.append("\(indent)}")
        return lines.joined(separator: "\n")
    }
}
