//
//  ContentView.swift
//  Vaultify
//
//  Created by Sharvik Sutar on 27/06/26.
//

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
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.dark.rawValue

    var body: some View {
        TabView {
            DashboardView(appliances: appliances, appearanceMode: $appearanceMode)
                .tabItem {
                    Label("Vault", systemImage: "lock.shield")
                }

            ApplianceListView()
                .tabItem {
                    Label("Assets", systemImage: "square.stack.3d.up")
                }

            ForecastView(appliances: appliances)
                .tabItem {
                    Label("Horizon", systemImage: "point.3.connected.trianglepath.dotted")
                }

            IntelligenceView(appliances: appliances)
                .tabItem {
                    Label("Oracle", systemImage: "sparkles")
                }

            ReportsView(appliances: appliances)
                .tabItem {
                    Label("Dossier", systemImage: "doc.badge.gearshape")
                }

            SettingsView(appearanceMode: $appearanceMode, appliances: appliances)
                .tabItem {
                    Label("Control", systemImage: "slider.horizontal.3")
                }
        }
        .tint(.mint)
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
                            LiquidVaultHome(
                                appliances: appliances,
                                appearanceMode: $appearanceMode,
                                totalValue: totalValue,
                                replacementReserve: replacementReserve,
                                averageHealth: averageHealth,
                                riskLoad: riskLoad,
                                claimWindowAppliances: claimWindowAppliances,
                                criticalAppliances: criticalAppliances,
                                maintenanceDue: maintenanceDue
                            )
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
                    PremiumScanIntakeCard {
                        applyDemoExtraction()
                    }
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
                        ReplacementHorizonHero(appliances: appliances)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowBackground(Color.clear)
                    }

                    Section("Budget Planner") {
                        ReplacementHorizonVisual(appliances: appliances)
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
                    PremiumReportReadinessCard(appliances: appliances, totalInsuredValue: totalInsuredValue)
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
        ZStack {
            Color(red: 0.015, green: 0.018, blue: 0.024)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.035),
                    Color.mint.opacity(0.08),
                    Color.indigo.opacity(0.07),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TechnicalField()
                .stroke(.white.opacity(0.045), lineWidth: 1)
                .ignoresSafeArea()
        }
    }
}

struct LiquidVaultHome: View {
    let appliances: [Appliance]
    @Binding var appearanceMode: String
    let totalValue: Double
    let replacementReserve: Double
    let averageHealth: Double
    let riskLoad: Double
    let claimWindowAppliances: [Appliance]
    let criticalAppliances: [Appliance]
    let maintenanceDue: [Appliance]

    private var riskiest: Appliance? {
        appliances.max { $0.riskScore < $1.riskScore }
    }

    private var best: Appliance? {
        appliances.max { $0.healthScore < $1.healthScore }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VaultOperatingHeader(
                appliances: appliances,
                averageHealth: averageHealth,
                riskLoad: riskLoad,
                reserve: replacementReserve,
                appearanceMode: $appearanceMode
            )

            BiometricInvoicePlate(appliances: appliances)

            HStack(spacing: 12) {
                CommandShard(title: "Portfolio", value: totalValue.formatted(.currency(code: currencyCode)), symbol: "shield.lefthalf.filled", tint: .mint)
                CommandShard(title: "Claims", value: "\(claimWindowAppliances.count)", symbol: "bell.badge", tint: .orange)
            }

            AssetShelf(appliances: appliances)

            HStack(spacing: 12) {
                if let riskiest {
                    HeroApplianceCapsule(title: "Highest Signal", appliance: riskiest, tint: riskiest.riskScore > 0.58 ? .orange : .mint)
                }

                if let best {
                    HeroApplianceCapsule(title: "Cleanest Asset", appliance: best, tint: .cyan)
                }
            }

            SignalMatrix(
                criticalAppliances: criticalAppliances,
                claimWindowAppliances: claimWindowAppliances,
                maintenanceDue: maintenanceDue
            )

            PortfolioVaultVisual(appliances: appliances)
        }
    }
}

struct VaultOperatingHeader: View {
    let appliances: [Appliance]
    let averageHealth: Double
    let riskLoad: Double
    let reserve: Double
    @Binding var appearanceMode: String

    var body: some View {
        ZStack {
            LiquidChromeSurface()

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                        Text("VAULTIFY OS")
                    }
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.62))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Private Appliance Intelligence")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)
                        Text("\(appliances.count) assets sealed")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    HStack(spacing: 8) {
                        MonoPill("HEALTH \(averageHealth.formatted(.percent.precision(.fractionLength(0))))", tint: .mint)
                        MonoPill("RISK \(riskLoad.formatted(.percent.precision(.fractionLength(0))))", tint: .orange)
                    }
                }

                Spacer(minLength: 4)

                VStack(spacing: 12) {
                    SpatialSeal(value: averageHealth, risk: riskLoad)
                        .frame(width: 132, height: 132)

                    Button {
                        let current = AppAppearance(rawValue: appearanceMode) ?? .dark
                        appearanceMode = current == .dark ? AppAppearance.light.rawValue : AppAppearance.dark.rawValue
                    } label: {
                        Image(systemName: "moonphase.waxing.crescent")
                            .font(.headline.weight(.black))
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.10), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }
            .padding(20)
        }
        .frame(minHeight: 260)
    }

    private func MonoPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(tint)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 1))
    }
}

struct LiquidChromeSurface: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.03, blue: 0.04),
                            Color(red: 0.03, green: 0.10, blue: 0.10),
                            Color(red: 0.12, green: 0.06, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .clear, .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)

            TechnicalField()
                .stroke(.white.opacity(0.07), lineWidth: 1)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.32), radius: 28, x: 0, y: 20)
    }
}

struct TechnicalField: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 34

        stride(from: rect.minX - rect.height, through: rect.maxX, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
        }

        stride(from: rect.minY, through: rect.maxY, by: step).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y + 18))
        }

        return path
    }
}

struct SpatialSeal: View {
    let value: Double
    let risk: Double

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.08 + Double(index) * 0.035), lineWidth: 1)
                    .frame(width: 88 + CGFloat(index) * 22, height: 88 + CGFloat(index) * 22)
                    .rotationEffect(.degrees(Double(index) * 18))
            }

            Circle()
                .trim(from: 0.08, to: 0.08 + value * 0.78)
                .stroke(.mint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(130))

            Circle()
                .trim(from: 0.04, to: 0.04 + risk * 0.34)
                .stroke(.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-40))
                .padding(17)

            VStack(spacing: 2) {
                Image(systemName: "seal.fill")
                    .font(.title3.weight(.black))
                Text(value.formatted(.percent.precision(.fractionLength(0))))
                    .font(.title2.weight(.black))
            }
            .foregroundStyle(.white)
        }
    }
}

struct BiometricInvoicePlate: View {
    let appliances: [Appliance]

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(0.42))
                    .frame(width: 116, height: 142)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.mint.opacity(0.28), lineWidth: 1))

                ViewfinderGlyph()
                    .stroke(.mint.opacity(0.86), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: 78, height: 104)

                VStack(spacing: 7) {
                    Capsule().fill(.white.opacity(0.58)).frame(width: 45, height: 4)
                    Capsule().fill(.white.opacity(0.27)).frame(width: 62, height: 4)
                    Capsule().fill(.white.opacity(0.18)).frame(width: 34, height: 4)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("BILL SCAN")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.mint)
                    Spacer()
                    Text("LIVE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.black)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 7)
                        .background(.mint, in: Capsule())
                }

                Text("Drop an invoice. Vaultify builds the appliance passport.")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    SignalPip(title: "MODEL", value: 0.94)
                    SignalPip(title: "DATE", value: 0.91)
                    SignalPip(title: "WARRANTY", value: 0.88)
                }
            }
        }
        .padding()
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

struct ViewfinderGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = min(rect.width, rect.height) * 0.24

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        path.move(to: CGPoint(x: rect.minX + 8, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.midY))

        return path
    }
}

struct SignalPip: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.48))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule()
                        .fill(.mint)
                        .frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CommandShard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint)
                Spacer()
                Capsule()
                    .fill(tint.opacity(0.42))
                    .frame(width: 30, height: 5)
            }

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            Text(title.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white.opacity(0.46))
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint.opacity(0.20), lineWidth: 1))
    }
}

struct AssetShelf: View {
    let appliances: [Appliance]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ASSET SHELF")
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.48))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appliances.prefix(10)) { appliance in
                        FloatingAssetTile(appliance: appliance)
                    }
                }
            }
        }
    }
}

struct FloatingAssetTile: View {
    let appliance: Appliance

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tileTint.opacity(0.16))
                    Image(systemName: appliance.category.symbol)
                        .font(.title2.weight(.black))
                        .foregroundStyle(tileTint)
                }
                .frame(width: 56, height: 56)

                Spacer()

                Text(appliance.healthScore.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.70))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(appliance.name)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(appliance.lifecycleStage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tileTint)
            }

            RiskBlade(value: appliance.riskScore, tint: tileTint)
        }
        .padding()
        .frame(width: 174, height: 184)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var tileTint: Color {
        appliance.riskScore > 0.62 ? .orange : appliance.healthScore > 0.70 ? .mint : .cyan
    }
}

struct RiskBlade: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tint)
                    .frame(width: proxy.size.width * max(0.05, min(1, value)))
            }
        }
        .frame(height: 7)
    }
}

struct HeroApplianceCapsule: View {
    let title: String
    let appliance: Appliance
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.46))
            Text(appliance.name)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
            HStack {
                Image(systemName: appliance.category.symbol)
                Text(appliance.riskScore.formatted(.percent.precision(.fractionLength(0))))
                Spacer()
                Text(appliance.replacementBudgetTarget, format: .currency(code: currencyCode))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint.opacity(0.20), lineWidth: 1))
    }
}

struct SignalMatrix: View {
    let criticalAppliances: [Appliance]
    let claimWindowAppliances: [Appliance]
    let maintenanceDue: [Appliance]

    var body: some View {
        HStack(spacing: 8) {
            MatrixCell(title: "RISK", count: criticalAppliances.count, tint: .orange)
            MatrixCell(title: "CLAIM", count: claimWindowAppliances.count, tint: .mint)
            MatrixCell(title: "SERVICE", count: maintenanceDue.count, tint: .cyan)
        }
    }
}

struct MatrixCell: View {
    let title: String
    let count: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(tint)
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < min(count, 5) ? tint : .white.opacity(0.12))
                        .frame(width: 10, height: 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

struct CommandCenterHero: View {
    let applianceCount: Int
    let averageHealth: Double
    let riskLoad: Double
    let reserve: Double

    var body: some View {
        ZStack {
            PremiumMesh()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                        Text("VAULTIFY")
                    }
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.72))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Appliance Vault")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("\(applianceCount) protected assets")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))
                    }

                    HStack(spacing: 8) {
                        PremiumCapsuleMetric(title: "Risk", value: riskLoad.formatted(.percent.precision(.fractionLength(0))), symbol: "waveform.path.ecg")
                        PremiumCapsuleMetric(title: "Reserve", value: reserve.formatted(.currency(code: currencyCode)), symbol: "banknote")
                    }
                }

                Spacer(minLength: 6)

                VaultDial(value: averageHealth, risk: riskLoad)
                    .frame(width: 124, height: 124)
            }
            .padding(20)
        }
        .frame(minHeight: 210)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: .teal.opacity(0.24), radius: 24, x: 0, y: 14)
    }
}

struct PremiumMesh: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.09, blue: 0.11),
                    Color(red: 0.04, green: 0.27, blue: 0.28),
                    Color(red: 0.28, green: 0.12, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.teal.opacity(0.72), .clear],
                center: .topTrailing,
                startRadius: 6,
                endRadius: 230
            )

            RadialGradient(
                colors: [.orange.opacity(0.42), .clear],
                center: .bottomLeading,
                startRadius: 4,
                endRadius: 250
            )

            PremiumGrid()
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }
}

struct PremiumGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 28

        stride(from: rect.minX, through: rect.maxX, by: spacing).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x + 42, y: rect.maxY))
        }

        stride(from: rect.minY, through: rect.maxY, by: spacing).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y - 18))
        }

        return path
    }
}

struct PremiumCapsuleMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .opacity(0.68)
            }
        } icon: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.13), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
    }
}

struct VaultDial: View {
    let value: Double
    let risk: Double

    var body: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 3) ? Color.white.opacity(0.52) : Color.white.opacity(0.18))
                    .frame(width: 3, height: index.isMultiple(of: 3) ? 12 : 7)
                    .offset(y: -58)
                    .rotationEffect(.degrees(Double(index) * 10))
            }

            Circle()
                .stroke(.white.opacity(0.13), lineWidth: 14)

            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    AngularGradient(colors: [.cyan, .teal, .green, .yellow], center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0, to: risk)
                .stroke(
                    AngularGradient(colors: [.clear, .orange, .red], center: .center),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(140))
                .padding(20)

            VStack(spacing: 2) {
                Image(systemName: "shield.checkered")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white.opacity(0.88))
                Text(value.formatted(.percent.precision(.fractionLength(0))))
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
            }
        }
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

struct PortfolioVaultVisual: View {
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
            SectionHeader(title: "Asset Constellation", actionTitle: "live portfolio")

            VStack(spacing: 16) {
                ApplianceConstellation(appliances: appliances)
                    .frame(height: 230)

                VStack(spacing: 10) {
                    ForEach(categoryMetrics.prefix(5)) { metric in
                        CategoryValueTrack(metric: metric, maxValue: maxCategoryValue)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private var maxCategoryValue: Double {
        max(1, categoryMetrics.map(\.value).max() ?? 1)
    }
}

struct CategoryMetric: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
    let risk: Double
}

struct ApplianceConstellation: View {
    let appliances: [Appliance]

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) * 0.34

            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(.teal.opacity(0.10 + Double(index) * 0.04), lineWidth: 1)
                        .frame(width: radius * CGFloat(index + 2), height: radius * CGFloat(index + 2))
                }

                ForEach(Array(appliances.prefix(12).enumerated()), id: \.element.id) { index, appliance in
                    let angle = (Double(index) / Double(max(1, min(appliances.count, 12)))) * .pi * 2 - .pi / 2
                    let distance = radius * (0.58 + CGFloat(appliance.riskScore) * 0.75)
                    let point = CGPoint(
                        x: center.x + cos(angle) * distance,
                        y: center.y + sin(angle) * distance
                    )

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point)
                    }
                    .stroke(.white.opacity(0.08), lineWidth: 1)

                    AssetNode(appliance: appliance)
                        .position(point)
                }

                ZStack {
                    Circle()
                        .fill(.teal.opacity(0.18))
                        .frame(width: 86, height: 86)
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 68, height: 68)
                    Image(systemName: "lock.shield")
                        .font(.title.weight(.black))
                        .foregroundStyle(.teal)
                }
                .position(center)
            }
        }
    }
}

struct AssetNode: View {
    let appliance: Appliance

    var body: some View {
        ZStack {
            Circle()
                .fill(nodeTint.opacity(0.18))
                .frame(width: nodeSize + 16, height: nodeSize + 16)
            Circle()
                .fill(.regularMaterial)
                .frame(width: nodeSize, height: nodeSize)
                .overlay(Circle().stroke(nodeTint.opacity(0.76), lineWidth: 2))
            Image(systemName: appliance.category.symbol)
                .font(.caption.weight(.heavy))
                .foregroundStyle(nodeTint)
        }
        .shadow(color: nodeTint.opacity(0.25), radius: 9, x: 0, y: 5)
    }

    private var nodeTint: Color {
        appliance.riskScore > 0.65 ? .red : appliance.riskScore > 0.38 ? .orange : .teal
    }

    private var nodeSize: CGFloat {
        30 + CGFloat(min(1, appliance.replacementBudgetTarget / 4000)) * 18
    }
}

struct CategoryValueTrack: View {
    let metric: CategoryMetric
    let maxValue: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(metric.category)
                .font(.caption.weight(.semibold))
                .frame(width: 82, alignment: .leading)
                .lineLimit(1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.teal, metric.risk > 0.45 ? .orange : .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * max(0.06, metric.value / maxValue))
                    Circle()
                        .fill(metric.risk > 0.45 ? .orange : .teal)
                        .frame(width: 11, height: 11)
                        .offset(x: proxy.size.width * max(0.06, metric.value / maxValue) - 6)
                }
            }
            .frame(height: 12)

            Text(metric.value, format: .currency(code: currencyCode))
                .font(.caption2.weight(.bold))
                .frame(width: 72, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
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

struct PremiumScanIntakeCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Invoice Capture", systemImage: "viewfinder")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.teal)
                        Text("AI Intake")
                            .font(.system(.title2, design: .rounded, weight: .black))
                        Text("Brand, model, serial, price, warranty and purchase date.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.black.opacity(0.72))
                            .frame(width: 92, height: 118)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(.teal.opacity(0.88), style: StrokeStyle(lineWidth: 2, dash: [9, 5]))
                            .frame(width: 68, height: 88)
                        VStack(spacing: 6) {
                            Capsule().fill(.white.opacity(0.62)).frame(width: 42, height: 4)
                            Capsule().fill(.white.opacity(0.34)).frame(width: 54, height: 4)
                            Capsule().fill(.white.opacity(0.22)).frame(width: 34, height: 4)
                        }
                    }
                    .shadow(color: .teal.opacity(0.28), radius: 14, x: 0, y: 8)
                }

                HStack(spacing: 8) {
                    ExtractionChip(title: "Model", value: 0.94)
                    ExtractionChip(title: "Warranty", value: 0.88)
                    ExtractionChip(title: "Price", value: 0.97)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.teal.opacity(0.14), Color(.secondarySystemGroupedBackground), Color.purple.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.teal.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ExtractionChip: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.heavy))
            ProgressView(value: value)
                .tint(.teal)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [rowTint.opacity(0.26), Color(.secondarySystemGroupedBackground)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: appliance.category.symbol)
                        .font(.title3.weight(.black))
                        .foregroundStyle(rowTint)
                }
                .frame(width: 50, height: 50)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(rowTint.opacity(0.24), lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(appliance.name)
                        .font(.headline.weight(.bold))
                    Text("\(appliance.displayBrand) · \(appliance.modelNumber.isEmpty ? appliance.category.title : appliance.modelNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(appliance.lifecycleStage.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 7)
                        .background(rowTint, in: Capsule())
                    Text(appliance.replacementBudgetTarget, format: .currency(code: currencyCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                PremiumMiniMeter(title: "H", value: appliance.healthScore, tint: .green)
                PremiumMiniMeter(title: "R", value: appliance.riskScore, tint: rowTint)
                PremiumMiniMeter(title: "W", value: warrantyProgress, tint: .blue)
            }
        }
        .padding(.vertical, 10)
    }

    private var rowTint: Color {
        appliance.riskScore > 0.65 ? .red : appliance.riskScore > 0.38 ? .orange : .teal
    }

    private var warrantyProgress: Double {
        guard let days = appliance.daysUntilWarrantyExpires else { return 0 }
        return max(0, min(1, Double(days) / 365))
    }
}

struct PremiumMiniMeter: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 15)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.12))
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: proxy.size.width * max(0.04, min(1, value)))
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.thinMaterial, in: Capsule())
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

struct ReplacementHorizonHero: View {
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
        ZStack {
            PremiumMesh()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 16) {
                VaultDial(value: appliances.isEmpty ? 0 : 1 - Double(urgentCount) / Double(appliances.count), risk: appliances.isEmpty ? 0 : Double(urgentCount) / Double(appliances.count))
                    .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Replacement Horizon")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                    Text(fiveYearBudget, format: .currency(code: currencyCode))
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("\(urgentCount) near-term asset\(urgentCount == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                }
                Spacer()
            }
            .padding(18)
        }
        .frame(minHeight: 150)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

struct ReplacementHorizonVisual: View {
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
        GeometryReader { proxy in
            let maxAmount = max(1, points.map(\.amount).max() ?? 1)
            let columnWidth = proxy.size.width / CGFloat(max(points.count, 1))

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let normalized = point.amount / maxAmount
                    VStack(spacing: 8) {
                        Spacer()

                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(.white.opacity(0.08))
                                .frame(width: 28, height: 126)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: point.amount > 0 ? [.orange, .teal] : [.secondary.opacity(0.18), .secondary.opacity(0.10)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 28, height: 18 + (108 * normalized))
                                .shadow(color: point.amount > 0 ? .teal.opacity(0.28) : .clear, radius: 10)
                        }

                        Text(point.year)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: columnWidth)
                    .position(x: columnWidth * CGFloat(index) + columnWidth / 2, y: proxy.size.height / 2)
                    .overlay(alignment: .top) {
                        if point.amount > 0 {
                            Text(point.amount, format: .currency(code: currencyCode))
                                .font(.caption2.weight(.heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .offset(y: 8)
                        }
                    }
                }
            }
        }
    }
}

struct MonthlyBudgetPoint: Identifiable {
    let id = UUID()
    let year: String
    let amount: Double
}

struct PremiumReportReadinessCard: View {
    let appliances: [Appliance]
    let totalInsuredValue: Double

    private var documentCoverage: Double {
        guard !appliances.isEmpty else { return 0 }
        let covered = appliances.filter { !$0.invoiceReference.isEmpty || !$0.warrantyDocumentReference.isEmpty }.count
        return Double(covered) / Double(appliances.count)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemGroupedBackground),
                            Color.teal.opacity(0.10),
                            Color.purple.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Dossier Builder", systemImage: "doc.badge.gearshape")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.teal)

                    Text(totalInsuredValue, format: .currency(code: currencyCode))
                        .font(.system(.title, design: .rounded, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    HStack(spacing: 8) {
                        DossierStamp(title: "Docs", value: documentCoverage)
                        DossierStamp(title: "Serials", value: serialCoverage)
                        DossierStamp(title: "Warranty", value: warrantyCoverage)
                    }
                }

                Spacer()

                DocumentStackVisual(coverage: documentCoverage)
                    .frame(width: 96, height: 118)
            }
            .padding()
        }
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private var serialCoverage: Double {
        guard !appliances.isEmpty else { return 0 }
        return Double(appliances.filter { !$0.serialNumber.isEmpty }.count) / Double(appliances.count)
    }

    private var warrantyCoverage: Double {
        guard !appliances.isEmpty else { return 0 }
        return Double(appliances.filter { !$0.warranties.isEmpty }.count) / Double(appliances.count)
    }
}

struct DossierStamp: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(value.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.weight(.black))
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 58, height: 42)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DocumentStackVisual: View {
    let coverage: Double

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(index == 0 ? Color.teal.opacity(0.22) : Color.white.opacity(0.16))
                    .overlay(
                        VStack(alignment: .leading, spacing: 7) {
                            Capsule().fill(.white.opacity(0.45)).frame(width: 42, height: 4)
                            Capsule().fill(.white.opacity(0.22)).frame(width: 58, height: 4)
                            Capsule().fill(.white.opacity(0.22)).frame(width: 34, height: 4)
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.teal)
                                Spacer()
                            }
                        }
                        .padding(10)
                    )
                    .frame(width: 76, height: 98)
                    .rotationEffect(.degrees(Double(index - 1) * 5))
                    .offset(x: CGFloat(index - 1) * 9, y: CGFloat(index) * -3)
            }

            Text(coverage.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.weight(.black))
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(.black.opacity(0.32), in: Capsule())
                .foregroundStyle(.white)
                .offset(y: 45)
        }
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

struct PremiumMetricStrip: View {
    let applianceCount: Int
    let totalValue: Double
    let replacementReserve: Double
    let claimWindows: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                PremiumStatTile(title: "Assets", value: "\(applianceCount)", symbol: "house.and.flag", tint: .teal)
                PremiumStatTile(title: "Covered Value", value: totalValue.formatted(.currency(code: currencyCode)), symbol: "shield.lefthalf.filled", tint: .blue)
                PremiumStatTile(title: "Reserve", value: replacementReserve.formatted(.currency(code: currencyCode)), symbol: "banknote", tint: .green)
                PremiumStatTile(title: "Claims", value: "\(claimWindows)", symbol: "bell.badge", tint: .orange)
            }
        }
    }
}

struct PremiumStatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SymbolBadge(symbol: symbol, tint: tint)
                Spacer()
                Circle()
                    .fill(tint.opacity(0.22))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(tint.opacity(0.65), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text(title.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 154, height: 118, alignment: .leading)
        .padding()
        .background(
            LinearGradient(colors: [tint.opacity(0.16), Color(.secondarySystemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint.opacity(0.20), lineWidth: 1))
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
