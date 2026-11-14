import ChiefKitStudioCore
import Foundation

// MARK: - Access Control & Type Kinds

/// Access control visibility modifier on a Swift declaration.
public enum SwiftAccessLevel: String, Codable, Hashable, CaseIterable, Sendable {
    case open
    case `public`
    case package
    case `internal`
    case `fileprivate`
    case `private`

    public init?(keyword: SwiftKeyword) {
        switch keyword {
        case .open: self = .open
        case .public: self = .public
        case .package: self = .package
        case .internal: self = .internal
        case .fileprivate: self = .fileprivate
        case .private: self = .private
        default: return nil
        }
    }

    /// Returns the explicit source keyword when non-default (`internal` is omitted by convention).
    public var explicitSourcePrefix: String? {
        switch self {
        case .internal:
            return nil
        default:
            return rawValue
        }
    }

    public var isPubliclyVisible: Bool {
        self == .open || self == .public || self == .package
    }
}

/// Primary nominal or extension declaration kind in Swift 6.
public enum SwiftTypeKind: String, Codable, Hashable, CaseIterable, Sendable {
    case `struct`
    case `class`
    case actor
    case `enum`
    case `protocol`
    case `extension`

    public init?(keyword: SwiftKeyword) {
        switch keyword {
        case .struct: self = .struct
        case .class: self = .class
        case .actor: self = .actor
        case .enum: self = .enum
        case .protocol: self = .protocol
        case .extension: self = .extension
        default: return nil
        }
    }

    public var isValueType: Bool {
        self == .struct || self == .enum
    }

    public var isReferenceType: Bool {
        self == .class || self == .actor
    }
}

// MARK: - Attributes, Imports & Property Wrappers

/// Concrete AST representation of an `@Attribute(...)` attached to a type, property, function, or parameter.
public struct SwiftAttributeNode: Codable, Hashable, Sendable {
    public var kind: SwiftAttributeKind
    public var rawName: String
    public var arguments: [String]
    public var span: SourceSpan

    public init(
        kind: SwiftAttributeKind,
        rawName: String? = nil,
        arguments: [String] = [],
        span: SourceSpan = .zero
    ) {
        self.kind = kind
        self.rawName = rawName ?? kind.canonicalName
        self.arguments = arguments
        self.span = span
    }

    public var renderedSource: String {
        if arguments.isEmpty { return "@\(rawName)" }
        return "@\(rawName)(\(arguments.joined(separator: ", ")))"
    }
}

/// Represents a Swift `import` declaration, optionally scoped inside a `#if` conditional block.
public struct SwiftImportDecl: Codable, Hashable, Sendable {
    public var moduleName: String
    public var subpath: [String]
    public var importKind: String?
    public var isExported: Bool
    public var isPreconcurrency: Bool
    public var conditionalDirective: String?
    public var span: SourceSpan

    public init(
        moduleName: String,
        subpath: [String] = [],
        importKind: String? = nil,
        isExported: Bool = false,
        isPreconcurrency: Bool = false,
        conditionalDirective: String? = nil,
        span: SourceSpan = .zero
    ) {
        self.moduleName = moduleName
        self.subpath = subpath
        self.importKind = importKind
        self.isExported = isExported
        self.isPreconcurrency = isPreconcurrency
        self.conditionalDirective = conditionalDirective
        self.span = span
    }

    public var fullModulePath: String {
        if subpath.isEmpty { return moduleName }
        return ([moduleName] + subpath).joined(separator: ".")
    }
}

/// Represents a SwiftUI or Observation property wrapper such as `@State`, `@Binding`, `@Environment`, or `@ScaledMetric`.
public struct SwiftPropertyWrapper: Codable, Hashable, Sendable {
    public var kind: SwiftAttributeKind
    public var arguments: [SwiftModifierArg]
    public var span: SourceSpan

    public init(
        kind: SwiftAttributeKind,
        arguments: [SwiftModifierArg] = [],
        span: SourceSpan = .zero
    ) {
        self.kind = kind
        self.arguments = arguments
        self.span = span
    }

    public var wrapperName: String {
        kind.canonicalName
    }
}

// MARK: - Expressions, Calls & Closures

/// Typed literal payload inside `SwiftExpr.literal`.
public enum SwiftLiteralValue: Codable, Hashable, Sendable {
    case integer(Int64, raw: String)
    case float(Double, raw: String)
    case string(String)
    case interpolatedString(raw: String, expressions: [String])
    case boolean(Bool)
    case `nil`
    case colorHex(String)

    public var numericDoubleValue: Double? {
        switch self {
        case .integer(let v, _): return Double(v)
        case .float(let v, _): return v
        default: return nil
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .interpolatedString(let raw, _): return raw
        case .colorHex(let hex): return hex
        default: return nil
        }
    }
}

/// Mode of a Swift `try` expression (`try`, `try?`, `try!`).
public enum SwiftTryMode: String, Codable, Hashable, Sendable {
    case regular = "try"
    case optional = "try?"
    case forced = "try!"
}

/// Labeled or unlabeled argument passed to a function, initializer, or modifier call.
public struct SwiftCallArgument: Codable, Hashable, Sendable {
    public var label: String?
    public var value: SwiftExpr

    public init(label: String? = nil, value: SwiftExpr) {
        self.label = label
        self.value = value
    }
}

/// Key-value pair in a Swift dictionary literal `[key: value]`.
public struct SwiftDictionaryEntry: Codable, Hashable, Sendable {
    public var key: SwiftExpr
    public var value: SwiftExpr

    public init(key: SwiftExpr, value: SwiftExpr) {
        self.key = key
        self.value = value
    }
}

/// Element in a Swift tuple expression `(label: value)`.
public struct SwiftTupleElement: Codable, Hashable, Sendable {
    public var label: String?
    public var value: SwiftExpr

    public init(label: String? = nil, value: SwiftExpr) {
        self.label = label
        self.value = value
    }
}

/// Represents a Swift closure expression `{ [captureList] params in statements / viewChildren }`.
public struct SwiftClosureExpr: Codable, Hashable, Sendable {
    public var captureList: [String]
    public var parameters: [String]
    public var statements: [SwiftStatement]
    public var viewChildren: [SwiftViewNode]
    public var rawBody: String

    public init(
        captureList: [String] = [],
        parameters: [String] = [],
        statements: [SwiftStatement] = [],
        viewChildren: [SwiftViewNode] = [],
        rawBody: String = ""
    ) {
        self.captureList = captureList
        self.parameters = parameters
        self.statements = statements
        self.viewChildren = viewChildren
        self.rawBody = rawBody
    }

    public var isEmpty: Bool {
        statements.isEmpty && viewChildren.isEmpty && rawBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Recursive Swift 6 expression AST node.
public indirect enum SwiftExpr: Codable, Hashable, Sendable {
    case literal(SwiftLiteralValue)
    case identifier(String)
    case dollarBinding(String)
    case implicitMember(String)
    case memberAccess(base: SwiftExpr, member: String)
    case call(callee: SwiftExpr, arguments: [SwiftCallArgument], trailingClosure: SwiftClosureExpr?)
    case closure(SwiftClosureExpr)
    case array([SwiftExpr])
    case dictionary([SwiftDictionaryEntry])
    case tuple([SwiftTupleElement])
    case binaryOp(lhs: SwiftExpr, op: String, rhs: SwiftExpr)
    case prefixOp(op: String, operand: SwiftExpr)
    case postfixOp(operand: SwiftExpr, op: String)
    case ternary(condition: SwiftExpr, thenExpr: SwiftExpr, elseExpr: SwiftExpr)
    case tryExpr(mode: SwiftTryMode, expr: SwiftExpr)
    case awaitExpr(SwiftExpr)
    case typeCast(expr: SwiftExpr, op: String, targetType: String)
    case keyPath(root: String?, path: [String])
    case raw(String)

    // MARK: Convenience Constructors

    public static func int(_ value: Int) -> SwiftExpr {
        .literal(.integer(Int64(value), raw: "\(value)"))
    }

    public static func double(_ value: Double) -> SwiftExpr {
        let formatted = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.1f", value)
            : String(value)
        return .literal(.float(value, raw: formatted))
    }

    public static func string(_ value: String) -> SwiftExpr {
        .literal(.string(value))
    }

    public static func bool(_ value: Bool) -> SwiftExpr {
        .literal(.boolean(value))
    }

    // MARK: Semantic Value Extractors

    public var stringLiteralValue: String? {
        switch self {
        case .literal(let lit):
            return lit.stringValue
        default:
            return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .literal(let lit):
            return lit.numericDoubleValue
        case .prefixOp(let op, let operand) where op == "-":
            return operand.doubleValue.map { -$0 }
        default:
            return nil
        }
    }

    public var intValue: Int? {
        switch self {
        case .literal(.integer(let val, _)):
            return Int(val)
        case .prefixOp(let op, let operand) where op == "-":
            return operand.intValue.map { -$0 }
        default:
            return nil
        }
    }

    public var boolValue: Bool? {
        if case .literal(.boolean(let b)) = self { return b }
        return nil
    }

    /// Extracts `.primary` -> `"primary"` or `CanvasVariant.primary` -> `"primary"`.
    public var memberLeafName: String? {
        switch self {
        case .implicitMember(let name):
            return name
        case .memberAccess(_, let member):
            return member
        case .call(let callee, _, _):
            return callee.memberLeafName
        default:
            return nil
        }
    }

    /// Collects all referenced unqualified variable/type identifiers inside this expression tree.
    public func allReferencedIdentifiers() -> Set<String> {
        var result = Set<String>()
        collectIdentifiers(into: &result)
        return result
    }

    private func collectIdentifiers(into set: inout Set<String>) {
        switch self {
        case .identifier(let name):
            set.insert(name)
        case .dollarBinding(let raw):
            let stripped = raw.hasPrefix("$") ? String(raw.dropFirst()) : raw
            if !stripped.isEmpty && !stripped.allSatisfy(\.isNumber) {
                set.insert(stripped)
            }
        case .memberAccess(let base, _):
            base.collectIdentifiers(into: &set)
        case .call(let callee, let args, let closure):
            callee.collectIdentifiers(into: &set)
            for arg in args {
                arg.value.collectIdentifiers(into: &set)
            }
            if let closure {
                for stmt in closure.statements {
                    set.formUnion(stmt.allReferencedIdentifiers())
                }
                for child in closure.viewChildren {
                    set.formUnion(child.allReferencedIdentifiers())
                }
            }
        case .closure(let c):
            for stmt in c.statements {
                set.formUnion(stmt.allReferencedIdentifiers())
            }
            for child in c.viewChildren {
                set.formUnion(child.allReferencedIdentifiers())
            }
        case .array(let elements):
            for el in elements { el.collectIdentifiers(into: &set) }
        case .dictionary(let entries):
            for entry in entries {
                entry.key.collectIdentifiers(into: &set)
                entry.value.collectIdentifiers(into: &set)
            }
        case .tuple(let elements):
            for el in elements { el.value.collectIdentifiers(into: &set) }
        case .binaryOp(let lhs, _, let rhs):
            lhs.collectIdentifiers(into: &set)
            rhs.collectIdentifiers(into: &set)
        case .prefixOp(_, let operand), .postfixOp(let operand, _):
            operand.collectIdentifiers(into: &set)
        case .ternary(let cond, let t, let e):
            cond.collectIdentifiers(into: &set)
            t.collectIdentifiers(into: &set)
            e.collectIdentifiers(into: &set)
        case .tryExpr(_, let inner), .awaitExpr(let inner), .typeCast(let inner, _, _):
            inner.collectIdentifiers(into: &set)
        case .literal(.interpolatedString(_, let expressions)):
            for exprText in expressions {
                let trimmed = exprText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let head = trimmed.split(separator: ".").first {
                    set.insert(String(head))
                }
            }
        case .literal, .implicitMember, .keyPath, .raw:
            break
        }
    }

    public var containsForceUnwrap: Bool {
        switch self {
        case .postfixOp(let operand, let op):
            return op == "!" || operand.containsForceUnwrap
        case .memberAccess(let base, _):
            return base.containsForceUnwrap
        case .call(let callee, let args, _):
            return callee.containsForceUnwrap || args.contains { $0.value.containsForceUnwrap }
        case .binaryOp(let lhs, _, let rhs):
            return lhs.containsForceUnwrap || rhs.containsForceUnwrap
        case .prefixOp(_, let opd):
            return opd.containsForceUnwrap
        case .ternary(let c, let t, let e):
            return c.containsForceUnwrap || t.containsForceUnwrap || e.containsForceUnwrap
        case .tryExpr(_, let inner), .awaitExpr(let inner), .typeCast(let inner, _, _):
            return inner.containsForceUnwrap
        case .array(let els):
            return els.contains { $0.containsForceUnwrap }
        case .tuple(let els):
            return els.contains { $0.value.containsForceUnwrap }
        default:
            return false
        }
    }

    public var containsForceTry: Bool {
        switch self {
        case .tryExpr(let mode, let inner):
            return mode == .forced || inner.containsForceTry
        case .call(let callee, let args, _):
            return callee.containsForceTry || args.contains { $0.value.containsForceTry }
        case .binaryOp(let l, _, let r):
            return l.containsForceTry || r.containsForceTry
        case .memberAccess(let b, _):
            return b.containsForceTry
        case .awaitExpr(let inner):
            return inner.containsForceTry
        default:
            return false
        }
    }

    public var containsForceCast: Bool {
        switch self {
        case .typeCast(let inner, let op, _):
            return op == "as!" || inner.containsForceCast
        case .call(let callee, let args, _):
            return callee.containsForceCast || args.contains { $0.value.containsForceCast }
        case .binaryOp(let l, _, let r):
            return l.containsForceCast || r.containsForceCast
        default:
            return false
        }
    }

    /// Concise source-like textual rendering of this expression.
    public var renderedDescription: String {
        switch self {
        case .literal(let lit):
            switch lit {
            case .integer(_, let raw): return raw
            case .float(_, let raw): return raw
            case .string(let s):
                let escaped = s
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                return "\"\(escaped)\""
            case .interpolatedString(let raw, _): return raw
            case .boolean(let b): return b ? "true" : "false"
            case .nil: return "nil"
            case .colorHex(let hex): return "\"\(hex)\""
            }
        case .identifier(let name):
            return name
        case .dollarBinding(let name):
            return name.hasPrefix("$") ? name : "$\(name)"
        case .implicitMember(let member):
            return ".\(member)"
        case .memberAccess(let base, let member):
            return "\(base.renderedDescription).\(member)"
        case .call(let callee, let args, let trailing):
            let argList = args.map { arg in
                if let label = arg.label { return "\(label): \(arg.value.renderedDescription)" }
                return arg.value.renderedDescription
            }.joined(separator: ", ")
            let baseCall: String
            if args.isEmpty && trailing != nil {
                baseCall = callee.renderedDescription
            } else {
                baseCall = "\(callee.renderedDescription)(\(argList))"
            }
            if let trailing {
                if trailing.rawBody.isEmpty && trailing.statements.isEmpty && trailing.viewChildren.isEmpty {
                    return "\(baseCall) { }"
                }
                return "\(baseCall) { \(trailing.rawBody) }"
            }
            return baseCall
        case .closure(let c):
            return "{ \(c.rawBody) }"
        case .array(let items):
            return "[\(items.map(\.renderedDescription).joined(separator: ", "))]"
        case .dictionary(let entries):
            if entries.isEmpty { return "[:]" }
            let rendered = entries.map { "\($0.key.renderedDescription): \($0.value.renderedDescription)" }
            return "[\(rendered.joined(separator: ", "))]"
        case .tuple(let els):
            let rendered = els.map { el in
                if let label = el.label { return "\(label): \(el.value.renderedDescription)" }
                return el.value.renderedDescription
            }
            return "(\(rendered.joined(separator: ", ")))"
        case .binaryOp(let lhs, let op, let rhs):
            return "\(lhs.renderedDescription) \(op) \(rhs.renderedDescription)"
        case .prefixOp(let op, let operand):
            return "\(op)\(operand.renderedDescription)"
        case .postfixOp(let operand, let op):
            return "\(operand.renderedDescription)\(op)"
        case .ternary(let cond, let t, let e):
            return "\(cond.renderedDescription) ? \(t.renderedDescription) : \(e.renderedDescription)"
        case .tryExpr(let mode, let inner):
            return "\(mode.rawValue) \(inner.renderedDescription)"
        case .awaitExpr(let inner):
            return "await \(inner.renderedDescription)"
        case .typeCast(let inner, let op, let target):
            return "\(inner.renderedDescription) \(op) \(target)"
        case .keyPath(let root, let path):
            let prefix = root ?? ""
            return "\\\(prefix).\(path.joined(separator: "."))"
        case .raw(let text):
            return text
        }
    }
}

// MARK: - Imperative Statements & Control Flow

/// Represents a `case` or `default` branch in a Swift `switch` statement or `@ViewBuilder` `switch`.
public struct SwiftSwitchCase: Codable, Hashable, Sendable {
    public var patterns: [String]
    public var isDefault: Bool
    public var statements: [SwiftStatement]
    public var viewChildren: [SwiftViewNode]

    public init(
        patterns: [String] = [],
        isDefault: Bool = false,
        statements: [SwiftStatement] = [],
        viewChildren: [SwiftViewNode] = []
    ) {
        self.patterns = patterns
        self.isDefault = isDefault
        self.statements = statements
        self.viewChildren = viewChildren
    }
}

/// Represents a `catch` clause attached to a `do` block.
public struct SwiftCatchClause: Codable, Hashable, Sendable {
    public var pattern: String?
    public var statements: [SwiftStatement]
    public var span: SourceSpan

    public init(
        pattern: String? = nil,
        statements: [SwiftStatement] = [],
        span: SourceSpan = .zero
    ) {
        self.pattern = pattern
        self.statements = statements
        self.span = span
    }
}

/// Recursive statement AST node inside function bodies, initializers, reducers, and action closures.
public indirect enum SwiftStatement: Codable, Hashable, Sendable {
    case variableDecl(SwiftPropertyDecl)
    case assignment(target: SwiftExpr, op: String, value: SwiftExpr)
    case expression(SwiftExpr)
    case returnStmt(SwiftExpr?)
    case throwStmt(SwiftExpr)
    case ifStmt(condition: String, thenBody: [SwiftStatement], elseBody: [SwiftStatement])
    case guardStmt(condition: String, elseBody: [SwiftStatement])
    case switchStmt(subject: SwiftExpr, cases: [SwiftSwitchCase])
    case forLoop(pattern: String, sequence: SwiftExpr, body: [SwiftStatement])
    case whileLoop(condition: SwiftExpr, body: [SwiftStatement])
    case doCatch(doBody: [SwiftStatement], catches: [SwiftCatchClause])
    case deferStmt([SwiftStatement])
    case breakStmt
    case continueStmt

    public func allReferencedIdentifiers() -> Set<String> {
        var ids = Set<String>()
        switch self {
        case .variableDecl(let prop):
            if let initExpr = prop.initializer {
                ids.formUnion(initExpr.allReferencedIdentifiers())
            }
        case .assignment(let target, _, let value):
            ids.formUnion(target.allReferencedIdentifiers())
            ids.formUnion(value.allReferencedIdentifiers())
        case .expression(let expr), .throwStmt(let expr):
            ids.formUnion(expr.allReferencedIdentifiers())
        case .returnStmt(let expr):
            if let expr { ids.formUnion(expr.allReferencedIdentifiers()) }
        case .ifStmt(_, let thenBody, let elseBody):
            for s in thenBody { ids.formUnion(s.allReferencedIdentifiers()) }
            for s in elseBody { ids.formUnion(s.allReferencedIdentifiers()) }
        case .guardStmt(_, let elseBody):
            for s in elseBody { ids.formUnion(s.allReferencedIdentifiers()) }
        case .switchStmt(let subject, let cases):
            ids.formUnion(subject.allReferencedIdentifiers())
            for c in cases {
                for s in c.statements { ids.formUnion(s.allReferencedIdentifiers()) }
            }
        case .forLoop(_, let seq, let body):
            ids.formUnion(seq.allReferencedIdentifiers())
            for s in body { ids.formUnion(s.allReferencedIdentifiers()) }
        case .whileLoop(let cond, let body):
            ids.formUnion(cond.allReferencedIdentifiers())
            for s in body { ids.formUnion(s.allReferencedIdentifiers()) }
        case .doCatch(let doBody, let catches):
            for s in doBody { ids.formUnion(s.allReferencedIdentifiers()) }
            for c in catches {
                for s in c.statements { ids.formUnion(s.allReferencedIdentifiers()) }
            }
        case .deferStmt(let body):
            for s in body { ids.formUnion(s.allReferencedIdentifiers()) }
        case .breakStmt, .continueStmt:
            break
        }
        return ids
    }
}

// MARK: - SwiftUI View Builder Hierarchy Nodes

/// Argument passed to a SwiftUI view initializer or view modifier call.
public struct SwiftModifierArg: Codable, Hashable, Sendable {
    public var label: String?
    public var value: SwiftExpr

    public init(label: String? = nil, value: SwiftExpr) {
        self.label = label
        self.value = value
    }

    public var renderedSource: String {
        if let label { return "\(label): \(value.renderedDescription)" }
        return value.renderedDescription
    }
}

/// Chained SwiftUI modifier invocation (`.padding(16)`, `.edkLiquidGlass(cornerRadius: 12)`, `.onAppear { ... }`).
public struct SwiftModifierCall: Codable, Hashable, Sendable {
    public var name: String
    public var arguments: [SwiftModifierArg]
    public var trailingClosure: SwiftClosureExpr?
    public var span: SourceSpan

    public init(
        name: String,
        arguments: [SwiftModifierArg] = [],
        trailingClosure: SwiftClosureExpr? = nil,
        span: SourceSpan = .zero
    ) {
        self.name = name
        self.arguments = arguments
        self.trailingClosure = trailingClosure
        self.span = span
    }
}

/// Semantic layout or control-flow classification of a `SwiftViewNode`.
public enum SwiftViewContainerKind: String, Codable, Hashable, CaseIterable, Sendable {
    case vStack
    case hStack
    case zStack
    case lazyVStack
    case lazyHStack
    case lazyVGrid
    case lazyHGrid
    case grid
    case gridRow
    case scrollView
    case list
    case form
    case section
    case group
    case navigationStack
    case navigationSplitView
    case tabView
    case edkSurface
    case glassCard
    case geometryReader
    case forEach
    case conditionalIf
    case conditionalSwitch
    case button
    case menu
    case leaf
    case customContainer

    public static func classify(componentName: String, hasViewChildren: Bool) -> SwiftViewContainerKind {
        switch componentName {
        case "VStack": return .vStack
        case "HStack": return .hStack
        case "ZStack": return .zStack
        case "LazyVStack": return .lazyVStack
        case "LazyHStack": return .lazyHStack
        case "LazyVGrid": return .lazyVGrid
        case "LazyHGrid": return .lazyHGrid
        case "Grid": return .grid
        case "GridRow": return .gridRow
        case "ScrollView": return .scrollView
        case "List": return .list
        case "Form": return .form
        case "Section": return .section
        case "Group": return .group
        case "NavigationStack", "NavigationView": return .navigationStack
        case "NavigationSplitView": return .navigationSplitView
        case "TabView": return .tabView
        case "EDKSurface": return .edkSurface
        case "GlassCard", "EDKCard": return .glassCard
        case "GeometryReader": return .geometryReader
        case "ForEach": return .forEach
        case "if": return .conditionalIf
        case "switch": return .conditionalSwitch
        case "Button", "EDKButton": return .button
        case "Menu": return .menu
        default:
            return hasViewChildren ? .customContainer : .leaf
        }
    }

    public var isLayoutContainer: Bool {
        switch self {
        case .vStack, .hStack, .zStack, .lazyVStack, .lazyHStack, .lazyVGrid, .lazyHGrid,
             .grid, .gridRow, .scrollView, .list, .form, .section, .group,
             .navigationStack, .navigationSplitView, .tabView, .edkSurface, .glassCard,
             .geometryReader, .forEach, .customContainer:
            return true
        default:
            return false
        }
    }
}

/// Declarative SwiftUI `@ViewBuilder` tree node with child views, action closures, control-flow branches, and chained modifiers.
public struct SwiftViewNode: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var componentName: String
    public var containerKind: SwiftViewContainerKind
    public var arguments: [SwiftModifierArg]
    public var children: [SwiftViewNode]
    public var elseChildren: [SwiftViewNode]
    public var switchCases: [SwiftSwitchCase]
    public var actionStatements: [SwiftStatement]
    public var modifiers: [SwiftModifierCall]
    public var conditionDescription: String?
    public var span: SourceSpan

    public init(
        id: UUID = UUID(),
        componentName: String,
        containerKind: SwiftViewContainerKind? = nil,
        arguments: [SwiftModifierArg] = [],
        children: [SwiftViewNode] = [],
        elseChildren: [SwiftViewNode] = [],
        switchCases: [SwiftSwitchCase] = [],
        actionStatements: [SwiftStatement] = [],
        modifiers: [SwiftModifierCall] = [],
        conditionDescription: String? = nil,
        span: SourceSpan = .zero
    ) {
        self.id = id
        self.componentName = componentName
        let resolvedKind = containerKind ?? SwiftViewContainerKind.classify(componentName: componentName, hasViewChildren: !children.isEmpty)
        self.containerKind = resolvedKind
        self.arguments = arguments
        self.children = children
        self.elseChildren = elseChildren
        self.switchCases = switchCases
        self.actionStatements = actionStatements
        self.modifiers = modifiers
        self.conditionDescription = conditionDescription
        self.span = span
    }

    /// Total number of `SwiftViewNode` instances in this subtree (including `self`).
    public var totalNodeCount: Int {
        let primaryCount = children.reduce(0) { $0 + $1.totalNodeCount }
        let elseCount = elseChildren.reduce(0) { $0 + $1.totalNodeCount }
        let switchCount = switchCases.reduce(0) { acc, c in
            acc + c.viewChildren.reduce(0) { $0 + $1.totalNodeCount }
        }
        return 1 + primaryCount + elseCount + switchCount
    }

    /// Maximum nesting depth of this view subtree (`1` for a single leaf node).
    public var maxDepth: Int {
        var deepestChild = 0
        for child in children {
            deepestChild = max(deepestChild, child.maxDepth)
        }
        for child in elseChildren {
            deepestChild = max(deepestChild, child.maxDepth)
        }
        for switchCase in switchCases {
            for child in switchCase.viewChildren {
                deepestChild = max(deepestChild, child.maxDepth)
            }
        }
        return 1 + deepestChild
    }

    /// Total modifier count across this node and all descendant nodes.
    public var totalModifierCount: Int {
        let childMods = children.reduce(0) { $0 + $1.totalModifierCount }
        let elseMods = elseChildren.reduce(0) { $0 + $1.totalModifierCount }
        let switchMods = switchCases.reduce(0) { acc, c in
            acc + c.viewChildren.reduce(0) { $0 + $1.totalModifierCount }
        }
        return modifiers.count + childMods + elseMods + switchMods
    }

    /// Pre-order flattened list of all `SwiftViewNode` elements in this subtree.
    public func flattenedNodes() -> [SwiftViewNode] {
        var list: [SwiftViewNode] = [self]
        for child in children {
            list.append(contentsOf: child.flattenedNodes())
        }
        for child in elseChildren {
            list.append(contentsOf: child.flattenedNodes())
        }
        for switchCase in switchCases {
            for child in switchCase.viewChildren {
                list.append(contentsOf: child.flattenedNodes())
            }
        }
        return list
    }

    public func hasModifier(_ name: String) -> Bool {
        modifiers.contains { $0.name == name }
    }

    public func modifier(named name: String) -> SwiftModifierCall? {
        modifiers.first { $0.name == name }
    }

    public func argument(labeled label: String) -> SwiftExpr? {
        arguments.first { $0.label == label }?.value
    }

    public var firstUnlabeledStringArgument: String? {
        arguments.first { $0.label == nil }?.value.stringLiteralValue
    }

    public func allReferencedIdentifiers() -> Set<String> {
        var ids = Set<String>()
        for arg in arguments {
            ids.formUnion(arg.value.allReferencedIdentifiers())
        }
        for mod in modifiers {
            for arg in mod.arguments {
                ids.formUnion(arg.value.allReferencedIdentifiers())
            }
            if let closure = mod.trailingClosure {
                for stmt in closure.statements {
                    ids.formUnion(stmt.allReferencedIdentifiers())
                }
                for child in closure.viewChildren {
                    ids.formUnion(child.allReferencedIdentifiers())
                }
            }
        }
        for stmt in actionStatements {
            ids.formUnion(stmt.allReferencedIdentifiers())
        }
        for child in children {
            ids.formUnion(child.allReferencedIdentifiers())
        }
        for child in elseChildren {
            ids.formUnion(child.allReferencedIdentifiers())
        }
        for c in switchCases {
            for child in c.viewChildren {
                ids.formUnion(child.allReferencedIdentifiers())
            }
        }
        return ids
    }
}

// MARK: - Declarations (Properties, Parameters, Functions, Enum Cases, Types)

/// Stored or computed property declaration (`@State private var count: Int = 0` or `var body: some View { ... }`).
public struct SwiftPropertyDecl: Codable, Hashable, Sendable {
    public var name: String
    public var isLet: Bool
    public var accessLevel: SwiftAccessLevel
    public var isStatic: Bool
    public var typeAnnotation: String?
    public var initializer: SwiftExpr?
    public var wrappers: [SwiftPropertyWrapper]
    public var attributes: [SwiftAttributeNode]
    public var isComputed: Bool
    public var computedViewBody: [SwiftViewNode]
    public var computedStatements: [SwiftStatement]
    public var docComment: String?
    public var span: SourceSpan

    public init(
        name: String,
        isLet: Bool = false,
        accessLevel: SwiftAccessLevel = .internal,
        isStatic: Bool = false,
        typeAnnotation: String? = nil,
        initializer: SwiftExpr? = nil,
        wrappers: [SwiftPropertyWrapper] = [],
        attributes: [SwiftAttributeNode] = [],
        isComputed: Bool = false,
        computedViewBody: [SwiftViewNode] = [],
        computedStatements: [SwiftStatement] = [],
        docComment: String? = nil,
        span: SourceSpan = .zero
    ) {
        self.name = name
        self.isLet = isLet
        self.accessLevel = accessLevel
        self.isStatic = isStatic
        self.typeAnnotation = typeAnnotation
        self.initializer = initializer
        self.wrappers = wrappers
        self.attributes = attributes
        self.isComputed = isComputed
        self.computedViewBody = computedViewBody
        self.computedStatements = computedStatements
        self.docComment = docComment
        self.span = span
    }

    public func hasWrapper(_ kind: SwiftAttributeKind) -> Bool {
        wrappers.contains { $0.kind == kind }
    }

    public var isSwiftUIBodyProperty: Bool {
        isComputed && name == "body" && (!computedViewBody.isEmpty || (typeAnnotation?.contains("View") == true))
    }
}

/// Function, initializer, or enum-case associated value parameter.
public struct SwiftParameter: Codable, Hashable, Sendable {
    public var externalLabel: String?
    public var internalName: String
    public var typeName: String
    public var isInout: Bool
    public var isVariadic: Bool
    public var defaultValue: SwiftExpr?
    public var attributes: [SwiftAttributeNode]

    public init(
        externalLabel: String? = nil,
        internalName: String,
        typeName: String,
        isInout: Bool = false,
        isVariadic: Bool = false,
        defaultValue: SwiftExpr? = nil,
        attributes: [SwiftAttributeNode] = []
    ) {
        self.externalLabel = externalLabel
        self.internalName = internalName
        self.typeName = typeName
        self.isInout = isInout
        self.isVariadic = isVariadic
        self.defaultValue = defaultValue
        self.attributes = attributes
    }
}

/// Function, method, or `init` declaration.
public struct SwiftFunctionDecl: Codable, Hashable, Sendable {
    public var name: String
    public var isInitializer: Bool
    public var accessLevel: SwiftAccessLevel
    public var isStatic: Bool
    public var isMutating: Bool
    public var isAsync: Bool
    public var isThrows: Bool
    public var genericParameters: [String]
    public var parameters: [SwiftParameter]
    public var returnType: String?
    public var attributes: [SwiftAttributeNode]
    public var statements: [SwiftStatement]
    public var viewBody: [SwiftViewNode]
    public var docComment: String?
    public var span: SourceSpan

    public init(
        name: String,
        isInitializer: Bool = false,
        accessLevel: SwiftAccessLevel = .internal,
        isStatic: Bool = false,
        isMutating: Bool = false,
        isAsync: Bool = false,
        isThrows: Bool = false,
        genericParameters: [String] = [],
        parameters: [SwiftParameter] = [],
        returnType: String? = nil,
        attributes: [SwiftAttributeNode] = [],
        statements: [SwiftStatement] = [],
        viewBody: [SwiftViewNode] = [],
        docComment: String? = nil,
        span: SourceSpan = .zero
    ) {
        self.name = name
        self.isInitializer = isInitializer
        self.accessLevel = accessLevel
        self.isStatic = isStatic
        self.isMutating = isMutating
        self.isAsync = isAsync
        self.isThrows = isThrows
        self.genericParameters = genericParameters
        self.parameters = parameters
        self.returnType = returnType
        self.attributes = attributes
        self.statements = statements
        self.viewBody = viewBody
        self.docComment = docComment
        self.span = span
    }
}

/// Case element inside a Swift `enum` declaration (`case loaded([Item])` or `case button = "Button"`).
public struct SwiftEnumCaseDecl: Codable, Hashable, Sendable {
    public var name: String
    public var rawValue: SwiftExpr?
    public var associatedValues: [SwiftParameter]
    public var docComment: String?
    public var span: SourceSpan

    public init(
        name: String,
        rawValue: SwiftExpr? = nil,
        associatedValues: [SwiftParameter] = [],
        docComment: String? = nil,
        span: SourceSpan = .zero
    ) {
        self.name = name
        self.rawValue = rawValue
        self.associatedValues = associatedValues
        self.docComment = docComment
        self.span = span
    }
}

/// Nominal type (`struct`, `class`, `actor`, `enum`, `protocol`) or `extension` AST node.
public struct SwiftTypeDecl: Codable, Hashable, Sendable {
    public var name: String
    public var kind: SwiftTypeKind
    public var accessLevel: SwiftAccessLevel
    public var isFinal: Bool
    public var attributes: [SwiftAttributeNode]
    public var genericParameters: [String]
    public var conformances: [String]
    public var properties: [SwiftPropertyDecl]
    public var functions: [SwiftFunctionDecl]
    public var enumCases: [SwiftEnumCaseDecl]
    public var nestedTypes: [SwiftTypeDecl]
    public var docComment: String?
    public var conditionalDirective: String?
    public var span: SourceSpan

    public init(
        name: String,
        kind: SwiftTypeKind,
        accessLevel: SwiftAccessLevel = .internal,
        isFinal: Bool = false,
        attributes: [SwiftAttributeNode] = [],
        genericParameters: [String] = [],
        conformances: [String] = [],
        properties: [SwiftPropertyDecl] = [],
        functions: [SwiftFunctionDecl] = [],
        enumCases: [SwiftEnumCaseDecl] = [],
        nestedTypes: [SwiftTypeDecl] = [],
        docComment: String? = nil,
        conditionalDirective: String? = nil,
        span: SourceSpan = .zero
    ) {
        self.name = name
        self.kind = kind
        self.accessLevel = accessLevel
        self.isFinal = isFinal
        self.attributes = attributes
        self.genericParameters = genericParameters
        self.conformances = conformances
        self.properties = properties
        self.functions = functions
        self.enumCases = enumCases
        self.nestedTypes = nestedTypes
        self.docComment = docComment
        self.conditionalDirective = conditionalDirective
        self.span = span
    }

    public var isSwiftUIView: Bool {
        conformances.contains("View") || properties.contains { $0.isSwiftUIBodyProperty }
    }

    public var isLegacyObservableObject: Bool {
        conformances.contains("ObservableObject")
    }

    public var hasObservableMacro: Bool {
        attributes.contains { $0.kind == .observable }
    }

    public var conformsToSendable: Bool {
        conformances.contains("Sendable") || conformances.contains("@unchecked Sendable") || kind == .actor
    }

    public var isMainActorIsolated: Bool {
        attributes.contains { $0.kind == .mainActor } || isSwiftUIView
    }

    public var bodyViewNodes: [SwiftViewNode] {
        if let bodyProp = properties.first(where: { $0.name == "body" && !$0.computedViewBody.isEmpty }) {
            return bodyProp.computedViewBody
        }
        return properties.flatMap(\.computedViewBody)
    }
}

// MARK: - Conditional Blocks, Previews, Diagnostics & Source File Root

/// Records a `#if ... #elseif ... #else ... #endif` conditional compilation block encountered in source.
public struct SwiftConditionalCompilationBlock: Codable, Hashable, Sendable {
    public var condition: String
    public var elseIfConditions: [String]
    public var hasElse: Bool
    public var span: SourceSpan

    public init(
        condition: String,
        elseIfConditions: [String] = [],
        hasElse: Bool = false,
        span: SourceSpan = .zero
    ) {
        self.condition = condition
        self.elseIfConditions = elseIfConditions
        self.hasElse = hasElse
        self.span = span
    }
}

/// Represents a SwiftUI `#Preview("...") { ... }` macro declaration.
public struct SwiftPreviewDecl: Codable, Hashable, Sendable {
    public var title: String?
    public var viewNodes: [SwiftViewNode]
    public var statements: [SwiftStatement]
    public var span: SourceSpan

    public init(
        title: String? = nil,
        viewNodes: [SwiftViewNode] = [],
        statements: [SwiftStatement] = [],
        span: SourceSpan = .zero
    ) {
        self.title = title
        self.viewNodes = viewNodes
        self.statements = statements
        self.span = span
    }
}

/// Severity level of a parser syntax/recovery diagnostic.
public enum ParseDiagnosticSeverity: String, Codable, Hashable, CaseIterable, Sendable {
    case note
    case warning
    case error
}

/// Structured syntax diagnostic emitted by `SwiftUIParser` during recursive-descent parsing and error recovery.
public struct ParseDiagnostic: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let severity: ParseDiagnosticSeverity
    public let message: String
    public let span: SourceSpan
    public let expected: String?
    public let found: String?

    public init(
        id: UUID = UUID(),
        severity: ParseDiagnosticSeverity,
        message: String,
        span: SourceSpan,
        expected: String? = nil,
        found: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.span = span
        self.expected = expected
        self.found = found
    }
}

/// Root AST node representing a parsed Swift 6 / SwiftUI source file.
public struct SwiftSourceFile: Codable, Equatable, Sendable {
    public var filePath: String?
    public var imports: [SwiftImportDecl]
    public var types: [SwiftTypeDecl]
    public var topLevelProperties: [SwiftPropertyDecl]
    public var topLevelFunctions: [SwiftFunctionDecl]
    public var previews: [SwiftPreviewDecl]
    public var conditionalBlocks: [SwiftConditionalCompilationBlock]
    public var diagnostics: [ParseDiagnostic]
    public var lineCount: Int

    public init(
        filePath: String? = nil,
        imports: [SwiftImportDecl] = [],
        types: [SwiftTypeDecl] = [],
        topLevelProperties: [SwiftPropertyDecl] = [],
        topLevelFunctions: [SwiftFunctionDecl] = [],
        previews: [SwiftPreviewDecl] = [],
        conditionalBlocks: [SwiftConditionalCompilationBlock] = [],
        diagnostics: [ParseDiagnostic] = [],
        lineCount: Int = 1
    ) {
        self.filePath = filePath
        self.imports = imports
        self.types = types
        self.topLevelProperties = topLevelProperties
        self.topLevelFunctions = topLevelFunctions
        self.previews = previews
        self.conditionalBlocks = conditionalBlocks
        self.diagnostics = diagnostics
        self.lineCount = max(1, lineCount)
    }

    /// Recursively flattens all top-level and nested `SwiftTypeDecl` nodes in declaration order.
    public func allTypesFlattened() -> [SwiftTypeDecl] {
        var result: [SwiftTypeDecl] = []
        func visit(_ decl: SwiftTypeDecl) {
            result.append(decl)
            for nested in decl.nestedTypes {
                visit(nested)
            }
        }
        for decl in types {
            visit(decl)
        }
        return result
    }

    /// Returns the primary SwiftUI `View` type declared in this file, if any.
    public var primaryViewType: SwiftTypeDecl? {
        allTypesFlattened().first { $0.isSwiftUIView && $0.kind == .struct }
            ?? allTypesFlattened().first { $0.isSwiftUIView }
    }

    /// Collects every `SwiftViewNode` across all `View` types, `@ViewBuilder` functions, and `#Preview` blocks.
    public func allViewNodes() -> [SwiftViewNode] {
        var nodes: [SwiftViewNode] = []
        for typeDecl in allTypesFlattened() {
            for prop in typeDecl.properties {
                for root in prop.computedViewBody {
                    nodes.append(contentsOf: root.flattenedNodes())
                }
            }
            for fn in typeDecl.functions {
                for root in fn.viewBody {
                    nodes.append(contentsOf: root.flattenedNodes())
                }
            }
        }
        for preview in previews {
            for root in preview.viewNodes {
                nodes.append(contentsOf: root.flattenedNodes())
            }
        }
        return nodes
    }
}
