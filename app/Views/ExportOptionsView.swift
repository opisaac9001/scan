import SwiftUI

struct ExportOptionsView: View {
    @ObservedObject var viewModel: ReceiptListViewModel // Matches how it's called in SettingsView

    var body: some View {
        VStack {
            Text("Export Options")
                .font(.title)
                .padding()

            Text("This is where you will be able to configure and trigger exports for your receipts (e.g., CSV, PDF).")
                .multilineTextAlignment(.center)
                .padding()

            Text("Full UI and functionality for export options are yet to be implemented.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .navigationTitle("Export Receipts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Preview (optional, but good practice)
#if DEBUG
struct ExportOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock or sample ReceiptListViewModel for previewing
        // For simplicity, we can just pass a new instance if it doesn't crash the preview
        NavigationView {
            ExportOptionsView(viewModel: ReceiptListViewModel())
        }
    }
}
#endif
