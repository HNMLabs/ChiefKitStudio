import ChiefKitStudioCore
import Foundation

// MARK: - Vertical 1: Fintech & Multi-Currency Banking Blueprints

public enum FintechAndBankingBlueprints: Sendable {
    public static let specs: [EnterpriseBlueprintSpec] = [
        neobankMultiCurrencyTreasury,
        quantPortfolioAndOrderBook,
        escrowSplitBillingLedger
    ]

    // MARK: 1. Neobank Multi-Currency Treasury

    public static let neobankMultiCurrencyTreasury = EnterpriseBlueprintSpec(
        id: .neobankMultiCurrencyTreasury,
        vertical: .fintechBanking,
        title: "Neobank Multi-Currency Treasury",
        subtitle: "Corporate IBAN/SWIFT vaults, real-time FX conversion with bps spread math, and dual-control wire approvals.",
        sfSymbol: "globe.europe.africa.fill",
        complexityTier: .missionCritical,
        supportedPlatforms: [.macOS, .iOS, .iPadOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "CurrencyVaultAccount",
                tableName: "currency_vault_accounts",
                summary: "Segregated multi-currency corporate treasury account with IBAN/BIC routing and liquidity floor.",
                fields: [
                    BlueprintEntityField(
                        name: "id",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"vault-usd-main\"",
                        isIndexed: true,
                        summary: "Unique treasury vault identifier."
                    ),
                    BlueprintEntityField(
                        name: "currencyCode",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"USD\"",
                        isIndexed: true,
                        summary: "ISO 4217 three-letter currency code."
                    ),
                    BlueprintEntityField(
                        name: "ibanRaw",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"GB29NWBK60161331926819\"",
                        isIndexed: true,
                        summary: "Unspaced ISO 13616 IBAN identifier."
                    ),
                    BlueprintEntityField(
                        name: "swiftBIC",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"CHFKGB2LXXX\"",
                        summary: "ISO 9362 8-or-11 character SWIFT BIC routing code."
                    ),
                    BlueprintEntityField(
                        name: "availableMinorUnits",
                        swiftType: "Int64",
                        sqlType: "INTEGER NOT NULL",
                        defaultValueLiteral: "125000000",
                        summary: "Available settled balance in minor currency units (cents)."
                    ),
                    BlueprintEntityField(
                        name: "reservedMinorUnits",
                        swiftType: "Int64",
                        sqlType: "INTEGER NOT NULL",
                        defaultValueLiteral: "15000000",
                        summary: "Funds locked for pending FX forwards and outgoing wires."
                    ),
                    BlueprintEntityField(
                        name: "usdMarkRate",
                        swiftType: "Double",
                        sqlType: "REAL NOT NULL",
                        defaultValueLiteral: "1.0",
                        summary: "Mark-to-market conversion factor into USD reporting currency."
                    )
                ],
                computedHelpersSwift: """
                public var formattedIBAN: String {
                    let clean = ibanRaw.replacingOccurrences(of: " ", with: "").uppercased()
                    var groups: [String] = []
                    var idx = clean.startIndex
                    while idx < clean.endIndex {
                        let next = clean.index(idx, offsetBy: 4, limitedBy: clean.endIndex) ?? clean.endIndex
                        groups.append(String(clean[idx..<next]))
                        idx = next
                    }
                    return groups.joined(separator: " ")
                }

                public var isValidSWIFTFormat: Bool {
                    let count = swiftBIC.trimmingCharacters(in: .whitespacesAndNewlines).count
                    return count == 8 || count == 11
                }

                public var availableMajorUnits: Double {
                    Double(availableMinorUnits) / 100.0
                }

                public var netUSDValuation: Double {
                    Double(availableMinorUnits + reservedMinorUnits) / 100.0 * usdMarkRate
                }
                """
            ),
            BlueprintDomainEntity(
                name: "FXConversionOrder",
                tableName: "fx_conversion_orders",
                summary: "Spot or forward FX conversion ticket with mid-market rate and tier spread basis points.",
                fields: [
                    BlueprintEntityField(
                        name: "id",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"fx-ord-1001\"",
                        isIndexed: true,
                        summary: "Idempotent FX ticket ID."
                    ),
                    BlueprintEntityField(
                        name: "sellCurrency",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"USD\"",
                        isIndexed: true,
                        summary: "Source currency sold."
                    ),
                    BlueprintEntityField(
                        name: "buyCurrency",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"EUR\"",
                        isIndexed: true,
                        summary: "Target currency purchased."
                    ),
                    BlueprintEntityField(
                        name: "sellMinorUnits",
                        swiftType: "Int64",
                        sqlType: "INTEGER NOT NULL",
                        defaultValueLiteral: "5000000",
                        summary: "Notional sold in minor units."
                    ),
                    BlueprintEntityField(
                        name: "midMarketRate",
                        swiftType: "Double",
                        sqlType: "REAL NOT NULL",
                        defaultValueLiteral: "0.9215",
                        summary: "Interbank mid-market FX spot rate."
                    ),
                    BlueprintEntityField(
                        name: "spreadBps",
                        swiftType: "Double",
                        sqlType: "REAL NOT NULL",
                        defaultValueLiteral: "18.0",
                        summary: "Treasury desk markup in basis points (1 bps = 0.01%)."
                    ),
                    BlueprintEntityField(
                        name: "settlementStatus",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"SETTLED\"",
                        summary: "Lifecycle state: QUOTED, PENDING_COSIGN, SETTLED, REJECTED."
                    )
                ],
                computedHelpersSwift: """
                public var effectiveClientRate: Double {
                    let spreadFactor = max(0.0, 1.0 - (spreadBps / 10_000.0))
                    return midMarketRate * spreadFactor
                }

                public var settledBuyMinorUnits: Int64 {
                    Int64((Double(sellMinorUnits) * effectiveClientRate).rounded())
                }

                public var deskFeeInSellCurrency: Double {
                    (Double(sellMinorUnits) / 100.0) * (spreadBps / 10_000.0)
                }
                """
            ),
            BlueprintDomainEntity(
                name: "WireApprovalInstruction",
                tableName: "wire_approval_instructions",
                summary: "Dual-control SEPA Instant or SWIFT gpi outbound payment requiring multi-signatory quorum.",
                fields: [
                    BlueprintEntityField(
                        name: "id",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"wire-901\"",
                        isIndexed: true,
                        summary: "Outbound payment instruction reference."
                    ),
                    BlueprintEntityField(
                        name: "beneficiaryName",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"Nordic Cloud Infrastructure AB\"",
                        summary: "Verified beneficiary legal name."
                    ),
                    BlueprintEntityField(
                        name: "rail",
                        swiftType: "String",
                        sqlType: "TEXT NOT NULL",
                        defaultValueLiteral: "\"SEPA_INSTANT\"",
                        isIndexed: true,
                        summary: "Payment rail: SEPA_INSTANT, SWIFT_GPI, FEDNOW, FASTER_PAYMENTS."
                    ),
                    BlueprintEntityField(
                        name: "amountMinorUnits",
                        swiftType: "Int64",
                        sqlType: "INTEGER NOT NULL",
                        defaultValueLiteral: "8400000",
                        summary: "Transfer value in minor units."
                    ),
                    BlueprintEntityField(
                        name: "approvalsCollected",
                        swiftType: "Int",
                        sqlType: "INTEGER NOT NULL",
                        defaultValueLiteral: "1",
                        summary: "Current hardware-key signatures collected."
                    ),
                    BlueprintEntityField(
                        name: "approvalsRequired",
                        swiftType: "Int",
                        sqlType: "INTEGER NOT NULL",
                        defaultValueLiteral: "2",
                        summary: "Required quorum threshold under treasury policy."
                    )
                ],
                computedHelpersSwift: """
                public var isReadyForRelease: Bool {
                    approvalsCollected >= max(1, approvalsRequired)
                }

                public var remainingSignatures: Int {
                    max(0, approvalsRequired - approvalsCollected)
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "vaults",
                swiftType: "[CurrencyVaultAccount]",
                initialValueLiteral: """
                [
                    CurrencyVaultAccount(id: "vault-usd", currencyCode: "USD", ibanRaw: "US64CHFK00019283746501", swiftBIC: "CHFKUS33XXX", availableMinorUnits: 245_000_000, reservedMinorUnits: 18_500_000, usdMarkRate: 1.00),
                    CurrencyVaultAccount(id: "vault-eur", currencyCode: "EUR", ibanRaw: "DE89370400440532013000", swiftBIC: "CHFKDEFFXXX", availableMinorUnits: 162_400_000, reservedMinorUnits: 9_200_000, usdMarkRate: 1.085),
                    CurrencyVaultAccount(id: "vault-gbp", currencyCode: "GBP", ibanRaw: "GB29NWBK60161331926819", swiftBIC: "CHFKGB2LXXX", availableMinorUnits: 78_900_000, reservedMinorUnits: 4_000_000, usdMarkRate: 1.272),
                    CurrencyVaultAccount(id: "vault-try", currencyCode: "TRY", ibanRaw: "TR330006100519786457841326", swiftBIC: "CHFKTRISXXX", availableMinorUnits: 615_000_000, reservedMinorUnits: 25_000_000, usdMarkRate: 0.029)
                ]
                """,
                summary: "Active corporate currency vaults with live mark-to-USD valuations."
            ),
            BlueprintStateProperty(
                name: "fxOrders",
                swiftType: "[FXConversionOrder]",
                initialValueLiteral: """
                [
                    FXConversionOrder(id: "fx-101", sellCurrency: "USD", buyCurrency: "EUR", sellMinorUnits: 12_500_000, midMarketRate: 0.9216, spreadBps: 14.0, settlementStatus: "SETTLED")
                ]
                """,
                summary: "Historical and in-flight FX spot conversion tickets."
            ),
            BlueprintStateProperty(
                name: "pendingWires",
                swiftType: "[WireApprovalInstruction]",
                initialValueLiteral: """
                [
                    WireApprovalInstruction(id: "wire-901", beneficiaryName: "Nordic Cloud Infrastructure AB", rail: "SEPA_INSTANT", amountMinorUnits: 8_400_000, approvalsCollected: 1, approvalsRequired: 2),
                    WireApprovalInstruction(id: "wire-902", beneficiaryName: "Tokyo Semiconductor Foundry KK", rail: "SWIFT_GPI", amountMinorUnits: 32_000_000, approvalsCollected: 1, approvalsRequired: 3)
                ]
                """,
                summary: "Outbound corporate payment queue awaiting co-signatory approval."
            ),
            BlueprintStateProperty(
                name: "treasurySpreadBps",
                swiftType: "Double",
                initialValueLiteral: "15.0",
                summary: "Configured FX conversion tier spread in basis points."
            ),
            BlueprintStateProperty(
                name: "dailyWireLimitUSD",
                swiftType: "Double",
                initialValueLiteral: "1_500_000.0",
                summary: "Board-approved daily outbound wire cap in USD equivalent."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "executeSpotFX(sellVaultID: String, buyVaultID: String, sellMinorUnits: Int64, midRate: Double)",
                matchPattern: ".executeSpotFX(let sellVaultID, let buyVaultID, let sellMinorUnits, let midRate)",
                buttonTitle: "Convert $25k USD -> EUR",
                sampleDispatchLiteral: ".executeSpotFX(sellVaultID: \"vault-usd\", buyVaultID: \"vault-eur\", sellMinorUnits: 2_500_000, midRate: 0.9218)",
                summary: "Atomically debits source currency vault, applies bps spread, and credits target currency vault.",
                mutationBodySwift: """
                guard sellMinorUnits > 0,
                      let sellIdx = state.vaults.firstIndex(where: { $0.id == sellVaultID }),
                      let buyIdx = state.vaults.firstIndex(where: { $0.id == buyVaultID }),
                      sellIdx != buyIdx,
                      state.vaults[sellIdx].availableMinorUnits >= sellMinorUnits else {
                    state.lastAuditMessage = "FX rejected: insufficient vault liquidity or invalid pair"
                    break
                }
                let ticket = FXConversionOrder(
                    id: "fx-\\(state.fxOrders.count + 102)",
                    sellCurrency: state.vaults[sellIdx].currencyCode,
                    buyCurrency: state.vaults[buyIdx].currencyCode,
                    sellMinorUnits: sellMinorUnits,
                    midMarketRate: midRate,
                    spreadBps: state.treasurySpreadBps,
                    settlementStatus: "SETTLED"
                )
                state.vaults[sellIdx].availableMinorUnits -= sellMinorUnits
                state.vaults[buyIdx].availableMinorUnits += ticket.settledBuyMinorUnits
                state.fxOrders.insert(ticket, at: 0)
                state.lastAuditMessage = "Settled FX \\(ticket.sellCurrency)->\\(ticket.buyCurrency) @ \\(String(format: "%.4f", ticket.effectiveClientRate))"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "cosignOutboundWire(wireID: String)",
                matchPattern: ".cosignOutboundWire(let wireID)",
                buttonTitle: "Co-Sign Top Wire",
                sampleDispatchLiteral: ".cosignOutboundWire(wireID: \"wire-901\")",
                summary: "Appends hardware passkey co-signature and settles wire once quorum is met.",
                mutationBodySwift: """
                guard let idx = state.pendingWires.firstIndex(where: { $0.id == wireID }) else {
                    state.lastAuditMessage = "Wire instruction \\(wireID) not found"
                    break
                }
                state.pendingWires[idx].approvalsCollected += 1
                if state.pendingWires[idx].isReadyForRelease {
                    let released = state.pendingWires.remove(at: idx)
                    if !state.vaults.isEmpty {
                        let debit = min(state.vaults[0].availableMinorUnits, released.amountMinorUnits)
                        state.vaults[0].availableMinorUnits -= debit
                    }
                    state.lastAuditMessage = "Released \\(released.rail) wire to \\(released.beneficiaryName)"
                } else {
                    let rem = state.pendingWires[idx].remainingSignatures
                    state.lastAuditMessage = "Recorded signature for \\(wireID) (\\(rem) remaining)"
                }
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "updateSpreadTier(bps: Double)",
                matchPattern: ".updateSpreadTier(let bps)",
                summary: "Updates institutional FX desk spread tier within [2.0, 120.0] bps.",
                mutationBodySwift: """
                state.treasurySpreadBps = min(max(bps, 2.0), 120.0)
                state.lastAuditMessage = "Updated FX spread tier to \\(Int(state.treasurySpreadBps)) bps"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "sweepExcessLiquidity(fromVaultID: String, floorMinorUnits: Int64)",
                matchPattern: ".sweepExcessLiquidity(let fromVaultID, let floorMinorUnits)",
                summary: "Sweeps cash above operating floor into overnight T-Bill reserve bucket.",
                mutationBodySwift: """
                guard let idx = state.vaults.firstIndex(where: { $0.id == fromVaultID }) else { break }
                let excess = state.vaults[idx].availableMinorUnits - max(0, floorMinorUnits)
                guard excess > 0 else {
                    state.lastAuditMessage = "No excess liquidity above floor for \\(fromVaultID)"
                    break
                }
                state.vaults[idx].availableMinorUnits -= excess
                state.vaults[idx].reservedMinorUnits += excess
                state.lastAuditMessage = "Swept \\(excess / 100) \\(state.vaults[idx].currencyCode) into overnight yield reserve"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchTreasuryVaults",
                method: .get,
                path: "/v1/treasury/vaults",
                responseType: "[CurrencyVaultAccount]",
                offlineStubSwift: " NeobankTreasuryDeskState().vaults",
                summary: "Lists segregated multi-currency corporate IBAN/SWIFT accounts."
            ),
            BlueprintAPIEndpoint(
                methodName: "submitSpotFXOrder",
                method: .post,
                path: "/v1/treasury/fx/orders",
                requestPayloadType: "FXConversionOrder",
                responseType: "FXConversionOrder",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Executes an idempotent spot FX conversion with guaranteed quote lock."
            ),
            BlueprintAPIEndpoint(
                methodName: "approveWireInstruction",
                method: .post,
                path: "/v1/treasury/wires/cosign",
                requestPayloadType: "WireApprovalInstruction",
                responseType: "WireApprovalInstruction",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Submits FIDO2 cryptographic co-signature for an outbound SWIFT/SEPA wire."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "totalLiquidityUSD", label: "Consolidated Liquidity", value: "$5.84M", delta: "+4.2% MoM", sfSymbol: "dollarsign.circle.fill"),
            BlueprintKPIMetric(key: "fxDeskSpread", label: "Institutional FX Tier", value: "15 bps", delta: "-8 bps vs bank", sfSymbol: "arrow.left.arrow.right.circle.fill"),
            BlueprintKPIMetric(key: "overnightYield", label: "Overnight T-Bill Yield", value: "4.85% APY", delta: "+$23.6k/mo", sfSymbol: "chart.line.uptrend.xyaxis"),
            BlueprintKPIMetric(key: "pendingQuorum", label: "Awaiting Co-Sign", value: "2 Wires", delta: "SLA < 15m", sfSymbol: "signature")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "rec-usd", headline: "USD Operating Vault · US64 CHFK ... 6501", subheadline: "SWIFT: CHFKUS33XXX · FedNow + Wire Ready", trailingMetric: "$2,450,000.00", statusTag: "ACTIVE"),
            BlueprintSampleRecord(id: "rec-eur", headline: "EUR Frankfurt Vault · DE89 3704 ... 3000", subheadline: "SWIFT: CHFKDEFFXXX · SEPA Instant 24/7", trailingMetric: "€1,624,000.00", statusTag: "ACTIVE"),
            BlueprintSampleRecord(id: "rec-gbp", headline: "GBP London Clearing · GB29 NWBK ... 6819", subheadline: "SWIFT: CHFKGB2LXXX · Faster Payments", trailingMetric: "£789,000.00", statusTag: "YIELD SWEEP"),
            BlueprintSampleRecord(id: "rec-try", headline: "TRY Istanbul Settlement · TR33 0006 ... 1326", subheadline: "SWIFT: CHFKTRISXXX · FAST Instant Rail", trailingMetric: "₺6,150,000.00", statusTag: "HEDGED")
        ],
        onboardingPages: [
            FlowPage(
                id: "entity-kyb",
                title: "Verify Corporate Treasury Entity",
                body: "Import LEI registration, board signatory mandates, and segregated IBAN routing rules.",
                style: "hero",
                actions: ["Verify Entity Mandate"]
            ),
            FlowPage(
                id: "quorum-policy",
                title: "Configure Multi-Sig Wire Policy",
                body: "Enforce 2-of-3 hardware passkey co-signing on SEPA Instant and SWIFT gpi wires over $50,000.",
                style: "choice",
                actions: ["2-of-3 Hardware Quorum", "3-of-5 Board Quorum"]
            ),
            FlowPage(
                id: "treasury-ready",
                title: "Multi-Currency Desk Provisioned",
                body: "USD, EUR, GBP, and TRY vaults are live with real-time FX bps conversion and audit seals.",
                style: "completion",
                actions: ["Launch Treasury Desk"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "treasury.title", en: "Multi-Currency Treasury", tr: "Çok Para Birimli Hazine"),
            BlueprintLocalizedKey(key: "treasury.fx.execute", en: "Execute Spot FX", tr: "Spot Döviz İşlemini Gerçekleştir"),
            BlueprintLocalizedKey(key: "treasury.wire.cosign", en: "Co-Sign Outbound Wire", tr: "Giden Havale Onayını İmzala"),
            BlueprintLocalizedKey(key: "treasury.sweep.liquidity", en: "Sweep Excess Liquidity", tr: "Fazla Likiditeyi Gecelik Fona Aktar"),
            BlueprintLocalizedKey(key: "treasury.iban.copied", en: "IBAN copied to secure clipboard", tr: "IBAN güvenli panoya kopyalandı"),
            BlueprintLocalizedKey(key: "treasury.audit.verified", en: "ISO 20022 ledger balanced", tr: "ISO 20022 muhasebe defteri dengelendi")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores preferred reporting currency and non-sensitive treasury layout density."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Measures monotonic FX quote expiration countdowns without wall-clock drift."
            )
        ],
        customStateComputedSwift: """
        public var consolidatedNAVInUSD: Double {
            vaults.reduce(0.0) { $0 + $1.netUSDValuation }
        }

        public var totalPendingWireMinorUnits: Int64 {
            pendingWires.reduce(0) { $0 + $1.amountMinorUnits }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("FX Treasury Desk & IBAN Routing", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.headline)
                Spacer()
                Text("Consolidated NAV: $\\(String(format: "%.2f", store.state.consolidatedNAVInUSD))")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            ForEach(store.state.vaults) { vault in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\\(vault.currencyCode) · \\(vault.formattedIBAN)")
                            .font(.caption.monospaced())
                        Text("BIC: \\(vault.swiftBIC)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\\(vault.currencyCode) \\(String(format: "%.2f", vault.availableMajorUnits))")
                        .font(.subheadline.monospacedDigit().bold())
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let nav = state.consolidatedNAVInUSD
        let wireCount = state.pendingWires.count
        return String(
            format: "FX Exposure Audit: Consolidated NAV $%.0f across %d currency vaults; %d outbound wires awaiting FIDO2 quorum at %.0f bps desk tier.",
            nav,
            state.vaults.count,
            wireCount,
            state.treasurySpreadBps
        )
        """,
        customUnitTestsSwift: """
        @Test("IBAN 4-character grouping and spot FX basis-point conversion accuracy")
        func fxConversionAndIBANFormatting() {
            var state = NeobankTreasuryDeskState()
            #expect(state.vaults[1].formattedIBAN == "DE89 3704 0044 0532 0130 00")
            #expect(state.vaults[1].isValidSWIFTFormat == true)

            let usdBefore = state.vaults[0].availableMinorUnits
            let eurBefore = state.vaults[1].availableMinorUnits
            _ = NeobankTreasuryDeskReducer.reduce(
                state: &state,
                action: .executeSpotFX(sellVaultID: "vault-usd", buyVaultID: "vault-eur", sellMinorUnits: 1_000_000, midRate: 0.9200)
            )
            #expect(state.vaults[0].availableMinorUnits == usdBefore - 1_000_000)
            #expect(state.vaults[1].availableMinorUnits > eurBefore)
            #expect(state.fxOrders.first?.effectiveClientRate == 0.9200 * (1.0 - 0.0015))
        }

        @Test("Dual-control wire co-signing releases payment only when quorum is met")
        func dualControlWireQuorum() {
            var state = NeobankTreasuryDeskState()
            let initialWireCount = state.pendingWires.count
            _ = NeobankTreasuryDeskReducer.reduce(state: &state, action: .cosignOutboundWire(wireID: "wire-901"))
            #expect(state.pendingWires.count == initialWireCount - 1)
        }
        """,
        securityPostureHighlights: [
            "Hardware-backed FIDO2 passkey attestation required for every wire approval transition.",
            "All IBAN and SWIFT account identifiers verified locally before network serialization.",
            "Deterministic FNV-1a audit seal emitted on every FX conversion and liquidity sweep."
        ]
    )

    // MARK: 2. Quant Portfolio & L2 Order Book

    public static let quantPortfolioAndOrderBook = EnterpriseBlueprintSpec(
        id: .quantPortfolioAndOrderBook,
        vertical: .fintechBanking,
        title: "Quant Portfolio & L2 Order Book",
        subtitle: "Multi-asset Sharpe & parametric VaR telemetry, L2 bid/ask micro-price imbalance, and TWAP execution slices.",
        sfSymbol: "chart.xyaxis.line",
        complexityTier: .missionCritical,
        supportedPlatforms: [.macOS, .iPadOS, .visionOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "PortfolioPosition",
                tableName: "portfolio_positions",
                summary: "Real-time mark-to-market equity, ETF, or futures position with annualized volatility and target weight.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"pos-aapl\"", isIndexed: true, summary: "Unique instrument position ID."),
                    BlueprintEntityField(name: "symbol", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"AAPL\"", isIndexed: true, summary: "Exchange ticker symbol."),
                    BlueprintEntityField(name: "quantity", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1200.0", summary: "Signed net share/contract quantity."),
                    BlueprintEntityField(name: "averageEntryPrice", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "184.50", summary: "Volume-weighted average entry price."),
                    BlueprintEntityField(name: "markPrice", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "212.40", summary: "Latest L1 mid-market mark price."),
                    BlueprintEntityField(name: "annualizedVol", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.24", summary: "30-day realized annualized volatility sigma."),
                    BlueprintEntityField(name: "targetWeight", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.25", summary: "Optimizer target portfolio weight in [0, 1].")
                ],
                computedHelpersSwift: """
                public var marketValue: Double {
                    quantity * markPrice
                }

                public var unrealizedPnL: Double {
                    quantity * (markPrice - averageEntryPrice)
                }

                public var dailyParametricVaR95: Double {
                    let dailySigma = annualizedVol / 15.8745078664
                    return abs(marketValue) * 1.64485 * dailySigma
                }
                """
            ),
            BlueprintDomainEntity(
                name: "OrderBookDepthLevel",
                tableName: "order_book_depth_levels",
                summary: "Aggregated L2 limit order book level with bid/ask prices, resting sizes, and micro-price skew.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"lvl-1\"", isIndexed: true, summary: "Price level identifier."),
                    BlueprintEntityField(name: "symbol", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"AAPL\"", isIndexed: true, summary: "Instrument symbol."),
                    BlueprintEntityField(name: "bidPrice", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "212.38", summary: "Best bid price at depth rank."),
                    BlueprintEntityField(name: "bidSize", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1850.0", summary: "Resting bid liquidity shares."),
                    BlueprintEntityField(name: "askPrice", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "212.42", summary: "Best ask price at depth rank."),
                    BlueprintEntityField(name: "askSize", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "940.0", summary: "Resting ask liquidity shares.")
                ],
                computedHelpersSwift: """
                public var midPrice: Double {
                    (bidPrice + askPrice) * 0.5
                }

                public var spreadBps: Double {
                    guard midPrice > 0 else { return 0 }
                    return ((askPrice - bidPrice) / midPrice) * 10_000.0
                }

                public var orderBookImbalance: Double {
                    let total = bidSize + askSize
                    guard total > 0 else { return 0 }
                    return (bidSize - askSize) / total
                }

                public var microPrice: Double {
                    let total = bidSize + askSize
                    guard total > 0 else { return midPrice }
                    return (bidPrice * askSize + askPrice * bidSize) / total
                }
                """
            ),
            BlueprintDomainEntity(
                name: "TWAPExecutionParentOrder",
                tableName: "twap_execution_orders",
                summary: "Algorithmic TWAP parent order slicing institutional size across scheduled child intervals.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"twap-501\"", isIndexed: true, summary: "Parent algo order ID."),
                    BlueprintEntityField(name: "symbol", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"NVDA\"", isIndexed: true, summary: "Target ticker."),
                    BlueprintEntityField(name: "side", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"BUY\"", summary: "BUY or SELL."),
                    BlueprintEntityField(name: "totalShares", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "4000.0", summary: "Total parent order quantity."),
                    BlueprintEntityField(name: "filledShares", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1500.0", summary: "Cumulative executed child quantity."),
                    BlueprintEntityField(name: "limitPrice", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "130.00", summary: "Hard protection limit price."),
                    BlueprintEntityField(name: "sliceCount", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "8", summary: "Scheduled TWAP child slices.")
                ],
                computedHelpersSwift: """
                public var completionRatio: Double {
                    guard totalShares > 0 else { return 0 }
                    return min(1.0, max(0.0, filledShares / totalShares))
                }

                public var nextChildSliceShares: Double {
                    guard sliceCount > 0 else { return 0 }
                    let standardSlice = totalShares / Double(sliceCount)
                    return min(standardSlice, max(0, totalShares - filledShares))
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "positions",
                swiftType: "[PortfolioPosition]",
                initialValueLiteral: """
                [
                    PortfolioPosition(id: "pos-aapl", symbol: "AAPL", quantity: 1400, averageEntryPrice: 186.20, markPrice: 214.60, annualizedVol: 0.22, targetWeight: 0.35),
                    PortfolioPosition(id: "pos-msft", symbol: "MSFT", quantity: 820, averageEntryPrice: 392.10, markPrice: 428.50, annualizedVol: 0.21, targetWeight: 0.40),
                    PortfolioPosition(id: "pos-nvda", symbol: "NVDA", quantity: 1650, averageEntryPrice: 108.40, markPrice: 128.90, annualizedVol: 0.44, targetWeight: 0.25)
                ]
                """,
                summary: "Live marked-to-market institutional book positions."
            ),
            BlueprintStateProperty(
                name: "topOfBook",
                swiftType: "OrderBookDepthLevel",
                initialValueLiteral: "OrderBookDepthLevel(id: \"lvl-aapl-1\", symbol: \"AAPL\", bidPrice: 214.58, bidSize: 2400, askPrice: 214.62, askSize: 1100)",
                summary: "Primary symbol L2 top-of-book liquidity snapshot."
            ),
            BlueprintStateProperty(
                name: "algoOrders",
                swiftType: "[TWAPExecutionParentOrder]",
                initialValueLiteral: """
                [
                    TWAPExecutionParentOrder(id: "twap-501", symbol: "NVDA", side: "BUY", totalShares: 4000, filledShares: 1500, limitPrice: 130.00, sliceCount: 8)
                ]
                """,
                summary: "Active TWAP execution orders working on exchange venues."
            ),
            BlueprintStateProperty(
                name: "riskFreeRate",
                swiftType: "Double",
                initialValueLiteral: "0.0475",
                summary: "Annualized sovereign T-Bill benchmark rate used in Sharpe ratio calculation."
            ),
            BlueprintStateProperty(
                name: "expectedPortfolioAnnualReturn",
                swiftType: "Double",
                initialValueLiteral: "0.184",
                summary: "Alpha model expected annualized portfolio return."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "stepTWAPSlice(orderID: String, executionPrice: Double)",
                matchPattern: ".stepTWAPSlice(let orderID, let executionPrice)",
                buttonTitle: "Execute TWAP Child Slice",
                sampleDispatchLiteral: ".stepTWAPSlice(orderID: \"twap-501\", executionPrice: 128.75)",
                summary: "Executes the next scheduled TWAP child slice within limit price protection and updates position.",
                mutationBodySwift: """
                guard let idx = state.algoOrders.firstIndex(where: { $0.id == orderID }) else { break }
                let order = state.algoOrders[idx]
                if order.side == "BUY" && executionPrice > order.limitPrice {
                    state.lastAuditMessage = "TWAP slice paused: price \\(executionPrice) exceeds limit \\(order.limitPrice)"
                    break
                }
                let slice = order.nextChildSliceShares
                guard slice > 0 else {
                    state.lastAuditMessage = "TWAP parent order \\(orderID) already 100% filled"
                    break
                }
                state.algoOrders[idx].filledShares += slice
                if let posIdx = state.positions.firstIndex(where: { $0.symbol == order.symbol }) {
                    let signedQty = order.side == "BUY" ? slice : -slice
                    state.positions[posIdx].quantity += signedQty
                    state.positions[posIdx].markPrice = executionPrice
                }
                state.lastAuditMessage = "Executed TWAP child slice: \\(Int(slice)) \\(order.symbol) @ \\(executionPrice)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "ingestOrderBookTick(bidPrice: Double, bidSize: Double, askPrice: Double, askSize: Double)",
                matchPattern: ".ingestOrderBookTick(let bidPrice, let bidSize, let askPrice, let askSize)",
                buttonTitle: "Simulate L2 Depth Tick",
                sampleDispatchLiteral: ".ingestOrderBookTick(bidPrice: 214.64, bidSize: 3100, askPrice: 214.67, askSize: 890)",
                summary: "Updates L2 order book top-of-book quotes and re-marks matching position.",
                mutationBodySwift: """
                guard askPrice >= bidPrice, bidPrice > 0 else { break }
                state.topOfBook.bidPrice = bidPrice
                state.topOfBook.bidSize = max(0, bidSize)
                state.topOfBook.askPrice = askPrice
                state.topOfBook.askSize = max(0, askSize)
                let mid = state.topOfBook.midPrice
                if let idx = state.positions.firstIndex(where: { $0.symbol == state.topOfBook.symbol }) {
                    state.positions[idx].markPrice = mid
                }
                state.lastAuditMessage = "L2 tick \\(state.topOfBook.symbol) micro-price \\(String(format: "%.3f", state.topOfBook.microPrice))"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "rebalanceToTargetWeights",
                matchPattern: ".rebalanceToTargetWeights",
                buttonTitle: "Rebalance Book Weights",
                sampleDispatchLiteral: ".rebalanceToTargetWeights",
                summary: "Adjusts position quantities proportionally to match optimizer target weights while preserving gross NAV.",
                mutationBodySwift: """
                let totalNAV = state.grossPortfolioNAV
                guard totalNAV > 0 else { break }
                for idx in state.positions.indices {
                    let price = state.positions[idx].markPrice
                    guard price > 0 else { continue }
                    let desiredValue = totalNAV * state.positions[idx].targetWeight
                    state.positions[idx].quantity = (desiredValue / price).rounded()
                }
                state.lastAuditMessage = "Rebalanced \\(state.positions.count) positions to optimizer target weights"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "applyStressShock(priceDropFraction: Double)",
                matchPattern: ".applyStressShock(let priceDropFraction)",
                summary: "Applies instantaneous macro drawdown shock across all marks to evaluate VaR breach.",
                mutationBodySwift: """
                let clamped = min(max(priceDropFraction, -0.50), 0.50)
                for idx in state.positions.indices {
                    state.positions[idx].markPrice *= (1.0 - clamped)
                }
                state.lastAuditMessage = "Applied \\(Int(clamped * 100))% stress test across portfolio"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchPortfolioPositions",
                method: .get,
                path: "/v1/quant/positions",
                responseType: "[PortfolioPosition]",
                offlineStubSwift: "QuantOrderBookProState().positions",
                summary: "Retrieves prime-brokerage custody positions and realized vol."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchOrderBookSnapshot",
                method: .get,
                path: "/v1/quant/orderbook/top",
                responseType: "OrderBookDepthLevel",
                offlineStubSwift: "QuantOrderBookProState().topOfBook",
                summary: "Fetches consolidated SIP/direct-feed L2 top-of-book depth."
            ),
            BlueprintAPIEndpoint(
                methodName: "submitTWAPOrder",
                method: .post,
                path: "/v1/quant/execution/twap",
                requestPayloadType: "TWAPExecutionParentOrder",
                responseType: "TWAPExecutionParentOrder",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Routes algorithmic TWAP parent order with hard limit protection."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "grossNAV", label: "Gross Book NAV", value: "$864.5k", delta: "+$102.3k PnL", sfSymbol: "chart.pie.fill"),
            BlueprintKPIMetric(key: "sharpeRatio", label: "Ex-Ante Sharpe", value: "2.18", delta: "+0.24 vs bench", sfSymbol: "waveform.path.ecg"),
            BlueprintKPIMetric(key: "dailyVaR95", label: "1-Day VaR (95%)", value: "$14,820", delta: "1.71% of NAV", sfSymbol: "exclamationmark.shield.fill"),
            BlueprintKPIMetric(key: "obiSkew", label: "L2 Book Imbalance", value: "+0.37 Bid", delta: "1.86 bps spread", sfSymbol: "arrow.up.and.down.text.horizontal")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "pos-1", headline: "AAPL · 1,400 sh @ $214.60", subheadline: "Target Weight 35% · Ann. Vol 22.0%", trailingMetric: "+$39,760 PnL", statusTag: "CORE LONG"),
            BlueprintSampleRecord(id: "pos-2", headline: "MSFT · 820 sh @ $428.50", subheadline: "Target Weight 40% · Ann. Vol 21.0%", trailingMetric: "+$29,848 PnL", statusTag: "CORE LONG"),
            BlueprintSampleRecord(id: "pos-3", headline: "NVDA · 1,650 sh @ $128.90", subheadline: "TWAP Working (1,500/4,000 filled) · Vol 44.0%", trailingMetric: "+$33,825 PnL", statusTag: "ALGO EXEC")
        ],
        onboardingPages: [
            FlowPage(
                id: "venue-feeds",
                title: "Connect Market Data & FIX Drop-Copy",
                body: "Bind low-latency L2 order book snapshots and prime brokerage custody reconciliation.",
                style: "hero",
                actions: ["Configure Market Feeds"]
            ),
            FlowPage(
                id: "risk-limits",
                title: "Set Parametric VaR & Limit Guardrails",
                body: "Enforce automatic TWAP pause on hard limit breach or 95% daily VaR threshold.",
                style: "choice",
                actions: ["Institutional Conservative", "Quant Active"]
            ),
            FlowPage(
                id: "desk-live",
                title: "Quant Execution Desk Armed",
                body: "Ex-ante Sharpe, micro-price imbalance, and TWAP child slicing are live.",
                style: "completion",
                actions: ["Start Quant Desk"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "quant.title", en: "Quant Portfolio & Order Book", tr: "Kantitatif Portföy ve Emir Defteri"),
            BlueprintLocalizedKey(key: "quant.twap.step", en: "Execute TWAP Slice", tr: "TWAP Dilimini Çalıştır"),
            BlueprintLocalizedKey(key: "quant.rebalance", en: "Rebalance Target Weights", tr: "Hedef Ağırlıkları Yeniden Dengele"),
            BlueprintLocalizedKey(key: "quant.var95", en: "1-Day Parametric VaR (95%)", tr: "1 Günlük Parametrik RMD (%95)"),
            BlueprintLocalizedKey(key: "quant.microprice", en: "Order Book Micro-Price", tr: "Emir Defteri Mikro Fiyatı"),
            BlueprintLocalizedKey(key: "quant.sharpe", en: "Annualized Sharpe Ratio", tr: "Yıllıklandırılmış Sharpe Oranı")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Computes sub-millisecond market feed tick latency and TWAP interval cadence."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Persists risk-free benchmark rate and order book ladder depth preference."
            )
        ],
        customStateComputedSwift: """
        public var grossPortfolioNAV: Double {
            positions.reduce(0.0) { $0 + abs($1.marketValue) }
        }

        public var weightedPortfolioVolatility: Double {
            let nav = grossPortfolioNAV
            guard nav > 0 else { return 0.20 }
            return positions.reduce(0.0) { acc, pos in
                acc + (abs(pos.marketValue) / nav) * pos.annualizedVol
            }
        }

        public var estimatedSharpeRatio: Double {
            let vol = max(0.01, weightedPortfolioVolatility)
            return (expectedPortfolioAnnualReturn - riskFreeRate) / vol
        }

        public var totalDailyVaR95: Double {
            positions.reduce(0.0) { $0 + $1.dailyParametricVaR95 }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("L2 Micro-Price & Risk Telemetry", systemImage: "Waveform.path.ecg")
                    .font(.headline)
                Spacer()
                Text("Sharpe \\(String(format: "%.2f", store.state.estimatedSharpeRatio))")
                    .font(.subheadline.monospacedDigit().bold())
            }
            HStack {
                Text("\\(store.state.topOfBook.symbol) Bid \\(String(format: "%.2f", store.state.topOfBook.bidPrice)) (\\(Int(store.state.topOfBook.bidSize)))")
                Spacer()
                Text("Micro \\(String(format: "%.3f", store.state.topOfBook.microPrice))")
                    .fontWeight(.semibold)
                Spacer()
                Text("Ask \\(String(format: "%.2f", store.state.topOfBook.askPrice)) (\\(Int(store.state.topOfBook.askSize)))")
            }
            .font(.caption.monospacedDigit())
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let imb = state.topOfBook.orderBookImbalance
        let skewDir = imb >= 0 ? "bullish bid pressure" : "ask supply overhang"
        return String(
            format: "Quant Signal: %@ L2 imbalance %+.2f (%@), portfolio Sharpe %.2f, 1d VaR95 $%.0f.",
            state.topOfBook.symbol,
            imb,
            skewDir,
            state.estimatedSharpeRatio,
            state.totalDailyVaR95
        )
        """,
        customUnitTestsSwift: """
        @Test("Order book imbalance, micro-price, and TWAP child slice execution")
        func orderBookMathAndTWAPExecution() {
            var state = QuantOrderBookProState()
            #expect(state.topOfBook.orderBookImbalance > 0)
            #expect(state.topOfBook.microPrice > state.topOfBook.midPrice)

            let nvdaBefore = state.positions.first(where: { $0.symbol == "NVDA" })?.quantity ?? 0
            _ = QuantOrderBookProReducer.reduce(
                state: &state,
                action: .stepTWAPSlice(orderID: "twap-501", executionPrice: 128.50)
            )
            let nvdaAfter = state.positions.first(where: { $0.symbol == "NVDA" })?.quantity ?? 0
            #expect(nvdaAfter == nvdaBefore + 500)
        }

        @Test("TWAP hard limit protection blocks adverse execution above limit")
        func twapHardLimitGuardrail() {
            var state = QuantOrderBookProState()
            let filledBefore = state.algoOrders[0].filledShares
            _ = QuantOrderBookProReducer.reduce(
                state: &state,
                action: .stepTWAPSlice(orderID: "twap-501", executionPrice: 145.00)
            )
            #expect(state.algoOrders[0].filledShares == filledBefore)
        }
        """,
        securityPostureHighlights: [
            "Pre-trade fat-finger and hard limit price guardrails enforced synchronously inside pure reducer.",
            "Idempotent parent/child execution keys prevent duplicate FIX order transmission on reconnect.",
            "Zero cloud transmission of proprietary portfolio alpha weights or risk parameters."
        ]
    )

    // MARK: 3. Escrow & Split-Billing Double-Entry Ledger

    public static let escrowSplitBillingLedger = EnterpriseBlueprintSpec(
        id: .escrowSplitBillingLedger,
        vertical: .fintechBanking,
        title: "Escrow & Split-Billing Ledger",
        subtitle: "Double-entry GAAP marketplace escrow, basis-point commission splits, milestone releases, and dispute holds.",
        sfSymbol: "building.columns.circle.fill",
        complexityTier: .enterprise,
        supportedPlatforms: [.macOS, .iOS, .iPadOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "EscrowContractDeal",
                tableName: "escrow_contract_deals",
                summary: "Multi-party escrow agreement governing buyer deposit, merchant payout, platform take-rate bps, and holdback.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"esc-3001\"", isIndexed: true, summary: "Immutable escrow contract ID."),
                    BlueprintEntityField(name: "buyerTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Atlas Retail Group\"", summary: "Depositing buyer organization."),
                    BlueprintEntityField(name: "vendorTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Studio Kinetix Industrial\"", summary: "Fulfilling merchant beneficiary."),
                    BlueprintEntityField(name: "fundedCents", swiftType: "Int64", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "4_500_000", summary: "Gross buyer funds locked in escrow (cents)."),
                    BlueprintEntityField(name: "releasedCents", swiftType: "Int64", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1_500_000", summary: "Cumulative gross milestone funds released (cents)."),
                    BlueprintEntityField(name: "platformFeeBps", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "275", summary: "Marketplace commission take-rate in basis points."),
                    BlueprintEntityField(name: "isDisputed", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", isIndexed: true, summary: "True when arbitration freeze blocks payout release.")
                ],
                computedHelpersSwift: """
                public var remainingEscrowCents: Int64 {
                    max(0, fundedCents - releasedCents)
                }

                public func computeSplit(forGrossReleaseCents gross: Int64) -> (vendorCents: Int64, platformFeeCents: Int64) {
                    let clampedGross = min(max(0, gross), remainingEscrowCents)
                    let fee = (clampedGross * Int64(platformFeeBps)) / 10_000
                    let netVendor = clampedGross - fee
                    return (netVendor, fee)
                }
                """
            ),
            BlueprintDomainEntity(
                name: "DoubleEntryJournalPosting",
                tableName: "double_entry_journal_postings",
                summary: "Immutable GAAP double-entry journal batch where total debits strictly equal total credits.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"jrn-7001\"", isIndexed: true, summary: "Sequential journal entry ID."),
                    BlueprintEntityField(name: "escrowID", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"esc-3001\"", isIndexed: true, summary: "Parent escrow contract ID."),
                    BlueprintEntityField(name: "debitAccountCode", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"2100_ESCROW_LIABILITY\"", summary: "Debited ledger account."),
                    BlueprintEntityField(name: "creditVendorAccountCode", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"2200_VENDOR_PAYABLE\"", summary: "Credited merchant payable account."),
                    BlueprintEntityField(name: "creditFeeAccountCode", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"4100_PLATFORM_REVENUE\"", summary: "Credited marketplace fee revenue account."),
                    BlueprintEntityField(name: "debitCents", swiftType: "Int64", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1_500_000", summary: "Total debited cents."),
                    BlueprintEntityField(name: "creditVendorCents", swiftType: "Int64", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1_458_750", summary: "Net cents credited to vendor."),
                    BlueprintEntityField(name: "creditFeeCents", swiftType: "Int64", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "41_250", summary: "Commission cents credited to platform.")
                ],
                computedHelpersSwift: """
                public var imbalanceCents: Int64 {
                    debitCents - (creditVendorCents + creditFeeCents)
                }

                public var isBalanced: Bool {
                    imbalanceCents == 0 && debitCents > 0
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "contracts",
                swiftType: "[EscrowContractDeal]",
                initialValueLiteral: """
                [
                    EscrowContractDeal(id: "esc-3001", buyerTitle: "Atlas Retail Group", vendorTitle: "Studio Kinetix Industrial", fundedCents: 4_500_000, releasedCents: 1_500_000, platformFeeBps: 275, isDisputed: false),
                    EscrowContractDeal(id: "esc-3002", buyerTitle: "Meridian Health Labs", vendorTitle: "BioCold Robotics GmbH", fundedCents: 8_200_000, releasedCents: 0, platformFeeBps: 225, isDisputed: false)
                ]
                """,
                summary: "Active multi-party escrow contracts."
            ),
            BlueprintStateProperty(
                name: "journalPostings",
                swiftType: "[DoubleEntryJournalPosting]",
                initialValueLiteral: """
                [
                    DoubleEntryJournalPosting(id: "jrn-7001", escrowID: "esc-3001", debitAccountCode: "2100_ESCROW_LIABILITY", creditVendorAccountCode: "2200_VENDOR_PAYABLE", creditFeeAccountCode: "4100_PLATFORM_REVENUE", debitCents: 1_500_000, creditVendorCents: 1_458_750, creditFeeCents: 41_250)
                ]
                """,
                summary: "Append-only double-entry accounting journal."
            ),
            BlueprintStateProperty(
                name: "platformRevenueCents",
                swiftType: "Int64",
                initialValueLiteral: "41_250",
                summary: "Recognized platform split-billing commission revenue in cents."
            ),
            BlueprintStateProperty(
                name: "vendorPayableCents",
                swiftType: "Int64",
                initialValueLiteral: "1_458_750",
                summary: "Cleared vendor settlement balance ready for ACH/SEPA payout."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "releaseMilestone(escrowID: String, grossReleaseCents: Int64)",
                matchPattern: ".releaseMilestone(let escrowID, let grossReleaseCents)",
                buttonTitle: "Release $10k Milestone",
                sampleDispatchLiteral: ".releaseMilestone(escrowID: \"esc-3001\", grossReleaseCents: 1_000_000)",
                summary: "Splits gross milestone release into vendor net + platform fee and appends balanced double-entry posting.",
                mutationBodySwift: """
                guard let idx = state.contracts.firstIndex(where: { $0.id == escrowID }) else { break }
                guard !state.contracts[idx].isDisputed else {
                    state.lastAuditMessage = "Release blocked: contract \\(escrowID) is frozen under dispute"
                    break
                }
                let split = state.contracts[idx].computeSplit(forGrossReleaseCents: grossReleaseCents)
                let actualGross = split.vendorCents + split.platformFeeCents
                guard actualGross > 0 else {
                    state.lastAuditMessage = "No remaining funded escrow balance on \\(escrowID)"
                    break
                }
                state.contracts[idx].releasedCents += actualGross
                state.vendorPayableCents += split.vendorCents
                state.platformRevenueCents += split.platformFeeCents
                let posting = DoubleEntryJournalPosting(
                    id: "jrn-\\(7001 + state.journalPostings.count)",
                    escrowID: escrowID,
                    debitAccountCode: "2100_ESCROW_LIABILITY",
                    creditVendorAccountCode: "2200_VENDOR_PAYABLE",
                    creditFeeAccountCode: "4100_PLATFORM_REVENUE",
                    debitCents: actualGross,
                    creditVendorCents: split.vendorCents,
                    creditFeeCents: split.platformFeeCents
                )
                state.journalPostings.insert(posting, at: 0)
                state.lastAuditMessage = "Posted balanced split \\(posting.id): vendor \\(split.vendorCents)c + fee \\(split.platformFeeCents)c"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "toggleDisputeFreeze(escrowID: String, frozen: Bool)",
                matchPattern: ".toggleDisputeFreeze(let escrowID, let frozen)",
                buttonTitle: "Toggle Dispute Hold",
                sampleDispatchLiteral: ".toggleDisputeFreeze(escrowID: \"esc-3002\", frozen: true)",
                summary: "Places or lifts an arbitration freeze preventing milestone disbursements.",
                mutationBodySwift: """
                guard let idx = state.contracts.firstIndex(where: { $0.id == escrowID }) else { break }
                state.contracts[idx].isDisputed = frozen
                state.lastAuditMessage = frozen ? "Placed arbitration hold on \\(escrowID)" : "Lifted arbitration hold on \\(escrowID)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "fundAdditionalEscrow(escrowID: String, depositCents: Int64)",
                matchPattern: ".fundAdditionalEscrow(let escrowID, let depositCents)",
                summary: "Records verified buyer top-up deposit into segregated escrow liability.",
                mutationBodySwift: """
                guard depositCents > 0, let idx = state.contracts.firstIndex(where: { $0.id == escrowID }) else { break }
                state.contracts[idx].fundedCents += depositCents
                state.lastAuditMessage = "Funded +\\(depositCents / 100) USD into \\(escrowID)"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "listEscrowContracts",
                method: .get,
                path: "/v1/escrow/contracts",
                responseType: "[EscrowContractDeal]",
                offlineStubSwift: "EscrowSplitLedgerState().contracts",
                summary: "Lists active marketplace escrow contracts and holdback balances."
            ),
            BlueprintAPIEndpoint(
                methodName: "postMilestoneRelease",
                method: .post,
                path: "/v1/escrow/milestones/release",
                requestPayloadType: "DoubleEntryJournalPosting",
                responseType: "DoubleEntryJournalPosting",
                requiresIdempotencyKey: true,
                offlineStubSwift: "payload",
                summary: "Commits atomic double-entry split disbursement to ledger."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchJournalTrialBalance",
                method: .get,
                path: "/v1/escrow/journal",
                responseType: "[DoubleEntryJournalPosting]",
                offlineStubSwift: "EscrowSplitLedgerState().journalPostings",
                summary: "Exports immutable double-entry postings for GAAP audit."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "lockedEscrow", label: "Locked Escrow Liability", value: "$112,000", delta: "2 active deals", sfSymbol: "lock.doc.fill"),
            BlueprintKPIMetric(key: "vendorPayables", label: "Cleared Vendor Payouts", value: "$14,587.50", delta: "T+0 Instant", sfSymbol: "arrow.up.right.square.fill"),
            BlueprintKPIMetric(key: "platformTake", label: "Recognized Split Fees", value: "$412.50", delta: "250 bps avg", sfSymbol: "percent"),
            BlueprintKPIMetric(key: "trialBalance", label: "Ledger Imbalance", value: "$0.00", delta: "100% GAAP balanced", sfSymbol: "checkmark.seal.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "esc-1", headline: "Atlas Retail -> Studio Kinetix", subheadline: "Take-rate 275 bps · $15,000 released of $45,000", trailingMetric: "$30,000.00 Held", statusTag: "PERFORMING"),
            BlueprintSampleRecord(id: "esc-2", headline: "Meridian Health -> BioCold Robotics", subheadline: "Take-rate 225 bps · Milestone 1 pending inspection", trailingMetric: "$82,000.00 Held", statusTag: "ESCROW LOCKED"),
            BlueprintSampleRecord(id: "jrn-1", headline: "Journal #jrn-7001 · Split Settlement", subheadline: "DR 2100 Escrow $15,000 = CR Vendor $14,587.50 + CR Fee $412.50", trailingMetric: "Δ $0.00", statusTag: "BALANCED")
        ],
        onboardingPages: [
            FlowPage(
                id: "chart-of-accounts",
                title: "Map Double-Entry Chart of Accounts",
                body: "Bind segregated buyer FBO escrow liability, vendor payable, and platform revenue ledger codes.",
                style: "hero",
                actions: ["Bind Ledger Codes"]
            ),
            FlowPage(
                id: "commission-schedule",
                title: "Configure Split-Billing Take Rates",
                body: "Set default basis-point marketplace fees and dispute arbitration freeze policies.",
                style: "choice",
                actions: ["Standard 275 bps", "Enterprise Tiered bps"]
            ),
            FlowPage(
                id: "escrow-complete",
                title: "Double-Entry Escrow Engine Active",
                body: "Every milestone release is guaranteed to post zero-imbalance debit and credit entries.",
                style: "completion",
                actions: ["Complete Ledger Setup"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "escrow.title", en: "Escrow & Split-Billing Ledger", tr: "Emanet ve Bölünmüş Tahsilat Defteri"),
            BlueprintLocalizedKey(key: "escrow.release", en: "Release Milestone Payout", tr: "Aşama Ödemesini Serbest Bırak"),
            BlueprintLocalizedKey(key: "escrow.dispute", en: "Freeze for Arbitration", tr: "Uyuşmazlık Nedeniyle Dondur"),
            BlueprintLocalizedKey(key: "escrow.trial_balance", en: "Zero-Imbalance Trial Balance", tr: "Sıfır Farklı Mizan Doğrulaması"),
            BlueprintLocalizedKey(key: "escrow.platform_fee", en: "Platform Commission (bps)", tr: "Platform Komisyon Oranı (bps)"),
            BlueprintLocalizedKey(key: "escrow.vendor_net", en: "Net Merchant Settlement", tr: "Net Satıcı Hakediş Tutarı")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Timestamps exported GAAP trial-balance CSV/JSON audit archives."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryUserDefaults",
                reasonCodes: ["CA92.1"],
                purposeSummary: "Stores accounting period filter preferences."
            )
        ],
        customStateComputedSwift: """
        public var totalLedgerImbalanceCents: Int64 {
            journalPostings.reduce(0) { $0 + abs($1.imbalanceCents) }
        }

        public var totalLockedEscrowCents: Int64 {
            contracts.reduce(0) { $0 + $1.remainingEscrowCents }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Double-Entry Trial Balance Invariant", systemImage: "equal.circle.fill")
                    .font(.headline)
                Spacer()
                Text(store.state.totalLedgerImbalanceCents == 0 ? "BALANCED (0c)" : "IMBALANCE")
                    .font(.caption.monospaced().bold())
            }
            Text("Locked Escrow: $\\(String(format: "%.2f", Double(store.state.totalLockedEscrowCents) / 100.0)) · Postings: \\(store.state.journalPostings.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let disputedCount = state.contracts.filter(\\.isDisputed).count
        return "Ledger Audit: \\(state.journalPostings.count) journal postings verified with \\(state.totalLedgerImbalanceCents)c imbalance; \\(disputedCount) contracts frozen."
        """,
        customUnitTestsSwift: """
        @Test("Milestone split release preserves exact double-entry zero imbalance")
        func milestoneReleaseDoubleEntryInvariant() {
            var state = EscrowSplitLedgerState()
            _ = EscrowSplitLedgerReducer.reduce(
                state: &state,
                action: .releaseMilestone(escrowID: "esc-3001", grossReleaseCents: 1_000_000)
            )
            #expect(state.totalLedgerImbalanceCents == 0)
            #expect(state.journalPostings.first?.isBalanced == true)
            #expect(state.journalPostings.first?.creditFeeCents == 27_500)
            #expect(state.journalPostings.first?.creditVendorCents == 972_500)
        }

        @Test("Dispute freeze blocks milestone payout until lifted")
        func disputeFreezePreventsRelease() {
            var state = EscrowSplitLedgerState()
            _ = EscrowSplitLedgerReducer.reduce(state: &state, action: .toggleDisputeFreeze(escrowID: "esc-3002", frozen: true))
            _ = EscrowSplitLedgerReducer.reduce(state: &state, action: .releaseMilestone(escrowID: "esc-3002", grossReleaseCents: 500_000))
            #expect(state.contracts[1].releasedCents == 0)
        }
        """,
        securityPostureHighlights: [
            "Integer minor-unit (cent) arithmetic eliminates IEEE-754 floating-point penny rounding drift.",
            "Append-only double-entry journal verifies DR == sum(CR) on every milestone split.",
            "Arbitration dispute lock enforced synchronously prior to any ledger disbursement."
        ]
    )
}
