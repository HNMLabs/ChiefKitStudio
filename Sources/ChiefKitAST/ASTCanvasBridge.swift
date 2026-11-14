#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Bidirectional Bridge Diagnostics & Results

/// Severity classification for AST <-> Canvas mapping diagnostics.
public enum ASTCanvasDiagnosticSeverity: String, Codable, Hashable, CaseIterable, Sendable {
    case info
    case approximated
    case unsupported
}

/// Diagnostic emitted when importing a SwiftUI AST construct onto the visual `CanvasDocument`.
public struct ASTCanvasMappingDiagnostic: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let severity: ASTCanvasDiagnosticSeverity
    public let componentName: String
    public let message: String
    public let span: SourceSpan

    public init(
        id: UUID = UUID(),
        severity: ASTCanvasDiagnosticSeverity,
        componentName: String,
        message: String,
        span: SourceSpan = .zero
    ) {
        self.id = id
        self.severity = severity
        self.componentName = componentName
        self.message = message
        self.span = span
    }
}

/// Result of importing SwiftUI source code or a parsed `SwiftSourceFile` into a visual `CanvasDocument`.
public struct ASTCanvasImportResult: Codable, Equatable, Sendable {
    public let document: CanvasDocument
    public let structName: String
    public let detectedLayoutMode: CanvasCodeLayoutMode
    public let diagnostics: [ASTCanvasMappingDiagnostic]
    public let importedNodeCount: Int

    public init(
        document: CanvasDocument,
        structName: String,
        detectedLayoutMode: CanvasCodeLayoutMode,
        diagnostics: [ASTCanvasMappingDiagnostic]
    ) {
        self.document = document
        self.structName = structName
        self.detectedLayoutMode = detectedLayoutMode
        self.diagnostics = diagnostics
        self.importedNodeCount = document.nodes.count
    }
}

/// Result of exporting a `CanvasDocument` into both a typed `SwiftSourceFile` AST and formatted Swift 6 source.
public struct ASTCanvasExportBundle: Codable, Equatable, Sendable {
    public let ast: SwiftSourceFile
    public let formattedSource: String
    public let nodeCount: Int

    public init(ast: SwiftSourceFile, formattedSource: String, nodeCount: Int) {
        self.ast = ast
        self.formattedSource = formattedSource
        self.nodeCount = nodeCount
    }
}

// MARK: - Bidirectional SwiftUI AST <-> CanvasDocument Bridge

/// Converts arbitrary SwiftUI source code into non-overlapping `CanvasDocument` blocks and exports `CanvasDocument` back to typed `SwiftSourceFile` ASTs.
public enum ASTCanvasBridge: Sendable {
    /// Parses SwiftUI source code and maps its view hierarchy onto a non-overlapping `CanvasDocument`.
    public static func importToCanvas(
        source: String,
        canvasWidth: Double = 640
    ) -> ASTCanvasImportResult {
        let ast = SwiftUIParser.parse(source: source)
        return importToCanvas(ast: ast, canvasWidth: canvasWidth)
    }

    /// Maps an already-parsed `SwiftSourceFile` AST onto a non-overlapping `CanvasDocument`.
    public static func importToCanvas(
        ast: SwiftSourceFile,
        canvasWidth: Double = 640
    ) -> ASTCanvasImportResult {
        var importer = CanvasASTImporter(canvasWidth: max(320, canvasWidth))
        return importer.performImport(from: ast)
    }

    /// Synthesizes a strongly-typed `SwiftSourceFile` AST from a `CanvasDocument` and `StudioThemeTokens`.
    public static func exportToAST(
        document: CanvasDocument,
        structName: String = "CustomBlocksCanvasView",
        theme: StudioThemeTokens = StudioThemeTokens(),
        layoutMode: CanvasCodeLayoutMode = .adaptiveStacks
    ) -> SwiftSourceFile {
        let builder = CanvasASTExporter(
            document: document,
            structName: sanitizeIdentifier(structName, fallback: "CustomBlocksCanvasView"),
            theme: theme,
            layoutMode: layoutMode
        )
        return builder.buildSourceFile()
    }

    /// Synthesizes a `SwiftSourceFile` AST from `CanvasDocument` and formats it via `SwiftFormatterEngine`.
    public static func exportToFormattedSwift(
        document: CanvasDocument,
        structName: String = "CustomBlocksCanvasView",
        theme: StudioThemeTokens = StudioThemeTokens(),
        layoutMode: CanvasCodeLayoutMode = .adaptiveStacks,
        formatConfig: SwiftFormatConfig = .chiefKitStandard
    ) -> ASTCanvasExportBundle {
        let ast = exportToAST(document: document, structName: structName, theme: theme, layoutMode: layoutMode)
        let formatted = SwiftFormatterEngine.format(ast: ast, config: formatConfig)
        return ASTCanvasExportBundle(ast: ast, formattedSource: formatted, nodeCount: document.nodes.count)
    }

    private static func sanitizeIdentifier(_ raw: String, fallback: String) -> String {
        let filtered = raw.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        guard let first = filtered.first else { return fallback }
        if first.isNumber { return "View_\(filtered)" }
        return filtered
    }
}

// MARK: - SwiftUI AST -> Canvas Importer

private struct CanvasASTImporter {
    let canvasWidth: Double
    let margin: Double = 24
    let gutter: Double = 16

    var cursorY: Double = 24
    var nodes: [CanvasNode] = []
    var diagnostics: [ASTCanvasMappingDiagnostic] = []
    var detectedMode: CanvasCodeLayoutMode = .adaptiveStacks

    init(canvasWidth: Double) {
        self.canvasWidth = canvasWidth
    }

    mutating func performImport(from file: SwiftSourceFile) -> ASTCanvasImportResult {
        for parseDiag in file.diagnostics where parseDiag.severity == .error {
            diagnostics.append(
                ASTCanvasMappingDiagnostic(severity: .approximated, componentName: "Parser", message: parseDiag.message, span: parseDiag.span)
            )
        }

        let structName: String
        let rootViews: [SwiftViewNode]

        if let viewType = file.primaryViewType {
            structName = viewType.name
            rootViews = viewType.bodyViewNodes
        } else if let preview = file.previews.first {
            structName = preview.title ?? "PreviewCanvasView"
            rootViews = preview.viewNodes
        } else {
            structName = file.types.first?.name ?? "ImportedCanvasView"
            rootViews = file.allViewNodes()
        }

        for root in rootViews {
            visitFlowNode(root)
        }

        resolveAnyRemainingFrameCollisions()

        return ASTCanvasImportResult(
            document: CanvasDocument(nodes: nodes),
            structName: structName,
            detectedLayoutMode: detectedMode,
            diagnostics: diagnostics
        )
    }

    mutating func visitFlowNode(_ node: SwiftViewNode) {
        // Detect positioned ZStack mode when children carry explicit `.offset(x:y:)`
        if node.containerKind == .zStack {
            let hasExplicitOffsets = node.children.contains { $0.hasModifier("offset") }
            if hasExplicitOffsets {
                detectedMode = .positionedCanvas
                for child in node.children {
                    importExplicitlyPositionedNode(child)
                }
                return
            }
        }

        // Check if this VStack itself is a compact Heading+Subtitle pair (`Text` + `Text`)
        if node.containerKind == .vStack, let headingNode = tryExtractHeadingStack(node) {
            placeFullRowNode(headingNode)
            return
        }

        // Check if this HStack is a pure row of compact action buttons (`EDKButton` / `Button`) vs multi-column layout row
        if node.containerKind == .hStack {
            importHorizontalRow(node)
            return
        }

        // Unwrap structural layout containers (`VStack`, `ScrollView`, `List`, `Form`, `Section`, `Group`, `NavigationStack`, `NavigationSplitView`, `ForEach`)
        switch node.containerKind {
        case .vStack, .lazyVStack, .scrollView, .list, .form, .section, .group,
             .navigationStack, .navigationSplitView, .tabView, .zStack, .grid, .gridRow, .forEach:
            for child in node.children {
                visitFlowNode(child)
            }
            return
        case .conditionalIf:
            diagnostics.append(
                ASTCanvasMappingDiagnostic(
                    severity: .info,
                    componentName: "if",
                    message: "Imported both conditional branches of 'if \(node.conditionDescription ?? "")' sequentially.",
                    span: node.span
                )
            )
            for child in node.children { visitFlowNode(child) }
            for child in node.elseChildren { visitFlowNode(child) }
            return
        case .conditionalSwitch:
            for switchCase in node.switchCases {
                for child in switchCase.viewChildren {
                    visitFlowNode(child)
                }
            }
            return
        default:
            break
        }

        if let mapped = mapSingleLeafOrSurface(node) {
            placeFullRowNode(mapped)
        }
    }

    mutating func importExplicitlyPositionedNode(_ node: SwiftViewNode) {
        guard var mapped = mapSingleLeafOrSurface(node) ?? tryExtractHeadingStack(node) else {
            for child in node.children {
                importExplicitlyPositionedNode(child)
            }
            return
        }

        var frame = mapped.frame
        if let frameMod = node.modifier(named: "frame") {
            if let w = frameMod.arguments.first(where: { $0.label == "width" })?.value.doubleValue {
                frame.width = max(84, w)
            }
            if let h = frameMod.arguments.first(where: { $0.label == "height" })?.value.doubleValue {
                frame.height = max(34, h)
            }
        }
        if let offsetMod = node.modifier(named: "offset") {
            if let x = offsetMod.arguments.first(where: { $0.label == "x" })?.value.doubleValue {
                frame.x = max(0, x)
            }
            if let y = offsetMod.arguments.first(where: { $0.label == "y" })?.value.doubleValue {
                frame.y = max(0, y)
            }
        }
        mapped.frame = frame
        nodes.append(mapped)
        cursorY = max(cursorY, frame.y + frame.height + gutter)
    }

    mutating func importHorizontalRow(_ hStack: SwiftViewNode) {
        // Distinguish pure compact small-button action bar (`HStack { EDKButton("Save", ..., size: .small) ... }`)
        let allButtons = !hStack.children.isEmpty && hStack.children.allSatisfy {
            $0.componentName == "EDKButton" || $0.componentName == "Button"
        }
        let hasSmallSize = hStack.children.contains { child in
            child.argument(labeled: "size")?.memberLeafName == "small"
        }

        if allButtons && hasSmallSize && hStack.children.count >= 2 {
            let titles = hStack.children.compactMap { extractButtonTitle($0) }
            let joined = titles.isEmpty ? CanvasComponentKind.hStack.defaultTitle : titles.joined(separator: " • ")
            let variant = extractVariant(from: hStack.children[0], fallback: .primary)
            let actionRow = CanvasNode(
                kind: .hStack,
                title: joined,
                subtitle: "\(titles.count) actions",
                variant: variant,
                size: .medium,
                cornerRadius: 10
            )
            placeFullRowNode(actionRow)
            return
        }

        // Otherwise lay out children side-by-side horizontally across `canvasWidth`, wrapping cleanly if needed
        var rowItems: [CanvasNode] = []
        for child in hStack.children {
            if let heading = (child.containerKind == .vStack ? tryExtractHeadingStack(child) : nil) {
                rowItems.append(heading)
            } else if let mapped = mapSingleLeafOrSurface(child) {
                rowItems.append(mapped)
            } else {
                for nested in child.children {
                    if let sub = mapSingleLeafOrSurface(nested) {
                        rowItems.append(sub)
                    }
                }
            }
        }

        guard !rowItems.isEmpty else { return }
        let usableWidth = max(240, canvasWidth - margin * 2)
        let count = Double(rowItems.count)
        let totalDefaultWidth = rowItems.reduce(0.0) { $0 + $1.frame.width } + gutter * max(0, count - 1)
        let scale = totalDefaultWidth > usableWidth ? usableWidth / totalDefaultWidth : 1.0

        var cursorX = margin
        var rowMaxHeight: Double = 0

        for idx in rowItems.indices {
            var item = rowItems[idx]
            let targetWidth = snap16(max(96, item.frame.width * scale))
            if cursorX > margin && (cursorX + targetWidth) > (canvasWidth - margin + 8) {
                cursorX = margin
                cursorY = snap16(cursorY + rowMaxHeight + gutter)
                rowMaxHeight = 0
            }
            item.frame = CanvasFrame(x: snap16(cursorX), y: snap16(cursorY), width: min(usableWidth, targetWidth), height: item.frame.height)
            nodes.append(item)
            cursorX += item.frame.width + gutter
            rowMaxHeight = max(rowMaxHeight, item.frame.height)
        }

        cursorY = snap16(cursorY + rowMaxHeight + gutter)
    }

    mutating func placeFullRowNode(_ prototype: CanvasNode) {
        var node = prototype
        let usableWidth = max(180, canvasWidth - margin * 2)
        let desiredWidth: Double
        switch node.kind {
        case .card, .text, .input, .toggle:
            desiredWidth = min(usableWidth, max(node.frame.width, snap16(usableWidth * 0.72)))
        case .button, .badge, .spacer, .metric, .hStack:
            desiredWidth = min(usableWidth, node.frame.width)
        }

        if let explicitModWidth = explicitDimension(from: node, axis: "width") {
            node.frame.width = explicitModWidth
        } else {
            node.frame.width = desiredWidth
        }

        node.frame.x = snap16(margin)
        node.frame.y = snap16(cursorY)
        nodes.append(node)
        cursorY = snap16(node.frame.y + node.frame.height + gutter)
    }

    func explicitDimension(from node: CanvasNode, axis: String) -> Double? {
        _ = axis
        _ = node
        return nil
    }

    func snap16(_ value: Double) -> Double {
        (value / 8.0).rounded() * 8.0
    }

    // MARK: Component Semantic Mapping

    mutating func tryExtractHeadingStack(_ vStack: SwiftViewNode) -> CanvasNode? {
        guard vStack.children.count == 2,
              vStack.children[0].componentName == "Text",
              vStack.children[1].componentName == "Text" else {
            return nil
        }
        let primaryText = extractTextString(vStack.children[0]) ?? CanvasComponentKind.text.defaultTitle
        let secondaryText = extractTextString(vStack.children[1]) ?? CanvasComponentKind.text.defaultSubtitle
        let size = inferSizeFromFontModifier(vStack.children[0], defaultSize: .large)
        return CanvasNode(
            kind: .text,
            title: primaryText,
            subtitle: secondaryText,
            variant: .dark,
            size: size,
            cornerRadius: 12,
            frame: CanvasComponentKind.text.defaultFrame
        )
    }

    mutating func mapSingleLeafOrSurface(_ node: SwiftViewNode) -> CanvasNode? {
        let radius = extractCornerRadius(from: node, fallback: 12)

        switch node.componentName {
        case "EDKButton", "Button":
            let title = extractButtonTitle(node) ?? CanvasComponentKind.button.defaultTitle
            let variant = extractVariant(from: node, fallback: .primary)
            let size = extractSize(from: node, fallback: .medium)
            var frame = CanvasComponentKind.button.defaultFrame
            applyExplicitFrameModifier(from: node, into: &frame)
            return CanvasNode(kind: .button, title: title, subtitle: "Action", variant: variant, size: size, cornerRadius: radius, frame: frame)

        case "EDKSurface", "GlassCard", "EDKCard":
            let variant = extractVariant(
                from: node,
                fallback: (node.componentName == "GlassCard" || node.hasModifier("edkLiquidGlass")) ? .glass : .light
            )
            let allInner = node.flattenedNodes()
            let textNodes = allInner.filter { $0.componentName == "Text" }
            let hasMetricLabel = allInner.contains { sub in
                sub.componentName == "Label" && (sub.firstUnlabeledStringArgument?.localizedCaseInsensitiveContains("Metric") == true
                    || sub.argument(labeled: "systemImage")?.stringLiteralValue?.contains("chart") == true)
            }
            let firstText = textNodes.first.flatMap(extractTextString) ?? ""
            let looksLikeMetricValue = hasMetricLabel
                || firstText.hasPrefix("$")
                || firstText.hasSuffix("%")
                || firstText.first?.isNumber == true

            if looksLikeMetricValue {
                let kpiValue = firstText.isEmpty ? CanvasComponentKind.metric.defaultTitle : firstText
                let kpiSub = textNodes.dropFirst().first.flatMap(extractTextString) ?? CanvasComponentKind.metric.defaultSubtitle
                var frame = CanvasComponentKind.metric.defaultFrame
                applyExplicitFrameModifier(from: node, into: &frame)
                return CanvasNode(
                    kind: .metric,
                    title: kpiValue,
                    subtitle: kpiSub,
                    variant: variant,
                    size: .medium,
                    cornerRadius: radius,
                    frame: frame
                )
            } else {
                let cardTitle = firstText.isEmpty ? CanvasComponentKind.card.defaultTitle : firstText
                let cardSub = textNodes.dropFirst().first.flatMap(extractTextString) ?? CanvasComponentKind.card.defaultSubtitle
                var frame = CanvasComponentKind.card.defaultFrame
                applyExplicitFrameModifier(from: node, into: &frame)
                return CanvasNode(
                    kind: .card,
                    title: cardTitle,
                    subtitle: cardSub,
                    variant: variant,
                    size: .medium,
                    cornerRadius: radius,
                    frame: frame
                )
            }

        case "Text":
            let content = extractTextString(node) ?? CanvasComponentKind.text.defaultTitle
            let size = inferSizeFromFontModifier(node, defaultSize: .medium)
            var frame = CanvasComponentKind.text.defaultFrame
            applyExplicitFrameModifier(from: node, into: &frame)
            return CanvasNode(kind: .text, title: content, subtitle: "SwiftUI Text", variant: .dark, size: size, cornerRadius: radius, frame: frame)

        case "Label", "EDKBadge":
            let labelTitle = node.firstUnlabeledStringArgument
                ?? node.argument(labeled: "title")?.stringLiteralValue
                ?? CanvasComponentKind.badge.defaultTitle
            let icon = node.argument(labeled: "systemImage")?.stringLiteralValue ?? "sparkles"
            var frame = CanvasComponentKind.badge.defaultFrame
            applyExplicitFrameModifier(from: node, into: &frame)
            return CanvasNode(kind: .badge, title: labelTitle, subtitle: icon, variant: .glass, size: .small, cornerRadius: 999, frame: frame)

        case "TextField", "SecureField":
            let placeholder = node.firstUnlabeledStringArgument
                ?? node.argument(labeled: "prompt")?.stringLiteralValue
                ?? CanvasComponentKind.input.defaultTitle
            let bindingPreview = extractBindingText(from: node.argument(labeled: "text"))
                ?? CanvasComponentKind.input.defaultSubtitle
            var frame = CanvasComponentKind.input.defaultFrame
            applyExplicitFrameModifier(from: node, into: &frame)
            return CanvasNode(
                kind: .input,
                title: placeholder,
                subtitle: bindingPreview,
                variant: .light,
                size: .medium,
                cornerRadius: max(8, radius),
                frame: frame
            )

        case "Toggle":
            let toggleTitle = node.firstUnlabeledStringArgument
                ?? node.children.first(where: { $0.componentName == "Text" }).flatMap(extractTextString)
                ?? CanvasComponentKind.toggle.defaultTitle
            var frame = CanvasComponentKind.toggle.defaultFrame
            applyExplicitFrameModifier(from: node, into: &frame)
            return CanvasNode(
                kind: .toggle,
                title: toggleTitle,
                subtitle: "Boolean Binding",
                variant: .primary,
                size: .medium,
                cornerRadius: radius,
                frame: frame
            )

        case "Spacer", "Divider":
            let minLen = node.argument(labeled: "minLength")?.doubleValue ?? 28
            var frame = CanvasComponentKind.spacer.defaultFrame
            frame.height = max(24, minLen)
            applyExplicitFrameModifier(from: node, into: &frame)
            return CanvasNode(
                kind: .spacer,
                title: node.componentName,
                subtitle: "\(Int(frame.height.rounded())) pt",
                variant: .light,
                size: .small,
                cornerRadius: 6,
                frame: frame
            )

        default:
            if !node.children.isEmpty {
                diagnostics.append(
                    ASTCanvasMappingDiagnostic(
                        severity: .approximated,
                        componentName: node.componentName,
                        message: "Mapped custom container '\(node.componentName)' as an EDK glass card surface.",
                        span: node.span
                    )
                )
                let texts = node.flattenedNodes().filter { $0.componentName == "Text" }.compactMap(extractTextString)
                return CanvasNode(
                    kind: .card,
                    title: texts.first ?? node.componentName,
                    subtitle: texts.dropFirst().first ?? "Imported custom container",
                    variant: .glass,
                    size: .medium,
                    cornerRadius: radius
                )
            }
            diagnostics.append(
                ASTCanvasMappingDiagnostic(
                    severity: .approximated,
                    componentName: node.componentName,
                    message: "Approximated custom leaf view '\(node.componentName)' as a badge block.",
                    span: node.span
                )
            )
            return CanvasNode(
                kind: .badge,
                title: node.firstUnlabeledStringArgument ?? node.componentName,
                subtitle: "Custom View",
                variant: .secondary,
                size: .medium,
                cornerRadius: radius
            )
        }
    }

    func extractButtonTitle(_ node: SwiftViewNode) -> String? {
        if let direct = node.firstUnlabeledStringArgument { return direct }
        if let titled = node.argument(labeled: "title")?.stringLiteralValue {
            return titled
        }
        for sub in node.flattenedNodes() {
            if sub.componentName == "Text", let text = extractTextString(sub) {
                return text
            }
            if sub.componentName == "Label", let text = sub.firstUnlabeledStringArgument {
                return text
            }
        }
        return nil
    }

    func extractTextString(_ node: SwiftViewNode) -> String? {
        if let s = node.firstUnlabeledStringArgument { return s }
        if let firstArg = node.arguments.first {
            return firstArg.value.stringLiteralValue ?? firstArg.value.renderedDescription
        }
        return nil
    }

    func extractBindingText(from expr: SwiftExpr?) -> String? {
        guard let expr else { return nil }
        switch expr {
        case .call(_, let args, _):
            return args.first?.value.stringLiteralValue
        case .dollarBinding(let raw):
            return raw
        default:
            return expr.renderedDescription
        }
    }

    func extractVariant(from node: SwiftViewNode, fallback: CanvasVariant) -> CanvasVariant {
        if let variantExpr = node.argument(labeled: "variant"),
           let leaf = variantExpr.memberLeafName,
           let parsed = CanvasVariant(rawValue: leaf) {
            return parsed
        }
        if node.hasModifier("edkLiquidGlass") {
            return .glass
        }
        if let roleExpr = node.argument(labeled: "role"), roleExpr.memberLeafName == "destructive" {
            return .danger
        }
        if let styleMod = node.modifier(named: "buttonStyle"),
           let leaf = styleMod.arguments.first?.value.memberLeafName {
            if leaf == "borderedProminent" { return .primary }
            if leaf == "bordered" { return .secondary }
        }
        return fallback
    }

    func extractSize(from node: SwiftViewNode, fallback: CanvasComponentSize) -> CanvasComponentSize {
        if let sizeExpr = node.argument(labeled: "size"),
           let leaf = sizeExpr.memberLeafName,
           let parsed = CanvasComponentSize(rawValue: leaf) {
            return parsed
        }
        if let ctrlMod = node.modifier(named: "controlSize"),
           let leaf = ctrlMod.arguments.first?.value.memberLeafName {
            switch leaf {
            case "small", "mini": return .small
            case "large", "extraLarge": return .large
            default: return .medium
            }
        }
        return fallback
    }

    func inferSizeFromFontModifier(_ node: SwiftViewNode, defaultSize: CanvasComponentSize) -> CanvasComponentSize {
        guard let fontMod = node.modifier(named: "font"),
              let fontArg = fontMod.arguments.first?.value else { return defaultSize }
        let desc = fontArg.renderedDescription
        if desc.contains("largeTitle") || desc.contains("title") {
            return .large
        }
        if desc.contains("caption") || desc.contains("footnote") {
            return .small
        }
        return .medium
    }

    func extractCornerRadius(from node: SwiftViewNode, fallback: Double) -> Double {
        if let argVal = node.argument(labeled: "cornerRadius")?.doubleValue {
            return argVal
        }
        if let glassMod = node.modifier(named: "edkLiquidGlass"),
           let r = glassMod.arguments.first(where: { $0.label == "cornerRadius" })?.value.doubleValue {
            return r
        }
        if let crMod = node.modifier(named: "cornerRadius"),
           let r = crMod.arguments.first?.value.doubleValue {
            return r
        }
        if let bgMod = node.modifier(named: "background"),
           bgMod.arguments.contains(where: { $0.value.renderedDescription.contains("Capsule") }) {
            return 999
        }
        return fallback
    }

    func applyExplicitFrameModifier(from node: SwiftViewNode, into frame: inout CanvasFrame) {
        guard let frameMod = node.modifier(named: "frame") else { return }
        if let w = frameMod.arguments.first(where: { $0.label == "width" })?.value.doubleValue {
            frame.width = max(84, w)
        }
        if let h = frameMod.arguments.first(where: { $0.label == "height" })?.value.doubleValue {
            frame.height = max(34, h)
        }
    }

    /// Guarantees zero overlapping node bounding boxes even when importing hand-edited `.offset` layouts.
    mutating func resolveAnyRemainingFrameCollisions() {
        guard nodes.count > 1 else { return }
        for i in 1..<nodes.count {
            var candidate = nodes[i].frame
            var safetyPass = 0
            while safetyPass < 32 {
                let colliding = (0..<i).first { j in
                    framesOverlap(candidate, nodes[j].frame)
                }
                guard let hitIdx = colliding else { break }
                candidate.y = snap16(nodes[hitIdx].frame.y + nodes[hitIdx].frame.height + gutter)
                safetyPass += 1
            }
            nodes[i].frame = candidate
        }
    }

    func framesOverlap(_ a: CanvasFrame, _ b: CanvasFrame) -> Bool {
        let horizontal = a.x < (b.x + b.width - 2) && (a.x + a.width - 2) > b.x
        let vertical = a.y < (b.y + b.height - 2) && (a.y + a.height - 2) > b.y
        return horizontal && vertical
    }
}

// MARK: - Canvas -> SwiftUI AST Exporter

private struct CanvasASTExporter {
    let document: CanvasDocument
    let structName: String
    let theme: StudioThemeTokens
    let layoutMode: CanvasCodeLayoutMode

    func buildSourceFile() -> SwiftSourceFile {
        let imports = [
            SwiftImportDecl(moduleName: "SwiftBlocks"),
            SwiftImportDecl(moduleName: "SwiftUI")
        ]

        let rootViewNode = buildBodyRootView()

        let bodyProp = SwiftPropertyDecl(
            name: "body",
            isLet: false,
            accessLevel: .public,
            typeAnnotation: "some View",
            isComputed: true,
            computedViewBody: [rootViewNode]
        )

        let viewStruct = SwiftTypeDecl(
            name: structName,
            kind: .struct,
            accessLevel: .public,
            attributes: [SwiftAttributeNode(kind: .mainActor)],
            conformances: ["View"],
            properties: [bodyProp],
            docComment: "Synthesized by ChiefKitAST from CanvasDocument (\(document.nodes.count) blocks)."
        )

        return SwiftSourceFile(imports: imports, types: [viewStruct], lineCount: max(12, document.nodes.count * 10))
    }

    func buildBodyRootView() -> SwiftViewNode {
        if document.nodes.isEmpty {
            return SwiftViewNode(
                componentName: "EDKSurface",
                containerKind: .edkSurface,
                arguments: [
                    SwiftModifierArg(label: "variant", value: .implicitMember("glass")),
                    SwiftModifierArg(label: "cornerRadius", value: .int(Int(theme.radiusMedium.rounded())))
                ],
                children: [
                    SwiftViewNode(
                        componentName: "Text",
                        arguments: [SwiftModifierArg(value: .string("Drop SwiftBlocks components onto the canvas to generate SwiftUI."))],
                        modifiers: [
                            SwiftModifierCall(name: "foregroundStyle", arguments: [SwiftModifierArg(value: .implicitMember("secondary"))])
                        ]
                    )
                ],
                modifiers: [
                    SwiftModifierCall(name: "padding", arguments: [SwiftModifierArg(value: .int(Int(theme.spacingMD)))]),
                    SwiftModifierCall(name: "edkTheme", arguments: [SwiftModifierArg(value: .identifier("studioTheme"))])
                ]
            )
        }

        switch layoutMode {
        case .adaptiveStacks:
            let rows = groupIntoVisualRows(document.nodes)
            let rowNodes: [SwiftViewNode] = rows.map { row in
                if row.count == 1 { return buildASTView(for: row[0], includeExplicitPosition: false) }
                return SwiftViewNode(
                    componentName: "HStack",
                    containerKind: .hStack,
                    arguments: [
                        SwiftModifierArg(label: "alignment", value: .implicitMember("top")),
                        SwiftModifierArg(label: "spacing", value: .int(Int(theme.spacingMD)))
                    ],
                    children: row.map { buildASTView(for: $0, includeExplicitPosition: false) }
                )
            }

            return SwiftViewNode(
                componentName: "VStack",
                containerKind: .vStack,
                arguments: [
                    SwiftModifierArg(label: "alignment", value: .implicitMember("leading")),
                    SwiftModifierArg(label: "spacing", value: .int(Int(theme.spacingMD)))
                ],
                children: rowNodes,
                modifiers: [
                    SwiftModifierCall(name: "padding", arguments: [SwiftModifierArg(value: .int(Int(theme.spacingLG)))]),
                    SwiftModifierCall(name: "edkTheme", arguments: [SwiftModifierArg(value: .identifier("studioTheme"))])
                ]
            )

        case .positionedCanvas:
            let positionedChildren = document.nodes.map { buildASTView(for: $0, includeExplicitPosition: true) }
            return SwiftViewNode(
                componentName: "ZStack",
                containerKind: .zStack,
                arguments: [
                    SwiftModifierArg(label: "alignment", value: .implicitMember("topLeading"))
                ],
                children: positionedChildren,
                modifiers: [
                    SwiftModifierCall(
                        name: "frame",
                        arguments: [
                            SwiftModifierArg(label: "minWidth", value: .int(560)),
                            SwiftModifierArg(label: "minHeight", value: .int(380)),
                            SwiftModifierArg(label: "alignment", value: .implicitMember("topLeading"))
                        ]
                    ),
                    SwiftModifierCall(name: "edkTheme", arguments: [SwiftModifierArg(value: .identifier("studioTheme"))])
                ]
            )
        }
    }

    func buildASTView(for node: CanvasNode, includeExplicitPosition: Bool) -> SwiftViewNode {
        let radius = Int(node.cornerRadius.rounded())
        var viewNode: SwiftViewNode

        switch node.kind {
        case .button:
            viewNode = SwiftViewNode(
                componentName: "EDKButton",
                containerKind: .button,
                arguments: [
                    SwiftModifierArg(value: .string(node.title)),
                    SwiftModifierArg(label: "variant", value: .implicitMember(node.variant.rawValue)),
                    SwiftModifierArg(label: "size", value: .implicitMember(node.size.rawValue))
                ]
            )

        case .card:
            var mods: [SwiftModifierCall] = []
            if node.variant == .glass || theme.isLiquidGlassEnabled {
                mods.append(SwiftModifierCall(name: "edkLiquidGlass", arguments: [SwiftModifierArg(label: "cornerRadius", value: .int(radius))]))
            }
            viewNode = SwiftViewNode(
                componentName: "EDKSurface",
                containerKind: .edkSurface,
                arguments: [
                    SwiftModifierArg(label: "variant", value: .implicitMember(node.variant.rawValue)),
                    SwiftModifierArg(label: "cornerRadius", value: .int(radius))
                ],
                children: [
                    SwiftViewNode(
                        componentName: "VStack",
                        containerKind: .vStack,
                        arguments: [
                            SwiftModifierArg(label: "alignment", value: .implicitMember("leading")),
                            SwiftModifierArg(label: "spacing", value: .int(Int(theme.spacingXS)))
                        ],
                        children: [
                            SwiftViewNode(
                                componentName: "Text",
                                arguments: [SwiftModifierArg(value: .string(node.title))],
                                modifiers: [SwiftModifierCall(name: "font", arguments: [SwiftModifierArg(value: .implicitMember("headline"))])]
                            ),
                            SwiftViewNode(
                                componentName: "Text",
                                arguments: [SwiftModifierArg(value: .string(node.subtitle))],
                                modifiers: [
                                    SwiftModifierCall(name: "font", arguments: [SwiftModifierArg(value: .implicitMember("subheadline"))]),
                                    SwiftModifierCall(name: "foregroundStyle", arguments: [SwiftModifierArg(value: .implicitMember("secondary"))])
                                ]
                            )
                        ]
                    )
                ],
                modifiers: mods
            )

        case .metric:
            var mods: [SwiftModifierCall] = []
            if node.variant == .glass || theme.isLiquidGlassEnabled {
                mods.append(SwiftModifierCall(name: "edkLiquidGlass", arguments: [SwiftModifierArg(label: "cornerRadius", value: .int(radius))]))
            }
            viewNode = SwiftViewNode(
                componentName: "EDKSurface",
                containerKind: .edkSurface,
                arguments: [
                    SwiftModifierArg(label: "variant", value: .implicitMember(node.variant.rawValue)),
                    SwiftModifierArg(label: "cornerRadius", value: .int(radius))
                ],
                children: [
                    SwiftViewNode(
                        componentName: "VStack",
                        containerKind: .vStack,
                        arguments: [
                            SwiftModifierArg(label: "alignment", value: .implicitMember("leading")),
                            SwiftModifierArg(label: "spacing", value: .int(6))
                        ],
                        children: [
                            SwiftViewNode(
                                componentName: "Label",
                                arguments: [
                                    SwiftModifierArg(value: .string("Metric")),
                                    SwiftModifierArg(label: "systemImage", value: .string("chart.line.uptrend.xyaxis"))
                                ],
                                modifiers: [
                                    SwiftModifierCall(name: "font", arguments: [SwiftModifierArg(value: .implicitMember("caption"))]),
                                    SwiftModifierCall(name: "foregroundStyle", arguments: [SwiftModifierArg(value: .implicitMember("secondary"))])
                                ]
                            ),
                            SwiftViewNode(
                                componentName: "Text",
                                arguments: [SwiftModifierArg(value: .string(node.title))],
                                modifiers: [SwiftModifierCall(name: "font", arguments: [SwiftModifierArg(value: .implicitMember("title"))])]
                            ),
                            SwiftViewNode(
                                componentName: "Text",
                                arguments: [SwiftModifierArg(value: .string(node.subtitle))],
                                modifiers: [
                                    SwiftModifierCall(name: "font", arguments: [SwiftModifierArg(value: .implicitMember("caption"))]),
                                    SwiftModifierCall(name: "foregroundStyle", arguments: [SwiftModifierArg(value: .implicitMember("secondary"))])
                                ]
                            )
                        ]
                    )
                ],
                modifiers: mods
            )

        case .text:
            viewNode = SwiftViewNode(
                componentName: "VStack",
                containerKind: .vStack,
                arguments: [
                    SwiftModifierArg(label: "alignment", value: .implicitMember("leading")),
                    SwiftModifierArg(label: "spacing", value: .int(4))
                ],
                children: [
                    SwiftViewNode(
                        componentName: "Text",
                        arguments: [SwiftModifierArg(value: .string(node.title))],
                        modifiers: [SwiftModifierCall(name: "font", arguments: [SwiftModifierArg(value: .implicitMember("title2"))])]
                    ),
                    SwiftViewNode(
                        componentName: "Text",
                        arguments: [SwiftModifierArg(value: .string(node.subtitle))],
                        modifiers: [
                            SwiftModifierCall(name: "font", arguments: [SwiftModifierArg(value: .implicitMember("subheadline"))]),
                            SwiftModifierCall(name: "foregroundStyle", arguments: [SwiftModifierArg(value: .implicitMember("secondary"))])
                        ]
                    )
                ]
            )

        case .input:
            let constantBinding = SwiftExpr.call(
                callee: .implicitMember("constant"),
                arguments: [SwiftCallArgument(value: .string(node.subtitle))],
                trailingClosure: nil
            )
            viewNode = SwiftViewNode(
                componentName: "TextField",
                arguments: [
                    SwiftModifierArg(value: .string(node.title)),
                    SwiftModifierArg(label: "text", value: constantBinding)
                ],
                modifiers: [
                    SwiftModifierCall(name: "textFieldStyle", arguments: [SwiftModifierArg(value: .implicitMember("roundedBorder"))])
                ]
            )

        case .toggle:
            let constantOn = SwiftExpr.call(
                callee: .implicitMember("constant"),
                arguments: [SwiftCallArgument(value: .bool(true))],
                trailingClosure: nil
            )
            viewNode = SwiftViewNode(
                componentName: "Toggle",
                arguments: [
                    SwiftModifierArg(value: .string(node.title)),
                    SwiftModifierArg(label: "isOn", value: constantOn)
                ],
                modifiers: [
                    SwiftModifierCall(name: "toggleStyle", arguments: [SwiftModifierArg(value: .implicitMember("switch"))])
                ]
            )

        case .badge:
            viewNode = SwiftViewNode(
                componentName: "Label",
                arguments: [
                    SwiftModifierArg(value: .string(node.title)),
                    SwiftModifierArg(label: "systemImage", value: .string("sparkles"))
                ],
                modifiers: [
                    SwiftModifierCall(name: "font", arguments: [SwiftModifierArg(value: .implicitMember("caption"))]),
                    SwiftModifierCall(
                        name: "padding",
                        arguments: [
                            SwiftModifierArg(value: .implicitMember("horizontal")),
                            SwiftModifierArg(value: .int(10))
                        ]
                    ),
                    SwiftModifierCall(
                        name: "padding",
                        arguments: [
                            SwiftModifierArg(value: .implicitMember("vertical")),
                            SwiftModifierArg(value: .int(6))
                        ]
                    ),
                    SwiftModifierCall(
                        name: "background",
                        arguments: [
                            SwiftModifierArg(value: .implicitMember("ultraThinMaterial")),
                            SwiftModifierArg(label: "in", value: .call(callee: .identifier("Capsule"), arguments: [], trailingClosure: nil))
                        ]
                    )
                ]
            )

        case .hStack:
            let parts = node.title
                .split(separator: "•")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let labels = parts.isEmpty ? ["Save", "Cancel"] : parts
            let childButtons = labels.map { label in
                SwiftViewNode(
                    componentName: "EDKButton",
                    containerKind: .button,
                    arguments: [
                        SwiftModifierArg(value: .string(label)),
                        SwiftModifierArg(label: "variant", value: .implicitMember(node.variant.rawValue)),
                        SwiftModifierArg(label: "size", value: .implicitMember("small"))
                    ]
                )
            }
            viewNode = SwiftViewNode(
                componentName: "HStack",
                containerKind: .hStack,
                arguments: [
                    SwiftModifierArg(label: "spacing", value: .int(Int(theme.spacingSM)))
                ],
                children: childButtons
            )

        case .spacer:
            viewNode = SwiftViewNode(
                componentName: "Spacer",
                arguments: [
                    SwiftModifierArg(label: "minLength", value: .int(Int(node.frame.height.rounded())))
                ]
            )
        }

        if includeExplicitPosition {
            viewNode.modifiers.append(
                SwiftModifierCall(
                    name: "frame",
                    arguments: [
                        SwiftModifierArg(label: "width", value: .int(Int(node.frame.width.rounded()))),
                        SwiftModifierArg(label: "height", value: .int(Int(node.frame.height.rounded())))
                    ]
                )
            )
            viewNode.modifiers.append(
                SwiftModifierCall(
                    name: "offset",
                    arguments: [
                        SwiftModifierArg(label: "x", value: .int(Int(node.frame.x.rounded()))),
                        SwiftModifierArg(label: "y", value: .int(Int(node.frame.y.rounded())))
                    ]
                )
            )
        }

        return viewNode
    }

    func groupIntoVisualRows(_ items: [CanvasNode]) -> [[CanvasNode]] {
        let sorted = items.sorted {
            if abs($0.frame.y - $1.frame.y) <= 28 { return $0.frame.x < $1.frame.x }
            return $0.frame.y < $1.frame.y
        }
        var rows: [[CanvasNode]] = []
        for item in sorted {
            if let last = rows.last, let anchor = last.first, abs(item.frame.y - anchor.frame.y) <= 28 {
                rows[rows.count - 1].append(item)
                rows[rows.count - 1].sort { $0.frame.x < $1.frame.x }
            } else {
                rows.append([item])
            }
        }
        return rows
    }
}
