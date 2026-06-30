//
//  AppIconStore.swift
//  Vaultify
//
//  Alternate app icon catalog + a small observable manager that swaps the
//  home-screen icon via UIApplication.setAlternateIconName.
//

import SwiftUI
import UIKit

enum VaultAppIcon: String, CaseIterable, Identifiable {
    case midnight
    case catppuccin
    case tokyo
    case oneDark
    case aurora

    var id: String { rawValue }

    /// Asset name passed to `setAlternateIconName`. `nil` means the primary AppIcon.
    var alternateName: String? {
        switch self {
        case .midnight: nil
        case .catppuccin: "AltCatppuccin"
        case .tokyo: "AltTokyo"
        case .oneDark: "AltOneDark"
        case .aurora: "AltAurora"
        }
    }

    var title: String {
        switch self {
        case .midnight: "Midnight"
        case .catppuccin: "Catppuccin"
        case .tokyo: "Tokyo Night"
        case .oneDark: "One Dark"
        case .aurora: "Aurora"
        }
    }

    /// Imageset used to render the in-app preview swatch.
    var previewAsset: String {
        switch self {
        case .midnight: "iconpreview-midnight"
        case .catppuccin: "iconpreview-catppuccin"
        case .tokyo: "iconpreview-tokyo"
        case .oneDark: "iconpreview-onedark"
        case .aurora: "iconpreview-aurora"
        }
    }

    /// The icon currently set on the app, inferred from the live alternate name.
    static var current: VaultAppIcon {
        let alt = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateName == alt } ?? .midnight
    }
}

@Observable
final class AppIconStore {
    static let shared = AppIconStore()

    var selected: VaultAppIcon
    var supportsAlternateIcons: Bool { UIApplication.shared.supportsAlternateIcons }

    private init() {
        selected = VaultAppIcon.current
    }

    func apply(_ icon: VaultAppIcon) {
        guard supportsAlternateIcons else { return }
        guard icon != selected else { return }
        let previous = selected
        selected = icon
        UIApplication.shared.setAlternateIconName(icon.alternateName) { [weak self] error in
            if error != nil {
                // Revert the selection if the system rejected the change.
                Task { @MainActor [weak self] in self?.selected = previous }
            }
        }
    }
}
