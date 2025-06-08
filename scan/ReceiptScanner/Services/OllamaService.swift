import Foundation
import UIKit
import SwiftUI // Added for @AppStorage if not already present

/// Service for integrating with Ollama LLM API and OpenAI-compatible APIs for advanced receipt processing
class OllamaService: ObservableObject {

    // MARK: - Configuration
    @AppStorage("api_base_url") private var storedBaseURL = "http://localhost:11434"
    @AppStorage("api_model") private var storedModelName = "llama3.2-vision:latest"
    @AppStorage("api_key") private var storedAPIKey = ""
    @AppStorage("api_timeout") private var storedTimeout = 60.0
    @AppStorage("api_temperature") private var storedTemperature = 0.7
    @AppStorage("api_type") private var storedAPIType = "ollama"
    @AppStorage("enable_llm_processing") private var enableLLMProcessing = true

    private let baseURL: String
    private let modelName: String
    private let apiKey: String?
    private let timeout: TimeInterval
    private let temperature: Double
    private let apiType: String

    enum APIType: String {
        case ollama = "ollama"
        case openai = "openai"
        case custom = "custom"
    }

    init(baseURL: String? = nil, modelName: String? = nil, apiKey: String? = nil) {
        self.baseURL = (baseURL ?? storedBaseURL).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.modelName = modelName ?? storedModelName
        self.apiKey = apiKey ?? (storedAPIKey.isEmpty ? nil : storedAPIKey)
        self.timeout = storedTimeout
        self.temperature = storedTemperature
        self.apiType = storedAPIType
    }

    var isEnabled: Bool {
        return enableLLMProcessing
    }

    // MARK: - Data Models
    struct OllamaRequest: Codable {
        let model: String
        let prompt: String
        let images: [String]
        let format: String
        let stream: Bool
        let options: RequestOptions
    }

    struct RequestOptions: Codable {
        let temperature: Double
    }

    struct OllamaResponse: Codable {
        let response: String
    }

    struct DetailedReceiptData: Codable {
        let receiptType: String?
        let vendorInfo: VendorInfo?
        let transactionInfo: TransactionInfo?
        let items: [LineItem]?
        let totals: Totals?
        let notes: Notes?

        enum CodingKeys: String, CodingKey {
            case receiptType = "receipt_type"
            case vendorInfo = "vendor_info"
            case transactionInfo = "transaction_info"
            case items, totals, notes
        }
    }

    struct VendorInfo: Codable {
        let vendor: String? // Existing, to be simplified by LLM
        let store_name: String? // New
        let slogan: String? // New
        let address: String?
        let city: String? // Ensure lowercase
        let state: String? // Ensure postal abbreviation
        let zipCode: String?
        let phone: String?
        let website: String?
        let taxId: String?

        enum CodingKeys: String, CodingKey {
            case vendor, address, city, state, phone, website
            case store_name = "store_name"
            case slogan
            case zipCode = "zip_code"
            case taxId = "tax_id"
        }
    }

    struct TransactionInfo: Codable {
        let date: String? // YYYY/MM/DD
        let time: String?
        let transactionId: String?
        let paymentMethod: String?
        let cashier: String?
        let register: String?
        let customer_name: String? // New
        let customer_number: String? // New
        let card_ending: String? // New
        let auth_code: String? // New
        let return_policy: String? // New
        let promotions: [Promotion]? // New
        let code_definitions: [String: String]? // New

        enum CodingKeys: String, CodingKey {
            case date, time, cashier, register
            case transactionId = "transaction_id"
            case paymentMethod = "payment_method"
            case customer_name, customer_number, card_ending, auth_code, return_policy, promotions, code_definitions
        }
    }

    struct Promotion: Codable { // New for TransactionInfo.promotions
        let promo_type: String?
        let details: String?
    }

    struct LineItem: Codable {
        let description: String?
        let quantity: Double?
        let unitPrice: Double? // Or gal_price for fuel
        let unit_subtotal: Double? // New
        let totalPrice: Double?
        let taxCategory: String?
        let expenseCategory: String?
        let sku: String?
        // let discounts: Double? // Existing, seems redundant if 'discount' (singular) is preferred for line item
        let discount: Double? // New (line-item specific discount amount, positive value)
        let codes: [String]? // New
        let is_expense: Bool? // New
        let needs_review: Bool? // New

        enum CodingKeys: String, CodingKey {
            case description, quantity, sku, discount, codes, is_expense, needs_review // 'discounts' removed, 'discount' added
            case unitPrice = "unit_price" // or "gal_price" based on context
            case unit_subtotal = "unit_subtotal"
            case totalPrice = "total_price"
            case taxCategory = "tax_category"
            case expenseCategory = "expense_category"
        }
    }

    struct Totals: Codable {
        let subtotal: Double?
        let tax: Double?
        let tip: Double?
        let discount: Double? // Overall discount
        let total: Double?
        let cashback: Double?
        let change: Double?
        let taxRate: Double? // Ensure present

        enum CodingKeys: String, CodingKey {
            case subtotal, tax, tip, discount, total, change
            case taxRate = "tax_rate"
            case cashback = "cash_back"
        }
    }

    struct Notes: Codable {
        let handwriting: String?
        let description: String? // May include "[Vehicle] [Mileage] [Trip]"
        let vehicle: String?
        let mileage: String? // Corrected spelling from "milage"
        let trip: String?
        let businessPurpose: String?
        let rawText: String?

        enum CodingKeys: String, CodingKey {
            case handwriting, description, vehicle, mileage, trip // mileage spelling corrected
            case businessPurpose = "business_purpose"
            case rawText = "raw_text"
        }
    }

    // MARK: - OpenAI-Compatible Data Models (Can remain as is unless prompt changes affect this)
    struct OpenAIRequest: Codable {
        let model: String
        let messages: [OpenAIMessage]
        let max_tokens: Int?
        let temperature: Double?

        struct OpenAIMessage: Codable {
            let role: String
            let content: [OpenAIContent]

            struct OpenAIContent: Codable {
                let type: String
                let text: String?
                let image_url: OpenAIImageURL?

                struct OpenAIImageURL: Codable {
                    let url: String
                }
            }
        }
    }

    struct OpenAIResponse: Codable {
        let choices: [OpenAIChoice]

        struct OpenAIChoice: Codable {
            let message: OpenAIMessage

            struct OpenAIMessage: Codable {
                let content: String
            }
        }
    }

    // MARK: - Main Processing Method
    func processReceiptWithLLM(image: UIImage, basicOCRText: String?) async throws -> Receipt {
        print("🤖 OllamaService: Starting LLM processing for receipt")

        guard let base64Image = encodeImageToBase64(image) else {
            throw OllamaError.imageEncodingFailed
        }

        let prompt = createDetailedPrompt()

        let request = OllamaRequest(
            model: modelName,
            prompt: prompt,
            images: [base64Image],
            format: "json",
            stream: false,
            options: RequestOptions(temperature: temperature) // Using configured temperature
        )

        do {
            let detailedData = try await sendRequest(request)
            let receipt = mapToReceipt(detailedData: detailedData, originalOCR: basicOCRText, image: image)

            print("✅ OllamaService: Successfully processed receipt with LLM")
            return receipt

        } catch {
            print("❌ OllamaService: Error processing with LLM: \(error)")

            // Fallback to basic processing if LLM fails
            return createFallbackReceipt(ocr: basicOCRText, image: image)
        }
    }

    // MARK: - Private Methods
    private func encodeImageToBase64(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        return imageData.base64EncodedString()
    }

    private func createDetailedPrompt() -> String {
        return """
You are an expert financial document parser. Analyze the provided receipt image and extract data into a **single, valid JSON object**. Do NOT include any explanatory text before or after the JSON.

**JSON Output Structure:**
{
  "receipt_type": "String (e.g., 'Retail Sale', 'Fuel Receipt', 'Restaurant Dining', 'Service Invoice', 'Travel Itinerary', 'Subscription Confirmation', 'Utility Bill', 'Healthcare Bill', 'Financial Statement', 'Other')",
  "vendor_info": {
    "store_name": "String (Simplified, common name, e.g., 'Walmart', 'Starbucks', 'Shell')",
    "slogan": "String (If clearly visible, otherwise null)",
    "vendor": "String (Full legal or displayed name from receipt)",
    "address": "String (Street address)",
    "city": "String (Lowercase, e.g., 'new york')",
    "state": "String (2-letter postal abbreviation, e.g., 'NY')",
    "zip_code": "String (5 or 9 digit)",
    "phone": "String (XXX-XXX-XXXX format if possible)",
    "website": "String (Homepage if available, e.g., www.example.com)",
    "tax_id": "String (e.g., EIN, VAT ID, if present)"
  },
  "transaction_info": {
    "date": "String (YYYY/MM/DD format)",
    "time": "String (HH:MM:SS or HH:MM AM/PM)",
    "transaction_id": "String (Transaction or receipt number)",
    "payment_method": "String (e.g., 'Visa', 'MasterCard', 'Amex', 'Discover', 'Cash', 'Check', 'Mobile Pay', 'Gift Card')",
    "card_ending": "String (Last 4 digits of card, if available)",
    "auth_code": "String (Authorization code, if available)",
    "cashier": "String (Cashier name or ID)",
    "register": "String (Register or terminal ID)",
    "customer_name": "String (If present, e.g., on an invoice or loyalty receipt)",
    "customer_number": "String (Loyalty card or customer ID, if present)",
    "return_policy": "String (Brief summary if clearly stated, e.g., '30-day return policy')",
    "promotions": [
      { "promo_type": "String (e.g., 'Discount', 'Coupon', 'Loyalty Points')", "details": "String (e.g., '$5 Off', '20% Discount on Item X', '100 points earned')" }
    ],
    "code_definitions": {
      "F": "Food Item (Taxable)",
      "N": "Non-Food Item (Non-Taxable)",
      "T": "Taxable Item"
    }
  },
  "items": [
    {
      "description": "String (Item description)",
      "quantity": "Number (e.g., 1, 1.5, if not present assume 1)",
      "unit_price": "Number (Price per unit, or gal_price for fuel)",
      "unit_subtotal": "Number (Subtotal for this line if quantity > 1, before discounts/taxes for this line)",
      "total_price": "Number (Total price for this line after quantity and line-specific discounts/taxes if applicable)",
      "tax_category": "String (e.g., 'Taxable', 'Non-Taxable', specific tax code like 'F')",
      "expense_category": "String (Choose from provided list)",
      "sku": "String (Item Stock Keeping Unit or product code)",
      "discount": "Number (Line-item specific discount amount, positive value)",
      "codes": ["String (List of codes applicable to this item, e.g., 'F', 'T')"],
      "is_expense": "Boolean (True if likely a business expense, false if clearly personal, null if unsure. Default to true for most items unless explicitly personal like 'Personal Shopping')",
      "needs_review": "Boolean (True if uncertain about any field for this item)"
    }
  ],
  "totals": {
    "subtotal": "Number (Overall subtotal before taxes and main discount)",
    "tax": "Number (Total sales tax amount)",
    "tax_rate": "Number (Calculated or stated overall tax rate, e.g., 0.085 for 8.5%)",
    "tip": "Number (Tip or gratuity amount)",
    "discount": "Number (Overall discount amount applied to subtotal, positive value)",
    "total": "Number (Final amount paid)",
    "cash_back": "Number (If applicable)",
    "change": "Number (If paid with cash and change given)"
  },
  "notes": {
    "handwriting": "String (Transcribe any handwritten notes on the receipt)",
    "description": "String (A general description of the receipt. For gas/fuel receipts, if vehicle, mileage, or trip info is found on the receipt (not handwritten), include it here in the format '[Vehicle] [Mileage] [Trip]', e.g., 'Pump 5 12345 miles Business Trip'. Otherwise, general notes like 'Lunch meeting with client' or 'Office supplies purchase'.)",
    "vehicle": "String (Vehicle identifier like license plate, make/model, or pump number if clearly associated, mainly for fuel/auto service)",
    "mileage": "String (Odometer reading if present, e.g., '12345 mi')",
    "trip": "String (Trip purpose or ID if noted, e.g., 'Client Visit X', 'Project Y Delivery')",
    "business_purpose": "String (Suggest a concise business purpose based on items and vendor. Use provided examples.)",
    "raw_text": "String (The full, raw OCR text extracted from the receipt, if available as input to you. If not, make this null.)"
  }
}

**Tax Categories for 'expense_category':**
- Office Supplies
- Travel
- Meals & Entertainment
- Fuel & Vehicle
- Professional Services
- Marketing & Advertising
- Utilities
- Rent & Facilities
- Insurance
- Equipment & Technology
- Training & Education
- Medical & Health (Business-related)
- Home & Garden (Business property)
- Groceries & Food (Business, distinct from meals)
- Clothing & Personal (Business-related, e.g., uniforms)
- Gifts & Entertainment (Business gifts)
- Banking & Finance
- Shipping & Postage
- Other Business
- Personal

**Parsing Rules & Instructions:**
1.  **Vendor Simplification:** For `vendor_info.store_name`, use common names (e.g., "Home Depot" not "HOME DEPOT #1234"). `vendor_info.vendor` should be the full name.
2.  **Date Format:** `transaction_info.date` MUST be YYYY/MM/DD.
3.  **Lowercase City:** `vendor_info.city` must be lowercase.
4.  **State Abbreviation:** `vendor_info.state` must be 2-letter postal abbreviation (e.g., CA, NY, TX).
5.  **Numeric Values:** All prices, totals, quantities, rates MUST be numbers (integer or decimal), not strings. Use null if not present.
6.  **Boolean Values:** Use true/false, not strings.
7.  **Fuel Receipts:** If `receipt_type` is "Fuel Receipt", `items[0].unit_price` can be labeled `gal_price` in thought process but use `unit_price` in JSON. Extract gallons if possible for quantity.
8.  **Business Purpose Examples:**
    - Fuel: "Business travel - fuel for [Vehicle]"
    - Meals: "Business meal with [Client/Colleague Name if identifiable, else 'team/client'] at [Vendor Name]"
    - Office Supplies: "Office supplies for [Company/Department if identifiable]"
9.  **`notes.description` for Fuel:** If vehicle/mileage/trip data is found PRINTED on a fuel receipt, append it to `notes.description` in format "[Vehicle] [Mileage] [Trip]". Otherwise, `notes.vehicle`, `notes.mileage`, `notes.trip` capture this.
10. **`items.is_expense`:** Default to true. Set to false only if an item is unambiguously personal (e.g., "Personal Magazine" at a grocery store alongside business items).
11. **`items.needs_review`:** Set to true if any part of the line item is ambiguous or confidence is low for that item.
12. **Return ONLY JSON:** No introductory text, no explanations, no markdown `json` block, just the raw JSON object.

Analyze the receipt image and provide the structured JSON output.
"""
    }

    private func sendRequest(_ request: OllamaRequest) async throws -> DetailedReceiptData {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Log more details for non-200 responses
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ OllamaService: Request failed. Status: \( (response as? HTTPURLResponse)?.statusCode ?? -1), Body: \(responseBody)")
            throw OllamaError.requestFailed
        }

        let decoder = JSONDecoder()
        let ollamaResponse: OllamaResponse
        do {
            ollamaResponse = try decoder.decode(OllamaResponse.self, from: data)
        } catch {
            print("❌ OllamaService: Failed to decode OllamaResponse (outer shell). Error: \(error)")
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("Raw response body: \(responseBody)")
            throw OllamaError.decodingFailed
        }

        // Parse the nested JSON response string
        guard let responseData = ollamaResponse.response.data(using: .utf8) else {
            print("❌ OllamaService: Nested JSON string is nil or invalid UTF-8.")
            throw OllamaError.invalidResponse
        }

        do {
            let detailedData = try decoder.decode(DetailedReceiptData.self, from: responseData)
            return detailedData
        } catch {
            print("❌ OllamaService: Failed to decode DetailedReceiptData (nested JSON). Error: \(error)")
            let jsonString = String(data: responseData, encoding: .utf8) ?? "Invalid JSON string"
            print("Raw nested JSON string: \(jsonString)")
            throw OllamaError.decodingFailed
        }
    }

    // Updated mapToReceipt function signature to include image
    private func mapToReceipt(detailedData: DetailedReceiptData, originalOCR: String?, image: UIImage?) -> Receipt {
        // Vendor mapping
        let vendorName = detailedData.vendorInfo?.store_name ?? detailedData.vendorInfo?.vendor ?? "Unknown Vendor"
        // Additional vendor details for notes or future fields
        // let slogan = detailedData.vendorInfo?.slogan
        // let fullAddress = [detailedData.vendorInfo?.address, detailedData.vendorInfo?.city, detailedData.vendorInfo?.state, detailedData.vendorInfo?.zipCode].compactMap { $0 }.joined(separator: ", ")

        // Date mapping (ensure YYYY/MM/DD is parsed correctly)
        let date = parseDate(from: detailedData.transactionInfo?.date) ?? Date()
        // let time = detailedData.transactionInfo?.time // Available if needed

        // Totals mapping
        let amount = detailedData.totals?.total
        let subtotal = detailedData.totals?.subtotal
        let taxAmount = detailedData.totals?.tax
        let tipAmount = detailedData.totals?.tip
        let taxRate = detailedData.totals?.taxRate
        // let discount = detailedData.totals?.discount // Overall discount

        // Category mapping (more sophisticated logic might be needed based on items)
        let category = determinePrimaryCategory(from: detailedData.items) ??
                       mapReceiptTypeToCategory(detailedData.receiptType) ??
                       "Other Business"

        // Location mapping
        var locationParts: [String] = []
        if let city = detailedData.vendorInfo?.city { locationParts.append(city.lowercased()) } // Ensure city is lowercase
        if let state = detailedData.vendorInfo?.state { locationParts.append(state.uppercased()) } // Ensure state is uppercase postal
        let location = locationParts.isEmpty ? nil : locationParts.joined(separator: ", ")

        // Notes and other textual info
        // let handwrittenNotes = detailedData.notes?.handwriting
        let descriptionNotes = detailedData.notes?.description // May contain vehicle/mileage/trip
        let businessPurpose = detailedData.notes?.businessPurpose // Already mapped in Receipt.swift

        // New fields from TransactionInfo - not directly mapped to Receipt.swift yet, store in notes or log for now
        // let customerName = detailedData.transactionInfo?.customer_name
        // let customerNumber = detailedData.transactionInfo?.customer_number
        // let cardEnding = detailedData.transactionInfo?.card_ending
        // let authCode = detailedData.transactionInfo?.auth_code
        // let returnPolicy = detailedData.transactionInfo?.return_policy
        // let promotions = detailedData.transactionInfo?.promotions // List of Promotion structs
        // let codeDefinitions = detailedData.transactionInfo?.code_definitions // Dictionary
        // Example: if promotions != nil && !promotions!.isEmpty { descriptionNotes = (descriptionNotes ?? "") + " Promotions: \(promotions!)" }


        // Line items - complex mapping. For now, not directly mapping to Receipt.items.
        // `is_expense` and `needs_review` per item are not directly used yet.
        // let itemDescriptions = detailedData.items?.compactMap { $0.description }.joined(separator: "; ")

        // Vehicle and Mileage
        let vehicleInfo = detailedData.notes?.vehicle
        let mileageInfo = detailedData.notes?.mileage // Corrected spelling

        // Confidence & Review
        let confidence = calculateConfidence(for: detailedData)
        let needsReview = confidence < 0.7 || amount == nil || amount == 0.0 || vendorName == "Unknown Vendor" || (detailedData.items?.contains(where: { $0.needs_review == true }) ?? false)


        return Receipt(
            id: UUID(),
            imageData: image?.jpegData(compressionQuality: 0.8),
            vendor: vendorName,
            amount: amount,
            date: date,
            category: category,
            notes: descriptionNotes,
            rawText: detailedData.notes?.rawText,
            confidence: confidence,
            paymentMethod: detailedData.transactionInfo?.paymentMethod,
            location: location,
            tags: [],
            needsReview: needsReview,
            createdAt: Date(),
            updatedAt: Date(),
            taxCategory: category,
            businessPurpose: businessPurpose,
            subtotal: subtotal,
            taxAmount: taxAmount,
            tipAmount: tipAmount,
            taxRate: taxRate,
            transactionId: detailedData.transactionInfo?.transactionId,
            vendorTaxId: detailedData.vendorInfo?.taxId,
            mileage: mileageInfo,
            vehicleInfo: vehicleInfo,
            receiptType: detailedData.receiptType,
            rawOCRText: originalOCR,
            confidenceScore: confidence
        )
    }

    // Updated createFallbackReceipt to include image
    private func createFallbackReceipt(ocr: String?, image: UIImage?) -> Receipt {
        return Receipt(
            id: UUID(),
            imageData: image?.jpegData(compressionQuality: 0.8),
            vendor: "Unknown Vendor",
            amount: nil,
            date: Date(),
            category: "Other Business",
            paymentMethod: nil,
            location: nil,
            notes: "LLM processing failed - manual review required. OCR text available.",
            rawText: ocr,
            confidence: 0.3,
            needsReview: true,
            createdAt: Date(),
            updatedAt: Date(),
            taxCategory: "Other Business",
            businessPurpose: "LLM processing failed, requires manual review.",
            rawOCRText: ocr,
            confidenceScore: 0.3
        )
    }

    private func parseDate(from dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatters = [
            "yyyy/MM/dd",
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "dd/MM/yyyy",
            "dd-MM-yyyy"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.autoupdatingCurrent // Use local timezone for date interpretation
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        print("⚠️ OllamaService: Failed to parse date string: \(dateString)")
        return nil
    }

    private func determinePrimaryCategory(from items: [LineItem]?) -> String? {
        guard let items = items, !items.isEmpty else { return nil }

        let categoryCounts = items.compactMap { $0.expenseCategory }.reduce(into: [:]) { counts, category in
            counts[category, default: 0] += 1
        }

        return categoryCounts.max(by: { $0.value < $1.value })?.key
    }

    private func mapReceiptTypeToCategory(_ receiptType: String?) -> String? {
        guard let type = receiptType?.lowercased() else { return nil }

        if type.contains("fuel") || type.contains("gas") || type.contains("gasoline") ||
           type.contains("diesel") || type.contains("auto") || type.contains("vehicle") ||
           type.contains("maintenance") || type.contains("car wash") || type.contains("oil change") {
            return "Fuel & Vehicle"
        }
        if type.contains("restaurant") || type.contains("food") || type.contains("dining") ||
           type.contains("cafe") || type.contains("coffee") || type.contains("bar") ||
           type.contains("catering") || type.contains("meal") {
            return "Meals & Entertainment"
        }
        if type.contains("gift") || type.contains("flower") || type.contains("basket") ||
           (type.contains("entertainment") && !type.contains("meal") && !type.contains("food")) {
            return "Gifts & Entertainment"
        }
        if type.contains("office") || type.contains("supplies") || type.contains("stationery") ||
           type.contains("equipment") || type.contains("software") {
            return "Office Supplies" // Or "Equipment & Technology" for software/equipment
        }
        if type.contains("travel") || type.contains("hotel") || type.contains("airline") ||
           type.contains("flight") || type.contains("lodging") || type.contains("rental") {
            return "Travel"
        }
        if type.contains("grocery") || type.contains("supermarket") || type.contains("market") {
            return "Groceries & Food"
        }
        if type.contains("legal") || type.contains("accounting") || type.contains("consulting") ||
           type.contains("professional") || type.contains("service") && !type.contains("auto") {
            return "Professional Services"
        }
        if type.contains("bank") || type.contains("finance") || type.contains("payment") ||
           type.contains("fee") || type.contains("interest") {
            return "Banking & Finance"
        }
        if type.contains("clothing") || type.contains("apparel") {
            return "Clothing & Personal"
        }
        if type.contains("medical") || type.contains("health") || type.contains("pharmacy") {
            return "Medical & Health"
        }
        if type.contains("shipping") || type.contains("postage") || type.contains("courier") {
            return "Shipping & Postage"
        }
        if type.contains("utility") || type.contains("utilities") {
            return "Utilities"
        }
        if type.contains("insurance") {
            return "Insurance"
        }
        if type.contains("rent") || type.contains("lease") && !type.contains("car") && !type.contains("vehicle") {
            return "Rent & Facilities"
        }
        if type.contains("marketing") || type.contains("advertising") {
            return "Marketing & Advertising"
        }
        if type.contains("education") || type.contains("training") || type.contains("conference") {
            return "Training & Education"
        }
        if type.contains("technology") && !type.contains("office supplies"){ // If not already office supplies
             return "Equipment & Technology"
        }


        return "Other Business"
    }

    private func extractVehicleAndMileageInfo(from detailedData: DetailedReceiptData) -> (vehicleInfo: String?, mileageInfo: String?) {
        return (detailedData.notes?.vehicle, detailedData.notes?.mileage)
    }

    private func buildNotesString(from notesData: Notes?) -> String? {
        guard let notes = notesData else { return nil }
        var noteParts: [String] = []
        if let desc = notes.description, !desc.isEmpty { noteParts.append(desc) }
        if let handwriting = notes.handwriting, !handwriting.isEmpty { noteParts.append("Handwritten: \(handwriting)") }
        return noteParts.isEmpty ? nil : noteParts.joined(separator: " | ")
    }

    private func calculateConfidence(for data: DetailedReceiptData) -> Double {
        var score = 0.0
        var maxScorePossible = 0.0

        maxScorePossible += 2.0 // Vendor info
        if data.vendorInfo?.store_name != nil || data.vendorInfo?.vendor != nil { score += 1.0 }
        if data.vendorInfo?.city != nil || data.vendorInfo?.state != nil || data.vendorInfo?.address != nil { score += 1.0 }

        maxScorePossible += 2.0 // Transaction info
        if data.transactionInfo?.date != nil { score += 1.0 }
        if data.transactionInfo?.paymentMethod != nil { score += 0.5 }
        if data.transactionInfo?.transactionId != nil { score += 0.5}

        maxScorePossible += 2.0 // Totals
        if let total = data.totals?.total, total != 0  { score += 1.5 }
        if data.totals?.subtotal != nil { score += 0.5 }

        maxScorePossible += 1.0 // Items presence
        if let items = data.items, !items.isEmpty {
            score += 1.0
            maxScorePossible += 1.0 // Bonus for detailed items
            if items.allSatisfy({ $0.description != nil && $0.totalPrice != nil }) {
                score += 1.0
            }
            if items.contains(where: { $0.needs_review == true }) { // Penalize if any item needs review
                score -= 0.5
            }
        }

        maxScorePossible += 0.5 // Receipt Type
        if data.receiptType != nil { score += 0.5 }

        return maxScorePossible > 0 ? max(0, min(score / maxScorePossible, 1.0)) : 0.0 // Ensure score is not negative
    }
}

// MARK: - Error Types
enum OllamaError: Error, LocalizedError {
    case invalidURL
    case imageEncodingFailed
    case requestFailed
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama server URL"
        case .imageEncodingFailed:
            return "Failed to encode image to base64"
        case .requestFailed:
            return "Failed to send request to Ollama server. Check server status and endpoint/model configuration in Settings."
        case .invalidResponse:
            return "Invalid response structure from Ollama server."
        case .decodingFailed:
            return "Failed to decode Ollama response. The JSON structure might be incorrect or unexpected."
        }
    }
}

// MARK: - Connection Testing (Can remain as is)
extension OllamaService {
    func testConnection(apiKey: String? = nil) async -> Bool {
        guard isEnabled else { return true }

        do {
            let currentAPIType = APIType(rawValue: apiType) ?? .ollama

            switch currentAPIType {
            case .ollama:
                return await testOllamaConnection()
            case .openai, .custom:
                return await testOpenAIConnection(apiKey: apiKey ?? self.apiKey)
            }
        } catch {
            print("❌ Connection test failed: \(error)")
            return false
        }
    }

    private func testOllamaConnection() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    private func testOpenAIConnection(apiKey: String?) async -> Bool {
        guard let apiKey = apiKey, !apiKey.isEmpty else { return false }
        // Corrected common OpenAI endpoint for listing models
        let openAIModelsURL = baseURL.contains("api.openai.com") ? "\(baseURL)/models" : "\(baseURL)/v1/models"
        guard let url = URL(string: openAIModelsURL) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Enhanced Processing Methods (OpenAI part can remain as is for now)
    func processReceiptWithOpenAI(image: UIImage, ocrText: String) async throws -> Receipt {
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            throw OllamaError.invalidResponse // Or a more specific API key error
        }

        guard let imageBase64 = encodeImageToBase64(image) else { // Corrected call
             throw OllamaError.imageEncodingFailed
        }
        // Use the same detailed prompt for OpenAI for consistency in expected JSON output
        let promptText = createDetailedPrompt()

        let requestPayload = OpenAIRequest(
            model: modelName, // Ensure this model is compatible with OpenAI endpoint
            messages: [
                OpenAIRequest.OpenAIMessage(
                    role: "user",
                    content: [
                        OpenAIRequest.OpenAIMessage.OpenAIContent(
                            type: "text",
                            text: promptText,
                            image_url: nil
                        ),
                        OpenAIRequest.OpenAIMessage.OpenAIContent(
                            type: "image_url",
                            text: nil,
                            image_url: OpenAIRequest.OpenAIMessage.OpenAIContent.OpenAIImageURL(
                                url: "data:image/jpeg;base64,\(imageBase64)"
                            )
                        )
                    ]
                )
            ],
            max_tokens: 4096, // Increased max_tokens for potentially larger JSON output
            temperature: temperature
        )

        let openAIChatCompletionsURL = baseURL.contains("api.openai.com") ? "\(baseURL)/chat/completions" : "\(baseURL)/v1/chat/completions"
        guard let url = URL(string: openAIChatCompletionsURL) else {
            throw OllamaError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = timeout

        let requestData = try JSONEncoder().encode(requestPayload)
        urlRequest.httpBody = requestData

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ OpenAI API Request failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1), Body: \(responseBody)")
            throw OllamaError.requestFailed
        }

        let openAIResponse: OpenAIResponse
        do {
            openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            print("❌ OpenAI API: Failed to decode OpenAIResponse. Error: \(error)")
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("Raw response body: \(responseBody)")
            throw OllamaError.decodingFailed
        }

        guard let content = openAIResponse.choices.first?.message.content else {
            throw OllamaError.invalidResponse
        }

        // The content from OpenAI should also be a JSON string.
        // It needs to be parsed into DetailedReceiptData.
        // Clean the string: remove potential markdown ```json ... ``` and leading/trailing whitespace
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let responseData = jsonString.data(using: .utf8) else {
            print("❌ OpenAI API: Response content string is nil or invalid UTF-8 after cleaning.")
            throw OllamaError.invalidResponse
        }

        do {
            let detailedData = try JSONDecoder().decode(DetailedReceiptData.self, from: responseData)
            return mapToReceipt(detailedData: detailedData, originalOCR: ocrText, image: image)
        } catch {
            print("❌ OpenAI API: Failed to decode DetailedReceiptData from OpenAI response. Error: \(error)")
            let cleanedJsonString = String(data: responseData, encoding: .utf8) ?? "Invalid JSON string"
            print("Cleaned nested JSON string from OpenAI: \(cleanedJsonString)")
            throw OllamaError.decodingFailed
        }
    }

    // Main entry point for AI processing
    func processReceiptWithAI(image: UIImage, ocrText: String) async throws -> Receipt {
        guard isEnabled else {
            return createBasicReceipt(from: ocrText, image: image)
        }

        let currentAPIType = APIType(rawValue: apiType) ?? .ollama

        switch currentAPIType {
        case .ollama:
            return try await processReceiptWithOllama(image: image, basicOCRText: ocrText)
        case .openai, .custom:
            return try await processReceiptWithOpenAI(image: image, ocrText: ocrText)
        }
    }

    private func createBasicReceipt(from ocrText: String, image: UIImage?) -> Receipt {
        print("ℹ️ OllamaService: AI processing disabled or failed catastrophically. Creating basic receipt from OCR text.")
        return Receipt(
            id: UUID(),
            imageData: image?.jpegData(compressionQuality: 0.8),
            vendor: "Unknown (OCR only)",
            amount: nil,
            date: Date(),
            category: "Needs Review",
            notes: "Processed with OCR only. AI analysis was disabled or failed.",
            rawText: ocrText,
            confidence: 0.2,
            needsReview: true,
            createdAt: Date(),
            updatedAt: Date(),
            taxCategory: "Needs Review",
            businessPurpose: "Needs manual categorization.",
            rawOCRText: ocrText,
            confidenceScore: 0.2
        )
    }
}
