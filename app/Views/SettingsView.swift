import SwiftUI

struct SettingsView: View {
    @State private var showingExportOptions = false
    @State private var showingClearDataAlert = false
    @State private var showingAPISettings = false // This seems unused, but kept for now
    @EnvironmentObject var receiptListViewModel: ReceiptListViewModel

    var body: some View {
        List {
            // AI Configuration Section
            Section("AI & Processing") {
                NavigationLink(destination: APISettingsView()) { // Assumes APISettingsView is in app.Views
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI Settings")
                                .font(.headline)
                            Text("Configure OpenAI, Ollama, or custom APIs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }

                NavigationLink(destination: OCRSettingsView()) { // Assumes OCRSettingsView is in app.Views
                    HStack {
                        Image(systemName: "doc.text.viewfinder")
                            .foregroundColor(.green)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("OCR Settings")
                                .font(.headline)
                            Text("Text recognition and accuracy settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AppConfig.version) // Assumes AppConfig is available
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(AppConfig.build) // Assumes AppConfig is available
                        .foregroundColor(.secondary)
                }
            }
            Section("Data") {
                Button("Export All Receipts") {
                    exportAllReceipts()
                }

                Button("Clear All Data") {
                    showingClearDataAlert = true
                }
                .foregroundColor(.red)
            }

            Section("Support") {
                Link("Privacy Policy", destination: URL(string: "#privacy-policy-url-pending")!)
                Link("Terms of Service", destination: URL(string: "#terms-of-service-url-pending")!)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(viewModel: receiptListViewModel) // Assumes ExportOptionsView is in app.Views
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your receipts and cannot be undone.")
        }
    }

    private func exportAllReceipts() {
        showingExportOptions = true
    }

    private func clearAllData() {
        receiptListViewModel.clearAllData()
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(ReceiptListViewModel()) // Provide a mock/sample ViewModel
        }
    }
}
#endif
