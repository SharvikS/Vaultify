//
//  ContentView.swift
//  Vaultify
//
//  Created by Sharvik Sutar on 27/06/26.
//

import Charts
import SwiftData
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
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

enum ApplianceSortMode: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case risk
    case value
    case warranty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest"
        case .oldest: "Oldest"
        case .risk: "Highest Risk"
        case .value: "Highest Value"
        case .warranty: "Warranty Soon"
        }
    }

    var symbol: String {
        switch self {
        case .newest: "calendar.badge.plus"
        case .oldest: "calendar"
        case .risk: "exclamationmark.triangle"
        case .value: "dollarsign.circle"
        case .warranty: "shield.lefthalf.filled"
        }
    }
}

enum ApplianceFilterMode: String, CaseIterable, Identifiable {
    case all
    case protected
    case attention
    case replace
    case uninsured

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

private var currencyCode: String {
    Locale.current.currency?.identifier ?? "USD"
}

struct ContentView: View {
    @Query(sort: \Appliance.purchaseDate, order: .reverse) private var appliances: [Appliance]
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.system.rawValue

    var body: some View {
        TabView {
            DashboardView(appliances: appliances, appearanceMode: $appearanceMode)
                .tabItem {
                    Label("Today", systemImage: "gauge.with.dots.needle.50percent")
                }

            ApplianceListView()
                .tabItem {
                    Label("Appliances", systemImage: "house.and.flag")
                }

            ForecastView(appliances: appliances)
                .tabItem {
                    Label("Forecast", systemImage: "calendar.badge.clock")
                }

            IntelligenceView(appliances: appliances)
                .tabItem {
                    Label("Intel", systemImage: "sparkles")
                }

            ReportsView(appliances: appliances)
                .tabItem {
                    Label("Reports", systemImage: "doc.richtext")
                }

            SettingsView(appearanceMode: $appearanceMode, appliances: appliances)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.teal)
        .preferredColorScheme((AppAppearance(rawValue: appearanceMode) ?? .system).colorScheme)
    }
}

struct DashboardView: View {
    let appliances: [Appliance]
    @Binding var appearanceMode: String

    private var totalValue: Double {
        appliances.reduce(0) { $0 + $1.purchasePrice }
    }

    private var replacementReserve: Double {
        appliances.reduce(0) { $0 + max(0, $1.replacementBudgetTarget * (1 - $1.healthScore)) }
    }

    private var averageHealth: Double {
        guard !appliances.isEmpty else { return 0 }
        return appliances.reduce(0) { $0 + $1.healthScore } / Double(appliances.count)
    }

    private var riskLoad: Double {
        guard !appliances.isEmpty else { return 0 }
        return appliances.reduce(0) { $0 + $1.riskScore } / Double(appliances.count)
    }

    private var claimWindowAppliances: [Appliance] {
        appliances
            .filter { ($0.daysUntilWarrantyExpires ?? Int.max) <= 90 }
            .sorted { ($0.daysUntilWarrantyExpires ?? Int.max) < ($1.daysUntilWarrantyExpires ?? Int.max) }
    }

    private var criticalAppliances: [Appliance] {
        appliances
            .filter { $0.riskScore > 0.45 || $0.shouldReviewRepairVsReplace }
            .sorted { $0.riskScore > $1.riskScore }
    }

    private var maintenanceDue: [Appliance] {
        appliances
            .filter { appliance in
                guard let lastService = appliance.serviceLogs.map(\.serviceDate).max() else {
                    return appliance.ageInYears > 0.5
                }

                return Calendar.current.dateComponents([.month], from: lastService, to: .now).month ?? 0 >= 6
            }
            .sorted { $0.healthScore < $1.healthScore }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                    if appliances.isEmpty {
                        EmptyStateView(
                            title: "Build your appliance vault",
                            message: "Add the first appliance manually or use the invoice scan flow to prefill the essentials.",
                            symbol: "doc.viewfinder"
                        )
                    } else {
                        CommandCenterHero(
                            applianceCount: appliances.count,
                            averageHealth: averageHealth,
                            riskLoad: riskLoad,
                            reserve: replacementReserve
                        )

                        QuickActionDock(appearanceMode: $appearanceMode)

                        SummaryGrid(
                            applianceCount: appliances.count,
                            totalValue: totalValue,
                            replacementReserve: replacementReserve,
                            claimWindows: claimWindowAppliances.count
                        )

                        SectionHeader(title: "Risk Radar", actionTitle: "\(criticalAppliances.count) flagged")

                        if criticalAppliances.isEmpty {
                            QuietMessage("No appliance is crossing the risk threshold.")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(criticalAppliances.prefix(8)) { appliance in
                                        RiskRadarCard(appliance: appliance)
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }

                        DashboardCharts(appliances: appliances)

                        SectionHeader(title: "Warranty Claim Windows", actionTitle: "90 days")

                        if claimWindowAppliances.isEmpty {
                            QuietMessage("No warranty expirations in the next 90 days.")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(claimWindowAppliances.prefix(4)) { appliance in
                                    AlertRow(appliance: appliance)
                                }
                            }
                        }

                        SectionHeader(title: "Maintenance Due", actionTitle: "6 month rule")

                        if maintenanceDue.isEmpty {
                            QuietMessage("Nothing needs routine attention right now.")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(maintenanceDue.prefix(4)) { appliance in
                                    MaintenanceRow(appliance: appliance)
                                }
                            }
                        }

                        AIInsightCard(appliances: appliances)
                    }
                }
                .padding()
            }
            }
            .navigationTitle("Vaultify")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Appearance", selection: $appearanceMode) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Label(appearance.title, systemImage: appearance.symbol)
                                    .tag(appearance.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: (AppAppearance(rawValue: appearanceMode) ?? .system).symbol)
                    }
                }
            }
        }
    }
}

struct ApplianceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Appliance.purchaseDate, order: .reverse) private var appliances: [Appliance]

    @State private var showingAddAppliance = false
    @State private var searchText = ""
    @State private var selectedCategory: ApplianceCategory?
    @State private var filterMode = ApplianceFilterMode.all
    @State private var sortMode = ApplianceSortMode.risk

    private var filteredAppliances: [Appliance] {
        let searched = appliances.filter { appliance in
            searchText.isEmpty
                || appliance.name.localizedCaseInsensitiveContains(searchText)
                || appliance.brand.localizedCaseInsensitiveContains(searchText)
                || appliance.modelNumber.localizedCaseInsensitiveContains(searchText)
                || appliance.category.title.localizedCaseInsensitiveContains(searchText)
        }

        let categoryFiltered = searched.filter { appliance in
            selectedCategory == nil || appliance.category == selectedCategory
        }

        let modeFiltered = categoryFiltered.filter { appliance in
            switch filterMode {
            case .all:
                true
            case .protected:
                appliance.status == .protected
            case .attention:
                appliance.status == .inspectSoon || appliance.status == .aging || appliance.shouldReviewRepairVsReplace
            case .replace:
                appliance.status == .planReplacement
            case .uninsured:
                appliance.activeWarranties.isEmpty
            }
        }

        return modeFiltered.sorted { lhs, rhs in
            switch sortMode {
            case .newest:
                lhs.purchaseDate > rhs.purchaseDate
            case .oldest:
                lhs.purchaseDate < rhs.purchaseDate
            case .risk:
                lhs.riskScore > rhs.riskScore
            case .value:
                lhs.replacementBudgetTarget > rhs.replacementBudgetTarget
            case .warranty:
                (lhs.daysUntilWarrantyExpires ?? Int.max) < (rhs.daysUntilWarrantyExpires ?? Int.max)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    InventoryControlPanel(
                        selectedCategory: $selectedCategory,
                        filterMode: $filterMode,
                        sortMode: $sortMode,
                        visibleCount: filteredAppliances.count,
                        totalCount: appliances.count
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if filteredAppliances.isEmpty {
                    EmptyStateView(
                        title: "No appliances yet",
                        message: "Start with your biggest appliances: refrigerator, washer, AC, water heater, and television.",
                        symbol: "plus.viewfinder"
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredAppliances) { appliance in
                        NavigationLink {
                            ApplianceDetailView(appliance: appliance)
                        } label: {
                            AdvancedApplianceRow(appliance: appliance)
                        }
                    }
                    .onDelete(perform: deleteAppliances)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Appliances")
            .searchable(text: $searchText, prompt: "Name, brand, model, category")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAppliance = true
                    } label: {
                        Label("Add Appliance", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAppliance) {
                AddApplianceView()
            }
        }
    }

    private func deleteAppliances(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredAppliances[index])
            }
        }
    }
}

struct ApplianceDetailView: View {
    @Bindable var appliance: Appliance
    @Environment(\.modelContext) private var modelContext

    @State private var showingWarrantyForm = false
    @State private var showingServiceForm = false

    private var warrantyRows: [WarrantyRecord] {
        appliance.warranties.sorted { $0.endDate < $1.endDate }
    }

    private var serviceRows: [ServiceLog] {
        appliance.serviceLogs.sorted { $0.serviceDate > $1.serviceDate }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        SymbolBadge(symbol: appliance.category.symbol, tint: .teal)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(appliance.name)
                                .font(.title2.bold())
                            Text("\(appliance.displayBrand) \(appliance.modelNumber)")
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()
                    }

                    HStack(spacing: 12) {
                        MetricPill(title: "Health", value: appliance.healthScore.formatted(.percent.precision(.fractionLength(0))))
                        MetricPill(title: "Age", value: appliance.ageLabel)
                    }

                    ProgressView(value: appliance.healthScore)
                        .tint(appliance.healthScore < 0.25 ? .red : .green)
                }
                .padding(.vertical, 6)
            }

            Section("Command Metrics") {
                ApplianceIntelligencePanel(appliance: appliance)
            }

            Section("Lifecycle Timeline") {
                LifecycleTimeline(appliance: appliance)
            }

            Section("Identity") {
                TextField("Name", text: $appliance.name)
                TextField("Brand", text: $appliance.brand)
                TextField("Model number", text: $appliance.modelNumber)
                TextField("Serial number", text: $appliance.serialNumber)
                Picker("Category", selection: $appliance.categoryRawValue) {
                    ForEach(ApplianceCategory.allCases) { category in
                        Label(category.title, systemImage: category.symbol)
                            .tag(category.rawValue)
                    }
                }
                TextField("Room", text: $appliance.room)
                TextField("Household", text: $appliance.householdName)
            }

            Section("Purchase & Lifespan") {
                DatePicker("Purchased", selection: $appliance.purchaseDate, displayedComponents: .date)
                CurrencyField(title: "Purchase price", value: $appliance.purchasePrice)
                CurrencyField(title: "Replacement cost", value: $appliance.estimatedReplacementCost)
                Stepper("Expected lifespan: \(appliance.expectedLifespanYears) years", value: $appliance.expectedLifespanYears, in: 1...30)
                LabeledContent("Forecast date", value: appliance.expectedEndOfLifeDate.formatted(date: .abbreviated, time: .omitted))

                if appliance.shouldReviewRepairVsReplace {
                    Label("Repair costs are above 40% of replacement cost.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                TextField("Invoice reference", text: $appliance.invoiceReference)
                TextField("Warranty document", text: $appliance.warrantyDocumentReference)
            } header: {
                Text("Documents")
            } footer: {
                Text("References are placeholders for now. The next step is connecting this to file import, camera capture, OCR, and structured extraction.")
            }

            Section {
                TextField("Authorized service center", text: $appliance.serviceContactName)
                TextField("Phone", text: $appliance.serviceContactPhone)
                    .keyboardType(.phonePad)
            } header: {
                Text("Service Partner")
            }

            Section {
                if warrantyRows.isEmpty {
                    QuietMessage("No warranties added.")
                } else {
                    ForEach(warrantyRows) { warranty in
                        WarrantyRow(warranty: warranty)
                    }
                    .onDelete(perform: deleteWarranty)
                }

                Button {
                    showingWarrantyForm = true
                } label: {
                    Label("Add Warranty", systemImage: "shield")
                }
            } header: {
                Text("Warranties")
            }

            Section {
                if serviceRows.isEmpty {
                    QuietMessage("No service history yet.")
                } else {
                    ForEach(serviceRows) { serviceLog in
                        ServiceLogRow(serviceLog: serviceLog)
                    }
                    .onDelete(perform: deleteServiceLog)
                }

                Button {
                    showingServiceForm = true
                } label: {
                    Label("Log Service", systemImage: "wrench.adjustable")
                }
            } header: {
                Text("Service History")
            }

            Section("Notes") {
                TextEditor(text: $appliance.notes)
                    .frame(minHeight: 96)
            }
        }
        .navigationTitle(appliance.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingWarrantyForm) {
            AddWarrantyView(appliance: appliance)
        }
        .sheet(isPresented: $showingServiceForm) {
            AddServiceLogView(appliance: appliance)
        }
    }

    private func deleteWarranty(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(warrantyRows[index])
        }
    }

    private func deleteServiceLog(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(serviceRows[index])
        }
    }
}

struct AddApplianceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var brand = ""
    @State private var modelNumber = ""
    @State private var serialNumber = ""
    @State private var categoryRawValue = ApplianceCategory.kitchen.rawValue
    @State private var householdName = "Home"
    @State private var room = ""
    @State private var purchaseDate = Date.now
    @State private var purchasePrice = 0.0
    @State private var estimatedReplacementCost = 0.0
    @State private var expectedLifespanYears = ApplianceCategory.kitchen.defaultLifespanYears
    @State private var invoiceReference = ""
    @State private var warrantyDocumentReference = ""
    @State private var warrantyEndDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var includeWarranty = true

    private var category: ApplianceCategory {
        ApplianceCategory(rawValue: categoryRawValue) ?? .other
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        applyDemoExtraction()
                    } label: {
                        Label("Scan Bill or Invoice", systemImage: "doc.viewfinder")
                    }

                    Text("This prefill flow is wired as a placeholder. Camera capture, PDF import, OCR, and AI extraction can attach here without changing the rest of the model.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Appliance") {
                    TextField("Name", text: $name)
                    TextField("Brand", text: $brand)
                    TextField("Model number", text: $modelNumber)
                    TextField("Serial number", text: $serialNumber)
                    Picker("Category", selection: $categoryRawValue) {
                        ForEach(ApplianceCategory.allCases) { category in
                            Label(category.title, systemImage: category.symbol)
                                .tag(category.rawValue)
                        }
                    }
                    .onChange(of: categoryRawValue) { _, newValue in
                        expectedLifespanYears = (ApplianceCategory(rawValue: newValue) ?? .other).defaultLifespanYears
                    }
                    TextField("Room", text: $room)
                    TextField("Household", text: $householdName)
                }

                Section("Purchase") {
                    DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                    CurrencyField(title: "Purchase price", value: $purchasePrice)
                    CurrencyField(title: "Replacement cost", value: $estimatedReplacementCost)
                    Stepper("Expected lifespan: \(expectedLifespanYears) years", value: $expectedLifespanYears, in: 1...30)
                    TextField("Invoice reference", text: $invoiceReference)
                }

                Section("Warranty") {
                    Toggle("Track manufacturer warranty", isOn: $includeWarranty)

                    if includeWarranty {
                        DatePicker("Expires", selection: $warrantyEndDate, displayedComponents: .date)
                        TextField("Warranty document", text: $warrantyDocumentReference)
                    }
                }
            }
            .navigationTitle("Add Appliance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func applyDemoExtraction() {
        name = "French Door Refrigerator"
        brand = "LG"
        modelNumber = "LRFXS2503S"
        serialNumber = "LG-27A9-4421"
        categoryRawValue = ApplianceCategory.kitchen.rawValue
        room = "Kitchen"
        purchaseDate = Calendar.current.date(byAdding: .month, value: -14, to: .now) ?? .now
        purchasePrice = 1899
        estimatedReplacementCost = 2199
        expectedLifespanYears = ApplianceCategory.kitchen.defaultLifespanYears
        invoiceReference = "Invoice scanned from June 2025 purchase"
        warrantyDocumentReference = "Manufacturer warranty booklet"
        warrantyEndDate = Calendar.current.date(byAdding: .day, value: 76, to: .now) ?? .now
        includeWarranty = true
    }

    private func save() {
        let appliance = Appliance(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            modelNumber: modelNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            serialNumber: serialNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            householdName: householdName.trimmingCharacters(in: .whitespacesAndNewlines),
            room: room.trimmingCharacters(in: .whitespacesAndNewlines),
            purchaseDate: purchaseDate,
            purchasePrice: purchasePrice,
            estimatedReplacementCost: estimatedReplacementCost,
            expectedLifespanYears: expectedLifespanYears,
            invoiceReference: invoiceReference.trimmingCharacters(in: .whitespacesAndNewlines),
            warrantyDocumentReference: warrantyDocumentReference.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if includeWarranty {
            appliance.warranties.append(
                WarrantyRecord(
                    type: .manufacturer,
                    providerName: brand.isEmpty ? "Manufacturer" : brand,
                    startDate: purchaseDate,
                    endDate: warrantyEndDate
                )
            )
        }

        modelContext.insert(appliance)
        dismiss()
    }
}

struct AddWarrantyView: View {
    @Environment(\.dismiss) private var dismiss
    let appliance: Appliance

    @State private var warrantyType = WarrantyType.manufacturer.rawValue
    @State private var providerName = ""
    @State private var policyNumber = ""
    @State private var startDate = Date.now
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var claimPhone = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $warrantyType) {
                    ForEach(WarrantyType.allCases) { type in
                        Text(type.title).tag(type.rawValue)
                    }
                }
                TextField("Provider", text: $providerName)
                TextField("Policy number", text: $policyNumber)
                DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                DatePicker("Expires", selection: $endDate, displayedComponents: .date)
                TextField("Claim phone", text: $claimPhone)
                    .keyboardType(.phonePad)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Add Warranty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        appliance.warranties.append(
            WarrantyRecord(
                type: WarrantyType(rawValue: warrantyType) ?? .manufacturer,
                providerName: providerName,
                policyNumber: policyNumber,
                startDate: startDate,
                endDate: endDate,
                claimPhone: claimPhone,
                notes: notes
            )
        )
        dismiss()
    }
}

struct AddServiceLogView: View {
    @Environment(\.dismiss) private var dismiss
    let appliance: Appliance

    @State private var serviceDate = Date.now
    @State private var summary = ""
    @State private var providerName = ""
    @State private var cost = 0.0
    @State private var isRepair = true

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $serviceDate, displayedComponents: .date)
                TextField("Summary", text: $summary, axis: .vertical)
                TextField("Provider", text: $providerName)
                CurrencyField(title: "Cost", value: $cost)
                Toggle("Repair visit", isOn: $isRepair)
            }
            .navigationTitle("Log Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        appliance.serviceLogs.append(
            ServiceLog(
                serviceDate: serviceDate,
                summary: summary,
                providerName: providerName,
                cost: cost,
                isRepair: isRepair
            )
        )
        dismiss()
    }
}

struct ForecastView: View {
    let appliances: [Appliance]

    private func replacements(within years: Int) -> [Appliance] {
        let cutoff = Calendar.current.date(byAdding: .year, value: years, to: .now) ?? .now
        return appliances
            .filter { $0.expectedEndOfLifeDate <= cutoff }
            .sorted { $0.expectedEndOfLifeDate < $1.expectedEndOfLifeDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                List {
                    Section {
                        ForecastOverviewCard(appliances: appliances)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowBackground(Color.clear)
                    }

                    Section("Budget Planner") {
                        ReplacementBudgetChart(appliances: appliances)
                            .frame(height: 220)
                    }

                    ForecastSection(title: "Next 12 Months", appliances: replacements(within: 1))
                    ForecastSection(title: "Next 3 Years", appliances: replacements(within: 3))
                    ForecastSection(title: "Next 5 Years", appliances: replacements(within: 5))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Forecast")
        }
    }
}

struct ForecastSection: View {
    let title: String
    let appliances: [Appliance]

    private var totalCost: Double {
        appliances.reduce(0) { $0 + $1.replacementBudgetTarget }
    }

    var body: some View {
        Section {
            if appliances.isEmpty {
                QuietMessage("No expected replacements in this window.")
            } else {
                ForEach(appliances) { appliance in
                    HStack(spacing: 12) {
                        SymbolBadge(symbol: appliance.category.symbol, tint: appliance.healthScore < 0.25 ? .red : .orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(appliance.name)
                                .font(.headline)
                            Text("\(appliance.displayBrand) · \(appliance.expectedEndOfLifeDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(appliance.replacementBudgetTarget, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Text(totalCost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            }
        }
    }
}

struct ReportsView: View {
    let appliances: [Appliance]

    private var totalInsuredValue: Double {
        appliances.reduce(0) { $0 + max($1.purchasePrice, $1.replacementBudgetTarget) }
    }

    private var households: [String] {
        Array(Set(appliances.map(\.householdName))).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ReportReadinessCard(appliances: appliances, totalInsuredValue: totalInsuredValue)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section("Insurance Snapshot") {
                    LabeledContent("Tracked appliances", value: "\(appliances.count)")
                    LabeledContent("Estimated contents value") {
                        Text(totalInsuredValue, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    }
                    LabeledContent("Households", value: "\(households.count)")
                }

                Section("Export Modes") {
                    ExportModeRow(title: "Household appliance report", subtitle: "Warranty, invoices, models, service, and forecast.", symbol: "house")
                    ExportModeRow(title: "Home sale handover pack", subtitle: "Buyer-friendly maintenance and ownership packet.", symbol: "key")
                    ExportModeRow(title: "Rental property inventory", subtitle: "Property grouped records for landlords.", symbol: "building.2")
                    ExportModeRow(title: "Insurance claim binder", subtitle: "Total value, serials, proof of purchase, and photos.", symbol: "cross.case")
                }

                Section("Planned Pro Features") {
                    Label("PDF export", systemImage: "doc.richtext")
                    Label("iCloud backup", systemImage: "icloud")
                    Label("AI invoice extraction", systemImage: "sparkles")
                    Label("Multi-property tracking", systemImage: "map")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Reports")
        }
    }
}

struct IntelligenceView: View {
    let appliances: [Appliance]

    private var riskiest: Appliance? {
        appliances.max { $0.riskScore < $1.riskScore }
    }

    private var mostExpensive: Appliance? {
        appliances.max { $0.replacementBudgetTarget < $1.replacementBudgetTarget }
    }

    private var bestResaleCandidates: [Appliance] {
        appliances.sorted { $0.estimatedResaleValue > $1.estimatedResaleValue }
    }

    private var averageSustainability: Double {
        guard !appliances.isEmpty else { return 0 }
        return appliances.reduce(0) { $0 + $1.sustainabilityScore } / Double(appliances.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AssistantQuestionCard(
                            question: "Which appliance is most likely to break down this year?",
                            answer: riskiest.map { "\($0.name) is the highest-risk item. It is in the \($0.lifecycleStage.lowercased()) stage with \($0.riskScore.formatted(.percent.precision(.fractionLength(0)))) risk and \($0.totalRepairCost.formatted(.currency(code: currencyCode))) logged repairs." } ?? "Add appliances to unlock risk ranking."
                        )

                        if let mostExpensive {
                            AssistantQuestionCard(
                                question: "Where should I start saving first?",
                                answer: "Start with \(mostExpensive.name). Its replacement target is \(mostExpensive.replacementBudgetTarget.formatted(.currency(code: currencyCode))) and the monthly reserve target is \(mostExpensive.monthlyReplacementSavingsTarget.formatted(.currency(code: currencyCode)))."
                            )
                        }

                        HStack(spacing: 12) {
                            GaugeCard(title: "Sustainability", value: averageSustainability, symbol: "leaf", tint: .green)
                            GaugeCard(title: "Portfolio Risk", value: portfolioRisk, symbol: "waveform.path.ecg", tint: .orange)
                        }

                        SectionHeader(title: "Brand Reliability", actionTitle: "derived")
                        VStack(spacing: 10) {
                            ForEach(appliances.sorted { $0.reliabilityScore > $1.reliabilityScore }.prefix(6)) { appliance in
                                ScoreRow(
                                    title: "\(appliance.displayBrand) \(appliance.name)",
                                    subtitle: appliance.category.title,
                                    score: appliance.reliabilityScore,
                                    symbol: "checkmark.seal",
                                    tint: .teal
                                )
                            }
                        }

                        SectionHeader(title: "Resale Candidates", actionTitle: "upgrade value")
                        VStack(spacing: 10) {
                            ForEach(bestResaleCandidates.prefix(5)) { appliance in
                                ValueOpportunityRow(appliance: appliance)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Intelligence")
        }
    }

    private var portfolioRisk: Double {
        guard !appliances.isEmpty else { return 0 }
        return appliances.reduce(0) { $0 + $1.riskScore } / Double(appliances.count)
    }
}

struct SettingsView: View {
    @Binding var appearanceMode: String
    let appliances: [Appliance]

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Mode", selection: $appearanceMode) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Label(appearance.title, systemImage: appearance.symbol)
                                .tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Product Mode") {
                    Toggle("Claim-window alerts", isOn: .constant(true))
                    Toggle("Maintenance nudges", isOn: .constant(true))
                    Toggle("Annual health check", isOn: .constant(true))
                    Toggle("Replacement budget reminders", isOn: .constant(true))
                }

                Section("Household") {
                    LabeledContent("Appliances", value: "\(appliances.count)")
                    LabeledContent("Households", value: "\(Set(appliances.map(\.householdName)).count)")
                    LabeledContent("Cloud backup", value: "Ready for iCloud")
                    LabeledContent("Free tier usage", value: "\(min(appliances.count, 5))/5")
                }

                Section("Advanced Modules") {
                    SettingsModuleRow(title: "Vision invoice parser", subtitle: "Camera, PDF import, OCR, field confidence.", symbol: "doc.viewfinder")
                    SettingsModuleRow(title: "Warranty engine", subtitle: "Manufacturer, extended, credit-card coverage.", symbol: "shield")
                    SettingsModuleRow(title: "PDF report builder", subtitle: "Insurance, sale handover, rental exports.", symbol: "doc.richtext")
                    SettingsModuleRow(title: "Replacement marketplace", subtitle: "Amazon, Flipkart, and price watch hooks.", symbol: "cart")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
        }
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.teal.opacity(0.08),
                Color.indigo.opacity(0.07),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct CommandCenterHero: View {
    let applianceCount: Int
    let averageHealth: Double
    let riskLoad: Double
    let reserve: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home Systems Command")
                        .font(.largeTitle.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Text("\(applianceCount) assets monitored across warranty, lifecycle, service, budget, resale, and sustainability.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HealthOrbit(value: averageHealth, title: "Health")
                    .frame(width: 96, height: 96)
            }

            HStack(spacing: 10) {
                HeroMicroMetric(title: "Risk load", value: riskLoad.formatted(.percent.precision(.fractionLength(0))), symbol: "waveform.path.ecg", tint: .orange)
                HeroMicroMetric(title: "Reserve", value: reserve.formatted(.currency(code: currencyCode)), symbol: "banknote", tint: .green)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

struct HealthOrbit: View {
    let value: Double
    let title: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 10)
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    AngularGradient(colors: [.teal, .green, .yellow, .orange, .teal], center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(value.formatted(.percent.precision(.fractionLength(0))))
                    .font(.headline.bold())
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(title) \(value.formatted(.percent.precision(.fractionLength(0))))")
    }
}

struct HeroMicroMetric: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            SymbolBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct QuickActionDock: View {
    @Binding var appearanceMode: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                QuickActionButton(title: "Scan", symbol: "doc.viewfinder", tint: .teal)
                QuickActionButton(title: "Warranty", symbol: "shield", tint: .blue)
                QuickActionButton(title: "Service", symbol: "wrench.adjustable", tint: .orange)
                QuickActionButton(title: "Export", symbol: "square.and.arrow.up", tint: .purple)

                Button {
                    let current = AppAppearance(rawValue: appearanceMode) ?? .system
                    appearanceMode = current == .dark ? AppAppearance.light.rawValue : AppAppearance.dark.rawValue
                } label: {
                    Label("Theme", systemImage: "moon.stars")
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        Button {} label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(tint.opacity(0.13), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct DashboardCharts: View {
    let appliances: [Appliance]

    private var categoryMetrics: [CategoryMetric] {
        ApplianceCategory.allCases.compactMap { category in
            let matching = appliances.filter { $0.category == category }
            guard !matching.isEmpty else { return nil }
            let value = matching.reduce(0) { $0 + $1.replacementBudgetTarget }
            let risk = matching.reduce(0) { $0 + $1.riskScore } / Double(matching.count)
            return CategoryMetric(category: category.title, value: value, risk: risk)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Portfolio Mix", actionTitle: "replacement value")

            Chart(categoryMetrics) { metric in
                BarMark(
                    x: .value("Category", metric.category),
                    y: .value("Value", metric.value)
                )
                .foregroundStyle(by: .value("Category", metric.category))
                .cornerRadius(5)

                PointMark(
                    x: .value("Category", metric.category),
                    y: .value("Value", metric.value * max(0.08, metric.risk))
                )
                .foregroundStyle(.orange)
            }
            .chartLegend(.hidden)
            .frame(height: 190)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct CategoryMetric: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
    let risk: Double
}

struct RiskRadarCard: View {
    let appliance: Appliance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SymbolBadge(symbol: appliance.category.symbol, tint: appliance.riskScore > 0.65 ? .red : .orange)
                Spacer()
                Text(appliance.riskScore.formatted(.percent.precision(.fractionLength(0))))
                    .font(.headline.bold())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(appliance.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(appliance.lifecycleStage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: appliance.riskScore)
                .tint(appliance.riskScore > 0.65 ? .red : .orange)

            Text(appliance.monthlyReplacementSavingsTarget, format: .currency(code: currencyCode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 172, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct AIInsightCard: View {
    let appliances: [Appliance]

    private var insight: String {
        guard let appliance = appliances.max(by: { $0.riskScore < $1.riskScore }) else {
            return "Add appliances to unlock predictive insights."
        }

        if appliance.shouldReviewRepairVsReplace {
            return "\(appliance.name) has crossed the repair-vs-replace review line. Repair spend is \(appliance.repairRatio.formatted(.percent.precision(.fractionLength(0)))) of replacement cost."
        }

        if let days = appliance.daysUntilWarrantyExpires, days <= 90 {
            return "\(appliance.name) should be inspected before its warranty expires in \(days) days."
        }

        return "\(appliance.name) is your highest current risk. Start reserving \(appliance.monthlyReplacementSavingsTarget.formatted(.currency(code: currencyCode))) per month."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Home Analyst", systemImage: "sparkles")
                .font(.headline)
            Text(insight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct InventoryControlPanel: View {
    @Binding var selectedCategory: ApplianceCategory?
    @Binding var filterMode: ApplianceFilterMode
    @Binding var sortMode: ApplianceSortMode
    let visibleCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inventory Control")
                        .font(.headline)
                    Text("\(visibleCount) of \(totalCount) visible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Picker("Sort", selection: $sortMode) {
                        ForEach(ApplianceSortMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbol)
                                .tag(mode)
                        }
                    }
                } label: {
                    Label(sortMode.title, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.semibold))
                }
            }

            Picker("Filter", selection: $filterMode) {
                ForEach(ApplianceFilterMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(title: "All", symbol: "square.grid.2x2", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(ApplianceCategory.allCases) { category in
                        CategoryChip(title: category.title, symbol: category.symbol, isSelected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CategoryChip: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(isSelected ? Color.teal : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct AdvancedApplianceRow: View {
    let appliance: Appliance

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SymbolBadge(symbol: appliance.category.symbol, tint: rowTint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(appliance.name)
                        .font(.headline)
                    Text("\(appliance.displayBrand) · \(appliance.modelNumber.isEmpty ? appliance.category.title : appliance.modelNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(appliance.lifecycleStage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(rowTint)
                    Text(appliance.replacementBudgetTarget, format: .currency(code: currencyCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                MiniProgress(title: "Health", value: appliance.healthScore, tint: .green)
                MiniProgress(title: "Risk", value: appliance.riskScore, tint: rowTint)
                MiniProgress(title: "Warranty", value: warrantyProgress, tint: .blue)
            }
        }
        .padding(.vertical, 6)
    }

    private var rowTint: Color {
        appliance.riskScore > 0.65 ? .red : appliance.riskScore > 0.38 ? .orange : .teal
    }

    private var warrantyProgress: Double {
        guard let days = appliance.daysUntilWarrantyExpires else { return 0 }
        return max(0, min(1, Double(days) / 365))
    }
}

struct MiniProgress: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.percent.precision(.fractionLength(0))))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            ProgressView(value: value)
                .tint(tint)
        }
    }
}

struct ApplianceIntelligencePanel: View {
    let appliance: Appliance

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                GaugeCard(title: "Risk", value: appliance.riskScore, symbol: "waveform.path.ecg", tint: appliance.riskScore > 0.6 ? .red : .orange)
                GaugeCard(title: "Reliability", value: appliance.reliabilityScore, symbol: "checkmark.seal", tint: .teal)
            }

            HStack(spacing: 12) {
                MetricPill(title: "Monthly reserve", value: appliance.monthlyReplacementSavingsTarget.formatted(.currency(code: currencyCode)))
                MetricPill(title: "Resale value", value: appliance.estimatedResaleValue.formatted(.currency(code: currencyCode)))
            }

            ScoreRow(title: "Sustainability", subtitle: "Age and repair adjusted", score: appliance.sustainabilityScore, symbol: "leaf", tint: .green)
        }
    }
}

struct LifecycleTimeline: View {
    let appliance: Appliance

    var body: some View {
        VStack(spacing: 12) {
            TimelineStep(title: "Purchased", date: appliance.purchaseDate, symbol: "cart", tint: .teal, isActive: true)
            TimelineStep(title: "Next maintenance", date: appliance.nextMaintenanceDate, symbol: "wrench.adjustable", tint: .blue, isActive: appliance.nextMaintenanceDate <= .now)

            if let warrantyDate = appliance.nextWarrantyExpiration {
                TimelineStep(title: "Warranty expires", date: warrantyDate, symbol: "shield.lefthalf.filled", tint: .orange, isActive: (appliance.daysUntilWarrantyExpires ?? 999) <= 90)
            }

            TimelineStep(title: "Expected replacement", date: appliance.expectedEndOfLifeDate, symbol: "calendar.badge.clock", tint: .red, isActive: appliance.healthScore < 0.3)
        }
    }
}

struct TimelineStep: View {
    let title: String
    let date: Date
    let symbol: String
    let tint: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "bell.badge")
                    .foregroundStyle(tint)
            }
        }
    }
}

struct ForecastOverviewCard: View {
    let appliances: [Appliance]

    private var urgentCount: Int {
        appliances.filter { $0.expectedEndOfLifeDate <= Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now }.count
    }

    private var fiveYearBudget: Double {
        let cutoff = Calendar.current.date(byAdding: .year, value: 5, to: .now) ?? .now
        return appliances
            .filter { $0.expectedEndOfLifeDate <= cutoff }
            .reduce(0) { $0 + $1.replacementBudgetTarget }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Replacement Forecast", systemImage: "calendar.badge.clock")
                .font(.headline)
            HStack(spacing: 12) {
                GaugeCard(title: "Urgent", value: appliances.isEmpty ? 0 : Double(urgentCount) / Double(appliances.count), symbol: "exclamationmark.triangle", tint: .orange)
                VStack(alignment: .leading, spacing: 8) {
                    Text(fiveYearBudget, format: .currency(code: currencyCode))
                        .font(.title2.bold())
                    Text("Projected five-year replacement exposure")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ReplacementBudgetChart: View {
    let appliances: [Appliance]

    private var points: [MonthlyBudgetPoint] {
        (0..<6).map { offset in
            let year = Calendar.current.component(.year, from: .now) + offset
            let total = appliances
                .filter { Calendar.current.component(.year, from: $0.expectedEndOfLifeDate) == year }
                .reduce(0) { $0 + $1.replacementBudgetTarget }
            return MonthlyBudgetPoint(year: String(year), amount: total)
        }
    }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Year", point.year),
                y: .value("Budget", point.amount)
            )
            .foregroundStyle(.teal.gradient)
            .cornerRadius(5)

            LineMark(
                x: .value("Year", point.year),
                y: .value("Budget", point.amount)
            )
            .foregroundStyle(.orange)
            .symbol(.circle)
        }
    }
}

struct MonthlyBudgetPoint: Identifiable {
    let id = UUID()
    let year: String
    let amount: Double
}

struct ReportReadinessCard: View {
    let appliances: [Appliance]
    let totalInsuredValue: Double

    private var documentCoverage: Double {
        guard !appliances.isEmpty else { return 0 }
        let covered = appliances.filter { !$0.invoiceReference.isEmpty || !$0.warrantyDocumentReference.isEmpty }.count
        return Double(covered) / Double(appliances.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Readiness")
                        .font(.title3.bold())
                    Text("Insurance, handover, rental, and claim packs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HealthOrbit(value: documentCoverage, title: "Docs")
                    .frame(width: 78, height: 78)
            }

            HStack(spacing: 10) {
                HeroMicroMetric(title: "Contents", value: totalInsuredValue.formatted(.currency(code: currencyCode)), symbol: "shield", tint: .blue)
                HeroMicroMetric(title: "Serials", value: "\(appliances.filter { !$0.serialNumber.isEmpty }.count)", symbol: "barcode", tint: .purple)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ExportModeRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: symbol, tint: .teal)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AssistantQuestionCard: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                SymbolBadge(symbol: "sparkles", tint: .purple)
                VStack(alignment: .leading, spacing: 4) {
                    Text(question)
                        .font(.headline)
                    Text(answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct GaugeCard: View {
    let title: String
    let value: Double
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.bold())
            }

            Gauge(value: value) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ScoreRow: View {
    let title: String
    let subtitle: String
    let score: Double
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(score.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption.bold())
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: score)
                    .tint(tint)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ValueOpportunityRow: View {
    let appliance: Appliance

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: "tag", tint: .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(appliance.name)
                    .font(.headline)
                Text("Estimated resale \(appliance.estimatedResaleValue.formatted(.currency(code: currencyCode))) · \(appliance.sustainabilityScore.formatted(.percent.precision(.fractionLength(0)))) sustainability")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SettingsModuleRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: symbol, tint: .indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SummaryGrid: View {
    let applianceCount: Int
    let totalValue: Double
    let replacementReserve: Double
    let claimWindows: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryTile(title: "Appliances", value: "\(applianceCount)", symbol: "house.and.flag", tint: .teal)
            SummaryTile(title: "Insurance Value", value: totalValue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")), symbol: "shield", tint: .blue)
            SummaryTile(title: "Reserve Target", value: replacementReserve.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")), symbol: "creditcard", tint: .green)
            SummaryTile(title: "Claim Windows", value: "\(claimWindows)", symbol: "bell.badge", tint: .orange)
        }
    }
}

struct SummaryTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SymbolBadge(symbol: symbol, tint: tint)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ApplianceRow: View {
    let appliance: Appliance

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: appliance.category.symbol, tint: appliance.healthScore < 0.25 ? .red : .teal)

            VStack(alignment: .leading, spacing: 4) {
                Text(appliance.name)
                    .font(.headline)
                Text("\(appliance.displayBrand) · \(appliance.ageLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Label(appliance.status.title, systemImage: appliance.status.symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(appliance.status == .planReplacement ? .red : .secondary)
                Text(appliance.category.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AlertRow: View {
    let appliance: Appliance

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: appliance.status.symbol, tint: .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(appliance.name)
                    .font(.headline)
                Text(warrantyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var warrantyText: String {
        guard let days = appliance.daysUntilWarrantyExpires else {
            return "No active warranty"
        }

        if days <= 0 {
            return "Warranty expires today"
        }

        return "Inspect before warranty expires in \(days) days"
    }
}

struct MaintenanceRow: View {
    let appliance: Appliance

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: "wrench.adjustable", tint: .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(appliance.name)
                    .font(.headline)
                Text("Routine check recommended for \(appliance.category.title.lowercased()) appliances.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct WarrantyRow: View {
    let warranty: WarrantyRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(warranty.type.title, systemImage: "shield")
                    .font(.headline)
                Spacer()
                Text(warranty.reminderLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(warranty.daysRemaining <= 30 ? .orange : .secondary)
            }
            Text("\(warranty.providerName.isEmpty ? "Provider not set" : warranty.providerName) · expires \(warranty.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ServiceLogRow: View {
    let serviceLog: ServiceLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(serviceLog.isRepair ? "Repair" : "Maintenance", systemImage: serviceLog.isRepair ? "wrench.adjustable" : "checkmark.circle")
                    .font(.headline)
                Spacer()
                Text(serviceLog.cost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline.weight(.semibold))
            }
            Text(serviceLog.summary.isEmpty ? "No summary" : serviceLog.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(serviceLog.serviceDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CurrencyField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        TextField(title, value: $value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            .keyboardType(.decimalPad)
    }
}

struct SectionHeader: View {
    let title: String
    let actionTitle: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(actionTitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct SymbolBadge: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct QuietMessage: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}

@MainActor
private let previewContainer: ModelContainer = {
    let schema = Schema([Appliance.self, WarrantyRecord.self, ServiceLog.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])

    let refrigerator = Appliance(
        name: "French Door Refrigerator",
        brand: "LG",
        modelNumber: "LRFXS2503S",
        category: .kitchen,
        room: "Kitchen",
        purchaseDate: Calendar.current.date(byAdding: .year, value: -8, to: .now) ?? .now,
        purchasePrice: 1899,
        estimatedReplacementCost: 2299,
        invoiceReference: "Invoice #A-1029"
    )
    refrigerator.warranties.append(
        WarrantyRecord(
            type: .extended,
            providerName: "Retailer Care",
            endDate: Calendar.current.date(byAdding: .day, value: 44, to: .now) ?? .now
        )
    )
    refrigerator.serviceLogs.append(
        ServiceLog(
            serviceDate: Calendar.current.date(byAdding: .month, value: -8, to: .now) ?? .now,
            summary: "Replaced ice maker assembly.",
            providerName: "LG Authorized Service",
            cost: 280
        )
    )

    let washer = Appliance(
        name: "Front Load Washer",
        brand: "Samsung",
        modelNumber: "WF45B6300",
        category: .laundry,
        room: "Laundry",
        purchaseDate: Calendar.current.date(byAdding: .year, value: -9, to: .now) ?? .now,
        purchasePrice: 799,
        estimatedReplacementCost: 999
    )

    container.mainContext.insert(refrigerator)
    container.mainContext.insert(washer)
    return container
}()
