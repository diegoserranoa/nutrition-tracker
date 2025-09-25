//
//  OCRServiceIntegration.swift
//  NutritionTrackerV2
//
//  Integration helpers and utilities for OCRService usage throughout the app
//

import Foundation
import SwiftUI
import UIKit

// MARK: - OCR Integration Manager

/// Manager class that provides simplified OCR integration for different use cases
@MainActor
class OCRIntegrationManager: ObservableObject {

    // MARK: - Published Properties

    @Published var currentService: OCRService
    @Published var isProcessing: Bool = false
    @Published var lastError: OCRServiceError?
    @Published var processingHistory: [OCRExtractionResult] = []

    // MARK: - Private Properties

    private var serviceObservation: AnyCancellable?

    // MARK: - Initialization

    init(serviceConfig: OCRServiceConfig = .default) {
        self.currentService = OCRService(config: serviceConfig)
        setupServiceObservation()
    }

    // MARK: - Public Methods

    /// Process nutrition label with automatic error handling and history tracking
    func processNutritionLabel(_ image: UIImage) async -> OCRExtractionResult? {
        lastError = nil

        do {
            let result = try await currentService.extractNutritionalInfo(from: image)
            processingHistory.insert(result, at: 0) // Add to beginning

            // Keep only last 10 results
            if processingHistory.count > 10 {
                processingHistory = Array(processingHistory.prefix(10))
            }

            print("✅ OCR Integration: Successfully processed nutrition label")
            return result

        } catch let error as OCRServiceError {
            lastError = error
            print("❌ OCR Integration Error: \(error.localizedDescription)")
            return nil
        } catch {
            lastError = .ocrProcessingFailed(OCRError.visionFrameworkError(error))
            print("❌ OCR Integration Unknown Error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Switch to different service configuration
    func switchServiceConfig(_ config: OCRServiceConfig) {
        currentService = OCRService(config: config)
        setupServiceObservation()
        print("🔄 Switched OCR service to \(configName(config))")
    }

    /// Clear processing history and errors
    func clearHistory() {
        processingHistory.removeAll()
        lastError = nil
    }

    /// Get recommended service configuration based on use case
    static func recommendedConfig(for useCase: OCRUseCase) -> OCRServiceConfig {
        switch useCase {
        case .quickScan:
            return .fast
        case .accurateExtraction:
            return .default
        case .highQuality:
            return .highQuality
        case .batch:
            return .fast
        }
    }

    // MARK: - Private Methods

    private func setupServiceObservation() {
        // Remove previous observation
        serviceObservation?.cancel()

        // Observe service processing state
        serviceObservation = currentService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isProcessing, on: self)
    }

    private func configName(_ config: OCRServiceConfig) -> String {
        switch config.minimumQualityScore {
        case 0.8...:
            return "high quality"
        case 0.6..<0.8:
            return "default"
        default:
            return "fast"
        }
    }
}

// MARK: - OCR Use Cases

enum OCRUseCase: String, CaseIterable {
    case quickScan = "quick_scan"
    case accurateExtraction = "accurate_extraction"
    case highQuality = "high_quality"
    case batch = "batch_processing"

    var displayName: String {
        switch self {
        case .quickScan:
            return "Quick Scan"
        case .accurateExtraction:
            return "Accurate Extraction"
        case .highQuality:
            return "High Quality"
        case .batch:
            return "Batch Processing"
        }
    }

    var description: String {
        switch self {
        case .quickScan:
            return "Fast processing with lower accuracy requirements"
        case .accurateExtraction:
            return "Balanced speed and accuracy for most use cases"
        case .highQuality:
            return "Highest accuracy with longer processing time"
        case .batch:
            return "Optimized for processing multiple images"
        }
    }
}

// MARK: - OCR Result Extensions

extension OCRExtractionResult {
    /// Get human-readable summary of the extraction
    var summary: String {
        let textCount = ocrResult.recognizedTexts.count
        let qualityScore = String(format: "%.1f", imageQualityScore * 100)
        let processingTime = String(format: "%.2f", processingMetrics.totalProcessingTime)

        return "Found \(textCount) text items with \(qualityScore)% quality in \(processingTime)s"
    }

    /// Check if result contains potential nutrition information
    var hasNutritionInfo: Bool {
        let fullText = ocrResult.fullText.lowercased()
        let nutritionKeywords = [
            "calories", "protein", "fat", "carb", "sodium",
            "fiber", "sugar", "vitamin", "serving", "nutrition"
        ]

        return nutritionKeywords.contains { keyword in
            fullText.contains(keyword)
        }
    }

    /// Extract potential calorie values from OCR text
    var extractedCalories: [String] {
        return ocrResult.recognizedTexts.compactMap { textItem in
            let text = textItem.text.lowercased()
            if text.contains("calorie") || text.contains("kcal") {
                return textItem.text
            }
            return nil
        }
    }

    /// Get confidence level description
    var confidenceDescription: String {
        let avgConfidence = processingMetrics.averageConfidence
        switch avgConfidence {
        case 0.9...:
            return "Excellent"
        case 0.8..<0.9:
            return "Good"
        case 0.6..<0.8:
            return "Fair"
        default:
            return "Poor"
        }
    }
}

// MARK: - SwiftUI Integration Helpers

struct OCRServiceStatusView: View {
    @ObservedObject var integrationManager: OCRIntegrationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: integrationManager.isProcessing ? "gearshape.2.fill" : "checkmark.circle.fill")
                    .foregroundColor(integrationManager.isProcessing ? .blue : .green)
                    .symbolEffect(.pulse, isActive: integrationManager.isProcessing)

                Text(integrationManager.isProcessing ? "Processing..." : "Ready")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if integrationManager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let error = integrationManager.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }

            if !integrationManager.processingHistory.isEmpty {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)

                    Text("Last: \(integrationManager.processingHistory.first?.summary ?? "None")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension OCRIntegrationManager {
    static func previewInstance() -> OCRIntegrationManager {
        let manager = OCRIntegrationManager(serviceConfig: .fast)

        // Add some mock history for preview
        let mockMetrics = OCRProcessingMetrics(
            imageValidationTime: 0.1,
            preprocessingTime: 0.2,
            ocrProcessingTime: 1.5,
            totalProcessingTime: 1.8,
            imageQualityChecks: [],
            textConfidenceDistribution: [0.9, 0.8, 0.85]
        )

        let mockOCRResult = OCRResult(
            textObservations: [],
            recognizedTexts: [
                ("CALORIES 250", 0.9, .zero),
                ("Protein 12g", 0.8, .zero)
            ],
            processingTime: 1.5
        )

        let mockResult = OCRExtractionResult(
            originalImage: UIImage(),
            processedImage: nil,
            ocrResult: mockOCRResult,
            imageQualityScore: 0.85,
            extractionTimestamp: Date(),
            processingMetrics: mockMetrics
        )

        manager.processingHistory = [mockResult]
        return manager
    }
}

struct OCRServiceStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            OCRServiceStatusView(integrationManager: OCRIntegrationManager.previewInstance())

            OCRServiceStatusView(integrationManager: {
                let manager = OCRIntegrationManager.previewInstance()
                manager.isProcessing = true
                return manager
            }())

            OCRServiceStatusView(integrationManager: {
                let manager = OCRIntegrationManager.previewInstance()
                manager.lastError = .imageQualityTooLow(0.45)
                return manager
            }())
        }
        .padding()
    }
}
#endif

// MARK: - Import for Combine

import Combine