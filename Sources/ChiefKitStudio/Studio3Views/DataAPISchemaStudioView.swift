#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitStudioCore
import SwiftUI

struct DataAPISchemaStudioView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    private enum SchemaCodeTab: String, CaseIterable, Identifiable {
        case swiftData = "SwiftData @Model"
        case sqliteDDL = "SQLite3 STRICT DDL"
        case coreDataXML = "CoreData XML"
        case actorRepo = "Actor Repository"
        case openAPI = "OpenAPI 3.1"
        case graphQL = "GraphQL SDL"
        case urlSession = "URLSession Client"
        case mermaidER = "Mermaid ER"

        var id: String { rawValue }
    }

    @State private var selectedPreset: SchemaPresetKind = .fintechDoubleEntry
    @State private var schemaWorkspace: DataSchemaWorkspace = .preset(.fintechDoubleEntry)
    @State private var selectedEntityName: String = ""
    @State private var selectedCodeTab: SchemaCodeTab = .swiftData

    @State private var selectedEndpointID: UUID?
    @State private var enforceMockAuth = false
    @State private var includeBearerHeader = true
    @State private var lastMockResponse: MockHTTPResponse?

    private var derivedService: APIServiceSpec {
        APIServiceSpec.deriveCRUDService(from: schemaWorkspace)
    }

    private var selectedEntity: SchemaEntity? {
        if let match = schemaWorkspace.entity(named: selectedEntityName) {
            return match
        }
        return schemaWorkspace.entities.first
    }

    var body: some View {
        let analysis = schemaWorkspace.analyzeNormalizationAndIntegrity()
        let service = derivedService

        VStack(alignment: .leading, spacing: 16) {
            presetAndNormalizationHeader(analysis: analysis)
            entityRelationshipInspectorCard
            backendAndAPISynthesizerCard(service: service)
            interactiveMockHTTPClientCard(service: service)
        }
        .onAppear {
            if selectedEntityName.isEmpty {
                selectedEntityName = schemaWorkspace.entities.first?.name ?? ""
            }
            if selectedEndpointID == nil {
                selectedEndpointID = service.endpoints.first?.id
            }
        }
        .onChange(of: selectedPreset) { nextPreset in
            let nextWS = DataSchemaWorkspace.preset(nextPreset)
            schemaWorkspace = nextWS
            selectedEntityName = nextWS.entities.first?.name ?? ""
            let nextService = APIServiceSpec.deriveCRUDService(from: nextWS)
            selectedEndpointID = nextService.endpoints.first?.id
            lastMockResponse = nil
            viewModel.statusMessage = "Loaded '\(nextPreset.title)' ER schema (\(nextWS.entities.count) entities)"
        }
    }

    // MARK: - 1. Schema Preset Switcher & 3NF Integrity Advisor

    private func presetAndNormalizationHeader(analysis: SchemaAnalysisReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Entity-Relationship Modeler & 3NF Normalization Advisor",
                        subtitle: "\(schemaWorkspace.name) — \(schemaWorkspace.entities.count) entities, \(schemaWorkspace.relationships.count) foreign-key relationships."
                    )
                    Spacer()
                    PillLabel(
                        title: "\(analysis.achievedNormalForm) · \(analysis.normalFormScore)/100",
                        systemImage: "cylinder.split.1x2.fill"
                    )
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SchemaPresetKind.allCases) { preset in
                            let active = selectedPreset == preset
                            Button {
                                selectedPreset = preset
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(active ? .white : .primary)
                                    Text(preset.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(active ? .white.opacity(0.84) : .secondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    active ? theme.primary.swiftUIColor : Color.secondary.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], spacing: 8) {
                    schemaStatBadge("Normal Form", analysis.achievedNormalForm, detail: "Score \(analysis.normalFormScore)/100")
                    schemaStatBadge("Est. Storage", String(format: "%.2f MB", analysis.estimatedTotalStorageMB), detail: "\(schemaWorkspace.entities.count) tables")
                    schemaStatBadge("PII Attributes", "\(analysis.piiAttributeCount)", detail: "Encrypted/Redacted")
                    schemaStatBadge("Index Suggestions", "\(analysis.indexRecommendations.count)", detail: analysis.cyclicEntityNames.isEmpty ? "DAG Acyclic" : "Cycle Warning")
                }

                if !analysis.indexRecommendations.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .foregroundStyle(theme.warning.swiftUIColor)
                        Text("\(analysis.indexRecommendations.count) missing B-Tree / FTS5 index recommendation(s) available for foreign keys & search predicates.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Apply Recommended Indexes") {
                            schemaWorkspace.applyRecommendedIndexes(analysis.indexRecommendations)
                            viewModel.statusMessage = "Applied \(analysis.indexRecommendations.count) index recommendations to \(schemaWorkspace.name)"
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primary.swiftUIColor)
                        .controlSize(.small)
                    }
                    .padding(9)
                    .background(theme.warning.swiftUIColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. Entity Columns & Relationships Inspector

    private var entityRelationshipInspectorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(schemaWorkspace.entities) { entity in
                        let active = selectedEntity?.id == entity.id
                        Button {
                            selectedEntityName = entity.name
                        } label: {
                            HStack(spacing: 6) {
                                Text(entity.name)
                                    .font(.caption.weight(.semibold))
                                Text("\(entity.attributes.count) cols")
                                    .font(.system(size: 10, design: .monospaced))
                                    .opacity(0.8)
                            }
                            .foregroundStyle(active ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                active ? theme.primary.swiftUIColor : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                if let entity = selectedEntity {
                    HStack {
                        Text("Table `\(entity.tableName)` — \(entity.summary)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("~\(entity.estimatedRowCount) rows · \(entity.estimatedRowStrideBytes)B stride · \(entity.indexes.count) indexes")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entity.attributes) { attr in
                            HStack(spacing: 8) {
                                Text(attr.name)
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .frame(width: 145, alignment: .leading)
                                Text(attr.fieldType.conciseLabel)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.primary.swiftUIColor)
                                    .frame(width: 120, alignment: .leading)
                                Text(attr.fieldType.sqliteStrictColumnType)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if attr.isPrimaryKey {
                                    attributePill("PK", color: theme.primary.swiftUIColor)
                                }
                                if attr.isUnique {
                                    attributePill("UNIQUE", color: theme.secondary.swiftUIColor)
                                }
                                if attr.isIndexed {
                                    attributePill("IDX", color: theme.success.swiftUIColor)
                                }
                                if attr.isSensitivePII {
                                    attributePill("PII", color: theme.danger.swiftUIColor)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                if !schemaWorkspace.relationships.isEmpty {
                    Divider()
                    Text("Foreign-Key Relationships (\(schemaWorkspace.relationships.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(schemaWorkspace.relationships) { rel in
                        HStack(spacing: 8) {
                            Text("\(rel.sourceEntityName).\(rel.name) → \(rel.targetEntityName)")
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            Spacer()
                            Text("\(rel.kind.displayTitle) · ON DELETE \(rel.deleteRule.sqliteAction)")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. Multi-Backend Persistence & API Specification Synthesizer

    private func backendAndAPISynthesizerCard(service: APIServiceSpec) -> some View {
        let synthesizedOutput = renderSynthesizedCode(service: service)

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "Persistence & API Code Compiler",
                        subtitle: "Compile SwiftData @Model, SQLite3 STRICT + FTS5, CoreData XML, OpenAPI 3.1, GraphQL & URLSession client."
                    )
                    Spacer()
                    Button {
                        viewModel.aiOverriddenCode[viewModel.selection] = synthesizedOutput
                        viewModel.rightInspectorTab = .code
                        viewModel.codePreviewMode = .swiftUI
                        viewModel.statusMessage = "Sent '\(selectedCodeTab.rawValue)' artifact to Live Code inspector"
                    } label: {
                        Label("Send to Inspector", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SchemaCodeTab.allCases) { tab in
                            let active = selectedCodeTab == tab
                            Button {
                                selectedCodeTab = tab
                            } label: {
                                Text(tab.rawValue)
                                    .font(.caption.weight(active ? .bold : .medium))
                                    .foregroundStyle(active ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        active ? theme.primary.swiftUIColor : Color.secondary.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                CodeBlockView(text: synthesizedOutput)
                    .frame(minHeight: 205, maxHeight: 280)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. Interactive Mock HTTP Endpoint Simulator

    private func interactiveMockHTTPClientCard(service: APIServiceSpec) -> some View {
        let activeEndpoint = service.endpoints.first { $0.id == selectedEndpointID } ?? service.endpoints.first

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Deterministic Mock HTTP Router (\(service.endpoints.count) CRUD Endpoints)",
                        subtitle: "Simulate authenticated REST requests against \(service.baseURL) with rate-limit headers."
                    )
                    Spacer()
                    Button {
                        if let endpoint = activeEndpoint {
                            executeMockRequest(endpoint: endpoint, service: service)
                        }
                    } label: {
                        Label("Send Mock Request", systemImage: "paperplane.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                HStack(spacing: 12) {
                    Picker("Endpoint", selection: $selectedEndpointID) {
                        ForEach(service.endpoints) { ep in
                            Text("\(ep.method.rawValue) \(ep.pathTemplate) (\(ep.operationID))")
                                .tag(Optional(ep.id))
                        }
                    }
                    .controlSize(.small)

                    Toggle("Enforce Auth", isOn: $enforceMockAuth)
                        .font(.caption)
                    Toggle("Bearer Token", isOn: $includeBearerHeader)
                        .font(.caption)
                }

                if let response = lastMockResponse {
                    HStack(spacing: 10) {
                        Text("HTTP \(response.statusCode)")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                response.statusCode < 300 ? theme.success.swiftUIColor : theme.danger.swiftUIColor,
                                in: Capsule()
                            )
                        Text(String(format: "%.1f ms", response.simulatedLatencyMs))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if let op = response.matchedOperationID {
                            Text("Operation: \(op)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    CodeBlockView(text: response.bodyJSON, showLineNumbers: false)
                        .frame(minHeight: 135, maxHeight: 195)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func renderSynthesizedCode(service: APIServiceSpec) -> String {
        switch selectedCodeTab {
        case .swiftData:
            return PersistenceCodeSynthesizer.synthesize(workspace: schemaWorkspace, backend: .swiftData).sourceCode
        case .sqliteDDL:
            return PersistenceCodeSynthesizer.synthesize(workspace: schemaWorkspace, backend: .sqlite3StrictDDL).sourceCode
        case .coreDataXML:
            return PersistenceCodeSynthesizer.synthesize(workspace: schemaWorkspace, backend: .coreDataXML).sourceCode
        case .actorRepo:
            return PersistenceCodeSynthesizer.synthesize(workspace: schemaWorkspace, backend: .swiftActorRepository).sourceCode
        case .openAPI:
            return APISpecAndMockEngine.compileOpenAPI31JSON(service)
        case .graphQL:
            return APISpecAndMockEngine.compileGraphQLSDL(service)
        case .urlSession:
            return APISpecAndMockEngine.synthesizeSwiftURLSessionClient(service)
        case .mermaidER:
            return schemaWorkspace.generateMermaidERDiagram(includeDocumentation: true)
        }
    }

    private func executeMockRequest(endpoint: APIEndpointSpec, service: APIServiceSpec) {
        let concretePath = endpoint.pathTemplate.replacingOccurrences(
            of: "{id}",
            with: "550e8400-e29b-41d4-a716-446655440000"
        )
        var headers: [String: String] = ["Accept": "application/json"]
        if includeBearerHeader {
            headers["Authorization"] = "Bearer ck_live_demo_jwt_token"
        }
        let sampleBody: String?
        if let reqEntityName = endpoint.requestEntityName,
           let entity = schemaWorkspace.entity(named: reqEntityName) {
            sampleBody = APISpecAndMockEngine.synthesizeSampleEntityJSON(entity: entity)
        } else {
            sampleBody = nil
        }

        let res = APISpecAndMockEngine.simulateRequest(
            service: service,
            method: endpoint.method,
            path: concretePath,
            headers: headers,
            body: sampleBody,
            enforceAuth: enforceMockAuth
        )
        lastMockResponse = res
        viewModel.statusMessage = "Mock \(endpoint.method.rawValue) \(concretePath) → HTTP \(res.statusCode)"
    }

    private func schemaStatBadge(_ title: String, _ value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(detail)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func attributePill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }
}
#endif
