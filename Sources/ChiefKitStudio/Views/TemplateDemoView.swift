#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct TemplateDemoView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme
    let template: TemplateKind

    private var example: TemplateExample {
        DemoLibrary.templateExample(for: template, theme: theme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    livePreviewCard
                    dependencyCard
                }

                VStack(alignment: .leading, spacing: 18) {
                    livePreviewCard
                    dependencyCard
                }
            }
        }
    }

    private var livePreviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle("Interactive Preview", subtitle: "Reacts live to Theme Tokens, Preview Modes, and Local AI.")
                    Spacer()
                    PillLabel(title: template.category.rawValue, systemImage: template.category.symbolName)
                }

                Group {
                    switch template {
                    case .loginFlow:
                        LoginInteractivePreview()
                    case .onboardingFlow:
                        OnboardingInteractivePreview()
                    case .settingsScreen:
                        SettingsInteractivePreview()
                    case .apiLoadingState:
                        LoadingInteractivePreview()
                    case .quizFlow:
                        QuizInteractivePreview()
                    case .liquidGlassDashboard:
                        LiquidGlassInteractivePreview()
                    case .multiStepProfileForm:
                        ProfileFormInteractivePreview()
                    case .shoppingCartStore:
                        CartStoreInteractivePreview(viewModel: viewModel)
                    case .aiAccessibilityAudit:
                        AccessibilityAuditInteractivePreview {
                            let preset = LocalAIPromptPreset.presets.first { $0.kind == .addAccessibility }
                            viewModel.runLocalAI(preset: preset)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        }
    }

    private var dependencyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Required ChiefKit Packages", subtitle: "Export as a snippet or generate a complete Xcode project.")

                ForEach(example.requiredPackages) { package in
                    HStack(spacing: 10) {
                        Image(systemName: package.symbolName)
                            .foregroundStyle(theme.primary.swiftUIColor)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(package.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(package.repositoryURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        Spacer()

                        Button {
                            ExportService.openURL(package.webURL)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open \(package.title) on GitHub")
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 8) {
                    Button {
                        viewModel.copyPackageDependency()
                    } label: {
                        Label("Copy Dependencies", systemImage: "doc.on.doc")
                    }

                    Button {
                        viewModel.isProjectGeneratorPresented = true
                    } label: {
                        Label("Generate Project…", systemImage: "hammer.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        }
    }
}

// MARK: - Interactive Example Previews

private struct LoginInteractivePreview: View {
    @Environment(\.studioTheme) private var theme
    @State private var email = "developer@hnmlabs.com"
    @State private var password = "••••••••••••"
    @State private var useTouchID = true
    @State private var signedIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Sign in to ChiefKit")
                .font(.title3.weight(.bold))
            TextField("Work Email", text: $email)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            Toggle("Remember this Mac with Touch ID", isOn: $useTouchID)

            HStack(spacing: 10) {
                Button(signedIn ? "Authenticated ✓" : "Continue") {
                    signedIn.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary.swiftUIColor)

                Button("Use Passkey") {
                    signedIn = true
                }
            }
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }
}

private struct OnboardingInteractivePreview: View {
    @Environment(\.studioTheme) private var theme
    @State private var step = 0
    private let titles = [
        "Welcome to ChiefKit Studio",
        "Token-Driven Design System",
        "Ready for Xcode Export"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            PillLabel(title: "Step \(step + 1) of \(titles.count)", systemImage: "sparkles")
            Text(titles[step])
                .font(.title3.weight(.bold))
            Text("Portable JSON pages drive native SwiftUI views with typed completion callbacks.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Previous") {
                    step = max(0, step - 1)
                }
                .disabled(step == 0)

                Button(step == titles.count - 1 ? "Restart" : "Continue") {
                    step = (step + 1) % titles.count
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary.swiftUIColor)
            }
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }
}

private struct SettingsInteractivePreview: View {
    @Environment(\.studioTheme) private var theme
    @State private var syncEnabled = true
    @State private var strictLocalAI = true
    @State private var snapGrid = true

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Workspace Preferences")
                .font(.title3.weight(.semibold))
            Toggle("Enable real-time canvas sync", isOn: $syncEnabled)
            Toggle("Strict on-device AI mode (0 cloud calls)", isOn: $strictLocalAI)
            Toggle("Snap blocks to 16pt design grid", isOn: $snapGrid)
            Divider()
            HStack {
                Text("Theme Accent")
                Spacer()
                Text(theme.primary.hexString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.primary.swiftUIColor)
            }
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }
}

private struct LoadingInteractivePreview: View {
    @Environment(\.studioTheme) private var theme
    @State private var phase: String = "loaded"

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Picker("Phase", selection: $phase) {
                Text("Idle").tag("idle")
                Text("Loading").tag("loading")
                Text("Loaded").tag("loaded")
                Text("Error").tag("error")
            }
            .pickerStyle(.segmented)

            switch phase {
            case "loading":
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Fetching ChiefKit package metadata…")
                }
            case "error":
                Label("Connection offline — tap Retry to recover cleanly.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(theme.danger.swiftUIColor)
                Button("Retry") { phase = "loaded" }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
            case "loaded":
                ForEach(["SwiftBlocks 2.0", "SwiftState TimeTravel", "CoreLocalAIKit"], id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(theme.success.swiftUIColor)
                }
            default:
                Text("Tap a phase above to inspect deterministic UI transitions.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }
}

private struct QuizInteractivePreview: View {
    @Environment(\.studioTheme) private var theme
    @State private var selected = "Reducers"
    @State private var submitted = false
    private let answers = ["Reducers", "View Modifiers", "Ad-hoc Timers"]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Which layer owns pure state transitions in SwiftState?")
                .font(.headline)

            ForEach(answers, id: \.self) { answer in
                Button {
                    selected = answer
                    submitted = false
                } label: {
                    HStack {
                        Image(systemName: selected == answer ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(theme.primary.swiftUIColor)
                        Text(answer)
                        Spacer()
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Check Answer") {
                    submitted = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary.swiftUIColor)

                if submitted {
                    Text(selected == "Reducers" ? "Correct! Pure reducers guarantee replayability." : "Try 'Reducers'!")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected == "Reducers" ? theme.success.swiftUIColor : theme.warning.swiftUIColor)
                }
            }
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }
}

private struct LiquidGlassInteractivePreview: View {
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                metricBox(title: "Active Devs", value: "14.8k", badge: "+24%")
                metricBox(title: "AI Latency", value: "3.8 ms", badge: "Local")
            }

            HStack {
                Text(theme.isLiquidGlassEnabled ? "Liquid Glass: Active" : "Standard Material")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Radius \(Int(theme.radiusMedium))pt")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.primary.swiftUIColor)
            }
        }
        .padding(theme.spacingMD)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }

    private func metricBox(title: String, value: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.success.swiftUIColor)
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusSmall), style: .continuous))
    }
}

private struct ProfileFormInteractivePreview: View {
    @Environment(\.studioTheme) private var theme
    @State private var orgName = "HNM Labs"
    @State private var role = "Engineering"
    @State private var localAI = true
    private let roles = ["Engineering", "Design", "Product"]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Create Team Workspace")
                .font(.title3.weight(.bold))
            TextField("Organization Name", text: $orgName)
                .textFieldStyle(.roundedBorder)
            Picker("Department", selection: $role) {
                ForEach(roles, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Enable CoreLocalAIKit On-Device Assistant", isOn: $localAI)
            Button("Provision \(orgName.isEmpty ? "Workspace" : orgName)") { }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary.swiftUIColor)
                .disabled(orgName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(theme.spacingMD)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }
}

private struct CartStoreInteractivePreview: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            ForEach(viewModel.cartItems) { item in
                HStack {
                    Text(item.name)
                        .font(.callout.weight(.medium))
                    Spacer()
                    Button("-") { viewModel.adjustCartQuantity(itemID: item.id, delta: -1) }
                    Text("\(item.quantity)")
                        .font(.system(.callout, design: .monospaced))
                        .frame(width: 24)
                    Button("+") { viewModel.adjustCartQuantity(itemID: item.id, delta: 1) }
                }
            }
            Toggle(
                "Apply 20% Promo (CHIEF20)",
                isOn: Binding(
                    get: { viewModel.promoApplied },
                    set: { _ in viewModel.togglePromoCode() }
                )
            )
            Divider()
            HStack {
                Text("Total: $\(viewModel.computedCartTotal)/mo")
                    .font(.headline)
                Spacer()
                Button("Scrub History (⌘T)") {
                    viewModel.isTimeTravelVisible = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary.swiftUIColor)
            }
        }
        .padding(theme.spacingMD)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }
}

private struct AccessibilityAuditInteractivePreview: View {
    @Environment(\.studioTheme) private var theme
    let onAudit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Label("Accessibility Verified", systemImage: "checkmark.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.success.swiftUIColor)
            Text("ChiefKit 2.0 Release Candidate")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text("Annotated with VoiceOver labels, rotor headings, and @ScaledMetric spacing.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                onAudit()
            } label: {
                Label("Run CoreLocalAIKit Accessibility Pass", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary.swiftUIColor)
        }
        .padding(theme.spacingMD)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
    }
}
#endif
