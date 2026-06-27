//
//  ContentView.swift
//  Vaultify
//
//  Created by Sharvik Sutar on 27/06/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \Appliance.purchaseDate, order: .reverse) private var appliances: [Appliance]

    var body: some View {
        TabView {
            DashboardView(appliances: appliances)
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

            ReportsView(appliances: appliances)
                .tabItem {
                    Label("Reports", systemImage: "doc.richtext")
                }
        }
    }
}

struct DashboardView: View {
    let appliances: [Appliance]

    private var totalValue: Double {
        appliances.reduce(0) { $0 + $1.purchasePrice }
    }

    private var replacementReserve: Double {
        appliances.reduce(0) { $0 + max(0, $1.replacementBudgetTarget * (1 - $1.healthScore)) }
    }

    private var claimWindowAppliances: [Appliance] {
        appliances
            .filter { ($0.daysUntilWarrantyExpires ?? Int.max) <= 90 }
            .sorted { ($0.daysUntilWarrantyExpires ?? Int.max) < ($1.daysUntilWarrantyExpires ?? Int.max) }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if appliances.isEmpty {
                        EmptyStateView(
                            title: "Build your appliance vault",
                            message: "Add the first appliance manually or use the invoice scan flow to prefill the essentials.",
                            symbol: "doc.viewfinder"
                        )
                    } else {
                        SummaryGrid(
                            applianceCount: appliances.count,
                            totalValue: totalValue,
                            replacementReserve: replacementReserve,
                            claimWindows: claimWindowAppliances.count
                        )

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
                    }
                }
                .padding()
            }
            .navigationTitle("Vaultify")
        }
    }
}

struct ApplianceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Appliance.purchaseDate, order: .reverse) private var appliances: [Appliance]

    @State private var showingAddAppliance = false
    @State private var searchText = ""

    private var filteredAppliances: [Appliance] {
        guard !searchText.isEmpty else { return appliances }

        return appliances.filter { appliance in
            appliance.name.localizedCaseInsensitiveContains(searchText)
                || appliance.brand.localizedCaseInsensitiveContains(searchText)
                || appliance.modelNumber.localizedCaseInsensitiveContains(searchText)
                || appliance.category.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
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
                            ApplianceRow(appliance: appliance)
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
            List {
                ForecastSection(title: "Next 12 Months", appliances: replacements(within: 1))
                ForecastSection(title: "Next 3 Years", appliances: replacements(within: 3))
                ForecastSection(title: "Next 5 Years", appliances: replacements(within: 5))
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
                Section("Insurance Snapshot") {
                    LabeledContent("Tracked appliances", value: "\(appliances.count)")
                    LabeledContent("Estimated contents value") {
                        Text(totalInsuredValue, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    }
                    LabeledContent("Households", value: "\(households.count)")
                }

                Section("Export Modes") {
                    Label("Household appliance report", systemImage: "house")
                    Label("Home sale handover pack", systemImage: "key")
                    Label("Rental property inventory", systemImage: "building.2")
                }

                Section("Planned Pro Features") {
                    Label("PDF export", systemImage: "doc.richtext")
                    Label("iCloud backup", systemImage: "icloud")
                    Label("AI invoice extraction", systemImage: "sparkles")
                    Label("Multi-property tracking", systemImage: "map")
                }
            }
            .navigationTitle("Reports")
        }
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
