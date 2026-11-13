#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct FloatingTimeTravelView: View {
    @ObservedObject var viewModel: PlaygroundViewModel

    @State private var isMinimized = false
    @State private var dragOffset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private var activeSnapshot: StateSnapshot? {
        guard viewModel.stateHistory.indices.contains(viewModel.currentHistoryIndex) else {
            return viewModel.stateHistory.last
        }
        return viewModel.stateHistory[viewModel.currentHistoryIndex]
    }

    var body: some View {
        Group {
            if isMinimized {
                minimizedPill
            } else {
                expandedPanel
            }
        }
        .offset(
            x: committedOffset.width + dragOffset.width,
            y: committedOffset.height + dragOffset.height
        )
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    committedOffset.width += value.translation.width
                    committedOffset.height += value.translation.height
                    dragOffset = .zero
                }
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
    }

    private var minimizedPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)

            Text("Time-Travel \(viewModel.currentHistoryIndex + 1)/\(viewModel.stateHistory.count)")
                .font(.system(.caption, design: .monospaced).weight(.semibold))

            Button {
                viewModel.undoHistory()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canUndoHistory)

            Button {
                viewModel.redoHistory()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRedoHistory)

            Button {
                isMinimized = false
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(viewModel.themeTokens.primary.swiftUIColor.opacity(0.45), lineWidth: 1)
        }
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header bar (draggable)
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text("SwiftState Time-Travel")
                        .font(.caption.weight(.bold))
                    Text("Step \(viewModel.currentHistoryIndex + 1) of \(viewModel.stateHistory.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isMinimized = true
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Minimize Time-Travel Debugger")

                Button {
                    viewModel.isTimeTravelVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Time-Travel Debugger (⌘T)")
            }

            Divider()

            // Active action readout
            if let snap = activeSnapshot {
                HStack {
                    Text(snap.action)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)
                        .lineLimit(1)
                    Spacer()
                    Text(snap.summary)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(viewModel.themeTokens.primary.swiftUIColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
            }

            // History scrubbing slider
            if viewModel.stateHistory.count > 1 {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentHistoryIndex) },
                        set: { viewModel.scrubHistory(to: Int($0.rounded())) }
                    ),
                    in: 0...Double(max(1, viewModel.stateHistory.count - 1)),
                    step: 1
                )
                .tint(viewModel.themeTokens.primary.swiftUIColor)
            } else {
                Text("Trigger counter, cart, or flow actions to record history.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Playback controls
            HStack(spacing: 8) {
                Button {
                    viewModel.undoHistory()
                } label: {
                    Label("Back", systemImage: "backward.frame.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!viewModel.canUndoHistory)

                Button {
                    viewModel.replayHistory()
                } label: {
                    Label(viewModel.isReplayingHistory ? "Playing" : "Replay", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.themeTokens.primary.swiftUIColor)
                .controlSize(.small)
                .disabled(viewModel.stateHistory.count <= 1 || viewModel.isReplayingHistory)

                Button {
                    viewModel.redoHistory()
                } label: {
                    Label("Next", systemImage: "forward.frame.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!viewModel.canRedoHistory)

                Spacer()

                Button("Clear") {
                    viewModel.clearStateHistory()
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            // Compact scrollable history entries
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(viewModel.stateHistory.enumerated().reversed()), id: \.element.id) { idx, entry in
                        Button {
                            viewModel.scrubHistory(to: idx)
                        } label: {
                            HStack(spacing: 6) {
                                Text("#\(idx)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(idx == viewModel.currentHistoryIndex ? .white : .secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        idx == viewModel.currentHistoryIndex
                                            ? viewModel.themeTokens.primary.swiftUIColor
                                            : Color.secondary.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 4)
                                    )

                                Text(entry.action)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)

                                Spacer()

                                Text(entry.timeText)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                idx == viewModel.currentHistoryIndex
                                    ? viewModel.themeTokens.primary.swiftUIColor.opacity(0.14)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 120)
        }
        .padding(12)
        .frame(width: 316)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(viewModel.themeTokens.primary.swiftUIColor.opacity(0.38), lineWidth: 1)
        }
    }
}
#endif
