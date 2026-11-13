#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import Foundation
import SwiftUI

enum PreviewAppearance: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum PreviewViewport: String, CaseIterable, Identifiable, Sendable {
    case fluid = "Fluid"
    case macCompact = "macOS 680"
    case iPadCard = "Tablet 540"
    case iPhonePro = "Mobile 393"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .fluid: "macwindow"
        case .macCompact: "laptopcomputer"
        case .iPadCard: "ipad.landscape"
        case .iPhonePro: "iphone"
        }
    }

    var maxWidth: CGFloat? {
        switch self {
        case .fluid: nil
        case .macCompact: 680
        case .iPadCard: 540
        case .iPhonePro: 393
        }
    }
}

enum PreviewDynamicType: String, CaseIterable, Identifiable, Sendable {
    case compact = "Small"
    case standard = "Default"
    case large = "Large"
    case ax1 = "AX Large"
    case ax3 = "AX Max"

    var id: String { rawValue }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .compact: .small
        case .standard: .large
        case .large: .xxLarge
        case .ax1: .accessibility1
        case .ax3: .accessibility3
        }
    }

    var scaleMultiplier: CGFloat {
        switch self {
        case .compact: 0.92
        case .standard: 1.0
        case .large: 1.08
        case .ax1: 1.18
        case .ax3: 1.30
        }
    }
}

struct PreviewConfiguration: Hashable, Sendable {
    var appearance: PreviewAppearance = .system
    var viewport: PreviewViewport = .fluid
    var dynamicType: PreviewDynamicType = .standard
    var showAccessibilityOverlay: Bool = false
}
#endif
