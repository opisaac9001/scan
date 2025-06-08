import Foundation
import Vision
import UIKit
import SwiftUI // Added for @AppStorage

class OCRService: ObservableObject {
    static let shared = OCRService()

    // AppStorage properties for OCR settings
    @AppStorage("ocr_recognition_level") private var recognitionLevelSetting: String = "accurate"
    @AppStorage("ocr_minimum_confidence") private var minimumConfidenceSetting: Double = 0.5 // Note: Not directly used by Vision request, for post-processing.
    @AppStorage("ocr_language_correction") private var languageCorrectionSetting: Bool = true
    @AppStorage("ocr_language") private var preferredLanguageSetting: String = "en-US" // Assuming this is a BCP-47 code like "en-US"

    private init() {}

    func recognizeText(from image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            if recognizedText.isEmpty {
                completion(.failure(OCRError.noTextFound))
            } else {
                completion(.success(recognizedText))
            }
        }

        // Configure the request using AppStorage settings
        request.recognitionLevel = (recognitionLevelSetting == "fast") ? .fast : .accurate
        request.usesLanguageCorrection = languageCorrectionSetting
        request.recognitionLanguages = [preferredLanguageSetting] // Assuming preferredLanguageSetting is a valid BCP-47 code

        // Process the image
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func recognizeTextWithConfidence(from image: UIImage, completion: @escaping (Result<OCRResult, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }

            var textLines: [OCRTextLine] = []
            var totalConfidence: Float = 0.0
            var lineCount = 0

            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    // Note: Filtering by minimumConfidenceSetting would happen here if implemented
                    // e.g., if candidate.confidence >= Float(self.minimumConfidenceSetting) { ... }
                    let textLine = OCRTextLine(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                    textLines.append(textLine)
                    totalConfidence += candidate.confidence
                    lineCount += 1
                }
            }

            let averageConfidence = lineCount > 0 ? totalConfidence / Float(lineCount) : 0.0
            let fullText = textLines.map { $0.text }.joined(separator: "\n")

            if textLines.isEmpty {
                completion(.failure(OCRError.noTextFound)) // Could also be due to all lines falling below a confidence threshold if implemented
            } else {
                let result = OCRResult(
                    fullText: fullText,
                    textLines: textLines,
                    averageConfidence: averageConfidence
                )
                completion(.success(result))
            }
        }

        // Configure the request using AppStorage settings
        request.recognitionLevel = (recognitionLevelSetting == "fast") ? .fast : .accurate
        request.usesLanguageCorrection = languageCorrectionSetting
        request.recognitionLanguages = [preferredLanguageSetting] // Assuming preferredLanguageSetting is a valid BCP-47 code

        // Process the image
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct OCRResult {
    let fullText: String
    let textLines: [OCRTextLine]
    let averageConfidence: Float
}

struct OCRTextLine {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid or cannot be processed."
        case .noTextFound:
            return "No text was found in the image."
        case .processingFailed:
            return "Text recognition processing failed."
        }
    }
}
