#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Transformation Passes & Results

/// Automated AST-to-AST refactoring and modernization passes supported by `ASTTransformationEngine`.
public enum ASTTransformPass: Codable, Hashable, Sendable {
    case extractSubview(targetNodeName: String, newStructName: String)
    case migrateToObservableMacro
    case tokenizeMagicLiterals
    case injectVoiceOverAndDynamicType
    case liftStateToSwiftStateReducer
    case instrumentTimelineTelemetry

    public var displayName: String {
        switch self {
        case .extractSubview(let target, let newName):
            return "Extract Subview (\(target) -> \(newName))"
        case .migrateToObservableMacro:
            return "Migrate Combine to @Observable"
        case .tokenizeMagicLiterals:
            return "Tokenize Magic Literals to EDKTheme"
        case .injectVoiceOverAndDynamicType:
            return "Inject VoiceOver & Dynamic Type"
        case .liftStateToSwiftStateReducer:
            return "Lift @State to SwiftState Reducer"
        case .instrumentTimelineTelemetry:
            return "Instrument Timeline Telemetry"
        }
    }
}

/// Describes an individual AST modification performed by a refactoring pass.
public struct ASTTransformEdit: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let passName: String
    public let symbolName: String
    public let summary: String

    public init(id: UUID = UUID(), passName: String, symbolName: String, summary: String) {
        self.id = id
        self.passName = passName
        self.symbolName = symbolName
        self.summary = summary
    }
}

/// Complete output of applying one or more `ASTTransformPass` operations to Swift source code or AST.
public struct ASTTransformResult: Codable, Equatable, Sendable {
    public let transformedAST: SwiftSourceFile
    public let formattedSource: String
    public let edits: [ASTTransformEdit]
    public let didModify: Bool

    public init(
        transformedAST: SwiftSourceFile,
        formattedSource: String,
        edits: [ASTTransformEdit],
        didModify: Bool
    ) {
        self.transformedAST = transformedAST
        self.formattedSource = formattedSource
        self.edits = edits
        self.didModify = didModify
    }
}

// MARK: - AST Transformation Engine

/// Pure `Sendable` compiler transformation engine executing automated Swift 6 & SwiftUI AST refactorings.
public enum ASTTransformationEngine: Sendable {
    /// Parses `source`, executes a single `ASTTransformPass`, and pretty-prints the rewritten AST.
    public static func apply(
        pass: ASTTransformPass,
        to source: String,
        theme: StudioThemeTokens = StudioThemeTokens(),
        formatConfig: SwiftFormatConfig = .chiefKitStandard
    ) -> ASTTransformResult {
        let ast = SwiftUIParser.parse(source: source)
        return apply(pass: pass, to: ast, theme: theme, formatConfig: formatConfig)
    }

    /// Executes a single `ASTTransformPass` directly on a `SwiftSourceFile` AST.
    public static func apply(
        pass: ASTTransformPass,
        to ast: SwiftSourceFile,
        theme: StudioThemeTokens = StudioThemeTokens(),
        formatConfig: SwiftFormatConfig = .chiefKitStandard
    ) -> ASTTransformResult {
        var rewriter = ASTPassRewriter(theme: theme)
        let updatedAST = rewriter.run(pass: pass, on: ast)
        let formatted = SwiftFormatterEngine.format(ast: updatedAST, config: formatConfig)
        return ASTTransformResult(
            transformedAST: updatedAST,
            formattedSource: formatted,
            edits: rewriter.edits,
            didModify: !rewriter.edits.isEmpty || updatedAST != ast
        )
    }

    /// Runs an ordered sequence of `ASTTransformPass` refactorings as a multi-pass compiler pipeline.
    public static func applyPipeline(
        passes: [ASTTransformPass],
        to source: String,
        theme: StudioThemeTokens = StudioThemeTokens(),
        formatConfig: SwiftFormatConfig = .chiefKitStandard
    ) -> ASTTransformResult {
        var currentAST = SwiftUIParser.parse(source: source)
        var allEdits: [ASTTransformEdit] = []

        for pass in passes {
            var rewriter = ASTPassRewriter(theme: theme)
            currentAST = rewriter.run(pass: pass, on: currentAST)
            allEdits.append(contentsOf: rewriter.edits)
        }

        let formatted = SwiftFormatterEngine.format(ast: currentAST, config: formatConfig)
        return ASTTransformResult(transformedAST: currentAST, formattedSource: formatted, edits: allEdits, didModify: !allEdits.isEmpty)
    }
}

// MARK: - Internal AST Rewriter Passes

private struct ASTPassRewriter {
    let theme: StudioThemeTokens
    var edits: [ASTTransformEdit] = []

    init(theme: StudioThemeTokens) {
        self.theme = theme
    }

    mutating func record(_ pass: ASTTransformPass, symbol: String, summary: String) {
        edits.append(ASTTransformEdit(passName: pass.displayName, symbolName: symbol, summary: summary))
    }

    mutating func run(pass: ASTTransformPass, on file: SwiftSourceFile) -> SwiftSourceFile {
        switch pass {
        case .extractSubview(let targetNodeName, let newStructName):
            return passExtractSubview(file, targetNodeName: targetNodeName, newStructName: newStructName)
        case .migrateToObservableMacro:
            return passMigrateObservable(file)
        case .tokenizeMagicLiterals:
            return passTokenizeMagicLiterals(file)
        case .injectVoiceOverAndDynamicType:
            return passInjectVoiceOverAndDynamicType(file)
        case .liftStateToSwiftStateReducer:
            return passLiftStateToReducer(file)
        case .instrumentTimelineTelemetry:
            return passInstrumentTelemetry(file)
        }
    }

    // MARK: Pass 1 — Extract Subview

    mutating func passExtractSubview(
        _ file: SwiftSourceFile,
        targetNodeName: String,
        newStructName: String
    ) -> SwiftSourceFile {
        var updated = file
        let pass = ASTTransformPass.extractSubview(targetNodeName: targetNodeName, newStructName: newStructName)
        let cleanStructName = sanitizeIdentifier(newStructName, fallback: "ExtractedSubview")
        var synthesizedTypes: [SwiftTypeDecl] = []

        for tIdx in updated.types.indices where updated.types[tIdx].isSwiftUIView {
            let parentView = updated.types[tIdx]
            let parentPropMap = Dictionary(
                uniqueKeysWithValues: parentView.properties.map { ($0.name, $0) }
            )

            for pIdx in updated.types[tIdx].properties.indices where updated.types[tIdx].properties[pIdx].isComputed {
                var extractedSubtree: SwiftViewNode?
                var bodyNodes = updated.types[tIdx].properties[pIdx].computedViewBody

                for nIdx in bodyNodes.indices where extractedSubtree == nil {
                    bodyNodes[nIdx] = replaceMatchingSubview(
                        in: bodyNodes[nIdx],
                        targetName: targetNodeName,
                        replacementName: cleanStructName,
                        isRootOfBody: bodyNodes.count == 1 && bodyNodes[nIdx].children.count > 1,
                        capturedOut: &extractedSubtree
                    )
                }

                if let captured = extractedSubtree {
                    let referencedIDs = captured.allReferencedIdentifiers()
                    var forwardedProps: [SwiftPropertyDecl] = []
                    var callArgs: [SwiftModifierArg] = []

                    for propName in referencedIDs.sorted() {
                        guard let origProp = parentPropMap[propName], propName != "body" else { continue }
                        let propType = origProp.typeAnnotation ?? inferExprType(origProp.initializer) ?? "String"
                        if origProp.hasWrapper(.state) || origProp.hasWrapper(.binding) {
                            forwardedProps.append(
                                SwiftPropertyDecl(
                                    name: propName,
                                    isLet: false,
                                    typeAnnotation: propType,
                                    wrappers: [SwiftPropertyWrapper(kind: .binding)]
                                )
                            )
                            callArgs.append(SwiftModifierArg(label: propName, value: .dollarBinding("$\(propName)")))
                        } else if !origProp.isComputed {
                            forwardedProps.append(SwiftPropertyDecl(name: propName, isLet: true, typeAnnotation: propType))
                            callArgs.append(SwiftModifierArg(label: propName, value: .identifier(propName)))
                        }
                    }

                    // Update call arguments on the inserted placeholder node if bindings/props were forwarded
                    if !callArgs.isEmpty {
                        bodyNodes = bodyNodes.map { injectArgumentsOnPlaceholder($0, name: cleanStructName, args: callArgs) }
                    }
                    updated.types[tIdx].properties[pIdx].computedViewBody = bodyNodes

                    let subviewBody = SwiftPropertyDecl(
                        name: "body",
                        isLet: false,
                        accessLevel: parentView.accessLevel,
                        typeAnnotation: "some View",
                        isComputed: true,
                        computedViewBody: [captured]
                    )
                    let subviewStruct = SwiftTypeDecl(
                        name: cleanStructName,
                        kind: .struct,
                        accessLevel: parentView.accessLevel,
                        attributes: [SwiftAttributeNode(kind: .mainActor)],
                        conformances: ["View"],
                        properties: forwardedProps + [subviewBody],
                        docComment: "Extracted from '\(parentView.name)' via ChiefKitAST."
                    )
                    synthesizedTypes.append(subviewStruct)
                    record(pass, symbol: parentView.name, summary: "Extracted '\(captured.componentName)' subtree into '\(cleanStructName)'.")
                    break
                }
            }
        }

        updated.types.append(contentsOf: synthesizedTypes)
        return updated
    }

    func replaceMatchingSubview(
        in node: SwiftViewNode,
        targetName: String,
        replacementName: String,
        isRootOfBody: Bool,
        capturedOut: inout SwiftViewNode?
    ) -> SwiftViewNode {
        if capturedOut != nil { return node }

        let matchesComponent = node.componentName == targetName
        let matchesTitle = node.firstUnlabeledStringArgument == targetName

        if !isRootOfBody && (matchesComponent || matchesTitle) {
            capturedOut = node
            return SwiftViewNode(componentName: replacementName, containerKind: .leaf)
        }

        var copy = node
        for idx in copy.children.indices where capturedOut == nil {
            copy.children[idx] = replaceMatchingSubview(
                in: copy.children[idx],
                targetName: targetName,
                replacementName: replacementName,
                isRootOfBody: false,
                capturedOut: &capturedOut
            )
        }
        for idx in copy.elseChildren.indices where capturedOut == nil {
            copy.elseChildren[idx] = replaceMatchingSubview(
                in: copy.elseChildren[idx],
                targetName: targetName,
                replacementName: replacementName,
                isRootOfBody: false,
                capturedOut: &capturedOut
            )
        }
        return copy
    }

    func injectArgumentsOnPlaceholder(_ node: SwiftViewNode, name: String, args: [SwiftModifierArg]) -> SwiftViewNode {
        var copy = node
        if copy.componentName == name && copy.arguments.isEmpty {
            copy.arguments = args
        }
        copy.children = copy.children.map { injectArgumentsOnPlaceholder($0, name: name, args: args) }
        copy.elseChildren = copy.elseChildren.map { injectArgumentsOnPlaceholder($0, name: name, args: args) }
        return copy
    }

    // MARK: Pass 2 — Migrate Combine (`ObservableObject`) to `@Observable`

    mutating func passMigrateObservable(_ file: SwiftSourceFile) -> SwiftSourceFile {
        var updated = file
        let pass = ASTTransformPass.migrateToObservableMacro
        var needsObservationImport = false

        for idx in updated.types.indices {
            updated.types[idx] = rewriteTypeForObservable(updated.types[idx], pass: pass, needsObservationOut: &needsObservationImport)
        }

        if needsObservationImport {
            let alreadyImported = updated.imports.contains { $0.moduleName == "Observation" }
            if !alreadyImported {
                updated.imports.append(SwiftImportDecl(moduleName: "Observation"))
            }
            // Remove `import Combine` if no Combine publishers remain
            updated.imports.removeAll { $0.moduleName == "Combine" }
        }

        return updated
    }

    mutating func rewriteTypeForObservable(
        _ decl: SwiftTypeDecl,
        pass: ASTTransformPass,
        needsObservationOut: inout Bool
    ) -> SwiftTypeDecl {
        var updated = decl

        // 1. Upgrade ObservableObject class -> @Observable class
        if updated.conformances.contains("ObservableObject") {
            needsObservationOut = true
            updated.conformances.removeAll { $0 == "ObservableObject" }
            if !updated.attributes.contains(where: { $0.kind == .observable }) {
                updated.attributes.insert(SwiftAttributeNode(kind: .observable), at: 0)
            }
            for pIdx in updated.properties.indices {
                if updated.properties[pIdx].hasWrapper(.published) {
                    updated.properties[pIdx].wrappers.removeAll { $0.kind == .published }
                    updated.properties[pIdx].attributes.removeAll { $0.kind == .published }
                }
            }
            record(pass, symbol: updated.name, summary: "Migrated 'ObservableObject' class '\(updated.name)' to '@Observable' and stripped '@Published'.")
        }

        // Collect all `$dollarBinding` references inside body to decide whether `@ObservedObject` needs `@Bindable`
        let bodyDollarIdentifiers: Set<String> = Set(
            updated.bodyViewNodes.flatMap { $0.allReferencedIdentifiers() }
        )
        let usesDollarBindingInBody = updated.bodyViewNodes.contains { viewUsesDollarPrefix($0) }

        // 2. Upgrade View wrappers (@StateObject -> @State, @ObservedObject -> @Bindable / plain, @EnvironmentObject -> @Environment)
        for pIdx in updated.properties.indices {
            var prop = updated.properties[pIdx]
            if prop.hasWrapper(.stateObject) {
                needsObservationOut = true
                prop.wrappers = prop.wrappers.map { $0.kind == .stateObject ? SwiftPropertyWrapper(kind: .state) : $0 }
                record(pass, symbol: "\(updated.name).\(prop.name)", summary: "Converted '@StateObject' on '\(prop.name)' to '@State'.")
            } else if prop.hasWrapper(.observedObject) {
                needsObservationOut = true
                if usesDollarBindingInBody && bodyDollarIdentifiers.contains(prop.name) {
                    prop.wrappers = prop.wrappers.map { $0.kind == .observedObject ? SwiftPropertyWrapper(kind: .bindable) : $0 }
                    record(pass, symbol: "\(updated.name).\(prop.name)", summary: "Converted '@ObservedObject' on '\(prop.name)' to '@Bindable'.")
                } else {
                    prop.wrappers.removeAll { $0.kind == .observedObject }
                    record(pass, symbol: "\(updated.name).\(prop.name)", summary: "Removed '@ObservedObject' from '\(prop.name)' for direct '@Observable' tracking.")
                }
            } else if prop.hasWrapper(.environmentObject) {
                needsObservationOut = true
                let modelType = prop.typeAnnotation ?? "AppModel"
                let envArg = SwiftModifierArg(value: .memberAccess(base: .identifier(modelType), member: "self"))
                prop.wrappers = [SwiftPropertyWrapper(kind: .environment, arguments: [envArg])]
                record(pass, symbol: "\(updated.name).\(prop.name)", summary: "Converted '@EnvironmentObject' on '\(prop.name)' to '@Environment(\(modelType).self)'.")
            }
            updated.properties[pIdx] = prop
        }

        for nIdx in updated.nestedTypes.indices {
            updated.nestedTypes[nIdx] = rewriteTypeForObservable(updated.nestedTypes[nIdx], pass: pass, needsObservationOut: &needsObservationOut)
        }
        return updated
    }

    func viewUsesDollarPrefix(_ node: SwiftViewNode) -> Bool {
        for arg in node.arguments {
            if case .dollarBinding = arg.value { return true }
            if arg.value.renderedDescription.contains("$") { return true }
        }
        return node.children.contains(where: viewUsesDollarPrefix)
            || node.elseChildren.contains(where: viewUsesDollarPrefix)
    }

    // MARK: Pass 3 — Tokenize Magic Literals to `StudioThemeTokens` / `EDKTheme`

    mutating func passTokenizeMagicLiterals(_ file: SwiftSourceFile) -> SwiftSourceFile {
        var updated = file
        let pass = ASTTransformPass.tokenizeMagicLiterals

        for tIdx in updated.types.indices where updated.types[tIdx].isSwiftUIView {
            var didTokenizeInView = false
            let viewName = updated.types[tIdx].name

            for pIdx in updated.types[tIdx].properties.indices where updated.types[tIdx].properties[pIdx].isComputed {
                updated.types[tIdx].properties[pIdx].computedViewBody =
                    updated.types[tIdx].properties[pIdx].computedViewBody.map {
                        tokenizeViewSubtree($0, viewName: viewName, pass: pass, changedOut: &didTokenizeInView)
                    }
            }

            if didTokenizeInView {
                let hasThemeProp = updated.types[tIdx].properties.contains { $0.name == "theme" }
                if !hasThemeProp {
                    let themeProp = SwiftPropertyDecl(
                        name: "theme",
                        isLet: false,
                        accessLevel: .private,
                        initializer: .call(callee: .identifier("StudioThemeTokens"), arguments: [], trailingClosure: nil)
                    )
                    updated.types[tIdx].properties.insert(themeProp, at: 0)
                }
            }
        }

        return updated
    }

    mutating func tokenizeViewSubtree(
        _ node: SwiftViewNode,
        viewName: String,
        pass: ASTTransformPass,
        changedOut: inout Bool
    ) -> SwiftViewNode {
        var copy = node

        // 1. Tokenize stack `spacing:` numeric literals & surface `cornerRadius:` literals
        for aIdx in copy.arguments.indices {
            let label = copy.arguments[aIdx].label
            if label == "spacing", let val = copy.arguments[aIdx].value.doubleValue, val > 0 {
                let tokenName = nearestSpacingTokenName(for: val)
                copy.arguments[aIdx].value = .memberAccess(base: .identifier("theme"), member: tokenName)
                changedOut = true
                record(pass, symbol: "\(viewName).\(copy.componentName)", summary: "Replaced spacing '\(Int(val))' with 'theme.\(tokenName)'.")
            } else if label == "cornerRadius", let val = copy.arguments[aIdx].value.doubleValue, val < 500 {
                let tokenName = nearestRadiusTokenName(for: val)
                copy.arguments[aIdx].value = .memberAccess(base: .identifier("theme"), member: tokenName)
                changedOut = true
                record(pass, symbol: "\(viewName).\(copy.componentName)", summary: "Replaced cornerRadius '\(Int(val))' with 'theme.\(tokenName)'.")
            } else if let replacedColor = replaceRawColorExpr(copy.arguments[aIdx].value) {
                copy.arguments[aIdx].value = replacedColor
                changedOut = true
                record(pass, symbol: "\(viewName).\(copy.componentName)", summary: "Replaced raw RGB Color initializer with semantic theme token.")
            }
        }

        // 2. Tokenize `.padding(...)`, `.cornerRadius(...)`, `.foregroundStyle(Color(red:...))`, `.background(Color(red:...))`
        for mIdx in copy.modifiers.indices {
            var mod = copy.modifiers[mIdx]
            if mod.name == "padding", let lastIdx = mod.arguments.indices.last,
               let val = mod.arguments[lastIdx].value.doubleValue {
                let tokenName = nearestSpacingTokenName(for: val)
                mod.arguments[lastIdx].value = .memberAccess(base: .identifier("theme"), member: tokenName)
                changedOut = true
                record(pass, symbol: "\(viewName).padding", summary: "Tokenized '.padding(\(Int(val)))' -> '.padding(theme.\(tokenName))'.")
            } else if mod.name == "cornerRadius", let val = mod.arguments.first?.value.doubleValue {
                let tokenName = nearestRadiusTokenName(for: val)
                mod.name = "clipShape"
                mod.arguments = [
                    SwiftModifierArg(
                        value: .call(
                            callee: .implicitMember("rect"),
                            arguments: [
                                SwiftCallArgument(label: "cornerRadius", value: .memberAccess(base: .identifier("theme"), member: tokenName))
                            ],
                            trailingClosure: nil
                        )
                    )
                ]
                changedOut = true
                record(pass, symbol: "\(viewName).clipShape", summary: "Upgraded '.cornerRadius(\(Int(val)))' -> '.clipShape(.rect(cornerRadius: theme.\(tokenName)))'.")
            } else {
                for aIdx in mod.arguments.indices {
                    if let replaced = replaceRawColorExpr(mod.arguments[aIdx].value) {
                        mod.arguments[aIdx].value = replaced
                        changedOut = true
                        record(pass, symbol: "\(viewName).\(mod.name)", summary: "Mapped raw RGB color to nearest semantic theme token.")
                    }
                }
            }
            copy.modifiers[mIdx] = mod
        }

        copy.children = copy.children.map { tokenizeViewSubtree($0, viewName: viewName, pass: pass, changedOut: &changedOut) }
        copy.elseChildren = copy.elseChildren.map { tokenizeViewSubtree($0, viewName: viewName, pass: pass, changedOut: &changedOut) }
        return copy
    }

    func nearestSpacingTokenName(for rawValue: Double) -> String {
        let candidates: [(String, Double)] = [
            ("spacingXS", Double(theme.spacingXS)),
            ("spacingSM", Double(theme.spacingSM)),
            ("spacingMD", Double(theme.spacingMD)),
            ("spacingLG", Double(theme.spacingLG))
        ]
        return candidates.min(by: { abs($0.1 - rawValue) < abs($1.1 - rawValue) })?.0 ?? "spacingMD"
    }

    func nearestRadiusTokenName(for rawValue: Double) -> String {
        let candidates: [(String, Double)] = [
            ("radiusSmall", theme.radiusSmall),
            ("radiusMedium", theme.radiusMedium),
            ("radiusLarge", theme.radiusLarge)
        ]
        return candidates.min(by: { abs($0.1 - rawValue) < abs($1.1 - rawValue) })?.0 ?? "radiusMedium"
    }

    func replaceRawColorExpr(_ expr: SwiftExpr) -> SwiftExpr? {
        guard case .call(let callee, let args, _) = expr,
              callee.renderedDescription == "Color",
              let r = args.first(where: { $0.label == "red" })?.value.doubleValue,
              let g = args.first(where: { $0.label == "green" })?.value.doubleValue,
              let b = args.first(where: { $0.label == "blue" })?.value.doubleValue else {
            return nil
        }

        let palette: [(String, RGBAColor)] = [
            ("primary", theme.primary),
            ("secondary", theme.secondary),
            ("success", theme.success),
            ("warning", theme.warning),
            ("danger", theme.danger),
            ("surface", theme.surface)
        ]
        let nearest = palette.min { lhs, rhs in
            rgbDistanceSquared(r, g, b, lhs.1) < rgbDistanceSquared(r, g, b, rhs.1)
        }?.0 ?? "primary"

        return .memberAccess(base: .memberAccess(base: .identifier("studioTheme"), member: "colors"), member: nearest)
    }

    func rgbDistanceSquared(_ r: Double, _ g: Double, _ b: Double, _ target: RGBAColor) -> Double {
        let dr = r - target.red
        let dg = g - target.green
        let db = b - target.blue
        return dr * dr + dg * dg + db * db
    }

    // MARK: Pass 4 — Inject VoiceOver & Dynamic Type (`@ScaledMetric`)

    mutating func passInjectVoiceOverAndDynamicType(_ file: SwiftSourceFile) -> SwiftSourceFile {
        var updated = file
        let pass = ASTTransformPass.injectVoiceOverAndDynamicType

        for tIdx in updated.types.indices where updated.types[tIdx].isSwiftUIView {
            let viewName = updated.types[tIdx].name
            var scaledMetricsToAdd: [SwiftPropertyDecl] = []

            for pIdx in updated.types[tIdx].properties.indices where updated.types[tIdx].properties[pIdx].isComputed {
                updated.types[tIdx].properties[pIdx].computedViewBody =
                    updated.types[tIdx].properties[pIdx].computedViewBody.map {
                        injectA11yOnNode($0, viewName: viewName, pass: pass, scaledPropsOut: &scaledMetricsToAdd)
                    }
            }

            // Insert synthesized `@ScaledMetric` properties without duplicates
            for metricProp in scaledMetricsToAdd {
                if !updated.types[tIdx].properties.contains(where: { $0.name == metricProp.name }) {
                    updated.types[tIdx].properties.insert(metricProp, at: 0)
                }
            }
        }

        return updated
    }

    mutating func injectA11yOnNode(
        _ node: SwiftViewNode,
        viewName: String,
        pass: ASTTransformPass,
        scaledPropsOut: inout [SwiftPropertyDecl]
    ) -> SwiftViewNode {
        var copy = node

        // 1. Add VoiceOver `.accessibilityLabel` & `.accessibilityHint` on interactive controls
        if (copy.componentName == "Button" || copy.componentName == "EDKButton") && !copy.hasModifier("accessibilityLabel") {
            let label = copy.firstUnlabeledStringArgument
                ?? copy.flattenedNodes().first(where: { $0.componentName == "Text" })?.firstUnlabeledStringArgument
                ?? "Action Button"
            copy.modifiers.append(SwiftModifierCall(name: "accessibilityLabel", arguments: [SwiftModifierArg(value: .string(label))]))
            if !copy.hasModifier("accessibilityHint") {
                copy.modifiers.append(
                    SwiftModifierCall(name: "accessibilityHint", arguments: [SwiftModifierArg(value: .string("Activates \(label)"))])
                )
            }
            record(pass, symbol: "\(viewName).\(copy.componentName)", summary: "Injected VoiceOver label & hint for '\(label)'.")
        } else if (copy.componentName == "TextField" || copy.componentName == "SecureField") && !copy.hasModifier("accessibilityLabel") {
            let fieldLabel = copy.firstUnlabeledStringArgument ?? "Input Field"
            copy.modifiers.append(SwiftModifierCall(name: "accessibilityLabel", arguments: [SwiftModifierArg(value: .string(fieldLabel))]))
            record(pass, symbol: "\(viewName).\(copy.componentName)", summary: "Added VoiceOver label '\(fieldLabel)' to input field.")
        } else if copy.componentName == "Toggle" && !copy.hasModifier("accessibilityLabel") {
            let toggleLabel = copy.firstUnlabeledStringArgument ?? "Toggle Setting"
            copy.modifiers.append(SwiftModifierCall(name: "accessibilityLabel", arguments: [SwiftModifierArg(value: .string(toggleLabel))]))
            copy.modifiers.append(
                SwiftModifierCall(name: "accessibilityHint", arguments: [SwiftModifierArg(value: .string("Double-tap to toggle \(toggleLabel)"))])
            )
            record(pass, symbol: "\(viewName).Toggle", summary: "Added VoiceOver label & hint to Toggle '\(toggleLabel)'.")
        }

        // 2. Add `.accessibilityAddTraits(.isHeader)` to `.title` / `.largeTitle` / `.title2` headings
        if copy.componentName == "Text", let fontMod = copy.modifier(named: "font") {
            let desc = fontMod.arguments.first?.value.renderedDescription ?? ""
            if (desc.contains("title") || desc.contains("largeTitle")) && !copy.hasModifier("accessibilityAddTraits") {
                copy.modifiers.append(
                    SwiftModifierCall(name: "accessibilityAddTraits", arguments: [SwiftModifierArg(value: .implicitMember("isHeader"))])
                )
                record(pass, symbol: "\(viewName).Text", summary: "Marked title 'Text' with '.accessibilityAddTraits(.isHeader)'.")
            }
        }

        // 3. Upgrade hardcoded `.font(.system(size: N, ...))` to `@ScaledMetric`
        for mIdx in copy.modifiers.indices where copy.modifiers[mIdx].name == "font" {
            if let firstArg = copy.modifiers[mIdx].arguments.first,
               case .call(let callee, var sysArgs, let trailing) = firstArg.value,
               callee.memberLeafName == "system",
               let sizeIdx = sysArgs.firstIndex(where: { $0.label == "size" }),
               let ptSize = sysArgs[sizeIdx].value.doubleValue {
                let intPt = Int(ptSize.rounded())
                let metricVarName = "scaledFont\(intPt)"
                sysArgs[sizeIdx].value = .identifier(metricVarName)
                copy.modifiers[mIdx].arguments[0].value = .call(callee: callee, arguments: sysArgs, trailingClosure: trailing)

                let scaledWrapper = SwiftPropertyWrapper(
                    kind: .scaledMetric,
                    arguments: [SwiftModifierArg(label: "relativeTo", value: .implicitMember("body"))]
                )
                scaledPropsOut.append(
                    SwiftPropertyDecl(
                        name: metricVarName,
                        isLet: false,
                        accessLevel: .private,
                        typeAnnotation: "CGFloat",
                        initializer: .int(intPt),
                        wrappers: [scaledWrapper]
                    )
                )
                record(pass, symbol: "\(viewName).\(metricVarName)", summary: "Replaced fixed \(intPt)pt font size with '@ScaledMetric' '\(metricVarName)'.")
            }
        }

        copy.children = copy.children.map { injectA11yOnNode($0, viewName: viewName, pass: pass, scaledPropsOut: &scaledPropsOut) }
        copy.elseChildren = copy.elseChildren.map { injectA11yOnNode($0, viewName: viewName, pass: pass, scaledPropsOut: &scaledPropsOut) }
        return copy
    }

    // MARK: Pass 5 — Lift `@State` Properties into Pure Unidirectional `State` + `Action` + `Reducer`

    mutating func passLiftStateToReducer(_ file: SwiftSourceFile) -> SwiftSourceFile {
        var updated = file
        let pass = ASTTransformPass.liftStateToSwiftStateReducer
        var companionTypes: [SwiftTypeDecl] = []

        for tIdx in updated.types.indices where updated.types[tIdx].isSwiftUIView {
            let viewDecl = updated.types[tIdx]
            let stateProps = viewDecl.properties.filter { $0.hasWrapper(.state) && !$0.isComputed && $0.name != "state" }
            guard !stateProps.isEmpty else { continue }

            let basePrefix = viewDecl.name.hasSuffix("View")
                ? String(viewDecl.name.dropLast(4))
                : viewDecl.name
            let stateTypeName = "\(basePrefix)State"
            let actionTypeName = "\(basePrefix)Action"
            let reducerTypeName = "\(basePrefix)Reducer"

            // 1. Build `State` struct fields
            let stateFields: [SwiftPropertyDecl] = stateProps.map { prop in
                let inferredType = prop.typeAnnotation ?? inferExprType(prop.initializer) ?? "String"
                let fallbackInit = prop.initializer ?? defaultExpr(forType: inferredType)
                return SwiftPropertyDecl(
                    name: prop.name,
                    isLet: false,
                    accessLevel: .public,
                    typeAnnotation: inferredType,
                    initializer: fallbackInit
                )
            }

            let stateStruct = SwiftTypeDecl(
                name: stateTypeName,
                kind: .struct,
                accessLevel: viewDecl.accessLevel,
                conformances: ["Equatable", "Codable", "Sendable"],
                properties: stateFields,
                docComment: "Pure value-type state store extracted from '\(viewDecl.name)'."
            )

            // 2. Build `Action` enum cases & `Reducer` switch cases
            var actionCases: [SwiftEnumCaseDecl] = []
            var reducerSwitchCases: [SwiftSwitchCase] = []

            for field in stateFields {
                let capName = field.name.prefix(1).uppercased() + field.name.dropFirst()
                let fieldType = field.typeAnnotation ?? "String"
                if fieldType == "Bool" {
                    let toggleCase = "toggle\(capName)"
                    actionCases.append(SwiftEnumCaseDecl(name: toggleCase))
                    reducerSwitchCases.append(
                        SwiftSwitchCase(
                            patterns: [".\(toggleCase)"],
                            statements: [
                                .expression(
                                    .call(
                                        callee: .memberAccess(
                                            base: .memberAccess(base: .identifier("state"), member: field.name),
                                            member: "toggle"
                                        ),
                                        arguments: [],
                                        trailingClosure: nil
                                    )
                                )
                            ]
                        )
                    )
                }
                let setCase = "set\(capName)"
                actionCases.append(SwiftEnumCaseDecl(name: setCase, associatedValues: [SwiftParameter(internalName: "_", typeName: fieldType)]))
                reducerSwitchCases.append(
                    SwiftSwitchCase(
                        patterns: [".\(setCase)(let value)"],
                        statements: [
                            .assignment(target: .memberAccess(base: .identifier("state"), member: field.name), op: "=", value: .identifier("value"))
                        ]
                    )
                )
            }

            let actionEnum = SwiftTypeDecl(
                name: actionTypeName,
                kind: .enum,
                accessLevel: viewDecl.accessLevel,
                conformances: ["Equatable", "Sendable"],
                enumCases: actionCases,
                docComment: "Unidirectional intent actions dispatched by '\(viewDecl.name)'."
            )

            let reduceMethod = SwiftFunctionDecl(
                name: "reduce",
                accessLevel: viewDecl.accessLevel,
                parameters: [
                    SwiftParameter(internalName: "state", typeName: stateTypeName, isInout: true),
                    SwiftParameter(internalName: "action", typeName: actionTypeName)
                ],
                statements: [
                    .switchStmt(subject: .identifier("action"), cases: reducerSwitchCases)
                ]
            )

            let reducerStruct = SwiftTypeDecl(
                name: reducerTypeName,
                kind: .struct,
                accessLevel: viewDecl.accessLevel,
                conformances: ["Sendable"],
                functions: [reduceMethod],
                docComment: "Deterministic state transition reducer for '\(viewDecl.name)'."
            )

            companionTypes.append(contentsOf: [stateStruct, actionEnum, reducerStruct])

            // 3. Replace scattered `@State` properties on the View with consolidated `state` + `reducer`
            let liftedNames = Set(stateProps.map(\.name))
            var remainingProps = viewDecl.properties.filter { !liftedNames.contains($0.name) }
            let consolidatedState = SwiftPropertyDecl(
                name: "state",
                isLet: false,
                accessLevel: .private,
                initializer: .call(callee: .identifier(stateTypeName), arguments: [], trailingClosure: nil),
                wrappers: [SwiftPropertyWrapper(kind: .state)]
            )
            let reducerProp = SwiftPropertyDecl(
                name: "reducer",
                isLet: true,
                accessLevel: .private,
                initializer: .call(callee: .identifier(reducerTypeName), arguments: [], trailingClosure: nil)
            )
            remainingProps.insert(reducerProp, at: 0)
            remainingProps.insert(consolidatedState, at: 0)

            for pIdx in remainingProps.indices where remainingProps[pIdx].isComputed {
                remainingProps[pIdx].computedViewBody = remainingProps[pIdx].computedViewBody.map {
                    qualifyLiftedStateReferences(in: $0, liftedNames: liftedNames)
                }
            }
            updated.types[tIdx].properties = remainingProps

            record(
                pass,
                symbol: viewDecl.name,
                summary: "Lifted \(stateProps.count) '@State' properties into '\(stateTypeName)', '\(actionTypeName)', and '\(reducerTypeName)'."
            )
        }

        updated.types.insert(contentsOf: companionTypes, at: 0)
        return updated
    }

    func qualifyLiftedStateReferences(in node: SwiftViewNode, liftedNames: Set<String>) -> SwiftViewNode {
        var copy = node
        for aIdx in copy.arguments.indices {
            copy.arguments[aIdx].value = qualifyExprStateRefs(copy.arguments[aIdx].value, liftedNames: liftedNames)
        }
        copy.children = copy.children.map { qualifyLiftedStateReferences(in: $0, liftedNames: liftedNames) }
        copy.elseChildren = copy.elseChildren.map { qualifyLiftedStateReferences(in: $0, liftedNames: liftedNames) }
        return copy
    }

    func qualifyExprStateRefs(_ expr: SwiftExpr, liftedNames: Set<String>) -> SwiftExpr {
        switch expr {
        case .identifier(let name) where liftedNames.contains(name):
            return .memberAccess(base: .identifier("state"), member: name)
        case .dollarBinding(let raw):
            let clean = raw.hasPrefix("$") ? String(raw.dropFirst()) : raw
            if liftedNames.contains(clean) { return .memberAccess(base: .dollarBinding("$state"), member: clean) }
            return expr
        case .memberAccess(let base, let member):
            return .memberAccess(base: qualifyExprStateRefs(base, liftedNames: liftedNames), member: member)
        case .call(let callee, let args, let closure):
            let updatedArgs = args.map { SwiftCallArgument(label: $0.label, value: qualifyExprStateRefs($0.value, liftedNames: liftedNames)) }
            return .call(callee: qualifyExprStateRefs(callee, liftedNames: liftedNames), arguments: updatedArgs, trailingClosure: closure)
        case .binaryOp(let l, let op, let r):
            return .binaryOp(lhs: qualifyExprStateRefs(l, liftedNames: liftedNames), op: op, rhs: qualifyExprStateRefs(r, liftedNames: liftedNames))
        default:
            return expr
        }
    }

    // MARK: Pass 6 — Instrument Timeline & Action Telemetry

    mutating func passInstrumentTelemetry(_ file: SwiftSourceFile) -> SwiftSourceFile {
        var updated = file
        let pass = ASTTransformPass.instrumentTimelineTelemetry
        var didInstrument = false

        for tIdx in updated.types.indices where updated.types[tIdx].isSwiftUIView {
            let viewName = updated.types[tIdx].name
            for pIdx in updated.types[tIdx].properties.indices where updated.types[tIdx].properties[pIdx].name == "body" {
                var roots = updated.types[tIdx].properties[pIdx].computedViewBody
                guard !roots.isEmpty else { continue }

                // 1. Instrument interactive buttons across subtree
                roots = roots.map { instrumentButtons(in: $0, viewName: viewName, pass: pass, instrumentedOut: &didInstrument) }

                // 2. Attach root `.onAppear` telemetry trace if not already instrumented
                if !roots[0].hasModifier("onAppear") {
                    let appearTraceStmt = SwiftStatement.expression(
                        .call(
                            callee: .memberAccess(base: .identifier("ChiefKitTelemetry"), member: "recordViewAppear"),
                            arguments: [SwiftCallArgument(value: .string(viewName))],
                            trailingClosure: nil
                        )
                    )
                    roots[0].modifiers.append(SwiftModifierCall(name: "onAppear", trailingClosure: SwiftClosureExpr(statements: [appearTraceStmt])))
                    didInstrument = true
                    record(pass, symbol: viewName, summary: "Attached '.onAppear' timeline trace to '\(viewName)'.")
                }

                updated.types[tIdx].properties[pIdx].computedViewBody = roots
            }
        }

        // Synthesize lightweight Sendable `ChiefKitTelemetry` namespace if not already declared in file
        if didInstrument && !updated.types.contains(where: { $0.name == "ChiefKitTelemetry" }) {
            let appearFn = SwiftFunctionDecl(
                name: "recordViewAppear",
                isStatic: true,
                parameters: [SwiftParameter(externalLabel: "_", internalName: "screen", typeName: "String")],
                statements: []
            )
            let actionFn = SwiftFunctionDecl(
                name: "recordAction",
                isStatic: true,
                parameters: [
                    SwiftParameter(externalLabel: "_", internalName: "action", typeName: "String"),
                    SwiftParameter(externalLabel: "in", internalName: "screen", typeName: "String")
                ],
                statements: []
            )
            updated.types.append(
                SwiftTypeDecl(
                    name: "ChiefKitTelemetry",
                    kind: .enum,
                    conformances: ["Sendable"],
                    functions: [appearFn, actionFn],
                    docComment: "Lightweight Sendable timeline telemetry hooks synthesized by ChiefKitAST."
                )
            )
        }

        return updated
    }

    mutating func instrumentButtons(
        _ node: SwiftViewNode,
        viewName: String,
        pass: ASTTransformPass,
        instrumentedOut: inout Bool
    ) -> SwiftViewNode {
        instrumentButtons(in: node, viewName: viewName, pass: pass, instrumentedOut: &instrumentedOut)
    }

    mutating func instrumentButtons(
        in node: SwiftViewNode,
        viewName: String,
        pass: ASTTransformPass,
        instrumentedOut: inout Bool
    ) -> SwiftViewNode {
        var copy = node
        if copy.componentName == "Button" || copy.componentName == "EDKButton" {
            let alreadyTraced = copy.actionStatements.contains { stmt in
                stmt.allReferencedIdentifiers().contains("ChiefKitTelemetry")
            }
            if !alreadyTraced {
                let buttonLabel = copy.firstUnlabeledStringArgument ?? "buttonTap"
                let traceCall = SwiftStatement.expression(
                    .call(
                        callee: .memberAccess(base: .identifier("ChiefKitTelemetry"), member: "recordAction"),
                        arguments: [
                            SwiftCallArgument(value: .string(buttonLabel)),
                            SwiftCallArgument(label: "in", value: .string(viewName))
                        ],
                        trailingClosure: nil
                    )
                )
                copy.actionStatements.insert(traceCall, at: 0)
                instrumentedOut = true
                record(pass, symbol: "\(viewName).\(copy.componentName)", summary: "Instrumented action telemetry for '\(buttonLabel)'.")
            }
        }
        copy.children = copy.children.map { instrumentButtons(in: $0, viewName: viewName, pass: pass, instrumentedOut: &instrumentedOut) }
        copy.elseChildren = copy.elseChildren.map { instrumentButtons(in: $0, viewName: viewName, pass: pass, instrumentedOut: &instrumentedOut) }
        return copy
    }

    // MARK: Type Inference & Sanitization Helpers

    func inferExprType(_ expr: SwiftExpr?) -> String? {
        guard let expr else { return nil }
        switch expr {
        case .literal(.integer): return "Int"
        case .literal(.float): return "Double"
        case .literal(.string), .literal(.interpolatedString): return "String"
        case .literal(.boolean): return "Bool"
        case .array: return "[String]"
        case .call(let callee, _, _):
            let name = callee.renderedDescription
            if name.first?.isUppercase == true { return name }
            return nil
        default:
            return nil
        }
    }

    func defaultExpr(forType typeName: String) -> SwiftExpr {
        switch typeName {
        case "Int": return .int(0)
        case "Double", "CGFloat": return .double(0.0)
        case "Bool": return .bool(false)
        case "String": return .string("")
        default:
            if typeName.hasPrefix("[") { return .array([]) }
            return .call(callee: .identifier(typeName), arguments: [], trailingClosure: nil)
        }
    }

    func sanitizeIdentifier(_ raw: String, fallback: String) -> String {
        let filtered = raw.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        guard let first = filtered.first else { return fallback }
        return first.isNumber ? "Subview_\(filtered)" : filtered
    }
}
