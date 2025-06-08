import SwiftUI

struct ReceiptListView: View {
    @EnvironmentObject var viewModel: ReceiptListViewModel
    @State private var showingFilter = false
    @State private var searchText = ""
    @State private var selectedReceipt: Receipt?
    
    var filteredReceipts: [Receipt] {
        if searchText.isEmpty {
            return viewModel.receipts
        } else {
            return viewModel.receipts.filter { receipt in
                receipt.vendor?.localizedCaseInsensitiveContains(searchText) == true ||
                receipt.category?.localizedCaseInsensitiveContains(searchText) == true ||
                receipt.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                receipt.rawText?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Processing receipt...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredReceipts.isEmpty {
                    EmptyStateView()
                } else {
                    receiptsList
                }
            }            .navigationTitle("Receipts")
            .searchable(text: $searchText, prompt: "Search receipts...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isInSelectionMode {
                        Button("Cancel") {
                            viewModel.toggleSelectionMode()
                        }
                    } else {
                        Button("Select") {
                            viewModel.toggleSelectionMode()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isInSelectionMode {
                        Menu {
                            Button("Select All") {
                                viewModel.selectAllReceipts()
                            }
                            Button("Deselect All") {
                                viewModel.deselectAllReceipts()
                            }
                            
                            Divider()
                            
                            Button("Mark as Reviewed") {
                                viewModel.markSelectedAsReviewed()
                            }
                            
                            Menu("Change Category") {
                                ForEach(viewModel.availableCategories.filter { $0 != "All" }, id: \.self) { category in
                                    Button(category) {
                                        viewModel.bulkUpdateCategory(category)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Button("Delete Selected", role: .destructive) {
                                viewModel.deleteSelectedReceipts()
                            }
                        } label: {
                            Text("Actions")
                        }
                    } else {
                        Button("Filter") {
                            showingFilter = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilter) {
                FilterView(viewModel: viewModel)
            }
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
            .onAppear {
                viewModel.loadReceipts()
            }
        }
    }
      private var receiptsList: some View {
        List {
            ForEach(filteredReceipts) { receipt in
                ReceiptRowView(
                    receipt: receipt,
                    isSelected: viewModel.selectedReceiptIds.contains(receipt.id),
                    isInSelectionMode: viewModel.isInSelectionMode
                )
                .onTapGesture {
                    if viewModel.isInSelectionMode {
                        viewModel.toggleReceiptSelection(receipt)
                    } else {
                        selectedReceipt = receipt
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !viewModel.isInSelectionMode {
                        Button("Delete", role: .destructive) {
                            viewModel.deleteReceipt(receipt)
                        }
                        
                        Button("Edit") {
                            selectedReceipt = receipt
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadReceipts()
        }
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    let isSelected: Bool
    let isInSelectionMode: Bool
    
    init(receipt: Receipt, isSelected: Bool = false, isInSelectionMode: Bool = false) {
        self.receipt = receipt
        self.isSelected = isSelected
        self.isInSelectionMode = isInSelectionMode
    }
    
    var body: some View {
        HStack {
            // Selection indicator
            if isInSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            
            // Receipt thumbnail or icon
            if let imageData = receipt.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 80)
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Vendor name
                Text(receipt.vendor ?? "Unknown Vendor")
                    .font(.headline)
                    .lineLimit(1)
                
                // Amount
                Text(receipt.formattedAmount)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Date and category
                HStack {
                    Text(receipt.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let category = receipt.category {
                        Spacer()
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                
                // Tags
                if !receipt.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(receipt.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack {
                // Review status
                if receipt.needsReview {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Spacer()
                
                // Confidence indicator
                if let confidence = receipt.confidence {
                    ConfidenceIndicator(confidence: confidence)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double
    
    private var color: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(String(format: "%.0f%%", confidence * 100))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Receipts Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tap the camera tab to scan your first receipt")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilterView: View {
    @ObservedObject var viewModel: ReceiptListViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedCategory: String = "All"
    @State private var showingNeedsReview: Bool = false
    @State private var dateRange: ClosedRange<Date> = Date()...Date()
    @State private var minAmount: String = ""
    @State private var maxAmount: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag("All")
                        ForEach(viewModel.availableCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Status") {
                    Toggle("Needs Review Only", isOn: $showingNeedsReview)
                }
                
                Section("Amount Range") {
                    HStack {
                        Text("Min:")
                        TextField("0.00", text: $minAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Max:")
                        TextField("999.99", text: $maxAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section {
                    Button("Apply Filters") {
                        applyFilters()
                        presentationMode.wrappedValue.dismiss()
                    }
                    
                    Button("Clear Filters") {
                        clearFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filter Receipts")
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
      private func applyFilters() {
        // Apply category filter
        viewModel.selectedCategory = selectedCategory
        
        // Apply status filter
        viewModel.showingNeedsReview = showingNeedsReview
        
        // Apply amount range filters
        let min = Double(minAmount.trimmingCharacters(in: .whitespacesAndNewlines))
        let max = Double(maxAmount.trimmingCharacters(in: .whitespacesAndNewlines))
        viewModel.setAmountRange(min: min, max: max)
        
        print("✅ Applied filters - Category: \(selectedCategory), MinAmount: \(min?.description ?? "none"), MaxAmount: \(max?.description ?? "none")")
    }
    
    private func clearFilters() {
        selectedCategory = "All"
        showingNeedsReview = false
        minAmount = ""
        maxAmount = ""
        viewModel.clearFilters()
    }
}

#Preview {
    ReceiptListView()
        .environmentObject(ReceiptListViewModel())
}
