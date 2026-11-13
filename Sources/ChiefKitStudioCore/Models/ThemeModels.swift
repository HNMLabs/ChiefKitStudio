#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

public enum TokenExportFormat: String, CaseIterable, Identifiable, Sendable {
    case swiftBlocks = "SwiftBlocks EDKTheme"
    case w3cDesignTokens = "W3C Design Tokens (JSON)"
    case cssVariables = "CSS Custom Properties"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .swiftBlocks: "swift"
        case .w3cDesignTokens: "json"
        case .cssVariables: "css"
        }
    }
}

public enum StudioThemePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case chiefKitBlue = "ChiefKit Default"
    case liquidGlass26 = "Liquid Glass 26"
    case midnightViolet = "Midnight Violet"
    case emeraldMint = "Emerald Mint"
    case sunsetAmber = "Sunset Amber"
    case monochromePro = "Monochrome Pro"

    public var id: String { rawValue }

    public var tokens: StudioThemeTokens {
        switch self {
        case .chiefKitBlue:
            StudioThemeTokens()
        case .liquidGlass26:
            StudioThemeTokens(
                primary: RGBAColor(red: 0.12, green: 0.44, blue: 0.92),
                secondary: RGBAColor(red: 0.44, green: 0.50, blue: 0.62),
                success: RGBAColor(red: 0.12, green: 0.64, blue: 0.42),
                warning: RGBAColor(red: 0.96, green: 0.68, blue: 0.14),
                danger: RGBAColor(red: 0.88, green: 0.22, blue: 0.30),
                surface: RGBAColor(red: 0.96, green: 0.98, blue: 1.00),
                spacingScale: 1.08,
                radiusSmall: 10,
                radiusMedium: 16,
                radiusLarge: 22,
                isLiquidGlassEnabled: true,
                glassFrost: 0.68,
                specularRim: 0.72
            )
        case .midnightViolet:
            StudioThemeTokens(
                primary: RGBAColor(red: 0.42, green: 0.24, blue: 0.88),
                secondary: RGBAColor(red: 0.50, green: 0.48, blue: 0.66),
                success: RGBAColor(red: 0.12, green: 0.66, blue: 0.48),
                warning: RGBAColor(red: 0.94, green: 0.66, blue: 0.18),
                danger: RGBAColor(red: 0.88, green: 0.22, blue: 0.42),
                surface: RGBAColor(red: 0.96, green: 0.95, blue: 0.99),
                spacingScale: 1.0,
                radiusSmall: 8,
                radiusMedium: 14,
                radiusLarge: 20,
                isLiquidGlassEnabled: true,
                glassFrost: 0.55,
                specularRim: 0.65
            )
        case .emeraldMint:
            StudioThemeTokens(
                primary: RGBAColor(red: 0.04, green: 0.50, blue: 0.36),
                secondary: RGBAColor(red: 0.36, green: 0.48, blue: 0.44),
                success: RGBAColor(red: 0.06, green: 0.58, blue: 0.34),
                warning: RGBAColor(red: 0.92, green: 0.64, blue: 0.10),
                danger: RGBAColor(red: 0.82, green: 0.20, blue: 0.26),
                surface: RGBAColor(red: 0.95, green: 0.98, blue: 0.97),
                spacingScale: 1.0,
                radiusSmall: 8,
                radiusMedium: 12,
                radiusLarge: 18,
                isLiquidGlassEnabled: false,
                glassFrost: 0.42,
                specularRim: 0.35
            )
        case .sunsetAmber:
            StudioThemeTokens(
                primary: RGBAColor(red: 0.78, green: 0.28, blue: 0.08),
                secondary: RGBAColor(red: 0.52, green: 0.42, blue: 0.38),
                success: RGBAColor(red: 0.14, green: 0.58, blue: 0.34),
                warning: RGBAColor(red: 0.94, green: 0.60, blue: 0.06),
                danger: RGBAColor(red: 0.80, green: 0.16, blue: 0.22),
                surface: RGBAColor(red: 0.99, green: 0.97, blue: 0.95),
                spacingScale: 1.05,
                radiusSmall: 8,
                radiusMedium: 14,
                radiusLarge: 20,
                isLiquidGlassEnabled: true,
                glassFrost: 0.48,
                specularRim: 0.56
            )
        case .monochromePro:
            StudioThemeTokens(
                primary: RGBAColor(red: 0.14, green: 0.16, blue: 0.20),
                secondary: RGBAColor(red: 0.46, green: 0.48, blue: 0.52),
                success: RGBAColor(red: 0.15, green: 0.56, blue: 0.36),
                warning: RGBAColor(red: 0.88, green: 0.62, blue: 0.12),
                danger: RGBAColor(red: 0.80, green: 0.20, blue: 0.24),
                surface: RGBAColor(red: 0.97, green: 0.97, blue: 0.98),
                spacingScale: 0.92,
                radiusSmall: 4,
                radiusMedium: 6,
                radiusLarge: 10,
                isLiquidGlassEnabled: false,
                glassFrost: 0.30,
                specularRim: 0.20
            )
        }
    }
}

public struct StudioThemeTokens: Codable, Hashable, Sendable {
    public var primary: RGBAColor
    public var secondary: RGBAColor
    public var success: RGBAColor
    public var warning: RGBAColor
    public var danger: RGBAColor
    public var surface: RGBAColor

    public var spacingScale: Double
    public var radiusSmall: Double
    public var radiusMedium: Double
    public var radiusLarge: Double

    public var isLiquidGlassEnabled: Bool
    public var glassFrost: Double
    public var specularRim: Double

    public init(
        primary: RGBAColor = RGBAColor(red: 0.05, green: 0.36, blue: 0.94),
        secondary: RGBAColor = RGBAColor(red: 0.42, green: 0.46, blue: 0.52),
        success: RGBAColor = RGBAColor(red: 0.10, green: 0.56, blue: 0.34),
        warning: RGBAColor = RGBAColor(red: 0.96, green: 0.68, blue: 0.08),
        danger: RGBAColor = RGBAColor(red: 0.86, green: 0.20, blue: 0.27),
        surface: RGBAColor = RGBAColor(red: 0.96, green: 0.97, blue: 0.99),
        spacingScale: Double = 1.0,
        radiusSmall: Double = 6,
        radiusMedium: Double = 12,
        radiusLarge: Double = 18,
        isLiquidGlassEnabled: Bool = true,
        glassFrost: Double = 0.54,
        specularRim: Double = 0.58
    ) {
        self.primary = primary
        self.secondary = secondary
        self.success = success
        self.warning = warning
        self.danger = danger
        self.surface = surface
        self.spacingScale = spacingScale
        self.radiusSmall = radiusSmall
        self.radiusMedium = radiusMedium
        self.radiusLarge = radiusLarge
        self.isLiquidGlassEnabled = isLiquidGlassEnabled
        self.glassFrost = glassFrost
        self.specularRim = specularRim
    }

    public var spacingXS: CGFloat { CGFloat((8 * spacingScale).rounded()) }
    public var spacingSM: CGFloat { CGFloat((12 * spacingScale).rounded()) }
    public var spacingMD: CGFloat { CGFloat((16 * spacingScale).rounded()) }
    public var spacingLG: CGFloat { CGFloat((24 * spacingScale).rounded()) }

    public var contrastReport: WCAGContrastReport {
        WCAGContrastReport(tokens: self)
    }

    public mutating func autoFixPrimaryContrast() {
        primary = primary.adjustedForContrast(against: surface, minimumRatio: 4.5)
    }

    public func exportedCode(in format: TokenExportFormat) -> String {
        switch format {
        case .swiftBlocks:
            return swiftBlocksThemeSnippet
        case .w3cDesignTokens:
            return w3cDesignTokensJSON
        case .cssVariables:
            return cssVariablesSnippet
        }
    }

    public var swiftBlocksThemeSnippet: String {
        let glassComment = isLiquidGlassEnabled
            ? "// Liquid Glass enabled (frost: \(Int((glassFrost * 100).rounded()))%, specular: \(Int((specularRim * 100).rounded()))%)"
            : "// Standard material surfaces"

        return """
        import SwiftBlocks
        import SwiftUI

        \(glassComment)
        let studioTheme = EDKTheme(
            colors: EDKColorPalette(
                primary: \(primary.swiftInitializer), // \(primary.hexString)
                secondary: \(secondary.swiftInitializer), // \(secondary.hexString)
                success: \(success.swiftInitializer), // \(success.hexString)
                danger: \(danger.swiftInitializer), // \(danger.hexString)
                warning: \(warning.swiftInitializer), // \(warning.hexString)
                info: \(primary.swiftInitializer),
                light: \(surface.swiftInitializer),
                dark: Color(red: 0.12, green: 0.14, blue: 0.18),
                canvas: \(surface.swiftInitializer),
                stroke: Color.secondary.opacity(0.25)
            ),
            spacing: EDKSpacingScale(
                xs: \(Int(spacingXS)),
                sm: \(Int(spacingSM)),
                md: \(Int(spacingMD)),
                lg: \(Int(spacingLG))
            ),
            radii: EDKRadiusScale(
                sm: \(Int(radiusSmall.rounded())),
                md: \(Int(radiusMedium.rounded())),
                lg: \(Int(radiusLarge.rounded())),
                pill: 999
            )
        )
        """
    }

    public var w3cDesignTokensJSON: String {
        """
        {
          "chiefkit": {
            "color": {
              "primary": { "$value": "\(primary.hexString)", "$type": "color" },
              "secondary": { "$value": "\(secondary.hexString)", "$type": "color" },
              "success": { "$value": "\(success.hexString)", "$type": "color" },
              "warning": { "$value": "\(warning.hexString)", "$type": "color" },
              "danger": { "$value": "\(danger.hexString)", "$type": "color" },
              "surface": { "$value": "\(surface.hexString)", "$type": "color" }
            },
            "spacing": {
              "xs": { "$value": "\(Int(spacingXS))px", "$type": "dimension" },
              "sm": { "$value": "\(Int(spacingSM))px", "$type": "dimension" },
              "md": { "$value": "\(Int(spacingMD))px", "$type": "dimension" },
              "lg": { "$value": "\(Int(spacingLG))px", "$type": "dimension" }
            },
            "radius": {
              "sm": { "$value": "\(Int(radiusSmall.rounded()))px", "$type": "dimension" },
              "md": { "$value": "\(Int(radiusMedium.rounded()))px", "$type": "dimension" },
              "lg": { "$value": "\(Int(radiusLarge.rounded()))px", "$type": "dimension" }
            },
            "liquidGlass": {
              "enabled": { "$value": \(isLiquidGlassEnabled), "$type": "boolean" },
              "frost": { "$value": \(String(format: "%.2f", glassFrost)), "$type": "number" },
              "specularRim": { "$value": \(String(format: "%.2f", specularRim)), "$type": "number" }
            }
          }
        }
        """
    }

    public var cssVariablesSnippet: String {
        """
        /* ChiefKit Studio — Exported Design Tokens */
        :root {
          --ck-color-primary: \(primary.hexString);
          --ck-color-secondary: \(secondary.hexString);
          --ck-color-success: \(success.hexString);
          --ck-color-warning: \(warning.hexString);
          --ck-color-danger: \(danger.hexString);
          --ck-color-surface: \(surface.hexString);

          --ck-space-xs: \(Int(spacingXS))px;
          --ck-space-sm: \(Int(spacingSM))px;
          --ck-space-md: \(Int(spacingMD))px;
          --ck-space-lg: \(Int(spacingLG))px;

          --ck-radius-sm: \(Int(radiusSmall.rounded()))px;
          --ck-radius-md: \(Int(radiusMedium.rounded()))px;
          --ck-radius-lg: \(Int(radiusLarge.rounded()))px;
          --ck-glass-blur: \(isLiquidGlassEnabled ? "\(Int((glassFrost * 28).rounded()))px" : "0px");
        }
        """
    }
}
