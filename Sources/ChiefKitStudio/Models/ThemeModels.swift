#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitStudioCore
import Foundation
import SwiftUI

extension RGBAColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func from(_ color: Color) -> RGBAColor {
        if let srgb = NSColor(color).usingColorSpace(.sRGB) {
            return RGBAColor(
                red: Double(srgb.redComponent),
                green: Double(srgb.greenComponent),
                blue: Double(srgb.blueComponent),
                alpha: Double(srgb.alphaComponent)
            )
        }
        return RGBAColor(red: 0.05, green: 0.36, blue: 0.94)
    }
}

private struct StudioThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = StudioThemeTokens()
}

extension EnvironmentValues {
    var studioTheme: StudioThemeTokens {
        get { self[StudioThemeEnvironmentKey.self] }
        set { self[StudioThemeEnvironmentKey.self] = newValue }
    }
}

extension View {
    func studioTheme(_ tokens: StudioThemeTokens) -> some View {
        environment(\.studioTheme, tokens)
    }
}
#endif
