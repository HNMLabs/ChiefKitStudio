import ChiefKitStudioCore
import Foundation

// MARK: - Vertical 3: Clinical Health & Biometrics Blueprints

public enum HealthAndBiometricsBlueprints: Sendable {
    public static let specs: [EnterpriseBlueprintSpec] = [
        clinicalVitalsLongevityLab,
        circadianSleepHRVCoach,
        telemedicinePrescriptionVault
    ]

    // MARK: 7. Clinical Vitals & Longevity Biomarker Lab

    public static let clinicalVitalsLongevityLab = EnterpriseBlueprintSpec(
        id: .clinicalVitalsLongevityLab,
        vertical: .healthBiometrics,
        title: "Clinical Vitals & Longevity Lab",
        subtitle: "ApoB, hs-CRP & VO2Max longevity reference zones, phenotypic age delta math, and HL7 FHIR R4 local vaulting.",
        sfSymbol: "waveform.path.ecg.rectangle.fill",
        complexityTier: .enterprise,
        supportedPlatforms: [.iOS, .iPadOS, .macOS, .watchOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "LongevityBiomarkerPanel",
                tableName: "longevity_biomarker_panels",
                summary: "Quantitative venous or cardiopulmonary biomarker assay with longevity optimal reference bounds.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"bio-apob\"", isIndexed: true, summary: "LOINC-aligned biomarker identifier."),
                    BlueprintEntityField(name: "loincCode", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"1884-6\"", isIndexed: true, summary: "Standard HL7 LOINC observation code."),
                    BlueprintEntityField(name: "markerName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Apolipoprotein B (ApoB)\"", summary: "Clinical assay title."),
                    BlueprintEntityField(name: "measuredValue", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "68.0", summary: "Assayed numeric concentration."),
                    BlueprintEntityField(name: "unit", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"mg/dL\"", summary: "UCUM clinical measurement unit."),
                    BlueprintEntityField(name: "optimalLower", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "40.0", summary: "Lower bound of longevity optimal decile."),
                    BlueprintEntityField(name: "optimalUpper", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "70.0", summary: "Upper bound of longevity optimal decile.")
                ],
                computedHelpersSwift: """
                public var isWithinOptimalZone: Bool {
                    measuredValue >= optimalLower && measuredValue <= optimalUpper
                }

                public var normalizedDeviationRatio: Double {
                    let span = max(0.001, optimalUpper - optimalLower)
                    if measuredValue < optimalLower {
                        return (measuredValue - optimalLower) / span
                    } else if measuredValue > optimalUpper {
                        return (measuredValue - optimalUpper) / span
                    }
                    return 0.0
                }
                """
            ),
            BlueprintDomainEntity(
                name: "CardioMetabolicSession",
                tableName: "cardio_metabolic_sessions",
                summary: "Zone 2 mitochondrial endurance or Zone 5 VO2Max interval training session.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"cardio-101\"", isIndexed: true, summary: "Workout record ID."),
                    BlueprintEntityField(name: "zoneClassification", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"ZONE_2_AEROBIC\"", isIndexed: true, summary: "ZONE_2_AEROBIC or ZONE_5_VO2MAX."),
                    BlueprintEntityField(name: "durationMinutes", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "45", summary: "Completed training duration in minutes."),
                    BlueprintEntityField(name: "averageHeartRateBPM", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "136", summary: "Mean optical/ECG strap heart rate."),
                    BlueprintEntityField(name: "bloodLactateMmol", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1.8", summary: "Capillary lactate in mmol/L (< 2.0 target for Zone 2).")
                ],
                computedHelpersSwift: """
                public var isTrueMitochondrialZone2: Bool {
                    zoneClassification == "ZONE_2_AEROBIC" && bloodLactateMmol >= 1.2 && bloodLactateMmol <= 2.0
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "biomarkers",
                swiftType: "[LongevityBiomarkerPanel]",
                initialValueLiteral: """
                [
                    LongevityBiomarkerPanel(id: "bio-apob", loincCode: "1884-6", markerName: "Apolipoprotein B (ApoB)", measuredValue: 66.0, unit: "mg/dL", optimalLower: 40.0, optimalUpper: 70.0),
                    LongevityBiomarkerPanel(id: "bio-hscrp", loincCode: "30522-7", markerName: "High-Sensitivity CRP", measuredValue: 0.65, unit: "mg/L", optimalLower: 0.1, optimalUpper: 1.0),
                    LongevityBiomarkerPanel(id: "bio-hba1c", loincCode: "4548-4", markerName: "Hemoglobin A1c", measuredValue: 5.1, unit: "%", optimalLower: 4.6, optimalUpper: 5.3),
                    LongevityBiomarkerPanel(id: "bio-vo2", loincCode: "80493-0", markerName: "VO2Max Cardiorespiratory", measuredValue: 51.4, unit: "mL/kg/min", optimalLower: 46.0, optimalUpper: 65.0)
                ]
                """,
                summary: "Tracked clinical longevity assays."
            ),
            BlueprintStateProperty(
                name: "sessions",
                swiftType: "[CardioMetabolicSession]",
                initialValueLiteral: """
                [
                    CardioMetabolicSession(id: "cardio-101", zoneClassification: "ZONE_2_AEROBIC", durationMinutes: 50, averageHeartRateBPM: 135, bloodLactateMmol: 1.7),
                    CardioMetabolicSession(id: "cardio-102", zoneClassification: "ZONE_5_VO2MAX", durationMinutes: 24, averageHeartRateBPM: 176, bloodLactateMmol: 6.4)
                ]
                """,
                summary: "Weekly Zone 2 and Zone 5 training log."
            ),
            BlueprintStateProperty(
                name: "chronologicalAgeYears",
                swiftType: "Double",
                initialValueLiteral: "38.0",
                summary: "Patient chronological age in years."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "recordBiomarkerResult(markerID: String, value: Double)",
                matchPattern: ".recordBiomarkerResult(let markerID, let value)",
                buttonTitle: "Log ApoB 62 mg/dL",
                sampleDispatchLiteral: ".recordBiomarkerResult(markerID: \"bio-apob\", value: 62.0)",
                summary: "Updates assayed biomarker value and recalculates phenotypic age delta.",
                mutationBodySwift: """
                guard value > 0, let idx = state.biomarkers.firstIndex(where: { $0.id == markerID }) else { break }
                state.biomarkers[idx].measuredValue = value
                state.lastAuditMessage = "Recorded \\(state.biomarkers[idx].markerName): \\(value) \\(state.biomarkers[idx].unit)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "logZone2Session(minutes: Int, heartRateBPM: Int, lactateMmol: Double)",
                matchPattern: ".logZone2Session(let minutes, let heartRateBPM, let lactateMmol)",
                buttonTitle: "Log 45m Zone 2",
                sampleDispatchLiteral: ".logZone2Session(minutes: 45, heartRateBPM: 134, lactateMmol: 1.6)",
                summary: "Appends an aerobic Zone 2 session toward the 180-minute weekly mitochondrial target.",
                mutationBodySwift: """
                let session = CardioMetabolicSession(
                    id: "cardio-\\(101 + state.sessions.count)",
                    zoneClassification: "ZONE_2_AEROBIC",
                    durationMinutes: max(5, minutes),
                    averageHeartRateBPM: heartRateBPM,
                    bloodLactateMmol: lactateMmol
                )
                state.sessions.insert(session, at: 0)
                state.lastAuditMessage = "Logged \\(session.durationMinutes)m Zone 2 session (lactate \\(lactateMmol) mmol/L)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchFHIRObservations",
                method: .get,
                path: "/v1/fhir/r4/Observation",
                responseType: "[LongevityBiomarkerPanel]",
                offlineStubSwift: "LongevityVitalsLabState().biomarkers",
                summary: "Imports LOINC-coded laboratory panels from HL7 FHIR R4 patient endpoint."
            ),
            BlueprintAPIEndpoint(
                methodName: "uploadEncryptedBiomarkerSnapshot",
                method: .post,
                path: "/v1/fhir/r4/Observation/batch",
                requestPayloadType: "[LongevityBiomarkerPanel]",
                responseType: "Bool",
                requiresIdempotencyKey: true,
                offlineStubSwift: "true",
                summary: "Uploads client-side HPKE-encrypted biomarker snapshot to clinician portal."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchCardioSessions",
                method: .get,
                path: "/v1/longevity/cardio-sessions",
                responseType: "[CardioMetabolicSession]",
                offlineStubSwift: "LongevityVitalsLabState().sessions",
                summary: "Retrieves synchronized ergometer and lactate meter sessions."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "phenoAge", label: "Phenotypic Age", value: "33.6 yrs", delta: "-4.4 yrs bio delta", sfSymbol: "sparkles"),
            BlueprintKPIMetric(key: "vo2max", label: "VO2Max Top Decile", value: "51.4", delta: "mL/kg/min", sfSymbol: "figure.run"),
            BlueprintKPIMetric(key: "apob", label: "ApoB Atherogenic", value: "66 mg/dL", delta: "Optimal < 70", sfSymbol: "drop.fill"),
            BlueprintKPIMetric(key: "zone2Weekly", label: "Weekly Zone 2", value: "50 / 180m", delta: "1.7 mmol/L", sfSymbol: "heart.circle.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "b-1", headline: "Apolipoprotein B (LOINC 1884-6)", subheadline: "Longevity target 40-70 mg/dL · Lipid particle count proxy", trailingMetric: "66 mg/dL", statusTag: "OPTIMAL"),
            BlueprintSampleRecord(id: "b-2", headline: "High-Sensitivity CRP (LOINC 30522-7)", subheadline: "Systemic vascular inflammation · Target < 1.0 mg/L", trailingMetric: "0.65 mg/L", statusTag: "OPTIMAL"),
            BlueprintSampleRecord(id: "b-3", headline: "VO2Max Cardiopulmonary Assay", subheadline: "95th age-adjusted percentile · Peak HR 184 BPM", trailingMetric: "51.4 mL/kg", statusTag: "ELITE")
        ],
        onboardingPages: [
            FlowPage(
                id: "enclave-consent",
                title: "HIPAA Zero-Cloud Enclave Storage",
                body: "All blood panels and HealthKit workouts remain encrypted inside your local SQLite vault.",
                style: "hero",
                actions: ["Enable Local Health Vault"]
            ),
            FlowPage(
                id: "longevity-targets",
                title: "Select Reference Percentile Protocol",
                body: "Compare lab assays against longevity medicine optimal deciles rather than population averages.",
                style: "choice",
                actions: ["Longevity Top Decile", "Standard Clinical"]
            ),
            FlowPage(
                id: "lab-ready",
                title: "Longevity Biomarker Lab Ready",
                body: "Phenotypic age modeling, Zone 2 lactate tracking, and Dynamic Type cards are live.",
                style: "completion",
                actions: ["Launch Longevity Lab"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "longevity.title", en: "Clinical Vitals & Longevity Lab", tr: "Klinik Bulgular ve Uzun Ömür Laboratuvarı"),
            BlueprintLocalizedKey(key: "longevity.pheno_age", en: "Estimated Phenotypic Age", tr: "Tahmini Biyolojik Yaş"),
            BlueprintLocalizedKey(key: "longevity.zone2", en: "Log Zone 2 Aerobic Session", tr: "Bölge 2 Aerobik Antrenman Ekle"),
            BlueprintLocalizedKey(key: "longevity.optimal", en: "Within Optimal Longevity Range", tr: "Optimal Uzun Ömür Aralığında"),
            BlueprintLocalizedKey(key: "longevity.fhir_export", en: "Export HL7 FHIR R4 Bundle", tr: "HL7 FHIR R4 Paketi Dışa Aktar"),
            BlueprintLocalizedKey(key: "longevity.lactate", en: "Capillary Lactate (mmol/L)", tr: "Kapiller Laktat (mmol/L)")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Tracks HL7 FHIR lab PDF/JSON import timestamps locally."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores preferred SI vs conventional clinical unit toggle."
            )
        ],
        customStateComputedSwift: """
        public var optimalBiomarkerCount: Int {
            biomarkers.filter(\\.isWithinOptimalZone).count
        }

        public var weeklyZone2Minutes: Int {
            sessions.filter { $0.zoneClassification == "ZONE_2_AEROBIC" }.reduce(0) { $0 + $1.durationMinutes }
        }

        public var estimatedPhenotypicAge: Double {
            let optimalBonus = Double(optimalBiomarkerCount) * 1.1
            let penalty = biomarkers.reduce(0.0) { $0 + max(0.0, $1.normalizedDeviationRatio) * 1.8 }
            return chronologicalAgeYears - optimalBonus + penalty
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Phenotypic Age & Mitochondrial Volume", systemImage: "heart.text.square.fill")
                    .font(.headline)
                Spacer()
                Text("\\(String(format: "%.1f", store.state.estimatedPhenotypicAge)) yrs")
                    .font(.subheadline.monospacedDigit().bold())
            }
            Text("Optimal Assays: \\(store.state.optimalBiomarkerCount)/\\(store.state.biomarkers.count) · Weekly Zone 2: \\(store.state.weeklyZone2Minutes)/180 min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let delta = state.estimatedPhenotypicAge - state.chronologicalAgeYears
        return String(format: "Biomarker Copilot: Phenotypic age delta %+.1f yrs; %d/%d markers in optimal decile; %d min Zone 2 logged.", delta, state.optimalBiomarkerCount, state.biomarkers.count, state.weeklyZone2Minutes)
        """,
        customUnitTestsSwift: """
        @Test("Optimal biomarker range evaluation and phenotypic age improvement")
        func biomarkerOptimalZoneAndPhenotypicAge() {
            var state = LongevityVitalsLabState()
            #expect(state.optimalBiomarkerCount == 4)
            #expect(state.estimatedPhenotypicAge < state.chronologicalAgeYears)

            _ = LongevityVitalsLabReducer.reduce(state: &state, action: .logZone2Session(minutes: 45, heartRateBPM: 134, lactateMmol: 1.7))
            #expect(state.weeklyZone2Minutes == 95)
        }
        """,
        securityPostureHighlights: [
            "Protected health observations stored with SQLite WAL + CompleteFileProtection entitlement.",
            "Zero third-party analytics SDKs; NSPrivacyTracking strictly false in PrivacyInfo.xcprivacy.",
            "Dynamic Type @ScaledMetric spacing guarantees WCAG accessibility at AX5 text sizes."
        ]
    )

    // MARK: 8. Circadian Sleep & HRV Recovery Coach

    public static let circadianSleepHRVCoach = EnterpriseBlueprintSpec(
        id: .circadianSleepHRVCoach,
        vertical: .healthBiometrics,
        title: "Circadian Sleep & HRV Coach",
        subtitle: "Nocturnal RMSSD autonomic readiness zones, SWS/REM hypnogram efficiency, and circadian light-phase windows.",
        sfSymbol: "moon.zzz.fill",
        complexityTier: .professional,
        supportedPlatforms: [.iOS, .watchOS, .iPadOS, .macOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "NocturnalSleepSummary",
                tableName: "nocturnal_sleep_summaries",
                summary: "Overnight autonomic HRV RMSSD and polysomnography-equivalent stage architecture.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"slp-2026-11-14\"", isIndexed: true, summary: "ISO date night key."),
                    BlueprintEntityField(name: "deepSWSMinutes", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "98", summary: "Slow-wave restorative N3 sleep minutes."),
                    BlueprintEntityField(name: "remMinutes", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "112", summary: "REM cognitive consolidation minutes."),
                    BlueprintEntityField(name: "coreLightMinutes", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "235", summary: "N1/N2 core light sleep minutes."),
                    BlueprintEntityField(name: "awakeMinutes", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "26", summary: "WASO wake-after-sleep-onset minutes."),
                    BlueprintEntityField(name: "rmssdMillis", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "74.5", summary: "Nocturnal vagal heart-rate variability RMSSD in ms."),
                    BlueprintEntityField(name: "restingHeartRateBPM", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "48.0", summary: "Sleeping nadir heart rate BPM.")
                ],
                computedHelpersSwift: """
                public var totalAsleepMinutes: Int {
                    deepSWSMinutes + remMinutes + coreLightMinutes
                }

                public var totalInBedMinutes: Int {
                    totalAsleepMinutes + awakeMinutes
                }

                public var sleepEfficiencyPercent: Double {
                    guard totalInBedMinutes > 0 else { return 0 }
                    return (Double(totalAsleepMinutes) / Double(totalInBedMinutes)) * 100.0
                }

                public var restorativeRatioPercent: Double {
                    guard totalAsleepMinutes > 0 else { return 0 }
                    return (Double(deepSWSMinutes + remMinutes) / Double(totalAsleepMinutes)) * 100.0
                }
                """
            ),
            BlueprintDomainEntity(
                name: "CircadianPhaseAnchor",
                tableName: "circadian_phase_anchors",
                summary: "Suprachiasmatic nucleus (SCN) light exposure and melatonin onset anchor schedule.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"phase-today\"", isIndexed: true, summary: "Anchor schedule ID."),
                    BlueprintEntityField(name: "wakeMinuteOfDay", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "405", summary: "Wake time in minutes since midnight (06:45 = 405)."),
                    BlueprintEntityField(name: "morningOutdoorLuxMinutes", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "15", summary: "Completed >10,000 lux outdoor sunlight minutes."),
                    BlueprintEntityField(name: "caffeineCutoffMinuteOfDay", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "810", summary: "Adenosine clearance cutoff minute (13:30 = 810).")
                ],
                computedHelpersSwift: """
                public var dlmoMelatoninWindowMinute: Int {
                    (wakeMinuteOfDay + 14 * 60) % 1440
                }

                public var hasAnchoredMorningSunlight: Bool {
                    morningOutdoorLuxMinutes >= 15
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "nights",
                swiftType: "[NocturnalSleepSummary]",
                initialValueLiteral: """
                [
                    NocturnalSleepSummary(id: "2026-11-14", deepSWSMinutes: 98, remMinutes: 112, coreLightMinutes: 235, awakeMinutes: 26, rmssdMillis: 78.2, restingHeartRateBPM: 47.0),
                    NocturnalSleepSummary(id: "2026-11-13", deepSWSMinutes: 84, remMinutes: 104, coreLightMinutes: 242, awakeMinutes: 34, rmssdMillis: 69.4, restingHeartRateBPM: 49.5)
                ]
                """,
                summary: "Rolling nocturnal HRV and sleep stage logs."
            ),
            BlueprintStateProperty(
                name: "baselineRMSSD",
                swiftType: "Double",
                initialValueLiteral: "71.0",
                summary: "Rolling 60-day vagal RMSSD baseline in milliseconds."
            ),
            BlueprintStateProperty(
                name: "phaseAnchor",
                swiftType: "CircadianPhaseAnchor",
                initialValueLiteral: "CircadianPhaseAnchor()",
                summary: "Active circadian sunlight and DLMO anchor schedule."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "ingestOvernightSummary(night: NocturnalSleepSummary)",
                matchPattern: ".ingestOvernightSummary(let night)",
                buttonTitle: "Sync Last Night HRV",
                sampleDispatchLiteral: ".ingestOvernightSummary(night: NocturnalSleepSummary(id: \"2026-11-15\", deepSWSMinutes: 104, remMinutes: 118, coreLightMinutes: 228, awakeMinutes: 20, rmssdMillis: 82.6, restingHeartRateBPM: 46.0))",
                summary: "Ingests overnight sleep stages and updates rolling exponentially weighted RMSSD baseline.",
                mutationBodySwift: """
                state.nights.removeAll { $0.id == night.id }
                state.nights.insert(night, at: 0)
                state.baselineRMSSD = (state.baselineRMSSD * 0.90) + (night.rmssdMillis * 0.10)
                state.lastAuditMessage = "Synced night \\(night.id): RMSSD \\(String(format: "%.1f", night.rmssdMillis)) ms"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "logMorningSunlight(minutes: Int)",
                matchPattern: ".logMorningSunlight(let minutes)",
                buttonTitle: "Log +10m Morning Lux",
                sampleDispatchLiteral: ".logMorningSunlight(minutes: 10)",
                summary: "Increments outdoor morning sunlight exposure to anchor circadian cortisol peak.",
                mutationBodySwift: """
                state.phaseAnchor.morningOutdoorLuxMinutes += max(1, minutes)
                state.lastAuditMessage = "Morning outdoor light: \\(state.phaseAnchor.morningOutdoorLuxMinutes) mins"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchSleepSummaries",
                method: .get,
                path: "/v1/biometrics/sleep/summaries",
                responseType: "[NocturnalSleepSummary]",
                offlineStubSwift: "CircadianHRVCoachState().nights",
                summary: "Fetches longitudinal nocturnal HRV and hypnogram records."
            ),
            BlueprintAPIEndpoint(
                methodName: "syncCircadianAnchor",
                method: .put,
                path: "/v1/biometrics/circadian/anchor",
                requestPayloadType: "CircadianPhaseAnchor",
                responseType: "CircadianPhaseAnchor",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Synchronizes circadian wake and DLMO schedule across watchOS complications."
            ),
            BlueprintAPIEndpoint(
                methodName: "exportReadinessTrend",
                method: .post,
                path: "/v1/biometrics/hrv/export",
                requestPayloadType: "[NocturnalSleepSummary]",
                responseType: "Bool",
                offlineStubSwift: "true",
                summary: "Exports anonymized autonomic readiness CSV/JSON archive."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "rmssd", label: "Nocturnal RMSSD", value: "78.2 ms", delta: "+10.1% vs 60d", sfSymbol: "waveform.path.ecg"),
            BlueprintKPIMetric(key: "efficiency", label: "Sleep Efficiency", value: "94.5%", delta: "7h 25m asleep", sfSymbol: "bed.double.fill"),
            BlueprintKPIMetric(key: "swsRem", label: "SWS + REM Share", value: "47.2%", delta: "3h 30m restorative", sfSymbol: "sparkles"),
            BlueprintKPIMetric(key: "rhr", label: "Nadir Sleeping HR", value: "47 BPM", delta: "Green Recovery", sfSymbol: "heart.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "slp-1", headline: "Night 2026-11-14 · Green Parasympathetic Peak", subheadline: "SWS 1h 38m · REM 1h 52m · WASO 26m", trailingMetric: "78.2 ms", statusTag: "PEAK READY"),
            BlueprintSampleRecord(id: "slp-2", headline: "Night 2026-11-13 · Nominal Baseline", subheadline: "SWS 1h 24m · REM 1h 44m · WASO 34m", trailingMetric: "69.4 ms", statusTag: "BALANCED"),
            BlueprintSampleRecord(id: "anc-1", headline: "Circadian SCN Phase Schedule", subheadline: "Wake 06:45 · Caffeine cutoff 13:30 · DLMO 20:45", trailingMetric: "15m Lux", statusTag: "ANCHORED")
        ],
        onboardingPages: [
            FlowPage(
                id: "watch-sensor",
                title: "Connect Apple Watch Tachogram & Sleep Stages",
                body: "Compute nocturnal RMSSD and SWS/REM restorative ratios locally on device.",
                style: "hero",
                actions: ["Authorize Sleep Metrics"]
            ),
            FlowPage(
                id: "wake-anchor",
                title: "Set Consistent Circadian Wake Time",
                body: "Anchor morning outdoor photon exposure and 14-hour DLMO wind-down window.",
                style: "choice",
                actions: ["06:30 Early Chronotype", "07:30 Standard Chronotype"]
            ),
            FlowPage(
                id: "hrv-coach-ready",
                title: "Circadian HRV Coach Active",
                body: "Autonomic recovery zones and strain ceilings are ready for today.",
                style: "completion",
                actions: ["Start Recovery Coach"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "hrv.title", en: "Circadian Sleep & HRV Coach", tr: "Sirkadiyen Uyku ve HRV Koçu"),
            BlueprintLocalizedKey(key: "hrv.readiness_zone", en: "Autonomic Readiness Zone", tr: "Otonom Hazırlık Bölgesi"),
            BlueprintLocalizedKey(key: "hrv.morning_lux", en: "Morning Outdoor Sunlight", tr: "Sabah Doğal Gün Işığı"),
            BlueprintLocalizedKey(key: "hrv.efficiency", en: "Sleep Architecture Efficiency", tr: "Uyku Mimarisi Verimliliği"),
            BlueprintLocalizedKey(key: "hrv.dlmo", en: "Melatonin Onset Window", tr: "Melatonin Başlangıç Penceresi"),
            BlueprintLocalizedKey(key: "hrv.sync_watch", en: "Sync Overnight HRV", tr: "Gece HRV Verisini Eşitle")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores wake-up alarm window and chronotype offset locally."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Measures morning light timer intervals accurately."
            )
        ],
        customStateComputedSwift: """
        public var latestRMSSD: Double {
            nights.first?.rmssdMillis ?? baselineRMSSD
        }

        public var recoveryReadinessZone: String {
            let ratio = latestRMSSD / max(1.0, baselineRMSSD)
            if ratio >= 1.05 { return "GREEN_PEAK" }
            if ratio >= 0.90 { return "AMBER_NOMINAL" }
            return "RED_DELOAD"
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Parasympathetic Recovery Zone", systemImage: "bolt.heart.fill")
                    .font(.headline)
                Spacer()
                Text(store.state.recoveryReadinessZone)
                    .font(.caption.monospaced().bold())
            }
            Text("Latest RMSSD: \\(String(format: "%.1f", store.state.latestRMSSD)) ms vs 60d Baseline \\(String(format: "%.1f", store.state.baselineRMSSD)) ms")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let eff = state.nights.first?.sleepEfficiencyPercent ?? 0
        return String(format: "Circadian Copilot: Zone %@, sleep efficiency %.1f%%, morning lux %dm.", state.recoveryReadinessZone, eff, state.phaseAnchor.morningOutdoorLuxMinutes)
        """,
        customUnitTestsSwift: """
        @Test("Sleep efficiency math and HRV recovery zone classification")
        func sleepEfficiencyAndHRVZone() {
            var state = CircadianHRVCoachState()
            #expect(state.nights[0].sleepEfficiencyPercent > 94.0)
            #expect(state.recoveryReadinessZone == "GREEN_PEAK")

            let deloadNight = NocturnalSleepSummary(id: "2026-11-15", deepSWSMinutes: 50, remMinutes: 60, coreLightMinutes: 250, awakeMinutes: 55, rmssdMillis: 52.0, restingHeartRateBPM: 56.0)
            _ = CircadianHRVCoachReducer.reduce(state: &state, action: .ingestOvernightSummary(night: deloadNight))
            #expect(state.recoveryReadinessZone == "RED_DELOAD")
        }
        """,
        securityPostureHighlights: [
            "Raw beat-to-beat R-R intervals processed exclusively in memory and never transmitted.",
            "Watch-to-phone sync payloads signed per session.",
            "WCAG high-contrast badges ensure legibility in low-lux bedroom environments."
        ]
    )

    // MARK: 9. Telemedicine & Encrypted Prescription Vault

    public static let telemedicinePrescriptionVault = EnterpriseBlueprintSpec(
        id: .telemedicinePrescriptionVault,
        vertical: .healthBiometrics,
        title: "Telemedicine & Prescription Vault",
        subtitle: "RxNorm medication adherence schedules, refill runway alerts, interaction checks, and HIPAA local vaulting.",
        sfSymbol: "cross.case.fill",
        complexityTier: .enterprise,
        supportedPlatforms: [.iOS, .iPadOS, .macOS, .watchOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "MedicationRegimenPrescription",
                tableName: "medication_regimen_prescriptions",
                summary: "Active e-prescription with RxNorm code, daily dosing frequency, pill inventory, and adherence streak.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"rx-501\"", isIndexed: true, summary: "Prescription vault ID."),
                    BlueprintEntityField(name: "rxNormCode", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"860975\"", isIndexed: true, summary: "National Library of Medicine RxNorm CUI."),
                    BlueprintEntityField(name: "medicationTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Rosuvastatin Calcium 10 mg\"", summary: "Generic + strength display title."),
                    BlueprintEntityField(name: "dosesPerDay", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1", summary: "Scheduled intakes per 24 hours."),
                    BlueprintEntityField(name: "remainingUnits", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "24", summary: "Remaining tablets/capsules in bottle."),
                    BlueprintEntityField(name: "refillsAuthorized", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "3", summary: "Remaining clinician-authorized pharmacy refills."),
                    BlueprintEntityField(name: "adherenceStreakDays", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "19", summary: "Consecutive days of 100% scheduled intake.")
                ],
                computedHelpersSwift: """
                public var daysOfSupplyRemaining: Int {
                    guard dosesPerDay > 0 else { return remainingUnits }
                    return remainingUnits / dosesPerDay
                }

                public var needsPharmacyRefillSoon: Bool {
                    daysOfSupplyRemaining <= 7
                }
                """
            ),
            BlueprintDomainEntity(
                name: "TelehealthConsultNote",
                tableName: "telehealth_consult_notes",
                summary: "End-to-end encrypted clinician SOAP encounter note with follow-up action items.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"enc-88\"", isIndexed: true, summary: "Encounter ID."),
                    BlueprintEntityField(name: "clinicianName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Dr. Selin Kaya, MD, FACC\"", summary: "Attending physician."),
                    BlueprintEntityField(name: "specialty", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Preventive Cardiology\"", summary: "Clinical specialty."),
                    BlueprintEntityField(name: "assessmentSummary", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Lipid panel well controlled; continue evening statin regimen.\"", summary: "Decrypted clinical plan summary."),
                    BlueprintEntityField(name: "isAcknowledgedByPatient", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "true", summary: "True once patient reviews post-visit instructions.")
                ],
                computedHelpersSwift: """
                public var requiresPatientSignature: Bool {
                    !isAcknowledgedByPatient
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "prescriptions",
                swiftType: "[MedicationRegimenPrescription]",
                initialValueLiteral: """
                [
                    MedicationRegimenPrescription(id: "rx-501", rxNormCode: "860975", medicationTitle: "Rosuvastatin Calcium 10 mg", dosesPerDay: 1, remainingUnits: 24, refillsAuthorized: 3, adherenceStreakDays: 28),
                    MedicationRegimenPrescription(id: "rx-502", rxNormCode: "861007", medicationTitle: "Metformin ER 500 mg", dosesPerDay: 2, remainingUnits: 10, refillsAuthorized: 2, adherenceStreakDays: 14)
                ]
                """,
                summary: "Active medication regimens in encrypted patient vault."
            ),
            BlueprintStateProperty(
                name: "consultNotes",
                swiftType: "[TelehealthConsultNote]",
                initialValueLiteral: """
                [
                    TelehealthConsultNote(id: "enc-88", clinicianName: "Dr. Selin Kaya, MD", specialty: "Preventive Cardiology", assessmentSummary: "ApoB target achieved with zero myalgia; recheck CMP in 6 months.", isAcknowledgedByPatient: false)
                ]
                """,
                summary: "Encrypted telemedicine SOAP visit summaries."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "logDoseTaken(prescriptionID: String)",
                matchPattern: ".logDoseTaken(let prescriptionID)",
                buttonTitle: "Log Dose Taken",
                sampleDispatchLiteral: ".logDoseTaken(prescriptionID: \"rx-501\")",
                summary: "Decrements remaining pill inventory and increments adherence streak.",
                mutationBodySwift: """
                guard let idx = state.prescriptions.firstIndex(where: { $0.id == prescriptionID }),
                      state.prescriptions[idx].remainingUnits > 0 else { break }
                state.prescriptions[idx].remainingUnits -= 1
                state.prescriptions[idx].adherenceStreakDays += 1
                state.lastAuditMessage = "Logged dose for \\(state.prescriptions[idx].medicationTitle)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "dispensePharmacyRefill(prescriptionID: String, dispensedUnits: Int)",
                matchPattern: ".dispensePharmacyRefill(let prescriptionID, let dispensedUnits)",
                buttonTitle: "Refill Low Rx (+60)",
                sampleDispatchLiteral: ".dispensePharmacyRefill(prescriptionID: \"rx-502\", dispensedUnits: 60)",
                summary: "Consumes one authorized refill and replenishes bottle unit count.",
                mutationBodySwift: """
                guard dispensedUnits > 0,
                      let idx = state.prescriptions.firstIndex(where: { $0.id == prescriptionID }),
                      state.prescriptions[idx].refillsAuthorized > 0 else { break }
                state.prescriptions[idx].refillsAuthorized -= 1
                state.prescriptions[idx].remainingUnits += dispensedUnits
                state.lastAuditMessage = "Dispensed +\\(dispensedUnits) units for \\(state.prescriptions[idx].medicationTitle)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "acknowledgeConsultNote(encounterID: String)",
                matchPattern: ".acknowledgeConsultNote(let encounterID)",
                summary: "Marks post-visit telemedicine care plan reviewed by patient.",
                mutationBodySwift: """
                guard let idx = state.consultNotes.firstIndex(where: { $0.id == encounterID }) else { break }
                state.consultNotes[idx].isAcknowledgedByPatient = true
                state.lastAuditMessage = "Acknowledged consult note \\(encounterID)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchActivePrescriptions",
                method: .get,
                path: "/v1/telehealth/rx/active",
                responseType: "[MedicationRegimenPrescription]",
                offlineStubSwift: "TelemedicineRxVaultState().prescriptions",
                summary: "Loads active NCPDP SCRIPT / FHIR MedicationRequest records."
            ),
            BlueprintAPIEndpoint(
                methodName: "requestPharmacyRefill",
                method: .post,
                path: "/v1/telehealth/rx/refill",
                requestPayloadType: "MedicationRegimenPrescription",
                responseType: "MedicationRegimenPrescription",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Submits signed pharmacy refill fulfillment order."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchEncryptedConsults",
                method: .get,
                path: "/v1/telehealth/encounters",
                responseType: "[TelehealthConsultNote]",
                offlineStubSwift: "TelemedicineRxVaultState().consultNotes",
                summary: "Retrieves E2EE clinician SOAP summaries."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "adherence", label: "30d Rx Adherence", value: "98.4%", delta: "28d peak streak", sfSymbol: "pills.fill"),
            BlueprintKPIMetric(key: "refillDue", label: "Refill Runway Alert", value: "1 Rx <= 7d", delta: "Metformin 5d left", sfSymbol: "exclamationmark.triangle.fill"),
            BlueprintKPIMetric(key: "interactions", label: "RxNorm DDI Screen", value: "0 Conflicts", delta: "Verified locally", sfSymbol: "checkmark.shield.fill"),
            BlueprintKPIMetric(key: "vaultMode", label: "HIPAA Enclave", value: "AES-256-GCM", delta: "Biometric lock", sfSymbol: "lock.rotation")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "rx-1", headline: "Rosuvastatin Calcium 10 mg · RxNorm 860975", subheadline: "1 tablet nightly · 3 refills authorized · 28d streak", trailingMetric: "24 days left", statusTag: "ON TRACK"),
            BlueprintSampleRecord(id: "rx-2", headline: "Metformin ER 500 mg · RxNorm 861007", subheadline: "1 tablet twice daily with meals · 2 refills left", trailingMetric: "5 days left", statusTag: "REFILL DUE"),
            BlueprintSampleRecord(id: "enc-1", headline: "Dr. Selin Kaya, MD · Preventive Cardiology", subheadline: "SOAP Care Plan: Continue regimen, recheck CMP in 6m", trailingMetric: "E2EE Sealed", statusTag: "UNREAD")
        ],
        onboardingPages: [
            FlowPage(
                id: "biometric-gate",
                title: "Protect Prescription Vault with Face ID / Touch ID",
                body: "Wrap local SQLite medication schedules and clinician notes behind LocalAuthentication.",
                style: "hero",
                actions: ["Enable Biometric Lock"]
            ),
            FlowPage(
                id: "dose-reminders",
                title: "Configure Local Time-Sensitive Dose Alerts",
                body: "Schedule on-device UNNotification reminders without sharing medication names with push servers.",
                style: "choice",
                actions: ["Discreet Privacy Banner", "Detailed Dose Card"]
            ),
            FlowPage(
                id: "rx-vault-ready",
                title: "Telemedicine Rx Vault Provisioned",
                body: "RxNorm adherence tracking and refill runway alerts are active.",
                style: "completion",
                actions: ["Complete Vault Setup"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "rx.title", en: "Telemedicine & Prescription Vault", tr: "Teletıp ve Şifreli Reçete Kasası"),
            BlueprintLocalizedKey(key: "rx.log_dose", en: "Record Scheduled Dose", tr: "Planlanan Dozu Kaydet"),
            BlueprintLocalizedKey(key: "rx.request_refill", en: "Order Pharmacy Refill", tr: "Eczane Yenileme Talebi Gönder"),
            BlueprintLocalizedKey(key: "rx.days_supply", en: "Days of Supply Remaining", tr: "Kalan İlaç Gün Sayısı"),
            BlueprintLocalizedKey(key: "rx.soap_note", en: "Encrypted Physician Note", tr: "Şifreli Hekim Muayene Notu"),
            BlueprintLocalizedKey(key: "rx.discreet_mode", en: "Privacy-Masked Notifications", tr: "Gizlilik Maskeli Bildirimler")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Audits encrypted prescription backup timestamps."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Persists discreet notification masking preference."
            )
        ],
        customStateComputedSwift: """
        public var prescriptionsNeedingRefill: [MedicationRegimenPrescription] {
            prescriptions.filter(\\.needsPharmacyRefillSoon)
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Pharmacy Refill Runway Monitor", systemImage: "pills.circle.fill")
                    .font(.headline)
                Spacer()
                Text("\\(store.state.prescriptionsNeedingRefill.count) Due Soon")
                    .font(.caption.monospaced().bold())
            }
            ForEach(store.state.prescriptions) { rx in
                HStack {
                    Text(rx.medicationTitle)
                        .font(.caption)
                    Spacer()
                    Text("\\(rx.daysOfSupplyRemaining)d supply (\\(rx.remainingUnits) units)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let lowCount = state.prescriptionsNeedingRefill.count
        let unread = state.consultNotes.filter(\\.requiresPatientSignature).count
        return "Rx Vault Copilot: \\(lowCount) regimen(s) have <= 7 days supply; \\(unread) clinician note(s) awaiting review."
        """,
        customUnitTestsSwift: """
        @Test("Dose logging decrements inventory and pharmacy refill restores >7 day supply")
        func rxRunwayAndRefillFlow() {
            var state = TelemedicineRxVaultState()
            #expect(state.prescriptions[1].needsPharmacyRefillSoon == true)
            _ = TelemedicineRxVaultReducer.reduce(
                state: &state,
                action: .dispensePharmacyRefill(prescriptionID: "rx-502", dispensedUnits: 60)
            )
            #expect(state.prescriptions[1].daysOfSupplyRemaining == 35)
            #expect(state.prescriptions[1].needsPharmacyRefillSoon == false)
        }
        """,
        securityPostureHighlights: [
            "Medication titles masked on lock-screen notifications to prevent shoulder-surfing PHI exposure.",
            "Idempotent refill authorization keys prevent double-dispensing across pharmacy networks.",
            "Full VoiceOver accessibility traits and Dynamic Type layouts for elderly patient usability."
        ]
    )
}
