import Foundation
import SwiftUI
import Combine

@MainActor
class ReceiptListViewModel: ObservableObject {
    // MARK: - Published Properties for List Display & Filtering
    @Published var receipts: [Receipt] = []
    @Published var filteredReceipts: [Receipt] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedCategory = "All"
    @Published var selectedDateRange = DateRange.all
    @Published var sortOption = SortOption.newest
    @Published var showingNeedsReview = false
    @Published var minAmount: Double? = nil
    @Published var maxAmount: Double? = nil

    // MARK: - Statistics
    @Published var totalReceipts = 0
    @Published var needsReviewCount = 0
    @Published var categoryBreakdown: [String: Double] = [:]
    @Published var monthlyTotals: [String: Double] = [:]

    // MARK: - Export Properties
    @Published var shareableExportURL: URL? = nil
    @Published var showingShareSheet = false
    @Published var isExporting = false
    @Published var exportError: ExportService.ExportError? = nil

    // MARK: - Services
    private let coreDataManager = CoreDataManager.shared
    private let exportService = ExportService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Filter Options
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

    // MARK: - Initialization
    init() {
        loadReceipts()
        setupSubscriptions()
    }

    // MARK: - Data Loading
    func loadReceipts() {
        isLoading = true
        errorMessage = nil
        self.receipts = coreDataManager.fetchReceipts()
        self.isLoading = false
        if self.receipts.isEmpty {
            print("ℹ️ ReceiptListViewModel: No receipts found in Core Data.")
        } else {
            print("✅ ReceiptListViewModel: Loaded \(self.receipts.count) receipts")
        }
        self.filteredReceipts = applyFiltersAndSort(
            receipts: self.receipts,
            searchText: self.searchText,
            category: self.selectedCategory,
            dateRange: self.selectedDateRange,
            needsReview: self.showingNeedsReview,
            minAmount: self.minAmount,
            maxAmount: self.maxAmount,
            sortOption: self.sortOption
        )
         updateStatistics()
    }

    // MARK: - Filtering and Sorting
    private func setupSubscriptions() {
        Publishers.CombineLatest4(
            $searchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main),
            $selectedCategory,
            $selectedDateRange,
            $showingNeedsReview
        )
        .combineLatest(Publishers.CombineLatest4(
            $minAmount,
            $maxAmount,
            $receipts,
            $sortOption
        ))
        .map { [weak self] (textAndCatFilters, amountAndDataFilters) in
            let (searchText, category, dateRange, needsReview) = textAndCatFilters
            let (minAmt, maxAmt, allReceipts, sortOpt) = amountAndDataFilters

            return self?.applyFiltersAndSort(
                receipts: allReceipts,
                searchText: searchText,
                category: category,
                dateRange: dateRange,
                needsReview: needsReview,
                minAmount: minAmt,
                maxAmount: maxAmt,
                sortOption: sortOpt
            ) ?? []
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.filteredReceipts, on: self)
        .store(in: &cancellables)

        $filteredReceipts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatistics()
            }
            .store(in: &cancellables)
    }

    private func applyFiltersAndSort(
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

        if let dateInterval = dateRange.dateInterval {
            localFilteredReceipts = localFilteredReceipts.filter { receipt in
                guard let receiptDate = receipt.parsedDate else { return false }
                return dateInterval.contains(receiptDate)
            }
        }

        if let minAmount = minAmount {
            localFilteredReceipts = localFilteredReceipts.filter { ($0.totals?.total ?? 0) >= minAmount }
        }

        if let maxAmount = maxAmount {
            localFilteredReceipts = localFilteredReceipts.filter { ($0.totals?.total ?? 0) <= maxAmount }
        }

        if needsReview {
            localFilteredReceipts = localFilteredReceipts.filter { $0.needsReview }
        }

        return localFilteredReceipts.sorted(by: sortOption.sortDescriptor)
    }

    // MARK: - Statistics
    private func updateStatistics() {
        let receiptsToAnalyze = filteredReceipts
        totalReceipts = receiptsToAnalyze.count
        needsReviewCount = receiptsToAnalyze.filter { $0.needsReview }.count

        categoryBreakdown = Dictionary(grouping: receiptsToAnalyze) { $0.displayCategory ?? "Uncategorized" }
            .mapValues { $0.compactMap { $0.totals?.total }.reduce(0, +) }

        monthlyTotals = Dictionary(grouping: receiptsToAnalyze) { receipt in
            guard let date = receipt.parsedDate else { return "Unknown Date" }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: date)
        }
        .mapValues { $0.compactMap { $0.totals?.total }.reduce(0, +) }
    }

    // MARK: - Receipt Management
    func deleteReceipt(_ receipt: Receipt) {
        coreDataManager.deleteReceipt(withId: receipt.id)
        if let index = receipts.firstIndex(where: { $0.id == receipt.id }) {
            receipts.remove(at: index)
        }
        print("✅ ReceiptListViewModel: Receipt delete initiated for ID \(receipt.id)")
    }

    func markAsReviewed(_ receipt: Receipt) {
        var updatedReceipt = receipt
        updatedReceipt.needsReview = false
        updatedReceipt.updatedAt = Date()
        coreDataManager.updateReceipt(updatedReceipt)

        if let index = receipts.firstIndex(where: { $0.id == receipt.id }) {
            receipts[index] = updatedReceipt
        }
        print("✅ ReceiptListViewModel: Receipt marked as reviewed for ID \(receipt.id)")
    }

    func updateReceipt(_ receipt: Receipt) {
        var mutableReceipt = receipt
        mutableReceipt.updatedAt = Date()
        coreDataManager.updateReceipt(mutableReceipt)

        if let index = receipts.firstIndex(where: { $0.id == receipt.id }) {
            receipts[index] = mutableReceipt
        }
        print("✅ ReceiptListViewModel: Receipt update initiated for ID \(receipt.id)")
    }

    // MARK: - Export Functions
    func exportAndShareReceipts(format: ExportService.ExportFormat) {
        isExporting = true
        exportError = nil
        shareableExportURL = nil

        let receiptsToExport = self.filteredReceipts

        if receiptsToExport.isEmpty {
            print("ℹ️ No receipts to export for the current filter.")
            self.exportError = .noReceiptsToExport
            self.isExporting = false
            return
        }

        Task {
            let result: Result<URL, ExportService.ExportError>
            let summary = generateTaxSummary(receipts: receiptsToExport)

            switch format {
            case .csv:
                result = exportService.exportToCSV(receipts: receiptsToExport)
            case .json:
                result = exportService.exportToJSON(receipts: receiptsToExport, taxSummary: summary)
            case .pdf:
                result = exportService.exportToPDF(receipts: receiptsToExport, taxSummary: summary)
            case .excel:
                result = exportService.exportToExcel(receipts: receiptsToExport) // Call the new stubbed method
            }

            await MainActor.run {
                self.isExporting = false
                switch result {
                case .success(let url):
                    self.shareableExportURL = url
                    self.showingShareSheet = true
                    print("✅ Export successful. URL: \(url)")
                case .failure(let error):
                    self.exportError = error
                    print("❌ Export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func generateTaxSummary(receipts: [Receipt], dateRange: DateRange = .all) -> TaxSummary {
        let taxReceipts = receipts.filter { $0.displayCategory != "Personal" }

        let categoryTotals = Dictionary(grouping: taxReceipts) { $0.displayCategory ?? "Other Business" }
            .mapValues { receiptsInCat in
                receiptsInCat.compactMap { $0.totals?.total }.reduce(0, +)
            }

        let totalDeductions = categoryTotals.values.reduce(0, +)

        return TaxSummary(
            dateRangeString: dateRange.rawValue,
            totalDeductions: totalDeductions,
            categoryBreakdown: categoryTotals,
            receiptCount: taxReceipts.count,
            needsReviewCount: taxReceipts.filter { $0.needsReview }.count,
            receipts: taxReceipts
        )
    }

    // MARK: - Utility Methods
    var availableCategories: [String] {
        let categories = Set(receipts.compactMap { $0.displayCategory })
        return ["All"] + categories.sorted()
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = "All"
        selectedDateRange = .all
        showingNeedsReview = false
        minAmount = nil
        maxAmount = nil
    }

    func setAmountRange(min: Double?, max: Double?) {
        minAmount = min
        maxAmount = max
    }

    func refreshData() {
        loadReceipts()
    }
}

// MARK: - Tax Summary Model
struct TaxSummary {
    let dateRangeString: String
    let totalDeductions: Double
    let categoryBreakdown: [String: Double]
    let receiptCount: Int
    let needsReviewCount: Int
    let receipts: [Receipt]

    var formattedTotalDeductions: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalDeductions)) ?? "$0.00"
    }

    var completionPercentage: Double {
        guard receiptCount > 0 else { return 1.0 }
        return Double(receiptCount - needsReviewCount) / Double(receiptCount)
    }
}

// MARK: - Batch Operations
extension ReceiptListViewModel {
    @Published var isInSelectionMode = false
    @Published var selectedReceiptIds: Set<UUID> = []

    var selectedReceipts: [Receipt] {
        filteredReceipts.filter { selectedReceiptIds.contains($0.id) }
    }

    var hasSelectedReceipts: Bool {
        !selectedReceiptIds.isEmpty
    }

    func toggleSelectionMode() {
        isInSelectionMode.toggle()
        if !isInSelectionMode {
            selectedReceiptIds.removeAll()
        }
    }

    func toggleReceiptSelection(_ receipt: Receipt) {
        if selectedReceiptIds.contains(receipt.id) {
            selectedReceiptIds.remove(receipt.id)
        } else {
            selectedReceiptIds.insert(receipt.id)
        }
    }

    func selectAllFilteredReceipts() {
        selectedReceiptIds = Set(filteredReceipts.map { $0.id })
    }

    func deselectAllReceipts() {
        selectedReceiptIds.removeAll()
    }

    func deleteSelectedReceipts() {
        let receiptsToDelete = selectedReceipts
        for receipt in receiptsToDelete {
            deleteReceipt(receipt)
        }
        selectedReceiptIds.removeAll()
        if receiptsToDelete.count > 0 && filteredReceipts.isEmpty {
             isInSelectionMode = false
        } else if selectedReceipts.isEmpty {
        }
    }

    func markSelectedAsReviewed() {
        let receiptsToUpdate = selectedReceipts.filter { $0.needsReview }
        for receipt in receiptsToUpdate {
            markAsReviewed(receipt)
        }
    }

    func bulkUpdateCategory(_ newCategory: String) {
        let receiptsToUpdate = selectedReceipts
        for var receipt in receiptsToUpdate {
            receipt.receiptType = newCategory
            if receipt.items != nil {
                receipt.items = receipt.items?.map {
                    var item = $0
                    item.expense_category = newCategory
                    return item
                }
            }
            updateReceipt(receipt)
        }
    }
}

// MARK: - Core Data Interaction
extension ReceiptListViewModel {
    func clearAllData() {
        coreDataManager.clearAllReceipts { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.receipts.removeAll()
                    self?.selectedReceiptIds.removeAll()
                    print("✅ ReceiptListViewModel: All data cleared successfully")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ ReceiptListViewModel: Error clearing data: \(error)")
                }
            }
        }
    }
}
