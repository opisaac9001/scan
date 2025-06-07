import Foundation
import SwiftUI
import Combine

@MainActor
class ReceiptListViewModel: ObservableObject {
      // MARK: - Published Properties
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
    @Published var totalAmount: Double = 0.0
    @Published var needsReviewCount = 0
    @Published var categoryBreakdown: [String: Double] = [:]
    @Published var monthlyTotals: [String: Double] = [:]
    
    // MARK: - Services
    private let coreDataManager = CoreDataManager.shared
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
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
                let endOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
                return DateInterval(start: startOfLastMonth, end: endOfLastMonth)
            case .thisYear:
                let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                return DateInterval(start: startOfYear, end: now)
            case .lastYear:
                let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                let startOfLastYear = calendar.dateInterval(of: .year, for: lastYear)?.start ?? now
                let endOfLastYear = calendar.dateInterval(of: .year, for: lastYear)?.end ?? now
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
                return { $0.date ?? Date.distantPast > $1.date ?? Date.distantPast }
            case .oldest:
                return { $0.date ?? Date.distantPast < $1.date ?? Date.distantPast }
            case .amountHighest:
                return { $0.amount ?? 0 > $1.amount ?? 0 }
            case .amountLowest:
                return { $0.amount ?? 0 < $1.amount ?? 0 }
            case .vendor:
                return { ($0.vendor ?? "").localizedCaseInsensitiveCompare($1.vendor ?? "") == .orderedAscending }
            case .category:
                return { ($0.category ?? "").localizedCaseInsensitiveCompare($1.category ?? "") == .orderedAscending }
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        setupSubscriptions()
        loadReceipts()
    }
    
    // MARK: - Data Loading
    func loadReceipts() {
        isLoading = true
        errorMessage = nil
        
        coreDataManager.fetchReceipts { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let receipts):
                    self?.receipts = receipts
                    self?.updateStatistics()
                    print("✅ ReceiptListViewModel: Loaded \(receipts.count) receipts")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ ReceiptListViewModel: Error loading receipts: \(error)")
                }
            }
        }
    }
      // MARK: - Filtering and Sorting
    private func setupSubscriptions() {
        // Combine search, category, date, and amount filters
        Publishers.CombineLatest(
            Publishers.CombineLatest4(
                $searchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main),
                $selectedCategory,
                $selectedDateRange,
                $showingNeedsReview
            ),
            Publishers.CombineLatest3(
                $minAmount,
                $maxAmount,
                $receipts
            )
        )
        .combineLatest($sortOption)
        .map { [weak self] (filters, amounts, sort) in
            self?.applyFiltersAndSort(
                receipts: amounts.2,
                searchText: filters.0,
                category: filters.1,
                dateRange: filters.2,
                needsReview: filters.3,
                minAmount: amounts.0,
                maxAmount: amounts.1,
                sortOption: sort
            ) ?? []
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.filteredReceipts, on: self)
        .store(in: &cancellables)
    }
      private func applyFiltersAndSort(
        receipts: [Receipt],
        searchText: String,
        category: String,
        dateRange: DateRange,
        needsReview: Bool,
        minAmount: Double?,
        maxAmount: Double?,
        sortOption: SortOption
    ) -> [Receipt] {
        
        var filtered = receipts
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { receipt in
                (receipt.vendor?.localizedCaseInsensitiveContains(searchText) == true) ||
                (receipt.category?.localizedCaseInsensitiveContains(searchText) == true) ||
                (receipt.notes?.localizedCaseInsensitiveContains(searchText) == true) ||
                (receipt.location?.localizedCaseInsensitiveContains(searchText) == true) ||
                (receipt.rawOCRText?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
        
        // Category filter
        if category != "All" {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Date range filter
        if let dateInterval = dateRange.dateInterval {
            filtered = filtered.filter { receipt in
                guard let receiptDate = receipt.date else { return false }
                return dateInterval.contains(receiptDate)
            }
        }
        
        // Amount range filter
        if let minAmount = minAmount {
            filtered = filtered.filter { receipt in
                guard let amount = receipt.amount else { return false }
                return amount >= minAmount
            }
        }
        
        if let maxAmount = maxAmount {
            filtered = filtered.filter { receipt in
                guard let amount = receipt.amount else { return false }
                return amount <= maxAmount
            }
        }
        
        // Needs review filter
        if needsReview {
            filtered = filtered.filter { $0.needsReview }
        }
        
        // Sort
        return filtered.sorted(by: sortOption.sortDescriptor)
    }
    
    // MARK: - Statistics
    private func updateStatistics() {
        totalReceipts = receipts.count
        totalAmount = receipts.compactMap { $0.amount }.reduce(0, +)
        needsReviewCount = receipts.filter { $0.needsReview }.count
        
        // Category breakdown
        categoryBreakdown = Dictionary(grouping: receipts) { $0.category ?? "Uncategorized" }
            .mapValues { $0.compactMap { $0.amount }.reduce(0, +) }
        
        // Monthly totals
        let calendar = Calendar.current
        monthlyTotals = Dictionary(grouping: receipts) { receipt in
            guard let date = receipt.date else { return "Unknown" }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: date)
        }
        .mapValues { $0.compactMap { $0.amount }.reduce(0, +) }
    }
    
    // MARK: - Receipt Management
    func deleteReceipt(_ receipt: Receipt) {
        coreDataManager.deleteReceipt(receipt) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.receipts.removeAll { $0.id == receipt.id }
                    self?.updateStatistics()
                    print("✅ ReceiptListViewModel: Receipt deleted successfully")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ ReceiptListViewModel: Error deleting receipt: \(error)")
                }
            }
        }
    }
    
    func markAsReviewed(_ receipt: Receipt) {
        let updatedReceipt = Receipt(
            id: receipt.id,
            imageData: receipt.imageData,
            vendor: receipt.vendor,
            amount: receipt.amount,
            date: receipt.date,
            category: receipt.category,
            notes: receipt.notes,
            rawText: receipt.rawText,
            confidence: receipt.confidence,
            paymentMethod: receipt.paymentMethod,
            location: receipt.location,
            tags: receipt.tags,
            needsReview: false, // Mark as reviewed
            taxCategory: receipt.taxCategory,
            businessPurpose: receipt.businessPurpose,
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
        
        updateReceipt(updatedReceipt)
    }
    
    func updateReceipt(_ receipt: Receipt) {
        coreDataManager.updateReceipt(receipt) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedReceipt):
                    if let index = self?.receipts.firstIndex(where: { $0.id == receipt.id }) {
                        self?.receipts[index] = updatedReceipt
                        self?.updateStatistics()
                    }
                    print("✅ ReceiptListViewModel: Receipt updated successfully")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ ReceiptListViewModel: Error updating receipt: \(error)")
                }
            }
        }
    }
    
    // MARK: - Export Functions
    func exportReceiptsForTaxes(dateRange: DateRange = .thisYear) -> [Receipt] {
        let receiptsForExport = receipts.filter { receipt in
            // Filter business receipts only
            guard let category = receipt.taxCategory,
                  category != "Personal" else { return false }
            
            // Apply date filter
            if let dateInterval = dateRange.dateInterval {
                guard let receiptDate = receipt.date else { return false }
                return dateInterval.contains(receiptDate)
            }
            
            return true
        }
        
        return receiptsForExport.sorted { receipt1, receipt2 in
            (receipt1.date ?? Date.distantPast) < (receipt2.date ?? Date.distantPast)
        }
    }
    
    func generateTaxSummary(for dateRange: DateRange = .thisYear) -> TaxSummary {
        let taxReceipts = exportReceiptsForTaxes(dateRange: dateRange)
        
        let categoryTotals = Dictionary(grouping: taxReceipts) { $0.taxCategory ?? "Other" }
            .mapValues { receipts in
                receipts.compactMap { $0.amount }.reduce(0, +)
            }
        
        let totalDeductions = categoryTotals.values.reduce(0, +)
        let receiptCount = taxReceipts.count
        let needsReviewCount = taxReceipts.filter { $0.needsReview }.count
        
        return TaxSummary(
            dateRange: dateRange,
            totalDeductions: totalDeductions,
            categoryBreakdown: categoryTotals,
            receiptCount: receiptCount,
            needsReviewCount: needsReviewCount,
            receipts: taxReceipts
        )
    }
    
    // MARK: - Utility Methods
    var availableCategories: [String] {
        let categories = Set(receipts.compactMap { $0.category })
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
    let dateRange: ReceiptListViewModel.DateRange
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
        receipts.filter { selectedReceiptIds.contains($0.id) }
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
    
    func selectAllReceipts() {
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
        isInSelectionMode = false
    }
    
    func markSelectedAsReviewed() {
        let receiptsToUpdate = selectedReceipts.filter { $0.needsReview }
        for receipt in receiptsToUpdate {
            markAsReviewed(receipt)
        }
        selectedReceiptIds.removeAll()
    }
    
    func bulkUpdateCategory(_ newCategory: String) {
        let receiptsToUpdate = selectedReceipts
        for receipt in receiptsToUpdate {
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
                needsReview: receipt.needsReview,
                taxCategory: newCategory,
                businessPurpose: receipt.businessPurpose,
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
            updateReceipt(updatedReceipt)
        }
        selectedReceiptIds.removeAll()
    }
}

extension ReceiptListViewModel {
    // MARK: - Data Management
    func clearAllData() {
        coreDataManager.clearAllReceipts { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.receipts.removeAll()
                    self?.selectedReceiptIds.removeAll()
                    self?.updateStatistics()
                    print("✅ ReceiptListViewModel: All data cleared successfully")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ ReceiptListViewModel: Error clearing data: \(error)")
                }
            }
        }
    }
    
    func processNewReceipt(image: UIImage) {
        // This would trigger the scanning workflow
        // For now, we'll indicate that this would start a scan
        print("🔄 Processing new receipt image...")
        // In a real implementation, this would integrate with ScanViewModel
    }
}
