import ChiefKitAST
import ChiefKitStudioCore
import Foundation
import Testing
import XCTest

// MARK: - Swift 6 Testing (@Suite / @Test) for Data Modeler, Localization, Profiler & Runtime

@Suite("ChiefKitStudioCore 3.0 — Data Schema, Persistence, Localization, Profiler & Runtime Suite")
struct DataLocalizationProfilerRuntimeSwiftTestingSuite {
    @Test(
        "All 6 SchemaPresetKind relational presets pass topological sort, 3NF analysis, Mermaid ER, and 4-backend synthesis",
        arguments: SchemaPresetKind.allCases
    )
    func allSixSchemaPresetsAndFourPersistenceBackends(presetKind: SchemaPresetKind) {
        #expect(SchemaPresetKind.allCases.count == 6)
        let workspace = DataSchemaWorkspace.preset(presetKind)
        #expect(!workspace.entities.isEmpty)
        #expect(!workspace.relationships.isEmpty)

        let topo = workspace.topologicalSortEntities()
        #expect(topo.cyclicEntityNames.isEmpty)
        #expect(topo.sorted.count == workspace.entities.count)

        let analysis = workspace.analyzeNormalizationAndIntegrity()
        #expect(analysis.normalFormScore >= 75)
        let severeAnomalies = analysis.graphAnomalies.filter { $0.severity == .error }
        #expect(severeAnomalies.isEmpty)

        let erd = workspace.generateMermaidERDiagram(includeDocumentation: true)
        #expect(erd.contains("erDiagram"))

        let artifacts = PersistenceCodeSynthesizer.synthesizeAllBackends(workspace: workspace)
        #expect(artifacts.count == 4)
        #expect(PersistenceBackendKind.allCases.count == 4)

        for artifact in artifacts {
            #expect(!artifact.sourceCode.isEmpty)
            #expect(artifact.entityCount == workspace.entities.count)

            switch artifact.backend {
            case .swiftData, .swiftActorRepository:
                let check = ASTSourceVerifier.verifySource(code: artifact.sourceCode, filePath: artifact.filename)
                #expect(check.isValid, "\(presetKind.rawValue) \(artifact.backend.rawValue) invalid Swift: \(check.issues)")
            case .sqlite3StrictDDL:
                #expect(artifact.sourceCode.contains("CREATE TABLE"))
                #expect(artifact.sourceCode.contains("STRICT"))
            case .coreDataXML:
                #expect(artifact.sourceCode.contains("<model"))
                #expect(artifact.sourceCode.contains("<entity"))
            }
        }
    }

    @Test(
        "All 4 PseudolocMode transformations preserve C/Swift format specifiers (%@, %lld, %.2f) intact",
        arguments: PseudolocMode.allCases
    )
    func pseudolocalizationModesPreservePlaceholders(mode: PseudolocMode) {
        #expect(PseudolocMode.allCases.count == 4)
        let template = "Welcome %@, you have %lld unread alerts worth $%.2f"
        let transformed = StringCatalogCompiler.pseudolocalize(template, mode: mode)

        #expect(transformed != template)
        #expect(transformed.contains("%@"))
        #expect(transformed.contains("%lld"))
        #expect(transformed.contains("%.2f"))

        let extractedBefore = StringCatalogCompiler.extractPlaceholders(from: template)
        let extractedAfter = StringCatalogCompiler.extractPlaceholders(from: transformed)
        #expect(extractedBefore == extractedAfter)
    }

    @Test(
        "FrameBudgetProfiler evaluates CPU/GPU phases and flamegraphs across 60Hz, 90Hz, and 120Hz targets",
        arguments: DisplayRefreshTarget.allCases
    )
    func frameBudgetProfilerAcrossDisplayRefreshTargets(target: DisplayRefreshTarget) {
        #expect(DisplayRefreshTarget.allCases.count == 3)
        let cleanSwiftUI = """
        import SwiftUI

        struct LightweightHeaderView: View {
            var body: some View {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                    Text("Real-Time Telemetry")
                        .font(.headline)
                }
                .padding(16)
            }
        }
        """

        let report = FrameBudgetProfiler.profile(
            swiftUISource: cleanSwiftUI,
            theme: StudioThemePreset.liquidGlass26.tokens,
            target: target
        )
        #expect(report.target == target)
        #expect(report.budgetMs > 8.0 && report.budgetMs < 17.0)
        #expect(report.meetsFrameBudget)
        #expect(report.headroomMs > 0.0)

        let rows = report.flamegraphRoot.flattenedRows()
        #expect(rows.count >= 4)
    }
}

// MARK: - XCTest Suite for Schema Normalization, API Mock Router, CLDR Localization, Profiler, Store DAG & Flow Runtime

final class DataLocalizationProfilerRuntimeXCTests: XCTestCase {
    func testSchemaNormalizationViolationsCycleOrphanDetectionIndexAdvisorAndDiffMigrationSQL() {
        // Synthetic unnormalized & anomalous schema triggering 0NF, 1NF, 3NF, orphan target, and cascade cycle
        let brokenOrderEntity = SchemaEntity(
            name: "FlatInvoice",
            isAuditedWithTimestamps: false,
            attributes: [
                // Missing primary key (0NF) + repeating group tag1/tag2/tag3 (1NF) + transitive customer_zip -> customer_city (3NF)
                SchemaAttribute(name: "tag1", fieldType: .string(maxLength: 40)),
                SchemaAttribute(name: "tag2", fieldType: .string(maxLength: 40)),
                SchemaAttribute(name: "tag3", fieldType: .string(maxLength: 40)),
                SchemaAttribute(name: "customer_id", fieldType: .uuid),
                SchemaAttribute(name: "customer_name", fieldType: .string(maxLength: 120)),
                SchemaAttribute(name: "customer_city", fieldType: .string(maxLength: 80))
            ]
        )
        let cycleA = SchemaEntity(
            name: "DepartmentNode",
            attributes: [SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true)]
        )
        let cycleB = SchemaEntity(
            name: "ManagerNode",
            attributes: [SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true)]
        )

        var anomalousWorkspace = DataSchemaWorkspace(
            name: "LegacyUnnormalizedDB",
            entities: [brokenOrderEntity, cycleA, cycleB],
            relationships: [
                SchemaRelationship(
                    name: "ghostLink",
                    sourceEntityName: "DepartmentNode",
                    targetEntityName: "NonExistentEntity",
                    kind: .oneToMany,
                    deleteRule: .cascade
                ),
                SchemaRelationship(
                    name: "leads",
                    sourceEntityName: "DepartmentNode",
                    targetEntityName: "ManagerNode",
                    kind: .oneToOne,
                    deleteRule: .cascade,
                    isOptional: false
                ),
                SchemaRelationship(
                    name: "belongsTo",
                    sourceEntityName: "ManagerNode",
                    targetEntityName: "DepartmentNode",
                    kind: .oneToOne,
                    deleteRule: .cascade,
                    isOptional: false
                )
            ]
        )

        let report = anomalousWorkspace.analyzeNormalizationAndIntegrity()
        let violationKinds = Set(report.normalizationFindings.map(\.kind))
        XCTAssertTrue(violationKinds.contains(.missingPrimaryKey))
        XCTAssertTrue(violationKinds.contains(.firstNFRepeatingGroup))

        let anomalyKinds = Set(report.graphAnomalies.map(\.kind))
        XCTAssertTrue(anomalyKinds.contains(.orphanTargetEntity))
        XCTAssertTrue(anomalyKinds.contains(.cascadeDeleteCycle) || anomalyKinds.contains(.mandatoryCircularDependency))

        let topo = anomalousWorkspace.topologicalSortEntities()
        XCTAssertFalse(topo.cyclicEntityNames.isEmpty)

        // Apply index advisor recommendations and confirm index count grows
        let indexCountBefore = anomalousWorkspace.entities.reduce(0) { $0 + $1.indexes.count }
        anomalousWorkspace.applyRecommendedIndexes(report.indexRecommendations)
        let indexCountAfter = anomalousWorkspace.entities.reduce(0) { $0 + $1.indexes.count }
        XCTAssertGreaterThanOrEqual(indexCountAfter, indexCountBefore)

        // Diff migration SQL between v1 and v2 workspaces
        let v1 = DataSchemaWorkspace(
            name: "BillingDB",
            schemaVersion: 1,
            entities: [
                SchemaEntity(
                    name: "Account",
                    attributes: [
                        SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true),
                        SchemaAttribute(name: "legacy_code", fieldType: .string(maxLength: 32))
                    ]
                )
            ]
        )
        let v2 = DataSchemaWorkspace(
            name: "BillingDB",
            schemaVersion: 2,
            entities: [
                SchemaEntity(
                    name: "Account",
                    attributes: [
                        SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true),
                        SchemaAttribute(name: "credit_limit", fieldType: .decimal(precision: 12, scale: 2), defaultValue: .literalDouble(0.0))
                    ]
                ),
                SchemaEntity(
                    name: "LedgerEntry",
                    attributes: [
                        SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true),
                        SchemaAttribute(name: "memo", fieldType: .text)
                    ]
                )
            ]
        )

        let diffSQL = PersistenceCodeSynthesizer.synthesizeDiffMigrationSQL(from: v1, to: v2)
        XCTAssertTrue(diffSQL.contains("ADD COLUMN"))
        XCTAssertTrue(diffSQL.contains("DROP COLUMN"))
        XCTAssertTrue(diffSQL.contains("CREATE TABLE"))
    }

    func testAPISpecAndMockEngineOpenAPIGraphQLMockRouterStatusCodesAndURLSessionClient() throws {
        let workspace = DataSchemaWorkspace.preset(.saasMultiTenant)
        let service = APIServiceSpec.deriveCRUDService(
            from: workspace,
            baseURL: "https://api.chiefkit.dev/v1",
            auth: .bearerJWT,
            pagination: .cursorBased(defaultLimit: 10, maxLimit: 50)
        )
        XCTAssertGreaterThanOrEqual(service.endpoints.count, workspace.entities.count * 5)

        // 1. OpenAPI 3.1.0 JSON validity
        let openAPIJSON = APISpecAndMockEngine.compileOpenAPI31JSON(service)
        let openAPIData = try XCTUnwrap(openAPIJSON.data(using: .utf8))
        let rawOpenAPI = try JSONSerialization.jsonObject(with: openAPIData)
        let openAPIObj = try XCTUnwrap(rawOpenAPI as? [String: Any])
        XCTAssertEqual(openAPIObj["openapi"] as? String, "3.1.0")
        XCTAssertNotNil(openAPIObj["paths"] as? [String: Any])
        XCTAssertNotNil(openAPIObj["components"] as? [String: Any])

        // 2. GraphQL SDL compilation
        let graphQLSDL = APISpecAndMockEngine.compileGraphQLSDL(service)
        XCTAssertTrue(graphQLSDL.contains("type Query"))
        XCTAssertTrue(graphQLSDL.contains("type Mutation"))

        // 3. Mock HTTP Router status codes: 401 Unauthorized, 200 Paginated List, 201 Create, 400 Empty Body, 204 Delete, 404 Not Found, 405 Method Not Allowed
        let firstEntity = workspace.entities[0]
        let slug = firstEntity.tableName.replacingOccurrences(of: "_", with: "-")
        let collectionPath = "/\(slug)"
        let itemPath = "/\(slug)/550e8400-e29b-41d4-a716-446655440000"
        let authHeaders = ["Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.validtoken"]

        let unauthorized = APISpecAndMockEngine.simulateRequest(
            service: service,
            method: .get,
            path: collectionPath,
            headers: [:],
            enforceAuth: true
        )
        XCTAssertEqual(unauthorized.statusCode, 401)

        let listOK = APISpecAndMockEngine.simulateRequest(
            service: service,
            method: .get,
            path: collectionPath,
            query: ["limit": "3"],
            headers: authHeaders,
            enforceAuth: true
        )
        XCTAssertEqual(listOK.statusCode, 200)
        XCTAssertTrue(listOK.bodyJSON.contains("next_cursor"))
        XCTAssertTrue(listOK.bodyJSON.contains("items"))

        let createBadBody = APISpecAndMockEngine.simulateRequest(
            service: service,
            method: .post,
            path: collectionPath,
            headers: authHeaders,
            body: "",
            enforceAuth: true
        )
        XCTAssertEqual(createBadBody.statusCode, 400)

        let sampleBody = APISpecAndMockEngine.synthesizeSampleEntityJSON(entity: firstEntity)
        let createOK = APISpecAndMockEngine.simulateRequest(
            service: service,
            method: .post,
            path: collectionPath,
            headers: authHeaders,
            body: sampleBody,
            enforceAuth: true
        )
        XCTAssertEqual(createOK.statusCode, 201)

        let deleteNoContent = APISpecAndMockEngine.simulateRequest(
            service: service,
            method: .delete,
            path: itemPath,
            headers: authHeaders,
            enforceAuth: true
        )
        XCTAssertEqual(deleteNoContent.statusCode, 204)

        let methodNotAllowed = APISpecAndMockEngine.simulateRequest(
            service: service,
            method: .put,
            path: collectionPath,
            headers: authHeaders
        )
        XCTAssertEqual(methodNotAllowed.statusCode, 405)

        let notFound = APISpecAndMockEngine.simulateRequest(
            service: service,
            method: .get,
            path: "/non-existent-collection-xyz"
        )
        XCTAssertEqual(notFound.statusCode, 404)

        // 4. Swift 6 URLSession Client synthesis passes ASTSourceVerifier
        let clientCode = APISpecAndMockEngine.synthesizeSwiftURLSessionClient(service)
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: clientCode).isValid)
    }

    func testStringCatalogXCStringsRoundTripCLDRPluralsTurkishArabicExtractionDiagnosticsAndL10n() throws {
        // 1. CLDR plural rules including Turkish (1 -> .one, 0/2/5 -> .other) & 6-form Arabic (0, 1, 2, 3..10, 11..99, 100)
        XCTAssertEqual(LocaleCode.allCases.count, 10)
        XCTAssertEqual(CLDRPluralCategory.allCases.count, 6)

        XCTAssertEqual(pluralCategory(for: 1, locale: .tr), .one)
        XCTAssertEqual(pluralCategory(for: 0, locale: .tr), .other)
        XCTAssertEqual(pluralCategory(for: 5, locale: .tr), .other)

        XCTAssertEqual(pluralCategory(for: 0, locale: .ar), .zero)
        XCTAssertEqual(pluralCategory(for: 1, locale: .ar), .one)
        XCTAssertEqual(pluralCategory(for: 2, locale: .ar), .two)
        XCTAssertEqual(pluralCategory(for: 7, locale: .ar), .few)
        XCTAssertEqual(pluralCategory(for: 42, locale: .ar), .many)
        XCTAssertEqual(pluralCategory(for: 100, locale: .ar), .other)
        XCTAssertTrue(LocaleCode.ar.scriptDirection.isRTL)

        // 2. Unified master built-in catalog + .xcstrings JSON lossless round-trip
        var master = StudioBuiltInTranslations.unifiedMasterCatalog()
        XCTAssertGreaterThanOrEqual(master.entries.count, 20)

        master.upsertPluralTranslation(
            key: "inbox.unread_count",
            comment: "Unread notifications badge",
            locale: .ar,
            forms: [
                .zero: "لا توجد رسائل",
                .one: "رسالة واحدة",
                .two: "رسالتان",
                .few: "%lld رسائل",
                .many: "%lld رسالة",
                .other: "%lld رسالة"
            ]
        )
        XCTAssertEqual(
            master.resolve(key: "inbox.unread_count", locale: .ar, count: 2, arguments: [.int(2)]),
            "رسالتان"
        )
        XCTAssertEqual(
            master.resolve(key: "inbox.unread_count", locale: .ar, count: 7, arguments: [.int(7)]),
            "7 رسائل"
        )

        let encodedXCStrings = try StringCatalogCompiler.encodeXCStringsJSON(master)
        let decodedCatalog = try StringCatalogCompiler.decodeXCStringsJSON(encodedXCStrings)
        XCTAssertEqual(decodedCatalog.entries.count, master.entries.count)
        XCTAssertEqual(
            decodedCatalog.resolve(key: "inbox.unread_count", locale: .ar, count: 42, arguments: [.int(42)]),
            "42 رسالة"
        )

        // 3. SwiftUI source literal extraction & placeholder mismatch diagnostics
        let swiftUISource = """
        import SwiftUI

        struct BillingAlertView: View {
            var body: some View {
                VStack {
                    Text("Pay Invoice")
                    Button("Confirm Transfer") {}
                    EDKButton("Export Statement") {}
                    Label("Security Verified", systemImage: "checkmark.shield")
                }
                .navigationTitle("Treasury")
            }
        }
        """
        let extracted = StringCatalogCompiler.extractSwiftUIStrings(from: swiftUISource)
        XCTAssertGreaterThanOrEqual(extracted.count, 4)

        var mismatchedCatalog = StringCatalogCompiler.extractAndMergeIntoCatalog(
            swiftSource: swiftUISource,
            into: StringCatalogDocument(catalogName: "Billing", targetLocales: [.en, .tr])
        )
        mismatchedCatalog.upsertSimpleTranslation(
            key: "greeting.balance",
            locale: .en,
            value: "Hello %@, balance is %lld USD"
        )
        // Missing second placeholder in Turkish translation triggers placeholder mismatch diagnostic!
        mismatchedCatalog.upsertSimpleTranslation(
            key: "greeting.balance",
            locale: .tr,
            value: "Merhaba %@"
        )
        let diagnostics = StringCatalogCompiler.validateCatalog(mismatchedCatalog, swiftUISource: swiftUISource)
        XCTAssertTrue(diagnostics.contains(where: { $0.key == "greeting.balance" }))

        // 4. Strongly-typed L10n Swift enum generation passes ASTSourceVerifier
        let l10nCode = StringCatalogCompiler.synthesizeL10nSwiftEnum(from: master, enumName: "L10n")
        XCTAssertTrue(l10nCode.contains("public enum L10n"))
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: l10nCode).isValid)
    }

    func testFrameBudgetOptimizationPatchesAndStateInvalidationBlastRadiusAnalyzer() {
        // 1. FrameBudgetProfiler detects offscreen GPU hazards and optimization patches lower frame time
        let heavyOffscreenView = """
        import SwiftUI

        struct HeavyGlassScrollScreen: View {
            let rows = Array(0..<50)

            var body: some View {
                ScrollView {
                    GeometryReader { geo in
                        VStack {
                            ForEach(rows, id: \\.self) { item in
                                Text("Row \\(item)")
                                    .padding(12)
                                    .background(.ultraThinMaterial)
                                    .blur(radius: 14)
                                    .shadow(radius: 12)
                                    .shadow(radius: 18)
                                    .mask(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
        """

        let beforeProfile = FrameBudgetProfiler.profile(swiftUISource: heavyOffscreenView, target: .proMotion120Hz)
        XCTAssertFalse(beforeProfile.hazards.isEmpty)
        XCTAssertGreaterThan(beforeProfile.metalOffscreenPassCount, 0)

        let acrossAll = FrameBudgetProfiler.compareAcrossTargets(swiftUISource: heavyOffscreenView)
        XCTAssertEqual(acrossAll.count, 3)

        let patchedSource = FrameBudgetProfiler.applyOptimizationPatches(
            to: heavyOffscreenView,
            hazards: beforeProfile.hazards
        )
        let afterProfile = FrameBudgetProfiler.profile(swiftUISource: patchedSource, target: .proMotion120Hz)
        XCTAssertLessThanOrEqual(afterProfile.totalFrameTimeMs, beforeProfile.totalFrameTimeMs)

        // 2. StateInvalidationAnalyzer detects coarse @EnvironmentObject / monolithic @State blast radius & emits decomposition
        let coupledStateSource = """
        import Combine
        import SwiftUI

        final class GlobalAppSession: ObservableObject {
            @Published var currentTab: Int = 0
            @Published var unreadCount: Int = 3
        }

        struct MonolithicRootView: View {
            @EnvironmentObject var session: GlobalAppSession
            @State private var s1: String = ""
            @State private var s2: String = ""
            @State private var s3: String = ""
            @State private var s4: String = ""
            @State private var s5: String = ""
            @State private var s6: String = ""

            var body: some View {
                VStack {
                    Text("Tab \\(session.currentTab)")
                    TextField("One", text: $s1)
                    ChildBannerView()
                }
            }
        }

        struct ChildBannerView: View {
            @EnvironmentObject var session: GlobalAppSession
            var body: some View {
                Text("Unread \\(session.unreadCount)")
            }
        }
        """

        let invReport = StateInvalidationAnalyzer.analyze(swiftSource: coupledStateSource)
        XCTAssertGreaterThanOrEqual(invReport.views.count, 2)
        XCTAssertFalse(invReport.edges.isEmpty)
        XCTAssertFalse(invReport.blastRadiusMetrics.isEmpty)
        XCTAssertGreaterThan(invReport.worstBlastRadiusPercent, 0.0)
        XCTAssertFalse(invReport.findings.isEmpty)
        XCTAssertTrue(invReport.mermaidFlowchartLR.contains("flowchart LR"))
    }

    func testStudioStoreActorReducerMiddlewareRateLimiterAndCausalStateDAG() async {
        struct LedgerState: Codable, Equatable, Sendable {
            var balanceCents: Int = 1_000
            var auditCount: Int = 0
            var statusNote: String = "ready"
        }

        enum LedgerAction: StudioActionProtocol, Equatable, Sendable {
            case deposit(Int)
            case blockedNegativeDeposit
            case triggerBonusDeposit(Int)
            case recordBonusNote(String)
            case rapidPing

            var rateLimitKey: String? {
                if case .rapidPing = self { return "ping_key" }
                return nil
            }
        }

        let reducer = StudioReducer<LedgerState, LedgerAction> { state, action in
            switch action {
            case .deposit(let cents):
                state.balanceCents += cents
                state.auditCount += 1
                return .none
            case .blockedNegativeDeposit:
                state.balanceCents -= 999_999
                return .none
            case .triggerBonusDeposit(let cents):
                state.balanceCents += cents
                state.auditCount += 1
                return .send(.recordBonusNote("bonus_applied"))
            case .recordBonusNote(let note):
                state.statusNote = note
                return .none
            case .rapidPing:
                state.auditCount += 1
                return .none
            }
        }

        let guardMW = StudioMiddleware<LedgerState, LedgerAction>.guardPredicate(
            name: "BlockNegativeDeposit",
            reasonWhenBlocked: "Negative deposit prohibited"
        ) { _, action in
            action != .blockedNegativeDeposit
        }

        let rewriteMW = StudioMiddleware<LedgerState, LedgerAction>(name: "DoubleSmallDeposits") { _, action, _ in
            if case .deposit(let cents) = action, cents == 50 {
                return .rewrite(.deposit(100), sideEffect: .none)
            }
            return .proceed(action)
        }

        let store = StudioStore(
            storeName: "TreasuryTestStore",
            initialState: LedgerState(),
            reducer: reducer,
            middlewares: [guardMW, rewriteMW],
            rateLimiter: ActionRateLimiterCalculator(debounceIntervalMs: 250, burstTokens: 5.0, refillTokensPerSecond: 2.0)
        )

        // 1. Rewrite middleware turns deposit(50) into deposit(100)
        let afterRewrite = await store.send(.deposit(50), nowEpochMs: 1_000)
        XCTAssertEqual(afterRewrite.balanceCents, 1_100)

        // 2. Guard middleware drops .blockedNegativeDeposit
        let afterBlocked = await store.send(.blockedNegativeDeposit, nowEpochMs: 2_000)
        XCTAssertEqual(afterBlocked.balanceCents, 1_100)

        // 3. Immediate effect chaining (.triggerBonusDeposit -> .recordBonusNote)
        let afterEffect = await store.send(.triggerBonusDeposit(250), nowEpochMs: 3_000)
        XCTAssertEqual(afterEffect.balanceCents, 1_350)
        XCTAssertEqual(afterEffect.statusNote, "bonus_applied")

        // 4. Debounce rate-limiter drops duplicate rapidPing within 250ms window
        _ = await store.send(.rapidPing, nowEpochMs: 5_000)
        let countAfterFirstPing = await store.currentState().auditCount
        _ = await store.send(.rapidPing, nowEpochMs: 5_050)
        let countAfterDebouncedPing = await store.currentState().auditCount
        XCTAssertEqual(countAfterDebouncedPing, countAfterFirstPing)

        // 5. CausalStateDAG checkpoints, branching, JSON state diffing, time-travel, and cherry-pick
        await store.tagCheckpoint("v1-baseline")
        let dagBeforeBranch = await store.snapshotDAG()
        let baseCommitID = dagBeforeBranch.headCommitID

        let createdBranch = await store.createBranch(named: "what-if-simulation")
        XCTAssertTrue(createdBranch)
        _ = await store.send(.deposit(5_000), nowEpochMs: 6_000)
        let simState = await store.currentState()
        XCTAssertEqual(simState.balanceCents, 6_350)

        let simHeadID = await store.snapshotDAG().headCommitID
        let diffs = await store.diffCommits(from: baseCommitID, to: simHeadID)
        XCTAssertTrue(diffs.contains(where: { $0.jsonPath.contains("balanceCents") }))

        // Switch back to main branch restores pre-simulation state (1_350)
        let mainRestored = await store.switchBranch(to: "main")
        XCTAssertEqual(mainRestored?.balanceCents, 1_350)

        // Direct CausalStateDAG cherryPickReplay verification
        var localDAG = await store.snapshotDAG()
        let replayedState = localDAG.cherryPickReplay(
            actionsToReplay: [LedgerAction.deposit(400)],
            ontoCommitID: baseCommitID,
            newBranchName: "cherry-picked",
            reducer: reducer,
            timestampEpochMs: 7_000
        )
        XCTAssertEqual(replayedState?.balanceCents, 1_750)
        XCTAssertGreaterThanOrEqual(localDAG.ancestryLineage().count, 2)

        let telemetry = await store.telemetrySummary()
        XCTAssertGreaterThanOrEqual(telemetry.totalRecordedCount, 5)
        XCTAssertGreaterThanOrEqual(telemetry.droppedActionCount, 2)
    }

    func testNotebookFlowRuntimePredicatesISO13616IBANPathExplorerJupyterAndDocBundleCompiler() throws {
        // 1. Boolean predicate evaluator (`&&`, `||`, `!`, `contains`, comparisons, subscripts)
        let predTrue = try FlowExpressionEvaluator.evaluate(
            predicate: #"answers["role"] == "engineer" && (score >= 80 || vip == true) && !(country == "KP") && email contains "@chiefkit.io""#,
            answers: ["role": "engineer", "email": "ada@chiefkit.io", "country": "TR"],
            variables: ["score": .number(92), "vip": .bool(false)]
        )
        XCTAssertTrue(predTrue)

        let predFalse = try FlowExpressionEvaluator.evaluate(
            predicate: #"score > 95 && answers["role"] == "finance""#,
            answers: ["role": "engineer"],
            variables: ["score": .number(92)]
        )
        XCTAssertFalse(predFalse)

        // 2. ISO-13616 Modulo-97 IBAN validation (official valid DE, GB, TR IBANs vs corrupted check digits)
        XCTAssertNil(FlowValidationRule.iban.validate("DE89 3704 0044 0532 0130 00"))
        XCTAssertNil(FlowValidationRule.iban.validate("GB29 NWBK 6016 1331 9268 19"))
        XCTAssertNil(FlowValidationRule.iban.validate("TR33 0006 1005 1978 6457 8413 26"))
        XCTAssertNotNil(FlowValidationRule.iban.validate("DE00 3704 0044 0532 0130 00"))
        XCTAssertNotNil(FlowValidationRule.iban.validate("INVALID-IBAN"))

        XCTAssertNil(FlowValidationRule.phoneE164.validate("+905321234567"))
        XCTAssertNotNil(FlowValidationRule.phoneE164.validate("0532-123-4567"))
        XCTAssertNil(FlowValidationRule.email.validate("architect@hnmlabs.io"))
        XCTAssertNotNil(FlowValidationRule.email.validate("not-an-email"))

        // 3. Step evaluation & full path exploration on enterpriseQualificationSample + synthetic cycle/orphan graph
        let sampleFlow = ConditionalFlowSpec.enterpriseQualificationSample
        let engineerOutcome = NotebookFlowRuntimeEngine.evaluateStep(
            in: sampleFlow,
            stepID: "profile_intake",
            answers: ["work_email": "dev@hnmlabs.io", "role": "engineer", "score": "90"],
            variables: ["score": .number(90)]
        )
        XCTAssertTrue(engineerOutcome.isValid)
        XCTAssertEqual(engineerOutcome.resolvedNextStepID, "sdk_fast_track")

        let pathReport = NotebookFlowRuntimeEngine.exploreAllPaths(in: sampleFlow)
        XCTAssertEqual(pathReport.reachablePaths.count, 3)
        XCTAssertTrue(pathReport.unreachableStepIDs.isEmpty)
        XCTAssertTrue(pathReport.deadEndStepIDs.isEmpty)
        XCTAssertTrue(pathReport.cyclicStepPaths.isEmpty)
        XCTAssertTrue(pathReport.brokenTargetReferences.isEmpty)

        // Synthetic cyclic + orphan + dead-end flow topology verification
        let cyclicFlow = ConditionalFlowSpec(
            id: "cyclic_audit",
            title: "Cyclic Flow",
            entryStepID: "s1",
            steps: [
                FlowStepSpec(
                    id: "s1",
                    title: "Entry",
                    branches: [FlowBranchRule(id: "b1", predicateExpression: "retry == true", targetStepID: "s2")],
                    fallbackNextStepID: "dead_end"
                ),
                FlowStepSpec(id: "s2", title: "LoopBack", fallbackNextStepID: "s1"),
                FlowStepSpec(id: "dead_end", title: "Stuck Non-Terminal", isTerminalCompletion: false),
                FlowStepSpec(id: "orphan_step", title: "Unreachable", isTerminalCompletion: true)
            ]
        )
        let cyclicReport = NotebookFlowRuntimeEngine.exploreAllPaths(in: cyclicFlow)
        XCTAssertFalse(cyclicReport.cyclicStepPaths.isEmpty)
        XCTAssertTrue(cyclicReport.deadEndStepIDs.contains("dead_end"))
        XCTAssertTrue(cyclicReport.unreachableStepIDs.contains("orphan_step"))

        // 4. Jupyter .ipynb v4 JSON notebook export
        let ipynbJSON = NotebookFlowRuntimeEngine.exportJupyterNotebookJSON(sampleFlow)
        let ipynbData = try XCTUnwrap(ipynbJSON.data(using: .utf8))
        let rawIpynb = try JSONSerialization.jsonObject(with: ipynbData)
        let ipynbObj = try XCTUnwrap(rawIpynb as? [String: Any])
        XCTAssertEqual(ipynbObj["nbformat"] as? Int, 4)
        let cells = try XCTUnwrap(ipynbObj["cells"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(cells.count, 2 + sampleFlow.steps.count * 2)

        // 5. StudioDocBundleCompiler DocC (.docc) + standalone HTML specification bundle + disk write
        let docInput = StudioSpecBundleInput(
            projectName: "ChiefKit Treasury Suite",
            versionString: "3.0.0",
            authorOrganization: "HNMLabs",
            themeTokens: StudioThemePreset.liquidGlass26.tokens,
            conditionalFlow: sampleFlow,
            dataSchema: DataSchemaWorkspace.preset(.fintechDoubleEntry),
            stringCatalog: StudioBuiltInTranslations.unifiedMasterCatalog()
        )
        let compiledBundle = StudioDocBundleCompiler.compileBundle(docInput)
        XCTAssertEqual(compiledBundle.doccFiles.count, DocArticleKind.allCases.count)
        for kind in DocArticleKind.allCases {
            XCTAssertNotNil(compiledBundle.article(for: kind))
        }
        XCTAssertTrue(compiledBundle.standaloneHTMLSpecification.contains("<!DOCTYPE html>"))
        XCTAssertTrue(compiledBundle.standaloneHTMLSpecification.contains("ChiefKit Treasury Suite"))

        let tempDocDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChiefKitDocBundleTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempDocDir)
        }
        let writtenURLs = try StudioDocBundleCompiler.writeBundleToDirectory(compiledBundle, directoryURL: tempDocDir)
        XCTAssertEqual(writtenURLs.count, compiledBundle.doccFiles.count + 1)
        for url in writtenURLs {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }
}
