import ChiefKitStudioCore
import Foundation

// MARK: - Ephemeris Errors & Physical Constants

public enum EphemerisMathError: Error, LocalizedError, Equatable, Sendable {
    case invalidCalendarDate(year: Int, month: Int, day: Int)
    case invalidClockTime(hour: Int, minute: Int, second: Double)
    case invalidEccentricity(Double)
    case invalidSemiMajorAxis(Double)
    case keplerConvergenceFailure(eccentricity: Double, meanAnomalyRad: Double)
    case invalidObserverLatitude(Double)
    case invalidObserverLongitude(Double)

    public var errorDescription: String? {
        switch self {
        case .invalidCalendarDate(let y, let m, let d):
            return "Invalid calendar date \(y)-\(m)-\(d)."
        case .invalidClockTime(let h, let min, let sec):
            return "Invalid clock time \(h):\(min):\(sec)."
        case .invalidEccentricity(let e):
            return "Invalid orbital eccentricity (\(e)); must be >= 0 and finite."
        case .invalidSemiMajorAxis(let a):
            return "Invalid semi-major axis (\(a) AU); must be non-zero and finite."
        case .keplerConvergenceFailure(let e, let m):
            return "Kepler solver failed to reach 1e-12 rad tolerance for e=\(e), M=\(m)."
        case .invalidObserverLatitude(let lat):
            return "Observer geodetic latitude (\(lat) deg) must lie within [-90, +90]."
        case .invalidObserverLongitude(let lon):
            return "Observer geodetic longitude (\(lon) deg) must lie within [-180, +180]."
        }
    }
}

public enum EphemerisConstants {
    public static let j2000JulianDate: Double = 2_451_545.0
    public static let unixEpochJulianDate: Double = 2_440_587.5
    public static let modifiedJulianDateOffset: Double = 2_400_000.5
    public static let julianCenturyDays: Double = 36_525.0
    public static let julianMillenniumDays: Double = 365_250.0
    public static let secondsPerDay: Double = 86_400.0

    /// Exact IAU 2012 Astronomical Unit in kilometers.
    public static let astronomicalUnitKm: Double = 149_597_870.700
    public static let speedOfLightKmPerSec: Double = 299_792.458
    public static let lightTimeDaysPerAU: Double = 0.005_775_518_331_09
    public static let gaussianGravitationalConstant: Double = 0.017_202_098_95
    public static let heliocentricMuAU3PerDay2: Double = 0.000_295_912_208_285_591_1

    /// WGS-84 reference ellipsoid parameters.
    public static let wgs84EquatorialRadiusKm: Double = 6_378.137
    public static let wgs84Flattening: Double = 1.0 / 298.257_223_563

    public static let degToRad: Double = Double.pi / 180.0
    public static let radToDeg: Double = 180.0 / Double.pi
    public static let arcsecToDeg: Double = 1.0 / 3_600.0
    public static let arcsecToRad: Double = Double.pi / 648_000.0

    @inlinable
    public static func normalizeDegrees360(_ degrees: Double) -> Double {
        var mod = degrees.truncatingRemainder(dividingBy: 360.0)
        if mod < 0.0 {
            mod += 360.0
        }
        return mod == 360.0 ? 0.0 : mod
    }

    @inlinable
    public static func normalizeDegreesSigned180(_ degrees: Double) -> Double {
        var mod = normalizeDegrees360(degrees)
        if mod > 180.0 {
            mod -= 360.0
        }
        return mod
    }

    @inlinable
    public static func normalizeRadians2Pi(_ radians: Double) -> Double {
        let twoPi = 2.0 * Double.pi
        var mod = radians.truncatingRemainder(dividingBy: twoPi)
        if mod < 0.0 {
            mod += twoPi
        }
        return mod
    }

    @inlinable
    public static func normalizeRadiansSignedPi(_ radians: Double) -> Double {
        let twoPi = 2.0 * Double.pi
        var mod = normalizeRadians2Pi(radians)
        if mod > Double.pi {
            mod -= twoPi
        }
        return mod
    }
}

// MARK: - Sexagesimal Formatters (HMS & DMS)

public struct SexagesimalDMS: Codable, Equatable, Hashable, Sendable {
    public let isNegative: Bool
    public let degrees: Int
    public let minutes: Int
    public let seconds: Double

    public init(decimalDegrees: Double) {
        self.isNegative = decimalDegrees < 0.0
        let absVal = abs(decimalDegrees)
        let wholeDeg = Int(floor(absVal))
        let remMin = (absVal - Double(wholeDeg)) * 60.0
        let wholeMin = Int(floor(remMin))
        let sec = (remMin - Double(wholeMin)) * 60.0
        self.degrees = wholeDeg
        self.minutes = wholeMin
        self.seconds = sec
    }

    public var formatted: String {
        let sign = isNegative ? "-" : "+"
        let secRounded = (seconds * 100.0).rounded() / 100.0
        return "\(sign)\(degrees)° \(minutes)' \(secRounded)\""
    }
}

public struct SexagesimalHMS: Codable, Equatable, Hashable, Sendable {
    public let hours: Int
    public let minutes: Int
    public let seconds: Double

    public init(rightAscensionDegrees: Double) {
        let totalHours = EphemerisConstants.normalizeDegrees360(rightAscensionDegrees) / 15.0
        let wholeH = Int(floor(totalHours))
        let remM = (totalHours - Double(wholeH)) * 60.0
        let wholeM = Int(floor(remM))
        let sec = (remM - Double(wholeM)) * 60.0
        self.hours = wholeH
        self.minutes = wholeM
        self.seconds = sec
    }

    public var formatted: String {
        let secRounded = (seconds * 100.0).rounded() / 100.0
        return "\(hours)h \(minutes)m \(secRounded)s"
    }
}

// MARK: - Civil UTC Date-Time <-> Julian Date / Ephemeris Epoch

public struct CivilDateTime: Codable, Equatable, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int
    public let minute: Int
    public let second: Double

    public init(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Double = 0.0
    ) throws {
        guard (1...12).contains(month), (1...31).contains(day) else {
            throw EphemerisMathError.invalidCalendarDate(year: year, month: month, day: day)
        }
        guard (0...23).contains(hour), (0...59).contains(minute), second >= 0.0 && second < 61.0 else {
            throw EphemerisMathError.invalidClockTime(hour: hour, minute: minute, second: second)
        }
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    public init(utcDate: Date) {
        let jd = EphemerisConstants.unixEpochJulianDate
            + (utcDate.timeIntervalSince1970 / EphemerisConstants.secondsPerDay)
        let converted = Self.fromJulianDate(jd)
        self.year = converted.year
        self.month = converted.month
        self.day = converted.day
        self.hour = converted.hour
        self.minute = converted.minute
        self.second = converted.second
    }

    public var fractionalDay: Double {
        Double(day)
            + (Double(hour) / 24.0)
            + (Double(minute) / 1_440.0)
            + (second / 86_400.0)
    }

    public var decimalYearApprox: Double {
        Double(year) + ((Double(month - 1) + (fractionalDay - 1.0) / 30.4375) / 12.0)
    }

    /// Exact Meeus Chapter 7 Julian Date conversion supporting both Julian and Gregorian calendars.
    public func toJulianDate() -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }

        let isGregorian: Bool
        if year > 1582 {
            isGregorian = true
        } else if year < 1582 {
            isGregorian = false
        } else if month > 10 {
            isGregorian = true
        } else if month < 10 {
            isGregorian = false
        } else {
            isGregorian = day >= 15
        }

        let bTerm: Int
        if isGregorian {
            let aTerm = Int(floor(Double(y) / 100.0))
            bTerm = 2 - aTerm + Int(floor(Double(aTerm) / 4.0))
        } else {
            bTerm = 0
        }

        let term1 = floor(365.25 * Double(y + 4_716))
        let term2 = floor(30.6001 * Double(m + 1))
        return term1 + term2 + fractionalDay + Double(bTerm) - 1_524.5
    }

    public func toUTCDate() -> Date {
        let unixSeconds = (toJulianDate() - EphemerisConstants.unixEpochJulianDate) * EphemerisConstants.secondsPerDay
        return Date(timeIntervalSince1970: unixSeconds)
    }

    /// Inverse Julian Date -> Civil UTC calendar date-time (Meeus Chapter 7).
    public static func fromJulianDate(_ jd: Double) -> CivilDateTime {
        let shifted = jd + 0.5
        let z = Int(floor(shifted))
        let f = shifted - Double(z)

        let a: Int
        if z < 2_299_161 {
            a = z
        } else {
            let alpha = Int(floor((Double(z) - 186_7216.25) / 36_524.25))
            a = z + 1 + alpha - Int(floor(Double(alpha) / 4.0))
        }

        let b = a + 1_524
        let c = Int(floor((Double(b) - 122.1) / 365.25))
        let d = Int(floor(365.25 * Double(c)))
        let e = Int(floor(Double(b - d) / 30.6001))

        let dayWhole = b - d - Int(floor(30.6001 * Double(e)))
        let monthOut = (e < 14) ? (e - 1) : (e - 13)
        let yearOut = (monthOut > 2) ? (c - 4_716) : (c - 4_715)

        var totalSeconds = f * EphemerisConstants.secondsPerDay
        if totalSeconds < 0 { totalSeconds = 0 }
        var hourOut = Int(floor(totalSeconds / 3_600.0))
        totalSeconds -= Double(hourOut) * 3_600.0
        var minOut = Int(floor(totalSeconds / 60.0))
        var secOut = totalSeconds - Double(minOut) * 60.0

        if secOut >= 59.999_999_5 {
            secOut = 0.0
            minOut += 1
        }
        if minOut >= 60 {
            minOut = 0
            hourOut = min(23, hourOut + 1)
        }

        return (try? CivilDateTime(
            year: yearOut,
            month: max(1, min(12, monthOut)),
            day: max(1, min(31, dayWhole)),
            hour: max(0, min(23, hourOut)),
            minute: max(0, min(59, minOut)),
            second: max(0.0, secOut)
        )) ?? CivilDateTimeFallback.j2000
    }
}

private enum CivilDateTimeFallback {
    static let j2000 = try! CivilDateTime(year: 2000, month: 1, day: 1, hour: 12, minute: 0, second: 0.0)
}

public struct JulianEpoch: Codable, Equatable, Hashable, Sendable {
    /// Universal Time Julian Date (`JD_UTC`).
    public let jd: Double
    /// Modified Julian Date (`JD - 2400000.5`).
    public let mjd: Double
    /// Terrestrial Time offset `DeltaT = TT - UT1` in seconds.
    public let deltaTSeconds: Double
    /// Julian Ephemeris Day (`JDE = JD + DeltaT / 86400`).
    public let jde: Double
    /// Julian centuries from J2000.0 in UT (`(JD - 2451545.0) / 36525.0`).
    public let julianCenturiesUT: Double
    /// Julian centuries from J2000.0 in Dynamical/Terrestrial Time (`(JDE - 2451545.0) / 36525.0`).
    public let julianCenturiesTT: Double

    public init(jdUTC: Double, customDeltaTSeconds: Double? = nil) {
        self.jd = jdUTC
        self.mjd = jdUTC - EphemerisConstants.modifiedJulianDateOffset
        let civil = CivilDateTime.fromJulianDate(jdUTC)
        let dt = customDeltaTSeconds ?? Self.estimateDeltaTSeconds(decimalYear: civil.decimalYearApprox)
        self.deltaTSeconds = dt
        let jdeVal = jdUTC + (dt / EphemerisConstants.secondsPerDay)
        self.jde = jdeVal
        self.julianCenturiesUT = (jdUTC - EphemerisConstants.j2000JulianDate) / EphemerisConstants.julianCenturyDays
        self.julianCenturiesTT = (jdeVal - EphemerisConstants.j2000JulianDate) / EphemerisConstants.julianCenturyDays
    }

    public init(civil: CivilDateTime, customDeltaTSeconds: Double? = nil) {
        self.init(jdUTC: civil.toJulianDate(), customDeltaTSeconds: customDeltaTSeconds)
    }

    public init(utcDate: Date, customDeltaTSeconds: Double? = nil) {
        let jd = EphemerisConstants.unixEpochJulianDate
            + (utcDate.timeIntervalSince1970 / EphemerisConstants.secondsPerDay)
        self.init(jdUTC: jd, customDeltaTSeconds: customDeltaTSeconds)
    }

    public var unixTimestamp: TimeInterval {
        (jd - EphemerisConstants.unixEpochJulianDate) * EphemerisConstants.secondsPerDay
    }

    /// NASA Espenak & Meeus polynomial approximation for `DeltaT = TT - UT` in seconds.
    public static func estimateDeltaTSeconds(decimalYear y: Double) -> Double {
        if y >= 2005.0 && y <= 2050.0 {
            let t = y - 2000.0
            return 62.92 + 0.32217 * t + 0.005589 * t * t
        } else if y > 2050.0 && y <= 2150.0 {
            let u = (y - 1820.0) / 100.0
            return -20.0 + 32.0 * u * u - 0.5628 * (2150.0 - y)
        } else if y >= 1986.0 && y < 2005.0 {
            let t = y - 2000.0
            return 63.86 + 0.3345 * t
                - 0.060374 * t * t
                + 0.0017275 * t * t * t
                + 0.000651814 * pow(t, 4)
                + 0.00002373599 * pow(t, 5)
        } else if y >= 1961.0 && y < 1986.0 {
            let t = y - 1975.0
            return 45.45 + 1.067 * t - (t * t / 260.0) - (t * t * t / 718.0)
        } else if y >= 1900.0 && y < 1961.0 {
            let t = (y - 1900.0) / 100.0
            return -2.79 + 149.4119 * t - 59.8939 * t * t + 61.966 * t * t * t
        } else {
            let u = (y - 1820.0) / 100.0
            return -20.0 + 32.0 * u * u
        }
    }
}

// MARK: - Earth Orientation: Sidereal Time, Obliquity & Nutation

public struct NutationState: Codable, Equatable, Hashable, Sendable {
    /// Mean obliquity of the ecliptic `epsilon_0` in degrees.
    public let meanObliquityDeg: Double
    /// Nutation in ecliptic longitude `Delta psi` in arcseconds.
    public let nutationLongitudeArcsec: Double
    /// Nutation in obliquity `Delta epsilon` in arcseconds.
    public let nutationObliquityArcsec: Double
    /// True obliquity `epsilon = epsilon_0 + Delta epsilon` in degrees.
    public let trueObliquityDeg: Double
    /// Equation of the equinoxes `Delta psi * cos(epsilon)` in degrees.
    public let equationOfEquinoxesDeg: Double

    public init(
        meanObliquityDeg: Double,
        nutationLongitudeArcsec: Double,
        nutationObliquityArcsec: Double,
        trueObliquityDeg: Double,
        equationOfEquinoxesDeg: Double
    ) {
        self.meanObliquityDeg = meanObliquityDeg
        self.nutationLongitudeArcsec = nutationLongitudeArcsec
        self.nutationObliquityArcsec = nutationObliquityArcsec
        self.trueObliquityDeg = trueObliquityDeg
        self.equationOfEquinoxesDeg = equationOfEquinoxesDeg
    }
}

public enum EarthOrientationModel {
    /// Greenwich Mean Sidereal Time (IAU / Meeus) in degrees `[0, 360)`.
    public static func gmstDegrees(for epoch: JulianEpoch) -> Double {
        let d = epoch.jd - EphemerisConstants.j2000JulianDate
        let t = epoch.julianCenturiesUT
        let theta = 280.460_618_37
            + 360.985_647_366_29 * d
            + 0.000_387_933 * t * t
            - (t * t * t) / 38_710_000.0
        return EphemerisConstants.normalizeDegrees360(theta)
    }

    public static func gmstHours(for epoch: JulianEpoch) -> Double {
        gmstDegrees(for: epoch) / 15.0
    }

    /// Greenwich Apparent Sidereal Time (`GMST + Equation of Equinoxes`) in degrees `[0, 360)`.
    public static func gastDegrees(for epoch: JulianEpoch) -> Double {
        let nut = nutationAndObliquity(for: epoch)
        return EphemerisConstants.normalizeDegrees360(gmstDegrees(for: epoch) + nut.equationOfEquinoxesDeg)
    }

    /// Local Mean Sidereal Time in degrees `[0, 360)` for East-positive observer longitude.
    public static func lmstDegrees(for epoch: JulianEpoch, eastLongitudeDeg: Double) -> Double {
        EphemerisConstants.normalizeDegrees360(gmstDegrees(for: epoch) + eastLongitudeDeg)
    }

    /// Local Apparent Sidereal Time in degrees `[0, 360)` for East-positive observer longitude.
    public static func lastDegrees(for epoch: JulianEpoch, eastLongitudeDeg: Double) -> Double {
        EphemerisConstants.normalizeDegrees360(gastDegrees(for: epoch) + eastLongitudeDeg)
    }

    /// IAU 2006 / Laskar mean obliquity + 10-term lunar-solar nutation model (`< 0.5"` precision).
    public static func nutationAndObliquity(for epoch: JulianEpoch) -> NutationState {
        let t = epoch.julianCenturiesTT
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t
        let t5 = t4 * t

        // IAU 2006 mean obliquity in arcseconds
        let eps0Arcsec = 84_381.406
            - 46.836_769 * t
            - 0.000_183_1 * t2
            + 0.002_003_40 * t3
            - 0.000_000_576 * t4
            - 0.000_000_043_4 * t5
        let meanObliqDeg = eps0Arcsec * EphemerisConstants.arcsecToDeg

        // Fundamental Delaunay & mean longitude arguments (degrees)
        let dElong = EphemerisConstants.normalizeDegrees360(
            297.85036 + 445_267.111480 * t - 0.0019142 * t2 + t3 / 189_474.0
        )
        let mSun = EphemerisConstants.normalizeDegrees360(
            357.52772 + 35_999.050340 * t - 0.0001603 * t2 - t3 / 300_000.0
        )
        let mMoon = EphemerisConstants.normalizeDegrees360(
            134.96298 + 477_198.867398 * t + 0.0086972 * t2 + t3 / 56_250.0
        )
        let fArg = EphemerisConstants.normalizeDegrees360(
            93.27191 + 483_202.017538 * t - 0.0036825 * t2 + t3 / 327_270.0
        )
        let omega = EphemerisConstants.normalizeDegrees360(
            125.04452 - 1_934.136261 * t + 0.0020708 * t2 + t3 / 450_000.0
        )
        let lSun = EphemerisConstants.normalizeDegrees360(280.4665 + 36_000.7698 * t)
        let lMoon = EphemerisConstants.normalizeDegrees360(218.3165 + 481_267.8813 * t)

        let deg = EphemerisConstants.degToRad
        let omRad = omega * deg
        let twoLSun = 2.0 * lSun * deg
        let twoLMoon = 2.0 * lMoon * deg
        let twoOmega = 2.0 * omega * deg
        let mSunRad = mSun * deg
        let mMoonRad = mMoon * deg
        let twoFMinusTwoDPlusTwoOm = (2.0 * fArg - 2.0 * dElong + 2.0 * omega) * deg
        let twoFPlusTwoOm = (2.0 * fArg + 2.0 * omega) * deg

        // Nutation in longitude Delta_psi (arcseconds)
        let dPsiArcsec = (-17.1996 - 0.01742 * t) * sin(omRad)
            + (-1.3187 - 0.00016 * t) * sin(twoFMinusTwoDPlusTwoOm)
            + (-0.2274 - 0.00002 * t) * sin(twoFPlusTwoOm)
            + (0.2062 + 0.00002 * t) * sin(twoOmega)
            + (0.1426 - 0.00034 * t) * sin(mSunRad)
            + (0.0712 + 0.00001 * t) * sin(mMoonRad)
            - 0.0517 * sin(twoLSun + mSunRad)
            - 0.0386 * sin(twoLMoon - omRad)
            - 0.0301 * sin(twoLMoon + mMoonRad)
            + 0.0217 * sin(twoLSun - mSunRad)

        // Nutation in obliquity Delta_epsilon (arcseconds)
        let dEpsArcsec = (9.2025 + 0.00089 * t) * cos(omRad)
            + (0.5736 - 0.00031 * t) * cos(twoFMinusTwoDPlusTwoOm)
            + (0.0977 - 0.00005 * t) * cos(twoFPlusTwoOm)
            + (-0.0895 + 0.00005 * t) * cos(twoOmega)
            + 0.0054 * cos(mSunRad)
            - 0.0007 * cos(mMoonRad)
            + 0.0224 * cos(twoLSun + mSunRad)
            + 0.0200 * cos(twoLMoon - omRad)
            + 0.0129 * cos(twoLMoon + mMoonRad)
            - 0.0095 * cos(twoLSun - mSunRad)

        let trueObliqDeg = meanObliqDeg + (dEpsArcsec * EphemerisConstants.arcsecToDeg)
        let eqEquinoxDeg = (dPsiArcsec * EphemerisConstants.arcsecToDeg) * cos(trueObliqDeg * deg)

        return NutationState(
            meanObliquityDeg: meanObliqDeg,
            nutationLongitudeArcsec: dPsiArcsec,
            nutationObliquityArcsec: dEpsArcsec,
            trueObliquityDeg: trueObliqDeg,
            equationOfEquinoxesDeg: eqEquinoxDeg
        )
    }
}

// MARK: - Kepler's Equation Solver (Elliptic, Parabolic & Hyperbolic)

public enum OrbitRegime: String, Codable, Equatable, Hashable, Sendable {
    case circular
    case elliptic
    case nearParabolic
    case hyperbolic
}

public struct KeplerSolution: Codable, Equatable, Hashable, Sendable {
    public let regime: OrbitRegime
    public let meanAnomalyRad: Double
    /// Eccentric anomaly `E` (elliptic), Barker parameter `W` (parabolic), or hyperbolic anomaly `H`.
    public let eccentricOrHyperbolicAnomalyRad: Double
    /// True anomaly `nu` in radians `(-pi, pi]`.
    public let trueAnomalyRad: Double
    /// True anomaly `nu` normalized to `[0, 360)` degrees.
    public let trueAnomalyDeg: Double
    /// Heliocentric radius vector `r` in Astronomical Units (AU).
    public let radiusAU: Double
    public let iterationsUsed: Int
    public let residualRad: Double

    public init(
        regime: OrbitRegime,
        meanAnomalyRad: Double,
        eccentricOrHyperbolicAnomalyRad: Double,
        trueAnomalyRad: Double,
        trueAnomalyDeg: Double,
        radiusAU: Double,
        iterationsUsed: Int,
        residualRad: Double
    ) {
        self.regime = regime
        self.meanAnomalyRad = meanAnomalyRad
        self.eccentricOrHyperbolicAnomalyRad = eccentricOrHyperbolicAnomalyRad
        self.trueAnomalyRad = trueAnomalyRad
        self.trueAnomalyDeg = trueAnomalyDeg
        self.radiusAU = radiusAU
        self.iterationsUsed = iterationsUsed
        self.residualRad = residualRad
    }
}

public enum KeplerSolver {
    public static let defaultToleranceRad: Double = 1.0e-12
    public static let maxIterations: Int = 64

    /// Solves Kepler's equation for circular (`e == 0`), elliptic (`0 < e < 1 - 1e-9`),
    /// near-parabolic (`|e - 1| <= 1e-9`), and hyperbolic (`e > 1 + 1e-9`) trajectories.
    public static func solve(
        meanAnomalyRad rawMeanAnomaly: Double,
        eccentricity e: Double,
        semiMajorAxisAU a: Double = 1.0,
        toleranceRad: Double = defaultToleranceRad
    ) throws -> KeplerSolution {
        guard e.isFinite && e >= 0.0 else {
            throw EphemerisMathError.invalidEccentricity(e)
        }
        guard a.isFinite && abs(a) > 0.0 else {
            throw EphemerisMathError.invalidSemiMajorAxis(a)
        }

        if e < 1.0e-14 {
            let mNorm = EphemerisConstants.normalizeRadiansSignedPi(rawMeanAnomaly)
            return KeplerSolution(
                regime: .circular,
                meanAnomalyRad: mNorm,
                eccentricOrHyperbolicAnomalyRad: mNorm,
                trueAnomalyRad: mNorm,
                trueAnomalyDeg: EphemerisConstants.normalizeDegrees360(mNorm * EphemerisConstants.radToDeg),
                radiusAU: abs(a),
                iterationsUsed: 0,
                residualRad: 0.0
            )
        }

        if abs(e - 1.0) <= 1.0e-9 {
            return solveNearParabolic(meanAnomalyRad: rawMeanAnomaly, perihelionDistanceAU: abs(a))
        }

        if e < 1.0 {
            return try solveElliptic(
                meanAnomalyRad: rawMeanAnomaly,
                eccentricity: e,
                semiMajorAxisAU: abs(a),
                toleranceRad: toleranceRad
            )
        } else {
            return try solveHyperbolic(
                meanAnomalyRad: rawMeanAnomaly,
                eccentricity: e,
                semiMajorAxisAU: abs(a),
                toleranceRad: toleranceRad
            )
        }
    }

    public static func solveDegrees(
        meanAnomalyDeg: Double,
        eccentricity: Double,
        semiMajorAxisAU: Double = 1.0,
        toleranceRad: Double = defaultToleranceRad
    ) throws -> KeplerSolution {
        try solve(
            meanAnomalyRad: meanAnomalyDeg * EphemerisConstants.degToRad,
            eccentricity: eccentricity,
            semiMajorAxisAU: semiMajorAxisAU,
            toleranceRad: toleranceRad
        )
    }

    private static func solveElliptic(
        meanAnomalyRad rawM: Double,
        eccentricity e: Double,
        semiMajorAxisAU a: Double,
        toleranceRad: Double
    ) throws -> KeplerSolution {
        let m = EphemerisConstants.normalizeRadiansSignedPi(rawM)

        // Danby high-eccentricity starter guarantees global convergence even as e -> 0.999999
        var eccAnomaly: Double
        if e > 0.8 {
            let signM: Double = (sin(m) >= 0.0) ? 1.0 : -1.0
            eccAnomaly = m + 0.85 * e * signM
        } else {
            eccAnomaly = m + e * sin(m) * (1.0 + e * cos(m))
        }

        var iter = 0
        var residual = Double.greatestFiniteMagnitude

        while iter < maxIterations {
            iter += 1
            let sinE = sin(eccAnomaly)
            let cosE = cos(eccAnomaly)
            let f = eccAnomaly - e * sinE - m
            residual = abs(f)
            if residual <= toleranceRad {
                break
            }
            let fPrime = max(1.0e-15, 1.0 - e * cosE)
            let fDoublePrime = e * sinE
            // Halley's third-order step with Newton safeguard
            let denom = fPrime - (0.5 * f * fDoublePrime / fPrime)
            let step = (abs(denom) > 1.0e-15) ? (f / denom) : (f / fPrime)
            eccAnomaly -= step
            if abs(step) <= toleranceRad {
                residual = abs(eccAnomaly - e * sin(eccAnomaly) - m)
                break
            }
        }

        guard residual <= max(toleranceRad * 100.0, 1.0e-10) else {
            throw EphemerisMathError.keplerConvergenceFailure(eccentricity: e, meanAnomalyRad: m)
        }

        let halfE = 0.5 * eccAnomaly
        let nu = 2.0 * atan2(sqrt(1.0 + e) * sin(halfE), sqrt(1.0 - e) * cos(halfE))
        let r = a * (1.0 - e * cos(eccAnomaly))

        return KeplerSolution(
            regime: .elliptic,
            meanAnomalyRad: m,
            eccentricOrHyperbolicAnomalyRad: eccAnomaly,
            trueAnomalyRad: nu,
            trueAnomalyDeg: EphemerisConstants.normalizeDegrees360(nu * EphemerisConstants.radToDeg),
            radiusAU: r,
            iterationsUsed: iter,
            residualRad: residual
        )
    }

    private static func solveHyperbolic(
        meanAnomalyRad m: Double,
        eccentricity e: Double,
        semiMajorAxisAU absA: Double,
        toleranceRad: Double
    ) throws -> KeplerSolution {
        let signM: Double = (m >= 0.0) ? 1.0 : -1.0
        var h = signM * log(2.0 * abs(m) / e + 1.8)
        var iter = 0
        var residual = Double.greatestFiniteMagnitude

        while iter < maxIterations {
            iter += 1
            let sinhH = sinh(h)
            let coshH = cosh(h)
            let f = e * sinhH - h - m
            residual = abs(f)
            if residual <= toleranceRad {
                break
            }
            let fPrime = e * coshH - 1.0
            let fDoublePrime = e * sinhH
            let denom = fPrime - (0.5 * f * fDoublePrime / fPrime)
            let step = f / denom
            h -= step
            if abs(step) <= toleranceRad {
                residual = abs(e * sinh(h) - h - m)
                break
            }
        }

        guard residual <= max(toleranceRad * 1_000.0, 1.0e-9) else {
            throw EphemerisMathError.keplerConvergenceFailure(eccentricity: e, meanAnomalyRad: m)
        }

        let halfH = 0.5 * h
        let nu = 2.0 * atan2(sqrt(e + 1.0) * sinh(halfH), sqrt(e - 1.0) * cosh(halfH))
        let r = absA * (e * cosh(h) - 1.0)

        return KeplerSolution(
            regime: .hyperbolic,
            meanAnomalyRad: m,
            eccentricOrHyperbolicAnomalyRad: h,
            trueAnomalyRad: nu,
            trueAnomalyDeg: EphemerisConstants.normalizeDegrees360(nu * EphemerisConstants.radToDeg),
            radiusAU: r,
            iterationsUsed: iter,
            residualRad: residual
        )
    }

    /// Exact analytic cubic Barker solution for `W + W^3 / 3 = 1.5 * M`.
    private static func solveNearParabolic(
        meanAnomalyRad m: Double,
        perihelionDistanceAU q: Double
    ) -> KeplerSolution {
        let b = 1.5 * m
        let rootTerm = sqrt(1.0 + b * b)
        let y = cbrt(b + rootTerm)
        let w = y - (1.0 / y)
        let nu = 2.0 * atan(w)
        let r = q * (1.0 + w * w)
        return KeplerSolution(
            regime: .nearParabolic,
            meanAnomalyRad: m,
            eccentricOrHyperbolicAnomalyRad: w,
            trueAnomalyRad: nu,
            trueAnomalyDeg: EphemerisConstants.normalizeDegrees360(nu * EphemerisConstants.radToDeg),
            radiusAU: r,
            iterationsUsed: 1,
            residualRad: 0.0
        )
    }
}

// MARK: - 3D Vectors & Astronomical Coordinate Frames

public struct CartesianVector3D: Codable, Equatable, Hashable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }

    public func normalized() -> CartesianVector3D {
        let mag = magnitude
        guard mag > 1.0e-18 else { return CartesianVector3D(x: 0, y: 0, z: 0) }
        return CartesianVector3D(x: x / mag, y: y / mag, z: z / mag)
    }

    public static func + (lhs: CartesianVector3D, rhs: CartesianVector3D) -> CartesianVector3D {
        CartesianVector3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func - (lhs: CartesianVector3D, rhs: CartesianVector3D) -> CartesianVector3D {
        CartesianVector3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public func scaled(by factor: Double) -> CartesianVector3D {
        CartesianVector3D(x: x * factor, y: y * factor, z: z * factor)
    }

    public func dot(_ other: CartesianVector3D) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    public func cross(_ other: CartesianVector3D) -> CartesianVector3D {
        CartesianVector3D(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }
}

public struct HeliocentricStateVector: Codable, Equatable, Hashable, Sendable {
    public let positionAU: CartesianVector3D
    public let velocityAUPerDay: CartesianVector3D

    public init(positionAU: CartesianVector3D, velocityAUPerDay: CartesianVector3D) {
        self.positionAU = positionAU
        self.velocityAUPerDay = velocityAUPerDay
    }
}

public struct EclipticCoordinates: Codable, Equatable, Hashable, Sendable {
    /// Geocentric or heliocentric ecliptic longitude `lambda` in degrees `[0, 360)`.
    public let longitudeDeg: Double
    /// Ecliptic latitude `beta` in degrees `[-90, +90]`.
    public let latitudeDeg: Double
    /// Euclidean distance `Delta` in AU.
    public let distanceAU: Double

    public init(longitudeDeg: Double, latitudeDeg: Double, distanceAU: Double) {
        self.longitudeDeg = EphemerisConstants.normalizeDegrees360(longitudeDeg)
        self.latitudeDeg = max(-90.0, min(90.0, latitudeDeg))
        self.distanceAU = distanceAU
    }
}

public struct EquatorialCoordinates: Codable, Equatable, Hashable, Sendable {
    /// Right Ascension `alpha` in degrees `[0, 360)`.
    public let rightAscensionDeg: Double
    /// Declination `delta` in degrees `[-90, +90]`.
    public let declinationDeg: Double
    /// Geocentric distance `Delta` in AU.
    public let distanceAU: Double

    public init(rightAscensionDeg: Double, declinationDeg: Double, distanceAU: Double) {
        self.rightAscensionDeg = EphemerisConstants.normalizeDegrees360(rightAscensionDeg)
        self.declinationDeg = max(-90.0, min(90.0, declinationDeg))
        self.distanceAU = distanceAU
    }

    public var rightAscensionHours: Double {
        rightAscensionDeg / 15.0
    }

    public var hms: SexagesimalHMS {
        SexagesimalHMS(rightAscensionDegrees: rightAscensionDeg)
    }

    public var dms: SexagesimalDMS {
        SexagesimalDMS(decimalDegrees: declinationDeg)
    }
}

public struct HorizontalCoordinates: Codable, Equatable, Hashable, Sendable {
    /// Topocentric azimuth measured clockwise from True North (`0 deg = N, 90 deg = E, 180 deg = S, 270 deg = W`).
    public let azimuthDeg: Double
    /// Geometric topocentric altitude before atmospheric refraction, in degrees.
    public let trueAltitudeDeg: Double
    /// Apparent topocentric altitude including atmospheric refraction, in degrees.
    public let apparentAltitudeDeg: Double
    /// Applied atmospheric refraction correction in arcminutes.
    public let refractionArcmin: Double
    /// Local hour angle `H` in degrees `[-180, +180]`.
    public let localHourAngleDeg: Double
    /// Kasten-Young optical airmass `X` (nil when below horizon).
    public let opticalAirmass: Double?

    public init(
        azimuthDeg: Double,
        trueAltitudeDeg: Double,
        apparentAltitudeDeg: Double,
        refractionArcmin: Double,
        localHourAngleDeg: Double,
        opticalAirmass: Double?
    ) {
        self.azimuthDeg = EphemerisConstants.normalizeDegrees360(azimuthDeg)
        self.trueAltitudeDeg = trueAltitudeDeg
        self.apparentAltitudeDeg = apparentAltitudeDeg
        self.refractionArcmin = refractionArcmin
        self.localHourAngleDeg = localHourAngleDeg
        self.opticalAirmass = opticalAirmass
    }

    public var isAboveApparentHorizon: Bool {
        apparentAltitudeDeg >= 0.0
    }
}

public struct GeodeticObserver: Codable, Equatable, Hashable, Sendable {
    public let latitudeDeg: Double
    public let longitudeDeg: Double
    public let elevationMeters: Double
    public let pressureHPa: Double
    public let temperatureCelsius: Double

    public init(
        latitudeDeg: Double,
        longitudeDeg: Double,
        elevationMeters: Double = 0.0,
        pressureHPa: Double = 1_013.25,
        temperatureCelsius: Double = 15.0
    ) throws {
        guard (-90.0...90.0).contains(latitudeDeg) else {
            throw EphemerisMathError.invalidObserverLatitude(latitudeDeg)
        }
        guard (-180.0...180.0).contains(longitudeDeg) else {
            throw EphemerisMathError.invalidObserverLongitude(longitudeDeg)
        }
        self.latitudeDeg = latitudeDeg
        self.longitudeDeg = longitudeDeg
        self.elevationMeters = elevationMeters
        self.pressureHPa = pressureHPa
        self.temperatureCelsius = temperatureCelsius
    }

    public static let greenwichPrimeMeridian = try! GeodeticObserver(
        latitudeDeg: 51.4769,
        longitudeDeg: 0.0,
        elevationMeters: 46.0
    )

    /// WGS-84 geocentric auxiliary quantities `(rho * sin(phi'), rho * cos(phi'))` in Earth equatorial radii.
    public func geocentricParallaxFactors() -> (rhoSinPhiPrime: Double, rhoCosPhiPrime: Double) {
        let phi = latitudeDeg * EphemerisConstants.degToRad
        let bOverA = 1.0 - EphemerisConstants.wgs84Flattening
        let u = atan(bOverA * tan(phi))
        let hRatio = (elevationMeters / 1_000.0) / EphemerisConstants.wgs84EquatorialRadiusKm
        let rhoSin = bOverA * sin(u) + hRatio * sin(phi)
        let rhoCos = cos(u) + hRatio * cos(phi)
        return (rhoSin, rhoCos)
    }
}

// MARK: - Full Coordinate Transformation Pipeline

public enum EphemerisCoordinateTransformer {
    /// Rotates perifocal orbital coordinates into 3D heliocentric J2000 ecliptic position & velocity.
    public static func orbitalPlaneToHeliocentricEcliptic(
        semiMajorAxisAU a: Double,
        eccentricity e: Double,
        inclinationDeg iDeg: Double,
        longitudeAscendingNodeDeg omegaNodeDeg: Double,
        argumentOfPerihelionDeg argPeriDeg: Double,
        kepler: KeplerSolution
    ) -> HeliocentricStateVector {
        let deg = EphemerisConstants.degToRad
        let inc = iDeg * deg
        let bigOmega = omegaNodeDeg * deg
        let smallOmega = argPeriDeg * deg

        let cosO = cos(bigOmega)
        let sinO = sin(bigOmega)
        let cosW = cos(smallOmega)
        let sinW = sin(smallOmega)
        let cosI = cos(inc)
        let sinI = sin(inc)

        // Gauss unit vectors P and Q
        let px = cosO * cosW - sinO * sinW * cosI
        let py = sinO * cosW + cosO * sinW * cosI
        let pz = sinW * sinI

        let qx = -cosO * sinW - sinO * cosW * cosI
        let qy = -sinO * sinW + cosO * cosW * cosI
        let qz = cosW * sinI

        let xOrb = kepler.radiusAU * cos(kepler.trueAnomalyRad)
        let yOrb = kepler.radiusAU * sin(kepler.trueAnomalyRad)

        let pos = CartesianVector3D(
            x: px * xOrb + qx * yOrb,
            y: py * xOrb + qy * yOrb,
            z: pz * xOrb + qz * yOrb
        )

        // Perifocal velocity (AU/day) for elliptic/circular orbits
        let pSemiLatus = max(1.0e-12, abs(a) * abs(1.0 - e * e))
        let speedScale = sqrt(EphemerisConstants.heliocentricMuAU3PerDay2 / pSemiLatus)
        let vxOrb = -speedScale * sin(kepler.trueAnomalyRad)
        let vyOrb = speedScale * (e + cos(kepler.trueAnomalyRad))

        let vel = CartesianVector3D(
            x: px * vxOrb + qx * vyOrb,
            y: py * vxOrb + qy * vyOrb,
            z: pz * vxOrb + qz * vyOrb
        )

        return HeliocentricStateVector(positionAU: pos, velocityAUPerDay: vel)
    }

    /// Converts heliocentric body & Earth Cartesian positions into geocentric spherical ecliptic `(lambda, beta, Delta)`.
    public static func heliocentricToGeocentricEcliptic(
        bodyHeliocentricAU: CartesianVector3D,
        earthHeliocentricAU: CartesianVector3D
    ) -> EclipticCoordinates {
        let geo = bodyHeliocentricAU - earthHeliocentricAU
        return cartesianToSphericalEcliptic(geo)
    }

    public static func cartesianToSphericalEcliptic(_ vectorAU: CartesianVector3D) -> EclipticCoordinates {
        let dist = vectorAU.magnitude
        guard dist > 1.0e-15 else {
            return EclipticCoordinates(longitudeDeg: 0.0, latitudeDeg: 0.0, distanceAU: 0.0)
        }
        let lon = atan2(vectorAU.y, vectorAU.x) * EphemerisConstants.radToDeg
        let xy = sqrt(vectorAU.x * vectorAU.x + vectorAU.y * vectorAU.y)
        let lat = atan2(vectorAU.z, xy) * EphemerisConstants.radToDeg
        return EclipticCoordinates(longitudeDeg: lon, latitudeDeg: lat, distanceAU: dist)
    }

    /// Transforms geocentric ecliptic `(lambda, beta)` into apparent geocentric equatorial `(alpha, delta)`
    /// applying nutation in longitude `Delta psi` and true obliquity `epsilon`.
    public static func eclipticToApparentEquatorial(
        ecliptic: EclipticCoordinates,
        epoch: JulianEpoch,
        applyNutation: Bool = true
    ) -> EquatorialCoordinates {
        let nut = EarthOrientationModel.nutationAndObliquity(for: epoch)
        let epsRad = (applyNutation ? nut.trueObliquityDeg : nut.meanObliquityDeg) * EphemerisConstants.degToRad
        let nutLonDeg = applyNutation ? (nut.nutationLongitudeArcsec * EphemerisConstants.arcsecToDeg) : 0.0

        let lam = (ecliptic.longitudeDeg + nutLonDeg) * EphemerisConstants.degToRad
        let bet = ecliptic.latitudeDeg * EphemerisConstants.degToRad

        let sinLam = sin(lam)
        let cosLam = cos(lam)
        let sinBet = sin(bet)
        let cosBet = cos(bet)
        let sinEps = sin(epsRad)
        let cosEps = cos(epsRad)

        let y = sinLam * cosEps - tan(bet) * sinEps
        let raRad = atan2(y * cosBet, cosLam * cosBet)
        let sinDec = sinBet * cosEps + cosBet * sinEps * sinLam
        let decRad = asin(max(-1.0, min(1.0, sinDec)))

        return EquatorialCoordinates(
            rightAscensionDeg: raRad * EphemerisConstants.radToDeg,
            declinationDeg: decRad * EphemerisConstants.radToDeg,
            distanceAU: ecliptic.distanceAU
        )
    }

    /// Transforms apparent geocentric equatorial `(alpha, delta, Delta)` to topocentric horizontal `(Az, Alt)`
    /// including WGS-84 diurnal parallax, Saemundsson atmospheric refraction, and Kasten-Young airmass.
    public static func equatorialToTopocentricHorizontal(
        equatorial: EquatorialCoordinates,
        epoch: JulianEpoch,
        observer: GeodeticObserver,
        applyRefraction: Bool = true
    ) -> HorizontalCoordinates {
        let deg = EphemerisConstants.degToRad
        let rad = EphemerisConstants.radToDeg

        let lastDeg = EarthOrientationModel.lastDegrees(for: epoch, eastLongitudeDeg: observer.longitudeDeg)
        let geocentricHADeg = EphemerisConstants.normalizeDegreesSigned180(lastDeg - equatorial.rightAscensionDeg)
        let hGeo = geocentricHADeg * deg
        let decGeo = equatorial.declinationDeg * deg

        // Rigorous Meeus Chapter 40 topocentric parallax correction
        let sinPi: Double
        if equatorial.distanceAU > 1.0e-9 {
            sinPi = (EphemerisConstants.wgs84EquatorialRadiusKm / EphemerisConstants.astronomicalUnitKm)
                / equatorial.distanceAU
        } else {
            sinPi = 0.0
        }

        let (rhoSinPhiP, rhoCosPhiP) = observer.geocentricParallaxFactors()
        let denom = cos(decGeo) - rhoCosPhiP * sinPi * cos(hGeo)
        let deltaRA = atan2(-rhoCosPhiP * sinPi * sin(hGeo), denom)
        let topocentricH = hGeo - deltaRA
        let topocentricDec = atan2(
            (sin(decGeo) - rhoSinPhiP * sinPi) * cos(deltaRA),
            denom
        )

        let phi = observer.latitudeDeg * deg
        let sinAlt = sin(phi) * sin(topocentricDec) + cos(phi) * cos(topocentricDec) * cos(topocentricH)
        let trueAltDeg = asin(max(-1.0, min(1.0, sinAlt))) * rad

        // Azimuth measured North=0, East=90
        let azY = -sin(topocentricH) * cos(topocentricDec)
        let azX = cos(phi) * sin(topocentricDec) - sin(phi) * cos(topocentricDec) * cos(topocentricH)
        let azimuthDeg = EphemerisConstants.normalizeDegrees360(atan2(azY, azX) * rad)

        let refractionArcmin: Double
        if applyRefraction && observer.pressureHPa > 0.0 {
            refractionArcmin = atmosphericRefractionArcmin(
                trueAltitudeDeg: trueAltDeg,
                pressureHPa: observer.pressureHPa,
                temperatureCelsius: observer.temperatureCelsius
            )
        } else {
            refractionArcmin = 0.0
        }

        let apparentAltDeg = min(90.0, trueAltDeg + (refractionArcmin / 60.0))
        let airmass = computeKastenYoungAirmass(apparentAltitudeDeg: apparentAltDeg)

        return HorizontalCoordinates(
            azimuthDeg: azimuthDeg,
            trueAltitudeDeg: trueAltDeg,
            apparentAltitudeDeg: apparentAltDeg,
            refractionArcmin: refractionArcmin,
            localHourAngleDeg: EphemerisConstants.normalizeDegreesSigned180(topocentricH * rad),
            opticalAirmass: airmass
        )
    }

    /// Saemundsson (1986) / Meeus atmospheric refraction in arcminutes from true altitude `h_0`.
    public static func atmosphericRefractionArcmin(
        trueAltitudeDeg h0: Double,
        pressureHPa: Double = 1_013.25,
        temperatureCelsius: Double = 15.0
    ) -> Double {
        guard h0 >= -1.5 else { return 0.0 }
        let angleArg = (h0 + (10.3 / (h0 + 5.11))) * EphemerisConstants.degToRad
        let baseRefraction = 1.02 / tan(angleArg)
        let metFactor = (pressureHPa / 1_010.0) * (283.0 / max(150.0, 273.0 + temperatureCelsius))
        return max(0.0, baseRefraction * metFactor)
    }

    /// Kasten & Young (1989) optical airmass valid down to the horizon (`X ~ 38` at `Alt = 0 deg`).
    public static func computeKastenYoungAirmass(apparentAltitudeDeg alt: Double) -> Double? {
        guard alt >= 0.0 else { return nil }
        let zenithDeg = 90.0 - alt
        let denom = sin(alt * EphemerisConstants.degToRad)
            + 0.50572 * pow(96.07995 - zenithDeg, -1.6364)
        guard denom > 1.0e-9 else { return nil }
        return 1.0 / denom
    }

    /// Exact spherical angular separation in degrees `[0, 180]` using Vincenty's arctan formula
    /// (numerically stable for both tiny arcsecond conjunctions and antipodal oppositions).
    public static func angularSeparationDegrees(
        ra1Deg: Double,
        dec1Deg: Double,
        ra2Deg: Double,
        dec2Deg: Double
    ) -> Double {
        let deg = EphemerisConstants.degToRad
        let phi1 = dec1Deg * deg
        let phi2 = dec2Deg * deg
        let dLam = (ra2Deg - ra1Deg) * deg

        let sinPhi1 = sin(phi1)
        let cosPhi1 = cos(phi1)
        let sinPhi2 = sin(phi2)
        let cosPhi2 = cos(phi2)
        let sinDL = sin(dLam)
        let cosDL = cos(dLam)

        let t1 = cosPhi2 * sinDL
        let t2 = cosPhi1 * sinPhi2 - sinPhi1 * cosPhi2 * cosDL
        let numerator = sqrt(t1 * t1 + t2 * t2)
        let denominator = sinPhi1 * sinPhi2 + cosPhi1 * cosPhi2 * cosDL
        return atan2(numerator, denominator) * EphemerisConstants.radToDeg
    }
}
