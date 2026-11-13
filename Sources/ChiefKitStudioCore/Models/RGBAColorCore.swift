import Foundation

public struct RGBAColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(max(0, red), 1)
        self.green = min(max(0, green), 1)
        self.blue = min(max(0, blue), 1)
        self.alpha = min(max(0, alpha), 1)
    }

    public var hexString: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public var swiftInitializer: String {
        String(
            format: "Color(red: %.2f, green: %.2f, blue: %.2f)",
            red,
            green,
            blue
        )
    }

    /// WCAG 2.1 relative luminance in [0.0, 1.0].
    public var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG 2.1 contrast ratio against another color in [1.0, 21.0].
    public func contrastRatio(against other: RGBAColor) -> Double {
        let l1 = max(relativeLuminance, other.relativeLuminance)
        let l2 = min(relativeLuminance, other.relativeLuminance)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    /// Adjusts brightness toward target contrast >= minimumRatio against `background`.
    public func adjustedForContrast(against background: RGBAColor, minimumRatio: Double = 4.5) -> RGBAColor {
        if contrastRatio(against: background) >= minimumRatio {
            return self
        }
        let darken = background.relativeLuminance > 0.5
        var candidate = self
        for _ in 0..<40 {
            if candidate.contrastRatio(against: background) >= minimumRatio {
                return candidate
            }
            if darken {
                candidate = RGBAColor(
                    red: candidate.red * 0.88,
                    green: candidate.green * 0.88,
                    blue: candidate.blue * 0.88,
                    alpha: candidate.alpha
                )
            } else {
                candidate = RGBAColor(
                    red: candidate.red + (1.0 - candidate.red) * 0.14,
                    green: candidate.green + (1.0 - candidate.green) * 0.14,
                    blue: candidate.blue + (1.0 - candidate.blue) * 0.14,
                    alpha: candidate.alpha
                )
            }
        }
        return candidate
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let darkSurface = RGBAColor(red: 0.12, green: 0.14, blue: 0.18)
}

public enum WCAGComplianceLevel: String, Codable, Sendable {
    case aaa = "WCAG AAA (≥ 7.0:1)"
    case aa = "WCAG AA (≥ 4.5:1)"
    case aaLarge = "AA Large Only (≥ 3.0:1)"
    case fail = "Low Contrast (< 3.0:1)"

    public static func evaluate(ratio: Double) -> WCAGComplianceLevel {
        if ratio >= 7.0 { return .aaa }
        if ratio >= 4.5 { return .aa }
        if ratio >= 3.0 { return .aaLarge }
        return .fail
    }

    public var passesAA: Bool {
        self == .aa || self == .aaa
    }
}

public struct WCAGContrastReport: Equatable, Sendable {
    public let primaryOnSurfaceRatio: Double
    public let primaryOnSurfaceLevel: WCAGComplianceLevel
    public let whiteOnPrimaryRatio: Double
    public let whiteOnPrimaryLevel: WCAGComplianceLevel
    public let primaryOnDarkRatio: Double
    public let primaryOnDarkLevel: WCAGComplianceLevel

    public init(tokens: StudioThemeTokens) {
        let pos = tokens.primary.contrastRatio(against: tokens.surface)
        self.primaryOnSurfaceRatio = pos
        self.primaryOnSurfaceLevel = WCAGComplianceLevel.evaluate(ratio: pos)

        let wop = RGBAColor.white.contrastRatio(against: tokens.primary)
        self.whiteOnPrimaryRatio = wop
        self.whiteOnPrimaryLevel = WCAGComplianceLevel.evaluate(ratio: wop)

        let pod = tokens.primary.contrastRatio(against: .darkSurface)
        self.primaryOnDarkRatio = pod
        self.primaryOnDarkLevel = WCAGComplianceLevel.evaluate(ratio: pod)
    }
}
