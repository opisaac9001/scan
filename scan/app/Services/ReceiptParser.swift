import Foundation

class ReceiptParser: ObservableObject {
    static let shared = ReceiptParser()
    
    private init() {}
    
    func parseReceipt(from ocrResult: OCRResult) -> ParsedReceiptData {
        let lines = ocrResult.textLines.map { $0.text }
        let fullText = ocrResult.fullText
        
        return ParsedReceiptData(
            vendor: extractVendor(from: lines),
            amount: extractAmount(from: lines),
            date: extractDate(from: lines),
            category: inferCategory(from: fullText),
            paymentMethod: extractPaymentMethod(from: lines),
            location: extractLocation(from: lines),
            lineItems: extractLineItems(from: lines),
            confidence: Double(ocrResult.averageConfidence),
            rawText: fullText
        )
    }
    
    // MARK: - Private Parsing Methods
    
    private func extractVendor(from lines: [String]) -> String? {
        // Look for vendor name in the first few lines
        let vendorPatterns = [
            "^[A-Z][A-Z\\s&]+$", // All caps company names
            "^[A-Za-z\\s&'.-]+(?:LLC|Inc|Corp|Co\\.|Ltd|Limited).*$", // Company suffixes
            "^[A-Z][a-z]+\\s+[A-Z][a-z]+.*$" // Title case names
        ]
        
        for (index, line) in lines.prefix(5).enumerated() {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip very short lines or lines that look like addresses/phone numbers
            if cleanLine.count < 3 || 
               cleanLine.contains(CharacterSet.decimalDigits) && cleanLine.count > 8 ||
               cleanLine.localizedCaseInsensitiveContains("phone") ||
               cleanLine.localizedCaseInsensitiveContains("tel") {
                continue
            }
            
            for pattern in vendorPatterns {
                if cleanLine.range(of: pattern, options: .regularExpression) != nil {
                    return cleanLine
                }
            }
            
            // If it's the first meaningful line, it's likely the vendor
            if index == 0 && cleanLine.count > 3 {
                return cleanLine
            }
        }
        
        return nil
    }
    
    private func extractAmount(from lines: [String]) -> Double? {
        let amountPatterns = [
            "(?i)total[:\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "(?i)amount[:\\s]*\\$?([0-9,]+\\.?[0-9]*)",
            "\\$([0-9,]+\\.[0-9]{2})(?:\\s|$)",
            "([0-9,]+\\.[0-9]{2})(?:\\s|$)"
        ]
        
        var amounts: [(Double, Int)] = [] // (amount, priority)
        
        for (lineIndex, line) in lines.enumerated() {
            for (patternIndex, pattern) in amountPatterns.enumerated() {
                if let match = line.range(of: pattern, options: .regularExpression) {
                    let matchString = String(line[match])
                    if let extractedAmount = extractNumberFromString(matchString) {
                        // Higher priority for lines containing "total" or "amount"
                        let priority = line.localizedCaseInsensitiveContains("total") ? 0 :
                                     line.localizedCaseInsensitiveContains("amount") ? 1 :
                                     patternIndex + 2
                        amounts.append((extractedAmount, priority))
                    }
                }
            }
        }
        
        // Return the amount with highest priority (lowest number)
        return amounts.min(by: { $0.1 < $1.1 })?.0
    }
    
    private func extractDate(from lines: [String]) -> Date? {
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",
            "\\d{1,2}-\\d{1,2}-\\d{2,4}",
            "\\d{4}-\\d{1,2}-\\d{1,2}",
            "(?i)(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+\\d{1,2},?\\s+\\d{2,4}",
            "\\d{1,2}\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+\\d{2,4}"
        ]
        
        let dateFormatters = createDateFormatters()
        
        for line in lines.prefix(10) {
            for pattern in datePatterns {
                if let match = line.range(of: pattern, options: .regularExpression) {
                    let dateString = String(line[match])
                    
                    for formatter in dateFormatters {
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractPaymentMethod(from lines: [String]) -> String? {
        let paymentPatterns = [
            "(?i)(visa|mastercard|amex|american express|discover|cash|debit|credit)",
            "(?i)card\\s*ending\\s*in\\s*(\\d{4})",
            "(?i)(\\*{4}\\d{4}|x{4}\\d{4})",
            "(?i)payment\\s*method[:\\s]*(.*)"
        ]
        
        for line in lines {
            for pattern in paymentPatterns {
                if let match = line.range(of: pattern, options: .regularExpression) {
                    return String(line[match]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
    
    private func extractLocation(from lines: [String]) -> String? {
        // Look for address patterns in the text
        let locationPatterns = [
            "\\d+\\s+[A-Za-z\\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln)",
            "[A-Za-z\\s]+,\\s*[A-Z]{2}\\s*\\d{5}",
            "[A-Za-z\\s]+\\s+[A-Z]{2}\\s+\\d{5}"
        ]
        
        for line in lines {
            for pattern in locationPatterns {
                if let match = line.range(of: pattern, options: .regularExpression) {
                    return String(line[match]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
    
    private func extractLineItems(from lines: [String]) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []
        
        for line in lines {
            // Look for patterns like "Item Name $X.XX" or "Item Name X.XX"
            let itemPattern = "^(.+?)\\s+\\$?([0-9,]+\\.[0-9]{2})$"
            
            if let match = line.range(of: itemPattern, options: .regularExpression) {
                let matchString = String(line[match])
                let components = matchString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                
                if let priceString = components.last,
                   let price = Double(priceString.replacingOccurrences(of: ",", with: "")),
                   price > 0 {
                    
                    let description = line.replacingOccurrences(of: "\\$?[0-9,]+\\.[0-9]{2}$", 
                                                              with: "", 
                                                              options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !description.isEmpty && description.count > 2 {
                        items.append(ReceiptLineItem(description: description, price: price))
                    }
                }
            }
        }
        
        return items
    }
      private func inferCategory(from fullText: String) -> String? {
        let categoryKeywords: [String: [String]] = [
            "Groceries": ["grocery", "supermarket", "walmart", "target", "safeway", "kroger", "food", "market", "whole foods", "trader joe"],
            "Gas": ["gas", "fuel", "shell", "exxon", "chevron", "bp", "mobil", "station", "arco", "valero", "speedway", "circle k"],
            "Restaurant": ["restaurant", "cafe", "coffee", "pizza", "burger", "diner", "food", "bar", "starbucks", "mcdonald", "subway"],
            "Retail": ["store", "shop", "mall", "clothing", "electronics", "amazon", "best buy", "costco", "sam's club"],
            "Pharmacy": ["pharmacy", "cvs", "walgreens", "rite aid", "drug", "medicine", "prescription"],
            "Transportation": ["uber", "lyft", "taxi", "metro", "bus", "train", "parking", "toll", "rental car"],
            "Entertainment": ["movie", "theater", "cinema", "concert", "game", "entertainment", "ticket"],
            "Office": ["office", "supplies", "staples", "depot", "business", "equipment", "stationery", "software"],
            "Gifts": ["gift", "flower", "ftd", "1-800-flowers", "basket", "card", "bouquet", "wine", "spirits"],
            "Auto": ["auto", "vehicle", "maintenance", "repair", "oil change", "car wash", "autozone", "o'reilly", "napa"],
            "Professional": ["attorney", "lawyer", "cpa", "accountant", "consultant", "legal", "tax preparation"],
            "Banking": ["bank", "fee", "service charge", "paypal", "square", "merchant", "payment processing"],
            "Shipping": ["fedex", "ups", "usps", "dhl", "shipping", "postage", "courier", "delivery"],
            "Travel": ["hotel", "airline", "flight", "lodging", "airbnb", "expedia", "booking", "travel"]
        ]
        
        let lowercaseText = fullText.lowercased()
        
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if lowercaseText.contains(keyword) {
                    return category
                }
            }
        }
        
        return "Other"
    }
    
    // MARK: - Helper Methods
    
    private func extractNumberFromString(_ string: String) -> Double? {
        let cleanString = string
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Double(cleanString)
    }
    
    private func createDateFormatters() -> [DateFormatter] {
        let patterns = [
            "MM/dd/yyyy", "MM/dd/yy", "M/d/yyyy", "M/d/yy",
            "MM-dd-yyyy", "MM-dd-yy", "M-d-yyyy", "M-d-yy",
            "yyyy-MM-dd", "yyyy-M-d",
            "MMM dd, yyyy", "MMM d, yyyy",
            "dd MMM yyyy", "d MMM yyyy"
        ]
        
        return patterns.map { pattern in
            let formatter = DateFormatter()
            formatter.dateFormat = pattern
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }
    }
}

// MARK: - Supporting Types

struct ParsedReceiptData {
    let vendor: String?
    let amount: Double?
    let date: Date?
    let category: String?
    let paymentMethod: String?
    let location: String?
    let lineItems: [ReceiptLineItem]
    let confidence: Double?
    let rawText: String
}

struct ReceiptLineItem {
    let description: String
    let price: Double
}
