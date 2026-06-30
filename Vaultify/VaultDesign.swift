//
//  VaultDesign.swift
//  Vaultify
//
//  The Liquid Glass design system: tokens, the living aurora backdrop,
//  and the reusable glass primitives every screen is composed from.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Color helpers

extension Color {
    /// Build a color from a 24-bit hex literal, e.g. `Color(hex: 0xCBA6F7)`.
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Linear sRGB blend toward `other`. `amount` 0 → self, 1 → other.
    func blended(with other: Color, amount: Double) -> Color {
        let c1 = UIColor(self), c2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(min(1, max(0, amount)))
        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t)
        )
    }
}

// MARK: - Theme palettes

/// A complete set of tints + backdrop colors for one theme.
struct VaultPalette {
    let accent: Color
    let cyan: Color
    let violet: Color
    let warn: Color
    let danger: Color
    let bgBase: Color
    let mesh: [Color]

    /// Derive a soft 3×3 mesh from a base color tinted toward the two primaries.
    static func mesh(_ base: Color, _ a: Color, _ b: Color) -> [Color] {
        [
            base.blended(with: a, amount: 0.16), base.blended(with: a, amount: 0.07), base.blended(with: b, amount: 0.13),
            base.blended(with: a, amount: 0.09), base,                                 base.blended(with: b, amount: 0.07),
            base.blended(with: b, amount: 0.11), base.blended(with: a, amount: 0.05), base.blended(with: b, amount: 0.15)
        ]
    }
}

/// The selectable themes. All are dark surfaces, so white-on-dark text stays legible across them.
enum VaultThemeKind: String, CaseIterable, Identifiable {
    case midnight
    case catppuccin
    case tokyoNight
    case oneDarkPro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight: "Midnight"
        case .catppuccin: "Catppuccin"
        case .tokyoNight: "Tokyo Night"
        case .oneDarkPro: "One Dark Pro"
        }
    }

    var blurb: String {
        switch self {
        case .midnight: "Default — emerald on deep space"
        case .catppuccin: "Mocha — soft mauve pastels"
        case .tokyoNight: "Neon blue over inky indigo"
        case .oneDarkPro: "The editor classic"
        }
    }

    var palette: VaultPalette {
        switch self {
        case .midnight: VaultPalettes.midnight
        case .catppuccin: VaultPalettes.catppuccin
        case .tokyoNight: VaultPalettes.tokyoNight
        case .oneDarkPro: VaultPalettes.oneDarkPro
        }
    }
}

private enum VaultPalettes {
    static let midnight: VaultPalette = {
        let base = Color(red: 0.030, green: 0.035, blue: 0.046)
        return VaultPalette(
            accent: Color(red: 0.27, green: 0.71, blue: 0.60),
            cyan: Color(red: 0.44, green: 0.61, blue: 0.78),
            violet: Color(red: 0.49, green: 0.53, blue: 0.66),
            warn: Color(red: 0.86, green: 0.67, blue: 0.38),
            danger: Color(red: 0.80, green: 0.41, blue: 0.41),
            bgBase: base,
            mesh: VaultPalette.mesh(
                base,
                Color(red: 0.27, green: 0.71, blue: 0.60),
                Color(red: 0.44, green: 0.61, blue: 0.78)
            )
        )
    }()

    static let catppuccin: VaultPalette = {
        let base = Color(hex: 0x1E1E2E)
        return VaultPalette(
            accent: Color(hex: 0xCBA6F7),
            cyan: Color(hex: 0x89B4FA),
            violet: Color(hex: 0xB4BEFE),
            warn: Color(hex: 0xFAB387),
            danger: Color(hex: 0xF38BA8),
            bgBase: base,
            mesh: VaultPalette.mesh(base, Color(hex: 0xCBA6F7), Color(hex: 0x89B4FA))
        )
    }()

    static let tokyoNight: VaultPalette = {
        let base = Color(hex: 0x1A1B26)
        return VaultPalette(
            accent: Color(hex: 0x7AA2F7),
            cyan: Color(hex: 0x7DCFFF),
            violet: Color(hex: 0xBB9AF7),
            warn: Color(hex: 0xE0AF68),
            danger: Color(hex: 0xF7768E),
            bgBase: base,
            mesh: VaultPalette.mesh(base, Color(hex: 0x7AA2F7), Color(hex: 0xBB9AF7))
        )
    }()

    static let oneDarkPro: VaultPalette = {
        let base = Color(hex: 0x282C34)
        return VaultPalette(
            accent: Color(hex: 0x61AFEF),
            cyan: Color(hex: 0x56B6C2),
            violet: Color(hex: 0xC678DD),
            warn: Color(hex: 0xE5C07B),
            danger: Color(hex: 0xE06C75),
            bgBase: base,
            mesh: VaultPalette.mesh(base, Color(hex: 0x61AFEF), Color(hex: 0x56B6C2))
        )
    }()
}

/// Observable holder for the active theme. Persists the choice across launches.
@Observable
final class VaultThemeStore {
    static let shared = VaultThemeStore()

    private let key = "vault.theme.kind"

    var kind: VaultThemeKind {
        didSet { UserDefaults.standard.set(kind.rawValue, forKey: key) }
    }

    var palette: VaultPalette { kind.palette }

    private init() {
        // `-VaultThemeKind tokyoNight` forces a theme for demos / screenshots.
        let override = UserDefaults.standard.string(forKey: "VaultThemeKind")
        let raw = override ?? UserDefaults.standard.string(forKey: key) ?? ""
        kind = VaultThemeKind(rawValue: raw) ?? .midnight
    }
}

// MARK: - Tokens

enum VaultTheme {
    // The active palette drives every accent in the app; swap themes in Settings.
    static var palette: VaultPalette { VaultThemeStore.shared.palette }

    static var accent: Color { palette.accent }   // primary
    static var cyan: Color { palette.cyan }        // secondary
    static var violet: Color { palette.violet }    // used sparingly
    static var warn: Color { palette.warn }        // caution
    static var danger: Color { palette.danger }    // critical

    static let card: CGFloat = 28
    static let chip: CGFloat = 18

    /// Brand sweep used for hero numbers and primary accents.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accent, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

var vaultCurrencyCode: String {
    Locale.current.currency?.identifier ?? "USD"
}

var vaultReducedPerformanceMode: Bool {
    let processInfo = ProcessInfo.processInfo
    return processInfo.isLowPowerModeEnabled
        || processInfo.thermalState == .serious
        || processInfo.thermalState == .critical
}

extension Appliance {
    /// Single source of truth for an asset's signal color.
    var signalColor: Color {
        riskScore > 0.62 ? VaultTheme.danger : riskScore > 0.38 ? VaultTheme.warn : VaultTheme.accent
    }
}

extension ApplianceSnapshot {
    /// Cached risk score with the active theme's current palette.
    var signalColor: Color {
        riskScore > 0.62 ? VaultTheme.danger : riskScore > 0.38 ? VaultTheme.warn : VaultTheme.accent
    }
}

// MARK: - Living aurora backdrop

/// Deep space base + a static mesh gradient + two slow drifting light orbs.
/// The orbs animate; the mesh is static, so it stays effortless on the GPU.
struct VaultBackground: View {
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var particleCount: Int { reduceMotion || vaultReducedPerformanceMode ? 0 : 12 }
    private var particleFrameInterval: TimeInterval { 1.0 / 6.0 }

    var body: some View {
        let palette = VaultTheme.palette
        ZStack {
            palette.bgBase
                .ignoresSafeArea()

            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: palette.mesh
            )
            .ignoresSafeArea()

            orb(VaultTheme.accent.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 74)
                .offset(x: drift ? -130 : -90, y: drift ? -260 : -310)

            orb(VaultTheme.cyan.opacity(0.13))
                .frame(width: 290, height: 290)
                .blur(radius: 82)
                .offset(x: drift ? 150 : 110, y: drift ? 300 : 350)

            if particleCount > 0 {
                // Drifting particle field — slow rising motes that twinkle.
                TimelineView(.animation(minimumInterval: particleFrameInterval)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        for i in 0..<particleCount {
                            let fx = vfrac(i * 2)
                            let speed = 5 + vfrac(i * 3 + 1) * 12
                            let baseY = vfrac(i * 5 + 2) * size.height
                            let y = baseY - CGFloat(t).truncatingRemainder(dividingBy: size.height / speed) * speed
                            let wrapped = (y.truncatingRemainder(dividingBy: size.height) + size.height).truncatingRemainder(dividingBy: size.height)
                            let x = fx * size.width + sin(t * 0.4 + fx * 8) * 8
                            let twinkle = 0.3 + 0.7 * abs(sin(t * (0.5 + vfrac(i + 7)) + fx * 6))
                            let r = 0.6 + vfrac(i * 7 + 3) * 1.7
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x, y: wrapped, width: r * 2, height: r * 2)),
                                with: .color(.white.opacity(0.04 + 0.12 * twinkle))
                            )
                        }
                    }
                }
                .ignoresSafeArea()
                .blendMode(.plusLighter)
            }
        }
        .onAppear {
            guard !reduceMotion, !vaultReducedPerformanceMode else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func orb(_ color: Color) -> some View {
        Circle().fill(color)
    }
}

// MARK: - Glass primitives

extension View {
    /// Wraps content in a rounded Liquid Glass surface with consistent padding.
    func glassCard(
        _ radius: CGFloat = VaultTheme.card,
        padding: CGFloat = 18,
        tint: Color? = nil
    ) -> some View {
        modifier(GlassCardModifier(radius: radius, padding: padding, tint: tint))
    }

    func interactiveLift(tint: Color = VaultTheme.accent) -> some View {
        modifier(InteractiveLiftModifier(tint: tint))
    }
}

private struct GlassCardModifier: ViewModifier {
    let radius: CGFloat
    let padding: CGFloat
    let tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || vaultReducedPerformanceMode {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill((tint ?? .white).opacity(tint == nil ? 0.075 : 0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 0.75)
                )
        } else {
            content
                .padding(padding)
                .glassEffect(
                    tint.map { Glass.regular.tint($0.opacity(0.18)) } ?? .regular,
                    in: .rect(cornerRadius: radius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 0.75)
                )
        }
    }
}

private struct InteractiveLiftModifier: ViewModifier {
    let tint: Color
    @State private var tilt = CGSize.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion || vaultReducedPerformanceMode {
            content
                .shadow(color: tint.opacity(0.06), radius: 3, y: 2)
        } else {
            content
                .rotation3DEffect(.degrees(Double(tilt.height) / -18), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(Double(tilt.width) / 18), axis: (x: 0, y: 1, z: 0))
                .shadow(color: tint.opacity(0.10), radius: tilt == .zero ? 4 : 12, y: tilt == .zero ? 2 : 8)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.78)) {
                                tilt = CGSize(
                                    width: max(-12, min(12, value.translation.width)),
                                    height: max(-12, min(12, value.translation.height))
                                )
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                                tilt = .zero
                            }
                        }
                )
        }
    }
}

struct VaultPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == VaultPressButtonStyle {
    static var vaultPress: VaultPressButtonStyle { VaultPressButtonStyle() }
}

/// Small uppercase eyebrow label used above sections and inside cards.
struct Eyebrow: View {
    let text: String
    var tint: Color = .secondary

    init(_ text: String, tint: Color = .secondary) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.heavy))
            .tracking(1.4)
            .foregroundStyle(tint)
    }
}

/// Section header with a title and a soft trailing caption.
struct GlassSectionHeader: View {
    let title: String
    var caption: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            if let caption {
                Text(caption.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }
}

/// Animated circular gauge — the signature health/risk dial.
struct VaultRing: View {
    let value: Double
    var secondary: Double = 0
    var size: CGFloat = 128
    var lineWidth: CGFloat = 12
    var label: String?

    @State private var animated = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animated ? value : 0)
                .stroke(
                    AngularGradient(colors: [VaultTheme.cyan, VaultTheme.accent, VaultTheme.cyan], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if secondary > 0 {
                Circle()
                    .trim(from: 0, to: animated ? secondary : 0)
                    .stroke(
                        AngularGradient(colors: [VaultTheme.warn, VaultTheme.danger], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth * 0.42, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth * 1.6)
            }

            VStack(spacing: 1) {
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: size * 0.24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                if let label {
                    Text(label.uppercased())
                        .font(.system(size: size * 0.072, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.85)) { animated = true }
        }
    }
}

/// Thin labeled progress bar used across rows and cards.
struct MeterBar: View {
    let value: Double
    var tint: Color = VaultTheme.accent
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * max(0.04, min(1, value)))
                    .shadow(color: tint.opacity(0.5), radius: 4, y: 0)
            }
        }
        .frame(height: height)
    }
}

/// Capsule glyph badge with a tinted symbol.
struct GlyphBadge: View {
    let symbol: String
    var tint: Color = VaultTheme.accent
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .stroke(tint.opacity(0.30), lineWidth: 0.75)
            )
    }
}

/// Compact pill used for inline metrics.
struct StatChip: View {
    let label: String
    let value: String
    var tint: Color = VaultTheme.accent

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(value).font(.caption.weight(.heavy)).foregroundStyle(.white)
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.62))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .glassEffect(.regular, in: .capsule)
    }
}

struct ActionPill: View {
    let title: String
    let symbol: String
    var tint: Color = VaultTheme.accent
    var filled = false

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.heavy))
            .foregroundStyle(filled ? .black : .white.opacity(0.82))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.vertical, 10)
            .padding(.horizontal, 13)
            .background {
                Capsule()
                    .fill(filled ? tint : .white.opacity(0.08))
            }
            .overlay(
                Capsule()
                    .stroke(filled ? .clear : tint.opacity(0.26), lineWidth: 0.8)
            )
    }
}
