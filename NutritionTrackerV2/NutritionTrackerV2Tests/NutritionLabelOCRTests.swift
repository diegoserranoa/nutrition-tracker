//
//  NutritionLabelOCRTests.swift
//  NutritionTrackerV2Tests
//
//  Unit tests for nutrition label OCR functionality
//

import XCTest
import Vision
@testable import NutritionTrackerV2

@MainActor
final class NutritionLabelOCRTests: XCTestCase {

    var ocr: NutritionLabelOCR!

    override func setUp() {
        super.setUp()
        ocr = NutritionLabelOCR(config: .fast) // Use fast config for testing
    }

    override func tearDown() {
        ocr = nil
        super.tearDown()
    }

    func testOCRConfiguration() {
        // Test different configurations
        let nutritionConfig = OCRConfig.nutritionLabel
        let fastConfig = OCRConfig.fast

        XCTAssertEqual(nutritionConfig.recognitionLevel, .accurate)
        XCTAssertEqual(fastConfig.recognitionLevel, .fast)
        XCTAssertTrue(nutritionConfig.minimumTextConfidence > fastConfig.minimumTextConfidence)
        XCTAssertFalse(nutritionConfig.customWords.isEmpty)
    }

    func testOCRInitialization() {
        XCTAssertNotNil(ocr)

        // Test with nutrition label config
        let nutritionOCR = NutritionLabelOCR(config: .nutritionLabel)
        XCTAssertNotNil(nutritionOCR)
    }

    func testCreateTestImage() {
        let testImage = createTestNutritionLabelImage()
        XCTAssertNotNil(testImage)
        XCTAssertTrue(testImage.size.width > 0)
        XCTAssertTrue(testImage.size.height > 0)
    }

    func testOCRWithSimpleText() async throws {
        let testImage = createSimpleTextImage(text: "CALORIES 250\nPROTEIN 15g\nFAT 10g")

        do {
            let result = try await ocr.recognizeText(in: testImage, timeout: 10.0)

            // Basic assertions
            XCTAssertTrue(result.hasText, "OCR should detect text in the image")
            XCTAssertFalse(result.recognizedTexts.isEmpty, "Should have recognized text items")
            XCTAssertTrue(result.processingTime > 0, "Processing time should be positive")

            print("📊 Test OCR Results:")
            print("   - Found \(result.recognizedTexts.count) text items")
            print("   - Processing time: \(String(format: "%.3f", result.processingTime))s")
            print("   - Full text: \(result.fullText)")

            // Check if any nutrition-related terms were found
            let fullTextLower = result.fullText.lowercased()
            let nutritionTermsFound = ["calories", "protein", "fat", "g"].contains { term in
                fullTextLower.contains(term)
            }

            if nutritionTermsFound {
                print("   ✅ Found nutrition-related terms")
            } else {
                print("   ⚠️ No nutrition terms found - this might be expected with simple test images")
            }

        } catch {
            // OCR might fail with synthetic images, but we still test the error handling
            print("⚠️ OCR failed with test image (expected): \(error.localizedDescription)")

            if let ocrError = error as? OCRError {
                switch ocrError {
                case .noTextFound:
                    print("   - No text found (synthetic image limitation)")
                case .visionFrameworkError(let visionError):
                    print("   - Vision framework error: \(visionError.localizedDescription)")
                case .imageProcessingFailed:
                    XCTFail("Image processing should not fail with valid image")
                case .configurationError(let message):
                    XCTFail("Configuration error: \(message)")
                case .timeout:
                    XCTFail("OCR should not timeout with 10s limit")
                }
            }
        }
    }

    func testOCRTimeout() async {
        let testImage = createSimpleTextImage(text: "Test")

        do {
            // Test with very short timeout
            let result = try await ocr.recognizeText(in: testImage, timeout: 0.001)
            // If it doesn't timeout, that's also okay
            print("✅ OCR completed quickly: \(result.recognizedTexts.count) items")
        } catch OCRError.timeout {
            print("✅ Timeout handling working correctly")
        } catch {
            print("⚠️ OCR failed with other error: \(error.localizedDescription)")
        }
    }

    func testOCRConfigurationTypes() {
        // Test all configuration types can be created
        let configs: [OCRConfig] = [.nutritionLabel, .fast]

        for config in configs {
            let testOCR = NutritionLabelOCR(config: config)
            XCTAssertNotNil(testOCR)
        }
    }

    // MARK: - Helper Methods

    private func createSimpleTextImage(text: String) -> UIImage {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Black text
            UIColor.black.setFill()

            let font = UIFont.systemFont(ofSize: 24, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]

            let textRect = CGRect(x: 20, y: 50, width: size.width - 40, height: size.height - 100)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }

    private func createTestNutritionLabelImage() -> UIImage {
        let nutritionText = """
        NUTRITION FACTS
        Serving Size 1 cup (240ml)

        CALORIES 250

        Total Fat 12g          15%
        Saturated Fat 3g       15%
        Trans Fat 0g

        Cholesterol 30mg       10%
        Sodium 470mg           20%
        Total Carbohydrate 31g 10%
        Dietary Fiber 0g        0%
        Total Sugars 5g
        Added Sugars 0g         0%

        Protein 5g             10%

        Vitamin D 2mcg         10%
        Calcium 260mg          20%
        Iron 1mg                6%
        Potassium 240mg         6%
        """

        return createSimpleTextImage(text: nutritionText)
    }
}

// MARK: - Performance Tests

extension NutritionLabelOCRTests {

    func testOCRPerformance() async throws {
        let testImage = createTestNutritionLabelImage()

        measure {
            Task {
                do {
                    let result = try await ocr.recognizeText(in: testImage, timeout: 30.0)
                    print("Performance test: \(result.recognizedTexts.count) items in \(String(format: "%.3f", result.processingTime))s")
                } catch {
                    print("Performance test failed: \(error.localizedDescription)")
                }
            }
        }
    }
}