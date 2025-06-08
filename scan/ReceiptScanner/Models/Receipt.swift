import Foundation

struct Receipt: Identifiable, Codable {
    // MARK: - Core Properties
    let id: UUID
    var imageData: Data?
    var rawOCRText: String?      // Full OCR text, potentially different from LLM's interpretation in notes.rawText
    var confidenceScore: Double? // Overall confidence from parsing (either local or LLM)
    var needsReview: Bool
    let createdAt: Date
    var updatedAt: Date

    // MARK: - New Structured Data Properties
    var receiptType: String?     // Top-level type from LLM
    var vendorInfo: VendorInfo?
    var transactionInfo: TransactionInfo?
    var items: [LineItem]?       // Optional list of line items
    var totals: Totals?
    var notes: Notes?            // Contains general notes, handwritten text, mileage etc. from LLM

    // MARK: - Nested Structs Matching OllamaService.DetailedReceiptData

    struct VendorInfo: Codable {
        var vendor: String?          // Full legal or displayed name from receipt
        var store_name: String?      // Simplified, common name (e.g., "Walmart", "Starbucks")
        var address: String?         // Street address
        var city: String?            // Lowercase
        var state: String?           // 2-letter postal abbreviation (e.g., "NY")
        var zip_code: String?
        var phone: String?
        var website: String?         // New, from prompt
        var slogan: String?          // New
        var tax_id: String?          // New, from prompt (was vendorTaxId at top level)

        // Default initializer
        init(vendor: String? = nil, store_name: String? = nil, address: String? = nil, city: String? = nil, state: String? = nil, zip_code: String? = nil, phone: String? = nil, website: String? = nil, slogan: String? = nil, tax_id: String? = nil) {
            self.vendor = vendor
            self.store_name = store_name
            self.address = address
            self.city = city
            self.state = state
            self.zip_code = zip_code
            self.phone = phone
            self.website = website
            self.slogan = slogan
            self.tax_id = tax_id
        }
    }

    struct TransactionInfo: Codable {
        var date: String?            // YYYY/MM/DD string from LLM
        var time: String?            // HH:MM:SS or HH:MM AM/PM string from LLM
        var transaction_id: String?
        var payment_method: String?
        var card_ending: String?     // New
        var auth_code: String?       // New
        var cashier: String?
        var register: String?        // New (was not explicitly in old top-level)
        var customer_name: String?   // New
        var customer_number: String? // New
        var return_policy: String?   // New
        var promotions: [PromotionItem]? // New
        var code_definitions: [String: String]? // New

        // Default initializer
        init(date: String? = nil, time: String? = nil, transaction_id: String? = nil, payment_method: String? = nil, card_ending: String? = nil, auth_code: String? = nil, cashier: String? = nil, register: String? = nil, customer_name: String? = nil, customer_number: String? = nil, return_policy: String? = nil, promotions: [PromotionItem]? = nil, code_definitions: [String : String]? = nil) {
            self.date = date
            self.time = time
            self.transaction_id = transaction_id
            self.payment_method = payment_method
            self.card_ending = card_ending
            self.auth_code = auth_code
            self.cashier = cashier
            self.register = register
            self.customer_name = customer_name
            self.customer_number = customer_number
            self.return_policy = return_policy
            self.promotions = promotions
            self.code_definitions = code_definitions
        }
    }

    struct PromotionItem: Codable { // New
        var promo_type: String?
        var details: String?

        init(promo_type: String? = nil, details: String? = nil) {
            self.promo_type = promo_type
            self.details = details
        }
    }

    struct LineItem: Codable { // New
        var description: String?     // Renamed from 'name' for clarity if it was ever 'name'
        var quantity: Double?
        var unit_price: Double?      // Price per unit (or gal_price contextually)
        var unit_subtotal: Double?   // Optional: subtotal for this line if quantity > 1
        var total_price: Double?     // Total for this line item
        var expense_category: String?// Mapped from LLM
        var tax_category: String?    // e.g., 'Taxable', 'F' (from LLM)
        var sku: String?
        var discount: Double?        // Line-item specific discount
        var codes: [String]?         // e.g., ['F', 'T']
        var is_expense: Bool?        // True if business expense, false if personal
        var needs_review: Bool?      // True if item is ambiguous

        // Default initializer
        init(description: String? = nil, quantity: Double? = nil, unit_price: Double? = nil, unit_subtotal: Double? = nil, total_price: Double? = nil, expense_category: String? = nil, tax_category: String? = nil, sku: String? = nil, discount: Double? = nil, codes: [String]? = nil, is_expense: Bool? = nil, needs_review: Bool? = nil) {
            self.description = description
            self.quantity = quantity
            self.unit_price = unit_price
            self.unit_subtotal = unit_subtotal
            self.total_price = total_price
            self.expense_category = expense_category
            self.tax_category = tax_category
            self.sku = sku
            self.discount = discount
            self.codes = codes
            self.is_expense = is_expense
            self.needs_review = needs_review
        }
    }

    struct Totals: Codable { // New
        var subtotal: Double?
        var tax: Double?
        var tax_rate: Double?        // Overall tax rate (e.g., 0.085 for 8.5%)
        var tip: Double?
        var discount: Double?        // Overall discount amount
        var total: Double?           // Final amount paid
        var cash_back: Double?
        var change: Double?

        // Default initializer
        init(subtotal: Double? = nil, tax: Double? = nil, tax_rate: Double? = nil, tip: Double? = nil, discount: Double? = nil, total: Double? = nil, cash_back: Double? = nil, change: Double? = nil) {
            self.subtotal = subtotal
            self.tax = tax
            self.tax_rate = tax_rate
            self.tip = tip
            self.discount = discount
            self.total = total
            self.cash_back = cash_back
            self.change = change
        }
    }

    struct Notes: Codable { // New
        var handwriting: String?     // Transcribed handwritten notes
        var description: String?     // General description from LLM, may include [Vehicle][Mileage][Trip] for fuel.
        var vehicle: String?         // Vehicle identifier (e.g., plate, pump#) from LLM (often from notes.description)
        var mileage: String?         // Odometer reading from LLM (often from notes.description)
        var trip: String?            // Trip purpose from LLM (often from notes.description)
        var business_purpose: String?// Suggested by LLM
        var raw_text_from_llm: String? // LLM's version of raw text (distinct from overall rawOCRText)

        // Default initializer
        init(handwriting: String? = nil, description: String? = nil, vehicle: String? = nil, mileage: String? = nil, trip: String? = nil, business_purpose: String? = nil, raw_text_from_llm: String? = nil) {
            self.handwriting = handwriting
            self.description = description
            self.vehicle = vehicle
            self.mileage = mileage
            self.trip = trip
            self.business_purpose = business_purpose
            self.raw_text_from_llm = raw_text_from_llm
        }
    }

    // MARK: - Main Initializer
    init(
        id: UUID = UUID(),
        imageData: Data? = nil,
        rawOCRText: String? = nil,
        confidenceScore: Double? = nil,
        needsReview: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        receiptType: String? = nil,
        vendorInfo: VendorInfo? = nil,
        transactionInfo: TransactionInfo? = nil,
        items: [LineItem]? = nil,
        totals: Totals? = nil,
        notes: Notes? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.rawOCRText = rawOCRText
        self.confidenceScore = confidenceScore
        self.needsReview = needsReview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.receiptType = receiptType
        self.vendorInfo = vendorInfo
        self.transactionInfo = transactionInfo
        self.items = items
        self.totals = totals
        self.notes = notes
    }

    // MARK: - Computed Properties (Examples, adapt as needed)

    // Primary vendor name for display
    var primaryVendorName: String? {
        vendorInfo?.store_name ?? vendorInfo?.vendor
    }

    // Main category for display (could be from receiptType or derived from items)
    var displayCategory: String? {
        // More sophisticated logic might be needed here:
        // 1. Check items for a consensus category
        // 2. Fallback to receiptType mapped to a category
        // 3. Fallback to a default like "Other" or "Needs Categorization"
        if let items = items, !items.isEmpty {
            let categoryCounts = items.compactMap { $0.expense_category }.reduce(into: [:]) { counts, category in
                counts[category, default: 0] += 1
            }
            if let mostFrequent = categoryCounts.max(by: { $0.value < $1.value })?.key {
                return mostFrequent
            }
        }
        if let type = receiptType { // Basic mapping, can be expanded
            if type.lowercased().contains("fuel") { return "Fuel & Vehicle" }
            if type.lowercased().contains("food") || type.lowercased().contains("restaurant") { return "Meals & Entertainment" }
            // Add more mappings from OllamaService.mapReceiptTypeToCategory if needed here
        }
        return "Other Business" // Default
    }

    var formattedAmount: String {
        guard let total = totals?.total else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: total)) ?? "N/A"
    }

    var parsedDate: Date? {
        guard let dateString = transactionInfo?.date else { return nil }
        // Consistent date parsing logic (should match OllamaService.parseDate or use a shared utility)
        let formatters = [
            "yyyy/MM/dd", "yyyy-MM-dd", "MM/dd/yyyy", "MM-dd-yyyy", "dd/MM/yyyy", "dd-MM-yyyy"
        ]
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }

    var formattedDate: String {
        guard let date = parsedDate else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var confidencePercentage: String {
        guard let score = confidenceScore else { return "N/A" }
        return String(format: "%.0f%%", score * 100)
    }

    // Example of accessing a deeply nested value safely
    var taxIdDisplay: String? {
        vendorInfo?.tax_id
    }
}

// Placeholder for removed fields for easier identification during CoreData update:
// Removed: vendor: String?
// Removed: amount: Double?
// Removed: date: Date? (now string in transactionInfo, parsed to Date by computed property)
// Removed: category: String? (now part of LineItem or derived)
// Removed: notes: String? (now a struct Receipt.Notes)
// Removed: paymentMethod: String? (now in transactionInfo)
// Removed: location: String? (now derived from vendorInfo city/state)
// Removed: tags: [String] (can be re-added if LLM provides tags or derived)
// Removed: taxCategory: String? (now part of LineItem or derived)
// Removed: businessPurpose: String? (now in notes struct)
// Removed: subtotal: Double? (now in totals struct)
// Removed: taxAmount: Double? (now in totals struct)
// Removed: tipAmount: Double? (now in totals struct)
// Removed: taxRate: Double? (now in totals struct)
// Removed: transactionId: String? (now in transactionInfo)
// Removed: vendorTaxId: String? (now tax_id in vendorInfo)
// Removed: mileage: String? (now in notes struct)
// Removed: vehicleInfo: String? (now in notes struct)
// Removed: confidence: Double? (replaced by confidenceScore for clarity)
// rawOCRText, receiptType were already present or added correctly.
// id, imageData, needsReview, createdAt, updatedAt are kept.
