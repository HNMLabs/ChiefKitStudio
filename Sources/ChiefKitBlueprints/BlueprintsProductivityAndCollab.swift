import ChiefKitStudioCore
import Foundation

// MARK: - Vertical 5: Multiplayer Productivity & Zero-Knowledge Vault Blueprints

public enum ProductivityAndCollabBlueprints: Sendable {
    public static let specs: [EnterpriseBlueprintSpec] = [
        multiplayerBlockWikiDocs,
        agileSprintOKRRoadmap,
        zeroKnowledgePasskeyVault
    ]

    // MARK: 13. Multiplayer CRDT Block Wiki & Docs

    public static let multiplayerBlockWikiDocs = EnterpriseBlueprintSpec(
        id: .multiplayerBlockWikiDocs,
        vertical: .productivityCollab,
        title: "Multiplayer Block Wiki & Docs",
        subtitle: "Lamport-clock CRDT block operations, fractional index ordering, live peer cursors, and macOS split-view editing.",
        sfSymbol: "doc.richtext.fill",
        complexityTier: .enterprise,
        supportedPlatforms: [.macOS, .iPadOS, .iOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "CRDTDocumentBlock",
                tableName: "crdt_document_blocks",
                summary: "Conflict-free replicated document block ordered by fractional index key and resolved via Lamport clock + peer ID.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"blk-01\"", isIndexed: true, summary: "Immutable UUID/ULID block identifier."),
                    BlueprintEntityField(name: "fractionalKey", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "100.0", isIndexed: true, summary: "Dense fractional ordering index allowing O(1) midpoint insertion."),
                    BlueprintEntityField(name: "blockKind", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"HEADING_1\"", summary: "HEADING_1, PARAGRAPH, CALLOUT, CODE_SWIFT, CHECKLIST."),
                    BlueprintEntityField(name: "markdownBody", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"# ChiefKit 3.0 Architecture RFC\"", summary: "Block markdown content."),
                    BlueprintEntityField(name: "lamportTick", swiftType: "UInt64", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "12", summary: "Causal Lamport logical timestamp."),
                    BlueprintEntityField(name: "authorPeerID", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"peer-mac-01\"", summary: "Replica peer identifier for deterministic tie-breaking."),
                    BlueprintEntityField(name: "isTombstoned", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "Soft-delete tombstone preserving causal CRDT convergence.")
                ],
                computedHelpersSwift: """
                /// Deterministic LWW comparison: higher Lamport tick wins; ties break lexicographically on peer ID.
                public func supersedes(_ other: CRDTDocumentBlock) -> Bool {
                    if lamportTick != other.lamportTick {
                        return lamportTick > other.lamportTick
                    }
                    return authorPeerID > other.authorPeerID
                }
                """
            ),
            BlueprintDomainEntity(
                name: "PeerPresenceCursor",
                tableName: "peer_presence_cursors",
                summary: "Ephemeral WebSocket/WebRTC awareness cursor broadcasting collaborator block focus.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"peer-ipad-02\"", isIndexed: true, summary: "Replica peer ID."),
                    BlueprintEntityField(name: "displayName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Emre (iPad Pro)\"", summary: "Collaborator display label."),
                    BlueprintEntityField(name: "focusedBlockID", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"blk-02\"", summary: "Currently focused block ID."),
                    BlueprintEntityField(name: "rttMillis", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "22", summary: "Peer sync round-trip latency in ms.")
                ],
                computedHelpersSwift: """
                public var isLowLatencyPeer: Bool {
                    rttMillis <= 50
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "blocks",
                swiftType: "[CRDTDocumentBlock]",
                initialValueLiteral: """
                [
                    CRDTDocumentBlock(id: "blk-01", fractionalKey: 100.0, blockKind: "HEADING_1", markdownBody: "# Q4 Distributed Sync Specification", lamportTick: 10, authorPeerID: "peer-mac-01", isTombstoned: false),
                    CRDTDocumentBlock(id: "blk-02", fractionalKey: 200.0, blockKind: "CALLOUT", markdownBody: "Zero-conflict offline edits converge deterministically via Lamport + PeerID.", lamportTick: 11, authorPeerID: "peer-ipad-02", isTombstoned: false),
                    CRDTDocumentBlock(id: "blk-03", fractionalKey: 300.0, blockKind: "CODE_SWIFT", markdownBody: "actor SyncCoordinator { func merge(_ delta: CRDTBlock) {} }", lamportTick: 12, authorPeerID: "peer-mac-01", isTombstoned: false)
                ]
                """,
                summary: "Replicated CRDT blocks sorted by fractional index."
            ),
            BlueprintStateProperty(
                name: "collaborators",
                swiftType: "[PeerPresenceCursor]",
                initialValueLiteral: """
                [
                    PeerPresenceCursor(id: "peer-ipad-02", displayName: "Emre · Design Systems", focusedBlockID: "blk-02", rttMillis: 19),
                    PeerPresenceCursor(id: "peer-mac-09", displayName: "Zeynep · Core Runtime", focusedBlockID: "blk-03", rttMillis: 31)
                ]
                """,
                summary: "Active multiplayer collaborator cursors."
            ),
            BlueprintStateProperty(
                name: "localLamportClock",
                swiftType: "UInt64",
                initialValueLiteral: "12",
                summary: "Monotonically increasing local logical clock."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "insertMidpointBlock(afterBlockID: String, kind: String, markdown: String)",
                matchPattern: ".insertMidpointBlock(let afterBlockID, let kind, let markdown)",
                buttonTitle: "Insert Midpoint Block",
                sampleDispatchLiteral: ".insertMidpointBlock(afterBlockID: \"blk-01\", kind: \"PARAGRAPH\", markdown: \"Inserted concurrently at fractional key 150.0.\")",
                summary: "Computes dense fractional midpoint key between adjacent blocks and increments Lamport clock.",
                mutationBodySwift: """
                state.localLamportClock += 1
                let sorted = state.blocks.sorted { $0.fractionalKey < $1.fractionalKey }
                let anchorIdx = sorted.firstIndex(where: { $0.id == afterBlockID }) ?? max(0, sorted.count - 1)
                let leftKey = sorted.isEmpty ? 100.0 : sorted[anchorIdx].fractionalKey
                let rightKey = (anchorIdx + 1 < sorted.count) ? sorted[anchorIdx + 1].fractionalKey : (leftKey + 100.0)
                let midpoint = (leftKey + rightKey) * 0.5
                let created = CRDTDocumentBlock(
                    id: "blk-0\\(state.blocks.count + 1)",
                    fractionalKey: midpoint,
                    blockKind: kind,
                    markdownBody: markdown,
                    lamportTick: state.localLamportClock,
                    authorPeerID: "peer-local",
                    isTombstoned: false
                )
                state.blocks.append(created)
                state.blocks.sort { $0.fractionalKey < $1.fractionalKey }
                state.lastAuditMessage = "Inserted \\(created.id) @ key \\(midpoint) (Lamport \\(state.localLamportClock))"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "mergeRemoteBlockOperation(incoming: CRDTDocumentBlock)",
                matchPattern: ".mergeRemoteBlockOperation(let incoming)",
                buttonTitle: "Merge Remote CRDT Op",
                sampleDispatchLiteral: ".mergeRemoteBlockOperation(incoming: CRDTDocumentBlock(id: \"blk-02\", fractionalKey: 200.0, blockKind: \"CALLOUT\", markdownBody: \"Updated remotely with higher Lamport tick 25.\", lamportTick: 25, authorPeerID: \"peer-ipad-02\", isTombstoned: false))",
                summary: "Idempotently merges a remote CRDT block operation if it supersedes local state.",
                mutationBodySwift: """
                state.localLamportClock = max(state.localLamportClock, incoming.lamportTick) + 1
                if let idx = state.blocks.firstIndex(where: { $0.id == incoming.id }) {
                    if incoming.supersedes(state.blocks[idx]) {
                        state.blocks[idx] = incoming
                        state.lastAuditMessage = "Merged winning remote op on \\(incoming.id)"
                    } else {
                        state.lastAuditMessage = "Ignored stale remote op on \\(incoming.id)"
                    }
                } else {
                    state.blocks.append(incoming)
                    state.blocks.sort { $0.fractionalKey < $1.fractionalKey }
                    state.lastAuditMessage = "Inserted remote block \\(incoming.id)"
                }
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "tombstoneBlock(blockID: String)",
                matchPattern: ".tombstoneBlock(let blockID)",
                summary: "Marks block tombstoned with incremented Lamport clock so offline peers converge.",
                mutationBodySwift: """
                guard let idx = state.blocks.firstIndex(where: { $0.id == blockID }) else { break }
                state.localLamportClock += 1
                state.blocks[idx].isTombstoned = true
                state.blocks[idx].lamportTick = state.localLamportClock
                state.lastAuditMessage = "Tombstoned block \\(blockID)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchDocumentCRDTLog",
                method: .get,
                path: "/v1/wiki/documents/blocks",
                responseType: "[CRDTDocumentBlock]",
                offlineStubSwift: "MultiplayerBlockWikiState().blocks",
                summary: "Downloads compacted CRDT block state for offline hydration."
            ),
            BlueprintAPIEndpoint(
                methodName: "pushCRDTBlockDelta",
                method: .post,
                path: "/v1/wiki/documents/deltas",
                requestPayloadType: "CRDTDocumentBlock",
                responseType: "CRDTDocumentBlock",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Broadcasts idempotent Lamport-stamped block delta."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchCollaboratorPresence",
                method: .get,
                path: "/v1/wiki/presence",
                responseType: "[PeerPresenceCursor]",
                offlineStubSwift: "MultiplayerBlockWikiState().collaborators",
                summary: "Lists active peer cursors in document room."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "liveBlocks", label: "Visible Wiki Blocks", value: "3 Blocks", delta: "0 tombstones", sfSymbol: "text.append"),
            BlueprintKPIMetric(key: "lamport", label: "Logical Clock", value: "Tick #12", delta: "Causal converged", sfSymbol: "clock.badge.checkmark.fill"),
            BlueprintKPIMetric(key: "peers", label: "Active Collaborators", value: "3 Online", delta: "19ms median RTT", sfSymbol: "person.2.wave.2.fill"),
            BlueprintKPIMetric(key: "e2ee", label: "Room Encryption", value: "MLS / HPKE", delta: "Zero server plaintext", sfSymbol: "lock.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "w-1", headline: "# Q4 Distributed Sync Specification", subheadline: "HEADING_1 · Fractional Key 100.0 · Lamport #10", trailingMetric: "peer-mac-01", statusTag: "CONVERGED"),
            BlueprintSampleRecord(id: "w-2", headline: "Zero-conflict offline edits converge deterministically...", subheadline: "CALLOUT · Focused by Emre · Lamport #11", trailingMetric: "peer-ipad-02", statusTag: "LIVE CURSOR"),
            BlueprintSampleRecord(id: "w-3", headline: "actor SyncCoordinator { func merge(...) }", subheadline: "CODE_SWIFT · Focused by Zeynep · Lamport #12", trailingMetric: "peer-mac-09", statusTag: "CODE BLOCK")
        ],
        onboardingPages: [
            FlowPage(
                id: "offline-first",
                title: "Local-First SQLite + CRDT Convergence",
                body: "Edit slash-command blocks offline on airplanes and merge with zero conflicts on reconnect.",
                style: "hero",
                actions: ["Create Workspace Key"]
            ),
            FlowPage(
                id: "keymap-mode",
                title: "Select macOS Split-View Keybindings",
                body: "Navigate slash menus, backlinks, and command palette without leaving the home row.",
                style: "choice",
                actions: ["Standard macOS", "Vim Modal Navigation"]
            ),
            FlowPage(
                id: "wiki-ready",
                title: "Multiplayer Block Wiki Ready",
                body: "Fractional indexing, Lamport tie-breaking, and live peer presence are active.",
                style: "completion",
                actions: ["Launch Block Wiki"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "wiki.title", en: "Multiplayer Block Wiki & Docs", tr: "Çok Oyunculu Blok Wiki ve Belgeler"),
            BlueprintLocalizedKey(key: "wiki.insert_block", en: "Insert Slash Block", tr: "Yeni İçerik Bloğu Ekle"),
            BlueprintLocalizedKey(key: "wiki.merge_remote", en: "Sync Peer Changes", tr: "Eş Değişikliklerini Birleştir"),
            BlueprintLocalizedKey(key: "wiki.collaborators", en: "Active Collaborators", tr: "Aktif Çalışma Arkadaşları"),
            BlueprintLocalizedKey(key: "wiki.offline_ready", en: "Offline CRDT Log Synced", tr: "Çevrimdışı CRDT Kaydı Eşitlendi"),
            BlueprintLocalizedKey(key: "wiki.tombstone", en: "Archive Block", tr: "Bloğu Arşivle")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Tracks markdown attachment export timestamps."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores split-view sidebar width and editor font ligature settings."
            )
        ],
        customStateComputedSwift: """
        public var visibleBlocks: [CRDTDocumentBlock] {
            blocks.filter { !$0.isTombstoned }.sorted { $0.fractionalKey < $1.fractionalKey }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("CRDT Causal State · Lamport #\\(store.state.localLamportClock)", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                Spacer()
                Text("\\(store.state.visibleBlocks.count) Visible")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("Peers online: \\(store.state.collaborators.map(\\.displayName).joined(separator: " · "))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Wiki Copilot: \\(state.visibleBlocks.count) visible CRDT blocks converged at Lamport #\\(state.localLamportClock) across \\(state.collaborators.count) peers."
        """,
        customUnitTestsSwift: """
        @Test("Fractional midpoint insertion orders between 100 and 200; stale remote Lamport op is ignored")
        func crdtMidpointAndLamportConvergence() {
            var state = MultiplayerBlockWikiState()
            _ = MultiplayerBlockWikiReducer.reduce(
                state: &state,
                action: .insertMidpointBlock(afterBlockID: "blk-01", kind: "PARAGRAPH", markdown: "Midpoint")
            )
            #expect(state.visibleBlocks[1].fractionalKey == 150.0)

            let staleOp = CRDTDocumentBlock(id: "blk-01", fractionalKey: 100.0, blockKind: "HEADING_1", markdownBody: "Stale", lamportTick: 2, authorPeerID: "peer-old", isTombstoned: false)
            _ = MultiplayerBlockWikiReducer.reduce(state: &state, action: .mergeRemoteBlockOperation(incoming: staleOp))
            #expect(state.blocks.first(where: { $0.id == "blk-01" })?.markdownBody != "Stale")
        }
        """,
        securityPostureHighlights: [
            "MLS / RFC 9180 HPKE group key schedule encrypts block deltas prior to relay transmission.",
            "Commutative, idempotent Lamport + PeerID resolution prevents replay divergence.",
            "Local SQLite compaction purges aged tombstones only after vector-clock stability."
        ]
    )

    // MARK: 14. Agile Sprint Velocity & OKR Roadmap

    public static let agileSprintOKRRoadmap = EnterpriseBlueprintSpec(
        id: .agileSprintOKRRoadmap,
        vertical: .productivityCollab,
        title: "Agile Sprint & OKR Roadmap",
        subtitle: "Story-point burndown math, rolling 3-sprint velocity forecasting, and linked quarterly OKR confidence.",
        sfSymbol: "chart.bar.doc.horizontal.fill",
        complexityTier: .professional,
        supportedPlatforms: [.macOS, .iPadOS, .iOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "SprintIssueItem",
                tableName: "sprint_issue_items",
                summary: "Engineering sprint issue sized in Fibonacci story points and linked to a quarterly Key Result.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"CHK-412\"", isIndexed: true, summary: "Issue tracker key."),
                    BlueprintEntityField(name: "title", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Ship W3C Design Token Exporter\"", summary: "Actionable engineering deliverable."),
                    BlueprintEntityField(name: "storyPoints", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "5", summary: "Fibonacci complexity estimate (1, 2, 3, 5, 8, 13)."),
                    BlueprintEntityField(name: "workflowState", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"IN_PROGRESS\"", isIndexed: true, summary: "TODO, IN_PROGRESS, IN_REVIEW, DONE."),
                    BlueprintEntityField(name: "linkedKeyResultID", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"kr-01\"", isIndexed: true, summary: "Parent quarterly OKR Key Result ID.")
                ],
                computedHelpersSwift: """
                public var isCompleted: Bool {
                    workflowState == "DONE"
                }

                public var remainingBurndownPoints: Int {
                    isCompleted ? 0 : storyPoints
                }
                """
            ),
            BlueprintDomainEntity(
                name: "QuarterlyKeyResult",
                tableName: "quarterly_key_results",
                summary: "Measurable quarterly outcome automatically updated as linked engineering sprint points ship.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"kr-01\"", isIndexed: true, summary: "Key Result identifier."),
                    BlueprintEntityField(name: "objectiveTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Cut Enterprise App Scaffolding Time by 70%\"", summary: "Outcome statement."),
                    BlueprintEntityField(name: "completedPoints", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "34", summary: "Shipped story points toward KR."),
                    BlueprintEntityField(name: "targetPoints", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "55", summary: "Total scoped story points for 100% KR attainment.")
                ],
                computedHelpersSwift: """
                public var attainmentRatio: Double {
                    guard targetPoints > 0 else { return 0 }
                    return min(1.0, Double(completedPoints) / Double(targetPoints))
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "sprintIssues",
                swiftType: "[SprintIssueItem]",
                initialValueLiteral: """
                [
                    SprintIssueItem(id: "CHK-410", title: "Swift 6 Sendable Blueprint Validator", storyPoints: 8, workflowState: "DONE", linkedKeyResultID: "kr-01"),
                    SprintIssueItem(id: "CHK-412", title: "14-File SwiftPM Workspace Exporter", storyPoints: 8, workflowState: "IN_PROGRESS", linkedKeyResultID: "kr-01"),
                    SprintIssueItem(id: "CHK-415", title: "Bilingual TR/EN Strings Catalog Generator", storyPoints: 5, workflowState: "TODO", linkedKeyResultID: "kr-01")
                ]
                """,
                summary: "Committed issues in active 2-week sprint."
            ),
            BlueprintStateProperty(
                name: "keyResults",
                swiftType: "[QuarterlyKeyResult]",
                initialValueLiteral: """
                [
                    QuarterlyKeyResult(id: "kr-01", objectiveTitle: "Deliver 28 Production Industry Blueprints", completedPoints: 34, targetPoints: 55)
                ]
                """,
                summary: "Quarterly OKRs rolling up sprint execution."
            ),
            BlueprintStateProperty(
                name: "historicalSprintVelocities",
                swiftType: "[Int]",
                initialValueLiteral: "[38, 42, 40]",
                summary: "Completed story points across trailing 3 sprints."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "completeIssue(issueID: String)",
                matchPattern: ".completeIssue(let issueID)",
                buttonTitle: "Complete CHK-412 (8 pts)",
                sampleDispatchLiteral: ".completeIssue(issueID: \"CHK-412\")",
                summary: "Transitions issue to DONE, burns down sprint points, and credits linked OKR Key Result.",
                mutationBodySwift: """
                guard let idx = state.sprintIssues.firstIndex(where: { $0.id == issueID }),
                      !state.sprintIssues[idx].isCompleted else { break }
                state.sprintIssues[idx].workflowState = "DONE"
                let pts = state.sprintIssues[idx].storyPoints
                let krID = state.sprintIssues[idx].linkedKeyResultID
                if let krIdx = state.keyResults.firstIndex(where: { $0.id == krID }) {
                    state.keyResults[krIdx].completedPoints += pts
                }
                state.lastAuditMessage = "Completed \\(issueID) (-\\(pts) burndown pts)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "scopeNewSprintIssue(id: String, title: String, points: Int)",
                matchPattern: ".scopeNewSprintIssue(let id, let title, let points)",
                buttonTitle: "Add 3pt Scope Item",
                sampleDispatchLiteral: ".scopeNewSprintIssue(id: \"CHK-419\", title: \"Mermaid Topology Renderer\", points: 3)",
                summary: "Adds scoped issue and evaluates sprint capacity creep against trailing velocity.",
                mutationBodySwift: """
                let item = SprintIssueItem(id: id, title: title, storyPoints: max(1, points), workflowState: "TODO", linkedKeyResultID: "kr-01")
                state.sprintIssues.append(item)
                state.lastAuditMessage = "Scoped \\(id) (+\\(item.storyPoints) pts)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchActiveSprintBoard",
                method: .get,
                path: "/v1/roadmap/sprints/active",
                responseType: "[SprintIssueItem]",
                offlineStubSwift: "AgileOKRRoadmapState().sprintIssues",
                summary: "Loads active sprint issues and story point estimates."
            ),
            BlueprintAPIEndpoint(
                methodName: "transitionIssueState",
                method: .patch,
                path: "/v1/roadmap/issues/transition",
                requestPayloadType: "SprintIssueItem",
                responseType: "SprintIssueItem",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Updates workflow state and syncs burndown chart."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchQuarterlyOKRs",
                method: .get,
                path: "/v1/roadmap/okrs",
                responseType: "[QuarterlyKeyResult]",
                offlineStubSwift: "AgileOKRRoadmapState().keyResults",
                summary: "Retrieves quarterly Objectives and Key Results."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "burndownLeft", label: "Remaining Burndown", value: "13 pts", delta: "8 pts shipped", sfSymbol: "chart.line.downtrend.xyaxis"),
            BlueprintKPIMetric(key: "rollingVelocity", label: "3-Sprint Velocity", value: "40.0 pts", delta: "High predictability", sfSymbol: "speedometer"),
            BlueprintKPIMetric(key: "okrAttainment", label: "Q4 KR Attainment", value: "61.8%", delta: "34 / 55 pts", sfSymbol: "target"),
            BlueprintKPIMetric(key: "scopeHealth", label: "Capacity Load", value: "52.5%", delta: "Zero overcommit", sfSymbol: "checkmark.circle.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "ag-1", headline: "CHK-410 · Swift 6 Sendable Blueprint Validator", subheadline: "Linked to KR-01 · Verified by CI suite", trailingMetric: "8 pts", statusTag: "DONE"),
            BlueprintSampleRecord(id: "ag-2", headline: "CHK-412 · 14-File SwiftPM Workspace Exporter", subheadline: "Linked to KR-01 · Active branch PR open", trailingMetric: "8 pts", statusTag: "IN PROGRESS"),
            BlueprintSampleRecord(id: "ag-3", headline: "CHK-415 · Bilingual TR/EN Strings Catalog", subheadline: "Linked to KR-01 · Scheduled next in sprint", trailingMetric: "5 pts", statusTag: "TODO")
        ],
        onboardingPages: [
            FlowPage(
                id: "cadence-setup",
                title: "Configure Sprint Cadence & Estimation Scale",
                body: "Align 2-week sprint burndown slopes with Fibonacci story point sizing.",
                style: "hero",
                actions: ["2-Week Fibonacci Cadence"]
            ),
            FlowPage(
                id: "okr-rollup",
                title: "Enable Automatic OKR Rollup",
                body: "Credit quarterly Key Result progress automatically whenever linked engineering issues ship.",
                style: "choice",
                actions: ["Auto-Credit Key Results", "Manual Weekly Check-In"]
            ),
            FlowPage(
                id: "roadmap-ready",
                title: "Sprint & OKR Roadmap Live",
                body: "Velocity forecasting, scope-creep guardrails, and OKR rollups are active.",
                style: "completion",
                actions: ["Start Sprint Planning"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "okr.title", en: "Agile Sprint & OKR Roadmap", tr: "Çevik Sprint ve OKR Yol Haritası"),
            BlueprintLocalizedKey(key: "okr.complete_issue", en: "Mark Issue Done", tr: "Görevi Tamamlandı İşaretle"),
            BlueprintLocalizedKey(key: "okr.burndown", en: "Remaining Story Points", tr: "Kalan Hikaye Puanı"),
            BlueprintLocalizedKey(key: "okr.velocity", en: "Rolling 3-Sprint Velocity", tr: "Son 3 Sprint Ortalama Hızı"),
            BlueprintLocalizedKey(key: "okr.attainment", en: "Key Result Attainment", tr: "Anahtar Sonuç Gerçekleşme Oranı"),
            BlueprintLocalizedKey(key: "okr.scope_creep", en: "Sprint Scope Guardrail", tr: "Sprint Kapsam Sınırı")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores Kanban vs Roadmap timeline layout preference."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Timestamps exported quarterly roadmap review snapshots."
            )
        ],
        customStateComputedSwift: """
        public var remainingBurndownPoints: Int {
            sprintIssues.reduce(0) { $0 + $1.remainingBurndownPoints }
        }

        public var rollingMeanVelocity: Double {
            guard !historicalSprintVelocities.isEmpty else { return 0 }
            let sum = historicalSprintVelocities.reduce(0, +)
            return Double(sum) / Double(historicalSprintVelocities.count)
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sprint Burndown & OKR Rollup", systemImage: "flag.checkered")
                    .font(.headline)
                Spacer()
                Text("\\(store.state.remainingBurndownPoints) pts left")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("Mean Velocity: \\(String(format: "%.1f", store.state.rollingMeanVelocity)) pts · KR-01: \\(Int((store.state.keyResults.first?.attainmentRatio ?? 0) * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return String(format: "Roadmap Copilot: %d pts remaining vs %.1f mean velocity; primary OKR at %.0f%% attainment.", state.remainingBurndownPoints, state.rollingMeanVelocity, (state.keyResults.first?.attainmentRatio ?? 0) * 100.0)
        """,
        customUnitTestsSwift: """
        @Test("Completing sprint issue reduces burndown points and increments linked OKR")
        func sprintBurndownAndOKRRollup() {
            var state = AgileOKRRoadmapState()
            #expect(state.remainingBurndownPoints == 13)
            _ = AgileOKRRoadmapReducer.reduce(state: &state, action: .completeIssue(issueID: "CHK-412"))
            #expect(state.remainingBurndownPoints == 5)
            #expect(state.keyResults[0].completedPoints == 42)
        }
        """,
        securityPostureHighlights: [
            "Role-based roadmap visibility isolates confidential M&A or security OKRs.",
            "Deterministic audit trail records every scope addition and story point re-estimate.",
            "Offline Kanban caching supports uninterrupted standups without VPN connectivity."
        ]
    )

    // MARK: 15. Zero-Knowledge Passkey & Secret Vault

    public static let zeroKnowledgePasskeyVault = EnterpriseBlueprintSpec(
        id: .zeroKnowledgePasskeyVault,
        vertical: .productivityCollab,
        title: "Zero-Knowledge Passkey Vault",
        subtitle: "FIDO2 WebAuthn passkey metadata, monotonic sign-counter clone detection, and Argon2id/AES-GCM vaulting.",
        sfSymbol: "key.radiowaves.forward.fill",
        complexityTier: .missionCritical,
        supportedPlatforms: [.macOS, .iOS, .iPadOS, .visionOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "PasskeyCredentialMetadata",
                tableName: "passkey_credential_metadata",
                summary: "FIDO2 / WebAuthn discoverable credential bound to a relying party domain with monotonic signature counter.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"pk-github\"", isIndexed: true, summary: "Credential record ID."),
                    BlueprintEntityField(name: "relyingPartyID", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"github.com\"", isIndexed: true, summary: "Verified WebAuthn RP ID domain."),
                    BlueprintEntityField(name: "accountHandle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"eng-lead@hnmlabs.dev\"", summary: "User handle display name."),
                    BlueprintEntityField(name: "publicKeyAlgorithm", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"ES256 (P-256)\"", summary: "COSE algorithm identifier (ES256 or EdDSA)."),
                    BlueprintEntityField(name: "signatureCounter", swiftType: "UInt32", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "41", summary: "Monotonic authenticator assertion counter."),
                    BlueprintEntityField(name: "cloneAnomalyFlagged", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", isIndexed: true, summary: "Set true if incoming signCount <= stored counter."),
                    BlueprintEntityField(name: "ageDays", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "64", summary: "Days since key pair generation.")
                ],
                computedHelpersSwift: """
                public var requiresSecurityReview: Bool {
                    cloneAnomalyFlagged || ageDays > 365
                }
                """
            ),
            BlueprintDomainEntity(
                name: "SealedEnvironmentSecret",
                tableName: "sealed_environment_secrets",
                summary: "Zero-knowledge AES-256-GCM sealed API token or SSH key never materialized in plaintext logs.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"sec-prod-db\"", isIndexed: true, summary: "Vault item ID."),
                    BlueprintEntityField(name: "label", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"PROD_POSTGRES_MTLS_CERT\"", summary: "Secret identifier."),
                    BlueprintEntityField(name: "ciphertextTagHex", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"9f86d081884c7d659a2feaa0c55ad015\"", summary: "128-bit GCM authentication tag hex."),
                    BlueprintEntityField(name: "rotationIntervalDays", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "90", summary: "Policy rotation cadence."),
                    BlueprintEntityField(name: "daysSinceRotation", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "18", summary: "Elapsed days since last rotation.")
                ],
                computedHelpersSwift: """
                public var isRotationOverdue: Bool {
                    daysSinceRotation >= rotationIntervalDays
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "passkeys",
                swiftType: "[PasskeyCredentialMetadata]",
                initialValueLiteral: """
                [
                    PasskeyCredentialMetadata(id: "pk-github", relyingPartyID: "github.com", accountHandle: "eng-lead@hnmlabs.dev", publicKeyAlgorithm: "ES256 (P-256)", signatureCounter: 41, cloneAnomalyFlagged: false, ageDays: 64),
                    PasskeyCredentialMetadata(id: "pk-aws", relyingPartyID: "signin.aws.amazon.com", accountHandle: "root-treasury@hnmlabs.dev", publicKeyAlgorithm: "EdDSA (Ed25519)", signatureCounter: 19, cloneAnomalyFlagged: false, ageDays: 112)
                ]
                """,
                summary: "Discoverable FIDO2 passkeys stored in Secure Enclave / vault."
            ),
            BlueprintStateProperty(
                name: "secrets",
                swiftType: "[SealedEnvironmentSecret]",
                initialValueLiteral: """
                [
                    SealedEnvironmentSecret(id: "sec-prod-db", label: "PROD_POSTGRES_MTLS_CERT", ciphertextTagHex: "9f86d081884c7d659a2feaa0c55ad015", rotationIntervalDays: 90, daysSinceRotation: 94)
                ]
                """,
                summary: "Zero-knowledge AEAD-sealed developer secrets."
            ),
            BlueprintStateProperty(
                name: "isVaultUnlocked",
                swiftType: "Bool",
                initialValueLiteral: "true",
                summary: "True while Secure Enclave biometric session key is active."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "verifyPasskeyAssertion(passkeyID: String, observedCounter: UInt32)",
                matchPattern: ".verifyPasskeyAssertion(let passkeyID, let observedCounter)",
                buttonTitle: "Assert GitHub Passkey",
                sampleDispatchLiteral: ".verifyPasskeyAssertion(passkeyID: \"pk-github\", observedCounter: 42)",
                summary: "Validates strictly increasing WebAuthn signature counter or flags authenticator clone anomaly.",
                mutationBodySwift: """
                guard let idx = state.passkeys.firstIndex(where: { $0.id == passkeyID }) else { break }
                if observedCounter > state.passkeys[idx].signatureCounter {
                    state.passkeys[idx].signatureCounter = observedCounter
                    state.lastAuditMessage = "Verified WebAuthn assertion for \\(state.passkeys[idx].relyingPartyID) (#\\(observedCounter))"
                } else {
                    state.passkeys[idx].cloneAnomalyFlagged = true
                    state.lastAuditMessage = "SECURITY ALERT: Non-monotonic signCount on \\(state.passkeys[idx].relyingPartyID)"
                }
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "rotateSealedSecret(secretID: String, newTagHex: String)",
                matchPattern: ".rotateSealedSecret(let secretID, let newTagHex)",
                buttonTitle: "Rotate Overdue Secret",
                sampleDispatchLiteral: ".rotateSealedSecret(secretID: \"sec-prod-db\", newTagHex: \"4b227777d4dd1fc61c6f884f48641d02\")",
                summary: "Re-seals secret with fresh 96-bit nonce and resets rotation age to zero.",
                mutationBodySwift: """
                guard let idx = state.secrets.firstIndex(where: { $0.id == secretID }) else { break }
                state.secrets[idx].ciphertextTagHex = newTagHex
                state.secrets[idx].daysSinceRotation = 0
                state.lastAuditMessage = "Rotated sealed secret \\(state.secrets[idx].label)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "lockVaultImmediately",
                matchPattern: ".lockVaultImmediately",
                summary: "Zeroizes ephemeral session state and locks vault.",
                mutationBodySwift: """
                state.isVaultUnlocked = false
                state.lastAuditMessage = "Zeroized session key and locked vault"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchEncryptedVaultManifest",
                method: .get,
                path: "/v1/vault/passkeys",
                responseType: "[PasskeyCredentialMetadata]",
                offlineStubSwift: "ZeroKnowledgeVaultState().passkeys",
                summary: "Downloads opaque encrypted passkey envelopes (zero server knowledge)."
            ),
            BlueprintAPIEndpoint(
                methodName: "putRotatedSecretEnvelope",
                method: .put,
                path: "/v1/vault/secrets",
                requestPayloadType: "SealedEnvironmentSecret",
                responseType: "SealedEnvironmentSecret",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Uploads client-side AES-256-GCM sealed secret ciphertext."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchSealedSecrets",
                method: .get,
                path: "/v1/vault/secrets",
                responseType: "[SealedEnvironmentSecret]",
                offlineStubSwift: "ZeroKnowledgeVaultState().secrets",
                summary: "Lists AEAD-authenticated secret headers."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "passkeyCount", label: "Phishing-Proof Keys", value: "2 Passkeys", delta: "ES256 + Ed25519", sfSymbol: "person.badge.key.fill"),
            BlueprintKPIMetric(key: "cloneAlerts", label: "SignCount Anomalies", value: "0 Clones", delta: "Monotonic OK", sfSymbol: "checkmark.shield.fill"),
            BlueprintKPIMetric(key: "overdueSecrets", label: "Rotation Watch", value: "1 Overdue", delta: "94 / 90d policy", sfSymbol: "arrow.triangle.2.circlepath", isFavorable: false),
            BlueprintKPIMetric(key: "kdfSuite", label: "Key Derivation", value: "Argon2id", delta: "64 MiB + Enclave", sfSymbol: "cpu")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "pk-1", headline: "github.com · eng-lead@hnmlabs.dev", subheadline: "ES256 (P-256) · SignCount #41 · Phishing-resistant RP bind", trailingMetric: "64d old", statusTag: "VERIFIED"),
            BlueprintSampleRecord(id: "pk-2", headline: "signin.aws.amazon.com · root-treasury", subheadline: "EdDSA (Ed25519) · SignCount #19 · Hardware Enclave", trailingMetric: "112d old", statusTag: "VERIFIED"),
            BlueprintSampleRecord(id: "sec-1", headline: "PROD_POSTGRES_MTLS_CERT", subheadline: "AES-256-GCM Tag 9f86...d015 · 94d since rotation", trailingMetric: "+4d Overdue", statusTag: "ROTATE NOW")
        ],
        onboardingPages: [
            FlowPage(
                id: "master-secret-kit",
                title: "Generate 128-Bit Emergency Recovery Kit",
                body: "Your vault key is derived exclusively on device; servers only ever see authenticated ciphertext.",
                style: "hero",
                actions: ["Generate Secret Kit"]
            ),
            FlowPage(
                id: "autofill-provider",
                title: "Enable ASCredentialProvider Passkey Autofill",
                body: "Bind WebAuthn relying-party domain checks across macOS and iOS.",
                style: "choice",
                actions: ["Biometric Every Use", "15-Minute Session Unlock"]
            ),
            FlowPage(
                id: "vault-ready",
                title: "Zero-Knowledge Vault Armed",
                body: "Passkey clone anomaly detection and secret rotation policies are active.",
                style: "completion",
                actions: ["Launch Passkey Vault"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "vault.title", en: "Zero-Knowledge Passkey Vault", tr: "Sıfır Bilgili Passkey ve Sır Kasası"),
            BlueprintLocalizedKey(key: "vault.assert", en: "Authenticate with Passkey", tr: "Passkey ile Kimlik Doğrula"),
            BlueprintLocalizedKey(key: "vault.rotate", en: "Rotate Sealed Secret", tr: "Şifreli Sırrı Yenile"),
            BlueprintLocalizedKey(key: "vault.clone_alert", en: "Cloned Authenticator Anomaly", tr: "Kopyalanmış Anahtar Anomalisi"),
            BlueprintLocalizedKey(key: "vault.lock_now", en: "Lock Vault Immediately", tr: "Kasayı Hemen Kilitle"),
            BlueprintLocalizedKey(key: "vault.zero_knowledge", en: "Client-Side AES-256-GCM", tr: "İstemci Taraflı AES-256-GCM")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Enforces monotonic auto-lock idle timeout independent of system clock changes."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores auto-lock timeout interval preference."
            )
        ],
        customStateComputedSwift: """
        public var anomalyCount: Int {
            passkeys.filter(\\.cloneAnomalyFlagged).count
        }

        public var overdueRotationCount: Int {
            secrets.filter(\\.isRotationOverdue).count
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("WebAuthn Clone Watch & Secret Hygiene", systemImage: "lock.laptopcomputer")
                    .font(.headline)
                Spacer()
                Text(store.state.isVaultUnlocked ? "UNLOCKED" : "LOCKED")
                    .font(.caption.monospaced().bold())
            }
            Text("Clone Anomalies: \\(store.state.anomalyCount) · Overdue Secrets: \\(store.state.overdueRotationCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Vault Security Copilot: \\(state.anomalyCount) signCount clone anomalies, \\(state.overdueRotationCount) secret(s) overdue for 90-day rotation."
        """,
        customUnitTestsSwift: """
        @Test("Non-monotonic WebAuthn signature counter flags clone anomaly; secret rotation clears overdue")
        func webAuthnCloneDetectionAndRotation() {
            var state = ZeroKnowledgeVaultState()
            _ = ZeroKnowledgeVaultReducer.reduce(
                state: &state,
                action: .verifyPasskeyAssertion(passkeyID: "pk-github", observedCounter: 41)
            )
            #expect(state.passkeys[0].cloneAnomalyFlagged == true)

            _ = ZeroKnowledgeVaultReducer.reduce(
                state: &state,
                action: .rotateSealedSecret(secretID: "sec-prod-db", newTagHex: "abcdef0123456789abcdef0123456789")
            )
            #expect(state.overdueRotationCount == 0)
        }
        """,
        securityPostureHighlights: [
            "WebAuthn RP ID origin binding eliminates credential stuffing and Adversary-in-the-Middle phishing.",
            "Monotonic signCount invariant flags suspected hardware token cloning immediately.",
            "Monotonic boot-clock auto-lock defeats wall-clock rollback attacks."
        ]
    )
}
