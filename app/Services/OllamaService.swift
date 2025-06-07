import Foundation
import UIKit

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
        let vendor: String?
        let address: String?
        let city: String?
        let state: String?
        let zipCode: String?
        let phone: String?
        let website: String?
        let taxId: String?
        
        enum CodingKeys: String, CodingKey {
            case vendor, address, city, state, phone, website
            case zipCode = "zip_code"
            case taxId = "tax_id"
        }
    }
    
    struct TransactionInfo: Codable {
        let date: String?
        let time: String?
        let transactionId: String?
        let paymentMethod: String?
        let cashier: String?
        let register: String?
        
        enum CodingKeys: String, CodingKey {
            case date, time, cashier, register
            case transactionId = "transaction_id"
            case paymentMethod = "payment_method"
        }
    }
    
    struct LineItem: Codable {
        let description: String?
        let quantity: Double?
        let unitPrice: Double?
        let totalPrice: Double?
        let taxCategory: String?
        let expenseCategory: String?
        let sku: String?
        let discounts: Double?
        
        enum CodingKeys: String, CodingKey {
            case description, quantity, sku, discounts
            case unitPrice = "unit_price"
            case totalPrice = "total_price"
            case taxCategory = "tax_category"
            case expenseCategory = "expense_category"
        }
    }
    
    struct Totals: Codable {
        let subtotal: Double?
        let tax: Double?
        let tip: Double?
        let discount: Double?
        let total: Double?
        let cashback: Double?
        let change: Double?
        let taxRate: Double?
        
        enum CodingKeys: String, CodingKey {
            case subtotal, tax, tip, discount, total, change
            case taxRate = "tax_rate"
            case cashback = "cash_back"
        }
    }
    
    struct Notes: Codable {
        let handwriting: String?
        let description: String?
        let vehicle: String?
        let mileage: String?
        let trip: String?
        let businessPurpose: String?
        let rawText: String?
        
        enum CodingKeys: String, CodingKey {
            case handwriting, description, vehicle, mileage, trip
            case businessPurpose = "business_purpose"
            case rawText = "raw_text"
        }
    }
    
    // MARK: - OpenAI-Compatible Data Models
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
            options: RequestOptions(temperature: 0.0)
        )
        
        do {
            let detailedData = try await sendRequest(request)
            let receipt = mapToReceipt(detailedData: detailedData, originalOCR: basicOCRText)
            
            print("✅ OllamaService: Successfully processed receipt with LLM")
            return receipt
            
        } catch {
            print("❌ OllamaService: Error processing with LLM: \(error)")
            
            // Fallback to basic processing if LLM fails
            return createFallbackReceipt(ocr: basicOCRText)
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
        You are a financial document parser specialized in receipt analysis for tax preparation and business expense tracking.

        Analyze the receipt image and extract comprehensive structured data into JSON format with six main sections: receipt_type, vendor_info, transaction_info, items, totals, and notes.

        **Required JSON Structure:**

        {
          "receipt_type": "string",               
          "vendor_info": {
            "vendor": "string",                   
            "address": "string",                  
            "city": "string",                     
            "state": "string",
            "zip_code": "string",
            "phone": "string",
            "website": "string",
            "tax_id": "string"
          },
          "transaction_info": {
            "date": "YYYY-MM-DD",
            "time": "HH:MM:SS",
            "transaction_id": "string",
            "payment_method": "string",
            "cashier": "string",
            "register": "string"
          },
          "items": [
            {
              "description": "string",
              "quantity": number,
              "unit_price": number,
              "total_price": number,
              "tax_category": "string",
              "expense_category": "string",
              "sku": "string",
              "discounts": number
            }
          ],
          "totals": {
            "subtotal": number,
            "tax": number,
            "tip": number,
            "discount": number,
            "total": number,
            "cash_back": number,
            "change": number,
            "tax_rate": number
          },
          "notes": {
            "handwriting": "string",
            "description": "string",
            "vehicle": "string",
            "mileage": "string",
            "trip": "string",
            "business_purpose": "string",
            "raw_text": "string"
          }
        }

        **Enhanced Tax Categories for expense_category (choose most appropriate):**
        - "Office Supplies" - pens, paper, software, equipment, stationery
        - "Travel" - hotels, flights, car rentals, mileage, lodging, airfare
        - "Meals & Entertainment" - restaurants, client dinners, business meals, coffee meetings
        - "Fuel & Vehicle" - gasoline, diesel, vehicle maintenance, repairs, parking, tolls, car wash
        - "Professional Services" - legal fees, accounting, consulting, contract services
        - "Marketing & Advertising" - ads, promotional materials, business cards, website costs
        - "Utilities" - internet, phone, electricity, water, business facility costs
        - "Rent & Facilities" - office rent, storage, coworking spaces, facility maintenance
        - "Insurance" - business insurance policies, liability, property, vehicle insurance
        - "Equipment & Technology" - computers, machinery, tools, software licenses, electronics
        - "Training & Education" - courses, conferences, books, certifications, workshops
        - "Medical & Health" - medical supplies, prescriptions, healthcare related to business
        - "Home & Garden" - maintenance supplies, landscaping (if business property)
        - "Groceries & Food" - grocery shopping, food supplies (separate from meals)
        - "Clothing & Personal" - uniforms, safety equipment, business attire
        - "Gifts & Entertainment" - client gifts, holiday gifts, gift baskets, gift cards
        - "Banking & Finance" - bank fees, loan interest, financial services
        - "Shipping & Postage" - shipping costs, postage, courier services, packaging
        - "Other Business" - miscellaneous business expenses that don't fit other categories
        - "Personal" - non-deductible personal expenses

        **Enhanced Business Detection Rules:**

        **Fuel & Vehicle Specific:**
        - Always extract gallons, price per gallon, and odometer readings
        - Look for vehicle information: license plate, pump number, vehicle type
        - Common fuel vendors: Shell, Chevron, Exxon, BP, Mobil, Arco, Valero, Speedway, Circle K
        - Extract mileage data from any handwritten notes or printed odometer readings
        - For vehicle maintenance: oil changes, tire service, brake service categorize as "Fuel & Vehicle"
        - Auto parts stores: AutoZone, O'Reilly, NAPA, Advance Auto Parts

        **Gift & Entertainment Detection:**
        - Gift baskets, flower arrangements, gift cards, corporate gifts
        - Holiday gifts, client appreciation gifts, business entertainment
        - Vendors: 1-800-Flowers, FTD, local florists, gift shops, wine shops
        - Amazon purchases with gift-related items
        - Restaurant receipts with multiple people (likely business meals)

        **Professional Services Enhanced:**
        - Legal: attorney fees, court filings, notary services
        - Accounting: tax preparation, bookkeeping, CPA services, payroll services
        - Consulting: business consulting, IT services, marketing consulting
        - Banking: business banking fees, merchant services, payment processing

        **Office & Technology Enhanced:**
        - Staples, Office Depot, Best Buy, Amazon Business, Costco Business
        - Software subscriptions: Microsoft Office, Adobe, QuickBooks, cloud services
        - Computer equipment, printers, monitors, networking equipment
        - Office furniture, supplies, paper, ink cartridges

        **Special Parsing Instructions:**

        **For Fuel Receipts:**
        - Extract vehicle info from pump displays or receipts
        - Look for odometer readings in notes or printed on receipt
        - Calculate cost per gallon and total gallons
        - Note fleet card usage or business credit cards
        - Extract location for mileage tracking

        **For Restaurant/Meal Receipts:**
        - Check for multiple people (party size, number of entrees)
        - Look for alcohol purchases (limited business deductibility)
        - Extract tip amounts separately for proper tax calculation
        - Note time of day (breakfast/lunch more likely business)
        - Check for business-related notes or meeting purposes

        **For Retail/Mixed Receipts:**
        - Separate business items from personal items when possible
        - Flag mixed purchases for manual review
        - Look for business-specific items: uniforms, safety equipment, tools
        - Check for bulk purchases indicating business use

        **For Gift/Entertainment:**
        - Identify recipient or business purpose
        - Note if items are promotional or client-related
        - Extract gift card amounts and vendors
        - Flag expensive gifts for IRS limit review

        **Vehicle Detection Patterns:**
        - License plate numbers, VIN numbers
        - Vehicle make/model mentioned
        - Fleet numbers or company vehicle identifiers
        - Odometer readings, mileage notations
        - Service intervals, maintenance schedules

        **Enhanced Accuracy Requirements:**
        - For unclear or missing information, use null rather than guessing
        - Maintain exact amounts and dates as written on receipt
        - Flag receipts needing manual review when confidence is low
        - Extract tax ID numbers for vendor verification when visible
        - Note any handwritten annotations for audit trail purposes
        - Identify sales tax rates for proper tax calculation
        - Return ONLY the JSON structure, no additional text

        **Business Purpose Generation:**
        Based on the receipt type and vendor, suggest appropriate business purposes:
        - Fuel: "Business travel - fuel expense"
        - Meals: "Business meal with [client/colleague]" or "Working lunch"
        - Office: "Office supplies for business operations"
        - Professional: "Professional services for business consulting"
        - Gifts: "Client appreciation gift" or "Holiday business gift"

        Analyze the provided receipt image now and return only the JSON structure.
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
            throw OllamaError.requestFailed
        }
        
        let decoder = JSONDecoder()
        let ollamaResponse = try decoder.decode(OllamaResponse.self, from: data)
        
        // Parse the nested JSON response
        guard let responseData = ollamaResponse.response.data(using: .utf8) else {
            throw OllamaError.invalidResponse
        }
        
        let detailedData = try decoder.decode(DetailedReceiptData.self, from: responseData)
        return detailedData
    }
      private func mapToReceipt(detailedData: DetailedReceiptData, originalOCR: String?) -> Receipt {
        let vendorName = detailedData.vendorInfo?.vendor ?? "Unknown Vendor"
        let date = parseDate(from: detailedData.transactionInfo?.date) ?? Date()
        let amount = detailedData.totals?.total ?? 0.0
        
        // Determine primary category from items
        let category = determinePrimaryCategory(from: detailedData.items) ?? 
                      mapReceiptTypeToCategory(detailedData.receiptType) ?? 
                      "Other Business"
        
        // Build location string
        var locationParts: [String] = []
        if let city = detailedData.vendorInfo?.city { locationParts.append(city) }
        if let state = detailedData.vendorInfo?.state { locationParts.append(state) }
        let location = locationParts.isEmpty ? nil : locationParts.joined(separator: ", ")
        
        // Combine notes
        let notes = buildNotesString(from: detailedData.notes)
        
        // Extract enhanced vehicle and mileage info
        let (vehicleInfo, mileageInfo) = extractVehicleAndMileageInfo(from: detailedData)
        
        // Calculate confidence based on data completeness
        let confidence = calculateConfidence(for: detailedData)
        
        // Determine if manual review is needed
        let needsReview = confidence < 0.7 || amount == 0.0 || vendorName == "Unknown Vendor"
        
        return Receipt(
            vendor: vendorName,
            amount: amount,
            date: date,
            category: category,
            paymentMethod: detailedData.transactionInfo?.paymentMethod,
            location: location,
            notes: notes,
            confidenceScore: confidence,
            needsReview: needsReview,
            rawOCRText: originalOCR,
            taxCategory: category,
            businessPurpose: detailedData.notes?.businessPurpose,
            subtotal: detailedData.totals?.subtotal,
            taxAmount: detailedData.totals?.tax,
            tipAmount: detailedData.totals?.tip,
            taxRate: detailedData.totals?.taxRate,
            transactionId: detailedData.transactionInfo?.transactionId,
            vendorTaxId: detailedData.vendorInfo?.taxId,
            mileage: mileageInfo,
            vehicleInfo: vehicleInfo,
            receiptType: detailedData.receiptType
        )
    }
    
    private func createFallbackReceipt(ocr: String?) -> Receipt {
        return Receipt(
            vendor: "Unknown Vendor",
            amount: 0.0,
            date: Date(),
            category: "Other Business",
            paymentMethod: nil,
            location: nil,
            notes: "LLM processing failed - manual review required",
            confidenceScore: 0.3,
            needsReview: true,
            rawOCRText: ocr,
            taxCategory: "Other Business",
            businessPurpose: nil
        )
    }
    
    private func parseDate(from dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatters = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "dd/MM/yyyy",
            "dd-MM-yyyy"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func determinePrimaryCategory(from items: [LineItem]?) -> String? {
        guard let items = items, !items.isEmpty else { return nil }
        
        // Return the most specific category from items
        return items.compactMap { $0.expenseCategory }.first
    }
      private func mapReceiptTypeToCategory(_ receiptType: String?) -> String? {
        guard let type = receiptType?.lowercased() else { return nil }
        
        // Fuel & Vehicle
        if type.contains("fuel") || type.contains("gas") || type.contains("gasoline") || 
           type.contains("diesel") || type.contains("auto") || type.contains("vehicle") ||
           type.contains("maintenance") || type.contains("car wash") || type.contains("oil change") {
            return "Fuel & Vehicle"
        }
        
        // Meals & Entertainment
        if type.contains("restaurant") || type.contains("food") || type.contains("dining") ||
           type.contains("cafe") || type.contains("coffee") || type.contains("bar") ||
           type.contains("catering") || type.contains("meal") {
            return "Meals & Entertainment"
        }
        
        // Gifts & Entertainment
        if type.contains("gift") || type.contains("flower") || type.contains("basket") ||
           type.contains("entertainment") || type.contains("card") || type.contains("bouquet") {
            return "Gifts & Entertainment"
        }
        
        // Office Supplies
        if type.contains("office") || type.contains("supplies") || type.contains("stationery") ||
           type.contains("equipment") || type.contains("software") {
            return "Office Supplies"
        }
        
        // Travel
        if type.contains("hotel") || type.contains("travel") || type.contains("airline") ||
           type.contains("flight") || type.contains("lodging") || type.contains("rental") {
            return "Travel"
        }
        
        // Grocery/Food Shopping
        if type.contains("grocery") || type.contains("supermarket") || type.contains("market") {
            return "Groceries & Food"
        }
        
        // Professional Services
        if type.contains("legal") || type.contains("accounting") || type.contains("consulting") ||
           type.contains("professional") || type.contains("service") {
            return "Professional Services"
        }
        
        // Banking & Finance
        if type.contains("bank") || type.contains("finance") || type.contains("payment") ||
           type.contains("fee") || type.contains("interest") {
            return "Banking & Finance"
        }
        
        return nil
    }
    
    private func extractVehicleAndMileageInfo(from detailedData: DetailedReceiptData) -> (vehicleInfo: String?, mileageInfo: String?) {
        var vehicleInfo: String? = nil
        var mileageInfo: String? = nil
        
        // Extract from notes section
        if let vehicle = detailedData.notes?.vehicle, !vehicle.isEmpty {
            vehicleInfo = vehicle
        }
        
        if let mileage = detailedData.notes?.mileage, !mileage.isEmpty {
            mileageInfo = mileage
        }
        
        // If not found in notes, try to extract from description or raw text
        if vehicleInfo == nil || mileageInfo == nil {
            let rawText = detailedData.notes?.rawText ?? ""
            let description = detailedData.notes?.description ?? ""
            let combinedText = "\(rawText) \(description)".lowercased()
            
            // Look for vehicle info patterns
            if vehicleInfo == nil {
                let vehiclePatterns = [
                    #"(?:pump|lane|position)\s*\#?\s*(\d+)"#,
                    #"(?:vehicle|car|truck)\s*\#?\s*([a-z0-9\-]+)"#,
                    #"(?:license|plate)\s*\#?\s*([a-z0-9\-]+)"#,
                    #"(?:fleet|unit)\s*\#?\s*([a-z0-9\-]+)"#
                ]
                
                for pattern in vehiclePatterns {
                    if let match = combinedText.range(of: pattern, options: .regularExpression) {
                        vehicleInfo = String(combinedText[match])
                        break
                    }
                }
            }
            
            // Look for mileage/odometer patterns
            if mileageInfo == nil {
                let mileagePatterns = [
                    #"(?:odometer|odo|mileage)\s*:?\s*(\d{1,6})"#,
                    #"(\d{1,6})\s*(?:miles|mi|km)"#,
                    #"(?:current|reading)\s*:?\s*(\d{1,6})"#
                ]
                
                for pattern in mileagePatterns {
                    if let match = combinedText.range(of: pattern, options: .regularExpression) {
                        mileageInfo = String(combinedText[match])
                        break
                    }
                }
            }
        }
        
        return (vehicleInfo, mileageInfo)
    }
    
    private func buildNotesString(from notes: Notes?) -> String? {
        guard let notes = notes else { return nil }
        
        var noteParts: [String] = []
        
        if let handwriting = notes.handwriting { noteParts.append("Handwriting: \(handwriting)") }
        if let description = notes.description { noteParts.append(description) }
        if let vehicle = notes.vehicle { noteParts.append("Vehicle: \(vehicle)") }
        if let mileage = notes.mileage { noteParts.append("Mileage: \(mileage)") }
        if let trip = notes.trip { noteParts.append("Trip: \(trip)") }
        
        return noteParts.isEmpty ? nil : noteParts.joined(separator: " | ")
    }
    
    private func calculateConfidence(for data: DetailedReceiptData) -> Double {
        var score = 0.0
        let maxScore = 8.0
        
        // Vendor info (2 points)
        if data.vendorInfo?.vendor != nil { score += 1.0 }
        if data.vendorInfo?.city != nil || data.vendorInfo?.state != nil { score += 1.0 }
        
        // Transaction info (2 points)
        if data.transactionInfo?.date != nil { score += 1.0 }
        if data.transactionInfo?.paymentMethod != nil { score += 1.0 }
        
        // Totals (3 points - most important)
        if let total = data.totals?.total, total > 0 { score += 2.0 }
        if data.totals?.tax != nil { score += 1.0 }
        
        // Items (1 point)
        if let items = data.items, !items.isEmpty { score += 1.0 }
        
        return min(score / maxScore, 1.0)
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
            return "Failed to send request to Ollama server"
        case .invalidResponse:
            return "Invalid response from Ollama server"
        case .decodingFailed:
            return "Failed to decode Ollama response"
        }
    }
}

// MARK: - Connection Testing
extension OllamaService {
    func testConnection(apiKey: String? = nil) async -> Bool {
        guard isEnabled else { return true } // If disabled, consider it "working"
        
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
        // Test Ollama with a simple model list request
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10 // Shorter timeout for connection test
        
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
        guard let url = URL(string: "\(baseURL)/models") else { return false }
        
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
    
    // MARK: - Enhanced Processing Methods
    func processReceiptWithOpenAI(image: UIImage, ocrText: String) async throws -> Receipt {
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            throw OllamaError.invalidResponse
        }
        
        let imageBase64 = try encodeImageToBase64(image)
        let prompt = generatePrompt(ocrText: ocrText)
        
        let request = OpenAIRequest(
            model: modelName,
            messages: [
                OpenAIRequest.OpenAIMessage(
                    role: "user",
                    content: [
                        OpenAIRequest.OpenAIMessage.OpenAIContent(
                            type: "text",
                            text: prompt,
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
            max_tokens: 2000,
            temperature: temperature
        )
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw OllamaError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = timeout
        
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = response.choices.first?.message.content else {
            throw OllamaError.invalidResponse
        }
        
        return try parseAIResponse(content, originalImage: image, ocrText: ocrText)
    }
    
    // Enhanced main processing method that chooses the right API
    func processReceiptWithAI(image: UIImage, ocrText: String) async throws -> Receipt {
        guard isEnabled else {
            // If AI is disabled, return a basic receipt with OCR data only
            return createBasicReceipt(from: ocrText, image: image)
        }
        
        let currentAPIType = APIType(rawValue: apiType) ?? .ollama
        
        switch currentAPIType {
        case .ollama:
            return try await processReceiptWithOllama(image: image, ocrText: ocrText)
        case .openai, .custom:
            return try await processReceiptWithOpenAI(image: image, ocrText: ocrText)
        }
    }
    
    private func createBasicReceipt(from ocrText: String, image: UIImage) -> Receipt {
        // Create a basic receipt using only OCR parsing
        let parser = ReceiptParser()
        return parser.parseReceiptFromOCR(ocrText, image: image)
    }
}
