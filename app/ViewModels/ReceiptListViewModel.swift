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
    // @Published var totalAmount: Double = 0.0 // Will use totals from new Receipt struct if needed
    @Published var needsReviewCount = 0
    @Published var categoryBreakdown: [String: Double] = [:] // Based on new Receipt.displayCategory
    @Published var monthlyTotals: [String: Double] = [:]   // Based on new Receipt.totals.total

    // MARK: - Export Properties
    @Published var shareableExportURL: URL? = nil
    @Published var showingShareSheet = false
    @Published var isExporting = false
    @Published var exportError: ExportService.ExportError? = nil // For showing alerts

    // MARK: - Services
    private let coreDataManager = CoreDataManager.shared
    private let exportService = ExportService() // Added ExportService instance
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Filter Options
    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"
        case lastYear = "Last Year"
        case custom = "Custom Range" // Assuming custom range selection UI exists elsewhere

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
                // Use parsedDate which comes from transactionInfo.date (String)
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
                // displayCategory is a computed property in Receipt.swift
                return { ($0.displayCategory ?? "").localizedCaseInsensitiveCompare($1.displayCategory ?? "") == .orderedAscending }
            }
        }
    }

    // MARK: - Initialization
    init() {
        // Initial load can be triggered by View's onAppear or here.
        // For preview and simplicity, it's often fine here.
        loadReceipts() // Initial load
        setupSubscriptions()
    }

    // MARK: - Data Loading
    func loadReceipts() {
        isLoading = true
        errorMessage = nil

        // Assuming CoreDataManager.fetchReceipts() is updated for the new Receipt structure
        self.receipts = coreDataManager.fetchReceipts()
        self.isLoading = false
        if self.receipts.isEmpty {
            // self.errorMessage = "No receipts found." // Optional: message for empty state
            print("ℹ️ ReceiptListViewModel: No receipts found in Core Data.")
        } else {
            print("✅ ReceiptListViewModel: Loaded \(self.receipts.count) receipts")
        }
        // updateStatistics() will be called by the pipeline when `receipts` changes if it's part of amounts.2
        // Explicitly call applyFiltersAndSort to initialize filteredReceipts correctly after load.
        // The subscription might not fire immediately if receipts is set before subscribers are fully ready.
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
         updateStatistics() // Update statistics after initial load and filtering
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
            $receipts, // Triggered when receipts array itself is replaced
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

        // Update statistics whenever filteredReceipts changes
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
        category: String, // This is displayCategory
        dateRange: DateRange,
        needsReview: Bool,
        minAmount: Double?,
        maxAmount: Double?,
        sortOption: SortOption
    ) -> [Receipt] {

        var filtered = receipts

        if !searchText.isEmpty {
            filtered = filtered.filter { receipt in
                (receipt.primaryVendorName?.localizedCaseInsensitiveContains(searchText) == true) ||
                (receipt.displayCategory?.localizedCaseInsensitiveContains(searchText) == true) ||
                (receipt.notes?.description?.localizedCaseInsensitiveContains(searchText) == true) || // notes.description
                (receipt.items?.contains(where: { $0.description?.localizedCaseInsensitiveContains(searchText) == true }) == true) ||
                (receipt.rawOCRText?.localizedCaseInsensitiveContains(searchText) == true) ||
                (receipt.vendorInfo?.city?.localizedCaseInsensitiveContains(searchText) == true) ||
                (receipt.vendorInfo?.state?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }

        if category != "All" {
            filtered = filtered.filter { $0.displayCategory == category }
        }

        if let dateInterval = dateRange.dateInterval {
            filtered = filtered.filter { receipt in
                guard let receiptDate = receipt.parsedDate else { return false } // Use parsedDate
                return dateInterval.contains(receiptDate)
            }
        }

        if let minAmount = minAmount {
            filtered = filtered.filter { $0.totals?.total ?? 0 >= minAmount }
        }

        if let maxAmount = maxAmount {
            filtered = filtered.filter { $0.totals?.total ?? 0 <= maxAmount }
        }

        if needsReview {
            filtered = filtered.filter { $0.needsReview }
        }

        return filtered.sorted(by: sortOption.sortDescriptor)
    }

    // MARK: - Statistics
    private func updateStatistics() {
        // Update statistics based on FILTERED receipts, not all receipts
        let receiptsToAnalyze = filteredReceipts

        totalReceipts = receiptsToAnalyze.count
        // totalAmount = receiptsToAnalyze.compactMap { $0.totals?.total }.reduce(0, +) // Use filtered for stats
        needsReviewCount = receiptsToAnalyze.filter { $0.needsReview }.count

        categoryBreakdown = Dictionary(grouping: receiptsToAnalyze) { $0.displayCategory ?? "Uncategorized" }
            .mapValues { $0.compactMap { $0.totals?.total }.reduce(0, +) }

        monthlyTotals = Dictionary(grouping: receiptsToAnalyze) { receipt in
            guard let date = receipt.parsedDate else { return "Unknown Date" } // Use parsedDate
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: date)
        }
        .mapValues { $0.compactMap { $0.totals?.total }.reduce(0, +) }
    }

    // MARK: - Receipt Management
    func deleteReceipt(_ receipt: Receipt) {
        coreDataManager.deleteReceipt(withId: receipt.id) // CoreDataManager handles its own fetch/delete
        // Optimistically update local list or reload
        if let index = receipts.firstIndex(where: { $0.id == receipt.id }) {
            receipts.remove(at: index)
        }
        // filteredReceipts will update via Combine pipeline due to `receipts` changing.
        // updateStatistics() will also be called by pipeline.
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
        // filteredReceipts will update via Combine pipeline.
        print("✅ ReceiptListViewModel: Receipt marked as reviewed for ID \(receipt.id)")
    }

    func updateReceipt(_ receipt: Receipt) { // General update
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
        shareableExportURL = nil // Clear previous URL

        // Use filteredReceipts for export, as this reflects what the user is currently seeing.
        let receiptsToExport = self.filteredReceipts

        if receiptsToExport.isEmpty {
            print("ℹ️ No receipts to export for the current filter.")
            // self.exportError = ExportService.ExportError.noData // Or a custom error
            // self.isExporting = false
            // return
            // For now, proceed with empty data, ExportService might handle it or return error.
        }

        Task { // Ensure background execution for potentially long export tasks
            let result: Result<URL, ExportService.ExportError>
            let summary = generateTaxSummary(receipts: receiptsToExport) // Generate summary based on receiptsToExport

            switch format {
            case .csv:
                result = exportService.exportToCSV(receipts: receiptsToExport)
            case .json:
                result = exportService.exportToJSON(receipts: receiptsToExport, taxSummary: summary)
            case .pdf:
                result = exportService.exportToPDF(receipts: receiptsToExport, taxSummary: summary)
            // If .excel or other formats are added to ExportFormat enum but not implemented in ExportService:
            default:
                print("❌ Export format \(format.rawValue) not implemented yet.")
                result = .failure(.exportFailed(reason: "Format \(format.rawValue) not implemented."))
            }

            await MainActor.run { // Switch back to main thread for UI updates
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

    // Modified generateTaxSummary to accept receipts
    func generateTaxSummary(receipts: [Receipt], dateRange: DateRange = .all) -> TaxSummary {
        // Filter business receipts only (assuming displayCategory is reliable for "Personal")
        let taxReceipts = receipts.filter { $0.displayCategory != "Personal" }

        let categoryTotals = Dictionary(grouping: taxReceipts) { $0.displayCategory ?? "Other Business" }
            .mapValues { receiptsInCat in
                receiptsInCat.compactMap { $0.totals?.total }.reduce(0, +)
            }

        let totalDeductions = categoryTotals.values.reduce(0, +)

        return TaxSummary(
            dateRangeString: dateRange.rawValue, // Pass string directly
            totalDeductions: totalDeductions,
            categoryBreakdown: categoryTotals,
            receiptCount: taxReceipts.count,
            needsReviewCount: taxReceipts.filter { $0.needsReview }.count,
            receipts: taxReceipts // Pass the filtered tax receipts
        )
    }

    // MARK: - Utility Methods
    var availableCategories: [String] {
        // Use displayCategory for UI consistency
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
        // This will re-trigger the Core Data fetch and update the `receipts` array,
        // which in turn will update `filteredReceipts` and statistics via the Combine pipeline.
        loadReceipts()
    }
}

// MARK: - Tax Summary Model (Updated to use String for dateRange for simplicity)
struct TaxSummary {
    let dateRangeString: String
    let totalDeductions: Double
    let categoryBreakdown: [String: Double]
    let receiptCount: Int
    let needsReviewCount: Int
    let receipts: [Receipt] // Keep actual receipts for detailed PDF/JSON if needed

    var formattedTotalDeductions: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalDeductions)) ?? "$0.00"
    }

    var completionPercentage: Double {
        guard receiptCount > 0 else { return 1.0 } // Or 0.0 if no receipts means 0% complete
        return Double(receiptCount - needsReviewCount) / Double(receiptCount)
    }
}

// MARK: - Batch Operations (Updated to use new Receipt structure if necessary)
extension ReceiptListViewModel {
    @Published var isInSelectionMode = false
    @Published var selectedReceiptIds: Set<UUID> = []

    var selectedReceipts: [Receipt] {
        // Ensure this uses the currently displayed (and filtered) list for selection context
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

    func selectAllFilteredReceipts() { // Renamed for clarity
        selectedReceiptIds = Set(filteredReceipts.map { $0.id })
    }

    func deselectAllReceipts() {
        selectedReceiptIds.removeAll()
    }

    func deleteSelectedReceipts() {
        let receiptsToDelete = selectedReceipts // selectedReceipts already refers to filtered list
        for receipt in receiptsToDelete {
            deleteReceipt(receipt) // This will update `self.receipts` and pipeline will update `filteredReceipts`
        }
        selectedReceiptIds.removeAll() // Clear selection
        if receiptsToDelete.count > 0 && filteredReceipts.isEmpty { // If all visible items were deleted
             isInSelectionMode = false // Exit selection mode
        } else if selectedReceipts.isEmpty { // If selection becomes empty
            // Optionally exit selection mode or leave it to user
        }
    }

    func markSelectedAsReviewed() {
        let receiptsToUpdate = selectedReceipts.filter { $0.needsReview }
        for receipt in receiptsToUpdate {
            markAsReviewed(receipt) // This updates `self.receipts` and pipeline updates `filteredReceipts`
        }
        // Selection remains, user can deselect or continue.
        // Or clear selection:
        // selectedReceiptIds.removeAll()
    }

    func bulkUpdateCategory(_ newCategory: String) {
        let receiptsToUpdate = selectedReceipts
        for var receipt in receiptsToUpdate { // Make receipt mutable
            // Updating category is complex due to new structure.
            // This might mean changing receipt.receiptType or items' expense_category.
            // For simplicity, let's assume we're changing a conceptual 'displayCategory'
            // which might mean updating the receiptType for now.
            // This is a placeholder for more robust category update logic.
            receipt.receiptType = newCategory // Example: treat newCategory as the new receiptType
            // If items exist, ideally update their expense_category too
            if receipt.items != nil {
                receipt.items = receipt.items?.map {
                    var item = $0
                    item.expense_category = newCategory
                    return item
                }
            }
            updateReceipt(receipt)
        }
        // selectedReceiptIds.removeAll() // Optionally clear selection
    }
}

// MARK: - Core Data Interaction (Simplified, assuming CoreDataManager methods handle details)
extension ReceiptListViewModel {
    func clearAllData() {
        coreDataManager.clearAllReceipts { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.receipts.removeAll() // This will trigger UI updates via Combine
                    self?.selectedReceiptIds.removeAll()
                    // self?.updateStatistics() // Will be called by pipeline
                    print("✅ ReceiptListViewModel: All data cleared successfully")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ ReceiptListViewModel: Error clearing data: \(error)")
                }
            }
        }
    }

    // This was a placeholder, ScanViewModel now handles new receipt processing.
    // func processNewReceipt(image: UIImage) {
    //     print("🔄 This method is deprecated. Use ScanViewModel for new receipts.")
    // }
}
