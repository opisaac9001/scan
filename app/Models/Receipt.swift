import Foundation

struct Receipt: Identifiable, Codable {
    let id: UUID
    let imageData: Data?
    let vendor: String?
    let amount: Double?
    let date: Date?
    let category: String?
    let notes: String?
    let rawText: String?
    let confidence: Double?
    let paymentMethod: String?
    let location: String?
    let tags: [String]
    let needsReview: Bool
    let createdAt: Date
    let updatedAt: Date
    
    // Enhanced tax and business fields
    let taxCategory: String?
    let businessPurpose: String?
    let subtotal: Double?
    let taxAmount: Double?
    let tipAmount: Double?
    let taxRate: Double?
    let transactionId: String?
    let vendorTaxId: String?
    let mileage: String?
    let vehicleInfo: String?
    let receiptType: String?
    let rawOCRText: String?
    let confidenceScore: Double?
      init(
        id: UUID = UUID(),
        imageData: Data? = nil,
        vendor: String? = nil,
        amount: Double? = nil,
        date: Date? = nil,
        category: String? = nil,
        notes: String? = nil,
        rawText: String? = nil,
        confidence: Double? = nil,
        paymentMethod: String? = nil,
        location: String? = nil,
        tags: [String] = [],
        needsReview: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        // Enhanced tax fields
        taxCategory: String? = nil,
        businessPurpose: String? = nil,
        subtotal: Double? = nil,
        taxAmount: Double? = nil,
        tipAmount: Double? = nil,
        taxRate: Double? = nil,
        transactionId: String? = nil,
        vendorTaxId: String? = nil,
        mileage: String? = nil,
        vehicleInfo: String? = nil,
        receiptType: String? = nil,
        rawOCRText: String? = nil,
        confidenceScore: Double? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.vendor = vendor
        self.amount = amount
        self.date = date
        self.category = category
        self.notes = notes
        self.rawText = rawText
        self.confidence = confidence
        self.paymentMethod = paymentMethod
        self.location = location
        self.tags = tags
        self.needsReview = needsReview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        // Enhanced tax fields
        self.taxCategory = taxCategory
        self.businessPurpose = businessPurpose
        self.subtotal = subtotal
        self.taxAmount = taxAmount
        self.tipAmount = tipAmount
        self.taxRate = taxRate
        self.transactionId = transactionId
        self.vendorTaxId = vendorTaxId
        self.mileage = mileage
        self.vehicleInfo = vehicleInfo
        self.receiptType = receiptType
        self.rawOCRText = rawOCRText
        self.confidenceScore = confidenceScore ?? confidence
    }
    
    var formattedAmount: String {
        guard let amount = amount else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "N/A"
    }
    
    var formattedDate: String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var confidencePercentage: String {
        guard let confidence = confidence else { return "N/A" }
        return String(format: "%.0f%%", confidence * 100)
    }
}
