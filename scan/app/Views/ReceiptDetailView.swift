import SwiftUI

struct ReceiptDetailView: View {
    @State private var receipt: Receipt
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    init(receipt: Receipt) {
        self._receipt = State(initialValue: receipt)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Receipt Image
                    receiptImageSection
                    
                    // Main Info
                    mainInfoSection
                    
                    // Details
                    detailsSection
                    
                    // Raw Text
                    rawTextSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Receipt Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { isEditing = true }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button(action: shareReceipt) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: exportReceipt) {
                            Label("Export", systemImage: "arrow.up.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditReceiptView(receipt: $receipt)
            }
            .alert("Delete Receipt", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteReceipt()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this receipt? This action cannot be undone.")
            }
        }
    }
    
    private var receiptImageSection: some View {
        Group {
            if let imageData = receipt.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No Image Available")
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
    }
    
    private var mainInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vendor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(receipt.vendor ?? "Unknown Vendor")
                .font(.title2)
                .fontWeight(.semibold)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Amount")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(receipt.formattedAmount)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Date")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(receipt.formattedDate)
                        .font(.headline)
                }
            }
            
            if receipt.needsReview {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Needs Review")
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .padding(.bottom, 4)
            
            DetailRow(title: "Category", value: receipt.category ?? "Uncategorized")
            DetailRow(title: "Payment Method", value: receipt.paymentMethod ?? "Not specified")
            DetailRow(title: "Location", value: receipt.location ?? "Not specified")
            DetailRow(title: "Confidence", value: receipt.confidencePercentage)
            
            if !receipt.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(receipt.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            if let notes = receipt.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(notes)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private var rawTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Raw OCR Text")
                .font(.headline)
            
            if let rawText = receipt.rawText, !rawText.isEmpty {
                ScrollView {
                    Text(rawText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 200)
            } else {
                Text("No OCR text available")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
      private func shareReceipt() {
        var itemsToShare: [Any] = []
        
        // Add text summary
        let summary = """
        Receipt Details
        Vendor: \(receipt.vendor ?? "Unknown")
        Amount: \(receipt.formattedAmount)
        Date: \(receipt.formattedDate)
        Category: \(receipt.category ?? "Uncategorized")
        \(receipt.notes != nil ? "Notes: \(receipt.notes!)" : "")
        """
        itemsToShare.append(summary)
        
        // Add image if available
        if let imageData = receipt.imageData, let image = UIImage(data: imageData) {
            itemsToShare.append(image)
        }
        
        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // For iPad compatibility
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func exportReceipt() {
        let exportService = ExportService()
        
        // Export single receipt as CSV
        let result = exportService.exportToCSV(receipts: [receipt])
        
        switch result {
        case .success(let url):
            // Create document picker to save the file
            let documentPicker = UIDocumentPickerViewController(forExporting: [url])
            documentPicker.modalPresentationStyle = .formSheet
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(documentPicker, animated: true)
            }
            
        case .failure(let error):
            print("❌ Export failed: \(error)")
            // Show error alert
            let alert = UIAlertController(title: "Export Failed", 
                                        message: "Could not export receipt: \(error.localizedDescription)", 
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    private func deleteReceipt() {
        CoreDataManager.shared.deleteReceipt(withId: receipt.id)
        presentationMode.wrappedValue.dismiss()
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.body)
            
            Spacer()
        }
    }
}

struct EditReceiptView: View {
    @Binding var receipt: Receipt
    @Environment(\.presentationMode) var presentationMode
    
    @State private var vendor: String
    @State private var amount: String
    @State private var category: String
    @State private var notes: String
    @State private var paymentMethod: String
    @State private var location: String
    @State private var date: Date
    @State private var needsReview: Bool
    @State private var tagsText: String
    
    init(receipt: Binding<Receipt>) {
        self._receipt = receipt
        self._vendor = State(initialValue: receipt.wrappedValue.vendor ?? "")
        self._amount = State(initialValue: receipt.wrappedValue.amount?.description ?? "")
        self._category = State(initialValue: receipt.wrappedValue.category ?? "")
        self._notes = State(initialValue: receipt.wrappedValue.notes ?? "")
        self._paymentMethod = State(initialValue: receipt.wrappedValue.paymentMethod ?? "")
        self._location = State(initialValue: receipt.wrappedValue.location ?? "")
        self._date = State(initialValue: receipt.wrappedValue.date ?? Date())
        self._needsReview = State(initialValue: receipt.wrappedValue.needsReview)
        self._tagsText = State(initialValue: receipt.wrappedValue.tags.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Vendor", text: $vendor)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Details") {
                    TextField("Category", text: $category)
                    TextField("Payment Method", text: $paymentMethod)
                    TextField("Location", text: $location)
                }
                
                Section("Additional") {
                    TextField("Tags (comma separated)", text: $tagsText)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Toggle("Needs Review", isOn: $needsReview)
                }
            }
            .navigationTitle("Edit Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        let updatedReceipt = Receipt(
            id: receipt.id,
            imageData: receipt.imageData,
            vendor: vendor.isEmpty ? nil : vendor,
            amount: Double(amount),
            date: date,
            category: category.isEmpty ? nil : category,
            notes: notes.isEmpty ? nil : notes,
            rawText: receipt.rawText,
            confidence: receipt.confidence,
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
            location: location.isEmpty ? nil : location,
            tags: tagsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            needsReview: needsReview,
            createdAt: receipt.createdAt,
            updatedAt: Date()
        )
        
        receipt = updatedReceipt
        CoreDataManager.shared.updateReceipt(updatedReceipt)
    }
}

#Preview {
    ReceiptDetailView(receipt: Receipt(
        vendor: "Target Store",
        amount: 45.67,
        date: Date(),
        category: "Groceries",
        notes: "Weekly shopping",
        confidence: 0.85,
        tags: ["groceries", "weekly", "target"]
    ))
}
