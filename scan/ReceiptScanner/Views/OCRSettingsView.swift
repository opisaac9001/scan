import SwiftUI

struct OCRSettingsView: View {
    @AppStorage("ocr_recognition_level") private var recognitionLevel = "accurate"
    @AppStorage("ocr_minimum_confidence") private var minimumConfidence = 0.5
    @AppStorage("ocr_language_correction") private var languageCorrection = true
    @AppStorage("ocr_language") private var preferredLanguage = "en"
    @AppStorage("image_preprocessing") private var enablePreprocessing = true
    @AppStorage("image_max_size") private var maxImageSize = 1024.0
    @AppStorage("image_compression_quality") private var compressionQuality = 0.8
    
    @State private var isTestingOCR = false
    @State private var ocrTestResult: String?
    @State private var showingImagePicker = false
    @State private var testImage: UIImage?
    
    var body: some View {
        NavigationView {
            Form {
                // OCR Accuracy Settings
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recognition Level")
                            .font(.headline)
                        
                        Picker("Recognition Level", selection: $recognitionLevel) {
                            HStack {
                                Image(systemName: "hare.fill")
                                    .foregroundColor(.orange)
                                Text("Fast")
                            }.tag("fast")
                            
                            HStack {
                                Image(systemName: "target")
                                    .foregroundColor(.blue)
                                Text("Accurate")
                            }.tag("accurate")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Text(recognitionLevel == "fast" ? 
                             "Faster processing with good accuracy for clear receipts." :
                             "Slower but more accurate for poor quality or handwritten receipts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Minimum Confidence")
                            Spacer()
                            Text("\(Int(minimumConfidence * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $minimumConfidence, in: 0.1...1.0, step: 0.1)
                        Text("Only accept text with this confidence level or higher.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Language Correction", isOn: $languageCorrection)
                    
                } header: {
                    Text("Text Recognition")
                } footer: {
                    Text("These settings control how the iOS Vision framework processes receipt images.")
                }
                
                // Language Settings
                Section {
                    Picker("Primary Language", selection: $preferredLanguage) {
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                        Text("Chinese (Simplified)").tag("zh-Hans")
                        Text("Chinese (Traditional)").tag("zh-Hant")
                        Text("Japanese").tag("ja")
                        Text("Korean").tag("ko")
                    }
                } header: {
                    Text("Language Settings")
                } footer: {
                    Text("Select the primary language for receipt text recognition.")
                }
                
                // Image Processing Settings
                Section {
                    Toggle("Image Preprocessing", isOn: $enablePreprocessing)
                    
                    if enablePreprocessing {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Max Image Size")
                                Spacer()
                                Text("\(Int(maxImageSize))px")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $maxImageSize, in: 512...2048, step: 256)
                            Text("Larger images provide better OCR accuracy but use more processing power.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Compression Quality")
                                Spacer()
                                Text("\(Int(compressionQuality * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $compressionQuality, in: 0.1...1.0, step: 0.1)
                            Text("Balance between file size and image quality for stored receipts.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Image Processing")
                } footer: {
                    Text("Optimize images before OCR processing to improve accuracy and performance.")
                }
                
                // OCR Testing
                Section {
                    VStack(spacing: 12) {
                        if let testImage = testImage {
                            Image(uiImage: testImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                            
                            Button("Test OCR on This Image") {
                                testOCRWithImage(testImage)
                            }
                            .disabled(isTestingOCR)
                            .buttonStyle(.borderedProminent)
                            
                            if let result = ocrTestResult {
                                ScrollView {
                                    Text(result)
                                        .font(.caption)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .frame(maxHeight: 150)
                            }
                            
                        } else {
                            Button("Select Test Image") {
                                showingImagePicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if isTestingOCR {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Processing...")
                                    .font(.caption)
                            }
                        }
                    }
                } header: {
                    Text("OCR Testing")
                } footer: {
                    Text("Test your OCR settings with a sample receipt image to see how well text is recognized.")
                }
                
                // Performance Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Performance Tips")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Good lighting improves OCR accuracy")
                            Text("• Flat, unwrinkled receipts work best")
                            Text("• Clean the camera lens before scanning")
                            Text("• Use 'Accurate' mode for damaged receipts")
                            Text("• 'Fast' mode is sufficient for clear receipts")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Tips")
                }
            }
            .navigationTitle("OCR Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $testImage)
            }
        }
    }
    
    private func testOCRWithImage(_ image: UIImage) {
        isTestingOCR = true
        ocrTestResult = nil
        
        Task {
            do {
                let ocrService = OCRService()
                let text = try await ocrService.extractText(from: image)
                
                await MainActor.run {
                    ocrTestResult = text.isEmpty ? "No text detected in image." : text
                    isTestingOCR = false
                }
            } catch {
                await MainActor.run {
                    ocrTestResult = "OCR Error: \(error.localizedDescription)"
                    isTestingOCR = false
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    OCRSettingsView()
}
