import Foundation
import UIKit
import UniformTypeIdentifiers

/// Service for exporting receipt data in various formats for tax preparation
class ExportService: ObservableObject {

    // MARK: - Export Formats
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case pdf = "PDF"
        case json = "JSON"
        case excel = "Excel" // Excel is a format option

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .pdf: return "pdf"
            case .json: return "json"
            case .excel: return "xlsx"
            }
        }

        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .pdf: return "application/pdf"
            case .json: return "application/json"
            case .excel: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            }
        }
    }

    // MARK: - Export Options (Currently not used directly by export methods, but can be expanded)
    struct ExportOptions {
        let format: ExportFormat
        static func `default`(for format: ExportFormat) -> ExportOptions {
            ExportOptions(format: format)
        }
    }

    // MARK: - CSV Export
    func exportToCSV(receipts: [Receipt]) -> Result<URL, ExportError> {
        if receipts.isEmpty { return .failure(.noReceiptsToExport) }
        do {
            let csvContent = try generateCSVContent(receipts: receipts)
            let fileName = "receipts_export_\(dateString()).csv"
            let url = try writeToTemporaryFile(content: csvContent, fileName: fileName)

            print("✅ ExportService: CSV export successful - \(receipts.count) receipts")
            return .success(url)

        } catch let error as ExportError {
            print("❌ ExportService: CSV export failed - \(error.localizedDescription)")
            return .failure(error)
        } catch {
            print("❌ ExportService: CSV export failed - \(error.localizedDescription)")
            return .failure(.csvGenerationFailed(error))
        }
    }

    private func generateCSVContent(receipts: [Receipt]) throws -> String {
        var csvLines: [String] = []
        let headers = [
            "ID", "Date", "Time", "Vendor Name", "Store Name", "Address", "City", "State", "Zip", "Phone", "Website", "Slogan", "Vendor Tax ID",
            "Transaction ID", "Payment Method", "Card Ending", "Auth Code", "Cashier", "Register", "Customer Name", "Customer Number", "Return Policy",
            "Receipt Type", "Subtotal", "Tax Amount", "Tax Rate", "Tip Amount", "Discount (Total)", "Total Amount",
            "Item Description", "Item Quantity", "Item Unit Price", "Item Total Price", "Item Expense Category", "Item Tax Category", "Item SKU", "Item Discount", "Item Codes", "Item Is Expense", "Item Needs Review",
            "Notes Description", "Handwritten Notes", "Vehicle", "Mileage", "Trip", "Business Purpose (Note)",
            "Raw OCR Text", "Confidence Score", "Needs Review (Receipt)", "Created At", "Updated At"
        ]
        csvLines.append(headers.joined(separator: ","))
        let sortedReceipts = receipts.sorted { ($0.parsedDate ?? Date.distantPast) < ($1.parsedDate ?? Date.distantPast) }

        for receipt in sortedReceipts {
            if let items = receipt.items, !items.isEmpty {
                for item in items {
                    let row = [
                        csvEscape(receipt.id.uuidString), csvEscape(receipt.transactionInfo?.date ?? ""), csvEscape(receipt.transactionInfo?.time ?? ""),
                        csvEscape(receipt.vendorInfo?.vendor ?? ""), csvEscape(receipt.vendorInfo?.store_name ?? ""), csvEscape(receipt.vendorInfo?.address ?? ""),
                        csvEscape(receipt.vendorInfo?.city ?? ""), csvEscape(receipt.vendorInfo?.state ?? ""), csvEscape(receipt.vendorInfo?.zip_code ?? ""),
                        csvEscape(receipt.vendorInfo?.phone ?? ""), csvEscape(receipt.vendorInfo?.website ?? ""), csvEscape(receipt.vendorInfo?.slogan ?? ""),
                        csvEscape(receipt.vendorInfo?.tax_id ?? ""), csvEscape(receipt.transactionInfo?.transaction_id ?? ""),
                        csvEscape(receipt.transactionInfo?.payment_method ?? ""), csvEscape(receipt.transactionInfo?.card_ending ?? ""),
                        csvEscape(receipt.transactionInfo?.auth_code ?? ""), csvEscape(receipt.transactionInfo?.cashier ?? ""),
                        csvEscape(receipt.transactionInfo?.register ?? ""), csvEscape(receipt.transactionInfo?.customer_name ?? ""),
                        csvEscape(receipt.transactionInfo?.customer_number ?? ""), csvEscape(receipt.transactionInfo?.return_policy ?? ""),
                        csvEscape(receipt.receiptType ?? ""), String(receipt.totals?.subtotal ?? 0.0), String(receipt.totals?.tax ?? 0.0),
                        String(receipt.totals?.tax_rate ?? 0.0), String(receipt.totals?.tip ?? 0.0), String(receipt.totals?.discount ?? 0.0),
                        String(receipt.totals?.total ?? 0.0), csvEscape(item.description ?? ""), String(item.quantity ?? 0.0),
                        String(item.unit_price ?? 0.0), String(item.total_price ?? 0.0), csvEscape(item.expense_category ?? ""),
                        csvEscape(item.tax_category ?? ""), csvEscape(item.sku ?? ""), String(item.discount ?? 0.0),
                        csvEscape(item.codes?.joined(separator: ";") ?? ""), item.is_expense.map { $0 ? "Yes" : "No" } ?? "",
                        item.needs_review.map { $0 ? "Yes" : "No" } ?? "", csvEscape(receipt.notes?.description ?? ""),
                        csvEscape(receipt.notes?.handwriting ?? ""), csvEscape(receipt.notes?.vehicle ?? ""), csvEscape(receipt.notes?.mileage ?? ""),
                        csvEscape(receipt.notes?.trip ?? ""), csvEscape(receipt.notes?.business_purpose ?? ""), csvEscape(receipt.rawOCRText ?? ""),
                        String(receipt.confidenceScore ?? 0.0), receipt.needsReview ? "Yes" : "No", formatDateForCSV(receipt.createdAt),
                        formatDateForCSV(receipt.updatedAt)
                    ].map { $0 }
                    csvLines.append(row.joined(separator: ","))
                }
            } else {
                 let row = [
                    csvEscape(receipt.id.uuidString), csvEscape(receipt.transactionInfo?.date ?? ""), csvEscape(receipt.transactionInfo?.time ?? ""),
                    csvEscape(receipt.vendorInfo?.vendor ?? ""), csvEscape(receipt.vendorInfo?.store_name ?? ""), csvEscape(receipt.vendorInfo?.address ?? ""),
                    csvEscape(receipt.vendorInfo?.city ?? ""), csvEscape(receipt.vendorInfo?.state ?? ""), csvEscape(receipt.vendorInfo?.zip_code ?? ""),
                    csvEscape(receipt.vendorInfo?.phone ?? ""), csvEscape(receipt.vendorInfo?.website ?? ""), csvEscape(receipt.vendorInfo?.slogan ?? ""),
                    csvEscape(receipt.vendorInfo?.tax_id ?? ""), csvEscape(receipt.transactionInfo?.transaction_id ?? ""),
                    csvEscape(receipt.transactionInfo?.payment_method ?? ""), csvEscape(receipt.transactionInfo?.card_ending ?? ""),
                    csvEscape(receipt.transactionInfo?.auth_code ?? ""), csvEscape(receipt.transactionInfo?.cashier ?? ""),
                    csvEscape(receipt.transactionInfo?.register ?? ""), csvEscape(receipt.transactionInfo?.customer_name ?? ""),
                    csvEscape(receipt.transactionInfo?.customer_number ?? ""), csvEscape(receipt.transactionInfo?.return_policy ?? ""),
                    csvEscape(receipt.receiptType ?? ""), String(receipt.totals?.subtotal ?? 0.0), String(receipt.totals?.tax ?? 0.0),
                    String(receipt.totals?.tax_rate ?? 0.0), String(receipt.totals?.tip ?? 0.0), String(receipt.totals?.discount ?? 0.0),
                    String(receipt.totals?.total ?? 0.0), "", "", "", "", "", "", "", "", "", "", "",
                    csvEscape(receipt.notes?.description ?? ""), csvEscape(receipt.notes?.handwriting ?? ""),
                    csvEscape(receipt.notes?.vehicle ?? ""), csvEscape(receipt.notes?.mileage ?? ""), csvEscape(receipt.notes?.trip ?? ""),
                    csvEscape(receipt.notes?.business_purpose ?? ""), csvEscape(receipt.rawOCRText ?? ""),
                    String(receipt.confidenceScore ?? 0.0), receipt.needsReview ? "Yes" : "No", formatDateForCSV(receipt.createdAt),
                    formatDateForCSV(receipt.updatedAt)
                ].map { $0 }
                csvLines.append(row.joined(separator: ","))
            }
        }
        return csvLines.joined(separator: "\n")
    }

    private func csvEscape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return text
    }

    // MARK: - JSON Export
    func exportToJSON(receipts: [Receipt], taxSummary: TaxSummary? = nil) -> Result<URL, ExportError> {
        if receipts.isEmpty && taxSummary == nil { return .failure(.noReceiptsToExport) }
        do {
            let exportData = JSONExportContainer(
                exportDate: Date(),
                summary: taxSummary,
                receipts: receipts
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(exportData)
            let fileName = "receipts_export_\(dateString()).json"
            let url = try writeToTemporaryFile(data: jsonData, fileName: fileName)
            print("✅ ExportService: JSON export successful - \(receipts.count) receipts")
            return .success(url)
        } catch let error as ExportError {
            print("❌ ExportService: JSON export failed - \(error.localizedDescription)")
            return .failure(error)
        } catch {
            print("❌ ExportService: JSON export failed - \(error.localizedDescription)")
            return .failure(.jsonGenerationFailed(error))
        }
    }

    // MARK: - PDF Export
    func exportToPDF(receipts: [Receipt], taxSummary: TaxSummary) -> Result<URL, ExportError> {
         if receipts.isEmpty && taxSummary.receiptCount == 0 { return .failure(.noReceiptsToExport) }
        do {
            let pdfData = try generateTaxPDFReport(receipts: receipts, summary: taxSummary)
            let fileName = "tax_report_\(dateString()).pdf"
            let url = try writeToTemporaryFile(data: pdfData, fileName: fileName)
            print("✅ ExportService: PDF export successful")
            return .success(url)
        } catch let error as ExportError {
            print("❌ ExportService: PDF export failed - \(error.localizedDescription)")
            return .failure(error)
        } catch {
            print("❌ ExportService: PDF export failed - \(error.localizedDescription)")
            return .failure(.pdfGenerationFailed(error))
        }
    }

    // MARK: - Excel Export (Stubbed)
    func exportToExcel(receipts: [Receipt]) -> Result<URL, ExportError> {
        if receipts.isEmpty {
            return .failure(.noReceiptsToExport)
        }
        // For now, Excel export is not implemented.
        // A real implementation would involve creating an .xlsx file,
        // possibly using a third-party library if direct generation is complex.
        print("ℹ️ ExportService: Excel export requested but not implemented.")
        return .failure(.unimplementedFormat("Excel (.xlsx)"))
    }

    private func generateTaxPDFReport(receipts: [Receipt], summary: TaxSummary) throws -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            var yPosition: CGFloat = 30
            let leftMargin: CGFloat = 50
            let rightMargin: CGFloat = 50
            let contentWidth = 612 - leftMargin - rightMargin

            func addText(_ text: String, font: UIFont, y: inout CGFloat, x: CGFloat = leftMargin, width: CGFloat = contentWidth, height: CGFloat = 20, alignment: NSTextAlignment = .left) {
                if y + height > 792 - 50 {
                    context.beginPage()
                    y = 30
                }
                text.draw(in: CGRect(x: x, y: y, width: width, height: height),
                          withAttributes: [.font: font, .paragraphStyle: { let style = NSMutableParagraphStyle(); style.alignment = alignment; return style }()])
                y += height
            }

            addText("Tax Receipt Report - \(summary.dateRangeString)", font: .boldSystemFont(ofSize: 20), y: &yPosition, alignment: .center)
            yPosition += 10

            addText("Summary", font: .boldSystemFont(ofSize: 16), y: &yPosition)
            yPosition += 5

            addText("Total Receipts Analyzed: \(summary.receiptCount)", font: .systemFont(ofSize: 12), y: &yPosition)
            addText("Total Deductions Claimed: \(summary.formattedTotalDeductions)", font: .systemFont(ofSize: 12), y: &yPosition)
            addText("Receipts Needing Review: \(summary.needsReviewCount)", font: .systemFont(ofSize: 12), y: &yPosition)
            addText("Data Completion: \(String(format: "%.1f%%", summary.completionPercentage * 100))", font: .systemFont(ofSize: 12), y: &yPosition)
            yPosition += 15

            addText("Category Breakdown", font: .boldSystemFont(ofSize: 16), y: &yPosition)
            yPosition += 5

            for (category, amount) in summary.categoryBreakdown.sorted(by: { $0.value > $1.value }) {
                let amountStr = (NumberFormatter.currencyFormatter).string(from: NSNumber(value: amount)) ?? "$0.00"
                addText("\(category): \(amountStr)", font: .systemFont(ofSize: 12), y: &yPosition, x: leftMargin + 10)
            }
            yPosition += 15

            addText("Receipt Details", font: .boldSystemFont(ofSize: 16), y: &yPosition)
            yPosition += 5

            let tableHeaders = ["Date", "Vendor", "Category", "Amount"]
            let columnWidths: [CGFloat] = [100, 180, 120, 100]
            var currentX: CGFloat = leftMargin

            for (i, header) in tableHeaders.enumerated() {
                addText(header, font: .boldSystemFont(ofSize: 10), y: &yPosition, x: currentX, width: columnWidths[i])
                currentX += columnWidths[i]
            }
            yPosition -= 20
            yPosition += 20

            context.cgContext.move(to: CGPoint(x: leftMargin, y: yPosition))
            context.cgContext.addLine(to: CGPoint(x: contentWidth + leftMargin, y: yPosition))
            context.cgContext.strokePath()
            yPosition += 5

            for receipt in summary.receipts {
                currentX = leftMargin
                let dateStr = receipt.parsedDate != nil ? AppDateFormatter.shared.string(from: receipt.parsedDate!, format: "yyyy/MM/dd") : "N/A"
                let vendorStr = receipt.primaryVendorName ?? "N/A"
                let categoryStr = receipt.displayCategory ?? "N/A"
                let amountStr = receipt.totals?.total.map { (NumberFormatter.currencyFormatter).string(from: NSNumber(value: $0)) ?? "N/A" } ?? "N/A"

                let rowData = [dateStr, vendorStr, categoryStr, amountStr]

                for (i, data) in rowData.enumerated() {
                    addText(data, font: .systemFont(ofSize: 9), y: &yPosition, x: currentX, width: columnWidths[i], height: 15)
                    currentX += columnWidths[i]
                }
                yPosition -= 15
                 yPosition += 15
            }
        }
        return data
    }

    // MARK: - Utility Methods
    private func writeToTemporaryFile(content: String, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func writeToTemporaryFile(data: Data, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }

    private func formatDateForCSV(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    struct ShareableDocument {
        let url: URL
        let format: ExportService.ExportFormat
        let title: String
    }
}

// MARK: - Export Models
struct JSONExportContainer: Codable {
    let exportDate: Date
    let summary: TaxSummary?
    let receipts: [Receipt]

    enum CodingKeys: String, CodingKey {
        case exportDate = "export_date"
        case summary, receipts
    }
}

extension TaxSummary: Codable {
    enum CodingKeys: String, CodingKey {
        case dateRangeString = "date_range"
        case totalDeductions = "total_deductions"
        case categoryBreakdown = "category_breakdown"
        case receiptCount = "receipt_count"
        case needsReviewCount = "needs_review_count"
        case receipts
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dateRangeString, forKey: .dateRangeString)
        try container.encode(totalDeductions, forKey: .totalDeductions)
        try container.encode(categoryBreakdown, forKey: .categoryBreakdown)
        try container.encode(receiptCount, forKey: .receiptCount)
        try container.encode(needsReviewCount, forKey: .needsReviewCount)
        try container.encode(receipts, forKey: .receipts)
    }

     init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateRangeString = try container.decode(String.self, forKey: .dateRangeString)
        totalDeductions = try container.decode(Double.self, forKey: .totalDeductions)
        categoryBreakdown = try container.decode([String: Double].self, forKey: .categoryBreakdown)
        receiptCount = try container.decode(Int.self, forKey: .receiptCount)
        needsReviewCount = try container.decode(Int.self, forKey: .needsReviewCount)
        receipts = try container.decode([Receipt].self, forKey: .receipts)
    }
}

// MARK: - Error Types
enum ExportError: Error, LocalizedError, Identifiable {
    case csvGenerationFailed(Error)
    case jsonGenerationFailed(Error)
    case pdfGenerationFailed(Error)
    case fileWriteFailed(Error)
    case noReceiptsToExport
    case unimplementedFormat(String)

    var id: String {
        switch self {
        case .csvGenerationFailed: return "csvGenerationFailed"
        case .jsonGenerationFailed: return "jsonGenerationFailed"
        case .pdfGenerationFailed: return "pdfGenerationFailed"
        case .fileWriteFailed: return "fileWriteFailed"
        case .noReceiptsToExport: return "noReceiptsToExport"
        case .unimplementedFormat(let type): return "unimplementedFormat_\(type)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .csvGenerationFailed(let error):
            return "Failed to generate CSV: \(error.localizedDescription)"
        case .jsonGenerationFailed(let error):
            return "Failed to generate JSON: \(error.localizedDescription)"
        case .pdfGenerationFailed(let error):
            return "Failed to generate PDF: \(error.localizedDescription)"
        case .fileWriteFailed(let error):
            return "Failed to write export file: \(error.localizedDescription)"
        case .noReceiptsToExport:
            return "There are no receipts matching the current filter to export."
        case .unimplementedFormat(let formatType):
            return "Export to \(formatType) is not currently implemented."
        }
    }
}

extension NumberFormatter {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()
}
