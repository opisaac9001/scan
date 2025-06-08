import SwiftUI

// MARK: - ExportOptionsView reference from StatisticsView
// This ensures ExportOptionsView is available

struct ContentView: View {
    @StateObject private var receiptListViewModel = ReceiptListViewModel()
    @StateObject private var scanViewModel = ScanViewModel() // Added ScanViewModel
    @State private var showingScanner = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {            // Receipts List Tab
            NavigationView {
                EnhancedReceiptListView()
                    .environmentObject(receiptListViewModel)
                    .environmentObject(scanViewModel) // Pass scanViewModel if needed by detail views
            }
            .tabItem {
                Image(systemName: "doc.text.viewfinder")
                Text("Receipts")
            }
            .tag(0)

            // Scan Tab
            VStack {
                // Display ScanViewModel's processing stage and errors if any
                if scanViewModel.isProcessing {
                    VStack {
                        ProgressView()
                            .padding(.bottom, 5)
                        Text(scanViewModel.processingStage.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let errorMessage = scanViewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if scanViewModel.scanResult != nil {
                     Text("Scan Complete!")
                        .foregroundColor(.green)
                        .padding()
                } else {
                    Text("Ready to Scan")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                }

                Button(action: {
                    scanViewModel.clearResults() // Clear previous scan results before new scan
                    showingScanner = true
                }) {
                    VStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Scan Receipt")
                            .font(.headline)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
                .disabled(scanViewModel.isProcessing) // Disable button while processing
                .padding()

                Spacer()
            }
            .navigationTitle("Scan")
            .tabItem {
                Image(systemName: "camera")
                Text("Scan")
            }
            .tag(1)
            .sheet(isPresented: $showingScanner) {
                CameraView { image in
                    // Handle scanned image
                    processScannedImage(image)
                }
            }            // Statistics Tab
            NavigationView {
                StatisticsView()
                    .environmentObject(receiptListViewModel)
            }
            .tabItem {
                Image(systemName: "chart.bar")
                Text("Statistics")
            }
            .tag(2)

            // Settings Tab
            NavigationView {
                SettingsView()
                    .environmentObject(receiptListViewModel)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(3)
        }
        .accentColor(.blue)
        // Present alert from ScanViewModel if needed (e.g., for critical errors)
        .alert(item: $scanViewModel.errorMessageProvider) { provider in
            Alert(title: Text(provider.title), message: Text(provider.message), dismissButton: .default(Text("OK")))
        }
    }

    private func processScannedImage(_ image: UIImage) {
        showingScanner = false // Hide scanner immediately
        selectedTab = 0      // Switch to receipts tab to see results eventually

        Task {
            await scanViewModel.processReceipt(image: image)
            // After ScanViewModel finishes processing, explicitly refresh the receipt list.
            receiptListViewModel.refreshData()
        }
    }
}

// Added ErrorMessageProvider for Alert
struct ErrorMessageProvider: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// Extend ScanViewModel to provide error messages for alerts if needed
extension ScanViewModel {
    @Published var errorMessageProvider: ErrorMessageProvider?

    // Modify existing error handling to use errorMessageProvider
    // Example (would need to be integrated into ScanViewModel's actual error handling logic):
    /*
    private func handleAdvancedError(_ error: Error) async {
        await MainActor.run {
            // ... existing logic ...
            let title = "Processing Error"
            let message: String
            if let scanError = error as? ScanError {
                self.errorMessage = scanError.localizedDescription // For inline display
                message = scanError.localizedDescription + (scanError.recoverySuggestion.map { "\n\nSuggestion: \($0)" } ?? "")
            } else {
                self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)" // For inline display
                message = "An unexpected error occurred: \(error.localizedDescription)"
            }
            self.errorMessageProvider = ErrorMessageProvider(title: title, message: message)
            print("❌ ScanViewModel advanced error: \(error)")
        }
    }
    */
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
}
