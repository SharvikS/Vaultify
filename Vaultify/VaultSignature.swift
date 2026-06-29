//
//  VaultSignature.swift
//  Vaultify
//
//  Bespoke, Canvas-rendered signature visuals — the "never seen before" layer.
//  Everything here is drawn by hand (no stock charts/controls) and animated
//  with TimelineView, which keeps it GPU-light and fluid.
//

import SwiftUI

// MARK: - Math helpers

/// Deterministic 0...1 hash so particle fields are stable across redraws.
func vfrac(_ n: Int) -> CGFloat {
    let v = sin(Double(n) * 12.9898) * 43758.5453
    return CGFloat(v - floor(v))
}

/// Health → color ramp: 0 danger, 0.5 amber, 1 mint.
func healthColor(_ h: Double) -> Color {
    let danger = (0.80, 0.41, 0.41)
    let warn = (0.86, 0.67, 0.38)
    let accent = (0.27, 0.71, 0.60)
    func lerp(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }
    let h = min(1, max(0, h))
    return h < 0.5 ? lerp(danger, warn, h / 0.5) : lerp(warn, accent, (h - 0.5) / 0.5)
}

// MARK: - Brand mark

/// The Vaultify logo, drawn with SwiftUI shapes so it inherits the active theme:
/// a vault keyhole inside the app's signature gauge ring.
struct VaultLogoMark: View {
    var size: CGFloat = 96
    var lineWidth: CGFloat { size * 0.072 }

    var body: some View {
        ZStack {
            // Gauge track (open at the bottom).
            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(130))

            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(VaultTheme.brandGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(130))

            // Vault face.
            Circle()
                .fill(.black.opacity(0.55))
                .frame(width: size * 0.5, height: size * 0.5)
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.8).frame(width: size * 0.5, height: size * 0.5))

            // Keyhole.
            KeyholeShape()
                .fill(VaultTheme.brandGradient)
                .frame(width: size * 0.2, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}

struct KeyholeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let cx = rect.midX
        let headR = w * 0.5
        p.addEllipse(in: CGRect(x: cx - headR, y: rect.minY, width: headR * 2, height: headR * 2))
        let topY = rect.minY + headR * 1.3
        let botY = rect.maxY
        let topHW = w * 0.22
        let botHW = w * 0.42
        p.move(to: CGPoint(x: cx - topHW, y: topY))
        p.addLine(to: CGPoint(x: cx + topHW, y: topY))
        p.addLine(to: CGPoint(x: cx + botHW, y: botY))
        p.addLine(to: CGPoint(x: cx - botHW, y: botY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Boot / launch screen

/// Sleek launch screen: the logo + wordmark settle in, a slim progress bar
/// fills, and a rotating set of appliance facts keeps the wait useful.
struct VaultBootView: View {
    @State private var start = Date.now
    @State private var appeared = false

    /// Kept just under the app's boot duration so the bar reads full on dismiss.
    private let total: Double = 3.2

    private let facts = [
        "Most major appliances last 8–15 years when service history is tracked.",
        "A saved serial number speeds up warranty claims and insurance reports.",
        "Routine filter cleaning eases HVAC strain and delays replacement costs.",
        "Credit cards sometimes add extended warranty coverage after purchase.",
        "Repair costs above 40% of replacement value deserve a second look."
    ]

    var body: some View {
        ZStack {
            VaultBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 22) {
                    VaultLogoMark(size: 104)
                        .shadow(color: VaultTheme.accent.opacity(0.35), radius: 24)

                    VStack(spacing: 6) {
                        Text("Vaultify")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Your home asset vault")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.94)
                .blur(radius: appeared ? 0 : 6)

                Spacer()

                bootFooter
                    .opacity(appeared ? 1 : 0)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 64)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
        }
    }

    private var bootFooter: some View {
        TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 1.0 / 8.0 : 1.0 / 30.0)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(start))
            let progress = min(1, elapsed / total)
            let factIndex = min(facts.count - 1, Int(elapsed / 1.25) % facts.count)

            VStack(spacing: 18) {
                Text(facts[factIndex])
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(height: 38)
                    .id(factIndex)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.45), value: factIndex)

                VStack(spacing: 8) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.10))
                            Capsule()
                                .fill(VaultTheme.brandGradient)
                                .frame(width: max(6, proxy.size.width * progress))
                                .shadow(color: VaultTheme.accent.opacity(0.5), radius: 5)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text("Preparing your vault")
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.42))
                }
            }
        }
        .frame(maxWidth: 460)
    }
}

// MARK: - Reactor core hero

/// A living portfolio "core": a pulsing plasma center whose color reflects
/// health, wrapped by health & risk arcs, with each asset orbiting as a mote.
struct VaultCore: View {
    var health: Double
    var risk: Double
    var signals: [Double]          // per-asset risk
    var size: CGFloat = 132

    var body: some View {
        TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 1.0 / 8.0 : 1.0 / 16.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, sz in
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let R = min(sz.width, sz.height) / 2
                let core = healthColor(health)

                // Faint nested rings.
                for i in 0..<3 {
                    let rr = R * (0.5 + CGFloat(i) * 0.22)
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                               with: .color(.white.opacity(0.06)), lineWidth: 1)
                }

                // Health arc (rotating).
                var hArc = Path()
                let hStart = Angle.degrees(t * 18 - 90)
                hArc.addArc(center: c, radius: R * 0.86, startAngle: hStart,
                            endAngle: hStart + .degrees(health * 300), clockwise: false)
                ctx.stroke(hArc, with: .linearGradient(Gradient(colors: [VaultTheme.cyan, core]),
                                                       startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: sz.width, y: sz.height)),
                           style: StrokeStyle(lineWidth: R * 0.085, lineCap: .round))

                // Risk arc (counter-rotating, inner).
                var rArc = Path()
                let rStart = Angle.degrees(-t * 26 + 90)
                rArc.addArc(center: c, radius: R * 0.66, startAngle: rStart,
                            endAngle: rStart + .degrees(risk * 220), clockwise: false)
                ctx.stroke(rArc, with: .color(VaultTheme.warn.opacity(0.85)),
                           style: StrokeStyle(lineWidth: R * 0.04, lineCap: .round))

                // Plasma center.
                let pulse = 0.5 + 0.5 * sin(t * 1.8)
                let coreR = R * 0.34 * (0.9 + 0.12 * pulse)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - coreR * 1.7, y: c.y - coreR * 1.7, width: coreR * 3.4, height: coreR * 3.4)),
                         with: .radialGradient(Gradient(colors: [core.opacity(0.55), .clear]), center: c, startRadius: 0, endRadius: coreR * 1.7))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2)),
                         with: .radialGradient(Gradient(colors: [.white, core]), center: CGPoint(x: c.x - coreR * 0.3, y: c.y - coreR * 0.3),
                                               startRadius: 0, endRadius: coreR))

                // Orbiting asset motes.
                let n = max(1, signals.count)
                for (i, s) in signals.prefix(10).enumerated() {
                    let speed = 0.4 + s * 0.6
                    let ang = t * speed + Double(i) / Double(n) * .pi * 2
                    let orbit = R * (0.55 + CGFloat(s) * 0.30)
                    let pt = CGPoint(x: c.x + cos(ang) * orbit, y: c.y + sin(ang) * orbit)
                    let tint = healthColor(1 - s)
                    let dr = R * (0.05 + CGFloat(s) * 0.03)
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - dr * 1.8, y: pt.y - dr * 1.8, width: dr * 3.6, height: dr * 3.6)),
                             with: .radialGradient(Gradient(colors: [tint.opacity(0.6), .clear]), center: pt, startRadius: 0, endRadius: dr * 1.8))
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - dr, y: pt.y - dr, width: dr * 2, height: dr * 2)), with: .color(tint))
                }
            }
        }
        .frame(width: size, height: size)
        .overlay {
            VStack(spacing: 2) {
                Text(health, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: size * 0.18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("HEALTH")
                    .font(.system(size: size * 0.055, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.vertical, max(6, size * 0.05))
            .padding(.horizontal, max(10, size * 0.08))
            .frame(minWidth: size * 0.56)
            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: size * 0.13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.13, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.32), radius: 6, y: 3)
        }
    }
}

// MARK: - Event horizon timeline

/// A gravitational timeline: "now" is the core, each appliance falls inward
/// as its replacement date approaches. Distance = years remaining, size = cost.
struct EventHorizon: View {
    struct Node: Identifiable {
        let id = UUID()
        var years: Double
        var cost: Double
        var color: Color
        var angle: Double
    }

    var nodes: [Node]
    var maxYears: Double = 6
    var maxCost: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 1.0 / 7.0 : 1.0 / 14.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let maxR = min(sz.width, sz.height) / 2 - 12

                    // Year rings. Labels live in SwiftUI overlays so they stay
                    // readable above the animated canvas.
                    for year in stride(from: 1, through: Int(maxYears), by: 1) {
                        let rr = maxR * CGFloat(Double(year) / maxYears)
                        let ring = Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
                        ctx.stroke(ring, with: .color(.white.opacity(year % 2 == 0 ? 0.10 : 0.05)),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    }

                    // Radar sweep.
                    let sweep = t * 0.5
                    var beam = Path()
                    beam.move(to: c)
                    beam.addArc(center: c, radius: maxR, startAngle: .radians(sweep), endAngle: .radians(sweep + 0.5), clockwise: false)
                    ctx.fill(beam, with: .radialGradient(Gradient(colors: [VaultTheme.accent.opacity(0.18), .clear]),
                                                         center: c, startRadius: 0, endRadius: maxR))

                    // Nodes + tethers.
                    for node in nodes {
                        let yr = min(maxYears, max(0.05, node.years))
                        let rr = maxR * CGFloat(yr / maxYears)
                        let drift = sin(t * 0.8 + node.angle * 3) * 0.04
                        let ang = node.angle + drift
                        let pt = CGPoint(x: c.x + cos(ang) * rr, y: c.y + sin(ang) * rr)

                        var tether = Path()
                        tether.move(to: c); tether.addLine(to: pt)
                        ctx.stroke(tether, with: .color(node.color.opacity(0.14)), lineWidth: 1)

                        let twinkle = 0.7 + 0.3 * sin(t * 2 + node.angle * 5)
                        let dr = 4 + CGFloat(min(1, node.cost / maxCost)) * 12
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - dr * 1.35, y: pt.y - dr * 1.35, width: dr * 2.7, height: dr * 2.7)),
                                 with: .radialGradient(Gradient(colors: [node.color.opacity(0.35 * twinkle), .clear]), center: pt, startRadius: 0, endRadius: dr * 1.35))
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - dr, y: pt.y - dr, width: dr * 2, height: dr * 2)), with: .color(node.color))
                        ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - dr, y: pt.y - dr, width: dr * 2, height: dr * 2)),
                                   with: .color(.white.opacity(0.5 * twinkle)), lineWidth: 1)
                    }
                }

                EventHorizonLabels(maxYears: maxYears)

                // Core.
                ZStack {
                    Circle().fill(.black.opacity(0.62)).frame(width: 62, height: 62)
                    Circle().stroke(VaultTheme.accent.opacity(0.72), lineWidth: 1.2).frame(width: 62, height: 62)
                    Image(systemName: "lock.shield.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(VaultTheme.accent)
                }
                .shadow(color: VaultTheme.accent.opacity(0.32), radius: 8)
            }
        }
    }
}

private struct EventHorizonLabels: View {
    let maxYears: Double

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let maxR = min(proxy.size.width, proxy.size.height) / 2 - 12

            ZStack {
                ForEach([1, 3, 5], id: \.self) { year in
                    ReadableOrbitLabel("\(year)y")
                        .position(
                            x: center.x,
                            y: center.y - (maxR * CGFloat(Double(year) / maxYears)) - 14
                        )
                }

                ReadableOrbitLabel("NOW", tint: VaultTheme.accent)
                    .position(x: center.x, y: center.y + 48)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ReadableOrbitLabel: View {
    let text: String
    var tint: Color

    init(_ text: String, tint: Color = .white) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.vertical, 4)
            .padding(.horizontal, 7)
            .background(.black.opacity(0.68), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    }
}

// MARK: - Liquid fill gauge

/// Circular gauge that fills like liquid, with a live animated surface wave.
struct LiquidGauge: View {
    var value: Double
    var tint: Color
    var size: CGFloat = 64

    var body: some View {
        TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 1.0 / 6.0 : 1.0 / 12.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, sz in
                let circle = Path(ellipseIn: CGRect(x: 2, y: 2, width: sz.width - 4, height: sz.height - 4))
                ctx.stroke(circle, with: .color(.white.opacity(0.14)), lineWidth: 2)
                ctx.drawLayer { layer in
                    layer.clip(to: circle)
                    let v = CGFloat(min(1, max(0, value)))
                    let level = sz.height * (1 - v)
                    let amp: CGFloat = 3.2

                    func wave(_ phase: CGFloat, _ opacity: Double) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: level))
                        stride(from: CGFloat(0), through: sz.width, by: 3).forEach { x in
                            let y = level + sin(x / sz.width * .pi * 4 + phase) * amp
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: sz.width, y: sz.height))
                        path.addLine(to: CGPoint(x: 0, y: sz.height))
                        path.closeSubpath()
                        layer.fill(path, with: .linearGradient(Gradient(colors: [tint.opacity(opacity), tint.opacity(opacity * 0.6)]),
                                                               startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: sz.height)))
                    }
                    wave(CGFloat(t * 2.2) + .pi, 0.35)
                    wave(CGFloat(t * 2.8), 0.85)
                }
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Text(value, format: .percent.precision(.fractionLength(0)))
                .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, size * 0.07)
                .padding(.horizontal, size * 0.10)
                .background(.black.opacity(0.58), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.7))
                .shadow(color: .black.opacity(0.32), radius: 5, y: 2)
        }
    }
}

// MARK: - Scan processing loader

/// Shown while an invoice is being read on-device.
struct VaultProcessingView: View {
    var caption: String = "Reading invoice…"
    @State private var start = Date.now

    var body: some View {
        ZStack {
            VaultBackground()
            VStack(spacing: 24) {
                TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 1.0 / 8.0 : 1.0 / 16.0)) { timeline in
                    let t = timeline.date.timeIntervalSince(start)
                    Canvas { ctx, sz in
                        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        let R = min(sz.width, sz.height) / 2 - 6
                        for i in 0..<3 {
                            let sp = t * (0.8 + Double(i) * 0.4) * (i % 2 == 0 ? 1 : -1)
                            var arc = Path()
                            arc.addArc(center: c, radius: R - CGFloat(i) * 12, startAngle: .radians(sp), endAngle: .radians(sp + 1.8), clockwise: false)
                            ctx.stroke(arc, with: .color([VaultTheme.accent, VaultTheme.cyan, VaultTheme.violet][i].opacity(0.9)),
                                       style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        }
                        // scanning line
                        let y = c.y + sin(t * 2) * R * 0.7
                        var line = Path()
                        line.move(to: CGPoint(x: c.x - R * 0.5, y: y)); line.addLine(to: CGPoint(x: c.x + R * 0.5, y: y))
                        ctx.stroke(line, with: .color(VaultTheme.accent.opacity(0.5)), lineWidth: 1.5)
                    }
                    .frame(width: 96, height: 96)
                }
                Text(caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
