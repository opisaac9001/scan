import SwiftUI

struct ExportOptionsView: View {
    @ObservedObject var viewModel: ReceiptListViewModel
    @State private var selectedFormat: ExportService.ExportFormat = .csv
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Settings")) {
                    Picker("Select Format", selection: $selectedFormat) {
                        ForEach(ExportService.ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue.uppercased()).tag(format)
                        }
                    }
                }

                Section {
                    if viewModel.isExporting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Exporting...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        Button("Export Filtered Receipts") { // Changed label to be more specific
                            viewModel.exportAndShareReceipts(format: selectedFormat)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(viewModel.isExporting)
                    }
                }

                Section(header: Text("Information")) {
                     Text("This will export the currently filtered list of receipts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    Text("After export, a share sheet will appear to save or send the file.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(viewModel.isExporting)
                }
            }
            .sheet(isPresented: $viewModel.showingShareSheet, onDismiss: {
                viewModel.shareableExportURL = nil // Clear URL on dismiss
            }) {
                if let url = viewModel.shareableExportURL {
                    ShareSheet(activityItems: [url])
                } else {
                    // This fallback should ideally not be shown if logic is correct,
                    // as showingShareSheet should only be true when shareableExportURL is non-nil.
                    VStack {
                        Text("Error: No export file available to share.")
                            .padding()
                        Button("Dismiss") {
                            viewModel.showingShareSheet = false
                        }
                        .padding()
                    }
                }
            }
            // Using .alert with an optional item for better state management
            .alert(item: $viewModel.exportError) { error in // Assumes ExportError is Identifiable
                Alert(
                    title: Text("Export Error"),
                    message: Text(error.localizedDescription),
                    dismissButton: .default(Text("OK")) {
                        viewModel.exportError = nil // Reset error
                    }
                )
            }
        }
    }
}

// Make ExportService.ExportError Identifiable if it's not already, for use with .alert(item:)
// This would typically be in ExportService.swift, but added here for completeness of this file's needs.
// If ExportService.ExportError is already Identifiable, this extension is not needed.
// For example, if ExportError is an enum:
/*
extension ExportService.ExportError: Identifiable {
    public var id: String {
        self.localizedDescription // Or a more unique identifier if needed
    }
}
*/


#if DEBUG
struct ExportOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock ReceiptListViewModel for previewing
        let mockViewModel = ReceiptListViewModel()
        // Example: Simulate an error for preview
        // mockViewModel.exportError = ExportService.ExportError.exportFailed(reason: "Preview error example.")
        // Example: Simulate successful export for share sheet preview (more complex to show sheet in preview)
        // mockViewModel.shareableExportURL = URL(string: "file:///example.csv")
        // mockViewModel.showingShareSheet = true

        return ExportOptionsView(viewModel: mockViewModel)
    }
}
#endif
