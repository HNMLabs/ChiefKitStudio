import Foundation

public enum DemoLibrary {
    public static let defaultFlowJSON = """
    {
      "title": "Launch Onboarding",
      "pages": [
        {
          "id": "welcome",
          "title": "Welcome to ChiefKit Studio",
          "body": "Ship guided onboarding, surveys, quizzes, and setup flows from portable JSON.",
          "style": "hero",
          "actions": ["Start Setup"]
        },
        {
          "id": "personalize",
          "title": "Choose Your Focus",
          "body": "Ask targeted questions and drive conditional routes from user answers.",
          "style": "choice",
          "actions": ["SwiftUI Engineer", "Design Systems", "Indie Founder"]
        },
        {
          "id": "ai_mode",
          "title": "Local AI Profile",
          "body": "Select how CoreLocalAIKit assists your workspace — 100% on-device.",
          "style": "choice",
          "actions": ["Apple Intelligence + AST", "Fast NaturalLanguage"]
        },
        {
          "id": "ready",
          "title": "Workspace Ready",
          "body": "Render the final state as native SwiftUI and export directly to Xcode.",
          "style": "completion",
          "actions": ["Finish"]
        }
      ]
    }
    """

    public static func liveSwiftStateCode(counter: Int, isLoading: Bool, loadedMessage: String?) -> String {
        let initialMsg = loadedMessage.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" } ?? "nil"
        return """
        import SwiftState
        import SwiftUI

        struct CounterState: Codable, Equatable, Sendable {
            var count = \(counter)
            var isLoading = \(isLoading)
            var message: String? = \(initialMsg)
        }

        enum CounterAction: Equatable, Sendable {
            case increment
            case decrement
            case loadButtonTapped
            case responseReceived(String)
        }

        let counterReducer = Reducer<CounterState, CounterAction> { state, action in
            switch action {
            case .increment:
                state.count += 1
            case .decrement:
                state.count -= 1
            case .loadButtonTapped:
                state.isLoading = true
                return .run { send in
                    try await Task.sleep(for: .milliseconds(900))
                    await send(.responseReceived("Loaded payload for count \\(state.count)"))
                }
            case .responseReceived(let message):
                state.isLoading = false
                state.message = message
            }
            return .none
        }

        struct CounterPlaygroundView: View {
            @StateStore(counterReducer, initialState: CounterState(), enableTimeTravel: true)
            private var store

            var body: some View {
                VStack(spacing: 16) {
                    Text("\\(store.count)")
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .accessibilityAddTraits(.isHeader)

                    HStack(spacing: 12) {
                        Button("-") { store.send(.decrement) }
                            .accessibilityLabel("Decrement Counter")
                        Button("+") { store.send(.increment) }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("Increment Counter")
                        Button("Run Effect") { store.send(.loadButtonTapped) }
                            .accessibilityLabel("Run Async Effect")
                    }

                    if store.isLoading {
                        ProgressView()
                    } else if let message = store.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    TimeTravelDebuggerView(store: store)
                }
            }
        }
        """
    }

    public static func notebookUsageCode(flowTitle: String) -> String {
        let escapedTitle = flowTitle.replacingOccurrences(of: "\"", with: "\\\"")
        return """
        import NotebookFlowKit
        import SwiftUI

        struct OnboardingHostView: View {
            let flowJSON: String

            var body: some View {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(escapedTitle)")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    NotebookFlowView(json: flowJSON) { result in
                        print("Completed \(escapedTitle):", result.answers)
                    }
                }
            }
        }
        """
    }

    public static let coreLocalAIKitUsageCode = """
    import NaturalLanguage
    import SwiftUI
    #if canImport(FoundationModels)
    import FoundationModels
    #endif

    struct LocalAssistantHostView: View {
        @State private var prompt = "Add VoiceOver accessibility labels to this card"
        @State private var summary = "Ready — 100% on-device (0 network calls)"

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Label("CoreLocalAIKit Assistant", systemImage: "cpu.fill")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                TextEditor(text: $prompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 88)

                Button("Run On-Device Analysis") {
                    let recognizer = NLLanguageRecognizer()
                    recognizer.processString(prompt)
                    let lang = recognizer.dominantLanguage?.rawValue ?? "en"
                    summary = "Analyzed locally (lang: \\(lang)) — zero cloud calls."
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Run On-Device Analysis")

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }
    """

    public static func packageSnippet(
        for selection: NavigationSelection,
        blueprint: BlueprintConfiguration = BlueprintConfiguration()
    ) -> String {
        let pkgs = requiredPackages(for: selection, blueprint: blueprint)
        let packages = pkgs
            .map(\.packageDependencySnippet)
            .joined(separator: ",\n")
        let products = pkgs
            .map(\.targetDependencySnippet)
            .joined(separator: ",\n")

        return """
        // Package.swift
        dependencies: [
        \(packages.indented(by: 4))
        ],
        targets: [
            .target(
                name: "YourApp",
                dependencies: [
        \(products.indented(by: 12))
                ]
            )
        ]
        """
    }

    public static func requiredPackages(
        for selection: NavigationSelection,
        blueprint: BlueprintConfiguration = BlueprintConfiguration()
    ) -> [PackageDemo] {
        switch selection {
        case .package(let pkg):
            return [pkg]
        case .template(let kind):
            return templateExample(for: kind, theme: StudioThemeTokens()).requiredPackages
        case .blueprint:
            return blueprint.requiredPackages
        case .savedSnippet:
            return [.swiftBlocks]
        }
    }

    public static func templateExample(for kind: TemplateKind, theme: StudioThemeTokens) -> TemplateExample {
        let r = Int(theme.radiusMedium.rounded())
        let sp = Int(theme.spacingMD)
        let glassLine = theme.isLiquidGlassEnabled ? "\n            .edkLiquidGlass(cornerRadius: \(r))" : ""

        switch kind {
        case .loginFlow:
            return TemplateExample(
                kind: .loginFlow,
                explanation: "Combine SwiftBlocks tokenized inputs with a SwiftState reducer for deterministic validation, passkey fallback, and retry handling.",
                learningPoints: [
                    "Bind email & password inputs cleanly without leaking validation logic into View body",
                    "Disable primary CTA until domain credentials satisfy pure state predicates",
                    "Adapt corner radius (\(r)pt) and spacing (\(sp)pt) directly from EDKTheme"
                ],
                highlightedAPIs: ["EDKSurface", "EDKButton", "@StateStore", "Reducer"],
                requiredPackages: [.swiftBlocks, .swiftState],
                swiftUICode: """
                import SwiftBlocks
                import SwiftState
                import SwiftUI

                struct LoginFlowView: View {
                    @State private var email = "developer@hnmlabs.com"
                    @State private var password = ""
                    @State private var useTouchID = true

                    var body: some View {
                        EDKSurface(variant: .glass, cornerRadius: \(r)) {
                            VStack(alignment: .leading, spacing: \(sp)) {
                                Text("Sign in to ChiefKit")
                                    .font(.title2.bold())
                                    .accessibilityAddTraits(.isHeader)
                                TextField("Work Email", text: $email)
                                    .textFieldStyle(.roundedBorder)
                                SecureField("Password", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                Toggle("Remember this Mac with Touch ID", isOn: $useTouchID)

                                HStack(spacing: 10) {
                                    EDKButton("Continue", variant: .primary, size: .medium) { }
                                        .accessibilityLabel("Continue Sign In")
                                    EDKButton("Passkey", variant: .glass, size: .medium) { }
                                        .accessibilityLabel("Sign in with Passkey")
                                }
                            }
                        }\(glassLine)
                    }
                }
                """
            )

        case .onboardingFlow:
            return TemplateExample(
                kind: .onboardingFlow,
                explanation: "Render portable JSON screen definitions as native SwiftUI while keeping analytics and completion handlers strongly typed.",
                learningPoints: [
                    "Ship copy or step-order updates via JSON without rebuilding SwiftUI views",
                    "Capture structured FlowResult answers at the end of the sequence",
                    "Pair with CoreLocalAIKit to generate tailored onboarding flows from prompts"
                ],
                highlightedAPIs: ["NotebookFlowView", "NotebookFlow", "FlowResult"],
                requiredPackages: [.notebookFlowKit],
                swiftUICode: """
                import NotebookFlowKit
                import SwiftUI

                struct ProductOnboardingView: View {
                    let flowJSON: String

                    var body: some View {
                        NotebookFlowView(json: flowJSON) { result in
                            print("Onboarding completed:", result.answers)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: \(r), style: .continuous))
                    }
                }
                """
            )

        case .settingsScreen:
            return TemplateExample(
                kind: .settingsScreen,
                explanation: "Compose native macOS & iOS preference panes from reusable SwiftBlocks surfaces and @AppStorage bindings.",
                learningPoints: [
                    "Group related toggles inside semantic EDKSurface containers",
                    "Persist lightweight user preferences automatically via @AppStorage",
                    "Preview Light/Dark and Dynamic Type scaling before shipping"
                ],
                highlightedAPIs: ["EDKSurface", "EDKButton", "@AppStorage", "EDKTheme"],
                requiredPackages: [.swiftBlocks],
                swiftUICode: """
                import SwiftBlocks
                import SwiftUI

                struct SettingsScreenView: View {
                    @AppStorage("syncEnabled") private var syncEnabled = true
                    @AppStorage("localAIOnly") private var localAIOnly = true

                    var body: some View {
                        EDKSurface(variant: .glass, cornerRadius: \(r)) {
                            VStack(alignment: .leading, spacing: \(sp)) {
                                Text("Workspace Preferences")
                                    .font(.title3.weight(.semibold))
                                    .accessibilityAddTraits(.isHeader)
                                Toggle("Enable real-time canvas sync", isOn: $syncEnabled)
                                Toggle("Strict on-device AI mode (0 network calls)", isOn: $localAIOnly)
                                Divider()
                                EDKButton("Export Diagnostic Bundle", variant: .secondary, size: .small) { }
                                    .accessibilityLabel("Export Diagnostic Bundle")
                            }
                        }\(glassLine)
                    }
                }
                """
            )

        case .apiLoadingState:
            return TemplateExample(
                kind: .apiLoadingState,
                explanation: "Model network/database request lifecycles explicitly with SwiftState so idle, loading, empty, and retry states never conflict.",
                learningPoints: [
                    "Eliminate impossible boolean combinations (e.g. isLoading && hasError)",
                    "Cancel stale async tasks automatically when Retry is tapped",
                    "Inspect every state transition inside TimeTravelDebuggerView"
                ],
                highlightedAPIs: ["Reducer", "Store", "TimeTravelStore", ".run"],
                requiredPackages: [.swiftState],
                swiftUICode: """
                import SwiftState
                import SwiftUI

                struct ResourceView: View {
                    @State private var phase = "loaded"
                    private let items = ["SwiftBlocks 2.5", "SwiftState TimeTravel", "CoreLocalAIKit"]

                    var body: some View {
                        VStack(alignment: .leading, spacing: \(sp)) {
                            HStack {
                                Label("Package Registry", systemImage: "shippingbox.fill")
                                    .font(.headline)
                                    .accessibilityAddTraits(.isHeader)
                                Spacer()
                                Button("Reload") { phase = "loaded" }
                                    .accessibilityLabel("Reload Registry")
                            }
                            ForEach(items, id: \\.self) { item in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(item)
                                }
                            }
                        }
                        .padding(\(sp))
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: \(r), style: .continuous))
                    }
                }
                """
            )

        case .quizFlow:
            return TemplateExample(
                kind: .quizFlow,
                explanation: "NotebookFlowKit drives multi-choice branching screens while SwiftState tracks live scoring, streaks, and undoable answers.",
                learningPoints: [
                    "Combine declarative JSON question banks with reducer-backed scoring",
                    "Route users to tailored follow-up screens based on selected choices",
                    "Export quiz flows directly into iOS/macOS educational apps"
                ],
                highlightedAPIs: ["NotebookFlowView", "FlowScreen", "Store"],
                requiredPackages: [.notebookFlowKit, .swiftState],
                swiftUICode: """
                import NotebookFlowKit
                import SwiftState
                import SwiftUI

                struct QuizFlowView: View {
                    let quizJSON: String

                    var body: some View {
                        NotebookFlowView(json: quizJSON) { result in
                            print("Quiz finished with answers:", result.answers)
                        }
                    }
                }
                """
            )

        case .liquidGlassDashboard:
            return TemplateExample(
                kind: .liquidGlassDashboard,
                explanation: "Showcase specular Liquid Glass cards, KPI pills, and live EDKTheme color/radius tokens working together.",
                learningPoints: [
                    "Layer translucent glass surfaces with subtle specular highlights",
                    "Drive primary accents (\(theme.primary.hexString)) and corner radii (\(r)pt) from a single theme",
                    "Maintain crisp contrast in both Light and Dark preview modes"
                ],
                highlightedAPIs: ["EDKSurface", ".edkLiquidGlass", "EDKColorPalette", "EDKRadiusScale"],
                requiredPackages: [.swiftBlocks],
                swiftUICode: """
                import SwiftBlocks
                import SwiftUI

                struct LiquidGlassKPIView: View {
                    var body: some View {
                        VStack(alignment: .leading, spacing: \(sp)) {
                            HStack(spacing: \(sp)) {
                                EDKSurface(variant: .glass, cornerRadius: \(r)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Active Developers")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("14,820")
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                    }
                                }\(glassLine)

                                EDKSurface(variant: .glass, cornerRadius: \(r)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("On-Device Latency")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("3.8 ms")
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                    }
                                }\(glassLine)
                            }

                            EDKButton("Export Telemetry Report", variant: .primary, size: .medium) { }
                                .accessibilityLabel("Export Telemetry Report")
                        }
                    }
                }
                """
            )

        case .multiStepProfileForm:
            return TemplateExample(
                kind: .multiStepProfileForm,
                explanation: "Build structured macOS/iOS workspace forms with role pickers, live character counters, and instant state validation.",
                learningPoints: [
                    "Structure multi-field forms with consistent spacing (\(sp)pt) and clear labels",
                    "Validate required fields deterministically before enabling submission",
                    "Test keyboard navigation and Accessibility X-Ray focus order"
                ],
                highlightedAPIs: ["EDKSurface", "EDKButton", "StoreBinding"],
                requiredPackages: [.swiftBlocks, .swiftState],
                swiftUICode: """
                import SwiftBlocks
                import SwiftUI

                struct WorkspaceSetupFormView: View {
                    @State private var teamName = "HNM Labs"
                    @State private var role = "Engineering"
                    @State private var enableLocalAI = true

                    private let roles = ["Engineering", "Design", "Product"]

                    var body: some View {
                        EDKSurface(variant: .glass, cornerRadius: \(r)) {
                            VStack(alignment: .leading, spacing: \(sp)) {
                                Text("Create Team Workspace")
                                    .font(.title3.bold())
                                    .accessibilityAddTraits(.isHeader)
                                TextField("Organization Name", text: $teamName)
                                    .textFieldStyle(.roundedBorder)
                                Picker("Department", selection: $role) {
                                    ForEach(roles, id: \\.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                Toggle("Enable CoreLocalAIKit Code Assistant", isOn: $enableLocalAI)
                                EDKButton("Create Workspace", variant: .primary, size: .medium) { }
                                    .accessibilityLabel("Create Workspace")
                            }
                        }\(glassLine)
                    }
                }
                """
            )

        case .shoppingCartStore:
            return TemplateExample(
                kind: .shoppingCartStore,
                explanation: "Demonstrates undoable domain mutations (quantities, promo discounts, totals) connected directly to the Time-Travel Debugger.",
                learningPoints: [
                    "Compute derived totals purely from immutable cart item arrays",
                    "Record every quantity change and promo toggle as a replayable snapshot",
                    "Open Time-Travel Debugger (⌘T) to scrub cart history live"
                ],
                highlightedAPIs: ["TimeTravelStore", "Reducer", "Action", "TimeTravelHistoryEntry"],
                requiredPackages: [.swiftState, .swiftBlocks],
                swiftUICode: """
                import SwiftBlocks
                import SwiftState
                import SwiftUI

                struct CartCheckoutView: View {
                    @State private var seats = 3
                    @State private var annualDiscount = true

                    private var total: Int {
                        let raw = seats * 29
                        return annualDiscount ? Int(Double(raw) * 0.8) : raw
                    }

                    var body: some View {
                        EDKSurface(variant: .glass, cornerRadius: \(r)) {
                            VStack(alignment: .leading, spacing: \(sp)) {
                                Text("Team License Summary")
                                    .font(.title3.bold())
                                    .accessibilityAddTraits(.isHeader)
                                Stepper("Seats: \\(seats)", value: $seats, in: 1...50)
                                Toggle("Apply 20% Annual Billing Discount", isOn: $annualDiscount)
                                Divider()
                                HStack {
                                    Text("Monthly Total")
                                    Spacer()
                                    Text("$\\(total)/mo")
                                        .font(.title2.bold())
                                }
                                EDKButton("Complete Order", variant: .primary, size: .medium) { }
                                    .accessibilityLabel("Complete Order")
                            }
                        }\(glassLine)
                    }
                }
                """
            )

        case .aiAccessibilityAudit:
            return TemplateExample(
                kind: .aiAccessibilityAudit,
                explanation: "A reference SwiftUI component pre-instrumented with VoiceOver labels, hints, @ScaledMetric layout, and high-contrast badges.",
                learningPoints: [
                    "Combine visual polish with complete screen-reader semantics",
                    "Toggle 'Accessibility X-Ray' in the preview toolbar to inspect focus order",
                    "Use CoreLocalAIKit in the right panel to audit any custom SwiftUI snippet"
                ],
                highlightedAPIs: ["@ScaledMetric", ".accessibilityLabel", ".accessibilityHint", "LocalAIEngine"],
                requiredPackages: [.swiftBlocks, .coreLocalAIKit],
                swiftUICode: """
                import SwiftBlocks
                import SwiftUI

                struct AccessibleReleaseCard: View {
                    @ScaledMetric(relativeTo: .body) private var cardSpacing: CGFloat = \(sp)

                    var body: some View {
                        EDKSurface(variant: .glass, cornerRadius: \(r)) {
                            VStack(alignment: .leading, spacing: cardSpacing) {
                                Label("Accessibility Verified", systemImage: "checkmark.shield.fill")
                                    .font(.caption.weight(.semibold))
                                    .accessibilityLabel("Accessibility status: verified")

                                Text("ChiefKit 2.5 Release Candidate")
                                    .font(.title3.bold())
                                    .accessibilityAddTraits(.isHeader)

                                Text("Supports VoiceOver rotor headings, Dynamic Type AX3 scaling, and keyboard shortcuts.")
                                    .foregroundStyle(.secondary)

                                EDKButton("Run Local Audit", variant: .primary, size: .medium) { }
                                    .accessibilityLabel("Run Local Accessibility Audit")
                                    .accessibilityHint("Analyzes this view on-device without network access")
                            }
                        }\(glassLine)
                    }
                }
                """
            )
        }
    }
}
