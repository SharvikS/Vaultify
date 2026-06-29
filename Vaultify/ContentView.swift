//
//  ContentView.swift
//  Vaultify
//
//  A Liquid Glass redesign — an immersive dark "vault" composed of
//  translucent glass surfaces over a living aurora, with real invoice
//  scanning, reminders, and PDF export wired underneath.
//

import SwiftData
import SwiftUI
import VisionKit

// MARK: - Sorting & filtering

enum ApplianceSortMode: String, CaseIterable, Identifiable {
    case risk, value, newest, oldest, warranty
    var id: String { rawValue }

    var title: String {
        switch self {
        case .risk: "Highest risk"
        case .value: "Highest value"
        case .newest: "Newest"
        case .oldest: "Oldest"
        case .warranty: "Warranty soon"
        }
    }

    var symbol: String {
        switch self {
        case .risk: "exclamationmark.triangle"
        case .value: "dollarsign.circle"
        case .newest: "calendar.badge.plus"
        case .oldest: "calendar"
        case .warranty: "shield.lefthalf.filled"
        }
    }
}

enum ApplianceFilterMode: String, CaseIterable, Identifiable {
    case all, protected, attention, replace, uninsured
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .protected: "Protected"
        case .attention: "Attention"
        case .replace: "Replace"
        case .uninsured: "Uninsured"
        }
    }
}

enum VaultHomeMode: String, CaseIterable, Identifiable {
    case command, exposure, funding
    var id: String { rawValue }

    var title: String {
        switch self {
        case .command: "Command"
        case .exposure: "Exposure"
        case .funding: "Funding"
        }
    }

    var symbol: String {
        switch self {
        case .command: "scope"
        case .exposure: "waveform.path.ecg"
        case .funding: "banknote"
        }
    }
}

enum AssetDisplayMode: String, CaseIterable, Identifiable {
    case deck, matrix
    var id: String { rawValue }

    var title: String {
        switch self {
        case .deck: "Deck"
        case .matrix: "Matrix"
        }
    }

    var symbol: String {
        switch self {
        case .deck: "rectangle.stack.fill"
        case .matrix: "square.grid.2x2.fill"
        }
    }
}

enum DetailMode: String, CaseIterable, Identifiable {
    case signals, identity, records
    var id: String { rawValue }

    var title: String {
        switch self {
        case .signals: "Signals"
        case .identity: "Identity"
        case .records: "Records"
        }
    }

    var symbol: String {
        switch self {
        case .signals: "waveform.path.ecg"
        case .identity: "tag.fill"
        case .records: "folder.badge.gearshape"
        }
    }
}

// MARK: - Root

enum VaultTab: String, CaseIterable, Identifiable {
    case vault, assets, forecast, insights, reports
    var id: String { rawValue }

    var title: String {
        switch self {
        case .vault: "Vault"
        case .assets: "Assets"
        case .forecast: "Forecast"
        case .insights: "Intel"
        case .reports: "Reports"
        }
    }

    var symbol: String {
        switch self {
        case .vault: "lock.shield.fill"
        case .assets: "square.stack.3d.up.fill"
        case .forecast: "chart.line.uptrend.xyaxis"
        case .insights: "sparkles"
        case .reports: "doc.text.fill"
        }
    }

    var tint: Color {
        switch self {
        case .vault: VaultTheme.accent
        case .assets: VaultTheme.cyan
        case .forecast: VaultTheme.warn
        case .insights: VaultTheme.violet
        case .reports: VaultTheme.danger
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = VaultTab(rawValue: UserDefaults.standard.string(forKey: "VaultInitialTab") ?? "") ?? .vault
    @State private var theme = VaultThemeStore.shared

    var body: some View {
        // Re-keying on the active theme rebuilds the tree so every VaultTheme accent
        // re-reads the new palette; the opacity transition makes that swap a smooth crossfade.
        ZStack {
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .vault: VaultHomeView()
                    case .assets: AssetsView()
                    case .forecast: ForecastView()
                    case .insights: InsightsView()
                    case .reports: ReportsView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.985)),
                    removal: .opacity
                ))

                OrbitalTabDock(selection: $selectedTab)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            .tint(VaultTheme.accent)
            .animation(.spring(response: 0.44, dampingFraction: 0.86), value: selectedTab)
            .id(theme.kind)
            .transition(.opacity)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.6), value: theme.kind)
    }
}

struct OrbitalTabDock: View {
    @Binding var selection: VaultTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(VaultTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if selection == tab {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(tab.tint.opacity(0.22))
                                    .frame(height: 36)
                                    .matchedGeometryEffect(id: "dock-pill", in: tabNamespace)
                                    .shadow(color: tab.tint.opacity(0.30), radius: 8, y: 3)
                            }

                            Image(systemName: tab.symbol)
                                .font(.system(size: selection == tab ? 17 : 15, weight: .black))
                                .foregroundStyle(selection == tab ? tab.tint : .white.opacity(0.6))
                                .frame(width: 42, height: 34)
                                .symbolEffect(.bounce, value: selection == tab)
                        }

                        Text(tab.title)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(selection == tab ? .white : .white.opacity(0.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .contentShape(.rect)
                }
                .buttonStyle(.vaultPress)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .glassEffect(.regular.tint(.white.opacity(0.06)), in: .rect(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.20), radius: 14, y: 8)
        .frame(height: 76)
    }
}

// MARK: - Vault home

struct VaultHomeView: View {
    @Query(sort: \Appliance.purchaseDate, order: .reverse) private var appliances: [Appliance]
    @State private var showAdd = false
    @State private var showSettings = false
    @State private var mode = VaultHomeMode.command
    @State private var heroExpanded = false

    private var totalValue: Double { appliances.reduce(0) { $0 + max($1.purchasePrice, $1.replacementBudgetTarget) } }
    private var averageHealth: Double {
        appliances.isEmpty ? 0 : appliances.reduce(0) { $0 + $1.healthScore } / Double(appliances.count)
    }
    private var riskLoad: Double {
        appliances.isEmpty ? 0 : appliances.reduce(0) { $0 + $1.riskScore } / Double(appliances.count)
    }
    private var reserve: Double {
        appliances.reduce(0) { $0 + max(0, $1.replacementBudgetTarget * (1 - $1.healthScore)) }
    }
    private var claimsDue: [Appliance] {
        appliances.filter { ($0.daysUntilWarrantyExpires ?? .max) <= 90 }
            .sorted { ($0.daysUntilWarrantyExpires ?? .max) < ($1.daysUntilWarrantyExpires ?? .max) }
    }
    private var serviceDue: [Appliance] {
        appliances.filter { $0.nextMaintenanceDate <= .now }
    }
    private var attention: [Appliance] {
        appliances.filter { $0.riskScore > 0.45 || $0.shouldReviewRepairVsReplace }
            .sorted { $0.riskScore > $1.riskScore }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                if appliances.isEmpty {
                    VaultEmptyState(
                        title: "Your vault is empty",
                        message: "Scan an invoice or add an appliance to start tracking warranties, health, and replacement budgets.",
                        symbol: "lock.shield"
                    ) { showAdd = true }
                } else {
                  GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 18) {
                            PortfolioHero(totalValue: totalValue, health: averageHealth, risk: riskLoad,
                                          count: appliances.count, signals: appliances.map(\.riskScore),
                                          expanded: heroExpanded)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                                        heroExpanded.toggle()
                                    }
                                }
                                .interactiveLift(tint: healthColor(averageHealth))

                            VaultModeSwitch(selection: $mode)
                            VaultModePanel(mode: mode, reserve: reserve, totalValue: totalValue,
                                           claimsDue: claimsDue, serviceDue: serviceDue,
                                           attention: attention) { showAdd = true }

                            HStack(spacing: 12) {
                                QuickStatTile(value: "\(appliances.count)", label: "Assets", symbol: "shippingbox.fill", tint: VaultTheme.accent)
                                QuickStatTile(value: "\(claimsDue.count)", label: "Claims", symbol: "bell.badge.fill", tint: VaultTheme.warn)
                                QuickStatTile(value: "\(serviceDue.count)", label: "Service", symbol: "wrench.adjustable.fill", tint: VaultTheme.cyan)
                            }

                            ScanIntakeBanner { showAdd = true }

                            if !attention.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    GlassSectionHeader(title: "Needs attention", caption: "\(attention.count) flagged")
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(attention.prefix(8)) { appliance in
                                                NavigationLink { ApplianceDetailView(appliance: appliance) } label: {
                                                    AttentionCard(appliance: appliance)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                GlassSectionHeader(title: "Reserve outlook", caption: "self-fund")
                                ReserveCard(reserve: reserve, total: totalValue)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                GlassSectionHeader(title: "Recent assets")
                                ForEach(appliances.prefix(5)) { appliance in
                                    NavigationLink { ApplianceDetailView(appliance: appliance) } label: {
                                        AssetRow(appliance: appliance)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 18)
                        .frame(width: max(0, geo.size.width - 32))
                        .frame(maxWidth: .infinity)
                        .safeAreaPadding(.bottom, 94)
                    }
                    .scrollIndicators(.hidden)
                  }
                }
            }
            .navigationTitle("Vault")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddApplianceView() }
            .sheet(isPresented: $showSettings) { SettingsSheet(appliances: appliances) }
        }
    }
}

struct PortfolioHero: View {
    let totalValue: Double
    let health: Double
    let risk: Double
    let count: Int
    var signals: [Double] = []
    var expanded = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Eyebrow("Protected value", tint: VaultTheme.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize()
                        Image(systemName: expanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Text(totalValue, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                    Text("\(count) sealed asset\(count == 1 ? "" : "s")")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer(minLength: 8)
                VaultCore(health: health, risk: risk, signals: signals, size: expanded ? 138 : 116)
            }

            HStack(spacing: 8) {
                StatChip(label: "Health", value: health.formatted(.percent.precision(.fractionLength(0))), tint: VaultTheme.accent)
                StatChip(label: "Risk", value: risk.formatted(.percent.precision(.fractionLength(0))), tint: VaultTheme.warn)
                Spacer(minLength: 0)
            }

            if expanded {
                HStack(spacing: 10) {
                    HeroMicroMetric(title: "Signal density", value: "\(signals.count)", symbol: "dot.radiowaves.left.and.right")
                    HeroMicroMetric(title: "Clean assets", value: "\(signals.filter { $0 < 0.25 }.count)", symbol: "checkmark.seal.fill")
                    HeroMicroMetric(title: "Hot zones", value: "\(signals.filter { $0 > 0.45 }.count)", symbol: "flame.fill")
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .glassCard(padding: 18)
    }
}

struct HeroMicroMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.black))
                .foregroundStyle(VaultTheme.cyan)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.white.opacity(0.44))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct VaultModeSwitch: View {
    @Binding var selection: VaultHomeMode
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(VaultHomeMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: mode.symbol)
                            .font(.caption.weight(.black))
                        Text(mode.title)
                            .font(.caption.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selection == mode ? .black : .white.opacity(0.66))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .background {
                        if selection == mode {
                            Capsule()
                                .fill(VaultTheme.accent)
                                .matchedGeometryEffect(id: "mode", in: namespace)
                        }
                    }
                }
                .buttonStyle(.vaultPress)
            }
        }
        .padding(5)
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.8))
    }
}

struct VaultModePanel: View {
    let mode: VaultHomeMode
    let reserve: Double
    let totalValue: Double
    let claimsDue: [Appliance]
    let serviceDue: [Appliance]
    let attention: [Appliance]
    let scan: () -> Void

    var body: some View {
        Group {
            switch mode {
            case .command:
                HStack(spacing: 10) {
                    Button(action: scan) {
                        ActionPill(title: "Scan", symbol: "doc.viewfinder", tint: VaultTheme.accent, filled: true)
                    }
                    .buttonStyle(.vaultPress)

                    CommandPulse(title: "Claims", value: "\(claimsDue.count)", symbol: "bell.badge.fill", tint: VaultTheme.warn)
                    CommandPulse(title: "Service", value: "\(serviceDue.count)", symbol: "wrench.adjustable.fill", tint: VaultTheme.cyan)
                }
            case .exposure:
                VStack(alignment: .leading, spacing: 10) {
                    GlassSectionHeader(title: "Exposure map", caption: "\(attention.count) signals")
                    ForEach(attention.prefix(3)) { appliance in
                        HStack(spacing: 10) {
                            GlyphBadge(symbol: appliance.category.symbol, tint: appliance.signalColor, size: 38)
                            Text(appliance.name)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            MeterBar(value: appliance.riskScore, tint: appliance.signalColor)
                                .frame(width: 92)
                        }
                    }
                    if attention.isEmpty {
                        Text("No active risk clusters.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }
                .glassCard(22, padding: 15, tint: VaultTheme.warn)
            case .funding:
                FundingStrip(reserve: reserve, total: totalValue)
            }
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }
}

struct CommandPulse: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 11)
        .glassEffect(.regular.tint(tint.opacity(0.12)), in: .rect(cornerRadius: 18))
    }
}

struct FundingStrip: View {
    let reserve: Double
    let total: Double
    @State private var multiplier = 1.0

    private var monthly: Double { max(0, reserve / 24 * multiplier) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Reserve tuner", tint: VaultTheme.cyan)
                Spacer()
                Text(monthly, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
            }
            Slider(value: $multiplier, in: 0.5...2.0)
                .tint(VaultTheme.cyan)
            HStack {
                Text("24 mo baseline")
                Spacer()
                Text("\(Int(multiplier * 100))% pace")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.5))
            MeterBar(value: total > 0 ? reserve / total : 0, tint: VaultTheme.cyan, height: 8)
        }
        .glassCard(22, padding: 15, tint: VaultTheme.cyan)
    }
}

struct QuickStatTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.caption2.weight(.heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(20, padding: 14, tint: tint)
    }
}

struct ScanIntakeBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(VaultTheme.accent.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                        .frame(width: 56, height: 70)
                    Image(systemName: "doc.viewfinder")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(VaultTheme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("AI intake", tint: VaultTheme.accent)
                    Text("Scan an invoice")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Auto-fill brand, model, price & date on-device.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
            }
            .glassCard(tint: VaultTheme.accent)
        }
        .buttonStyle(.plain)
    }
}

struct ReserveCard: View {
    let reserve: Double
    let total: Double

    private var coverage: Double { total > 0 ? min(1, reserve / total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(reserve, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                    .font(.system(.title, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Text("to self-fund replacements")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            MeterBar(value: coverage, tint: VaultTheme.cyan, height: 9)
        }
        .glassCard()
    }
}

struct AttentionCard: View {
    let appliance: Appliance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GlyphBadge(symbol: appliance.category.symbol, tint: appliance.signalColor)
                Spacer()
                Text(appliance.riskScore, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.black))
                    .foregroundStyle(appliance.signalColor)
            }
            Text(appliance.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(appliance.lifecycleStage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 0)
            MeterBar(value: appliance.riskScore, tint: appliance.signalColor)
        }
        .frame(width: 168, height: 168, alignment: .topLeading)
        .glassCard(22, padding: 16, tint: appliance.signalColor)
    }
}

struct AssetRow: View {
    let appliance: Appliance

    var body: some View {
        HStack(spacing: 14) {
            GlyphBadge(symbol: appliance.category.symbol, tint: appliance.signalColor, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(appliance.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(appliance.displayBrand) · \(appliance.ageLabel)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                MeterBar(value: appliance.healthScore, tint: VaultTheme.accent, height: 5)
                    .frame(width: 120)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(appliance.lifecycleStage.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.black)
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(appliance.signalColor, in: Capsule())
                Text(appliance.replacementBudgetTarget, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .glassCard(22, padding: 14)
        .interactiveLift(tint: appliance.signalColor)
    }
}

struct AssetMatrixCard: View {
    let appliance: Appliance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GlyphBadge(symbol: appliance.category.symbol, tint: appliance.signalColor, size: 42)
                Spacer()
                Text(appliance.riskScore, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.black))
                    .foregroundStyle(appliance.signalColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(appliance.name)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(appliance.displayBrand)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            MeterBar(value: appliance.healthScore, tint: healthColor(appliance.healthScore), height: 6)
            HStack {
                Text(appliance.lifecycleStage.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.52))
                Spacer()
                Text(appliance.replacementBudgetTarget, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 166)
        .glassCard(24, padding: 15, tint: appliance.signalColor)
        .interactiveLift(tint: appliance.signalColor)
    }
}

// MARK: - Assets

struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Appliance.purchaseDate, order: .reverse) private var appliances: [Appliance]

    @State private var showAdd = false
    @State private var search = ""
    @State private var category: ApplianceCategory?
    @State private var filter = ApplianceFilterMode.all
    @State private var sort = ApplianceSortMode.risk
    @State private var displayMode = AssetDisplayMode.deck

    private var results: [Appliance] {
        appliances.filter { appliance in
            (search.isEmpty
                || appliance.name.localizedCaseInsensitiveContains(search)
                || appliance.brand.localizedCaseInsensitiveContains(search)
                || appliance.modelNumber.localizedCaseInsensitiveContains(search)
                || appliance.category.title.localizedCaseInsensitiveContains(search))
            && (category == nil || appliance.category == category)
            && passes(appliance)
        }
        .sorted(by: ordering)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        AssetFilterBar(category: $category, filter: $filter, sort: $sort,
                                       visible: results.count, total: appliances.count)
                        AssetViewSwitcher(selection: $displayMode)

                        if results.isEmpty {
                            VaultEmptyState(title: "Nothing here yet",
                                            message: "Adjust filters or add your first appliance.",
                                            symbol: "tray") { showAdd = true }
                                .padding(.top, 14)
                        } else if displayMode == .deck {
                            LazyVStack(spacing: 10) {
                                ForEach(results) { appliance in
                                    NavigationLink { ApplianceDetailView(appliance: appliance) } label: {
                                        AssetRow(appliance: appliance)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation { modelContext.delete(appliance) }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            }
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(results) { appliance in
                                    NavigationLink { ApplianceDetailView(appliance: appliance) } label: {
                                        AssetMatrixCard(appliance: appliance)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation { modelContext.delete(appliance) }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .safeAreaPadding(.bottom, 94)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Assets")
            .searchable(text: $search, prompt: "Name, brand, model, category")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddApplianceView() }
        }
    }

    private func passes(_ appliance: Appliance) -> Bool {
        switch filter {
        case .all: true
        case .protected: appliance.status == .protected
        case .attention: appliance.status == .inspectSoon || appliance.status == .aging || appliance.shouldReviewRepairVsReplace
        case .replace: appliance.status == .planReplacement
        case .uninsured: appliance.activeWarranties.isEmpty
        }
    }

    private func ordering(_ lhs: Appliance, _ rhs: Appliance) -> Bool {
        switch sort {
        case .risk: lhs.riskScore > rhs.riskScore
        case .value: lhs.replacementBudgetTarget > rhs.replacementBudgetTarget
        case .newest: lhs.purchaseDate > rhs.purchaseDate
        case .oldest: lhs.purchaseDate < rhs.purchaseDate
        case .warranty: (lhs.daysUntilWarrantyExpires ?? .max) < (rhs.daysUntilWarrantyExpires ?? .max)
        }
    }
}

struct AssetViewSwitcher: View {
    @Binding var selection: AssetDisplayMode

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AssetDisplayMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    ActionPill(title: mode.title, symbol: mode.symbol, tint: VaultTheme.cyan, filled: selection == mode)
                }
                .buttonStyle(.vaultPress)
            }
            Spacer()
            Text(selection == .deck ? "Gesture deck" : "Signal matrix")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
        }
    }
}

struct AssetFilterBar: View {
    @Binding var category: ApplianceCategory?
    @Binding var filter: ApplianceFilterMode
    @Binding var sort: ApplianceSortMode
    let visible: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(visible) of \(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(ApplianceSortMode.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                } label: {
                    Label(sort.title, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.bold))
                }
                .tint(VaultTheme.accent)
            }

            Picker("Filter", selection: $filter) {
                ForEach(ApplianceFilterMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(title: "All", symbol: "square.grid.2x2", selected: category == nil) { category = nil }
                    ForEach(ApplianceCategory.allCases) { cat in
                        CategoryChip(title: cat.title, symbol: cat.symbol, selected: category == cat) {
                            category = category == cat ? nil : cat
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

struct CategoryChip: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? .black : .white.opacity(0.7))
                .padding(.vertical, 8).padding(.horizontal, 12)
        }
        .background {
            if selected { Capsule().fill(VaultTheme.accent) }
            else { Capsule().fill(.white.opacity(0.08)) }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Forecast

struct ForecastView: View {
    @Query private var appliances: [Appliance]

    private struct YearPoint: Identifiable { let id = UUID(); let year: Int; let amount: Double }

    private var points: [YearPoint] {
        let thisYear = Calendar.current.component(.year, from: .now)
        return (0..<6).map { offset in
            let year = thisYear + offset
            let amount = appliances
                .filter { Calendar.current.component(.year, from: $0.expectedEndOfLifeDate) == year }
                .reduce(0) { $0 + $1.replacementBudgetTarget }
            return YearPoint(year: year, amount: amount)
        }
    }

    private var fiveYearBudget: Double { points.reduce(0) { $0 + $1.amount } }

    private var horizonNodes: [EventHorizon.Node] {
        appliances.enumerated().map { index, appliance in
            let years = appliance.expectedEndOfLifeDate.timeIntervalSinceNow / (365.25 * 24 * 3600)
            return EventHorizon.Node(
                years: max(0.1, years),
                cost: appliance.replacementBudgetTarget,
                color: appliance.signalColor,
                angle: Double(index) * 2.399963  // golden angle for organic spread
            )
        }
    }

    private var maxCost: Double { max(1, appliances.map(\.replacementBudgetTarget).max() ?? 1) }
    private var urgent: Int {
        let cutoff = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
        return appliances.filter { $0.expectedEndOfLifeDate <= cutoff }.count
    }

    private func upcoming(within years: Int) -> [Appliance] {
        let cutoff = Calendar.current.date(byAdding: .year, value: years, to: .now) ?? .now
        return appliances.filter { $0.expectedEndOfLifeDate <= cutoff }
            .sorted { $0.expectedEndOfLifeDate < $1.expectedEndOfLifeDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow("6-year replacement budget", tint: VaultTheme.cyan)
                            Text(fiveYearBudget, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                                .font(.system(size: 40, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.6).lineLimit(1)
                            Text("\(urgent) asset\(urgent == 1 ? "" : "s") likely to need replacing within 12 months")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.55))

                            EventHorizon(nodes: horizonNodes, maxYears: 6, maxCost: maxCost)
                                .frame(height: 300)
                                .padding(.top, 4)
                        }
                        .glassCard(padding: 20)

                        ForecastBucket(title: "Next 12 months", items: upcoming(within: 1))
                        ForecastBucket(title: "Next 3 years", items: upcoming(within: 3))
                        ForecastBucket(title: "Next 5 years", items: upcoming(within: 5))
                    }
                    .padding(18)
                    .safeAreaPadding(.bottom, 94)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Forecast")
        }
    }
}

struct ForecastBucket: View {
    let title: String
    let items: [Appliance]

    private var total: Double { items.reduce(0) { $0 + $1.replacementBudgetTarget } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GlassSectionHeader(title: title)
                Text(total, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VaultTheme.accent)
            }
            if items.isEmpty {
                Text("No expected replacements in this window.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(20, padding: 16)
            } else {
                ForEach(items) { appliance in
                    HStack(spacing: 12) {
                        GlyphBadge(symbol: appliance.category.symbol, tint: appliance.signalColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appliance.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(appliance.expectedEndOfLifeDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(appliance.replacementBudgetTarget, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                            .font(.caption.weight(.bold)).foregroundStyle(.white)
                    }
                    .glassCard(20, padding: 14)
                }
            }
        }
    }
}

// MARK: - Insights

enum VaultChatRole: Equatable {
    case assistant
    case user
}

struct VaultChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: VaultChatRole
    let text: String
}

enum VaultChatBrain {
    static func opening(for appliances: [Appliance]) -> String {
        guard !appliances.isEmpty else {
            return "I am ready to analyze your vault. Add or scan an appliance and I will start ranking risk, warranty exposure, resale value, and replacement planning."
        }

        let totalValue = appliances.reduce(0) { $0 + max($1.purchasePrice, $1.replacementBudgetTarget) }
        let highestRisk = appliances.max { $0.riskScore < $1.riskScore }
        let name = highestRisk?.name ?? "your portfolio"
        let risk = highestRisk?.riskScore.formatted(.percent.precision(.fractionLength(0))) ?? "0%"
        return "I scanned \(appliances.count) asset\(appliances.count == 1 ? "" : "s") worth about \(totalValue.formatted(.currency(code: vaultCurrencyCode).precision(.fractionLength(0)))). Highest live signal: \(name) at \(risk) risk."
    }

    static func answer(_ prompt: String, appliances: [Appliance]) -> String {
        guard !appliances.isEmpty else {
            return "Your vault has no appliance data yet. Start with one invoice scan and I can answer risk, warranty, service, resale, and replacement questions from the record."
        }

        let lower = prompt.lowercased()

        if lower.contains("risk") || lower.contains("fail") || lower.contains("attention") || lower.contains("urgent") {
            let ranked = appliances.sorted { $0.riskScore > $1.riskScore }.prefix(3)
            let lines = ranked.map { appliance in
                "\(appliance.name): \(appliance.riskScore.formatted(.percent.precision(.fractionLength(0)))) risk, \(appliance.lifecycleStage.lowercased()) stage"
            }
            return "Top risk signals:\n" + lines.joined(separator: "\n") + "\nI would inspect the first item before spending on lower-risk assets."
        }

        if lower.contains("warranty") || lower.contains("claim") || lower.contains("expire") {
            let expiring = appliances
                .filter { $0.nextWarrantyExpiration != nil }
                .sorted { ($0.daysUntilWarrantyExpires ?? .max) < ($1.daysUntilWarrantyExpires ?? .max) }
                .prefix(3)

            guard !expiring.isEmpty else {
                return "I do not see active warranty dates in the vault. Add warranty records to unlock claim-window alerts and expiry ranking."
            }

            let lines = expiring.map { appliance in
                let days = appliance.daysUntilWarrantyExpires ?? 0
                return "\(appliance.name): \(days)d remaining"
            }
            return "Warranty watchlist:\n" + lines.joined(separator: "\n") + "\nAnything under 30 days should be checked for eligible claims now."
        }

        if lower.contains("save") || lower.contains("budget") || lower.contains("replace") || lower.contains("money") {
            let target = appliances.max { $0.monthlyReplacementSavingsTarget < $1.monthlyReplacementSavingsTarget }
            guard let target else { return "I need at least one replacement target before I can calculate a reserve plan." }
            return "Start funding \(target.name). Replacement target is \(target.replacementBudgetTarget.formatted(.currency(code: vaultCurrencyCode).precision(.fractionLength(0)))) and the current monthly reserve target is \(target.monthlyReplacementSavingsTarget.formatted(.currency(code: vaultCurrencyCode).precision(.fractionLength(0))))."
        }

        if lower.contains("service") || lower.contains("maintenance") || lower.contains("repair") {
            let due = appliances
                .sorted { $0.nextMaintenanceDate < $1.nextMaintenanceDate }
                .prefix(3)
            let lines = due.map { appliance in
                "\(appliance.name): \(appliance.nextMaintenanceDate.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Service queue:\n" + lines.joined(separator: "\n") + "\nLog each visit so reliability and repair-vs-replace signals stay accurate."
        }

        if lower.contains("resale") || lower.contains("sell") || lower.contains("value") {
            let ranked = appliances.sorted { $0.estimatedResaleValue > $1.estimatedResaleValue }.prefix(3)
            let lines = ranked.map { appliance in
                "\(appliance.name): \(appliance.estimatedResaleValue.formatted(.currency(code: vaultCurrencyCode).precision(.fractionLength(0)))) estimated resale"
            }
            return "Best resale candidates:\n" + lines.joined(separator: "\n") + "\nKeep serials, invoices, and service records attached before selling."
        }

        let averageRisk = appliances.reduce(0) { $0 + $1.riskScore } / Double(appliances.count)
        let activeWarranties = appliances.filter { !$0.activeWarranties.isEmpty }.count
        return "Portfolio readout: \(appliances.count) assets, \(activeWarranties) with active warranty coverage, average risk \(averageRisk.formatted(.percent.precision(.fractionLength(0)))). Ask me about risk, warranty, service, resale, or budget and I will drill in."
    }
}

struct InsightsView: View {
    @Query private var appliances: [Appliance]
    @State private var messages: [VaultChatMessage] = []
    @State private var draft = ""
    @State private var isThinking = false

    private let suggestions = [
        "What needs attention?",
        "Which warranty expires soon?",
        "Where should I save first?",
        "What service is due?",
        "Best resale candidates?"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                VaultAIHeader(applianceCount: appliances.count)

                                SuggestionRail(suggestions: suggestions, action: send)

                                LazyVStack(spacing: 12) {
                                    ForEach(messages) { message in
                                        VaultChatBubble(message: message)
                                            .id(message.id)
                                    }

                                    if isThinking {
                                        TypingBubble()
                                            .id("typing")
                                    }
                                }
                            }
                            .padding(18)
                            .safeAreaPadding(.bottom, 12)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: messages) { _, newMessages in
                            guard let last = newMessages.last else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: isThinking) { _, thinking in
                            guard thinking else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }

                    VaultChatComposer(text: $draft, disabled: isThinking, send: sendDraft)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 92)
                }
            }
            .navigationTitle("Vault AI")
            .onAppear(perform: seedChat)
            .onChange(of: appliances.count) { _, _ in
                if messages.count <= 1 {
                    messages = [VaultChatMessage(role: .assistant, text: VaultChatBrain.opening(for: appliances))]
                }
            }
        }
    }

    private func seedChat() {
        guard messages.isEmpty else { return }
        messages = [VaultChatMessage(role: .assistant, text: VaultChatBrain.opening(for: appliances))]
    }

    private func sendDraft() {
        send(draft)
    }

    private func send(_ rawPrompt: String) {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isThinking else { return }

        draft = ""
        messages.append(VaultChatMessage(role: .user, text: prompt))
        isThinking = true

        Task {
            try? await Task.sleep(for: .milliseconds(650))
            let answer = VaultChatBrain.answer(prompt, appliances: appliances)
            await MainActor.run {
                messages.append(VaultChatMessage(role: .assistant, text: answer))
                isThinking = false
            }
        }
    }
}

struct VaultAIHeader: View {
    let applianceCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                VaultCore(health: applianceCount == 0 ? 0.52 : 0.82, risk: applianceCount == 0 ? 0.16 : 0.28,
                          signals: [0.12, 0.28, 0.36], size: 82)
                Image(systemName: "sparkles")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("On-device vault assistant", tint: VaultTheme.violet)
                Text("Ask about your appliances")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
                Text("Risk, warranties, service timing, resale, and replacement reserves.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .glassCard(26, padding: 16, tint: VaultTheme.violet)
    }
}

struct SuggestionRail: View {
    let suggestions: [String]
    let action: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        action(suggestion)
                    } label: {
                        ActionPill(title: suggestion, symbol: "bolt.fill", tint: VaultTheme.violet)
                    }
                    .buttonStyle(.vaultPress)
                }
            }
        }
    }
}

struct VaultChatBubble: View {
    let message: VaultChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isUser { Spacer(minLength: 44) }

            if !isUser {
                GlyphBadge(symbol: "sparkles", tint: VaultTheme.violet, size: 34)
            }

            Text(message.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isUser ? .black : .white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background {
                    if isUser {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(VaultTheme.accent)
                    } else {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.075))
                            .glassEffect(.regular.tint(VaultTheme.violet.opacity(0.10)), in: .rect(cornerRadius: 22))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isUser ? .clear : .white.opacity(0.12), lineWidth: 0.8)
                )

            if !isUser { Spacer(minLength: 28) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

struct TypingBubble: View {
    var body: some View {
        HStack(spacing: 10) {
            GlyphBadge(symbol: "sparkles", tint: VaultTheme.violet, size: 34)
            TimelineView(.animation(minimumInterval: vaultReducedPerformanceMode ? 1.0 / 4.0 : 1.0 / 8.0)) { timeline in
                HStack(spacing: 5) {
                    ForEach(0..<3) { index in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Circle()
                            .fill(VaultTheme.violet.opacity(0.55 + 0.35 * sin(t * 4 + Double(index))))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 16)
                .glassEffect(.regular.tint(VaultTheme.violet.opacity(0.12)), in: .rect(cornerRadius: 20))
            }
            Spacer()
        }
    }
}

struct VaultChatComposer: View {
    @Binding var text: String
    let disabled: Bool
    let send: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask Vault AI...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .tint(VaultTheme.accent)
                .padding(.vertical, 12)
                .padding(.leading, 14)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: disabled ? "waveform" : "arrow.up")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(VaultTheme.accent, in: Circle())
            }
            .disabled(disabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(disabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .buttonStyle(.vaultPress)
        }
        .padding(6)
        .glassEffect(.regular.tint(.white.opacity(0.07)), in: .rect(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 0.8)
        )
    }
}

struct GaugeTile: View {
    let title: String
    let value: Double
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            LiquidGauge(value: value, tint: tint, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: symbol).font(.callout.weight(.bold)).foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.caption2.weight(.heavy)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(22, padding: 16)
    }
}

struct InsightScoreRow: View {
    let title: String
    let subtitle: String
    let score: Double
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            GlyphBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                    Spacer()
                    Text(score, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.bold)).foregroundStyle(tint)
                }
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                MeterBar(value: score, tint: tint, height: 5)
            }
        }
        .glassCard(20, padding: 14)
    }
}

// MARK: - Reports

struct ReportsView: View {
    @Query(sort: \Appliance.purchaseDate, order: .reverse) private var appliances: [Appliance]
    @State private var exportURL: URL?
    @State private var showShare = false

    private var totalValue: Double { appliances.reduce(0) { $0 + max($1.purchasePrice, $1.replacementBudgetTarget) } }
    private var docCoverage: Double {
        guard !appliances.isEmpty else { return 0 }
        return Double(appliances.filter { !$0.invoiceReference.isEmpty || !$0.warrantyDocumentReference.isEmpty }.count) / Double(appliances.count)
    }
    private var serialCoverage: Double {
        guard !appliances.isEmpty else { return 0 }
        return Double(appliances.filter { !$0.serialNumber.isEmpty }.count) / Double(appliances.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow("Estimated contents value", tint: VaultTheme.cyan)
                            Text(totalValue, format: .currency(code: vaultCurrencyCode).precision(.fractionLength(0)))
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
                            HStack(spacing: 10) {
                                StatChip(label: "Docs", value: docCoverage.formatted(.percent.precision(.fractionLength(0))), tint: VaultTheme.accent)
                                StatChip(label: "Serials", value: serialCoverage.formatted(.percent.precision(.fractionLength(0))), tint: VaultTheme.cyan)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(padding: 20)

                        VStack(alignment: .leading, spacing: 12) {
                            GlassSectionHeader(title: "Export dossier", caption: "PDF")
                            ExportButton(title: "Household appliance report",
                                         subtitle: "Full inventory with warranty & value.",
                                         symbol: "house.fill") {
                                generate(title: "Household Appliance Report", subtitle: "Complete inventory with warranty, serials, and replacement value.")
                            }
                            ExportButton(title: "Insurance claim binder",
                                         subtitle: "Total value, serials, proof of purchase.",
                                         symbol: "cross.case.fill") {
                                generate(title: "Insurance Claim Binder", subtitle: "Contents valuation with serials and purchase records.")
                            }
                            ExportButton(title: "Home sale handover pack",
                                         subtitle: "Buyer-friendly ownership & maintenance.",
                                         symbol: "key.fill") {
                                generate(title: "Home Sale Handover Pack", subtitle: "Appliance ownership and maintenance history for the new owner.")
                            }
                        }
                        .disabled(appliances.isEmpty)
                        .opacity(appliances.isEmpty ? 0.45 : 1)

                        VStack(alignment: .leading, spacing: 12) {
                            GlassSectionHeader(title: "Snapshot")
                            SnapshotRow(label: "Tracked appliances", value: "\(appliances.count)")
                            SnapshotRow(label: "Households", value: "\(Set(appliances.map(\.householdName)).count)")
                            SnapshotRow(label: "Active warranties", value: "\(appliances.filter { !$0.activeWarranties.isEmpty }.count)")
                        }
                    }
                    .padding(18)
                    .safeAreaPadding(.bottom, 94)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Reports")
            .sheet(isPresented: $showShare) {
                if let exportURL { ShareSheet(items: [exportURL]) }
            }
        }
    }

    private func generate(title: String, subtitle: String) {
        guard !appliances.isEmpty,
              let url = VaultPDF.dossier(title: title, subtitle: subtitle, appliances: appliances) else { return }
        exportURL = url
        showShare = true
    }
}

struct ExportButton: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GlyphBadge(symbol: symbol, tint: VaultTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "square.and.arrow.up").foregroundStyle(VaultTheme.accent)
            }
            .glassCard(20, padding: 14)
        }
        .buttonStyle(.plain)
    }
}

struct SnapshotRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(.white)
        }
        .glassCard(18, padding: 14)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Settings

/// Theme gallery — tap a card to recolor the whole vault with a smooth crossfade.
struct ThemePickerSection: View {
    @Bindable var theme: VaultThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader(title: "Appearance", caption: "theme")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(VaultThemeKind.allCases) { kind in
                        ThemeSwatchCard(kind: kind, isSelected: theme.kind == kind) {
                            withAnimation(.easeInOut(duration: 0.6)) { theme.kind = kind }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }
}

struct ThemeSwatchCard: View {
    let kind: VaultThemeKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let palette = kind.palette
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Live mini-preview of the theme's backdrop + accents.
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.bgBase)
                    MeshGradient(
                        width: 3, height: 3,
                        points: [
                            [0, 0], [0.5, 0], [1, 0],
                            [0, 0.5], [0.5, 0.5], [1, 0.5],
                            [0, 1], [0.5, 1], [1, 1]
                        ],
                        colors: palette.mesh
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(0.9)

                    HStack(spacing: 6) {
                        ForEach(Array([palette.accent, palette.cyan, palette.violet, palette.warn, palette.danger].enumerated()), id: \.offset) { _, color in
                            Circle().fill(color).frame(width: 13, height: 13)
                                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
                        }
                    }
                }
                .frame(width: 168, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? palette.accent : .white.opacity(0.10), lineWidth: isSelected ? 2 : 0.75)
                )

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(kind.blurb)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.body.weight(.bold))
                        .foregroundStyle(isSelected ? palette.accent : .white.opacity(0.3))
                        .symbolEffect(.bounce, value: isSelected)
                }
            }
            .frame(width: 168)
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? palette.accent.opacity(0.5) : .white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.vaultPress)
    }
}

struct SettingsSheet: View {
    let appliances: [Appliance]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var notifications = VaultNotifications.shared
    @State private var remindersOn = false
    @State private var theme = VaultThemeStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                    .id(theme.kind)
                    .transition(.opacity)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SheetHero(symbol: "gearshape.2.fill",
                                  title: "Vault controls",
                                  subtitle: "Tune reminders, theme the vault, and inspect your on-device household graph.",
                                  tint: VaultTheme.violet)

                        ThemePickerSection(theme: theme)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Eyebrow("Reminder mesh", tint: VaultTheme.accent)
                                    Text("Warranty & maintenance alerts")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Toggle("", isOn: $remindersOn)
                                    .labelsHidden()
                                    .tint(VaultTheme.accent)
                            }
                            .onChange(of: remindersOn) { _, on in
                                Task {
                                    if on {
                                        let granted = await notifications.requestAuthorization()
                                        if granted { await notifications.sync(appliances: appliances) }
                                        else { remindersOn = false }
                                    }
                                }
                            }

                            Text("Fires 14 days before warranty expiry and when routine maintenance is due. Everything stays on-device.")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.54))

                            if remindersOn {
                                Button {
                                    Task { await notifications.sync(appliances: appliances) }
                                } label: {
                                    ActionPill(title: "Reschedule all", symbol: "arrow.clockwise", tint: VaultTheme.accent, filled: true)
                                }
                                .buttonStyle(.vaultPress)
                            }
                        }
                        .glassCard(24, padding: 16, tint: remindersOn ? VaultTheme.accent : VaultTheme.violet)

                        VStack(alignment: .leading, spacing: 12) {
                            GlassSectionHeader(title: "Household graph")
                            SnapshotRow(label: "Appliances", value: "\(appliances.count)")
                            SnapshotRow(label: "Households", value: "\(Set(appliances.map(\.householdName)).count)")
                            SnapshotRow(label: "Active warranties", value: "\(appliances.filter { !$0.activeWarranties.isEmpty }.count)")

                            if appliances.isEmpty {
                                Button {
                                    DemoVault.seed(modelContext)
                                } label: {
                                    ActionPill(title: "Load demo vault", symbol: "wand.and.stars", tint: VaultTheme.cyan, filled: true)
                                }
                                .buttonStyle(.vaultPress)
                                Text("Populates a sample household so you can explore every screen instantly.")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.54))
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            GlassSectionHeader(title: "System")
                            SnapshotRow(label: "Design language", value: "Liquid Glass")
                            SnapshotRow(label: "Storage", value: "SwiftData")
                            SnapshotRow(label: "Processing", value: "On-device")
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(VaultTheme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await notifications.refreshStatus(); remindersOn = notifications.isAuthorized }
        }
        .animation(.easeInOut(duration: 0.6), value: theme.kind)
    }
}

// MARK: - Detail

struct ApplianceDetailView: View {
    @Bindable var appliance: Appliance
    @Environment(\.modelContext) private var modelContext

    @State private var showWarranty = false
    @State private var showService = false
    @State private var detailMode = DetailMode.signals

    private var warranties: [WarrantyRecord] { appliance.warranties.sorted { $0.endDate < $1.endDate } }
    private var services: [ServiceLog] { appliance.serviceLogs.sorted { $0.serviceDate > $1.serviceDate } }

    var body: some View {
        ZStack {
            VaultBackground()
          GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {
                    DetailHeader(appliance: appliance)
                    DetailModeSwitch(selection: $detailMode)

                    Group {
                        switch detailMode {
                        case .signals:
                            VStack(spacing: 16) {
                                HStack(spacing: 12) {
                                    GaugeTile(title: "Risk", value: appliance.riskScore, symbol: "waveform.path.ecg", tint: appliance.signalColor)
                                    GaugeTile(title: "Reliability", value: appliance.reliabilityScore, symbol: "checkmark.seal.fill", tint: VaultTheme.cyan)
                                }

                                HStack(spacing: 12) {
                                    DetailMetric(title: "Monthly reserve", value: appliance.monthlyReplacementSavingsTarget.formatted(.currency(code: vaultCurrencyCode)))
                                    DetailMetric(title: "Resale value", value: appliance.estimatedResaleValue.formatted(.currency(code: vaultCurrencyCode)))
                                }

                                DiagnosticCard(appliance: appliance)

                                VStack(alignment: .leading, spacing: 12) {
                                    GlassSectionHeader(title: "Lifecycle")
                                    TimelineRow(title: "Purchased", date: appliance.purchaseDate, symbol: "cart.fill", tint: VaultTheme.accent, active: true)
                                    TimelineRow(title: "Next maintenance", date: appliance.nextMaintenanceDate, symbol: "wrench.adjustable.fill", tint: VaultTheme.cyan, active: appliance.nextMaintenanceDate <= .now)
                                    if let warranty = appliance.nextWarrantyExpiration {
                                        TimelineRow(title: "Warranty expires", date: warranty, symbol: "shield.lefthalf.filled", tint: VaultTheme.warn, active: (appliance.daysUntilWarrantyExpires ?? 999) <= 90)
                                    }
                                    TimelineRow(title: "Expected replacement", date: appliance.expectedEndOfLifeDate, symbol: "calendar.badge.clock", tint: VaultTheme.danger, active: appliance.healthScore < 0.3)
                                }
                            }
                        case .identity:
                            EditSection(appliance: appliance)
                        case .records:
                            VStack(spacing: 16) {
                                HStack(spacing: 10) {
                                    Button { showWarranty = true } label: {
                                        ActionPill(title: "Warranty", symbol: "shield.badge.plus", tint: VaultTheme.cyan, filled: true)
                                    }
                                    .buttonStyle(.vaultPress)
                                    Button { showService = true } label: {
                                        ActionPill(title: "Service", symbol: "wrench.and.screwdriver.fill", tint: VaultTheme.warn, filled: true)
                                    }
                                    .buttonStyle(.vaultPress)
                                    Spacer()
                                }

                                DetailListSection(title: "Warranties", addTitle: "Add warranty", add: { showWarranty = true }) {
                                    if warranties.isEmpty {
                                        EmptyLine("No warranties added.")
                                    } else {
                                        ForEach(warranties) { warranty in
                                            WarrantyLine(warranty: warranty)
                                                .swipeOnDelete { modelContext.delete(warranty) }
                                        }
                                    }
                                }

                                DetailListSection(title: "Service history", addTitle: "Log service", add: { showService = true }) {
                                    if services.isEmpty {
                                        EmptyLine("No service history yet.")
                                    } else {
                                        ForEach(services) { log in
                                            ServiceLine(log: log)
                                                .swipeOnDelete { modelContext.delete(log) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
                .padding(.vertical, 18)
                .frame(width: max(0, geo.size.width - 32))
                .frame(maxWidth: .infinity)
                .safeAreaPadding(.bottom, 94)
            }
            .scrollIndicators(.hidden)
          }
        }
        .navigationTitle(appliance.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWarranty) { AddWarrantyView(appliance: appliance) }
        .sheet(isPresented: $showService) { AddServiceLogView(appliance: appliance) }
    }
}

struct DetailModeSwitch: View {
    @Binding var selection: DetailMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DetailMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    ActionPill(title: mode.title, symbol: mode.symbol, tint: VaultTheme.accent, filled: selection == mode)
                }
                .buttonStyle(.vaultPress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DiagnosticCard: View {
    let appliance: Appliance

    private var verdict: String {
        if appliance.shouldReviewRepairVsReplace {
            return "Repair spend has crossed the review threshold. Compare one more repair quote against replacement."
        }
        if appliance.riskScore > 0.55 {
            return "Risk is elevated. Prioritize warranty checks, maintenance, and reserve planning."
        }
        if appliance.activeWarranties.isEmpty {
            return "No active warranty is attached. Add proof of coverage or mark this as self-insured."
        }
        return "Signals are stable. Keep service history current to preserve resale and claim readiness."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GlyphBadge(symbol: "brain.head.profile", tint: appliance.signalColor)
            VStack(alignment: .leading, spacing: 7) {
                Eyebrow("Vault diagnosis", tint: appliance.signalColor)
                Text(verdict)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassCard(22, padding: 16, tint: appliance.signalColor)
    }
}

struct DetailHeader: View {
    let appliance: Appliance

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                GlyphBadge(symbol: appliance.category.symbol, tint: appliance.signalColor, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appliance.name).font(.title3.weight(.bold)).foregroundStyle(.white).lineLimit(2)
                    Text("\(appliance.displayBrand) · \(appliance.ageLabel)")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            HStack(spacing: 18) {
                LiquidGauge(value: appliance.healthScore, tint: appliance.signalColor, size: 96)
                VStack(alignment: .leading, spacing: 10) {
                    StatChip(label: "Stage", value: appliance.lifecycleStage, tint: appliance.signalColor)
                    StatChip(label: "Value", value: appliance.replacementBudgetTarget.formatted(.currency(code: vaultCurrencyCode).precision(.fractionLength(0))), tint: VaultTheme.cyan)
                    if let days = appliance.daysUntilWarrantyExpires {
                        StatChip(label: "Warranty", value: days > 0 ? "\(days)d" : "expired", tint: VaultTheme.warn)
                    }
                }
                Spacer()
            }
        }
        .glassCard(padding: 20)
    }
}

struct DetailMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.45))
            Text(value).font(.headline.weight(.bold)).foregroundStyle(.white).minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(20, padding: 16)
    }
}

struct TimelineRow: View {
    let title: String
    let date: Date
    let symbol: String
    let tint: Color
    let active: Bool

    var body: some View {
        HStack(spacing: 12) {
            GlyphBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            if active { Image(systemName: "bell.badge.fill").foregroundStyle(tint) }
        }
        .glassCard(20, padding: 14)
    }
}

struct EditSection: View {
    @Bindable var appliance: Appliance

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Identity")
                EditGroup {
                    EditRow(label: "Name") { TextField("Required", text: $appliance.name).vaultFieldStyle() }
                    EditDivider()
                    EditRow(label: "Brand") { TextField("—", text: $appliance.brand).vaultFieldStyle() }
                    EditDivider()
                    EditRow(label: "Model") { TextField("—", text: $appliance.modelNumber).vaultFieldStyle() }
                    EditDivider()
                    EditRow(label: "Serial") { TextField("—", text: $appliance.serialNumber).vaultFieldStyle() }
                    EditDivider()
                    EditRow(label: "Category") {
                        Picker("", selection: $appliance.categoryRawValue) {
                            ForEach(ApplianceCategory.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                        .labelsHidden().tint(VaultTheme.accent)
                    }
                    EditDivider()
                    EditRow(label: "Room") { TextField("—", text: $appliance.room).vaultFieldStyle() }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Purchase & lifespan")
                EditGroup {
                    EditRow(label: "Purchased") {
                        DatePicker("", selection: $appliance.purchaseDate, displayedComponents: .date)
                            .labelsHidden().tint(VaultTheme.accent)
                    }
                    EditDivider()
                    EditRow(label: "Price") { CurrencyField(title: "0", value: $appliance.purchasePrice).vaultFieldStyle() }
                    EditDivider()
                    EditRow(label: "Replace") { CurrencyField(title: "0", value: $appliance.estimatedReplacementCost).vaultFieldStyle() }
                    EditDivider()
                    Stepper("Lifespan: \(appliance.expectedLifespanYears) yrs",
                            value: $appliance.expectedLifespanYears, in: 1...30)
                        .font(.subheadline).foregroundStyle(.white).tint(VaultTheme.accent)
                        .padding(.vertical, 6)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Notes")
                TextField("Add notes…", text: $appliance.notes, axis: .vertical)
                    .lineLimit(3...8)
                    .vaultFieldStyle()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(20, padding: 14)
            }
        }
    }
}

/// Rounded glass container for a stack of edit rows.
struct EditGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 0.75))
    }
}

struct EditRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 88, alignment: .leading)
            content.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 11)
    }
}

struct EditDivider: View {
    var body: some View { Divider().overlay(.white.opacity(0.08)) }
}

extension View {
    func vaultFieldStyle() -> some View {
        self.font(.subheadline)
            .foregroundStyle(.white)
            .tint(VaultTheme.accent)
            .multilineTextAlignment(.trailing)
    }
}

struct DetailListSection<Content: View>: View {
    let title: String
    let addTitle: String
    let add: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GlassSectionHeader(title: title)
                Button(action: add) { Image(systemName: "plus.circle.fill").foregroundStyle(VaultTheme.accent) }
            }
            content
        }
    }
}

struct WarrantyLine: View {
    let warranty: WarrantyRecord
    var body: some View {
        HStack(spacing: 12) {
            GlyphBadge(symbol: "shield.fill", tint: warranty.daysRemaining <= 30 ? VaultTheme.warn : VaultTheme.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(warranty.type.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("\(warranty.providerName.isEmpty ? "Provider not set" : warranty.providerName) · \(warranty.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text(warranty.reminderLabel).font(.caption2.weight(.bold))
                .foregroundStyle(warranty.daysRemaining <= 30 ? VaultTheme.warn : .white.opacity(0.5))
        }
        .glassCard(20, padding: 14)
    }
}

struct ServiceLine: View {
    let log: ServiceLog
    var body: some View {
        HStack(spacing: 12) {
            GlyphBadge(symbol: log.isRepair ? "wrench.adjustable.fill" : "checkmark.circle.fill",
                       tint: log.isRepair ? VaultTheme.warn : VaultTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.summary.isEmpty ? (log.isRepair ? "Repair" : "Maintenance") : log.summary)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                Text(log.serviceDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text(log.cost, format: .currency(code: vaultCurrencyCode)).font(.caption.weight(.bold)).foregroundStyle(.white)
        }
        .glassCard(20, padding: 14)
    }
}

struct EmptyLine: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(20, padding: 14)
    }
}

extension View {
    /// Inline destructive swipe wrapper for non-List glass rows via context menu.
    func swipeOnDelete(_ action: @escaping () -> Void) -> some View {
        contextMenu {
            Button(role: .destructive, action: { withAnimation { action() } }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add appliance (with scanning)

struct AddApplianceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var brand = ""
    @State private var modelNumber = ""
    @State private var serialNumber = ""
    @State private var categoryRawValue = ApplianceCategory.kitchen.rawValue
    @State private var room = ""
    @State private var purchaseDate = Date.now
    @State private var purchasePrice = 0.0
    @State private var estimatedReplacementCost = 0.0
    @State private var expectedLifespanYears = ApplianceCategory.kitchen.defaultLifespanYears
    @State private var includeWarranty = true
    @State private var warrantyEndDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now

    @State private var showScanner = false
    @State private var scanning = false
    @State private var scanError: String?

    private var category: ApplianceCategory { ApplianceCategory(rawValue: categoryRawValue) ?? .other }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        IntakeHeroPanel(scanError: scanError, action: startScan)

                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Identity", tint: VaultTheme.accent)
                            EditGroup {
                                EditRow(label: "Name") { TextField("Required", text: $name).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Brand") { TextField("Optional", text: $brand).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Model") { TextField("Auto-filled", text: $modelNumber).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Serial") { TextField("Auto-filled", text: $serialNumber).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Room") { TextField("Kitchen, Laundry...", text: $room).vaultFieldStyle() }
                            }
                        }

                        AddCategoryPicker(selection: $categoryRawValue)
                            .onChange(of: categoryRawValue) { _, new in
                                expectedLifespanYears = (ApplianceCategory(rawValue: new) ?? .other).defaultLifespanYears
                            }

                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Purchase intelligence", tint: VaultTheme.cyan)
                            EditGroup {
                                EditRow(label: "Purchased") {
                                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(VaultTheme.accent)
                                }
                                EditDivider()
                                EditRow(label: "Price") { CurrencyField(title: "0", value: $purchasePrice).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Replace") { CurrencyField(title: "0", value: $estimatedReplacementCost).vaultFieldStyle() }
                                EditDivider()
                                Stepper("Lifespan: \(expectedLifespanYears) yrs",
                                        value: $expectedLifespanYears, in: 1...30)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .tint(VaultTheme.accent)
                                    .padding(.vertical, 10)
                            }
                        }

                        WarrantyCaptureCard(includeWarranty: $includeWarranty, warrantyEndDate: $warrantyEndDate)
                    }
                    .padding(18)
                    .safeAreaPadding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Add Appliance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!canSave) }
            }
            .fullScreenCover(isPresented: $showScanner) {
                Group {
                    if scanning {
                        VaultProcessingView()
                    } else {
                        DocumentScanner(
                            onProcessing: { scanning = true },
                            onResult: { result in
                                scanning = false
                                showScanner = false
                                switch result {
                                case .success(let invoice): apply(invoice)
                                case .failure: scanError = "Couldn't read that invoice. Try again or enter details manually."
                                }
                            },
                            onCancel: { showScanner = false }
                        )
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func startScan() {
        scanError = nil
        guard VNDocumentCameraViewController.isSupported else {
            scanError = "Document scanning needs a device with a camera."
            return
        }
        showScanner = true
    }

    private func apply(_ invoice: ExtractedInvoice) {
        if let v = invoice.name, name.isEmpty { name = v }
        if let v = invoice.brand { brand = v }
        if let v = invoice.modelNumber { modelNumber = v }
        if let v = invoice.serialNumber { serialNumber = v }
        if let v = invoice.price, v > 0 { purchasePrice = v; estimatedReplacementCost = v }
        if let v = invoice.purchaseDate { purchaseDate = v }
    }

    private func save() {
        let appliance = Appliance(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            modelNumber: modelNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            serialNumber: serialNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            room: room.trimmingCharacters(in: .whitespacesAndNewlines),
            purchaseDate: purchaseDate,
            purchasePrice: purchasePrice,
            estimatedReplacementCost: estimatedReplacementCost,
            expectedLifespanYears: expectedLifespanYears
        )
        if includeWarranty {
            appliance.warranties.append(
                WarrantyRecord(type: .manufacturer, providerName: brand.isEmpty ? "Manufacturer" : brand,
                               startDate: purchaseDate, endDate: warrantyEndDate)
            )
        }
        modelContext.insert(appliance)
        dismiss()
    }
}

struct IntakeHeroPanel: View {
    let scanError: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    VaultCore(health: 0.78, risk: 0.18, signals: [0.2, 0.35, 0.12], size: 78)
                    Image(systemName: "doc.viewfinder")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow("Live OCR intake", tint: VaultTheme.accent)
                    Text("Scan receipt into a vault record")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text(scanError ?? "Brand, model, serial, price, and date are extracted on-device.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(scanError == nil ? .white.opacity(0.56) : VaultTheme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(VaultTheme.accent)
            }
            .glassCard(26, padding: 16, tint: VaultTheme.accent)
        }
        .buttonStyle(.vaultPress)
    }
}

struct AddCategoryPicker: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Asset class", tint: VaultTheme.warn)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ApplianceCategory.allCases) { category in
                        Button {
                            selection = category.rawValue
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: category.symbol)
                                    .font(.title3.weight(.black))
                                Text(category.title)
                                    .font(.caption.weight(.heavy))
                            }
                            .foregroundStyle(selection == category.rawValue ? .black : .white.opacity(0.72))
                            .frame(width: 92, height: 82)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(selection == category.rawValue ? VaultTheme.warn : .white.opacity(0.075))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(VaultTheme.warn.opacity(selection == category.rawValue ? 0 : 0.22), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.vaultPress)
                    }
                }
            }
        }
    }
}

struct WarrantyCaptureCard: View {
    @Binding var includeWarranty: Bool
    @Binding var warrantyEndDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Warranty shield", tint: VaultTheme.cyan)
                    Text(includeWarranty ? "Coverage will be tracked" : "Self-insured asset")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Toggle("", isOn: $includeWarranty)
                    .labelsHidden()
                    .tint(VaultTheme.accent)
            }

            if includeWarranty {
                DatePicker("Expires", selection: $warrantyEndDate, displayedComponents: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .tint(VaultTheme.accent)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .glassCard(24, padding: 16, tint: includeWarranty ? VaultTheme.cyan : VaultTheme.violet)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: includeWarranty)
    }
}

struct AddWarrantyView: View {
    @Environment(\.dismiss) private var dismiss
    let appliance: Appliance

    @State private var type = WarrantyType.manufacturer.rawValue
    @State private var provider = ""
    @State private var policy = ""
    @State private var startDate = Date.now
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var claimPhone = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SheetHero(symbol: "shield.lefthalf.filled",
                                  title: "Add warranty layer",
                                  subtitle: "Attach claim details and expiration signals to this asset.",
                                  tint: VaultTheme.cyan)

                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Coverage", tint: VaultTheme.cyan)
                            EditGroup {
                                EditRow(label: "Type") {
                                    Picker("", selection: $type) {
                                        ForEach(WarrantyType.allCases) { Text($0.title).tag($0.rawValue) }
                                    }
                                    .labelsHidden()
                                    .tint(VaultTheme.accent)
                                }
                                EditDivider()
                                EditRow(label: "Provider") { TextField("Provider", text: $provider).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Policy") { TextField("Policy number", text: $policy).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Claim") {
                                    TextField("Phone", text: $claimPhone)
                                        .keyboardType(.phonePad)
                                        .vaultFieldStyle()
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Timeline", tint: VaultTheme.warn)
                            EditGroup {
                                EditRow(label: "Starts") {
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(VaultTheme.accent)
                                }
                                EditDivider()
                                EditRow(label: "Expires") {
                                    DatePicker("", selection: $endDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(VaultTheme.accent)
                                }
                            }
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Add Warranty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appliance.warranties.append(
                            WarrantyRecord(type: WarrantyType(rawValue: type) ?? .manufacturer,
                                           providerName: provider, policyNumber: policy,
                                           startDate: startDate, endDate: endDate, claimPhone: claimPhone)
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddServiceLogView: View {
    @Environment(\.dismiss) private var dismiss
    let appliance: Appliance

    @State private var serviceDate = Date.now
    @State private var summary = ""
    @State private var provider = ""
    @State private var cost = 0.0
    @State private var isRepair = true

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SheetHero(symbol: isRepair ? "wrench.adjustable.fill" : "checkmark.seal.fill",
                                  title: isRepair ? "Log repair signal" : "Log maintenance proof",
                                  subtitle: "Every service entry sharpens risk, resale, and replacement timing.",
                                  tint: isRepair ? VaultTheme.warn : VaultTheme.accent)

                        HStack(spacing: 10) {
                            Button {
                                isRepair = true
                            } label: {
                                ActionPill(title: "Repair", symbol: "wrench.adjustable.fill", tint: VaultTheme.warn, filled: isRepair)
                            }
                            .buttonStyle(.vaultPress)
                            Button {
                                isRepair = false
                            } label: {
                                ActionPill(title: "Maintenance", symbol: "checkmark.seal.fill", tint: VaultTheme.accent, filled: !isRepair)
                            }
                            .buttonStyle(.vaultPress)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Service record", tint: isRepair ? VaultTheme.warn : VaultTheme.accent)
                            EditGroup {
                                EditRow(label: "Date") {
                                    DatePicker("", selection: $serviceDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(VaultTheme.accent)
                                }
                                EditDivider()
                                EditRow(label: "Summary") { TextField("What happened?", text: $summary, axis: .vertical).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Provider") { TextField("Technician or company", text: $provider).vaultFieldStyle() }
                                EditDivider()
                                EditRow(label: "Cost") { CurrencyField(title: "0", value: $cost).vaultFieldStyle() }
                            }
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Log Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appliance.serviceLogs.append(
                            ServiceLog(serviceDate: serviceDate, summary: summary,
                                       providerName: provider, cost: cost, isRepair: isRepair)
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SheetHero: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            GlyphBadge(symbol: symbol, tint: tint, size: 54)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .glassCard(26, padding: 18, tint: tint)
    }
}

// MARK: - Shared small pieces

struct CurrencyField: View {
    let title: String
    @Binding var value: Double
    var body: some View {
        TextField(title, value: $value, format: .currency(code: vaultCurrencyCode))
            .keyboardType(.decimalPad)
    }
}

struct VaultEmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(VaultTheme.accent)
            Text(title).font(.title3.weight(.bold)).foregroundStyle(.white)
            Text(message)
                .font(.subheadline).foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            if let action {
                Button(action: action) {
                    Label("Add appliance", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 12).padding(.horizontal, 20)
                }
                .buttonStyle(.glassProminent)
                .tint(VaultTheme.accent)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassCard(padding: 28)
        .padding(.horizontal, 18)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}

@MainActor
private let previewContainer: ModelContainer = {
    let schema = Schema([Appliance.self, WarrantyRecord.self, ServiceLog.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])

    let fridge = Appliance(
        name: "French Door Refrigerator", brand: "LG", modelNumber: "LRFXS2503S",
        category: .kitchen, room: "Kitchen",
        purchaseDate: Calendar.current.date(byAdding: .year, value: -8, to: .now) ?? .now,
        purchasePrice: 1899, estimatedReplacementCost: 2299, invoiceReference: "Invoice #A-1029"
    )
    fridge.warranties.append(WarrantyRecord(type: .extended, providerName: "Retailer Care",
        endDate: Calendar.current.date(byAdding: .day, value: 44, to: .now) ?? .now))
    fridge.serviceLogs.append(ServiceLog(
        serviceDate: Calendar.current.date(byAdding: .month, value: -8, to: .now) ?? .now,
        summary: "Replaced ice maker assembly.", providerName: "LG Service", cost: 280))

    let washer = Appliance(
        name: "Front Load Washer", brand: "Samsung", modelNumber: "WF45B6300",
        category: .laundry, room: "Laundry",
        purchaseDate: Calendar.current.date(byAdding: .year, value: -9, to: .now) ?? .now,
        purchasePrice: 799, estimatedReplacementCost: 999)

    container.mainContext.insert(fridge)
    container.mainContext.insert(washer)
    return container
}()
