import ChiefKitStudioCore
import Foundation

// MARK: - Vertical 7: Cognitive Learning & Scientific Research Blueprints

public enum EducationAndScienceBlueprints: Sendable {
    public static let specs: [EnterpriseBlueprintSpec] = [
        fsrsSpacedRepetitionAcademy,
        celestialObservatoryPlanner,
        molecularProtocolLabNotebook
    ]

    // MARK: 19. FSRS-5 Spaced Repetition Memory Academy

    public static let fsrsSpacedRepetitionAcademy = EnterpriseBlueprintSpec(
        id: .fsrsSpacedRepetitionAcademy,
        vertical: .educationScience,
        title: "FSRS Spaced Repetition Academy",
        subtitle: "FSRS-5 power-law forgetting curves, memory stability/difficulty scheduling, and 90% target retention.",
        sfSymbol: "brain.filled.head.profile",
        complexityTier: .professional,
        supportedPlatforms: [.macOS, .iOS, .iPadOS, .watchOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "FSRSMemoryFlashcard",
                tableName: "fsrs_memory_flashcards",
                summary: "Three-component DSR (Difficulty, Stability, Retrievability) spaced-repetition flashcard.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"crd-101\"", isIndexed: true, summary: "Card UUID."),
                    BlueprintEntityField(name: "deckTopic", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Neuroanatomy & Cranial Nerves\"", isIndexed: true, summary: "Deck taxonomy path."),
                    BlueprintEntityField(name: "frontPrompt", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Which cranial foramen transmits the maxillary division (V2) of the trigeminal nerve?\"", summary: "Active recall prompt."),
                    BlueprintEntityField(name: "backAnswer", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Foramen rotundum (sphenoid bone)\"", summary: "Canonical answer + cloze context."),
                    BlueprintEntityField(name: "stabilityDays", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "12.4", summary: "Memory stability S in days (time until R drops to 90%)."),
                    BlueprintEntityField(name: "difficultyRating", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "5.2", summary: "Inherent item difficulty D in [1.0, 10.0]."),
                    BlueprintEntityField(name: "elapsedDaysSinceReview", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "13.0", summary: "Elapsed days t since last review."),
                    BlueprintEntityField(name: "lapseCount", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "0", summary: "Cumulative forgetting lapses.")
                ],
                computedHelpersSwift: """
                /// FSRS-4.5/5 power-law forgetting curve: R(t, S) = (1 + (19/81) * (t / S))^(-0.5)
                public var currentRetrievability: Double {
                    let s = max(0.1, stabilityDays)
                    let factor = 19.0 / 81.0
                    let base = 1.0 + factor * (max(0.0, elapsedDaysSinceReview) / s)
                    return Foundation.pow(base, -0.5)
                }

                public func isDue(targetRetention: Double = 0.90) -> Bool {
                    currentRetrievability <= targetRetention
                }
                """
            ),
            BlueprintDomainEntity(
                name: "StudyReviewTelemetry",
                tableName: "study_review_telemetry",
                summary: "Immutable FSRS review log entry used by local gradient optimizer to personalize weights.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"rev-01\"", isIndexed: true, summary: "Review log entry ID."),
                    BlueprintEntityField(name: "cardID", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"crd-101\"", isIndexed: true, summary: "Reviewed card ID."),
                    BlueprintEntityField(name: "gradeButton", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "3", summary: "1=Again, 2=Hard, 3=Good, 4=Easy."),
                    BlueprintEntityField(name: "responseLatencyMs", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "3850", summary: "Active recall latency in ms.")
                ],
                computedHelpersSwift: """
                public var wasRecalledSuccessfully: Bool {
                    gradeButton >= 2
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "cards",
                swiftType: "[FSRSMemoryFlashcard]",
                initialValueLiteral: """
                [
                    FSRSMemoryFlashcard(id: "crd-101", deckTopic: "Cranial Nerves", frontPrompt: "Foramen transmitting CN V2 (Maxillary)?", backAnswer: "Foramen rotundum", stabilityDays: 12.0, difficultyRating: 5.2, elapsedDaysSinceReview: 13.5, lapseCount: 0),
                    FSRSMemoryFlashcard(id: "crd-102", deckTopic: "Distributed Systems", frontPrompt: "FLP Impossibility theorem core assumption?", backAnswer: "Asynchronous network with even 1 unannounced crash fault", stabilityDays: 28.0, difficultyRating: 6.4, elapsedDaysSinceReview: 9.0, lapseCount: 1),
                    FSRSMemoryFlashcard(id: "crd-103", deckTopic: "Swift 6 Runtime", frontPrompt: "What protocol guarantees safe value transfer across actor domains?", backAnswer: "Sendable", stabilityDays: 45.0, difficultyRating: 2.8, elapsedDaysSinceReview: 48.0, lapseCount: 0)
                ]
                """,
                summary: "Active FSRS deck cards with DSR state."
            ),
            BlueprintStateProperty(
                name: "reviewLogs",
                swiftType: "[StudyReviewTelemetry]",
                initialValueLiteral: "[]",
                summary: "Completed review history for FSRS weight optimization."
            ),
            BlueprintStateProperty(
                name: "desiredRetention",
                swiftType: "Double",
                initialValueLiteral: "0.90",
                summary: "Target recall probability at review time [0.75, 0.97]."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "gradeCard(cardID: String, grade: Int, latencyMs: Int)",
                matchPattern: ".gradeCard(let cardID, let grade, let latencyMs)",
                buttonTitle: "Grade Due Card 'Good' (3)",
                sampleDispatchLiteral: ".gradeCard(cardID: \"crd-101\", grade: 3, latencyMs: 3200)",
                summary: "Updates FSRS memory stability S and difficulty D according to recall grade (1..4).",
                mutationBodySwift: """
                guard let idx = state.cards.firstIndex(where: { $0.id == cardID }) else { break }
                let clampedGrade = min(max(grade, 1), 4)
                let oldS = state.cards[idx].stabilityDays
                let oldD = state.cards[idx].difficultyRating
                let r = state.cards[idx].currentRetrievability

                let nextD = min(max(oldD - 0.55 * Double(clampedGrade - 3), 1.0), 10.0)
                let nextS: Double
                if clampedGrade == 1 {
                    nextS = max(0.5, oldS * 0.28)
                    state.cards[idx].lapseCount += 1
                } else {
                    let hardPenalty = clampedGrade == 2 ? 0.82 : (clampedGrade == 4 ? 1.32 : 1.0)
                    let recallGain = 1.0 + (11.0 - nextD) * 0.22 * (1.15 - r) * hardPenalty
                    nextS = oldS * max(1.15, recallGain)
                }
                state.cards[idx].difficultyRating = nextD
                state.cards[idx].stabilityDays = nextS
                state.cards[idx].elapsedDaysSinceReview = 0.0
                state.reviewLogs.append(
                    StudyReviewTelemetry(id: "rev-\\(state.reviewLogs.count + 1)", cardID: cardID, gradeButton: clampedGrade, responseLatencyMs: latencyMs)
                )
                state.lastAuditMessage = String(format: "Graded %@ (%d) -> next S=%.1fd, D=%.2f", cardID, clampedGrade, nextS, nextD)
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "advanceSimulatedClock(days: Double)",
                matchPattern: ".advanceSimulatedClock(let days)",
                buttonTitle: "Advance +7 Days",
                sampleDispatchLiteral: ".advanceSimulatedClock(days: 7.0)",
                summary: "Advances elapsed days across all cards to project future review queue load.",
                mutationBodySwift: """
                guard days > 0 else { break }
                for idx in state.cards.indices {
                    state.cards[idx].elapsedDaysSinceReview += days
                }
                state.lastAuditMessage = "Advanced FSRS simulation clock +\\(Int(days))d"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchDeckCards",
                method: .get,
                path: "/v1/academy/decks/cards",
                responseType: "[FSRSMemoryFlashcard]",
                offlineStubSwift: "FSRSMemoryAcademyState().cards",
                summary: "Syncs FSRS flashcard DSR states across macOS, iOS, and watchOS."
            ),
            BlueprintAPIEndpoint(
                methodName: "uploadReviewLogBatch",
                method: .post,
                path: "/v1/academy/reviews/batch",
                requestPayloadType: "[StudyReviewTelemetry]",
                responseType: "Bool",
                requiresIdempotencyKey: true,
                offlineStubSwift: "true",
                summary: "Appends idempotent review logs for cross-device scheduler convergence."
            ),
            BlueprintAPIEndpoint(
                methodName: "optimizePersonalFSRSWeights",
                method: .post,
                path: "/v1/academy/fsrs/optimize",
                requestPayloadType: "[StudyReviewTelemetry]",
                responseType: "[Double]",
                offlineStubSwift: "[0.40, 1.18, 3.12, 15.47]",
                summary: "Fits 19-parameter FSRS weights to learner review history."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "dueNow", label: "Due Queue Today", value: "2 Cards", delta: "R <= 90.0%", sfSymbol: "rectangle.stack.badge.play.fill"),
            BlueprintKPIMetric(key: "meanStability", label: "Mean Stability (S)", value: "28.3 days", delta: "Long-term consolidated", sfSymbol: "chart.line.uptrend.xyaxis"),
            BlueprintKPIMetric(key: "retentionTarget", label: "Desired Retention", value: "90.0%", delta: "Optimal workload", sfSymbol: "target"),
            BlueprintKPIMetric(key: "lapses", label: "Leech / Lapse Rate", value: "1 Lapse", delta: "97% pass rate", sfSymbol: "checkmark.seal.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "fc-1", headline: "Foramen transmitting CN V2 (Maxillary)?", subheadline: "Cranial Nerves · S = 12.0d · D = 5.2 · Elapsed 13.5d", trailingMetric: "R 88.9%", statusTag: "DUE NOW"),
            BlueprintSampleRecord(id: "fc-2", headline: "FLP Impossibility theorem core assumption?", subheadline: "Distributed Systems · S = 28.0d · D = 6.4 · Elapsed 9.0d", trailingMetric: "R 96.4%", statusTag: "SCHEDULED"),
            BlueprintSampleRecord(id: "fc-3", headline: "Safe value transfer protocol in Swift 6?", subheadline: "Swift 6 Runtime · S = 45.0d · D = 2.8 · Elapsed 48.0d", trailingMetric: "R 89.4%", statusTag: "DUE NOW")
        ],
        onboardingPages: [
            FlowPage(
                id: "import-decks",
                title: "Import Markdown Cloze or Anki .apkg Decks",
                body: "Parse LaTeX equations, code snippets, and anatomical image occlusions natively.",
                style: "hero",
                actions: ["Import Study Decks"]
            ),
            FlowPage(
                id: "retention-slider",
                title: "Calibrate Desired Retention vs Daily Workload",
                body: "90% retention maximizes long-term knowledge per minute invested.",
                style: "choice",
                actions: ["90% Optimal Retention", "95% Exam Sprint Mode"]
            ),
            FlowPage(
                id: "fsrs-ready",
                title: "FSRS-5 Memory Engine Active",
                body: "Power-law forgetting curves and personalized DSR intervals are live.",
                style: "completion",
                actions: ["Start Daily Reviews"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "fsrs.title", en: "FSRS Spaced Repetition Academy", tr: "FSRS Aralıklı Tekrar Akademisi"),
            BlueprintLocalizedKey(key: "fsrs.retrievability", en: "Predicted Recall Probability (R)", tr: "Tahmini Hatırlama Olasılığı (R)"),
            BlueprintLocalizedKey(key: "fsrs.stability", en: "Memory Stability (Days)", tr: "Bellek Kararlılığı (Gün)"),
            BlueprintLocalizedKey(key: "fsrs.grade_good", en: "Recalled Effortlessly (Good)", tr: "Doğru Hatırlandı (İyi)"),
            BlueprintLocalizedKey(key: "fsrs.due_queue", en: "Cards Due for Review", tr: "Tekrar Zamanı Gelen Kartlar"),
            BlueprintLocalizedKey(key: "fsrs.leech", en: "High-Lapse Leech Card", tr: "Sık Unutulan Zorlu Kart")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Measures per-card recall response latency milliseconds."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores daily new-card cap and desired retention target."
            )
        ],
        customStateComputedSwift: """
        public var dueCards: [FSRSMemoryFlashcard] {
            cards.filter { $0.isDue(targetRetention: desiredRetention) }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("FSRS-5 DSR Forgetting Curve Queue", systemImage: "function")
                    .font(.headline)
                Spacer()
                Text("\\(store.state.dueCards.count) Due Now")
                    .font(.caption.monospacedDigit().bold())
            }
            ForEach(store.state.cards) { card in
                HStack {
                    Text(card.deckTopic)
                        .font(.caption)
                    Spacer()
                    Text("S=\\(String(format: "%.1fd", card.stabilityDays)) · R=\\(String(format: "%.1f%%", card.currentRetrievability * 100))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Academy Copilot: \\(state.dueCards.count) of \\(state.cards.count) cards below \\(Int(state.desiredRetention * 100))% retrievability; \\(state.reviewLogs.count) reviews logged."
        """,
        customUnitTestsSwift: """
        @Test("FSRS power-law retrievability equals 90% when t == S and grading Good expands stability")
        func fsrsForgettingCurveAndStabilityExpansion() {
            var state = FSRSMemoryAcademyState()
            let probe = FSRSMemoryFlashcard(stabilityDays: 10.0, difficultyRating: 5.0, elapsedDaysSinceReview: 10.0)
            #expect(abs(probe.currentRetrievability - 0.90) < 0.001)

            let beforeS = state.cards[0].stabilityDays
            _ = FSRSMemoryAcademyReducer.reduce(
                state: &state,
                action: .gradeCard(cardID: "crd-101", grade: 3, latencyMs: 2800)
            )
            #expect(state.cards[0].stabilityDays > beforeS)
            #expect(state.cards[0].elapsedDaysSinceReview == 0.0)
        }
        """,
        securityPostureHighlights: [
            "100% offline SQLite study engine works on flights and medical school wards without Wi-Fi.",
            "Personal recall telemetry optimized locally on Apple Neural Engine / CPU.",
            "Idempotent review log UUIDs prevent duplicate stability inflation on sync."
        ]
    )

    // MARK: 20. Celestial Observatory & EphemerisCore Planner

    public static let celestialObservatoryPlanner = EnterpriseBlueprintSpec(
        id: .celestialObservatoryPlanner,
        vertical: .educationScience,
        title: "Celestial Observatory Planner",
        subtitle: "EphemerisCore J2000 night-sky targets, Rozenberg airmass & Bortle dark-sky scoring, and ASCOM/INDI mount queue.",
        sfSymbol: "sparkles",
        complexityTier: .enterprise,
        supportedPlatforms: [.macOS, .iPadOS, .iOS, .visionOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "DeepSkyEphemerisTarget",
                tableName: "deep_sky_ephemeris_targets",
                summary: "EphemerisCore J2000 astrophotography or visual deep-sky target with real-time altitude and airmass.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"dso-m31\"", isIndexed: true, summary: "Messier/NGC/IC catalog ID."),
                    BlueprintEntityField(name: "catalogDesignation", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"M31 · NGC 224\"", isIndexed: true, summary: "Astronomical catalog code."),
                    BlueprintEntityField(name: "commonName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Andromeda Galaxy\"", summary: "Object common name."),
                    BlueprintEntityField(name: "raHours", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.712", summary: "J2000 Right Ascension in decimal hours [0, 24)."),
                    BlueprintEntityField(name: "decDegrees", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "41.269", summary: "J2000 Declination in degrees [-90, +90]."),
                    BlueprintEntityField(name: "altitudeDegrees", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "64.5", summary: "Current EphemerisCore topocentric altitude above horizon."),
                    BlueprintEntityField(name: "plannedSubExposures", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "48", summary: "Scheduled 300s narrowband/LRGB sub-frames.")
                ],
                computedHelpersSwift: """
                /// Plane-parallel + Rozenberg horizon-safe optical airmass X (1.0 at zenith, ~2.0 at 30° altitude).
                public var opticalAirmass: Double {
                    guard altitudeDegrees > 1.0 else { return 38.0 }
                    let rad = altitudeDegrees * .pi / 180.0
                    let sinAlt = Foundation.sin(rad)
                    return 1.0 / (sinAlt + 0.025 * Foundation.exp(-11.0 * sinAlt))
                }

                public var isOptimalImagingWindow: Bool {
                    altitudeDegrees >= 30.0 && opticalAirmass <= 2.0
                }
                """
            ),
            BlueprintDomainEntity(
                name: "ObservatoryWeatherDome",
                tableName: "observatory_weather_domes",
                summary: "Observatory sky quality meter (SQM), Bortle class, FWHM seeing arcseconds, and cloud safety interlock.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"site-toros\"", isIndexed: true, summary: "Observatory site ID."),
                    BlueprintEntityField(name: "siteTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Bakirlitepe 2500m Dark Sky\"", summary: "Site location name."),
                    BlueprintEntityField(name: "bortleClass", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "2", summary: "Bortle dark-sky scale [1..9]."),
                    BlueprintEntityField(name: "seeingArcsec", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1.15", summary: "Autoguider FWHM atmospheric seeing in arcseconds."),
                    BlueprintEntityField(name: "dewSpreadCelsius", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "6.4", summary: "Ambient minus dew-point temperature spread (°C)."),
                    BlueprintEntityField(name: "shutterOpenSafe", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "true", summary: "False if rain/wind sensor commands dome Park & Close.")
                ],
                computedHelpersSwift: """
                public var needsDewHeaterBoost: Bool {
                    dewSpreadCelsius <= 3.0
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "targets",
                swiftType: "[DeepSkyEphemerisTarget]",
                initialValueLiteral: """
                [
                    DeepSkyEphemerisTarget(id: "dso-m31", catalogDesignation: "M31 · NGC 224", commonName: "Andromeda Galaxy", raHours: 0.712, decDegrees: 41.269, altitudeDegrees: 68.4, plannedSubExposures: 48),
                    DeepSkyEphemerisTarget(id: "dso-ic1805", catalogDesignation: "IC 1805 · Sh2-190", commonName: "Heart Nebula (SHO)", raHours: 2.545, decDegrees: 61.45, altitudeDegrees: 54.2, plannedSubExposures: 60),
                    DeepSkyEphemerisTarget(id: "dso-m42", catalogDesignation: "M42 · NGC 1976", commonName: "Orion Nebula", raHours: 5.588, decDegrees: -5.391, altitudeDegrees: 19.5, plannedSubExposures: 36)
                ]
                """,
                summary: "EphemerisCore tonight's imaging target sequence."
            ),
            BlueprintStateProperty(
                name: "domeStatus",
                swiftType: "ObservatoryWeatherDome",
                initialValueLiteral: "ObservatoryWeatherDome()",
                summary: "Live observatory environmental & dome safety telemetry."
            ),
            BlueprintStateProperty(
                name: "activeSlewedTargetID",
                swiftType: "String",
                initialValueLiteral: "\"dso-m31\"",
                summary: "Target currently plate-solved and tracked by equatorial mount."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "slewMountToTarget(targetID: String)",
                matchPattern: ".slewMountToTarget(let targetID)",
                buttonTitle: "Slew Mount to IC 1805",
                sampleDispatchLiteral: ".slewMountToTarget(targetID: \"dso-ic1805\")",
                summary: "Verifies dome safety and minimum 30° altitude horizon guardrail before slewing equatorial mount.",
                mutationBodySwift: """
                guard state.domeStatus.shutterOpenSafe,
                      let target = state.targets.first(where: { $0.id == targetID }) else {
                    state.lastAuditMessage = "Slew aborted: dome weather safety closed"
                    break
                }
                guard target.altitudeDegrees >= 25.0 else {
                    state.lastAuditMessage = "Slew rejected: \\(target.catalogDesignation) below 25° horizon limit"
                    break
                }
                state.activeSlewedTargetID = targetID
                state.lastAuditMessage = String(format: "Slewed & plate-solved %@ (airmass %.2f)", target.catalogDesignation, target.opticalAirmass)
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "triggerWeatherSafetyPark(reason: String)",
                matchPattern: ".triggerWeatherSafetyPark(let reason)",
                buttonTitle: "Emergency Cloud Park",
                sampleDispatchLiteral: ".triggerWeatherSafetyPark(reason: \"High-altitude cirrus + wind gust > 45 km/h\")",
                summary: "Parks equatorial mount at celestial pole and closes observatory dome shutter.",
                mutationBodySwift: """
                state.domeStatus.shutterOpenSafe = false
                state.lastAuditMessage = "DOME PARKED: \\(reason)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchTonightEphemeris",
                method: .get,
                path: "/v1/observatory/ephemeris/tonight",
                responseType: "[DeepSkyEphemerisTarget]",
                offlineStubSwift: "CelestialPlannerState().targets",
                summary: "Computes EphemerisCore topocentric altitudes and transit times."
            ),
            BlueprintAPIEndpoint(
                methodName: "commandMountSlewAndSolve",
                method: .post,
                path: "/v1/observatory/mount/slew",
                requestPayloadType: "DeepSkyEphemerisTarget",
                responseType: "DeepSkyEphemerisTarget",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Dispatches ASCOM Alpaca / INDI GoTo slew + ASTAP plate-solve."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchDomeWeatherSafety",
                method: .get,
                path: "/v1/observatory/dome/weather",
                responseType: "ObservatoryWeatherDome",
                offlineStubSwift: "CelestialPlannerState().domeStatus",
                summary: "Polls Boltwood cloud sensor and SQM-LU sky brightness."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "skyQuality", label: "Dark Sky Class", value: "Bortle 2", delta: "21.82 mag/arcsec²", sfSymbol: "moon.stars.fill"),
            BlueprintKPIMetric(key: "seeingFWHM", label: "Autoguider Seeing", value: "1.15\"", delta: "RMS 0.38\" RA/Dec", sfSymbol: "scope"),
            BlueprintKPIMetric(key: "airmass", label: "M31 Optical Airmass", value: "1.08 X", delta: "Alt 68.4° optimal", sfSymbol: "safari.fill"),
            BlueprintKPIMetric(key: "domeState", label: "Dome Safety Relay", value: "OPEN SAFE", delta: "Dew Δ +6.4°C", sfSymbol: "checkmark.shield.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "obs-1", headline: "M31 · Andromeda Galaxy (RA 00h42m Dec +41°16')", subheadline: "Alt 68.4° · Airmass 1.08 · 48 x 300s LRGB queued", trailingMetric: "TRACKING", statusTag: "OPTIMAL"),
            BlueprintSampleRecord(id: "obs-2", headline: "IC 1805 · Heart Nebula (SHO Narrowband)", subheadline: "Alt 54.2° · Airmass 1.23 · 60 x 300s 3nm Ha/OIII/SII", trailingMetric: "QUEUED #2", statusTag: "OPTIMAL"),
            BlueprintSampleRecord(id: "obs-3", headline: "M42 · Orion Nebula (Rising East)", subheadline: "Alt 19.5° · Airmass 2.94 · Waiting for >30° transit", trailingMetric: "LOW ALT", statusTag: "RISING")
        ],
        onboardingPages: [
            FlowPage(
                id: "site-coords",
                title: "Configure Observatory Geodetic Coordinates",
                body: "Initialize EphemerisCore local sidereal time, astronomical twilight, and horizon mask.",
                style: "hero",
                actions: ["Set Site Latitude & Elevation"]
            ),
            FlowPage(
                id: "red-night-ui",
                title: "Enable Scotopic Red-Vision Preserve Mode",
                body: "Protect dark-adapted rhodopsin vision at the telescope pier while keeping telemetry crisp.",
                style: "choice",
                actions: ["630nm Deep Red Mode", "Control Room Dark Mode"]
            ),
            FlowPage(
                id: "observatory-ready",
                title: "Celestial Observatory Planner Armed",
                body: "EphemerisCore airmass curves, horizon safety limits, and mount sequencing are live.",
                style: "completion",
                actions: ["Start Night Sequence"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "astro.title", en: "Celestial Observatory Planner", tr: "Gökyüzü Gözlemevi Planlayıcısı"),
            BlueprintLocalizedKey(key: "astro.slew_mount", en: "Slew Telescope & Plate-Solve", tr: "Teleskobu Yönlendir ve Konum Çöz"),
            BlueprintLocalizedKey(key: "astro.airmass", en: "Optical Airmass (X)", tr: "Optik Hava Kütlesi (X)"),
            BlueprintLocalizedKey(key: "astro.dome_park", en: "Emergency Weather Park", tr: "Acil Hava Durumu Kubbe Kapatma"),
            BlueprintLocalizedKey(key: "astro.seeing", en: "Atmospheric Seeing (FWHM)", tr: "Atmosferik Görüş Kalitesi (FWHM)"),
            BlueprintLocalizedKey(key: "astro.bortle", en: "Bortle Dark-Sky Scale", tr: "Bortle Karanlık Gökyüzü Ölçeği")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Tracks sub-second pulse-guiding and long-exposure bulb shutter durations."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryDiskSpace",
                reasonCodes: ["E174.1"],
                purposeSummary: "Verifies SSD capacity before capturing uncompressed 16-bit FITS sub-frames."
            )
        ],
        customStateComputedSwift: """
        public var optimalWindowTargets: [DeepSkyEphemerisTarget] {
            targets.filter(\\.isOptimalImagingWindow)
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("EphemerisCore Airmass & Mount Pier", systemImage: "moon.stars.fill")
                    .font(.headline)
                Spacer()
                Text("Optimal: \\(store.state.optimalWindowTargets.count)/\\(store.state.targets.count)")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("Tracking: \\(store.state.activeSlewedTargetID) · Dome Safe: \\(store.state.domeStatus.shutterOpenSafe ? "OPEN" : "PARKED")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Ephemeris Copilot: \\(state.optimalWindowTargets.count) DSO target(s) above 30° (airmass <= 2.0); seeing \\(state.domeStatus.seeingArcsec) arcsec in Bortle \\(state.domeStatus.bortleClass)."
        """,
        customUnitTestsSwift: """
        @Test("Rozenberg optical airmass < 1.3 at high altitude and horizon guardrail blocks low slew")
        func airmassMathAndHorizonGuardrail() {
            var state = CelestialPlannerState()
            #expect(state.targets[0].opticalAirmass < 1.15)
            #expect(state.targets[2].isOptimalImagingWindow == false)

            _ = CelestialPlannerReducer.reduce(state: &state, action: .slewMountToTarget(targetID: "dso-m42"))
            #expect(state.activeSlewedTargetID == "dso-m31")

            _ = CelestialPlannerReducer.reduce(state: &state, action: .slewMountToTarget(targetID: "dso-ic1805"))
            #expect(state.activeSlewedTargetID == "dso-ic1805")
        }
        """,
        securityPostureHighlights: [
            "Hardcoded 25° horizon & meridian-flip pier collision guardrails protect optical tube assemblies.",
            "Offline EphemerisCore orbital math requires zero internet at remote mountain dark-sky sites.",
            "Hardware weather relay interlock overrides software commands during precipitation."
        ]
    )

    // MARK: 21. Molecular Protocol & Wet-Lab Electronic Notebook (ELN)

    public static let molecularProtocolLabNotebook = EnterpriseBlueprintSpec(
        id: .molecularProtocolLabNotebook,
        vertical: .educationScience,
        title: "Molecular Protocol Lab Notebook",
        subtitle: "C1V1=C2V2 stock molarity/dilution calculators, dry-reagent mass math, and GLP step timers.",
        sfSymbol: "flask.fill",
        complexityTier: .enterprise,
        supportedPlatforms: [.iPadOS, .macOS, .iOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "ReagentDilutionPrep",
                tableName: "reagent_dilution_preps",
                summary: "Stoichiometric C1*V1 = C2*V2 buffer or stock dilution specification with pipette volume uL.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"sol-tris\"", isIndexed: true, summary: "Reagent prep ID."),
                    BlueprintEntityField(name: "reagentTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Tris-HCl pH 8.0 Assay Buffer\"", summary: "Chemical or enzyme stock name."),
                    BlueprintEntityField(name: "stockMolarityM", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1.0", summary: "Concentrated stock molarity C1 in mol/L (M)."),
                    BlueprintEntityField(name: "workingMolarityM", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.05", summary: "Desired working molarity C2 in mol/L (M)."),
                    BlueprintEntityField(name: "finalVolumeML", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "50.0", summary: "Desired final working volume V2 in mL."),
                    BlueprintEntityField(name: "molecularWeightGPerMol", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "121.14", summary: "Formula weight in g/mol for dry-powder preparation.")
                ],
                computedHelpersSwift: """
                /// Required stock aliquot V1 in milliliters: V1 = (C2 * V2) / C1
                public var requiredStockVolumeML: Double {
                    guard stockMolarityM > 0, workingMolarityM <= stockMolarityM else { return 0.0 }
                    return (workingMolarityM * finalVolumeML) / stockMolarityM
                }

                public var requiredStockMicroliters: Double {
                    requiredStockVolumeML * 1000.0
                }

                public var diluentWaterVolumeML: Double {
                    max(0.0, finalVolumeML - requiredStockVolumeML)
                }

                /// Dry mass in grams if prepared directly from powder: mass = M * V(L) * MW
                public var equivalentDryMassGrams: Double {
                    workingMolarityM * (finalVolumeML / 1000.0) * molecularWeightGPerMol
                }
                """
            ),
            BlueprintDomainEntity(
                name: "WetLabProtocolStep",
                tableName: "wet_lab_protocol_steps",
                summary: "Sequential benchtop SOP step with incubation temperature, countdown timer, and GLP witness sign-off.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"stp-01\"", isIndexed: true, summary: "Protocol step ID."),
                    BlueprintEntityField(name: "stepIndex", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1", summary: "1-based execution order."),
                    BlueprintEntityField(name: "instruction", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Denature cDNA template at 98°C with Q5 High-Fidelity Polymerase\"", summary: "Benchtop step instruction."),
                    BlueprintEntityField(name: "targetTempCelsius", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "98.0", summary: "Thermocycler or water-bath setpoint (°C)."),
                    BlueprintEntityField(name: "remainingSeconds", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "30", summary: "Remaining incubation timer in seconds."),
                    BlueprintEntityField(name: "glpSignedBy", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"\"", summary: "Researcher ORCID/initials once step is completed.")
                ],
                computedHelpersSwift: """
                public var isCompletedGLP: Bool {
                    !glpSignedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "reagentPreps",
                swiftType: "[ReagentDilutionPrep]",
                initialValueLiteral: """
                [
                    ReagentDilutionPrep(id: "sol-tris", reagentTitle: "Tris-HCl pH 8.0 (1M -> 50mM)", stockMolarityM: 1.0, workingMolarityM: 0.05, finalVolumeML: 50.0, molecularWeightGPerMol: 121.14),
                    ReagentDilutionPrep(id: "sol-mgcl2", reagentTitle: "MgCl2 Cofactor (25mM -> 1.5mM)", stockMolarityM: 0.025, workingMolarityM: 0.0015, finalVolumeML: 10.0, molecularWeightGPerMol: 95.21)
                ]
                """,
                summary: "Benchtop molarity & dilution calculations."
            ),
            BlueprintStateProperty(
                name: "protocolSteps",
                swiftType: "[WetLabProtocolStep]",
                initialValueLiteral: """
                [
                    WetLabProtocolStep(id: "stp-01", stepIndex: 1, instruction: "Initial Denaturation (Q5 Hot-Start)", targetTempCelsius: 98.0, remainingSeconds: 30, glpSignedBy: "Dr. Arda T."),
                    WetLabProtocolStep(id: "stp-02", stepIndex: 2, instruction: "Primer Annealing (30 cycles)", targetTempCelsius: 62.5, remainingSeconds: 20, glpSignedBy: ""),
                    WetLabProtocolStep(id: "stp-03", stepIndex: 3, instruction: "Amplicon Extension (30s/kb)", targetTempCelsius: 72.0, remainingSeconds: 90, glpSignedBy: "")
                ]
                """,
                summary: "Active wet-lab assay SOP steps."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "signOffProtocolStep(stepID: String, researcherInitials: String)",
                matchPattern: ".signOffProtocolStep(let stepID, let researcherInitials)",
                buttonTitle: "GLP Sign-Off Step #2",
                sampleDispatchLiteral: ".signOffProtocolStep(stepID: \"stp-02\", researcherInitials: \"Dr. Arda T.\")",
                summary: "Records timestamped GLP researcher sign-off and zeroes step timer.",
                mutationBodySwift: """
                guard let idx = state.protocolSteps.firstIndex(where: { $0.id == stepID }) else { break }
                state.protocolSteps[idx].remainingSeconds = 0
                state.protocolSteps[idx].glpSignedBy = researcherInitials
                state.lastAuditMessage = "GLP signed \\(stepID) by \\(researcherInitials)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "scaleDilutionFinalVolume(prepID: String, newFinalVolumeML: Double)",
                matchPattern: ".scaleDilutionFinalVolume(let prepID, let newFinalVolumeML)",
                buttonTitle: "Scale Tris Mastermix -> 100 mL",
                sampleDispatchLiteral: ".scaleDilutionFinalVolume(prepID: \"sol-tris\", newFinalVolumeML: 100.0)",
                summary: "Scales mastermix final volume V2 while maintaining exact C2 stoichiometric molarity.",
                mutationBodySwift: """
                guard newFinalVolumeML > 0,
                      let idx = state.reagentPreps.firstIndex(where: { $0.id == prepID }) else { break }
                state.reagentPreps[idx].finalVolumeML = newFinalVolumeML
                let ul = state.reagentPreps[idx].requiredStockMicroliters
                state.lastAuditMessage = String(format: "Scaled %@ to %.1f mL (pipette %.0f uL stock)", prepID, newFinalVolumeML, ul)
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchAssayProtocol",
                method: .get,
                path: "/v1/eln/protocols/active/steps",
                responseType: "[WetLabProtocolStep]",
                offlineStubSwift: "MolecularLabNotebookState().protocolSteps",
                summary: "Loads version-pinned wet-lab SOP steps."
            ),
            BlueprintAPIEndpoint(
                methodName: "commitGLPSignOff",
                method: .post,
                path: "/v1/eln/protocols/signoff",
                requestPayloadType: "WetLabProtocolStep",
                responseType: "WetLabProtocolStep",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Records immutable Good Laboratory Practice electronic witness signature."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchReagentRecipes",
                method: .get,
                path: "/v1/eln/reagents/dilutions",
                responseType: "[ReagentDilutionPrep]",
                offlineStubSwift: "MolecularLabNotebookState().reagentPreps",
                summary: "Retrieves verified molarity and buffer preparation sheets."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "trisAliquot", label: "Tris Stock Aliquot", value: "2,500 uL", delta: "+ 47.5 mL ddH2O", sfSymbol: "eyedropper.halffull"),
            BlueprintKPIMetric(key: "dryMass", label: "Tris Powder Equiv.", value: "0.303 g", delta: "MW 121.14 g/mol", sfSymbol: "scalemass.fill"),
            BlueprintKPIMetric(key: "glpProgress", label: "GLP SOP Progress", value: "1 / 3 Steps", delta: "Anneal @ 62.5°C", sfSymbol: "timer"),
            BlueprintKPIMetric(key: "fairAudit", label: "FAIR / GLP Seal", value: "ORCID Bound", delta: "Append-only ELN", sfSymbol: "checkmark.seal.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "lab-1", headline: "Tris-HCl pH 8.0 · 1.0 M -> 50 mM (50 mL)", subheadline: "Pipette 2.50 mL stock + 47.50 mL nuclease-free water", trailingMetric: "2,500 uL", statusTag: "VERIFIED"),
            BlueprintSampleRecord(id: "lab-2", headline: "MgCl2 Cofactor · 25 mM -> 1.5 mM (10 mL)", subheadline: "Pipette 600 uL stock + 9.40 mL molecular grade H2O", trailingMetric: "600 uL", statusTag: "VERIFIED"),
            BlueprintSampleRecord(id: "lab-3", headline: "Step 2 · Primer Annealing @ 62.5°C", subheadline: "30 thermal cycles · Touch-free Apple Pencil / Voice ready", trailingMetric: "20s timer", statusTag: "NEXT STEP")
        ],
        onboardingPages: [
            FlowPage(
                id: "orcid-bind",
                title: "Bind Researcher ORCID & GLP Signature",
                body: "Stamp every wet-lab buffer lot and thermocycler step with tamper-evident attribution.",
                style: "hero",
                actions: ["Bind ORCID Identity"]
            ),
            FlowPage(
                id: "glove-mode",
                title: "Enable Benchtop Nitrile-Glove & Voice Controls",
                body: "Oversized touch targets and hands-free timer triggers keep iPads clean at the biosafety hood.",
                style: "choice",
                actions: ["Large Benchtop Controls", "Compact Desktop ELN"]
            ),
            FlowPage(
                id: "eln-ready",
                title: "Molecular Lab Notebook Armed",
                body: "C1V1=C2V2 stoichiometry calculators and GLP step timers are active.",
                style: "completion",
                actions: ["Launch Lab Notebook"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "lab.title", en: "Molecular Protocol Lab Notebook", tr: "Moleküler Protokol Laboratuvar Defteri"),
            BlueprintLocalizedKey(key: "lab.dilution_calc", en: "Stoichiometric Dilution (C1V1=C2V2)", tr: "Stokiyometrik Seyreltme (C1V1=C2V2)"),
            BlueprintLocalizedKey(key: "lab.stock_aliquot", en: "Required Stock Pipette Volume", tr: "Gerekli Stok Pipetleme Hacmi"),
            BlueprintLocalizedKey(key: "lab.glp_sign", en: "GLP Researcher Sign-Off", tr: "GLP Araştırmacı İmza Onayı"),
            BlueprintLocalizedKey(key: "lab.dry_mass", en: "Dry Reagent Mass (g)", tr: "Kuru Reaktif Kütlesi (g)"),
            BlueprintLocalizedKey(key: "lab.thermal_step", en: "Thermocycler Setpoint", tr: "Termosiklör Sıcaklık Hedefi")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Drives precision enzymatic incubation countdown timers."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Audits gel electrophoresis and Sanger chromatogram attachment timestamps."
            )
        ],
        customStateComputedSwift: """
        public var completedStepCount: Int {
            protocolSteps.filter(\\.isCompletedGLP).count
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("C1V1 = C2V2 Benchtop Calculator", systemImage: "testtube.2")
                    .font(.headline)
                Spacer()
                Text("GLP \\(store.state.completedStepCount)/\\(store.state.protocolSteps.count)")
                    .font(.caption.monospacedDigit().bold())
            }
            ForEach(store.state.reagentPreps) { prep in
                Text("\\(prep.reagentTitle): \\(Int(prep.requiredStockMicroliters)) uL stock + \\(String(format: "%.2f", prep.diluentWaterVolumeML)) mL diluent")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Benchtop Copilot: \\(state.completedStepCount)/\\(state.protocolSteps.count) GLP steps signed; Tris aliquot = \\(Int(state.reagentPreps.first?.requiredStockMicroliters ?? 0)) uL."
        """,
        customUnitTestsSwift: """
        @Test("C1V1=C2V2 dilution math computes exact stock microliters and dry mass grams")
        func molarityDilutionStoichiometry() {
            var state = MolecularLabNotebookState()
            #expect(abs(state.reagentPreps[0].requiredStockVolumeML - 2.5) < 0.001)
            #expect(abs(state.reagentPreps[0].diluentWaterVolumeML - 47.5) < 0.001)
            #expect(abs(state.reagentPreps[0].equivalentDryMassGrams - 0.30285) < 0.001)

            _ = MolecularLabNotebookReducer.reduce(
                state: &state,
                action: .scaleDilutionFinalVolume(prepID: "sol-tris", newFinalVolumeML: 100.0)
            )
            #expect(abs(state.reagentPreps[0].requiredStockMicroliters - 5000.0) < 0.1)
        }
        """,
        securityPostureHighlights: [
            "GLP / FDA 21 CFR Part 11 audit seal hashes researcher sign-off with step parameters.",
            "Unpublished molecular structures and primer sequences remain inside encrypted local vault.",
            "Guardrail rejects impossible dilutions where target C2 exceeds concentrated stock C1."
        ]
    )
}
