#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Signed Math Helpers

@inline(__always)
private func signedCubeRoot(_ value: Double) -> Double {
    if value >= 0 {
        return pow(value, 1.0 / 3.0)
    } else {
        return -pow(-value, 1.0 / 3.0)
    }
}

@inline(__always)
private func normalizeDegrees(_ degrees: Double) -> Double {
    let mod = degrees.truncatingRemainder(dividingBy: 360.0)
    return mod < 0 ? mod + 360.0 : mod
}

@inline(__always)
private func degreesToRadians(_ degrees: Double) -> Double {
    degrees * .pi / 180.0
}

@inline(__always)
private func radiansToDegrees(_ radians: Double) -> Double {
    radians * 180.0 / .pi
}

// MARK: - Linear sRGB Color Space (IEC 61966-2-1)

/// Unclamped linear-light sRGB color representation with D65 white point.
/// Preserves out-of-gamut negative or >1.0 channel values during intermediate color-space math.
public struct LinearSRGBColor: Codable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var alpha: Double

    public init(r: Double, g: Double, b: Double, alpha: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.alpha = min(max(0.0, alpha), 1.0)
    }

    /// Converts gamma-encoded sRGB `RGBAColor` to linear-light sRGB using IEC 61966-2-1 transfer function.
    public init(srgb: RGBAColor) {
        self.r = Self.srgbChannelToLinear(srgb.red)
        self.g = Self.srgbChannelToLinear(srgb.green)
        self.b = Self.srgbChannelToLinear(srgb.blue)
        self.alpha = srgb.alpha
    }

    /// Exact IEC 61966-2-1 electro-optical transfer function (EOTF), sign-extended for wide-gamut math.
    public static func srgbChannelToLinear(_ channel: Double) -> Double {
        let sign = channel < 0 ? -1.0 : 1.0
        let absVal = abs(channel)
        if absVal <= 0.04045 {
            return channel / 12.92
        }
        return sign * pow((absVal + 0.055) / 1.055, 2.4)
    }

    /// Exact IEC 61966-2-1 opto-electronic transfer function (OETF), sign-extended for wide-gamut math.
    public static func linearChannelToSRGB(_ linear: Double) -> Double {
        let sign = linear < 0 ? -1.0 : 1.0
        let absVal = abs(linear)
        if absVal <= 0.0031308 {
            return linear * 12.92
        }
        return sign * (1.055 * pow(absVal, 1.0 / 2.4) - 0.055)
    }

    /// Returns whether all linear channels fall within the standard `[0, 1]` sRGB cube.
    public func isInSRGBGamut(tolerance: Double = 1e-4) -> Bool {
        let low = -tolerance
        let high = 1.0 + tolerance
        return r >= low && r <= high && g >= low && g <= high && b >= low && b <= high
    }

    /// Hard-clips linear channels to `[0, 1]` and encodes into gamma-corrected `RGBAColor`.
    public func clampedToSRGB() -> RGBAColor {
        let cr = min(max(0.0, r), 1.0)
        let cg = min(max(0.0, g), 1.0)
        let cb = min(max(0.0, b), 1.0)
        return RGBAColor(
            red: Self.linearChannelToSRGB(cr),
            green: Self.linearChannelToSRGB(cg),
            blue: Self.linearChannelToSRGB(cb),
            alpha: alpha
        )
    }

    /// Relative CIE Y luminance using exact sRGB D65 primaries.
    public var luminanceY: Double {
        0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    }

    /// Linear interpolation between two linear-light colors (physically accurate optical mixing).
    public func mixed(with other: LinearSRGBColor, fraction: Double) -> LinearSRGBColor {
        let t = min(max(0.0, fraction), 1.0)
        return LinearSRGBColor(
            r: r + (other.r - r) * t,
            g: g + (other.g - g) * t,
            b: b + (other.b - b) * t,
            alpha: alpha + (other.alpha - alpha) * t
        )
    }
}

// MARK: - CIE 1931 XYZ (D65 Standard Illuminant)

/// CIE 1931 2-degree tristimulus color with D65 reference white (`Xn = 0.95047, Yn = 1.00000, Zn = 1.08883`).
public struct CIEXYZColor: Codable, Hashable, Sendable {
    public static let d65WhiteX: Double = 0.95047
    public static let d65WhiteY: Double = 1.00000
    public static let d65WhiteZ: Double = 1.08883

    public var x: Double
    public var y: Double
    public var z: Double
    public var alpha: Double

    public init(x: Double, y: Double, z: Double, alpha: Double = 1.0) {
        self.x = x
        self.y = y
        self.z = z
        self.alpha = min(max(0.0, alpha), 1.0)
    }

    /// Forward sRGB (D65) -> CIE XYZ transformation using standard Brucelindbloom / IEC 61966-2-1 matrix.
    public init(linearSRGB c: LinearSRGBColor) {
        self.x = 0.4124564 * c.r + 0.3575761 * c.g + 0.1804375 * c.b
        self.y = 0.2126729 * c.r + 0.7151522 * c.g + 0.0721750 * c.b
        self.z = 0.0193339 * c.r + 0.1191920 * c.g + 0.9503041 * c.b
        self.alpha = c.alpha
    }

    public init(srgb: RGBAColor) {
        self.init(linearSRGB: LinearSRGBColor(srgb: srgb))
    }

    /// Inverse CIE XYZ (D65) -> Linear sRGB transformation.
    public func toLinearSRGB() -> LinearSRGBColor {
        let r =  3.2404542 * x - 1.5371385 * y - 0.4985314 * z
        let g = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
        let b =  0.0556434 * x - 0.2040259 * y + 1.0572252 * z
        return LinearSRGBColor(r: r, g: g, b: b, alpha: alpha)
    }

    public func toSRGBClipped() -> RGBAColor {
        toLinearSRGB().clampedToSRGB()
    }

    /// CIE 1931 `(x, y)` chromaticity coordinates.
    public var chromaticityXY: (x: Double, y: Double) {
        let sum = x + y + z
        guard abs(sum) > 1e-12 else {
            return (0.31271, 0.32902) // D65 neutral point
        }
        return (x / sum, y / sum)
    }

    /// CIE 1976 Uniform Chromaticity Scale `(u', v')` coordinates.
    public var chromaticityUPrimeVPrime: (uPrime: Double, vPrime: Double) {
        let denom = x + 15.0 * y + 3.0 * z
        guard abs(denom) > 1e-12 else {
            return (0.19784, 0.46832)
        }
        return (4.0 * x / denom, 9.0 * y / denom)
    }

    /// Estimates Correlated Color Temperature (CCT) in Kelvin via McCamy's cubic approximation.
    public var correlatedColorTemperatureKelvin: Double {
        let (cx, cy) = chromaticityXY
        let denom = 0.1858 - cy
        guard abs(denom) > 1e-9 else { return 6504.0 }
        let n = (cx - 0.3320) / denom
        let cct = 449.0 * pow(n, 3.0) + 3525.0 * pow(n, 2.0) + 6823.3 * n + 5520.33
        return min(max(1000.0, cct), 40000.0)
    }
}

// MARK: - CIE 1976 L*a*b* and L*C*h°

/// Perceptually uniform CIE 1976 `L*a*b*` color space anchored to D65.
public struct CIELabColor: Codable, Hashable, Sendable {
    private static let epsilon: Double = 216.0 / 24389.0 // ~0.0088564517
    private static let kappa: Double = 24389.0 / 27.0    // ~903.2962963

    /// Lightness `L*` nominally in `[0, 100]`.
    public var l: Double
    /// Green-red opponent axis `a*` nominally in `[-128, +127]`.
    public var a: Double
    /// Blue-yellow opponent axis `b*` nominally in `[-128, +127]`.
    public var b: Double
    public var alpha: Double

    public init(l: Double, a: Double, b: Double, alpha: Double = 1.0) {
        self.l = l
        self.a = a
        self.b = b
        self.alpha = min(max(0.0, alpha), 1.0)
    }

    public init(xyz: CIEXYZColor) {
        func forwardF(_ t: Double) -> Double {
            t > Self.epsilon ? signedCubeRoot(t) : (Self.kappa * t + 16.0) / 116.0
        }
        let fx = forwardF(xyz.x / CIEXYZColor.d65WhiteX)
        let fy = forwardF(xyz.y / CIEXYZColor.d65WhiteY)
        let fz = forwardF(xyz.z / CIEXYZColor.d65WhiteZ)

        self.l = 116.0 * fy - 16.0
        self.a = 500.0 * (fx - fy)
        self.b = 200.0 * (fy - fz)
        self.alpha = xyz.alpha
    }

    public init(srgb: RGBAColor) {
        self.init(xyz: CIEXYZColor(srgb: srgb))
    }

    public func toXYZ() -> CIEXYZColor {
        let fy = (l + 16.0) / 116.0
        let fx = a / 500.0 + fy
        let fz = fy - b / 200.0

        let fx3 = fx * fx * fx
        let fz3 = fz * fz * fz

        let xr = fx3 > Self.epsilon ? fx3 : (116.0 * fx - 16.0) / Self.kappa
        let yr = l > (Self.kappa * Self.epsilon) ? pow((l + 16.0) / 116.0, 3.0) : l / Self.kappa
        let zr = fz3 > Self.epsilon ? fz3 : (116.0 * fz - 16.0) / Self.kappa

        return CIEXYZColor(
            x: xr * CIEXYZColor.d65WhiteX,
            y: yr * CIEXYZColor.d65WhiteY,
            z: zr * CIEXYZColor.d65WhiteZ,
            alpha: alpha
        )
    }

    public func toSRGBClipped() -> RGBAColor {
        toXYZ().toSRGBClipped()
    }

    /// Cylindrical chroma `C*ab`.
    public var chroma: Double {
        hypot(a, b)
    }

    /// Cylindrical hue angle `h°ab` in `[0, 360)`.
    public var hueDegrees: Double {
        if hypot(a, b) < 1e-7 { return 0.0 }
        return normalizeDegrees(radiansToDegrees(atan2(b, a)))
    }
}

// MARK: - OKLAB & OKLCH (Björn Ottosson Perceptual Color Space)

/// Björn Ottosson's perceptual opponent color space (`L` in `[0, 1]`, `a` & `b` in `[-0.4, +0.4]`).
/// Eliminates the blue-to-purple hue shift inherent in CIE LAB when interpolating or scaling chroma.
public struct OklabColor: Codable, Hashable, Sendable {
    public var l: Double
    public var a: Double
    public var b: Double
    public var alpha: Double

    public init(l: Double, a: Double, b: Double, alpha: Double = 1.0) {
        self.l = l
        self.a = a
        self.b = b
        self.alpha = min(max(0.0, alpha), 1.0)
    }

    /// Exact forward Linear sRGB -> Cone LMS -> Cube Root -> OKLAB transform.
    public init(linearSRGB c: LinearSRGBColor) {
        let lCone = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b
        let mCone = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b
        let sCone = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b

        let lRoot = signedCubeRoot(lCone)
        let mRoot = signedCubeRoot(mCone)
        let sRoot = signedCubeRoot(sCone)

        self.l = 0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot
        self.a = 1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot
        self.b = 0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot
        self.alpha = c.alpha
    }

    public init(srgb: RGBAColor) {
        self.init(linearSRGB: LinearSRGBColor(srgb: srgb))
    }

    /// Exact inverse OKLAB -> Cone LMS -> Linear sRGB transform.
    public func toLinearSRGB() -> LinearSRGBColor {
        let lRoot = l + 0.3963377774 * a + 0.2158037573 * b
        let mRoot = l - 0.1055613458 * a - 0.0638541728 * b
        let sRoot = l - 0.0894841775 * a - 1.2914855480 * b

        let lCone = lRoot * lRoot * lRoot
        let mCone = mRoot * mRoot * mRoot
        let sCone = sRoot * sRoot * sRoot

        let r = +4.0767416621 * lCone - 3.3077115913 * mCone + 0.2309699292 * sCone
        let g = -1.2684380046 * lCone + 2.6097574011 * mCone - 0.3413193965 * sCone
        let bVal = -0.0041960863 * lCone - 0.7034186147 * mCone + 1.7076147010 * sCone

        return LinearSRGBColor(r: r, g: g, b: bVal, alpha: alpha)
    }

    /// Euclidean perceptual distance `ΔE_OK` in OKLAB space (`~0.02` corresponds to 1 JND).
    public func euclideanDistance(to other: OklabColor) -> Double {
        let dl = l - other.l
        let da = a - other.a
        let db = b - other.b
        return sqrt(dl * dl + da * da + db * db)
    }

    public func toOklch() -> OklchColor {
        let c = hypot(a, b)
        let h = c < 1e-7 ? 0.0 : normalizeDegrees(radiansToDegrees(atan2(b, a)))
        return OklchColor(l: l, c: c, h: h, alpha: alpha)
    }

    /// Perceptually uniform interpolation in Cartesian OKLAB coordinates.
    public func interpolated(to other: OklabColor, t: Double) -> OklabColor {
        let clamped = min(max(0.0, t), 1.0)
        return OklabColor(
            l: l + (other.l - l) * clamped,
            a: a + (other.a - a) * clamped,
            b: b + (other.b - b) * clamped,
            alpha: alpha + (other.alpha - alpha) * clamped
        )
    }
}

/// Cylindrical polar representation of OKLAB: Lightness `l` `[0, 1]`, Chroma `c` `[0, ~0.37]`, Hue `h` `[0, 360)`.
public struct OklchColor: Codable, Hashable, Sendable {
    public var l: Double
    public var c: Double
    public var h: Double
    public var alpha: Double

    public init(l: Double, c: Double, h: Double, alpha: Double = 1.0) {
        self.l = min(max(0.0, l), 1.0)
        self.c = max(0.0, c)
        self.h = normalizeDegrees(h)
        self.alpha = min(max(0.0, alpha), 1.0)
    }

    public init(srgb: RGBAColor) {
        self = OklabColor(srgb: srgb).toOklch()
    }

    public func toOklab() -> OklabColor {
        let rad = degreesToRadians(h)
        return OklabColor(
            l: l,
            a: c * cos(rad),
            b: c * sin(rad),
            alpha: alpha
        )
    }

    public func toLinearSRGB() -> LinearSRGBColor {
        toOklab().toLinearSRGB()
    }

    public func isInSRGBGamut(tolerance: Double = 1e-4) -> Bool {
        toLinearSRGB().isInSRGBGamut(tolerance: tolerance)
    }

    /// Computes the maximum sRGB-representable chroma at `(l, h)` via binary search.
    public static func maximumSRGBChroma(
        lightness: Double,
        hue: Double,
        iterations: Int = 26
    ) -> Double {
        let clampedL = min(max(0.0, lightness), 1.0)
        if clampedL <= 1e-5 || clampedL >= 1.0 - 1e-5 {
            return 0.0
        }
        var low = 0.0
        var high = 0.40
        for _ in 0..<iterations {
            let mid = 0.5 * (low + high)
            let probe = OklchColor(l: clampedL, c: mid, h: hue)
            if probe.isInSRGBGamut(tolerance: 1e-5) {
                low = mid
            } else {
                high = mid
            }
        }
        return low
    }

    /// CSS Color Level 4 gamut-mapping algorithm: preserves perceptual lightness `L` and hue `H`
    /// while compressing chroma `C` via binary search + JND (`ΔE_OK < 0.02`) check.
    public func gamutMappedOklch(iterations: Int = 24) -> OklchColor {
        if l <= 0.0 {
            return OklchColor(l: 0.0, c: 0.0, h: h, alpha: alpha)
        }
        if l >= 1.0 {
            return OklchColor(l: 1.0, c: 0.0, h: h, alpha: alpha)
        }
        if isInSRGBGamut(tolerance: 1e-4) {
            return self
        }

        let jndEpsilon = 0.02
        var minChroma = 0.0
        var maxChroma = c

        for _ in 0..<iterations {
            if maxChroma - minChroma <= 1e-6 {
                break
            }
            let midChroma = 0.5 * (minChroma + maxChroma)
            let candidate = OklchColor(l: l, c: midChroma, h: h, alpha: alpha)
            if candidate.isInSRGBGamut(tolerance: 1e-5) {
                minChroma = midChroma
            } else {
                let clippedLab = OklabColor(srgb: candidate.toLinearSRGB().clampedToSRGB())
                let candidateLab = candidate.toOklab()
                if clippedLab.euclideanDistance(to: candidateLab) < jndEpsilon {
                    // Check if clipped color actually stays close in lightness
                    if abs(clippedLab.l - l) < jndEpsilon {
                        maxChroma = midChroma
                    } else {
                        maxChroma = midChroma
                    }
                } else {
                    maxChroma = midChroma
                }
            }
        }
        return OklchColor(l: l, c: minChroma, h: h, alpha: alpha)
    }

    /// Converts this OKLCH color into an in-gamut sRGB `RGBAColor` using chroma binary-search compression.
    public func gamutMappedToSRGB(iterations: Int = 24) -> RGBAColor {
        gamutMappedOklch(iterations: iterations).toLinearSRGB().clampedToSRGB()
    }

    /// Formats as CSS Color Level 4 `oklch(...)` notation.
    public var cssString: String {
        let lPct = l * 100.0
        if alpha < 0.9995 {
            return String(format: "oklch(%.2f%% %.4f %.2f / %.3f)", lPct, c, h, alpha)
        }
        return String(format: "oklch(%.2f%% %.4f %.2f)", lPct, c, h)
    }

    /// Hue-shortest-arc cylindrical interpolation between two OKLCH colors.
    public func interpolated(to other: OklchColor, t: Double) -> OklchColor {
        let clamped = min(max(0.0, t), 1.0)
        var deltaH = other.h - h
        if deltaH > 180.0 { deltaH -= 360.0 }
        if deltaH < -180.0 { deltaH += 360.0 }

        let resolvedHue: Double
        if c < 1e-5 {
            resolvedHue = other.h
        } else if other.c < 1e-5 {
            resolvedHue = h
        } else {
            resolvedHue = normalizeDegrees(h + deltaH * clamped)
        }

        return OklchColor(
            l: l + (other.l - l) * clamped,
            c: c + (other.c - c) * clamped,
            h: resolvedHue,
            alpha: alpha + (other.alpha - alpha) * clamped
        )
    }
}

// MARK: - APCA W3 Contrast Engine (SAPC / APCA 0.0.98G-4g)

public enum APCAPolarity: String, Codable, Hashable, Sendable {
    /// Dark text rendered on a lighter background (`Lc > 0`, BoW).
    case darkOnLight
    /// Light text rendered on a darker background (`Lc < 0`, WoB).
    case lightOnDark
}

public enum APCAUsageContext: String, CaseIterable, Codable, Hashable, Sendable {
    case fluentBodyCopy
    case primaryContentText
    case subheadlineOrLabel
    case largeDisplayHeadline
    case interactiveControlOrIcon
    case decorativeOrPlaceholder

    public var minimumRecommendedLc: Double {
        switch self {
        case .fluentBodyCopy: 90.0
        case .primaryContentText: 75.0
        case .subheadlineOrLabel: 60.0
        case .largeDisplayHeadline: 45.0
        case .interactiveControlOrIcon: 30.0
        case .decorativeOrPlaceholder: 15.0
        }
    }
}

public struct APCAEvaluation: Codable, Hashable, Sendable {
    public let lcValue: Double
    public let magnitudeLc: Double
    public let polarity: APCAPolarity
    public let wcag2Ratio: Double
    public let passesBodyCopy: Bool
    public let passesContentText: Bool
    public let passesLargeHeadline: Bool
    public let passesNonTextUI: Bool
    public let minimumFontSizeAtRegular400: Double?
    public let minimumFontSizeAtSemibold600: Double?
    public let minimumFontSizeAtBold700: Double?

    public init(text: RGBAColor, background: RGBAColor) {
        let lc = PerceptualColorScience.apcaContrast(text: text, background: background)
        let mag = abs(lc)
        self.lcValue = lc
        self.magnitudeLc = mag
        self.polarity = lc >= 0 ? .darkOnLight : .lightOnDark
        self.wcag2Ratio = text.contrastRatio(against: background)
        self.passesBodyCopy = mag >= 75.0
        self.passesContentText = mag >= 60.0
        self.passesLargeHeadline = mag >= 45.0
        self.passesNonTextUI = mag >= 30.0
        self.minimumFontSizeAtRegular400 = PerceptualColorScience.apcaMinimumFontSize(forLc: lc, fontWeight: 400)
        self.minimumFontSizeAtSemibold600 = PerceptualColorScience.apcaMinimumFontSize(forLc: lc, fontWeight: 600)
        self.minimumFontSizeAtBold700 = PerceptualColorScience.apcaMinimumFontSize(forLc: lc, fontWeight: 700)
    }
}

// MARK: - Perceptual Difference Rating (CIEDE2000)

public enum PerceptualDifferenceRating: String, Codable, Hashable, Sendable {
    case imperceptible = "Imperceptible (ΔE00 < 1.0)"
    case subtleCloseObservation = "Subtle / Expert Only (1.0–2.0)"
    case noticeableAtAGlance = "Noticeable at a Glance (2.0–5.0)"
    case clearlyDistinctHueOrTone = "Clearly Distinct (5.0–12.0)"
    case stronglyContrastingColors = "Strongly Contrasting (> 12.0)"

    public static func classify(deltaE2000: Double) -> PerceptualDifferenceRating {
        if deltaE2000 < 1.0 { return .imperceptible }
        if deltaE2000 < 2.0 { return .subtleCloseObservation }
        if deltaE2000 < 5.0 { return .noticeableAtAGlance }
        if deltaE2000 < 12.0 { return .clearlyDistinctHueOrTone }
        return .stronglyContrastingColors
    }
}

// MARK: - Color Vision Deficiency Simulation (Brettel / Viénot / Machado)

public enum ColorBlindnessKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case normal = "Normal Trichromacy"
    case protanopia = "Protanopia (L-Cone Absent)"
    case deuteranopia = "Deuteranopia (M-Cone Absent)"
    case tritanopia = "Tritanopia (S-Cone Absent)"
    case achromatopsia = "Achromatopsia (Rod Monochromacy)"
    case protanomaly = "Protanomaly (L-Cone Shifted ~60%)"
    case deuteranomaly = "Deuteranomaly (M-Cone Shifted ~60%)"

    public var id: String { rawValue }

    public var prevalenceEstimate: String {
        switch self {
        case .normal: "~92.0% of population"
        case .protanopia: "~1.0% of males"
        case .deuteranopia: "~1.1% of males"
        case .tritanopia: "~0.008% of population"
        case .achromatopsia: "~0.003% of population"
        case .protanomaly: "~1.1% of males"
        case .deuteranomaly: "~4.9% of males"
        }
    }

    /// Physiologically-based 3x3 transform matrix operating in Linear sRGB space
    /// derived from Machado-Oliveira-Fernandes (IEEE TVCG 2009) & Viénot/Brettel dichromat projections.
    public var linearRGBMatrix: [[Double]] {
        switch self {
        case .normal:
            return [
                [1.0, 0.0, 0.0],
                [0.0, 1.0, 0.0],
                [0.0, 0.0, 1.0]
            ]
        case .protanopia:
            return [
                [0.152286, 1.052583, -0.204868],
                [0.114503, 0.786281,  0.099216],
                [-0.003882, -0.048116, 1.051998]
            ]
        case .deuteranopia:
            return [
                [0.367322, 0.860646, -0.227968],
                [0.280085, 0.672501,  0.047413],
                [-0.011820, 0.042940, 0.968881]
            ]
        case .tritanopia:
            return [
                [1.255528, -0.076749, -0.178779],
                [-0.078411, 0.930809,  0.147602],
                [0.004733,  0.691367,  0.303900]
            ]
        case .achromatopsia:
            return [
                [0.2126729, 0.7151522, 0.0721750],
                [0.2126729, 0.7151522, 0.0721750],
                [0.2126729, 0.7151522, 0.0721750]
            ]
        case .protanomaly:
            // Machado 2009 ~0.60 severity matrix (12 nm L-cone spectral shift)
            return [
                [0.458064, 0.679578, -0.137642],
                [0.092785, 0.846313,  0.060902],
                [-0.007494, -0.016807, 1.024301]
            ]
        case .deuteranomaly:
            // Machado 2009 ~0.60 severity matrix (12 nm M-cone spectral shift)
            return [
                [0.547494, 0.607765, -0.155259],
                [0.181692, 0.781742,  0.036566],
                [-0.010410, 0.027275, 0.983136]
            ]
        }
    }
}

public struct ColorPairDistinguishability: Codable, Hashable, Sendable {
    public let firstIndex: Int
    public let secondIndex: Int
    public let condition: ColorBlindnessKind
    public let simulatedDeltaE2000: Double
    public let isConfusable: Bool

    public init(
        firstIndex: Int,
        secondIndex: Int,
        condition: ColorBlindnessKind,
        simulatedDeltaE2000: Double,
        isConfusable: Bool
    ) {
        self.firstIndex = firstIndex
        self.secondIndex = secondIndex
        self.condition = condition
        self.simulatedDeltaE2000 = simulatedDeltaE2000
        self.isConfusable = isConfusable
    }
}

public struct ColorBlindnessSafetyReport: Codable, Hashable, Sendable {
    public let minimumDeltaEAcrossAllConditions: Double
    public let confusablePairs: [ColorPairDistinguishability]
    public let isUniversalSafe: Bool

    public init(
        minimumDeltaEAcrossAllConditions: Double,
        confusablePairs: [ColorPairDistinguishability],
        isUniversalSafe: Bool
    ) {
        self.minimumDeltaEAcrossAllConditions = minimumDeltaEAcrossAllConditions
        self.confusablePairs = confusablePairs
        self.isUniversalSafe = isUniversalSafe
    }
}

// MARK: - Perceptual 11-Stop Tonal Scale & Harmony Models

public enum TonalStop: Int, CaseIterable, Comparable, Codable, Hashable, Identifiable, Sendable {
    case s50 = 50
    case s100 = 100
    case s200 = 200
    case s300 = 300
    case s400 = 400
    case s500 = 500
    case s600 = 600
    case s700 = 700
    case s800 = 800
    case s900 = 900
    case s950 = 950

    public var id: Int { rawValue }

    public static func < (lhs: TonalStop, rhs: TonalStop) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Target OKLCH perceptual lightness `L` across the 11-stop scale.
    public var targetLightness: Double {
        switch self {
        case .s50: 0.974
        case .s100: 0.938
        case .s200: 0.876
        case .s300: 0.798
        case .s400: 0.708
        case .s500: 0.614
        case .s600: 0.522
        case .s700: 0.434
        case .s800: 0.348
        case .s900: 0.268
        case .s950: 0.188
        }
    }

    /// Parabolic chroma envelope multiplier keeping extreme highlights & shadows clean and non-muddy.
    public var chromaMultiplier: Double {
        switch self {
        case .s50: 0.14
        case .s100: 0.28
        case .s200: 0.52
        case .s300: 0.76
        case .s400: 0.94
        case .s500: 1.00
        case .s600: 0.98
        case .s700: 0.88
        case .s800: 0.74
        case .s900: 0.58
        case .s950: 0.42
        }
    }
}

public struct TonalScaleSwatch: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { stop.rawValue }
    public let stop: TonalStop
    public let oklch: OklchColor
    public let srgb: RGBAColor
    public let apcaOnWhite: Double
    public let apcaOnBlack: Double

    public init(stop: TonalStop, oklch: OklchColor, srgb: RGBAColor) {
        self.stop = stop
        self.oklch = oklch
        self.srgb = srgb
        self.apcaOnWhite = PerceptualColorScience.apcaContrast(text: srgb, background: .white)
        self.apcaOnBlack = PerceptualColorScience.apcaContrast(
            text: srgb,
            background: RGBAColor(red: 0.04, green: 0.05, blue: 0.07)
        )
    }
}

public struct TonalScale: Codable, Hashable, Sendable {
    public let name: String
    public let seedColor: RGBAColor
    public let swatches: [TonalScaleSwatch]

    public init(name: String, seedColor: RGBAColor, swatches: [TonalScaleSwatch]) {
        self.name = name
        self.seedColor = seedColor
        self.swatches = swatches.sorted { $0.stop < $1.stop }
    }

    public subscript(stop: TonalStop) -> RGBAColor {
        swatches.first(where: { $0.stop == stop })?.srgb ?? seedColor
    }

    public func oklch(at stop: TonalStop) -> OklchColor {
        swatches.first(where: { $0.stop == stop })?.oklch ?? OklchColor(srgb: seedColor)
    }
}

public enum ColorHarmonyRule: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case complementary = "Complementary (180°)"
    case splitComplementary = "Split Complementary (±150°)"
    case triadic = "Triadic (120° / 240°)"
    case analogous = "Analogous (±30°)"
    case tetradic = "Tetradic Rectangular (60° / 180° / 240°)"
    case monochromatic = "Monochromatic Tonal"

    public var id: String { rawValue }

    /// Relative OKLCH hue offsets in degrees from the base seed hue.
    public var hueOffsets: [Double] {
        switch self {
        case .complementary: [0.0, 180.0]
        case .splitComplementary: [0.0, 150.0, 210.0]
        case .triadic: [0.0, 120.0, 240.0]
        case .analogous: [-30.0, 0.0, 30.0]
        case .tetradic: [0.0, 60.0, 180.0, 240.0]
        case .monochromatic: [0.0, 0.0, 0.0, 0.0]
        }
    }
}

public struct HarmoniousPalette: Codable, Hashable, Sendable {
    public let rule: ColorHarmonyRule
    public let baseColor: RGBAColor
    public let primarySwatches: [RGBAColor]
    public let oklchSwatches: [OklchColor]
    public let scales: [TonalScale]

    public init(
        rule: ColorHarmonyRule,
        baseColor: RGBAColor,
        primarySwatches: [RGBAColor],
        oklchSwatches: [OklchColor],
        scales: [TonalScale]
    ) {
        self.rule = rule
        self.baseColor = baseColor
        self.primarySwatches = primarySwatches
        self.oklchSwatches = oklchSwatches
        self.scales = scales
    }
}

// MARK: - PerceptualColorScience Primary Engine

public enum PerceptualColorScience {

    // MARK: APCA W3 0.0.98G-4g Implementation

    /// Computes Accessible Perceptual Contrast Algorithm (APCA W3 0.0.98G-4g) `Lc` contrast value
    /// in the range `[-108.0, +106.0]`.
    /// - Positive `Lc`: dark text on lighter background (BoW).
    /// - Negative `Lc`: light text on darker background (WoB).
    public static func apcaContrast(text: RGBAColor, background: RGBAColor) -> Double {
        func screenLuminance(_ c: RGBAColor) -> Double {
            let rLin = pow(max(0.0, c.red), 2.4)
            let gLin = pow(max(0.0, c.green), 2.4)
            let bLin = pow(max(0.0, c.blue), 2.4)
            return 0.2126729 * rLin + 0.7151522 * gLin + 0.0721750 * bLin
        }

        func softClamp(_ y: Double) -> Double {
            let blkThrs = 0.022
            let blkClmp = 1.414
            let clampedY = max(0.0, y)
            if clampedY >= blkThrs {
                return clampedY
            }
            return clampedY + pow(blkThrs - clampedY, blkClmp)
        }

        // Composite semi-transparent foreground onto background if alpha < 1
        let compositedText: RGBAColor
        if text.alpha < 0.9999 {
            let a = text.alpha
            compositedText = RGBAColor(
                red: text.red * a + background.red * (1.0 - a),
                green: text.green * a + background.green * (1.0 - a),
                blue: text.blue * a + background.blue * (1.0 - a),
                alpha: 1.0
            )
        } else {
            compositedText = text
        }

        let yTxt = softClamp(screenLuminance(compositedText))
        let yBg = softClamp(screenLuminance(background))

        let deltaYMin = 0.0005
        if abs(yBg - yTxt) < deltaYMin {
            return 0.0
        }

        let normBG = 0.56
        let normTXT = 0.57
        let revTXT = 0.62
        let revBG = 0.65
        let scaleBoW = 1.14
        let scaleWoB = 1.14
        let loBoWOffset = 0.027
        let loWoBOffset = 0.027
        let loClip = 0.1

        let sapc: Double
        let outputContrast: Double

        if yBg > yTxt {
            // Normal polarity: Dark text on Light background (BoW -> positive Lc)
            sapc = (pow(yBg, normBG) - pow(yTxt, normTXT)) * scaleBoW
            if sapc < loClip {
                outputContrast = 0.0
            } else {
                outputContrast = sapc - loBoWOffset
            }
        } else {
            // Reverse polarity: Light text on Dark background (WoB -> negative Lc)
            sapc = (pow(yBg, revBG) - pow(yTxt, revTXT)) * scaleWoB
            if sapc > -loClip {
                outputContrast = 0.0
            } else {
                outputContrast = sapc + loWoBOffset
            }
        }

        return outputContrast * 100.0
    }

    /// W3 APCA Font-Weight & Polarity Lookup Table (`fontWeight` in `100...900`).
    /// Returns the minimum recommended CSS/SwiftUI point size for readable text, or `nil` if prohibited.
    public static func apcaMinimumFontSize(forLc lc: Double, fontWeight: Int) -> Double? {
        let mag = abs(lc)
        guard mag >= 15.0 else { return nil }

        // Snap weight to nearest 100 in 100...900
        let weightIndex = min(max(0, (fontWeight + 50) / 100 - 1), 8)

        // APCA W3 canonical reference matrix rows ordered by descending Lc threshold
        // Columns correspond to weights: [100, 200, 300, 400, 500, 600, 700, 800, 900]
        // Values >= 999 indicate disallowed/discouraged at that ultra-thin or ultra-heavy weight.
        let table: [(threshold: Double, sizes: [Double])] = [
            (90.0, [30, 20, 15, 12, 11, 10, 10, 12, 14]),
            (85.0, [34, 22, 16, 13, 12, 11, 11, 13, 15]),
            (80.0, [38, 24, 18, 14, 13, 12, 12, 14, 16]),
            (75.0, [42, 28, 20, 15, 14, 13, 12, 15, 18]),
            (70.0, [48, 32, 22, 16, 14.5, 13.5, 13, 16, 19]),
            (65.0, [54, 36, 25, 17, 15.5, 14.5, 14, 17, 20]),
            (60.0, [60, 40, 28, 18, 16, 15, 14.5, 18, 22]),
            (55.0, [68, 46, 32, 21, 18, 16.5, 16, 20, 24]),
            (50.0, [78, 54, 36, 24, 20, 18, 17, 22, 26]),
            (45.0, [90, 62, 42, 28, 24, 21, 19, 25, 30]),
            (40.0, [999, 72, 48, 32, 28, 24, 22, 28, 34]),
            (35.0, [999, 86, 58, 38, 32, 28, 26, 32, 38]),
            (30.0, [999, 999, 72, 46, 38, 34, 30, 38, 44]),
            (25.0, [999, 999, 92, 60, 48, 42, 38, 46, 54]),
            (20.0, [999, 999, 999, 78, 64, 54, 48, 58, 68]),
            (15.0, [999, 999, 999, 96, 80, 68, 60, 72, 84])
        ]

        // Light-on-dark polarity requires slightly (~1pt) more conservative sizing for halation control
        let polarityPenalty = lc < 0 ? 1.0 : 0.0

        for row in table where mag >= row.threshold {
            let baseSize = row.sizes[weightIndex]
            guard baseSize < 900 else { return nil }
            return baseSize + polarityPenalty
        }
        return nil
    }

    /// Adjusts `text` color in OKLCH lightness via binary search so `|apcaContrast(text:background:)| >= minimumMagnitudeLc`
    /// while preserving perceptual hue and compressing chroma smoothly into sRGB gamut.
    public static func adjustForAPCAContrast(
        text: RGBAColor,
        against background: RGBAColor,
        minimumMagnitudeLc: Double = 60.0
    ) -> RGBAColor {
        let currentLc = abs(apcaContrast(text: text, background: background))
        if currentLc >= minimumMagnitudeLc {
            return text
        }

        let seedOklch = OklchColor(srgb: text)
        let bgOklch = OklchColor(srgb: background)
        let shouldDarken = bgOklch.l >= 0.54

        var lowL = shouldDarken ? 0.0 : seedOklch.l
        var highL = shouldDarken ? seedOklch.l : 1.0
        var bestCandidate = shouldDarken
            ? OklchColor(l: 0.05, c: seedOklch.c * 0.4, h: seedOklch.h, alpha: text.alpha).gamutMappedToSRGB()
            : OklchColor(l: 0.98, c: seedOklch.c * 0.3, h: seedOklch.h, alpha: text.alpha).gamutMappedToSRGB()

        for _ in 0..<28 {
            let midL = 0.5 * (lowL + highL)
            let candidate = OklchColor(l: midL, c: seedOklch.c, h: seedOklch.h, alpha: text.alpha)
                .gamutMappedToSRGB(iterations: 18)
            let mag = abs(apcaContrast(text: candidate, background: background))

            if mag >= minimumMagnitudeLc {
                bestCandidate = candidate
                // Move closer to original lightness while maintaining target contrast
                if shouldDarken {
                    lowL = midL
                } else {
                    highL = midL
                }
            } else {
                if shouldDarken {
                    highL = midL
                } else {
                    lowL = midL
                }
            }
        }
        return bestCandidate
    }

    // MARK: CIEDE2000 Perceptual Color Difference (Sharma, Wu & Dalal 2005)

    /// Computes exact CIE ΔE2000 perceptual color difference between two `CIELabColor` samples.
    public static func deltaE2000(
        _ lab1: CIELabColor,
        _ lab2: CIELabColor,
        kL: Double = 1.0,
        kC: Double = 1.0,
        kH: Double = 1.0
    ) -> Double {
        let c1 = hypot(lab1.a, lab1.b)
        let c2 = hypot(lab2.a, lab2.b)
        let cBar = 0.5 * (c1 + c2)

        let cBar7 = pow(cBar, 7.0)
        let twentyFive7 = 6103515625.0 // 25^7
        let gFactor = 0.5 * (1.0 - sqrt(cBar7 / (cBar7 + twentyFive7)))

        let a1Prime = (1.0 + gFactor) * lab1.a
        let a2Prime = (1.0 + gFactor) * lab2.a

        let c1Prime = hypot(a1Prime, lab1.b)
        let c2Prime = hypot(a2Prime, lab2.b)

        func huePrimeDegrees(aPrime: Double, b: Double) -> Double {
            if abs(aPrime) < 1e-12 && abs(b) < 1e-12 {
                return 0.0
            }
            return normalizeDegrees(radiansToDegrees(atan2(b, aPrime)))
        }

        let h1Prime = huePrimeDegrees(aPrime: a1Prime, b: lab1.b)
        let h2Prime = huePrimeDegrees(aPrime: a2Prime, b: lab2.b)

        let deltaLPrime = lab2.l - lab1.l
        let deltaCPrime = c2Prime - c1Prime

        let cPrimeProduct = c1Prime * c2Prime
        let deltaHPrimeAngle: Double
        if cPrimeProduct < 1e-12 {
            deltaHPrimeAngle = 0.0
        } else {
            let diff = h2Prime - h1Prime
            if abs(diff) <= 180.0 {
                deltaHPrimeAngle = diff
            } else if diff > 180.0 {
                deltaHPrimeAngle = diff - 360.0
            } else {
                deltaHPrimeAngle = diff + 360.0
            }
        }

        let deltaHPrime = 2.0 * sqrt(cPrimeProduct) * sin(degreesToRadians(0.5 * deltaHPrimeAngle))

        let lBarPrime = 0.5 * (lab1.l + lab2.l)
        let cBarPrime = 0.5 * (c1Prime + c2Prime)

        let hBarPrime: Double
        if cPrimeProduct < 1e-12 {
            hBarPrime = h1Prime + h2Prime
        } else {
            let sum = h1Prime + h2Prime
            if abs(h1Prime - h2Prime) <= 180.0 {
                hBarPrime = 0.5 * sum
            } else if sum < 360.0 {
                hBarPrime = 0.5 * (sum + 360.0)
            } else {
                hBarPrime = 0.5 * (sum - 360.0)
            }
        }

        let tFactor = 1.0
            - 0.17 * cos(degreesToRadians(hBarPrime - 30.0))
            + 0.24 * cos(degreesToRadians(2.0 * hBarPrime))
            + 0.32 * cos(degreesToRadians(3.0 * hBarPrime + 6.0))
            - 0.20 * cos(degreesToRadians(4.0 * hBarPrime - 63.0))

        let deltaTheta = 30.0 * exp(-pow((hBarPrime - 275.0) / 25.0, 2.0))
        let cBarPrime7 = pow(cBarPrime, 7.0)
        let rC = 2.0 * sqrt(cBarPrime7 / (cBarPrime7 + twentyFive7))

        let lMinus50Sq = (lBarPrime - 50.0) * (lBarPrime - 50.0)
        let sL = 1.0 + (0.015 * lMinus50Sq) / sqrt(20.0 + lMinus50Sq)
        let sC = 1.0 + 0.045 * cBarPrime
        let sH = 1.0 + 0.015 * cBarPrime * tFactor
        let rT = -sin(degreesToRadians(2.0 * deltaTheta)) * rC

        let termL = deltaLPrime / (kL * sL)
        let termC = deltaCPrime / (kC * sC)
        let termH = deltaHPrime / (kH * sH)

        let radicand = termL * termL + termC * termC + termH * termH + rT * termC * termH
        return sqrt(max(0.0, radicand))
    }

    /// Computes CIE ΔE2000 perceptual color difference between two sRGB `RGBAColor` values.
    public static func deltaE2000(
        _ lhs: RGBAColor,
        _ rhs: RGBAColor,
        kL: Double = 1.0,
        kC: Double = 1.0,
        kH: Double = 1.0
    ) -> Double {
        deltaE2000(CIELabColor(srgb: lhs), CIELabColor(srgb: rhs), kL: kL, kC: kC, kH: kH)
    }

    // MARK: Color-Vision Deficiency Simulation & Daltonization

    /// Simulates how `color` appears to an observer with `condition` at optional `severity` in `[0, 1]`.
    public static func simulateColorBlindness(
        _ color: RGBAColor,
        condition: ColorBlindnessKind,
        severity: Double = 1.0
    ) -> RGBAColor {
        if condition == .normal || severity <= 0.0 {
            return color
        }
        let lin = LinearSRGBColor(srgb: color)
        let m = condition.linearRGBMatrix
        let simLin = LinearSRGBColor(
            r: m[0][0] * lin.r + m[0][1] * lin.g + m[0][2] * lin.b,
            g: m[1][0] * lin.r + m[1][1] * lin.g + m[1][2] * lin.b,
            b: m[2][0] * lin.r + m[2][1] * lin.g + m[2][2] * lin.b,
            alpha: lin.alpha
        )
        let clampedSeverity = min(max(0.0, severity), 1.0)
        return lin.mixed(with: simLin, fraction: clampedSeverity).clampedToSRGB()
    }

    /// Daltonizes `color` for `condition` by projecting lost chromatic signal onto remaining cone axes.
    public static func daltonize(
        _ color: RGBAColor,
        for condition: ColorBlindnessKind,
        strength: Double = 0.85
    ) -> RGBAColor {
        if condition == .normal || condition == .achromatopsia {
            return color
        }
        let orig = LinearSRGBColor(srgb: color)
        let sim = LinearSRGBColor(srgb: simulateColorBlindness(color, condition: condition))
        let errR = orig.r - sim.r
        let errG = orig.g - sim.g
        let errB = orig.b - sim.b

        let shiftR: Double
        let shiftG: Double
        let shiftB: Double

        switch condition {
        case .protanopia, .protanomaly:
            shiftR = 0.0
            shiftG = 0.7 * errR + errG
            shiftB = 0.7 * errR + errB
        case .deuteranopia, .deuteranomaly:
            shiftR = 0.7 * errG + errR
            shiftG = 0.0
            shiftB = 0.7 * errG + errB
        case .tritanopia:
            shiftR = 0.7 * errB + errR
            shiftG = 0.7 * errB + errG
            shiftB = 0.0
        case .normal, .achromatopsia:
            shiftR = 0.0
            shiftG = 0.0
            shiftB = 0.0
        }

        let k = min(max(0.0, strength), 1.0)
        let corrected = LinearSRGBColor(
            r: orig.r + k * shiftR,
            g: orig.g + k * shiftG,
            b: orig.b + k * shiftB,
            alpha: orig.alpha
        )
        return corrected.clampedToSRGB()
    }

    /// Audits an array of categorical/semantic UI colors across trichromatic and dichromatic conditions.
    public static func auditPaletteDistinguishability(
        colors: [RGBAColor],
        minimumDeltaE2000: Double = 7.5
    ) -> ColorBlindnessSafetyReport {
        guard colors.count >= 2 else {
            return ColorBlindnessSafetyReport(
                minimumDeltaEAcrossAllConditions: 100.0,
                confusablePairs: [],
                isUniversalSafe: true
            )
        }

        let conditionsToCheck: [ColorBlindnessKind] = [
            .normal, .protanopia, .deuteranopia, .tritanopia, .protanomaly, .deuteranomaly
        ]

        var minDelta = Double.greatestFiniteMagnitude
        var confusables: [ColorPairDistinguishability] = []

        for condition in conditionsToCheck {
            let simulated = colors.map { simulateColorBlindness($0, condition: condition) }
            for i in 0..<(simulated.count - 1) {
                for j in (i + 1)..<simulated.count {
                    let de = deltaE2000(simulated[i], simulated[j])
                    if de < minDelta {
                        minDelta = de
                    }
                    if de < minimumDeltaE2000 {
                        confusables.append(
                            ColorPairDistinguishability(
                                firstIndex: i,
                                secondIndex: j,
                                condition: condition,
                                simulatedDeltaE2000: de,
                                isConfusable: true
                            )
                        )
                    }
                }
            }
        }

        return ColorBlindnessSafetyReport(
            minimumDeltaEAcrossAllConditions: minDelta.isFinite ? minDelta : 0.0,
            confusablePairs: confusables,
            isUniversalSafe: confusables.isEmpty
        )
    }

    // MARK: Perceptual 11-Stop Tonal Scale & Harmony Synthesis

    /// Generates an 11-stop perceptual tonal ramp (`50...950`) in OKLCH space from a seed `RGBAColor`.
    /// Includes Bezold-Brücke hue-shift compensation so yellows stay warm and blues stay crisp across lightness stops.
    public static func generateTonalScale(
        named name: String,
        from seed: RGBAColor,
        preserveExactSeedAtNearestStop: Bool = false
    ) -> TonalScale {
        let seedOklch = OklchColor(srgb: seed)
        // Ensure chromatic scales maintain balanced peak chroma while neutral seeds stay subtly tinted
        let baseChroma = seedOklch.c < 0.012 ? seedOklch.c : max(0.035, min(0.26, seedOklch.c / 0.92))

        // Find closest stop if caller wants exact seed anchored
        let nearestStop = TonalStop.allCases.min {
            abs($0.targetLightness - seedOklch.l) < abs($1.targetLightness - seedOklch.l)
        }

        let swatches: [TonalScaleSwatch] = TonalStop.allCases.map { stop in
            if preserveExactSeedAtNearestStop && stop == nearestStop {
                return TonalScaleSwatch(stop: stop, oklch: seedOklch, srgb: seed)
            }

            let targetL = stop.targetLightness
            let targetC = baseChroma * stop.chromaMultiplier

            // Subtle Bezold-Brücke hue compensation (+/- 4 deg from midtone toward cooler shadows & warmer highlights)
            let lightnessDelta = targetL - 0.58
            let hueShift = seedOklch.c > 0.02 ? lightnessDelta * 5.0 * sin(degreesToRadians(seedOklch.h)) : 0.0
            let rawOklch = OklchColor(
                l: targetL,
                c: targetC,
                h: seedOklch.h + hueShift,
                alpha: seed.alpha
            )
            let mappedOklch = rawOklch.gamutMappedOklch(iterations: 22)
            let mappedSRGB = mappedOklch.toLinearSRGB().clampedToSRGB()
            return TonalScaleSwatch(stop: stop, oklch: mappedOklch, srgb: mappedSRGB)
        }

        return TonalScale(name: name, seedColor: seed, swatches: swatches)
    }

    /// Synthesizes a multi-swatch harmonious palette and full 11-stop scales for each harmonic accent.
    public static func synthesizeHarmony(
        from baseColor: RGBAColor,
        rule: ColorHarmonyRule
    ) -> HarmoniousPalette {
        let seed = OklchColor(srgb: baseColor)
        let offsets = rule.hueOffsets

        var srgbList: [RGBAColor] = []
        var oklchList: [OklchColor] = []
        var scales: [TonalScale] = []

        for (idx, offset) in offsets.enumerated() {
            let lightnessVariant: Double
            let chromaVariant: Double

            if rule == .monochromatic {
                let steppedLightness = [0.34, 0.52, 0.68, 0.84]
                lightnessVariant = steppedLightness[idx % steppedLightness.count]
                chromaVariant = seed.c * (idx == 3 ? 0.55 : 0.95)
            } else {
                lightnessVariant = min(max(0.32, seed.l + (idx == 0 ? 0.0 : Double((idx % 2 == 0) ? 0.04 : -0.03))), 0.78)
                chromaVariant = idx == 0 ? seed.c : max(0.06, seed.c * 0.92)
            }

            let raw = OklchColor(
                l: lightnessVariant,
                c: chromaVariant,
                h: seed.h + offset,
                alpha: baseColor.alpha
            )
            let mappedOklch = raw.gamutMappedOklch(iterations: 24)
            let mappedSRGB = mappedOklch.toLinearSRGB().clampedToSRGB()

            oklchList.append(mappedOklch)
            srgbList.append(mappedSRGB)
            scales.append(
                generateTonalScale(
                    named: "harmony_\(idx + 1)",
                    from: mappedSRGB
                )
            )
        }

        return HarmoniousPalette(
            rule: rule,
            baseColor: baseColor,
            primarySwatches: srgbList,
            oklchSwatches: oklchList,
            scales: scales
        )
    }
}

// MARK: - Convenient RGBAColor Extensions

public extension RGBAColor {
    /// Parses `#RRGGBB`, `#RRGGBBAA`, `RRGGBB`, or `#RGB` hexadecimal strings into `RGBAColor`.
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let length = trimmed.count
        var rawValue: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&rawValue) else {
            return nil
        }

        switch length {
        case 3:
            let r = Double((rawValue >> 8) & 0xF) / 15.0
            let g = Double((rawValue >> 4) & 0xF) / 15.0
            let b = Double(rawValue & 0xF) / 15.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        case 6:
            let r = Double((rawValue >> 16) & 0xFF) / 255.0
            let g = Double((rawValue >> 8) & 0xFF) / 255.0
            let b = Double(rawValue & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        case 8:
            let r = Double((rawValue >> 24) & 0xFF) / 255.0
            let g = Double((rawValue >> 16) & 0xFF) / 255.0
            let b = Double((rawValue >> 8) & 0xFF) / 255.0
            let a = Double(rawValue & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }

    var linearSRGB: LinearSRGBColor {
        LinearSRGBColor(srgb: self)
    }

    var cieXYZ: CIEXYZColor {
        CIEXYZColor(srgb: self)
    }

    var cieLab: CIELabColor {
        CIELabColor(srgb: self)
    }

    var oklab: OklabColor {
        OklabColor(srgb: self)
    }

    var oklch: OklchColor {
        OklchColor(srgb: self)
    }

    /// Computes APCA W3 `Lc` perceptual contrast when `self` is rendered as foreground text over `background`.
    func apcaContrast(against background: RGBAColor) -> Double {
        PerceptualColorScience.apcaContrast(text: self, background: background)
    }

    /// Computes full APCA evaluation diagnostics against `background`.
    func apcaEvaluation(against background: RGBAColor) -> APCAEvaluation {
        APCAEvaluation(text: self, background: background)
    }

    /// Computes CIEDE2000 perceptual difference `ΔE00` to `other`.
    func deltaE2000(to other: RGBAColor) -> Double {
        PerceptualColorScience.deltaE2000(self, other)
    }

    /// Simulates color-vision deficiency appearance.
    func simulated(for condition: ColorBlindnessKind, severity: Double = 1.0) -> RGBAColor {
        PerceptualColorScience.simulateColorBlindness(self, condition: condition, severity: severity)
    }

    /// Generates an 11-stop perceptual tonal scale (`50...950`) from `self`.
    func tonalScale(named name: String = "accent") -> TonalScale {
        PerceptualColorScience.generateTonalScale(named: name, from: self)
    }
}
