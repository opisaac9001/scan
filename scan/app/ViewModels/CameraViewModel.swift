import Foundation
import SwiftUI
import UIKit
import AVFoundation
import Combine

@MainActor
class CameraViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAuthorized = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var capturedImage: UIImage?
    @Published var isCapturing = false
    @Published var errorMessage: String?
    @Published var showingImagePicker = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Camera Properties
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkCameraAuthorization()
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Authorization
    func checkCameraAuthorization() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authorizationStatus {
        case .authorized:
            isAuthorized = true
            setupCaptureSession()
        case .notDetermined:
            requestCameraPermission()
        case .denied, .restricted:
            isAuthorized = false
            errorMessage = "Camera access is required to scan receipts. Please enable camera access in Settings."
        @unknown default:
            isAuthorized = false
            errorMessage = "Unknown camera authorization status."
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                self?.isAuthorized = granted
                
                if granted {
                    self?.setupCaptureSession()
                } else {
                    self?.errorMessage = "Camera access denied. Receipt scanning requires camera access."
                }
            }
        }
    }
    
    // MARK: - Camera Session Setup
    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        guard captureSession == nil else { return }
        
        let session = AVCaptureSession()
        
        do {
            // Configure session for high quality photo capture
            session.beginConfiguration()
            session.sessionPreset = .photo
            
            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw CameraError.deviceNotFound
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                throw CameraError.cannotAddInput
            }
            
            // Add photo output
            let photoOutput = AVCapturePhotoOutput()
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                self.photoOutput = photoOutput
                
                // Configure photo output for high quality
                photoOutput.isHighResolutionCaptureEnabled = true
                if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                    // JPEG is preferred for compatibility
                }
            } else {
                throw CameraError.cannotAddOutput
            }
            
            session.commitConfiguration()
            self.captureSession = session
            
            DispatchQueue.main.async {
                self.createPreviewLayer()
            }
            
        } catch {
            DispatchQueue.main.async {
                self.handleError(error)
            }
        }
    }
    
    private func createPreviewLayer() {
        guard let captureSession = captureSession else { return }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        self.previewLayer = previewLayer
    }
    
    // MARK: - Session Control
    func startSession() {
        guard isAuthorized else {
            checkCameraAuthorization()
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let captureSession = self?.captureSession else { return }
            
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let captureSession = self?.captureSession else { return }
            
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            errorMessage = "Photo output not configured"
            return
        }
        
        guard !isCapturing else { return }
        
        isCapturing = true
        errorMessage = nil
        
        sessionQueue.async { [weak self] in
            let photoSettings = AVCapturePhotoSettings()
            
            // Configure for high quality JPEG
            if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                photoSettings.flashMode = .auto
                photoSettings.isHighResolutionPhotoEnabled = true
                
                // Enable auto-stabilization if available
                if photoOutput.isStillImageStabilizationSupported {
                    photoSettings.isAutoStillImageStabilizationEnabled = true
                }
            }
            
            photoOutput.capturePhoto(with: photoSettings, delegate: self!)
        }
    }
    
    // MARK: - Image Picker Support
    func showImagePicker() {
        showingImagePicker = true
    }
    
    func handleImagePickerResult(_ result: Result<UIImage, Error>) {
        showingImagePicker = false
        
        switch result {
        case .success(let image):
            capturedImage = image
            print("✅ CameraViewModel: Image selected from photo library")
        case .failure(let error):
            handleError(error)
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.isCapturing = false
            self.errorMessage = error.localizedDescription
            print("❌ CameraViewModel error: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    func clearCapturedImage() {
        capturedImage = nil
        errorMessage = nil
    }
    
    func retakePhoto() {
        clearCapturedImage()
        startSession()
    }
    
    // MARK: - Preview Layer Management
    func configurePreviewLayer(for view: UIView) {
        guard let previewLayer = previewLayer else { return }
        
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.bounds
    }
    
    func updatePreviewLayerFrame(_ frame: CGRect) {
        previewLayer?.frame = frame
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        DispatchQueue.main.async {
            self.isCapturing = false
        }
        
        if let error = error {
            handleError(error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            handleError(CameraError.imageProcessingFailed)
            return
        }
        
        // Apply image orientation correction
        let correctedImage = correctImageOrientation(image)
        
        DispatchQueue.main.async {
            self.capturedImage = correctedImage
            print("✅ CameraViewModel: Photo captured successfully")
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Photo capture started - could add sound/haptic feedback here
        print("📸 CameraViewModel: Photo capture initiated")
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Image Processing
extension CameraViewModel {
    
    private func correctImageOrientation(_ image: UIImage) -> UIImage {
        // Ensure the image is properly oriented for receipt processing
        guard image.imageOrientation != .up else { return image }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return correctedImage ?? image
    }
    
    // Image enhancement for better OCR results
    func enhanceImageForOCR(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        
        // Apply filters to improve text recognition
        var enhancedImage = ciImage
        
        // Increase contrast
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.2, forKey: kCIInputContrastKey) // Increase contrast
            contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // Slight brightness boost
            
            if let output = contrastFilter.outputImage {
                enhancedImage = output
            }
        }
        
        // Sharpen text
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.7, forKey: kCIInputSharpnessKey)
            
            if let output = sharpenFilter.outputImage {
                enhancedImage = output
            }
        }
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(enhancedImage, from: enhancedImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Error Types
enum CameraError: Error, LocalizedError {
    case deviceNotFound
    case cannotAddInput
    case cannotAddOutput
    case imageProcessingFailed
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Camera device not found"
        case .cannotAddInput:
            return "Cannot add camera input"
        case .cannotAddOutput:
            return "Cannot add photo output"
        case .imageProcessingFailed:
            return "Failed to process captured image"
        case .authorizationDenied:
            return "Camera access denied"
        }
    }
}
