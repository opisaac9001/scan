import Foundation
import Vision
import UIKit

class OCRService: ObservableObject {
    static let shared = OCRService()
    
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
        
        // Configure the request for optimal receipt text recognition
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        
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
                completion(.failure(OCRError.noTextFound))
            } else {
                let result = OCRResult(
                    fullText: fullText,
                    textLines: textLines,
                    averageConfidence: averageConfidence
                )
                completion(.success(result))
            }
        }
        
        // Configure the request for optimal receipt text recognition
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        
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
