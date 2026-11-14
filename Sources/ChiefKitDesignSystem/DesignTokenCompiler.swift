#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Multi-Platform Design Token Targets & Modes

public enum DesignTokenTarget: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case swiftUITheme
    case appKitNSColor
    case uiKitUIColor
    case w3cDTCGJSON
    case cssOKLCHVariables
    case tailwindV4Config
    case jetpackComposeKotlin
    case xcodeAssetCatalogJSON

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .swiftUITheme: "SwiftUI Adaptive Theme"
        case .appKitNSColor: "AppKit Dynamic NSColor"
        case .uiKitUIColor: "UIKit Trait-Resolved UIColor"
        case .w3cDTCGJSON: "W3C Design Tokens (DTCG JSON)"
        case .cssOKLCHVariables: "CSS Level 4 OKLCH Variables"
        case .tailwindV4Config: "Tailwind CSS v4 @theme"
        case .jetpackComposeKotlin: "Jetpack Compose Material3 Kotlin"
        case .xcodeAssetCatalogJSON: "Xcode .xcassets Catalog JSON"
        }
    }

    public var defaultFilename: String {
        switch self {
        case .swiftUITheme: "ChiefKitSemanticTheme.swift"
        case .appKitNSColor: "NSColor+ChiefKitTokens.swift"
        case .uiKitUIColor: "UIColor+ChiefKitTokens.swift"
        case .w3cDTCGJSON: "chiefkit.tokens.json"
        case .cssOKLCHVariables: "chiefkit-tokens.css"
        case .tailwindV4Config: "chiefkit-tailwind-v4.css"
        case .jetpackComposeKotlin: "ChiefKitThemeTokens.kt"
        case .xcodeAssetCatalogJSON: "ChiefKitColors.xcassets.json"
        }
    }

    public var fileExtension: String {
        switch self {
        case .swiftUITheme, .appKitNSColor, .uiKitUIColor: "swift"
        case .w3cDTCGJSON, .xcodeAssetCatalogJSON: "json"
        case .cssOKLCHVariables, .tailwindV4Config: "css"
        case .jetpackComposeKotlin: "kt"
        }
    }

    public var languageIdentifier: String {
        switch self {
        case .swiftUITheme, .appKitNSColor, .uiKitUIColor: "swift"
        case .w3cDTCGJSON, .xcodeAssetCatalogJSON: "json"
        case .cssOKLCHVariables, .tailwindV4Config: "css"
        case .jetpackComposeKotlin: "kotlin"
        }
    }
}

public enum DesignAppearanceMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case light
    case dark
    case highContrastLight
    case highContrastDark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .highContrastLight: "High Contrast Light"
        case .highContrastDark: "High Contrast Dark"
        }
    }

    public var isDark: Bool {
        self == .dark || self == .highContrastDark
    }

    public var isHighContrast: Bool {
        self == .highContrastLight || self == .highContrastDark
    }
}

// MARK: - Semantic Color Roles

public enum SemanticColorRole: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case canvasBackground
    case surfacePrimary
    case surfaceElevated
    case surfaceSunken
    case surfaceGlassTint
    case textPrimary
    case textSecondary
    case textTertiary
    case textOnBrand
    case brandPrimary
    case brandPrimaryHover
    case brandPrimaryActive
    case brandSubtleFill
    case borderSubtle
    case borderStrong
    case borderFocusRing
    case statusSuccess
    case statusSuccessSubtle
    case statusWarning
    case statusWarningSubtle
    case statusDanger
    case statusDangerSubtle
    case specularHighlight

    public var id: String { rawValue }

    public var kebabCaseName: String {
        var result = ""
        for ch in rawValue {
            if ch.isUppercase {
                result.append("-")
                result.append(ch.lowercased())
            } else {
                result.append(ch)
            }
        }
        return result
    }

    public var pascalCaseName: String {
        guard let first = rawValue.first else { return rawValue }
        return first.uppercased() + rawValue.dropFirst()
    }

    public var tokenDescription: String {
        switch self {
        case .canvasBackground: "Root window or scroll-canvas backdrop surface."
        case .surfacePrimary: "Default card, sheet, or list-row container surface."
        case .surfaceElevated: "Popover, modal, or floating inspector surface."
        case .surfaceSunken: "Recessed input well, code block, or track background."
        case .surfaceGlassTint: "Translucent Liquid Glass tint layer."
        case .textPrimary: "High-emphasis primary heading and body copy."
        case .textSecondary: "Supporting labels, metadata, and secondary copy."
        case .textTertiary: "Muted hints, timestamps, and disabled captions."
        case .textOnBrand: "Foreground label rendered atop solid brandPrimary fill."
        case .brandPrimary: "Primary interactive CTA and accent fill."
        case .brandPrimaryHover: "Hovered state for primary brand controls."
        case .brandPrimaryActive: "Pressed/active state for primary brand controls."
        case .brandSubtleFill: "Low-chroma tinted badge or selected-row background."
        case .borderSubtle: "Hairline divider and subtle card stroke."
        case .borderStrong: "High-visibility input border and control outline."
        case .borderFocusRing: "Keyboard accessibility focus indicator ring."
        case .statusSuccess: "Positive confirmation, healthy check, or gain delta."
        case .statusSuccessSubtle: "Tinted background banner for positive status."
        case .statusWarning: "Cautionary alert, latency spike, or pending review."
        case .statusWarningSubtle: "Tinted background banner for warning status."
        case .statusDanger: "Destructive action, validation error, or critical failure."
        case .statusDangerSubtle: "Tinted background banner for critical status."
        case .specularHighlight: "Top-edge Liquid Glass rim highlight stroke."
        }
    }
}

// MARK: - Primitive & Semantic Token Bundles

public struct ElevationShadowSpec: Codable, Hashable, Sendable {
    public let name: String
    public let offsetY: Double
    public let blurRadius: Double
    public let spread: Double
    public let opacityLight: Double
    public let opacityDark: Double

    public init(
        name: String,
        offsetY: Double,
        blurRadius: Double,
        spread: Double,
        opacityLight: Double,
        opacityDark: Double
    ) {
        self.name = name
        self.offsetY = offsetY
        self.blurRadius = blurRadius
        self.spread = spread
        self.opacityLight = opacityLight
        self.opacityDark = opacityDark
    }
}

public struct PrimitiveTokenPalette: Codable, Hashable, Sendable {
    public let primaryRamp: TonalScale
    public let secondaryRamp: TonalScale
    public let neutralRamp: TonalScale
    public let successRamp: TonalScale
    public let warningRamp: TonalScale
    public let dangerRamp: TonalScale

    public let spacingSteps: [(name: String, points: Double)]
    public let radiusSteps: [(name: String, points: Double)]
    public let elevations: [ElevationShadowSpec]

    public let isLiquidGlassEnabled: Bool
    public let glassFrost: Double
    public let specularRim: Double
    public let glassBlurRadius: Double

    enum CodingKeys: String, CodingKey {
        case primaryRamp, secondaryRamp, neutralRamp, successRamp, warningRamp, dangerRamp
        case spacingNames, spacingPoints, radiusNames, radiusPoints, elevations
        case isLiquidGlassEnabled, glassFrost, specularRim, glassBlurRadius
    }

    public init(from tokens: StudioThemeTokens) {
        self.primaryRamp = PerceptualColorScience.generateTonalScale(named: "primary", from: tokens.primary)
        self.secondaryRamp = PerceptualColorScience.generateTonalScale(named: "secondary", from: tokens.secondary)

        // Neutral ramp subtly tinted with 12% of the primary hue chroma so grays feel cohesive
        let primaryOklch = tokens.primary.oklch
        let tintedNeutralSeed = OklchColor(
            l: 0.52,
            c: min(0.016, primaryOklch.c * 0.10),
            h: primaryOklch.h
        ).gamutMappedToSRGB()
        self.neutralRamp = PerceptualColorScience.generateTonalScale(named: "neutral", from: tintedNeutralSeed)

        self.successRamp = PerceptualColorScience.generateTonalScale(named: "success", from: tokens.success)
        self.warningRamp = PerceptualColorScience.generateTonalScale(named: "warning", from: tokens.warning)
        self.dangerRamp = PerceptualColorScience.generateTonalScale(named: "danger", from: tokens.danger)

        let s = tokens.spacingScale
        self.spacingSteps = [
            ("0", 0.0),
            ("2xs", (2.0 * s).rounded()),
            ("xs", (4.0 * s).rounded()),
            ("sm", (8.0 * s).rounded()),
            ("md", (12.0 * s).rounded()),
            ("lg", (16.0 * s).rounded()),
            ("xl", (24.0 * s).rounded()),
            ("2xl", (32.0 * s).rounded()),
            ("3xl", (48.0 * s).rounded()),
            ("4xl", (64.0 * s).rounded())
        ]

        self.radiusSteps = [
            ("none", 0.0),
            ("xs", max(2.0, (tokens.radiusSmall * 0.65).rounded())),
            ("sm", tokens.radiusSmall.rounded()),
            ("md", tokens.radiusMedium.rounded()),
            ("lg", tokens.radiusLarge.rounded()),
            ("xl", (tokens.radiusLarge * 1.4).rounded()),
            ("pill", 999.0)
        ]

        self.elevations = [
            ElevationShadowSpec(name: "xs", offsetY: 1, blurRadius: 3, spread: 0, opacityLight: 0.06, opacityDark: 0.24),
            ElevationShadowSpec(name: "sm", offsetY: 4, blurRadius: 10, spread: -1, opacityLight: 0.09, opacityDark: 0.32),
            ElevationShadowSpec(name: "md", offsetY: 10, blurRadius: 24, spread: -3, opacityLight: 0.12, opacityDark: 0.44),
            ElevationShadowSpec(name: "lg", offsetY: 20, blurRadius: 42, spread: -6, opacityLight: 0.18, opacityDark: 0.56)
        ]

        self.isLiquidGlassEnabled = tokens.isLiquidGlassEnabled
        self.glassFrost = tokens.glassFrost
        self.specularRim = tokens.specularRim
        self.glassBlurRadius = tokens.isLiquidGlassEnabled ? (tokens.glassFrost * 32.0).rounded() : 0.0
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.primaryRamp = try c.decode(TonalScale.self, forKey: .primaryRamp)
        self.secondaryRamp = try c.decode(TonalScale.self, forKey: .secondaryRamp)
        self.neutralRamp = try c.decode(TonalScale.self, forKey: .neutralRamp)
        self.successRamp = try c.decode(TonalScale.self, forKey: .successRamp)
        self.warningRamp = try c.decode(TonalScale.self, forKey: .warningRamp)
        self.dangerRamp = try c.decode(TonalScale.self, forKey: .dangerRamp)

        let sNames = try c.decode([String].self, forKey: .spacingNames)
        let sPoints = try c.decode([Double].self, forKey: .spacingPoints)
        self.spacingSteps = Array(zip(sNames, sPoints))

        let rNames = try c.decode([String].self, forKey: .radiusNames)
        let rPoints = try c.decode([Double].self, forKey: .radiusPoints)
        self.radiusSteps = Array(zip(rNames, rPoints))

        self.elevations = try c.decode([ElevationShadowSpec].self, forKey: .elevations)
        self.isLiquidGlassEnabled = try c.decode(Bool.self, forKey: .isLiquidGlassEnabled)
        self.glassFrost = try c.decode(Double.self, forKey: .glassFrost)
        self.specularRim = try c.decode(Double.self, forKey: .specularRim)
        self.glassBlurRadius = try c.decode(Double.self, forKey: .glassBlurRadius)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(primaryRamp, forKey: .primaryRamp)
        try c.encode(secondaryRamp, forKey: .secondaryRamp)
        try c.encode(neutralRamp, forKey: .neutralRamp)
        try c.encode(successRamp, forKey: .successRamp)
        try c.encode(warningRamp, forKey: .warningRamp)
        try c.encode(dangerRamp, forKey: .dangerRamp)
        try c.encode(spacingSteps.map(\.name), forKey: .spacingNames)
        try c.encode(spacingSteps.map(\.points), forKey: .spacingPoints)
        try c.encode(radiusSteps.map(\.name), forKey: .radiusNames)
        try c.encode(radiusSteps.map(\.points), forKey: .radiusPoints)
        try c.encode(elevations, forKey: .elevations)
        try c.encode(isLiquidGlassEnabled, forKey: .isLiquidGlassEnabled)
        try c.encode(glassFrost, forKey: .glassFrost)
        try c.encode(specularRim, forKey: .specularRim)
        try c.encode(glassBlurRadius, forKey: .glassBlurRadius)
    }

    public static func == (lhs: PrimitiveTokenPalette, rhs: PrimitiveTokenPalette) -> Bool {
        lhs.primaryRamp == rhs.primaryRamp &&
        lhs.secondaryRamp == rhs.secondaryRamp &&
        lhs.neutralRamp == rhs.neutralRamp &&
        lhs.successRamp == rhs.successRamp &&
        lhs.warningRamp == rhs.warningRamp &&
        lhs.dangerRamp == rhs.dangerRamp &&
        lhs.spacingSteps.map(\.name) == rhs.spacingSteps.map(\.name) &&
        lhs.spacingSteps.map(\.points) == rhs.spacingSteps.map(\.points) &&
        lhs.radiusSteps.map(\.name) == rhs.radiusSteps.map(\.name) &&
        lhs.radiusSteps.map(\.points) == rhs.radiusSteps.map(\.points) &&
        lhs.elevations == rhs.elevations &&
        lhs.isLiquidGlassEnabled == rhs.isLiquidGlassEnabled &&
        lhs.glassFrost == rhs.glassFrost &&
        lhs.specularRim == rhs.specularRim
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(primaryRamp)
        hasher.combine(neutralRamp)
        hasher.combine(isLiquidGlassEnabled)
        hasher.combine(glassFrost)
        hasher.combine(specularRim)
    }

    public var allRamps: [TonalScale] {
        [primaryRamp, secondaryRamp, neutralRamp, successRamp, warningRamp, dangerRamp]
    }
}

public struct ResolvedModeTokenMap: Codable, Hashable, Sendable {
    public let mode: DesignAppearanceMode
    public let colors: [SemanticColorRole: RGBAColor]

    public init(mode: DesignAppearanceMode, colors: [SemanticColorRole: RGBAColor]) {
        self.mode = mode
        self.colors = colors
    }

    public subscript(role: SemanticColorRole) -> RGBAColor {
        colors[role] ?? .white
    }
}

// MARK: - Token Audit & Compilation Artifacts

public struct DesignTokenAuditFinding: Codable, Hashable, Sendable {
    public let mode: DesignAppearanceMode
    public let role: SemanticColorRole
    public let measuredLc: Double
    public let requiredLc: Double
    public let message: String

    public init(
        mode: DesignAppearanceMode,
        role: SemanticColorRole,
        measuredLc: Double,
        requiredLc: Double,
        message: String
    ) {
        self.mode = mode
        self.role = role
        self.measuredLc = measuredLc
        self.requiredLc = requiredLc
        self.message = message
    }
}

public struct DesignTokenAuditReport: Codable, Hashable, Sendable {
    public let passesAllChecks: Bool
    public let statusPaletteDichromatSafe: Bool
    public let minimumTextPrimaryLc: Double
    public let minimumBrandContrastLc: Double
    public let findings: [DesignTokenAuditFinding]

    public init(
        passesAllChecks: Bool,
        statusPaletteDichromatSafe: Bool,
        minimumTextPrimaryLc: Double,
        minimumBrandContrastLc: Double,
        findings: [DesignTokenAuditFinding]
    ) {
        self.passesAllChecks = passesAllChecks
        self.statusPaletteDichromatSafe = statusPaletteDichromatSafe
        self.minimumTextPrimaryLc = minimumTextPrimaryLc
        self.minimumBrandContrastLc = minimumBrandContrastLc
        self.findings = findings
    }
}

public struct CompiledTokenFile: Codable, Hashable, Identifiable, Sendable {
    public var id: DesignTokenTarget { target }
    public let target: DesignTokenTarget
    public let filename: String
    public let sourceCode: String
    public let exportedTokenCount: Int
    public let lineCount: Int
    public let checksumHex: String

    public init(
        target: DesignTokenTarget,
        filename: String,
        sourceCode: String,
        exportedTokenCount: Int
    ) {
        self.target = target
        self.filename = filename
        self.sourceCode = sourceCode
        self.exportedTokenCount = exportedTokenCount
        self.lineCount = sourceCode.split(separator: "\n", omittingEmptySubsequences: false).count
        self.checksumHex = Self.fnv1a64Hex(sourceCode)
    }

    private static func fnv1a64Hex(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}

public struct CompiledTokenBundle: Codable, Hashable, Sendable {
    public let namespace: String
    public let primitives: PrimitiveTokenPalette
    public let modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    public let files: [CompiledTokenFile]
    public let auditReport: DesignTokenAuditReport

    public init(
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap],
        files: [CompiledTokenFile],
        auditReport: DesignTokenAuditReport
    ) {
        self.namespace = namespace
        self.primitives = primitives
        self.modeMaps = modeMaps
        self.files = files
        self.auditReport = auditReport
    }

    public func file(for target: DesignTokenTarget) -> CompiledTokenFile? {
        files.first { $0.target == target }
    }
}

// MARK: - DesignTokenCompiler

public enum DesignTokenCompiler {

    /// Synthesizes semantic token maps across Light, Dark, High-Contrast Light, and High-Contrast Dark modes
    /// with automatic APCA contrast enforcement.
    public static func resolveSemanticModes(
        tokens: StudioThemeTokens,
        primitives: PrimitiveTokenPalette
    ) -> [DesignAppearanceMode: ResolvedModeTokenMap] {
        let p = primitives.primaryRamp
        let n = primitives.neutralRamp
        let ok = primitives.successRamp
        let warn = primitives.warningRamp
        let err = primitives.dangerRamp

        func buildMap(for mode: DesignAppearanceMode) -> ResolvedModeTokenMap {
            var map: [SemanticColorRole: RGBAColor] = [:]

            switch mode {
            case .light:
                let surfacePrimary = RGBAColor.white
                let canvasBg = tokens.surface
                map[.canvasBackground] = canvasBg
                map[.surfacePrimary] = surfacePrimary
                map[.surfaceElevated] = RGBAColor.white
                map[.surfaceSunken] = n[.s100]
                map[.surfaceGlassTint] = RGBAColor(
                    red: surfacePrimary.red,
                    green: surfacePrimary.green,
                    blue: surfacePrimary.blue,
                    alpha: tokens.glassFrost
                )
                map[.textPrimary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s950], against: surfacePrimary, minimumMagnitudeLc: 85.0
                )
                map[.textSecondary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s600], against: surfacePrimary, minimumMagnitudeLc: 62.0
                )
                map[.textTertiary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s500], against: surfacePrimary, minimumMagnitudeLc: 46.0
                )
                let brand = PerceptualColorScience.adjustForAPCAContrast(
                    text: p[.s600], against: surfacePrimary, minimumMagnitudeLc: 55.0
                )
                map[.brandPrimary] = brand
                map[.brandPrimaryHover] = p[.s700]
                map[.brandPrimaryActive] = p[.s800]
                map[.brandSubtleFill] = p[.s100]
                map[.textOnBrand] = abs(RGBAColor.white.apcaContrast(against: brand)) >= 55.0
                    ? .white
                    : n[.s950]
                map[.borderSubtle] = n[.s200]
                map[.borderStrong] = n[.s400]
                map[.borderFocusRing] = p[.s500]
                map[.statusSuccess] = PerceptualColorScience.adjustForAPCAContrast(
                    text: ok[.s700], against: surfacePrimary, minimumMagnitudeLc: 55.0
                )
                map[.statusSuccessSubtle] = ok[.s100]
                map[.statusWarning] = PerceptualColorScience.adjustForAPCAContrast(
                    text: warn[.s700], against: surfacePrimary, minimumMagnitudeLc: 52.0
                )
                map[.statusWarningSubtle] = warn[.s100]
                map[.statusDanger] = PerceptualColorScience.adjustForAPCAContrast(
                    text: err[.s600], against: surfacePrimary, minimumMagnitudeLc: 55.0
                )
                map[.statusDangerSubtle] = err[.s100]
                map[.specularHighlight] = RGBAColor(red: 1, green: 1, blue: 1, alpha: tokens.specularRim)

            case .dark:
                let canvasBg = RGBAColor(red: 0.055, green: 0.065, blue: 0.088)
                let surfacePrimary = n[.s950]
                map[.canvasBackground] = canvasBg
                map[.surfacePrimary] = surfacePrimary
                map[.surfaceElevated] = n[.s900]
                map[.surfaceSunken] = RGBAColor(red: 0.035, green: 0.042, blue: 0.058)
                map[.surfaceGlassTint] = RGBAColor(
                    red: n[.s900].red,
                    green: n[.s900].green,
                    blue: n[.s900].blue,
                    alpha: tokens.glassFrost
                )
                map[.textPrimary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s50], against: surfacePrimary, minimumMagnitudeLc: 85.0
                )
                map[.textSecondary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s300], against: surfacePrimary, minimumMagnitudeLc: 62.0
                )
                map[.textTertiary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s400], against: surfacePrimary, minimumMagnitudeLc: 46.0
                )
                let brand = PerceptualColorScience.adjustForAPCAContrast(
                    text: p[.s400], against: surfacePrimary, minimumMagnitudeLc: 55.0
                )
                map[.brandPrimary] = brand
                map[.brandPrimaryHover] = p[.s300]
                map[.brandPrimaryActive] = p[.s500]
                map[.brandSubtleFill] = p[.s900]
                map[.textOnBrand] = abs(n[.s950].apcaContrast(against: brand)) >= abs(RGBAColor.white.apcaContrast(against: brand))
                    ? n[.s950]
                    : .white
                map[.borderSubtle] = n[.s800]
                map[.borderStrong] = n[.s600]
                map[.borderFocusRing] = p[.s400]
                map[.statusSuccess] = PerceptualColorScience.adjustForAPCAContrast(
                    text: ok[.s400], against: surfacePrimary, minimumMagnitudeLc: 55.0
                )
                map[.statusSuccessSubtle] = ok[.s900]
                map[.statusWarning] = PerceptualColorScience.adjustForAPCAContrast(
                    text: warn[.s300], against: surfacePrimary, minimumMagnitudeLc: 55.0
                )
                map[.statusWarningSubtle] = warn[.s900]
                map[.statusDanger] = PerceptualColorScience.adjustForAPCAContrast(
                    text: err[.s400], against: surfacePrimary, minimumMagnitudeLc: 55.0
                )
                map[.statusDangerSubtle] = err[.s900]
                map[.specularHighlight] = RGBAColor(red: 1, green: 1, blue: 1, alpha: tokens.specularRim * 0.55)

            case .highContrastLight:
                let surfacePrimary = RGBAColor.white
                map[.canvasBackground] = RGBAColor(red: 0.98, green: 0.98, blue: 0.99)
                map[.surfacePrimary] = surfacePrimary
                map[.surfaceElevated] = surfacePrimary
                map[.surfaceSunken] = n[.s100]
                map[.surfaceGlassTint] = RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.94)
                map[.textPrimary] = RGBAColor(red: 0.02, green: 0.02, blue: 0.03)
                map[.textSecondary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s800], against: surfacePrimary, minimumMagnitudeLc: 78.0
                )
                map[.textTertiary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s700], against: surfacePrimary, minimumMagnitudeLc: 64.0
                )
                let brand = PerceptualColorScience.adjustForAPCAContrast(
                    text: p[.s800], against: surfacePrimary, minimumMagnitudeLc: 72.0
                )
                map[.brandPrimary] = brand
                map[.brandPrimaryHover] = p[.s900]
                map[.brandPrimaryActive] = p[.s950]
                map[.brandSubtleFill] = p[.s100]
                map[.textOnBrand] = .white
                map[.borderSubtle] = n[.s500]
                map[.borderStrong] = n[.s900]
                map[.borderFocusRing] = p[.s800]
                map[.statusSuccess] = PerceptualColorScience.adjustForAPCAContrast(
                    text: ok[.s800], against: surfacePrimary, minimumMagnitudeLc: 70.0
                )
                map[.statusSuccessSubtle] = ok[.s50]
                map[.statusWarning] = PerceptualColorScience.adjustForAPCAContrast(
                    text: warn[.s800], against: surfacePrimary, minimumMagnitudeLc: 68.0
                )
                map[.statusWarningSubtle] = warn[.s50]
                map[.statusDanger] = PerceptualColorScience.adjustForAPCAContrast(
                    text: err[.s800], against: surfacePrimary, minimumMagnitudeLc: 70.0
                )
                map[.statusDangerSubtle] = err[.s50]
                map[.specularHighlight] = RGBAColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.28)

            case .highContrastDark:
                let surfacePrimary = RGBAColor(red: 0.02, green: 0.02, blue: 0.03)
                map[.canvasBackground] = RGBAColor(red: 0.0, green: 0.0, blue: 0.0)
                map[.surfacePrimary] = surfacePrimary
                map[.surfaceElevated] = n[.s950]
                map[.surfaceSunken] = RGBAColor(red: 0.0, green: 0.0, blue: 0.0)
                map[.surfaceGlassTint] = RGBAColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 0.94)
                map[.textPrimary] = .white
                map[.textSecondary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s100], against: surfacePrimary, minimumMagnitudeLc: 80.0
                )
                map[.textTertiary] = PerceptualColorScience.adjustForAPCAContrast(
                    text: n[.s200], against: surfacePrimary, minimumMagnitudeLc: 66.0
                )
                let brand = PerceptualColorScience.adjustForAPCAContrast(
                    text: p[.s300], against: surfacePrimary, minimumMagnitudeLc: 72.0
                )
                map[.brandPrimary] = brand
                map[.brandPrimaryHover] = p[.s200]
                map[.brandPrimaryActive] = p[.s400]
                map[.brandSubtleFill] = p[.s950]
                map[.textOnBrand] = RGBAColor(red: 0.02, green: 0.02, blue: 0.03)
                map[.borderSubtle] = n[.s500]
                map[.borderStrong] = n[.s100]
                map[.borderFocusRing] = p[.s200]
                map[.statusSuccess] = PerceptualColorScience.adjustForAPCAContrast(
                    text: ok[.s300], against: surfacePrimary, minimumMagnitudeLc: 70.0
                )
                map[.statusSuccessSubtle] = ok[.s950]
                map[.statusWarning] = PerceptualColorScience.adjustForAPCAContrast(
                    text: warn[.s200], against: surfacePrimary, minimumMagnitudeLc: 70.0
                )
                map[.statusWarningSubtle] = warn[.s950]
                map[.statusDanger] = PerceptualColorScience.adjustForAPCAContrast(
                    text: err[.s300], against: surfacePrimary, minimumMagnitudeLc: 70.0
                )
                map[.statusDangerSubtle] = err[.s950]
                map[.specularHighlight] = RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.85)
            }

            return ResolvedModeTokenMap(mode: mode, colors: map)
        }

        var result: [DesignAppearanceMode: ResolvedModeTokenMap] = [:]
        for mode in DesignAppearanceMode.allCases {
            result[mode] = buildMap(for: mode)
        }
        return result
    }

    /// Audits resolved semantic token maps across all 4 modes for APCA compliance and CVD distinguishability.
    public static func audit(
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> DesignTokenAuditReport {
        var findings: [DesignTokenAuditFinding] = []
        var minPrimaryTextLc = Double.greatestFiniteMagnitude
        var minBrandLc = Double.greatestFiniteMagnitude

        for mode in DesignAppearanceMode.allCases {
            guard let map = modeMaps[mode] else { continue }
            let surface = map[.surfacePrimary]

            let primaryLc = abs(map[.textPrimary].apcaContrast(against: surface))
            minPrimaryTextLc = min(minPrimaryTextLc, primaryLc)
            let requiredPrimary = mode.isHighContrast ? 90.0 : 75.0
            if primaryLc < requiredPrimary {
                findings.append(
                    DesignTokenAuditFinding(
                        mode: mode,
                        role: .textPrimary,
                        measuredLc: primaryLc,
                        requiredLc: requiredPrimary,
                        message: "Primary text APCA contrast falls below \(Int(requiredPrimary)) Lc in \(mode.label)."
                    )
                )
            }

            let secondaryLc = abs(map[.textSecondary].apcaContrast(against: surface))
            let requiredSecondary = mode.isHighContrast ? 72.0 : 58.0
            if secondaryLc < requiredSecondary {
                findings.append(
                    DesignTokenAuditFinding(
                        mode: mode,
                        role: .textSecondary,
                        measuredLc: secondaryLc,
                        requiredLc: requiredSecondary,
                        message: "Secondary text APCA contrast falls below \(Int(requiredSecondary)) Lc in \(mode.label)."
                    )
                )
            }

            let brandLc = abs(map[.brandPrimary].apcaContrast(against: surface))
            minBrandLc = min(minBrandLc, brandLc)
            if brandLc < 45.0 {
                findings.append(
                    DesignTokenAuditFinding(
                        mode: mode,
                        role: .brandPrimary,
                        measuredLc: brandLc,
                        requiredLc: 45.0,
                        message: "Brand primary fill lacks sufficient perceptual separation from primary surface."
                    )
                )
            }
        }

        let lightMap = modeMaps[.light]
        let statusSamples: [RGBAColor] = [
            lightMap?[.statusSuccess] ?? .white,
            lightMap?[.statusWarning] ?? .white,
            lightMap?[.statusDanger] ?? .white,
            lightMap?[.brandPrimary] ?? .white
        ]
        let cvdSafety = PerceptualColorScience.auditPaletteDistinguishability(
            colors: statusSamples,
            minimumDeltaE2000: 6.0
        )

        return DesignTokenAuditReport(
            passesAllChecks: findings.isEmpty,
            statusPaletteDichromatSafe: cvdSafety.isUniversalSafe,
            minimumTextPrimaryLc: minPrimaryTextLc.isFinite ? minPrimaryTextLc : 0.0,
            minimumBrandContrastLc: minBrandLc.isFinite ? minBrandLc : 0.0,
            findings: findings
        )
    }

    /// Compiles all 8 multi-platform token targets simultaneously into a deterministic `CompiledTokenBundle`.
    public static func compileAllTargets(
        tokens: StudioThemeTokens,
        namespace: String = "ChiefKit"
    ) -> CompiledTokenBundle {
        let primitives = PrimitiveTokenPalette(from: tokens)
        let modeMaps = resolveSemanticModes(tokens: tokens, primitives: primitives)
        let auditReport = audit(modeMaps: modeMaps)

        let files = DesignTokenTarget.allCases.map { target in
            compile(
                target: target,
                namespace: namespace,
                primitives: primitives,
                modeMaps: modeMaps
            )
        }

        return CompiledTokenBundle(
            namespace: namespace,
            primitives: primitives,
            modeMaps: modeMaps,
            files: files,
            auditReport: auditReport
        )
    }

    /// Compiles a single `DesignTokenTarget` from `StudioThemeTokens`.
    public static func compile(
        tokens: StudioThemeTokens,
        target: DesignTokenTarget,
        namespace: String = "ChiefKit"
    ) -> CompiledTokenFile {
        let primitives = PrimitiveTokenPalette(from: tokens)
        let modeMaps = resolveSemanticModes(tokens: tokens, primitives: primitives)
        return compile(
            target: target,
            namespace: namespace,
            primitives: primitives,
            modeMaps: modeMaps
        )
    }

    public static func compile(
        target: DesignTokenTarget,
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> CompiledTokenFile {
        let primitiveColorCount = primitives.allRamps.count * TonalStop.allCases.count
        let semanticCount = SemanticColorRole.allCases.count * DesignAppearanceMode.allCases.count
        let metricCount = primitives.spacingSteps.count + primitives.radiusSteps.count + primitives.elevations.count
        let totalTokenCount = primitiveColorCount + semanticCount + metricCount

        let code: String
        switch target {
        case .swiftUITheme:
            code = emitSwiftUITheme(namespace: namespace, primitives: primitives, modeMaps: modeMaps)
        case .appKitNSColor:
            code = emitAppKitNSColor(namespace: namespace, primitives: primitives, modeMaps: modeMaps)
        case .uiKitUIColor:
            code = emitUIKitUIColor(namespace: namespace, primitives: primitives, modeMaps: modeMaps)
        case .w3cDTCGJSON:
            code = emitW3CDTCGJSON(namespace: namespace, primitives: primitives, modeMaps: modeMaps)
        case .cssOKLCHVariables:
            code = emitCSSOKLCHVariables(namespace: namespace, primitives: primitives, modeMaps: modeMaps)
        case .tailwindV4Config:
            code = emitTailwindV4Config(namespace: namespace, primitives: primitives, modeMaps: modeMaps)
        case .jetpackComposeKotlin:
            code = emitJetpackComposeKotlin(namespace: namespace, primitives: primitives, modeMaps: modeMaps)
        case .xcodeAssetCatalogJSON:
            code = emitXcodeAssetCatalogJSON(namespace: namespace, modeMaps: modeMaps)
        }

        return CompiledTokenFile(
            target: target,
            filename: target.defaultFilename,
            sourceCode: code,
            exportedTokenCount: totalTokenCount
        )
    }

    // MARK: - Target 1: SwiftUI Adaptive Theme

    private static func emitSwiftUITheme(
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> String {
        let light = modeMaps[.light]!
        let dark = modeMaps[.dark]!
        let hcLight = modeMaps[.highContrastLight]!
        let hcDark = modeMaps[.highContrastDark]!

        func rgbaLiteral(_ c: RGBAColor) -> String {
            String(format: "Color(.sRGB, red: %.4f, green: %.4f, blue: %.4f, opacity: %.3f)", c.red, c.green, c.blue, c.alpha)
        }

        let roleProperties = SemanticColorRole.allCases.map { role in
            """
                /// \(role.tokenDescription)
                public var \(role.rawValue): Color {
                    resolve(
                        light: \(rgbaLiteral(light[role])),
                        dark: \(rgbaLiteral(dark[role])),
                        highContrastLight: \(rgbaLiteral(hcLight[role])),
                        highContrastDark: \(rgbaLiteral(hcDark[role]))
                    )
                }
            """
        }.joined(separator: "\n\n")

        let spacingConsts = primitives.spacingSteps.map { step in
            let safeName = step.name.first?.isNumber == true ? "s\(step.name)" : step.name
            return "        public static let \(safeName): CGFloat = \(Int(step.points))"
        }.joined(separator: "\n")

        let radiusConsts = primitives.radiusSteps.map { step in
            let safeName = step.name.first?.isNumber == true ? "r\(step.name)" : step.name
            return "        public static let \(safeName): CGFloat = \(Int(step.points))"
        }.joined(separator: "\n")

        return """
        // Generated by ChiefKit DesignTokenCompiler 3.0 — SwiftUI Adaptive Semantic Theme
        import SwiftUI

        public struct \(namespace)SemanticResolver: Sendable {
            public let colorScheme: ColorScheme
            public let colorSchemeContrast: ColorSchemeContrast

            public init(colorScheme: ColorScheme = .light, colorSchemeContrast: ColorSchemeContrast = .standard) {
                self.colorScheme = colorScheme
                self.colorSchemeContrast = colorSchemeContrast
            }

            @inline(__always)
            private func resolve(
                light: Color,
                dark: Color,
                highContrastLight: Color,
                highContrastDark: Color
            ) -> Color {
                switch (colorScheme, colorSchemeContrast) {
                case (.dark, .increased):
                    return highContrastDark
                case (.dark, _):
                    return dark
                case (_, .increased):
                    return highContrastLight
                default:
                    return light
                }
            }

        \(roleProperties)
        }

        public enum \(namespace)Tokens {
            public enum Spacing {
        \(spacingConsts)
            }

            public enum Radius {
        \(radiusConsts)
            }

            public enum LiquidGlass {
                public static let isEnabled: Bool = \(primitives.isLiquidGlassEnabled)
                public static let frostOpacity: Double = \(String(format: "%.3f", primitives.glassFrost))
                public static let specularRimOpacity: Double = \(String(format: "%.3f", primitives.specularRim))
                public static let blurRadius: CGFloat = \(Int(primitives.glassBlurRadius))
            }
        }
        """
    }

    // MARK: - Target 2: AppKit Dynamic NSColor

    private static func emitAppKitNSColor(
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> String {
        let light = modeMaps[.light]!
        let dark = modeMaps[.dark]!
        let hcLight = modeMaps[.highContrastLight]!
        let hcDark = modeMaps[.highContrastDark]!

        func nsColorInit(_ c: RGBAColor) -> String {
            String(format: "NSColor(srgbRed: %.4f, green: %.4f, blue: %.4f, alpha: %.3f)", c.red, c.green, c.blue, c.alpha)
        }

        let entries = SemanticColorRole.allCases.map { role in
            """
                /// \(role.tokenDescription)
                static let ck\(role.pascalCaseName) = NSColor(name: NSColor.Name("\(namespace).\(role.rawValue)")) { appearance in
                    let match = appearance.bestMatch(from: [
                        .accessibilityHighContrastDarkAqua,
                        .darkAqua,
                        .accessibilityHighContrastAqua,
                        .aqua
                    ])
                    switch match {
                    case .accessibilityHighContrastDarkAqua:
                        return \(nsColorInit(hcDark[role]))
                    case .darkAqua:
                        return \(nsColorInit(dark[role]))
                    case .accessibilityHighContrastAqua:
                        return \(nsColorInit(hcLight[role]))
                    default:
                        return \(nsColorInit(light[role]))
                    }
                }
            """
        }.joined(separator: "\n\n")

        let primaryRampStops = primitives.primaryRamp.swatches.map { sw in
            "    static let ckPrimary\(sw.stop.rawValue) = \(nsColorInit(sw.srgb))"
        }.joined(separator: "\n")

        return """
        // Generated by ChiefKit DesignTokenCompiler 3.0 — AppKit Dynamic NSColor Palette
        #if canImport(AppKit)
        import AppKit

        public extension NSColor {
        \(entries)

            // MARK: Primitive Primary Perceptual Tonal Scale (OKLCH Gamut-Mapped)
        \(primaryRampStops)
        }
        #endif
        """
    }

    // MARK: - Target 3: UIKit Trait-Resolved UIColor

    private static func emitUIKitUIColor(
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> String {
        let light = modeMaps[.light]!
        let dark = modeMaps[.dark]!
        let hcLight = modeMaps[.highContrastLight]!
        let hcDark = modeMaps[.highContrastDark]!

        func uiColorInit(_ c: RGBAColor) -> String {
            String(format: "UIColor(red: %.4f, green: %.4f, blue: %.4f, alpha: %.3f)", c.red, c.green, c.blue, c.alpha)
        }

        let entries = SemanticColorRole.allCases.map { role in
            """
                /// \(role.tokenDescription)
                static let ck\(role.pascalCaseName) = UIColor { traits in
                    let isDark = traits.userInterfaceStyle == .dark
                    let isHigh = traits.accessibilityContrast == .high
                    switch (isDark, isHigh) {
                    case (true, true):
                        return \(uiColorInit(hcDark[role]))
                    case (true, false):
                        return \(uiColorInit(dark[role]))
                    case (false, true):
                        return \(uiColorInit(hcLight[role]))
                    case (false, false):
                        return \(uiColorInit(light[role]))
                    }
                }
            """
        }.joined(separator: "\n\n")

        let neutralRampStops = primitives.neutralRamp.swatches.map { sw in
            "    static let ckNeutral\(sw.stop.rawValue) = \(uiColorInit(sw.srgb))"
        }.joined(separator: "\n")

        return """
        // Generated by ChiefKit DesignTokenCompiler 3.0 — UIKit TraitCollection Dynamic UIColor
        #if canImport(UIKit)
        import UIKit

        public extension UIColor {
        \(entries)

            // MARK: Primitive Neutral Perceptual Tonal Scale
        \(neutralRampStops)
        }
        #endif
        """
    }

    // MARK: - Target 4: W3C Design Tokens Community Group (DTCG JSON)

    private static func emitW3CDTCGJSON(
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> String {
        let light = modeMaps[.light]!
        let dark = modeMaps[.dark]!
        let hcLight = modeMaps[.highContrastLight]!
        let hcDark = modeMaps[.highContrastDark]!

        let rampBlocks = primitives.allRamps.map { ramp in
            let stopsJSON = ramp.swatches.map { sw in
                """
                        "\(sw.stop.rawValue)": {
                          "$type": "color",
                          "$value": "\(sw.srgb.hexString)",
                          "$extensions": {
                            "com.chiefkit.oklch": "\(sw.oklch.cssString)",
                            "com.chiefkit.apcaOnWhite": \(String(format: "%.1f", sw.apcaOnWhite))
                          }
                        }
                """
            }.joined(separator: ",\n")
            return """
                  "\(ramp.name)": {
            \(stopsJSON)
                  }
            """
        }.joined(separator: ",\n")

        let semanticBlocks = SemanticColorRole.allCases.map { role in
            let lColor = light[role]
            let dColor = dark[role]
            let hclColor = hcLight[role]
            let hcdColor = hcDark[role]
            return """
                  "\(role.rawValue)": {
                    "$type": "color",
                    "$value": "\(lColor.hexString)",
                    "$description": "\(role.tokenDescription)",
                    "$extensions": {
                      "com.chiefkit.modes": {
                        "light": "\(lColor.hexString)",
                        "dark": "\(dColor.hexString)",
                        "highContrastLight": "\(hclColor.hexString)",
                        "highContrastDark": "\(hcdColor.hexString)"
                      },
                      "com.chiefkit.oklch": {
                        "light": "\(lColor.oklch.cssString)",
                        "dark": "\(dColor.oklch.cssString)"
                      }
                    }
                  }
            """
        }.joined(separator: ",\n")

        let spacingJSON = primitives.spacingSteps.map { step in
            "      \"\(step.name)\": { \"$type\": \"dimension\", \"$value\": \"\(Int(step.points))px\" }"
        }.joined(separator: ",\n")

        let radiusJSON = primitives.radiusSteps.map { step in
            "      \"\(step.name)\": { \"$type\": \"dimension\", \"$value\": \"\(Int(step.points))px\" }"
        }.joined(separator: ",\n")

        return """
        {
          "$schema": "https://tr.designtokens.org/format/",
          "\(namespace.lowercased())": {
            "primitive": {
              "color": {
        \(rampBlocks)
              },
              "spacing": {
        \(spacingJSON)
              },
              "radius": {
        \(radiusJSON)
              }
            },
            "semantic": {
              "color": {
        \(semanticBlocks)
              }
            },
            "material": {
              "liquidGlass": {
                "enabled": { "$type": "boolean", "$value": \(primitives.isLiquidGlassEnabled) },
                "frost": { "$type": "number", "$value": \(String(format: "%.3f", primitives.glassFrost)) },
                "specularRim": { "$type": "number", "$value": \(String(format: "%.3f", primitives.specularRim)) },
                "blur": { "$type": "dimension", "$value": "\(Int(primitives.glassBlurRadius))px" }
              }
            }
          }
        }
        """
    }

    // MARK: - Target 5: CSS Color Level 4 OKLCH Variables

    private static func emitCSSOKLCHVariables(
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> String {
        let prefix = namespace.lowercased()
        let light = modeMaps[.light]!
        let dark = modeMaps[.dark]!
        let hcLight = modeMaps[.highContrastLight]!
        let hcDark = modeMaps[.highContrastDark]!

        let primitiveLines = primitives.allRamps.flatMap { ramp in
            ramp.swatches.map { sw in
                "  --\(prefix)-\(ramp.name)-\(sw.stop.rawValue): \(sw.oklch.cssString); /* \(sw.srgb.hexString) */"
            }
        }.joined(separator: "\n")

        let spacingLines = primitives.spacingSteps.map { step in
            "  --\(prefix)-space-\(step.name): \(Int(step.points))px;"
        }.joined(separator: "\n")

        let radiusLines = primitives.radiusSteps.map { step in
            "  --\(prefix)-radius-\(step.name): \(Int(step.points))px;"
        }.joined(separator: "\n")

        func modeBlock(_ map: ResolvedModeTokenMap, indent: String = "  ") -> String {
            SemanticColorRole.allCases.map { role in
                let c = map[role]
                return "\(indent)--\(prefix)-\(role.kebabCaseName): \(c.oklch.cssString);"
            }.joined(separator: "\n")
        }

        return """
        /* Generated by ChiefKit DesignTokenCompiler 3.0 — CSS Color Level 4 OKLCH Custom Properties */
        :root,
        [data-theme="light"] {
          /* Primitive OKLCH Tonal Scales */
        \(primitiveLines)

          /* Spacing & Radii */
        \(spacingLines)
        \(radiusLines)
          --\(prefix)-glass-blur: \(Int(primitives.glassBlurRadius))px;
          --\(prefix)-glass-frost: \(String(format: "%.3f", primitives.glassFrost));

          /* Semantic Roles (Light Mode) */
        \(modeBlock(light))
        }

        [data-theme="dark"] {
        \(modeBlock(dark))
        }

        @media (prefers-color-scheme: dark) {
          :root:not([data-theme="light"]) {
        \(modeBlock(dark, indent: "    "))
          }
        }

        @media (prefers-contrast: more) {
          :root,
          [data-theme="light"] {
        \(modeBlock(hcLight, indent: "    "))
          }
          [data-theme="dark"] {
        \(modeBlock(hcDark, indent: "    "))
          }
        }
        """
    }

    // MARK: - Target 6: Tailwind CSS v4 @theme Configuration

    private static func emitTailwindV4Config(
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> String {
        let light = modeMaps[.light]!
        let dark = modeMaps[.dark]!

        let colorScaleVars = primitives.allRamps.flatMap { ramp in
            ramp.swatches.map { sw in
                "  --color-\(ramp.name)-\(sw.stop.rawValue): \(sw.oklch.cssString);"
            }
        }.joined(separator: "\n")

        let semanticLightVars = SemanticColorRole.allCases.map { role in
            "  --color-\(role.kebabCaseName): \(light[role].oklch.cssString);"
        }.joined(separator: "\n")

        let semanticDarkVars = SemanticColorRole.allCases.map { role in
            "    --color-\(role.kebabCaseName): \(dark[role].oklch.cssString);"
        }.joined(separator: "\n")

        let radiusVars = primitives.radiusSteps.map { step in
            "  --radius-\(step.name): \(Int(step.points))px;"
        }.joined(separator: "\n")

        let shadowVars = primitives.elevations.map { elev in
            "  --shadow-\(elev.name): 0 \(Int(elev.offsetY))px \(Int(elev.blurRadius))px \(Int(elev.spread))px rgb(0 0 0 / \(String(format: "%.2f", elev.opacityLight)));"
        }.joined(separator: "\n")

        return """
        /* Generated by ChiefKit DesignTokenCompiler 3.0 — Tailwind CSS v4 @theme Configuration */
        @import "tailwindcss";

        @theme {
          /* Perceptual OKLCH Tonal Palettes */
        \(colorScaleVars)

          /* Semantic Design System Tokens */
        \(semanticLightVars)

          /* Radii & Shadows */
        \(radiusVars)
        \(shadowVars)
        }

        @layer base {
          .dark,
          [data-mode="dark"] {
        \(semanticDarkVars)
          }
        }

        @utility ck-liquid-glass {
          background-color: var(--color-surface-glass-tint);
          backdrop-filter: blur(\(Int(primitives.glassBlurRadius))px) saturate(1.65);
          border: 1px solid var(--color-specular-highlight);
        }
        """
    }

    // MARK: - Target 7: Jetpack Compose Kotlin

    private static func emitJetpackComposeKotlin(
        namespace: String,
        primitives: PrimitiveTokenPalette,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> String {
        let light = modeMaps[.light]!
        let dark = modeMaps[.dark]!
        let hcDark = modeMaps[.highContrastDark]!

        func ktColorHex(_ c: RGBAColor) -> String {
            let a = Int((c.alpha * 255.0).rounded())
            let r = Int((c.red * 255.0).rounded())
            let g = Int((c.green * 255.0).rounded())
            let b = Int((c.blue * 255.0).rounded())
            return String(format: "Color(0x%02X%02X%02X%02X)", a, r, g, b)
        }

        let classFields = SemanticColorRole.allCases.map { role in
            "    val \(role.rawValue): Color,"
        }.joined(separator: "\n")

        func schemeInstance(name: String, map: ResolvedModeTokenMap) -> String {
            let assignments = SemanticColorRole.allCases.map { role in
                "    \(role.rawValue) = \(ktColorHex(map[role])),"
            }.joined(separator: "\n")
            return """
            val \(name) = \(namespace)ColorScheme(
            \(assignments)
            )
            """
        }

        let spacingVals = primitives.spacingSteps.map { step in
            let safe = step.name.first?.isNumber == true ? "Space\(step.name)" : "Space\(step.name.uppercased())"
            return "    val \(safe) = \(Int(step.points)).dp"
        }.joined(separator: "\n")

        return """
        // Generated by ChiefKit DesignTokenCompiler 3.0 — Jetpack Compose Semantic Theme
        package com.hnmlabs.\(namespace.lowercased()).designsystem

        import androidx.compose.foundation.isSystemInDarkTheme
        import androidx.compose.runtime.Composable
        import androidx.compose.runtime.CompositionLocalProvider
        import androidx.compose.runtime.Immutable
        import androidx.compose.runtime.staticCompositionLocalOf
        import androidx.compose.ui.graphics.Color
        import androidx.compose.ui.unit.dp

        @Immutable
        data class \(namespace)ColorScheme(
        \(classFields)
        )

        \(schemeInstance(name: "Light\(namespace)Colors", map: light))

        \(schemeInstance(name: "Dark\(namespace)Colors", map: dark))

        \(schemeInstance(name: "HighContrastDark\(namespace)Colors", map: hcDark))

        object \(namespace)Dimensions {
        \(spacingVals)
            val RadiusSm = \(Int(primitives.radiusSteps[2].points)).dp
            val RadiusMd = \(Int(primitives.radiusSteps[3].points)).dp
            val RadiusLg = \(Int(primitives.radiusSteps[4].points)).dp
        }

        val Local\(namespace)Colors = staticCompositionLocalOf { Light\(namespace)Colors }

        @Composable
        fun \(namespace)Theme(
            darkTheme: Boolean = isSystemInDarkTheme(),
            highContrast: Boolean = false,
            content: @Composable () -> Unit
        ) {
            val colors = when {
                darkTheme && highContrast -> HighContrastDark\(namespace)Colors
                darkTheme -> Dark\(namespace)Colors
                else -> Light\(namespace)Colors
            }
            CompositionLocalProvider(Local\(namespace)Colors provides colors, content = content)
        }
        """
    }

    // MARK: - Target 8: Xcode Asset Catalog (.xcassets JSON Bundle Manifest)

    private static func emitXcodeAssetCatalogJSON(
        namespace: String,
        modeMaps: [DesignAppearanceMode: ResolvedModeTokenMap]
    ) -> String {
        let light = modeMaps[.light]!
        let dark = modeMaps[.dark]!
        let hcLight = modeMaps[.highContrastLight]!
        let hcDark = modeMaps[.highContrastDark]!

        func colorComponentsJSON(_ c: RGBAColor) -> String {
            String(
                format: "{ \"alpha\": \"%.3f\", \"blue\": \"%.4f\", \"green\": \"%.4f\", \"red\": \"%.4f\" }",
                c.alpha, c.blue, c.green, c.red
            )
        }

        let colorsets = SemanticColorRole.allCases.map { role in
            """
                "\(namespace)\(role.pascalCaseName).colorset/Contents.json": {
                  "colors": [
                    {
                      "color": { "color-space": "srgb", "components": \(colorComponentsJSON(light[role])) },
                      "idiom": "universal"
                    },
                    {
                      "appearances": [{ "appearance": "luminosity", "value": "dark" }],
                      "color": { "color-space": "srgb", "components": \(colorComponentsJSON(dark[role])) },
                      "idiom": "universal"
                    },
                    {
                      "appearances": [{ "appearance": "contrast", "value": "high" }],
                      "color": { "color-space": "srgb", "components": \(colorComponentsJSON(hcLight[role])) },
                      "idiom": "universal"
                    },
                    {
                      "appearances": [
                        { "appearance": "luminosity", "value": "dark" },
                        { "appearance": "contrast", "value": "high" }
                      ],
                      "color": { "color-space": "srgb", "components": \(colorComponentsJSON(hcDark[role])) },
                      "idiom": "universal"
                    }
                  ],
                  "info": { "author": "chiefkit-token-compiler", "version": 1 }
                }
            """
        }.joined(separator: ",\n")

        return """
        {
          "catalog": "\(namespace)Colors.xcassets",
          "info": { "author": "chiefkit-token-compiler", "version": 1 },
          "colorsets": {
        \(colorsets)
          }
        }
        """
    }
}
