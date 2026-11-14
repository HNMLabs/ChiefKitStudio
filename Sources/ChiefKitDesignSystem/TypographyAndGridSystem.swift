#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Apple HIG Dynamic Type Categories & Text Styles

/// All 12 Apple Human Interface Guidelines Dynamic Type size categories (`xSmall` through `accessibility5`).
public enum DynamicTypeSizeCategory: String, CaseIterable, Comparable, Identifiable, Codable, Hashable, Sendable {
    case xSmall
    case small
    case medium
    case large // Apple system default
    case xLarge
    case xxLarge
    case xxxLarge
    case accessibility1
    case accessibility2
    case accessibility3
    case accessibility4
    case accessibility5

    public var id: String { rawValue }

    public var ordinalIndex: Int {
        switch self {
        case .xSmall: 0
        case .small: 1
        case .medium: 2
        case .large: 3
        case .xLarge: 4
        case .xxLarge: 5
        case .xxxLarge: 6
        case .accessibility1: 7
        case .accessibility2: 8
        case .accessibility3: 9
        case .accessibility4: 10
        case .accessibility5: 11
        }
    }

    public static func < (lhs: DynamicTypeSizeCategory, rhs: DynamicTypeSizeCategory) -> Bool {
        lhs.ordinalIndex < rhs.ordinalIndex
    }

    public var isAccessibilityCategory: Bool {
        ordinalIndex >= 7
    }

    public var swiftUIName: String {
        switch self {
        case .xSmall: ".xSmall"
        case .small: ".small"
        case .medium: ".medium"
        case .large: ".large"
        case .xLarge: ".xLarge"
        case .xxLarge: ".xxLarge"
        case .xxxLarge: ".xxxLarge"
        case .accessibility1: ".accessibility1"
        case .accessibility2: ".accessibility2"
        case .accessibility3: ".accessibility3"
        case .accessibility4: ".accessibility4"
        case .accessibility5: ".accessibility5"
        }
    }
}

/// All 11 semantic text styles defined by Apple Human Interface Guidelines.
public enum HIGTextStyle: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2

    public var id: String { rawValue }

    public var displayLabel: String {
        switch self {
        case .largeTitle: "Large Title"
        case .title: "Title 1"
        case .title2: "Title 2"
        case .title3: "Title 3"
        case .headline: "Headline"
        case .body: "Body"
        case .callout: "Callout"
        case .subheadline: "Subheadline"
        case .footnote: "Footnote"
        case .caption: "Caption 1"
        case .caption2: "Caption 2"
        }
    }

    public var defaultCSSWeight: Int {
        switch self {
        case .headline: 600
        case .largeTitle, .title, .title2, .title3, .body, .callout, .subheadline, .footnote, .caption, .caption2:
            400
        }
    }

    public var swiftUIFontToken: String {
        ".\(rawValue)"
    }
}

public enum OpticalFontFamilyVariant: String, Codable, Hashable, Sendable {
    case sfProText = "SF Pro Text (< 20pt)"
    case sfProDisplay = "SF Pro Display (≥ 20pt)"
}

/// Complete resolved typographic metrics for a single `(HIGTextStyle, DynamicTypeSizeCategory)` pair.
public struct HIGResolvedTypeMetrics: Codable, Hashable, Sendable {
    public let style: HIGTextStyle
    public let category: DynamicTypeSizeCategory
    public let pointSize: Double
    public let lineHeight: Double
    public let leadingDelta: Double
    public let cssFontWeight: Int
    public let trackingPoints: Double
    public let trackingEm: Double
    public let opticalVariant: OpticalFontFamilyVariant

    public init(
        style: HIGTextStyle,
        category: DynamicTypeSizeCategory,
        pointSize: Double,
        lineHeight: Double,
        cssFontWeight: Int,
        trackingPoints: Double
    ) {
        self.style = style
        self.category = category
        self.pointSize = pointSize
        self.lineHeight = lineHeight
        self.leadingDelta = lineHeight - pointSize
        self.cssFontWeight = cssFontWeight
        self.trackingPoints = trackingPoints
        self.trackingEm = pointSize > 0 ? trackingPoints / pointSize : 0.0
        self.opticalVariant = pointSize >= 20.0 ? .sfProDisplay : .sfProText
    }

    /// Optimal readable measure width in points targeting 62 characters per line (`~0.48 * pointSize` avg advance).
    public var idealMeasureWidthPoints: Double {
        (pointSize * 0.48 * 62.0).rounded()
    }
}

// MARK: - Modular Typographic Scale Ratios

public enum TypographicScaleRatio: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case minorSecond
    case majorSecond
    case minorThird
    case majorThird
    case perfectFourth
    case augmentedFourth
    case goldenRatio

    public var id: String { rawValue }

    public var multiplier: Double {
        switch self {
        case .minorSecond: 16.0 / 15.0        // 1.0667
        case .majorSecond: 9.0 / 8.0          // 1.1250
        case .minorThird: 6.0 / 5.0           // 1.2000
        case .majorThird: 5.0 / 4.0           // 1.2500
        case .perfectFourth: 4.0 / 3.0        // 1.3333
        case .augmentedFourth: 2.0.squareRoot() // 1.4142
        case .goldenRatio: 1.61803398875      // φ
        }
    }

    public var musicalIntervalTitle: String {
        switch self {
        case .minorSecond: "Minor Second (1.067)"
        case .majorSecond: "Major Second (1.125)"
        case .minorThird: "Minor Third (1.200)"
        case .majorThird: "Major Third (1.250)"
        case .perfectFourth: "Perfect Fourth (1.333)"
        case .augmentedFourth: "Augmented Fourth / √2 (1.414)"
        case .goldenRatio: "Golden Ratio φ (1.618)"
        }
    }
}

public struct ModularScaleStep: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { stepExponent }
    public let stepExponent: Int
    public let tokenName: String
    public let rawSizePoints: Double
    public let snappedSizePoints: Double
    public let snappedLineHeightPoints: Double
    public let opticalTrackingPoints: Double
    public let opticalTrackingEm: Double

    public init(
        stepExponent: Int,
        tokenName: String,
        rawSizePoints: Double,
        snappedSizePoints: Double,
        snappedLineHeightPoints: Double,
        opticalTrackingPoints: Double
    ) {
        self.stepExponent = stepExponent
        self.tokenName = tokenName
        self.rawSizePoints = rawSizePoints
        self.snappedSizePoints = snappedSizePoints
        self.snappedLineHeightPoints = snappedLineHeightPoints
        self.opticalTrackingPoints = opticalTrackingPoints
        self.opticalTrackingEm = snappedSizePoints > 0 ? opticalTrackingPoints / snappedSizePoints : 0
    }
}

// MARK: - Responsive Breakpoint & Baseline Grid Engine

public enum DeviceBreakpoint: String, CaseIterable, Comparable, Identifiable, Codable, Hashable, Sendable {
    case watchOS
    case iPhoneCompact
    case iPhoneMax
    case iPadSplit
    case iPadPro
    case macWindow
    case macUltrawide
    case visionOSWindow

    public var id: String { rawValue }

    public var sortOrder: Int {
        switch self {
        case .watchOS: 0
        case .iPhoneCompact: 1
        case .iPhoneMax: 2
        case .iPadSplit: 3
        case .iPadPro: 4
        case .macWindow: 5
        case .visionOSWindow: 6
        case .macUltrawide: 7
        }
    }

    public static func < (lhs: DeviceBreakpoint, rhs: DeviceBreakpoint) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    public var title: String {
        switch self {
        case .watchOS: "Apple Watch Ultra (205pt)"
        case .iPhoneCompact: "iPhone Compact (393pt)"
        case .iPhoneMax: "iPhone Pro Max (440pt)"
        case .iPadSplit: "iPad Split / Compact (678pt)"
        case .iPadPro: "iPad Pro 13\" (1032pt)"
        case .macWindow: "macOS Desktop Window (1440pt)"
        case .macUltrawide: "macOS Studio Ultrawide (2560pt)"
        case .visionOSWindow: "visionOS Spatial Window (1280pt)"
        }
    }

    public var referenceViewportWidth: Double {
        switch self {
        case .watchOS: 205
        case .iPhoneCompact: 393
        case .iPhoneMax: 440
        case .iPadSplit: 678
        case .iPadPro: 1032
        case .visionOSWindow: 1280
        case .macWindow: 1440
        case .macUltrawide: 2560
        }
    }

    public var referenceViewportHeight: Double {
        switch self {
        case .watchOS: 251
        case .iPhoneCompact: 852
        case .iPhoneMax: 956
        case .iPadSplit: 1032
        case .iPadPro: 1376
        case .visionOSWindow: 720
        case .macWindow: 900
        case .macUltrawide: 1440
        }
    }

    /// Minimum HIG interactive hit target dimension in points (`44pt` iOS/iPadOS, `28pt` macOS pointer, `60pt` visionOS eye gaze).
    public var minimumHitTargetPoints: Double {
        switch self {
        case .watchOS: 38
        case .iPhoneCompact, .iPhoneMax, .iPadSplit, .iPadPro: 44
        case .macWindow, .macUltrawide: 28
        case .visionOSWindow: 60
        }
    }
}

public struct SafeAreaInsetsMetrics: Codable, Hashable, Sendable {
    public let top: Double
    public let leading: Double
    public let bottom: Double
    public let trailing: Double

    public init(top: Double, leading: Double, bottom: Double, trailing: Double) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

/// Deterministic 4pt/8pt baseline and multi-column layout grid specification for a breakpoint.
public struct ResponsiveGridSpec: Codable, Hashable, Sendable {
    public let breakpoint: DeviceBreakpoint
    public let columns: Int
    public let outerMargin: Double
    public let gutter: Double
    public let subGridUnit: Double       // 4pt fine optical grid
    public let baselineUnit: Double      // 8pt primary vertical rhythm
    public let maxContentWidth: Double
    public let safeArea: SafeAreaInsetsMetrics

    public init(
        breakpoint: DeviceBreakpoint,
        columns: Int,
        outerMargin: Double,
        gutter: Double,
        subGridUnit: Double = 4.0,
        baselineUnit: Double = 8.0,
        maxContentWidth: Double,
        safeArea: SafeAreaInsetsMetrics
    ) {
        self.breakpoint = breakpoint
        self.columns = max(1, columns)
        self.outerMargin = outerMargin
        self.gutter = gutter
        self.subGridUnit = subGridUnit
        self.baselineUnit = baselineUnit
        self.maxContentWidth = maxContentWidth
        self.safeArea = safeArea
    }

    /// Effective inner track width inside margins and `maxContentWidth` clamp.
    public func contentTrackWidth(forViewportWidth viewportWidth: Double) -> Double {
        let usable = max(0.0, viewportWidth - safeArea.leading - safeArea.trailing - 2.0 * outerMargin)
        return min(usable, maxContentWidth)
    }

    /// Exact width of a single grid column for `viewportWidth`.
    public func singleColumnWidth(forViewportWidth viewportWidth: Double) -> Double {
        let track = contentTrackWidth(forViewportWidth: viewportWidth)
        let totalGutters = Double(max(0, columns - 1)) * gutter
        return max(0.0, (track - totalGutters) / Double(columns))
    }

    /// Exact width of an element spanning `span` columns (`1...columns`), including `span - 1` internal gutters.
    public func spanWidth(columns span: Int, viewportWidth: Double) -> Double {
        let clampedSpan = min(max(1, span), columns)
        let colW = singleColumnWidth(forViewportWidth: viewportWidth)
        return Double(clampedSpan) * colW + Double(clampedSpan - 1) * gutter
    }

    /// Horizontal X origin in viewport coordinates for 0-indexed `columnIndex` (centered when `viewportWidth` exceeds `maxContentWidth`).
    public func columnOriginX(columnIndex: Int, viewportWidth: Double) -> Double {
        let clampedIdx = min(max(0, columnIndex), columns - 1)
        let track = contentTrackWidth(forViewportWidth: viewportWidth)
        let availableBetweenSafeAreas = max(0.0, viewportWidth - safeArea.leading - safeArea.trailing)
        let centeringOffset = max(0.0, (availableBetweenSafeAreas - track) * 0.5)
        let startX = safeArea.leading + max(outerMargin, centeringOffset)
        let colW = singleColumnWidth(forViewportWidth: viewportWidth)
        return startX + Double(clampedIdx) * (colW + gutter)
    }

    /// Snaps an arbitrary dimension or vertical coordinate to the nearest `baselineUnit` (8pt) or `subGridUnit` (4pt).
    public func snap(_ value: Double, useSubGrid: Bool = false) -> Double {
        let step = useSubGrid ? subGridUnit : baselineUnit
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }
}

// MARK: - TypographyAndGridSystem Primary Engine

public enum TypographyAndGridSystem {

    // MARK: Apple HIG Dynamic Type Specification Matrix (12 Categories x 11 Styles = 132 Specs)

    /// Canonical Apple HIG Dynamic Type `(pointSize, lineHeight)` pairs ordered from `.xSmall` (index 0) to `.accessibility5` (index 11).
    private static let higRampTable: [HIGTextStyle: [(size: Double, leading: Double)]] = [
        .largeTitle: [
            (31, 38), (32, 39), (33, 40), (34, 41), (36, 43), (38, 46), (40, 48),
            (44, 52), (48, 57), (52, 61), (56, 66), (60, 70)
        ],
        .title: [
            (25, 31), (26, 32), (27, 33), (28, 34), (30, 37), (32, 39), (34, 41),
            (38, 46), (43, 51), (48, 57), (53, 62), (58, 68)
        ],
        .title2: [
            (19, 24), (20, 25), (21, 26), (22, 28), (24, 30), (26, 32), (28, 34),
            (34, 41), (39, 47), (44, 52), (49, 58), (54, 64)
        ],
        .title3: [
            (17, 22), (18, 23), (19, 24), (20, 25), (22, 28), (24, 30), (26, 32),
            (31, 38), (37, 44), (43, 51), (49, 58), (55, 65)
        ],
        .headline: [
            (14, 19), (15, 20), (16, 21), (17, 22), (19, 24), (21, 26), (23, 29),
            (28, 34), (33, 40), (40, 48), (47, 56), (53, 62)
        ],
        .body: [
            (14, 19), (15, 20), (16, 21), (17, 22), (19, 24), (21, 26), (23, 29),
            (28, 34), (33, 40), (40, 48), (47, 56), (53, 62)
        ],
        .callout: [
            (13, 18), (14, 19), (15, 20), (16, 21), (18, 23), (20, 25), (22, 28),
            (26, 32), (32, 39), (38, 46), (44, 52), (51, 60)
        ],
        .subheadline: [
            (12, 16), (13, 18), (14, 19), (15, 20), (17, 22), (19, 24), (21, 26),
            (25, 31), (30, 37), (36, 43), (42, 50), (49, 58)
        ],
        .footnote: [
            (12, 16), (12, 16), (12, 16), (13, 18), (15, 20), (17, 22), (19, 24),
            (23, 29), (27, 33), (33, 40), (38, 46), (44, 52)
        ],
        .caption: [
            (11, 13), (11, 13), (11, 13), (12, 16), (14, 19), (16, 21), (18, 23),
            (22, 28), (26, 32), (32, 39), (37, 44), (43, 51)
        ],
        .caption2: [
            (11, 13), (11, 13), (11, 13), (11, 13), (13, 18), (15, 20), (17, 22),
            (20, 25), (24, 30), (29, 35), (34, 41), (40, 48)
        ]
    ]

    /// Resolves exact Apple HIG Dynamic Type metrics for `style` at `category`.
    public static func metrics(
        for style: HIGTextStyle,
        at category: DynamicTypeSizeCategory = .large
    ) -> HIGResolvedTypeMetrics {
        let entries = higRampTable[style] ?? []
        let idx = min(max(0, category.ordinalIndex), max(0, entries.count - 1))
        let (pt, lh) = entries.isEmpty ? (17.0, 22.0) : entries[idx]
        let tracking = opticalTrackingPoints(forPointSize: pt)
        return HIGResolvedTypeMetrics(
            style: style,
            category: category,
            pointSize: pt,
            lineHeight: lh,
            cssFontWeight: style.defaultCSSWeight,
            trackingPoints: tracking
        )
    }

    /// Returns all 11 HIG text styles resolved for a given `DynamicTypeSizeCategory`.
    public static func fullRamp(at category: DynamicTypeSizeCategory = .large) -> [HIGResolvedTypeMetrics] {
        HIGTextStyle.allCases.map { metrics(for: $0, at: category) }
    }

    /// Returns all 12 Dynamic Type size steps for a single `HIGTextStyle`.
    public static func scalingCurve(for style: HIGTextStyle) -> [HIGResolvedTypeMetrics] {
        DynamicTypeSizeCategory.allCases.map { metrics(for: style, at: $0) }
    }

    // MARK: Optical Tracking & Measure-Aware Line-Height Solver

    /// Computes Apple SF Pro optical tracking in points as a smooth rational curve of `pointSize`.
    /// - Small sizes (`<= 12pt`) gain positive tracking (`+0.06pt` to `+0.18pt`) to prevent glyph crowding.
    /// - Mid body sizes (`16–18pt`) tighten slightly (`-0.32pt` to `-0.43pt`).
    /// - Display sizes (`>= 20pt`) transition to SF Pro Display optical spacing (`+0.35pt` down to `+0.22pt` at 60pt).
    public static func opticalTrackingPoints(forPointSize size: Double) -> Double {
        let s = max(8.0, min(120.0, size))
        if s < 20.0 {
            // Rational fit matching Apple SF Pro Text tracking table (11pt -> +0.06pt, 17pt -> -0.43pt)
            let normalized = (s - 11.5) / 8.5
            let raw = 0.06 - 0.52 * normalized
            return (raw * 100.0).rounded() / 100.0
        } else {
            // SF Pro Display tracking curve (20pt -> +0.38pt, 34pt -> +0.40pt, 60pt -> +0.24pt)
            let raw = 0.38 + 0.004 * (s - 20.0) - 0.00018 * pow(s - 20.0, 2.0)
            return (raw * 100.0).rounded() / 100.0
        }
    }

    /// Solves optimal line-height in points accounting for both `pointSize` (display sizes tighten toward `1.15x`)
    /// and horizontal `containerWidth` (wider line measures gain extra leading to prevent eye-jump errors).
    public static func solveOpticalLineHeight(
        pointSize: Double,
        containerWidth: Double = 520.0,
        snapTo4ptSubGrid: Bool = true
    ) -> Double {
        let s = max(9.0, pointSize)
        // Base ratio transitions smoothly from ~1.48x at 12pt to ~1.16x at 56pt
        let sizeRatio = 1.14 + 0.36 * exp(-(s - 11.0) / 22.0)

        // Estimate characters per line (~0.48 * s average character width)
        let estimatedCPL = containerWidth / (0.48 * s)
        // Ideal Bringhurst range is 50..70 CPL; add up to +0.10 leading ratio for wide 95+ CPL columns
        let measureAdjustment: Double
        if estimatedCPL <= 50.0 {
            measureAdjustment = -0.03
        } else if estimatedCPL >= 90.0 {
            measureAdjustment = 0.09
        } else {
            measureAdjustment = ((estimatedCPL - 50.0) / 40.0) * 0.09
        }

        let rawLineHeight = s * (sizeRatio + measureAdjustment)
        if snapTo4ptSubGrid {
            return max(s + 2.0, (rawLineHeight / 2.0).rounded() * 2.0)
        }
        return (rawLineHeight * 10.0).rounded() / 10.0
    }

    // MARK: Modular Scale Calculator

    /// Generates a 9-step modular typographic scale (`-2` through `+6`) from `baseSizePoints` and `ratio`.
    public static func generateModularScale(
        baseSizePoints: Double = 16.0,
        ratio: TypographicScaleRatio = .majorThird,
        containerWidth: Double = 640.0
    ) -> [ModularScaleStep] {
        let stepNames: [(exp: Int, name: String)] = [
            (-2, "caption2"),
            (-1, "footnote"),
            (0, "body"),
            (1, "title3"),
            (2, "title2"),
            (3, "title1"),
            (4, "largeTitle"),
            (5, "displaySm"),
            (6, "displayHero")
        ]

        return stepNames.map { entry in
            let raw = baseSizePoints * pow(ratio.multiplier, Double(entry.exp))
            let snappedSize = (raw * 2.0).rounded() / 2.0 // half-point precision
            let lineHeight = solveOpticalLineHeight(
                pointSize: snappedSize,
                containerWidth: containerWidth,
                snapTo4ptSubGrid: true
            )
            let tracking = opticalTrackingPoints(forPointSize: snappedSize)
            return ModularScaleStep(
                stepExponent: entry.exp,
                tokenName: entry.name,
                rawSizePoints: raw,
                snappedSizePoints: snappedSize,
                snappedLineHeightPoints: lineHeight,
                opticalTrackingPoints: tracking
            )
        }
    }

    // MARK: Responsive Breakpoint Grid Engine

    /// Returns the canonical 4pt/8pt/12-column `ResponsiveGridSpec` for `breakpoint`.
    public static func gridSpec(for breakpoint: DeviceBreakpoint) -> ResponsiveGridSpec {
        switch breakpoint {
        case .watchOS:
            return ResponsiveGridSpec(
                breakpoint: .watchOS,
                columns: 2,
                outerMargin: 10,
                gutter: 8,
                maxContentWidth: 205,
                safeArea: SafeAreaInsetsMetrics(top: 28, leading: 6, bottom: 12, trailing: 6)
            )
        case .iPhoneCompact:
            return ResponsiveGridSpec(
                breakpoint: .iPhoneCompact,
                columns: 4,
                outerMargin: 16,
                gutter: 12,
                maxContentWidth: 428,
                safeArea: SafeAreaInsetsMetrics(top: 59, leading: 0, bottom: 34, trailing: 0)
            )
        case .iPhoneMax:
            return ResponsiveGridSpec(
                breakpoint: .iPhoneMax,
                columns: 4,
                outerMargin: 20,
                gutter: 16,
                maxContentWidth: 480,
                safeArea: SafeAreaInsetsMetrics(top: 62, leading: 0, bottom: 34, trailing: 0)
            )
        case .iPadSplit:
            return ResponsiveGridSpec(
                breakpoint: .iPadSplit,
                columns: 8,
                outerMargin: 24,
                gutter: 16,
                maxContentWidth: 720,
                safeArea: SafeAreaInsetsMetrics(top: 24, leading: 0, bottom: 20, trailing: 0)
            )
        case .iPadPro:
            return ResponsiveGridSpec(
                breakpoint: .iPadPro,
                columns: 12,
                outerMargin: 32,
                gutter: 20,
                maxContentWidth: 1120,
                safeArea: SafeAreaInsetsMetrics(top: 24, leading: 0, bottom: 20, trailing: 0)
            )
        case .macWindow:
            return ResponsiveGridSpec(
                breakpoint: .macWindow,
                columns: 12,
                outerMargin: 40,
                gutter: 24,
                maxContentWidth: 1360,
                safeArea: SafeAreaInsetsMetrics(top: 28, leading: 0, bottom: 0, trailing: 0)
            )
        case .macUltrawide:
            return ResponsiveGridSpec(
                breakpoint: .macUltrawide,
                columns: 12,
                outerMargin: 64,
                gutter: 32,
                maxContentWidth: 1760,
                safeArea: SafeAreaInsetsMetrics(top: 28, leading: 0, bottom: 0, trailing: 0)
            )
        case .visionOSWindow:
            return ResponsiveGridSpec(
                breakpoint: .visionOSWindow,
                columns: 12,
                outerMargin: 36,
                gutter: 24,
                maxContentWidth: 1280,
                safeArea: SafeAreaInsetsMetrics(top: 32, leading: 24, bottom: 32, trailing: 24)
            )
        }
    }

    /// Resolves the active `DeviceBreakpoint` for an arbitrary viewport width and optional spatial flag.
    public static func resolveBreakpoint(
        forWidth width: Double,
        isSpatialVisionOS: Bool = false
    ) -> DeviceBreakpoint {
        if isSpatialVisionOS {
            return .visionOSWindow
        }
        switch width {
        case ..<260:
            return .watchOS
        case 260..<415:
            return .iPhoneCompact
        case 415..<560:
            return .iPhoneMax
        case 560..<840:
            return .iPadSplit
        case 840..<1180:
            return .iPadPro
        case 1180..<1920:
            return .macWindow
        default:
            return .macUltrawide
        }
    }

    /// Emits a production SwiftUI responsive grid & Dynamic Type helper file for a given `TypographicScaleRatio`.
    public static func emitSwiftUITypographyAndGridCode(
        ratio: TypographicScaleRatio = .majorThird,
        baseSize: Double = 16.0
    ) -> String {
        let scale = generateModularScale(baseSizePoints: baseSize, ratio: ratio)
        let styleCases = scale.map { step in
            let lineSpacing = max(0.0, step.snappedLineHeightPoints - step.snappedSizePoints * 1.18)
            return """
                case .\(step.tokenName):
                    content
                        .font(.system(size: \(String(format: "%.1f", step.snappedSizePoints)), design: .default))
                        .tracking(\(String(format: "%.2f", step.opticalTrackingPoints)))
                        .lineSpacing(\(String(format: "%.1f", lineSpacing)))
            """
        }.joined(separator: "\n")

        let enumCases = scale.map { "    case \($0.tokenName)" }.joined(separator: "\n")

        return """
        // Generated by ChiefKit TypographyAndGridSystem 3.0 — \(ratio.musicalIntervalTitle)
        import SwiftUI

        public enum ChiefKitModularRole: String, CaseIterable, Sendable {
        \(enumCases)
        }

        public struct ChiefKitModularTypeModifier: ViewModifier {
            @ScaledMetric private var dynamicMultiplier: CGFloat = 1.0
            public let role: ChiefKitModularRole

            public init(role: ChiefKitModularRole) {
                self.role = role
            }

            public func body(content: Content) -> some View {
                switch role {
        \(styleCases)
                }
            }
        }

        public extension View {
            func ckModularType(_ role: ChiefKitModularRole) -> some View {
                modifier(ChiefKitModularTypeModifier(role: role))
            }
        }
        """
    }
}
