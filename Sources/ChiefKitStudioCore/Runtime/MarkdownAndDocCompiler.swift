import Foundation

// MARK: - DocC & HTML Specification Bundle Models

public enum DocArticleKind: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case rootCatalog = "ChiefKitWorkspace.md"
    case architecture = "Architecture.md"
    case designTokens = "DesignTokens.md"
    case dataModel = "DataModel.md"
    case localizationReport = "LocalizationReport.md"

    public var id: String { rawValue }
}

public struct DocCGeneratedFile: Identifiable, Codable, Hashable, Sendable {
    public var id: String { relativePath }
    public var relativePath: String
    public var title: String
    public var content: String
    public var byteCount: Int

    public init(relativePath: String, title: String, content: String) {
        self.relativePath = relativePath
        self.title = title
        self.content = content
        self.byteCount = content.utf8.count
    }
}

public struct StudioSpecBundleInput: Codable, Hashable, Sendable {
    public var projectName: String
    public var versionString: String
    public var authorOrganization: String
    public var themeTokens: StudioThemeTokens?
    public var canvasDocument: CanvasDocument?
    public var flowDefinition: FlowDefinition?
    public var conditionalFlow: ConditionalFlowSpec?
    public var dataSchema: DataSchemaWorkspace?
    public var stringCatalog: StringCatalogDocument?

    public init(
        projectName: String = "ChiefKit Workspace",
        versionString: String = "3.0.0",
        authorOrganization: String = "HNMLabs",
        themeTokens: StudioThemeTokens? = StudioThemeTokens(),
        canvasDocument: CanvasDocument? = nil,
        flowDefinition: FlowDefinition? = nil,
        conditionalFlow: ConditionalFlowSpec? = nil,
        dataSchema: DataSchemaWorkspace? = nil,
        stringCatalog: StringCatalogDocument? = nil
    ) {
        self.projectName = projectName
        self.versionString = versionString
        self.authorOrganization = authorOrganization
        self.themeTokens = themeTokens
        self.canvasDocument = canvasDocument
        self.flowDefinition = flowDefinition
        self.conditionalFlow = conditionalFlow
        self.dataSchema = dataSchema
        self.stringCatalog = stringCatalog
    }
}

public struct StudioCompiledDocBundle: Codable, Hashable, Sendable {
    public var bundleFolderName: String
    public var doccFiles: [DocCGeneratedFile]
    public var standaloneHTMLSpecification: String

    public init(
        bundleFolderName: String,
        doccFiles: [DocCGeneratedFile],
        standaloneHTMLSpecification: String
    ) {
        self.bundleFolderName = bundleFolderName
        self.doccFiles = doccFiles
        self.standaloneHTMLSpecification = standaloneHTMLSpecification
    }

    public func article(for kind: DocArticleKind) -> DocCGeneratedFile? {
        doccFiles.first { $0.relativePath.hasSuffix(kind.rawValue) }
    }
}

// MARK: - StudioDocBundleCompiler

public enum StudioDocBundleCompiler {

    public static func compileBundle(_ input: StudioSpecBundleInput) -> StudioCompiledDocBundle {
        let slug = SchemaNamingHelpers.pascalCase(input.projectName.isEmpty ? "ChiefKitSpec" : input.projectName)
        let folder = "\(slug).docc"
        let articles = compileDocCArticles(input)
        let html = compileStandaloneHTML(input)
        return StudioCompiledDocBundle(
            bundleFolderName: folder,
            doccFiles: articles,
            standaloneHTMLSpecification: html
        )
    }

    public static func compileDocCArticles(_ input: StudioSpecBundleInput) -> [DocCGeneratedFile] {
        [
            DocCGeneratedFile(
                relativePath: DocArticleKind.rootCatalog.rawValue,
                title: input.projectName,
                content: buildRootCatalogMarkdown(input)
            ),
            DocCGeneratedFile(
                relativePath: "Articles/\(DocArticleKind.architecture.rawValue)",
                title: "Architecture & Flow Topology",
                content: buildArchitectureMarkdown(input)
            ),
            DocCGeneratedFile(
                relativePath: "Articles/\(DocArticleKind.designTokens.rawValue)",
                title: "Design Tokens & Contrast Audit",
                content: buildDesignTokensMarkdown(input)
            ),
            DocCGeneratedFile(
                relativePath: "Articles/\(DocArticleKind.dataModel.rawValue)",
                title: "Domain Data Model & Normalization",
                content: buildDataModelMarkdown(input)
            ),
            DocCGeneratedFile(
                relativePath: "Articles/\(DocArticleKind.localizationReport.rawValue)",
                title: "Localization & String Catalog Coverage",
                content: buildLocalizationReportMarkdown(input)
            )
        ]
    }

    public static func writeBundleToDirectory(
        _ bundle: StudioCompiledDocBundle,
        directoryURL: URL
    ) throws -> [URL] {
        let fm = FileManager.default
        let doccRoot = directoryURL.appendingPathComponent(bundle.bundleFolderName, isDirectory: true)
        try fm.createDirectory(at: doccRoot, withIntermediateDirectories: true)

        var writtenURLs: [URL] = []
        for file in bundle.doccFiles {
            let targetURL = doccRoot.appendingPathComponent(file.relativePath)
            let parentDir = targetURL.deletingLastPathComponent()
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try Data(file.content.utf8).write(to: targetURL, options: .atomic)
            writtenURLs.append(targetURL)
        }

        let htmlURL = directoryURL.appendingPathComponent("\(bundle.bundleFolderName.replacingOccurrences(of: ".docc", with: ""))-Spec.html")
        try Data(bundle.standaloneHTMLSpecification.utf8).write(to: htmlURL, options: .atomic)
        writtenURLs.append(htmlURL)
        return writtenURLs
    }

    // MARK: - DocC Markdown Builders

    private static func buildRootCatalogMarkdown(_ input: StudioSpecBundleInput) -> String {
        """
        # ``\(SchemaNamingHelpers.pascalCase(input.projectName))``

        @Metadata {
            @DisplayName("\(escapeQuotes(input.projectName)) Specification")
            @TechnologyRoot
        }

        Production design system, domain schema, flow topology, and localization specification for **\(input.projectName)** (`v\(input.versionString)`) by \(input.authorOrganization).

        ## Overview

        This DocC catalog was synthesized deterministically by **ChiefKit Studio 3.0**. All architectural invariants, WCAG 2.1 contrast ratios, 3NF relational checks, and CLDR plural localizations are documented in the articles below.

        ## Topics

        ### System Specification Articles

        - <doc:Architecture>
        - <doc:DesignTokens>
        - <doc:DataModel>
        - <doc:LocalizationReport>
        """
    }

    private static func buildArchitectureMarkdown(_ input: StudioSpecBundleInput) -> String {
        var lines: [String] = [
            "# Architecture & Flow Topology",
            "",
            "@Metadata {",
            "    @PageKind(article)",
            "}",
            "",
            "Overview of visual canvas composition, unidirectional `StudioStore` state management, and screen navigation flows for **\(input.projectName)**.",
            ""
        ]

        if let canvas = input.canvasDocument {
            lines.append("## Visual Canvas Composition (\(canvas.nodes.count) Blocks)")
            lines.append("")
            lines.append("| Layer | Kind | Title | Variant | Frame (pt) |")
            lines.append("| :--- | :--- | :--- | :--- | :--- |")
            for (idx, node) in canvas.nodes.enumerated() {
                let frameStr = "\(Int(node.frame.width))×\(Int(node.frame.height)) @ (\(Int(node.frame.x)),\(Int(node.frame.y)))"
                lines.append("| \(idx + 1) | `\(node.kind.rawValue)` | \(escapePipe(node.title)) | `.\(node.variant.rawValue)` | \(frameStr) |")
            }
            lines.append("")
        }

        if let condFlow = input.conditionalFlow {
            let report = NotebookFlowRuntimeEngine.exploreAllPaths(in: condFlow)
            lines.append("## Conditional NotebookFlow (`\(condFlow.id)` · v\(condFlow.version))")
            lines.append("")
            lines.append("- **Entry Step:** `\(condFlow.entryStepID)`")
            lines.append("- **Total Steps:** \(condFlow.steps.count)")
            lines.append("- **Reachable Execution Paths:** \(report.reachablePaths.count)")
            lines.append("- **Dead-End Screens:** \(report.deadEndStepIDs.isEmpty ? "None" : report.deadEndStepIDs.joined(separator: ", "))")
            lines.append("")
            for step in condFlow.steps {
                lines.append("### `\(step.id)` — \(step.title)")
                if !step.markdownBody.isEmpty {
                    lines.append(step.markdownBody)
                }
                for br in step.branches {
                    lines.append("- **When** `\(br.predicateExpression)` → `\(br.targetStepID)`")
                }
                if let fb = step.fallbackNextStepID {
                    lines.append("- **Fallback Next:** `\(fb)`")
                }
                lines.append("")
            }
        } else if let legacyFlow = input.flowDefinition {
            let diags = legacyFlow.validate()
            lines.append("## Screen Navigation Flow: \(legacyFlow.title)")
            lines.append("")
            lines.append("| Screen ID | Title | Style | Actions |")
            lines.append("| :--- | :--- | :--- | :--- |")
            for page in legacyFlow.pages {
                lines.append("| `\(page.id)` | \(escapePipe(page.title)) | `\(page.style)` | \(escapePipe(page.actions.joined(separator: ", "))) |")
            }
            lines.append("")
            lines.append("> Note: Flow diagnostics count: \(diags.count) (\(diags.first?.message ?? "Validated")).")
        } else {
            lines.append("> Note: No `CanvasDocument` or `FlowDefinition` was attached to this specification bundle.")
        }

        return lines.joined(separator: "\n")
    }

    private static func buildDesignTokensMarkdown(_ input: StudioSpecBundleInput) -> String {
        let tokens = input.themeTokens ?? StudioThemeTokens()
        let contrast = tokens.contrastReport
        return """
        # Design Tokens & Contrast Audit

        @Metadata {
            @PageKind(article)
        }

        Semantic color palette, spatial rhythm, corner radii, and Liquid Glass material settings.

        ## Semantic Color Palette

        | Token | Hex | SwiftUI Initializer | Relative Luminance |
        | :--- | :--- | :--- | :--- |
        | `primary` | `\(tokens.primary.hexString)` | `\(tokens.primary.swiftInitializer)` | \(String(format: "%.3f", tokens.primary.relativeLuminance)) |
        | `secondary` | `\(tokens.secondary.hexString)` | `\(tokens.secondary.swiftInitializer)` | \(String(format: "%.3f", tokens.secondary.relativeLuminance)) |
        | `success` | `\(tokens.success.hexString)` | `\(tokens.success.swiftInitializer)` | \(String(format: "%.3f", tokens.success.relativeLuminance)) |
        | `warning` | `\(tokens.warning.hexString)` | `\(tokens.warning.swiftInitializer)` | \(String(format: "%.3f", tokens.warning.relativeLuminance)) |
        | `danger` | `\(tokens.danger.hexString)` | `\(tokens.danger.swiftInitializer)` | \(String(format: "%.3f", tokens.danger.relativeLuminance)) |
        | `surface` | `\(tokens.surface.hexString)` | `\(tokens.surface.swiftInitializer)` | \(String(format: "%.3f", tokens.surface.relativeLuminance)) |

        ## WCAG 2.1 Accessibility Contrast Matrix

        - **Primary on Surface:** `\(String(format: "%.2f", contrast.primaryOnSurfaceRatio)):1` — \(contrast.primaryOnSurfaceLevel.rawValue)
        - **White on Primary CTA:** `\(String(format: "%.2f", contrast.whiteOnPrimaryRatio)):1` — \(contrast.whiteOnPrimaryLevel.rawValue)
        - **Primary on Dark Surface:** `\(String(format: "%.2f", contrast.primaryOnDarkRatio)):1` — \(contrast.primaryOnDarkLevel.rawValue)

        ## Spacing, Radii & Liquid Glass

        - **Spacing Scale (`×\(String(format: "%.2f", tokens.spacingScale))`):** XS `\(Int(tokens.spacingXS))pt` · SM `\(Int(tokens.spacingSM))pt` · MD `\(Int(tokens.spacingMD))pt` · LG `\(Int(tokens.spacingLG))pt`
        - **Corner Radii:** Small `\(Int(tokens.radiusSmall))pt` · Medium `\(Int(tokens.radiusMedium))pt` · Large `\(Int(tokens.radiusLarge))pt`
        - **Liquid Glass:** `\(tokens.isLiquidGlassEnabled ? "Enabled" : "Disabled")` (frost: `\(Int((tokens.glassFrost * 100).rounded()))%`, specular rim: `\(Int((tokens.specularRim * 100).rounded()))%`)

        ## W3C Design Tokens Export

        ```json
        \(tokens.w3cDesignTokensJSON)
        ```
        """
    }

    private static func buildDataModelMarkdown(_ input: StudioSpecBundleInput) -> String {
        guard let schema = input.dataSchema else {
            return """
            # Domain Data Model & Normalization

            @Metadata {
                @PageKind(article)
            }

            No `DataSchemaWorkspace` was included in this specification bundle.
            """
        }

        let analysis = schema.analyzeNormalizationAndIntegrity()
        var lines: [String] = [
            "# Domain Data Model: \(schema.name)",
            "",
            "@Metadata {",
            "    @PageKind(article)",
            "}",
            "",
            "- **Schema Version:** `v\(schema.schemaVersion)` (`\(schema.namespacePrefix)`)",
            "- **Achieved Normal Form:** **\(analysis.achievedNormalForm)** (Score: `\(analysis.normalFormScore)/100`)",
            "- **Estimated Storage Footprint:** `\(String(format: "%.2f", analysis.estimatedTotalStorageMB)) MB`",
            "- **Sensitive PII Columns:** `\(analysis.piiAttributeCount)`",
            "",
            "## Entity-Relationship Diagram",
            "",
            "```mermaid",
            schema.generateMermaidERDiagram(includeDocumentation: true),
            "```",
            ""
        ]

        for entity in schema.entities {
            lines.append("## `\(entity.name)` (`\(entity.tableName)`)")
            if !entity.summary.isEmpty {
                lines.append(entity.summary)
            }
            lines.append("")
            lines.append("| Column | Type | Key / Unique | Nullable | PII |")
            lines.append("| :--- | :--- | :--- | :--- | :--- |")
            for attr in entity.attributes {
                let keyFlag = attr.isPrimaryKey ? "PK" : (attr.isUnique ? "UNIQUE" : (attr.isIndexed ? "INDEX" : "—"))
                lines.append("| `\(attr.name)` | `\(attr.fieldType.conciseLabel)` | \(keyFlag) | \(attr.isNullable ? "Yes" : "No") | \(attr.isSensitivePII ? "Yes" : "No") |")
            }
            lines.append("")
        }

        if !analysis.indexRecommendations.isEmpty {
            lines.append("## Index Coverage Advisor")
            for rec in analysis.indexRecommendations {
                lines.append("- **`\(rec.entityName)` → `\(rec.suggestedIndex.name)`** (`~\(String(format: "%.1f", rec.estimatedSpeedupFactor))x` speedup): \(rec.reason)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func buildLocalizationReportMarkdown(_ input: StudioSpecBundleInput) -> String {
        guard let catalog = input.stringCatalog else {
            return """
            # Localization & String Catalog Coverage

            @Metadata {
                @PageKind(article)
            }

            No `StringCatalogDocument` was included in this specification bundle.
            """
        }

        let coverage = catalog.coverageReport()
        let diagnostics = StringCatalogCompiler.validateCatalog(catalog)

        var lines: [String] = [
            "# Localization Coverage: `\(catalog.catalogName).xcstrings`",
            "",
            "@Metadata {",
            "    @PageKind(article)",
            "}",
            "",
            "- **Source Language:** `\(catalog.sourceLanguage.rawValue)` (\(catalog.sourceLanguage.englishName))",
            "- **Total String Keys:** \(catalog.entries.count)",
            "- **Validator Diagnostics:** \(diagnostics.count)",
            "",
            "## Locale Completion Matrix",
            "",
            "| Locale | Native Name | Direction | Expansion | Translated | Missing | Completion |",
            "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"
        ]

        for row in coverage {
            lines.append(
                "| `\(row.locale.rawValue)` | \(row.locale.nativeDisplayName) | \(row.locale.scriptDirection.rawValue) | `\(String(format: "%.2fx", row.locale.characterExpansionRatio))` | \(row.translatedCount)/\(row.totalTranslatableKeys) | \(row.missingCount) | **\(row.completionPercentage)%** |"
            )
        }

        if !diagnostics.isEmpty {
            lines.append("")
            lines.append("## Validation Diagnostics")
            for diag in diagnostics.prefix(25) {
                lines.append("- **[\(diag.severity.rawValue.uppercased())]** `\(diag.key)` (\(diag.locale?.rawValue ?? "all")): \(diag.message)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Standalone Self-Contained Interactive HTML Specification Compiler

    public static func compileStandaloneHTML(_ input: StudioSpecBundleInput) -> String {
        let tokens = input.themeTokens ?? StudioThemeTokens()
        let contrast = tokens.contrastReport
        let schemaAnalysis = input.dataSchema?.analyzeNormalizationAndIntegrity()
        let coverage = input.stringCatalog?.coverageReport() ?? []

        let swatchesHTML = [
            ("Primary", tokens.primary),
            ("Secondary", tokens.secondary),
            ("Success", tokens.success),
            ("Warning", tokens.warning),
            ("Danger", tokens.danger),
            ("Surface", tokens.surface)
        ].map { label, color in
            """
            <div class="swatch-card">
              <div class="swatch-chip" style="background: \(color.hexString);"></div>
              <div class="swatch-meta"><strong>\(escapeHTML(label))</strong><code>\(color.hexString)</code></div>
            </div>
            """
        }.joined(separator: "\n")

        let entitiesHTML: String
        if let schema = input.dataSchema {
            entitiesHTML = schema.entities.map { ent in
                let rows = ent.attributes.map { attr in
                    "<tr><td><code>\(escapeHTML(attr.name))</code></td><td><code>\(escapeHTML(attr.fieldType.conciseLabel))</code></td><td>\(attr.isPrimaryKey ? "PK" : (attr.isUnique ? "UNIQUE" : "—"))</td><td>\(attr.isSensitivePII ? "PII" : "—")</td></tr>"
                }.joined()
                return """
                <section class="panel">
                  <h3>\(escapeHTML(ent.name)) <small>(<code>\(escapeHTML(ent.tableName))</code> · ~\(ent.estimatedRowCount) rows)</small></h3>
                  <p>\(escapeHTML(ent.summary))</p>
                  <table><thead><tr><th>Column</th><th>Type</th><th>Key</th><th>Sensitivity</th></tr></thead><tbody>\(rows)</tbody></table>
                </section>
                """
            }.joined(separator: "\n")
        } else {
            entitiesHTML = "<p class=\"muted\">No DataSchemaWorkspace attached.</p>"
        }

        let localesHTML: String
        if coverage.isEmpty {
            localesHTML = "<p class=\"muted\">No StringCatalogDocument attached.</p>"
        } else {
            localesHTML = coverage.map { item in
                """
                <div class="locale-row">
                  <div><strong>\(escapeHTML(item.locale.nativeDisplayName))</strong> <code>\(escapeHTML(item.locale.rawValue))</code> (\(item.locale.scriptDirection.rawValue))</div>
                  <div class="bar-track"><div class="bar-fill" style="width: \(item.completionPercentage)%;"></div></div>
                  <span>\(item.completionPercentage)% (\(item.translatedCount)/\(item.totalTranslatableKeys))</span>
                </div>
                """
            }.joined(separator: "\n")
        }

        let canvasCount = input.canvasDocument?.nodes.count ?? 0
        let flowStepsCount = input.conditionalFlow?.steps.count ?? input.flowDefinition?.pages.count ?? 0
        let normLabel = schemaAnalysis.map { "\($0.achievedNormalForm) (\($0.normalFormScore)/100)" } ?? "N/A"

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>\(escapeHTML(input.projectName)) — ChiefKit Studio 3.0 Specification</title>
          <style>
            :root {
              --ck-primary: \(tokens.primary.hexString);
              --ck-secondary: \(tokens.secondary.hexString);
              --ck-success: \(tokens.success.hexString);
              --ck-surface: \(tokens.surface.hexString);
              --ck-radius: \(Int(tokens.radiusMedium.rounded()))px;
            }
            * { box-sizing: border-box; }
            body {
              margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              background: #f4f6fb; color: #141824; line-height: 1.55;
            }
            header {
              background: linear-gradient(135deg, var(--ck-primary), #182238);
              color: #fff; padding: 28px 36px;
            }
            header h1 { margin: 0 0 6px; font-size: 1.75rem; }
            nav.tabs {
              display: flex; gap: 8px; padding: 12px 36px; background: #fff;
              border-bottom: 1px solid #e2e8f0; position: sticky; top: 0;
            }
            nav.tabs button {
              border: 1px solid #cbd5e1; background: #f8fafc; padding: 8px 14px;
              border-radius: 8px; cursor: pointer; font-weight: 600;
            }
            nav.tabs button.active { background: var(--ck-primary); color: #fff; border-color: var(--ck-primary); }
            main { max-width: 1120px; margin: 24px auto; padding: 0 24px 48px; }
            .kpi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 14px; margin-bottom: 24px; }
            .panel, .kpi-card {
              background: #fff; border: 1px solid #e2e8f0; border-radius: var(--ck-radius);
              padding: 18px 20px; margin-bottom: 16px;
            }
            .swatch-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; }
            .swatch-card { border: 1px solid #e2e8f0; border-radius: 10px; overflow: hidden; background: #fff; }
            .swatch-chip { height: 56px; }
            .swatch-meta { padding: 10px; display: flex; justify-content: space-between; font-size: 0.88rem; }
            table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
            th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #edf2f7; }
            .locale-row { display: grid; grid-template-columns: 220px 1fr 120px; align-items: center; gap: 14px; padding: 8px 0; }
            .bar-track { height: 10px; background: #e2e8f0; border-radius: 999px; overflow: hidden; }
            .bar-fill { height: 100%; background: var(--ck-success); }
            .tab-pane { display: none; }
            .tab-pane.active { display: block; }
            .muted { color: #64748b; }
          </style>
        </head>
        <body>
          <header>
            <h1>\(escapeHTML(input.projectName)) <small>v\(escapeHTML(input.versionString))</small></h1>
            <div>Organization: \(escapeHTML(input.authorOrganization)) · Synthesized by ChiefKit Studio 3.0</div>
          </header>
          <nav class="tabs">
            <button class="active" onclick="showPane('tokens', this)">Design Tokens</button>
            <button onclick="showPane('schema', this)">Data Schema</button>
            <button onclick="showPane('l10n', this)">Localization</button>
          </nav>
          <main>
            <div class="kpi-grid">
              <div class="kpi-card"><div>WCAG Primary/Surface</div><strong>\(String(format: "%.2f", contrast.primaryOnSurfaceRatio)):1</strong></div>
              <div class="kpi-card"><div>Canvas UI Blocks</div><strong>\(canvasCount)</strong></div>
              <div class="kpi-card"><div>Flow Screens</div><strong>\(flowStepsCount)</strong></div>
              <div class="kpi-card"><div>Schema Integrity</div><strong>\(escapeHTML(normLabel))</strong></div>
            </div>
            <div id="pane-tokens" class="tab-pane active">
              <div class="panel"><h2>Color Tokens</h2><div class="swatch-grid">\(swatchesHTML)</div></div>
            </div>
            <div id="pane-schema" class="tab-pane">\(entitiesHTML)</div>
            <div id="pane-l10n" class="tab-pane"><div class="panel"><h2>String Catalog Coverage</h2>\(localesHTML)</div></div>
          </main>
          <script>
            function showPane(id, btn) {
              document.querySelectorAll('.tab-pane').forEach(el => el.classList.remove('active'));
              document.querySelectorAll('nav.tabs button').forEach(el => el.classList.remove('active'));
              document.getElementById('pane-' + id).classList.add('active');
              btn.classList.add('active');
            }
          </script>
        </body>
        </html>
        """
    }

    private static func escapeQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func escapePipe(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "\\|")
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
