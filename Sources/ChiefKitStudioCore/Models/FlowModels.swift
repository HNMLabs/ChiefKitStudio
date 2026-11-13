import Foundation

public struct FlowDiagnostic: Identifiable, Equatable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case error
        case warning
        case valid
    }

    public let id: String
    public let severity: Severity
    public let message: String

    public init(id: String, severity: Severity, message: String) {
        self.id = id
        self.severity = severity
        self.message = message
    }
}

public struct FlowTransitionEdge: Identifiable, Equatable, Sendable {
    public var id: String { "\(fromID)->\(toID):\(trigger)" }
    public let fromID: String
    public let toID: String
    public let trigger: String
}

public struct FlowPage: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var style: String
    public var actions: [String]

    public init(id: String, title: String, body: String, style: String, actions: [String]) {
        self.id = id
        self.title = title
        self.body = body
        self.style = style
        self.actions = actions
    }
}

public struct FlowDefinition: Codable, Hashable, Sendable {
    public var title: String
    public var pages: [FlowPage]

    public init(title: String, pages: [FlowPage]) {
        self.title = title
        self.pages = pages
    }

    public static func decode(_ text: String) -> Result<FlowDefinition, Error> {
        Result {
            let data = Data(text.utf8)
            return try JSONDecoder().decode(FlowDefinition.self, from: data)
        }
    }

    public func encodedPrettyJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    /// Computes linear + multi-action transition topology edges for visual graph rendering.
    public var topologyEdges: [FlowTransitionEdge] {
        guard pages.count >= 2 else { return [] }
        var edges: [FlowTransitionEdge] = []
        for idx in 0..<(pages.count - 1) {
            let source = pages[idx]
            let next = pages[idx + 1]
            let trigger = source.actions.isEmpty ? "(none)" : source.actions.joined(separator: " | ")
            edges.append(FlowTransitionEdge(fromID: source.id, toID: next.id, trigger: trigger))
        }
        return edges
    }

    /// Validates ID uniqueness, non-empty actions, titles, and completion terminal screen.
    public func validate() -> [FlowDiagnostic] {
        var diagnostics: [FlowDiagnostic] = []

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            diagnostics.append(FlowDiagnostic(id: "empty-title", severity: .warning, message: "Flow title is empty."))
        }

        if pages.isEmpty {
            diagnostics.append(FlowDiagnostic(id: "no-pages", severity: .error, message: "Flow has zero pages. Add at least one screen."))
            return diagnostics
        }

        var seenIDs = Set<String>()
        for (idx, page) in pages.enumerated() {
            let cleanID = page.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanID.isEmpty {
                diagnostics.append(FlowDiagnostic(id: "blank-id-\(idx)", severity: .error, message: "Screen #\(idx + 1) has a blank ID."))
            } else if !seenIDs.insert(cleanID).inserted {
                diagnostics.append(FlowDiagnostic(id: "dup-id-\(cleanID)-\(idx)", severity: .error, message: "Duplicate screen ID '\(cleanID)' detected."))
            }

            if page.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(FlowDiagnostic(id: "empty-page-title-\(idx)", severity: .warning, message: "Screen '\(page.id)' has an empty title."))
            }

            if page.actions.isEmpty {
                diagnostics.append(FlowDiagnostic(id: "no-actions-\(idx)", severity: .error, message: "Screen '\(page.id)' has no action buttons — user cannot advance."))
            }
        }

        if let last = pages.last, last.style.lowercased() != "completion" {
            diagnostics.append(
                FlowDiagnostic(
                    id: "missing-completion",
                    severity: .warning,
                    message: "Final screen '\(last.id)' uses style '\(last.style)' instead of 'completion'."
                )
            )
        }

        if diagnostics.isEmpty {
            diagnostics.append(
                FlowDiagnostic(
                    id: "flow-valid",
                    severity: .valid,
                    message: "All \(pages.count) screens validated cleanly (\(topologyEdges.count) transitions)."
                )
            )
        }

        return diagnostics
    }

    public static let fallback = FlowDefinition(
        title: "Welcome Flow",
        pages: [
            FlowPage(
                id: "intro",
                title: "Build faster",
                body: "Compose onboarding screens from JSON and render them natively.",
                style: "completion",
                actions: ["Continue"]
            )
        ]
    )
}
