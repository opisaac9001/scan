import Foundation

// MARK: - App Configuration
struct AppConfig {
    
    // MARK: - Build Configuration
    static let isDebugMode = true
    static let version = "1.0.0"
    static let build = "1"
    
    // MARK: - Ollama Configuration
    struct Ollama {
        static let defaultBaseURL = "http://localhost:11434"
        static let defaultModel = "llava:latest"
        static let requestTimeout: TimeInterval = 60.0
        static let maxRetryAttempts = 3
    }
    
    // MARK: - OCR Configuration
    struct OCR {
        static let recognitionLevel: String = "accurate" // "fast" or "accurate"
        static let minimumConfidence: Float = 0.5
        static let usesLanguageCorrection = true
    }
    
    // MARK: - Storage Configuration
    struct Storage {
        static let maxImageSize: CGFloat = 1024.0 // Maximum width/height for stored images
        static let imageCompressionQuality: CGFloat = 0.8
        static let enableBackup = true
    }
    
    // MARK: - UI Configuration
    struct UI {
        static let animationDuration: TimeInterval = 0.3
        static let cornerRadius: CGFloat = 12.0
        static let primaryColor = "AccentColor"
    }
    
    // MARK: - Tax Categories
    static let taxCategories = [
        "Meals & Entertainment",
        "Travel & Transportation", 
        "Office Supplies",
        "Professional Services",
        "Equipment & Software",
        "Marketing & Advertising",
        "Fuel & Vehicle",
        "Utilities",
        "Insurance",
        "Professional Development",
        "Gifts & Client Entertainment",
        "Home Office",
        "Healthcare",
        "Charity & Donations",
        "Banking & Finance",
        "Legal & Professional",
        "Maintenance & Repairs",
        "Other Business Expense"
    ]
    
    // MARK: - Development Features
    #if DEBUG
    static let enableDemoData = true
    static let enableDebugLogs = true
    static let skipOllamaInTests = true
    #else
    static let enableDemoData = false
    static let enableDebugLogs = false
    static let skipOllamaInTests = false
    #endif
}

// MARK: - Global Extensions
extension CGFloat {
    static let cornerRadius = AppConfig.UI.cornerRadius
}

extension TimeInterval {
    static let animation = AppConfig.UI.animationDuration
}
