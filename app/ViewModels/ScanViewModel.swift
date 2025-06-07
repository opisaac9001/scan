import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
class ScanViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var scanResult: Receipt?
    @Published var errorMessage: String?
    @Published var showCamera = false
    @Published var capturedImage: UIImage?
    @Published var processingStage: ProcessingStage = .idle
    @Published var confidence: Double = 0.0
    @Published var retryCount = 0
    @Published var canRetry = false

    // MARK: - Services
    private let ocrService = OCRService()
    private let ollamaService = OllamaService()
    private let coreDataManager = CoreDataManager.shared

    // MARK: - Processing Stages
    enum ProcessingStage: String, CaseIterable {
        case idle = "Ready to scan"
        case capturing = "Capturing image..."
        case extractingText = "Extracting text with OCR..."
        case analyzingWithLLM = "Analyzing with AI..."
        case parsing = "Parsing receipt data..."
        case categorizing = "Categorizing for taxes..."
        case saving = "Saving receipt..."
        case complete = "Processing complete"
        case error = "Error occurred"

        var description: String {
            switch self {
            case .idle:
                return "Ready to scan a new receipt"
            case .capturing:
                return "Taking photo of receipt"
            case .extractingText:
                return "Using Vision framework to extract text"
            case .analyzingWithLLM:
                return "Using Ollama LLM for detailed analysis"
            case .parsing:
                return "Converting data to structured format"
            case .categorizing:
                return "Determining tax category and business purpose"
            case .saving:
                return "Saving to local database"
            case .complete:
                return "Receipt successfully processed"
            case .error:
                return "An error occurred during processing"
            }
        }
    }
      // MARK: - Tax Categories
    static let taxCategories = [
        "Office Supplies",
        "Travel",
        "Meals & Entertainment",
        "Fuel & Vehicle",
        "Professional Services",
        "Marketing & Advertising",
        "Utilities",
        "Rent & Facilities",
        "Insurance",
        "Equipment & Technology",
        "Training & Education",
        "Medical & Health",
        "Home & Garden",
        "Groceries & Food",
        "Clothing & Personal",
        "Gifts & Entertainment",
        "Banking & Finance",
        "Shipping & Postage",
        "Other Business",
        "Personal"
    ]

    // MARK: - Main Processing Method
    func processReceipt(image: UIImage) async {
        print("🔄 ScanViewModel: Starting receipt processing")

        resetState()
        isProcessing = true
        capturedImage = image

        do {
            // Stage 1: Basic OCR
            await updateStage(.extractingText)
            let ocrText = try await extractBasicOCR(from: image)
            confidence = 0.3

            // Stage 2: Enhanced LLM Analysis
            await updateStage(.analyzingWithLLM)
            let enhancedReceipt = try await processWithOllama(image: image, basicOCR: ocrText)
            confidence = enhancedReceipt.confidenceScore ?? 0.7

            // Stage 3: Tax Categorization
            await updateStage(.categorizing)
            let categorizedReceipt = await enhanceTaxCategorization(receipt: enhancedReceipt)

            // Stage 4: Save to Core Data
            await updateStage(.saving)
            let savedReceipt = try await saveReceipt(categorizedReceipt, imageData: image.jpegData(compressionQuality: 0.8))

            // Complete
            await updateStage(.complete)
            scanResult = savedReceipt

            print("✅ ScanViewModel: Receipt processing completed successfully")
              } catch {
            await handleAdvancedError(error)
        }

        // Auto-reset after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isProcessing = false
        }
    }

    // MARK: - OCR Processing
    private func extractBasicOCR(from image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            ocrService.recognizeText(from: image) { result in // Changed extractText to recognizeText
                switch result {
                case .success(let text):
                    continuation.resume(returning: text)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Ollama LLM Processing
    private func processWithOllama(image: UIImage, basicOCR: String) async throws -> Receipt {
        await updateStage(.analyzingWithLLM)

        do {
            let enhancedReceipt = try await ollamaService.processReceiptWithLLM(
                image: image,
                basicOCRText: basicOCR
            )

            print("✅ ScanViewModel: Ollama LLM processing successful")
            return enhancedReceipt

        } catch {
            print("⚠️ ScanViewModel: Ollama LLM failed, falling back to basic processing")

            // Fallback to basic parsing if LLM fails
            return createFallbackReceipt(from: basicOCR, image: image)
        }
    }

    // MARK: - Tax Categorization Enhancement
    private func enhanceTaxCategorization(receipt: Receipt) async -> Receipt {
        let enhancedCategory = await determineBestTaxCategory(
            category: receipt.category,
            vendor: receipt.vendor,
            amount: receipt.amount,
            rawText: receipt.rawOCRText
        )

        let businessPurpose = await generateBusinessPurpose(
            category: enhancedCategory,
            vendor: receipt.vendor,
            notes: receipt.notes
        )

        return Receipt(
            id: receipt.id,
            imageData: receipt.imageData,
            vendor: receipt.vendor,
            amount: receipt.amount,
            date: receipt.date,
            category: enhancedCategory,
            notes: receipt.notes,
            rawText: receipt.rawText,
            confidence: receipt.confidence,
            paymentMethod: receipt.paymentMethod,
            location: receipt.location,
            tags: receipt.tags,
            needsReview: receipt.needsReview,
            taxCategory: enhancedCategory,
            businessPurpose: businessPurpose,
            subtotal: receipt.subtotal,
            taxAmount: receipt.taxAmount,
            tipAmount: receipt.tipAmount,
            taxRate: receipt.taxRate,
            transactionId: receipt.transactionId,
            vendorTaxId: receipt.vendorTaxId,
            mileage: receipt.mileage,
            vehicleInfo: receipt.vehicleInfo,
            receiptType: receipt.receiptType,
            rawOCRText: receipt.rawOCRText,
            confidenceScore: receipt.confidenceScore
        )
    }
      // MARK: - Helper Methods
    private func determineBestTaxCategory(category: String?, vendor: String?, amount: Double?, rawText: String?) async -> String {
        let vendorLower = vendor?.lowercased() ?? ""
        let textLower = rawText?.lowercased() ?? ""

        // Fuel & Vehicle - Enhanced detection
        if vendorLower.contains("shell") || vendorLower.contains("chevron") ||
           vendorLower.contains("exxon") || vendorLower.contains("bp") ||
           vendorLower.contains("mobil") || vendorLower.contains("arco") ||
           vendorLower.contains("valero") || vendorLower.contains("speedway") ||
           vendorLower.contains("circle k") || vendorLower.contains("autozone") ||
           vendorLower.contains("o'reilly") || vendorLower.contains("napa") ||
           vendorLower.contains("advance auto") ||
           textLower.contains("gallons") || textLower.contains("fuel") ||
           textLower.contains("gasoline") || textLower.contains("diesel") ||
           textLower.contains("oil change") || textLower.contains("car wash") ||
           textLower.contains("odometer") || textLower.contains("mileage") {
            return "Fuel & Vehicle"
        }

        // Gifts & Entertainment - New enhanced detection
        if vendorLower.contains("flower") || vendorLower.contains("ftd") ||
           vendorLower.contains("1-800-flowers") || vendorLower.contains("gift") ||
           vendorLower.contains("wine") || vendorLower.contains("spirits") ||
           textLower.contains("gift basket") || textLower.contains("gift card") ||
           textLower.contains("bouquet") || textLower.contains("arrangement") ||
           textLower.contains("corporate gift") || textLower.contains("client gift") ||
           textLower.contains("holiday gift") || textLower.contains("appreciation") {
            return "Gifts & Entertainment"
        }

        // Meals & Entertainment - Enhanced detection
        if vendorLower.contains("restaurant") || vendorLower.contains("cafe") ||
           vendorLower.contains("mcdonald") || vendorLower.contains("starbucks") ||
           vendorLower.contains("subway") || vendorLower.contains("pizza") ||
           vendorLower.contains("burger") || vendorLower.contains("diner") ||
           vendorLower.contains("bar") || vendorLower.contains("grill") ||
           textLower.contains("tip") || textLower.contains("gratuity") ||
           textLower.contains("dining") || textLower.contains("catering") ||
           textLower.contains("business meal") || textLower.contains("client dinner") {
            return "Meals & Entertainment"
        }

        // Office Supplies - Enhanced detection
        if vendorLower.contains("staples") || vendorLower.contains("office depot") ||
           vendorLower.contains("best buy") || vendorLower.contains("amazon") ||
           vendorLower.contains("costco business") ||
           textLower.contains("supplies") || textLower.contains("stationery") ||
           textLower.contains("office furniture") || textLower.contains("printer") ||
           textLower.contains("software") || textLower.contains("license") ||
           textLower.contains("ink cartridge") || textLower.contains("paper") {
            return "Office Supplies"
        }

        // Professional Services - Enhanced detection
        if vendorLower.contains("attorney") || vendorLower.contains("lawyer") ||
           vendorLower.contains("cpa") || vendorLower.contains("accountant") ||
           vendorLower.contains("consultant") || vendorLower.contains("notary") ||
           textLower.contains("legal fee") || textLower.contains("consulting") ||
           textLower.contains("professional service") || textLower.contains("tax preparation") ||
           textLower.contains("bookkeeping") || textLower.contains("payroll") {
            return "Professional Services"
        }

        // Banking & Finance - New category
        if vendorLower.contains("bank") || vendorLower.contains("credit union") ||
           vendorLower.contains("paypal") || vendorLower.contains("square") ||
           textLower.contains("bank fee") || textLower.contains("service charge") ||
           textLower.contains("merchant fee") || textLower.contains("payment processing") ||
           textLower.contains("loan interest") || textLower.contains("finance charge") {
            return "Banking & Finance"
        }

        // Shipping & Postage - New category
        if vendorLower.contains("fedex") || vendorLower.contains("ups") ||
           vendorLower.contains("usps") || vendorLower.contains("dhl") ||
           vendorLower.contains("postal") ||
           textLower.contains("shipping") || textLower.contains("postage") ||
           textLower.contains("courier") || textLower.contains("delivery") ||
           textLower.contains("packaging") || textLower.contains("freight") {
            return "Shipping & Postage"
        }

        // Groceries - Enhanced detection
        if vendorLower.contains("walmart") || vendorLower.contains("target") ||
           vendorLower.contains("kroger") || vendorLower.contains("safeway") ||
           vendorLower.contains("whole foods") || vendorLower.contains("trader joe") ||
           vendorLower.contains("costco") || vendorLower.contains("sam's club") ||
           vendorLower.contains("grocery") || vendorLower.contains("supermarket") {
            return "Groceries & Food"
        }

        // Travel - Enhanced detection
        if vendorLower.contains("hotel") || vendorLower.contains("airline") ||
           vendorLower.contains("uber") || vendorLower.contains("lyft") ||
           vendorLower.contains("rental car") || vendorLower.contains("airbnb") ||
           vendorLower.contains("expedia") || vendorLower.contains("booking.com") ||
           textLower.contains("lodging") || textLower.contains("accommodation") ||
           textLower.contains("flight") || textLower.contains("travel") ||
           textLower.contains("mileage reimbursement") {
            return "Travel"
        }

        // Use provided category or default
        return category ?? "Other Business"
    }
      private func generateBusinessPurpose(category: String?, vendor: String?, notes: String?) async -> String? {
        guard let category = category else { return nil }

        let vendor = vendor ?? "vendor"

        switch category {
        case "Fuel & Vehicle":
            return "Business travel - fuel expense for \(vendor)"
        case "Meals & Entertainment":
            return "Business meal at \(vendor)"
        case "Gifts & Entertainment":
            return "Business gift from \(vendor) - client appreciation"
        case "Office Supplies":
            return "Office supplies from \(vendor)"
        case "Travel":
            return "Business travel expense - \(vendor)"
        case "Professional Services":
            return "Professional services from \(vendor)"
        case "Banking & Finance":
            return "Business banking/finance fee - \(vendor)"
        case "Shipping & Postage":
            return "Business shipping/postage - \(vendor)"
        case "Marketing & Advertising":
            return "Marketing/advertising expense - \(vendor)"
        case "Equipment & Technology":
            return "Business equipment purchase - \(vendor)"
        case "Training & Education":
            return "Professional development - \(vendor)"
        case "Utilities":
            return "Business utility expense - \(vendor)"
        case "Rent & Facilities":
            return "Business facility expense - \(vendor)"
        case "Insurance":
            return "Business insurance - \(vendor)"
        default:
            return "Business expense - \(category.lowercased()) from \(vendor)"
        }
    }

    private func createFallbackReceipt(from ocrText: String, image: UIImage) -> Receipt {
        // Basic parsing fallback
        return Receipt(
            imageData: image.jpegData(compressionQuality: 0.8),
            vendor: "Unknown Vendor",
            amount: 0.0,
            date: Date(),
            category: "Other Business",
            rawText: ocrText,
            confidence: 0.4,
            needsReview: true,
            taxCategory: "Other Business",
            businessPurpose: "Manual review required - OCR only processing",
            rawOCRText: ocrText,
            confidenceScore: 0.4
        )
    }

    private func saveReceipt(_ receipt: Receipt, imageData: Data?) async throws -> Receipt {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataManager.saveReceipt(receipt) { result in
                switch result {
                case .success(let savedReceipt):
                    continuation.resume(returning: savedReceipt)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - State Management
    private func updateStage(_ stage: ProcessingStage) async {
        await MainActor.run {
            processingStage = stage
            print("📍 Processing stage: \(stage.rawValue)")
        }
    }

    private func resetState() {
        errorMessage = nil
        scanResult = nil
        processingStage = .idle
        confidence = 0.0
        retryCount = 0
        canRetry = false
    }

    // MARK: - Error Handling & Retry
    enum ScanError: LocalizedError {
        case cameraPermissionDenied
        case ocrFailed(String)
        case llamaServiceUnavailable
        case networkTimeout
        case saveFailed(String)
        case imageProcessingFailed

        var errorDescription: String? {
            switch self {
            case .cameraPermissionDenied:
                return "Camera permission is required to scan receipts"
            case .ocrFailed(let detail):
                return "Failed to extract text from image: \(detail)"
            case .llamaServiceUnavailable:
                return "AI service is currently unavailable"
            case .networkTimeout:
                return "Network request timed out"
            case .saveFailed(let detail):
                return "Failed to save receipt: \(detail)"
            case .imageProcessingFailed:
                return "Failed to process the image"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .cameraPermissionDenied:
                return "Please enable camera access in Settings"
            case .ocrFailed:
                return "Try taking a clearer photo with better lighting"
            case .llamaServiceUnavailable:
                return "Please check your network connection and try again"
            case .networkTimeout:
                return "Check your internet connection and retry"
            case .saveFailed:
                return "Please try again or contact support"
            case .imageProcessingFailed:
                return "Try taking a new photo with better quality"
            }
        }
    }

    private func handleAdvancedError(_ error: Error) async {
        await MainActor.run {
            isProcessing = false
            processingStage = .error

            // Determine if retry is possible
            canRetry = retryCount < 3 && isRetryableError(error)

            // Set user-friendly error message
            if let scanError = error as? ScanError {
                errorMessage = scanError.localizedDescription
            } else {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }

            print("❌ ScanViewModel advanced error: \(error)")
        }
    }

    private func isRetryableError(_ error: Error) -> Bool {
        if let scanError = error as? ScanError {
            switch scanError {
            case .cameraPermissionDenied, .imageProcessingFailed:
                return false
            case .ocrFailed, .llamaServiceUnavailable, .networkTimeout, .saveFailed:
                return true
            }
        }
        return true // Default to retryable for unknown errors
    }

    // MARK: - Public Methods
    func startNewScan() {
        resetState()
        showCamera = true
    }

    func retryProcessing() {
        guard let image = capturedImage else { return }

        Task {
            await processReceipt(image: image)
        }
    }

    func clearResults() {
        resetState()
        capturedImage = nil
        scanResult = nil
    }

    func retryWithExponentialBackoff() async {
        guard canRetry, retryCount < 3, let image = capturedImage else { return }

        retryCount += 1
        let delay = Double(retryCount * 2) // 2, 4, 6 seconds

        print("🔄 Retrying scan attempt \(retryCount)/3 after \(delay)s delay")

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        await processReceipt(image: image)
    }

    // MARK: - Manual Editing
    func updateReceiptCategory(_ receipt: Receipt, newCategory: String) async throws -> Receipt {
        let updatedReceipt = Receipt(
            id: receipt.id,
            imageData: receipt.imageData,
            vendor: receipt.vendor,
            amount: receipt.amount,
            date: receipt.date,
            category: newCategory,
            notes: receipt.notes,
            rawText: receipt.rawText,
            confidence: receipt.confidence,
            paymentMethod: receipt.paymentMethod,
            location: receipt.location,
            tags: receipt.tags,
            needsReview: false, // Mark as reviewed
            taxCategory: newCategory,
            businessPurpose: await generateBusinessPurpose(category: newCategory, vendor: receipt.vendor, notes: receipt.notes),
            subtotal: receipt.subtotal,
            taxAmount: receipt.taxAmount,
            tipAmount: receipt.tipAmount,
            taxRate: receipt.taxRate,
            transactionId: receipt.transactionId,
            vendorTaxId: receipt.vendorTaxId,
            mileage: receipt.mileage,
            vehicleInfo: receipt.vehicleInfo,
            receiptType: receipt.receiptType,
            rawOCRText: receipt.rawOCRText,
            confidenceScore: receipt.confidenceScore
        )

        return try await saveReceipt(updatedReceipt, imageData: receipt.imageData)
    }
}
