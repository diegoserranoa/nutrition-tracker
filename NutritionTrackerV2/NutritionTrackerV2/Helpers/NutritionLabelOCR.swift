//
//  NutritionLabelOCR.swift
//  NutritionTrackerV2
//
//  Vision framework integration for nutrition label text recognition and processing
//

import Vision
import UIKit
import CoreImage
import Accelerate
import SwiftUI

/// Configuration for OCR text recognition
struct OCRConfig {
    /// Recognition level for text detection
    let recognitionLevel: VNRequestTextRecognitionLevel
    /// Languages to recognize (ISO language codes)
    let recognitionLanguages: [String]
    /// Minimum confidence threshold for accepted text
    let minimumTextConfidence: Float
    /// Whether to use language correction
    let usesLanguageCorrection: Bool
    /// Custom words to recognize (nutrition-specific terms)
    let customWords: [String]

    static let nutritionLabel = OCRConfig(
        recognitionLevel: .accurate,
        recognitionLanguages: ["en-US"],
        minimumTextConfidence: 0.8,
        usesLanguageCorrection: true,
        customWords: [
            "calories", "protein", "carbohydrates", "fat", "fiber", "sugar",
            "sodium", "potassium", "calcium", "iron", "vitamin", "serving",
            "per", "container", "total", "saturated", "trans", "cholesterol",
            "dietary", "added", "includes", "daily", "value", "percent", "%"
        ]
    )

    static let fast = OCRConfig(
        recognitionLevel: .fast,
        recognitionLanguages: ["en-US"],
        minimumTextConfidence: 0.6,
        usesLanguageCorrection: false,
        customWords: []
    )
}

/// Result of OCR text recognition
struct OCRResult: Equatable {
    /// All recognized text observations
    let textObservations: [VNRecognizedTextObservation]
    /// Extracted text strings with confidence scores
    let recognizedTexts: [(text: String, confidence: Float, boundingBox: CGRect)]
    /// Processing time in seconds
    let processingTime: TimeInterval
    /// Whether any text was found
    var hasText: Bool { !recognizedTexts.isEmpty }
    /// Combined text string
    var fullText: String { recognizedTexts.map { $0.text }.joined(separator: "\n") }

    static func == (lhs: OCRResult, rhs: OCRResult) -> Bool {
        // Compare based on recognized texts and processing time, ignoring VNRecognizedTextObservation
        return lhs.recognizedTexts.count == rhs.recognizedTexts.count &&
               lhs.processingTime == rhs.processingTime &&
               zip(lhs.recognizedTexts, rhs.recognizedTexts).allSatisfy { left, right in
                   left.text == right.text && left.confidence == right.confidence && left.boundingBox == right.boundingBox
               }
    }
}

/// Errors that can occur during OCR processing
enum OCRError: LocalizedError {
    case visionFrameworkError(Error)
    case noTextFound
    case imageProcessingFailed
    case configurationError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .visionFrameworkError(let error):
            return "Vision framework error: \(error.localizedDescription)"
        case .noTextFound:
            return "No text found in the image"
        case .imageProcessingFailed:
            return "Failed to process image for OCR"
        case .configurationError(let message):
            return "OCR configuration error: \(message)"
        case .timeout:
            return "OCR processing timed out"
        }
    }
}

/// Main OCR text recognition class
@MainActor
class NutritionLabelOCR: ObservableObject {

    // MARK: - Private Properties

    private let config: OCRConfig
    private var textRecognitionRequest: VNRecognizeTextRequest?

    // MARK: - Initialization

    init(config: OCRConfig = .nutritionLabel) {
        self.config = config
        setupTextRecognitionRequest()
    }

    // MARK: - Public Methods

    /// Recognize text in an image
    func recognizeText(in image: UIImage, timeout: TimeInterval = 30.0) async throws -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Preprocess image for better OCR accuracy
        guard let preprocessedImage = preprocessImageForOCR(image) else {
            throw OCRError.imageProcessingFailed
        }

        guard let ciImage = CIImage(image: preprocessedImage) else {
            throw OCRError.imageProcessingFailed
        }

        // Create request for this specific operation
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = config.recognitionLevel
        if !config.recognitionLanguages.isEmpty {
            request.recognitionLanguages = config.recognitionLanguages
        }
        request.usesLanguageCorrection = config.usesLanguageCorrection
        if !config.customWords.isEmpty {
            request.customWords = config.customWords
        }
        request.automaticallyDetectsLanguage = true

        // Perform the request
        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                continuation.resume(throwing: OCRError.timeout)
            }

            Task.detached { [requestHandler, request] in
                do {
                    try requestHandler.perform([request])
                    timeoutTask.cancel()

                    guard let observations = request.results else {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }

                    let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                    let result = await self.processTextObservations(observations, processingTime: processingTime)

                    if result.hasText {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: OCRError.noTextFound)
                    }
                } catch {
                    timeoutTask.cancel()
                    continuation.resume(throwing: OCRError.visionFrameworkError(error))
                }
            }
        }
    }

    /// Recognize text synchronously (for testing)
    func recognizeTextSync(in image: UIImage) throws -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let preprocessedImage = preprocessImageForOCR(image) else {
            throw OCRError.imageProcessingFailed
        }

        guard let ciImage = CIImage(image: preprocessedImage) else {
            throw OCRError.imageProcessingFailed
        }

        // Create request for this specific operation
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = config.recognitionLevel
        if !config.recognitionLanguages.isEmpty {
            request.recognitionLanguages = config.recognitionLanguages
        }
        request.usesLanguageCorrection = config.usesLanguageCorrection
        if !config.customWords.isEmpty {
            request.customWords = config.customWords
        }
        request.automaticallyDetectsLanguage = true

        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try requestHandler.perform([request])

        guard let observations = request.results else {
            throw OCRError.noTextFound
        }

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let result = processTextObservations(observations, processingTime: processingTime)

        if result.hasText {
            return result
        } else {
            throw OCRError.noTextFound
        }
    }

    // MARK: - Private Methods

    private func setupTextRecognitionRequest() {
        let request = VNRecognizeTextRequest()

        // Configure recognition level
        request.recognitionLevel = config.recognitionLevel

        // Set recognition languages
        if !config.recognitionLanguages.isEmpty {
            request.recognitionLanguages = config.recognitionLanguages
        }

        // Enable language correction if specified
        request.usesLanguageCorrection = config.usesLanguageCorrection

        // Set custom words for better recognition
        if !config.customWords.isEmpty {
            request.customWords = config.customWords
        }

        // Enable automatic language detection
        request.automaticallyDetectsLanguage = true

        self.textRecognitionRequest = request

        print("🔤 OCR configured with recognition level: \(config.recognitionLevel), languages: \(config.recognitionLanguages)")
    }

    private func processTextObservations(_ observations: [VNRecognizedTextObservation], processingTime: TimeInterval) -> OCRResult {
        var recognizedTexts: [(text: String, confidence: Float, boundingBox: CGRect)] = []

        for observation in observations {
            // Get the top candidate for each observation
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            // Filter by confidence threshold
            if topCandidate.confidence >= config.minimumTextConfidence {
                recognizedTexts.append((
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: observation.boundingBox
                ))
            }
        }

        // Sort by reading order (top to bottom, left to right)
        recognizedTexts.sort { first, second in
            let firstY = 1.0 - first.boundingBox.midY  // Flip Y coordinate
            let secondY = 1.0 - second.boundingBox.midY

            // If on different lines (Y difference > threshold), sort by Y
            if abs(firstY - secondY) > 0.05 {
                return firstY < secondY
            }
            // If on same line, sort by X
            return first.boundingBox.midX < second.boundingBox.midX
        }

        print("✅ OCR completed in \(String(format: "%.3f", processingTime))s: found \(recognizedTexts.count) text items")

        return OCRResult(
            textObservations: observations,
            recognizedTexts: recognizedTexts,
            processingTime: processingTime
        )
    }

    private func preprocessImageForOCR(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Create filter chain for optimal OCR
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return image }
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.2, forKey: kCIInputContrastKey) // Increase contrast
        contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // Slight brightness increase

        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return image }
        exposureFilter.setValue(contrastFilter.outputImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.3, forKey: kCIInputEVKey) // Increase exposure slightly

        // Sharpen for better text clarity
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return image }
        sharpenFilter.setValue(exposureFilter.outputImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.8, forKey: kCIInputSharpnessKey)

        guard let outputImage = sharpenFilter.outputImage else { return image }

        // Convert back to UIImage
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Extensions

extension VNRequestTextRecognitionLevel: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .fast:
            return "fast"
        case .accurate:
            return "accurate"
        @unknown default:
            return "unknown"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension NutritionLabelOCR {
    /// Create a test instance with fast configuration for previews
    static func testInstance() -> NutritionLabelOCR {
        return NutritionLabelOCR(config: .fast)
    }
}
#endif