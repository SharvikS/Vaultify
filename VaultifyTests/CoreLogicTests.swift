import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import Vaultify

@MainActor
final class CoreLogicTests: XCTestCase {
    func testCategoryMetadataAndFallbacksAreComplete() {
        for category in ApplianceCategory.allCases {
            XCTAssertFalse(category.title.isEmpty)
            XCTAssertFalse(category.symbol.isEmpty)
            XCTAssertGreaterThan(category.defaultLifespanYears, 0)
            XCTAssertGreaterThan(category.maintenanceCadenceMonths, 0)
        }

        let appliance = Appliance(name: "Mystery", category: .kitchen)
        appliance.categoryRawValue = "not-a-real-category"

        XCTAssertEqual(appliance.category, .other)
        XCTAssertEqual(appliance.displayBrand, "Unknown brand")
        XCTAssertEqual(appliance.replacementBudgetTarget, 0)
    }

    func testApplianceLifecycleStatusAndBudgetBoundaries() {
        let protected = Appliance(
            name: "Washer",
            brand: "LG",
            category: .laundry,
            purchaseDate: date(byAdding: .month, value: -6),
            purchasePrice: 900,
            estimatedReplacementCost: 1_100,
            warranties: [WarrantyRecord(endDate: date(byAdding: .day, value: 240))]
        )

        XCTAssertEqual(protected.status.title, ApplianceStatus.protected.title)
        XCTAssertEqual(protected.lifecycleStage, "Prime")
        XCTAssertEqual(protected.replacementBudgetTarget, 1_100)
        XCTAssertGreaterThan(protected.healthScore, 0.90)
        XCTAssertGreaterThan(protected.monthlyReplacementSavingsTarget, 0)
        XCTAssertLessThan(protected.monthlyReplacementSavingsTarget, protected.replacementBudgetTarget)

        let expiringSoon = Appliance(
            name: "Television",
            category: .electronics,
            purchaseDate: date(byAdding: .year, value: -1),
            purchasePrice: 1_500,
            warranties: [WarrantyRecord(endDate: date(byAdding: .day, value: 14))]
        )

        XCTAssertEqual(expiringSoon.status.title, ApplianceStatus.inspectSoon.title)
        XCTAssertNotNil(expiringSoon.daysUntilWarrantyExpires)
        XCTAssertGreaterThanOrEqual(expiringSoon.riskScore, 0.14)

        let old = Appliance(
            name: "Aged HVAC",
            category: .hvac,
            purchaseDate: date(byAdding: .year, value: -20),
            purchasePrice: 4_000,
            estimatedReplacementCost: 7_000,
            expectedLifespanYears: 12
        )

        XCTAssertEqual(old.status.title, ApplianceStatus.planReplacement.title)
        XCTAssertEqual(old.lifecycleStage, "Replace")
        XCTAssertEqual(old.healthScore, 0, accuracy: 0.0001)
        XCTAssertEqual(old.yearsRemaining, 0, accuracy: 0.0001)
        XCTAssertEqual(old.monthlyReplacementSavingsTarget, old.replacementBudgetTarget, accuracy: 0.0001)
    }

    func testWarrantyFilteringSortingAndReminderLabels() {
        let expired = WarrantyRecord(endDate: date(byAdding: .day, value: -2))
        let finalWeek = WarrantyRecord(endDate: date(byAdding: .day, value: 5))
        let inspect = WarrantyRecord(endDate: date(byAdding: .day, value: 25))
        let check = WarrantyRecord(endDate: date(byAdding: .day, value: 70))
        let active = WarrantyRecord(endDate: date(byAdding: .day, value: 180))

        XCTAssertEqual(expired.reminderLabel, "Expired")
        XCTAssertEqual(finalWeek.reminderLabel, "Final week")
        XCTAssertEqual(inspect.reminderLabel, "Inspect for claims")
        XCTAssertEqual(check.reminderLabel, "Warranty check")
        XCTAssertEqual(active.reminderLabel, "Active")

        let appliance = Appliance(
            name: "Refrigerator",
            warranties: [active, expired, check, inspect, finalWeek]
        )

        XCTAssertEqual(appliance.activeWarranties.count, 4)
        XCTAssertEqual(appliance.nextWarrantyExpiration, finalWeek.endDate)
        XCTAssertEqual(appliance.activeWarranties.map(\.endDate), [finalWeek.endDate, inspect.endDate, check.endDate, active.endDate])
    }

    func testRepairRiskAndMaintenanceScheduling() {
        let purchase = date(byAdding: .month, value: -11)
        let firstService = ServiceLog(serviceDate: date(byAdding: .month, value: -8), summary: "Filter", cost: 90, isRepair: false)
        let latestRepair = ServiceLog(serviceDate: date(byAdding: .month, value: -1), summary: "Motor", cost: 450, isRepair: true)
        let oldRepair = ServiceLog(serviceDate: date(byAdding: .month, value: -5), summary: "Pump", cost: 250, isRepair: true)
        let appliance = Appliance(
            name: "Dishwasher",
            category: .kitchen,
            purchaseDate: purchase,
            purchasePrice: 1_000,
            serviceLogs: [firstService, latestRepair, oldRepair]
        )

        XCTAssertEqual(appliance.totalRepairCost, 700, accuracy: 0.0001)
        XCTAssertEqual(appliance.repairRatio, 0.7, accuracy: 0.0001)
        XCTAssertTrue(appliance.shouldReviewRepairVsReplace)
        XCTAssertEqual(appliance.nextMaintenanceDate, date(from: latestRepair.serviceDate, byAdding: .month, value: 6))
    }

    func testApplianceSnapshotMatchesLiveModelMetrics() {
        let appliance = Appliance(
            name: "Snapshot Washer",
            brand: "LG",
            modelNumber: "WM9000",
            serialNumber: "SNAP123",
            category: .laundry,
            purchaseDate: date(byAdding: .year, value: -4),
            purchasePrice: 1_000,
            estimatedReplacementCost: 1_350,
            warranties: [WarrantyRecord(endDate: date(byAdding: .day, value: 45))],
            serviceLogs: [
                ServiceLog(serviceDate: date(byAdding: .month, value: -3), cost: 550, isRepair: true)
            ]
        )

        let snapshot = ApplianceSnapshot(appliance)

        XCTAssertEqual(snapshot.name, appliance.name)
        XCTAssertEqual(snapshot.category, appliance.category)
        XCTAssertEqual(snapshot.replacementBudgetTarget, appliance.replacementBudgetTarget, accuracy: 0.0001)
        XCTAssertEqual(snapshot.healthScore, appliance.healthScore, accuracy: 0.0001)
        XCTAssertEqual(snapshot.riskScore, appliance.riskScore, accuracy: 0.0001)
        XCTAssertEqual(snapshot.status.title, appliance.status.title)
        XCTAssertEqual(snapshot.lifecycleStage, appliance.lifecycleStage)
        XCTAssertEqual(snapshot.activeWarranties.count, appliance.activeWarranties.count)
        XCTAssertEqual(snapshot.nextMaintenanceDate, appliance.nextMaintenanceDate)
        XCTAssertTrue(snapshot.shouldReviewRepairVsReplace)
        XCTAssertFalse(snapshot.id.isEmpty)
    }

    func testPortfolioSnapshotAggregatesAndRanksCoreDashboardSignals() {
        let protected = Appliance(
            name: "Protected Fridge",
            brand: "Samsung",
            category: .kitchen,
            purchaseDate: date(byAdding: .month, value: -3),
            purchasePrice: 2_000,
            estimatedReplacementCost: 2_400,
            warranties: [WarrantyRecord(endDate: date(byAdding: .day, value: 25))]
        )
        let repairHeavy = Appliance(
            name: "Repair Heavy Washer",
            category: .laundry,
            purchaseDate: date(byAdding: .year, value: -7),
            purchasePrice: 1_000,
            serviceLogs: [ServiceLog(serviceDate: date(byAdding: .month, value: -1), cost: 600, isRepair: true)]
        )
        let serviceDue = Appliance(
            name: "Service Due HVAC",
            category: .hvac,
            purchaseDate: date(byAdding: .year, value: -2),
            purchasePrice: 5_000
        )

        let portfolio = AppliancePortfolioSnapshot(appliances: [protected, repairHeavy, serviceDue])

        XCTAssertEqual(portfolio.items.count, 3)
        XCTAssertEqual(portfolio.signals.count, 3)
        XCTAssertEqual(portfolio.totalValue, 8_400, accuracy: 0.0001)
        assertUnitInterval(portfolio.averageHealth, "average health")
        assertUnitInterval(portfolio.riskLoad, "risk load")
        XCTAssertGreaterThan(portfolio.reserve, 0)
        XCTAssertEqual(portfolio.claimsDue.map(\.name), ["Protected Fridge"])
        XCTAssertTrue(portfolio.serviceDue.contains { $0.name == "Service Due HVAC" })
        XCTAssertEqual(portfolio.attention.first?.name, "Repair Heavy Washer")
    }

    func testDemoSeedIsIdempotentAndChatBrainAnswersFromPortfolio() throws {
        let schema = Schema([Appliance.self, WarrantyRecord.self, ServiceLog.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        XCTAssertTrue(DemoVault.seedIfEmpty(context))
        XCTAssertFalse(DemoVault.seedIfEmpty(context))

        let appliances = try context.fetch(FetchDescriptor<Appliance>())
        XCTAssertEqual(appliances.count, 7)

        let opening = VaultChatBrain.opening(for: appliances)
        XCTAssertTrue(opening.contains("7 assets"))
        XCTAssertTrue(opening.contains("Highest live signal"))

        let riskAnswer = VaultChatBrain.answer("What needs attention?", appliances: appliances)
        XCTAssertTrue(riskAnswer.contains("Top risk signals"))
        XCTAssertTrue(riskAnswer.contains("risk"))

        let budgetAnswer = VaultChatBrain.answer("Where should I save first?", appliances: appliances)
        XCTAssertTrue(budgetAnswer.contains("Replacement target"))
    }

    func testValueBasedPDFDossierRendersFromSnapshotItems() throws {
        let appliance = Appliance(
            name: "Value Snapshot Range",
            brand: "Bosch",
            modelNumber: "HGI8056UC",
            serialNumber: "BOSCH-RANGE-1",
            category: .kitchen,
            purchaseDate: date(byAdding: .year, value: -1),
            purchasePrice: 1_499,
            estimatedReplacementCost: 1_699,
            warranties: [WarrantyRecord(providerName: "Bosch", endDate: date(byAdding: .year, value: 2))]
        )
        let item = VaultPDF.DossierItem(snapshot: ApplianceSnapshot(appliance))

        let url = try XCTUnwrap(VaultPDF.dossier(
            title: "Snapshot Dossier",
            subtitle: "Value-data renderer test.",
            items: [item],
            currencyCode: "USD"
        ))

        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = try XCTUnwrap(attributes[.size] as? NSNumber).intValue
        XCTAssertGreaterThan(size, 1_000)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(PDFDocument(url: url)).pageCount, 1)
    }

    func testScoresStayFiniteAndBoundedUnderRepeatedGeneratedPortfolios() {
        for run in 0..<25 {
            for index in 0..<40 {
                let category = ApplianceCategory.allCases[index % ApplianceCategory.allCases.count]
                let purchaseDate = date(byAdding: .month, value: -(index * 3 + run))
                let price = Double((index + 1) * 175)
                let repairCost = Double((index % 9) * 80)
                let appliance = Appliance(
                    name: "Asset \(run)-\(index)",
                    brand: ["LG", "Samsung", "Bosch", "", "Dyson"][index % 5],
                    category: category,
                    purchaseDate: purchaseDate,
                    purchasePrice: price,
                    estimatedReplacementCost: index % 3 == 0 ? price * 1.35 : 0,
                    expectedLifespanYears: max(1, category.defaultLifespanYears - (index % 4)),
                    warranties: index % 2 == 0 ? [WarrantyRecord(endDate: date(byAdding: .day, value: 45 + index))] : [],
                    serviceLogs: [
                        ServiceLog(serviceDate: date(byAdding: .month, value: -(index % 12)), cost: repairCost, isRepair: true)
                    ]
                )

                assertUnitInterval(appliance.healthScore, "health", file: #filePath, line: #line)
                assertUnitInterval(appliance.riskScore, "risk", file: #filePath, line: #line)
                assertUnitInterval(appliance.reliabilityScore, "reliability", file: #filePath, line: #line)
                assertUnitInterval(appliance.sustainabilityScore, "sustainability", file: #filePath, line: #line)
                XCTAssertTrue(appliance.estimatedResaleValue.isFinite)
                XCTAssertGreaterThanOrEqual(appliance.estimatedResaleValue, 0)
                XCTAssertTrue(appliance.monthlyReplacementSavingsTarget.isFinite)
                XCTAssertGreaterThanOrEqual(appliance.monthlyReplacementSavingsTarget, 0)
                XCTAssertFalse(appliance.lifecycleStage.isEmpty)
                XCTAssertGreaterThanOrEqual(appliance.expectedEndOfLifeDate, appliance.purchaseDate)
            }
        }
    }

    func testInvoiceParsingFindsConservativeHighConfidenceFields() throws {
        let lines = [
            "Receipt",
            "Samsung Home Appliances",
            "French Door Refrigerator",
            "Model: RF28T5001SR",
            "Serial: SN12345XYZ",
            "Subtotal $1,249.00",
            "Total $1,399.99",
            "Purchased June 12, 2026"
        ]

        let invoice = InvoiceOCR.parse(lines: lines)

        XCTAssertEqual(invoice.name, "Samsung Home Appliances")
        XCTAssertEqual(invoice.brand, "Samsung")
        XCTAssertEqual(invoice.modelNumber, "RF28T5001SR")
        XCTAssertEqual(invoice.serialNumber, "SN12345XYZ")
        XCTAssertEqual(try XCTUnwrap(invoice.price), 1_399.99, accuracy: 0.001)
        XCTAssertNotNil(invoice.purchaseDate)
        XCTAssertTrue(invoice.rawText.contains("French Door Refrigerator"))
    }

    func testInvoiceParsingIsRepeatedAndDoesNotOverreachOnWeakInput() throws {
        for iteration in 0..<150 {
            let invoice = InvoiceOCR.parse(lines: [
                "Invoice #\(iteration)",
                "Unknown Store",
                "Model:",
                "Total $1,200,000.00",
                "Paid $899.50"
            ])

            XCTAssertNil(invoice.brand)
            XCTAssertNil(invoice.modelNumber)
            XCTAssertEqual(try XCTUnwrap(invoice.price), 899.50, accuracy: 0.001)
            XCTAssertEqual(invoice.name, "Unknown Store")
        }
    }

    func testVisionOCRRecognizesCleanGeneratedSamsungReceipt() throws {
        let receipt = makeReceiptImage(lines: [
            "Receipt",
            "Samsung Home Appliances",
            "French Door Refrigerator",
            "Model: RF28T5001SR",
            "Serial: SN12345XYZ",
            "Subtotal $1,249.00",
            "Total $1,399.99",
            "Purchased June 12, 2026"
        ])

        let invoice = try recognize(images: [receipt])

        XCTAssertOCRContains(invoice.rawText, "Samsung")
        XCTAssertOCRContains(invoice.rawText, "RF28T5001SR")
        XCTAssertOCRContains(invoice.rawText, "SN12345XYZ")
        XCTAssertEqual(invoice.brand, "Samsung")
        XCTAssertEqual(invoice.modelNumber, "RF28T5001SR")
        XCTAssertEqual(invoice.serialNumber, "SN12345XYZ")
        XCTAssertEqual(try XCTUnwrap(invoice.price), 1_399.99, accuracy: 0.01)
        XCTAssertNotNil(invoice.purchaseDate)
    }

    func testVisionOCRRecognizesGeneratedBoschReceiptWithLargeSerialNumbers() throws {
        let receipt = makeReceiptImage(lines: [
            "Invoice",
            "Bosch Appliance Center",
            "Series 8 Dishwasher",
            "Serial: BOSCH99887766",
            "Model: SHX878ZD5N",
            "Item code 8736452190",
            "Amount $1,089.50",
            "Tax $87.16",
            "Total $1,176.66",
            "Date July 2, 2026"
        ])

        let invoice = try recognize(images: [receipt])

        XCTAssertOCRContains(invoice.rawText, "Bosch")
        XCTAssertEqual(invoice.brand, "Bosch")
        XCTAssertEqual(invoice.modelNumber, "SHX878ZD5N")
        XCTAssertEqual(invoice.serialNumber, "BOSCH99887766")
        XCTAssertEqual(try XCTUnwrap(invoice.price), 1_176.66, accuracy: 0.01)
        XCTAssertLessThan(try XCTUnwrap(invoice.price), 10_000)
    }

    func testVisionOCRRecognizesGeneratedMultiPageReceipt() throws {
        let pageOne = makeReceiptImage(lines: [
            "Receipt",
            "LG Signature Store",
            "Front Load Washer",
            "Model: WM8900HBA",
            "Serial: LGWASH1234"
        ])
        let pageTwo = makeReceiptImage(lines: [
            "Payment Summary",
            "Subtotal $1,699.00",
            "Delivery $99.00",
            "Total $1,798.00",
            "Purchased August 9, 2026"
        ])

        let invoice = try recognize(images: [pageOne, pageTwo])

        XCTAssertOCRContains(invoice.rawText, "LG")
        XCTAssertOCRContains(invoice.rawText, "Payment Summary")
        XCTAssertEqual(invoice.brand, "LG")
        XCTAssertEqual(invoice.modelNumber, "WM8900HBA")
        XCTAssertEqual(invoice.serialNumber, "LGWASH1234")
        XCTAssertEqual(try XCTUnwrap(invoice.price), 1_798.00, accuracy: 0.01)
        XCTAssertNotNil(invoice.purchaseDate)
    }

    func testSwiftDataInMemoryPersistenceAndCascadeDelete() throws {
        let schema = Schema([Appliance.self, WarrantyRecord.self, ServiceLog.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let appliance = Appliance(
            name: "Range",
            brand: "Bosch",
            purchasePrice: 1_800,
            warranties: [WarrantyRecord(providerName: "Bosch", endDate: date(byAdding: .year, value: 2))],
            serviceLogs: [ServiceLog(summary: "Install check", cost: 0, isRepair: false)]
        )

        context.insert(appliance)
        try context.save()

        let savedAppliances = try context.fetch(FetchDescriptor<Appliance>())
        XCTAssertEqual(savedAppliances.count, 1)
        XCTAssertEqual(savedAppliances[0].name, "Range")
        XCTAssertEqual(savedAppliances[0].activeWarranties.count, 1)
        XCTAssertEqual(savedAppliances[0].serviceLogs.count, 1)

        context.delete(savedAppliances[0])
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Appliance>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WarrantyRecord>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ServiceLog>()).count, 0)
    }

    func testPDFDossierCreatesReadableNonEmptyFile() throws {
        let appliance = Appliance(
            name: "Heat Pump",
            brand: "Daikin",
            modelNumber: "DX20VC",
            serialNumber: "HP123456",
            category: .hvac,
            purchaseDate: date(byAdding: .year, value: -2),
            purchasePrice: 6_500,
            estimatedReplacementCost: 8_000,
            warranties: [WarrantyRecord(providerName: "Daikin", endDate: date(byAdding: .year, value: 3))]
        )

        let url = try XCTUnwrap(VaultPDF.dossier(
            title: "Insurance Claim Binder",
            subtitle: "Contents valuation with serials and purchase records.",
            appliances: [appliance]
        ))

        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = try XCTUnwrap(attributes[.size] as? NSNumber).intValue
        XCTAssertGreaterThan(size, 1_000)

        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
    }

    private func assertUnitInterval(
        _ value: Double,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(value.isFinite, "\(name) should be finite", file: file, line: line)
        XCTAssertGreaterThanOrEqual(value, 0, "\(name) should be >= 0", file: file, line: line)
        XCTAssertLessThanOrEqual(value, 1, "\(name) should be <= 1", file: file, line: line)
    }

    private func recognize(images: [CGImage], timeout: TimeInterval = 12) throws -> ExtractedInvoice {
        let expectation = expectation(description: "Vision OCR completes")
        var captured: Result<ExtractedInvoice, Error>?

        InvoiceOCR.recognize(in: images) { result in
            captured = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
        return try XCTUnwrap(captured).get()
    }

    private func makeReceiptImage(lines: [String]) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1_240, height: 1_680), format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_240, height: 1_680))

            UIColor.black.setStroke()
            UIBezierPath(rect: CGRect(x: 64, y: 64, width: 1_112, height: 1_552)).stroke()

            var y: CGFloat = 130
            for (index, line) in lines.enumerated() {
                let font: UIFont
                if index == 0 {
                    font = .monospacedSystemFont(ofSize: 52, weight: .bold)
                } else if line.localizedCaseInsensitiveContains("total") {
                    font = .monospacedSystemFont(ofSize: 48, weight: .bold)
                } else {
                    font = .monospacedSystemFont(ofSize: 44, weight: .regular)
                }

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                line.draw(at: CGPoint(x: 112, y: y), withAttributes: attributes)
                y += 82
            }
        }

        return image.cgImage!
    }

    private func XCTAssertOCRContains(
        _ rawText: String,
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            rawText.localizedCaseInsensitiveContains(expected),
            "OCR text did not contain '\(expected)'. Raw OCR:\n\(rawText)",
            file: file,
            line: line
        )
    }

    private func date(byAdding component: Calendar.Component, value: Int) -> Date {
        Calendar.current.date(byAdding: component, value: value, to: .now) ?? .now
    }

    private func date(from base: Date, byAdding component: Calendar.Component, value: Int) -> Date {
        Calendar.current.date(byAdding: component, value: value, to: base) ?? base
    }
}
