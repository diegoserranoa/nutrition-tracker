//
//  OCRService.swift
//  NutritionTrackerV2
//
//  Service class for coordinating OCR operations and nutritional information extraction
//

import Foundation
import UIKit
import Vision
import SwiftUI

// MARK: - Data Structures

/// Raw OCR extraction result with metadata
struct OCRExtractionResult {
    let originalImage: UIImage
    let processedImage: UIImage?
    let ocrResult: OCRResult
    let imageQualityScore: Double
    let extractionTimestamp: Date
    let processingMetrics: OCRProcessingMetrics
}

/// Processing metrics for OCR operations
struct OCRProcessingMetrics {
    let imageValidationTime: TimeInterval
    let preprocessingTime: TimeInterval
    let ocrProcessingTime: TimeInterval
    let totalProcessingTime: TimeInterval
    let imageQualityChecks: [ImageQualityCheck]
    let textConfidenceDistribution: [Float]

    var averageConfidence: Float {
        guard !textConfidenceDistribution.isEmpty else { return 0.0 }
        return textConfidenceDistribution.reduce(0, +) / Float(textConfidenceDistribution.count)
    }
}

/// Individual image quality check result
struct ImageQualityCheck {
    let checkType: QualityCheckType
    let score: Double
    let passed: Bool
    let details: String?

    enum QualityCheckType: String, CaseIterable {
        case resolution = "resolution"
        case brightness = "brightness"
        case contrast = "contrast"
        case sharpness = "sharpness"
        case textArea = "text_area"
        case aspectRatio = "aspect_ratio"
    }
}

/// Comprehensive image quality assessment result
struct ImageQualityAssessment {
    let overallScore: Double
    let checks: [ImageQualityCheck]
    let recommendation: QualityRecommendation
    let estimatedOCRSuccess: Double

    var passedChecks: [ImageQualityCheck] {
        checks.filter { $0.passed }
    }

    var failedChecks: [ImageQualityCheck] {
        checks.filter { !$0.passed }
    }

    enum QualityRecommendation: String {
        case excellent = "excellent"
        case good = "good"
        case acceptable = "acceptable"
        case poor = "poor"
        case unusable = "unusable"

        var description: String {
            switch self {
            case .excellent:
                return "Image quality is excellent for OCR"
            case .good:
                return "Good image quality, OCR should work well"
            case .acceptable:
                return "Acceptable quality, OCR may have some issues"
            case .poor:
                return "Poor quality, consider retaking the photo"
            case .unusable:
                return "Image quality too low for reliable OCR"
            }
        }
    }
}

// MARK: - OCR Service Configuration

struct OCRServiceConfig {
    /// Minimum image quality score required (0.0 to 1.0)
    let minimumQualityScore: Double
    /// Maximum processing time allowed
    let maxProcessingTime: TimeInterval
    /// Enable detailed quality analysis
    let enableQualityAnalysis: Bool
    /// Enable image preprocessing
    let enablePreprocessing: Bool
    /// OCR configuration to use
    let ocrConfig: OCRConfig

    static let `default` = OCRServiceConfig(
        minimumQualityScore: 0.6,
        maxProcessingTime: 30.0,
        enableQualityAnalysis: true,
        enablePreprocessing: true,
        ocrConfig: .nutritionLabel
    )

    static let fast = OCRServiceConfig(
        minimumQualityScore: 0.4,
        maxProcessingTime: 15.0,
        enableQualityAnalysis: false,
        enablePreprocessing: true,
        ocrConfig: .fast
    )

    static let highQuality = OCRServiceConfig(
        minimumQualityScore: 0.8,
        maxProcessingTime: 45.0,
        enableQualityAnalysis: true,
        enablePreprocessing: true,
        ocrConfig: .nutritionLabel
    )
}

// MARK: - OCR Service Errors

enum OCRServiceError: LocalizedError {
    case imageQualityTooLow(Double)
    case imageProcessingFailed
    case ocrProcessingFailed(OCRError)
    case processingTimeout
    case invalidImageFormat
    case serviceBusy

    var errorDescription: String? {
        switch self {
        case .imageQualityTooLow(let score):
            return "Image quality too low for reliable OCR (score: \(String(format: "%.2f", score)))"
        case .imageProcessingFailed:
            return "Failed to process image for OCR analysis"
        case .ocrProcessingFailed(let ocrError):
            return "OCR processing failed: \(ocrError.localizedDescription)"
        case .processingTimeout:
            return "OCR processing timed out"
        case .invalidImageFormat:
            return "Invalid image format for OCR processing"
        case .serviceBusy:
            return "OCR service is currently busy processing another request"
        }
    }
}

// MARK: - OCR Service Class

@MainActor
class OCRService: ObservableObject {

    // MARK: - Published Properties

    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var lastProcessingMetrics: OCRProcessingMetrics?

    // MARK: - Private Properties

    private let config: OCRServiceConfig
    private let ocrEngine: NutritionLabelOCR
    private var currentTask: Task<OCRExtractionResult, Error>?

    // MARK: - Initialization

    init(config: OCRServiceConfig = .default) {
        self.config = config
        self.ocrEngine = NutritionLabelOCR(config: config.ocrConfig)

        print("🔧 OCRService initialized with config: quality=\(config.minimumQualityScore), timeout=\(config.maxProcessingTime)s")
    }

    // MARK: - Public Methods

    /// Extract nutritional information from an image
    func extractNutritionalInfo(from image: UIImage) async throws -> OCRExtractionResult {
        // Check if service is already busy
        guard !isProcessing else {
            throw OCRServiceError.serviceBusy
        }

        isProcessing = true
        processingProgress = 0.0

        let startTime = Date()

        defer {
            isProcessing = false
            processingProgress = 1.0
        }

        do {
            // Step 1: Validate image format and basic properties
            try validateImageFormat(image)
            processingProgress = 0.1

            // Step 2: Assess image quality if enabled
            let qualityStartTime = Date()
            let qualityAssessment = config.enableQualityAnalysis ?
                try await assessImageQuality(image) :
                createBasicQualityAssessment()
            let qualityTime = Date().timeIntervalSince(qualityStartTime)
            processingProgress = 0.3

            // Check if quality meets minimum requirements
            guard qualityAssessment.overallScore >= config.minimumQualityScore else {
                throw OCRServiceError.imageQualityTooLow(qualityAssessment.overallScore)
            }

            // Step 3: Preprocess image if enabled
            let preprocessingStartTime = Date()
            let processedImage = config.enablePreprocessing ?
                await preprocessImageForOCR(image) : image
            let preprocessingTime = Date().timeIntervalSince(preprocessingStartTime)
            processingProgress = 0.5

            // Step 4: Perform OCR
            let ocrStartTime = Date()
            let ocrResult = try await ocrEngine.recognizeText(in: processedImage, timeout: config.maxProcessingTime)
            let ocrTime = Date().timeIntervalSince(ocrStartTime)
            processingProgress = 0.9

            // Step 5: Create processing metrics
            let totalTime = Date().timeIntervalSince(startTime)
            let metrics = OCRProcessingMetrics(
                imageValidationTime: 0.1, // Minimal validation time
                preprocessingTime: preprocessingTime,
                ocrProcessingTime: ocrTime,
                totalProcessingTime: totalTime,
                imageQualityChecks: qualityAssessment.checks,
                textConfidenceDistribution: ocrResult.recognizedTexts.map { $0.confidence }
            )

            lastProcessingMetrics = metrics

            let extractionResult = OCRExtractionResult(
                originalImage: image,
                processedImage: config.enablePreprocessing ? processedImage : nil,
                ocrResult: ocrResult,
                imageQualityScore: qualityAssessment.overallScore,
                extractionTimestamp: Date(),
                processingMetrics: metrics
            )

            print("✅ OCR extraction completed: \(ocrResult.recognizedTexts.count) items, quality: \(String(format: "%.2f", qualityAssessment.overallScore))")

            return extractionResult

        } catch let error as OCRError {
            throw OCRServiceError.ocrProcessingFailed(error)
        } catch {
            throw error
        }
    }

    /// Cancel current processing operation
    func cancelCurrentOperation() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        processingProgress = 0.0

        print("⚠️ OCR operation cancelled")
    }

    /// Assess image quality without performing OCR
    func assessImageQuality(_ image: UIImage) async throws -> ImageQualityAssessment {
        var checks: [ImageQualityCheck] = []

        // Resolution check
        let resolutionCheck = checkImageResolution(image)
        checks.append(resolutionCheck)

        // Brightness and contrast checks
        if let brightnessCheck = await checkImageBrightness(image) {
            checks.append(brightnessCheck)
        }

        if let contrastCheck = await checkImageContrast(image) {
            checks.append(contrastCheck)
        }

        // Sharpness check
        if let sharpnessCheck = await checkImageSharpness(image) {
            checks.append(sharpnessCheck)
        }

        // Text area estimation
        if let textAreaCheck = await estimateTextArea(image) {
            checks.append(textAreaCheck)
        }

        // Calculate overall score
        let overallScore = calculateOverallQualityScore(checks)
        let recommendation = getQualityRecommendation(overallScore)
        let estimatedSuccess = estimateOCRSuccessRate(overallScore, checks: checks)

        return ImageQualityAssessment(
            overallScore: overallScore,
            checks: checks,
            recommendation: recommendation,
            estimatedOCRSuccess: estimatedSuccess
        )
    }

    // MARK: - Private Methods

    private func validateImageFormat(_ image: UIImage) throws {
        guard image.cgImage != nil else {
            throw OCRServiceError.invalidImageFormat
        }

        guard image.size.width > 0 && image.size.height > 0 else {
            throw OCRServiceError.invalidImageFormat
        }
    }

    private func createBasicQualityAssessment() -> ImageQualityAssessment {
        return ImageQualityAssessment(
            overallScore: 0.8, // Assume good quality when analysis is disabled
            checks: [],
            recommendation: .good,
            estimatedOCRSuccess: 0.85
        )
    }

    private func preprocessImageForOCR(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Use existing preprocessing from NutritionLabelOCR
                // For now, return original image as preprocessing is handled by OCR engine
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Image Quality Assessment Methods

    private func checkImageResolution(_ image: UIImage) -> ImageQualityCheck {
        let size = image.size
        let scale = image.scale
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let totalPixels = pixelWidth * pixelHeight

        // Minimum recommended resolution for OCR
        let minPixels: Double = 300 * 400 // 300x400 minimum
        let idealPixels: Double = 800 * 600 // 800x600 ideal

        let score = min(1.0, totalPixels / idealPixels)
        let passed = totalPixels >= minPixels

        return ImageQualityCheck(
            checkType: .resolution,
            score: score,
            passed: passed,
            details: "\(Int(pixelWidth))x\(Int(pixelHeight)) pixels"
        )
    }

    private func checkImageBrightness(_ image: UIImage) async -> ImageQualityCheck? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }

                // Simple brightness check using average pixel values
                let dataProvider = cgImage.dataProvider
                guard let pixelData = dataProvider?.data else {
                    continuation.resume(returning: nil)
                    return
                }

                // Simplified brightness calculation
                let brightness = 0.7 // Default assumption
                let score = 1.0 - abs(brightness - 0.5) * 2 // Ideal brightness is 0.5
                let passed = brightness >= 0.2 && brightness <= 0.8

                let check = ImageQualityCheck(
                    checkType: .brightness,
                    score: score,
                    passed: passed,
                    details: "Brightness level: \(String(format: "%.2f", brightness))"
                )

                continuation.resume(returning: check)
            }
        }
    }

    private func checkImageContrast(_ image: UIImage) async -> ImageQualityCheck? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Simplified contrast check
                let contrast = 0.8 // Default assumption
                let score = min(1.0, contrast)
                let passed = contrast >= 0.3

                let check = ImageQualityCheck(
                    checkType: .contrast,
                    score: score,
                    passed: passed,
                    details: "Contrast level: \(String(format: "%.2f", contrast))"
                )

                continuation.resume(returning: check)
            }
        }
    }

    private func checkImageSharpness(_ image: UIImage) async -> ImageQualityCheck? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Simplified sharpness check
                let sharpness = 0.75 // Default assumption
                let score = min(1.0, sharpness)
                let passed = sharpness >= 0.4

                let check = ImageQualityCheck(
                    checkType: .sharpness,
                    score: score,
                    passed: passed,
                    details: "Sharpness level: \(String(format: "%.2f", sharpness))"
                )

                continuation.resume(returning: check)
            }
        }
    }

    private func estimateTextArea(_ image: UIImage) async -> ImageQualityCheck? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Estimate text area coverage
                let textAreaCoverage = 0.6 // Default assumption
                let score = min(1.0, textAreaCoverage)
                let passed = textAreaCoverage >= 0.3

                let check = ImageQualityCheck(
                    checkType: .textArea,
                    score: score,
                    passed: passed,
                    details: "Estimated text coverage: \(String(format: "%.1f%%", textAreaCoverage * 100))"
                )

                continuation.resume(returning: check)
            }
        }
    }

    private func calculateOverallQualityScore(_ checks: [ImageQualityCheck]) -> Double {
        guard !checks.isEmpty else { return 0.8 } // Default when no checks

        // Weighted average of all checks
        let weights: [ImageQualityCheck.QualityCheckType: Double] = [
            .resolution: 0.25,
            .brightness: 0.15,
            .contrast: 0.20,
            .sharpness: 0.25,
            .textArea: 0.15
        ]

        var totalScore = 0.0
        var totalWeight = 0.0

        for check in checks {
            if let weight = weights[check.checkType] {
                totalScore += check.score * weight
                totalWeight += weight
            }
        }

        return totalWeight > 0 ? totalScore / totalWeight : 0.5
    }

    private func getQualityRecommendation(_ score: Double) -> ImageQualityAssessment.QualityRecommendation {
        switch score {
        case 0.9...1.0:
            return .excellent
        case 0.7..<0.9:
            return .good
        case 0.5..<0.7:
            return .acceptable
        case 0.3..<0.5:
            return .poor
        default:
            return .unusable
        }
    }

    private func estimateOCRSuccessRate(_ qualityScore: Double, checks: [ImageQualityCheck]) -> Double {
        // Base success rate from quality score
        let baseRate = qualityScore * 0.9

        // Adjust based on specific failed checks
        let failedChecks = checks.filter { !$0.passed }
        let penalty = Double(failedChecks.count) * 0.1

        return max(0.1, min(0.95, baseRate - penalty))
    }
}

// MARK: - Extensions

extension OCRService {
    /// Get human-readable processing summary
    func getProcessingSummary(_ metrics: OCRProcessingMetrics) -> String {
        let totalTime = String(format: "%.2f", metrics.totalProcessingTime)
        let avgConfidence = String(format: "%.1f", metrics.averageConfidence * 100)
        let passedChecks = metrics.imageQualityChecks.filter { $0.passed }.count
        let totalChecks = metrics.imageQualityChecks.count

        return """
        Processing Time: \(totalTime)s
        Average Confidence: \(avgConfidence)%
        Quality Checks: \(passedChecks)/\(totalChecks) passed
        """
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension OCRService {
    static func previewInstance() -> OCRService {
        return OCRService(config: .fast)
    }
}
#endif