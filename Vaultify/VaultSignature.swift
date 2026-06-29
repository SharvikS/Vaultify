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

// MARK: - Boot / seal sequence

/// Full-screen launch animation: an energy seal that converges, draws its
/// hex sigil, and ignites — then the wordmark resolves.
struct VaultBootView: View {
    @State private var start = Date.now

    var body: some View {
        ZStack {
            VaultBackground()

            TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 1.0 / 10.0 : 1.0 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                let p = min(1, t / 1.5)
                let ease = 1 - pow(1 - p, 3)          // easeOutCubic
                let ignite = max(0, (p - 0.7) / 0.3)  // last 30%

                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let R = min(size.width, size.height) * 0.30

                    // Expanding ripple rings.
                    for i in 0..<3 {
                        let rp = ((t / 1.6) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                        let radius = R * (0.4 + CGFloat(rp) * 2.4)
                        let ring = Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
                        ctx.stroke(ring, with: .color(VaultTheme.accent.opacity((1 - rp) * 0.25)), lineWidth: 1)
                    }

                    // Converging particles.
                    for k in 0..<32 {
                        let ang = Double(k) / 32 * .pi * 2 + t * 0.6
                        let dist = R * (2.3 * (1 - ease)) + R * 0.55 + sin(t * 3 + Double(k)) * 3
                        let pt = CGPoint(x: c.x + cos(ang) * dist, y: c.y + sin(ang) * dist)
                        let dotR = 1.4 + vfrac(k) * 1.8
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - dotR, y: pt.y - dotR, width: dotR * 2, height: dotR * 2)),
                                 with: .color(VaultTheme.cyan.opacity(0.35 + 0.5 * ease)))
                    }

                    // Rotating tick ring.
                    for k in 0..<48 {
                        let ang = Double(k) / 48 * .pi * 2 + t * 0.4
                        let inner = R * 1.18, outer = R * 1.18 + (k % 4 == 0 ? 9 : 5)
                        var tick = Path()
                        tick.move(to: CGPoint(x: c.x + cos(ang) * inner, y: c.y + sin(ang) * inner))
                        tick.addLine(to: CGPoint(x: c.x + cos(ang) * outer, y: c.y + sin(ang) * outer))
                        ctx.stroke(tick, with: .color(.white.opacity(0.10 + 0.25 * ease)), lineWidth: 1.2)
                    }

                    // Hex sigil, drawn (trimmed) by progress.
                    var hex = Path()
                    for i in 0...6 {
                        let a = Double(i) / 6 * .pi * 2 - .pi / 2
                        let pt = CGPoint(x: c.x + cos(a) * R, y: c.y + sin(a) * R)
                        if i == 0 { hex.move(to: pt) } else { hex.addLine(to: pt) }
                    }
                    let drawn = hex.trimmedPath(from: 0, to: ease)
                    ctx.stroke(drawn, with: .linearGradient(Gradient(colors: [VaultTheme.accent, VaultTheme.cyan]),
                                                            startPoint: CGPoint(x: c.x - R, y: c.y - R),
                                                            endPoint: CGPoint(x: c.x + R, y: c.y + R)),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Ignition core glow.
                    if ignite > 0 {
                        let glowR = R * (0.2 + 0.55 * ignite)
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - glowR, y: c.y - glowR, width: glowR * 2, height: glowR * 2)),
                                 with: .radialGradient(Gradient(colors: [VaultTheme.accent.opacity(0.9 * ignite), .clear]),
                                                       center: c, startRadius: 0, endRadius: glowR))
                    }
                }
            }
            .ignoresSafeArea()

            // Wordmark resolves in.
            VStack(spacing: 16) {
                Spacer()
                BootWordmark(start: start)
                BootLoadingPanel(start: start)
                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct BootWordmark: View {
    let start: Date
    var body: some View {
        TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 1.0 / 10.0 : 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let p = min(1, max(0, (t - 0.7) / 0.8))
            Text("VAULTIFY")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .tracking(14 - 8 * p)
                .foregroundStyle(.white)
                .opacity(p)
                .shadow(color: VaultTheme.accent.opacity(0.6 * p), radius: 12)
        }
    }
}

private struct BootLoadingPanel: View {
    let start: Date

    private let facts = [
        "Most major appliances last 8 to 15 years when service history is tracked.",
        "A saved serial number can speed up warranty claims and insurance reports.",
        "Routine filter cleaning can cut HVAC strain and delay replacement costs.",
        "Credit cards sometimes add extended warranty coverage after purchase.",
        "Repair costs above 40% of replacement value deserve a second look."
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 0.75 : 0.35)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(start) - 0.55)
            let factIndex = min(facts.count - 1, Int(elapsed / 0.95) % facts.count)
            let progress = min(1, max(0, elapsed / 3.55))
            let pulse = 0.5 + 0.5 * sin(timeline.date.timeIntervalSinceReferenceDate * 3)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(VaultTheme.accent.opacity(0.22), lineWidth: 2)
                            .frame(width: 34, height: 34)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(VaultTheme.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 34, height: 34)
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.black))
                            .foregroundStyle(VaultTheme.accent)
                            .scaleEffect(0.94 + 0.08 * pulse)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Preparing your vault")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                        Text(facts[factIndex])
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .contentTransition(.opacity)
                    }

                    Spacer(minLength: 0)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(colors: [VaultTheme.accent, VaultTheme.cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(18, proxy.size.width * progress))
                    }
                }
                .frame(height: 5)
            }
            .padding(14)
            .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
            .opacity(elapsed > 0 ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: factIndex)
        }
        .frame(maxWidth: 420)
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
