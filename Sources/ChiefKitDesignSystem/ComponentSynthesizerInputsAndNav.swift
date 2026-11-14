#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Navigation & Input Component Specs + Parameterized Synthesizers (16 Components)

internal enum ComponentSynthesizerInputsAndNav {

    static let specs: [SwiftBlockSpec] = [
        // MARK: 8 Navigation Specs
        SwiftBlockSpec(
            id: .commandBar,
            title: "Command Palette Bar",
            summary: "Keyboard-first ⌘K quick-launcher with fuzzy query input, category chips, and shortcut hints.",
            sfSymbol: "command",
            vectorIcon: .commandPalette,
            variants: ["glass", "compact", "spotlight"],
            props: [
                SwiftBlockPropSpec(name: "query", kind: .binding, defaultValue: "\"\"", summary: "Live search string", isRequired: true),
                SwiftBlockPropSpec(name: "placeholder", kind: .string, defaultValue: "\"Type a command or search…\"", summary: "Prompt text"),
                SwiftBlockPropSpec(name: "onExecute", kind: .actionClosure, defaultValue: "{ }", summary: "Invoked on return key")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 460, height: 184),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "searchField", minimumAPCALc: 75, keyboardNavigationShortcut: "⌘K"),
            searchKeywords: ["command", "palette", "raycast", "spotlight", "shortcut"]
        ),
        SwiftBlockSpec(
            id: .breadcrumbTrail,
            title: "Breadcrumb Trail",
            summary: "Hierarchical workspace path navigation with truncation menu and active leaf pill.",
            sfSymbol: "chevron.right.2",
            vectorIcon: .gitBranchMerge,
            variants: ["glass", "minimal", "slashed"],
            props: [
                SwiftBlockPropSpec(name: "segments", kind: .dataArray, defaultValue: "[\"Workspace\", \"Design System\", \"Tokens\"]", summary: "Ordered path nodes", isRequired: true),
                SwiftBlockPropSpec(name: "onSelectIndex", kind: .actionClosure, defaultValue: "{ _ in }", summary: "Breadcrumb tap handler")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 420, height: 52),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "navigation", minimumAPCALc: 65),
            searchKeywords: ["breadcrumb", "path", "hierarchy", "header"]
        ),
        SwiftBlockSpec(
            id: .segmentedTabStrip,
            title: "Segmented Tab Strip",
            summary: "Spring-animated pill tab switcher with unread counters and keyboard arrow support.",
            sfSymbol: "rectangle.split.3x1",
            vectorIcon: .layoutGrid12,
            variants: ["glass", "underline", "pill"],
            props: [
                SwiftBlockPropSpec(name: "selectedTab", kind: .binding, defaultValue: "0", summary: "Selected index", isRequired: true),
                SwiftBlockPropSpec(name: "tabs", kind: .dataArray, defaultValue: "[\"Overview\", \"Physics\", \"Tokens\"]", summary: "Tab labels")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 56),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "tabBar", minimumAPCALc: 70, keyboardNavigationShortcut: "⌃⇥"),
            searchKeywords: ["tabs", "segmented", "picker", "switcher"]
        ),
        SwiftBlockSpec(
            id: .sidebarSplitShell,
            title: "Sidebar Split Shell",
            summary: "Collapsible two-column master-detail navigation container with grouped sections and footer status.",
            sfSymbol: "sidebar.left",
            vectorIcon: .artboardDevices,
            variants: ["glass", "translucent", "bordered"],
            props: [
                SwiftBlockPropSpec(name: "selection", kind: .binding, defaultValue: "\"canvas\"", summary: "Active route ID", isRequired: true),
                SwiftBlockPropSpec(name: "isCollapsed", kind: .bool, defaultValue: "false", summary: "Sidebar collapse toggle")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 520, height: 280),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "splitGroup", minimumAPCALc: 75, keyboardNavigationShortcut: "⌥⌘S"),
            searchKeywords: ["sidebar", "navigationSplitView", "shell", "chrome"]
        ),
        SwiftBlockSpec(
            id: .floatingGlassDock,
            title: "Floating Glass Dock",
            summary: "Specular Liquid Glass floating tool dock with hover spring magnification and active indicator dot.",
            sfSymbol: "dock.rectangle",
            vectorIcon: .liquidGlassCube,
            variants: ["glass", "spatial", "compact"],
            props: [
                SwiftBlockPropSpec(name: "activeTool", kind: .binding, defaultValue: "0", summary: "Selected tool index", isRequired: true),
                SwiftBlockPropSpec(name: "magnification", kind: .double, defaultValue: "1.18", summary: "Hover scale factor")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 72),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "toolbar", minimumAPCALc: 60, keyboardNavigationShortcut: "1…5"),
            tokenCompliance: SwiftBlockTokenCompliance(recommendedSpring: .bouncy),
            searchKeywords: ["dock", "toolbar", "floating", "glass"]
        ),
        SwiftBlockSpec(
            id: .stepProgressHeader,
            title: "Step Progress Header",
            summary: "Numbered multi-step checkout or onboarding progress bar with animated connector tracks.",
            sfSymbol: "list.number",
            vectorIcon: .checkBadgeVerified,
            variants: ["glass", "numbered", "minimal"],
            props: [
                SwiftBlockPropSpec(name: "currentStep", kind: .int, defaultValue: "2", summary: "1-based active step", isRequired: true),
                SwiftBlockPropSpec(name: "steps", kind: .dataArray, defaultValue: "[\"Account\", \"Tokens\", \"Review\", \"Ship\"]", summary: "Step titles")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 460, height: 84),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "progressIndicator", minimumAPCALc: 65),
            searchKeywords: ["stepper", "wizard", "onboarding", "progress"]
        ),
        SwiftBlockSpec(
            id: .contextualPopoverBar,
            title: "Contextual Popover Bar",
            summary: "Floating inline selection action bar for text styling, alignment, and AI rewrite triggers.",
            sfSymbol: "ContextualMenu",
            vectorIcon: .sparklesAI,
            variants: ["glass", "dark", "compact"],
            props: [
                SwiftBlockPropSpec(name: "isBold", kind: .binding, defaultValue: "true", summary: "Bold toggle"),
                SwiftBlockPropSpec(name: "onTriggerAI", kind: .actionClosure, defaultValue: "{ }", summary: "AI action callback")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 320, height: 54),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "toolbar", minimumAPCALc: 70, keyboardNavigationShortcut: "⌘B"),
            searchKeywords: ["popover", "toolbar", "selection", "inline"]
        ),
        SwiftBlockSpec(
            id: .pagedCarouselHeader,
            title: "Paged Carousel Header",
            summary: "Interactive feature showcase header with capsule page indicators and directional controls.",
            sfSymbol: "rectangle.on.rectangle.angled",
            vectorIcon: .rocketDeploy,
            variants: ["glass", "hero", "card"],
            props: [
                SwiftBlockPropSpec(name: "currentPage", kind: .binding, defaultValue: "0", summary: "Zero-indexed page", isRequired: true),
                SwiftBlockPropSpec(name: "pageCount", kind: .int, defaultValue: "4", summary: "Total slide count")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 440, height: 168),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "tabGroup", minimumAPCALc: 70),
            tokenCompliance: SwiftBlockTokenCompliance(recommendedSpring: .smooth),
            searchKeywords: ["carousel", "pager", "hero", "slides"]
        ),

        // MARK: 8 Input Specs
        SwiftBlockSpec(
            id: .tokenSearchField,
            title: "Token Search Field",
            summary: "Structured query bar parsing scope:value facets into interactive removable filter pills.",
            sfSymbol: "magnifyingglass.circle",
            vectorIcon: .searchMagnifier,
            variants: ["glass", "bordered", "prominent"],
            props: [
                SwiftBlockPropSpec(name: "tokens", kind: .dataArray, defaultValue: "[\"role:brand\", \"mode:dark\"]", summary: "Active filter chips"),
                SwiftBlockPropSpec(name: "text", kind: .binding, defaultValue: "\"\"", summary: "Trailing text query", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 420, height: 64),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "searchField", minimumAPCALc: 75, keyboardNavigationShortcut: "⌘F"),
            searchKeywords: ["search", "filter", "tokens", "facets"]
        ),
        SwiftBlockSpec(
            id: .otpVerificationField,
            title: "OTP Verification Field",
            summary: "Six-cell monospaced one-time code entry with auto-paste parsing and focus ring highlight.",
            sfSymbol: "ellipsis.rectangle",
            vectorIcon: .passkeyShield,
            variants: ["glass", "boxed", "underlined"],
            props: [
                SwiftBlockPropSpec(name: "code", kind: .binding, defaultValue: "\"482910\"", summary: "6-digit OTP value", isRequired: true),
                SwiftBlockPropSpec(name: "digitCount", kind: .int, defaultValue: "6", summary: "Number of code slots")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 340, height: 96),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "textField", minimumAPCALc: 80),
            searchKeywords: ["otp", "2fa", "mfa", "verification", "pin"]
        ),
        SwiftBlockSpec(
            id: .passkeySignInButton,
            title: "Passkey Sign-In Button",
            summary: "FIDO2 / WebAuthn biometric authentication button with Touch ID / Face ID status feedback.",
            sfSymbol: "person.badge.key.fill",
            vectorIcon: .biometricKey,
            variants: ["glass", "solid", "outline"],
            props: [
                SwiftBlockPropSpec(name: "relyingParty", kind: .string, defaultValue: "\"chiefkit.studio\"", summary: "WebAuthn RP domain", isRequired: true),
                SwiftBlockPropSpec(name: "onAuthenticate", kind: .actionClosure, defaultValue: "{ }", summary: "Auth trigger")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 300, height: 58),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "button", minimumAPCALc: 75),
            searchKeywords: ["passkey", "biometric", "faceid", "touchid", "auth"]
        ),
        SwiftBlockSpec(
            id: .dualRangeSlider,
            title: "Dual Range Slider",
            summary: "Two-handle continuous interval slider for price, latency, or lightness filtering with live readout.",
            sfSymbol: "slider.horizontal.below.rectangle",
            vectorIcon: .filterSliders,
            variants: ["glass", "compact", "histogram"],
            props: [
                SwiftBlockPropSpec(name: "lowerBound", kind: .binding, defaultValue: "0.22", summary: "Normalized lower thumb", isRequired: true),
                SwiftBlockPropSpec(name: "upperBound", kind: .binding, defaultValue: "0.78", summary: "Normalized upper thumb", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 340, height: 92),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "slider", minimumAPCALc: 65),
            searchKeywords: ["range", "slider", "interval", "min", "max"]
        ),
        SwiftBlockSpec(
            id: .oklchSwatchPicker,
            title: "OKLCH Swatch Picker",
            summary: "Perceptual Lightness, Chroma, and Hue color inspector with live sRGB gamut & APCA readout.",
            sfSymbol: "paintpalette.fill",
            vectorIcon: .colorWheelOKLCH,
            variants: ["glass", "inspector", "compact"],
            props: [
                SwiftBlockPropSpec(name: "lightness", kind: .binding, defaultValue: "0.62", summary: "OKLCH L [0, 1]", isRequired: true),
                SwiftBlockPropSpec(name: "chroma", kind: .binding, defaultValue: "0.18", summary: "OKLCH C [0, 0.37]", isRequired: true),
                SwiftBlockPropSpec(name: "hue", kind: .binding, defaultValue: "258.0", summary: "OKLCH H [0, 360)", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 340, height: 180),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "colorWell", minimumAPCALc: 70),
            searchKeywords: ["color", "oklch", "picker", "swatch", "gamut"]
        ),
        SwiftBlockSpec(
            id: .tagChipInputField,
            title: "Tag Chip Input Field",
            summary: "Multi-value token pill composer supporting keyboard return creation and one-tap removal.",
            sfSymbol: "tag.fill",
            vectorIcon: .tagBookmark,
            variants: ["glass", "bordered", "inline"],
            props: [
                SwiftBlockPropSpec(name: "tags", kind: .binding, defaultValue: "[\"Swift 6\", \"Sendable\", \"LiquidGlass\"]", summary: "Selected tags", isRequired: true),
                SwiftBlockPropSpec(name: "maxTags", kind: .int, defaultValue: "8", summary: "Maximum allowed tags")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 88),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "group", minimumAPCALc: 70),
            searchKeywords: ["tags", "chips", "pills", "multiselect"]
        ),
        SwiftBlockSpec(
            id: .dateRangeCalendarBar,
            title: "Date Range Calendar Bar",
            summary: "Analytics window selector combining quick horizon presets (7D/30D/90D) with start & end pickers.",
            sfSymbol: "calendar.badge.clock",
            vectorIcon: .calendarRange,
            variants: ["glass", "toolbar", "compact"],
            props: [
                SwiftBlockPropSpec(name: "preset", kind: .string, defaultValue: "\"30D\"", summary: "Active horizon preset"),
                SwiftBlockPropSpec(name: "startDate", kind: .binding, defaultValue: "Date()", summary: "Interval start", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 440, height: 68),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "dateTimeArea", minimumAPCALc: 70),
            searchKeywords: ["date", "calendar", "range", "timeframe"]
        ),
        SwiftBlockSpec(
            id: .fileDropZoneCard,
            title: "File Drop Zone Card",
            summary: "Drag-and-drop asset dropzone with UTType validation, dashed highlight border, and byte progress.",
            sfSymbol: "arrow.up.doc.fill",
            vectorIcon: .uploadDropzone,
            variants: ["glass", "dashed", "compact"],
            props: [
                SwiftBlockPropSpec(name: "acceptedTypes", kind: .dataArray, defaultValue: "[\".svg\", \".json\", \".xcassets\"]", summary: "Allowed extensions"),
                SwiftBlockPropSpec(name: "onDropFiles", kind: .actionClosure, defaultValue: "{ _ in }", summary: "File URLs handler", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 156),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "button", minimumAPCALc: 65),
            searchKeywords: ["upload", "dropzone", "drag", "file", "import"]
        )
    ]

    // MARK: - Component Code Synthesis

    static func synthesize(context ctx: SwiftBlockSynthesisContext) -> String {
        let accent = ctx.accentSwiftUI
        let rSM = ctx.radSM

        switch ctx.id {
        case .commandBar:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var query: String = \"\"\n    @State private var selectedIndex: Int = 0",
                bodyCore: """
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(\(accent))
                            TextField("Type a command or jump to artboard…", text: $query)
                                .textFieldStyle(.plain)
                            Text("⌘K")
                                .font(.caption2.monospaced().weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: \(rSM)))
                        }
                        Divider()
                        ForEach(Array(["Compile Design Tokens", "Run APCA Contrast Audit", "Export SwiftUI Shape"].enumerated()), id: \\.offset) { idx, title in
                            HStack {
                                Image(systemName: idx == 0 ? "hammer.fill" : (idx == 1 ? "eye.fill" : "beziercurve"))
                                    .foregroundStyle(idx == selectedIndex ? \(accent) : .secondary)
                                Text(title).font(.subheadline)
                                Spacer()
                                Text("↩").font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                """
            )

        case .breadcrumbTrail:
            return ctx.wrapComponentView(
                stateProperties: "    public var segments: [String] = [\"ChiefKit\", \"DesignSystem\", \"OKLCH Tokens\"]",
                bodyCore: """
                        HStack(spacing: 6) {
                            ForEach(Array(segments.enumerated()), id: \\.offset) { index, label in
                                if index > 0 {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                }
                                let isLast = index == segments.count - 1
                                Text(label)
                                    .font(.subheadline.weight(isLast ? .semibold : .regular))
                                    .foregroundStyle(isLast ? \(accent) : .secondary)
                                    .padding(.horizontal, isLast ? 8 : 2)
                                    .padding(.vertical, isLast ? 4 : 0)
                                    .background(isLast ? \(accent).opacity(0.14) : .clear, in: Capsule())
                            }
                        }
                """
            )

        case .segmentedTabStrip:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var selectedTab: Int = 0\n    private let tabs = [\"Canvas\", \"Physics\", \"Tokens\", \"Export\"]",
                bodyCore: """
                        HStack(spacing: 6) {
                            ForEach(Array(tabs.enumerated()), id: \\.offset) { index, tab in
                                Button {
                                    selectedTab = index
                                } label: {
                                    Text(tab)
                                        .font(.subheadline.weight(selectedTab == index ? .semibold : .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(selectedTab == index ? \(accent) : .clear, in: Capsule())
                                        .foregroundStyle(selectedTab == index ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                """
            )

        case .sidebarSplitShell:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var activeSection: String = \"Artboards\"",
                bodyCore: """
                        HStack(alignment: .top, spacing: \(ctx.padMD)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("WORKSPACE").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                                ForEach(["Artboards", "Components", "Tokens", "Physics"], id: \\.self) { item in
                                    Button {
                                        activeSection = item
                                    } label: {
                                        HStack {
                                            Circle().fill(activeSection == item ? \(accent) : .clear).frame(width: 6, height: 6)
                                            Text(item).font(.subheadline.weight(activeSection == item ? .semibold : .regular))
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(width: 132)
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text(activeSection).font(.headline)
                                Text("Responsive 12-column canvas synchronized across active breakpoints.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                """
            )

        case .floatingGlassDock:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var activeTool: Int = 0\n    private let icons = [\"cursorarrow\", \"rectangle.on.rectangle\", \"beziercurve\", \"textformat\", \"sparkles\"]",
                bodyCore: """
                        HStack(spacing: 14) {
                            ForEach(Array(icons.enumerated()), id: \\.offset) { index, symbol in
                                Button {
                                    activeTool = index
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: symbol)
                                            .font(.system(size: 17, weight: .semibold))
                                            .frame(width: 36, height: 36)
                                            .background(activeTool == index ? \(accent).opacity(0.20) : .clear, in: Circle())
                                            .foregroundStyle(activeTool == index ? \(accent) : .primary)
                                        Circle()
                                            .fill(activeTool == index ? \(accent) : .clear)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                """
            )

        case .stepProgressHeader:
            return ctx.wrapComponentView(
                stateProperties: "    public var currentStep: Int = 2\n    private let steps = [\"Palette\", \"Typography\", \"Audit\", \"Bundle\"]",
                bodyCore: """
                        HStack(spacing: 8) {
                            ForEach(Array(steps.enumerated()), id: \\.offset) { idx, label in
                                let stepNum = idx + 1
                                HStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(stepNum <= currentStep ? \(accent) : Color.secondary.opacity(0.2))
                                            .frame(width: 24, height: 24)
                                        Text(stepNum < currentStep ? "✓" : "\\(stepNum)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(stepNum <= currentStep ? .white : .secondary)
                                    }
                                    Text(label)
                                        .font(.caption.weight(stepNum == currentStep ? .semibold : .regular))
                                }
                                if idx < steps.count - 1 {
                                    Rectangle()
                                        .fill(stepNum < currentStep ? \(accent) : Color.secondary.opacity(0.25))
                                        .frame(height: 2)
                                }
                            }
                        }
                """
            )

        case .contextualPopoverBar:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var isBold = true\n    @State private var isItalic = false",
                bodyCore: """
                        HStack(spacing: 10) {
                            Button { isBold.toggle() } label: {
                                Image(systemName: "bold").foregroundStyle(isBold ? \(accent) : .primary)
                            }
                            Button { isItalic.toggle() } label: {
                                Image(systemName: "italic").foregroundStyle(isItalic ? \(accent) : .primary)
                            }
                            Divider().frame(height: 16)
                            Button { } label: {
                                Label("Polish Copy", systemImage: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(\(accent))
                            }
                        }
                        .buttonStyle(.plain)
                """
            )

        case .pagedCarouselHeader:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var page: Int = 0\n    private let headlines = [\"Perceptual OKLCH Engine\", \"RK4 Spring Oscillator\", \"64 Native SwiftBlocks\"]",
                bodyCore: """
                        VStack(alignment: .leading, spacing: 10) {
                            Text("FEATURE SPOTLIGHT · \\(page + 1)/\\(headlines.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(\(accent))
                            Text(headlines[page % headlines.count])
                                .font(.title3.weight(.bold))
                            HStack {
                                HStack(spacing: 6) {
                                    ForEach(0..<headlines.count, id: \\.self) { idx in
                                        Capsule()
                                            .fill(idx == page ? \(accent) : Color.secondary.opacity(0.3))
                                            .frame(width: idx == page ? 20 : 7, height: 7)
                                    }
                                }
                                Spacer()
                                Button("Next →") { page = (page + 1) % headlines.count }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(\(accent))
                            }
                        }
                """
            )

        case .tokenSearchField:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var activeFacets: [String] = [\"target:swiftUI\", \"apca:≥75\"]\n    @State private var queryText: String = \"\"",
                bodyCore: """
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .foregroundStyle(\(accent))
                            ForEach(activeFacets, id: \\.self) { facet in
                                HStack(spacing: 4) {
                                    Text(facet).font(.caption.monospaced())
                                    Button {
                                        activeFacets.removeAll { $0 == facet }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill").font(.caption2)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(\(accent).opacity(0.15), in: Capsule())
                            }
                            TextField("Add token filter…", text: $queryText)
                                .textFieldStyle(.plain)
                        }
                """
            )

        case .otpVerificationField:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var digits: [String] = [\"4\", \"8\", \"2\", \"9\", \"1\", \"\"]",
                bodyCore: """
                        Text("Enter 6-Digit Security Code").font(.subheadline.weight(.semibold))
                        HStack(spacing: 8) {
                            ForEach(0..<6, id: \\.self) { slot in
                                let value = slot < digits.count ? digits[slot] : ""
                                Text(value.isEmpty ? "•" : value)
                                    .font(.title3.monospaced().weight(.bold))
                                    .frame(width: 40, height: 46)
                                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: \(rSM)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: \(rSM))
                                            .strokeBorder(value.isEmpty ? \(accent) : Color.secondary.opacity(0.3), lineWidth: value.isEmpty ? 1.8 : 1)
                                    )
                            }
                        }
                """
            )

        case .passkeySignInButton:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var isAuthenticating = false",
                bodyCore: """
                        Button {
                            isAuthenticating.toggle()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.badge.key.fill")
                                    .font(.headline)
                                Text(isAuthenticating ? "Verifying Biometric Passkey…" : "Continue with Passkey")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "faceid")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(\(accent), in: RoundedRectangle(cornerRadius: \(rSM), style: .continuous))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                """
            )

        case .dualRangeSlider:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var minRatio: Double = 0.24\n    @State private var maxRatio: Double = 0.78",
                bodyCore: """
                        HStack {
                            Text("Response Window").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\\(Int(minRatio * 500))ms – \\(Int(maxRatio * 500))ms")
                                .font(.caption.monospaced())
                                .foregroundStyle(\(accent))
                        }
                        GeometryReader { geo in
                            let w = max(1, geo.size.width)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.22)).frame(height: 6)
                                Capsule()
                                    .fill(\(accent))
                                    .frame(width: max(12, (maxRatio - minRatio) * w), height: 6)
                                    .offset(x: minRatio * w)
                            }
                        }
                        .frame(height: 18)
                """
            )

        case .oklchSwatchPicker:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var l: Double = 0.62\n    @State private var c: Double = 0.18\n    @State private var h: Double = 256.0",
                bodyCore: """
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: \(rSM), style: .continuous)
                                .fill(\(accent))
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("OKLCH Perceptual Inspector").font(.subheadline.weight(.semibold))
                                Text(String(format: "oklch(%.0f%% %.3f %.0f°)", l * 100, c, h))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        VStack(spacing: 6) {
                            HStack { Text("L").font(.caption.monospaced()); Slider(value: $l, in: 0...1) }
                            HStack { Text("C").font(.caption.monospaced()); Slider(value: $c, in: 0...0.35) }
                            HStack { Text("H").font(.caption.monospaced()); Slider(value: $h, in: 0...360) }
                        }
                        .tint(\(accent))
                """
            )

        case .tagChipInputField:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var tags: [String] = [\"Swift 6\", \"Sendable\", \"OKLCH\"]\n    @State private var draft: String = \"\"",
                bodyCore: """
                        HStack(spacing: 6) {
                            ForEach(tags, id: \\.self) { tag in
                                Label(tag, systemImage: "tag.fill")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(\(accent).opacity(0.14), in: Capsule())
                                    .foregroundStyle(\(accent))
                            }
                        }
                        TextField("Add capability tag and press Return…", text: $draft)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                guard !draft.isEmpty else { return }
                                tags.append(draft)
                                draft = ""
                            }
                """
            )

        case .dateRangeCalendarBar:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var selectedHorizon = \"30D\"\n    @State private var startDate = Date()",
                bodyCore: """
                        HStack(spacing: 8) {
                            ForEach(["24H", "7D", "30D", "90D"], id: \\.self) { horizon in
                                Button(horizon) { selectedHorizon = horizon }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(selectedHorizon == horizon ? \(accent) : Color.secondary.opacity(0.15), in: Capsule())
                                    .foregroundStyle(selectedHorizon == horizon ? .white : .primary)
                                    .buttonStyle(.plain)
                            }
                            Spacer()
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                """
            )

        default: // .fileDropZoneCard
            return ctx.wrapComponentView(
                stateProperties: "    @State private var isDropTargeted = false",
                bodyCore: """
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.doc.on.clipboard")
                                .font(.title2)
                                .foregroundStyle(\(accent))
                            Text("Drop SVG Icons or W3C Token JSON")
                                .font(.subheadline.weight(.semibold))
                            Text("Supports .svg, .tokens.json, and .xcassets up to 25 MB")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: \(rSM), style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .foregroundStyle(isDropTargeted ? \(accent) : Color.secondary.opacity(0.4))
                        )
                """
            )
        }
    }
}
