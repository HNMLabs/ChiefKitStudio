#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct SwiftBlocksDemoView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            autoCraftCard
            paletteCard
            interactiveCanvasCard
            selectedNodeInspectorCard
        }
    }

    // MARK: - Auto-Craft Bar

    private var autoCraftCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Auto-Craft & Presets",
                        subtitle: "Generate editable SwiftBlocks layouts locally or pick a starter template."
                    )
                    Spacer()
                    PillLabel(title: "\(viewModel.canvasDocument.nodes.count) blocks", systemImage: "square.stack.3d.up")
                }

                HStack(spacing: 8) {
                    TextField(
                        "Describe a layout (e.g. \"login card\", \"pricing banner\", \"giriş ekranı\")…",
                        text: $viewModel.autoCraftPrompt
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.runAutoCraftFromPrompt()
                    }

                    Button {
                        viewModel.runAutoCraftFromPrompt()
                    } label: {
                        Label("Auto-Craft", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CanvasAutoCraftPreset.allCases) { preset in
                            Button {
                                viewModel.applyAutoCraftPreset(preset)
                            } label: {
                                Label(preset.rawValue, systemImage: preset.symbolName)
                                    .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Draggable Palette

    private var paletteCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Component Palette", systemImage: "hand.draw.fill")
                        .font(.headline)
                    Spacer()
                    Text("Drag onto canvas or click + to insert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 136), spacing: 8)], spacing: 8) {
                    ForEach(CanvasPaletteItem.library) { item in
                        Button {
                            viewModel.addPaletteItem(item)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.kind.symbolName)
                                    .foregroundStyle(theme.primary.swiftUIColor)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.kind.paletteTitle)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Text(item.badge)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 2)

                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(.separator.opacity(0.35), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .draggable("palette:\(item.id)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Embedded Drag-and-Drop Canvas

    private var interactiveCanvasCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        canvasToolbarTitle
                        Spacer()
                        canvasToolbarControls
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        canvasToolbarTitle
                        canvasToolbarControls
                    }
                }

                GeometryReader { proxy in
                    let canvasSize = CGSize(
                        width: max(360, proxy.size.width),
                        height: max(380, proxy.size.height)
                    )

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous)
                            .fill(theme.surface.swiftUIColor.opacity(0.55))
                            .overlay {
                                DesignCanvasGrid()
                                    .clipShape(RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous)
                                    .stroke(
                                        isDropTargeted ? theme.primary.swiftUIColor : Color.secondary.opacity(0.28),
                                        lineWidth: isDropTargeted ? 2.2 : 1
                                    )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectCanvasNode(nil)
                            }

                        if viewModel.canvasDocument.nodes.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "square.dashed.inset.filled")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                                Text("Drop SwiftBlocks Here")
                                    .font(.headline)
                                Text("Drag items from the Component Palette above or click an Auto-Craft preset.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        ForEach(viewModel.canvasDocument.nodes) { node in
                            InteractiveCanvasNodeView(
                                node: node,
                                isSelected: viewModel.selectedCanvasNodeID == node.id,
                                snapToGrid: viewModel.snapCanvasToGrid,
                                canvasSize: canvasSize,
                                onSelect: {
                                    viewModel.selectCanvasNode(node.id)
                                },
                                onBeginMutation: {
                                    viewModel.recordCanvasUndoCheckpoint()
                                },
                                onFrameChange: { nextFrame in
                                    viewModel.updateCanvasNodeFrame(id: node.id, frame: nextFrame)
                                }
                            )
                        }
                    }
                    .dropDestination(for: String.self) { items, location in
                        guard let first = items.first else { return false }
                        return viewModel.handleCanvasDrop(payload: first, at: location, canvasSize: canvasSize)
                    } isTargeted: { targeted in
                        isDropTargeted = targeted
                    }
                }
                .frame(height: 390)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var canvasToolbarTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SwiftBlocks Live Drag & Drop Canvas")
                .font(.headline)
            Text("Move, resize, align, auto-tidy, or undo/redo (⌘Z) — SwiftUI code updates live.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var canvasToolbarControls: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.undoCanvas()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .controlSize(.small)
            .disabled(!viewModel.canUndoCanvas)
            .help("Undo Canvas Edit (⌘Z)")

            Button {
                viewModel.redoCanvas()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .controlSize(.small)
            .disabled(!viewModel.canRedoCanvas)
            .help("Redo Canvas Edit (⇧⌘Z)")

            Button {
                viewModel.autoTidyCanvas()
            } label: {
                Label("Tidy Grid", systemImage: "square.grid.2x2")
                    .font(.caption)
            }
            .controlSize(.small)
            .help("Auto-arrange unlocked blocks onto a clean grid")

            Toggle("Snap 16pt", isOn: $viewModel.snapCanvasToGrid)
                .toggleStyle(.checkbox)
                .font(.caption)

            Toggle("Selected Only", isOn: $viewModel.focusSelectedNodeCode)
                .toggleStyle(.checkbox)
                .font(.caption)
                .help("Show SwiftUI code only for the selected canvas component")

            Picker("Layout", selection: $viewModel.canvasLayoutMode) {
                ForEach(CanvasCodeLayoutMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 140)

            Button(role: .destructive) {
                viewModel.clearCanvas()
            } label: {
                Image(systemName: "trash")
            }
            .controlSize(.small)
            .help("Clear all blocks on canvas")
        }
    }

    // MARK: - Selected Block Inspector

    private var selectedNodeInspectorCard: some View {
        GlassCard {
            if let selected = viewModel.selectedCanvasNode {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Selected Block: \(selected.kind.paletteTitle)", systemImage: selected.kind.symbolName)
                            .font(.headline)
                            .foregroundStyle(theme.primary.swiftUIColor)

                        Spacer()

                        Text("(\(Int(selected.frame.x)), \(Int(selected.frame.y))) · \(Int(selected.frame.width))×\(Int(selected.frame.height))pt")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Button {
                            viewModel.toggleLockSelectedCanvasNode()
                        } label: {
                            Label(selected.isLocked ? "Unlock" : "Lock", systemImage: selected.isLocked ? "lock.fill" : "lock.open")
                        }
                        .controlSize(.small)

                        Button {
                            viewModel.duplicateSelectedCanvasNode()
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .controlSize(.small)

                        Button {
                            viewModel.sendSelectedNodeBackward()
                        } label: {
                            Image(systemName: "square.2.layers.3d.bottom.filled")
                        }
                        .controlSize(.small)
                        .help("Send Backward")

                        Button {
                            viewModel.bringSelectedNodeToFront()
                        } label: {
                            Image(systemName: "square.2.layers.3d.top.filled")
                        }
                        .controlSize(.small)
                        .help("Bring Forward")

                        Button(role: .destructive) {
                            viewModel.deleteSelectedCanvasNode()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .controlSize(.small)
                    }

                    HStack(spacing: 6) {
                        Text("Align:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        ForEach(CanvasAlignmentAxis.allCases) { axis in
                            Button {
                                viewModel.alignSelectedCanvasNode(axis, canvasSize: CGSize(width: 640, height: 390))
                            } label: {
                                Label(axis.rawValue, systemImage: axis.symbolName)
                                    .labelStyle(.iconOnly)
                            }
                            .controlSize(.small)
                            .disabled(selected.isLocked)
                            .help(axis.rawValue)
                        }

                        Spacer()
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Title / Primary Label")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            TextField(
                                "Title",
                                text: Binding(
                                    get: { selected.title },
                                    set: { val in viewModel.updateSelectedCanvasNode { $0.title = val } }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subtitle / Value")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            TextField(
                                "Subtitle",
                                text: Binding(
                                    get: { selected.subtitle },
                                    set: { val in viewModel.updateSelectedCanvasNode { $0.subtitle = val } }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Semantic Variant")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Picker(
                                "Variant",
                                selection: Binding(
                                    get: { selected.variant },
                                    set: { v in viewModel.updateSelectedCanvasNode { $0.variant = v } }
                                )
                            ) {
                                ForEach(CanvasVariant.allCases) { variant in
                                    Text(variant.label).tag(variant)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Size")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Picker(
                                "Size",
                                selection: Binding(
                                    get: { selected.size },
                                    set: { s in viewModel.updateSelectedCanvasNode { $0.size = s } }
                                )
                            ) {
                                ForEach(CanvasComponentSize.allCases) { size in
                                    Text(size.rawValue.capitalized).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 190)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Corner Radius: \(Int(selected.cornerRadius)) pt")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Slider(
                                value: Binding(
                                    get: { selected.cornerRadius },
                                    set: { r in viewModel.updateSelectedCanvasNode { $0.cornerRadius = r } }
                                ),
                                in: 0...32,
                                step: 2
                            )
                            .tint(theme.primary.swiftUIColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    Image(systemName: "cursorarrow.click.2")
                        .foregroundStyle(.secondary)
                    Text("Click any block on the canvas above to edit its label, semantic variant, size, or corner radius.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Interactive Draggable & Resizable Node View

private struct InteractiveCanvasNodeView: View {
    @Environment(\.studioTheme) private var theme
    let node: CanvasNode
    let isSelected: Bool
    let snapToGrid: Bool
    let canvasSize: CGSize
    let onSelect: () -> Void
    let onBeginMutation: () -> Void
    let onFrameChange: (CanvasFrame) -> Void

    @State private var moveStartFrame: CanvasFrame?
    @State private var resizeStartFrame: CanvasFrame?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            renderedComponent
                .frame(width: node.frame.width, height: node.frame.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect()
                }
                .gesture(moveGesture)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: CGFloat(min(node.cornerRadius, 24)) + 2, style: .continuous)
                            .stroke(theme.primary.swiftUIColor, lineWidth: 2)
                    }
                }

            if isSelected {
                Circle()
                    .fill(theme.primary.swiftUIColor)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 6, y: 6)
                    .highPriorityGesture(resizeGesture)
            }
        }
        .offset(x: node.frame.x, y: node.frame.y)
    }

    @ViewBuilder
    private var renderedComponent: some View {
        let radius = CGFloat(node.cornerRadius)
        switch node.kind {
        case .button:
            HStack(spacing: 6) {
                Text(node.title)
                    .font(.system(size: node.size.fontSize, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(node.variant.foregroundColor(in: theme))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if node.variant == .glass {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(node.variant.fillColor(in: theme))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(theme.isLiquidGlassEnabled ? 0.35 : 0.12), lineWidth: 1)
            }

        case .card:
            VStack(alignment: .leading, spacing: 6) {
                Text(node.title)
                    .font(.system(size: node.size.fontSize + 1, weight: .bold))
                    .lineLimit(1)
                Text(node.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        theme.isLiquidGlassEnabled
                            ? theme.primary.swiftUIColor.opacity(0.35)
                            : Color.secondary.opacity(0.24),
                        lineWidth: 1
                    )
            }

        case .metric:
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(theme.primary.swiftUIColor)
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.success.swiftUIColor)
                }
                Text(node.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(node.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(theme.primary.swiftUIColor.opacity(0.28), lineWidth: 1)
            }

        case .text:
            VStack(alignment: .leading, spacing: 3) {
                Text(node.title)
                    .font(.system(size: node.size == .large ? 21 : 17, weight: .bold))
                    .lineLimit(1)
                Text(node.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        case .input:
            HStack(spacing: 8) {
                Image(systemName: "envelope")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(node.subtitle)
                        .font(.caption)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.85), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.separator.opacity(0.55), lineWidth: 1)
            }

        case .toggle:
            HStack {
                Text(node.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Capsule()
                    .fill(theme.primary.swiftUIColor)
                    .frame(width: 34, height: 20)
                    .overlay(alignment: .trailing) {
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .padding(.trailing, 2)
                    }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))

        case .badge:
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                Text(node.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(theme.primary.swiftUIColor)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.primary.swiftUIColor.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.primary.swiftUIColor.opacity(0.32), lineWidth: 1)
            }

        case .hStack:
            let actions = node.title
                .split(separator: "•")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            HStack(spacing: 8) {
                ForEach(actions.isEmpty ? ["Save", "Cancel"] : actions, id: \.self) { label in
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(theme.primary.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))

        case .spacer:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(.secondary.opacity(0.5))
                .overlay {
                    Text(node.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !node.isLocked else { return }
                if moveStartFrame == nil {
                    moveStartFrame = node.frame
                    onSelect()
                    onBeginMutation()
                }
                guard let start = moveStartFrame else { return }
                let next = start
                    .movedBy(
                        dx: Double(value.translation.width),
                        dy: Double(value.translation.height),
                        snapToGrid: snapToGrid
                    )
                    .clamped(to: canvasSize)
                onFrameChange(next)
            }
            .onEnded { _ in
                moveStartFrame = nil
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !node.isLocked else { return }
                if resizeStartFrame == nil {
                    resizeStartFrame = node.frame
                    onSelect()
                    onBeginMutation()
                }
                guard let start = resizeStartFrame else { return }
                let next = start
                    .resizedBy(
                        dw: Double(value.translation.width),
                        dh: Double(value.translation.height),
                        snapToGrid: snapToGrid
                    )
                    .clamped(to: canvasSize)
                onFrameChange(next)
            }
            .onEnded { _ in
                resizeStartFrame = nil
            }
    }
}

private struct DesignCanvasGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }

            context.stroke(path, with: .color(.secondary.opacity(0.14)), lineWidth: 0.5)
        }
    }
}
#endif
