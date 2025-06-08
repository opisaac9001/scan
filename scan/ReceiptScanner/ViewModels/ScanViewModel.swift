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
    // @Published var confidence: Double = 0.0 // 'confidence' is now part of scanResult.confidenceScore
    @Published var retryCount = 0
    @Published var canRetry = false

    // MARK: - Services
    private let ocrService = OCRService.shared // Use shared instance
    private let ollamaService = OllamaService() // OllamaService might need its own @AppStorage or be configured
    private let coreDataManager = CoreDataManager.shared
    private let receiptParser = ReceiptParser.shared // Use shared instance

    // MARK: - Processing Stages
    enum ProcessingStage: String, CaseIterable {
        case idle = "Ready to scan"
        case capturing = "Capturing image..."
        case extractingText = "Extracting text with OCR..."
        case analyzingWithLLM = "Analyzing with AI..."
        // case parsing = "Parsing receipt data..." // Parsing is part of LLM or fallback
        case categorizing = "Categorizing..." // Simplified, as LLM does most of this
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
                return "Using AI for detailed analysis"
            // case .parsing:
            //     return "Converting data to structured format"
            case .categorizing:
                return "Finalizing category and business purpose"
            case .saving:
                return "Saving to local database"
            case .complete:
                return "Receipt successfully processed"
            case .error:
                return "An error occurred during processing"
            }
        }
    }
      // MARK: - Tax Categories (Still useful for fallback or UI pickers)
    static let taxCategories = [ // This list should align with categories LLM uses
        "Office Supplies", "Travel", "Meals & Entertainment", "Fuel & Vehicle",
        "Professional Services", "Marketing & Advertising", "Utilities", "Rent & Facilities",
        "Insurance", "Equipment & Technology", "Training & Education", "Medical & Health",
        "Home & Garden", "Groceries & Food", "Clothing & Personal", "Gifts & Entertainment",
        "Banking & Finance", "Shipping & Postage", "Other Business", "Personal"
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
            // self.confidence = 0.3 // Old confidence metric

            // Stage 2: Enhanced LLM Analysis (or fallback)
            await updateStage(.analyzingWithLLM)
            var processedReceipt = try await processWithOllamaOrFallback(image: image, basicOCR: ocrText)
            // self.confidence = processedReceipt.confidenceScore ?? 0.3 // Update confidence from receipt

            // Stage 3: Tax Categorization (now potentially minor adjustments or pass-through)
            await updateStage(.categorizing)
            processedReceipt = await enhanceTaxCategorization(receipt: processedReceipt)

            // Stage 4: Save to Core Data
            await updateStage(.saving)
            // imageData is now part of Receipt struct, CoreDataManager handles it.
            let savedReceipt = try await saveReceiptToCoreData(processedReceipt)

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
             // scanResult remains to be displayed until next scan
        }
    }

    // MARK: - OCR Processing
    private func extractBasicOCR(from image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            ocrService.recognizeText(from: image) { result in
                switch result {
                case .success(let text):
                    continuation.resume(returning: text)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Ollama LLM Processing or Fallback
    private func processWithOllamaOrFallback(image: UIImage, basicOCR: String) async throws -> Receipt {
        // Check if LLM processing is enabled in OllamaService (via its AppStorage)
        if ollamaService.isEnabled {
            do {
                // Try processing with OllamaService (which now returns the new Receipt structure)
                let enhancedReceipt = try await ollamaService.processReceiptWithAI(
                    image: image,
                    ocrText: basicOCR
                )
                print("✅ ScanViewModel: Ollama/AI processing successful")
                return enhancedReceipt
            } catch {
                print("⚠️ ScanViewModel: Ollama/AI processing failed: \(error.localizedDescription). Falling back to basic OCR parsing.")
                return createFallbackReceipt(from: basicOCR, image: image)
            }
        } else {
            print("ℹ️ ScanViewModel: LLM processing is disabled. Using basic OCR parsing.")
            return createFallbackReceipt(from: basicOCR, image: image)
        }
    }

    // MARK: - Tax Categorization Enhancement (Provisionally Disabled)
    private func enhanceTaxCategorization(receipt: Receipt) async -> Receipt {
        // The new LLM prompt is expected to provide accurate `expense_category` for items
        // and a `business_purpose`. This function can be re-enabled or re-purposed
        // if the LLM's output for these fields needs further refinement or local overrides.
        // For now, it acts as a pass-through.

        // let primaryDisplayCategory = receipt.displayCategory ?? "Other Business"
        // let refinedBusinessPurpose = await generateBusinessPurpose(
        //     category: primaryDisplayCategory,
        //     vendor: receipt.vendorInfo?.store_name ?? receipt.vendorInfo?.vendor,
        //     currentPurpose: receipt.notes?.business_purpose,
        //     receiptNotes: receipt.notes?.description
        // )

        // // Create a new Receipt instance only if something actually changed.
        // if receipt.displayCategory != primaryDisplayCategory || receipt.notes?.business_purpose != refinedBusinessPurpose {
        //     var updatedReceipt = receipt
        //     // This is tricky because displayCategory is computed. We'd need to update what it's based on.
        //     // For now, if LLM provides good item categories, displayCategory should be fine.
        //     // If notes struct is a var:
        //     // updatedReceipt.notes?.business_purpose = refinedBusinessPurpose
        //     // Or re-initialize:
        //     // return Receipt( ... copy all fields ... notes: newNotes ... )
        //     print("ℹ️ ScanViewModel: Tax categorization/business purpose potentially refined (currently pass-through).")
        // }
        return receipt
    }

    // MARK: - Business Purpose Generation (Provisionally Disabled)
    private func generateBusinessPurpose(category: String?, vendor: String?, currentPurpose: String?, receiptNotes: String?) async -> String? {
        // This function is provisionally disabled as the new LLM prompt is expected
        // to provide a `business_purpose` directly. If the LLM's output is insufficient,
        // this local logic can be re-enabled or enhanced.
        // It could also serve as a fallback if currentPurpose from LLM is nil.

        // if let existingPurpose = currentPurpose, !existingPurpose.isEmpty {
        //     return existingPurpose // Prefer LLM's purpose if available
        // }

        // guard let category = category else { return nil }
        // let vendorName = vendor ?? "vendor"
        // // ... (original switch logic could go here as a fallback) ...
        // switch category {
        // default:
        //    return "Business expense - \(category.lowercased()) from \(vendorName)"
        // }
        return currentPurpose // Effectively a pass-through or returns LLM's value
    }

    // MARK: - Fallback Receipt Creation
    private func createFallbackReceipt(from ocrText: String, image: UIImage) -> Receipt {
        // 1. Construct a basic OCRResult
        let ocrLines = ocrText.split(separator: "\n").map {
            OCRTextLine(text: String($0), confidence: 0.5, boundingBox: .zero) // Assign default confidence
        }
        let ocrResult = OCRResult(fullText: ocrText, textLines: ocrLines, averageConfidence: 0.5)

        // 2. Use ReceiptParser to get ParsedReceiptData
        let parsedData = receiptParser.parseReceipt(from: ocrResult)

        // 3. Map ParsedReceiptData to the new Receipt structure
        let vendorInfo = Receipt.VendorInfo(
            vendor: parsedData.vendor, // Full name from parser
            store_name: parsedData.vendor // Simplified name can be same as full name for fallback
            // address, city, state, etc., will be nil as parser doesn't provide them in this structure
        )

        let transactionInfo = Receipt.TransactionInfo(
            date: parsedData.date != nil ? AppDateFormatter.shared.string(from: parsedData.date!, format: "yyyy/MM/dd") : nil,
            payment_method: parsedData.paymentMethod
            // time, transaction_id, etc., will be nil
        )

        let lineItems: [Receipt.LineItem]? = parsedData.lineItems.isEmpty ? nil : parsedData.lineItems.map { parsedItem in
            Receipt.LineItem(
                description: parsedItem.description,
                total_price: parsedItem.price // ParsedReceiptData.LineItem only has description and price
                // quantity, unit_price, category, etc., will be nil
            )
        }

        let totals = Receipt.Totals(
            total: parsedData.amount
            // subtotal, tax, etc., will be nil
        )

        let notes = Receipt.Notes(
            description: "Fallback processing using local OCR parser.",
            business_purpose: "Needs manual review and categorization.",
            raw_text_from_llm: nil // No LLM raw text in this case
        )

        return Receipt(
            id: UUID(),
            imageData: image.jpegData(compressionQuality: 0.8),
            rawOCRText: ocrText, // Original OCR text
            confidenceScore: parsedData.confidence ?? 0.3, // Low confidence for fallback
            needsReview: true,
            createdAt: Date(),
            updatedAt: Date(),
            receiptType: parsedData.category ?? "Unknown", // Use parser's category as receiptType
            vendorInfo: vendorInfo,
            transactionInfo: transactionInfo,
            items: lineItems,
            totals: totals,
            notes: notes
        )
    }

    // Updated saveReceipt to match CoreDataManager's expectation (which now handles new Receipt structure)
    private func saveReceiptToCoreData(_ receipt: Receipt) async throws -> Receipt {
        // CoreDataManager.createReceipt now handles the new Receipt structure internally
        guard let savedEntity = coreDataManager.createReceipt(from: receipt) else {
            throw ScanError.saveFailed("Failed to create ReceiptEntity in Core Data.")
        }
        // We need to return a Receipt struct.
        // If createReceipt in CoreDataManager returned the saved ReceiptEntity, we'd map it back.
        // For now, assume the input receipt is the "saved" representation for the ViewModel.
        // Or, ideally, CoreDataManager.createReceipt would return the created Receipt struct.
        // Let's assume for now the input `receipt` is what we want to reflect as `scanResult`.
        // This might need adjustment if CoreDataManager.createReceipt returns something else or modifies the receipt.

        // To ensure we have the UUID from the entity (if it was generated by CoreData, though we pass one in)
        // and any other DB-side changes, it's best if createReceipt returns the final state.
        // For now, we return the receipt that was passed in, assuming it's complete.
        // If `coreDataManager.createReceipt` returned a `Receipt` struct, that would be ideal.
        // Since it returns `ReceiptEntity?`, we'll just use the `receipt` we have.
        // This implies `ReceiptListViewModel` will fetch the actual saved data.
        return receipt
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
        // scanResult = nil // Keep last scan result visible until new scan starts
        processingStage = .idle
        // confidence = 0.0 // Old confidence metric
        retryCount = 0
        canRetry = false
    }

    // MARK: - Error Handling & Retry
    enum ScanError: LocalizedError {
        case cameraPermissionDenied
        case ocrFailed(String)
        // case llamaServiceUnavailable // Covered by OllamaError or a general AI service error
        // case networkTimeout // Covered by URLSession errors
        case saveFailed(String)
        case imageProcessingFailed
        case aiProcessingError(String) // More generic AI error

        var errorDescription: String? {
            switch self {
            case .cameraPermissionDenied:
                return "Camera permission is required to scan receipts"
            case .ocrFailed(let detail):
                return "Failed to extract text from image: \(detail)"
            // case .llamaServiceUnavailable:
            //     return "AI service is currently unavailable"
            // case .networkTimeout:
            //     return "Network request timed out"
            case .saveFailed(let detail):
                return "Failed to save receipt: \(detail)"
            case .imageProcessingFailed:
                return "Failed to process the image"
            case .aiProcessingError(let detail):
                return "AI processing failed: \(detail)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .cameraPermissionDenied:
                return "Please enable camera access in Settings"
            case .ocrFailed:
                return "Try taking a clearer photo with better lighting"
            // case .llamaServiceUnavailable:
            //     return "Please check your network connection and AI service settings, then try again."
            // case .networkTimeout:
            //     return "Check your internet connection and retry"
            case .saveFailed:
                return "Please try again or contact support"
            case .imageProcessingFailed:
                return "Try taking a new photo with better quality"
            case .aiProcessingError:
                 return "Please check your AI service settings (endpoint, model, API key) and network connection, then try again. If the issue persists, the AI model may be unable to process this receipt."
            }
        }
    }

    private func handleAdvancedError(_ error: Error) async {
        await MainActor.run {
            isProcessing = false
            processingStage = .error

            canRetry = retryCount < 3 && isRetryableError(error)

            if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
                 errorMessage = description
            } else {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }

            // For more specific error reporting to UI if needed
            if let ollamaError = error as? OllamaError {
                 errorMessage = ollamaError.localizedDescription // OllamaError now has user-friendly descriptions
            } else if let scanError = error as? ScanError {
                 errorMessage = scanError.localizedDescription
            }

            print("❌ ScanViewModel advanced error: \(errorMessage ?? error.localizedDescription)")
        }
    }

    private func isRetryableError(_ error: Error) -> Bool {
        if let scanError = error as? ScanError {
            switch scanError {
            case .cameraPermissionDenied, .imageProcessingFailed:
                return false
            case .ocrFailed, .saveFailed, .aiProcessingError:
                return true
            }
        }
        if let ollamaError = error as? OllamaError { // OllamaError can be retryable
            switch ollamaError {
            case .requestFailed, .invalidResponse, .decodingFailed: // Network or temp server issues
                return true
            case .invalidURL, .imageEncodingFailed: // Configuration or unrecoverable issues
                return false
            }
        }
        // Default to retryable for unknown errors or network errors from URLSession
        if (error as NSError).domain == NSURLErrorDomain {
            return true
        }
        return true
    }

    // MARK: - Public Methods
    func startNewScan() {
        resetState()
        scanResult = nil // Clear previous successful scan when starting a new one
        capturedImage = nil // Clear previous image
        showCamera = true
    }

    func retryProcessing() {
        guard let image = capturedImage else {
            errorMessage = "No image available to retry."
            return
        }
        // Reset relevant state before retry
        errorMessage = nil
        processingStage = .idle
        // scanResult = nil // Keep previous scan result or clear? Decided to clear on new scan.

        Task {
            await processReceipt(image: image)
        }
    }

    func clearResults() { // Typically called when user dismisses a scan result view or starts new scan
        resetState()
        capturedImage = nil
        scanResult = nil
    }

    // MARK: - Manual Editing (Placeholder - Not fully implemented in this context)
    // This would involve fetching the receipt, allowing edits, and re-saving.
    // For now, just an example of how one might update a category.
    func updateReceiptCategory(for receiptToUpdate: Receipt, newCategory: String) async throws -> Receipt {
        // This is a simplified example. A real implementation would need more robust error handling
        // and potentially re-generating business purpose or other dependent fields.

        var updatedReceipt = receiptToUpdate
        // How to update category? If items drive it, this is complex.
        // If receiptType drives it:
        updatedReceipt.receiptType = newCategory // Or map newCategory to a receiptType if different

        // If there was a direct category field, it would be:
        // updatedReceipt.category = newCategory
        // updatedReceipt.taxCategory = newCategory

        // Business purpose might need to be regenerated if category changes significantly
        // updatedReceipt.notes?.business_purpose = await generateBusinessPurpose(
        // category: newCategory,
        // vendor: updatedReceipt.vendorInfo?.store_name ?? updatedReceipt.vendorInfo?.vendor,
        // currentPurpose: updatedReceipt.notes?.business_purpose,
        // receiptNotes: updatedReceipt.notes?.description
        // )

        updatedReceipt.needsReview = false // Assuming manual edit means it's reviewed
        updatedReceipt.updatedAt = Date()

        // Re-save to Core Data
        return try await saveReceiptToCoreData(updatedReceipt)
    }
}

// Helper for date formatting, if needed more broadly
class AppDateFormatter {
    static let shared = AppDateFormatter()
    private init() {}

    private func getFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    func string(from date: Date, format: String) -> String {
        return getFormatter(format: format).string(from: date)
    }

    func date(from string: String, format: String) -> Date? {
        return getFormatter(format: format).date(from: string)
    }
}

// Extension for ScanViewModel error provider (if used for Alerts from ContentView)
extension ScanViewModel {
    @Published var errorMessageProvider: ErrorMessageProvider?
}
