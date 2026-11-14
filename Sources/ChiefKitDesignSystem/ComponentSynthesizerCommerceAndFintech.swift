#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Commerce, Fintech & SaaS Component Specs + Synthesizers (16 Components)

internal enum ComponentSynthesizerCommerceAndFintech {

    static let specs: [SwiftBlockSpec] = [
        // MARK: 8 Commerce & Fintech Specs
        SwiftBlockSpec(
            id: .pricingTierComparison,
            title: "Pricing Tier Comparison",
            summary: "Side-by-side plan matrix with billing cycle toggle, feature checkmarks, and highlighted Pro badge.",
            sfSymbol: "crown.fill",
            vectorIcon: .checkBadgeVerified,
            props: [
                SwiftBlockPropSpec(name: "annualBilling", kind: .binding, defaultValue: "true", summary: "Annual discount toggle", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 460, height: 224),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "group", minimumAPCALc: 75),
            searchKeywords: ["pricing", "tiers", "subscription", "billing"]
        ),
        SwiftBlockSpec(
            id: .virtualCardGlassView,
            title: "Virtual Card Glass View",
            summary: "Specular Liquid Glass payment card with EMV chip, masked PAN toggle, and spend limit bar.",
            sfSymbol: "creditcard.fill",
            vectorIcon: .creditCardChip,
            props: [
                SwiftBlockPropSpec(name: "lastFour", kind: .string, defaultValue: "\"4829\"", summary: "Card suffix", isRequired: true),
                SwiftBlockPropSpec(name: "revealDigits", kind: .bool, defaultValue: "false", summary: "PAN visibility")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 340, height: 204),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "card", minimumAPCALc: 75),
            searchKeywords: ["card", "payment", "virtual", "fintech"]
        ),
        SwiftBlockSpec(
            id: .ledgerEntryRow,
            title: "Ledger Entry Row",
            summary: "Double-entry accounting row displaying counterparty, settlement status pill, and monospaced amount.",
            sfSymbol: "list.bullet.rectangle.portrait",
            vectorIcon: .ledgerBook,
            props: [
                SwiftBlockPropSpec(name: "counterparty", kind: .string, defaultValue: "\"Apple App Store Connect\"", summary: "Merchant/source", isRequired: true),
                SwiftBlockPropSpec(name: "amountFormatted", kind: .string, defaultValue: "\"+$4,920.00\"", summary: "Signed amount", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 420, height: 74),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "row", minimumAPCALc: 75),
            searchKeywords: ["ledger", "transaction", "accounting", "payout"]
        ),
        SwiftBlockSpec(
            id: .multiCurrencySwapCard,
            title: "Multi-Currency Swap Card",
            summary: "FX treasury converter with live mid-market rate badge, slippage guard, and instant direction flip.",
            sfSymbol: "arrow.up.arrow.down.circle.fill",
            vectorIcon: .currencySwap,
            props: [
                SwiftBlockPropSpec(name: "fromCurrency", kind: .string, defaultValue: "\"USD\"", summary: "Source ISO code", isRequired: true),
                SwiftBlockPropSpec(name: "toCurrency", kind: .string, defaultValue: "\"EUR\"", summary: "Target ISO code", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 196),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "form", minimumAPCALc: 75),
            searchKeywords: ["fx", "currency", "swap", "exchange"]
        ),
        SwiftBlockSpec(
            id: .invoiceLineItemCard,
            title: "Invoice Line-Item Card",
            summary: "Itemized B2B invoice summary with unit quantities, subtotal calculation, and PDF receipt action.",
            sfSymbol: "doc.text.fill",
            vectorIcon: .ledgerBook,
            props: [
                SwiftBlockPropSpec(name: "invoiceNumber", kind: .string, defaultValue: "\"INV-2026-084\"", summary: "Document ID", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 400, height: 184),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "document", minimumAPCALc: 75),
            searchKeywords: ["invoice", "receipt", "billing", "b2b"]
        ),
        SwiftBlockSpec(
            id: .planUpgradeBanner,
            title: "Plan Upgrade Banner",
            summary: "High-conversion upsell callout highlighting unlocked Studio capabilities and instant trial CTA.",
            sfSymbol: "sparkles",
            vectorIcon: .rocketDeploy,
            props: [
                SwiftBlockPropSpec(name: "ctaLabel", kind: .string, defaultValue: "\"Unlock Team Studio\"", summary: "Button title", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 480, height: 108),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "banner", minimumAPCALc: 70),
            searchKeywords: ["upgrade", "upsell", "pro", "cta"]
        ),
        SwiftBlockSpec(
            id: .orderBookDepthCard,
            title: "Order Book Depth Card",
            summary: "Bid/ask liquidity ladder with cumulative volume bars and mid-spread basis-point readout.",
            sfSymbol: "chart.bar.doc.horizontal",
            vectorIcon: .chartCandlestick,
            props: [
                SwiftBlockPropSpec(name: "spreadBps", kind: .double, defaultValue: "1.8", summary: "Spread in bps", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 196),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "table", minimumAPCALc: 70),
            searchKeywords: ["orderbook", "depth", "bids", "asks", "trading"]
        ),
        SwiftBlockSpec(
            id: .assetAllocationBar,
            title: "Asset Allocation Bar",
            summary: "Proportional multi-segment portfolio bar with semantic legend swatches and weight percentages.",
            sfSymbol: "chart.bar.xaxis.ascending",
            vectorIcon: .chartDonutGauge,
            props: [
                SwiftBlockPropSpec(name: "segments", kind: .dataArray, defaultValue: "[0.52, 0.30, 0.18]", summary: "Normalized weights", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 400, height: 120),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "chart", minimumAPCALc: 70),
            searchKeywords: ["portfolio", "allocation", "weights", "treasury"]
        ),

        // MARK: 8 SaaS & Operations Specs
        SwiftBlockSpec(
            id: .shippingAddressCard,
            title: "Shipping Address Card",
            summary: "Verified fulfillment address selector with default badge, carrier estimate, and edit sheet action.",
            sfSymbol: "shippingbox.fill",
            vectorIcon: .checkBadgeVerified,
            props: [
                SwiftBlockPropSpec(name: "recipient", kind: .string, defaultValue: "\"HNM Labs Hardware\"", summary: "Address title", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 136),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "button", minimumAPCALc: 75),
            searchKeywords: ["shipping", "address", "checkout", "delivery"]
        ),
        SwiftBlockSpec(
            id: .promoRedemptionBar,
            title: "Promo Redemption Bar",
            summary: "Coupon & license voucher input bar with instant discount pill confirmation.",
            sfSymbol: "ticket.fill",
            vectorIcon: .tagBookmark,
            props: [
                SwiftBlockPropSpec(name: "promoCode", kind: .binding, defaultValue: "\"CHIEFKIT3\"", summary: "Voucher code", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 76),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "form", minimumAPCALc: 75),
            searchKeywords: ["promo", "coupon", "discount", "voucher"]
        ),
        SwiftBlockSpec(
            id: .escrowMilestoneStepper,
            title: "Escrow Milestone Stepper",
            summary: "Contract milestone release tracker showing funded, verified, and released payout tranches.",
            sfSymbol: "lock.shield.fill",
            vectorIcon: .escrowLock,
            props: [
                SwiftBlockPropSpec(name: "releasedTranches", kind: .int, defaultValue: "2", summary: "Completed milestones", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 420, height: 148),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "list", minimumAPCALc: 70),
            searchKeywords: ["escrow", "milestone", "contract", "payout"]
        ),
        SwiftBlockSpec(
            id: .taxSummaryBreakdown,
            title: "Tax Summary Breakdown",
            summary: "Checkout subtotal, regional VAT/GST calculation, and bold settlement total card.",
            sfSymbol: "percent",
            vectorIcon: .ledgerBook,
            props: [
                SwiftBlockPropSpec(name: "taxRatePercent", kind: .double, defaultValue: "8.875", summary: "Jurisdiction rate", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 340, height: 156),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "summary", minimumAPCALc: 75),
            searchKeywords: ["tax", "vat", "checkout", "total"]
        ),
        SwiftBlockSpec(
            id: .teamSeatSliderCard,
            title: "Team Seat Slider Card",
            summary: "Interactive seat count estimator with volume tier discounts and per-seat monthly readout.",
            sfSymbol: "person.3.fill",
            vectorIcon: .userTeamNodes,
            props: [
                SwiftBlockPropSpec(name: "seatCount", kind: .binding, defaultValue: "12.0", summary: "Active seats", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 148),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "slider", minimumAPCALc: 70),
            searchKeywords: ["seats", "team", "licensing", "saas"]
        ),
        SwiftBlockSpec(
            id: .immutableAuditLogRow,
            title: "Immutable Audit Log Row",
            summary: "Cryptographically hashed security event row with actor principal, IP badge, and SHA-256 prefix.",
            sfSymbol: "checkmark.seal.fill",
            vectorIcon: .auditSeal,
            props: [
                SwiftBlockPropSpec(name: "eventHash", kind: .string, defaultValue: "\"sha256:9f84c2a1\"", summary: "Digest tag", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 460, height: 78),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "row", minimumAPCALc: 75),
            searchKeywords: ["audit", "compliance", "soc2", "security", "log"]
        ),
        SwiftBlockSpec(
            id: .serviceUptimeMatrix,
            title: "Service Uptime Matrix",
            summary: "30-day operational status bar strip with 99.99% SLA readout and incident tooltip summary.",
            sfSymbol: "server.rack",
            vectorIcon: .boltThroughput,
            props: [
                SwiftBlockPropSpec(name: "uptimePercent", kind: .string, defaultValue: "\"99.99%\"", summary: "SLA percentage", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 440, height: 112),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "status", minimumAPCALc: 70),
            searchKeywords: ["uptime", "status", "sla", "health"]
        ),
        SwiftBlockSpec(
            id: .webhookEndpointCard,
            title: "Webhook Endpoint Card",
            summary: "Developer webhook subscription card with HTTPS URL, HMAC signing status, and 2xx delivery rate.",
            sfSymbol: "network",
            vectorIcon: .webhookSignal,
            props: [
                SwiftBlockPropSpec(name: "endpointURL", kind: .string, defaultValue: "\"https://api.hnmlabs.com/hooks/tokens\"", summary: "Target URL", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 440, height: 132),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "group", minimumAPCALc: 75),
            searchKeywords: ["webhook", "api", "events", "hmac"]
        )
    ]

    // MARK: - Component Code Synthesis

    static func synthesize(context ctx: SwiftBlockSynthesisContext) -> String {
        let accent = ctx.accentSwiftUI
        let okColor = ctx.theme.success.swiftInitializer
        let errColor = ctx.theme.danger.swiftInitializer

        switch ctx.id {
        case .pricingTierComparison:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var annualBilling = true",
                bodyCore: """
                        HStack {
                            Text("ChiefKit Studio Tiers").font(.headline)
                            Spacer()
                            Toggle("Annual (-20%)", isOn: $annualBilling).toggleStyle(.switch).font(.caption)
                        }
                        HStack(spacing: 12) {
                            ForEach([("Indie", annualBilling ? "$0" : "$0", "Local OSS"), ("Team Pro", annualBilling ? "$24" : "$29", "Multi-Artboard Sync")], id: \\.0) { tier, price, note in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(tier).font(.subheadline.weight(.bold))
                                    Text("\\(price)/mo").font(.title3.weight(.bold)).foregroundStyle(\(accent))
                                    Text(note).font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: \(ctx.radSM)))
                            }
                        }
                """
            )

        case .virtualCardGlassView:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var revealNumber = false",
                bodyCore: """
                        HStack {
                            Image(systemName: "wave.3.right").foregroundStyle(\(accent))
                            Spacer()
                            Text("CHIEFKIT TREASURY").font(.caption2.monospaced().weight(.bold))
                        }
                        Text(revealNumber ? "4532 • 8910 • 7741 • 4829" : "•••• •••• •••• 4829")
                            .font(.headline.monospaced())
                            .padding(.vertical, 8)
                        HStack {
                            Text("EXP 09/29").font(.caption2.monospaced()).foregroundStyle(.secondary)
                            Spacer()
                            Button(revealNumber ? "Hide" : "Reveal") { revealNumber.toggle() }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(\(accent))
                        }
                """
            )

        case .ledgerEntryRow:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down.left.circle.fill")
                                .font(.title3)
                                .foregroundStyle(\(okColor))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Store Connect Settlement").font(.subheadline.weight(.semibold))
                                Text("Settled · ACH #9042").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+$4,920.00").font(.subheadline.monospaced().weight(.bold)).foregroundStyle(\(okColor))
                        }
                """
            )

        case .multiCurrencySwapCard:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var usdAmount: String = \"1000\"\n    @State private var reversed = false",
                bodyCore: """
                        HStack {
                            Text(reversed ? "EUR → USD" : "USD → EUR").font(.subheadline.weight(.bold))
                            Spacer()
                            Text("1 USD = 0.9214 EUR").font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField("Amount", text: $usdAmount).textFieldStyle(.roundedBorder)
                            Button { reversed.toggle() } label: {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(\(accent))
                            }
                            .buttonStyle(.plain)
                        }
                """
            )

        case .invoiceLineItemCard:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Text("INV-2026-084").font(.caption.monospaced().weight(.bold))
                            Spacer()
                            Text("PAID").font(.caption2.weight(.bold)).foregroundStyle(\(okColor))
                        }
                        Divider()
                        HStack { Text("ChiefKit Enterprise Design Seat × 10").font(.caption); Spacer(); Text("$2,400.00").font(.caption.monospaced()) }
                        HStack { Text("Total Paid").font(.subheadline.weight(.bold)); Spacer(); Text("$2,400.00").font(.subheadline.monospaced().weight(.bold)).foregroundStyle(\(accent)) }
                """
            )

        case .planUpgradeBanner:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles").font(.title2).foregroundStyle(\(accent))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Multi-Platform Token CI").font(.subheadline.weight(.bold))
                                Text("Automate SwiftUI, Compose, CSS OKLCH, and Xcode .xcassets exports.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            EDKButton("Enable", variant: .primary, size: .small) { }
                        }
                """
            )

        case .orderBookDepthCard:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Text("Order Book Depth").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Spread 1.8 bps").font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("BIDS").font(.caption2.weight(.bold)).foregroundStyle(\(okColor))
                                Text("102.40 · 420").font(.caption.monospaced())
                                Text("102.38 · 890").font(.caption.monospaced())
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("ASKS").font(.caption2.weight(.bold)).foregroundStyle(\(errColor))
                                Text("102.42 · 380").font(.caption.monospaced())
                                Text("102.45 · 760").font(.caption.monospaced())
                            }
                        }
                """
            )

        case .assetAllocationBar:
            return ctx.wrapComponentView(
                bodyCore: """
                        Text("Treasury Allocation").font(.subheadline.weight(.semibold))
                        GeometryReader { geo in
                            HStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 4).fill(\(accent)).frame(width: geo.size.width * 0.54)
                                RoundedRectangle(cornerRadius: 4).fill(\(okColor)).frame(width: geo.size.width * 0.28)
                                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.45))
                            }
                        }
                        .frame(height: 12)
                        HStack {
                            Text("54% T-Bills").font(.caption2)
                            Spacer()
                            Text("28% Operating").font(.caption2)
                            Spacer()
                            Text("18% Reserve").font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                """
            )

        case .shippingAddressCard:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Label("HNM Labs Hardware Studio", systemImage: "shippingbox.fill").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("DEFAULT").font(.caption2.weight(.bold)).foregroundStyle(\(accent))
                        }
                        Text("548 Market St, Suite 41200 · San Francisco, CA 94104")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                """
            )

        case .promoRedemptionBar:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var code: String = \"CHIEFKIT3\"\n    @State private var applied = true",
                bodyCore: """
                        HStack(spacing: 8) {
                            TextField("Promo code", text: $code).textFieldStyle(.roundedBorder)
                            Button(applied ? "Applied ✓" : "Apply") { applied.toggle() }
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(applied ? \(okColor) : \(accent), in: RoundedRectangle(cornerRadius: \(ctx.radSM)))
                                .foregroundStyle(.white)
                                .buttonStyle(.plain)
                        }
                """
            )

        case .escrowMilestoneStepper:
            return ctx.wrapComponentView(
                bodyCore: """
                        Text("Escrow Contract Tranches").font(.subheadline.weight(.semibold))
                        ForEach([("1. Architecture Spec", "Released", true), ("2. Token Compiler QA", "Funded in Escrow", false)], id: \\.0) { title, status, done in
                            HStack {
                                Image(systemName: done ? "checkmark.seal.fill" : "lock.fill")
                                    .foregroundStyle(done ? \(okColor) : \(accent))
                                Text(title).font(.caption.weight(.medium))
                                Spacer()
                                Text(status).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                """
            )

        case .taxSummaryBreakdown:
            return ctx.wrapComponentView(
                bodyCore: """
                        VStack(spacing: 6) {
                            HStack { Text("Subtotal").font(.caption).foregroundStyle(.secondary); Spacer(); Text("$240.00").font(.caption.monospaced()) }
                            HStack { Text("Estimated Tax (8.88%)").font(.caption).foregroundStyle(.secondary); Spacer(); Text("$21.31").font(.caption.monospaced()) }
                            Divider()
                            HStack { Text("Total Due").font(.subheadline.weight(.bold)); Spacer(); Text("$261.31").font(.subheadline.monospaced().weight(.bold)).foregroundStyle(\(accent)) }
                        }
                """
            )

        case .teamSeatSliderCard:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var seats: Double = 14",
                bodyCore: """
                        HStack {
                            Text("Active Engineering Seats").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\\(Int(seats)) seats · $\\(Int(seats) * 22)/mo")
                                .font(.caption.monospaced().weight(.bold))
                                .foregroundStyle(\(accent))
                        }
                        Slider(value: $seats, in: 1...50, step: 1)
                            .tint(\(accent))
                """
            )

        case .immutableAuditLogRow:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill").foregroundStyle(\(okColor))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("token.bundle.exported · actor:founder@hnmlabs.com").font(.caption.weight(.semibold))
                                Text("sha256:9f84c2a1e7b0 · 192.0.2.44").font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("VERIFIED").font(.caption2.weight(.bold)).foregroundStyle(\(okColor))
                        }
                """
            )

        case .serviceUptimeMatrix:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Text("Local Build Daemon").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("99.99% Uptime").font(.caption.monospaced().weight(.bold)).foregroundStyle(\(okColor))
                        }
                        HStack(spacing: 3) {
                            ForEach(0..<24, id: \\.self) { slot in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(slot == 17 ? \(accent) : \(okColor))
                                    .frame(height: 18)
                            }
                        }
                """
            )

        default: // .webhookEndpointCard
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Label("https://api.hnmlabs.com/hooks/tokens", systemImage: "network")
                                .font(.caption.monospaced().weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("200 OK · 99.8%").font(.caption2.monospaced()).foregroundStyle(\(okColor))
                        }
                        Text("Events: design.tokens.compiled, artboard.master.synced · HMAC-SHA256")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                """
            )
        }
    }
}
