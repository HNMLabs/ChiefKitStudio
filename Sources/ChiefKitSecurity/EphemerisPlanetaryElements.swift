import ChiefKitStudioCore
import Foundation

// MARK: - Celestial Bodies & JPL J2000.0 Mean Orbital Elements

public enum CelestialBody: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case sun = "Sun"
    case moon = "Moon"
    case mercury = "Mercury"
    case venus = "Venus"
    case earthMoonBarycenter = "Earth-Moon Barycenter"
    case mars = "Mars"
    case jupiter = "Jupiter"
    case saturn = "Saturn"
    case uranus = "Uranus"
    case neptune = "Neptune"

    public var astronomicalSymbol: String {
        switch self {
        case .sun: return "☉"
        case .moon: return "☽"
        case .mercury: return "☿"
        case .venus: return "♀"
        case .earthMoonBarycenter: return "⊕"
        case .mars: return "♂"
        case .jupiter: return "♃"
        case .saturn: return "♄"
        case .uranus: return "♅"
        case .neptune: return "♆"
        }
    }

    public static let geocentricSkyBodies: [CelestialBody] = [
        .sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune
    ]
}

/// Standish / JPL Solar System Dynamics J2000.0 Keplerian elements and secular century rates
/// (`1800 AD - 2050 AD` fit + outer-planet quadratic/trigonometric anomaly terms `b, c, s, f`).
public struct JPLMeanOrbitalElements: Codable, Equatable, Hashable, Sendable {
    public let body: CelestialBody
    /// Semi-major axis `a_0` (AU) and rate `da/dT` (AU / Julian century).
    public let a0AU: Double
    public let aRateAUPerCentury: Double
    /// Eccentricity `e_0` and rate `de/dT` (1 / Julian century).
    public let e0: Double
    public let eRatePerCentury: Double
    /// Inclination `I_0` (deg) and rate `dI/dT` (deg / Julian century).
    public let i0Deg: Double
    public let iRateDegPerCentury: Double
    /// Mean longitude `L_0` (deg) and rate `dL/dT` (deg / Julian century).
    public let meanLongitude0Deg: Double
    public let meanLongitudeRateDegPerCentury: Double
    /// Longitude of perihelion `varpi_0` (deg) and rate `d(varpi)/dT` (deg / Julian century).
    public let perihelionLongitude0Deg: Double
    public let perihelionLongitudeRateDegPerCentury: Double
    /// Longitude of ascending node `Omega_0` (deg) and rate `d(Omega)/dT` (deg / Julian century).
    public let ascendingNode0Deg: Double
    public let ascendingNodeRateDegPerCentury: Double
    /// Standish outer-planet mean-anomaly refinement coefficients (`b * T^2 + c * cos(f*T) + s * sin(f*T)`).
    public let bQuadDeg: Double
    public let cCosDeg: Double
    public let sSinDeg: Double
    public let fFreqDegPerCentury: Double

    public init(
        body: CelestialBody,
        a0AU: Double,
        aRateAUPerCentury: Double,
        e0: Double,
        eRatePerCentury: Double,
        i0Deg: Double,
        iRateDegPerCentury: Double,
        meanLongitude0Deg: Double,
        meanLongitudeRateDegPerCentury: Double,
        perihelionLongitude0Deg: Double,
        perihelionLongitudeRateDegPerCentury: Double,
        ascendingNode0Deg: Double,
        ascendingNodeRateDegPerCentury: Double,
        bQuadDeg: Double = 0.0,
        cCosDeg: Double = 0.0,
        sSinDeg: Double = 0.0,
        fFreqDegPerCentury: Double = 0.0
    ) {
        self.body = body
        self.a0AU = a0AU
        self.aRateAUPerCentury = aRateAUPerCentury
        self.e0 = e0
        self.eRatePerCentury = eRatePerCentury
        self.i0Deg = i0Deg
        self.iRateDegPerCentury = iRateDegPerCentury
        self.meanLongitude0Deg = meanLongitude0Deg
        self.meanLongitudeRateDegPerCentury = meanLongitudeRateDegPerCentury
        self.perihelionLongitude0Deg = perihelionLongitude0Deg
        self.perihelionLongitudeRateDegPerCentury = perihelionLongitudeRateDegPerCentury
        self.ascendingNode0Deg = ascendingNode0Deg
        self.ascendingNodeRateDegPerCentury = ascendingNodeRateDegPerCentury
        self.bQuadDeg = bQuadDeg
        self.cCosDeg = cCosDeg
        self.sSinDeg = sSinDeg
        self.fFreqDegPerCentury = fFreqDegPerCentury
    }

    public static func catalogElements(for body: CelestialBody) -> JPLMeanOrbitalElements? {
        switch body {
        case .mercury:
            return JPLMeanOrbitalElements(
                body: .mercury,
                a0AU: 0.387_099_27, aRateAUPerCentury: +0.000_000_37,
                e0: 0.205_635_93, eRatePerCentury: +0.000_019_06,
                i0Deg: 7.004_979_02, iRateDegPerCentury: -0.005_947_49,
                meanLongitude0Deg: 252.250_323_50, meanLongitudeRateDegPerCentury: 149_472.674_111_75,
                perihelionLongitude0Deg: 77.457_796_28, perihelionLongitudeRateDegPerCentury: +0.160_476_89,
                ascendingNode0Deg: 48.330_765_93, ascendingNodeRateDegPerCentury: -0.125_340_81
            )
        case .venus:
            return JPLMeanOrbitalElements(
                body: .venus,
                a0AU: 0.723_335_66, aRateAUPerCentury: +0.000_003_90,
                e0: 0.006_776_72, eRatePerCentury: -0.000_041_07,
                i0Deg: 3.394_676_05, iRateDegPerCentury: -0.000_788_90,
                meanLongitude0Deg: 181.979_099_50, meanLongitudeRateDegPerCentury: 58_517.815_387_29,
                perihelionLongitude0Deg: 131.602_467_18, perihelionLongitudeRateDegPerCentury: +0.002_683_29,
                ascendingNode0Deg: 76.679_842_55, ascendingNodeRateDegPerCentury: -0.277_694_18
            )
        case .earthMoonBarycenter:
            return JPLMeanOrbitalElements(
                body: .earthMoonBarycenter,
                a0AU: 1.000_002_61, aRateAUPerCentury: +0.000_005_62,
                e0: 0.016_711_23, eRatePerCentury: -0.000_043_92,
                i0Deg: -0.000_015_31, iRateDegPerCentury: -0.012_946_68,
                meanLongitude0Deg: 100.464_571_66, meanLongitudeRateDegPerCentury: 35_999.372_449_81,
                perihelionLongitude0Deg: 102.937_681_93, perihelionLongitudeRateDegPerCentury: +0.323_273_64,
                ascendingNode0Deg: 0.0, ascendingNodeRateDegPerCentury: 0.0
            )
        case .mars:
            return JPLMeanOrbitalElements(
                body: .mars,
                a0AU: 1.523_710_34, aRateAUPerCentury: +0.000_018_47,
                e0: 0.093_394_10, eRatePerCentury: +0.000_078_82,
                i0Deg: 1.849_691_42, iRateDegPerCentury: -0.008_131_31,
                meanLongitude0Deg: -4.553_432_05, meanLongitudeRateDegPerCentury: 19_140.302_684_99,
                perihelionLongitude0Deg: -23.943_629_59, perihelionLongitudeRateDegPerCentury: +0.444_410_88,
                ascendingNode0Deg: 49.559_538_91, ascendingNodeRateDegPerCentury: -0.292_573_43
            )
        case .jupiter:
            return JPLMeanOrbitalElements(
                body: .jupiter,
                a0AU: 5.202_887_00, aRateAUPerCentury: -0.000_116_07,
                e0: 0.048_386_24, eRatePerCentury: -0.000_132_53,
                i0Deg: 1.304_396_95, iRateDegPerCentury: -0.001_837_14,
                meanLongitude0Deg: 34.396_440_51, meanLongitudeRateDegPerCentury: 3_034.746_127_75,
                perihelionLongitude0Deg: 14.728_479_83, perihelionLongitudeRateDegPerCentury: +0.212_526_68,
                ascendingNode0Deg: 100.473_909_09, ascendingNodeRateDegPerCentury: +0.204_691_06,
                bQuadDeg: -0.000_124_52, cCosDeg: +0.060_640_60, sSinDeg: -0.356_354_38, fFreqDegPerCentury: 38.351_250_00
            )
        case .saturn:
            return JPLMeanOrbitalElements(
                body: .saturn,
                a0AU: 9.536_675_94, aRateAUPerCentury: -0.001_250_60,
                e0: 0.053_861_79, eRatePerCentury: -0.000_509_91,
                i0Deg: 2.485_991_87, iRateDegPerCentury: +0.001_936_09,
                meanLongitude0Deg: 49.954_244_23, meanLongitudeRateDegPerCentury: 1_222.493_622_01,
                perihelionLongitude0Deg: 92.598_878_31, perihelionLongitudeRateDegPerCentury: -0.418_972_16,
                ascendingNode0Deg: 113.662_424_48, ascendingNodeRateDegPerCentury: -0.288_677_94,
                bQuadDeg: +0.000_258_99, cCosDeg: -0.134_344_69, sSinDeg: +0.873_201_47, fFreqDegPerCentury: 38.351_250_00
            )
        case .uranus:
            return JPLMeanOrbitalElements(
                body: .uranus,
                a0AU: 19.189_164_64, aRateAUPerCentury: -0.001_961_76,
                e0: 0.047_257_44, eRatePerCentury: -0.000_043_97,
                i0Deg: 0.772_637_83, iRateDegPerCentury: -0.002_429_39,
                meanLongitude0Deg: 313.238_104_51, meanLongitudeRateDegPerCentury: 428.482_027_85,
                perihelionLongitude0Deg: 170.954_276_30, perihelionLongitudeRateDegPerCentury: +0.408_052_81,
                ascendingNode0Deg: 74.016_925_03, ascendingNodeRateDegPerCentury: +0.042_405_89,
                bQuadDeg: +0.000_583_31, cCosDeg: -0.977_318_48, sSinDeg: +0.176_892_45, fFreqDegPerCentury: 7.670_250_00
            )
        case .neptune:
            return JPLMeanOrbitalElements(
                body: .neptune,
                a0AU: 30.069_922_76, aRateAUPerCentury: +0.000_262_91,
                e0: 0.008_590_48, eRatePerCentury: +0.000_051_05,
                i0Deg: 1.770_043_47, iRateDegPerCentury: +0.000_353_72,
                meanLongitude0Deg: -55.120_029_69, meanLongitudeRateDegPerCentury: 218.459_453_25,
                perihelionLongitude0Deg: 44.964_762_27, perihelionLongitudeRateDegPerCentury: -0.322_414_64,
                ascendingNode0Deg: 131.784_225_74, ascendingNodeRateDegPerCentury: -0.005_086_64,
                bQuadDeg: -0.000_413_48, cCosDeg: +0.683_463_18, sSinDeg: -0.101_625_47, fFreqDegPerCentury: 7.670_250_00
            )
        case .sun, .moon:
            return nil
        }
    }

    /// Evaluates osculating mean elements and solves heliocentric J2000 ecliptic state at `epoch`.
    public func heliocentricState(at epoch: JulianEpoch) throws -> HeliocentricStateVector {
        let t = epoch.julianCenturiesTT
        let a = a0AU + aRateAUPerCentury * t
        let e = max(0.0, min(0.99, e0 + eRatePerCentury * t))
        let inc = i0Deg + iRateDegPerCentury * t
        let meanLon = meanLongitude0Deg + meanLongitudeRateDegPerCentury * t
        let varpi = perihelionLongitude0Deg + perihelionLongitudeRateDegPerCentury * t
        let omegaNode = ascendingNode0Deg + ascendingNodeRateDegPerCentury * t

        let argPeri = varpi - omegaNode
        let fRad = (fFreqDegPerCentury * t) * EphemerisConstants.degToRad
        let outerPerturbation = bQuadDeg * t * t + cCosDeg * cos(fRad) + sSinDeg * sin(fRad)
        let meanAnomalyDeg = EphemerisConstants.normalizeDegreesSigned180(meanLon - varpi + outerPerturbation)

        let kepler = try KeplerSolver.solveDegrees(
            meanAnomalyDeg: meanAnomalyDeg,
            eccentricity: e,
            semiMajorAxisAU: a
        )

        return EphemerisCoordinateTransformer.orbitalPlaneToHeliocentricEcliptic(
            semiMajorAxisAU: a,
            eccentricity: e,
            inclinationDeg: inc,
            longitudeAscendingNodeDeg: omegaNode,
            argumentOfPerihelionDeg: argPeri,
            kepler: kepler
        )
    }
}

// MARK: - Solar Position, Equation of Time & Sunrise / Twilight Calculator

public enum SolarPolarCondition: String, Codable, Equatable, Hashable, Sendable {
    case normalRiseAndSet
    case midnightSunAboveThreshold
    case polarNightBelowThreshold
}

public struct SolarPositionSummary: Codable, Equatable, Hashable, Sendable {
    public let epoch: JulianEpoch
    public let apparentLongitudeDeg: Double
    public let distanceAU: Double
    public let equatorial: EquatorialCoordinates
    public let horizontal: HorizontalCoordinates
    /// Equation of Time (`Apparent Solar Time - Mean Solar Time`) in minutes.
    public let equationOfTimeMinutes: Double
    public let angularDiameterArcsec: Double

    public init(
        epoch: JulianEpoch,
        apparentLongitudeDeg: Double,
        distanceAU: Double,
        equatorial: EquatorialCoordinates,
        horizontal: HorizontalCoordinates,
        equationOfTimeMinutes: Double,
        angularDiameterArcsec: Double
    ) {
        self.epoch = epoch
        self.apparentLongitudeDeg = apparentLongitudeDeg
        self.distanceAU = distanceAU
        self.equatorial = equatorial
        self.horizontal = horizontal
        self.equationOfTimeMinutes = equationOfTimeMinutes
        self.angularDiameterArcsec = angularDiameterArcsec
    }
}

public struct SolarDayEvents: Codable, Equatable, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let observer: GeodeticObserver
    public let condition: SolarPolarCondition
    public let solarNoonUTC: Date
    public let solarNoonMaxAltitudeDeg: Double
    public let equationOfTimeAtNoonMinutes: Double
    public let sunriseUTC: Date?
    public let sunsetUTC: Date?
    public let daylightDurationHours: Double
    public let civilDawnUTC: Date?
    public let civilDuskUTC: Date?
    public let nauticalDawnUTC: Date?
    public let nauticalDuskUTC: Date?
    public let astronomicalDawnUTC: Date?
    public let astronomicalDuskUTC: Date?
}

public enum SolarEphemeris {
    /// Meeus Chapter 25 accurate apparent solar position and Equation of Time.
    public static func computeSolarPosition(
        epoch: JulianEpoch,
        observer: GeodeticObserver = .greenwichPrimeMeridian
    ) -> SolarPositionSummary {
        let t = epoch.julianCenturiesTT
        let t2 = t * t
        let deg = EphemerisConstants.degToRad

        // Geometric mean longitude of the Sun L0 (deg)
        let l0 = EphemerisConstants.normalizeDegrees360(
            280.46646 + 36_000.76983 * t + 0.0003032 * t2
        )
        // Mean anomaly of the Sun M (deg)
        let m = EphemerisConstants.normalizeDegrees360(
            357.52911 + 35_999.05029 * t - 0.0001537 * t2
        )
        let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t2

        let mRad = m * deg
        // Sun's equation of the center C (deg)
        let centerDeg = (1.914602 - 0.004817 * t - 0.000014 * t2) * sin(mRad)
            + (0.019993 - 0.000101 * t) * sin(2.0 * mRad)
            + 0.000289 * sin(3.0 * mRad)

        let trueLongitude = l0 + centerDeg
        let trueAnomalyRad = (m + centerDeg) * deg
        let radiusAU = (1.000001018 * (1.0 - e * e)) / (1.0 + e * cos(trueAnomalyRad))

        let nut = EarthOrientationModel.nutationAndObliquity(for: epoch)
        let aberrationDeg = -20.4898 * EphemerisConstants.arcsecToDeg / max(0.1, radiusAU)
        let apparentLonDeg = EphemerisConstants.normalizeDegrees360(
            trueLongitude + (nut.nutationLongitudeArcsec * EphemerisConstants.arcsecToDeg) + aberrationDeg
        )

        let epsRad = nut.trueObliquityDeg * deg
        let appLonRad = apparentLonDeg * deg
        let raDeg = EphemerisConstants.normalizeDegrees360(
            atan2(cos(epsRad) * sin(appLonRad), cos(appLonRad)) * EphemerisConstants.radToDeg
        )
        let decDeg = asin(max(-1.0, min(1.0, sin(epsRad) * sin(appLonRad)))) * EphemerisConstants.radToDeg

        let equatorial = EquatorialCoordinates(
            rightAscensionDeg: raDeg,
            declinationDeg: decDeg,
            distanceAU: radiusAU
        )
        let horizontal = EphemerisCoordinateTransformer.equatorialToTopocentricHorizontal(
            equatorial: equatorial,
            epoch: epoch,
            observer: observer,
            applyRefraction: true
        )

        // Equation of Time (Meeus Chapter 28): E = L0 - 0.0057183 - alpha + Delta_psi * cos(eps)
        let eqDiffDeg = EphemerisConstants.normalizeDegreesSigned180(
            l0 - 0.0057183 - raDeg + nut.equationOfEquinoxesDeg
        )
        let eotMinutes = eqDiffDeg * 4.0
        let angularDiameterArcsec = 1_919.26 / max(0.1, radiusAU)

        return SolarPositionSummary(
            epoch: epoch,
            apparentLongitudeDeg: apparentLonDeg,
            distanceAU: radiusAU,
            equatorial: equatorial,
            horizontal: horizontal,
            equationOfTimeMinutes: eotMinutes,
            angularDiameterArcsec: angularDiameterArcsec
        )
    }

    /// Computes solar transit (noon), sunrise/sunset (`h0 = -0.8333 deg`), and civil/nautical/astronomical
    /// twilight instants for a given UTC calendar date and `GeodeticObserver`.
    public static func computeSolarDayEvents(
        year: Int,
        month: Int,
        day: Int,
        observer: GeodeticObserver
    ) throws -> SolarDayEvents {
        let midnightUTC = try CivilDateTime(year: year, month: month, day: day, hour: 0, minute: 0, second: 0.0)
        let jd0 = midnightUTC.toJulianDate()

        // First-pass solar transit estimate (fraction of UTC day)
        var mTransit = (12.0 - (observer.longitudeDeg / 15.0)) / 24.0
        for _ in 0..<3 {
            let testEpoch = JulianEpoch(jdUTC: jd0 + mTransit)
            let sun = computeSolarPosition(epoch: testEpoch, observer: observer)
            let gast = EarthOrientationModel.gastDegrees(for: testEpoch)
            let localHA = EphemerisConstants.normalizeDegreesSigned180(
                gast + observer.longitudeDeg - sun.equatorial.rightAscensionDeg
            )
            mTransit -= localHA / 360.0
        }

        let noonEpoch = JulianEpoch(jdUTC: jd0 + mTransit)
        let noonSun = computeSolarPosition(epoch: noonEpoch, observer: observer)
        let noonDate = CivilDateTime.fromJulianDate(noonEpoch.jd).toUTCDate()

        // Horizon depression angle for upper solar limb + standard 34' refraction = -0.8333 deg
        let (riseDate, setDate, polarState) = solveSunAltitudeCrossingPair(
            jdTransit: noonEpoch.jd,
            targetAltitudeDeg: -0.8333,
            observer: observer
        )

        let daylightHours: Double
        switch polarState {
        case .midnightSunAboveThreshold:
            daylightHours = 24.0
        case .polarNightBelowThreshold:
            daylightHours = 0.0
        case .normalRiseAndSet:
            if let r = riseDate, let s = setDate {
                daylightHours = max(0.0, min(24.0, s.timeIntervalSince(r) / 3_600.0))
            } else {
                daylightHours = 0.0
            }
        }

        let (civilDawn, civilDusk, _) = solveSunAltitudeCrossingPair(
            jdTransit: noonEpoch.jd,
            targetAltitudeDeg: -6.0,
            observer: observer
        )
        let (nauticalDawn, nauticalDusk, _) = solveSunAltitudeCrossingPair(
            jdTransit: noonEpoch.jd,
            targetAltitudeDeg: -12.0,
            observer: observer
        )
        let (astroDawn, astroDusk, _) = solveSunAltitudeCrossingPair(
            jdTransit: noonEpoch.jd,
            targetAltitudeDeg: -18.0,
            observer: observer
        )

        return SolarDayEvents(
            year: year,
            month: month,
            day: day,
            observer: observer,
            condition: polarState,
            solarNoonUTC: noonDate,
            solarNoonMaxAltitudeDeg: noonSun.horizontal.apparentAltitudeDeg,
            equationOfTimeAtNoonMinutes: noonSun.equationOfTimeMinutes,
            sunriseUTC: riseDate,
            sunsetUTC: setDate,
            daylightDurationHours: daylightHours,
            civilDawnUTC: civilDawn,
            civilDuskUTC: civilDusk,
            nauticalDawnUTC: nauticalDawn,
            nauticalDuskUTC: nauticalDusk,
            astronomicalDawnUTC: astroDawn,
            astronomicalDuskUTC: astroDusk
        )
    }

    private static func solveSunAltitudeCrossingPair(
        jdTransit: Double,
        targetAltitudeDeg h0: Double,
        observer: GeodeticObserver
    ) -> (rise: Date?, set: Date?, condition: SolarPolarCondition) {
        let deg = EphemerisConstants.degToRad
        let transitEpoch = JulianEpoch(jdUTC: jdTransit)
        let sunNoon = computeSolarPosition(epoch: transitEpoch, observer: observer)
        let phi = observer.latitudeDeg * deg
        let dec = sunNoon.equatorial.declinationDeg * deg
        let sinH0 = sin(h0 * deg)

        let denom = cos(phi) * cos(dec)
        guard abs(denom) > 1.0e-12 else {
            let above = (sin(phi) * sin(dec)) >= sinH0
            return (nil, nil, above ? .midnightSunAboveThreshold : .polarNightBelowThreshold)
        }

        let cosH0 = (sinH0 - sin(phi) * sin(dec)) / denom
        if cosH0 < -1.0 {
            return (nil, nil, .midnightSunAboveThreshold)
        }
        if cosH0 > 1.0 {
            return (nil, nil, .polarNightBelowThreshold)
        }

        let h0Days = (acos(cosH0) * EphemerisConstants.radToDeg) / 360.0
        var jdRise = jdTransit - h0Days
        var jdSet = jdTransit + h0Days

        // Two Meeus Chapter 15 iterative refinements accounting for Sun's motion in RA/Dec
        for _ in 0..<2 {
            jdRise = refineCrossingInstant(jdEstimate: jdRise, targetAltitudeDeg: h0, observer: observer)
            jdSet = refineCrossingInstant(jdEstimate: jdSet, targetAltitudeDeg: h0, observer: observer)
        }

        let riseDate = CivilDateTime.fromJulianDate(jdRise).toUTCDate()
        let setDate = CivilDateTime.fromJulianDate(jdSet).toUTCDate()
        return (riseDate, setDate, .normalRiseAndSet)
    }

    private static func refineCrossingInstant(
        jdEstimate: Double,
        targetAltitudeDeg h0: Double,
        observer: GeodeticObserver
    ) -> Double {
        let deg = EphemerisConstants.degToRad
        let ep = JulianEpoch(jdUTC: jdEstimate)
        let sun = computeSolarPosition(epoch: ep, observer: observer)
        let gast = EarthOrientationModel.gastDegrees(for: ep)
        let localHADeg = EphemerisConstants.normalizeDegreesSigned180(
            gast + observer.longitudeDeg - sun.equatorial.rightAscensionDeg
        )
        let phi = observer.latitudeDeg * deg
        let dec = sun.equatorial.declinationDeg * deg
        let hRad = localHADeg * deg
        let geomAltDeg = asin(
            max(-1.0, min(1.0, sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(hRad)))
        ) * EphemerisConstants.radToDeg

        let slope = 360.0 * cos(dec) * cos(phi) * sin(hRad)
        guard abs(slope) > 1.0e-7 else { return jdEstimate }
        let deltaM = (geomAltDeg - h0) / slope
        return jdEstimate + deltaM
    }
}

// MARK: - Lunar Geocentric Ephemeris & Phase Model

public enum MoonPhaseName: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case newMoon = "New Moon"
    case waxingCrescent = "Waxing Crescent"
    case firstQuarter = "First Quarter"
    case waxingGibbous = "Waxing Gibbous"
    case fullMoon = "Full Moon"
    case waningGibbous = "Waning Gibbous"
    case lastQuarter = "Last Quarter"
    case waningCrescent = "Waning Crescent"

    public var emojiSymbol: String {
        switch self {
        case .newMoon: return "🌑"
        case .waxingCrescent: return "🌒"
        case .firstQuarter: return "🌓"
        case .waxingGibbous: return "🌔"
        case .fullMoon: return "🌕"
        case .waningGibbous: return "🌖"
        case .lastQuarter: return "🌗"
        case .waningCrescent: return "🌘"
        }
    }
}

public struct MoonPhaseSummary: Codable, Equatable, Hashable, Sendable {
    public let epoch: JulianEpoch
    public let ecliptic: EclipticCoordinates
    public let equatorial: EquatorialCoordinates
    public let horizontal: HorizontalCoordinates
    public let geocentricDistanceKm: Double
    public let angularDiameterArcsec: Double
    /// Moon minus Sun apparent ecliptic longitude `[0, 360)`.
    public let solarElongationDeg: Double
    /// Selenocentric phase angle `i` in degrees `[0, 180]`.
    public let phaseAngleDeg: Double
    /// Illuminated fraction `k` in `[0.0, 1.0]`.
    public let illuminatedFraction: Double
    /// Approximate synodic lunar age in days (`0..<29.53059`).
    public let lunarAgeDays: Double
    public let phaseName: MoonPhaseName
    public let isWaxing: Bool
    /// True when full/new Moon occurs near perigee (`< 362,000 km`).
    public let isPerigeeSyzygy: Bool
}

public enum LunarEphemeris {
    public static let synodicMonthDays: Double = 29.530_588_861

    /// Meeus Chapter 47 multi-periodic harmonic lunar position, distance, and illumination solver.
    public static func computeMoonSummary(
        epoch: JulianEpoch,
        observer: GeodeticObserver = .greenwichPrimeMeridian
    ) -> MoonPhaseSummary {
        let t = epoch.julianCenturiesTT
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t
        let deg = EphemerisConstants.degToRad

        // Moon's mean longitude L'
        let lPrime = EphemerisConstants.normalizeDegrees360(
            218.316_447_7 + 481_267.881_234_21 * t - 0.001_578_6 * t2 + t3 / 538_841.0 - t4 / 65_194_000.0
        )
        // Mean elongation of the Moon D
        let dElong = EphemerisConstants.normalizeDegrees360(
            297.850_192_1 + 445_267.111_403_4 * t - 0.001_881_9 * t2 + t3 / 545_868.0 - t4 / 113_065_000.0
        )
        // Sun's mean anomaly M
        let mSun = EphemerisConstants.normalizeDegrees360(
            357.529_109_2 + 35_999.050_290_9 * t - 0.000_153_6 * t2 + t3 / 24_490_000.0
        )
        // Moon's mean anomaly M'
        let mPrime = EphemerisConstants.normalizeDegrees360(
            134.963_396_4 + 477_198.867_505_5 * t + 0.008_741_4 * t2 + t3 / 69_699.0 - t4 / 14_712_000.0
        )
        // Moon's argument of latitude F
        let fArg = EphemerisConstants.normalizeDegrees360(
            93.272_095_0 + 483_202.017_523_3 * t - 0.003_653_9 * t2 - t3 / 3_526_000.0 + t4 / 863_310_000.0
        )

        // Planetary & Venus/Earth additive arguments A1, A2, A3
        let a1 = EphemerisConstants.normalizeDegrees360(119.75 + 131.849 * t) * deg
        let a2 = EphemerisConstants.normalizeDegrees360(53.09 + 479_264.290 * t) * deg
        let a3 = EphemerisConstants.normalizeDegrees360(313.45 + 481_266.484 * t) * deg

        // Earth orbital eccentricity scaling factor E
        let eccFactor = 1.0 - 0.002_516 * t - 0.000_007_4 * t2
        let eccFactor2 = eccFactor * eccFactor

        // Principal Meeus Chapter 47 Table 47.A periodic terms: (D, M, M', F, sinLon_1e-6deg, cosDist_m)
        let lonDistTerms: [(Int, Int, Int, Int, Double, Double)] = [
            (0, 0, 1, 0, +6_288_774, -20_905_355),
            (2, 0, -1, 0, +1_274_027, -3_699_111),
            (2, 0, 0, 0, +658_314, -2_955_968),
            (0, 0, 2, 0, +213_618, -569_925),
            (0, 1, 0, 0, -185_116, +48_888),
            (0, 0, 0, 2, -114_332, -3_149),
            (2, 0, -2, 0, +58_793, +246_158),
            (2, -1, -1, 0, +57_066, -152_138),
            (2, 0, 1, 0, +53_322, -170_733),
            (2, -1, 0, 0, +45_758, -204_586),
            (0, 1, -1, 0, -40_923, -129_620),
            (1, 0, 0, 0, -34_720, +108_743),
            (0, 1, 1, 0, -30_383, +104_755),
            (2, 0, 0, -2, +15_327, +10_321),
            (0, 0, 1, 2, -12_528, 0),
            (0, 0, 1, -2, +10_980, +79_661),
            (4, 0, -1, 0, +10_675, -34_782),
            (0, 0, 3, 0, +10_034, -23_210),
            (4, 0, -2, 0, +8_548, -21_636),
            (2, 1, -1, 0, -7_888, +24_208),
            (2, 1, 0, 0, -6_766, +30_824),
            (1, 0, -1, 0, -5_163, -8_379),
            (1, 1, 0, 0, +4_987, -16_675),
            (2, -1, 1, 0, +4_036, -12_831)
        ]

        var sumL = 0.0
        var sumR = 0.0
        for (cD, cM, cMP, cF, coeffL, coeffR) in lonDistTerms {
            let arg = (Double(cD) * dElong + Double(cM) * mSun + Double(cMP) * mPrime + Double(cF) * fArg) * deg
            let eScale: Double
            switch abs(cM) {
            case 1: eScale = eccFactor
            case 2: eScale = eccFactor2
            default: eScale = 1.0
            }
            sumL += eScale * coeffL * sin(arg)
            sumR += eScale * coeffR * cos(arg)
        }
        sumL += 3_958.0 * sin(a1) + 1_962.0 * sin((lPrime - fArg) * deg) + 318.0 * sin(a2)

        // Principal Meeus Table 47.B latitude terms: (D, M, M', F, sinLat_1e-6deg)
        let latTerms: [(Int, Int, Int, Int, Double)] = [
            (0, 0, 0, 1, +5_128_122),
            (0, 0, 1, 1, +280_602),
            (0, 0, 1, -1, +277_693),
            (2, 0, 0, -1, +173_237),
            (2, 0, -1, 1, +55_413),
            (2, 0, -1, -1, +46_271),
            (2, 0, 0, 1, +32_573),
            (0, 0, 2, 1, +17_198),
            (2, 0, 1, -1, +9_266),
            (0, 0, 2, -1, +8_822),
            (2, -1, 0, -1, +8_216),
            (2, 0, -2, -1, +4_324),
            (2, 0, 1, 1, +4_200)
        ]

        var sumB = 0.0
        for (cD, cM, cMP, cF, coeffB) in latTerms {
            let arg = (Double(cD) * dElong + Double(cM) * mSun + Double(cMP) * mPrime + Double(cF) * fArg) * deg
            let eScale: Double = (abs(cM) == 1) ? eccFactor : ((abs(cM) == 2) ? eccFactor2 : 1.0)
            sumB += eScale * coeffB * sin(arg)
        }
        sumB += -2_235.0 * sin(lPrime * deg)
            + 382.0 * sin(a3)
            + 175.0 * sin(a1 - fArg * deg)
            + 175.0 * sin(a1 + fArg * deg)
            + 127.0 * sin((lPrime - mPrime) * deg)
            - 115.0 * sin((lPrime + mPrime) * deg)

        let geomLonDeg = EphemerisConstants.normalizeDegrees360(lPrime + (sumL / 1_000_000.0))
        let geomLatDeg = sumB / 1_000_000.0
        let distKm = 385_000.56 + (sumR / 1_000.0)
        let distAU = distKm / EphemerisConstants.astronomicalUnitKm

        let ecliptic = EclipticCoordinates(
            longitudeDeg: geomLonDeg,
            latitudeDeg: geomLatDeg,
            distanceAU: distAU
        )
        let equatorial = EphemerisCoordinateTransformer.eclipticToApparentEquatorial(
            ecliptic: ecliptic,
            epoch: epoch,
            applyNutation: true
        )
        let horizontal = EphemerisCoordinateTransformer.equatorialToTopocentricHorizontal(
            equatorial: equatorial,
            epoch: epoch,
            observer: observer,
            applyRefraction: true
        )

        // Phase & Illumination against apparent Sun
        let sun = SolarEphemeris.computeSolarPosition(epoch: epoch, observer: observer)
        let nutLonDeg = EarthOrientationModel.nutationAndObliquity(for: epoch).nutationLongitudeArcsec
            * EphemerisConstants.arcsecToDeg
        let apparentMoonLon = EphemerisConstants.normalizeDegrees360(geomLonDeg + nutLonDeg)
        let elongationDeg = EphemerisConstants.normalizeDegrees360(apparentMoonLon - sun.apparentLongitudeDeg)

        let cosPsi = cos(geomLatDeg * deg) * cos(elongationDeg * deg)
        let psiRad = acos(max(-1.0, min(1.0, cosPsi)))
        let sunDistKm = sun.distanceAU * EphemerisConstants.astronomicalUnitKm
        let phaseAngleRad = atan2(
            sunDistKm * sin(psiRad),
            distKm - sunDistKm * cos(psiRad)
        )
        let phaseAngleDeg = phaseAngleRad * EphemerisConstants.radToDeg
        let illuminated = max(0.0, min(1.0, 0.5 * (1.0 + cos(phaseAngleRad))))
        let ageDays = (elongationDeg / 360.0) * synodicMonthDays
        let waxing = elongationDeg < 180.0
        let phaseName = classifyMoonPhase(elongationDeg: elongationDeg)
        let angularDiamArcsec = (2.0 * 1_737.4 / distKm) * EphemerisConstants.radToDeg * 3_600.0
        let isSyzygyNearPerigee = (phaseName == .fullMoon || phaseName == .newMoon) && (distKm < 362_000.0)

        return MoonPhaseSummary(
            epoch: epoch,
            ecliptic: ecliptic,
            equatorial: equatorial,
            horizontal: horizontal,
            geocentricDistanceKm: distKm,
            angularDiameterArcsec: angularDiamArcsec,
            solarElongationDeg: elongationDeg,
            phaseAngleDeg: phaseAngleDeg,
            illuminatedFraction: illuminated,
            lunarAgeDays: ageDays,
            phaseName: phaseName,
            isWaxing: waxing,
            isPerigeeSyzygy: isSyzygyNearPerigee
        )
    }

    private static func classifyMoonPhase(elongationDeg: Double) -> MoonPhaseName {
        let e = EphemerisConstants.normalizeDegrees360(elongationDeg)
        switch e {
        case 0.0..<11.25, 348.75...360.0:
            return .newMoon
        case 11.25..<78.75:
            return .waxingCrescent
        case 78.75..<101.25:
            return .firstQuarter
        case 101.25..<168.75:
            return .waxingGibbous
        case 168.75..<191.25:
            return .fullMoon
        case 191.25..<258.75:
            return .waningGibbous
        case 258.75..<281.25:
            return .lastQuarter
        default:
            return .waningCrescent
        }
    }
}

// MARK: - Multi-Body Sky Snapshot & Conjunction / Aspect Detector

public enum PlanetaryAspectType: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case conjunction = "Conjunction"
    case sextile = "Sextile"
    case quadrature = "Quadrature"
    case trine = "Trine"
    case opposition = "Opposition"

    public var exactAngleDeg: Double {
        switch self {
        case .conjunction: return 0.0
        case .sextile: return 60.0
        case .quadrature: return 90.0
        case .trine: return 120.0
        case .opposition: return 180.0
        }
    }
}

public struct CelestialBodyEphemeris: Codable, Equatable, Hashable, Sendable {
    public let body: CelestialBody
    public let heliocentricPositionAU: CartesianVector3D?
    public let geocentricEcliptic: EclipticCoordinates
    public let apparentEquatorial: EquatorialCoordinates
    public let topocentricHorizontal: HorizontalCoordinates
    public let solarElongationDeg: Double
    public let visualMagnitudeApprox: Double
    public let isApparentRetrograde: Bool
    public let eclipticLongitudeRateDegPerDay: Double
}

public struct PlanetaryAspectEvent: Codable, Equatable, Hashable, Sendable {
    public let bodyA: CelestialBody
    public let bodyB: CelestialBody
    public let aspect: PlanetaryAspectType
    public let sphericalSeparationDeg: Double
    public let eclipticLongitudeDifferenceDeg: Double
    public let orbErrorDeg: Double
}

public struct EphemerisSkySnapshot: Codable, Equatable, Sendable {
    public let epoch: JulianEpoch
    public let observer: GeodeticObserver
    public let gmstDegrees: Double
    public let lmstDegrees: Double
    public let nutation: NutationState
    public let sun: SolarPositionSummary
    public let moon: MoonPhaseSummary
    public let bodies: [CelestialBodyEphemeris]
    public let activeAspects: [PlanetaryAspectEvent]

    public func ephemeris(for body: CelestialBody) -> CelestialBodyEphemeris? {
        bodies.first { $0.body == body }
    }

    public func angularSeparationDegrees(between first: CelestialBody, and second: CelestialBody) -> Double? {
        guard let a = ephemeris(for: first), let b = ephemeris(for: second) else { return nil }
        return EphemerisCoordinateTransformer.angularSeparationDegrees(
            ra1Deg: a.apparentEquatorial.rightAscensionDeg,
            dec1Deg: a.apparentEquatorial.declinationDeg,
            ra2Deg: b.apparentEquatorial.rightAscensionDeg,
            dec2Deg: b.apparentEquatorial.declinationDeg
        )
    }

    /// Computes a full multi-body solar system sky snapshot at `epoch` and `observer`, including
    /// light-time-corrected geocentric planetary coordinates, retrograde motion detection, and conjunctions.
    public static func compute(
        epoch: JulianEpoch,
        observer: GeodeticObserver = .greenwichPrimeMeridian,
        aspectOrbThresholdDeg: Double = 4.0
    ) throws -> EphemerisSkySnapshot {
        let gmst = EarthOrientationModel.gmstDegrees(for: epoch)
        let lmst = EarthOrientationModel.lmstDegrees(for: epoch, eastLongitudeDeg: observer.longitudeDeg)
        let nut = EarthOrientationModel.nutationAndObliquity(for: epoch)
        let sunSummary = SolarEphemeris.computeSolarPosition(epoch: epoch, observer: observer)
        let moonSummary = LunarEphemeris.computeMoonSummary(epoch: epoch, observer: observer)

        guard let embElements = JPLMeanOrbitalElements.catalogElements(for: .earthMoonBarycenter) else {
            throw EphemerisMathError.invalidSemiMajorAxis(0.0)
        }
        let earthStateNow = try embElements.heliocentricState(at: epoch)
        let stepDays = 0.25
        let futureEpoch = JulianEpoch(jdUTC: epoch.jd + stepDays, customDeltaTSeconds: epoch.deltaTSeconds)
        let earthStateFuture = try embElements.heliocentricState(at: futureEpoch)

        var entries = [CelestialBodyEphemeris]()
        entries.reserveCapacity(9)

        // 1. Sun entry
        entries.append(
            CelestialBodyEphemeris(
                body: .sun,
                heliocentricPositionAU: CartesianVector3D(x: 0, y: 0, z: 0),
                geocentricEcliptic: EclipticCoordinates(
                    longitudeDeg: sunSummary.apparentLongitudeDeg,
                    latitudeDeg: 0.0,
                    distanceAU: sunSummary.distanceAU
                ),
                apparentEquatorial: sunSummary.equatorial,
                topocentricHorizontal: sunSummary.horizontal,
                solarElongationDeg: 0.0,
                visualMagnitudeApprox: -26.74,
                isApparentRetrograde: false,
                eclipticLongitudeRateDegPerDay: 0.9856
            )
        )

        // 2. Moon entry
        let moonNext = LunarEphemeris.computeMoonSummary(epoch: futureEpoch, observer: observer)
        let moonRate = EphemerisConstants.normalizeDegreesSigned180(
            moonNext.ecliptic.longitudeDeg - moonSummary.ecliptic.longitudeDeg
        ) / stepDays
        let moonMag = -12.73 + 0.026 * moonSummary.phaseAngleDeg + 4.0e-9 * pow(moonSummary.phaseAngleDeg, 4)

        entries.append(
            CelestialBodyEphemeris(
                body: .moon,
                heliocentricPositionAU: nil,
                geocentricEcliptic: moonSummary.ecliptic,
                apparentEquatorial: moonSummary.equatorial,
                topocentricHorizontal: moonSummary.horizontal,
                solarElongationDeg: moonSummary.solarElongationDeg,
                visualMagnitudeApprox: moonMag,
                isApparentRetrograde: moonRate < 0.0,
                eclipticLongitudeRateDegPerDay: moonRate
            )
        )

        // 3. Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune
        let planets: [CelestialBody] = [.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune]
        for planet in planets {
            guard let elem = JPLMeanOrbitalElements.catalogElements(for: planet) else { continue }
            let rawHelio = try elem.heliocentricState(at: epoch)

            // One-step planetary light-time retardation correction
            let geoInitial = rawHelio.positionAU - earthStateNow.positionAU
            let lightDelayDays = geoInitial.magnitude * EphemerisConstants.lightTimeDaysPerAU
            let retardedEpoch = JulianEpoch(
                jdUTC: epoch.jd - lightDelayDays,
                customDeltaTSeconds: epoch.deltaTSeconds
            )
            let retardedHelio = try elem.heliocentricState(at: retardedEpoch)
            let geoEcliptic = EphemerisCoordinateTransformer.heliocentricToGeocentricEcliptic(
                bodyHeliocentricAU: retardedHelio.positionAU,
                earthHeliocentricAU: earthStateNow.positionAU
            )

            // Finite-difference apparent ecliptic longitude velocity for retrograde flag
            let futureHelio = try elem.heliocentricState(at: futureEpoch)
            let geoFuture = EphemerisCoordinateTransformer.heliocentricToGeocentricEcliptic(
                bodyHeliocentricAU: futureHelio.positionAU,
                earthHeliocentricAU: earthStateFuture.positionAU
            )
            let lonRate = EphemerisConstants.normalizeDegreesSigned180(
                geoFuture.longitudeDeg - geoEcliptic.longitudeDeg
            ) / stepDays

            let apparentEq = EphemerisCoordinateTransformer.eclipticToApparentEquatorial(
                ecliptic: geoEcliptic,
                epoch: epoch,
                applyNutation: true
            )
            let topoHoriz = EphemerisCoordinateTransformer.equatorialToTopocentricHorizontal(
                equatorial: apparentEq,
                epoch: epoch,
                observer: observer,
                applyRefraction: true
            )

            let solarElong = EphemerisCoordinateTransformer.angularSeparationDegrees(
                ra1Deg: apparentEq.rightAscensionDeg,
                dec1Deg: apparentEq.declinationDeg,
                ra2Deg: sunSummary.equatorial.rightAscensionDeg,
                dec2Deg: sunSummary.equatorial.declinationDeg
            )

            let mag = estimateVisualMagnitude(
                planet: planet,
                heliocentricDistanceAU: retardedHelio.positionAU.magnitude,
                geocentricDistanceAU: geoEcliptic.distanceAU,
                earthDistanceAU: earthStateNow.positionAU.magnitude
            )

            entries.append(
                CelestialBodyEphemeris(
                    body: planet,
                    heliocentricPositionAU: retardedHelio.positionAU,
                    geocentricEcliptic: geoEcliptic,
                    apparentEquatorial: apparentEq,
                    topocentricHorizontal: topoHoriz,
                    solarElongationDeg: solarElong,
                    visualMagnitudeApprox: mag,
                    isApparentRetrograde: lonRate < 0.0,
                    eclipticLongitudeRateDegPerDay: lonRate
                )
            )
        }

        let aspects = detectAspects(entries: entries, orbThresholdDeg: aspectOrbThresholdDeg)

        return EphemerisSkySnapshot(
            epoch: epoch,
            observer: observer,
            gmstDegrees: gmst,
            lmstDegrees: lmst,
            nutation: nut,
            sun: sunSummary,
            moon: moonSummary,
            bodies: entries,
            activeAspects: aspects
        )
    }

    private static func detectAspects(
        entries: [CelestialBodyEphemeris],
        orbThresholdDeg: Double
    ) -> [PlanetaryAspectEvent] {
        var events = [PlanetaryAspectEvent]()
        guard entries.count >= 2 else { return events }

        for i in 0..<(entries.count - 1) {
            for j in (i + 1)..<entries.count {
                let first = entries[i]
                let second = entries[j]
                let sphericalSep = EphemerisCoordinateTransformer.angularSeparationDegrees(
                    ra1Deg: first.apparentEquatorial.rightAscensionDeg,
                    dec1Deg: first.apparentEquatorial.declinationDeg,
                    ra2Deg: second.apparentEquatorial.rightAscensionDeg,
                    dec2Deg: second.apparentEquatorial.declinationDeg
                )
                let eclipticDiff = abs(
                    EphemerisConstants.normalizeDegreesSigned180(
                        second.geocentricEcliptic.longitudeDeg - first.geocentricEcliptic.longitudeDeg
                    )
                )

                for aspect in PlanetaryAspectType.allCases {
                    let orb = abs(eclipticDiff - aspect.exactAngleDeg)
                    if orb <= orbThresholdDeg {
                        events.append(
                            PlanetaryAspectEvent(
                                bodyA: first.body,
                                bodyB: second.body,
                                aspect: aspect,
                                sphericalSeparationDeg: sphericalSep,
                                eclipticLongitudeDifferenceDeg: eclipticDiff,
                                orbErrorDeg: orb
                            )
                        )
                    }
                }
            }
        }
        return events.sorted { $0.orbErrorDeg < $1.orbErrorDeg }
    }

    private static func estimateVisualMagnitude(
        planet: CelestialBody,
        heliocentricDistanceAU r: Double,
        geocentricDistanceAU delta: Double,
        earthDistanceAU rEarth: Double
    ) -> Double {
        let denom = max(1.0e-9, 2.0 * r * delta)
        let cosPhase = max(-1.0, min(1.0, (r * r + delta * delta - rEarth * rEarth) / denom))
        let phaseDeg = acos(cosPhase) * EphemerisConstants.radToDeg
        let distModulus = 5.0 * log10(max(1.0e-6, r * delta))

        switch planet {
        case .mercury:
            return -0.60 + distModulus + 0.0380 * phaseDeg - 0.000273 * phaseDeg * phaseDeg
                + 2.0e-6 * pow(phaseDeg, 3)
        case .venus:
            return -4.40 + distModulus + 0.0009 * phaseDeg + 0.000239 * phaseDeg * phaseDeg
                - 6.5e-7 * pow(phaseDeg, 3)
        case .mars:
            return -1.52 + distModulus + 0.016 * phaseDeg
        case .jupiter:
            return -9.40 + distModulus + 0.005 * phaseDeg
        case .saturn:
            return -8.88 + distModulus + 0.044 * phaseDeg
        case .uranus:
            return -7.19 + distModulus + 0.002 * phaseDeg
        case .neptune:
            return -6.87 + distModulus
        default:
            return 0.0
        }
    }
}
