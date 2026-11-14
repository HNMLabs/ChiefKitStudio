#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - 2D Vector Geometry Primitives

public struct SVGPoint2D: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = SVGPoint2D(x: 0.0, y: 0.0)

    public func distance(to other: SVGPoint2D) -> Double {
        hypot(other.x - x, other.y - y)
    }

    public func interpolated(to other: SVGPoint2D, t: Double) -> SVGPoint2D {
        SVGPoint2D(x: x + (other.x - x) * t, y: y + (other.y - y) * t)
    }
}

public struct SVGRect2D: Codable, Hashable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public var width: Double { max(0.0, maxX - minX) }
    public var height: Double { max(0.0, maxY - minY) }
    public var midX: Double { 0.5 * (minX + maxX) }
    public var midY: Double { 0.5 * (minY + maxY) }

    public var asCanvasFrame: CanvasFrame {
        CanvasFrame(x: minX, y: minY, width: width, height: height)
    }

    public static let empty = SVGRect2D(minX: 0, minY: 0, maxX: 0, maxY: 0)
}

public struct SVGTriangle2D: Codable, Hashable, Sendable {
    public let a: SVGPoint2D
    public let b: SVGPoint2D
    public let c: SVGPoint2D

    public init(a: SVGPoint2D, b: SVGPoint2D, c: SVGPoint2D) {
        self.a = a
        self.b = b
        self.c = c
    }

    public var signedArea: Double {
        0.5 * ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y))
    }
}

// MARK: - SVG Path Commands & Normalized Segments

public enum SVGPathCommand: Codable, Hashable, Sendable {
    case moveTo(relative: Bool, x: Double, y: Double)
    case lineTo(relative: Bool, x: Double, y: Double)
    case horizontalLineTo(relative: Bool, x: Double)
    case verticalLineTo(relative: Bool, y: Double)
    case cubicBezier(relative: Bool, x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double)
    case smoothCubicBezier(relative: Bool, x2: Double, y2: Double, x: Double, y: Double)
    case quadraticBezier(relative: Bool, x1: Double, y1: Double, x: Double, y: Double)
    case smoothQuadraticBezier(relative: Bool, x: Double, y: Double)
    case ellipticalArc(
        relative: Bool,
        rx: Double,
        ry: Double,
        xAxisRotation: Double,
        largeArcFlag: Bool,
        sweepFlag: Bool,
        x: Double,
        y: Double
    )
    case closePath
}

public enum SVGNormalizedSegment: Codable, Hashable, Sendable {
    case moveTo(SVGPoint2D)
    case lineTo(SVGPoint2D)
    case cubicTo(control1: SVGPoint2D, control2: SVGPoint2D, end: SVGPoint2D)
    case closeSubpath
}

public enum SVGPathParseError: Error, LocalizedError, Equatable, Sendable {
    case unexpectedToken(String)
    case insufficientParameters(command: String, expected: Int)

    public var errorDescription: String? {
        switch self {
        case .unexpectedToken(let tok):
            return "Unexpected token '\(tok)' in SVG path data."
        case .insufficientParameters(let cmd, let expected):
            return "SVG command '\(cmd)' requires \(expected) numeric parameters."
        }
    }
}

// MARK: - Parsed SVG Path Document

public struct ParsedSVGPath: Codable, Hashable, Sendable {
    public let rawData: String
    public let commands: [SVGPathCommand]
    public let segments: [SVGNormalizedSegment]

    public init(rawData: String, commands: [SVGPathCommand], segments: [SVGNormalizedSegment]) {
        self.rawData = rawData
        self.commands = commands
        self.segments = segments
    }

    /// Computes exact analytical bounding box across all line and cubic Bezier segments
    /// by solving `dB/dt = 0` extrema (`3a*t² + 2b*t + c = 0`) on `(0, 1)`.
    public var exactBoundingBox: SVGRect2D {
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        var hasPoint = false

        func include(_ p: SVGPoint2D) {
            hasPoint = true
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }

        func cubicValue(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double, t: Double) -> Double {
            let mt = 1.0 - t
            return mt * mt * mt * p0
                + 3.0 * mt * mt * t * p1
                + 3.0 * mt * t * t * p2
                + t * t * t * p3
        }

        func cubicExtrema1D(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) -> [Double] {
            // Derivative coefficients of cubic Bezier: 3 * (a*t^2 + b*t + c) = 0
            let a = -p0 + 3.0 * p1 - 3.0 * p2 + p3
            let b = 2.0 * (p0 - 2.0 * p1 + p2)
            let c = p1 - p0
            var roots: [Double] = []

            if abs(a) < 1e-12 {
                if abs(b) > 1e-12 {
                    let t = -c / b
                    if t > 0.0 && t < 1.0 { roots.append(t) }
                }
            } else {
                let disc = b * b - 4.0 * a * c
                if disc >= 0.0 {
                    let s = sqrt(disc)
                    let t1 = (-b - s) / (2.0 * a)
                    let t2 = (-b + s) / (2.0 * a)
                    if t1 > 0.0 && t1 < 1.0 { roots.append(t1) }
                    if t2 > 0.0 && t2 < 1.0 { roots.append(t2) }
                }
            }
            return roots.map { cubicValue(p0, p1, p2, p3, t: $0) }
        }

        var current = SVGPoint2D.zero
        var subpathStart = SVGPoint2D.zero

        for seg in segments {
            switch seg {
            case .moveTo(let p):
                current = p
                subpathStart = p
                include(p)
            case .lineTo(let p):
                include(current)
                include(p)
                current = p
            case .cubicTo(let c1, let c2, let end):
                include(current)
                include(end)
                for ex in cubicExtrema1D(current.x, c1.x, c2.x, end.x) {
                    minX = min(minX, ex)
                    maxX = max(maxX, ex)
                }
                for ey in cubicExtrema1D(current.y, c1.y, c2.y, end.y) {
                    minY = min(minY, ey)
                    maxY = max(maxY, ey)
                }
                current = end
            case .closeSubpath:
                current = subpathStart
            }
        }

        guard hasPoint else { return .empty }
        return SVGRect2D(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }

    /// Estimates total geometric path arc length using 5-point Gauss-Legendre quadrature on each cubic Bezier.
    public var totalPathLength: Double {
        let glNodes: [Double] = [
            0.5 * (1.0 - 0.906179845938664),
            0.5 * (1.0 - 0.538469310105683),
            0.5,
            0.5 * (1.0 + 0.538469310105683),
            0.5 * (1.0 + 0.906179845938664)
        ]
        let glWeights: [Double] = [
            0.5 * 0.236926885056189,
            0.5 * 0.478628670499366,
            0.5 * 0.568888888888889,
            0.5 * 0.478628670499366,
            0.5 * 0.236926885056189
        ]

        func cubicArcLength(_ p0: SVGPoint2D, _ p1: SVGPoint2D, _ p2: SVGPoint2D, _ p3: SVGPoint2D) -> Double {
            var sum = 0.0
            for i in 0..<5 {
                let t = glNodes[i]
                let mt = 1.0 - t
                let dx = 3.0 * mt * mt * (p1.x - p0.x)
                    + 6.0 * mt * t * (p2.x - p1.x)
                    + 3.0 * t * t * (p3.x - p2.x)
                let dy = 3.0 * mt * mt * (p1.y - p0.y)
                    + 6.0 * mt * t * (p2.y - p1.y)
                    + 3.0 * t * t * (p3.y - p2.y)
                sum += glWeights[i] * hypot(dx, dy)
            }
            return sum
        }

        var length = 0.0
        var current = SVGPoint2D.zero
        var subpathStart = SVGPoint2D.zero

        for seg in segments {
            switch seg {
            case .moveTo(let p):
                current = p
                subpathStart = p
            case .lineTo(let p):
                length += current.distance(to: p)
                current = p
            case .cubicTo(let c1, let c2, let end):
                length += cubicArcLength(current, c1, c2, end)
                current = end
            case .closeSubpath:
                length += current.distance(to: subpathStart)
                current = subpathStart
            }
        }
        return length
    }

    /// Normalizes all path coordinates into unit square `[0, 1] x [0, 1]`.
    public func normalizedToUnitSquare(preserveAspectRatio: Bool = true) -> ParsedSVGPath {
        let bbox = exactBoundingBox
        guard bbox.width > 1e-9 || bbox.height > 1e-9 else { return self }

        let scaleX: Double
        let scaleY: Double
        let offsetX: Double
        let offsetY: Double

        if preserveAspectRatio {
            let maxDim = max(bbox.width, bbox.height)
            let s = maxDim > 1e-9 ? (1.0 / maxDim) : 1.0
            scaleX = s
            scaleY = s
            offsetX = (1.0 - bbox.width * s) * 0.5 - bbox.minX * s
            offsetY = (1.0 - bbox.height * s) * 0.5 - bbox.minY * s
        } else {
            scaleX = bbox.width > 1e-9 ? (1.0 / bbox.width) : 1.0
            scaleY = bbox.height > 1e-9 ? (1.0 / bbox.height) : 1.0
            offsetX = -bbox.minX * scaleX
            offsetY = -bbox.minY * scaleY
        }

        func mapPoint(_ p: SVGPoint2D) -> SVGPoint2D {
            SVGPoint2D(x: p.x * scaleX + offsetX, y: p.y * scaleY + offsetY)
        }

        let mappedSegments: [SVGNormalizedSegment] = segments.map { seg in
            switch seg {
            case .moveTo(let p):
                return .moveTo(mapPoint(p))
            case .lineTo(let p):
                return .lineTo(mapPoint(p))
            case .cubicTo(let c1, let c2, let end):
                return .cubicTo(control1: mapPoint(c1), control2: mapPoint(c2), end: mapPoint(end))
            case .closeSubpath:
                return .closeSubpath
            }
        }

        return ParsedSVGPath(rawData: rawData, commands: commands, segments: mappedSegments)
    }

    /// Flattens curves via recursive De Casteljau subdivision and tessellates closed subpaths into triangles
    /// using deterministic 2D ear-clipping.
    public func tessellatePolygons(flatness: Double = 0.35) -> [SVGTriangle2D] {
        let polylines = flattenToSubpaths(flatness: flatness)
        var triangles: [SVGTriangle2D] = []
        for poly in polylines where poly.count >= 3 {
            triangles.append(contentsOf: SVGPathEngine.earClipPolygon(poly))
        }
        return triangles
    }

    public func flattenToSubpaths(flatness: Double = 0.35) -> [[SVGPoint2D]] {
        var subpaths: [[SVGPoint2D]] = []
        var active: [SVGPoint2D] = []
        var current = SVGPoint2D.zero

        func subdivideCubic(
            _ p0: SVGPoint2D,
            _ p1: SVGPoint2D,
            _ p2: SVGPoint2D,
            _ p3: SVGPoint2D,
            depth: Int
        ) {
            let ux = 3.0 * p1.x - 2.0 * p0.x - p3.x
            let uy = 3.0 * p1.y - 2.0 * p0.y - p3.y
            let vx = 3.0 * p2.x - 2.0 * p3.x - p0.x
            let vy = 3.0 * p2.y - 2.0 * p3.y - p0.y
            let errSq = max(ux * ux, vx * vx) + max(uy * uy, vy * vy)

            if depth >= 8 || errSq <= 16.0 * flatness * flatness {
                active.append(p3)
                return
            }

            let m01 = p0.interpolated(to: p1, t: 0.5)
            let m12 = p1.interpolated(to: p2, t: 0.5)
            let m23 = p2.interpolated(to: p3, t: 0.5)
            let m012 = m01.interpolated(to: m12, t: 0.5)
            let m123 = m12.interpolated(to: m23, t: 0.5)
            let mid = m012.interpolated(to: m123, t: 0.5)

            subdivideCubic(p0, m01, m012, mid, depth: depth + 1)
            subdivideCubic(mid, m123, m23, p3, depth: depth + 1)
        }

        for seg in segments {
            switch seg {
            case .moveTo(let p):
                if active.count >= 2 { subpaths.append(active) }
                active = [p]
                current = p
            case .lineTo(let p):
                if active.isEmpty { active.append(current) }
                if current.distance(to: p) > 1e-6 {
                    active.append(p)
                }
                current = p
            case .cubicTo(let c1, let c2, let end):
                if active.isEmpty { active.append(current) }
                subdivideCubic(current, c1, c2, end, depth: 0)
                current = end
            case .closeSubpath:
                if let first = active.first, let last = active.last, first.distance(to: last) < 1e-5 {
                    active.removeLast()
                }
                if active.count >= 2 {
                    subpaths.append(active)
                }
                current = active.first ?? current
                active = []
            }
        }
        if active.count >= 2 {
            subpaths.append(active)
        }
        return subpaths
    }

    /// Synthesizes a standalone, normalized SwiftUI `Shape` struct reproducing this vector path.
    public func emitSwiftUIShape(
        structName: String = "ChiefKitCustomVectorShape",
        preserveAspectRatio: Bool = true
    ) -> String {
        let unitPath = normalizedToUnitSquare(preserveAspectRatio: preserveAspectRatio)
        let fmt = { (v: Double) in String(format: "%.4f", v) }

        let lines: [String] = unitPath.segments.map { seg in
            switch seg {
            case .moveTo(let p):
                return "        path.move(to: CGPoint(x: ox + s * \(fmt(p.x)), y: oy + s * \(fmt(p.y))))"
            case .lineTo(let p):
                return "        path.addLine(to: CGPoint(x: ox + s * \(fmt(p.x)), y: oy + s * \(fmt(p.y))))"
            case .cubicTo(let c1, let c2, let end):
                return """
                        path.addCurve(
                            to: CGPoint(x: ox + s * \(fmt(end.x)), y: oy + s * \(fmt(end.y))),
                            control1: CGPoint(x: ox + s * \(fmt(c1.x)), y: oy + s * \(fmt(c1.y))),
                            control2: CGPoint(x: ox + s * \(fmt(c2.x)), y: oy + s * \(fmt(c2.y)))
                        )
                """
            case .closeSubpath:
                return "        path.closeSubpath()"
            }
        }

        return """
        import SwiftUI

        public struct \(structName): Shape, Sendable {
            public init() {}

            public func path(in rect: CGRect) -> Path {
                var path = Path()
                let s = min(rect.width, rect.height)
                let ox = rect.minX + (rect.width - s) * 0.5
                let oy = rect.minY + (rect.height - s) * 0.5
        \(lines.joined(separator: "\n"))
                return path
            }
        }
        """
    }
}

// MARK: - SVGPathEngine Parser, Arc Parameterizer & Ear-Clipper

public enum SVGPathEngine {

    private static let commandLetters: Set<Character> = [
        "M", "m", "L", "l", "H", "h", "V", "v",
        "C", "c", "S", "s", "Q", "q", "T", "t",
        "A", "a", "Z", "z"
    ]

    /// Parses an SVG `d` attribute string into `ParsedSVGPath` supporting all 20 absolute & relative SVG path commands.
    public static func parse(_ dAttribute: String) throws -> ParsedSVGPath {
        let chars = Array(dAttribute)
        let count = chars.count
        var idx = 0

        func skipSeparators() {
            while idx < count {
                let c = chars[idx]
                if c == " " || c == "\t" || c == "\n" || c == "\r" || c == "," {
                    idx += 1
                } else {
                    break
                }
            }
        }

        func scanNumber() throws -> Double {
            skipSeparators()
            guard idx < count else {
                throw SVGPathParseError.unexpectedToken("EOF")
            }
            let start = idx
            if chars[idx] == "+" || chars[idx] == "-" {
                idx += 1
            }
            var hasDigits = false
            while idx < count && chars[idx].isASCII && chars[idx].isNumber {
                hasDigits = true
                idx += 1
            }
            if idx < count && chars[idx] == "." {
                idx += 1
                while idx < count && chars[idx].isASCII && chars[idx].isNumber {
                    hasDigits = true
                    idx += 1
                }
            }
            guard hasDigits else {
                throw SVGPathParseError.unexpectedToken(String(chars[start]))
            }
            if idx < count && (chars[idx] == "e" || chars[idx] == "E") {
                let expPos = idx
                idx += 1
                if idx < count && (chars[idx] == "+" || chars[idx] == "-") {
                    idx += 1
                }
                var expDigits = false
                while idx < count && chars[idx].isASCII && chars[idx].isNumber {
                    expDigits = true
                    idx += 1
                }
                if !expDigits {
                    idx = expPos
                }
            }
            let slice = String(chars[start..<idx])
            guard let val = Double(slice) else {
                throw SVGPathParseError.unexpectedToken(slice)
            }
            return val
        }

        func scanArcFlag() throws -> Bool {
            skipSeparators()
            guard idx < count else {
                throw SVGPathParseError.insufficientParameters(command: "A", expected: 7)
            }
            let c = chars[idx]
            if c == "0" {
                idx += 1
                return false
            } else if c == "1" {
                idx += 1
                return true
            }
            throw SVGPathParseError.unexpectedToken(String(c))
        }

        func hasNextParameter() -> Bool {
            skipSeparators()
            guard idx < count else { return false }
            let c = chars[idx]
            return !commandLetters.contains(c)
        }

        var commands: [SVGPathCommand] = []
        var activeCommand: Character?

        while true {
            skipSeparators()
            if idx >= count { break }

            let ch = chars[idx]
            if commandLetters.contains(ch) {
                activeCommand = ch
                idx += 1
                if ch == "Z" || ch == "z" {
                    commands.append(.closePath)
                    continue
                }
            }

            guard let cmd = activeCommand else {
                throw SVGPathParseError.unexpectedToken(String(ch))
            }

            let isRel = cmd.isLowercase
            switch cmd.uppercased() {
            case "M":
                let x = try scanNumber()
                let y = try scanNumber()
                commands.append(.moveTo(relative: isRel, x: x, y: y))
                // Subsequent coordinate pairs after M/m are treated as implicit L/l
                activeCommand = isRel ? "l" : "L"
            case "L":
                repeat {
                    let x = try scanNumber()
                    let y = try scanNumber()
                    commands.append(.lineTo(relative: isRel, x: x, y: y))
                } while hasNextParameter()
            case "H":
                repeat {
                    let x = try scanNumber()
                    commands.append(.horizontalLineTo(relative: isRel, x: x))
                } while hasNextParameter()
            case "V":
                repeat {
                    let y = try scanNumber()
                    commands.append(.verticalLineTo(relative: isRel, y: y))
                } while hasNextParameter()
            case "C":
                repeat {
                    let x1 = try scanNumber()
                    let y1 = try scanNumber()
                    let x2 = try scanNumber()
                    let y2 = try scanNumber()
                    let x = try scanNumber()
                    let y = try scanNumber()
                    commands.append(.cubicBezier(relative: isRel, x1: x1, y1: y1, x2: x2, y2: y2, x: x, y: y))
                } while hasNextParameter()
            case "S":
                repeat {
                    let x2 = try scanNumber()
                    let y2 = try scanNumber()
                    let x = try scanNumber()
                    let y = try scanNumber()
                    commands.append(.smoothCubicBezier(relative: isRel, x2: x2, y2: y2, x: x, y: y))
                } while hasNextParameter()
            case "Q":
                repeat {
                    let x1 = try scanNumber()
                    let y1 = try scanNumber()
                    let x = try scanNumber()
                    let y = try scanNumber()
                    commands.append(.quadraticBezier(relative: isRel, x1: x1, y1: y1, x: x, y: y))
                } while hasNextParameter()
            case "T":
                repeat {
                    let x = try scanNumber()
                    let y = try scanNumber()
                    commands.append(.smoothQuadraticBezier(relative: isRel, x: x, y: y))
                } while hasNextParameter()
            case "A":
                repeat {
                    let rx = try scanNumber()
                    let ry = try scanNumber()
                    let rot = try scanNumber()
                    let largeArc = try scanArcFlag()
                    let sweep = try scanArcFlag()
                    let x = try scanNumber()
                    let y = try scanNumber()
                    commands.append(
                        .ellipticalArc(
                            relative: isRel,
                            rx: rx,
                            ry: ry,
                            xAxisRotation: rot,
                            largeArcFlag: largeArc,
                            sweepFlag: sweep,
                            x: x,
                            y: y
                        )
                    )
                } while hasNextParameter()
            default:
                break
            }
        }

        let normalized = normalizeCommands(commands)
        return ParsedSVGPath(rawData: dAttribute, commands: commands, segments: normalized)
    }

    /// Converts all relative/shorthand/quadratic/arc commands into absolute `.moveTo`, `.lineTo`, `.cubicTo`, `.closeSubpath`.
    public static func normalizeCommands(_ commands: [SVGPathCommand]) -> [SVGNormalizedSegment] {
        var out: [SVGNormalizedSegment] = []
        var cur = SVGPoint2D.zero
        var subpathOrigin = SVGPoint2D.zero
        var lastCubicControl: SVGPoint2D?
        var lastQuadControl: SVGPoint2D?

        for cmd in commands {
            switch cmd {
            case .moveTo(let rel, let x, let y):
                let p = rel ? SVGPoint2D(x: cur.x + x, y: cur.y + y) : SVGPoint2D(x: x, y: y)
                out.append(.moveTo(p))
                cur = p
                subpathOrigin = p
                lastCubicControl = nil
                lastQuadControl = nil

            case .lineTo(let rel, let x, let y):
                let p = rel ? SVGPoint2D(x: cur.x + x, y: cur.y + y) : SVGPoint2D(x: x, y: y)
                out.append(.lineTo(p))
                cur = p
                lastCubicControl = nil
                lastQuadControl = nil

            case .horizontalLineTo(let rel, let x):
                let p = SVGPoint2D(x: rel ? cur.x + x : x, y: cur.y)
                out.append(.lineTo(p))
                cur = p
                lastCubicControl = nil
                lastQuadControl = nil

            case .verticalLineTo(let rel, let y):
                let p = SVGPoint2D(x: cur.x, y: rel ? cur.y + y : y)
                out.append(.lineTo(p))
                cur = p
                lastCubicControl = nil
                lastQuadControl = nil

            case .cubicBezier(let rel, let x1, let y1, let x2, let y2, let x, let y):
                let c1 = rel ? SVGPoint2D(x: cur.x + x1, y: cur.y + y1) : SVGPoint2D(x: x1, y: y1)
                let c2 = rel ? SVGPoint2D(x: cur.x + x2, y: cur.y + y2) : SVGPoint2D(x: x2, y: y2)
                let end = rel ? SVGPoint2D(x: cur.x + x, y: cur.y + y) : SVGPoint2D(x: x, y: y)
                out.append(.cubicTo(control1: c1, control2: c2, end: end))
                lastCubicControl = c2
                lastQuadControl = nil
                cur = end

            case .smoothCubicBezier(let rel, let x2, let y2, let x, let y):
                let c1: SVGPoint2D
                if let prevC2 = lastCubicControl {
                    c1 = SVGPoint2D(x: 2.0 * cur.x - prevC2.x, y: 2.0 * cur.y - prevC2.y)
                } else {
                    c1 = cur
                }
                let c2 = rel ? SVGPoint2D(x: cur.x + x2, y: cur.y + y2) : SVGPoint2D(x: x2, y: y2)
                let end = rel ? SVGPoint2D(x: cur.x + x, y: cur.y + y) : SVGPoint2D(x: x, y: y)
                out.append(.cubicTo(control1: c1, control2: c2, end: end))
                lastCubicControl = c2
                lastQuadControl = nil
                cur = end

            case .quadraticBezier(let rel, let x1, let y1, let x, let y):
                let qp = rel ? SVGPoint2D(x: cur.x + x1, y: cur.y + y1) : SVGPoint2D(x: x1, y: y1)
                let end = rel ? SVGPoint2D(x: cur.x + x, y: cur.y + y) : SVGPoint2D(x: x, y: y)
                let c1 = SVGPoint2D(x: cur.x + (2.0 / 3.0) * (qp.x - cur.x), y: cur.y + (2.0 / 3.0) * (qp.y - cur.y))
                let c2 = SVGPoint2D(x: end.x + (2.0 / 3.0) * (qp.x - end.x), y: end.y + (2.0 / 3.0) * (qp.y - end.y))
                out.append(.cubicTo(control1: c1, control2: c2, end: end))
                lastQuadControl = qp
                lastCubicControl = nil
                cur = end

            case .smoothQuadraticBezier(let rel, let x, let y):
                let qp: SVGPoint2D
                if let prevQ = lastQuadControl {
                    qp = SVGPoint2D(x: 2.0 * cur.x - prevQ.x, y: 2.0 * cur.y - prevQ.y)
                } else {
                    qp = cur
                }
                let end = rel ? SVGPoint2D(x: cur.x + x, y: cur.y + y) : SVGPoint2D(x: x, y: y)
                let c1 = SVGPoint2D(x: cur.x + (2.0 / 3.0) * (qp.x - cur.x), y: cur.y + (2.0 / 3.0) * (qp.y - cur.y))
                let c2 = SVGPoint2D(x: end.x + (2.0 / 3.0) * (qp.x - end.x), y: end.y + (2.0 / 3.0) * (qp.y - end.y))
                out.append(.cubicTo(control1: c1, control2: c2, end: end))
                lastQuadControl = qp
                lastCubicControl = nil
                cur = end

            case .ellipticalArc(let rel, let rx, let ry, let rot, let largeArc, let sweep, let x, let y):
                let end = rel ? SVGPoint2D(x: cur.x + x, y: cur.y + y) : SVGPoint2D(x: x, y: y)
                let cubics = approximateArcWithCubics(
                    from: cur,
                    to: end,
                    rx: abs(rx),
                    ry: abs(ry),
                    xAxisRotationDegrees: rot,
                    largeArcFlag: largeArc,
                    sweepFlag: sweep
                )
                out.append(contentsOf: cubics)
                cur = end
                lastCubicControl = nil
                lastQuadControl = nil

            case .closePath:
                out.append(.closeSubpath)
                cur = subpathOrigin
                lastCubicControl = nil
                lastQuadControl = nil
            }
        }

        return out
    }

    /// W3C SVG 1.1 F.6.5 / F.6.6 endpoint-to-center arc conversion into multi-quadrant cubic Beziers.
    private static func approximateArcWithCubics(
        from p1: SVGPoint2D,
        to p2: SVGPoint2D,
        rx rawRx: Double,
        ry rawRy: Double,
        xAxisRotationDegrees: Double,
        largeArcFlag: Bool,
        sweepFlag: Bool
    ) -> [SVGNormalizedSegment] {
        if p1.distance(to: p2) < 1e-9 { return [] }
        if rawRx < 1e-9 || rawRy < 1e-9 { return [.lineTo(p2)] }

        let phi = xAxisRotationDegrees * .pi / 180.0
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        let dx2 = 0.5 * (p1.x - p2.x)
        let dy2 = 0.5 * (p1.y - p2.y)
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        var rx = rawRx
        var ry = rawRy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1.0 {
            let s = sqrt(lambda)
            rx *= s
            ry *= s
        }

        let rxSq = rx * rx
        let rySq = ry * ry
        let x1pSq = x1p * x1p
        let y1pSq = y1p * y1p

        let num = max(0.0, rxSq * rySq - rxSq * y1pSq - rySq * x1pSq)
        let den = max(1e-12, rxSq * y1pSq + rySq * x1pSq)
        let signFactor = (largeArcFlag == sweepFlag) ? -1.0 : 1.0
        let coef = signFactor * sqrt(num / den)

        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * (-ry * x1p / rx)

        let cx = cosPhi * cxp - sinPhi * cyp + 0.5 * (p1.x + p2.x)
        let cy = sinPhi * cxp + cosPhi * cyp + 0.5 * (p1.y + p2.y)

        func vectorAngle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let mag = max(1e-12, hypot(ux, uy) * hypot(vx, vy))
            let cosVal = min(max(-1.0, dot / mag), 1.0)
            let ang = acos(cosVal)
            return (ux * vy - uy * vx) < 0 ? -ang : ang
        }

        let vx1 = (x1p - cxp) / rx
        let vy1 = (y1p - cyp) / ry
        let vx2 = (-x1p - cxp) / rx
        let vy2 = (-y1p - cyp) / ry

        let theta1 = vectorAngle(1.0, 0.0, vx1, vy1)
        var dTheta = vectorAngle(vx1, vy1, vx2, vy2)
        if !sweepFlag && dTheta > 0 {
            dTheta -= 2.0 * .pi
        } else if sweepFlag && dTheta < 0 {
            dTheta += 2.0 * .pi
        }

        let segCount = max(1, Int(ceil(abs(dTheta) / (.pi * 0.5))))
        let stepAngle = dTheta / Double(segCount)
        let alpha = (4.0 / 3.0) * tan(0.25 * stepAngle)

        func ellipsePoint(angle: Double) -> SVGPoint2D {
            let ex = rx * cos(angle)
            let ey = ry * sin(angle)
            return SVGPoint2D(
                x: cosPhi * ex - sinPhi * ey + cx,
                y: sinPhi * ex + cosPhi * ey + cy
            )
        }

        func ellipseDerivative(angle: Double) -> SVGPoint2D {
            let dex = -rx * sin(angle)
            let dey = ry * cos(angle)
            return SVGPoint2D(
                x: cosPhi * dex - sinPhi * dey,
                y: sinPhi * dex + cosPhi * dey
            )
        }

        var segments: [SVGNormalizedSegment] = []
        for i in 0..<segCount {
            let a1 = theta1 + Double(i) * stepAngle
            let a2 = a1 + stepAngle
            let startPt = ellipsePoint(angle: a1)
            let endPt = ellipsePoint(angle: a2)
            let d1 = ellipseDerivative(angle: a1)
            let d2 = ellipseDerivative(angle: a2)

            let cp1 = SVGPoint2D(x: startPt.x + alpha * d1.x, y: startPt.y + alpha * d1.y)
            let cp2 = SVGPoint2D(x: endPt.x - alpha * d2.x, y: endPt.y - alpha * d2.y)
            segments.append(.cubicTo(control1: cp1, control2: cp2, end: endPt))
        }
        return segments
    }

    /// Deterministic 2D ear-clipping triangulation for simple concave/convex polygons.
    public static func earClipPolygon(_ vertices: [SVGPoint2D]) -> [SVGTriangle2D] {
        guard vertices.count >= 3 else { return [] }

        // Compute signed polygon area via shoelace formula to orient indices counter-clockwise
        var area2 = 0.0
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            area2 += vertices[i].x * vertices[j].y - vertices[j].x * vertices[i].y
        }

        var indices = area2 >= 0
            ? Array(0..<vertices.count)
            : Array((0..<vertices.count).reversed())

        func cross2D(_ a: SVGPoint2D, _ b: SVGPoint2D, _ c: SVGPoint2D) -> Double {
            (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }

        func pointInTriangle(_ p: SVGPoint2D, _ a: SVGPoint2D, _ b: SVGPoint2D, _ c: SVGPoint2D) -> Bool {
            let c1 = cross2D(a, b, p)
            let c2 = cross2D(b, c, p)
            let c3 = cross2D(c, a, p)
            return c1 >= -1e-9 && c2 >= -1e-9 && c3 >= -1e-9
        }

        var result: [SVGTriangle2D] = []
        var guardCounter = 0
        let maxIterations = vertices.count * vertices.count + 16

        while indices.count > 3 && guardCounter < maxIterations {
            guardCounter += 1
            var earFound = false
            let n = indices.count

            for i in 0..<n {
                let prevIdx = indices[(i + n - 1) % n]
                let currIdx = indices[i]
                let nextIdx = indices[(i + 1) % n]

                let a = vertices[prevIdx]
                let b = vertices[currIdx]
                let c = vertices[nextIdx]

                if cross2D(a, b, c) <= 1e-9 {
                    continue // Reflex or collinear vertex
                }

                var containsOther = false
                for j in 0..<n {
                    let testIdx = indices[j]
                    if testIdx == prevIdx || testIdx == currIdx || testIdx == nextIdx { continue }
                    if pointInTriangle(vertices[testIdx], a, b, c) {
                        containsOther = true
                        break
                    }
                }

                if !containsOther {
                    result.append(SVGTriangle2D(a: a, b: b, c: c))
                    indices.remove(at: i)
                    earFound = true
                    break
                }
            }

            if !earFound {
                // Fallback fan step for self-touching / degenerate vertices
                let a = vertices[indices[0]]
                let b = vertices[indices[1]]
                let c = vertices[indices[2]]
                result.append(SVGTriangle2D(a: a, b: b, c: c))
                indices.remove(at: 1)
            }
        }

        if indices.count == 3 {
            result.append(
                SVGTriangle2D(
                    a: vertices[indices[0]],
                    b: vertices[indices[1]],
                    c: vertices[indices[2]]
                )
            )
        }
        return result
    }
}

// MARK: - 42 Built-In ChiefKit Vector Icon SVG Paths (24x24 ViewBox)

public enum ChiefKitVectorIcon: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case sparklesAI
    case liquidGlassCube
    case springOscillator
    case colorWheelOKLCH
    case layoutGrid12
    case artboardDevices
    case commandPalette
    case passkeyShield
    case biometricKey
    case neuralChip
    case tokenCompiler
    case gitBranchMerge
    case unifiedDiff
    case terminalPrompt
    case chartSparkline
    case chartDonutGauge
    case chartCandlestick
    case kanbanColumns
    case timelineClock
    case creditCardChip
    case currencySwap
    case ledgerBook
    case escrowLock
    case spatialVisionGoggles
    case depthLayers3D
    case waveformAudio
    case videoChapterPlay
    case microphonePulse
    case searchMagnifier
    case filterSliders
    case bellNotification
    case checkBadgeVerified
    case warningTriangle
    case boltThroughput
    case cloudOfflineSlash
    case uploadDropzone
    case calendarRange
    case tagBookmark
    case userTeamNodes
    case webhookSignal
    case auditSeal
    case rocketDeploy

    public var id: String { rawValue }

    /// Clean, self-contained 24x24 viewBox SVG `d` path string for each ChiefKit icon.
    public var svgPathData: String {
        switch self {
        case .sparklesAI:
            "M12 2L14.4 8.6L21 11L14.4 13.4L12 20L9.6 13.4L3 11L9.6 8.6Z M19 2L19.9 4.1L22 5L19.9 5.9L19 8L18.1 5.9L16 5L18.1 4.1Z"
        case .liquidGlassCube:
            "M12 2L21 7V17L12 22L3 17V7Z M12 2V12 M21 7L12 12L3 7"
        case .springOscillator:
            "M2 12H5L7 5L10 19L13 6L16 18L18 10L19.5 12H22"
        case .colorWheelOKLCH:
            "M12 3A9 9 0 1 0 21 12A9 9 0 0 0 12 3Z M12 8A4 4 0 1 1 8 12A4 4 0 0 1 12 8Z"
        case .layoutGrid12:
            "M3 3H21V21H3Z M9 3V21 M15 3V21 M3 9H21 M3 15H21"
        case .artboardDevices:
            "M2 5H16V16H2Z M6 19H12 M9 16V19 M18 9H22V19H18Z"
        case .commandPalette:
            "M7 7A2 2 0 1 1 9 9H15A2 2 0 1 1 17 7A2 2 0 0 1 15 9V15A2 2 0 1 1 17 17A2 2 0 0 1 15 15H9A2 2 0 1 1 7 17A2 2 0 0 1 9 15V9A2 2 0 0 1 7 7Z"
        case .passkeyShield:
            "M12 2L20 5V11C20 16.5 16.5 20.6 12 22C7.5 20.6 4 16.5 4 11V5Z M9 12L11 14L15 10"
        case .biometricKey:
            "M8 11A4 4 0 1 1 11.4 14.9L13 16.5H15V18.5H17V20.5H13.5L9.5 16.5"
        case .neuralChip:
            "M7 7H17V17H7Z M10 10H14V14H10Z M9 3V7 M15 3V7 M9 17V21 M15 17V21 M3 9H7 M3 15H7 M17 9H21 M17 15H21"
        case .tokenCompiler:
            "M8 6L3 12L8 18 M16 6L21 12L16 18 M14 4L10 20"
        case .gitBranchMerge:
            "M6 3V15 M6 9C6 12 18 9 18 15 M6 3A2 2 0 1 0 6 7A2 2 0 1 0 6 3Z M6 15A2 2 0 1 0 6 19A2 2 0 1 0 6 15Z M18 15A2 2 0 1 0 18 19A2 2 0 1 0 18 15Z"
        case .unifiedDiff:
            "M4 4H20V20H4Z M9 9H15 M12 6V12 M9 16H15"
        case .terminalPrompt:
            "M3 4H21V20H3Z M7 9L11 12L7 15 M12 15H17"
        case .chartSparkline:
            "M3 19H21 M4 15L8.5 10.5L12.5 13.5L19.5 6.5 M15.5 6.5H19.5V10.5"
        case .chartDonutGauge:
            "M12 3A9 9 0 1 1 3.5 15 M12 7A5 5 0 1 1 7.3 13.7 M12 3V7"
        case .chartCandlestick:
            "M7 4V20 M5 8H9V15H5Z M17 3V21 M15 7H19V13H15Z"
        case .kanbanColumns:
            "M3 4H8V18H3Z M9.5 4H14.5V13H9.5Z M16 4H21V20H16Z"
        case .timelineClock:
            "M12 3A9 9 0 1 0 21 12A9 9 0 0 0 12 3Z M12 7V12L15.5 14"
        case .creditCardChip:
            "M2 5H22V19H2Z M2 9H22 M6 13H10V16H6Z"
        case .currencySwap:
            "M4 8H19L15 4 M20 16H5L9 20"
        case .ledgerBook:
            "M5 3H19V21H5Z M9 3V21 M12 8H16 M12 12H16 M12 16H15"
        case .escrowLock:
            "M5 11H19V21H5Z M8 11V7A4 4 0 0 1 16 7V11 M12 15V17"
        case .spatialVisionGoggles:
            "M2 9C2 6.8 3.8 5 6 5H18C20.2 5 22 6.8 22 9V14C22 16.2 20.2 18 18 18H15L13 15H11L9 18H6C3.8 18 2 16.2 2 14Z"
        case .depthLayers3D:
            "M12 3L21 8L12 13L3 8Z M3 12.5L12 17.5L21 12.5 M3 17L12 22L21 17"
        case .waveformAudio:
            "M3 12V13 M6 8V16 M9 5V19 M12 3V21 M15 6V18 M18 9V15 M21 11V13"
        case .videoChapterPlay:
            "M3 5H21V17H3Z M10 8.5L15.5 11L10 13.5Z M3 20H8 M10 20H15 M17 20H21"
        case .microphonePulse:
            "M9 6A3 3 0 0 1 15 6V11A3 3 0 0 1 9 11Z M5 11A7 7 0 0 0 19 11 M12 18V22 M8 22H16"
        case .searchMagnifier:
            "M11 4A7 7 0 1 0 18 11A7 7 0 0 0 11 4Z M16.2 16.2L21 21"
        case .filterSliders:
            "M4 6H20 M8 4V8 M4 12H20 M16 10V14 M4 18H20 M10 16V20"
        case .bellNotification:
            "M6 10A6 6 0 0 1 18 10C18 15 20 17 20 17H4C4 17 6 15 6 10Z M10 20A2 2 0 0 0 14 20"
        case .checkBadgeVerified:
            "M12 2L15 4.2L18.7 4.5L19.8 8L22 11L20.5 14.5L20.8 18.2L17.3 19.5L14.5 22L11 20.8L7.5 22L4.7 19.5L3.2 18.2L3.5 14.5L2 11L4.2 8L5.3 4.5L9 4.2Z M8.5 12.2L11 14.7L15.8 9.8"
        case .warningTriangle:
            "M12 3L22 20H2Z M12 9V14 M12 17V17.5"
        case .boltThroughput:
            "M13 2L4 14H11L10 22L20 10H13Z"
        case .cloudOfflineSlash:
            "M3 3L21 21 M6.5 19H17.5A4.5 4.5 0 0 0 18 10A6 6 0 0 0 7 8.5A4 4 0 0 0 6.5 19Z"
        case .uploadDropzone:
            "M4 15V19H20V15 M12 15V4 M8 8L12 4L16 8"
        case .calendarRange:
            "M3 5H21V21H3Z M3 9H21 M8 3V6 M16 3V6 M7 13H17 M7 17H13"
        case .tagBookmark:
            "M6 3H18V21L12 16.5L6 21Z"
        case .userTeamNodes:
            "M9 7A3 3 0 1 0 9 13A3 3 0 0 0 9 7Z M3 20C3 16.7 5.7 14 9 14C12.3 14 15 16.7 15 20 M16 8A2.5 2.5 0 1 1 16 13 M17 14.5C19.5 15 21 17 21 20"
        case .webhookSignal:
            "M12 6A3 3 0 1 0 9.4 10.5L6.5 15.5 M14.6 10.5L17.5 15.5 M8.5 17H15.5 M6 15A3 3 0 1 0 9 18 M18 15A3 3 0 1 0 15 18"
        case .auditSeal:
            "M12 3A7 7 0 1 0 19 10A7 7 0 0 0 12 3Z M9 16L7 22L12 19.5L17 22L15 16 M9.5 10L11.2 11.7L14.8 8.2"
        case .rocketDeploy:
            "M14 4C17.5 4 20 6.5 20 10C20 14 15 18 11 19L5 13C6 9 10 4 14 4Z M5 13L3 17L7 19L11 19 M14.5 9.5A1.5 1.5 0 1 0 14.5 9.51"
        }
    }

    public func parsedPath() -> ParsedSVGPath {
        (try? SVGPathEngine.parse(svgPathData))
            ?? ParsedSVGPath(rawData: svgPathData, commands: [], segments: [])
    }

    public func emitSwiftUIShape(structName: String? = nil) -> String {
        let name = structName ?? "CK\(rawValue.prefix(1).uppercased() + rawValue.dropFirst())IconShape"
        return parsedPath().emitSwiftUIShape(structName: name)
    }
}
