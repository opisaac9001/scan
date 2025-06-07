import SwiftUI

struct EnhancedReceiptListView: View {
    @EnvironmentObject var viewModel: ReceiptListViewModel
    @State private var showingFilter = false
    @State private var showingSort = false
    @State private var selectedReceipt: Receipt?
    @State private var searchText = ""
    @State private var showingBulkActions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Quick Stats Bar
                if !viewModel.filteredReceipts.isEmpty {
                    quickStatsBar
                }
                
                // Main Content
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.filteredReceipts.isEmpty && searchText.isEmpty {
                    EmptyStateView()
                } else if viewModel.filteredReceipts.isEmpty && !searchText.isEmpty {
                    SearchEmptyView()
                } else {
                    receiptsList
                }
            }
            .navigationTitle("Receipts (\(viewModel.filteredReceipts.count))")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search receipts, vendors, categories...")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if viewModel.isInSelectionMode {
                        Button("Cancel") {
                            viewModel.toggleSelectionMode()
                        }
                    } else {
                        Menu {
                            Button(action: { showingFilter = true }) {
                                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            
                            Button(action: { showingSort = true }) {
                                Label("Sort", systemImage: "arrow.up.arrow.down")
                            }
                            
                            Button(action: { viewModel.clearFilters() }) {
                                Label("Clear Filters", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if viewModel.isInSelectionMode {
                        Button("Actions") {
                            showingBulkActions = true
                        }
                        .disabled(!viewModel.hasSelectedReceipts)
                    } else {
                        Button("Select") {
                            viewModel.toggleSelectionMode()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilter) {
                FilterView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSort) {
                SortView(viewModel: viewModel)
            }
            .confirmationDialog("Bulk Actions", isPresented: $showingBulkActions) {
                Button("Mark as Reviewed") {
                    viewModel.markSelectedAsReviewed()
                }
                
                Button("Delete Selected", role: .destructive) {
                    viewModel.deleteSelectedReceipts()
                }
                
                Button("Change Category") {
                    // Show category picker
                }
                
                Button("Cancel", role: .cancel) { }
            }
            .refreshable {
                viewModel.refreshData()
            }
        }
    }
    
    private var quickStatsBar: some View {
        HStack(spacing: 20) {
            StatBadge(
                icon: "doc.text",
                value: "\(viewModel.filteredReceipts.count)",
                label: "Total",
                color: .blue
            )
            
            StatBadge(
                icon: "dollarsign.circle",
                value: formatCurrency(viewModel.filteredReceipts.compactMap { $0.amount }.reduce(0, +)),
                label: "Amount",
                color: .green
            )
            
            StatBadge(
                icon: "exclamationmark.triangle",
                value: "\(viewModel.filteredReceipts.filter { $0.needsReview }.count)",
                label: "Review",
                color: .orange
            )
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }
    
    private var receiptsList: some View {
        List {
            ForEach(viewModel.filteredReceipts) { receipt in
                ReceiptRowView(
                    receipt: receipt,
                    isSelected: viewModel.selectedReceiptIds.contains(receipt.id),
                    isSelectionMode: viewModel.isInSelectionMode,
                    onTap: {
                        if viewModel.isInSelectionMode {
                            viewModel.toggleReceiptSelection(receipt)
                        } else {
                            selectedReceipt = receipt
                        }
                    },
                    onLongPress: {
                        viewModel.toggleSelectionMode()
                        viewModel.toggleReceiptSelection(receipt)
                    }
                )
            }
            .onDelete(perform: deleteReceipts)
        }
        .listStyle(PlainListStyle())
        .sheet(item: $selectedReceipt) { receipt in
            ReceiptDetailView(receipt: receipt)
                .environmentObject(viewModel)
        }
    }
    
    private func deleteReceipts(offsets: IndexSet) {
        for index in offsets {
            let receipt = viewModel.filteredReceipts[index]
            viewModel.deleteReceipt(receipt)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection Circle
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            
            // Receipt Thumbnail
            if let imageData = receipt.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
            }
            
            // Receipt Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(receipt.vendor ?? "Unknown Vendor")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let amount = receipt.amount {
                        Text(formatCurrency(amount))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                
                HStack {
                    if let date = receipt.date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let category = receipt.category {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Status indicators
                HStack(spacing: 4) {
                    if receipt.needsReview {
                        Chip(text: "Needs Review", color: .orange)
                    }
                    
                    if let taxCategory = receipt.taxCategory {
                        Chip(text: taxCategory, color: .blue)
                    }
                    
                    Spacer()
                }
            }
            
            // Arrow indicator (when not in selection mode)
            if !isSelectionMode {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct Chip: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading receipts...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Receipts Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start by scanning your first receipt using the camera tab")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Scan Receipt") {
                // Switch to camera tab
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct SearchEmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Results Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your search terms or filters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// Filter and Sort Views
struct FilterView: View {
    @ObservedObject var viewModel: ReceiptListViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(viewModel.availableCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section("Date Range") {
                    Picker("Date Range", selection: $viewModel.selectedDateRange) {
                        ForEach(ReceiptListViewModel.DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                }
                
                Section("Amount Range") {
                    HStack {
                        Text("Min:")
                        TextField("0", value: $viewModel.minAmount, format: .currency(code: "USD"))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Max:")
                        TextField("0", value: $viewModel.maxAmount, format: .currency(code: "USD"))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section("Status") {
                    Toggle("Needs Review Only", isOn: $viewModel.showingNeedsReview)
                }
            }
            .navigationTitle("Filter Receipts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        viewModel.clearFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct SortView: View {
    @ObservedObject var viewModel: ReceiptListViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ReceiptListViewModel.SortOption.allCases, id: \.self) { option in
                    HStack {
                        Text(option.rawValue)
                        Spacer()
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.sortOption = option
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EnhancedReceiptListView()
        .environmentObject(ReceiptListViewModel())
}
