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
        case excel = "Excel"
        
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
    
    // MARK: - Export Options
    struct ExportOptions {
        let format: ExportFormat
        let includePDFAttachments: Bool
        let groupByCategory: Bool
        let includeImages: Bool
        let dateRange: String
        let taxYearOnly: Bool
        
        static let `default` = ExportOptions(
            format: .csv,
            includePDFAttachments: false,
            groupByCategory: true,
            includeImages: false,
            dateRange: "This Year",
            taxYearOnly: true
        )
    }
    
    // MARK: - CSV Export
    func exportToCSV(receipts: [Receipt], options: ExportOptions = .default) -> Result<URL, ExportError> {
        do {
            let csvContent = try generateCSVContent(receipts: receipts, options: options)
            let fileName = "receipts_export_\(dateString()).csv"
            let url = try writeToTemporaryFile(content: csvContent, fileName: fileName)
            
            print("✅ ExportService: CSV export successful - \(receipts.count) receipts")
            return .success(url)
            
        } catch {
            print("❌ ExportService: CSV export failed - \(error)")
            return .failure(.csvGenerationFailed(error))
        }
    }
    
    private func generateCSVContent(receipts: [Receipt], options: ExportOptions) throws -> String {
        var csvLines: [String] = []
        
        // Enhanced CSV headers for tax purposes
        let headers = [
            "Date", "Vendor", "Category", "Tax Category", "Amount", "Subtotal", "Tax Amount", "Tip Amount", 
            "Tax Rate", "Payment Method", "Location", "Business Purpose", "Transaction ID", "Vendor Tax ID",
            "Mileage", "Vehicle Info", "Receipt Type", "Confidence Score", "Needs Review", "Notes", "Created Date"
        ]
        
        csvLines.append(headers.joined(separator: ","))
        
        // Group by category if requested
        let sortedReceipts = options.groupByCategory ? 
            receipts.sorted { ($0.taxCategory ?? "Other") < ($1.taxCategory ?? "Other") } : 
            receipts.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
        
        for receipt in sortedReceipts {
            let row = [
                csvEscape(receipt.formattedDate),
                csvEscape(receipt.vendor ?? ""),
                csvEscape(receipt.category ?? ""),
                csvEscape(receipt.taxCategory ?? ""),
                String(receipt.amount ?? 0.0),
                String(receipt.subtotal ?? 0.0),
                String(receipt.taxAmount ?? 0.0),
                String(receipt.tipAmount ?? 0.0),
                String(receipt.taxRate ?? 0.0),
                csvEscape(receipt.paymentMethod ?? ""),
                csvEscape(receipt.location ?? ""),
                csvEscape(receipt.businessPurpose ?? ""),
                csvEscape(receipt.transactionId ?? ""),
                csvEscape(receipt.vendorTaxId ?? ""),
                csvEscape(receipt.mileage ?? ""),
                csvEscape(receipt.vehicleInfo ?? ""),
                csvEscape(receipt.receiptType ?? ""),
                String(receipt.confidenceScore ?? 0.0),
                receipt.needsReview ? "Yes" : "No",
                csvEscape(receipt.notes ?? ""),
                formatDateForCSV(receipt.createdAt)
            ]
            
            csvLines.append(row.joined(separator: ","))
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
        do {
            let exportData = TaxExportData(
                exportDate: Date(),
                dateRange: taxSummary?.dateRange.rawValue ?? "All Time",
                totalReceipts: receipts.count,
                totalAmount: receipts.compactMap { $0.amount }.reduce(0, +),
                summary: taxSummary,
                receipts: receipts.map { ReceiptExportModel(from: $0) }
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let jsonData = try encoder.encode(exportData)
            let fileName = "receipts_tax_export_\(dateString()).json"
            let url = try writeToTemporaryFile(data: jsonData, fileName: fileName)
            
            print("✅ ExportService: JSON export successful - \(receipts.count) receipts")
            return .success(url)
            
        } catch {
            print("❌ ExportService: JSON export failed - \(error)")
            return .failure(.jsonGenerationFailed(error))
        }
    }
    
    // MARK: - PDF Export  
    func exportToPDF(receipts: [Receipt], taxSummary: TaxSummary) -> Result<URL, ExportError> {
        do {
            let pdfData = try generateTaxPDFReport(receipts: receipts, summary: taxSummary)
            let fileName = "tax_report_\(dateString()).pdf"
            let url = try writeToTemporaryFile(data: pdfData, fileName: fileName)
            
            print("✅ ExportService: PDF export successful")
            return .success(url)
            
        } catch {
            print("❌ ExportService: PDF export failed - \(error)")
            return .failure(.pdfGenerationFailed(error))
        }
    }
    
    private func generateTaxPDFReport(receipts: [Receipt], summary: TaxSummary) throws -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // Letter size
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 50
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let title = "Tax Receipt Report - \(summary.dateRange.rawValue)"
            title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Summary section
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            "Summary".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            let summaryText = """
            Total Receipts: \(summary.receiptCount)
            Total Deductions: \(summary.formattedTotalDeductions)
            Needs Review: \(summary.needsReviewCount)
            Completion: \(String(format: "%.1f", summary.completionPercentage * 100))%
            """
            
            summaryText.draw(in: CGRect(x: 50, y: yPosition, width: 500, height: 80), withAttributes: bodyAttributes)
            yPosition += 100
            
            // Category breakdown
            "Category Breakdown".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            for (category, amount) in summary.categoryBreakdown.sorted(by: { $0.value > $1.value }) {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                let amountStr = formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
                
                let categoryLine = "\(category): \(amountStr)"
                categoryLine.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 20
                
                if yPosition > 700 { // New page if needed
                    context.beginPage()
                    yPosition = 50
                }
            }
            
            // Receipt details (first page summary)
            yPosition += 20
            "Receipt Details".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            let detailsNote = "Detailed receipt information is available in the accompanying CSV export file."
            detailsNote.draw(in: CGRect(x: 50, y: yPosition, width: 500, height: 40), withAttributes: bodyAttributes)
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
    
    // MARK: - Share Sheet Support
    func createShareableDocument(from url: URL, format: ExportFormat) -> ShareableDocument {
        return ShareableDocument(
            url: url,
            format: format,
            title: "Receipt Export - \(format.rawValue)"
        )
    }
}

// MARK: - Export Models
struct TaxExportData: Codable {
    let exportDate: Date
    let dateRange: String
    let totalReceipts: Int
    let totalAmount: Double
    let summary: TaxSummary?
    let receipts: [ReceiptExportModel]
    
    enum CodingKeys: String, CodingKey {
        case exportDate = "export_date"
        case dateRange = "date_range"
        case totalReceipts = "total_receipts"
        case totalAmount = "total_amount"
        case summary, receipts
    }
}

struct ReceiptExportModel: Codable {
    let id: String
    let date: Date?
    let vendor: String?
    let category: String?
    let taxCategory: String?
    let amount: Double?
    let subtotal: Double?
    let taxAmount: Double?
    let tipAmount: Double?
    let taxRate: Double?
    let paymentMethod: String?
    let location: String?
    let businessPurpose: String?
    let transactionId: String?
    let vendorTaxId: String?
    let mileage: String?
    let vehicleInfo: String?
    let receiptType: String?
    let confidenceScore: Double?
    let needsReview: Bool
    let notes: String?
    let createdAt: Date
    
    init(from receipt: Receipt) {
        self.id = receipt.id.uuidString
        self.date = receipt.date
        self.vendor = receipt.vendor
        self.category = receipt.category
        self.taxCategory = receipt.taxCategory
        self.amount = receipt.amount
        self.subtotal = receipt.subtotal
        self.taxAmount = receipt.taxAmount
        self.tipAmount = receipt.tipAmount
        self.taxRate = receipt.taxRate
        self.paymentMethod = receipt.paymentMethod
        self.location = receipt.location
        self.businessPurpose = receipt.businessPurpose
        self.transactionId = receipt.transactionId
        self.vendorTaxId = receipt.vendorTaxId
        self.mileage = receipt.mileage
        self.vehicleInfo = receipt.vehicleInfo
        self.receiptType = receipt.receiptType
        self.confidenceScore = receipt.confidenceScore
        self.needsReview = receipt.needsReview
        self.notes = receipt.notes
        self.createdAt = receipt.createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, date, vendor, category, amount, subtotal, notes
        case taxCategory = "tax_category"
        case taxAmount = "tax_amount"
        case tipAmount = "tip_amount"
        case taxRate = "tax_rate"
        case paymentMethod = "payment_method"
        case location, businessPurpose = "business_purpose"
        case transactionId = "transaction_id"
        case vendorTaxId = "vendor_tax_id"
        case mileage, vehicleInfo = "vehicle_info"
        case receiptType = "receipt_type"
        case confidenceScore = "confidence_score"
        case needsReview = "needs_review"
        case createdAt = "created_at"
    }
}

// Make TaxSummary Codable
extension TaxSummary: Codable {
    enum CodingKeys: String, CodingKey {
        case dateRange = "date_range"
        case totalDeductions = "total_deductions"
        case categoryBreakdown = "category_breakdown"
        case receiptCount = "receipt_count"
        case needsReviewCount = "needs_review_count"
        case completionPercentage = "completion_percentage"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dateRange.rawValue, forKey: .dateRange)
        try container.encode(totalDeductions, forKey: .totalDeductions)
        try container.encode(categoryBreakdown, forKey: .categoryBreakdown)
        try container.encode(receiptCount, forKey: .receiptCount)
        try container.encode(needsReviewCount, forKey: .needsReviewCount)
        try container.encode(completionPercentage, forKey: .completionPercentage)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateRangeString = try container.decode(String.self, forKey: .dateRange)
        
        // This is a simplified reconstruction - in practice you'd want better handling
        self.dateRange = ReceiptListViewModel.DateRange(rawValue: dateRangeString) ?? .all
        self.totalDeductions = try container.decode(Double.self, forKey: .totalDeductions)
        self.categoryBreakdown = try container.decode([String: Double].self, forKey: .categoryBreakdown)
        self.receiptCount = try container.decode(Int.self, forKey: .receiptCount)
        self.needsReviewCount = try container.decode(Int.self, forKey: .needsReviewCount)
        self.receipts = [] // Would need to be included separately
    }
}

struct ShareableDocument {
    let url: URL
    let format: ExportService.ExportFormat
    let title: String
}

// MARK: - Error Types
enum ExportError: Error, LocalizedError {
    case csvGenerationFailed(Error)
    case jsonGenerationFailed(Error)
    case pdfGenerationFailed(Error)
    case fileWriteFailed(Error)
    case noReceiptsToExport
    
    var errorDescription: String? {
        switch self {
        case .csvGenerationFailed(let error):
            return "Failed to generate CSV: \(error.localizedDescription)"
        case .jsonGenerationFailed(let error):
            return "Failed to generate JSON: \(error.localizedDescription)"
        case .pdfGenerationFailed(let error):
            return "Failed to generate PDF: \(error.localizedDescription)"
        case .fileWriteFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .noReceiptsToExport:
            return "No receipts available to export"
        }
    }
}
