//
//  NutritionExtractionService.swift
//  NutritionTrackerV2
//
//  Combined service for OCR + parsing workflow for nutrition label extraction
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Complete Nutrition Extraction Result

/// Complete result of nutrition extraction from image to parsed data
struct NutritionExtractionResult: Equatable {
    let ocrResult: OCRExtractionResult
    let parsedNutrition: ParsedNutritionData
    let extractionMetrics: ExtractionMetrics
    let recommendations: [ExtractionRecommendation]

    /// Overall success rating
    var successRating: ExtractionSuccessRating {
        let confidence = parsedNutrition.confidence.overallScore
        switch confidence {
        case 0.8...:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        default:
            return .poor
        }
    }

    /// Human-readable summary
    var summary: String {
        let ocrSummary = ocrResult.ocrResult.recognizedTexts.count
        let nutritionSummary = parsedNutrition.summary
        let confidence = String(format: "%.1f%%", parsedNutrition.confidence.overallScore * 100)

        return "Found \(ocrSummary) text items, \(nutritionSummary) (confidence: \(confidence))"
    }
}

/// Extraction performance metrics
struct ExtractionMetrics: Equatable {
    let totalProcessingTime: TimeInterval
    let ocrProcessingTime: TimeInterval
    let parsingTime: TimeInterval
    let imageQualityScore: Double
    let textRecognitionAccuracy: Double
    let nutritionParsingAccuracy: Double

    var efficiency: ExtractionEfficiency {
        if totalProcessingTime < 3.0 && nutritionParsingAccuracy > 0.8 {
            return .excellent
        } else if totalProcessingTime < 5.0 && nutritionParsingAccuracy > 0.6 {
            return .good
        } else if totalProcessingTime < 8.0 && nutritionParsingAccuracy > 0.4 {
            return .acceptable
        } else {
            return .poor
        }
    }

    enum ExtractionEfficiency {
        case excellent, good, acceptable, poor

        var description: String {
            switch self {
            case .excellent: return "Excellent efficiency"
            case .good: return "Good efficiency"
            case .acceptable: return "Acceptable efficiency"
            case .poor: return "Poor efficiency"
            }
        }
    }
}

/// Extraction success rating
enum ExtractionSuccessRating {
    case excellent, good, fair, poor

    var description: String {
        switch self {
        case .excellent: return "Excellent extraction quality"
        case .good: return "Good extraction quality"
        case .fair: return "Fair extraction quality"
        case .poor: return "Poor extraction quality - consider retaking photo"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

/// Recommendations for improving extraction results
struct ExtractionRecommendation: Equatable {
    let type: RecommendationType
    let message: String
    let priority: Priority

    enum RecommendationType {
        case imageQuality, lighting, framing, retake, manualEntry
    }

    enum Priority {
        case high, medium, low
    }
}

// MARK: - Nutrition Extraction Service

@MainActor
class NutritionExtractionService: ObservableObject {

    // MARK: - Published Properties

    @Published var isProcessing: Bool = false
    @Published var processingStage: ProcessingStage = .idle
    @Published var processingProgress: Double = 0.0
    @Published var lastResult: NutritionExtractionResult?
    @Published var lastError: Error?

    // MARK: - Private Properties

    private let ocrService: OCRService
    private let textParser: NutritionTextParser

    // MARK: - Processing Stages

    enum ProcessingStage {
        case idle
        case imageQualityCheck
        case ocrProcessing
        case textParsing
        case generatingRecommendations
        case completed

        var description: String {
            switch self {
            case .idle: return "Ready"
            case .imageQualityCheck: return "Checking image quality..."
            case .ocrProcessing: return "Extracting text..."
            case .textParsing: return "Parsing nutrition data..."
            case .generatingRecommendations: return "Generating recommendations..."
            case .completed: return "Extraction complete"
            }
        }
    }

    // MARK: - Initialization

    init(ocrConfig: OCRServiceConfig = .default, parserConfig: NutritionParserConfig = .default) {
        self.ocrService = OCRService(config: ocrConfig)
        self.textParser = NutritionTextParser(config: parserConfig)
    }

    // MARK: - Public Methods

    /// Extract complete nutrition information from image
    func extractNutrition(from image: UIImage) async -> NutritionExtractionResult? {
        guard !isProcessing else {
            print("⚠️ Extraction already in progress")
            return nil
        }

        let startTime = Date()
        isProcessing = true
        processingProgress = 0.0
        lastError = nil

        defer {
            isProcessing = false
            processingStage = .completed
        }

        do {
            // Stage 1: Image quality check and OCR
            processingStage = .imageQualityCheck
            processingProgress = 0.1

            processingStage = .ocrProcessing
            processingProgress = 0.3

            let ocrResult = try await ocrService.extractNutritionalInfo(from: image)
            processingProgress = 0.6

            print("🔤 OCR completed: \(ocrResult.ocrResult.recognizedTexts.count) text items")

            // Stage 2: Parse nutrition data
            processingStage = .textParsing
            processingProgress = 0.8

            let parsingStartTime = Date()
            let parsedNutrition = textParser.parseNutritionData(from: ocrResult.ocrResult)
            let parsingTime = Date().timeIntervalSince(parsingStartTime)

            print("🧠 Parsing completed: \(parsedNutrition.summary)")

            // Stage 3: Generate recommendations
            processingStage = .generatingRecommendations
            processingProgress = 0.9

            let recommendations = generateRecommendations(
                ocrResult: ocrResult,
                parsedNutrition: parsedNutrition
            )

            // Stage 4: Create final result
            let totalTime = Date().timeIntervalSince(startTime)
            let metrics = ExtractionMetrics(
                totalProcessingTime: totalTime,
                ocrProcessingTime: ocrResult.processingMetrics.totalProcessingTime,
                parsingTime: parsingTime,
                imageQualityScore: ocrResult.imageQualityScore,
                textRecognitionAccuracy: Double(ocrResult.processingMetrics.averageConfidence),
                nutritionParsingAccuracy: parsedNutrition.confidence.overallScore
            )

            let result = NutritionExtractionResult(
                ocrResult: ocrResult,
                parsedNutrition: parsedNutrition,
                extractionMetrics: metrics,
                recommendations: recommendations
            )

            lastResult = result
            processingProgress = 1.0

            print("✅ Nutrition extraction completed:")
            print("   - \(result.summary)")
            print("   - Success Rating: \(result.successRating.description)")
            print("   - Efficiency: \(metrics.efficiency.description)")

            return result

        } catch {
            lastError = error
            print("❌ Nutrition extraction failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Cancel current extraction
    func cancelExtraction() {
        ocrService.cancelCurrentOperation()
        isProcessing = false
        processingStage = .idle
        processingProgress = 0.0
    }

    /// Clear last result and errors
    func clearResults() {
        lastResult = nil
        lastError = nil
    }

    // MARK: - Private Methods

    private func generateRecommendations(
        ocrResult: OCRExtractionResult,
        parsedNutrition: ParsedNutritionData
    ) -> [ExtractionRecommendation] {
        var recommendations: [ExtractionRecommendation] = []

        // Image quality recommendations
        if ocrResult.imageQualityScore < 0.6 {
            recommendations.append(ExtractionRecommendation(
                type: .imageQuality,
                message: "Image quality is low. Try taking a clearer photo with better lighting.",
                priority: .high
            ))
        }

        // OCR confidence recommendations
        if ocrResult.processingMetrics.averageConfidence < 0.7 {
            recommendations.append(ExtractionRecommendation(
                type: .lighting,
                message: "Text recognition confidence is low. Ensure good lighting and clear text visibility.",
                priority: .medium
            ))
        }

        // Parsing confidence recommendations
        if parsedNutrition.confidence.overallScore < 0.6 {
            if parsedNutrition.hasBasicNutrition {
                recommendations.append(ExtractionRecommendation(
                    type: .framing,
                    message: "Some nutrition information was found but confidence is low. Try centering the nutrition label in the frame.",
                    priority: .medium
                ))
            } else {
                recommendations.append(ExtractionRecommendation(
                    type: .retake,
                    message: "No nutrition information could be reliably extracted. Consider retaking the photo or entering data manually.",
                    priority: .high
                ))
            }
        }

        // Manual entry recommendation for very poor results
        if parsedNutrition.confidence.overallScore < 0.3 && !parsedNutrition.hasBasicNutrition {
            recommendations.append(ExtractionRecommendation(
                type: .manualEntry,
                message: "Automatic extraction failed. Manual entry may be more reliable for this label.",
                priority: .high
            ))
        }

        return recommendations
    }
}

// MARK: - Convenience Extensions

extension NutritionExtractionResult {
    /// Check if result has usable nutrition data
    var hasUsableData: Bool {
        return parsedNutrition.hasBasicNutrition && parsedNutrition.confidence.overallScore >= 0.4
    }

    /// Get high-priority recommendations
    var highPriorityRecommendations: [ExtractionRecommendation] {
        return recommendations.filter { $0.priority == .high }
    }

    /// Create Food model from extraction result
    func createFood(name: String) -> Food? {
        guard hasUsableData else { return nil }

        let nutrition = parsedNutrition

        // Extract serving information
        let servingSize = nutrition.servingInfo?.size ?? 1.0
        let servingUnit = nutrition.servingInfo?.unit ?? "serving"

        // Extract macronutrients
        let calories = nutrition.calories?.value ?? 0.0
        let protein = nutrition.macronutrients.protein?.value ?? 0.0
        let carbs = nutrition.macronutrients.carbohydrates?.value ?? 0.0
        let fat = nutrition.macronutrients.fat?.value ?? 0.0

        // Extract micronutrients
        let sodium = nutrition.micronutrients.sodium?.value
        let calcium = nutrition.micronutrients.calcium?.value
        let iron = nutrition.micronutrients.iron?.value

        // Note: This is a simplified Food creation - would need to match
        // the actual Food model structure from the codebase
        return nil // Placeholder - actual implementation would create proper Food object
    }
}

// MARK: - SwiftUI Integration

struct NutritionExtractionStatusView: View {
    @ObservedObject var service: NutritionExtractionService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: service.isProcessing ? "gearshape.2.fill" : statusIcon)
                    .foregroundColor(statusColor)
                    .symbolEffect(.pulse, isActive: service.isProcessing)

                Text(service.processingStage.description)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if service.isProcessing {
                    Text("\(Int(service.processingProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if service.isProcessing {
                ProgressView(value: service.processingProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
            }

            if let result = service.lastResult {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(result.successRating.color)

                    Text(result.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            if let error = service.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var statusIcon: String {
        if service.lastError != nil {
            return "exclamationmark.triangle.fill"
        } else if service.lastResult != nil {
            return "checkmark.circle.fill"
        } else {
            return "camera.viewfinder"
        }
    }

    private var statusColor: Color {
        if service.lastError != nil {
            return .red
        } else if let result = service.lastResult {
            return result.successRating.color
        } else {
            return .blue
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension NutritionExtractionService {
    static func previewInstance() -> NutritionExtractionService {
        let service = NutritionExtractionService()
        // Add mock data for preview
        return service
    }
}

struct NutritionExtractionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            NutritionExtractionStatusView(service: {
                let service = NutritionExtractionService.previewInstance()
                service.isProcessing = true
                service.processingStage = .ocrProcessing
                service.processingProgress = 0.6
                return service
            }())

            NutritionExtractionStatusView(service: NutritionExtractionService.previewInstance())
        }
        .padding()
    }
}
#endif