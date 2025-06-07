import SwiftUI

// MARK: - ExportOptionsView reference from StatisticsView
// This ensures ExportOptionsView is available

struct ContentView: View {
    @StateObject private var receiptListViewModel = ReceiptListViewModel()
    @State private var showingScanner = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {            // Receipts List Tab
            NavigationView {
                EnhancedReceiptListView()
                    .environmentObject(receiptListViewModel)
            }
            .tabItem {
                Image(systemName: "doc.text.viewfinder")
                Text("Receipts")
            }
            .tag(0)
            
            // Scan Tab
            VStack {
                Text("Ready to Scan")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding()
                
                Button(action: {
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
    }
    
    private func processScannedImage(_ image: UIImage) {
        showingScanner = false
        selectedTab = 0 // Switch to receipts tab
        receiptListViewModel.processNewReceipt(image: image)
    }
}

struct SettingsView: View {
    @State private var showingExportOptions = false
    @State private var showingClearDataAlert = false
    @State private var showingAPISettings = false
    @EnvironmentObject var receiptListViewModel: ReceiptListViewModel
    
    var body: some View {
        List {
            // AI Configuration Section
            Section("AI & Processing") {
                NavigationLink(destination: APISettingsView()) {
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
                
                NavigationLink(destination: OCRSettingsView()) {
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
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("1")
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
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
            }        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(viewModel: receiptListViewModel)
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

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
}
