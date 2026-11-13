#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct ActionBarView: View {
    @ObservedObject var viewModel: PlaygroundViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            ViewThatFits(in: .horizontal) {
                wideBar
                wrappedBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.bar)
        }
    }

    private var wideBar: some View {
        HStack(spacing: 8) {
            statusText
            Spacer()
            actionButtons
        }
    }

    private var wrappedBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusText

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)], spacing: 8) {
                actionButtons
            }
        }
    }

    private var statusText: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.themeTokens.success.swiftUIColor)
                .frame(width: 7, height: 7)

            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        actionButton("Copy SwiftUI", systemImage: "doc.on.doc") {
            viewModel.copySwiftUICode()
        }

        actionButton("Export Package Snippet", systemImage: "shippingbox") {
            viewModel.exportPackageSnippetFile()
        }

        actionButton("Generate Project", systemImage: "hammer.fill") {
            viewModel.isProjectGeneratorPresented = true
        }

        actionButton("Open in Xcode", systemImage: "wrench.and.screwdriver") {
            viewModel.openInXcode()
        }

        actionButton("Download DMG", systemImage: "arrow.down.circle") {
            viewModel.openDMGDownload()
        }

        actionButton("Reset", systemImage: "arrow.counterclockwise") {
            viewModel.resetDemo()
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .controlSize(.small)
    }
}
#endif
