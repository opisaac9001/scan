import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var viewModel: ReceiptListViewModel
    @State private var selectedDateRange = ReceiptListViewModel.DateRange.thisYear
    @State private var showingExportOptions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Date Range Picker
                    dateRangePicker
                    
                    // Summary Cards
                    summaryCards
                    
                    // Category Breakdown Chart
                    categoryChart
                    
                    // Monthly Trends Chart
                    monthlyTrendsChart
                    
                    // Tax Summary
                    taxSummarySection
                    
                    // Export Section
                    exportSection
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        showingExportOptions = true
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadReceipts()
            }
        }
    }
    
    private var dateRangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date Range")
                .font(.headline)
            
            Picker("Date Range", selection: $selectedDateRange) {
                ForEach(ReceiptListViewModel.DateRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var summaryCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(
                title: "Total Receipts",
                value: "\(viewModel.totalReceipts)",
                icon: "doc.text",
                color: .blue
            )
            
            StatCard(
                title: "Total Amount",
                value: formatCurrency(viewModel.totalAmount),
                icon: "dollarsign.circle",
                color: .green
            )
            
            StatCard(
                title: "Needs Review",
                value: "\(viewModel.needsReviewCount)",
                icon: "exclamationmark.triangle",
                color: .orange
            )
            
            StatCard(
                title: "Categories",
                value: "\(viewModel.categoryBreakdown.count)",
                icon: "folder",
                color: .purple
            )
        }
    }
    
    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
            
            if !viewModel.categoryBreakdown.isEmpty {
                Chart {
                    ForEach(Array(viewModel.categoryBreakdown.sorted(by: { $0.value > $1.value })), id: \.key) { category, amount in
                        BarMark(
                            x: .value("Amount", amount),
                            y: .value("Category", category)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                }
                .frame(height: 300)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            Text(formatCurrency(value.as(Double.self) ?? 0))
                        }
                    }
                }
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var monthlyTrendsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Trends")
                .font(.headline)
            
            if !viewModel.monthlyTotals.isEmpty {
                Chart {
                    ForEach(Array(viewModel.monthlyTotals.sorted(by: { $0.key < $1.key })), id: \.key) { month, amount in
                        LineMark(
                            x: .value("Month", month),
                            y: .value("Amount", amount)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .symbol(Circle())
                        
                        AreaMark(
                            x: .value("Month", month),
                            y: .value("Amount", amount)
                        )
                        .foregroundStyle(Color.green.opacity(0.2))
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            Text(formatCurrency(value.as(Double.self) ?? 0))
                        }
                    }
                }
            } else {
                Text("No monthly data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var taxSummarySection: some View {
        let taxSummary = viewModel.generateTaxSummary(for: selectedDateRange)
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Tax Summary")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Total Business Deductions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(taxSummary.formattedTotalDeductions)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Completion Rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", taxSummary.completionPercentage * 100))
                        .font(.headline)
                        .foregroundColor(taxSummary.completionPercentage > 0.8 ? .green : .orange)
                }
                
                ProgressView(value: taxSummary.completionPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: taxSummary.completionPercentage > 0.8 ? .green : .orange))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ActionButton(
                    title: "Export CSV",
                    icon: "tablecells",
                    color: .blue
                ) {
                    exportData(format: .csv)
                }
                
                ActionButton(
                    title: "Export PDF",
                    icon: "doc.richtext",
                    color: .red
                ) {
                    exportData(format: .pdf)
                }
                
                ActionButton(
                    title: "Tax Report",
                    icon: "chart.bar.doc.horizontal",
                    color: .green
                ) {
                    generateTaxReport()
                }
                
                ActionButton(
                    title: "Backup Data",
                    icon: "icloud.and.arrow.up",
                    color: .purple
                ) {
                    backupData()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func exportData(format: ExportService.ExportFormat) {
        let exportService = ExportService()
        let receipts = viewModel.exportReceiptsForTaxes(dateRange: selectedDateRange)
        
        let result = exportService.exportToCSV(receipts: receipts)
        
        switch result {
        case .success(let url):
            shareFile(url: url)
        case .failure(let error):
            print("❌ Export failed: \(error)")
        }
    }
    
    private func generateTaxReport() {
        let exportService = ExportService()
        let summary = viewModel.generateTaxSummary(for: selectedDateRange)
        
        let result = exportService.exportTaxSummaryToPDF(summary: summary)
        
        switch result {
        case .success(let url):
            shareFile(url: url)
        case .failure(let error):
            print("❌ Tax report generation failed: \(error)")
        }
    }
      private func backupData() {
        // Cloud backup implementation
        let exportService = ExportService()
        let receipts = viewModel.receipts
        
        // Export to JSON for backup
        let result = exportService.exportToJSON(receipts: receipts)
        
        switch result {
        case .success(let url):
            // Share backup file (user can save to iCloud, email, etc.)
            shareFile(url: url)
            print("📱 Backup file created and ready for sharing")
        case .failure(let error):
            print("❌ Backup failed: \(error)")
        }
    }
    
    private func shareFile(url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExportOptionsView: View {
    @ObservedObject var viewModel: ReceiptListViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedFormat = ExportService.ExportFormat.csv
    @State private var selectedDateRange = ReceiptListViewModel.DateRange.thisYear
    @State private var includeImages = false
    @State private var groupByCategory = true
    @State private var taxYearOnly = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        Text("CSV").tag(ExportService.ExportFormat.csv)
                        Text("JSON").tag(ExportService.ExportFormat.json)
                        Text("PDF").tag(ExportService.ExportFormat.pdf)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Date Range") {
                    Picker("Range", selection: $selectedDateRange) {
                        ForEach(ReceiptListViewModel.DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                }
                
                Section("Options") {
                    Toggle("Include Images", isOn: $includeImages)
                    Toggle("Group by Category", isOn: $groupByCategory)
                    Toggle("Tax Year Only", isOn: $taxYearOnly)
                }
                
                Section {
                    Button("Export Data") {
                        exportData()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func exportData() {
        let exportService = ExportService()
        let options = ExportService.ExportOptions(
            format: selectedFormat,
            includePDFAttachments: false,
            groupByCategory: groupByCategory,
            includeImages: includeImages,
            dateRange: selectedDateRange.rawValue,
            taxYearOnly: taxYearOnly
        )
        
        let receipts = viewModel.exportReceiptsForTaxes(dateRange: selectedDateRange)
        
        let result: Result<URL, ExportService.ExportError>
        
        switch selectedFormat {
        case .csv:
            result = exportService.exportToCSV(receipts: receipts, options: options)
        case .json:
            result = exportService.exportToJSON(receipts: receipts, options: options)
        case .pdf:
            result = exportService.exportToPDF(receipts: receipts, options: options)
        }
        
        switch result {
        case .success(let url):
            shareFile(url: url)
        case .failure(let error):
            print("❌ Export failed: \(error)")
        }
    }
    
    private func shareFile(url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

#Preview {
    StatisticsView()
        .environmentObject(ReceiptListViewModel())
}
