import ChiefKitStudioCore
import Foundation

// MARK: - Vertical 2: AI & Developer Engineering Tools Blueprints

public enum AIAndDeveloperToolsBlueprints: Sendable {
    public static let specs: [EnterpriseBlueprintSpec] = [
        localRAGKnowledgeWorkbench,
        cicdFleetIncidentCommander,
        gitDiffPullRequestStudio
    ]

    // MARK: 4. Local RAG Knowledge Workbench

    public static let localRAGKnowledgeWorkbench = EnterpriseBlueprintSpec(
        id: .localRAGKnowledgeWorkbench,
        vertical: .aiDeveloperTools,
        title: "Local RAG Knowledge Workbench",
        subtitle: "Zero-egress vector chunk indexing, cosine + BM25 Reciprocal Rank Fusion, and streaming token telemetry.",
        sfSymbol: "brain.head.profile.fill",
        complexityTier: .enterprise,
        supportedPlatforms: [.macOS, .iPadOS, .iOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "VectorDocumentChunk",
                tableName: "vector_document_chunks",
                summary: "Semantically segmented markdown/code chunk with normalized float embedding and BM25 lexical rank.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"chk-001\"", isIndexed: true, summary: "Deterministic SHA-derived chunk identifier."),
                    BlueprintEntityField(name: "documentTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Swift 6 Concurrency Architecture.md\"", isIndexed: true, summary: "Source document filename or URI."),
                    BlueprintEntityField(name: "tokenCount", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "384", summary: "BPE subword token count for context budgeting."),
                    BlueprintEntityField(name: "embeddingPreview", swiftType: "[Double]", sqlType: "TEXT NOT NULL", defaultValueLiteral: "[0.62, 0.48, 0.51, 0.35]", summary: "4D L2-projected preview slice of dense embedding."),
                    BlueprintEntityField(name: "cosineScore", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.89", summary: "Latest dense vector cosine similarity in [-1, 1]."),
                    BlueprintEntityField(name: "bm25Rank", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "2", summary: "1-indexed BM25 lexical rank for hybrid RRF."),
                    BlueprintEntityField(name: "vectorRank", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1", summary: "1-indexed dense ANN rank for hybrid RRF.")
                ],
                computedHelpersSwift: """
                public func cosineSimilarity(against queryVector: [Double]) -> Double {
                    let n = min(embeddingPreview.count, queryVector.count)
                    guard n > 0 else { return 0.0 }
                    var dot = 0.0
                    var normA = 0.0
                    var normB = 0.0
                    for i in 0..<n {
                        dot += embeddingPreview[i] * queryVector[i]
                        normA += embeddingPreview[i] * embeddingPreview[i]
                        normB += queryVector[i] * queryVector[i]
                    }
                    let denom = (normA.squareRoot() * normB.squareRoot())
                    guard denom > 0 else { return 0.0 }
                    return dot / denom
                }

                /// Reciprocal Rank Fusion (k = 60) combining dense ANN rank and sparse BM25 rank.
                public var reciprocalRankFusionScore: Double {
                    let k = 60.0
                    let vTerm = 1.0 / (k + Double(max(1, vectorRank)))
                    let lTerm = 1.0 / (k + Double(max(1, bm25Rank)))
                    return vTerm + lTerm
                }
                """
            ),
            BlueprintDomainEntity(
                name: "StreamingInferenceSession",
                tableName: "streaming_inference_sessions",
                summary: "Local Apple Silicon MLX / CoreML / FoundationModels generation session with KV-cache telemetry.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"inf-900\"", isIndexed: true, summary: "Inference session identifier."),
                    BlueprintEntityField(name: "modelIdentifier", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"ChiefLM-8B-4bit-MLX\"", summary: "Quantized local model identifier."),
                    BlueprintEntityField(name: "promptTokens", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1420", summary: "Prompt + retrieved RAG context tokens."),
                    BlueprintEntityField(name: "generatedTokens", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "196", summary: "Streamed completion tokens emitted."),
                    BlueprintEntityField(name: "timeToFirstTokenMs", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "142.0", summary: "Prefill TTFT latency in milliseconds."),
                    BlueprintEntityField(name: "totalDecodeMs", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "2680.0", summary: "Cumulative token decode duration in milliseconds."),
                    BlueprintEntityField(name: "streamedResponse", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Actor isolation guarantees data-race freedom across async boundaries.\"", summary: "Accumulated assistant completion text.")
                ],
                computedHelpersSwift: """
                public var decodeTokensPerSecond: Double {
                    guard totalDecodeMs > 0 else { return 0.0 }
                    return Double(generatedTokens) / (totalDecodeMs / 1000.0)
                }

                public var contextWindowUtilization: Double {
                    Double(promptTokens + generatedTokens) / 32_768.0
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "indexedChunks",
                swiftType: "[VectorDocumentChunk]",
                initialValueLiteral: """
                [
                    VectorDocumentChunk(id: "chk-001", documentTitle: "Swift6ConcurrencyGuide.md", tokenCount: 412, embeddingPreview: [0.74, 0.52, 0.38, 0.19], cosineScore: 0.94, bm25Rank: 1, vectorRank: 1),
                    VectorDocumentChunk(id: "chk-002", documentTitle: "SQLiteHNSWVectorIndex.md", tokenCount: 356, embeddingPreview: [0.58, 0.66, 0.41, 0.24], cosineScore: 0.88, bm25Rank: 3, vectorRank: 2),
                    VectorDocumentChunk(id: "chk-003", documentTitle: "LiquidGlassTokenSpec.md", tokenCount: 290, embeddingPreview: [0.22, 0.31, 0.81, 0.44], cosineScore: 0.71, bm25Rank: 5, vectorRank: 3)
                ]
                """,
                summary: "In-memory + SQLite HNSW indexed document chunks."
            ),
            BlueprintStateProperty(
                name: "activeSession",
                swiftType: "StreamingInferenceSession",
                initialValueLiteral: "StreamingInferenceSession()",
                summary: "Live local LLM streaming session with token speed metrics."
            ),
            BlueprintStateProperty(
                name: "topKContextLimit",
                swiftType: "Int",
                initialValueLiteral: "5",
                summary: "Maximum hybrid RRF chunks injected into prompt context."
            ),
            BlueprintStateProperty(
                name: "similarityFloor",
                swiftType: "Double",
                initialValueLiteral: "0.65",
                summary: "Minimum cosine similarity threshold to prevent hallucinated retrieval."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "indexDocumentChunk(title: String, tokenCount: Int, embedding: [Double])",
                matchPattern: ".indexDocumentChunk(let title, let tokenCount, let embedding)",
                buttonTitle: "Index Markdown Chunk",
                sampleDispatchLiteral: ".indexDocumentChunk(title: \"ZeroCopySerialization.md\", tokenCount: 340, embedding: [0.71, 0.49, 0.42, 0.25])",
                summary: "Embeds and inserts a new local document chunk into the hybrid retrieval index.",
                mutationBodySwift: """
                let nextRank = state.indexedChunks.count + 1
                let chunk = VectorDocumentChunk(
                    id: "chk-00\\(nextRank)",
                    documentTitle: title,
                    tokenCount: max(16, tokenCount),
                    embeddingPreview: embedding.isEmpty ? [0.5, 0.5, 0.5, 0.5] : embedding,
                    cosineScore: 0.85,
                    bm25Rank: nextRank,
                    vectorRank: nextRank
                )
                state.indexedChunks.insert(chunk, at: 0)
                state.lastAuditMessage = "Indexed \\(title) (\\(chunk.tokenCount) tokens) locally"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "appendStreamToken(fragment: String, decodeStepMs: Double)",
                matchPattern: ".appendStreamToken(let fragment, let decodeStepMs)",
                buttonTitle: "Simulate Token Stream",
                sampleDispatchLiteral: ".appendStreamToken(fragment: \" [Cite: chk-001]\", decodeStepMs: 13.5)",
                summary: "Appends a streamed token fragment and updates decode throughput telemetry.",
                mutationBodySwift: """
                state.activeSession.streamedResponse += fragment
                state.activeSession.generatedTokens += 1
                state.activeSession.totalDecodeMs += max(0.5, decodeStepMs)
                state.lastAuditMessage = String(format: "Streaming @ %.1f tok/s", state.activeSession.decodeTokensPerSecond)
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "rerankChunksAgainstQuery(queryEmbedding: [Double])",
                matchPattern: ".rerankChunksAgainstQuery(let queryEmbedding)",
                buttonTitle: "Re-Rank Hybrid RRF",
                sampleDispatchLiteral: ".rerankChunksAgainstQuery(queryEmbedding: [0.76, 0.50, 0.35, 0.20])",
                summary: "Recomputes dense cosine scores, updates vector ranks, and sorts chunks by RRF score.",
                mutationBodySwift: """
                for idx in state.indexedChunks.indices {
                    let sim = state.indexedChunks[idx].cosineSimilarity(against: queryEmbedding)
                    state.indexedChunks[idx].cosineScore = sim
                }
                let byCosine = state.indexedChunks.enumerated().sorted { $0.element.cosineScore > $1.element.cosineScore }
                for (rankIdx, pair) in byCosine.enumerated() {
                    state.indexedChunks[pair.offset].vectorRank = rankIdx + 1
                }
                state.indexedChunks.sort { $0.reciprocalRankFusionScore > $1.reciprocalRankFusionScore }
                state.lastAuditMessage = "Hybrid RRF reranked \\(state.indexedChunks.count) chunks"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "pruneBelowSimilarityFloor(floor: Double)",
                matchPattern: ".pruneBelowSimilarityFloor(let floor)",
                summary: "Evicts low-confidence chunks below the cosine similarity floor.",
                mutationBodySwift: """
                state.similarityFloor = min(max(floor, 0.10), 0.98)
                state.indexedChunks.removeAll { $0.cosineScore < state.similarityFloor }
                state.lastAuditMessage = "Pruned index with similarity floor \\(String(format: "%.2f", state.similarityFloor))"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchLocalModelManifest",
                method: .get,
                path: "/v1/local-ai/models/active",
                responseType: "StreamingInferenceSession",
                offlineStubSwift: "LocalRAGWorkbenchState().activeSession",
                summary: "Queries loopback MLX/Ollama daemon for loaded model & KV-cache telemetry."
            ),
            BlueprintAPIEndpoint(
                methodName: "queryHybridChunks",
                method: .post,
                path: "/v1/local-ai/rag/search",
                requestPayloadType: "[Double]",
                responseType: "[VectorDocumentChunk]",
                offlineStubSwift: "LocalRAGWorkbenchState().indexedChunks",
                summary: "Executes hybrid HNSW + FTS5 BM25 retrieval over local knowledge store."
            ),
            BlueprintAPIEndpoint(
                methodName: "upsertDocumentChunk",
                method: .put,
                path: "/v1/local-ai/rag/chunks",
                requestPayloadType: "VectorDocumentChunk",
                responseType: "VectorDocumentChunk",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Upserts a chunk vector into local-network team knowledge cache."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "decodeSpeed", label: "Apple Silicon Decode", value: "73.1 tok/s", delta: "TTFT 142ms", sfSymbol: "bolt.horizontal.circle.fill"),
            BlueprintKPIMetric(key: "indexedChunks", label: "Hybrid HNSW + BM25", value: "3 Chunks", delta: "1,058 tokens", sfSymbol: "doc.text.magnifyingglass"),
            BlueprintKPIMetric(key: "topCosine", label: "Top-1 Cosine Match", value: "0.94", delta: "RRF 0.0328", sfSymbol: "sparkle.magnifyingglass"),
            BlueprintKPIMetric(key: "cloudEgress", label: "External API Egress", value: "0 Bytes", delta: "100% Air-Gapped", sfSymbol: "lock.laptopcomputer")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "rag-1", headline: "Swift6ConcurrencyGuide.md · #chk-001", subheadline: "412 tokens · Vector #1 + BM25 #1 · Cited in active answer", trailingMetric: "cos 0.94", statusTag: "TOP RRF"),
            BlueprintSampleRecord(id: "rag-2", headline: "SQLiteHNSWVectorIndex.md · #chk-002", subheadline: "356 tokens · Vector #2 + BM25 #3 · WAL mmap enabled", trailingMetric: "cos 0.88", statusTag: "RETRIEVED"),
            BlueprintSampleRecord(id: "rag-3", headline: "LiquidGlassTokenSpec.md · #chk-003", subheadline: "290 tokens · Vector #3 + BM25 #5 · Design system context", trailingMetric: "cos 0.71", statusTag: "CONTEXT")
        ],
        onboardingPages: [
            FlowPage(
                id: "select-runtime",
                title: "Select On-Device Embedding & LLM Runtime",
                body: "Run 4-bit quantized Apple Silicon MLX or Apple FoundationModels with zero network egress.",
                style: "hero",
                actions: ["Enable Local Runtime"]
            ),
            FlowPage(
                id: "chunking-strategy",
                title: "Configure Semantic Chunking & RRF",
                body: "Balance dense cosine retrieval with SQLite FTS5 BM25 keyword precision.",
                style: "choice",
                actions: ["384-Token AST Aware", "512-Token Markdown"]
            ),
            FlowPage(
                id: "rag-complete",
                title: "Air-Gapped RAG Workbench Ready",
                body: "Local embeddings, RRF ranking, and citation-backed streaming are initialized.",
                style: "completion",
                actions: ["Launch RAG Workbench"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "rag.title", en: "Local RAG Knowledge Workbench", tr: "Yerel RAG Bilgi Çalışma Alanı"),
            BlueprintLocalizedKey(key: "rag.index.action", en: "Index Document Chunk", tr: "Belge Parçasını İndeksle"),
            BlueprintLocalizedKey(key: "rag.rerank", en: "Re-Rank Hybrid RRF", tr: "Hibrit RRF Sıralamasını Yenile"),
            BlueprintLocalizedKey(key: "rag.tokens_per_sec", en: "Decode Throughput (tok/s)", tr: "Üretim Hızı (token/sn)"),
            BlueprintLocalizedKey(key: "rag.zero_egress", en: "Zero Cloud Egress Verified", tr: "Sıfır Bulut Veri Çıkışı Doğrulandı"),
            BlueprintLocalizedKey(key: "rag.citation", en: "Grounded Source Citation", tr: "Kaynak Doğrulamalı Atıf")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryDiskSpace",
                reasonCodes: ["E174.1"],
                purposeSummary: "Verifies sufficient free SSD space before caching quantized GGUF/MLX weights."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Detects modified workspace markdown files for incremental re-embedding."
            )
        ],
        customStateComputedSwift: """
        public var averageChunkCosine: Double {
            guard !indexedChunks.isEmpty else { return 0.0 }
            let total = indexedChunks.reduce(0.0) { $0 + $1.cosineScore }
            return total / Double(indexedChunks.count)
        }

        public var totalIndexedTokens: Int {
            indexedChunks.reduce(0) { $0 + $1.tokenCount }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Streaming MLX Session · \\(store.state.activeSession.modelIdentifier)", systemImage: "cpu.fill")
                    .font(.headline)
                Spacer()
                Text("\\(String(format: "%.1f", store.state.activeSession.decodeTokensPerSecond)) tok/s")
                    .font(.caption.monospacedDigit().bold())
            }
            Text(store.state.activeSession.streamedResponse)
                .font(.caption)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return String(
            format: "RAG Telemetry: %d chunks (%d tokens), mean cosine %.2f, decode %.1f tok/s.",
            state.indexedChunks.count,
            state.totalIndexedTokens,
            state.averageChunkCosine,
            state.activeSession.decodeTokensPerSecond
        )
        """,
        customUnitTestsSwift: """
        @Test("Cosine similarity, Reciprocal Rank Fusion, and token stream throughput")
        func hybridRRFAndStreamingMetrics() {
            var state = LocalRAGWorkbenchState()
            let identicalSim = state.indexedChunks[0].cosineSimilarity(against: [0.74, 0.52, 0.38, 0.19])
            #expect(identicalSim > 0.999)
            #expect(state.indexedChunks[0].reciprocalRankFusionScore > state.indexedChunks[2].reciprocalRankFusionScore)

            let initialTokens = state.activeSession.generatedTokens
            _ = LocalRAGWorkbenchReducer.reduce(
                state: &state,
                action: .appendStreamToken(fragment: " Verified.", decodeStepMs: 12.0)
            )
            #expect(state.activeSession.generatedTokens == initialTokens + 1)
            #expect(state.activeSession.decodeTokensPerSecond > 0)
        }
        """,
        securityPostureHighlights: [
            "Strict loopback-only inference policy guarantees proprietary source code never leaves the device.",
            "Deterministic chunk SHA IDs prevent prompt-injection poisoning across incremental re-indexes.",
            "SSD disk-space preflight prevents partial weight corruption on Apple Silicon laptops."
        ]
    )

    // MARK: 5. CI/CD Fleet & Incident Commander

    public static let cicdFleetIncidentCommander = EnterpriseBlueprintSpec(
        id: .cicdFleetIncidentCommander,
        vertical: .aiDeveloperTools,
        title: "CI/CD Fleet & Incident Commander",
        subtitle: "Pipeline DAG critical-path status, Apple Silicon build runner telemetry, and SRE error-budget burn triage.",
        sfSymbol: "server.rack",
        complexityTier: .missionCritical,
        supportedPlatforms: [.macOS, .iOS, .iPadOS, .watchOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "PipelineDAGStage",
                tableName: "pipeline_dag_stages",
                summary: "Directed acyclic build/test/deploy stage with upstream dependencies, p95 duration, and flake rate.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"stg-build\"", isIndexed: true, summary: "Unique DAG stage node ID."),
                    BlueprintEntityField(name: "stageName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"macOS-arm64-release\"", summary: "Human-readable workflow stage name."),
                    BlueprintEntityField(name: "upstreamStageIDs", swiftType: "[String]", sqlType: "TEXT NOT NULL", defaultValueLiteral: "[]", summary: "Parent stage IDs required before execution."),
                    BlueprintEntityField(name: "status", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"SUCCEEDED\"", isIndexed: true, summary: "QUEUED, RUNNING, SUCCEEDED, FAILED, RETRYING."),
                    BlueprintEntityField(name: "durationSeconds", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "185", summary: "Measured execution wall time in seconds."),
                    BlueprintEntityField(name: "flakeRatePercent", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.4", summary: "Rolling 14-day non-deterministic failure percentage.")
                ],
                computedHelpersSwift: """
                public var isHealthy: Bool {
                    status == "SUCCEEDED" && flakeRatePercent < 2.0
                }

                public var formattedDuration: String {
                    let mins = durationSeconds / 60
                    let secs = durationSeconds % 60
                    return String(format: "%dm %02ds", mins, secs)
                }
                """
            ),
            BlueprintDomainEntity(
                name: "BuildRunnerHost",
                tableName: "build_runner_hosts",
                summary: "Dedicated bare-metal Mac Studio CI host running ephemeral VM Tart/Virtualization.framework sandboxes.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"mac-m3u-01\"", isIndexed: true, summary: "Fleet host identifier."),
                    BlueprintEntityField(name: "chipModel", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"M3 Ultra · 192GB\"", summary: "Apple Silicon hardware profile."),
                    BlueprintEntityField(name: "activeVMSlots", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "2", summary: "Currently executing ephemeral VM sandboxes."),
                    BlueprintEntityField(name: "maxVMSlots", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "2", summary: "Apple Virtualization.framework concurrent macOS VM limit."),
                    BlueprintEntityField(name: "nvmeFreeGB", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "640.0", summary: "Available NVMe scratch storage in GB."),
                    BlueprintEntityField(name: "isCordoned", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "True when drained for Xcode image rotation.")
                ],
                computedHelpersSwift: """
                public var slotUtilization: Double {
                    guard maxVMSlots > 0 else { return 0 }
                    return Double(activeVMSlots) / Double(maxVMSlots)
                }

                public var canAcceptJob: Bool {
                    !isCordoned && activeVMSlots < maxVMSlots && nvmeFreeGB >= 50.0
                }
                """
            ),
            BlueprintDomainEntity(
                name: "SREIncidentRecord",
                tableName: "sre_incident_records",
                summary: "Production SEV1-SEV3 incident tracking SLO error-budget burn rate and mitigation timeline.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"inc-408\"", isIndexed: true, summary: "Incident key."),
                    BlueprintEntityField(name: "title", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"EU-Central Edge TLS Handshake Spike\"", summary: "Incident summary."),
                    BlueprintEntityField(name: "severity", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"SEV2\"", isIndexed: true, summary: "SEV1, SEV2, SEV3."),
                    BlueprintEntityField(name: "burnRateMultiple", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "6.4", summary: "Multi-window SLO error-budget burn rate (1.0 = nominal)."),
                    BlueprintEntityField(name: "elapsedMinutes", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "18", summary: "Minutes elapsed since alert page."),
                    BlueprintEntityField(name: "isMitigated", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "True once rollback or traffic shift restores SLO.")
                ],
                computedHelpersSwift: """
                public var requiresImmediatePage: Bool {
                    !isMitigated && (severity == "SEV1" || burnRateMultiple >= 14.4)
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "dagStages",
                swiftType: "[PipelineDAGStage]",
                initialValueLiteral: """
                [
                    PipelineDAGStage(id: "stg-lint", stageName: "SwiftSyntax Strict Audit", upstreamStageIDs: [], status: "SUCCEEDED", durationSeconds: 42, flakeRatePercent: 0.0),
                    PipelineDAGStage(id: "stg-test", stageName: "Swift Testing Matrix (macOS + Linux)", upstreamStageIDs: ["stg-lint"], status: "FAILED", durationSeconds: 214, flakeRatePercent: 1.2),
                    PipelineDAGStage(id: "stg-notarize", stageName: "Apple Notarization & Staple", upstreamStageIDs: ["stg-test"], status: "QUEUED", durationSeconds: 95, flakeRatePercent: 0.3)
                ]
                """,
                summary: "Release pipeline DAG stages."
            ),
            BlueprintStateProperty(
                name: "runners",
                swiftType: "[BuildRunnerHost]",
                initialValueLiteral: """
                [
                    BuildRunnerHost(id: "mac-m3u-01", chipModel: "M3 Ultra · 192GB", activeVMSlots: 2, maxVMSlots: 2, nvmeFreeGB: 712, isCordoned: false),
                    BuildRunnerHost(id: "mac-m3u-02", chipModel: "M3 Ultra · 192GB", activeVMSlots: 1, maxVMSlots: 2, nvmeFreeGB: 845, isCordoned: false)
                ]
                """,
                summary: "Bare-metal Apple Silicon CI runner pool."
            ),
            BlueprintStateProperty(
                name: "incidents",
                swiftType: "[SREIncidentRecord]",
                initialValueLiteral: """
                [
                    SREIncidentRecord(id: "inc-408", title: "Artifact Cache CDN p99 Latency Regression", severity: "SEV2", burnRateMultiple: 6.4, elapsedMinutes: 18, isMitigated: false)
                ]
                """,
                summary: "Open and mitigated SRE incident records."
            ),
            BlueprintStateProperty(
                name: "monthlyErrorBudgetMinutes",
                swiftType: "Double",
                initialValueLiteral: "43.2",
                summary: "Monthly 99.9% availability error budget in minutes."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "retryFailedDAGStage(stageID: String)",
                matchPattern: ".retryFailedDAGStage(let stageID)",
                buttonTitle: "Retry Failed DAG Stage",
                sampleDispatchLiteral: ".retryFailedDAGStage(stageID: \"stg-test\")",
                summary: "Re-queues and marks a failed pipeline stage green on clean ephemeral VM runner.",
                mutationBodySwift: """
                guard let idx = state.dagStages.firstIndex(where: { $0.id == stageID }) else { break }
                state.dagStages[idx].status = "SUCCEEDED"
                state.lastAuditMessage = "Re-ran \\(state.dagStages[idx].stageName) on clean VM -> SUCCEEDED"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "mitigateIncident(incidentID: String)",
                matchPattern: ".mitigateIncident(let incidentID)",
                buttonTitle: "Mitigate Active Incident",
                sampleDispatchLiteral: ".mitigateIncident(incidentID: \"inc-408\")",
                summary: "Marks incident mitigated and resets real-time SLO burn rate to 0.8x nominal.",
                mutationBodySwift: """
                guard let idx = state.incidents.firstIndex(where: { $0.id == incidentID }) else { break }
                state.incidents[idx].isMitigated = true
                state.incidents[idx].burnRateMultiple = 0.8
                state.lastAuditMessage = "Mitigated incident \\(incidentID) via traffic drain"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "setRunnerCordon(runnerID: String, cordoned: Bool)",
                matchPattern: ".setRunnerCordon(let runnerID, let cordoned)",
                buttonTitle: "Cordon Runner #1",
                sampleDispatchLiteral: ".setRunnerCordon(runnerID: \"mac-m3u-01\", cordoned: true)",
                summary: "Cordons or uncordons a Mac build host for Xcode image maintenance.",
                mutationBodySwift: """
                guard let idx = state.runners.firstIndex(where: { $0.id == runnerID }) else { break }
                state.runners[idx].isCordoned = cordoned
                if cordoned {
                    state.runners[idx].activeVMSlots = 0
                }
                state.lastAuditMessage = cordoned ? "Cordoned runner \\(runnerID)" : "Uncordoned runner \\(runnerID)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchPipelineDAG",
                method: .get,
                path: "/v1/ci/pipelines/latest/dag",
                responseType: "[PipelineDAGStage]",
                offlineStubSwift: "CICDIncidentCommanderState().dagStages",
                summary: "Fetches current release pipeline DAG stage statuses."
            ),
            BlueprintAPIEndpoint(
                methodName: "retryStageExecution",
                method: .post,
                path: "/v1/ci/stages/retry",
                requestPayloadType: "PipelineDAGStage",
                responseType: "PipelineDAGStage",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Triggers isolated retry of a failed DAG node."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchActiveIncidents",
                method: .get,
                path: "/v1/sre/incidents",
                responseType: "[SREIncidentRecord]",
                offlineStubSwift: "CICDIncidentCommanderState().incidents",
                summary: "Lists open PagerDuty/OpenTelemetry correlated SRE incidents."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "fleetSlots", label: "M3 Ultra VM Capacity", value: "3 / 4 Slots", delta: "75% utilized", sfSymbol: "desktopcomputer"),
            BlueprintKPIMetric(key: "mttr", label: "Rolling 30d MTTR", value: "14m 20s", delta: "-6m vs Q3", sfSymbol: "bolt.shield.fill"),
            BlueprintKPIMetric(key: "sloBudget", label: "99.9% Error Budget", value: "71% Left", delta: "30.7m remaining", sfSymbol: "gauge.with.dots.needle.33percent"),
            BlueprintKPIMetric(key: "flakeIndex", label: "Suite Flake Rate", value: "0.53%", delta: "SLSA Level 3", sfSymbol: "checkmark.diamond.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "dag-1", headline: "Swift Testing Matrix (macOS + Linux)", subheadline: "Upstream: stg-lint · 3m 34s · 1.2% rolling flake", trailingMetric: "FAILED", statusTag: "NEEDS RETRY"),
            BlueprintSampleRecord(id: "host-1", headline: "mac-m3u-01 · Apple M3 Ultra (192 GB)", subheadline: "2/2 Ephemeral Tart VMs active · 712 GB NVMe free", trailingMetric: "100% Slot", statusTag: "ONLINE"),
            BlueprintSampleRecord(id: "inc-1", headline: "INC-408 · Artifact Cache CDN p99 Spike", subheadline: "SEV2 · Burn rate 6.4x · 18m elapsed", trailingMetric: "6.4x Burn", statusTag: "MITIGATING")
        ],
        onboardingPages: [
            FlowPage(
                id: "connect-ci",
                title: "Connect GitHub Actions & Buildkite Runners",
                body: "Stream real-time DAG node transitions and bare-metal Mac VM slot utilization.",
                style: "hero",
                actions: ["Bind CI Webhooks"]
            ),
            FlowPage(
                id: "slo-policy",
                title: "Set Multi-Window SLO Burn Alerts",
                body: "Trigger high-urgency watchOS/iOS pages when 1h burn rate exceeds 14.4x.",
                style: "choice",
                actions: ["99.9% Tier-1 SLO", "99.95% Payment Core SLO"]
            ),
            FlowPage(
                id: "commander-ready",
                title: "CI/CD & Incident Command Live",
                body: "DAG retries, runner cordoning, and one-tap incident mitigation are armed.",
                style: "completion",
                actions: ["Launch Incident Commander"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "cicd.title", en: "CI/CD Fleet & Incident Commander", tr: "CI/CD Filosu ve Olay Komuta Merkezi"),
            BlueprintLocalizedKey(key: "cicd.retry_stage", en: "Retry Failed Stage", tr: "Başarısız Aşamayı Yeniden Dene"),
            BlueprintLocalizedKey(key: "cicd.cordon_host", en: "Cordon Build Host", tr: "Derleme Sunucusunu Bakıma Al"),
            BlueprintLocalizedKey(key: "cicd.mitigate", en: "Mark Incident Mitigated", tr: "Olayı Çözümlendi Olarak İşaretle"),
            BlueprintLocalizedKey(key: "cicd.burn_rate", en: "SLO Error Budget Burn Rate", tr: "SLO Hata Bütçesi Tüketim Hızı"),
            BlueprintLocalizedKey(key: "cicd.vm_slots", en: "Ephemeral macOS VM Slots", tr: "Geçici macOS Sanal Makine Yuvaları")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Tracks monotonic incident elapsed timers during SEV1/SEV2 response."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Saves on-call rotation filter preferences."
            )
        ],
        customStateComputedSwift: """
        public var availableFleetSlots: Int {
            runners.filter { !$0.isCordoned }.reduce(0) { $0 + max(0, $1.maxVMSlots - $1.activeVMSlots) }
        }

        public var criticalPathSeconds: Int {
            dagStages.reduce(0) { $0 + $1.durationSeconds }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("DAG Critical Path & Fleet Capacity", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                Spacer()
                Text("Free VM Slots: \\(store.state.availableFleetSlots)")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("Critical Path Wall Time: \\(store.state.criticalPathSeconds)s across \\(store.state.dagStages.count) stages")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let failedCount = state.dagStages.filter { $0.status == "FAILED" }.count
        let openIncidents = state.incidents.filter { !$0.isMitigated }.count
        return "Triage Copilot: \\(failedCount) failed DAG stages, \\(openIncidents) unmitigated incidents, \\(state.availableFleetSlots) idle Mac VM slots."
        """,
        customUnitTestsSwift: """
        @Test("Retrying failed DAG stage and cordoning build runner updates capacity")
        func dagRetryAndRunnerCordon() {
            var state = CICDIncidentCommanderState()
            _ = CICDIncidentCommanderReducer.reduce(state: &state, action: .retryFailedDAGStage(stageID: "stg-test"))
            #expect(state.dagStages[1].status == "SUCCEEDED")

            _ = CICDIncidentCommanderReducer.reduce(state: &state, action: .setRunnerCordon(runnerID: "mac-m3u-02", cordoned: true))
            #expect(state.runners[1].canAcceptJob == false)
            #expect(state.availableFleetSlots == 0)
        }
        """,
        securityPostureHighlights: [
            "SLSA Level 3 ephemeral Tart VM teardown wipes build credentials after every CI job.",
            "Signed webhook HMAC verification prevents spoofed pipeline retry triggers.",
            "Incident postmortem audit seals preserve immutable timeline ordering."
        ]
    )

    // MARK: 6. Git Diff & Pull Request Review Studio

    public static let gitDiffPullRequestStudio = EnterpriseBlueprintSpec(
        id: .gitDiffPullRequestStudio,
        vertical: .aiDeveloperTools,
        title: "Git Diff & Pull Request Studio",
        subtitle: "Unified AST-aware hunk triage, inline patch suggestions, merge gate checks, and reviewer quorum.",
        sfSymbol: "arrow.triangle.pull",
        complexityTier: .professional,
        supportedPlatforms: [.macOS, .iPadOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "DiffHunkBlock",
                tableName: "diff_hunk_blocks",
                summary: "Unified diff hunk with line range headers, churn counts, semantic AST risk score, and review status.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"hunk-01\"", isIndexed: true, summary: "Unique diff hunk ID."),
                    BlueprintEntityField(name: "filePath", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Sources/SyncEngine/CRDTActor.swift\"", isIndexed: true, summary: "Repository-relative file path."),
                    BlueprintEntityField(name: "headerRange", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"@@ -42,14 +42,26 @@\"", summary: "Unified diff range header."),
                    BlueprintEntityField(name: "addedLines", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "18", summary: "Inserted line count."),
                    BlueprintEntityField(name: "deletedLines", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "6", summary: "Removed line count."),
                    BlueprintEntityField(name: "touchesConcurrencyBoundary", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "true", summary: "True if hunk modifies actor/Sendable/Task signatures."),
                    BlueprintEntityField(name: "reviewDecision", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"PENDING\"", summary: "PENDING, APPROVED, CHANGES_REQUESTED.")
                ],
                computedHelpersSwift: """
                public var netLineDelta: Int {
                    addedLines - deletedLines
                }

                public var churnMagnitude: Int {
                    addedLines + deletedLines
                }

                public var semanticRiskScore: Int {
                    let base = min(60, churnMagnitude * 2)
                    return touchesConcurrencyBoundary ? min(100, base + 35) : base
                }
                """
            ),
            BlueprintDomainEntity(
                name: "InlineReviewThread",
                tableName: "inline_review_threads",
                summary: "Line-anchored pull request review thread with committable Swift code suggestion.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"thr-101\"", isIndexed: true, summary: "Review thread ID."),
                    BlueprintEntityField(name: "hunkID", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"hunk-01\"", isIndexed: true, summary: "Associated diff hunk."),
                    BlueprintEntityField(name: "reviewerHandle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"@derya-arch\"", summary: "Reviewer handle."),
                    BlueprintEntityField(name: "body", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Check Task.isCancelled before persisting snapshot.\"", summary: "Review comment markdown."),
                    BlueprintEntityField(name: "isResolved", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "True once author applies fix or resolves conversation.")
                ],
                computedHelpersSwift: """
                public var blocksMerge: Bool {
                    !isResolved
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "hunks",
                swiftType: "[DiffHunkBlock]",
                initialValueLiteral: """
                [
                    DiffHunkBlock(id: "hunk-01", filePath: "Sources/SyncEngine/CRDTActor.swift", headerRange: "@@ -42,14 +42,26 @@", addedLines: 18, deletedLines: 6, touchesConcurrencyBoundary: true, reviewDecision: "PENDING"),
                    DiffHunkBlock(id: "hunk-02", filePath: "Sources/SyncEngine/SnapshotCodec.swift", headerRange: "@@ -108,8 +108,11 @@", addedLines: 9, deletedLines: 3, touchesConcurrencyBoundary: false, reviewDecision: "APPROVED"),
                    DiffHunkBlock(id: "hunk-03", filePath: "Tests/SyncEngineTests/CRDTActorTests.swift", headerRange: "@@ -1,6 +1,34 @@", addedLines: 28, deletedLines: 0, touchesConcurrencyBoundary: false, reviewDecision: "APPROVED")
                ]
                """,
                summary: "All diff hunks in the open pull request."
            ),
            BlueprintStateProperty(
                name: "threads",
                swiftType: "[InlineReviewThread]",
                initialValueLiteral: """
                [
                    InlineReviewThread(id: "thr-101", hunkID: "hunk-01", reviewerHandle: "@derya-arch", body: "Guard against cancellation before committing SQLite WAL frame.", isResolved: false)
                ]
                """,
                summary: "Inline code review comment threads."
            ),
            BlueprintStateProperty(
                name: "ciChecksGreen",
                swiftType: "Bool",
                initialValueLiteral: "true",
                summary: "True when required Swift 6 build + test checks pass."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "approveHunk(hunkID: String)",
                matchPattern: ".approveHunk(let hunkID)",
                buttonTitle: "Approve Top Hunk",
                sampleDispatchLiteral: ".approveHunk(hunkID: \"hunk-01\")",
                summary: "Marks a diff hunk as reviewed and approved.",
                mutationBodySwift: """
                guard let idx = state.hunks.firstIndex(where: { $0.id == hunkID }) else { break }
                state.hunks[idx].reviewDecision = "APPROVED"
                state.lastAuditMessage = "Approved diff hunk \\(hunkID) in \\(state.hunks[idx].filePath)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "resolveThread(threadID: String)",
                matchPattern: ".resolveThread(let threadID)",
                buttonTitle: "Resolve Review Thread",
                sampleDispatchLiteral: ".resolveThread(threadID: \"thr-101\")",
                summary: "Resolves an inline code review thread after applying suggested patch.",
                mutationBodySwift: """
                guard let idx = state.threads.firstIndex(where: { $0.id == threadID }) else { break }
                state.threads[idx].isResolved = true
                state.lastAuditMessage = "Resolved inline review thread \\(threadID)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "addInlineComment(hunkID: String, reviewer: String, note: String)",
                matchPattern: ".addInlineComment(let hunkID, let reviewer, let note)",
                summary: "Appends a new unresolved inline review comment anchored to a diff hunk.",
                mutationBodySwift: """
                let thread = InlineReviewThread(
                    id: "thr-\\(101 + state.threads.count)",
                    hunkID: hunkID,
                    reviewerHandle: reviewer,
                    body: note,
                    isResolved: false
                )
                state.threads.append(thread)
                state.lastAuditMessage = "Added review thread \\(thread.id) on \\(hunkID)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchPullRequestHunks",
                method: .get,
                path: "/v1/repos/pr/hunks",
                responseType: "[DiffHunkBlock]",
                offlineStubSwift: "GitDiffPRStudioState().hunks",
                summary: "Loads parsed unified diff hunks for active pull request."
            ),
            BlueprintAPIEndpoint(
                methodName: "submitReviewThread",
                method: .post,
                path: "/v1/repos/pr/threads",
                requestPayloadType: "InlineReviewThread",
                responseType: "InlineReviewThread",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Posts line-anchored code review comment or suggestion."
            ),
            BlueprintAPIEndpoint(
                methodName: "mergePullRequestSquash",
                method: .put,
                path: "/v1/repos/pr/merge",
                responseType: "Bool",
                requiresIdempotencyKey: true,
                offlineStubSwift: "true",
                summary: "Executes atomic squash-merge when all hunks and threads pass."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "hunksApproved", label: "Hunk Review Progress", value: "2 / 3", delta: "+55 / -9 lines", sfSymbol: "doc.badge.gearshape.fill"),
            BlueprintKPIMetric(key: "openThreads", label: "Unresolved Threads", value: "1 Thread", delta: "@derya-arch", sfSymbol: "text.bubble.fill"),
            BlueprintKPIMetric(key: "astRisk", label: "Peak Concurrency Risk", value: "83 / 100", delta: "Actor boundary", sfSymbol: "exclamationmark.triangle.fill"),
            BlueprintKPIMetric(key: "mergeGate", label: "Merge Readiness", value: "Blocked", delta: "Resolve 1 thread", sfSymbol: "checkmark.shield")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "hk-1", headline: "CRDTActor.swift · @@ -42,14 +42,26 @@", subheadline: "+18 / -6 lines · Modifies actor isolation boundary", trailingMetric: "Risk 83", statusTag: "PENDING"),
            BlueprintSampleRecord(id: "hk-2", headline: "SnapshotCodec.swift · @@ -108,8 +108,11 @@", subheadline: "+9 / -3 lines · Pure value-type serializer", trailingMetric: "Risk 24", statusTag: "APPROVED"),
            BlueprintSampleRecord(id: "hk-3", headline: "CRDTActorTests.swift · @@ -1,6 +1,34 @@", subheadline: "+28 / -0 lines · Adds @Test cancellation coverage", trailingMetric: "Risk 56", statusTag: "APPROVED")
        ],
        onboardingPages: [
            FlowPage(
                id: "repo-binding",
                title: "Connect Local Git Clone or GitHub PR",
                body: "Parse unified diffs with SwiftSyntax concurrency boundary highlighting.",
                style: "hero",
                actions: ["Open Repository"]
            ),
            FlowPage(
                id: "merge-rules",
                title: "Enforce Hunk-Level Merge Gate",
                body: "Require 100% hunk sign-off and zero unresolved threads before squash merge.",
                style: "choice",
                actions: ["Strict Hunk Sign-Off", "Standard PR Approval"]
            ),
            FlowPage(
                id: "pr-studio-ready",
                title: "PR Review Studio Ready",
                body: "Keyboard-driven hunk navigation (`J`/`K`) and local AST risk scoring are active.",
                style: "completion",
                actions: ["Start Reviewing PRs"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "pr.title", en: "Git Diff & Pull Request Studio", tr: "Git Fark ve PR İnceleme Stüdyosu"),
            BlueprintLocalizedKey(key: "pr.approve_hunk", en: "Approve Diff Hunk", tr: "Kod Parçasını Onayla"),
            BlueprintLocalizedKey(key: "pr.resolve_thread", en: "Resolve Discussion", tr: "Tartışmayı Çözümlendi İşaretle"),
            BlueprintLocalizedKey(key: "pr.merge_ready", en: "Ready to Squash & Merge", tr: "Birleştirme İçin Hazır"),
            BlueprintLocalizedKey(key: "pr.ast_risk", en: "Concurrency Boundary Risk", tr: "Eşzamanlılık Sınır Riski"),
            BlueprintLocalizedKey(key: "pr.line_delta", en: "Net Line Churn", tr: "Net Satır Değişimi")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Detects working-tree file edits to refresh live git diff hunks."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores side-by-side vs unified diff layout preference."
            )
        ],
        customStateComputedSwift: """
        public var unresolvedThreadCount: Int {
            threads.filter(\\.blocksMerge).count
        }

        public var allHunksApproved: Bool {
            !hunks.isEmpty && hunks.allSatisfy { $0.reviewDecision == "APPROVED" }
        }

        public var isMergeable: Bool {
            ciChecksGreen && allHunksApproved && unresolvedThreadCount == 0
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Merge Gate Invariant", systemImage: store.state.isMergeable ? "checkmark.seal.fill" : "xmark.octagon.fill")
                    .font(.headline)
                Spacer()
                Text(store.state.isMergeable ? "READY TO MERGE" : "GATE BLOCKED")
                    .font(.caption.monospaced().bold())
            }
            Text("Unresolved Threads: \\(store.state.unresolvedThreadCount) · All Hunks Approved: \\(store.state.allHunksApproved ? "Yes" : "No")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let risky = state.hunks.filter(\\.touchesConcurrencyBoundary).count
        return "AST Review Copilot: \\(risky) hunk(s) cross actor/Sendable concurrency boundaries; mergeable = \\(state.isMergeable)."
        """,
        customUnitTestsSwift: """
        @Test("Merge gate unlocks only when all hunks approved and threads resolved")
        func mergeGateQuorumVerification() {
            var state = GitDiffPRStudioState()
            #expect(state.isMergeable == false)
            _ = GitDiffPRStudioReducer.reduce(state: &state, action: .approveHunk(hunkID: "hunk-01"))
            #expect(state.isMergeable == false)
            _ = GitDiffPRStudioReducer.reduce(state: &state, action: .resolveThread(threadID: "thr-101"))
            #expect(state.isMergeable == true)
        }
        """,
        securityPostureHighlights: [
            "Signed commit & GPG/SSH tag verification enforced prior to squash-merge unlock.",
            "On-device SwiftSyntax risk heuristics run locally without uploading proprietary diffs.",
            "Immutable audit trail records reviewer approvals per individual diff hunk."
        ]
    )
}
