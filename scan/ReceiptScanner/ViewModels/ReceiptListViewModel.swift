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
    // Updated to use ReceiptFilterSortEngine.DateRange
    @Published var selectedDateRange = ReceiptFilterSortEngine.DateRange.all
    // Updated to use ReceiptFilterSortEngine.SortOption
    @Published var sortOption = ReceiptFilterSortEngine.SortOption.newest
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

    // Filter Options Enums (DateRange, SortOption) are now moved to ReceiptFilterSortEngine.swift

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
        // Initial filtering and sorting after loading receipts
        self.filteredReceipts = ReceiptFilterSortEngine.applyFiltersAndSort(
            receipts: self.receipts,
            searchText: self.searchText,
            filterCategory: self.selectedCategory, // Name matches what applyFiltersAndSort expects
            dateRange: self.selectedDateRange,
            needsReview: self.showingNeedsReview,
            minAmount: self.minAmount,
            maxAmount: self.maxAmount,
            sortOption: self.sortOption
        )
         updateStatistics()
    }

    // MARK: - Filtering and Sorting Logic (Now in ReceiptFilterSortEngine)
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
        .map { (textAndCatFilters, amountAndDataFilters) -> [Receipt] in // Removed [weak self] as not strictly needed for static call
            let (searchText, category, dateRange, needsReview) = textAndCatFilters
            let (minAmt, maxAmt, allReceipts, sortOpt) = amountAndDataFilters

            // Call the static method from ReceiptFilterSortEngine
            return ReceiptFilterSortEngine.applyFiltersAndSort(
                receipts: allReceipts,
                searchText: searchText,
                filterCategory: category, // Parameter name `category` from tuple maps to `filterCategory` in engine
                dateRange: dateRange,
                needsReview: needsReview,
                minAmount: minAmt,
                maxAmount: maxAmt,
                sortOption: sortOpt
            )
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

    // applyFiltersAndSort method is now removed from here.

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
            // Ensure generateTaxSummary uses the correct DateRange type if it's a parameter
            let summary = generateTaxSummary(receipts: receiptsToExport, dateRange: self.selectedDateRange)

            switch format {
            case .csv:
                result = exportService.exportToCSV(receipts: receiptsToExport)
            case .json:
                result = exportService.exportToJSON(receipts: receiptsToExport, taxSummary: summary)
            case .pdf:
                result = exportService.exportToPDF(receipts: receiptsToExport, taxSummary: summary)
            case .excel:
                result = exportService.exportToExcel(receipts: receiptsToExport)
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

    // Updated to use ReceiptFilterSortEngine.DateRange
    func generateTaxSummary(receipts: [Receipt], dateRange: ReceiptFilterSortEngine.DateRange = .all) -> TaxSummary {
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
        // Updated to use ReceiptFilterSortEngine.DateRange
        selectedDateRange = ReceiptFilterSortEngine.DateRange.all
        showingNeedsReview = false
        minAmount = nil
        maxAmount = nil
        // sortOption is not typically reset by clearFilters, but if it were:
        // sortOption = ReceiptFilterSortEngine.SortOption.newest
    }

    func setAmountRange(min: Double?, max: Double?) {
        minAmount = min
        maxAmount = max
    }

    func refreshData() {
        loadReceipts()
    }
}

// MARK: - Tax Summary Model (Still defined here, ensure DateRange usage is consistent if it was a param)
struct TaxSummary {
    let dateRangeString: String // This was already String, so no direct type change needed here.
                                // The generateTaxSummary method's parameter type was changed.
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
