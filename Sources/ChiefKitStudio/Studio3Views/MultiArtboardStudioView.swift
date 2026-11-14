#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitDesignSystem
import ChiefKitStudioCore
import SwiftUI

struct MultiArtboardStudioView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    private enum WireframeRenderMode: String, CaseIterable, Identifiable {
        case ascii = "ASCII Wireframe"
        case svg = "W3C SVG Wireframe"

        var id: String { rawValue }
    }

    private enum RootAxisChoice: String, CaseIterable, Identifiable {
        case vertical = "Vertical Stack"
        case horizontal = "Horizontal Split"
        case twoColumnGrid = "2-Column Grid"

        var id: String { rawValue }

        var layoutAxis: LayoutAxis {
            switch self {
            case .vertical: .vertical
            case .horizontal: .horizontal
            case .twoColumnGrid: .grid(columns: 2, rowSpacing: 12.0)
            }
        }
    }

    @State private var workspace = ArtboardWorkspace.flagshipSuite()
    @State private var selectedPreset: ArtboardDevicePreset = .iPhone16Pro
    @State private var rootAxisChoice: RootAxisChoice = .vertical
    @State private var layoutSpacing: Double = 12.0
    @State private var outerPadding: Double = 16.0
    @State private var wireframeMode: WireframeRenderMode = .ascii
    @State private var selectedVectorIcon: ChiefKitVectorIcon = .liquidGlassCube
    @State private var showTessellatedMesh = false
    @State private var masterSymbolRevisionCount = 1

    private var sampleLayoutTree: LayoutNode {
        LayoutNode(
            name: "AdaptiveShellRoot",
            axis: rootAxisChoice.layoutAxis,
            widthPolicy: .fillAvailable,
            heightPolicy: .fillAvailable,
            padding: .all(outerPadding),
            spacing: layoutSpacing,
            alignment: .stretch,
            children: [
                LayoutNode(
                    name: "NavigationHeader",
                    axis: .horizontal,
                    widthPolicy: .fillAvailable,
                    heightPolicy: .fixed(52),
                    padding: .symmetric(horizontal: 12, vertical: 8),
                    spacing: 8
                ),
                LayoutNode(
                    name: "HeroKPIWall",
                    axis: .grid(columns: 2, rowSpacing: 10),
                    widthPolicy: .fillAvailable(weight: 1.5),
                    heightPolicy: .fixed(148),
                    padding: .all(12),
                    spacing: 10,
                    children: [
                        LayoutNode(name: "MRRCard", widthPolicy: .fillAvailable, heightPolicy: .fixed(56)),
                        LayoutNode(name: "LatencyCard", widthPolicy: .fillAvailable, heightPolicy: .fixed(56)),
                        LayoutNode(name: "RetentionCard", widthPolicy: .fillAvailable, heightPolicy: .fixed(56)),
                        LayoutNode(name: "ConversionCard", widthPolicy: .fillAvailable, heightPolicy: .fixed(56))
                    ]
                ),
                LayoutNode(
                    name: "ActivityStreamCard",
                    axis: .vertical,
                    widthPolicy: .fillAvailable(weight: 1.0),
                    heightPolicy: .fillAvailable,
                    padding: .all(12),
                    spacing: 8
                )
            ]
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            deviceMatrixAndMasterSymbolCard
            autoLayoutSolverCard
            vectorSVGInspectorCard
        }
    }

    // MARK: - 1. Multi-Device Artboard Matrix & Master Symbols

    private var deviceMatrixAndMasterSymbolCard: some View {
        let gridSpec = TypographyAndGridSystem.gridSpec(for: selectedPreset.associatedBreakpoint)

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Multi-Device Artboard Matrix & Master Symbols",
                        subtitle: "\(workspace.artboards.count) synchronized artboards spanning iPhone, iPad, Mac, Vision Pro & Watch."
                    )
                    Spacer()
                    PillLabel(
                        title: "\(Int(selectedPreset.logicalWidth))×\(Int(selectedPreset.logicalHeight)) @\(Int(selectedPreset.pixelScaleFactor))x",
                        systemImage: "rectangle.3.group"
                    )
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ArtboardDevicePreset.allCases) { preset in
                            let active = selectedPreset == preset
                            Button {
                                selectedPreset = preset
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(active ? .white : .primary)
                                    Text("\(Int(preset.logicalWidth))×\(Int(preset.logicalHeight))pt · R\(Int(preset.hardwareCornerRadius))")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(active ? .white.opacity(0.86) : .secondary)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    active ? theme.primary.swiftUIColor : Color.secondary.opacity(0.11),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], spacing: 8) {
                    artboardInfoTile("Breakpoint", gridSpec.breakpoint.title)
                    artboardInfoTile("Grid Columns", "\(gridSpec.columns) cols · \(Int(gridSpec.gutter))pt gutter")
                    artboardInfoTile("Outer Margin", "\(Int(gridSpec.outerMargin))pt · Max \(Int(gridSpec.maxContentWidth))pt")
                    artboardInfoTile(
                        "Single Col Width",
                        String(format: "%.1f pt", gridSpec.singleColumnWidth(forViewportWidth: selectedPreset.logicalWidth))
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        workspace.autoArrangeArtboardsHorizontally(spacing: 120.0)
                        viewModel.statusMessage = "Auto-arranged \(workspace.artboards.count) artboards horizontally across infinite canvas"
                    } label: {
                        Label("Auto-Arrange Artboards", systemImage: "rectangle.split.3x1")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        propagateMasterComponentUpdate()
                    } label: {
                        Label("Propagate Master Symbol v\(masterSymbolRevisionCount)", systemImage: "arrow.triangle.branch")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)

                    Spacer()

                    Text("World Union: \(Int(workspace.unionWorldBounds.width))×\(Int(workspace.unionWorldBounds.height)) pt")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. Deterministic Auto-Layout Constraint Solver

    private var autoLayoutSolverCard: some View {
        let solved = AutoLayoutConstraintSolver.solve(
            root: sampleLayoutTree,
            availableWidth: selectedPreset.logicalWidth,
            availableHeight: selectedPreset.logicalHeight
        )
        let breakpointMatrix = AutoLayoutConstraintSolver.solveAcrossBreakpoints(root: sampleLayoutTree)
        let wireframeOutput = wireframeMode == .ascii
            ? AutoLayoutConstraintSolver.renderASCIIWireframe(solved, columns: 66, rows: 16)
            : AutoLayoutConstraintSolver.renderSVGWireframe(solved, theme: theme, showDimensions: true)

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Deterministic Auto-Layout Constraint Solver",
                        subtitle: "Evaluate hug/fill/weighted flex sizing across all 8 Apple breakpoints with zero runtime ambiguity."
                    )
                    Spacer()
                    Picker("Wireframe", selection: $wireframeMode) {
                        ForEach(WireframeRenderMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }

                HStack(spacing: 12) {
                    Picker("Root Axis", selection: $rootAxisChoice) {
                        ForEach(RootAxisChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .frame(width: 215)
                    .controlSize(.small)

                    HStack(spacing: 6) {
                        Text("Spacing \(Int(layoutSpacing))pt")
                            .font(.caption)
                        Slider(value: $layoutSpacing, in: 4...28, step: 2)
                            .frame(width: 110)
                    }

                    HStack(spacing: 6) {
                        Text("Padding \(Int(outerPadding))pt")
                            .font(.caption)
                        Slider(value: $outerPadding, in: 8...36, step: 4)
                            .frame(width: 110)
                    }

                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DeviceBreakpoint.allCases) { bp in
                            if let box = breakpointMatrix[bp] {
                                let overflowCount = box.flattened().filter(\.isOverflowingParent).count
                                HStack(spacing: 5) {
                                    Image(systemName: overflowCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(overflowCount == 0 ? theme.success.swiftUIColor : theme.warning.swiftUIColor)
                                    Text("\(bp.title): \(Int(box.worldFrame.width))×\(Int(box.worldFrame.height))")
                                        .font(.system(size: 10.5, design: .monospaced))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial, in: Capsule())
                            }
                        }
                    }
                }

                CodeBlockView(text: wireframeOutput, showLineNumbers: wireframeMode == .svg)
                    .frame(minHeight: 195, maxHeight: 255)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. 42-Icon W3C SVG Path Engine & SwiftUI Shape Compiler

    private var vectorSVGInspectorCard: some View {
        let parsed = selectedVectorIcon.parsedPath()
        let normalized = parsed.normalizedToUnitSquare(preserveAspectRatio: true)
        let subpaths = normalized.flattenToSubpaths(flatness: 0.02)
        let triangles = normalized.tessellatePolygons(flatness: 0.03)
        let swiftUIShapeCode = selectedVectorIcon.emitSwiftUIShape()

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "42-Icon W3C SVG Path Parser & SwiftUI Shape Compiler",
                        subtitle: "Inspect normalized cubic segments, ear-clipped polygon tessellation, and zero-asset SwiftUI Shape code."
                    )
                    Spacer()
                    Toggle("Ear-Clip Mesh (\(triangles.count) Δ)", isOn: $showTessellatedMesh)
                        .toggleStyle(.switch)
                        .font(.caption)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ChiefKitVectorIcon.allCases) { icon in
                            let active = selectedVectorIcon == icon
                            Button {
                                selectedVectorIcon = icon
                            } label: {
                                Text(icon.rawValue)
                                    .font(.system(size: 11, weight: active ? .bold : .regular, design: .monospaced))
                                    .foregroundStyle(active ? .white : .primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        active ? theme.primary.swiftUIColor : Color.secondary.opacity(0.11),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Canvas { context, size in
                            let side = min(size.width, size.height) - 28
                            let ox = (size.width - side) * 0.5
                            let oy = (size.height - side) * 0.5

                            if showTessellatedMesh {
                                for tri in triangles {
                                    var tPath = Path()
                                    tPath.move(to: CGPoint(x: ox + tri.a.x * side, y: oy + tri.a.y * side))
                                    tPath.addLine(to: CGPoint(x: ox + tri.b.x * side, y: oy + tri.b.y * side))
                                    tPath.addLine(to: CGPoint(x: ox + tri.c.x * side, y: oy + tri.c.y * side))
                                    tPath.closeSubpath()
                                    context.stroke(tPath, with: .color(theme.warning.swiftUIColor.opacity(0.55)), lineWidth: 0.8)
                                }
                            }

                            var vectorPath = Path()
                            for poly in subpaths where !poly.isEmpty {
                                vectorPath.move(to: CGPoint(x: ox + poly[0].x * side, y: oy + poly[0].y * side))
                                for pt in poly.dropFirst() {
                                    vectorPath.addLine(to: CGPoint(x: ox + pt.x * side, y: oy + pt.y * side))
                                }
                            }
                            context.stroke(
                                vectorPath,
                                with: .color(theme.primary.swiftUIColor),
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                            )
                        }
                        .frame(width: 176, height: 176)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.60), in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.separator.opacity(0.40), lineWidth: 1)
                        }

                        Text(
                            String(
                                format: "%d cmds · %d segs · len %.1f",
                                parsed.commands.count,
                                parsed.segments.count,
                                parsed.totalPathLength
                            )
                        )
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)

                        Button {
                            viewModel.aiOverriddenCode[viewModel.selection] = swiftUIShapeCode
                            viewModel.rightInspectorTab = .code
                            viewModel.codePreviewMode = .swiftUI
                            viewModel.statusMessage = "Loaded '\(selectedVectorIcon.rawValue)' Shape into Live Code"
                        } label: {
                            Label("Send Shape to Inspector", systemImage: "arrow.up.right.square")
                                .font(.caption.weight(.semibold))
                                .frame(width: 176)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primary.swiftUIColor)
                        .controlSize(.small)
                    }

                    CodeBlockView(text: swiftUIShapeCode)
                        .frame(minHeight: 225, maxHeight: 255)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func propagateMasterComponentUpdate() {
        if let existingID = workspace.masterSymbols.keys.first {
            masterSymbolRevisionCount += 1
            let updatedInstances = workspace.updateMasterSymbol(masterID: existingID) { proto in
                proto.cornerRadius = theme.radiusMedium
                proto.subtitle = "Synced Rev #\(masterSymbolRevisionCount)"
            }
            viewModel.statusMessage = "Updated Master Symbol v\(masterSymbolRevisionCount) across \(updatedInstances) instance(s)"
        } else {
            let symbol = workspace.registerMasterSymbol(
                name: "PrimaryGlassHeader",
                prototype: CanvasNode(kind: .card, title: "Unified Header", subtitle: "Master v1", variant: .glass)
            )
            for idx in workspace.artboards.indices {
                let artID = workspace.artboards[idx].id
                _ = workspace.instantiateMasterSymbol(
                    masterID: symbol.id,
                    onArtboard: artID,
                    at: SVGPoint2D(x: 20, y: 20)
                )
            }
            masterSymbolRevisionCount = 1
            viewModel.statusMessage = "Registered Master Symbol and instantiated across \(workspace.artboards.count) artboards"
        }
    }

    private func artboardInfoTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
#endif
