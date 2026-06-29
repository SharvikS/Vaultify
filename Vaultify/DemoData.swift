//
//  DemoData.swift
//  Vaultify
//
//  A curated sample household used for demos, the "Load demo vault" action,
//  and deterministic screenshot capture. Only seeds when the vault is empty.
//

import Foundation
import SwiftData

enum DemoVault {
    private static func date(monthsAgo: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -monthsAgo, to: .now) ?? .now
    }

    private static func date(monthsAhead: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: monthsAhead, to: .now) ?? .now
    }

    /// Seed a realistic spread of appliances if (and only if) the vault has none.
    @discardableResult
    static func seedIfEmpty(_ context: ModelContext) -> Bool {
        let existing = (try? context.fetchCount(FetchDescriptor<Appliance>())) ?? 0
        guard existing == 0 else { return false }
        seed(context)
        return true
    }

    static func seed(_ context: ModelContext) {
        let samples: [Appliance] = [
            {
                let a = Appliance(
                    name: "French Door Refrigerator",
                    brand: "Samsung",
                    modelNumber: "RF28R7551SR",
                    serialNumber: "0AJ74BFR900142",
                    category: .kitchen,
                    householdName: "Maple Street",
                    room: "Kitchen",
                    purchaseDate: date(monthsAgo: 18),
                    purchasePrice: 2199,
                    estimatedReplacementCost: 2499,
                    notes: "Ice maker serviced once under warranty."
                )
                a.warranties = [
                    WarrantyRecord(type: .manufacturer, providerName: "Samsung Care", policyNumber: "SC-558120",
                                   startDate: date(monthsAgo: 18), endDate: date(monthsAhead: 6), claimPhone: "1-800-726-7864"),
                    WarrantyRecord(type: .extended, providerName: "Best Buy Geek Squad", policyNumber: "GS-90211",
                                   startDate: date(monthsAgo: 18), endDate: date(monthsAhead: 30))
                ]
                a.serviceLogs = [
                    ServiceLog(serviceDate: date(monthsAgo: 5), summary: "Ice maker module replaced", providerName: "Samsung Care", cost: 0, isRepair: true)
                ]
                return a
            }(),
            {
                let a = Appliance(
                    name: "Front-Load Washer",
                    brand: "LG",
                    modelNumber: "WM4000HWA",
                    serialNumber: "812KW00521",
                    category: .laundry,
                    householdName: "Maple Street",
                    room: "Laundry",
                    purchaseDate: date(monthsAgo: 52),
                    purchasePrice: 1099,
                    estimatedReplacementCost: 1199,
                    notes: "Drain pump replaced twice — watch for recurring leaks."
                )
                a.warranties = [
                    WarrantyRecord(type: .manufacturer, providerName: "LG", policyNumber: "LG-44120",
                                   startDate: date(monthsAgo: 52), endDate: date(monthsAgo: 40))
                ]
                a.serviceLogs = [
                    ServiceLog(serviceDate: date(monthsAgo: 20), summary: "Drain pump replaced", providerName: "A&E Factory", cost: 240, isRepair: true),
                    ServiceLog(serviceDate: date(monthsAgo: 4), summary: "Door gasket + pump reseal", providerName: "A&E Factory", cost: 310, isRepair: true)
                ]
                return a
            }(),
            {
                let a = Appliance(
                    name: "Central HVAC Condenser",
                    brand: "Carrier",
                    modelNumber: "24ACC636A003",
                    serialNumber: "4521E29874",
                    category: .hvac,
                    householdName: "Maple Street",
                    room: "Exterior",
                    purchaseDate: date(monthsAgo: 30),
                    purchasePrice: 5400,
                    estimatedReplacementCost: 6200,
                    notes: "Annual coil cleaning keeps efficiency up."
                )
                a.warranties = [
                    WarrantyRecord(type: .manufacturer, providerName: "Carrier", policyNumber: "CR-77140",
                                   startDate: date(monthsAgo: 30), endDate: date(monthsAhead: 90))
                ]
                a.serviceLogs = [
                    ServiceLog(serviceDate: date(monthsAgo: 6), summary: "Seasonal tune-up & coil clean", providerName: "Comfort Pros", cost: 180, isRepair: false)
                ]
                return a
            }(),
            {
                let a = Appliance(
                    name: "OLED Television",
                    brand: "Sony",
                    modelNumber: "XR-65A80L",
                    serialNumber: "SN-A80L-7741",
                    category: .electronics,
                    householdName: "Maple Street",
                    room: "Living room",
                    purchaseDate: date(monthsAgo: 8),
                    purchasePrice: 2399,
                    estimatedReplacementCost: 2199
                )
                a.warranties = [
                    WarrantyRecord(type: .creditCard, providerName: "Amex Extended", policyNumber: "AX-31188",
                                   startDate: date(monthsAgo: 8), endDate: date(monthsAhead: 16))
                ]
                return a
            }(),
            {
                let a = Appliance(
                    name: "Tankless Water Heater",
                    brand: "Rinnai",
                    modelNumber: "RU199iN",
                    serialNumber: "RNI-09921",
                    category: .plumbing,
                    householdName: "Maple Street",
                    room: "Utility",
                    purchaseDate: date(monthsAgo: 14),
                    purchasePrice: 1650,
                    estimatedReplacementCost: 1850,
                    notes: "Descale yearly in hard-water region."
                )
                a.warranties = [
                    WarrantyRecord(type: .manufacturer, providerName: "Rinnai", policyNumber: "RN-66201",
                                   startDate: date(monthsAgo: 14), endDate: date(monthsAhead: 110))
                ]
                return a
            }(),
            {
                let a = Appliance(
                    name: "Robot Vacuum",
                    brand: "iRobot",
                    modelNumber: "Roomba j7+",
                    serialNumber: "RM-J7-55410",
                    category: .cleaning,
                    householdName: "Maple Street",
                    room: "Hall closet",
                    purchaseDate: date(monthsAgo: 42),
                    purchasePrice: 799,
                    estimatedReplacementCost: 649,
                    notes: "Battery holding less charge — nearing replacement."
                )
                a.serviceLogs = [
                    ServiceLog(serviceDate: date(monthsAgo: 3), summary: "Brush + filter kit", providerName: "Self", cost: 60, isRepair: false)
                ]
                return a
            }(),
            {
                let a = Appliance(
                    name: "Gas Range",
                    brand: "Bosch",
                    modelNumber: "HGI8056UC",
                    serialNumber: "BSH-80561",
                    category: .kitchen,
                    householdName: "Maple Street",
                    room: "Kitchen",
                    purchaseDate: date(monthsAgo: 3),
                    purchasePrice: 1499,
                    estimatedReplacementCost: 1599
                )
                a.warranties = [
                    WarrantyRecord(type: .manufacturer, providerName: "Bosch", policyNumber: "BO-11920",
                                   startDate: date(monthsAgo: 3), endDate: date(monthsAhead: 9)),
                    WarrantyRecord(type: .retailer, providerName: "AJ Madison", policyNumber: "AJM-3320",
                                   startDate: date(monthsAgo: 3), endDate: date(monthsAhead: 45))
                ]
                return a
            }()
        ]

        for appliance in samples {
            context.insert(appliance)
        }
        try? context.save()
    }
}
