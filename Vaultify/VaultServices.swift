//
//  VaultServices.swift
//  Vaultify
//
//  The "blazing fast / top notch" functionality layer:
//   • InvoiceScanner  — VisionKit document capture + on-device OCR + parsing
//   • VaultNotifications — warranty claim-window & maintenance reminders
//   • VaultPDF        — real PDF dossier generation for export / share
//

import SwiftUI
import SwiftData
import VisionKit
import Vision
import UserNotifications
import PDFKit

// MARK: - Invoice OCR

/// Fields pulled out of a scanned invoice. Anything we can't find stays nil.
struct ExtractedInvoice {
    var name: String?
    var brand: String?
    var modelNumber: String?
    var serialNumber: String?
    var price: Double?
    var purchaseDate: Date?
    var rawText: String = ""
}

/// SwiftUI wrapper around the system document scanner.
/// `onProcessing` fires the moment capture finishes (so the host can swap in a
/// loader while OCR runs); `onResult` delivers the parsed invoice; `onCancel`
/// is called if the user backs out. The host owns dismissal via its binding.
struct DocumentScanner: UIViewControllerRepresentable {
    var onProcessing: () -> Void = {}
    var onResult: (Result<ExtractedInvoice, Error>) -> Void
    var onCancel: () -> Void = {}

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [CGImage] = []
            for index in 0..<scan.pageCount {
                if let cg = scan.imageOfPage(at: index).cgImage { images.append(cg) }
            }
            DispatchQueue.main.async { self.parent.onProcessing() }
            InvoiceOCR.recognize(in: images) { result in
                DispatchQueue.main.async { self.parent.onResult(result) }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            DispatchQueue.main.async { self.parent.onCancel() }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            DispatchQueue.main.async { self.parent.onResult(.failure(error)) }
        }
    }
}

/// On-device text recognition + lightweight invoice field parsing.
enum InvoiceOCR {
    static func recognize(in images: [CGImage], completion: @escaping (Result<ExtractedInvoice, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []
            for image in images {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    lines.append(contentsOf: observations.compactMap { $0.topCandidates(1).first?.string })
                } catch {
                    completion(.failure(error))
                    return
                }
            }
            completion(.success(parse(lines: lines)))
        }
    }

    /// Heuristic field extraction. Conservative: prefers leaving a field blank
    /// over guessing wrong, so the user only reviews high-confidence fills.
    static func parse(lines: [String]) -> ExtractedInvoice {
        var result = ExtractedInvoice()
        result.rawText = lines.joined(separator: "\n")

        let knownBrands = ["LG", "Samsung", "Whirlpool", "Bosch", "GE", "Maytag", "KitchenAid",
                           "Frigidaire", "Panasonic", "Sony", "Daikin", "Carrier", "Haier",
                           "Electrolux", "Dyson", "Philips", "Sharp", "Toshiba", "Hitachi",
                           "Voltas", "Godrej", "IFB", "Midea", "Hisense", "TCL"]

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)

            // Brand
            if result.brand == nil {
                for brand in knownBrands where line.localizedCaseInsensitiveContains(brand) {
                    result.brand = brand
                    break
                }
            }

            // Price — only inspect lines that look financial, then pick the
            // largest currency-looking number (usually the total).
            let lowerLine = line.lowercased()
            let hasCurrency = line.rangeOfCharacter(from: CharacterSet(charactersIn: "$₹€£")) != nil
            let hasPriceKeyword = ["total", "subtotal", "amount", "price", "paid", "balance"].contains {
                lowerLine.contains($0)
            }
            if hasCurrency || hasPriceKeyword {
                for match in line.matches(of: /[$₹€£]?\s?([0-9][0-9,]{2,}(?:\.[0-9]{2})?)/) {
                    let cleaned = String(match.output.1).replacingOccurrences(of: ",", with: "")
                    if let value = Double(cleaned), value > (result.price ?? 0), value < 1_000_000 {
                        result.price = value
                    }
                }
            }

            // Model number — token with both letters and digits, reasonably long.
            if result.modelNumber == nil,
               line.localizedCaseInsensitiveContains("model") {
                result.modelNumber = alphanumericToken(in: line)
            }
            if result.serialNumber == nil,
               line.localizedCaseInsensitiveContains("serial") || line.localizedCaseInsensitiveContains("s/n") {
                result.serialNumber = alphanumericToken(in: line)
            }

            // Date
            if result.purchaseDate == nil, let date = detectDate(in: line) {
                result.purchaseDate = date
            }
        }

        // Name: first reasonably long line that isn't a number/price/header.
        result.name = lines.first { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.count >= 6 && t.rangeOfCharacter(from: .letters) != nil
                && !t.localizedCaseInsensitiveContains("invoice")
                && !t.localizedCaseInsensitiveContains("receipt")
                && !t.localizedCaseInsensitiveContains("total")
        }?.trimmingCharacters(in: .whitespaces)

        return result
    }

    private static func alphanumericToken(in line: String) -> String? {
        line.split(whereSeparator: { $0 == " " || $0 == ":" })
            .map(String.init)
            .first { token in
                token.count >= 5
                    && token.rangeOfCharacter(from: .decimalDigits) != nil
                    && token.rangeOfCharacter(from: .letters) != nil
            }
    }

    private static func detectDate(in line: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        return detector.firstMatch(in: line, range: range)?.date
    }
}

// MARK: - Notifications

@MainActor
@Observable
final class VaultNotifications {
    static let shared = VaultNotifications()
    var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        isAuthorized = granted
        return granted
    }

    /// Rebuilds the full reminder schedule from the current portfolio.
    func sync(appliances: [Appliance]) async {
        guard isAuthorized else { return }
        center.removeAllPendingNotificationRequests()

        for appliance in appliances {
            // Warranty claim window — fire 14 days before expiry.
            if let expiry = appliance.nextWarrantyExpiration,
               let fire = Calendar.current.date(byAdding: .day, value: -14, to: expiry),
               fire > .now {
                schedule(
                    id: "warranty-\(appliance.persistentModelID.hashValue)",
                    title: "Warranty closing soon",
                    body: "\(appliance.name) warranty expires \(expiry.formatted(date: .abbreviated, time: .omitted)). File any claims now.",
                    on: fire
                )
            }

            // Maintenance due reminder.
            if appliance.nextMaintenanceDate > .now {
                schedule(
                    id: "service-\(appliance.persistentModelID.hashValue)",
                    title: "Maintenance due",
                    body: "Time for a routine check on your \(appliance.name).",
                    on: appliance.nextMaintenanceDate
                )
            }
        }
    }

    private func schedule(id: String, title: String, body: String, on date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// MARK: - PDF export

enum VaultPDF {
    /// Renders a clean appliance dossier to a temporary PDF file and returns its URL.
    static func dossier(title: String, subtitle: String, appliances: [Appliance]) -> URL? {
        let pageWidth: CGFloat = 612, pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Vaultify-\(UUID().uuidString.prefix(8)).pdf")

        let accent = UIColor(VaultTheme.cyan)
        let currency: (Double) -> String = { $0.formatted(.currency(code: vaultCurrencyCode)) }

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = margin
                ctx.beginPage()

                func text(_ string: String, font: UIFont, color: UIColor = .black, x: CGFloat = margin) {
                    string.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
                }

                func newPageIfNeeded(_ needed: CGFloat) {
                    if y + needed > pageHeight - margin {
                        ctx.beginPage()
                        y = margin
                    }
                }

                // Header band
                accent.setFill()
                ctx.cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 8))

                text("VAULTIFY", font: .systemFont(ofSize: 11, weight: .heavy), color: accent)
                y += 18
                text(title, font: .systemFont(ofSize: 26, weight: .bold))
                y += 32
                text(subtitle, font: .systemFont(ofSize: 12, weight: .regular), color: .darkGray)
                y += 18
                text("Generated \(Date.now.formatted(date: .long, time: .shortened))",
                     font: .systemFont(ofSize: 10), color: .gray)
                y += 30

                let total = appliances.reduce(0.0) { $0 + max($1.purchasePrice, $1.replacementBudgetTarget) }
                text("Tracked assets: \(appliances.count)     Estimated contents value: \(currency(total))",
                     font: .systemFont(ofSize: 12, weight: .semibold))
                y += 28

                UIColor.lightGray.setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: y)); line.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                line.stroke()
                y += 18

                for appliance in appliances {
                    newPageIfNeeded(96)
                    text(appliance.name, font: .systemFont(ofSize: 15, weight: .bold))
                    y += 20
                    text("\(appliance.displayBrand)  ·  \(appliance.category.title)  ·  Model \(appliance.modelNumber.isEmpty ? "—" : appliance.modelNumber)",
                         font: .systemFont(ofSize: 11), color: .darkGray)
                    y += 16
                    text("Serial \(appliance.serialNumber.isEmpty ? "—" : appliance.serialNumber)  ·  Purchased \(appliance.purchaseDate.formatted(date: .abbreviated, time: .omitted))  ·  \(currency(appliance.purchasePrice))",
                         font: .systemFont(ofSize: 11), color: .darkGray)
                    y += 16
                    let warranty = appliance.nextWarrantyExpiration.map { "Warranty until \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "No active warranty"
                    text("Health \(appliance.healthScore.formatted(.percent.precision(.fractionLength(0))))  ·  \(warranty)  ·  Replacement \(currency(appliance.replacementBudgetTarget))",
                         font: .systemFont(ofSize: 11), color: .darkGray)
                    y += 24
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
