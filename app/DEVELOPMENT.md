# iOS Receipt Scanner - Development Guide

## Quick Start (macOS Required)

### Prerequisites
- macOS 12.0 or later
- Xcode 14.0 or later
- iOS 15.0+ target device or simulator
- Ollama installed locally (optional for LLM features)

### Initial Setup
1. **Clone and Open Project**
   ```bash
   git clone [repository-url]
   cd app
   open ReceiptScanner.xcodeproj
   ```

2. **Build and Test**
   ```bash
   # Clean and build
   xcodebuild -project ReceiptScanner.xcodeproj -scheme ReceiptScanner clean build
   
   # Run tests
   xcodebuild test -project ReceiptScanner.xcodeproj -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 15'
   
   # Or use the build script
   chmod +x build.sh
   ./build.sh
   ```

## Development Workflow

### 1. Camera Integration Testing
- **Physical Device Required**: Camera functionality requires actual iOS device
- Test OCR accuracy with various receipt types
- Verify proper image capture and processing

### 2. Core Data Setup
The app uses Core Data for local storage:
- **Models**: Receipt entity with tax categorization fields
- **Manager**: CoreDataManager handles all persistence operations
- **Testing**: Comprehensive unit tests for CRUD operations

### 3. OCR Implementation
Built on iOS Vision framework:
- **VNRecognizeTextRequest**: High-accuracy text recognition
- **Custom Parsing**: Intelligent receipt field extraction
- **Configuration**: Adjustable recognition levels in AppConfig

### 4. Ollama Integration
Optional LLM enhancement for intelligent categorization:
- **Default URL**: http://localhost:11434
- **Model**: llava:latest (multimodal for receipt images)
- **Fallback**: Works without Ollama for basic OCR functionality

## Project Architecture

### MVVM Structure
```
App/                    # App entry point and root views
├── ReceiptScannerApp.swift
└── ContentView.swift

Models/                 # Data models and Core Data
├── Receipt.swift
├── CoreDataManager.swift
└── ReceiptData.xcdatamodeld/

Views/                  # SwiftUI Views
├── CameraView.swift
├── ReceiptListView.swift
├── ReceiptDetailView.swift
└── StatisticsView.swift

ViewModels/             # Business logic and state management
├── ScanViewModel.swift
├── CameraViewModel.swift
└── ReceiptListViewModel.swift

Services/               # External integrations
├── OCRService.swift
├── ReceiptParser.swift
├── OllamaService.swift
└── ExportService.swift

Resources/              # Configuration and assets
├── Info.plist
├── AppConfig.swift
├── Assets.xcassets/
└── LaunchScreen.storyboard
```

## Testing Strategy

### Unit Tests (`Tests/ReceiptScannerTests.swift`)
- **OCR Service**: Text recognition accuracy
- **Receipt Parser**: Field extraction logic
- **Core Data**: CRUD operations and data integrity
- **Ollama Service**: API integration and error handling

### Integration Tests
- **Camera + OCR**: End-to-end scanning workflow
- **OCR + Parser**: Complete text processing pipeline
- **Parser + Core Data**: Data persistence flow

### Device Testing
- **Camera Permission**: iOS camera access workflow
- **Image Processing**: Performance with high-resolution images
- **OCR Accuracy**: Real-world receipt scanning
- **UI Responsiveness**: SwiftUI performance on device

## Configuration Management

### AppConfig.swift
Central configuration for all app settings:
```swift
// Development flags
AppConfig.isDebugMode = true

// Ollama settings
AppConfig.Ollama.defaultBaseURL = "http://localhost:11434"
AppConfig.Ollama.defaultModel = "llava:latest"

// OCR tuning
AppConfig.OCR.recognitionLevel = "accurate"
AppConfig.OCR.minimumConfidence = 0.5
```

### Build Configurations
- **Debug**: Full logging, relaxed validation
- **Release**: Optimized performance, minimal logging
- **Testing**: Mock services, controlled data

## Deployment Preparation

### 1. App Store Configuration
Update the following in Xcode:
- **Bundle ID**: Unique identifier for App Store
- **Team**: Apple Developer account
- **Signing**: Distribution certificate and provisioning profile
- **Version**: Increment for each release

### 2. Required Privacy Descriptions
Add to Info.plist:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan receipts</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access allows importing existing receipt images</string>
```

### 3. App Icons and Screenshots
- **App Icons**: Multiple sizes in Assets.xcassets
- **Screenshots**: Required for App Store listing
- **App Preview**: Optional video demonstration

### 4. TestFlight Beta Testing
- **Internal Testing**: Team members and stakeholders
- **External Testing**: Limited public beta
- **Feedback Integration**: Iterate based on user testing

## Troubleshooting

### Common Issues

1. **Build Errors**
   ```bash
   # Clean derived data
   rm -rf ~/Library/Developer/Xcode/DerivedData
   
   # Clean project
   xcodebuild clean -project ReceiptScanner.xcodeproj
   ```

2. **Simulator Issues**
   - Camera not available in simulator
   - Use photos from library for testing
   - OCR testing requires real images

3. **Core Data Issues**
   - Delete app from simulator to reset data
   - Check Core Data model versions
   - Verify NSManagedObject subclasses

4. **Ollama Connection**
   - Ensure Ollama is running: `ollama serve`
   - Check network permissions
   - Verify model availability: `ollama list`

### Performance Optimization

1. **Image Processing**
   - Resize images before OCR processing
   - Use background queues for heavy operations
   - Implement proper memory management

2. **Core Data**
   - Use NSFetchedResultsController for large datasets
   - Implement proper batch operations
   - Consider Core Data CloudKit for sync

3. **UI Responsiveness**
   - Use @MainActor for UI updates
   - Implement proper loading states
   - Optimize list rendering with LazyVStack

## Next Steps

### Immediate Tasks
1. ✅ **Project Setup**: Complete Xcode configuration
2. 🔄 **Build Testing**: Verify compilation on macOS
3. 🔄 **Device Testing**: Test camera and OCR functionality
4. 🔄 **Integration Testing**: Verify Ollama connectivity

### Short-term Goals
- **UI Polish**: Enhance user interface design
- **Error Handling**: Robust error states and recovery
- **Performance**: Optimize image processing pipeline
- **Accessibility**: VoiceOver and accessibility improvements

### Long-term Vision
- **Cloud Sync**: iCloud integration for data backup
- **Apple Watch**: Companion app for quick receipt capture
- **Siri Shortcuts**: Voice-activated scanning
- **Export Features**: Integration with accounting software

---

## Support

For development questions or issues:
1. Check existing unit tests for usage examples
2. Review AppConfig.swift for configuration options
3. Examine ViewModels for business logic patterns
4. Test with physical iOS device for camera features

The project is designed to be development-ready with comprehensive testing, documentation, and configuration management.
