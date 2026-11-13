#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct SwiftStateDemoView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            timeTravelBanner

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    counterCard
                    asyncCard
                }

                VStack(alignment: .leading, spacing: 18) {
                    counterCard
                    asyncCard
                }
            }

            cartReducerCard

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    timelineCard
                    statePreviewCard
                }

                VStack(alignment: .leading, spacing: 18) {
                    timelineCard
                    statePreviewCard
                }
            }
        }
    }

    private var timeTravelBanner: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(theme.primary.swiftUIColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Time-Travel Store Recording (\(viewModel.stateHistory.count) snapshots)")
                        .font(.headline)
                    Text("Every action below is recorded. Scrub backward & forward in time or branch from any historical state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.isTimeTravelVisible.toggle()
                } label: {
                    Label(
                        viewModel.isTimeTravelVisible ? "Hide Debugger" : "Open Time-Travel (⌘T)",
                        systemImage: "slider.horizontal.below.rectangle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary.swiftUIColor)
            }
        }
    }

    private var counterCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("Counter Reducer", subtitle: "Pure state mutations with keyboard shortcuts & live code sync.")

                Text("\(viewModel.counter)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primary.swiftUIColor)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    Button("-5") { viewModel.addCounterStep(-5) }

                    Button {
                        viewModel.decrementCounter()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 26, height: 22)
                    }

                    Button {
                        viewModel.incrementCounter()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)

                    Button("+5") { viewModel.addCounterStep(5) }

                    Spacer(minLength: 6)

                    PillLabel(title: "Step \(viewModel.currentHistoryIndex + 1)", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var asyncCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("Async Side-Effects", subtitle: "Dispatches .loadButtonTapped and awaits .responseReceived.")

                HStack(spacing: 12) {
                    Button {
                        viewModel.runAsyncSimulation()
                    } label: {
                        Label("Run Async Effect", systemImage: "bolt.fill")
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .disabled(viewModel.isLoading)

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(viewModel.loadedMessage ?? "No async payload loaded yet.")
                    .font(.callout)
                    .foregroundStyle(viewModel.loadedMessage == nil ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PillLabel(
                    title: viewModel.isLoading ? "Phase: .loading" : "Phase: .idle",
                    systemImage: viewModel.isLoading ? "hourglass" : "checkmark.circle"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cartReducerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle("Domain Cart Store", subtitle: "Multi-item state transitions tracked in Time-Travel history.")
                    Spacer()
                    Text("Total: $\(viewModel.computedCartTotal)/mo")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primary.swiftUIColor)
                }

                ForEach(viewModel.cartItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.callout.weight(.medium))
                            Text("$\(item.price) per unit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                viewModel.adjustCartQuantity(itemID: item.id, delta: -1)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)

                            Text("\(item.quantity)")
                                .font(.system(.callout, design: .monospaced).weight(.semibold))
                                .frame(width: 26)

                            Button {
                                viewModel.adjustCartQuantity(itemID: item.id, delta: 1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(theme.primary.swiftUIColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack {
                    Button {
                        viewModel.togglePromoCode()
                    } label: {
                        Label(
                            viewModel.promoApplied ? "Promo CHIEF20 Applied (-20%)" : "Apply Promo CHIEF20",
                            systemImage: viewModel.promoApplied ? "tag.fill" : "tag"
                        )
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        let refactorPreset = LocalAIPromptPreset.presets.first { $0.kind == .refactorSwiftState }
                        viewModel.runLocalAI(preset: refactorPreset)
                    } label: {
                        Label("Refactor with CoreLocalAIKit", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var timelineCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Action Log", subtitle: "Click any snapshot in Time-Travel (⌘T) to scrub.")

                VStack(spacing: 8) {
                    ForEach(viewModel.timeline) { event in
                        HStack(spacing: 10) {
                            Text(event.timeText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 82, alignment: .leading)

                            Text(event.action)
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(event.state)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(9)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statePreviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Live Store JSON Snapshot", subtitle: "Updates in real time as you dispatch or scrub.")
                CodeBlockView(text: viewModel.stateJSONPreview, showLineNumbers: false)
                    .frame(minHeight: 230)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
