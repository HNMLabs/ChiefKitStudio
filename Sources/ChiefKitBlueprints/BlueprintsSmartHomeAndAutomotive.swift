import ChiefKitStudioCore
import Foundation

// MARK: - Vertical 8: Smart Energy Microgrids & Autonomous Mobility Blueprints

public enum SmartHomeAndAutomotiveBlueprints: Sendable {
    public static let specs: [EnterpriseBlueprintSpec] = [
        matterSolarEnergyMicrogrid,
        evCockpitChargingPlanner,
        autonomousDroneMissionControl
    ]

    // MARK: 22. Matter 1.3 Solar & Battery Energy Microgrid

    public static let matterSolarEnergyMicrogrid = EnterpriseBlueprintSpec(
        id: .matterSolarEnergyMicrogrid,
        vertical: .smartHomeMobility,
        title: "Matter Solar Energy Microgrid",
        subtitle: "Real-time PV/battery/grid kW flow conservation, TOU tariff arbitrage, and Matter 1.3 smart load shedding.",
        sfSymbol: "sun.max.trianglebadge.exclamationmark.fill",
        complexityTier: .enterprise,
        supportedPlatforms: [.iOS, .iPadOS, .macOS, .watchOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "MicrogridInverterSnapshot",
                tableName: "microgrid_inverter_snapshots",
                summary: "Hybrid MPPT solar inverter and LFP home battery bus telemetry obeying Kirchhoff kW balance.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"inv-main\"", isIndexed: true, summary: "Hybrid inverter serial ID."),
                    BlueprintEntityField(name: "solarPVGenerationKW", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "9.4", summary: "Instantaneous rooftop PV array output in kW."),
                    BlueprintEntityField(name: "baseHomeLoadKW", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "2.1", summary: "Non-deferrable critical house load in kW."),
                    BlueprintEntityField(name: "batterySoCPercent", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "78.0", summary: "LFP stationary battery State of Charge [0..100]."),
                    BlueprintEntityField(name: "batteryCapacityKWh", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "27.0", summary: "Total usable energy storage in kWh."),
                    BlueprintEntityField(name: "gridImportTariffCents", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "34.5", summary: "Current utility Time-of-Use import rate in cents/kWh."),
                    BlueprintEntityField(name: "isIslandedOffGrid", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "True when MID transfer relay disconnects utility grid.")
                ],
                computedHelpersSwift: """
                public var storedEnergyKWh: Double {
                    batteryCapacityKWh * (min(max(batterySoCPercent, 0.0), 100.0) / 100.0)
                }

                public func backupAutonomyHours(totalLoadKW: Double) -> Double {
                    let draw = max(0.25, totalLoadKW)
                    return storedEnergyKWh / draw
                }
                """
            ),
            BlueprintDomainEntity(
                name: "MatterControllableLoad",
                tableName: "matter_controllable_loads",
                summary: "CSA Matter 1.3 Energy Management cluster endpoint (EVSE wallbox, heat pump, pool pump).",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"mtr-evse\"", isIndexed: true, summary: "Matter fabric node ID."),
                    BlueprintEntityField(name: "deviceName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Garage 11kW Matter EVSE\"", summary: "Homeowner endpoint title."),
                    BlueprintEntityField(name: "activeDrawKW", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "7.2", summary: "Current real power consumption in kW."),
                    BlueprintEntityField(name: "isDeferrable", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "true", summary: "True if load can pause during peak TOU or grid outage."),
                    BlueprintEntityField(name: "isShedded", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "True when paused by energy management controller.")
                ],
                computedHelpersSwift: """
                public var effectiveDrawKW: Double {
                    isShedded ? 0.0 : activeDrawKW
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "inverter",
                swiftType: "MicrogridInverterSnapshot",
                initialValueLiteral: "MicrogridInverterSnapshot()",
                summary: "Live hybrid solar inverter and LFP battery bus telemetry."
            ),
            BlueprintStateProperty(
                name: "matterLoads",
                swiftType: "[MatterControllableLoad]",
                initialValueLiteral: """
                [
                    MatterControllableLoad(id: "mtr-evse", deviceName: "Garage Bidirectional EVSE", activeDrawKW: 7.2, isDeferrable: true, isShedded: false),
                    MatterControllableLoad(id: "mtr-hvac", deviceName: "Hydronic Air-to-Water Heat Pump", activeDrawKW: 2.8, isDeferrable: true, isShedded: false),
                    MatterControllableLoad(id: "mtr-rack", deviceName: "Homelab & Cold Pantry Critical", activeDrawKW: 0.6, isDeferrable: false, isShedded: false)
                ]
                """,
                summary: "Commissioned Thread/Matter 1.3 controllable energy loads."
            ),
            BlueprintStateProperty(
                name: "stormWatchReservePercent",
                swiftType: "Double",
                initialValueLiteral: "20.0",
                summary: "Minimum battery SoC floor reserved for grid outages."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "shedDeferrablePeakLoads",
                matchPattern: ".shedDeferrablePeakLoads",
                buttonTitle: "Shed Peak TOU Loads",
                sampleDispatchLiteral: ".shedDeferrablePeakLoads",
                summary: "Curtails all deferrable Matter 1.3 heavy loads to flip microgrid from net import to net solar export.",
                mutationBodySwift: """
                var shedKW = 0.0
                for idx in state.matterLoads.indices where state.matterLoads[idx].isDeferrable && !state.matterLoads[idx].isShedded {
                    shedKW += state.matterLoads[idx].activeDrawKW
                    state.matterLoads[idx].isShedded = true
                }
                state.lastAuditMessage = String(format: "Shed %.1f kW of deferrable Matter loads; net PV surplus %.1f kW", shedKW, state.netSolarSurplusKW)
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "engageStormWatchIslanding(islanded: Bool)",
                matchPattern: ".engageStormWatchIslanding(let islanded)",
                buttonTitle: "Engage Off-Grid Islanding",
                sampleDispatchLiteral: ".engageStormWatchIslanding(islanded: true)",
                summary: "Opens utility MID transfer switch, raises reserve floor to 80%, and sheds non-essential loads.",
                mutationBodySwift: """
                state.inverter.isIslandedOffGrid = islanded
                if islanded {
                    state.stormWatchReservePercent = 80.0
                    for idx in state.matterLoads.indices where state.matterLoads[idx].isDeferrable {
                        state.matterLoads[idx].isShedded = true
                    }
                    state.lastAuditMessage = "ISLANDED OFF-GRID: critical backup autonomy \\(String(format: "%.1f", state.backupHoursRemaining))h"
                } else {
                    state.stormWatchReservePercent = 20.0
                    state.lastAuditMessage = "Re-synchronized microgrid with utility 50/60Hz phase"
                }
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchInverterTelemetry",
                method: .get,
                path: "/v1/microgrid/inverter",
                responseType: "MicrogridInverterSnapshot",
                offlineStubSwift: "MatterSolarMicrogridState().inverter",
                summary: "Reads SunSpec Modbus/TCP & Matter local gateway inverter telemetry."
            ),
            BlueprintAPIEndpoint(
                methodName: "dispatchMatterLoadCurtailment",
                method: .post,
                path: "/v1/microgrid/matter/curtail",
                requestPayloadType: "MatterControllableLoad",
                responseType: "MatterControllableLoad",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Sends local Thread/IPv6 Matter Device Energy Management pause command."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchUtilityTOUSchedule",
                method: .get,
                path: "/v1/microgrid/tariffs/tou",
                responseType: "[Double]",
                offlineStubSwift: "[14.2, 18.5, 34.5, 41.0, 16.0]",
                summary: "Fetches day-ahead dynamic utility tariff cents/kWh curve."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "pvOutput", label: "Rooftop Solar MPPT", value: "9.40 kW", delta: "Clear irradiance", sfSymbol: "sun.max.fill"),
            BlueprintKPIMetric(key: "batterySoC", label: "LFP Storage Bank", value: "78% (21.1 kWh)", delta: "27 kWh nameplate", sfSymbol: "battery.75percent"),
            BlueprintKPIMetric(key: "totalLoad", label: "Total Site Demand", value: "12.70 kW", delta: "EVSE + HVAC on", sfSymbol: "bolt.house.fill"),
            BlueprintKPIMetric(key: "touRate", label: "Peak TOU Tariff", value: "34.5 ¢/kWh", delta: "Arbitrage ready", sfSymbol: "dollarsign.arrow.circlepath")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "mg-1", headline: "Garage Bidirectional Matter EVSE", subheadline: "Matter 1.3 DEM Cluster · Deferrable surplus solar sink", trailingMetric: "7.20 kW", statusTag: "CHARGING"),
            BlueprintSampleRecord(id: "mg-2", headline: "Hydronic Air-to-Water Heat Pump", subheadline: "Thermal buffer tank @ 52°C · Deferrable for 3h peak", trailingMetric: "2.80 kW", statusTag: "ACTIVE"),
            BlueprintSampleRecord(id: "mg-3", headline: "Homelab & Cold Pantry Critical Bus", subheadline: "Protected UPS sub-panel · Never shed during islanding", trailingMetric: "0.60 kW", statusTag: "PROTECTED")
        ],
        onboardingPages: [
            FlowPage(
                id: "commission-matter",
                title: "Commission Matter 1.3 & SunSpec Inverter",
                body: "Pair your hybrid solar inverter, LFP battery, and EVSE over local IPv6 Thread/Wi-Fi.",
                style: "hero",
                actions: ["Discover Local Energy Fabric"]
            ),
            FlowPage(
                id: "tou-optimization",
                title: "Choose Microgrid Optimization Policy",
                body: "Maximize solar self-consumption or reserve 80% LFP capacity for severe weather outages.",
                style: "choice",
                actions: ["Peak Tariff Arbitrage", "Maximum Backup Autonomy"]
            ),
            FlowPage(
                id: "microgrid-ready",
                title: "Solar & Battery Microgrid Live",
                body: "Real-time kW flow balances, TOU load shedding, and off-grid islanding are armed.",
                style: "completion",
                actions: ["Launch Microgrid Console"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "grid.title", en: "Matter Solar Energy Microgrid", tr: "Matter Güneş Enerjisi Mikro Şebekesi"),
            BlueprintLocalizedKey(key: "grid.shed_loads", en: "Shed Deferrable Peak Loads", tr: "Ertelenebilir Puant Yükleri Kapat"),
            BlueprintLocalizedKey(key: "grid.island_mode", en: "Off-Grid Islanded Backup", tr: "Şebekeden Bağımsız Ada Modu"),
            BlueprintLocalizedKey(key: "grid.pv_surplus", en: "Net Solar Surplus (kW)", tr: "Net Güneş Enerjisi Fazlası (kW)"),
            BlueprintLocalizedKey(key: "grid.autonomy_hrs", en: "Estimated Backup Autonomy", tr: "Tahmini Yedek Enerji Süresi"),
            BlueprintLocalizedKey(key: "grid.tou_tariff", en: "Time-of-Use Tariff Rate", tr: "Çok Zamanlı Elektrik Tarifesi")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Integrates kW*dt kilowatt-hour energy counters accurately across poll ticks."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores utility tariff tier schedule and backup reserve floor."
            )
        ],
        customStateComputedSwift: """
        public var totalActiveSiteLoadKW: Double {
            inverter.baseHomeLoadKW + matterLoads.reduce(0.0) { $0 + $1.effectiveDrawKW }
        }

        public var netSolarSurplusKW: Double {
            inverter.solarPVGenerationKW - totalActiveSiteLoadKW
        }

        public var backupHoursRemaining: Double {
            inverter.backupAutonomyHours(totalLoadKW: totalActiveSiteLoadKW)
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Kirchhoff Power Bus Balance", systemImage: "bolt.circle.fill")
                    .font(.headline)
                Spacer()
                Text(String(format: "%+.2f kW Net", store.state.netSolarSurplusKW))
                    .font(.caption.monospacedDigit().bold())
            }
            Text("PV \\(String(format: "%.1f", store.state.inverter.solarPVGenerationKW)) kW · Load \\(String(format: "%.1f", store.state.totalActiveSiteLoadKW)) kW · Autonomy \\(String(format: "%.1f", store.state.backupHoursRemaining))h")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return String(format: "Microgrid Copilot: Net bus %+.2f kW, LFP backup %.1f hours, islanded=%@.", state.netSolarSurplusKW, state.backupHoursRemaining, state.inverter.isIslandedOffGrid ? "YES" : "NO")
        """,
        customUnitTestsSwift: """
        @Test("Shedding deferrable Matter loads flips microgrid from net grid import to +6.7 kW solar surplus")
        func matterLoadSheddingFlipsPowerBalance() {
            var state = MatterSolarMicrogridState()
            #expect(state.netSolarSurplusKW < 0)
            _ = MatterSolarMicrogridReducer.reduce(state: &state, action: .shedDeferrablePeakLoads)
            #expect(state.netSolarSurplusKW > 6.5)
            #expect(state.backupHoursRemaining > 7.5)
        }
        """,
        securityPostureHighlights: [
            "Matter PASE/CASE operational certificates authenticate local load control without cloud dependency.",
            "Occupancy-inferable sub-minute appliance signatures remain strictly inside home LAN.",
            "Protected critical-load flag prevents accidental shedding of medical or cold-storage circuits."
        ]
    )

    // MARK: 23. EV Cockpit & DC Fast-Charging Corridor Planner

    public static let evCockpitChargingPlanner = EnterpriseBlueprintSpec(
        id: .evCockpitChargingPlanner,
        vertical: .smartHomeMobility,
        title: "EV Cockpit Charging Planner",
        subtitle: "800V DC fast-charge taper curves, battery thermal preconditioning, and OCPI stall availability.",
        sfSymbol: "bolt.car.circle.fill",
        complexityTier: .professional,
        supportedPlatforms: [.iOS, .iPadOS, .macOS, .watchOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "FastChargerCorridorStop",
                tableName: "fast_charger_corridor_stops",
                summary: "OCPI 2.2.1 ultra-fast CCS2/NACS highway charging plaza with taper-modeled dwell time.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"chg-bolu\"", isIndexed: true, summary: "OCPI EVSE location ID."),
                    BlueprintEntityField(name: "plazaName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Highway O-4 Bolu 350kW Hub\"", summary: "Charging hub name."),
                    BlueprintEntityField(name: "dispenserMaxKW", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "350.0", summary: "Rated cabinet peak DC output in kW."),
                    BlueprintEntityField(name: "freeStalls", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "5", summary: "Currently unoccupied working stalls."),
                    BlueprintEntityField(name: "arrivalSoCPercent", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "12.0", summary: "Projected arrival State of Charge %."),
                    BlueprintEntityField(name: "departureSoCPercent", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "78.0", summary: "Optimal departure SoC % before steep C-rate taper."),
                    BlueprintEntityField(name: "packUsableKWh", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "93.4", summary: "Vehicle usable traction battery capacity in kWh.")
                ],
                computedHelpersSwift: """
                public var energyToAddKWh: Double {
                    let delta = max(0.0, departureSoCPercent - arrivalSoCPercent) / 100.0
                    return packUsableKWh * delta
                }

                /// Piecewise 800V charging curve: 88% of cabinet max (capped at 270 kW) below 55% SoC, 58% above 55%.
                public var estimatedDwellMinutes: Int {
                    guard departureSoCPercent > arrivalSoCPercent else { return 0 }
                    let peakCap = min(dispenserMaxKW, 270.0)
                    let knee = 55.0
                    let lowSpan = max(0.0, min(departureSoCPercent, knee) - arrivalSoCPercent) / 100.0
                    let highSpan = max(0.0, departureSoCPercent - max(arrivalSoCPercent, knee)) / 100.0
                    let lowHours = (packUsableKWh * lowSpan) / max(50.0, peakCap * 0.88)
                    let highHours = (packUsableKWh * highSpan) / max(40.0, peakCap * 0.58)
                    return Int(((lowHours + highHours) * 60.0).rounded(.up))
                }
                """
            ),
            BlueprintDomainEntity(
                name: "TractionPackTelemetry",
                tableName: "traction_pack_telemetry",
                summary: "800V NMC/LFP traction pack cell temperature, consumption Wh/km, and coolant heater state.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"pack-800v\"", isIndexed: true, summary: "BMS pack identifier."),
                    BlueprintEntityField(name: "currentSoCPercent", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "64.0", summary: "Live BMS usable State of Charge %."),
                    BlueprintEntityField(name: "cellTempCelsius", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "14.5", summary: "Mean cell module temperature in Celsius."),
                    BlueprintEntityField(name: "targetPreconditionTempC", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "31.0", summary: "Optimal fast-charge lithium plating avoidance temp (°C)."),
                    BlueprintEntityField(name: "whPerKilometer", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "188.0", summary: "Rolling highway efficiency in Wh/km."),
                    BlueprintEntityField(name: "isPreconditioningActive", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "True when heat-pump warms pack en route to HPC.")
                ],
                computedHelpersSwift: """
                public var needsThermalPreconditioning: Bool {
                    cellTempCelsius < (targetPreconditionTempC - 3.0)
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "corridorStops",
                swiftType: "[FastChargerCorridorStop]",
                initialValueLiteral: """
                [
                    FastChargerCorridorStop(id: "chg-bolu", plazaName: "O-4 Bolu Mountain 350kW Hub", dispenserMaxKW: 350.0, freeStalls: 5, arrivalSoCPercent: 11.0, departureSoCPercent: 76.0, packUsableKWh: 93.4),
                    FastChargerCorridorStop(id: "chg-ankara", plazaName: "Ankara West 300kW Ultra-Fast", dispenserMaxKW: 300.0, freeStalls: 3, arrivalSoCPercent: 14.0, departureSoCPercent: 65.0, packUsableKWh: 93.4)
                ]
                """,
                summary: "Planned DC fast-charging stops along route."
            ),
            BlueprintStateProperty(
                name: "packTelemetry",
                swiftType: "TractionPackTelemetry",
                initialValueLiteral: "TractionPackTelemetry()",
                summary: "Live BMS traction battery thermal & consumption state."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "activateBatteryPreconditioning",
                matchPattern: ".activateBatteryPreconditioning",
                buttonTitle: "Precondition Pack -> 31°C",
                sampleDispatchLiteral: ".activateBatteryPreconditioning",
                summary: "Engages heat-pump coolant loop ahead of 350 kW DC stop to unlock peak C-rate.",
                mutationBodySwift: """
                state.packTelemetry.isPreconditioningActive = true
                state.packTelemetry.cellTempCelsius = state.packTelemetry.targetPreconditionTempC
                state.lastAuditMessage = "Preconditioned 800V pack to \\(state.packTelemetry.cellTempCelsius)°C for 270 kW peak curve"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "optimizeStopDepartureCeiling(stopID: String, targetSoC: Double)",
                matchPattern: ".optimizeStopDepartureCeiling(let stopID, let targetSoC)",
                buttonTitle: "Cap Stop #1 @ 68% SoC",
                sampleDispatchLiteral: ".optimizeStopDepartureCeiling(stopID: \"chg-bolu\", targetSoC: 68.0)",
                summary: "Trims high-SoC taper tail to minimize total corridor travel + charging time.",
                mutationBodySwift: """
                guard let idx = state.corridorStops.firstIndex(where: { $0.id == stopID }) else { break }
                let floorSoC = state.corridorStops[idx].arrivalSoCPercent + 10.0
                state.corridorStops[idx].departureSoCPercent = min(max(targetSoC, floorSoC), 95.0)
                let mins = state.corridorStops[idx].estimatedDwellMinutes
                state.lastAuditMessage = "Optimized \\(stopID) to \\(Int(state.corridorStops[idx].departureSoCPercent))% (\\(mins)m dwell)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchOCPICorridorStalls",
                method: .get,
                path: "/v1/ev/ocpi/corridor-stops",
                responseType: "[FastChargerCorridorStop]",
                offlineStubSwift: "EVCockpitPlannerState().corridorStops",
                summary: "Queries live OCPI 2.2.1 dispenser stall occupancy and kW derating."
            ),
            BlueprintAPIEndpoint(
                methodName: "sendPreconditionCommand",
                method: .post,
                path: "/v1/ev/vehicle/bms/precondition",
                requestPayloadType: "TractionPackTelemetry",
                responseType: "TractionPackTelemetry",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Dispatches signed telematics thermal preconditioning command."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchPackTelemetry",
                method: .get,
                path: "/v1/ev/vehicle/bms/status",
                responseType: "TractionPackTelemetry",
                offlineStubSwift: "EVCockpitPlannerState().packTelemetry",
                summary: "Reads OBD-II BLE / CarPlay BMS SoC and cell module temperatures."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "totalChargeDwell", label: "Total Corridor Dwell", value: "30 mins", delta: "2 HPC stops", sfSymbol: "bolt.badge.clock.fill"),
            BlueprintKPIMetric(key: "packTemp", label: "Cell Module Temp", value: "14.5 °C", delta: "Precondition advised", sfSymbol: "thermometer.medium"),
            BlueprintKPIMetric(key: "efficiency", label: "Highway Consumption", value: "188 Wh/km", delta: "496 km WLTP eq", sfSymbol: "gauge.open.with.lines.needle.33percent"),
            BlueprintKPIMetric(key: "ocpiStalls", label: "Next Hub Availability", value: "5 / 6 Free", delta: "350 kW Plug&Charge", sfSymbol: "ev.charger.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "ev-1", headline: "Stop 1 · O-4 Bolu Mountain 350kW Hub", subheadline: "Arrive 11% -> Depart 76% (+60.7 kWh) · 5 stalls free", trailingMetric: "18m Dwell", statusTag: "PLUG & CHARGE"),
            BlueprintSampleRecord(id: "ev-2", headline: "Stop 2 · Ankara West 300kW Ultra-Fast", subheadline: "Arrive 14% -> Depart 65% (+47.6 kWh) · Avoids >70% taper", trailingMetric: "13m Dwell", statusTag: "OPTIMAL KNEE"),
            BlueprintSampleRecord(id: "ev-3", headline: "800V Silicon-Carbide BMS Thermal Loop", subheadline: "Current 14.5°C -> Target 31.0°C · Prevents cold-pack derate", trailingMetric: "270 kW Peak", statusTag: "READY")
        ],
        onboardingPages: [
            FlowPage(
                id: "vehicle-profile",
                title: "Select EV Architecture & Usable Pack kWh",
                body: "Load calibrated 400V or 800V DC taper curves and Plug & Charge ISO 15118 support.",
                style: "hero",
                actions: ["Select 800V Architecture"]
            ),
            FlowPage(
                id: "arrival-buffer",
                title: "Set Highway Arrival SoC Reserve",
                body: "Maintain a 10% minimum arrival buffer accounting for elevation gain and headwinds.",
                style: "choice",
                actions: ["10% Fast-Hopping", "18% Winter Safety Buffer"]
            ),
            FlowPage(
                id: "ev-cockpit-ready",
                title: "EV Cockpit Planner Armed",
                body: "High-contrast glare-free cockpit cards, OCPI stall telemetry, and BMS preconditioning are active.",
                style: "completion",
                actions: ["Start Route Planner"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "ev.title", en: "EV Cockpit Charging Planner", tr: "Elektrikli Araç Kokpit Şarj Planlayıcısı"),
            BlueprintLocalizedKey(key: "ev.precondition", en: "Precondition Battery Pack", tr: "Batarya Paketini Ön Isıtmaya Al"),
            BlueprintLocalizedKey(key: "ev.dwell_time", en: "Taper-Modeled Charging Time", tr: "Eğri Modelli Şarj Bekleme Süresi"),
            BlueprintLocalizedKey(key: "ev.free_stalls", en: "Available Ultra-Fast Stalls", tr: "Müsait Yüksek Hızlı Üniteler"),
            BlueprintLocalizedKey(key: "ev.arrival_soc", en: "Projected Arrival SoC", tr: "Tahmini Varış Doluluk Oranı"),
            BlueprintLocalizedKey(key: "ev.plug_and_charge", en: "ISO 15118 Plug & Charge", tr: "ISO 15118 Tak ve Şarj Et")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores preferred charging networks and minimum arrival SoC floor."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Tracks active DC session elapsed seconds."
            )
        ],
        customStateComputedSwift: """
        public var totalRouteChargingMinutes: Int {
            corridorStops.reduce(0) { $0 + $1.estimatedDwellMinutes }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("800V Taper Curve & BMS Thermal", systemImage: "ev.charger.fill")
                    .font(.headline)
                Spacer()
                Text("\\(store.state.totalRouteChargingMinutes)m Total Dwell")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("Cell Temp: \\(String(format: "%.1f", store.state.packTelemetry.cellTempCelsius))°C · Preconditioning: \\(store.state.packTelemetry.isPreconditioningActive ? "ACTIVE" : "IDLE")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Cockpit Copilot: \\(state.totalRouteChargingMinutes)m total HPC dwell across \\(state.corridorStops.count) stops; pack temp \\(state.packTelemetry.cellTempCelsius)°C."
        """,
        customUnitTestsSwift: """
        @Test("Capping departure SoC below taper knee reduces corridor dwell time and preconditioning heats cells")
        func chargingTaperOptimizationAndPreconditioning() {
            var state = EVCockpitChargingPlannerTestsHelper.makeState()
            let initialDwell = state.totalRouteChargingMinutes
            _ = EVCockpitPlannerReducer.reduce(
                state: &state,
                action: .optimizeStopDepartureCeiling(stopID: "chg-bolu", targetSoC: 60.0)
            )
            #expect(state.totalRouteChargingMinutes < initialDwell)

            _ = EVCockpitPlannerReducer.reduce(state: &state, action: .activateBatteryPreconditioning)
            #expect(state.packTelemetry.needsThermalPreconditioning == false)
        }

        enum EVCockpitChargingPlannerTestsHelper {
            static func makeState() -> EVCockpitPlannerState { EVCockpitPlannerState() }
        }
        """,
        securityPostureHighlights: [
            "Route corridor queries snap to coarse highway tiles so home garage coordinates stay private.",
            "Signed vehicle telematics commands prevent replay unlocking or unwanted HVAC drain.",
            "WCAG AAA high-contrast typography ensures glanceable safety in automotive cockpits."
        ]
    )

    // MARK: 24. Autonomous Drone Mission Control (GCS)

    public static let autonomousDroneMissionControl = EnterpriseBlueprintSpec(
        id: .autonomousDroneMissionControl,
        vertical: .smartHomeMobility,
        title: "Autonomous Drone Mission Control",
        subtitle: "MAVLink v2 photogrammetry waypoints, AGL geofence ceilings, and wind-aware Return-to-Home failsafes.",
        sfSymbol: "airplane.circle.fill",
        complexityTier: .missionCritical,
        supportedPlatforms: [.iPadOS, .macOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "UAVMissionWaypoint",
                tableName: "uav_mission_waypoints",
                summary: "3D RTK-GNSS survey waypoint with Above-Ground-Level altitude ceiling check and gimbal action.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"wp-01\"", isIndexed: true, summary: "Waypoint ID."),
                    BlueprintEntityField(name: "sequenceOrder", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1", summary: "1-based MAVLink mission index."),
                    BlueprintEntityField(name: "latitudeDeg", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "39.9255", summary: "WGS84 latitude degrees."),
                    BlueprintEntityField(name: "longitudeDeg", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "32.8662", summary: "WGS84 longitude degrees."),
                    BlueprintEntityField(name: "altitudeAGLMeters", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "85.0", summary: "Terrain-following Above-Ground-Level altitude in meters."),
                    BlueprintEntityField(name: "cruiseSpeedMPS", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "11.5", summary: "Target ground speed in m/s."),
                    BlueprintEntityField(name: "payloadTrigger", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"LIDAR_AND_RGB_NADIR\"", summary: "Sensor payload trigger command.")
                ],
                computedHelpersSwift: """
                public func compliesWithCeiling(maxAGLMeters: Double = 120.0) -> Bool {
                    altitudeAGLMeters > 5.0 && altitudeAGLMeters <= maxAGLMeters
                }
                """
            ),
            BlueprintDomainEntity(
                name: "UAVAirframeTelemetry",
                tableName: "uav_airframe_telemetry",
                summary: "Real-time RTK hexacopter airframe status with wind-compensated Return-to-Home (RTH) reserve math.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"uav-hex-01\"", isIndexed: true, summary: "Airframe tail number."),
                    BlueprintEntityField(name: "flightMode", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"AUTO_GRID\"", summary: "AUTO_GRID, LOITER_HOLD, RTH_FAILSAFE, LANDED."),
                    BlueprintEntityField(name: "batteryRemainingPercent", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "62.0", summary: "Smart LiPo 6S pack remaining %."),
                    BlueprintEntityField(name: "homeDistanceMeters", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1180.0", summary: "Slant range to launch pad in meters."),
                    BlueprintEntityField(name: "headwindMPS", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "4.2", summary: "Estimated return leg headwind component in m/s."),
                    BlueprintEntityField(name: "rtkFixedSatellites", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "24", summary: "Locked L1/L2 RTK GNSS satellites.")
                ],
                computedHelpersSwift: """
                /// Computes minimum safe RTH battery % including 15% landing reserve + wind-adjusted transit time.
                public var minimumSafeRTHBatteryPercent: Double {
                    let netReturnSpeed = max(3.5, 12.0 - headwindMPS)
                    let returnSeconds = homeDistanceMeters / netReturnSpeed
                    let transitDrainPercent = (returnSeconds / 60.0) * 3.2
                    return min(95.0, 15.0 + transitDrainPercent)
                }

                public var mustTriggerRTHFailsafe: Bool {
                    batteryRemainingPercent <= minimumSafeRTHBatteryPercent
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "waypoints",
                swiftType: "[UAVMissionWaypoint]",
                initialValueLiteral: """
                [
                    UAVMissionWaypoint(id: "wp-01", sequenceOrder: 1, latitudeDeg: 39.9255, longitudeDeg: 32.8662, altitudeAGLMeters: 85.0, cruiseSpeedMPS: 11.5, payloadTrigger: "LIDAR_SWEEP"),
                    UAVMissionWaypoint(id: "wp-02", sequenceOrder: 2, latitudeDeg: 39.9288, longitudeDeg: 32.8701, altitudeAGLMeters: 90.0, cruiseSpeedMPS: 11.5, payloadTrigger: "ORTHO_NADIR_80_70")
                ]
                """,
                summary: "Uploaded autonomous survey mission grid."
            ),
            BlueprintStateProperty(
                name: "airframe",
                swiftType: "UAVAirframeTelemetry",
                initialValueLiteral: "UAVAirframeTelemetry()",
                summary: "Live 10Hz MAVLink v2 airframe telemetry."
            ),
            BlueprintStateProperty(
                name: "geofenceCeilingAGLMeters",
                swiftType: "Double",
                initialValueLiteral: "120.0",
                summary: "FAA Part 107 / EASA U-Space 120m (400ft) hard AGL ceiling."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "appendSurveyWaypoint(lat: Double, lon: Double, aglMeters: Double)",
                matchPattern: ".appendSurveyWaypoint(let lat, let lon, let aglMeters)",
                buttonTitle: "Append 95m Survey Leg",
                sampleDispatchLiteral: ".appendSurveyWaypoint(lat: 39.9310, lon: 32.8740, aglMeters: 95.0)",
                summary: "Validates waypoint against 120m AGL geofence ceiling before appending to flight plan.",
                mutationBodySwift: """
                guard aglMeters > 5.0 && aglMeters <= state.geofenceCeilingAGLMeters else {
                    state.lastAuditMessage = "GEOFENCE REJECT: \\(Int(aglMeters))m exceeds \\(Int(state.geofenceCeilingAGLMeters))m ceiling"
                    break
                }
                let nextSeq = state.waypoints.count + 1
                let wp = UAVMissionWaypoint(
                    id: "wp-0\\(nextSeq)",
                    sequenceOrder: nextSeq,
                    latitudeDeg: lat,
                    longitudeDeg: lon,
                    altitudeAGLMeters: aglMeters,
                    cruiseSpeedMPS: 11.5,
                    payloadTrigger: "ORTHO_NADIR_80_70"
                )
                state.waypoints.append(wp)
                state.lastAuditMessage = "Appended compliant waypoint \\(wp.id) @ \\(Int(aglMeters))m AGL"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "evaluateTelemetryAndFailsafe(batteryPercent: Double, headwindMPS: Double)",
                matchPattern: ".evaluateTelemetryAndFailsafe(let batteryPercent, let headwindMPS)",
                buttonTitle: "Test Headwind RTH Failsafe",
                sampleDispatchLiteral: ".evaluateTelemetryAndFailsafe(batteryPercent: 21.0, headwindMPS: 6.5)",
                summary: "Updates battery/wind state and automatically switches flight mode to RTH_FAILSAFE if reserve breached.",
                mutationBodySwift: """
                state.airframe.batteryRemainingPercent = batteryPercent
                state.airframe.headwindMPS = headwindMPS
                if state.airframe.mustTriggerRTHFailsafe {
                    state.airframe.flightMode = "RTH_FAILSAFE"
                    state.lastAuditMessage = "FAILSAFE ENGAGED: RTH triggered at \\(Int(batteryPercent))% battery"
                } else {
                    state.lastAuditMessage = "Telemetry nominal; RTH floor \\(String(format: "%.1f%%", state.airframe.minimumSafeRTHBatteryPercent))"
                }
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "uploadMAVLinkMission",
                method: .put,
                path: "/v1/gcs/mavlink/mission",
                requestPayloadType: "[UAVMissionWaypoint]",
                responseType: "Bool",
                requiresIdempotencyKey: true,
                offlineStubSwift: "true",
                summary: "Uploads CRC-verified waypoint array to autopilot over 900MHz/LTE link."
            ),
            BlueprintAPIEndpoint(
                methodName: "commandImmediateRTH",
                method: .post,
                path: "/v1/gcs/mavlink/rth",
                responseType: "UAVAirframeTelemetry",
                requiresIdempotencyKey: true,
                offlineStubSwift: "DroneMissionControlState().airframe",
                summary: "Transmits MAV_CMD_NAV_RETURN_TO_LAUNCH high-priority override."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchRemoteIDAirspace",
                method: .get,
                path: "/v1/gcs/airspace/laanc",
                responseType: "Double",
                offlineStubSwift: "120.0",
                summary: "Fetches LAANC / U-Space authorized AGL ceiling for survey polygon."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "rtkFix", label: "GNSS Positioning", value: "RTK FIXED", delta: "24 sats · 1.4cm CEP", sfSymbol: "location.north.line.fill"),
            BlueprintKPIMetric(key: "rthFloor", label: "Dynamic RTH Floor", value: "23.1% SoC", delta: "4.2 m/s headwind", sfSymbol: "arrow.uturn.backward.circle.fill"),
            BlueprintKPIMetric(key: "aglCeiling", label: "Part 107 Ceiling", value: "90 / 120 m", delta: "Terrain-following", sfSymbol: "mountain.2.fill"),
            BlueprintKPIMetric(key: "linkQuality", label: "AES-256 C2 Link", value: "99.4% LQ", delta: "1.18 km slant", sfSymbol: "dot.radiowaves.up.forward")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "uav-1", headline: "WP-01 · Solar Farm North Corridor", subheadline: "85m AGL · 11.5 m/s · LiDAR + Thermal Ortho Sweep", trailingMetric: "COMPLIANT", statusTag: "COMPLETED"),
            BlueprintSampleRecord(id: "uav-2", headline: "WP-02 · Substation Insulator Inspection", subheadline: "90m AGL · 80/70% overlap · RTK Fixed 1.4cm", trailingMetric: "ACTIVE LEG", statusTag: "IN FLIGHT"),
            BlueprintSampleRecord(id: "uav-3", headline: "HEX-01 Airframe · 6S 22,000mAh Smart Pack", subheadline: "62% remaining vs 23.1% wind-adjusted RTH floor", trailingMetric: "+38.9% Margin", statusTag: "NOMINAL")
        ],
        onboardingPages: [
            FlowPage(
                id: "preflight-checklist",
                title: "Verify RTK Base Station & Compass Calibration",
                body: "Confirm <2cm RTK Fixed convergence, prop-lock torque, and Remote ID broadcast.",
                style: "hero",
                actions: ["Complete Preflight Check"]
            ),
            FlowPage(
                id: "geofence-ceiling",
                title: "Lock Airspace Geofence & Lost-Link Policy",
                body: "Enforce 120m AGL hard ceiling and automatic Return-to-Home on C2 link timeout.",
                style: "choice",
                actions: ["120m Part 107 / U-Space", "60m Industrial Corridor"]
            ),
            FlowPage(
                id: "gcs-ready",
                title: "Drone Mission Control Armed",
                body: "Wind-aware RTH reserve math, terrain geofencing, and MAVLink v2 signing are live.",
                style: "completion",
                actions: ["Launch Mission Control"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "uav.title", en: "Autonomous Drone Mission Control", tr: "Otonom İHA Görev Kontrol İstasyonu"),
            BlueprintLocalizedKey(key: "uav.rth_failsafe", en: "Return-to-Home Failsafe", tr: "Eve Dönüş Güvenlik Modu (RTH)"),
            BlueprintLocalizedKey(key: "uav.geofence_agl", en: "Hard Geofence Ceiling (AGL)", tr: "Coğrafi İrtifa Sınırı (AGL)"),
            BlueprintLocalizedKey(key: "uav.rtk_fixed", en: "Centimeter RTK GNSS Lock", tr: "Santimetre Hassasiyetli RTK Kilidi"),
            BlueprintLocalizedKey(key: "uav.headwind_margin", en: "Headwind Battery Reserve", tr: "Karşı Rüzgar Batarya Rezervi"),
            BlueprintLocalizedKey(key: "uav.append_wp", en: "Append Survey Waypoint", tr: "Haritalama Noktası Ekle")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryDiskSpace",
                reasonCodes: ["E174.1"],
                purposeSummary: "Checks iPad storage before downloading offline DEM terrain elevation tiles."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Detects MAVLink heartbeat timeouts within 1500ms."
            )
        ],
        customStateComputedSwift: """
        public var allWaypointsGeofenceCompliant: Bool {
            waypoints.allSatisfy { $0.compliesWithCeiling(maxAGLMeters: geofenceCeilingAGLMeters) }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("MAVLink v2 Flight Director · \\(store.state.airframe.flightMode)", systemImage: "safari.fill")
                    .font(.headline)
                Spacer()
                Text("RTH Floor \\(String(format: "%.1f%%", store.state.airframe.minimumSafeRTHBatteryPercent))")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("Battery \\(Int(store.state.airframe.batteryRemainingPercent))% · Geofence OK: \\(store.state.allWaypointsGeofenceCompliant ? "YES" : "BREACH")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return String(format: "GCS Flight Copilot: Mode %@, battery %.0f%% vs %.1f%% wind-compensated RTH floor.", state.airframe.flightMode, state.airframe.batteryRemainingPercent, state.airframe.minimumSafeRTHBatteryPercent)
        """,
        customUnitTestsSwift: """
        @Test("Geofence rejects 150m waypoint and strong headwind triggers RTH failsafe at low battery")
        func geofenceCeilingAndWindRTHFailsafe() {
            var state = DroneMissionControlState()
            let initialCount = state.waypoints.count
            _ = DroneMissionControlReducer.reduce(
                state: &state,
                action: .appendSurveyWaypoint(lat: 39.94, lon: 32.88, aglMeters: 150.0)
            )
            #expect(state.waypoints.count == initialCount)

            _ = DroneMissionControlReducer.reduce(
                state: &state,
                action: .evaluateTelemetryAndFailsafe(batteryPercent: 20.0, headwindMPS: 7.0)
            )
            #expect(state.airframe.flightMode == "RTH_FAILSAFE")
        }
        """,
        securityPostureHighlights: [
            "MAVLink v2 Ed25519/SHA-256 packet signing defeats RF command injection.",
            "Synchronous AGL ceiling gate rejects out-of-envelope waypoints before radio upload.",
            "Offline DEM elevation caching supports BVLOS mountain corridor inspections."
        ]
    )
}
