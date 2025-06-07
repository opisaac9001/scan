# Receipt Scanner iOS App

A modern iOS application that uses the device's built-in OCR capabilities via the iOS Vision framework to scan and process receipts for expense tracking. Features intelligent receipt processing with Ollama LLM integration for detailed categorization and tax-specific information extraction.

## ✨ Features

- **📷 Camera Integration**: Capture receipts using iPhone camera with positioning overlay
- **🔍 Built-in OCR**: Leverage iOS Vision framework for text recognition
- **🤖 AI-Powered Analysis**: Integrate with Ollama LLM for intelligent parsing and categorization
- **📊 Smart Data Extraction**: Parse vendor, amount, date, category, and tax information
- **💾 Local Storage**: Save receipts using Core Data with full CRUD operations
- **📤 Export Options**: Share data in CSV, JSON, PDF formats
- **📈 Statistics Dashboard**: Comprehensive analytics with charts and tax summaries
- **🎯 Tax Categories**: 18+ business expense categories for tax reporting
- **🔍 Advanced Filtering**: Filter by amount range, date, category, and review status
- **⚡ Batch Operations**: Multi-select receipts for bulk actions
- **☁️ Cloud Backup**: Export and share receipt data for backup purposes
- **🎨 Modern UI**: Clean, intuitive SwiftUI interface

## 🛠 Technical Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **OCR**: iOS Vision Framework (VNRecognizeTextRequest)
- **AI Integration**: Ollama LLM API
- **Storage**: Core Data for local persistence
- **Camera**: AVFoundation with UIViewControllerRepresentable
- **Minimum iOS**: 15.0+

## 📱 App Structure

The app follows a clean 4-tab navigation structure:

1. **📋 Receipts Tab**: Browse, search, filter, and manage all receipts
2. **📷 Scan Tab**: Camera interface for capturing new receipts
3. **📊 Statistics Tab**: Analytics dashboard with charts and tax summaries
4. **⚙️ Settings Tab**: App configuration, export options, and data management

## 🏗 Project Structure

```
ReceiptScanner/
├── App/
│   ├── ReceiptScannerApp.swift       # Main app entry point
│   └── ContentView.swift             # Root view with tab navigation
├── Models/
│   ├── Receipt.swift                 # Core receipt data model
│   ├── ReceiptData.xcdatamodeld      # Core Data schema
│   └── CoreDataManager.swift         # Data persistence manager
├── Views/
│   ├── CameraView.swift              # Camera capture interface
│   ├── ReceiptDetailView.swift       # Individual receipt view/edit
│   ├── ReceiptListView.swift         # Receipt browsing with filters
│   └── StatisticsView.swift          # Analytics dashboard
├── ViewModels/
│   ├── CameraViewModel.swift         # Camera management logic
│   ├── ReceiptListViewModel.swift    # List operations and filtering
│   └── ScanViewModel.swift           # OCR + LLM processing workflow
├── Services/
│   ├── OCRService.swift              # Vision framework integration
│   ├── ReceiptParser.swift           # Text parsing logic
│   ├── OllamaService.swift           # LLM API integration
│   └── ExportService.swift           # Data export functionality
├── Resources/
│   ├── Assets.xcassets               # App icons and images
│   ├── Info.plist                    # App configuration
│   ├── AppConfig.swift               # App-wide configuration
│   └── LaunchScreen.storyboard       # Launch screen
└── Tests/
    └── ReceiptScannerTests.swift     # Unit and integration tests
```

## 🚀 Getting Started

### Prerequisites

- **macOS** with Xcode 15.0+
- **iOS device or simulator** running iOS 15.0+
- **Apple Developer account** (for device testing)
- **Ollama** (optional, for advanced AI features)

### Installation

1. **Clone/Download** this project
2. **Open** `ReceiptScanner.xcodeproj` in Xcode
3. **Select your development team** in project settings
4. **Configure** bundle identifier if needed
5. **Build and run** on device or simulator

### 📷 Camera Permissions

The app requires camera access for receipt scanning. The following permission is included in `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan receipts for expense tracking</string>
```

### 🤖 Ollama Setup (Optional)

For enhanced AI-powered receipt analysis:

1. **Install Ollama**: Download from [ollama.ai](https://ollama.ai)
2. **Pull the vision model**: `ollama pull llava:latest`
3. **Start Ollama service**: `ollama serve`
4. **Configure endpoint**: Update `OllamaService.swift` if using different URL

## 🔧 Core Components

### 🔍 OCR Service
Uses iOS Vision framework to extract text from receipt images with high accuracy and confidence scoring.

### 🧠 Receipt Parser
Intelligently parses OCR results to extract:
- Vendor/Store name and location
- Total amount and line items
- Date and time
- Tax information and rates
- Payment method
- Business purpose and categories

### 🤖 Ollama Integration
Advanced LLM processing for:
- Intelligent vendor recognition
- Automatic categorization (18+ tax categories)
- Business purpose extraction
- Enhanced parsing accuracy
- Vehicle and mileage information

### 💾 Data Management
Core Data integration with:
- Efficient querying and filtering
- Image storage with optimization
- Export capabilities (CSV, JSON, PDF)
- Batch operations
- Cloud backup functionality

## 📊 Tax Categories

The app supports comprehensive business expense categorization:

- **Meals & Entertainment**
- **Travel & Transportation** 
- **Office Supplies**
- **Professional Services**
- **Equipment & Software**
- **Marketing & Advertising**
- **Fuel & Vehicle**
- **Utilities**
- **Insurance**
- **Professional Development**
- **Gifts & Client Entertainment**
- **Home Office**
- **Healthcare**
- **Charity & Donations**
- **Banking & Finance**
- **Legal & Professional**
- **Maintenance & Repairs**
- **Other Business Expense**

## 🧪 Testing

The project includes comprehensive test coverage:

### Unit Tests
- OCR service functionality
- Receipt parsing logic
- Core Data operations
- Category classification

### Integration Tests
- End-to-end scanning workflow
- Camera → OCR → LLM → storage pipeline
- Export functionality

### Performance Tests
- OCR processing speed
- Large dataset handling
- Memory usage optimization

### Running Tests

```bash
# Run all tests
cmd+U in Xcode

# Run specific test class
xcodebuild test -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 🚀 Deployment

### Development Build

1. **Configure** signing in Xcode project settings
2. **Select** target device or simulator
3. **Build and run** (`cmd+R`)

### App Store Distribution

1. **Archive** the project (`Product → Archive`)
2. **Upload** to App Store Connect
3. **Configure** app metadata and screenshots
4. **Submit** for review

### Key Deployment Settings

- **iOS Deployment Target**: 15.0+
- **Bundle Identifier**: `com.receiptscanner.app`
- **Version**: 1.0.0
- **Build**: 1

## 🔒 Privacy & Security

- **Local Storage**: All data stored locally using Core Data
- **Camera Privacy**: Clear usage description for camera access
- **No Data Collection**: App doesn't collect or transmit personal data
- **Optional Cloud**: Backup/export features use standard iOS sharing

## 🤝 Contributing

This project follows iOS development best practices:

1. **SwiftUI** for modern, declarative UI
2. **MVVM Architecture** for clear separation of concerns
3. **Combine** for reactive programming
4. **Async/Await** for modern concurrency
5. **Protocol-Oriented** design patterns

## 📈 Roadmap

### Planned Features
- [ ] **Watch App** for quick receipt capture
- [ ] **Widget Support** for recent receipts
- [ ] **Shortcuts Integration** for Siri commands
- [ ] **Document Scanner** integration
- [ ] **Receipt Templates** for common vendors
- [ ] **Multi-language** OCR support
- [ ] **Cloud Sync** with iCloud
- [ ] **Team Sharing** for business accounts

### Performance Improvements
- [ ] **Background Processing** for large batches
- [ ] **Caching** for improved performance
- [ ] **Progressive Loading** for large datasets
- [ ] **Memory Optimization** for image handling

## 📄 License

This project is intended for educational and personal use. All rights reserved.

---

**Built with ❤️ using SwiftUI and iOS Vision Framework**

For questions or support, please refer to the code documentation or create an issue in the project repository.
