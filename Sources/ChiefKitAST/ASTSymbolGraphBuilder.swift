import ChiefKitStudioCore
import Foundation

// MARK: - Cross-File Symbol Graph Models

/// Architectural role of a node inside a `SymbolGraph`.
public enum SymbolGraphNodeKind: String, Codable, Hashable, CaseIterable, Sendable {
    case swiftUIView
    case observableModel
    case reducer
    case structType
    case classType
    case actorType
    case enumType
    case protocolType
    case extensionBlock
}

/// Directed relationship kind connecting two `SymbolGraphNode` vertices.
public enum SymbolGraphEdgeKind: String, Codable, Hashable, CaseIterable, Sendable {
    case conformsTo
    case inheritsFrom
    case composesProperty
    case rendersChildView
    case mutatesOrReduces
    case nestedType
}

/// Vertex in a cross-file Swift 6 `SymbolGraph`.
public struct SymbolGraphNode: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let kind: SymbolGraphNodeKind
    public let accessLevel: SwiftAccessLevel
    public let filePath: String?
    public let conformances: [String]
    public let propertySignatures: [String]
    public let methodSignatures: [String]
    public let isSendable: Bool
    public let isMainActor: Bool

    public init(
        id: String,
        name: String,
        kind: SymbolGraphNodeKind,
        accessLevel: SwiftAccessLevel,
        filePath: String? = nil,
        conformances: [String] = [],
        propertySignatures: [String] = [],
        methodSignatures: [String] = [],
        isSendable: Bool = false,
        isMainActor: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.accessLevel = accessLevel
        self.filePath = filePath
        self.conformances = conformances
        self.propertySignatures = propertySignatures
        self.methodSignatures = methodSignatures
        self.isSendable = isSendable
        self.isMainActor = isMainActor
    }
}

/// Directed edge between two symbols in a `SymbolGraph`.
public struct SymbolGraphEdge: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(sourceID)->\(kind.rawValue)->\(targetID)" }
    public let sourceID: String
    public let targetID: String
    public let kind: SymbolGraphEdgeKind
    public let detailLabel: String?

    public init(sourceID: String, targetID: String, kind: SymbolGraphEdgeKind, detailLabel: String? = nil) {
        self.sourceID = sourceID
        self.targetID = targetID
        self.kind = kind
        self.detailLabel = detailLabel
    }
}

/// Complete cross-file architectural graph with Mermaid diagram and JSON index exporters.
public struct SymbolGraph: Codable, Equatable, Sendable {
    public let nodes: [SymbolGraphNode]
    public let edges: [SymbolGraphEdge]
    public let importedModules: [String]

    public init(nodes: [SymbolGraphNode], edges: [SymbolGraphEdge], importedModules: [String]) {
        self.nodes = nodes.sorted { $0.id < $1.id }
        self.edges = Array(Set(edges)).sorted { $0.id < $1.id }
        self.importedModules = Array(Set(importedModules)).sorted()
    }

    public func outgoingEdges(from symbolID: String) -> [SymbolGraphEdge] {
        edges.filter { $0.sourceID == symbolID }
    }

    public func incomingEdges(to symbolID: String) -> [SymbolGraphEdge] {
        edges.filter { $0.targetID == symbolID }
    }

    /// Detects strongly-coupled dependency cycles among declared symbols via 3-color DFS.
    public func detectCycles() -> [[String]] {
        let validNodeIDs = Set(nodes.map(\.id))
        var adj: [String: [String]] = [:]
        for edge in edges where validNodeIDs.contains(edge.sourceID) && validNodeIDs.contains(edge.targetID) && edge.sourceID != edge.targetID {
            adj[edge.sourceID, default: []].append(edge.targetID)
        }

        enum VisitState { case unvisited, visiting, visited }
        var state: [String: VisitState] = [:]
        var stack: [String] = []
        var cycles: [[String]] = []

        func dfs(_ u: String) {
            state[u] = .visiting
            stack.append(u)
            for v in (adj[u] ?? []) {
                let st = state[v, default: .unvisited]
                if st == .visiting {
                    if let idx = stack.firstIndex(of: v) {
                        cycles.append(Array(stack[idx...]) + [v])
                    }
                } else if st == .unvisited {
                    dfs(v)
                }
            }
            _ = stack.popLast()
            state[u] = .visited
        }

        for node in nodes where state[node.id, default: .unvisited] == .unvisited {
            dfs(node.id)
        }
        return cycles
    }

    /// Computes a Kahn topological ordering of symbol IDs (appending any cyclic nodes deterministically).
    public func topologicalOrder() -> [String] {
        let validIDs = Set(nodes.map(\.id))
        var inDegree: [String: Int] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        var dependents: [String: [String]] = [:]

        for edge in edges where validIDs.contains(edge.sourceID) && validIDs.contains(edge.targetID) && edge.sourceID != edge.targetID {
            // If A depends on B (`sourceID -> targetID`), B precedes A in dependency build order
            inDegree[edge.sourceID, default: 0] += 1
            dependents[edge.targetID, default: []].append(edge.sourceID)
        }

        var queue = inDegree.filter { $0.value == 0 }.map(\.key).sorted()
        var ordered: [String] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            ordered.append(current)
            for dep in (dependents[current] ?? []).sorted() {
                inDegree[dep, default: 1] -= 1
                if inDegree[dep] == 0 {
                    queue.append(dep)
                    queue.sort()
                }
            }
        }

        if ordered.count < nodes.count {
            let seen = Set(ordered)
            for node in nodes where !seen.contains(node.id) {
                ordered.append(node.id)
            }
        }
        return ordered
    }

    // MARK: Mermaid `classDiagram` Exporter

    /// Exports a valid Mermaid `classDiagram` depicting types, stereotypes, properties, methods, and relationships.
    public func exportMermaidClassDiagram() -> String {
        var lines = ["classDiagram"]

        for node in nodes {
            let safeID = sanitizeMermaidID(node.id)
            lines.append("    class \(safeID) {")
            lines.append("        <<\(stereotype(for: node.kind))>>")
            for prop in node.propertySignatures.prefix(8) {
                lines.append("        +\(sanitizeMermaidMember(prop))")
            }
            for fn in node.methodSignatures.prefix(8) {
                lines.append("        +\(sanitizeMermaidMember(fn))")
            }
            lines.append("    }")
        }

        for edge in edges {
            let src = sanitizeMermaidID(edge.sourceID)
            let dst = sanitizeMermaidID(edge.targetID)
            guard !src.isEmpty && !dst.isEmpty && src != dst else { continue }

            switch edge.kind {
            case .inheritsFrom:
                lines.append("    \(dst) <|-- \(src) : inherits")
            case .conformsTo:
                lines.append("    \(dst) <|.. \(src) : conforms")
            case .composesProperty:
                let lbl = edge.detailLabel.map { " : \(sanitizeMermaidMember($0))" } ?? " : has"
                lines.append("    \(src) *-- \(dst)\(lbl)")
            case .rendersChildView:
                lines.append("    \(src) --> \(dst) : renders")
            case .mutatesOrReduces:
                lines.append("    \(src) ..> \(dst) : reduces")
            case .nestedType:
                lines.append("    \(src) +-- \(dst) : nested")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: Mermaid `flowchart TD` Exporter

    /// Exports a valid Mermaid `flowchart TD` architecture & view-hierarchy diagram with quoted labels.
    public func exportMermaidFlowchartTD() -> String {
        var lines = ["flowchart TD"]

        for node in nodes {
            let safeID = sanitizeMermaidID(node.id)
            let badge = stereotype(for: node.kind)
            let isolationTag = node.isMainActor ? " @MainActor" : (node.isSendable ? " Sendable" : "")
            let quotedLabel = "\"\(escapeQuotes(node.name)) (\(badge)\(isolationTag))\""
            lines.append("    \(safeID)[\(quotedLabel)]")
        }

        let declaredIDs = Set(nodes.map { sanitizeMermaidID($0.id) })
        for edge in edges {
            let src = sanitizeMermaidID(edge.sourceID)
            let dst = sanitizeMermaidID(edge.targetID)
            guard !src.isEmpty && !dst.isEmpty && src != dst else { continue }

            // Ensure external protocol/view nodes also have quoted definitions if referenced
            if !declaredIDs.contains(dst) {
                lines.append("    \(dst)[\"\(escapeQuotes(edge.targetID))\"]")
            }

            let edgeVerb: String
            switch edge.kind {
            case .conformsTo: edgeVerb = "conforms"
            case .inheritsFrom: edgeVerb = "inherits"
            case .composesProperty: edgeVerb = edge.detailLabel ?? "composes"
            case .rendersChildView: edgeVerb = "renders"
            case .mutatesOrReduces: edgeVerb = "reduces"
            case .nestedType: edgeVerb = "contains"
            }
            lines.append("    \(src) -->|\"\(escapeQuotes(edgeVerb))\"| \(dst)")
        }

        return lines.joined(separator: "\n")
    }

    /// Serializes the symbol graph as a structured JSON symbol index.
    public func exportJSONIndex(prettyPrinted: Bool = true) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted
            ? [.prettyPrinted, .sortedKeys]
            : [.sortedKeys]
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func stereotype(for kind: SymbolGraphNodeKind) -> String {
        switch kind {
        case .swiftUIView: return "View"
        case .observableModel: return "Observable"
        case .reducer: return "Reducer"
        case .structType: return "Struct"
        case .classType: return "Class"
        case .actorType: return "Actor"
        case .enumType: return "Enum"
        case .protocolType: return "Protocol"
        case .extensionBlock: return "Extension"
        }
    }

    private func sanitizeMermaidID(_ raw: String) -> String {
        let mapped = raw.replacingOccurrences(of: ".", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return mapped.isEmpty ? "Symbol" : mapped
    }

    private func sanitizeMermaidMember(_ raw: String) -> String {
        raw.replacingOccurrences(of: "{", with: "(")
            .replacingOccurrences(of: "}", with: ")")
            .replacingOccurrences(of: "<", with: "~")
            .replacingOccurrences(of: ">", with: "~")
    }

    private func escapeQuotes(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\"", with: "'")
    }
}

// MARK: - AST Symbol Graph Builder Engine

/// Constructs cross-file `SymbolGraph` instances from parsed `SwiftSourceFile` ASTs or raw Swift source files.
public enum ASTSymbolGraphBuilder: Sendable {
    public static func build(from source: String, filePath: String? = nil) -> SymbolGraph {
        let ast = SwiftUIParser.parse(source: source, filePath: filePath)
        return build(from: [ast])
    }

    public static func build(from sources: [(filePath: String, code: String)]) -> SymbolGraph {
        let parsed = sources.map { SwiftUIParser.parse(source: $0.code, filePath: $0.filePath) }
        return build(from: parsed)
    }

    public static func build(from files: [SwiftSourceFile]) -> SymbolGraph {
        var nodesByID: [String: SymbolGraphNode] = [:]
        var edges: [SymbolGraphEdge] = []
        var modules: [String] = []

        let standardIgnoredTypes: Set<String> = [
            "String", "Int", "Int64", "Double", "Float", "Bool", "UUID", "Date", "Data", "URL",
            "CGFloat", "CGSize", "CGRect", "Void", "Any", "Sendable", "Codable", "Equatable",
            "Hashable", "Identifiable", "CaseIterable", "Error", "CustomStringConvertible"
        ]
        let standardBuiltInViews: Set<String> = [
            "VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack", "ScrollView", "List",
            "Form", "Section", "Group", "Text", "Label", "Image", "Button", "TextField",
            "SecureField", "Toggle", "Spacer", "Divider", "if", "switch", "ForEach",
            "GeometryReader", "NavigationStack", "NavigationSplitView", "TabView"
        ]

        // Pass 1: Collect all nominal type nodes across all files
        for file in files {
            modules.append(contentsOf: file.imports.map(\.fullModulePath))
            for topType in file.types {
                registerTypeRecursive(topType, parentPrefix: nil, filePath: file.filePath, into: &nodesByID, edgesOut: &edges)
            }
        }

        let knownDeclaredNames = Set(nodesByID.values.map(\.name))

        // Pass 2: Extract conformance, inheritance, property composition, reducer, and view-hierarchy edges
        for file in files {
            for decl in file.allTypesFlattened() {
                let srcID = nodesByID[decl.name]?.id ?? decl.name

                // 1. Inheritance & conformance edges
                for (idx, rawConf) in decl.conformances.enumerated() {
                    let cleanConf = extractBaseTypeName(rawConf)
                    guard !cleanConf.isEmpty && !standardIgnoredTypes.contains(cleanConf) else { continue }
                    let edgeKind: SymbolGraphEdgeKind = (decl.kind == .class && idx == 0 && cleanConf != "View" && cleanConf != "ObservableObject")
                        ? .inheritsFrom
                        : .conformsTo
                    edges.append(SymbolGraphEdge(sourceID: srcID, targetID: cleanConf, kind: edgeKind))
                }

                // 2. Stored property composition edges
                for prop in decl.properties where !prop.isComputed {
                    let candidateTypes = extractReferencedTypeNames(from: prop)
                    for targetType in candidateTypes where knownDeclaredNames.contains(targetType) && targetType != decl.name {
                        edges.append(
                            SymbolGraphEdge(
                                sourceID: srcID,
                                targetID: targetType,
                                kind: .composesProperty,
                                detailLabel: prop.name
                            )
                        )
                    }
                }

                // 3. Reducer -> State / Action edges
                for fn in decl.functions where fn.name == "reduce" {
                    for param in fn.parameters {
                        let baseType = extractBaseTypeName(param.typeName)
                        if knownDeclaredNames.contains(baseType) {
                            edges.append(
                                SymbolGraphEdge(
                                    sourceID: srcID,
                                    targetID: baseType,
                                    kind: .mutatesOrReduces,
                                    detailLabel: param.internalName
                                )
                            )
                        }
                    }
                }

                // 4. SwiftUI View -> child subview edges
                for viewNode in decl.bodyViewNodes.flatMap({ $0.flattenedNodes() }) {
                    let comp = viewNode.componentName
                    guard !standardBuiltInViews.contains(comp),
                          comp.first?.isUppercase == true,
                          comp != decl.name else {
                        continue
                    }
                    edges.append(
                        SymbolGraphEdge(
                            sourceID: srcID,
                            targetID: comp,
                            kind: .rendersChildView
                        )
                    )
                }
            }
        }

        return SymbolGraph(
            nodes: Array(nodesByID.values),
            edges: edges,
            importedModules: modules
        )
    }

    private static func registerTypeRecursive(
        _ decl: SwiftTypeDecl,
        parentPrefix: String?,
        filePath: String?,
        into map: inout [String: SymbolGraphNode],
        edgesOut: inout [SymbolGraphEdge]
    ) {
        let qualifiedID = parentPrefix.map { "\($0).\(decl.name)" } ?? decl.name
        let nodeKind = classifyNodeKind(decl)

        let propSigs = decl.properties.filter { !$0.isComputed }.map { p in
            "\(p.name): \(p.typeAnnotation ?? "Any")"
        }
        let fnSigs = decl.functions.map { fn in
            let params = fn.parameters.map { "\($0.internalName): \($0.typeName)" }.joined(separator: ", ")
            let ret = fn.returnType.map { " -> \($0)" } ?? ""
            return "\(fn.name)(\(params))\(ret)"
        }

        let graphNode = SymbolGraphNode(
            id: qualifiedID,
            name: decl.name,
            kind: nodeKind,
            accessLevel: decl.accessLevel,
            filePath: filePath,
            conformances: decl.conformances,
            propertySignatures: propSigs,
            methodSignatures: fnSigs,
            isSendable: decl.conformsToSendable,
            isMainActor: decl.isMainActorIsolated
        )
        map[decl.name] = graphNode

        if let parentPrefix {
            edgesOut.append(SymbolGraphEdge(sourceID: parentPrefix, targetID: qualifiedID, kind: .nestedType))
        }

        for nested in decl.nestedTypes {
            registerTypeRecursive(nested, parentPrefix: qualifiedID, filePath: filePath, into: &map, edgesOut: &edgesOut)
        }
    }

    private static func classifyNodeKind(_ decl: SwiftTypeDecl) -> SymbolGraphNodeKind {
        if decl.isSwiftUIView { return .swiftUIView }
        if decl.hasObservableMacro || decl.isLegacyObservableObject { return .observableModel }
        if decl.name.hasSuffix("Reducer") || decl.functions.contains(where: { $0.name == "reduce" }) {
            return .reducer
        }
        switch decl.kind {
        case .struct: return .structType
        case .class: return .classType
        case .actor: return .actorType
        case .enum: return .enumType
        case .protocol: return .protocolType
        case .extension: return .extensionBlock
        }
    }

    private static func extractReferencedTypeNames(from prop: SwiftPropertyDecl) -> [String] {
        var result: [String] = []
        if let ann = prop.typeAnnotation {
            let tokens = ann.split { !$0.isLetter && !$0.isNumber && $0 != "_" }.map(String.init)
            result.append(contentsOf: tokens)
        }
        if case .call(let callee, _, _) = prop.initializer {
            let name = callee.renderedDescription
            if name.first?.isUppercase == true {
                result.append(name)
            }
        }
        return result
    }

    private static func extractBaseTypeName(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "@unchecked", with: "")
            .replacingOccurrences(of: "@preconcurrency", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let genericStart = stripped.firstIndex(of: "<") {
            return String(stripped[..<genericStart]).trimmingCharacters(in: .whitespaces)
        }
        return stripped
    }
}
