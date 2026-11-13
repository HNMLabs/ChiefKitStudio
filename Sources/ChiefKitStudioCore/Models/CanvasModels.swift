#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

public enum CanvasComponentKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case button
    case card
    case metric
    case text
    case input
    case toggle
    case badge
    case hStack
    case spacer

    public var id: String { rawValue }

    public var paletteTitle: String {
        switch self {
        case .button: "Button"
        case .card: "Glass Surface"
        case .metric: "Metric KPI"
        case .text: "Heading Text"
        case .input: "Text Input"
        case .toggle: "Toggle Row"
        case .badge: "Status Pill"
        case .hStack: "Action Row"
        case .spacer: "Spacer"
        }
    }

    public var symbolName: String {
        switch self {
        case .button: "rectangle.and.hand.point.up.left"
        case .card: "rectangle.stack"
        case .metric: "chart.line.uptrend.xyaxis"
        case .text: "textformat"
        case .input: "character.cursor.ibeam"
        case .toggle: "switch.2"
        case .badge: "capsule.inset.filled"
        case .hStack: "rectangle.split.3x1"
        case .spacer: "arrow.left.and.right"
        }
    }

    public var defaultTitle: String {
        switch self {
        case .button: "Continue"
        case .card: "Workspace Summary"
        case .metric: "$48.2k"
        case .text: "Ship Faster with Blocks"
        case .input: "Enter workspace email…"
        case .toggle: "Enable Live Sync"
        case .badge: "Liquid Glass Ready"
        case .hStack: "Save • Preview • Share"
        case .spacer: "Flexible Spacer"
        }
    }

    public var defaultSubtitle: String {
        switch self {
        case .button: "Primary CTA"
        case .card: "Token-driven surface with adaptive glass material."
        case .metric: "Monthly Recurring Revenue · +18.4%"
        case .text: "Composable SwiftUI blocks for macOS & iOS"
        case .input: "developer@hnmlabs.com"
        case .toggle: "Real-time state sync"
        case .badge: "v2.0"
        case .hStack: "3 actions"
        case .spacer: "16 pt"
        }
    }

    public var defaultFrame: CanvasFrame {
        switch self {
        case .button:
            CanvasFrame(x: 28, y: 36, width: 176, height: 48)
        case .card:
            CanvasFrame(x: 28, y: 100, width: 292, height: 128)
        case .metric:
            CanvasFrame(x: 336, y: 100, width: 196, height: 128)
        case .text:
            CanvasFrame(x: 28, y: 24, width: 320, height: 56)
        case .input:
            CanvasFrame(x: 28, y: 244, width: 292, height: 52)
        case .toggle:
            CanvasFrame(x: 28, y: 308, width: 292, height: 50)
        case .badge:
            CanvasFrame(x: 336, y: 36, width: 176, height: 38)
        case .hStack:
            CanvasFrame(x: 28, y: 248, width: 304, height: 58)
        case .spacer:
            CanvasFrame(x: 28, y: 320, width: 180, height: 34)
        }
    }
}

public enum CanvasVariant: String, CaseIterable, Codable, Identifiable, Sendable {
    case primary
    case secondary
    case glass
    case success
    case warning
    case danger
    case light
    case dark

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

public enum CanvasComponentSize: String, CaseIterable, Codable, Identifiable, Sendable {
    case small
    case medium
    case large

    public var id: String { rawValue }

    public var fontSize: CGFloat {
        switch self {
        case .small: 12
        case .medium: 14
        case .large: 17
        }
    }

    public var verticalPadding: CGFloat {
        switch self {
        case .small: 8
        case .medium: 12
        case .large: 16
        }
    }
}

public enum CanvasCodeLayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case adaptiveStacks = "Adaptive Stacks"
    case positionedCanvas = "Positioned ZStack"

    public var id: String { rawValue }
}

public enum CanvasAlignmentAxis: String, CaseIterable, Identifiable, Sendable {
    case left = "Align Left"
    case centerH = "Center H"
    case right = "Align Right"
    case top = "Align Top"
    case centerV = "Center V"
    case bottom = "Align Bottom"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .left: "align.horizontal.left"
        case .centerH: "align.horizontal.center"
        case .right: "align.horizontal.right"
        case .top: "align.vertical.top"
        case .centerV: "align.vertical.center"
        case .bottom: "align.vertical.bottom"
        }
    }
}

public struct CanvasFrame: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func movedBy(dx: Double, dy: Double, snapToGrid: Bool) -> CanvasFrame {
        var nextX = x + dx
        var nextY = y + dy
        if snapToGrid {
            nextX = (nextX / 16.0).rounded() * 16.0
            nextY = (nextY / 16.0).rounded() * 16.0
        }
        return CanvasFrame(x: nextX, y: nextY, width: width, height: height)
    }

    public func resizedBy(dw: Double, dh: Double, snapToGrid: Bool) -> CanvasFrame {
        var nextW = max(84, width + dw)
        var nextH = max(34, height + dh)
        if snapToGrid {
            nextW = (nextW / 16.0).rounded() * 16.0
            nextH = (nextH / 16.0).rounded() * 16.0
        }
        return CanvasFrame(x: x, y: y, width: nextW, height: nextH)
    }

    public func clamped(to size: CGSize) -> CanvasFrame {
        let maxW = max(84, Double(size.width))
        let maxH = max(34, Double(size.height))
        let w = min(width, maxW)
        let h = min(height, maxH)
        let cx = min(max(0, x), max(0, maxW - w))
        let cy = min(max(0, y), max(0, maxH - h))
        return CanvasFrame(x: cx, y: cy, width: w, height: h)
    }
}

public struct CanvasNode: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: CanvasComponentKind
    public var title: String
    public var subtitle: String
    public var variant: CanvasVariant
    public var size: CanvasComponentSize
    public var cornerRadius: Double
    public var isLocked: Bool
    public var frame: CanvasFrame

    public init(
        id: UUID = UUID(),
        kind: CanvasComponentKind,
        title: String? = nil,
        subtitle: String? = nil,
        variant: CanvasVariant = .primary,
        size: CanvasComponentSize = .medium,
        cornerRadius: Double = 12,
        isLocked: Bool = false,
        frame: CanvasFrame? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.subtitle = subtitle ?? kind.defaultSubtitle
        self.variant = variant
        self.size = size
        self.cornerRadius = cornerRadius
        self.isLocked = isLocked
        self.frame = frame ?? kind.defaultFrame
    }

    public func swiftUISnippet(theme: StudioThemeTokens, includeFrame: Bool = false) -> String {
        let radius = Int(cornerRadius.rounded())
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedSub = subtitle.replacingOccurrences(of: "\"", with: "\\\"")
        let glassModifier = (variant == .glass || (theme.isLiquidGlassEnabled && kind == .card))
            ? "\n    .edkLiquidGlass(cornerRadius: \(radius))"
            : ""

        let core: String
        switch kind {
        case .button:
            core = """
            EDKButton("\(escapedTitle)", variant: .\(variant.rawValue), size: .\(size.rawValue)) {
                // Handle \(escapedTitle) action
            }
            """
        case .card:
            core = """
            EDKSurface(variant: .\(variant.rawValue), cornerRadius: \(radius)) {
                VStack(alignment: .leading, spacing: \(Int(theme.spacingXS))) {
                    Text("\(escapedTitle)")
                        .font(.headline)
                    Text("\(escapedSub)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }\(glassModifier)
            """
        case .metric:
            core = """
            EDKSurface(variant: .\(variant.rawValue), cornerRadius: \(radius)) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Metric", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(escapedTitle)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("\(escapedSub)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }\(glassModifier)
            """
        case .text:
            core = """
            VStack(alignment: .leading, spacing: 4) {
                Text("\(escapedTitle)")
                    .font(.title2.weight(.bold))
                Text("\(escapedSub)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            """
        case .input:
            core = """
            TextField("\(escapedTitle)", text: .constant("\(escapedSub)"))
                .textFieldStyle(.roundedBorder)
            """
        case .toggle:
            core = """
            Toggle("\(escapedTitle)", isOn: .constant(true))
                .toggleStyle(.switch)
            """
        case .badge:
            core = """
            Label("\(escapedTitle)", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            """
        case .hStack:
            let parts = title
                .split(separator: "•")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let buttons = (parts.isEmpty ? ["Save", "Cancel"] : parts)
                .map { "EDKButton(\"\($0)\", variant: .\(variant.rawValue), size: .small) { }" }
                .joined(separator: "\n    ")
            core = """
            HStack(spacing: \(Int(theme.spacingSM))) {
                \(buttons)
            }
            """
        case .spacer:
            core = "Spacer(minLength: \(Int(frame.height.rounded())))"
        }

        guard includeFrame else { return core }
        return """
        \(core)
            .frame(width: \(Int(frame.width.rounded())), height: \(Int(frame.height.rounded())))
            .offset(x: \(Int(frame.x.rounded())), y: \(Int(frame.y.rounded())))
        """
    }
}

public struct CanvasPaletteItem: Identifiable, Hashable, Sendable {
    public var id: String { "\(kind.rawValue)-\(variant.rawValue)" }
    public let kind: CanvasComponentKind
    public let variant: CanvasVariant
    public let badge: String

    public init(kind: CanvasComponentKind, variant: CanvasVariant, badge: String) {
        self.kind = kind
        self.variant = variant
        self.badge = badge
    }

    public func makeNode(defaultRadius: Double) -> CanvasNode {
        CanvasNode(
            kind: kind,
            variant: variant,
            size: .medium,
            cornerRadius: kind == .badge ? 999 : defaultRadius
        )
    }

    public static let library: [CanvasPaletteItem] = [
        CanvasPaletteItem(kind: .text, variant: .dark, badge: "Header"),
        CanvasPaletteItem(kind: .card, variant: .glass, badge: "Glass"),
        CanvasPaletteItem(kind: .metric, variant: .glass, badge: "KPI"),
        CanvasPaletteItem(kind: .button, variant: .primary, badge: "CTA"),
        CanvasPaletteItem(kind: .input, variant: .light, badge: "Field"),
        CanvasPaletteItem(kind: .toggle, variant: .primary, badge: "Switch"),
        CanvasPaletteItem(kind: .badge, variant: .glass, badge: "Pill"),
        CanvasPaletteItem(kind: .hStack, variant: .secondary, badge: "Row"),
        CanvasPaletteItem(kind: .spacer, variant: .light, badge: "Space")
    ]
}

public enum CanvasAutoCraftPreset: String, CaseIterable, Identifiable, Sendable {
    case glassDashboard = "Liquid Glass KPI Hero"
    case authCard = "Sign-In Block"
    case onboardingStack = "Onboarding Welcome"
    case pricingBanner = "Upgrade CTA Card"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .glassDashboard: "sparkles.rectangle.stack"
        case .authCard: "person.badge.key"
        case .onboardingStack: "hand.wave"
        case .pricingBanner: "crown"
        }
    }

    public func buildNodes(radius: Double) -> [CanvasNode] {
        switch self {
        case .glassDashboard:
            return [
                CanvasNode(
                    kind: .text,
                    title: "ChiefKit Workspace",
                    subtitle: "Live metrics & Liquid Glass surfaces",
                    variant: .dark,
                    size: .large,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 24, y: 20, width: 320, height: 56)
                ),
                CanvasNode(
                    kind: .badge,
                    title: "On-Device Ready",
                    subtitle: "2026",
                    variant: .glass,
                    size: .small,
                    cornerRadius: 999,
                    frame: CanvasFrame(x: 368, y: 26, width: 164, height: 36)
                ),
                CanvasNode(
                    kind: .metric,
                    title: "$48.2k",
                    subtitle: "Net Revenue · +22%",
                    variant: .glass,
                    size: .medium,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 24, y: 92, width: 244, height: 124)
                ),
                CanvasNode(
                    kind: .metric,
                    title: "99.94%",
                    subtitle: "Crash-Free Sessions",
                    variant: .glass,
                    size: .medium,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 284, y: 92, width: 248, height: 124)
                ),
                CanvasNode(
                    kind: .card,
                    title: "Release Pipeline",
                    subtitle: "All 4 ChiefKit modules verified on macOS & iOS.",
                    variant: .light,
                    size: .medium,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 24, y: 232, width: 332, height: 104)
                ),
                CanvasNode(
                    kind: .button,
                    title: "Deploy Build",
                    subtitle: "Action",
                    variant: .primary,
                    size: .medium,
                    cornerRadius: max(8, radius - 2),
                    frame: CanvasFrame(x: 372, y: 260, width: 160, height: 48)
                )
            ]
        case .authCard:
            return [
                CanvasNode(
                    kind: .text,
                    title: "Welcome Back",
                    subtitle: "Sign in to ChiefKit Cloud or continue locally",
                    variant: .dark,
                    size: .large,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 32, y: 24, width: 380, height: 56)
                ),
                CanvasNode(
                    kind: .input,
                    title: "Work Email",
                    subtitle: "founder@hnmlabs.com",
                    variant: .light,
                    size: .medium,
                    cornerRadius: max(8, radius - 2),
                    frame: CanvasFrame(x: 32, y: 96, width: 360, height: 48)
                ),
                CanvasNode(
                    kind: .toggle,
                    title: "Remember this Mac with Touch ID",
                    subtitle: "Biometric session",
                    variant: .primary,
                    size: .medium,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 32, y: 158, width: 360, height: 46)
                ),
                CanvasNode(
                    kind: .button,
                    title: "Sign In",
                    subtitle: "Submit",
                    variant: .primary,
                    size: .large,
                    cornerRadius: max(8, radius - 2),
                    frame: CanvasFrame(x: 32, y: 220, width: 176, height: 48)
                ),
                CanvasNode(
                    kind: .button,
                    title: "Use Passkey",
                    subtitle: "Secondary",
                    variant: .glass,
                    size: .large,
                    cornerRadius: max(8, radius - 2),
                    frame: CanvasFrame(x: 220, y: 220, width: 172, height: 48)
                )
            ]
        case .onboardingStack:
            return [
                CanvasNode(
                    kind: .badge,
                    title: "Step 1 of 3",
                    subtitle: "Onboarding",
                    variant: .glass,
                    size: .small,
                    cornerRadius: 999,
                    frame: CanvasFrame(x: 32, y: 24, width: 140, height: 34)
                ),
                CanvasNode(
                    kind: .text,
                    title: "Design Native Screens Visually",
                    subtitle: "Drag blocks onto the canvas and export production SwiftUI.",
                    variant: .dark,
                    size: .large,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 32, y: 72, width: 440, height: 60)
                ),
                CanvasNode(
                    kind: .card,
                    title: "Zero Lock-In",
                    subtitle: "Every block compiles to clean SwiftBlocks & SwiftUI views.",
                    variant: .glass,
                    size: .medium,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 32, y: 148, width: 440, height: 112)
                ),
                CanvasNode(
                    kind: .hStack,
                    title: "Get Started • Tour",
                    subtitle: "2 actions",
                    variant: .primary,
                    size: .medium,
                    cornerRadius: max(8, radius - 2),
                    frame: CanvasFrame(x: 32, y: 276, width: 300, height: 52)
                )
            ]
        case .pricingBanner:
            return [
                CanvasNode(
                    kind: .card,
                    title: "ChiefKit Pro Studio",
                    subtitle: "Unlimited local AI generations, theme presets, and Xcode templates.",
                    variant: .glass,
                    size: .large,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 28, y: 28, width: 468, height: 136)
                ),
                CanvasNode(
                    kind: .metric,
                    title: "$0 / local",
                    subtitle: "100% On-Device Open Source",
                    variant: .success,
                    size: .medium,
                    cornerRadius: radius,
                    frame: CanvasFrame(x: 28, y: 180, width: 240, height: 112)
                ),
                CanvasNode(
                    kind: .button,
                    title: "Export Xcode Starter",
                    subtitle: "CTA",
                    variant: .primary,
                    size: .large,
                    cornerRadius: max(8, radius - 2),
                    frame: CanvasFrame(x: 284, y: 212, width: 212, height: 52)
                )
            ]
        }
    }
}

public struct CanvasDocument: Codable, Hashable, Sendable {
    public var nodes: [CanvasNode]

    public init(nodes: [CanvasNode] = []) {
        self.nodes = nodes
    }

    public static func starter(radius: Double = 12) -> CanvasDocument {
        CanvasDocument(nodes: CanvasAutoCraftPreset.glassDashboard.buildNodes(radius: radius))
    }

    public mutating func alignNode(id: UUID, axis: CanvasAlignmentAxis, canvasSize: CGSize = CGSize(width: 560, height: 390), margin: Double = 24) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }), !nodes[idx].isLocked else { return }
        var frame = nodes[idx].frame
        let cw = Double(canvasSize.width)
        let ch = Double(canvasSize.height)

        switch axis {
        case .left:
            frame.x = margin
        case .centerH:
            frame.x = max(0, ((cw - frame.width) / 2.0 / 16.0).rounded() * 16.0)
        case .right:
            frame.x = max(0, cw - frame.width - margin)
        case .top:
            frame.y = margin
        case .centerV:
            frame.y = max(0, ((ch - frame.height) / 2.0 / 16.0).rounded() * 16.0)
        case .bottom:
            frame.y = max(0, ch - frame.height - margin)
        }
        nodes[idx].frame = frame.clamped(to: canvasSize)
    }

    /// Automatically packs unlocked blocks into clean 16pt-aligned rows with zero vertical overlap.
    public mutating func autoTidyGrid(maxWidth: Double = 540, spacing: Double = 16) {
        guard !nodes.isEmpty else { return }
        var cursorX: Double = 24
        var cursorY: Double = 24
        var rowHeight: Double = 0

        for idx in nodes.indices where !nodes[idx].isLocked {
            let w = nodes[idx].frame.width
            let h = nodes[idx].frame.height

            if cursorX > 24 && (cursorX + w) > maxWidth {
                cursorX = 24
                cursorY += rowHeight + spacing
                rowHeight = 0
            }

            nodes[idx].frame.x = cursorX
            nodes[idx].frame.y = cursorY
            cursorX += w + spacing
            rowHeight = max(rowHeight, h)
        }
    }

    public mutating func moveLayer(id: UUID, direction: Int) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(0, idx + direction), nodes.count - 1)
        guard target != idx else { return }
        let item = nodes.remove(at: idx)
        nodes.insert(item, at: target)
    }

    public func generateSwiftUICode(
        theme: StudioThemeTokens,
        layoutMode: CanvasCodeLayoutMode,
        focusedNodeID: UUID?,
        focusSelectedOnly: Bool
    ) -> String {
        if focusSelectedOnly, let focusedNodeID, let node = nodes.first(where: { $0.id == focusedNodeID }) {
            return """
            import SwiftBlocks
            import SwiftUI

            // Selected Block: \(node.kind.paletteTitle) ("\(node.title)")
            struct SelectedBlockPreview: View {
                var body: some View {
            \(node.swiftUISnippet(theme: theme, includeFrame: false).indented(by: 8))
                        .edkTheme(studioTheme)
                        .padding(\(Int(theme.spacingMD)))
                }
            }
            """
        }

        guard !nodes.isEmpty else {
            return """
            import SwiftBlocks
            import SwiftUI

            struct CustomBlocksCanvasView: View {
                var body: some View {
                    EDKSurface(variant: .glass, cornerRadius: \(Int(theme.radiusMedium.rounded()))) {
                        Text("Drop SwiftBlocks components onto the canvas to generate SwiftUI.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(\(Int(theme.spacingMD)))
                }
            }
            """
        }

        let bodyContent: String
        switch layoutMode {
        case .adaptiveStacks:
            let rows = groupedRows()
            let rowSnippets: [String] = rows.map { row in
                if row.count == 1 {
                    return row[0].swiftUISnippet(theme: theme, includeFrame: false)
                } else {
                    let children = row
                        .map { $0.swiftUISnippet(theme: theme, includeFrame: false).indented(by: 4) }
                        .joined(separator: "\n\n")
                    return """
                    HStack(alignment: .top, spacing: \(Int(theme.spacingMD))) {
                    \(children)
                    }
                    """
                }
            }
            let joinedRows = rowSnippets
                .map { $0.indented(by: 12) }
                .joined(separator: "\n\n")

            bodyContent = """
                    VStack(alignment: .leading, spacing: \(Int(theme.spacingMD))) {
            \(joinedRows)
                    }
                    .padding(\(Int(theme.spacingLG)))
            """
        case .positionedCanvas:
            let positioned = nodes
                .map { $0.swiftUISnippet(theme: theme, includeFrame: true).indented(by: 12) }
                .joined(separator: "\n\n")
            bodyContent = """
                    ZStack(alignment: .topLeading) {
            \(positioned)
                    }
                    .frame(minWidth: 560, minHeight: 380, alignment: .topLeading)
            """
        }

        return """
        import SwiftBlocks
        import SwiftUI

        struct CustomBlocksCanvasView: View {
            var body: some View {
        \(bodyContent)
                    .edkTheme(studioTheme)
            }
        }
        """
    }

    private func groupedRows() -> [[CanvasNode]] {
        let sorted = nodes.sorted {
            if abs($0.frame.y - $1.frame.y) <= 28 {
                return $0.frame.x < $1.frame.x
            }
            return $0.frame.y < $1.frame.y
        }

        var rows: [[CanvasNode]] = []
        for node in sorted {
            if let lastRow = rows.last,
               let anchor = lastRow.first,
               abs(node.frame.y - anchor.frame.y) <= 28 {
                rows[rows.count - 1].append(node)
                rows[rows.count - 1].sort { $0.frame.x < $1.frame.x }
            } else {
                rows.append([node])
            }
        }
        return rows
    }
}
