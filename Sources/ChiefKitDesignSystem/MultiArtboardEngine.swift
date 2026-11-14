#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Device Artboard Presets

public enum ArtboardDevicePreset: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case iPhone16Pro = "iPhone 16 Pro"
    case iPhone16ProMax = "iPhone 16 Pro Max"
    case iPadPro13 = "iPad Pro 13\""
    case macBookPro16 = "MacBook Pro 16\""
    case appleVisionProSpatial = "Apple Vision Pro Spatial Window"
    case appleWatchUltra2 = "Apple Watch Ultra 2"
    case macStudioUltrawide = "Mac Studio Display 27\""

    public var id: String { rawValue }

    public var logicalWidth: Double {
        switch self {
        case .iPhone16Pro: 402
        case .iPhone16ProMax: 440
        case .iPadPro13: 1032
        case .macBookPro16: 1728
        case .appleVisionProSpatial: 1280
        case .appleWatchUltra2: 205
        case .macStudioUltrawide: 2560
        }
    }

    public var logicalHeight: Double {
        switch self {
        case .iPhone16Pro: 874
        case .iPhone16ProMax: 956
        case .iPadPro13: 1376
        case .macBookPro16: 1117
        case .appleVisionProSpatial: 720
        case .appleWatchUltra2: 251
        case .macStudioUltrawide: 1440
        }
    }

    public var pixelScaleFactor: Double {
        switch self {
        case .iPhone16Pro, .iPhone16ProMax: 3.0
        case .iPadPro13, .macBookPro16, .appleVisionProSpatial, .appleWatchUltra2, .macStudioUltrawide: 2.0
        }
    }

    public var hardwareCornerRadius: Double {
        switch self {
        case .iPhone16Pro, .iPhone16ProMax: 55
        case .iPadPro13: 18
        case .macBookPro16, .macStudioUltrawide: 12
        case .appleVisionProSpatial: 44
        case .appleWatchUltra2: 52
        }
    }

    public var associatedBreakpoint: DeviceBreakpoint {
        switch self {
        case .appleWatchUltra2: .watchOS
        case .iPhone16Pro: .iPhoneCompact
        case .iPhone16ProMax: .iPhoneMax
        case .iPadPro13: .iPadPro
        case .macBookPro16: .macWindow
        case .appleVisionProSpatial: .visionOSWindow
        case .macStudioUltrawide: .macUltrawide
        }
    }
}

// MARK: - Infinite Canvas Viewport Transform

/// Affine zoom & pan transform mapping between infinite world coordinates and viewport screen pixels.
public struct InfiniteCanvasViewport: Codable, Hashable, Sendable {
    public static let minZoom: Double = 0.05
    public static let maxZoom: Double = 32.0

    public var panX: Double
    public var panY: Double
    public var zoomScale: Double

    public init(panX: Double = 0.0, panY: Double = 0.0, zoomScale: Double = 1.0) {
        self.panX = panX
        self.panY = panY
        self.zoomScale = min(max(Self.minZoom, zoomScale), Self.maxZoom)
    }

    public func worldToScreen(_ worldPoint: SVGPoint2D) -> SVGPoint2D {
        SVGPoint2D(
            x: worldPoint.x * zoomScale + panX,
            y: worldPoint.y * zoomScale + panY
        )
    }

    public func screenToWorld(_ screenPoint: SVGPoint2D) -> SVGPoint2D {
        SVGPoint2D(
            x: (screenPoint.x - panX) / zoomScale,
            y: (screenPoint.y - panY) / zoomScale
        )
    }

    public func worldToScreen(_ worldFrame: CanvasFrame) -> CanvasFrame {
        CanvasFrame(
            x: worldFrame.x * zoomScale + panX,
            y: worldFrame.y * zoomScale + panY,
            width: worldFrame.width * zoomScale,
            height: worldFrame.height * zoomScale
        )
    }

    /// Zooms smoothly around a stationary screen-space focal point (e.g. trackpad pinch cursor).
    public mutating func zoom(by factor: Double, anchoredAtScreen anchor: SVGPoint2D) {
        let worldBefore = screenToWorld(anchor)
        zoomScale = min(max(Self.minZoom, zoomScale * factor), Self.maxZoom)
        panX = anchor.x - worldBefore.x * zoomScale
        panY = anchor.y - worldBefore.y * zoomScale
    }

    /// Computes pan and zoom so `worldBounds` fits comfortably inside `viewportWidth x viewportHeight`.
    public mutating func zoomToFit(
        worldBounds: CanvasFrame,
        viewportWidth: Double,
        viewportHeight: Double,
        padding: Double = 48.0
    ) {
        guard worldBounds.width > 1e-3 && worldBounds.height > 1e-3 else { return }
        let availW = max(64.0, viewportWidth - 2.0 * padding)
        let availH = max(64.0, viewportHeight - 2.0 * padding)
        let fitScale = min(availW / worldBounds.width, availH / worldBounds.height)
        zoomScale = min(max(Self.minZoom, fitScale), Self.maxZoom)
        panX = (viewportWidth - worldBounds.width * zoomScale) * 0.5 - worldBounds.x * zoomScale
        panY = (viewportHeight - worldBounds.height * zoomScale) * 0.5 - worldBounds.y * zoomScale
    }

    /// Returns the axis-aligned world-space rectangle currently visible inside the viewport.
    public func visibleWorldRect(viewportWidth: Double, viewportHeight: Double) -> CanvasFrame {
        let topLeft = screenToWorld(.zero)
        let bottomRight = screenToWorld(SVGPoint2D(x: viewportWidth, y: viewportHeight))
        return CanvasFrame(
            x: topLeft.x,
            y: topLeft.y,
            width: max(0.0, bottomRight.x - topLeft.x),
            height: max(0.0, bottomRight.y - topLeft.y)
        )
    }
}

// MARK: - Smart Snap Guides (Edges, Centers, Margins & Equal-Spacing)

public enum SnapGuideKind: String, Codable, Hashable, Sendable {
    case leftEdge
    case centerX
    case rightEdge
    case topEdge
    case centerY
    case bottomEdge
    case artboardMarginX
    case artboardMarginY
    case equalHorizontalSpacing
    case equalVerticalSpacing
}

public struct SmartSnapGuide: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(kind.rawValue)-\(Int(axisCoordinate.rounded()))-\(label)" }
    public let kind: SnapGuideKind
    public let isVerticalLine: Bool
    public let axisCoordinate: Double
    public let spanStart: Double
    public let spanEnd: Double
    public let label: String

    public init(
        kind: SnapGuideKind,
        isVerticalLine: Bool,
        axisCoordinate: Double,
        spanStart: Double,
        spanEnd: Double,
        label: String
    ) {
        self.kind = kind
        self.isVerticalLine = isVerticalLine
        self.axisCoordinate = axisCoordinate
        self.spanStart = spanStart
        self.spanEnd = spanEnd
        self.label = label
    }
}

public struct SnapResolution: Codable, Hashable, Sendable {
    public let snappedFrame: CanvasFrame
    public let deltaX: Double
    public let deltaY: Double
    public let activeGuides: [SmartSnapGuide]

    public init(
        snappedFrame: CanvasFrame,
        deltaX: Double,
        deltaY: Double,
        activeGuides: [SmartSnapGuide]
    ) {
        self.snappedFrame = snappedFrame
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.activeGuides = activeGuides
    }
}

public enum SmartSnapGuideDetector {

    /// Evaluates candidate `movingFrame` against artboard bounds, margins, sibling edges/centers,
    /// and equal-spacing intervals, returning the snapped frame and visual guide lines.
    public static func resolveSnap(
        movingFrame: CanvasFrame,
        siblingFrames: [CanvasFrame],
        artboardWidth: Double,
        artboardHeight: Double,
        outerMargin: Double = 20.0,
        snapTolerance: Double = 6.0
    ) -> SnapResolution {
        var bestDX: Double?
        var bestAbsDX = snapTolerance + 0.001
        var xGuides: [SmartSnapGuide] = []

        var bestDY: Double?
        var bestAbsDY = snapTolerance + 0.001
        var yGuides: [SmartSnapGuide] = []

        func considerX(delta: Double, guide: SmartSnapGuide) {
            let absD = abs(delta)
            guard absD <= snapTolerance else { return }
            if absD + 1e-6 < bestAbsDX {
                bestAbsDX = absD
                bestDX = delta
                xGuides = [guide]
            } else if abs(absD - bestAbsDX) <= 1e-6, let currentDX = bestDX, abs(currentDX - delta) <= 1e-4 {
                xGuides.append(guide)
            }
        }

        func considerY(delta: Double, guide: SmartSnapGuide) {
            let absD = abs(delta)
            guard absD <= snapTolerance else { return }
            if absD + 1e-6 < bestAbsDY {
                bestAbsDY = absD
                bestDY = delta
                yGuides = [guide]
            } else if abs(absD - bestAbsDY) <= 1e-6, let currentDY = bestDY, abs(currentDY - delta) <= 1e-4 {
                yGuides.append(guide)
            }
        }

        let mLeft = movingFrame.x
        let mCenterX = movingFrame.x + movingFrame.width * 0.5
        let mRight = movingFrame.x + movingFrame.width

        let mTop = movingFrame.y
        let mCenterY = movingFrame.y + movingFrame.height * 0.5
        let mBottom = movingFrame.y + movingFrame.height

        // 1. Artboard Center & Margin Guides
        let abCenterX = artboardWidth * 0.5
        considerX(
            delta: abCenterX - mCenterX,
            guide: SmartSnapGuide(kind: .centerX, isVerticalLine: true, axisCoordinate: abCenterX, spanStart: 0, spanEnd: artboardHeight, label: "Artboard Center X")
        )
        considerX(
            delta: outerMargin - mLeft,
            guide: SmartSnapGuide(kind: .artboardMarginX, isVerticalLine: true, axisCoordinate: outerMargin, spanStart: 0, spanEnd: artboardHeight, label: "\(Int(outerMargin))pt Margin")
        )
        considerX(
            delta: (artboardWidth - outerMargin) - mRight,
            guide: SmartSnapGuide(kind: .artboardMarginX, isVerticalLine: true, axisCoordinate: artboardWidth - outerMargin, spanStart: 0, spanEnd: artboardHeight, label: "\(Int(outerMargin))pt Margin")
        )

        let abCenterY = artboardHeight * 0.5
        considerY(
            delta: abCenterY - mCenterY,
            guide: SmartSnapGuide(kind: .centerY, isVerticalLine: false, axisCoordinate: abCenterY, spanStart: 0, spanEnd: artboardWidth, label: "Artboard Center Y")
        )
        considerY(
            delta: outerMargin - mTop,
            guide: SmartSnapGuide(kind: .artboardMarginY, isVerticalLine: false, axisCoordinate: outerMargin, spanStart: 0, spanEnd: artboardWidth, label: "\(Int(outerMargin))pt Margin")
        )
        considerY(
            delta: (artboardHeight - outerMargin) - mBottom,
            guide: SmartSnapGuide(kind: .artboardMarginY, isVerticalLine: false, axisCoordinate: artboardHeight - outerMargin, spanStart: 0, spanEnd: artboardWidth, label: "\(Int(outerMargin))pt Margin")
        )

        // 2. Sibling Edge & Center Alignment Guides
        for sib in siblingFrames {
            let sLeft = sib.x
            let sCenterX = sib.x + sib.width * 0.5
            let sRight = sib.x + sib.width
            let spanMinY = min(mTop, sib.y)
            let spanMaxY = max(mBottom, sib.y + sib.height)

            for (targetX, anchorX, kind) in [
                (sLeft, mLeft, SnapGuideKind.leftEdge),
                (sLeft, mRight, SnapGuideKind.leftEdge),
                (sCenterX, mCenterX, SnapGuideKind.centerX),
                (sRight, mRight, SnapGuideKind.rightEdge),
                (sRight, mLeft, SnapGuideKind.rightEdge)
            ] {
                considerX(
                    delta: targetX - anchorX,
                    guide: SmartSnapGuide(kind: kind, isVerticalLine: true, axisCoordinate: targetX, spanStart: spanMinY, spanEnd: spanMaxY, label: "Align")
                )
            }

            let sTop = sib.y
            let sCenterY = sib.y + sib.height * 0.5
            let sBottom = sib.y + sib.height
            let spanMinX = min(mLeft, sib.x)
            let spanMaxX = max(mRight, sib.x + sib.width)

            for (targetY, anchorY, kind) in [
                (sTop, mTop, SnapGuideKind.topEdge),
                (sTop, mBottom, SnapGuideKind.topEdge),
                (sCenterY, mCenterY, SnapGuideKind.centerY),
                (sBottom, mBottom, SnapGuideKind.bottomEdge),
                (sBottom, mTop, SnapGuideKind.bottomEdge)
            ] {
                considerY(
                    delta: targetY - anchorY,
                    guide: SmartSnapGuide(kind: kind, isVerticalLine: false, axisCoordinate: targetY, spanStart: spanMinX, spanEnd: spanMaxX, label: "Align")
                )
            }
        }

        // 3. Equal-Spacing Guides across sorted pairs of siblings
        if siblingFrames.count >= 2 {
            let sortedX = siblingFrames.sorted { $0.x < $1.x }
            for i in 0..<(sortedX.count - 1) {
                let a = sortedX[i]
                let b = sortedX[i + 1]
                let gap = b.x - (a.x + a.width)
                guard gap >= 2.0 else { continue }

                // Moving node placed to the right of b with equal gap
                let targetAfterB = b.x + b.width + gap
                considerX(
                    delta: targetAfterB - mLeft,
                    guide: SmartSnapGuide(
                        kind: .equalHorizontalSpacing,
                        isVerticalLine: false,
                        axisCoordinate: mCenterY,
                        spanStart: b.x + b.width,
                        spanEnd: targetAfterB,
                        label: "\(Int(gap.rounded()))pt"
                    )
                )
                // Moving node placed to the left of a with equal gap
                let targetBeforeA = a.x - gap - movingFrame.width
                considerX(
                    delta: targetBeforeA - mLeft,
                    guide: SmartSnapGuide(
                        kind: .equalHorizontalSpacing,
                        isVerticalLine: false,
                        axisCoordinate: mCenterY,
                        spanStart: targetBeforeA + movingFrame.width,
                        spanEnd: a.x,
                        label: "\(Int(gap.rounded()))pt"
                    )
                )
            }

            let sortedY = siblingFrames.sorted { $0.y < $1.y }
            for i in 0..<(sortedY.count - 1) {
                let a = sortedY[i]
                let b = sortedY[i + 1]
                let gap = b.y - (a.y + a.height)
                guard gap >= 2.0 else { continue }

                let targetBelowB = b.y + b.height + gap
                considerY(
                    delta: targetBelowB - mTop,
                    guide: SmartSnapGuide(
                        kind: .equalVerticalSpacing,
                        isVerticalLine: true,
                        axisCoordinate: mCenterX,
                        spanStart: b.y + b.height,
                        spanEnd: targetBelowB,
                        label: "\(Int(gap.rounded()))pt"
                    )
                )
            }
        }

        let dx = bestDX ?? 0.0
        let dy = bestDY ?? 0.0
        let snapped = CanvasFrame(
            x: movingFrame.x + dx,
            y: movingFrame.y + dy,
            width: movingFrame.width,
            height: movingFrame.height
        )
        return SnapResolution(
            snappedFrame: snapped,
            deltaX: dx,
            deltaY: dy,
            activeGuides: xGuides + yGuides
        )
    }
}

// MARK: - Artboard Layer Hierarchy & Master-Component Sync

public enum MasterPropertyOverrideField: String, CaseIterable, Codable, Hashable, Sendable {
    case title
    case subtitle
    case variant
    case size
    case cornerRadius
}

public struct MasterComponentSymbol: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var symbolName: String
    public var prototypeNode: CanvasNode
    public var revision: Int

    public init(
        id: UUID = UUID(),
        symbolName: String,
        prototypeNode: CanvasNode,
        revision: Int = 1
    ) {
        self.id = id
        self.symbolName = symbolName
        self.prototypeNode = prototypeNode
        self.revision = revision
    }
}

public enum ArtboardLayerPayload: Codable, Hashable, Sendable {
    case primitiveNode(CanvasNode)
    case masterInstance(masterID: UUID, resolvedNode: CanvasNode, overriddenFields: Set<MasterPropertyOverrideField>)
    case vectorIcon(icon: ChiefKitVectorIcon, tint: RGBAColor)
    case group(children: [ArtboardLayer])
}

public struct ArtboardLayer: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var frame: CanvasFrame
    public var opacity: Double
    public var isVisible: Bool
    public var isLocked: Bool
    public var payload: ArtboardLayerPayload

    public init(
        id: UUID = UUID(),
        name: String,
        frame: CanvasFrame,
        opacity: Double = 1.0,
        isVisible: Bool = true,
        isLocked: Bool = false,
        payload: ArtboardLayerPayload
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.opacity = min(max(0.0, opacity), 1.0)
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.payload = payload
    }

    public init(canvasNode: CanvasNode) {
        self.init(
            id: canvasNode.id,
            name: canvasNode.title,
            frame: canvasNode.frame,
            isLocked: canvasNode.isLocked,
            payload: .primitiveNode(canvasNode)
        )
    }
}

// MARK: - DeviceArtboard & Infinite ArtboardWorkspace

public struct DeviceArtboard: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var preset: ArtboardDevicePreset
    public var worldOriginX: Double
    public var worldOriginY: Double
    public var customWidth: Double?
    public var customHeight: Double?
    public var backgroundColor: RGBAColor
    /// Ordered back-to-front (`layers.last` is topmost z-order).
    public var layers: [ArtboardLayer]

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        preset: ArtboardDevicePreset,
        worldOriginX: Double = 0.0,
        worldOriginY: Double = 0.0,
        backgroundColor: RGBAColor = RGBAColor(red: 0.96, green: 0.97, blue: 0.99),
        layers: [ArtboardLayer] = []
    ) {
        self.id = id
        self.title = title ?? preset.rawValue
        self.preset = preset
        self.worldOriginX = worldOriginX
        self.worldOriginY = worldOriginY
        self.backgroundColor = backgroundColor
        self.layers = layers
    }

    public var width: Double { customWidth ?? preset.logicalWidth }
    public var height: Double { customHeight ?? preset.logicalHeight }

    public var worldFrame: CanvasFrame {
        CanvasFrame(x: worldOriginX, y: worldOriginY, width: width, height: height)
    }

    public var gridSpec: ResponsiveGridSpec {
        TypographyAndGridSystem.gridSpec(for: preset.associatedBreakpoint)
    }

    /// Front-to-back hit-testing in artboard-local coordinates.
    public func hitTest(localPoint: SVGPoint2D) -> ArtboardLayer? {
        for layer in layers.reversed() where layer.isVisible && !layer.isLocked {
            let f = layer.frame
            if localPoint.x >= f.x && localPoint.x <= (f.x + f.width) &&
               localPoint.y >= f.y && localPoint.y <= (f.y + f.height) {
                return layer
            }
        }
        return nil
    }

    // MARK: Z-Order Manipulation

    public mutating func bringLayerToFront(id: UUID) {
        guard let idx = layers.firstIndex(where: { $0.id == id }) else { return }
        let layer = layers.remove(at: idx)
        layers.append(layer)
    }

    public mutating func sendLayerToBack(id: UUID) {
        guard let idx = layers.firstIndex(where: { $0.id == id }) else { return }
        let layer = layers.remove(at: idx)
        layers.insert(layer, at: 0)
    }

    public mutating func stepLayerZOrder(id: UUID, delta: Int) {
        guard let idx = layers.firstIndex(where: { $0.id == id }) else { return }
        let next = min(max(0, idx + delta), layers.count - 1)
        guard next != idx else { return }
        let layer = layers.remove(at: idx)
        layers.insert(layer, at: next)
    }
}

/// Multi-artboard workspace managing infinite canvas layout, grouping/ungrouping, and master-component synchronization.
public struct ArtboardWorkspace: Codable, Hashable, Sendable {
    public var name: String
    public var viewport: InfiniteCanvasViewport
    public var artboards: [DeviceArtboard]
    public var masterSymbols: [UUID: MasterComponentSymbol]
    public var selectedArtboardID: UUID?
    public var selectedLayerIDs: Set<UUID>

    public init(
        name: String = "ChiefKit Multi-Device Workspace",
        viewport: InfiniteCanvasViewport = InfiniteCanvasViewport(),
        artboards: [DeviceArtboard] = [],
        masterSymbols: [UUID: MasterComponentSymbol] = [:]
    ) {
        self.name = name
        self.viewport = viewport
        self.artboards = artboards
        self.masterSymbols = masterSymbols
        self.selectedArtboardID = artboards.first?.id
        self.selectedLayerIDs = []
    }

    /// Creates a flagship multi-device responsive suite (iPhone 16 Pro, iPad Pro 13", MacBook Pro 16", Vision Pro, Watch Ultra 2).
    public static func flagshipSuite() -> ArtboardWorkspace {
        let presets: [ArtboardDevicePreset] = [
            .appleWatchUltra2,
            .iPhone16Pro,
            .iPadPro13,
            .macBookPro16,
            .appleVisionProSpatial
        ]
        var cursorX = 0.0
        let gap = 120.0
        let boards = presets.map { preset -> DeviceArtboard in
            let board = DeviceArtboard(
                preset: preset,
                worldOriginX: cursorX,
                worldOriginY: 0.0
            )
            cursorX += preset.logicalWidth + gap
            return board
        }
        return ArtboardWorkspace(artboards: boards)
    }

    /// Computes the union world bounding box enclosing all artboards.
    public var unionWorldBounds: CanvasFrame {
        guard let first = artboards.first else {
            return CanvasFrame(x: 0, y: 0, width: 1440, height: 900)
        }
        var minX = first.worldOriginX
        var minY = first.worldOriginY
        var maxX = first.worldOriginX + first.width
        var maxY = first.worldOriginY + first.height

        for board in artboards.dropFirst() {
            minX = min(minX, board.worldOriginX)
            minY = min(minY, board.worldOriginY)
            maxX = max(maxX, board.worldOriginX + board.width)
            maxY = max(maxY, board.worldOriginY + board.height)
        }
        return CanvasFrame(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Arranges all artboards cleanly on a horizontal baseline with fixed world spacing.
    public mutating func autoArrangeArtboardsHorizontally(spacing: Double = 120.0) {
        var cursorX = 0.0
        for idx in artboards.indices {
            artboards[idx].worldOriginX = cursorX
            artboards[idx].worldOriginY = 0.0
            cursorX += artboards[idx].width + spacing
        }
    }

    // MARK: Group & Ungroup Operations

    /// Groups multiple top-level layers inside `artboardID` into a `.group` container,
    /// converting each child's frame into group-local coordinates.
    @discardableResult
    public mutating func groupLayers(
        inArtboard artboardID: UUID,
        layerIDs: Set<UUID>,
        groupName: String = "Component Group"
    ) -> UUID? {
        guard let bIdx = artboards.firstIndex(where: { $0.id == artboardID }) else { return nil }
        let matching = artboards[bIdx].layers.filter { layerIDs.contains($0.id) && !$0.isLocked }
        guard matching.count >= 2 else { return nil }

        let minX = matching.map(\.frame.x).min() ?? 0.0
        let minY = matching.map(\.frame.y).min() ?? 0.0
        let maxX = matching.map { $0.frame.x + $0.frame.width }.max() ?? 0.0
        let maxY = matching.map { $0.frame.y + $0.frame.height }.max() ?? 0.0
        let groupFrame = CanvasFrame(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))

        let localizedChildren: [ArtboardLayer] = matching.map { child in
            var copy = child
            copy.frame = CanvasFrame(
                x: child.frame.x - minX,
                y: child.frame.y - minY,
                width: child.frame.width,
                height: child.frame.height
            )
            return copy
        }

        let insertIdx = artboards[bIdx].layers.lastIndex(where: { layerIDs.contains($0.id) }) ?? artboards[bIdx].layers.count
        artboards[bIdx].layers.removeAll { layerIDs.contains($0.id) && !$0.isLocked }

        let groupLayer = ArtboardLayer(
            name: groupName,
            frame: groupFrame,
            payload: .group(children: localizedChildren)
        )
        let clampedInsert = min(insertIdx, artboards[bIdx].layers.count)
        artboards[bIdx].layers.insert(groupLayer, at: clampedInsert)
        return groupLayer.id
    }

    /// Ungroups a `.group` layer back into artboard-level sibling layers, restoring artboard-space coordinates.
    @discardableResult
    public mutating func ungroupLayer(
        inArtboard artboardID: UUID,
        groupLayerID: UUID
    ) -> [UUID] {
        guard let bIdx = artboards.firstIndex(where: { $0.id == artboardID }),
              let gIdx = artboards[bIdx].layers.firstIndex(where: { $0.id == groupLayerID }),
              case .group(let children) = artboards[bIdx].layers[gIdx].payload else {
            return []
        }

        let groupOrigin = artboards[bIdx].layers[gIdx].frame
        let restored: [ArtboardLayer] = children.map { child in
            var copy = child
            copy.frame = CanvasFrame(
                x: groupOrigin.x + child.frame.x,
                y: groupOrigin.y + child.frame.y,
                width: child.frame.width,
                height: child.frame.height
            )
            return copy
        }

        artboards[bIdx].layers.remove(at: gIdx)
        artboards[bIdx].layers.insert(contentsOf: restored, at: gIdx)
        return restored.map(\.id)
    }

    // MARK: Cross-Artboard Master-Component Sync

    /// Registers a reusable master component symbol in the workspace library.
    @discardableResult
    public mutating func registerMasterSymbol(
        name: String,
        prototype: CanvasNode
    ) -> MasterComponentSymbol {
        let symbol = MasterComponentSymbol(symbolName: name, prototypeNode: prototype)
        masterSymbols[symbol.id] = symbol
        return symbol
    }

    /// Instantiates a linked instance of `masterID` onto `artboardID` at `origin`.
    @discardableResult
    public mutating func instantiateMasterSymbol(
        masterID: UUID,
        onArtboard artboardID: UUID,
        at origin: SVGPoint2D
    ) -> UUID? {
        guard let master = masterSymbols[masterID],
              let bIdx = artboards.firstIndex(where: { $0.id == artboardID }) else {
            return nil
        }

        var instanceNode = master.prototypeNode
        instanceNode.id = UUID()
        instanceNode.frame.x = origin.x
        instanceNode.frame.y = origin.y

        let layer = ArtboardLayer(
            id: instanceNode.id,
            name: "\(master.symbolName) Instance",
            frame: instanceNode.frame,
            payload: .masterInstance(
                masterID: master.id,
                resolvedNode: instanceNode,
                overriddenFields: []
            )
        )
        artboards[bIdx].layers.append(layer)
        return layer.id
    }

    /// Applies a local override on a specific master-component instance without detaching non-overridden fields.
    public mutating func overrideInstanceProperty(
        artboardID: UUID,
        layerID: UUID,
        field: MasterPropertyOverrideField,
        mutate: (inout CanvasNode) -> Void
    ) {
        guard let bIdx = artboards.firstIndex(where: { $0.id == artboardID }),
              let lIdx = artboards[bIdx].layers.firstIndex(where: { $0.id == layerID }),
              case .masterInstance(let mID, var resolved, var overrides) = artboards[bIdx].layers[lIdx].payload else {
            return
        }
        mutate(&resolved)
        overrides.insert(field)
        artboards[bIdx].layers[lIdx].payload = .masterInstance(
            masterID: mID,
            resolvedNode: resolved,
            overriddenFields: overrides
        )
    }

    /// Updates `masterID` prototype and automatically propagates all non-overridden properties
    /// across every linked instance on every artboard in the workspace.
    @discardableResult
    public mutating func updateMasterSymbol(
        masterID: UUID,
        mutatePrototype: (inout CanvasNode) -> Void
    ) -> Int {
        guard var symbol = masterSymbols[masterID] else { return 0 }
        mutatePrototype(&symbol.prototypeNode)
        symbol.revision += 1
        masterSymbols[masterID] = symbol

        let proto = symbol.prototypeNode
        var syncedCount = 0

        func syncLayer(_ layer: inout ArtboardLayer) {
            switch layer.payload {
            case .masterInstance(let mID, var node, let overrides) where mID == masterID:
                if !overrides.contains(.title) { node.title = proto.title }
                if !overrides.contains(.subtitle) { node.subtitle = proto.subtitle }
                if !overrides.contains(.variant) { node.variant = proto.variant }
                if !overrides.contains(.size) { node.size = proto.size }
                if !overrides.contains(.cornerRadius) { node.cornerRadius = proto.cornerRadius }
                layer.payload = .masterInstance(masterID: mID, resolvedNode: node, overriddenFields: overrides)
                syncedCount += 1
            case .group(var children):
                for idx in children.indices {
                    syncLayer(&children[idx])
                }
                layer.payload = .group(children: children)
            default:
                break
            }
        }

        for bIdx in artboards.indices {
            for lIdx in artboards[bIdx].layers.indices {
                syncLayer(&artboards[bIdx].layers[lIdx])
            }
        }
        return syncedCount
    }
}
