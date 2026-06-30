//
//  Models.swift
//  Vaultify
//
//  Created by Sharvik Sutar on 27/06/26.
//

import Foundation
import SwiftData

enum ApplianceCategory: String, CaseIterable, Identifiable {
    case kitchen
    case laundry
    case hvac
    case electronics
    case plumbing
    case cleaning
    case outdoor
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kitchen: "Kitchen"
        case .laundry: "Laundry"
        case .hvac: "HVAC"
        case .electronics: "Electronics"
        case .plumbing: "Plumbing"
        case .cleaning: "Cleaning"
        case .outdoor: "Outdoor"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .kitchen: "refrigerator"
        case .laundry: "washer"
        case .hvac: "fan"
        case .electronics: "tv"
        case .plumbing: "water.waves"
        case .cleaning: "sparkles"
        case .outdoor: "leaf"
        case .other: "shippingbox"
        }
    }

    var defaultLifespanYears: Int {
        switch self {
        case .kitchen: 13
        case .laundry: 10
        case .hvac: 12
        case .electronics: 7
        case .plumbing: 9
        case .cleaning: 8
        case .outdoor: 9
        case .other: 10
        }
    }
}

enum WarrantyType: String, CaseIterable, Identifiable {
    case manufacturer
    case extended
    case creditCard
    case retailer
    case serviceContract

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manufacturer: "Manufacturer"
        case .extended: "Extended"
        case .creditCard: "Credit card"
        case .retailer: "Retailer"
        case .serviceContract: "Service contract"
        }
    }
}

enum ApplianceStatus {
    case protected
    case inspectSoon
    case warrantyExpired
    case aging
    case planReplacement

    var title: String {
        switch self {
        case .protected: "Protected"
        case .inspectSoon: "Inspect soon"
        case .warrantyExpired: "Warranty expired"
        case .aging: "Aging"
        case .planReplacement: "Plan replacement"
        }
    }

    var symbol: String {
        switch self {
        case .protected: "checkmark.shield"
        case .inspectSoon: "exclamationmark.shield"
        case .warrantyExpired: "shield.slash"
        case .aging: "clock.arrow.circlepath"
        case .planReplacement: "creditcard"
        }
    }

    var tintName: String {
        switch self {
        case .protected: "green"
        case .inspectSoon: "orange"
        case .warrantyExpired: "gray"
        case .aging: "yellow"
        case .planReplacement: "red"
        }
    }
}

@Model
final class Appliance {
    var name: String
    var brand: String
    var modelNumber: String
    var serialNumber: String
    var categoryRawValue: String
    var householdName: String
    var room: String
    var purchaseDate: Date
    var purchasePrice: Double
    var estimatedReplacementCost: Double
    var expectedLifespanYears: Int
    var invoiceReference: String
    var warrantyDocumentReference: String
    var serviceContactName: String
    var serviceContactPhone: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var warranties: [WarrantyRecord]

    @Relationship(deleteRule: .cascade)
    var serviceLogs: [ServiceLog]

    init(
        name: String,
        brand: String = "",
        modelNumber: String = "",
        serialNumber: String = "",
        category: ApplianceCategory = .kitchen,
        householdName: String = "Home",
        room: String = "",
        purchaseDate: Date = .now,
        purchasePrice: Double = 0,
        estimatedReplacementCost: Double = 0,
        expectedLifespanYears: Int? = nil,
        invoiceReference: String = "",
        warrantyDocumentReference: String = "",
        serviceContactName: String = "",
        serviceContactPhone: String = "",
        notes: String = "",
        warranties: [WarrantyRecord] = [],
        serviceLogs: [ServiceLog] = []
    ) {
        self.name = name
        self.brand = brand
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.categoryRawValue = category.rawValue
        self.householdName = householdName
        self.room = room
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.estimatedReplacementCost = estimatedReplacementCost
        self.expectedLifespanYears = expectedLifespanYears ?? category.defaultLifespanYears
        self.invoiceReference = invoiceReference
        self.warrantyDocumentReference = warrantyDocumentReference
        self.serviceContactName = serviceContactName
        self.serviceContactPhone = serviceContactPhone
        self.notes = notes
        self.createdAt = .now
        self.warranties = warranties
        self.serviceLogs = serviceLogs
    }
}

@Model
final class WarrantyRecord {
    var typeRawValue: String
    var providerName: String
    var policyNumber: String
    var startDate: Date
    var endDate: Date
    var claimPhone: String
    var notes: String

    init(
        type: WarrantyType = .manufacturer,
        providerName: String = "",
        policyNumber: String = "",
        startDate: Date = .now,
        endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now,
        claimPhone: String = "",
        notes: String = ""
    ) {
        self.typeRawValue = type.rawValue
        self.providerName = providerName
        self.policyNumber = policyNumber
        self.startDate = startDate
        self.endDate = endDate
        self.claimPhone = claimPhone
        self.notes = notes
    }
}

@Model
final class ServiceLog {
    var serviceDate: Date
    var summary: String
    var providerName: String
    var cost: Double
    var isRepair: Bool

    init(
        serviceDate: Date = .now,
        summary: String = "",
        providerName: String = "",
        cost: Double = 0,
        isRepair: Bool = true
    ) {
        self.serviceDate = serviceDate
        self.summary = summary
        self.providerName = providerName
        self.cost = cost
        self.isRepair = isRepair
    }
}

extension Appliance {
    var category: ApplianceCategory {
        ApplianceCategory(rawValue: categoryRawValue) ?? .other
    }

    var displayBrand: String {
        brand.isEmpty ? "Unknown brand" : brand
    }

    var replacementBudgetTarget: Double {
        max(estimatedReplacementCost, purchasePrice)
    }

    var ageInYears: Double {
        max(0, Date.now.timeIntervalSince(purchaseDate) / (365.25 * 24 * 60 * 60))
    }

    var ageLabel: String {
        let years = Int(ageInYears.rounded(.down))
        let months = max(0, Int((ageInYears - Double(years)) * 12))

        if years == 0 {
            return months == 1 ? "1 month old" : "\(months) months old"
        }

        return years == 1 ? "1 year old" : "\(years) years old"
    }

    var expectedEndOfLifeDate: Date {
        Calendar.current.date(byAdding: .year, value: expectedLifespanYears, to: purchaseDate) ?? purchaseDate
    }

    var yearsRemaining: Double {
        max(0, Double(expectedLifespanYears) - ageInYears)
    }

    var healthScore: Double {
        guard expectedLifespanYears > 0 else { return 0 }
        return max(0, min(1, 1 - (ageInYears / Double(expectedLifespanYears))))
    }

    var activeWarranties: [WarrantyRecord] {
        warranties.filter { $0.endDate >= .now }.sorted { $0.endDate < $1.endDate }
    }

    var nextWarrantyExpiration: Date? {
        activeWarranties.first?.endDate
    }

    var daysUntilWarrantyExpires: Int? {
        guard let nextWarrantyExpiration else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: nextWarrantyExpiration).day
    }

    var status: ApplianceStatus {
        if healthScore < 0.18 {
            return .planReplacement
        }

        if let daysUntilWarrantyExpires {
            if daysUntilWarrantyExpires <= 30 {
                return .inspectSoon
            }
            return .protected
        }

        if healthScore < 0.35 {
            return .aging
        }

        return .warrantyExpired
    }

    var totalRepairCost: Double {
        serviceLogs.filter(\.isRepair).reduce(0) { $0 + $1.cost }
    }

    var repairRatio: Double {
        guard replacementBudgetTarget > 0 else { return 0 }
        return totalRepairCost / replacementBudgetTarget
    }

    var shouldReviewRepairVsReplace: Bool {
        repairRatio >= 0.4
    }

    var riskScore: Double {
        let ageRisk = 1 - healthScore
        let repairRisk = min(1, repairRatio)
        let warrantyRisk = activeWarranties.isEmpty ? 0.18 : 0
        let claimWindowRisk = (daysUntilWarrantyExpires ?? 999) <= 90 ? 0.14 : 0
        return min(1, (ageRisk * 0.58) + (repairRisk * 0.28) + warrantyRisk + claimWindowRisk)
    }

    var reliabilityScore: Double {
        let brandSeed = Double(abs(brand.lowercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }) % 18)
        let base = 0.86 - (brandSeed / 100)
        return max(0.48, min(0.96, base - (repairRatio * 0.18)))
    }

    var sustainabilityScore: Double {
        let agePenalty = min(0.48, ageInYears / 40)
        let repairPenalty = min(0.18, repairRatio * 0.12)
        return max(0.28, min(0.98, 0.92 - agePenalty - repairPenalty))
    }

    var estimatedResaleValue: Double {
        replacementBudgetTarget * max(0.04, min(0.52, healthScore * reliabilityScore * 0.58))
    }

    var monthlyReplacementSavingsTarget: Double {
        let monthsRemaining = max(1, yearsRemaining * 12)
        return replacementBudgetTarget / monthsRemaining
    }

    var lifecycleStage: String {
        switch healthScore {
        case 0.76...1: "Prime"
        case 0.51..<0.76: "Watch"
        case 0.26..<0.51: "Aging"
        default: "Replace"
        }
    }

    var nextMaintenanceDate: Date {
        let latestServiceDate = serviceLogs.map(\.serviceDate).max() ?? purchaseDate
        return Calendar.current.date(byAdding: .month, value: category.maintenanceCadenceMonths, to: latestServiceDate) ?? latestServiceDate
    }
}

/// Immutable per-render appliance metrics. Aggregate screens build these once
/// and reuse them for filtering, sorting, totals, and row rendering.
struct ApplianceSnapshot: Identifiable {
    let appliance: Appliance
    let id: String

    let name: String
    let brand: String
    let modelNumber: String
    let serialNumber: String
    let householdName: String
    let category: ApplianceCategory
    let displayBrand: String
    let purchaseDate: Date
    let purchasePrice: Double
    let estimatedReplacementCost: Double
    let invoiceReference: String
    let warrantyDocumentReference: String

    let replacementBudgetTarget: Double
    let ageInYears: Double
    let ageLabel: String
    let expectedEndOfLifeDate: Date
    let yearsRemaining: Double
    let healthScore: Double
    let activeWarranties: [WarrantyRecord]
    let nextWarrantyExpiration: Date?
    let daysUntilWarrantyExpires: Int?
    let status: ApplianceStatus
    let totalRepairCost: Double
    let repairRatio: Double
    let shouldReviewRepairVsReplace: Bool
    let riskScore: Double
    let reliabilityScore: Double
    let sustainabilityScore: Double
    let estimatedResaleValue: Double
    let monthlyReplacementSavingsTarget: Double
    let lifecycleStage: String
    let nextMaintenanceDate: Date

    init(_ appliance: Appliance, now: Date = .now, calendar: Calendar = .current) {
        self.appliance = appliance
        self.id = String(describing: appliance.persistentModelID)

        name = appliance.name
        brand = appliance.brand
        modelNumber = appliance.modelNumber
        serialNumber = appliance.serialNumber
        householdName = appliance.householdName
        category = appliance.category
        displayBrand = appliance.displayBrand
        purchaseDate = appliance.purchaseDate
        purchasePrice = appliance.purchasePrice
        estimatedReplacementCost = appliance.estimatedReplacementCost
        invoiceReference = appliance.invoiceReference
        warrantyDocumentReference = appliance.warrantyDocumentReference

        replacementBudgetTarget = max(appliance.estimatedReplacementCost, appliance.purchasePrice)

        let age = max(0, now.timeIntervalSince(appliance.purchaseDate) / (365.25 * 24 * 60 * 60))
        ageInYears = age
        let fullYears = Int(age.rounded(.down))
        let months = max(0, Int((age - Double(fullYears)) * 12))
        if fullYears == 0 {
            ageLabel = months == 1 ? "1 month old" : "\(months) months old"
        } else {
            ageLabel = fullYears == 1 ? "1 year old" : "\(fullYears) years old"
        }

        expectedEndOfLifeDate = calendar.date(
            byAdding: .year,
            value: appliance.expectedLifespanYears,
            to: appliance.purchaseDate
        ) ?? appliance.purchaseDate
        yearsRemaining = max(0, Double(appliance.expectedLifespanYears) - age)

        if appliance.expectedLifespanYears > 0 {
            healthScore = max(0, min(1, 1 - (age / Double(appliance.expectedLifespanYears))))
        } else {
            healthScore = 0
        }

        activeWarranties = appliance.warranties
            .filter { $0.endDate >= now }
            .sorted { $0.endDate < $1.endDate }
        nextWarrantyExpiration = activeWarranties.first?.endDate
        if let nextWarrantyExpiration {
            daysUntilWarrantyExpires = calendar.dateComponents([.day], from: now, to: nextWarrantyExpiration).day
        } else {
            daysUntilWarrantyExpires = nil
        }

        totalRepairCost = appliance.serviceLogs.reduce(0) { total, log in
            log.isRepair ? total + log.cost : total
        }
        repairRatio = replacementBudgetTarget > 0 ? totalRepairCost / replacementBudgetTarget : 0
        shouldReviewRepairVsReplace = repairRatio >= 0.4

        if healthScore < 0.18 {
            status = .planReplacement
        } else if let daysUntilWarrantyExpires {
            status = daysUntilWarrantyExpires <= 30 ? .inspectSoon : .protected
        } else if healthScore < 0.35 {
            status = .aging
        } else {
            status = .warrantyExpired
        }

        let ageRisk = 1 - healthScore
        let repairRisk = min(1, repairRatio)
        let warrantyRisk = activeWarranties.isEmpty ? 0.18 : 0
        let claimWindowRisk = (daysUntilWarrantyExpires ?? 999) <= 90 ? 0.14 : 0
        riskScore = min(1, (ageRisk * 0.58) + (repairRisk * 0.28) + warrantyRisk + claimWindowRisk)

        let brandSeed = Double(abs(appliance.brand.lowercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }) % 18)
        let reliabilityBase = 0.86 - (brandSeed / 100)
        reliabilityScore = max(0.48, min(0.96, reliabilityBase - (repairRatio * 0.18)))

        let agePenalty = min(0.48, age / 40)
        let repairPenalty = min(0.18, repairRatio * 0.12)
        sustainabilityScore = max(0.28, min(0.98, 0.92 - agePenalty - repairPenalty))

        estimatedResaleValue = replacementBudgetTarget * max(0.04, min(0.52, healthScore * reliabilityScore * 0.58))
        let monthsRemaining = max(1, yearsRemaining * 12)
        monthlyReplacementSavingsTarget = replacementBudgetTarget / monthsRemaining

        switch healthScore {
        case 0.76...1: lifecycleStage = "Prime"
        case 0.51..<0.76: lifecycleStage = "Watch"
        case 0.26..<0.51: lifecycleStage = "Aging"
        default: lifecycleStage = "Replace"
        }

        let latestServiceDate = appliance.serviceLogs.map(\.serviceDate).max() ?? appliance.purchaseDate
        nextMaintenanceDate = calendar.date(
            byAdding: .month,
            value: category.maintenanceCadenceMonths,
            to: latestServiceDate
        ) ?? latestServiceDate
    }
}

struct AppliancePortfolioSnapshot {
    let items: [ApplianceSnapshot]
    let totalValue: Double
    let averageHealth: Double
    let riskLoad: Double
    let reserve: Double
    let claimsDue: [ApplianceSnapshot]
    let serviceDue: [ApplianceSnapshot]
    let attention: [ApplianceSnapshot]
    let signals: [Double]

    init(appliances: [Appliance], now: Date = .now, calendar: Calendar = .current) {
        let snapshots = appliances.map { ApplianceSnapshot($0, now: now, calendar: calendar) }
        items = snapshots
        signals = snapshots.map(\.riskScore)
        totalValue = snapshots.reduce(0) { $0 + max($1.purchasePrice, $1.replacementBudgetTarget) }
        averageHealth = snapshots.isEmpty ? 0 : snapshots.reduce(0) { $0 + $1.healthScore } / Double(snapshots.count)
        riskLoad = snapshots.isEmpty ? 0 : snapshots.reduce(0) { $0 + $1.riskScore } / Double(snapshots.count)
        reserve = snapshots.reduce(0) { $0 + max(0, $1.replacementBudgetTarget * (1 - $1.healthScore)) }
        claimsDue = snapshots
            .filter { ($0.daysUntilWarrantyExpires ?? .max) <= 90 }
            .sorted { ($0.daysUntilWarrantyExpires ?? .max) < ($1.daysUntilWarrantyExpires ?? .max) }
        serviceDue = snapshots.filter { $0.nextMaintenanceDate <= now }
        attention = snapshots
            .filter { $0.riskScore > 0.45 || $0.shouldReviewRepairVsReplace }
            .sorted { $0.riskScore > $1.riskScore }
    }
}

extension ApplianceCategory {
    var maintenanceCadenceMonths: Int {
        switch self {
        case .kitchen: 6
        case .laundry: 4
        case .hvac: 3
        case .electronics: 12
        case .plumbing: 6
        case .cleaning: 3
        case .outdoor: 6
        case .other: 6
        }
    }
}

extension WarrantyRecord {
    var type: WarrantyType {
        WarrantyType(rawValue: typeRawValue) ?? .manufacturer
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: .now, to: endDate).day ?? 0
    }

    var reminderLabel: String {
        if daysRemaining < 0 {
            return "Expired"
        }

        if daysRemaining <= 7 {
            return "Final week"
        }

        if daysRemaining <= 30 {
            return "Inspect for claims"
        }

        if daysRemaining <= 90 {
            return "Warranty check"
        }

        return "Active"
    }
}
