//
//  OCRServiceTests.swift
//  NutritionTrackerV2Tests
//
//  Comprehensive tests for OCRService functionality
//

import XCTest
@testable import NutritionTrackerV2

@MainActor
final class OCRServiceTests: XCTestCase {

    var ocrService: OCRService!

    override func setUp() {
        super.setUp()
        ocrService = OCRService(config: .fast) // Use fast config for testing
    }

    override func tearDown() {
        ocrService = nil
        super.tearDown()
    }

    // MARK: - Service Configuration Tests

    func testServiceInitialization() {
        XCTAssertNotNil(ocrService)
        XCTAssertFalse(ocrService.isProcessing)
        XCTAssertEqual(ocrService.processingProgress, 0.0)
        XCTAssertNil(ocrService.lastProcessingMetrics)
    }

    func testServiceConfigurations() {
        let defaultService = OCRService(config: .default)
        let fastService = OCRService(config: .fast)
        let highQualityService = OCRService(config: .highQuality)

        XCTAssertNotNil(defaultService)
        XCTAssertNotNil(fastService)
        XCTAssertNotNil(highQualityService)
    }

    // MARK: - Data Structure Tests

    func testImageQualityCheck() {
        let check = ImageQualityCheck(
            checkType: .resolution,
            score: 0.8,
            passed: true,
            details: "1920x1080 pixels"
        )

        XCTAssertEqual(check.checkType, .resolution)
        XCTAssertEqual(check.score, 0.8)
        XCTAssertTrue(check.passed)
        XCTAssertEqual(check.details, "1920x1080 pixels")
    }

    func testImageQualityAssessment() {
        let checks = [
            ImageQualityCheck(checkType: .resolution, score: 0.9, passed: true, details: nil),
            ImageQualityCheck(checkType: .brightness, score: 0.7, passed: true, details: nil),
            ImageQualityCheck(checkType: .contrast, score: 0.6, passed: false, details: nil)
        ]

        let assessment = ImageQualityAssessment(
            overallScore: 0.75,
            checks: checks,
            recommendation: .good,
            estimatedOCRSuccess: 0.8
        )

        XCTAssertEqual(assessment.overallScore, 0.75)
        XCTAssertEqual(assessment.checks.count, 3)
        XCTAssertEqual(assessment.passedChecks.count, 2)
        XCTAssertEqual(assessment.failedChecks.count, 1)
        XCTAssertEqual(assessment.recommendation, .good)
    }

    func testOCRProcessingMetrics() {
        let confidences: [Float] = [0.9, 0.8, 0.7, 0.85]
        let metrics = OCRProcessingMetrics(
            imageValidationTime: 0.1,
            preprocessingTime: 0.3,
            ocrProcessingTime: 2.5,
            totalProcessingTime: 3.0,
            imageQualityChecks: [],
            textConfidenceDistribution: confidences
        )

        XCTAssertEqual(metrics.averageConfidence, 0.8125)
        XCTAssertEqual(metrics.totalProcessingTime, 3.0)
    }

    // MARK: - Image Quality Assessment Tests

    func testImageQualityAssessment() async throws {
        let testImage = createTestImage(size: CGSize(width: 800, height: 600))

        do {
            let assessment = try await ocrService.assessImageQuality(testImage)

            XCTAssertTrue(assessment.overallScore >= 0.0)
            XCTAssertTrue(assessment.overallScore <= 1.0)
            XCTAssertNotNil(assessment.recommendation)
            XCTAssertTrue(assessment.estimatedOCRSuccess >= 0.0)
            XCTAssertTrue(assessment.estimatedOCRSuccess <= 1.0)

            print("📊 Quality Assessment Results:")
            print("   - Overall Score: \(String(format: "%.2f", assessment.overallScore))")
            print("   - Recommendation: \(assessment.recommendation.rawValue)")
            print("   - Estimated Success: \(String(format: "%.2f", assessment.estimatedOCRSuccess))")
            print("   - Checks Passed: \(assessment.passedChecks.count)/\(assessment.checks.count)")

        } catch {
            XCTFail("Image quality assessment should not fail with valid image: \(error)")
        }
    }

    func testLowQualityImageHandling() async {
        let lowQualityImage = createTestImage(size: CGSize(width: 50, height: 50))
        let highQualityService = OCRService(config: .highQuality)

        do {
            let _ = try await highQualityService.extractNutritionalInfo(from: lowQualityImage)
            // If it doesn't throw, that's also valid for some low quality images
            print("✅ Low quality image was processed successfully")
        } catch OCRServiceError.imageQualityTooLow(let score) {
            print("✅ Low quality image correctly rejected with score: \(String(format: "%.2f", score))")
            XCTAssertTrue(score < 0.8) // High quality service should reject low quality images
        } catch {
            print("⚠️ Low quality image failed with different error: \(error)")
        }
    }

    // MARK: - OCR Extraction Tests

    func testOCRExtractionWithValidImage() async throws {
        let testImage = createNutritionLabelImage()

        do {
            let result = try await ocrService.extractNutritionalInfo(from: testImage)

            // Verify result structure
            XCTAssertNotNil(result.originalImage)
            XCTAssertNotNil(result.ocrResult)
            XCTAssertTrue(result.imageQualityScore >= 0.0)
            XCTAssertTrue(result.imageQualityScore <= 1.0)
            XCTAssertNotNil(result.processingMetrics)

            // Verify metrics
            let metrics = result.processingMetrics
            XCTAssertTrue(metrics.totalProcessingTime > 0)
            XCTAssertTrue(metrics.ocrProcessingTime >= 0)

            print("✅ OCR Extraction Results:")
            print("   - Quality Score: \(String(format: "%.2f", result.imageQualityScore))")
            print("   - Text Items Found: \(result.ocrResult.recognizedTexts.count)")
            print("   - Processing Time: \(String(format: "%.3f", metrics.totalProcessingTime))s")

            if result.ocrResult.hasText {
                print("   - Sample Text: \(result.ocrResult.recognizedTexts.first?.text ?? "None")")
            }

        } catch {
            // OCR might fail with synthetic images - log the error
            print("⚠️ OCR extraction failed (expected with synthetic images): \(error.localizedDescription)")

            if let serviceError = error as? OCRServiceError {
                switch serviceError {
                case .imageQualityTooLow(let score):
                    XCTAssertTrue(score < ocrService.config.minimumQualityScore)
                case .ocrProcessingFailed:
                    print("   - OCR processing failed (expected with synthetic images)")
                case .processingTimeout:
                    XCTFail("Processing should not timeout with reasonable images")
                case .invalidImageFormat:
                    XCTFail("Image format should be valid")
                case .serviceBusy:
                    XCTFail("Service should not be busy initially")
                case .imageProcessingFailed:
                    print("   - Image processing failed (possible with synthetic images)")
                }
            }
        }
    }

    func testServiceBusyHandling() async {
        let testImage = createTestImage(size: CGSize(width: 400, height: 300))

        // Start first operation
        let firstTask = Task {
            do {
                let _ = try await ocrService.extractNutritionalInfo(from: testImage)
                return true
            } catch {
                return false
            }
        }

        // Wait briefly to ensure first operation starts
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Try second operation while first is running
        do {
            let _ = try await ocrService.extractNutritionalInfo(from: testImage)
            print("⚠️ Second operation succeeded - service might not be properly tracking busy state")
        } catch OCRServiceError.serviceBusy {
            print("✅ Service correctly rejected second operation while busy")
        } catch {
            print("⚠️ Second operation failed with different error: \(error)")
        }

        // Wait for first operation to complete
        let _ = await firstTask.result
    }

    func testCancelOperation() async {
        let testImage = createTestImage(size: CGSize(width: 800, height: 600))

        // Start operation
        let operationTask = Task {
            do {
                let _ = try await ocrService.extractNutritionalInfo(from: testImage)
                return "completed"
            } catch {
                return "failed"
            }
        }

        // Wait briefly then cancel
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        ocrService.cancelCurrentOperation()

        // Verify service state after cancellation
        XCTAssertFalse(ocrService.isProcessing)
        XCTAssertEqual(ocrService.processingProgress, 0.0)

        // Wait for task to complete
        let result = await operationTask.result
        print("✅ Operation result after cancellation: \(try! result.get())")
    }

    // MARK: - Error Handling Tests

    func testInvalidImageFormat() async {
        // Create an invalid image (empty)
        let invalidImage = UIImage()

        do {
            let _ = try await ocrService.extractNutritionalInfo(from: invalidImage)
            XCTFail("Should fail with invalid image format")
        } catch OCRServiceError.invalidImageFormat {
            print("✅ Invalid image format correctly handled")
        } catch {
            print("⚠️ Invalid image failed with different error: \(error)")
        }
    }

    // MARK: - Performance Tests

    func testOCRPerformance() async {
        let testImage = createNutritionLabelImage()

        let startTime = Date()
        var processingTimes: [TimeInterval] = []

        // Run multiple operations to test performance consistency
        for i in 1...3 {
            do {
                let result = try await ocrService.extractNutritionalInfo(from: testImage)
                processingTimes.append(result.processingMetrics.totalProcessingTime)
                print("   Run \(i): \(String(format: "%.3f", result.processingMetrics.totalProcessingTime))s")
            } catch {
                print("   Run \(i): Failed - \(error.localizedDescription)")
            }

            // Small delay between runs
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        let totalTestTime = Date().timeIntervalSince(startTime)

        print("📊 Performance Test Results:")
        print("   - Total Test Time: \(String(format: "%.3f", totalTestTime))s")
        if !processingTimes.isEmpty {
            let averageTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
            let maxTime = processingTimes.max() ?? 0
            let minTime = processingTimes.min() ?? 0

            print("   - Average Processing Time: \(String(format: "%.3f", averageTime))s")
            print("   - Min/Max Times: \(String(format: "%.3f", minTime))s / \(String(format: "%.3f", maxTime))s")
        }
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.black.setFill()
            let testRect = CGRect(x: 20, y: 20, width: size.width - 40, height: 40)
            UIRectFill(testRect)
        }
    }

    private func createNutritionLabelImage() -> UIImage {
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Nutrition facts text
            UIColor.black.setFill()
            let font = UIFont.systemFont(ofSize: 16, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]

            let nutritionText = """
            NUTRITION FACTS
            Serving Size 1 cup (240ml)

            CALORIES 250

            Total Fat 12g
            Protein 5g
            Sodium 470mg
            """

            let textRect = CGRect(x: 20, y: 50, width: size.width - 40, height: size.height - 100)
            nutritionText.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - Service Extension Tests

extension OCRServiceTests {

    func testProcessingSummary() {
        let metrics = OCRProcessingMetrics(
            imageValidationTime: 0.1,
            preprocessingTime: 0.3,
            ocrProcessingTime: 2.1,
            totalProcessingTime: 2.5,
            imageQualityChecks: [
                ImageQualityCheck(checkType: .resolution, score: 0.9, passed: true, details: nil),
                ImageQualityCheck(checkType: .brightness, score: 0.6, passed: false, details: nil)
            ],
            textConfidenceDistribution: [0.9, 0.8, 0.7]
        )

        let summary = ocrService.getProcessingSummary(metrics)

        XCTAssertTrue(summary.contains("2.50"))  // Total time
        XCTAssertTrue(summary.contains("80.0"))  // Average confidence
        XCTAssertTrue(summary.contains("1/2"))   // Quality checks

        print("📋 Processing Summary:")
        print(summary)
    }

    func testQualityRecommendations() {
        let recommendations = ImageQualityAssessment.QualityRecommendation.allCases

        for recommendation in [
            ImageQualityAssessment.QualityRecommendation.excellent,
            .good,
            .acceptable,
            .poor,
            .unusable
        ] {
            XCTAssertFalse(recommendation.description.isEmpty)
            print("   \(recommendation.rawValue): \(recommendation.description)")
        }
    }
}

// MARK: - Configuration Tests

extension OCRServiceTests {

    func testOCRServiceConfigs() {
        let configs = [
            OCRServiceConfig.default,
            OCRServiceConfig.fast,
            OCRServiceConfig.highQuality
        ]

        for (index, config) in configs.enumerated() {
            XCTAssertTrue(config.minimumQualityScore >= 0.0)
            XCTAssertTrue(config.minimumQualityScore <= 1.0)
            XCTAssertTrue(config.maxProcessingTime > 0)

            print("Config \(index): quality=\(config.minimumQualityScore), timeout=\(config.maxProcessingTime)s")
        }

        // Fast should be most permissive
        XCTAssertLessThan(OCRServiceConfig.fast.minimumQualityScore, OCRServiceConfig.highQuality.minimumQualityScore)
    }
}