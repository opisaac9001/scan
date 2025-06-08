import SwiftUI

@main
struct ReceiptScannerApp: App {
    let persistenceController = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    setupAppearance()
                }
        }
    }
    
    private func setupAppearance() {
        // Configure app-wide appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
    }
}
