import ChiefKitStudioCore
import Foundation

// MARK: - Vertical 4: Spatial Commerce & Cold-Chain Logistics Blueprints

public enum CommerceAndLogisticsBlueprints: Sendable {
    public static let specs: [EnterpriseBlueprintSpec] = [
        spatialLuxuryStorefrontAR,
        coldChainFleetTelemetry,
        posKitchenDisplaySystem
    ]

    // MARK: 10. Spatial Luxury Storefront & AR Configurator

    public static let spatialLuxuryStorefrontAR = EnterpriseBlueprintSpec(
        id: .spatialLuxuryStorefrontAR,
        vertical: .commerceLogistics,
        title: "Spatial Luxury Storefront AR",
        subtitle: "visionOS volumetric USDZ product atelier, PBR material ornament configurator, and boutique inventory reservation.",
        sfSymbol: "arkit",
        complexityTier: .enterprise,
        supportedPlatforms: [.visionOS, .iPadOS, .iOS, .macOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "SpatialAtelierPiece",
                tableName: "spatial_atelier_pieces",
                summary: "Room-scale 1:1 calibrated USDZ luxury timepiece or furniture piece with PBR shader budget.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"pcs-chronograph-01\"", isIndexed: true, summary: "Unique SKU identifier."),
                    BlueprintEntityField(name: "collectionTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Tourbillon Calibre IX\"", summary: "Haute horlogerie or bespoke piece name."),
                    BlueprintEntityField(name: "usdzAssetName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"TourbillonCalibreIX_LOD0.usdz\"", summary: "RealityKit USDZ resource name."),
                    BlueprintEntityField(name: "basePriceEUR", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "48500", summary: "Base atelier price in EUR."),
                    BlueprintEntityField(name: "finishSurchargeEUR", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "4200", summary: "Selected bespoke material surcharge in EUR."),
                    BlueprintEntityField(name: "boutiqueAvailableUnits", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "3", summary: "Global numbered edition units available."),
                    BlueprintEntityField(name: "worldScaleMultiplier", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1.0", summary: "1.0 = true physical millimeter scale; >1.0 = exploded movement inspection.")
                ],
                computedHelpersSwift: """
                public var configuredTotalEUR: Int {
                    basePriceEUR + max(0, finishSurchargeEUR)
                }

                public var isLimitedAllocationAvailable: Bool {
                    boutiqueAvailableUnits > 0
                }
                """
            ),
            BlueprintDomainEntity(
                name: "PBRMaterialOrnamentOption",
                tableName: "pbr_material_ornament_options",
                summary: "Physically based rendering metallic/roughness material swatch selectable from visionOS glass ornament.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"mat-rose-gold\"", isIndexed: true, summary: "Shader preset ID."),
                    BlueprintEntityField(name: "finishLabel", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"18k Brushed Rose Gold\"", summary: "Client-facing finish title."),
                    BlueprintEntityField(name: "metallicFactor", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.96", summary: "PBR metallic channel [0, 1]."),
                    BlueprintEntityField(name: "roughnessFactor", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.18", summary: "PBR micro-surface roughness [0, 1]."),
                    BlueprintEntityField(name: "surchargeEUR", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "4200", summary: "Incremental bespoke price delta in EUR.")
                ],
                computedHelpersSwift: """
                public var isMirrorPolished: Bool {
                    metallicFactor >= 0.90 && roughnessFactor <= 0.12
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "catalogPieces",
                swiftType: "[SpatialAtelierPiece]",
                initialValueLiteral: """
                [
                    SpatialAtelierPiece(id: "pcs-tourbillon", collectionTitle: "Tourbillon Calibre IX", usdzAssetName: "CalibreIX.usdz", basePriceEUR: 48_500, finishSurchargeEUR: 4_200, boutiqueAvailableUnits: 3, worldScaleMultiplier: 1.0),
                    SpatialAtelierPiece(id: "pcs-lounge", collectionTitle: "atelier-04 Sculpted Walnut Lounge", usdzAssetName: "WalnutLounge.usdz", basePriceEUR: 12_800, finishSurchargeEUR: 950, boutiqueAvailableUnits: 5, worldScaleMultiplier: 1.0)
                ]
                """,
                summary: "Volumetric luxury pieces loaded in spatial showroom."
            ),
            BlueprintStateProperty(
                name: "swatches",
                swiftType: "[PBRMaterialOrnamentOption]",
                initialValueLiteral: """
                [
                    PBRMaterialOrnamentOption(id: "mat-titanium", finishLabel: "Grade 5 Bead-Blasted Titanium", metallicFactor: 0.88, roughnessFactor: 0.32, surchargeEUR: 0),
                    PBRMaterialOrnamentOption(id: "mat-rose-gold", finishLabel: "18k Brushed Rose Gold", metallicFactor: 0.96, roughnessFactor: 0.18, surchargeEUR: 4_200),
                    PBRMaterialOrnamentOption(id: "mat-platinum", finishLabel: "950 Mirror Platinum", metallicFactor: 0.99, roughnessFactor: 0.08, surchargeEUR: 9_600)
                ]
                """,
                summary: "Selectable visionOS ornament PBR shader swatches."
            ),
            BlueprintStateProperty(
                name: "selectedSwatchID",
                swiftType: "String",
                initialValueLiteral: "\"mat-rose-gold\"",
                summary: "Currently active PBR swatch applied to primary volumetric model."
            ),
            BlueprintStateProperty(
                name: "reservedPieceIDs",
                swiftType: "[String]",
                initialValueLiteral: "[]",
                summary: "Private client concierge reservations placed in current session."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "applyMaterialSwatch(pieceID: String, swatchID: String)",
                matchPattern: ".applyMaterialSwatch(let pieceID, let swatchID)",
                buttonTitle: "Apply 950 Platinum Swatch",
                sampleDispatchLiteral: ".applyMaterialSwatch(pieceID: \"pcs-tourbillon\", swatchID: \"mat-platinum\")",
                summary: "Binds PBR shader parameters from selected ornament swatch and updates piece pricing.",
                mutationBodySwift: """
                guard let pIdx = state.catalogPieces.firstIndex(where: { $0.id == pieceID }),
                      let swatch = state.swatches.first(where: { $0.id == swatchID }) else { break }
                state.selectedSwatchID = swatchID
                state.catalogPieces[pIdx].finishSurchargeEUR = swatch.surchargeEUR
                state.lastAuditMessage = "Applied \\(swatch.finishLabel) (+€\\(swatch.surchargeEUR))"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "reserveBoutiqueEdition(pieceID: String)",
                matchPattern: ".reserveBoutiqueEdition(let pieceID)",
                buttonTitle: "Reserve Numbered Piece",
                sampleDispatchLiteral: ".reserveBoutiqueEdition(pieceID: \"pcs-tourbillon\")",
                summary: "Locks one numbered boutique allocation and appends private concierge hold.",
                mutationBodySwift: """
                guard let idx = state.catalogPieces.firstIndex(where: { $0.id == pieceID }),
                      state.catalogPieces[idx].boutiqueAvailableUnits > 0 else {
                    state.lastAuditMessage = "Allocation exhausted for \\(pieceID)"
                    break
                }
                state.catalogPieces[idx].boutiqueAvailableUnits -= 1
                state.reservedPieceIDs.append(pieceID)
                state.lastAuditMessage = "Reserved numbered allocation for \\(state.catalogPieces[idx].collectionTitle)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "setExplodedInspectionScale(pieceID: String, multiplier: Double)",
                matchPattern: ".setExplodedInspectionScale(let pieceID, let multiplier)",
                summary: "Adjusts volumetric scale between 1.0x true-to-life and 6.0x horological movement inspection.",
                mutationBodySwift: """
                guard let idx = state.catalogPieces.firstIndex(where: { $0.id == pieceID }) else { break }
                state.catalogPieces[idx].worldScaleMultiplier = min(max(multiplier, 0.5), 8.0)
                state.lastAuditMessage = "Set volumetric scale to \\(state.catalogPieces[idx].worldScaleMultiplier)x"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchSpatialCatalog",
                method: .get,
                path: "/v1/atelier/spatial-pieces",
                responseType: "[SpatialAtelierPiece]",
                offlineStubSwift: "SpatialLuxuryAtelierState().catalogPieces",
                summary: "Loads USDZ luxury catalog metadata and real-time Geneva/Paris boutique stock."
            ),
            BlueprintAPIEndpoint(
                methodName: "createConciergeReservation",
                method: .post,
                path: "/v1/atelier/reservations",
                requestPayloadType: "SpatialAtelierPiece",
                responseType: "SpatialAtelierPiece",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Places 48-hour numbered edition hold with Apple Pay / private client concierge."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchPBRSwatches",
                method: .get,
                path: "/v1/atelier/pbr-swatches",
                responseType: "[PBRMaterialOrnamentOption]",
                offlineStubSwift: "SpatialLuxuryAtelierState().swatches",
                summary: "Fetches calibrated HDRI/PBR finish definitions."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "activeConfigPrice", label: "Configured Bespoke Total", value: "€52,700", delta: "18k Rose Gold", sfSymbol: "eurosign.circle.fill"),
            BlueprintKPIMetric(key: "frameBudget", label: "visionOS 90Hz Budget", value: "8.4 ms", delta: "LOD0 120k tris", sfSymbol: "visionpro"),
            BlueprintKPIMetric(key: "allocations", label: "Geneva Vault Stock", value: "3 Numbered", delta: "Calibre IX", sfSymbol: "seal.fill"),
            BlueprintKPIMetric(key: "anchorError", label: "Plane Anchor Drift", value: "< 0.8 mm", delta: "1:1 True Scale", sfSymbol: "ruler.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "ar-1", headline: "Tourbillon Calibre IX · USDZ Volumetric", subheadline: "18k Brushed Rose Gold · 3 numbered editions remaining", trailingMetric: "€52,700", statusTag: "1:1 READY"),
            BlueprintSampleRecord(id: "ar-2", headline: "atelier-04 Sculpted Walnut Lounge", subheadline: "Full-grain saddle leather + oiled walnut · Room-anchor ready", trailingMetric: "€13,750", statusTag: "IN STOCK"),
            BlueprintSampleRecord(id: "ar-3", headline: "950 Mirror Platinum Ornament Swatch", subheadline: "Metallic 0.99 · Roughness 0.08 · Bespoke +€9,600", trailingMetric: "PBR Shader", statusTag: "AVAILABLE")
        ],
        onboardingPages: [
            FlowPage(
                id: "spatial-scan",
                title: "Calibrate Ambient Studio Lighting",
                body: "Match RealityKit IBL reflections to your room illumination without capturing camera frames.",
                style: "hero",
                actions: ["Calibrate Reflections"]
            ),
            FlowPage(
                id: "ornament-mode",
                title: "Choose Spatial Inspection Mode",
                body: "Switch seamlessly between 1:1 tabletop placement and 6x exploded calibre inspection.",
                style: "choice",
                actions: ["1:1 Boutique Scale", "6x Horology Macro"]
            ),
            FlowPage(
                id: "atelier-ready",
                title: "Spatial Luxury Atelier Ready",
                body: "Floating Liquid Glass material ornaments and instant concierge holds are live.",
                style: "completion",
                actions: ["Launch Spatial Atelier"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "atelier.title", en: "Spatial Luxury Storefront AR", tr: "Uzamsal Lüks Mağaza ve AR Atölyesi"),
            BlueprintLocalizedKey(key: "atelier.apply_finish", en: "Apply Bespoke Finish", tr: "Özel Yüzey Kaplamasını Uygula"),
            BlueprintLocalizedKey(key: "atelier.reserve", en: "Reserve Numbered Edition", tr: "Numaralı Özel Üretimi Ayırt"),
            BlueprintLocalizedKey(key: "atelier.true_scale", en: "1:1 Physical Scale", tr: "1:1 Gerçek Fiziksel Ölçek"),
            BlueprintLocalizedKey(key: "atelier.exploded_view", en: "Exploded Calibre Macro", tr: "Patlatılmış Mekanizma Görünümü"),
            BlueprintLocalizedKey(key: "atelier.concierge", en: "Private Boutique Concierge", tr: "Özel Butik Danışmanı")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryDiskSpace",
                reasonCodes: ["E174.1"],
                purposeSummary: "Verifies local cache space before streaming 8K PBR textures and USDZ assets."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores preferred currency display and ornament dock placement."
            )
        ],
        customStateComputedSwift: """
        public var primaryConfiguredPriceEUR: Int {
            catalogPieces.first?.configuredTotalEUR ?? 0
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("visionOS Ornament Swatch Picker", systemImage: "paintbrush.pointed.fill")
                    .font(.headline)
                Spacer()
                Text("€\\(store.state.primaryConfiguredPriceEUR)")
                    .font(.subheadline.monospacedDigit().bold())
            }
            Text("Active Swatch: \\(store.state.selectedSwatchID) · Reservations: \\(store.state.reservedPieceIDs.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Atelier Concierge Copilot: Primary piece configured at €\\(state.primaryConfiguredPriceEUR) with swatch \\(state.selectedSwatchID); \\(state.reservedPieceIDs.count) hold(s) active."
        """,
        customUnitTestsSwift: """
        @Test("Applying platinum PBR swatch updates bespoke EUR price and reservation decrements stock")
        func swatchPricingAndEditionReservation() {
            var state = SpatialLuxuryAtelierState()
            _ = SpatialLuxuryAtelierReducer.reduce(
                state: &state,
                action: .applyMaterialSwatch(pieceID: "pcs-tourbillon", swatchID: "mat-platinum")
            )
            #expect(state.catalogPieces[0].configuredTotalEUR == 58_100)

            _ = SpatialLuxuryAtelierReducer.reduce(
                state: &state,
                action: .reserveBoutiqueEdition(pieceID: "pcs-tourbillon")
            )
            #expect(state.catalogPieces[0].boutiqueAvailableUnits == 2)
            #expect(state.reservedPieceIDs.count == 1)
        }
        """,
        securityPostureHighlights: [
            "visionOS world-sensing anchor coordinates never persist outside ephemeral RealityKit session.",
            "Idempotent reservation tokens prevent double-allocation of 1-of-N numbered editions.",
            "Signed USDZ asset checksums guard against tampered 3D geometry."
        ]
    )

    // MARK: 11. Cold-Chain Fleet & Biologics Telemetry

    public static let coldChainFleetTelemetry = EnterpriseBlueprintSpec(
        id: .coldChainFleetTelemetry,
        vertical: .commerceLogistics,
        title: "Cold-Chain Fleet Telemetry",
        subtitle: "GDP biologics reefer monitoring, thermal excursion alerts, Mean Kinetic Temperature math, and quarantine locks.",
        sfSymbol: "thermometer.snowflake",
        complexityTier: .missionCritical,
        supportedPlatforms: [.macOS, .iPadOS, .iOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "ReeferContainerUnit",
                tableName: "reefer_container_units",
                summary: "BLE/cellular IoT refrigerated biologics container with thermal bounds and excursion accumulator.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"csu-401\"", isIndexed: true, summary: "ISO 6346 container identifier."),
                    BlueprintEntityField(name: "cargoManifest", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Monoclonal Antibody Batch #B94\"", summary: "Regulated pharma or perishable lot description."),
                    BlueprintEntityField(name: "currentTempC", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "4.6", summary: "Calibrated NIST probe temperature in Celsius."),
                    BlueprintEntityField(name: "minAllowedC", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "2.0", summary: "Lower GDP cold-chain bound (freeze risk below)."),
                    BlueprintEntityField(name: "maxAllowedC", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "8.0", summary: "Upper GDP cold-chain bound (degradation above)."),
                    BlueprintEntityField(name: "excursionMinutes", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "0", summary: "Cumulative out-of-range minutes during transit."),
                    BlueprintEntityField(name: "isQuarantined", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", isIndexed: true, summary: "QA hold triggered if excursion budget exceeded.")
                ],
                computedHelpersSwift: """
                public var isInThermalExcursion: Bool {
                    currentTempC < minAllowedC || currentTempC > maxAllowedC
                }

                public var thermalMarginToUpperC: Double {
                    maxAllowedC - currentTempC
                }
                """
            ),
            BlueprintDomainEntity(
                name: "ChainOfCustodyScan",
                tableName: "chain_of_custody_scans",
                summary: "FDA 21 CFR Part 11 signed handoff event at port, customs tarmac, or hospital receiving dock.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"coc-01\"", isIndexed: true, summary: "Custody handoff event ID."),
                    BlueprintEntityField(name: "containerID", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"csu-401\"", isIndexed: true, summary: "Scanned reefer container ID."),
                    BlueprintEntityField(name: "hubCode", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"FRA-PHARMA-HUB\"", summary: "IATA or depot location code."),
                    BlueprintEntityField(name: "sealVerified", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "true", summary: "Tamper-evident NFC bolt seal verification.")
                ],
                computedHelpersSwift: """
                public var complianceBadge: String {
                    sealVerified ? "21CFR11_VERIFIED" : "SEAL_TAMPER_ALERT"
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "containers",
                swiftType: "[ReeferContainerUnit]",
                initialValueLiteral: """
                [
                    ReeferContainerUnit(id: "CHFK-204810-2", cargoManifest: "mAb Oncology Lot #B94 (2-8°C)", currentTempC: 4.4, minAllowedC: 2.0, maxAllowedC: 8.0, excursionMinutes: 0, isQuarantined: false),
                    ReeferContainerUnit(id: "CHFK-991042-7", cargoManifest: "Cryo Viral Vector (-80°C)", currentTempC: -76.5, minAllowedC: -85.0, maxAllowedC: -65.0, excursionMinutes: 4, isQuarantined: false),
                    ReeferContainerUnit(id: "CHFK-512008-1", cargoManifest: "Insulin Pen Pallets (2-8°C)", currentTempC: 9.4, minAllowedC: 2.0, maxAllowedC: 8.0, excursionMinutes: 12, isQuarantined: false)
                ]
                """,
                summary: "Monitored cold-chain fleet containers."
            ),
            BlueprintStateProperty(
                name: "custodyScans",
                swiftType: "[ChainOfCustodyScan]",
                initialValueLiteral: """
                [
                    ChainOfCustodyScan(id: "coc-01", containerID: "CHFK-204810-2", hubCode: "ZRH-BIOLOGICS-GATE", sealVerified: true)
                ]
                """,
                summary: "Signed chain-of-custody handoff records."
            ),
            BlueprintStateProperty(
                name: "maxExcursionBudgetMinutes",
                swiftType: "Int",
                initialValueLiteral: "15",
                summary: "Maximum cumulative thermal excursion minutes before mandatory QA quarantine."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "ingestProbeReading(containerID: String, tempCelsius: Double, intervalMinutes: Int)",
                matchPattern: ".ingestProbeReading(let containerID, let tempCelsius, let intervalMinutes)",
                buttonTitle: "Simulate Excursion Tick",
                sampleDispatchLiteral: ".ingestProbeReading(containerID: \"CHFK-512008-1\", tempCelsius: 9.8, intervalMinutes: 5)",
                summary: "Updates container temperature, accumulates excursion minutes, and auto-quarantines on breach.",
                mutationBodySwift: """
                guard let idx = state.containers.firstIndex(where: { $0.id == containerID }) else { break }
                state.containers[idx].currentTempC = tempCelsius
                if state.containers[idx].isInThermalExcursion {
                    state.containers[idx].excursionMinutes += max(1, intervalMinutes)
                    if state.containers[idx].excursionMinutes > state.maxExcursionBudgetMinutes {
                        state.containers[idx].isQuarantined = true
                    }
                }
                state.lastAuditMessage = "Probe \\(containerID): \\(String(format: "%.1f", tempCelsius))°C (quarantined: \\(state.containers[idx].isQuarantined))"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "engageBackupCoolingDefrostReset(containerID: String, targetCelsius: Double)",
                matchPattern: ".engageBackupCoolingDefrostReset(let containerID, let targetCelsius)",
                buttonTitle: "Engage Backup Cooling",
                sampleDispatchLiteral: ".engageBackupCoolingDefrostReset(containerID: \"CHFK-512008-1\", targetCelsius: 4.8)",
                summary: "Switches reefer dual-compressor unit to secondary loop and restores nominal setpoint.",
                mutationBodySwift: """
                guard let idx = state.containers.firstIndex(where: { $0.id == containerID }) else { break }
                state.containers[idx].currentTempC = targetCelsius
                state.lastAuditMessage = "Engaged secondary compressor on \\(containerID) -> \\(targetCelsius)°C"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchReeferFleet",
                method: .get,
                path: "/v1/coldchain/containers",
                responseType: "[ReeferContainerUnit]",
                offlineStubSwift: "ColdChainTelemetryState().containers",
                summary: "Fetches live cellular/satellite IoT reefer container probes."
            ),
            BlueprintAPIEndpoint(
                methodName: "recordCustodyHandoff",
                method: .post,
                path: "/v1/coldchain/custody/scans",
                requestPayloadType: "ChainOfCustodyScan",
                responseType: "ChainOfCustodyScan",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Commits 21 CFR Part 11 signed NFC bolt-seal handoff."
            ),
            BlueprintAPIEndpoint(
                methodName: "dispatchCompressorSetpoint",
                method: .put,
                path: "/v1/coldchain/containers/setpoint",
                requestPayloadType: "ReeferContainerUnit",
                responseType: "ReeferContainerUnit",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Sends remote dual-compressor failover command."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "gdpCompliance", label: "GDP In-Range Fleet", value: "2 / 3 Units", delta: "1 high-temp alert", sfSymbol: "snowflake"),
            BlueprintKPIMetric(key: "cryoLoop", label: "Ultra-Cold Cryo", value: "-76.5 °C", delta: "LN2 nominal", sfSymbol: "thermometer.low"),
            BlueprintKPIMetric(key: "excursionAlert", label: "Active Excursion", value: "+9.4 °C", delta: "12 / 15m budget", sfSymbol: "exclamationmark.thermometer", isFavorable: false),
            BlueprintKPIMetric(key: "nfcSeals", label: "Bolt Seals Intact", value: "100%", delta: "21 CFR Part 11", sfSymbol: "checkmark.seal.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "cc-1", headline: "CHFK-204810-2 · mAb Oncology Lot #B94", subheadline: "Spec 2.0..8.0°C · ZRH-BIOLOGICS-GATE verified", trailingMetric: "+4.4 °C", statusTag: "COMPLIANT"),
            BlueprintSampleRecord(id: "cc-2", headline: "CHFK-991042-7 · Cryo Viral Vector", subheadline: "Spec -85.0..-65.0°C · Dual Stirling cooler active", trailingMetric: "-76.5 °C", statusTag: "CRYO OK"),
            BlueprintSampleRecord(id: "cc-3", headline: "CHFK-512008-1 · Insulin Pen Pallets", subheadline: "Spec 2.0..8.0°C · 12m cumulative excursion", trailingMetric: "+9.4 °C", statusTag: "EXCURSION")
        ],
        onboardingPages: [
            FlowPage(
                id: "nist-probes",
                title: "Pair NIST-Traceable BLE & Satellite Probes",
                body: "Ingest calibrated biologics container temperatures even in offline tarmac dead-zones.",
                style: "hero",
                actions: ["Pair Reefer Probes"]
            ),
            FlowPage(
                id: "gdp-thresholds",
                title: "Set GDP Quarantine Excursion Budgets",
                body: "Automatically lock lot release if cumulative excursion exceeds 15 minutes.",
                style: "choice",
                actions: ["Strict 15m Biologics", "30m Ambient Pharma"]
            ),
            FlowPage(
                id: "coldchain-ready",
                title: "Cold-Chain Fleet Command Live",
                body: "Real-time excursion alerts, compressor failover, and custody seals are active.",
                style: "completion",
                actions: ["Launch Fleet Telemetry"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "cold.title", en: "Cold-Chain Fleet Telemetry", tr: "Soğuk Zincir Filo Telemetrisi"),
            BlueprintLocalizedKey(key: "cold.excursion", en: "Thermal Excursion Alert", tr: "Sıcaklık İhlali Uyarısı"),
            BlueprintLocalizedKey(key: "cold.quarantine", en: "Mandatory QA Quarantine", tr: "Zorunlu Kalite Karantinası"),
            BlueprintLocalizedKey(key: "cold.backup_cooling", en: "Engage Secondary Compressor", tr: "Yedek Kompresörü Devreye Al"),
            BlueprintLocalizedKey(key: "cold.seal_ok", en: "NFC Tamper Seal Intact", tr: "NFC Güvenlik Mührü Sağlam"),
            BlueprintLocalizedKey(key: "cold.custody", en: "Chain of Custody Log", tr: "Teslimat Gözetim Zinciri Kaydı")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Computes tamper-proof excursion duration intervals offline."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Timestamps FDA 21 CFR Part 11 cold-chain audit exports."
            )
        ],
        customStateComputedSwift: """
        public var excursionContainerCount: Int {
            containers.filter(\\.isInThermalExcursion).count
        }

        public var quarantinedContainerCount: Int {
            containers.filter(\\.isQuarantined).count
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("GDP Thermal Excursion Watchdog", systemImage: "thermometer.high")
                    .font(.headline)
                Spacer()
                Text("Excursions: \\(store.state.excursionContainerCount) · Quarantined: \\(store.state.quarantinedContainerCount)")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("Auto-quarantine budget: \\(store.state.maxExcursionBudgetMinutes) cumulative minutes out-of-spec.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Cold-Chain Copilot: \\(state.excursionContainerCount) container(s) out-of-spec, \\(state.quarantinedContainerCount) quarantined under GDP rules."
        """,
        customUnitTestsSwift: """
        @Test("Cumulative thermal excursion beyond 15m triggers automatic GDP quarantine")
        func excursionAutoQuarantineRule() {
            var state = ColdChainTelemetryState()
            #expect(state.containers[2].isQuarantined == false)
            _ = ColdChainTelemetryReducer.reduce(
                state: &state,
                action: .ingestProbeReading(containerID: "CHFK-512008-1", tempCelsius: 9.6, intervalMinutes: 5)
            )
            #expect(state.containers[2].excursionMinutes == 17)
            #expect(state.containers[2].isQuarantined == true)
        }
        """,
        securityPostureHighlights: [
            "FDA 21 CFR Part 11 monotonic audit trail prevents retroactive temperature log editing.",
            "Offline SQLite WAL spooling preserves probe readings across ocean/air cellular blackouts.",
            "NFC bolt-seal cryptographic challenge prevents container substitution."
        ]
    )

    // MARK: 12. POS & High-Throughput Kitchen Display System (KDS)

    public static let posKitchenDisplaySystem = EnterpriseBlueprintSpec(
        id: .posKitchenDisplaySystem,
        vertical: .commerceLogistics,
        title: "POS & Kitchen Display System",
        subtitle: "Multi-station course fire pacing, ticket SLA bump timers, allergen VIP flags, and live 86 par-stock sync.",
        sfSymbol: "fork.knife.circle.fill",
        complexityTier: .professional,
        supportedPlatforms: [.iPadOS, .macOS, .iOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "KitchenCourseTicket",
                tableName: "kitchen_course_tickets",
                summary: "Active dining room table ticket routed across Garde Manger, Grill, Pastry, and Expo stations.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"tkt-204\"", isIndexed: true, summary: "Kitchen ticket ID."),
                    BlueprintEntityField(name: "tableCode", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"T-14\"", isIndexed: true, summary: "Dining room table identifier."),
                    BlueprintEntityField(name: "coversCount", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "4", summary: "Seated guest count."),
                    BlueprintEntityField(name: "activeCourseNumber", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1", summary: "Currently firing course (1 = Crudo, 2 = Pasta, 3 = Mains)."),
                    BlueprintEntityField(name: "totalCourses", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "3", summary: "Total scheduled tasting or a-la-carte courses."),
                    BlueprintEntityField(name: "elapsedSeconds", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "410", summary: "Seconds since current course was fired."),
                    BlueprintEntityField(name: "targetSLASeconds", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "600", summary: "Station SLA target before yellow/red expediter alert."),
                    BlueprintEntityField(name: "hasSevereAllergen", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "true", summary: "Highlights shellfish/nut anaphylaxis purple banner.")
                ],
                computedHelpersSwift: """
                public var isOverSLA: Bool {
                    elapsedSeconds > targetSLASeconds
                }

                public var isFinalCourseActive: Bool {
                    activeCourseNumber >= totalCourses
                }
                """
            ),
            BlueprintDomainEntity(
                name: "StationIngredientPar",
                tableName: "station_ingredient_pars",
                summary: "Real-time prep station portion count syncing instant 86 availability to front-of-house iPads.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"sku-halibut\"", isIndexed: true, summary: "Menu ingredient SKU."),
                    BlueprintEntityField(name: "itemName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Wild Pacific Halibut\"", summary: "Line item title."),
                    BlueprintEntityField(name: "remainingPortions", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "6", summary: "Remaining prepped portions on line."),
                    BlueprintEntityField(name: "lowParAlertAt", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "5", summary: "Low-stock warning threshold.")
                ],
                computedHelpersSwift: """
                public var is86edOutOfStock: Bool {
                    remainingPortions <= 0
                }

                public var isLowPar: Bool {
                    remainingPortions > 0 && remainingPortions <= lowParAlertAt
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "activeTickets",
                swiftType: "[KitchenCourseTicket]",
                initialValueLiteral: """
                [
                    KitchenCourseTicket(id: "tkt-204", tableCode: "T-14", coversCount: 4, activeCourseNumber: 1, totalCourses: 3, elapsedSeconds: 420, targetSLASeconds: 600, hasSevereAllergen: true),
                    KitchenCourseTicket(id: "tkt-205", tableCode: "T-08", coversCount: 2, activeCourseNumber: 2, totalCourses: 2, elapsedSeconds: 685, targetSLASeconds: 600, hasSevereAllergen: false)
                ]
                """,
                summary: "Live rail tickets on Expo KDS screen."
            ),
            BlueprintStateProperty(
                name: "stationInventory",
                swiftType: "[StationIngredientPar]",
                initialValueLiteral: """
                [
                    StationIngredientPar(id: "sku-halibut", itemName: "Wild Pacific Halibut", remainingPortions: 3, lowParAlertAt: 5),
                    StationIngredientPar(id: "sku-wagyu", itemName: "A5 Miyazaki Ribeye", remainingPortions: 9, lowParAlertAt: 4)
                ]
                """,
                summary: "Real-time station prep par counts."
            ),
            BlueprintStateProperty(
                name: "bumpedTicketsCount",
                swiftType: "Int",
                initialValueLiteral: "42",
                summary: "Completed covers/tickets bumped during current dinner service."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "fireOrBumpTicket(ticketID: String)",
                matchPattern: ".fireOrBumpTicket(let ticketID)",
                buttonTitle: "Fire Next Course / Bump",
                sampleDispatchLiteral: ".fireOrBumpTicket(ticketID: \"tkt-204\")",
                summary: "Advances ticket to next course with reset timer, or bumps completed ticket off the rail.",
                mutationBodySwift: """
                guard let idx = state.activeTickets.firstIndex(where: { $0.id == ticketID }) else { break }
                if state.activeTickets[idx].isFinalCourseActive {
                    let done = state.activeTickets.remove(at: idx)
                    state.bumpedTicketsCount += 1
                    state.lastAuditMessage = "Bumped final course for table \\(done.tableCode)"
                } else {
                    state.activeTickets[idx].activeCourseNumber += 1
                    state.activeTickets[idx].elapsedSeconds = 0
                    state.lastAuditMessage = "Fired course \\(state.activeTickets[idx].activeCourseNumber) for \\(state.activeTickets[idx].tableCode)"
                }
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "decrementPortionStock(skuID: String, count: Int)",
                matchPattern: ".decrementPortionStock(let skuID, let count)",
                buttonTitle: "Sell 3 Halibut (Auto-86)",
                sampleDispatchLiteral: ".decrementPortionStock(skuID: \"sku-halibut\", count: 3)",
                summary: "Deducts sold portions and broadcasts instant 86 status when count hits zero.",
                mutationBodySwift: """
                guard count > 0, let idx = state.stationInventory.firstIndex(where: { $0.id == skuID }) else { break }
                state.stationInventory[idx].remainingPortions = max(0, state.stationInventory[idx].remainingPortions - count)
                let item = state.stationInventory[idx]
                state.lastAuditMessage = item.is86edOutOfStock ? "86 ALERT: \\(item.itemName) out of stock" : "\\(item.itemName): \\(item.remainingPortions) portions left"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchActiveKDSTickets",
                method: .get,
                path: "/v1/pos/kds/tickets",
                responseType: "[KitchenCourseTicket]",
                offlineStubSwift: "KitchenCourseKDSState().activeTickets",
                summary: "Loads open kitchen rail tickets over local Bonjour/LAN mesh."
            ),
            BlueprintAPIEndpoint(
                methodName: "postCourseFireEvent",
                method: .post,
                path: "/v1/pos/kds/fire",
                requestPayloadType: "KitchenCourseTicket",
                responseType: "KitchenCourseTicket",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Broadcasts course fire or expo bump across all line iPads."
            ),
            BlueprintAPIEndpoint(
                methodName: "syncParInventory",
                method: .put,
                path: "/v1/pos/inventory/par",
                requestPayloadType: "StationIngredientPar",
                responseType: "StationIngredientPar",
                offlineStubSwift: "payload",
                summary: "Synchronizes 86 out-of-stock status with dining room handheld POS."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "avgTicketTime", label: "Median Course Time", value: "8m 12s", delta: "94% within SLA", sfSymbol: "stopwatch.fill"),
            BlueprintKPIMetric(key: "bumpedCovers", label: "Completed Tickets", value: "42 Tables", delta: "Dinner Service", sfSymbol: "checkmark.rectangle.stack.fill"),
            BlueprintKPIMetric(key: "overSLA", label: "Overdue on Rail", value: "1 Ticket", delta: "T-08 (+85s)", sfSymbol: "flame.fill", isFavorable: false),
            BlueprintKPIMetric(key: "lowPar", label: "Low-Par / 86 Watch", value: "Halibut (3)", delta: "Auto-sync POS", sfSymbol: "tray.full.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "kds-1", headline: "Table T-14 · 4 Covers · Course 1 / 3", subheadline: "SEVERE ALLERGEN PROTOCOL · 7m 00s elapsed", trailingMetric: "IN SLA", statusTag: "ALLERGEN VIP"),
            BlueprintSampleRecord(id: "kds-2", headline: "Table T-08 · 2 Covers · Course 2 / 2 (Mains)", subheadline: "Grill + Garde Manger · 11m 25s elapsed", trailingMetric: "+85s SLA", statusTag: "EXPEDITE"),
            BlueprintSampleRecord(id: "kds-3", headline: "Wild Pacific Halibut · Fish Station", subheadline: "Low par threshold <= 5 · Syncs instant 86 to servers", trailingMetric: "3 Portions", statusTag: "LOW PAR")
        ],
        onboardingPages: [
            FlowPage(
                id: "station-routing",
                title: "Assign iPad KDS Station Role",
                body: "Route incoming POS items to Grill, Saute, Garde Manger, Pastry, or Master Expo.",
                style: "hero",
                actions: ["Select Expo Master"]
            ),
            FlowPage(
                id: "lan-failover",
                title: "Enable Offline LAN Mesh Sync",
                body: "Keep kitchen firing and handheld ordering uninterrupted even if WAN fiber drops mid-service.",
                style: "choice",
                actions: ["Peer-to-Peer LAN Mesh", "Cloud + LAN Hybrid"]
            ),
            FlowPage(
                id: "kds-ready",
                title: "Kitchen Display Rail Armed",
                body: "Course pacing timers, allergen banners, and instant 86 par sync are active.",
                style: "completion",
                actions: ["Start Dinner Service"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "kds.title", en: "POS & Kitchen Display System", tr: "POS ve Mutfak Ekran Sistemi (KDS)"),
            BlueprintLocalizedKey(key: "kds.fire_course", en: "Fire Next Course", tr: "Sonraki Servisi Başlat"),
            BlueprintLocalizedKey(key: "kds.bump_ticket", en: "Bump Completed Ticket", tr: "Tamamlanan Adisyonu Kapat"),
            BlueprintLocalizedKey(key: "kds.allergen_alert", en: "Severe Allergen Protocol", tr: "Ciddi Alerjen Protokolü"),
            BlueprintLocalizedKey(key: "kds.out_of_stock", en: "86 Out of Stock", tr: "Stokta Yok (86)"),
            BlueprintLocalizedKey(key: "kds.expedite", en: "Expedite Overdue Table", tr: "Geciken Masayı Hızlandır")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Drives drift-free course elapsed second counters across KDS stations."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Saves assigned kitchen station role and audio chime volume."
            )
        ],
        customStateComputedSwift: """
        public var overdueTicketCount: Int {
            activeTickets.filter(\\.isOverSLA).count
        }

        public var eightySixedItemCount: Int {
            stationInventory.filter(\\.is86edOutOfStock).count
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Expo Pacing & 86 Line Board", systemImage: "bell.and.waves.left.and.right.fill")
                    .font(.headline)
                Spacer()
                Text("Bumped: \\(store.state.bumpedTicketsCount)")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("Over SLA: \\(store.state.overdueTicketCount) · 86'd Items: \\(store.state.eightySixedItemCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Expo Copilot: \\(state.activeTickets.count) open rails (\\(state.overdueTicketCount) over SLA), \\(state.eightySixedItemCount) SKU(s) 86'd."
        """,
        customUnitTestsSwift: """
        @Test("Firing courses advances ticket and final course bumps off rail; zero stock triggers 86")
        func coursePacingAndAuto86() {
            var state = KitchenCourseKDSState()
            _ = KitchenCourseKDSReducer.reduce(state: &state, action: .fireOrBumpTicket(ticketID: "tkt-204"))
            #expect(state.activeTickets[0].activeCourseNumber == 2)

            _ = KitchenCourseKDSReducer.reduce(state: &state, action: .fireOrBumpTicket(ticketID: "tkt-205"))
            #expect(state.activeTickets.count == 1)
            #expect(state.bumpedTicketsCount == 43)

            _ = KitchenCourseKDSReducer.reduce(state: &state, action: .decrementPortionStock(skuID: "sku-halibut", count: 3))
            #expect(state.stationInventory[0].is86edOutOfStock == true)
        }
        """,
        securityPostureHighlights: [
            "Local peer-to-peer TLS authentication prevents unauthorized guest devices from spoofing KDS bumps.",
            "Idempotent ticket fire events prevent double-plating during Wi-Fi roaming.",
            "High-contrast allergen callouts meet commercial kitchen glare legibility standards."
        ]
    )
}
