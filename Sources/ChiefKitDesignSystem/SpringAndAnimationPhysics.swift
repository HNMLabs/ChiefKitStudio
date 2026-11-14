#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Spring Damping Regimes & Parameters

public enum SpringDampingRegime: String, Codable, Hashable, Sendable {
    case undamped = "Undamped (ζ = 0)"
    case underdamped = "Underdamped Oscillatory (0 < ζ < 1)"
    case criticallyDamped = "Critically Damped (ζ = 1)"
    case overdamped = "Overdamped Exponential (ζ > 1)"
}

/// Physical and perceptual parameterization of a 1D damped harmonic oscillator
/// transitioning from normalized initial position `x(0) = 0` toward target equilibrium `x_eq = 1`.
public struct SpringParameters: Codable, Hashable, Sendable {
    public var mass: Double
    public var stiffness: Double
    public var damping: Double
    public var initialVelocity: Double

    /// Direct physical mass-spring-damper initializer (`m * x'' + c * x' + k * (x - 1) = 0`).
    public init(
        mass: Double = 1.0,
        stiffness: Double,
        damping: Double,
        initialVelocity: Double = 0.0
    ) {
        self.mass = max(1e-4, mass)
        self.stiffness = max(1e-4, stiffness)
        self.damping = max(0.0, damping)
        self.initialVelocity = initialVelocity
    }

    /// Apple SwiftUI perceptual spring initializer (`Spring(duration:bounce:)`).
    /// - `duration`: Perceptual duration in seconds (`> 0`).
    /// - `bounce`: Bounce in `[-1.0, 1.0]`: `0` = critically damped, `> 0` = underdamped bounce, `< 0` = overdamped.
    public init(
        duration: Double,
        bounce: Double = 0.0,
        initialVelocity: Double = 0.0
    ) {
        let safeDuration = max(0.02, duration)
        let m = 1.0
        let omegaN = (2.0 * .pi) / safeDuration
        let k = omegaN * omegaN * m

        let clampedBounce = min(max(-0.99, bounce), 0.99)
        let zeta: Double
        if clampedBounce >= 0.0 {
            zeta = 1.0 - clampedBounce
        } else {
            zeta = 1.0 / (1.0 + clampedBounce)
        }
        let c = 2.0 * zeta * sqrt(k * m)

        self.mass = m
        self.stiffness = k
        self.damping = c
        self.initialVelocity = initialVelocity
    }

    /// Undamped natural angular frequency `ω_n = √(k / m)` in rad/s.
    public var naturalFrequency: Double {
        sqrt(stiffness / mass)
    }

    /// Dimensionless damping ratio `ζ = c / (2 * √(k * m))`.
    public var dampingRatio: Double {
        damping / (2.0 * sqrt(stiffness * mass))
    }

    /// Damped angular frequency `ω_d = ω_n * √(1 - ζ²)` for underdamped systems, or `0` when `ζ >= 1`.
    public var dampedFrequency: Double {
        let z = dampingRatio
        guard z < 1.0 else { return 0.0 }
        return naturalFrequency * sqrt(max(0.0, 1.0 - z * z))
    }

    /// Perceptual SwiftUI response duration `T = 2π / ω_n`.
    public var perceptualDuration: Double {
        (2.0 * .pi) / naturalFrequency
    }

    /// Perceptual SwiftUI bounce parameter derived from `dampingRatio`.
    public var perceptualBounce: Double {
        let z = dampingRatio
        if z <= 1.0 {
            return 1.0 - z
        }
        return 1.0 - (1.0 / z)
    }

    public var regime: SpringDampingRegime {
        let z = dampingRatio
        if z < 1e-6 { return .undamped }
        if abs(z - 1.0) <= 1e-4 { return .criticallyDamped }
        return z < 1.0 ? .underdamped : .overdamped
    }

    // MARK: Standard Presets

    public static let smooth = SpringParameters(duration: 0.50, bounce: 0.0)
    public static let snappy = SpringParameters(duration: 0.32, bounce: 0.15)
    public static let bouncy = SpringParameters(duration: 0.55, bounce: 0.34)
    public static let interactiveGlass = SpringParameters(mass: 1.0, stiffness: 320.0, damping: 24.0, initialVelocity: 0.0)
    public static let gentleFloat = SpringParameters(mass: 1.2, stiffness: 110.0, damping: 18.0, initialVelocity: 0.0)

    // MARK: Closed-Form Analytical Differential Equation Solution

    /// Evaluates exact closed-form position `x(t)` and velocity `v(t)` at `time >= 0`
    /// solving `m * u'' + c * u' + k * u = 0` where displacement from target is `u(t) = x(t) - 1`,
    /// `u(0) = -1`, and `u'(0) = initialVelocity`.
    public func analyticalState(at time: Double) -> SpringStateSample {
        let t = max(0.0, time)
        let u0 = -1.0
        let v0 = initialVelocity
        let omegaN = naturalFrequency
        let zeta = dampingRatio

        let u: Double
        let v: Double

        if zeta < 1e-6 {
            // Purely undamped harmonic motion: u(t) = u0*cos(ωn*t) + (v0/ωn)*sin(ωn*t)
            let cosW = cos(omegaN * t)
            let sinW = sin(omegaN * t)
            u = u0 * cosW + (v0 / omegaN) * sinW
            v = -u0 * omegaN * sinW + v0 * cosW
        } else if abs(zeta - 1.0) <= 1e-4 {
            // Critically damped: u(t) = (c1 + c2*t) * e^(-ωn*t)
            let c1 = u0
            let c2 = v0 + omegaN * u0
            let decay = exp(-omegaN * t)
            u = (c1 + c2 * t) * decay
            v = (c2 - omegaN * (c1 + c2 * t)) * decay
        } else if zeta < 1.0 {
            // Underdamped oscillatory: u(t) = e^(-ζ*ωn*t) * [c1*cos(ωd*t) + c2*sin(ωd*t)]
            let omegaD = omegaN * sqrt(1.0 - zeta * zeta)
            let alpha = zeta * omegaN
            let c1 = u0
            let c2 = (v0 + alpha * u0) / omegaD
            let decay = exp(-alpha * t)
            let cosD = cos(omegaD * t)
            let sinD = sin(omegaD * t)
            u = decay * (c1 * cosD + c2 * sinD)
            v = decay * ((c2 * omegaD - alpha * c1) * cosD - (c1 * omegaD + alpha * c2) * sinD)
        } else {
            // Overdamped real roots: r1, r2 = -ωn * (ζ ∓ √(ζ² - 1))
            let rad = sqrt(zeta * zeta - 1.0)
            let r1 = -omegaN * (zeta - rad)
            let r2 = -omegaN * (zeta + rad)
            let denom = r1 - r2
            let c1 = (v0 - r2 * u0) / denom
            let c2 = (r1 * u0 - v0) / denom
            let e1 = exp(r1 * t)
            let e2 = exp(r2 * t)
            u = c1 * e1 + c2 * e2
            v = c1 * r1 * e1 + c2 * r2 * e2
        }

        let x = 1.0 + u
        let accel = (-stiffness * u - damping * v) / mass
        let kinetic = 0.5 * mass * v * v
        let potential = 0.5 * stiffness * u * u

        return SpringStateSample(
            time: t,
            position: x,
            velocity: v,
            acceleration: accel,
            totalEnergy: kinetic + potential
        )
    }

    public func position(at time: Double) -> Double {
        analyticalState(at: time).position
    }

    public func velocity(at time: Double) -> Double {
        analyticalState(at: time).velocity
    }
}

// MARK: - Spring State Sample, RK4 Solver & Analysis Report

public struct SpringStateSample: Codable, Hashable, Sendable {
    public let time: Double
    public let position: Double
    public let velocity: Double
    public let acceleration: Double
    public let totalEnergy: Double

    public init(
        time: Double,
        position: Double,
        velocity: Double,
        acceleration: Double,
        totalEnergy: Double
    ) {
        self.time = time
        self.position = position
        self.velocity = velocity
        self.acceleration = acceleration
        self.totalEnergy = totalEnergy
    }
}

public struct SpringAnalysisReport: Codable, Hashable, Sendable {
    public let parameters: SpringParameters
    public let regime: SpringDampingRegime
    public let dampingRatio: Double
    public let naturalFrequency: Double
    public let dampedFrequency: Double
    public let peakPosition: Double
    public let peakOvershootPercent: Double
    public let timeToPeakSeconds: Double
    public let settlingTimeSeconds: Double
    public let rk4AnalyticalRMSError: Double
    public let sampledCurve: [SpringStateSample]

    public init(
        parameters: SpringParameters,
        sampleStepSeconds: Double = 1.0 / 120.0,
        settlingTolerance: Double = 0.001
    ) {
        self.parameters = parameters
        self.regime = parameters.regime
        self.dampingRatio = parameters.dampingRatio
        self.naturalFrequency = parameters.naturalFrequency
        self.dampedFrequency = parameters.dampedFrequency

        let maxHorizon = min(15.0, max(2.0, parameters.perceptualDuration * 8.0))
        let dt = max(1.0 / 1000.0, sampleStepSeconds)
        let steps = Int((maxHorizon / dt).rounded(.up))

        var samples: [SpringStateSample] = []
        samples.reserveCapacity(steps + 1)

        var maxPos = 0.0
        var peakT = 0.0
        for i in 0...steps {
            let t = Double(i) * dt
            let s = parameters.analyticalState(at: t)
            samples.append(s)
            if s.position > maxPos {
                maxPos = s.position
                peakT = t
            }
        }

        // Determine exact settling time: latest instant where |x(t) - 1| >= tolerance or |v(t) / ωn| >= tolerance
        var lastUnsettledIndex = 0
        let velScale = max(1.0, parameters.naturalFrequency)
        for i in stride(from: samples.count - 1, through: 0, by: -1) {
            let posErr = abs(samples[i].position - 1.0)
            let normVelErr = abs(samples[i].velocity) / velScale
            if posErr >= settlingTolerance || normVelErr >= settlingTolerance {
                lastUnsettledIndex = i
                break
            }
        }

        let settledTime = min(maxHorizon, Double(min(samples.count - 1, lastUnsettledIndex + 1)) * dt)
        let trimCount = max(2, min(samples.count, Int((settledTime * 1.15 / dt).rounded(.up)) + 1))
        let trimmedSamples = Array(samples.prefix(trimCount))

        // Verify RK4 numerical integration accuracy over the same horizon
        let rk4Samples = RK4SpringIntegrator.integrate(
            parameters: parameters,
            duration: Double(trimCount - 1) * dt,
            dt: dt
        )
        var sqErrSum = 0.0
        let compareCount = min(trimmedSamples.count, rk4Samples.count)
        for i in 0..<compareCount {
            let diff = trimmedSamples[i].position - rk4Samples[i].position
            sqErrSum += diff * diff
        }
        let rms = compareCount > 0 ? sqrt(sqErrSum / Double(compareCount)) : 0.0

        self.peakPosition = maxPos
        self.peakOvershootPercent = max(0.0, (maxPos - 1.0) * 100.0)
        self.timeToPeakSeconds = peakT
        self.settlingTimeSeconds = settledTime
        self.rk4AnalyticalRMSError = rms
        self.sampledCurve = trimmedSamples
    }
}

/// Classical 4th-order Runge-Kutta (`O(dt⁴)` global error) differential equation solver for linear and nonlinear springs.
public enum RK4SpringIntegrator {

    /// Advances `(x, v)` by one `dt` time step using 4-stage RK4 integration.
    /// Supports optional quadratic fluid drag `-c_q * v * |v|` and external forcing `F(t)`.
    public static func step(
        time: Double,
        position x: Double,
        velocity v: Double,
        dt: Double,
        parameters p: SpringParameters,
        target: Double = 1.0,
        quadraticDrag: Double = 0.0,
        externalForce: (@Sendable (Double) -> Double)? = nil
    ) -> SpringStateSample {
        @inline(__always)
        func acceleration(t: Double, pos: Double, vel: Double) -> Double {
            let springForce = -p.stiffness * (pos - target)
            let linearDamper = -p.damping * vel
            let fluidDrag = -quadraticDrag * vel * abs(vel)
            let drive = externalForce?(t) ?? 0.0
            return (springForce + linearDamper + fluidDrag + drive) / p.mass
        }

        let k1x = v
        let k1v = acceleration(t: time, pos: x, vel: v)

        let tMid = time + 0.5 * dt
        let x2 = x + 0.5 * dt * k1x
        let v2 = v + 0.5 * dt * k1v
        let k2x = v2
        let k2v = acceleration(t: tMid, pos: x2, vel: v2)

        let x3 = x + 0.5 * dt * k2x
        let v3 = v + 0.5 * dt * k2v
        let k3x = v3
        let k3v = acceleration(t: tMid, pos: x3, vel: v3)

        let tEnd = time + dt
        let x4 = x + dt * k3x
        let v4 = v + dt * k3v
        let k4x = v4
        let k4v = acceleration(t: tEnd, pos: x4, vel: v4)

        let nextX = x + (dt / 6.0) * (k1x + 2.0 * k2x + 2.0 * k3x + k4x)
        let nextV = v + (dt / 6.0) * (k1v + 2.0 * k2v + 2.0 * k3v + k4v)
        let nextA = acceleration(t: tEnd, pos: nextX, vel: nextV)
        let disp = nextX - target
        let energy = 0.5 * p.mass * nextV * nextV + 0.5 * p.stiffness * disp * disp

        return SpringStateSample(
            time: tEnd,
            position: nextX,
            velocity: nextV,
            acceleration: nextA,
            totalEnergy: energy
        )
    }

    /// Integrates a complete trajectory from `t = 0` (`x = 0, v = p.initialVelocity`) through `duration`.
    public static func integrate(
        parameters p: SpringParameters,
        duration: Double,
        dt: Double = 1.0 / 240.0,
        target: Double = 1.0,
        quadraticDrag: Double = 0.0,
        externalForce: (@Sendable (Double) -> Double)? = nil
    ) -> [SpringStateSample] {
        let safeDt = max(1e-4, dt)
        let steps = max(1, Int((max(0.0, duration) / safeDt).rounded()))
        var trajectory: [SpringStateSample] = []
        trajectory.reserveCapacity(steps + 1)

        var currentX = 0.0
        var currentV = p.initialVelocity
        let initAcc = (-p.stiffness * (currentX - target) - p.damping * currentV + (externalForce?(0.0) ?? 0.0)) / p.mass
        let initEnergy = 0.5 * p.mass * currentV * currentV + 0.5 * p.stiffness * target * target

        trajectory.append(
            SpringStateSample(
                time: 0.0,
                position: currentX,
                velocity: currentV,
                acceleration: initAcc,
                totalEnergy: initEnergy
            )
        )

        for i in 0..<steps {
            let t = Double(i) * safeDt
            let next = step(
                time: t,
                position: currentX,
                velocity: currentV,
                dt: safeDt,
                parameters: p,
                target: target,
                quadraticDrag: quadraticDrag,
                externalForce: externalForce
            )
            currentX = next.position
            currentV = next.velocity
            trajectory.append(next)
        }
        return trajectory
    }
}

// MARK: - Newton-Raphson Cubic Bezier Timing Curve

/// Unit-interval CSS / CoreAnimation cubic Bezier timing curve from `(0, 0)` to `(1, 1)`
/// with control points `P1 = (x1, y1)` and `P2 = (x2, y2)`.
/// Note: `y1` and `y2` may exceed `[0, 1]` to produce anticipation or overshoot curves.
public struct CubicBezierCurve: Codable, Hashable, Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        // Time abscissae x1, x2 must remain in [0, 1] so X(u) is monotonic single-valued
        self.x1 = min(max(0.0, x1), 1.0)
        self.y1 = y1
        self.x2 = min(max(0.0, x2), 1.0)
        self.y2 = y2
    }

    // Standard Presets
    public static let linear = CubicBezierCurve(x1: 0.0, y1: 0.0, x2: 1.0, y2: 1.0)
    public static let easeInOut = CubicBezierCurve(x1: 0.42, y1: 0.0, x2: 0.58, y2: 1.0)
    public static let appleSpringLike = CubicBezierCurve(x1: 0.22, y1: 1.0, x2: 0.36, y2: 1.0)
    public static let snappy = CubicBezierCurve(x1: 0.16, y1: 1.0, x2: 0.30, y2: 1.0)
    public static let fluidGlass = CubicBezierCurve(x1: 0.25, y1: 0.92, x2: 0.20, y2: 1.02)
    public static let anticipate = CubicBezierCurve(x1: 0.38, y1: -0.28, x2: 0.26, y2: 1.18)

    // Polynomial coefficients A*u^3 + B*u^2 + C*u
    @inline(__always) private var cx: Double { 3.0 * x1 }
    @inline(__always) private var bx: Double { 3.0 * (x2 - x1) - cx }
    @inline(__always) private var ax: Double { 1.0 - cx - bx }

    @inline(__always) private var cy: Double { 3.0 * y1 }
    @inline(__always) private var by: Double { 3.0 * (y2 - y1) - cy }
    @inline(__always) private var ay: Double { 1.0 - cy - by }

    @inline(__always)
    private func sampleCurveX(_ u: Double) -> Double {
        ((ax * u + bx) * u + cx) * u
    }

    @inline(__always)
    private func sampleCurveY(_ u: Double) -> Double {
        ((ay * u + by) * u + cy) * u
    }

    @inline(__always)
    private func sampleDerivativeX(_ u: Double) -> Double {
        (3.0 * ax * u + 2.0 * bx) * u + cx
    }

    @inline(__always)
    private func sampleDerivativeY(_ u: Double) -> Double {
        (3.0 * ay * u + 2.0 * by) * u + cy
    }

    /// Solves `sampleCurveX(u) == x` for `u` in `[0, 1]` using 8 Newton-Raphson iterations
    /// followed by bracketed bisection fallback when slope `dX/du` is near zero.
    public func solveParameterU(forProgress x: Double, epsilon: Double = 1e-7) -> Double {
        if x <= 0.0 { return 0.0 }
        if x >= 1.0 { return 1.0 }

        var u = x
        for _ in 0..<8 {
            let xErr = sampleCurveX(u) - x
            if abs(xErr) < epsilon {
                return u
            }
            let dX = sampleDerivativeX(u)
            if abs(dX) < 1e-6 {
                break
            }
            u -= xErr / dX
            u = min(max(0.0, u), 1.0)
        }

        // Guaranteed monotonic bisection fallback
        var low = 0.0
        var high = 1.0
        u = min(max(0.0, x), 1.0)
        for _ in 0..<24 {
            let xVal = sampleCurveX(u)
            if abs(xVal - x) < epsilon {
                return u
            }
            if x > xVal {
                low = u
            } else {
                high = u
            }
            u = 0.5 * (low + high)
        }
        return u
    }

    /// Evaluates eased output progress `y` at normalized time `progress` in `[0, 1]`.
    public func evaluate(at progress: Double) -> Double {
        if progress <= 0.0 { return 0.0 }
        if progress >= 1.0 { return 1.0 }
        let u = solveParameterU(forProgress: progress)
        return sampleCurveY(u)
    }

    /// Evaluates instantaneous rate of change `dy/dx` at normalized time `progress`.
    public func velocity(at progress: Double) -> Double {
        let clamped = min(max(0.0, progress), 1.0)
        let u = solveParameterU(forProgress: clamped)
        let dx = sampleDerivativeX(u)
        let dy = sampleDerivativeY(u)
        guard abs(dx) > 1e-7 else { return 0.0 }
        return dy / dx
    }

    public var swiftUITimingCurveString: String {
        String(format: ".timingCurve(%.2f, %.2f, %.2f, %.2f)", x1, y1, x2, y2)
    }
}

// MARK: - Multi-Track Animation Timeline & SwiftUI Code Synthesizers

public enum KeyframeInterpolationMode: Codable, Hashable, Sendable {
    case linear
    case cubicBezier(CubicBezierCurve)
    case spring(SpringParameters)
    case discreteHold
}

public struct KeyframePoint: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(time)-\(value)" }
    public var time: Double
    public var value: Double
    public var interpolation: KeyframeInterpolationMode

    public init(
        time: Double,
        value: Double,
        interpolation: KeyframeInterpolationMode = .cubicBezier(.appleSpringLike)
    ) {
        self.time = max(0.0, time)
        self.value = value
        self.interpolation = interpolation
    }
}

public struct KeyframeTrack: Codable, Hashable, Identifiable, Sendable {
    public var id: String { propertyName }
    public var propertyName: String
    public var initialValue: Double
    public var keyframes: [KeyframePoint]

    public init(
        propertyName: String,
        initialValue: Double,
        keyframes: [KeyframePoint]
    ) {
        self.propertyName = propertyName
        self.initialValue = initialValue
        self.keyframes = keyframes.sorted { $0.time < $1.time }
    }

    public var totalDuration: Double {
        keyframes.last?.time ?? 0.0
    }

    /// Evaluates interpolated track scalar at `time` (in seconds).
    public func evaluate(at time: Double) -> Double {
        guard !keyframes.isEmpty else { return initialValue }
        if time <= 0.0 { return initialValue }
        if let last = keyframes.last, time >= last.time {
            return last.value
        }

        var prevTime = 0.0
        var prevValue = initialValue

        for kf in keyframes {
            if time <= kf.time {
                let span = max(1e-6, kf.time - prevTime)
                let localProgress = min(max(0.0, (time - prevTime) / span), 1.0)
                switch kf.interpolation {
                case .discreteHold:
                    return prevValue
                case .linear:
                    return prevValue + (kf.value - prevValue) * localProgress
                case .cubicBezier(let curve):
                    let eased = curve.evaluate(at: localProgress)
                    return prevValue + (kf.value - prevValue) * eased
                case .spring(let springParams):
                    let localElapsed = time - prevTime
                    let factor = springParams.position(at: localElapsed)
                    return prevValue + (kf.value - prevValue) * factor
                }
            }
            prevTime = kf.time
            prevValue = kf.value
        }

        return keyframes.last?.value ?? initialValue
    }
}

public struct AnimationTimeline: Codable, Hashable, Sendable {
    public var name: String
    public var tracks: [KeyframeTrack]
    public var isLooping: Bool

    public init(name: String, tracks: [KeyframeTrack], isLooping: Bool = false) {
        self.name = name
        self.tracks = tracks
        self.isLooping = isLooping
    }

    public var duration: Double {
        tracks.map(\.totalDuration).max() ?? 0.0
    }

    /// Evaluates all tracks at `time` into a dictionary keyed by `propertyName`.
    public func evaluateSnapshot(at time: Double) -> [String: Double] {
        let effectiveTime: Double
        if isLooping && duration > 1e-6 {
            effectiveTime = time.truncatingRemainder(dividingBy: duration)
        } else {
            effectiveTime = max(0.0, time)
        }

        var snapshot: [String: Double] = [:]
        for track in tracks {
            snapshot[track.propertyName] = track.evaluate(at: effectiveTime)
        }
        return snapshot
    }

    // MARK: Production SwiftUI Animation Code Synthesizers

    /// Synthesizes SwiftUI `.animation(.spring(...))` modifier snippet from `SpringParameters`.
    public static func synthesizeSpringModifier(
        parameters: SpringParameters,
        triggerIdentifier: String = "isExpanded"
    ) -> String {
        let bounce = parameters.perceptualBounce
        let dur = parameters.perceptualDuration
        return String(
            format: ".animation(.spring(duration: %.2f, bounce: %.2f), value: %@)",
            dur,
            bounce,
            triggerIdentifier
        )
    }

    /// Synthesizes a multi-step SwiftUI `PhaseAnimator` container view.
    public static func synthesizePhaseAnimatorCode(
        structName: String = "LiquidGlassPhaseBanner",
        spring: SpringParameters = .snappy
    ) -> String {
        let dur = String(format: "%.2f", spring.perceptualDuration)
        let bounce = String(format: "%.2f", spring.perceptualBounce)
        return """
        import SwiftUI

        enum \(structName)Phase: CaseIterable {
            case resting
            case elevated
            case highlighted

            var scale: CGFloat {
                switch self {
                case .resting: 1.0
                case .elevated: 1.035
                case .highlighted: 1.015
                }
            }

            var yOffset: CGFloat {
                switch self {
                case .resting: 0
                case .elevated: -6
                case .highlighted: -2
                }
            }

            var glowOpacity: Double {
                switch self {
                case .resting: 0.25
                case .elevated: 0.72
                case .highlighted: 0.48
                }
            }
        }

        struct \(structName): View {
            @State private var triggerCount = 0

            var body: some View {
                PhaseAnimator(\(structName)Phase.allCases, trigger: triggerCount) { phase in
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .symbolEffect(.bounce, value: triggerCount)
                        Text("ChiefKit Physics Ready")
                            .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(phase.glowOpacity), lineWidth: 1)
                    )
                    .scaleEffect(phase.scale)
                    .offset(y: phase.yOffset)
                } animation: { _ in
                    .spring(duration: \(dur), bounce: \(bounce))
                }
                .onTapGesture {
                    triggerCount += 1
                }
            }
        }
        """
    }

    /// Synthesizes a complete SwiftUI `KeyframeAnimator` view directly from this `AnimationTimeline`.
    public func synthesizeKeyframeAnimatorCode(structName: String = "TimelineAnimatedCard") -> String {
        let safeTracks = tracks.isEmpty
            ? [
                KeyframeTrack(
                    propertyName: "scale",
                    initialValue: 1.0,
                    keyframes: [
                        KeyframePoint(time: 0.18, value: 1.06, interpolation: .spring(.snappy)),
                        KeyframePoint(time: 0.45, value: 1.0, interpolation: .spring(.smooth))
                    ]
                )
            ]
            : tracks

        let valueProps = safeTracks.map { t in
            "        var \(t.propertyName): Double = \(String(format: "%.3f", t.initialValue))"
        }.joined(separator: "\n")

        let trackBlocks = safeTracks.map { track in
            var prevT = 0.0
            let kfLines = track.keyframes.map { kf -> String in
                let segDur = max(0.01, kf.time - prevT)
                prevT = kf.time
                let valStr = String(format: "%.3f", kf.value)
                let durStr = String(format: "%.2f", segDur)
                switch kf.interpolation {
                case .linear:
                    return "                    LinearKeyframe(\(valStr), duration: \(durStr))"
                case .cubicBezier:
                    return "                    CubicKeyframe(\(valStr), duration: \(durStr))"
                case .spring(let sp):
                    let bStr = String(format: "%.2f", sp.perceptualBounce)
                    return "                    SpringKeyframe(\(valStr), duration: \(durStr), spring: .spring(duration: \(durStr), bounce: \(bStr)))"
                case .discreteHold:
                    return "                    MoveKeyframe(\(valStr))"
                }
            }.joined(separator: "\n")

            return """
                            KeyframeTrack(\\.self.\(track.propertyName)) {
            \(kfLines)
                            }
            """
        }.joined(separator: "\n")

        let firstProp = safeTracks[0].propertyName

        return """
        import SwiftUI

        struct \(structName): View {
            struct AnimationValues {
        \(valueProps)
            }

            @State private var playTrigger = 0

            var body: some View {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 280, height: 148)
                    .overlay(
                        Text("\(name)")
                            .font(.headline)
                    )
                    .keyframeAnimator(
                        initialValue: AnimationValues(),
                        trigger: playTrigger\(isLooping ? ",\n                repeating: true" : "")
                    ) { content, values in
                        content
                            .scaleEffect(values.\(firstProp) > 0 ? values.\(firstProp) : 1.0)
                    } keyframes: { _ in
        \(trackBlocks)
                    }
                    .onTapGesture {
                        playTrigger += 1
                    }
            }
        }
        """
    }
}
