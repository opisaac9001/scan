import Foundation // For Date, DateInterval, Calendar, etc.
// No SwiftUI needed for these enums/logic if they don't use SwiftUI-specific property wrappers.
// Assuming Receipt.swift is in app/Models/ and accessible within the same target.

struct ReceiptFilterSortEngine {

    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"
        case lastYear = "Last Year"
        case custom = "Custom Range"

        var dateInterval: DateInterval? {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .all, .custom:
                return nil
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                return DateInterval(start: startOfMonth, end: now)
            case .lastMonth:
                guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
                let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonthDate)?.start ?? lastMonthDate
                let endOfLastMonth = calendar.dateInterval(of: .month, for: lastMonthDate)?.end ?? lastMonthDate
                return DateInterval(start: startOfLastMonth, end: endOfLastMonth)
            case .thisYear:
                let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                return DateInterval(start: startOfYear, end: now)
            case .lastYear:
                guard let lastYearDate = calendar.date(byAdding: .year, value: -1, to: now) else { return nil }
                let startOfLastYear = calendar.dateInterval(of: .year, for: lastYearDate)?.start ?? lastYearDate
                let endOfLastYear = calendar.dateInterval(of: .year, for: lastYearDate)?.end ?? lastYearDate
                return DateInterval(start: startOfLastYear, end: endOfLastYear)
            }
        }
    }

    enum SortOption: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case amountHighest = "Highest Amount"
        case amountLowest = "Lowest Amount"
        case vendor = "Vendor A-Z"
        case category = "Category"

        // This sortDescriptor now operates on Receipt type, which must be accessible.
        var sortDescriptor: (Receipt, Receipt) -> Bool {
            switch self {
            case .newest:
                return { $0.parsedDate ?? Date.distantPast > $1.parsedDate ?? Date.distantPast }
            case .oldest:
                return { $0.parsedDate ?? Date.distantPast < $1.parsedDate ?? Date.distantPast }
            case .amountHighest:
                return { $0.totals?.total ?? 0 > $1.totals?.total ?? 0 }
            case .amountLowest:
                return { $0.totals?.total ?? 0 < $1.totals?.total ?? 0 }
            case .vendor:
                return { ($0.primaryVendorName ?? "").localizedCaseInsensitiveCompare($1.primaryVendorName ?? "") == .orderedAscending }
            case .category:
                return { ($0.displayCategory ?? "").localizedCaseInsensitiveCompare($1.displayCategory ?? "") == .orderedAscending }
            }
        }
    }

    static func applyFiltersAndSort(
        receipts: [Receipt],
        searchText: String,
        category filterCategory: String,
        dateRange: DateRange,
        needsReview: Bool,
        minAmount: Double?,
        maxAmount: Double?,
        sortOption: SortOption
    ) -> [Receipt] {

        var localFilteredReceipts = receipts

        // Search Text Filter
        if !searchText.isEmpty {
            let lowercasedSearchText = searchText.lowercased()
            localFilteredReceipts = localFilteredReceipts.filter { receipt in
                if receipt.primaryVendorName?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.vendorInfo?.address?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.vendorInfo?.city?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.vendorInfo?.state?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.displayCategory?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.notes?.description?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.notes?.handwriting?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.notes?.business_purpose?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.transactionInfo?.payment_method?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.transactionInfo?.transaction_id?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.rawOCRText?.lowercased().contains(lowercasedSearchText) == true { return true }
                if receipt.receiptType?.lowercased().contains(lowercasedSearchText) == true { return true }

                if let items = receipt.items {
                    for item in items {
                        if item.description?.lowercased().contains(lowercasedSearchText) == true { return true }
                        if item.sku?.lowercased().contains(lowercasedSearchText) == true { return true }
                        if item.expense_category?.lowercased().contains(lowercasedSearchText) == true { return true }
                        if item.tax_category?.lowercased().contains(lowercasedSearchText) == true { return true }
                         if item.codes?.contains(where: { $0.lowercased().contains(lowercasedSearchText) }) == true { return true }
                    }
                }
                return false
            }
        }

        // Category Filter
        if filterCategory != "All" {
            localFilteredReceipts = localFilteredReceipts.filter { receipt in
                if receipt.displayCategory?.localizedCaseInsensitiveCompare(filterCategory) == .orderedSame {
                    return true
                }
                if let items = receipt.items {
                    for item in items {
                        if item.expense_category?.localizedCaseInsensitiveCompare(filterCategory) == .orderedSame {
                            return true
                        }
                    }
                }
                return false
            }
        }

        // Date Range Filter
        if let dateInterval = dateRange.dateInterval {
            localFilteredReceipts = localFilteredReceipts.filter { receipt in
                guard let receiptDate = receipt.parsedDate else { return false }
                return dateInterval.contains(receiptDate)
            }
        }

        // Amount Range Filters
        if let minAmount = minAmount {
            localFilteredReceipts = localFilteredReceipts.filter { ($0.totals?.total ?? 0) >= minAmount }
        }

        if let maxAmount = maxAmount {
            localFilteredReceipts = localFilteredReceipts.filter { ($0.totals?.total ?? 0) <= maxAmount }
        }

        // Needs Review Filter
        if needsReview {
            localFilteredReceipts = localFilteredReceipts.filter { $0.needsReview }
        }

        return localFilteredReceipts.sorted(by: sortOption.sortDescriptor)
    }
}
