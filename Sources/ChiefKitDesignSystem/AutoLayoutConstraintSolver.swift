#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Auto-Layout Axes, Sizing Policies & Edge Insets

public enum LayoutAxis: Codable, Hashable, Sendable {
    case horizontal
    case vertical
    case zOverlay
    case grid(columns: Int, rowSpacing: Double)

    public static var grid: LayoutAxis {
        .grid(columns: 3, rowSpacing: 12.0)
    }
}

public enum SizingPolicy: Codable, Hashable, Sendable {
    case fixed(Double)
    case hugContents
    case fillAvailableWeighted(Double)

    /// Equal-weight flexible fill (`weight = 1.0`).
    public static var fillAvailable: SizingPolicy {
        .fillAvailableWeighted(1.0)
    }

    public static func fillAvailable(weight: Double) -> SizingPolicy {
        .fillAvailableWeighted(max(0.01, weight))
    }

    public var isFillAvailable: Bool {
        if case .fillAvailableWeighted = self { return true }
        return false
    }

    public var flexWeight: Double {
        if case .fillAvailableWeighted(let w) = self { return max(0.01, w) }
        return 0.0
    }
}

public enum LayoutCrossAlignment: String, Codable, Hashable, Sendable {
    case leading
    case center
    case trailing
    case stretch
}

public struct EdgeInsetsSpec: Codable, Hashable, Sendable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double

    public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
        self.top = max(0, top)
        self.leading = max(0, leading)
        self.bottom = max(0, bottom)
        self.trailing = max(0, trailing)
    }

    public static let zero = EdgeInsetsSpec()

    public static func all(_ value: Double) -> EdgeInsetsSpec {
        EdgeInsetsSpec(top: value, leading: value, bottom: value, trailing: value)
    }

    public static func symmetric(horizontal: Double = 0, vertical: Double = 0) -> EdgeInsetsSpec {
        EdgeInsetsSpec(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    public var horizontalTotal: Double { leading + trailing }
    public var verticalTotal: Double { top + bottom }
}

// MARK: - Declarative Layout Tree Node & Solved Box Output

public struct LayoutNode: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var axis: LayoutAxis
    public var widthPolicy: SizingPolicy
    public var heightPolicy: SizingPolicy
    public var padding: EdgeInsetsSpec
    public var spacing: Double
    public var alignment: LayoutCrossAlignment
    public var layoutPriority: Double
    public var minWidth: Double?
    public var maxWidth: Double?
    public var minHeight: Double?
    public var maxHeight: Double?
    public var intrinsicWidth: Double
    public var intrinsicHeight: Double
    public var children: [LayoutNode]

    public init(
        id: String = UUID().uuidString,
        name: String,
        axis: LayoutAxis = .vertical,
        widthPolicy: SizingPolicy = .hugContents,
        heightPolicy: SizingPolicy = .hugContents,
        padding: EdgeInsetsSpec = .zero,
        spacing: Double = 8.0,
        alignment: LayoutCrossAlignment = .leading,
        layoutPriority: Double = 0.0,
        minWidth: Double? = nil,
        maxWidth: Double? = nil,
        minHeight: Double? = nil,
        maxHeight: Double? = nil,
        intrinsicWidth: Double = 80.0,
        intrinsicHeight: Double = 36.0,
        children: [LayoutNode] = []
    ) {
        self.id = id
        self.name = name
        self.axis = axis
        self.widthPolicy = widthPolicy
        self.heightPolicy = heightPolicy
        self.padding = padding
        self.spacing = max(0.0, spacing)
        self.alignment = alignment
        self.layoutPriority = layoutPriority
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.intrinsicWidth = max(0.0, intrinsicWidth)
        self.intrinsicHeight = max(0.0, intrinsicHeight)
        self.children = children
    }

    @inline(__always)
    public func clampWidth(_ value: Double) -> Double {
        var v = max(0.0, value)
        if let minW = minWidth { v = max(minW, v) }
        if let maxW = maxWidth { v = min(maxW, v) }
        return v
    }

    @inline(__always)
    public func clampHeight(_ value: Double) -> Double {
        var v = max(0.0, value)
        if let minH = minHeight { v = max(minH, v) }
        if let maxH = maxHeight { v = min(maxH, v) }
        return v
    }
}

public struct SolvedLayoutBox: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let localFrame: CanvasFrame
    public let worldFrame: CanvasFrame
    public let innerContentFrame: CanvasFrame
    public let isOverflowingParent: Bool
    public let children: [SolvedLayoutBox]

    public init(
        id: String,
        name: String,
        localFrame: CanvasFrame,
        worldFrame: CanvasFrame,
        innerContentFrame: CanvasFrame,
        isOverflowingParent: Bool,
        children: [SolvedLayoutBox]
    ) {
        self.id = id
        self.name = name
        self.localFrame = localFrame
        self.worldFrame = worldFrame
        self.innerContentFrame = innerContentFrame
        self.isOverflowingParent = isOverflowingParent
        self.children = children
    }

    /// Pre-order traversal returning every solved layout box in the subtree.
    public func flattened() -> [SolvedLayoutBox] {
        var result = [self]
        for child in children {
            result.append(contentsOf: child.flattened())
        }
        return result
    }
}

// MARK: - Deterministic Two-Pass AutoLayoutConstraintSolver

public enum AutoLayoutConstraintSolver {

    // MARK: Pass 1 — Bottom-Up Intrinsic Measurement

    /// Computes intrinsic `(width, height)` for `node` before flexible space expansion.
    public static func measureIntrinsicSize(of node: LayoutNode) -> (width: Double, height: Double) {
        let childMeasurements = node.children.map { measureIntrinsicSize(of: $0) }
        let n = childMeasurements.count

        let contentW: Double
        let contentH: Double

        if n == 0 {
            contentW = node.intrinsicWidth
            contentH = node.intrinsicHeight
        } else {
            switch node.axis {
            case .horizontal:
                let sumW = childMeasurements.reduce(0.0) { $0 + $1.width }
                let gaps = Double(max(0, n - 1)) * node.spacing
                contentW = sumW + gaps
                contentH = childMeasurements.map(\.height).max() ?? 0.0

            case .vertical:
                contentW = childMeasurements.map(\.width).max() ?? 0.0
                let sumH = childMeasurements.reduce(0.0) { $0 + $1.height }
                let gaps = Double(max(0, n - 1)) * node.spacing
                contentH = sumH + gaps

            case .zOverlay:
                contentW = childMeasurements.map(\.width).max() ?? 0.0
                contentH = childMeasurements.map(\.height).max() ?? 0.0

            case .grid(let rawCols, let rowSpacing):
                let cols = max(1, rawCols)
                let rows = (n + cols - 1) / cols
                var maxCellW = 0.0
                var totalGridH = 0.0
                for r in 0..<rows {
                    let rowStart = r * cols
                    let rowEnd = min(n, rowStart + cols)
                    var rowMaxH = 0.0
                    for idx in rowStart..<rowEnd {
                        maxCellW = max(maxCellW, childMeasurements[idx].width)
                        rowMaxH = max(rowMaxH, childMeasurements[idx].height)
                    }
                    totalGridH += rowMaxH
                }
                contentW = Double(min(cols, n)) * maxCellW + Double(max(0, min(cols, n) - 1)) * node.spacing
                contentH = totalGridH + Double(max(0, rows - 1)) * max(0.0, rowSpacing)
            }
        }

        let rawW: Double
        switch node.widthPolicy {
        case .fixed(let w):
            rawW = w
        case .hugContents, .fillAvailableWeighted:
            rawW = n == 0 && node.widthPolicy.isFillAvailable
                ? node.intrinsicWidth
                : contentW + node.padding.horizontalTotal
        }

        let rawH: Double
        switch node.heightPolicy {
        case .fixed(let h):
            rawH = h
        case .hugContents, .fillAvailableWeighted:
            rawH = n == 0 && node.heightPolicy.isFillAvailable
                ? node.intrinsicHeight
                : contentH + node.padding.verticalTotal
        }

        return (node.clampWidth(rawW), node.clampHeight(rawH))
    }

    // MARK: Pass 2 — Top-Down Priority-Sorted Space Distribution

    /// Solves exact coordinates for an arbitrary nested `LayoutNode` tree inside `availableWidth x availableHeight`.
    public static func solve(
        root: LayoutNode,
        availableWidth: Double,
        availableHeight: Double
    ) -> SolvedLayoutBox {
        let intrinsic = measureIntrinsicSize(of: root)

        let rootW: Double
        switch root.widthPolicy {
        case .fixed(let w): rootW = root.clampWidth(w)
        case .hugContents: rootW = root.clampWidth(min(intrinsic.width, availableWidth))
        case .fillAvailableWeighted: rootW = root.clampWidth(availableWidth)
        }

        let rootH: Double
        switch root.heightPolicy {
        case .fixed(let h): rootH = root.clampHeight(h)
        case .hugContents: rootH = root.clampHeight(intrinsic.height)
        case .fillAvailableWeighted: rootH = root.clampHeight(availableHeight)
        }

        return solveSubtree(
            node: root,
            assignedFrame: CanvasFrame(x: 0, y: 0, width: rootW, height: rootH),
            parentWorldOrigin: .zero,
            parentInnerBounds: CanvasFrame(x: 0, y: 0, width: availableWidth, height: availableHeight)
        )
    }

    /// Solves the same declarative `LayoutNode` tree across multiple `DeviceBreakpoint` viewports.
    public static func solveAcrossBreakpoints(
        root: LayoutNode,
        breakpoints: [DeviceBreakpoint] = DeviceBreakpoint.allCases
    ) -> [DeviceBreakpoint: SolvedLayoutBox] {
        var results: [DeviceBreakpoint: SolvedLayoutBox] = [:]
        for bp in breakpoints {
            results[bp] = solve(
                root: root,
                availableWidth: bp.referenceViewportWidth,
                availableHeight: bp.referenceViewportHeight
            )
        }
        return results
    }

    private static func solveSubtree(
        node: LayoutNode,
        assignedFrame: CanvasFrame,
        parentWorldOrigin: SVGPoint2D,
        parentInnerBounds: CanvasFrame
    ) -> SolvedLayoutBox {
        let worldX = parentWorldOrigin.x + assignedFrame.x
        let worldY = parentWorldOrigin.y + assignedFrame.y
        let worldFrame = CanvasFrame(
            x: worldX,
            y: worldY,
            width: assignedFrame.width,
            height: assignedFrame.height
        )

        let innerW = max(0.0, assignedFrame.width - node.padding.horizontalTotal)
        let innerH = max(0.0, assignedFrame.height - node.padding.verticalTotal)
        let innerWorldFrame = CanvasFrame(
            x: worldX + node.padding.leading,
            y: worldY + node.padding.top,
            width: innerW,
            height: innerH
        )

        let isOverflowing =
            (assignedFrame.x + assignedFrame.width) > (parentInnerBounds.width + node.padding.leading + 0.5) ||
            (assignedFrame.y + assignedFrame.height) > (parentInnerBounds.height + node.padding.top + 0.5)

        guard !node.children.isEmpty else {
            return SolvedLayoutBox(
                id: node.id,
                name: node.name,
                localFrame: assignedFrame,
                worldFrame: worldFrame,
                innerContentFrame: innerWorldFrame,
                isOverflowingParent: isOverflowing,
                children: []
            )
        }

        let childMeasurements = node.children.map { measureIntrinsicSize(of: $0) }
        let count = node.children.count
        var childLocalFrames = Array(repeating: CanvasFrame(x: 0, y: 0, width: 0, height: 0), count: count)

        switch node.axis {
        case .horizontal:
            let totalGaps = Double(max(0, count - 1)) * node.spacing
            let widths = distributeMainAxis(
                children: node.children,
                intrinsicMainSizes: childMeasurements.map(\.width),
                isHorizontal: true,
                availableTrack: max(0.0, innerW - totalGaps)
            )

            var cursorX = node.padding.leading
            for i in 0..<count {
                let child = node.children[i]
                let cw = widths[i]
                let ch = resolveCrossSize(
                    policy: child.heightPolicy,
                    intrinsic: childMeasurements[i].height,
                    availableCross: innerH,
                    alignment: node.alignment,
                    clamp: child.clampHeight
                )
                let cy = node.padding.top + alignCrossOffset(
                    childCross: ch,
                    availableCross: innerH,
                    alignment: node.alignment
                )
                childLocalFrames[i] = CanvasFrame(x: cursorX, y: cy, width: cw, height: ch)
                cursorX += cw + node.spacing
            }

        case .vertical:
            let totalGaps = Double(max(0, count - 1)) * node.spacing
            let heights = distributeMainAxis(
                children: node.children,
                intrinsicMainSizes: childMeasurements.map(\.height),
                isHorizontal: false,
                availableTrack: max(0.0, innerH - totalGaps)
            )

            var cursorY = node.padding.top
            for i in 0..<count {
                let child = node.children[i]
                let ch = heights[i]
                let cw = resolveCrossSize(
                    policy: child.widthPolicy,
                    intrinsic: childMeasurements[i].width,
                    availableCross: innerW,
                    alignment: node.alignment,
                    clamp: child.clampWidth
                )
                let cx = node.padding.leading + alignCrossOffset(
                    childCross: cw,
                    availableCross: innerW,
                    alignment: node.alignment
                )
                childLocalFrames[i] = CanvasFrame(x: cx, y: cursorY, width: cw, height: ch)
                cursorY += ch + node.spacing
            }

        case .zOverlay:
            for i in 0..<count {
                let child = node.children[i]
                let cw = resolveCrossSize(
                    policy: child.widthPolicy,
                    intrinsic: childMeasurements[i].width,
                    availableCross: innerW,
                    alignment: node.alignment,
                    clamp: child.clampWidth
                )
                let ch = resolveCrossSize(
                    policy: child.heightPolicy,
                    intrinsic: childMeasurements[i].height,
                    availableCross: innerH,
                    alignment: node.alignment,
                    clamp: child.clampHeight
                )
                let cx = node.padding.leading + alignCrossOffset(childCross: cw, availableCross: innerW, alignment: node.alignment)
                let cy = node.padding.top + alignCrossOffset(childCross: ch, availableCross: innerH, alignment: node.alignment)
                childLocalFrames[i] = CanvasFrame(x: cx, y: cy, width: cw, height: ch)
            }

        case .grid(let rawCols, let rowSpacing):
            let cols = max(1, rawCols)
            let colGaps = Double(max(0, cols - 1)) * node.spacing
            let colWidth = max(0.0, (innerW - colGaps) / Double(cols))
            let rows = (count + cols - 1) / cols
            var cursorY = node.padding.top

            for r in 0..<rows {
                let startIdx = r * cols
                let endIdx = min(count, startIdx + cols)
                var rowHeight = 0.0
                for idx in startIdx..<endIdx {
                    rowHeight = max(rowHeight, node.children[idx].clampHeight(childMeasurements[idx].height))
                }
                for idx in startIdx..<endIdx {
                    let colIdx = idx - startIdx
                    let child = node.children[idx]
                    let cw: Double
                    switch child.widthPolicy {
                    case .fixed(let fw): cw = child.clampWidth(min(fw, colWidth))
                    case .hugContents: cw = child.clampWidth(min(childMeasurements[idx].width, colWidth))
                    case .fillAvailableWeighted: cw = child.clampWidth(colWidth)
                    }
                    let ch = child.heightPolicy.isFillAvailable
                        ? child.clampHeight(rowHeight)
                        : child.clampHeight(childMeasurements[idx].height)
                    let cx = node.padding.leading + Double(colIdx) * (colWidth + node.spacing)
                    childLocalFrames[idx] = CanvasFrame(x: cx, y: cursorY, width: cw, height: ch)
                }
                cursorY += rowHeight + max(0.0, rowSpacing)
            }
        }

        // If parent is .hugContents, recompute tight outer dimensions when children expanded/clamped
        let childBoxes: [SolvedLayoutBox] = (0..<count).map { i in
            solveSubtree(
                node: node.children[i],
                assignedFrame: childLocalFrames[i],
                parentWorldOrigin: SVGPoint2D(x: worldX, y: worldY),
                parentInnerBounds: CanvasFrame(x: 0, y: 0, width: innerW, height: innerH)
            )
        }

        return SolvedLayoutBox(
            id: node.id,
            name: node.name,
            localFrame: assignedFrame,
            worldFrame: worldFrame,
            innerContentFrame: innerWorldFrame,
            isOverflowingParent: isOverflowing,
            children: childBoxes
        )
    }

    /// Priority-aware main-axis space allocator:
    /// 1. Fixed & `.hugContents` children claim space ordered by descending `layoutPriority` when space is tight.
    /// 2. Remaining surplus is distributed across `.fillAvailable` children ordered by priority tiers and clamped to `[min, max]`.
    private static func distributeMainAxis(
        children: [LayoutNode],
        intrinsicMainSizes: [Double],
        isHorizontal: Bool,
        availableTrack: Double
    ) -> [Double] {
        let n = children.count
        var sizes = Array(repeating: 0.0, count: n)
        var remaining = max(0.0, availableTrack)

        func policy(of idx: Int) -> SizingPolicy {
            isHorizontal ? children[idx].widthPolicy : children[idx].heightPolicy
        }
        func clamp(idx: Int, value: Double) -> Double {
            isHorizontal ? children[idx].clampWidth(value) : children[idx].clampHeight(value)
        }

        // Step A: Allocate non-flexible (.fixed and .hugContents) in descending layoutPriority order
        let nonFlexIndices = (0..<n)
            .filter { !policy(of: $0).isFillAvailable }
            .sorted { children[$0].layoutPriority > children[$1].layoutPriority }

        for idx in nonFlexIndices {
            let desired: Double
            switch policy(of: idx) {
            case .fixed(let f): desired = clamp(idx: idx, value: f)
            default: desired = clamp(idx: idx, value: intrinsicMainSizes[idx])
            }
            let granted = clamp(idx: idx, value: min(desired, remaining))
            sizes[idx] = granted
            remaining = max(0.0, remaining - granted)
        }

        // Step B: Group flexible (.fillAvailable) children by descending layoutPriority tiers
        let flexIndices = (0..<n).filter { policy(of: $0).isFillAvailable }
        let distinctPriorities = Array(Set(flexIndices.map { children[$0].layoutPriority })).sorted(by: >)

        for priority in distinctPriorities {
            var activeTier = flexIndices.filter { children[$0].layoutPriority == priority }
            // Iteratively freeze children that hit min/max bounds so residual space flows to unclamped peers
            while !activeTier.isEmpty {
                let totalWeight = activeTier.reduce(0.0) { $0 + policy(of: $1).flexWeight }
                guard totalWeight > 0 else { break }

                var clampedAny = false
                for idx in activeTier {
                    let share = remaining * (policy(of: idx).flexWeight / totalWeight)
                    let clampedShare = clamp(idx: idx, value: share)
                    if abs(clampedShare - share) > 1e-4 {
                        sizes[idx] = clampedShare
                        remaining = max(0.0, remaining - clampedShare)
                        activeTier.removeAll { $0 == idx }
                        clampedAny = true
                        break
                    }
                }

                if !clampedAny {
                    for idx in activeTier {
                        let share = remaining * (policy(of: idx).flexWeight / totalWeight)
                        sizes[idx] = clamp(idx: idx, value: share)
                    }
                    remaining = 0.0
                    break
                }
            }
        }

        return sizes
    }

    private static func resolveCrossSize(
        policy: SizingPolicy,
        intrinsic: Double,
        availableCross: Double,
        alignment: LayoutCrossAlignment,
        clamp: (Double) -> Double
    ) -> Double {
        if alignment == .stretch && !isFixed(policy) {
            return clamp(availableCross)
        }
        switch policy {
        case .fixed(let v):
            return clamp(v)
        case .hugContents:
            return clamp(min(intrinsic, availableCross))
        case .fillAvailableWeighted:
            return clamp(availableCross)
        }
    }

    private static func isFixed(_ policy: SizingPolicy) -> Bool {
        if case .fixed = policy { return true }
        return false
    }

    private static func alignCrossOffset(
        childCross: Double,
        availableCross: Double,
        alignment: LayoutCrossAlignment
    ) -> Double {
        let slack = max(0.0, availableCross - childCross)
        switch alignment {
        case .leading, .stretch:
            return 0.0
        case .center:
            return slack * 0.5
        case .trailing:
            return slack
        }
    }

    // MARK: - ASCII & SVG Wireframe Renderers

    /// Renders a solved layout hierarchy into a crisp ASCII box-drawing wireframe for CLI / test diagnostics.
    public static func renderASCIIWireframe(
        _ rootBox: SolvedLayoutBox,
        columns: Int = 72,
        rows: Int = 24
    ) -> String {
        let cols = max(20, columns)
        let rws = max(8, rows)
        let totalW = max(1.0, rootBox.worldFrame.width)
        let totalH = max(1.0, rootBox.worldFrame.height)

        var grid = Array(repeating: Array(repeating: Character(" "), count: cols), count: rws)

        for box in rootBox.flattened() {
            let wf = box.worldFrame
            let x0 = min(max(0, Int((wf.x / totalW * Double(cols - 1)).rounded())), cols - 1)
            let y0 = min(max(0, Int((wf.y / totalH * Double(rws - 1)).rounded())), rws - 1)
            let x1 = min(max(x0, Int(((wf.x + wf.width) / totalW * Double(cols - 1)).rounded())), cols - 1)
            let y1 = min(max(y0, Int(((wf.y + wf.height) / totalH * Double(rws - 1)).rounded())), rws - 1)

            guard x1 > x0 && y1 > y0 else { continue }

            for x in x0...x1 {
                grid[y0][x] = "-"
                grid[y1][x] = "-"
            }
            for y in y0...y1 {
                grid[y][x0] = "|"
                grid[y][x1] = "|"
            }
            grid[y0][x0] = "+"
            grid[y0][x1] = "+"
            grid[y1][x0] = "+"
            grid[y1][x1] = "+"

            let label = "\(box.name) (\(Int(wf.width))x\(Int(wf.height)))"
            let maxLabelLen = max(0, x1 - x0 - 2)
            if maxLabelLen >= 3 && (y0 + 1) < y1 {
                for (offset, ch) in label.prefix(maxLabelLen).enumerated() {
                    grid[y0 + 1][x0 + 1 + offset] = ch
                }
            }
        }

        return grid.map { String($0) }.joined(separator: "\n")
    }

    /// Renders a solved layout hierarchy into a standalone annotated SVG wireframe document.
    public static func renderSVGWireframe(
        _ rootBox: SolvedLayoutBox,
        theme: StudioThemeTokens = StudioThemeTokens(),
        showDimensions: Bool = true
    ) -> String {
        let w = Int(max(1, rootBox.worldFrame.width.rounded()))
        let h = Int(max(1, rootBox.worldFrame.height.rounded()))
        let strokeHex = theme.primary.hexString
        let warnHex = theme.danger.hexString

        let elements = rootBox.flattened().enumerated().map { depth, box -> String in
            let f = box.worldFrame
            let stroke = box.isOverflowingParent ? warnHex : strokeHex
            let fillOpacity = depth == 0 ? "0.04" : "0.08"
            let dimCaption = showDimensions
                ? "<text x=\"\(Int(f.x) + 6)\" y=\"\(Int(f.y) + 14)\" font-family=\"monospace\" font-size=\"10\" fill=\"\(stroke)\">\(box.name) · \(Int(f.width))×\(Int(f.height))</text>"
                : ""
            return """
              <g id="node-\(box.id)">
                <rect x="\(Int(f.x))" y="\(Int(f.y))" width="\(Int(f.width))" height="\(Int(f.height))" rx="4" fill="\(stroke)" fill-opacity="\(fillOpacity)" stroke="\(stroke)" stroke-width="1.2"/>
                \(dimCaption)
              </g>
            """
        }.joined(separator: "\n")

        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(w) \(h)" width="\(w)" height="\(h)">
        \(elements)
        </svg>
        """
    }
}
