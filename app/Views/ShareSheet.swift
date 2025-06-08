import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    @Environment(\.presentationMode) var presentationMode // Optional: for dismissing if needed, though system usually handles it.

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)

        // Optional: Handle completion for UIActivityViewController
        // controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
        //     // Handle completion or error here
        //     // For example, you might want to dismiss the sheet or log errors
        //     // self.presentationMode.wrappedValue.dismiss() // Be cautious with this, system might do it.
        // }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update here typically. Data is passed at initialization.
    }
}

// Optional Preview for ShareSheet - might be hard to make it fully functional in previews
#if DEBUG
struct ShareSheet_Previews: PreviewProvider {
    static var previews: some View {
        // Example: Create a dummy URL for previewing
        let dummyURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("example.txt")
        try? "This is a test file for ShareSheet preview.".write(to: dummyURL, atomically: true, encoding: .utf8)

        // You would typically present this in a sheet from another view
        // For direct preview, it might not show correctly or might try to present immediately.
        // A button that triggers a sheet with ShareSheet would be a better preview.
        return VStack {
            Text("Previewing ShareSheet (functionality limited in Xcode Previews)")
            // In a real app, this would be presented in a sheet.
            // ShareSheet(activityItems: ["Test share text", dummyURL])
        }
        .onAppear {
            print("ShareSheet preview appeared. For actual functionality, test by presenting it in a sheet.")
        }
    }
}
#endif
