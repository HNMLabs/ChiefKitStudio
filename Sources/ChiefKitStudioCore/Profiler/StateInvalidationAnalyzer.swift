import Foundation

// MARK: - Reactive Property Kinds & Graph Models

public enum StatePropertyKind: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case state = "@State"
    case binding = "@Binding"
    case observedObject = "@ObservedObject"
    case stateObject = "@StateObject"
    case environmentObject = "@EnvironmentObject"
    case environment = "@Environment"
    case observable = "@Observable"

    public var id: String { rawValue }

    /// `ObservableObject` wrappers broadcast `objectWillChange` on ANY `@Published` mutation, invalidating every subscriber.
    public var triggersCoarseObjectBroadcast: Bool {
        switch self {
        case .observedObject, .stateObject, .environmentObject:
            return true
        case .state, .binding, .environment, .observable:
            return false
        }
    }
}

public struct DiscoveredStateProperty: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(ownerTypeName).\(propertyName)" }
    public var ownerTypeName: String
    public var propertyName: String
    public var valueTypeName: String
    public var kind: StatePropertyKind
    public var lineNumber: Int

    public init(
        ownerTypeName: String,
        propertyName: String,
        valueTypeName: String,
        kind: StatePropertyKind,
        lineNumber: Int
    ) {
        self.ownerTypeName = ownerTypeName
        self.propertyName = propertyName
        self.valueTypeName = valueTypeName
        self.kind = kind
        self.lineNumber = lineNumber
    }
}

public struct DiscoveredViewComponent: Identifiable, Codable, Hashable, Sendable {
    public var id: String { viewName }
    public var viewName: String
    public var startLine: Int
    public var endLine: Int
    public var declaredProperties: [DiscoveredStateProperty]
    public var readSymbols: [String]
    public var mutatedSymbols: [String]
    public var childViewNames: [String]

    public init(
        viewName: String,
        startLine: Int,
        endLine: Int,
        declaredProperties: [DiscoveredStateProperty],
        readSymbols: [String],
        mutatedSymbols: [String],
        childViewNames: [String]
    ) {
        self.viewName = viewName
        self.startLine = startLine
        self.endLine = endLine
        self.declaredProperties = declaredProperties
        self.readSymbols = readSymbols
        self.mutatedSymbols = mutatedSymbols
        self.childViewNames = childViewNames
    }
}

public enum InvalidationAccessKind: String, Codable, Hashable, Sendable {
    case read
    case mutation
    case projectedBinding
    case coarseObjectWillChange
}

public struct InvalidationEdge: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(sourceSymbol)->\(targetViewName):\(accessKind.rawValue)" }
    public var sourceSymbol: String
    public var targetViewName: String
    public var accessKind: InvalidationAccessKind

    public init(sourceSymbol: String, targetViewName: String, accessKind: InvalidationAccessKind) {
        self.sourceSymbol = sourceSymbol
        self.targetViewName = targetViewName
        self.accessKind = accessKind
    }
}

public struct ActionBlastRadiusMetric: Identifiable, Codable, Hashable, Sendable {
    public var id: String { triggerSymbol }
    public var triggerSymbol: String
    public var kind: StatePropertyKind
    public var invalidatedViews: [String]
    public var totalViewCount: Int
    public var blastRadiusPercent: Double
    public var isCoarseBroadcast: Bool

    public init(
        triggerSymbol: String,
        kind: StatePropertyKind,
        invalidatedViews: [String],
        totalViewCount: Int,
        isCoarseBroadcast: Bool
    ) {
        self.triggerSymbol = triggerSymbol
        self.kind = kind
        self.invalidatedViews = invalidatedViews
        self.totalViewCount = max(1, totalViewCount)
        let pct = (Double(invalidatedViews.count) / Double(max(1, totalViewCount))) * 100.0
        self.blastRadiusPercent = (pct * 10.0).rounded() / 10.0
        self.isCoarseBroadcast = isCoarseBroadcast
    }
}

public enum StateInvalidationAntiPatternKind: String, CaseIterable, Codable, Hashable, Sendable {
    case coarseEnvironmentObjectBroadcast
    case unownedObservedObjectAllocation
    case monolithicRootViewState
    case coarseStateObjectStore
    case unreadDeclaredState
}

public struct SubviewDecompositionSuggestion: Codable, Hashable, Sendable {
    public var suggestedSubviewName: String
    public var isolatedProperties: [String]
    public var refactoredSwiftSnippet: String
    public var expectedBlastRadiusReductionPercent: Double

    public init(
        suggestedSubviewName: String,
        isolatedProperties: [String],
        refactoredSwiftSnippet: String,
        expectedBlastRadiusReductionPercent: Double
    ) {
        self.suggestedSubviewName = suggestedSubviewName
        self.isolatedProperties = isolatedProperties
        self.refactoredSwiftSnippet = refactoredSwiftSnippet
        self.expectedBlastRadiusReductionPercent = expectedBlastRadiusReductionPercent
    }
}

public struct StateInvalidationFinding: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var viewName: String
    public var symbolName: String
    public var kind: StateInvalidationAntiPatternKind
    public var severity: SchemaDiagnosticSeverity
    public var blastRadiusPercent: Double
    public var explanation: String
    public var suggestion: SubviewDecompositionSuggestion

    public init(
        id: String,
        viewName: String,
        symbolName: String,
        kind: StateInvalidationAntiPatternKind,
        severity: SchemaDiagnosticSeverity,
        blastRadiusPercent: Double,
        explanation: String,
        suggestion: SubviewDecompositionSuggestion
    ) {
        self.id = id
        self.viewName = viewName
        self.symbolName = symbolName
        self.kind = kind
        self.severity = severity
        self.blastRadiusPercent = blastRadiusPercent
        self.explanation = explanation
        self.suggestion = suggestion
    }
}

public struct StateInvalidationReport: Codable, Hashable, Sendable {
    public var views: [DiscoveredViewComponent]
    public var observableModelNames: [String]
    public var edges: [InvalidationEdge]
    public var blastRadiusMetrics: [ActionBlastRadiusMetric]
    public var averageBlastRadiusPercent: Double
    public var worstBlastRadiusPercent: Double
    public var findings: [StateInvalidationFinding]
    public var mermaidFlowchartLR: String

    public init(
        views: [DiscoveredViewComponent],
        observableModelNames: [String],
        edges: [InvalidationEdge],
        blastRadiusMetrics: [ActionBlastRadiusMetric],
        findings: [StateInvalidationFinding],
        mermaidFlowchartLR: String
    ) {
        self.views = views
        self.observableModelNames = observableModelNames
        self.edges = edges
        self.blastRadiusMetrics = blastRadiusMetrics
        if blastRadiusMetrics.isEmpty {
            self.averageBlastRadiusPercent = 0
            self.worstBlastRadiusPercent = 0
        } else {
            let sum = blastRadiusMetrics.reduce(0.0) { $0 + $1.blastRadiusPercent }
            self.averageBlastRadiusPercent = ((sum / Double(blastRadiusMetrics.count)) * 10.0).rounded() / 10.0
            self.worstBlastRadiusPercent = blastRadiusMetrics.map(\.blastRadiusPercent).max() ?? 0
        }
        self.findings = findings
        self.mermaidFlowchartLR = mermaidFlowchartLR
    }
}

// MARK: - StateInvalidationAnalyzer Engine

public enum StateInvalidationAnalyzer {

    public static func analyze(swiftSource: String) -> StateInvalidationReport {
        let lines = swiftSource.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let observableModels = scanObservableModels(lines: lines)
        let rawViewBlocks = extractViewStructBlocks(lines: lines)
        let allViewNames = Set(rawViewBlocks.map(\.name))

        var components: [DiscoveredViewComponent] = []
        var edges: [InvalidationEdge] = []
        var findings: [StateInvalidationFinding] = []

        for block in rawViewBlocks {
            let slice = Array(lines[(block.startLine - 1)..<block.endLine])
            var props = scanProperties(in: slice, baseLineNumber: block.startLine, ownerName: block.name, observableModels: observableModels)

            // Detect inline `@ObservedObject var vm = ViewModel()` ownership bug
            for prop in props where prop.kind == .observedObject {
                let declLine = lines[prop.lineNumber - 1]
                if declLine.contains("=") && declLine.contains("(") {
                    findings.append(
                        StateInvalidationFinding(
                            id: "finding-unowned-obs-\(block.name)-\(prop.propertyName)",
                            viewName: block.name,
                            symbolName: prop.propertyName,
                            kind: .unownedObservedObjectAllocation,
                            severity: .error,
                            blastRadiusPercent: 100.0,
                            explanation: "`@ObservedObject var \(prop.propertyName)` instantiates an object inline; parent re-renders will destroy and recreate it.",
                            suggestion: SubviewDecompositionSuggestion(
                                suggestedSubviewName: block.name,
                                isolatedProperties: [prop.propertyName],
                                refactoredSwiftSnippet: "@State private var \(prop.propertyName) = \(prop.valueTypeName)()",
                                expectedBlastRadiusReductionPercent: 45.0
                            )
                        )
                    )
                }
            }

            // Also detect plain stored properties whose type is an @Observable class
            let declaredNames = Set(props.map(\.propertyName))
            for (offset, line) in slice.enumerated() {
                if let obsProp = scanPlainObservableReference(line: line, lineNumber: block.startLine + offset, ownerName: block.name, observableModels: observableModels),
                   !declaredNames.contains(obsProp.propertyName) {
                    props.append(obsProp)
                }
            }

            let bodyText = slice.joined(separator: "\n")
            var reads: [String] = []
            var mutations: [String] = []

            for prop in props {
                let pName = prop.propertyName
                let hasProjectedBinding = bodyText.contains("$\(pName)")
                let isMutated = detectMutation(of: pName, in: slice) || hasProjectedBinding
                let occurrenceCount = countIdentifierOccurrences(of: pName, in: bodyText)

                if occurrenceCount > 1 {
                    reads.append(pName)
                    edges.append(
                        InvalidationEdge(
                            sourceSymbol: "\(block.name).\(pName)",
                            targetViewName: block.name,
                            accessKind: prop.kind.triggersCoarseObjectBroadcast ? .coarseObjectWillChange : .read
                        )
                    )
                } else {
                    findings.append(
                        StateInvalidationFinding(
                            id: "finding-unused-\(block.name)-\(pName)",
                            viewName: block.name,
                            symbolName: pName,
                            kind: .unreadDeclaredState,
                            severity: .info,
                            blastRadiusPercent: 0.0,
                            explanation: "State property `\(pName)` (\(prop.kind.rawValue)) is never read in `\(block.name).body`.",
                            suggestion: SubviewDecompositionSuggestion(
                                suggestedSubviewName: block.name,
                                isolatedProperties: [pName],
                                refactoredSwiftSnippet: "// Remove unused \(prop.kind.rawValue) var \(pName)",
                                expectedBlastRadiusReductionPercent: 0.0
                            )
                        )
                    )
                }

                if isMutated {
                    mutations.append(pName)
                    edges.append(
                        InvalidationEdge(
                            sourceSymbol: "\(block.name).\(pName)",
                            targetViewName: block.name,
                            accessKind: hasProjectedBinding ? .projectedBinding : .mutation
                        )
                    )
                }
            }

            // Child subview instantiations inside this view
            var childViews: [String] = []
            for candidateView in allViewNames where candidateView != block.name {
                if bodyText.contains("\(candidateView)(") {
                    childViews.append(candidateView)
                }
            }

            components.append(
                DiscoveredViewComponent(
                    viewName: block.name,
                    startLine: block.startLine,
                    endLine: block.endLine,
                    declaredProperties: props,
                    readSymbols: reads.sorted(),
                    mutatedSymbols: mutations.sorted(),
                    childViewNames: childViews.sorted()
                )
            )
        }

        // Compute Blast Radius % per reactive state property
        let totalViews = max(1, components.count)
        let viewMap = Dictionary(uniqueKeysWithValues: components.map { ($0.viewName, $0) })
        var blastMetrics: [ActionBlastRadiusMetric] = []

        for comp in components {
            for prop in comp.declaredProperties {
                var invalidated = Set<String>()
                if comp.readSymbols.contains(prop.propertyName) {
                    invalidated.insert(comp.viewName)
                    if prop.kind.triggersCoarseObjectBroadcast || prop.kind == .state {
                        collectTransitiveDescendants(from: comp.viewName, viewMap: viewMap, visited: &invalidated)
                    }
                }
                if prop.kind == .environmentObject {
                    // Coarse @EnvironmentObject invalidates every view subscribing to the same object type
                    for other in components where other.declaredProperties.contains(where: { $0.kind == .environmentObject && $0.valueTypeName == prop.valueTypeName }) {
                        invalidated.insert(other.viewName)
                        collectTransitiveDescendants(from: other.viewName, viewMap: viewMap, visited: &invalidated)
                    }
                }

                let metric = ActionBlastRadiusMetric(
                    triggerSymbol: "\(comp.viewName).\(prop.propertyName)",
                    kind: prop.kind,
                    invalidatedViews: invalidated.sorted(),
                    totalViewCount: totalViews,
                    isCoarseBroadcast: prop.kind.triggersCoarseObjectBroadcast
                )
                blastMetrics.append(metric)

                // Flag anti-patterns & synthesize @Observable decomposition
                if prop.kind == .environmentObject {
                    findings.append(
                        StateInvalidationFinding(
                            id: "finding-envobj-\(comp.viewName)-\(prop.propertyName)",
                            viewName: comp.viewName,
                            symbolName: prop.propertyName,
                            kind: .coarseEnvironmentObjectBroadcast,
                            severity: .warning,
                            blastRadiusPercent: metric.blastRadiusPercent,
                            explanation: "`@EnvironmentObject var \(prop.propertyName): \(prop.valueTypeName)` invalidates \(metric.blastRadiusPercent)% of the view graph on every `@Published` mutation.",
                            suggestion: buildObservableMigrationSuggestion(viewName: comp.viewName, prop: prop)
                        )
                    )
                } else if prop.kind == .stateObject && metric.blastRadiusPercent >= 65.0 {
                    findings.append(
                        StateInvalidationFinding(
                            id: "finding-stateobj-\(comp.viewName)-\(prop.propertyName)",
                            viewName: comp.viewName,
                            symbolName: prop.propertyName,
                            kind: .coarseStateObjectStore,
                            severity: .advisory,
                            blastRadiusPercent: metric.blastRadiusPercent,
                            explanation: "`@StateObject` broadcasts coarse `objectWillChange`; migrating `\(prop.valueTypeName)` to `@Observable` restricts diffing to field-level readers.",
                            suggestion: buildObservableMigrationSuggestion(viewName: comp.viewName, prop: prop)
                        )
                    )
                }
            }

            // Detect monolithic root view holding >= 4 independent @State fields
            let localStateProps = comp.declaredProperties.filter { $0.kind == .state }
            if localStateProps.count >= 4 {
                let names = localStateProps.map(\.propertyName)
                let extractedName = "\(comp.viewName)ControlsSection"
                let snippet = """
                @Observable
                final class \(comp.viewName)PresentationModel {
                \(names.map { "    var \($0): Any" }.joined(separator: "\n"))
                }

                struct \(extractedName): View {
                    @Bindable var model: \(comp.viewName)PresentationModel
                    var body: some View { /* Fine-grained field tracking */ }
                }
                """
                findings.append(
                    StateInvalidationFinding(
                        id: "finding-monolithic-\(comp.viewName)",
                        viewName: comp.viewName,
                        symbolName: names.joined(separator: ", "),
                        kind: .monolithicRootViewState,
                        severity: .warning,
                        blastRadiusPercent: 100.0,
                        explanation: "`\(comp.viewName)` owns \(localStateProps.count) `@State` properties directly; mutating any single field re-evaluates the entire monolithic `body`.",
                        suggestion: SubviewDecompositionSuggestion(
                            suggestedSubviewName: extractedName,
                            isolatedProperties: names,
                            refactoredSwiftSnippet: snippet,
                            expectedBlastRadiusReductionPercent: 58.0
                        )
                    )
                )
            }
        }

        let mermaid = renderMermaidInvalidationGraph(components: components, edges: edges, metrics: blastMetrics)
        return StateInvalidationReport(
            views: components,
            observableModelNames: Array(observableModels).sorted(),
            edges: edges,
            blastRadiusMetrics: blastMetrics,
            findings: findings,
            mermaidFlowchartLR: mermaid
        )
    }

    // MARK: - Mermaid Flowchart LR Generator

    public static func renderMermaidInvalidationGraph(
        components: [DiscoveredViewComponent],
        edges: [InvalidationEdge],
        metrics: [ActionBlastRadiusMetric]
    ) -> String {
        var out: [String] = ["flowchart LR"]
        let metricBySymbol = Dictionary(uniqueKeysWithValues: metrics.map { ($0.triggerSymbol, $0) })

        for comp in components {
            let vNode = sanitizeMermaidID("view_\(comp.viewName)")
            out.append("    \(vNode)[\"\(comp.viewName) (View)\"]")

            for prop in comp.declaredProperties {
                let sym = "\(comp.viewName).\(prop.propertyName)"
                let sNode = sanitizeMermaidID("state_\(sym)")
                let blast = metricBySymbol[sym]?.blastRadiusPercent ?? 0
                out.append("    \(sNode)(\"\(prop.kind.rawValue) \(prop.propertyName) · \(blast)% blast\")")
            }

            for child in comp.childViewNames {
                let cNode = sanitizeMermaidID("view_\(child)")
                out.append("    \(vNode) --> \(cNode)")
            }
        }

        for edge in edges {
            let sNode = sanitizeMermaidID("state_\(edge.sourceSymbol)")
            let vNode = sanitizeMermaidID("view_\(edge.targetViewName)")
            switch edge.accessKind {
            case .read:
                out.append("    \(sNode) -->|\"reads\"| \(vNode)")
            case .coarseObjectWillChange:
                out.append("    \(sNode) ==>|\"objectWillChange (coarse)\"| \(vNode)")
            case .mutation:
                out.append("    \(vNode) -.->|\"mutates\"| \(sNode)")
            case .projectedBinding:
                out.append("    \(vNode) <-->|\"$binding\"| \(sNode)")
            }
        }

        return out.joined(separator: "\n")
    }

    // MARK: - Private Scanners & Helpers

    private static func scanObservableModels(lines: [String]) -> Set<String> {
        var models = Set<String>()
        var sawObservableMacro = false
        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("@Observable") {
                sawObservableMacro = true
                if let inlineClass = parseClassName(from: trimmed) {
                    models.insert(inlineClass)
                    sawObservableMacro = false
                }
            } else if sawObservableMacro {
                if let className = parseClassName(from: trimmed) {
                    models.insert(className)
                    sawObservableMacro = false
                } else if !trimmed.isEmpty && !trimmed.hasPrefix("@") && !trimmed.hasPrefix("//") {
                    sawObservableMacro = false
                }
            }
        }
        return models
    }

    private static func parseClassName(from line: String) -> String? {
        let pattern = #"\bclass\s+([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let r = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[r])
    }

    private static func extractViewStructBlocks(lines: [String]) -> [(name: String, startLine: Int, endLine: Int)] {
        let viewDeclPattern = #"\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*:[^{]*\bView\b"#
        guard let regex = try? NSRegularExpression(pattern: viewDeclPattern) else { return [] }

        var results: [(name: String, startLine: Int, endLine: Int)] = []
        var idx = 0
        while idx < lines.count {
            let line = lines[idx]
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, range: nsRange),
               let nameRange = Range(match.range(at: 1), in: line) {
                let viewName = String(line[nameRange])
                let startLine = idx + 1
                var braceDepth = 0
                var sawOpenBrace = false
                var endIdx = idx

                for scanIdx in idx..<lines.count {
                    for ch in lines[scanIdx] {
                        if ch == "{" {
                            braceDepth += 1
                            sawOpenBrace = true
                        } else if ch == "}" {
                            braceDepth -= 1
                        }
                    }
                    endIdx = scanIdx
                    if sawOpenBrace && braceDepth <= 0 {
                        break
                    }
                }
                results.append((viewName, startLine, endIdx + 1))
                idx = endIdx + 1
            } else {
                idx += 1
            }
        }
        return results
    }

    private static func scanProperties(
        in slice: [String],
        baseLineNumber: Int,
        ownerName: String,
        observableModels: Set<String>
    ) -> [DiscoveredStateProperty] {
        let wrapperMapping: [(token: String, kind: StatePropertyKind)] = [
            ("@EnvironmentObject", .environmentObject),
            ("@ObservedObject", .observedObject),
            ("@StateObject", .stateObject),
            ("@Environment", .environment),
            ("@Binding", .binding),
            ("@Bindable", .observable),
            ("@State", .state)
        ]

        let varPattern = #"\b(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*([A-Za-z0-9_<>\[\]\?\.]+))?"#
        guard let regex = try? NSRegularExpression(pattern: varPattern) else { return [] }

        var props: [DiscoveredStateProperty] = []
        for (offset, line) in slice.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }

            for entry in wrapperMapping where trimmed.contains(entry.token) {
                let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if let match = regex.firstMatch(in: trimmed, range: nsRange),
                   let nameR = Range(match.range(at: 1), in: trimmed) {
                    let propName = String(trimmed[nameR])
                    let explicitType = Range(match.range(at: 2), in: trimmed).map { String(trimmed[$0]) } ?? "InferredState"
                    let effectiveKind: StatePropertyKind = observableModels.contains(explicitType) ? .observable : entry.kind
                    props.append(
                        DiscoveredStateProperty(
                            ownerTypeName: ownerName,
                            propertyName: propName,
                            valueTypeName: explicitType,
                            kind: effectiveKind,
                            lineNumber: baseLineNumber + offset
                        )
                    )
                }
                break
            }
        }
        return props
    }

    private static func scanPlainObservableReference(
        line: String,
        lineNumber: Int,
        ownerName: String,
        observableModels: Set<String>
    ) -> DiscoveredStateProperty? {
        guard !observableModels.isEmpty else { return nil }
        let pattern = #"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let nameR = Range(m.range(at: 1), in: line),
              let typeR = Range(m.range(at: 2), in: line) else { return nil }
        let typeName = String(line[typeR])
        guard observableModels.contains(typeName) else { return nil }
        return DiscoveredStateProperty(
            ownerTypeName: ownerName,
            propertyName: String(line[nameR]),
            valueTypeName: typeName,
            kind: .observable,
            lineNumber: lineNumber
        )
    }

    private static func detectMutation(of identifier: String, in lines: [String]) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: identifier)
        let mutPattern = "\\b\(escaped)\\s*(?:=(?!=)|\\+=|-=|\\.toggle\\(|\\.append\\(|\\.remove)"
        guard let regex = try? NSRegularExpression(pattern: mutPattern) else { return false }
        for (idx, line) in lines.enumerated() {
            if idx == 0 || line.contains("@") { continue }
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if regex.firstMatch(in: line, range: nsRange) != nil {
                return true
            }
        }
        return false
    }

    private static func countIdentifierOccurrences(of identifier: String, in text: String) -> Int {
        let escaped = NSRegularExpression.escapedPattern(for: identifier)
        guard let regex = try? NSRegularExpression(pattern: "\\b\(escaped)\\b") else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }

    private static func collectTransitiveDescendants(
        from viewName: String,
        viewMap: [String: DiscoveredViewComponent],
        visited: inout Set<String>
    ) {
        guard let comp = viewMap[viewName] else { return }
        for child in comp.childViewNames where visited.insert(child).inserted {
            collectTransitiveDescendants(from: child, viewMap: viewMap, visited: &visited)
        }
    }

    private static func buildObservableMigrationSuggestion(
        viewName: String,
        prop: DiscoveredStateProperty
    ) -> SubviewDecompositionSuggestion {
        let subviewName = "\(viewName)\(SchemaNamingHelpers.pascalCase(prop.propertyName))SliceView"
        let snippet = """
        @Observable
        final class \(prop.valueTypeName) {
            // ObservationRegistrar tracks individual field reads per View body
        }

        struct \(subviewName): View {
            let \(prop.propertyName): \(prop.valueTypeName)
            var body: some View {
                // Only invalidates when read properties of `\(prop.propertyName)` mutate
            }
        }
        """
        return SubviewDecompositionSuggestion(
            suggestedSubviewName: subviewName,
            isolatedProperties: [prop.propertyName],
            refactoredSwiftSnippet: snippet,
            expectedBlastRadiusReductionPercent: 62.0
        )
    }

    private static func sanitizeMermaidID(_ raw: String) -> String {
        raw.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
    }
}
