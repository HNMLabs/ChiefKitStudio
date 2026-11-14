#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - SwiftBlocks 3.0 Categories (8 Categories x 8 Components = 64)

public enum SwiftBlockCategory: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case navigation = "Navigation & Shells"
    case inputs = "Inputs & Controls"
    case charts = "Charts & Metrics"
    case dataGrids = "Data Grids & Workflows"
    case commerceAndFintech = "Commerce & Fintech"
    case saasOperations = "SaaS & Operations"
    case onDeviceAI = "On-Device AI & Agents"
    case spatialAndMedia = "Spatial, Media & System"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .navigation: "sidebar.left"
        case .inputs: "slider.horizontal.3"
        case .charts: "chart.xyaxis.line"
        case .dataGrids: "tablecells"
        case .commerceAndFintech: "creditcard.and.123"
        case .saasOperations: "server.rack"
        case .onDeviceAI: "cpu.fill"
        case .spatialAndMedia: "visionpro"
        }
    }
}

// MARK: - All 64 SwiftBlocks 3.0 Component Identifiers

public enum SwiftBlockID: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    // 1. Navigation (8)
    case commandBar = "CommandBar"
    case breadcrumbTrail = "BreadcrumbTrail"
    case segmentedTabStrip = "SegmentedTabStrip"
    case sidebarSplitShell = "SidebarSplitShell"
    case floatingGlassDock = "FloatingGlassDock"
    case stepProgressHeader = "StepProgressHeader"
    case contextualPopoverBar = "ContextualPopoverBar"
    case pagedCarouselHeader = "PagedCarouselHeader"

    // 2. Inputs (8)
    case tokenSearchField = "TokenSearchField"
    case otpVerificationField = "OTPVerificationField"
    case passkeySignInButton = "PasskeySignInButton"
    case dualRangeSlider = "DualRangeSlider"
    case oklchSwatchPicker = "OKLCHSwatchPicker"
    case tagChipInputField = "TagChipInputField"
    case dateRangeCalendarBar = "DateRangeCalendarBar"
    case fileDropZoneCard = "FileDropZoneCard"

    // 3. Charts & KPI (8)
    case sparklineMetricCard = "SparklineMetricCard"
    case smoothAreaTrendChart = "SmoothAreaTrendChart"
    case stackedBarComparison = "StackedBarComparison"
    case donutRingGauge = "DonutRingGauge"
    case contributionHeatmap = "ContributionHeatmap"
    case conversionFunnelCard = "ConversionFunnelCard"
    case latencyPercentileChart = "LatencyPercentileChart"
    case flamegraphSpanView = "FlamegraphSpanView"

    // 4. Data Grids & Workflows (8)
    case sortableDataGrid = "SortableDataGrid"
    case kanbanBoardColumn = "KanbanBoardColumn"
    case activityTimelineFeed = "ActivityTimelineFeed"
    case unifiedDiffBlock = "UnifiedDiffBlock"
    case jsonTreeExplorer = "JSONTreeExplorer"
    case heroKPIDeltaBanner = "HeroKPIDeltaBanner"
    case quotaUsageRing = "QuotaUsageRing"
    case realtimeTickerBar = "RealtimeTickerBar"

    // 5. Commerce & Fintech (8)
    case pricingTierComparison = "PricingTierComparison"
    case virtualCardGlassView = "VirtualCardGlassView"
    case ledgerEntryRow = "LedgerEntryRow"
    case multiCurrencySwapCard = "MultiCurrencySwapCard"
    case invoiceLineItemCard = "InvoiceLineItemCard"
    case planUpgradeBanner = "PlanUpgradeBanner"
    case orderBookDepthCard = "OrderBookDepthCard"
    case assetAllocationBar = "AssetAllocationBar"

    // 6. SaaS & Operations (8)
    case shippingAddressCard = "ShippingAddressCard"
    case promoRedemptionBar = "PromoRedemptionBar"
    case escrowMilestoneStepper = "EscrowMilestoneStepper"
    case taxSummaryBreakdown = "TaxSummaryBreakdown"
    case teamSeatSliderCard = "TeamSeatSliderCard"
    case immutableAuditLogRow = "ImmutableAuditLogRow"
    case serviceUptimeMatrix = "ServiceUptimeMatrix"
    case webhookEndpointCard = "WebhookEndpointCard"

    // 7. On-Device AI & Agents (8)
    case streamingPromptBar = "StreamingPromptBar"
    case tokenThroughputGauge = "TokenThroughputGauge"
    case groundingCitationRow = "GroundingCitationRow"
    case localModelPickerCard = "LocalModelPickerCard"
    case aiInlineDiffCard = "AIInlineDiffCard"
    case voiceSpectrogramBar = "VoiceSpectrogramBar"
    case agentToolTraceCard = "AgentToolTraceCard"
    case contextWindowRing = "ContextWindowRing"

    // 8. Spatial, Media & System (8)
    case visionGlassOrnament = "VisionGlassOrnament"
    case spatialCardStack = "SpatialCardStack"
    case parallaxHeroSurface = "ParallaxHeroSurface"
    case miniWaveformPlayer = "MiniWaveformPlayer"
    case chapterVideoScrubber = "ChapterVideoScrubber"
    case toastNotificationStack = "ToastNotificationStack"
    case systemPermissionCard = "SystemPermissionCard"
    case actionableEmptyState = "ActionableEmptyState"

    public var id: String { rawValue }

    public var structName: String {
        "CK\(rawValue)"
    }

    public var category: SwiftBlockCategory {
        switch self {
        case .commandBar, .breadcrumbTrail, .segmentedTabStrip, .sidebarSplitShell,
             .floatingGlassDock, .stepProgressHeader, .contextualPopoverBar, .pagedCarouselHeader:
            return .navigation
        case .tokenSearchField, .otpVerificationField, .passkeySignInButton, .dualRangeSlider,
             .oklchSwatchPicker, .tagChipInputField, .dateRangeCalendarBar, .fileDropZoneCard:
            return .inputs
        case .sparklineMetricCard, .smoothAreaTrendChart, .stackedBarComparison, .donutRingGauge,
             .contributionHeatmap, .conversionFunnelCard, .latencyPercentileChart, .flamegraphSpanView:
            return .charts
        case .sortableDataGrid, .kanbanBoardColumn, .activityTimelineFeed, .unifiedDiffBlock,
             .jsonTreeExplorer, .heroKPIDeltaBanner, .quotaUsageRing, .realtimeTickerBar:
            return .dataGrids
        case .pricingTierComparison, .virtualCardGlassView, .ledgerEntryRow, .multiCurrencySwapCard,
             .invoiceLineItemCard, .planUpgradeBanner, .orderBookDepthCard, .assetAllocationBar:
            return .commerceAndFintech
        case .shippingAddressCard, .promoRedemptionBar, .escrowMilestoneStepper, .taxSummaryBreakdown,
             .teamSeatSliderCard, .immutableAuditLogRow, .serviceUptimeMatrix, .webhookEndpointCard:
            return .saasOperations
        case .streamingPromptBar, .tokenThroughputGauge, .groundingCitationRow, .localModelPickerCard,
             .aiInlineDiffCard, .voiceSpectrogramBar, .agentToolTraceCard, .contextWindowRing:
            return .onDeviceAI
        case .visionGlassOrnament, .spatialCardStack, .parallaxHeroSurface, .miniWaveformPlayer,
             .chapterVideoScrubber, .toastNotificationStack, .systemPermissionCard, .actionableEmptyState:
            return .spatialAndMedia
        }
    }
}

// MARK: - Interactive States, Property Schema & Compliance Metadata

public enum SwiftBlockInteractiveState: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case idle
    case hovered
    case focused
    case pressed
    case loading
    case disabled
    case error

    public var id: String { rawValue }

    public var displayLabel: String {
        rawValue.capitalized
    }
}

public enum SwiftBlockPropKind: String, Codable, Hashable, Sendable {
    case string = "String"
    case int = "Int"
    case double = "Double"
    case bool = "Bool"
    case binding = "@Binding"
    case actionClosure = "() -> Void"
    case dataArray = "[Item]"
    case semanticToken = "SemanticColorRole"
}

public struct SwiftBlockPropSpec: Identifiable, Codable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let kind: SwiftBlockPropKind
    public let defaultValue: String
    public let summary: String
    public let isRequired: Bool

    public init(
        name: String,
        kind: SwiftBlockPropKind,
        defaultValue: String,
        summary: String,
        isRequired: Bool = false
    ) {
        self.name = name
        self.kind = kind
        self.defaultValue = defaultValue
        self.summary = summary
        self.isRequired = isRequired
    }
}

public struct SwiftBlockAccessibilityMetadata: Codable, Hashable, Sendable {
    public let voiceOverRole: String
    public let minimumAPCALc: Double
    public let supportsDynamicTypeAX5: Bool
    public let keyboardNavigationShortcut: String?
    public let reducedMotionFallback: String

    public init(
        voiceOverRole: String,
        minimumAPCALc: Double = 60.0,
        supportsDynamicTypeAX5: Bool = true,
        keyboardNavigationShortcut: String? = nil,
        reducedMotionFallback: String = "Replaces spring scale/offset with 150ms opacity crossfade."
    ) {
        self.voiceOverRole = voiceOverRole
        self.minimumAPCALc = minimumAPCALc
        self.supportsDynamicTypeAX5 = supportsDynamicTypeAX5
        self.keyboardNavigationShortcut = keyboardNavigationShortcut
        self.reducedMotionFallback = reducedMotionFallback
    }
}

public struct SwiftBlockTokenCompliance: Codable, Hashable, Sendable {
    public let semanticRoles: [SemanticColorRole]
    public let usesLiquidGlassMaterial: Bool
    public let supportsHighContrastMode: Bool
    public let supportsVisionOSDepthHover: Bool
    public let recommendedSpring: SpringParameters

    public init(
        semanticRoles: [SemanticColorRole] = [.surfacePrimary, .textPrimary, .brandPrimary, .borderSubtle],
        usesLiquidGlassMaterial: Bool = true,
        supportsHighContrastMode: Bool = true,
        supportsVisionOSDepthHover: Bool = true,
        recommendedSpring: SpringParameters = .snappy
    ) {
        self.semanticRoles = semanticRoles
        self.usesLiquidGlassMaterial = usesLiquidGlassMaterial
        self.supportsHighContrastMode = supportsHighContrastMode
        self.supportsVisionOSDepthHover = supportsVisionOSDepthHover
        self.recommendedSpring = recommendedSpring
    }
}

// MARK: - Complete SwiftBlockSpec Model

public struct SwiftBlockSpec: Identifiable, Codable, Hashable, Sendable {
    public let id: SwiftBlockID
    public let category: SwiftBlockCategory
    public let title: String
    public let summary: String
    public let sfSymbol: String
    public let vectorIcon: ChiefKitVectorIcon
    public let variants: [String]
    public let defaultVariant: String
    public let supportedStates: [SwiftBlockInteractiveState]
    public let props: [SwiftBlockPropSpec]
    public let defaultFrame: CanvasFrame
    public let accessibility: SwiftBlockAccessibilityMetadata
    public let tokenCompliance: SwiftBlockTokenCompliance
    public let searchKeywords: [String]

    public init(
        id: SwiftBlockID,
        title: String,
        summary: String,
        sfSymbol: String,
        vectorIcon: ChiefKitVectorIcon,
        variants: [String] = ["glass", "elevated", "compact"],
        defaultVariant: String = "glass",
        supportedStates: [SwiftBlockInteractiveState] = SwiftBlockInteractiveState.allCases,
        props: [SwiftBlockPropSpec],
        defaultFrame: CanvasFrame = CanvasFrame(x: 24, y: 24, width: 340, height: 140),
        accessibility: SwiftBlockAccessibilityMetadata,
        tokenCompliance: SwiftBlockTokenCompliance = SwiftBlockTokenCompliance(),
        searchKeywords: [String] = []
    ) {
        self.id = id
        self.category = id.category
        self.title = title
        self.summary = summary
        self.sfSymbol = sfSymbol
        self.vectorIcon = vectorIcon
        self.variants = variants
        self.defaultVariant = defaultVariant
        self.supportedStates = supportedStates
        self.props = props
        self.defaultFrame = defaultFrame
        self.accessibility = accessibility
        self.tokenCompliance = tokenCompliance
        self.searchKeywords = searchKeywords
    }
}

// MARK: - Shared Theme & State Code Synthesis Context

internal struct SwiftBlockSynthesisContext: Sendable {
    let id: SwiftBlockID
    let spec: SwiftBlockSpec
    let theme: StudioThemeTokens
    let variant: String
    let state: SwiftBlockInteractiveState

    var padSM: Int { Int(theme.spacingSM) }
    var padMD: Int { Int(theme.spacingMD) }
    var padLG: Int { Int(theme.spacingLG) }
    var radSM: Int { Int(theme.radiusSmall.rounded()) }
    var radMD: Int { Int(theme.radiusMedium.rounded()) }
    var radLG: Int { Int(theme.radiusLarge.rounded()) }

    var resolvedAccentColor: RGBAColor {
        switch state {
        case .error: theme.danger
        default: theme.primary
        }
    }

    var accentSwiftUI: String {
        resolvedAccentColor.swiftInitializer
    }

    var useGlass: Bool {
        variant == "glass" || (variant == "default" && theme.isLiquidGlassEnabled)
    }

    var containerSurfaceModifiers: String {
        let strokeColor = state == .error
            ? "\(theme.danger.swiftInitializer).opacity(0.85)"
            : (state == .focused ? "\(theme.primary.swiftInitializer).opacity(0.9)" : ".white.opacity(\(String(format: "%.2f", theme.specularRim * 0.55)))")
        let strokeWidth = (state == .focused || state == .error) ? "2" : "1"
        let bgMaterial = useGlass ? ".ultraThinMaterial" : "Color(red: \(String(format: "%.2f", theme.surface.red)), green: \(String(format: "%.2f", theme.surface.green)), blue: \(String(format: "%.2f", theme.surface.blue)))"
        let scaleStr = state == .pressed ? "\n            .scaleEffect(0.985)" : (state == .hovered ? "\n            .scaleEffect(1.01)" : "")
        let disabledStr = state == .disabled ? "\n            .opacity(0.48)\n            .disabled(true)" : ""

        return """
                    .padding(\(padMD))
                    .background(\(bgMaterial), in: RoundedRectangle(cornerRadius: \(radMD), style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: \(radMD), style: .continuous)
                            .strokeBorder(\(strokeColor), lineWidth: \(strokeWidth))
                    )\(scaleStr)\(disabledStr)
        """
    }

    var stateBannerIfNeeded: String {
        switch state {
        case .loading:
            return """
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Synchronizing \(spec.title)…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
            """
        case .error:
            return """
                        Label("Validation alert in \(spec.title)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(\(theme.danger.swiftInitializer))
            """
        default:
            return ""
        }
    }

    func wrapComponentView(stateProperties: String = "", bodyCore: String) -> String {
        let bannerSection = stateBannerIfNeeded.isEmpty ? "" : "\n\(stateBannerIfNeeded)"
        let stateDecls = stateProperties.isEmpty ? "" : "\(stateProperties)\n\n"
        let shortcutLine = spec.accessibility.keyboardNavigationShortcut.map {
            "\n            // Keyboard shortcut: \($0)"
        } ?? ""
        let sp = spec.tokenCompliance.recommendedSpring
        let dur = String(format: "%.2f", sp.perceptualDuration)
        let bnc = String(format: "%.2f", sp.perceptualBounce)

        return """
        import SwiftBlocks
        import SwiftUI

        /// SwiftBlocks 3.0 — \(spec.title) [Variant: \(variant), State: \(state.rawValue)]
        /// Category: \(spec.category.rawValue) · Min APCA: \(Int(spec.accessibility.minimumAPCALc)) Lc\(shortcutLine)
        public struct \(id.structName): View {
        \(stateDecls)    public init() {}

            public var body: some View {
                VStack(alignment: .leading, spacing: \(padSM)) {
        \(bodyCore)\(bannerSection)
                }
        \(containerSurfaceModifiers)
                    .animation(.spring(duration: \(dur), bounce: \(bnc)), value: "\(state.rawValue)")
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(spec.title)")
            }
        }
        """
    }
}

// MARK: - SwiftBlockCatalog Public Registry & Audit Facade

public struct SwiftBlockCatalogAuditReport: Codable, Hashable, Sendable {
    public let totalComponentCount: Int
    public let categoryCounts: [SwiftBlockCategory: Int]
    public let liquidGlassCapableCount: Int
    public let dynamicTypeAX5CompliantCount: Int
    public let primarySurfaceAPCALc: Double
    public let isFull64CatalogVerified: Bool

    public init(
        totalComponentCount: Int,
        categoryCounts: [SwiftBlockCategory: Int],
        liquidGlassCapableCount: Int,
        dynamicTypeAX5CompliantCount: Int,
        primarySurfaceAPCALc: Double
    ) {
        self.totalComponentCount = totalComponentCount
        self.categoryCounts = categoryCounts
        self.liquidGlassCapableCount = liquidGlassCapableCount
        self.dynamicTypeAX5CompliantCount = dynamicTypeAX5CompliantCount
        self.primarySurfaceAPCALc = primarySurfaceAPCALc
        self.isFull64CatalogVerified = totalComponentCount == 64 && SwiftBlockCategory.allCases.allSatisfy {
            categoryCounts[$0] == 8
        }
    }
}

public enum SwiftBlockCatalog {

    /// Complete 64-component `SwiftBlocks` 3.0 specification registry (8 categories x 8 components).
    public static let allSpecs: [SwiftBlockSpec] = {
        ComponentSynthesizerInputsAndNav.specs
            + ComponentSynthesizerDataAndCharts.specs
            + ComponentSynthesizerCommerceAndFintech.specs
            + ComponentSynthesizerAIAndSpatial.specs
    }()

    private static let specsByID: [SwiftBlockID: SwiftBlockSpec] = {
        Dictionary(uniqueKeysWithValues: allSpecs.map { ($0.id, $0) })
    }()

    /// Looks up the `SwiftBlockSpec` for any of the 64 `SwiftBlockID` identifiers.
    public static func spec(for id: SwiftBlockID) -> SwiftBlockSpec {
        if let found = specsByID[id] {
            return found
        }
        return allSpecs[0]
    }

    /// Returns all 8 components belonging to `category`.
    public static func specs(in category: SwiftBlockCategory) -> [SwiftBlockSpec] {
        allSpecs.filter { $0.category == category }
    }

    /// Fuzzy keyword & metadata search across all 64 `SwiftBlocks` 3.0 components.
    public static func search(
        query: String,
        category: SwiftBlockCategory? = nil,
        liquidGlassOnly: Bool = false
    ) -> [SwiftBlockSpec] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allSpecs.filter { item in
            if let category, item.category != category {
                return false
            }
            if liquidGlassOnly && !item.tokenCompliance.usesLiquidGlassMaterial {
                return false
            }
            guard !trimmed.isEmpty else { return true }
            return item.title.lowercased().contains(trimmed)
                || item.id.rawValue.lowercased().contains(trimmed)
                || item.summary.lowercased().contains(trimmed)
                || item.searchKeywords.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }

    /// Synthesizes parameterized, token-driven SwiftUI + `SwiftBlocks` production code for any of the 64 components.
    public static func synthesizeCode(
        for id: SwiftBlockID,
        theme: StudioThemeTokens = StudioThemeTokens(),
        variant: String = "glass",
        state: SwiftBlockInteractiveState = .idle
    ) -> String {
        let resolvedSpec = spec(for: id)
        let resolvedVariant = variant.isEmpty ? resolvedSpec.defaultVariant : variant
        let ctx = SwiftBlockSynthesisContext(
            id: id,
            spec: resolvedSpec,
            theme: theme,
            variant: resolvedVariant,
            state: state
        )

        switch id.category {
        case .navigation, .inputs:
            return ComponentSynthesizerInputsAndNav.synthesize(context: ctx)
        case .charts, .dataGrids:
            return ComponentSynthesizerDataAndCharts.synthesize(context: ctx)
        case .commerceAndFintech, .saasOperations:
            return ComponentSynthesizerCommerceAndFintech.synthesize(context: ctx)
        case .onDeviceAI, .spatialAndMedia:
            return ComponentSynthesizerAIAndSpatial.synthesize(context: ctx)
        }
    }

    /// Audits the 64-component catalog against `theme` tokens, verifying category parity, AX5 Dynamic Type, and APCA contrast.
    public static func auditCatalog(theme: StudioThemeTokens = StudioThemeTokens()) -> SwiftBlockCatalogAuditReport {
        var counts: [SwiftBlockCategory: Int] = [:]
        for cat in SwiftBlockCategory.allCases {
            counts[cat] = 0
        }
        var glassCount = 0
        var ax5Count = 0

        for s in allSpecs {
            counts[s.category, default: 0] += 1
            if s.tokenCompliance.usesLiquidGlassMaterial { glassCount += 1 }
            if s.accessibility.supportsDynamicTypeAX5 { ax5Count += 1 }
        }

        let apcaLc = abs(PerceptualColorScience.apcaContrast(text: theme.primary, background: theme.surface))
        return SwiftBlockCatalogAuditReport(
            totalComponentCount: allSpecs.count,
            categoryCounts: counts,
            liquidGlassCapableCount: glassCount,
            dynamicTypeAX5CompliantCount: ax5Count,
            primarySurfaceAPCALc: apcaLc
        )
    }
}
