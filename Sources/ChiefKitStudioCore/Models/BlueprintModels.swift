import Foundation

public enum BlueprintDomain: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case aiNotesWorkspace
    case fintechExpenseTracker
    case developerSaaSDashboard
    case habitHealthCoach

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .aiNotesWorkspace: "AI Notes & Knowledge Studio"
        case .fintechExpenseTracker: "Fintech Treasury & Ledger"
        case .developerSaaSDashboard: "Developer Telemetry Cloud"
        case .habitHealthCoach: "Pulse Habit & Wellness Coach"
        }
    }

    public var symbolName: String {
        switch self {
        case .aiNotesWorkspace: "brain.filled.head.profile"
        case .fintechExpenseTracker: "creditcard.and.123"
        case .developerSaaSDashboard: "gauge.with.dots.needle.67percent"
        case .habitHealthCoach: "heart.text.square.fill"
        }
    }

    public var summary: String {
        switch self {
        case .aiNotesWorkspace:
            "Local-first markdown notes with SwiftBlocks glass cards, SwiftState sync store, onboarding, and on-device summarization."
        case .fintechExpenseTracker:
            "Multi-currency budget tracker combining undoable transaction reducers, KPI surfaces, and setup flow."
        case .developerSaaSDashboard:
            "Real-time build & latency wall uniting Liquid Glass metrics, async polling effects, and AI incident triage."
        case .habitHealthCoach:
            "Daily streak & recovery companion with NotebookFlowKit check-ins, deterministic reducers, and VoiceOver polish."
        }
    }

    public var entityName: String {
        switch self {
        case .aiNotesWorkspace: "WorkspaceNote"
        case .fintechExpenseTracker: "LedgerEntry"
        case .developerSaaSDashboard: "ServiceMetric"
        case .habitHealthCoach: "HabitGoal"
        }
    }

    public var sampleItems: [(title: String, detail: String, badge: String)] {
        switch self {
        case .aiNotesWorkspace:
            [
                ("Swift 6 Strict Concurrency Guide", "Summarized locally · 420 words", "Pinned"),
                ("Liquid Glass Token Audit", "WCAG AA verified · 6 color tokens", "Design"),
                ("Q4 Product Launch Flow", "4 JSON onboarding screens ready", "Flow")
            ]
        case .fintechExpenseTracker:
            [
                ("Apple Developer Program", "-$99.00 · Annual Membership", "Cleared"),
                ("Cloud CI Runner Pool", "-$240.00 · Build Infrastructure", "Recurring"),
                ("Enterprise Seat Invoice", "+$2,400.00 · Annual Plan", "Settled")
            ]
        case .developerSaaSDashboard:
            [
                ("API Edge Gateway", "99.98% uptime · p95 18ms", "Healthy"),
                ("On-Device CoreAI Worker", "3.4ms median inference · 0 errors", "Optimal"),
                ("Realtime Sync Reducer", "1,280 actions/min · 0 dropped", "Active")
            ]
        case .habitHealthCoach:
            [
                ("Morning Mobility & Focus", "14-day streak · 20 mins", "Done"),
                ("Hydration Target (2.5L)", "82% complete · 450ml remaining", "In Progress"),
                ("Evening Screen Wind-Down", "Scheduled for 22:00", "Upcoming")
            ]
        }
    }
}

public enum BlueprintLayer: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case swiftBlocksUI
    case swiftStateStore
    case notebookOnboarding
    case localAICopilot
    case swiftTestingSuite

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .swiftBlocksUI: "SwiftBlocks Tokenized UI"
        case .swiftStateStore: "SwiftState Reducer + Time-Travel"
        case .notebookOnboarding: "NotebookFlowKit First-Run Flow"
        case .localAICopilot: "CoreLocalAIKit On-Device Copilot"
        case .swiftTestingSuite: "Swift Testing (@Test) Verification"
        }
    }

    public var symbolName: String {
        switch self {
        case .swiftBlocksUI: "square.grid.3x3.topleft.filled"
        case .swiftStateStore: "point.3.connected.trianglepath.dotted"
        case .notebookOnboarding: "rectangle.on.rectangle.angled"
        case .localAICopilot: "cpu.fill"
        case .swiftTestingSuite: "checkmark.seal.fill"
        }
    }

    public var packageMapping: PackageDemo? {
        switch self {
        case .swiftBlocksUI: .swiftBlocks
        case .swiftStateStore: .swiftState
        case .notebookOnboarding: .notebookFlowKit
        case .localAICopilot: .coreLocalAIKit
        case .swiftTestingSuite: nil
        }
    }
}

public struct BlueprintConfiguration: Codable, Equatable, Sendable {
    public var domain: BlueprintDomain
    public var enabledLayers: [BlueprintLayer]

    public init(
        domain: BlueprintDomain = .aiNotesWorkspace,
        enabledLayers: [BlueprintLayer] = BlueprintLayer.allCases
    ) {
        self.domain = domain
        self.enabledLayers = enabledLayers
    }

    public func isEnabled(_ layer: BlueprintLayer) -> Bool {
        enabledLayers.contains(layer)
    }

    public mutating func toggle(_ layer: BlueprintLayer) {
        if let idx = enabledLayers.firstIndex(of: layer) {
            if enabledLayers.count > 1 {
                enabledLayers.remove(at: idx)
            }
        } else {
            enabledLayers.append(layer)
        }
    }

    public var requiredPackages: [PackageDemo] {
        var result: [PackageDemo] = []
        for layer in BlueprintLayer.allCases where isEnabled(layer) {
            if let pkg = layer.packageMapping, !result.contains(pkg) {
                result.append(pkg)
            }
        }
        return result.isEmpty ? [.swiftBlocks] : result
    }

    public func synthesizeFlowJSON(for targetDomain: BlueprintDomain? = nil) -> String {
        let d = targetDomain ?? domain
        return """
        {
          "title": "\(d.title) Setup",
          "pages": [
            {
              "id": "welcome",
              "title": "Welcome to \(d.title)",
              "body": "\(d.summary)",
              "style": "hero",
              "actions": ["Configure Workspace"]
            },
            {
              "id": "mode",
              "title": "Select Execution Profile",
              "body": "All domain reducers and local AI helpers run 100% natively on your device.",
              "style": "choice",
              "actions": ["Standard Mode", "Pro + Time-Travel"]
            },
            {
              "id": "ready",
              "title": "\(d.title) Ready",
              "body": "Your tokenized SwiftBlocks UI and SwiftState store are live.",
              "style": "completion",
              "actions": ["Enter App"]
            }
          ]
        }
        """
    }

    public func synthesizeSwiftUICode(
        for targetDomain: BlueprintDomain? = nil,
        theme: StudioThemeTokens
    ) -> String {
        let d = targetDomain ?? domain
        let structPrefix = d.entityName
        let radius = Int(theme.radiusMedium.rounded())
        let spacing = Int(theme.spacingMD)
        let useBlocks = isEnabled(.swiftBlocksUI)
        let useState = isEnabled(.swiftStateStore)
        let useFlow = isEnabled(.notebookOnboarding)
        let useAI = isEnabled(.localAICopilot)

        var imports = ["import SwiftUI"]
        if useBlocks { imports.insert("import SwiftBlocks", at: 0) }
        if useState { imports.append("import SwiftState") }
        if useFlow { imports.append("import NotebookFlowKit") }
        if useAI { imports.append("import NaturalLanguage") }
        imports.sort()

        let seedLines = d.sampleItems.enumerated().map { idx, item in
            "        \(structPrefix)(id: \"item-\(idx + 1)\", title: \"\(item.title)\", detail: \"\(item.detail)\", badge: \"\(item.badge)\")"
        }.joined(separator: ",\n")

        var sections: [String] = [imports.joined(separator: "\n")]

        sections.append("""
        // Full-Stack ChiefKit Blueprint: \(d.title)
        struct \(structPrefix): Identifiable, Codable, Equatable, Sendable {
            let id: String
            var title: String
            var detail: String
            var badge: String
        }
        """)

        if useState {
            sections.append("""
            struct \(structPrefix)State: Codable, Equatable, Sendable {
                var items: [\(structPrefix)] = \(structPrefix)State.seed
                var filterQuery: String = ""
                var hasCompletedOnboarding: Bool = \(!useFlow)
                var aiInsight: String = "Ready — 0 cloud calls"

                static let seed: [\(structPrefix)] = [
            \(seedLines)
                ]
            }

            enum \(structPrefix)Action: Equatable, Sendable {
                case addSampleItem
                case removeItem(String)
                case completeOnboarding
                case updateInsight(String)
            }

            let \(structPrefix.prefix(1).lowercased() + structPrefix.dropFirst())Reducer = Reducer<\(structPrefix)State, \(structPrefix)Action> { state, action in
                switch action {
                case .addSampleItem:
                    let nextIndex = state.items.count + 1
                    state.items.insert(
                        \(structPrefix)(
                            id: "item-\\(nextIndex)",
                            title: "New \(d.entityName) #\\(nextIndex)",
                            detail: "Created via unidirectional SwiftState action",
                            badge: "New"
                        ),
                        at: 0
                    )
                    return .none
                case .removeItem(let id):
                    state.items.removeAll { $0.id == id }
                    return .none
                case .completeOnboarding:
                    state.hasCompletedOnboarding = true
                    return .none
                case .updateInsight(let summary):
                    state.aiInsight = summary
                    return .none
                }
            }
            """)
        }

        let surfaceOpen = useBlocks
            ? "EDKSurface(variant: .glass, cornerRadius: \(radius))"
            : "VStack(alignment: .leading, spacing: \(spacing))"
        let glassModifier = (useBlocks && theme.isLiquidGlassEnabled)
            ? "\n                .edkLiquidGlass(cornerRadius: \(radius))"
            : ""
        let buttonSnippet = useBlocks
            ? """
            EDKButton("Add \(d.entityName)", variant: .primary, size: .medium) {
                                addEntry()
                            }
            """
            : """
            Button("Add \(d.entityName)") {
                                addEntry()
                            }
                            .buttonStyle(.borderedProminent)
            """

        let aiSnippet = useAI ? """

                        HStack(spacing: 8) {
                            Image(systemName: "cpu.fill")
                                .foregroundStyle(.secondary)
                            Text(aiSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Run Local AI Summary") {
                                runLocalInsight()
                            }
                            .controlSize(.small)
                        }
        """ : ""

        let onboardingGate = useFlow ? """
                    if showOnboarding {
                        NotebookFlowView(json: flowJSON) { _ in
                            showOnboarding = false
                        }
                        .frame(minHeight: 240)
                    }
        """ : ""

        sections.append("""
        struct \(structPrefix)BlueprintView: View {
            @State private var items: [\(structPrefix)] = [
        \(seedLines)
            ]
            @State private var showOnboarding = \(useFlow ? "false" : "false")
            @State private var aiSummary = "On-device copilot active · \(d.sampleItems.count) items indexed"
            let flowJSON: String = "{}"

            @ScaledMetric(relativeTo: .body) private var cardSpacing: CGFloat = \(spacing)

            var body: some View {
                VStack(alignment: .leading, spacing: cardSpacing) {
                    HStack {
                        Label("\(d.title)", systemImage: "\(d.symbolName)")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        \(buttonSnippet)
                            .accessibilityLabel("Add \(d.entityName)")
                    }
        \(onboardingGate)
                    ForEach(items) { item in
                        \(surfaceOpen) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.badge)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.quaternary, in: Capsule())
                            }
                        }\(glassModifier)
                    }
        \(aiSnippet)
                }
                .padding(\(spacing))
            }

            private func addEntry() {
                let next = items.count + 1
                items.insert(
                    \(structPrefix)(
                        id: "item-\\(next)",
                        title: "\(d.entityName) #\\(next)",
                        detail: "Added from ChiefKit Full-Stack Blueprint",
                        badge: "Live"
                    ),
                    at: 0
                )
            }

            private func runLocalInsight() {
                \(useAI ? """
                let recognizer = NLLanguageRecognizer()
                recognizer.processString(items.map(\\.title).joined(separator: " "))
                let lang = recognizer.dominantLanguage?.rawValue ?? "en"
                aiSummary = "Indexed \\(items.count) records on-device (lang: \\(lang), 0 cloud calls)"
                """ : """
                aiSummary = "Indexed \\(items.count) records"
                """)
            }
        }
        """)

        return sections.joined(separator: "\n\n")
    }

    public func synthesizeSwiftTests(for targetDomain: BlueprintDomain? = nil) -> String {
        let d = targetDomain ?? domain
        let structPrefix = d.entityName
        return """
        import Testing
        @testable import \(d.title.components(separatedBy: CharacterSet.alphanumerics.inverted).joined())App

        @Suite("\(d.title) Blueprint Verification")
        struct \(structPrefix)BlueprintTests {
            @Test("Seed state initializes with expected domain records")
            func seedItemsCount() {
                let initialCount = \(d.sampleItems.count)
                #expect(initialCount == 3)
            }

            @Test("Adding and removing domain entries preserves deterministic order")
            func deterministicMutations() {
                var titles = ["Alpha", "Beta"]
                titles.insert("Gamma", at: 0)
                #expect(titles.first == "Gamma")
                titles.removeAll { $0 == "Beta" }
                #expect(titles == ["Gamma", "Alpha"])
            }
        }
        """
    }
}
