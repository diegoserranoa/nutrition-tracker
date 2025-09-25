//
//  NutritionTextParserTests.swift
//  NutritionTrackerV2Tests
//
//  Comprehensive tests for nutrition text parsing functionality
//

import XCTest
@testable import NutritionTrackerV2

final class NutritionTextParserTests: XCTestCase {

    var parser: NutritionTextParser!

    override func setUp() {
        super.setUp()
        parser = NutritionTextParser(config: .default)
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Parser Configuration Tests

    func testParserInitialization() {
        XCTAssertNotNil(parser)

        let strictParser = NutritionTextParser(config: .strict)
        XCTAssertNotNil(strictParser)
    }

    func testParserConfigurations() {
        let defaultConfig = NutritionParserConfig.default
        let strictConfig = NutritionParserConfig.strict

        XCTAssertTrue(defaultConfig.enableFuzzyMatching)
        XCTAssertFalse(strictConfig.enableFuzzyMatching)
        XCTAssertLessThan(defaultConfig.minimumMatchConfidence, strictConfig.minimumMatchConfidence)
    }

    // MARK: - Basic Nutrition Facts Parsing Tests

    func testBasicNutritionFactsParsing() {
        let nutritionText = """
        NUTRITION FACTS
        Serving Size 1 cup (240ml)
        Servings Per Container 2

        Calories 250

        Total Fat 12g
        Saturated Fat 3g
        Trans Fat 0g
        Cholesterol 30mg
        Sodium 470mg
        Total Carbohydrate 31g
        Dietary Fiber 0g
        Total Sugars 5g
        Protein 5g

        Vitamin A 10%
        Vitamin C 2%
        Calcium 260mg
        Iron 1mg
        """

        let mockOCRResult = createMockOCRResult(from: nutritionText)
        let parsedData = parser.parseNutritionData(from: mockOCRResult)

        // Test basic parsing success
        XCTAssertTrue(parsedData.hasBasicNutrition, "Should find basic nutrition information")

        // Test serving info
        XCTAssertNotNil(parsedData.servingInfo, "Should parse serving information")
        if let servingInfo = parsedData.servingInfo {
            XCTAssertEqual(servingInfo.size, 1.0)
            XCTAssertEqual(servingInfo.unit, "cup")
            XCTAssertEqual(servingInfo.servingsPerContainer, 2.0)
        }

        // Test calories
        XCTAssertNotNil(parsedData.calories, "Should parse calories")
        if let calories = parsedData.calories {
            XCTAssertEqual(calories.value, 250.0)
            XCTAssertEqual(calories.unit, "kcal")
        }

        // Test macronutrients
        let macros = parsedData.macronutrients
        XCTAssertNotNil(macros.fat, "Should parse total fat")
        XCTAssertNotNil(macros.protein, "Should parse protein")
        XCTAssertNotNil(macros.carbohydrates, "Should parse carbohydrates")
        XCTAssertNotNil(macros.saturatedFat, "Should parse saturated fat")

        if let fat = macros.fat {
            XCTAssertEqual(fat.value, 12.0)
            XCTAssertEqual(fat.unit, "g")
        }

        if let protein = macros.protein {
            XCTAssertEqual(protein.value, 5.0)
            XCTAssertEqual(protein.unit, "g")
        }

        // Test micronutrients
        let micros = parsedData.micronutrients
        XCTAssertNotNil(micros.sodium, "Should parse sodium")
        XCTAssertNotNil(micros.cholesterol, "Should parse cholesterol")
        XCTAssertNotNil(micros.calcium, "Should parse calcium")
        XCTAssertNotNil(micros.iron, "Should parse iron")

        // Test confidence
        XCTAssertGreaterThan(parsedData.confidence.overallScore, 0.6, "Should have reasonable confidence")

        print("✅ Basic Parsing Results:")
        print("   - \(parsedData.summary)")
        print("   - Overall Confidence: \(String(format: "%.2f", parsedData.confidence.overallScore))")
        print("   - Raw Matches: \(parsedData.rawMatches.count)")
    }

    // MARK: - Individual Nutrient Tests

    func testCaloriesParsing() {
        let testCases = [
            ("Calories 250", 250.0),
            ("250 calories", 250.0),
            ("Energy 300 kcal", 300.0),
            ("Calories: 180", 180.0),
            ("150 cal", 150.0)
        ]

        for (text, expectedValue) in testCases {
            let ocrResult = createMockOCRResult(from: text)
            let parsedData = parser.parseNutritionData(from: ocrResult)

            if let calories = parsedData.calories {
                XCTAssertEqual(calories.value, expectedValue, "Should parse calories from: \(text)")
                print("   ✅ Parsed '\(text)' → \(calories.value) \(calories.unit)")
            } else {
                XCTFail("Should parse calories from: \(text)")
            }
        }
    }

    func testProteinParsing() {
        let testCases = [
            ("Protein 12g", 12.0),
            ("12g protein", 12.0),
            ("Protein: 8.5g", 8.5),
            ("Prot 15g", 15.0)
        ]

        for (text, expectedValue) in testCases {
            let ocrResult = createMockOCRResult(from: text)
            let parsedData = parser.parseNutritionData(from: ocrResult)

            if let protein = parsedData.macronutrients.protein {
                XCTAssertEqual(protein.value, expectedValue, accuracy: 0.1, "Should parse protein from: \(text)")
                print("   ✅ Parsed '\(text)' → \(protein.value) \(protein.unit)")
            } else {
                XCTFail("Should parse protein from: \(text)")
            }
        }
    }

    func testFatParsing() {
        let testCases = [
            ("Total Fat 8g", 8.0),
            ("Fat 12.5g", 12.5),
            ("Total Fat: 6g", 6.0),
            ("Saturated Fat 3g", 3.0),
            ("Trans Fat 0g", 0.0)
        ]

        for (text, expectedValue) in testCases {
            let ocrResult = createMockOCRResult(from: text)
            let parsedData = parser.parseNutritionData(from: ocrResult)

            let macros = parsedData.macronutrients
            let fatValue = macros.fat?.value ?? macros.saturatedFat?.value ?? macros.transFat?.value

            if let value = fatValue {
                XCTAssertEqual(value, expectedValue, accuracy: 0.1, "Should parse fat from: \(text)")
                print("   ✅ Parsed '\(text)' → \(value)g")
            } else {
                XCTFail("Should parse fat from: \(text)")
            }
        }
    }

    func testCarbohydratesParsing() {
        let testCases = [
            ("Total Carbohydrate 31g", 31.0),
            ("Carbs 25g", 25.0),
            ("Carbohydrates: 18g", 18.0),
            ("Total Carbs 22g", 22.0)
        ]

        for (text, expectedValue) in testCases {
            let ocrResult = createMockOCRResult(from: text)
            let parsedData = parser.parseNutritionData(from: ocrResult)

            if let carbs = parsedData.macronutrients.carbohydrates {
                XCTAssertEqual(carbs.value, expectedValue, accuracy: 0.1, "Should parse carbs from: \(text)")
                print("   ✅ Parsed '\(text)' → \(carbs.value) \(carbs.unit)")
            } else {
                XCTFail("Should parse carbohydrates from: \(text)")
            }
        }
    }

    func testSodiumParsing() {
        let testCases = [
            ("Sodium 470mg", 470.0),
            ("470mg sodium", 470.0),
            ("Sodium: 320mg", 320.0),
            ("Sodium 1g", 1.0) // Should handle grams too
        ]

        for (text, expectedValue) in testCases {
            let ocrResult = createMockOCRResult(from: text)
            let parsedData = parser.parseNutritionData(from: ocrResult)

            if let sodium = parsedData.micronutrients.sodium {
                XCTAssertEqual(sodium.value, expectedValue, accuracy: 0.1, "Should parse sodium from: \(text)")
                print("   ✅ Parsed '\(text)' → \(sodium.value) \(sodium.unit)")
            } else {
                XCTFail("Should parse sodium from: \(text)")
            }
        }
    }

    // MARK: - Serving Size Tests

    func testServingSizeParsing() {
        let testCases = [
            ("Serving Size 1 cup", 1.0, "cup"),
            ("Serving Size 2.5 oz", 2.5, "oz"),
            ("Serving Size: 240ml", 240.0, "ml"),
            ("1 serving per container", 1.0, "serving")
        ]

        for (text, expectedSize, expectedUnit) in testCases {
            let ocrResult = createMockOCRResult(from: text)
            let parsedData = parser.parseNutritionData(from: ocrResult)

            if let servingInfo = parsedData.servingInfo {
                XCTAssertEqual(servingInfo.size, expectedSize, accuracy: 0.1, "Should parse serving size from: \(text)")
                XCTAssertTrue(servingInfo.unit.lowercased().contains(expectedUnit.lowercased()), "Should parse unit from: \(text)")
                print("   ✅ Parsed '\(text)' → \(servingInfo.size) \(servingInfo.unit)")
            } else {
                XCTFail("Should parse serving size from: \(text)")
            }
        }
    }

    // MARK: - Complex Nutrition Label Tests

    func testComplexNutritionLabel() {
        let complexLabel = """
        Nutrition Facts
        8 servings per container
        Serving size 2/3 cup (55g)

        Amount per serving
        Calories 230
                        % Daily Value*
        Total Fat 8g                     10%
          Saturated Fat 1g               5%
          Trans Fat 0g
        Cholesterol 0mg                  0%
        Sodium 160mg                     7%
        Total Carbohydrate 37g          13%
          Dietary Fiber 4g              14%
          Total Sugars 12g
            Includes 10g Added Sugars   20%
        Protein 3g

        Vitamin D 2mcg                  10%
        Calcium 260mg                   20%
        Iron 8mg                        45%
        Potassium 235mg                  5%
        """

        let ocrResult = createMockOCRResult(from: complexLabel)
        let parsedData = parser.parseNutritionData(from: ocrResult)

        // Test comprehensive parsing
        XCTAssertTrue(parsedData.hasBasicNutrition)
        XCTAssertNotNil(parsedData.servingInfo)
        XCTAssertNotNil(parsedData.calories)

        // Test specific values
        XCTAssertEqual(parsedData.calories?.value, 230.0)
        XCTAssertEqual(parsedData.macronutrients.fat?.value, 8.0)
        XCTAssertEqual(parsedData.macronutrients.protein?.value, 3.0)
        XCTAssertEqual(parsedData.micronutrients.sodium?.value, 160.0)

        // Test confidence for complex label
        XCTAssertGreaterThan(parsedData.confidence.overallScore, 0.7, "Should have high confidence for well-formatted label")

        print("✅ Complex Label Results:")
        print("   - \(parsedData.summary)")
        print("   - Confidence: \(String(format: "%.2f", parsedData.confidence.overallScore))")
        print("   - Matches found: \(parsedData.rawMatches.count)")
    }

    // MARK: - Edge Cases and Error Handling

    func testEmptyText() {
        let emptyOCRResult = createMockOCRResult(from: "")
        let parsedData = parser.parseNutritionData(from: emptyOCRResult)

        XCTAssertFalse(parsedData.hasBasicNutrition)
        XCTAssertNil(parsedData.calories)
        XCTAssertTrue(parsedData.macronutrients.isEmpty)
        XCTAssertEqual(parsedData.confidence.overallScore, 0.0)
    }

    func testNonNutritionText() {
        let nonNutritionText = "This is a recipe for chocolate chip cookies. Mix flour, sugar, and butter."
        let ocrResult = createMockOCRResult(from: nonNutritionText)
        let parsedData = parser.parseNutritionData(from: ocrResult)

        XCTAssertFalse(parsedData.hasBasicNutrition)
        XCTAssertLessThan(parsedData.confidence.overallScore, 0.3)
    }

    func testPartialNutritionInfo() {
        let partialInfo = "Calories 180\nSome other text here"
        let ocrResult = createMockOCRResult(from: partialInfo)
        let parsedData = parser.parseNutritionData(from: ocrResult)

        XCTAssertTrue(parsedData.hasBasicNutrition) // Has calories
        XCTAssertNotNil(parsedData.calories)
        XCTAssertTrue(parsedData.macronutrients.isEmpty) // But no macronutrients
    }

    // MARK: - Confidence Scoring Tests

    func testConfidenceScoring() {
        // High confidence case
        let highQualityLabel = """
        NUTRITION FACTS
        Serving Size 1 cup
        Calories 250
        Protein 12g
        Fat 8g
        """

        let highQualityResult = parser.parseNutritionData(from: createMockOCRResult(from: highQualityLabel))
        XCTAssertGreaterThan(highQualityResult.confidence.overallScore, 0.7)

        // Low confidence case
        let lowQualityText = "maybe 200 calories somewhere protein could be 5"
        let lowQualityResult = parser.parseNutritionData(from: createMockOCRResult(from: lowQualityText))
        XCTAssertLessThan(lowQualityResult.confidence.overallScore, 0.5)
    }

    // MARK: - Performance Tests

    func testParsingPerformance() {
        let nutritionLabel = """
        NUTRITION FACTS
        Serving Size 1 cup (240ml)
        Servings Per Container 2
        Calories 250
        Total Fat 12g
        Saturated Fat 3g
        Cholesterol 30mg
        Sodium 470mg
        Total Carbohydrate 31g
        Dietary Fiber 0g
        Total Sugars 5g
        Protein 5g
        Vitamin A 10%
        Vitamin C 2%
        Calcium 260mg
        Iron 1mg
        """

        measure {
            for _ in 1...10 {
                let ocrResult = createMockOCRResult(from: nutritionLabel)
                let _ = parser.parseNutritionData(from: ocrResult)
            }
        }
    }

    // MARK: - Data Structure Tests

    func testNutrientValueDisplayMethods() {
        let nutrientValue = NutrientValue(
            value: 12.5,
            unit: "g",
            originalText: "Protein 12.5g",
            confidence: 0.9,
            isEstimated: false
        )

        XCTAssertEqual(nutrientValue.displayValue, "12.5")
        XCTAssertEqual(nutrientValue.displayText, "12.5g")
    }

    func testServingInfoDisplayMethods() {
        let servingInfo = ServingInfo(
            size: 1.0,
            unit: "cup",
            description: "240ml",
            servingsPerContainer: 2.0,
            confidence: 0.85
        )

        XCTAssertEqual(servingInfo.displayText, "cup (240ml)")

        let simpleServing = ServingInfo(
            size: 2.0,
            unit: "pieces",
            description: nil,
            servingsPerContainer: nil,
            confidence: 0.9
        )

        XCTAssertEqual(simpleServing.displayText, "2 pieces")
    }

    func testParsedDataSummary() {
        let ocrResult = createMockOCRResult(from: "Calories 250\nProtein 12g\nFat 8g")
        let parsedData = parser.parseNutritionData(from: ocrResult)

        let summary = parsedData.summary
        XCTAssertTrue(summary.contains("calories"))
        XCTAssertTrue(summary.contains("protein"))
        XCTAssertTrue(summary.contains("fat"))
    }

    // MARK: - Helper Methods

    private func createMockOCRResult(from text: String) -> OCRResult {
        let lines = text.components(separatedBy: .newlines)
        let recognizedTexts = lines.enumerated().map { (index, line) -> (text: String, confidence: Float, boundingBox: CGRect) in
            let y = CGFloat(index) * 0.1
            return (
                text: line,
                confidence: 0.9,
                boundingBox: CGRect(x: 0, y: y, width: 1.0, height: 0.08)
            )
        }

        return OCRResult(
            textObservations: [], // Not needed for parsing tests
            recognizedTexts: recognizedTexts,
            processingTime: 0.1
        )
    }
}

// MARK: - Parser Config Tests

extension NutritionTextParserTests {

    func testParserConfigOptions() {
        let configs = [
            NutritionParserConfig.default,
            NutritionParserConfig.strict
        ]

        for config in configs {
            XCTAssertTrue(config.minimumMatchConfidence >= 0.0)
            XCTAssertTrue(config.minimumMatchConfidence <= 1.0)
            XCTAssertTrue(config.maxUnitDistance > 0)

            let parser = NutritionTextParser(config: config)
            XCTAssertNotNil(parser)
        }
    }

    func testNutrientTypeDisplayNames() {
        for nutrientType in NutritionMatch.NutrientType.allCases {
            XCTAssertFalse(nutrientType.displayName.isEmpty, "\(nutrientType.rawValue) should have display name")
        }
    }
}

// MARK: - Integration Tests

extension NutritionTextParserTests {

    func testRealWorldNutritionLabels() {
        let realWorldExamples = [
            // Cereal box
            """
            Nutrition Facts
            Servings Per Container About 11
            Serving size 3/4 cup (30g)
            Calories 110
            Total Fat 1g
            Sodium 160mg
            Total Carbohydrate 23g
            Dietary Fiber 3g
            Total Sugars 9g
            Protein 3g
            """,

            // Yogurt container
            """
            NUTRITION FACTS
            Serving Size: 1 container (170g)
            Calories 100
            Fat 0g
            Sodium 75mg
            Carbohydrate 16g
            Sugars 14g
            Protein 17g
            """,

            // Snack bar
            """
            Nutrition Facts
            1 bar (40g)
            Calories 140
            Total Fat 5g
            Saturated Fat 2g
            Sodium 85mg
            Total Carbs 22g
            Fiber 3g
            Sugars 12g
            Protein 3g
            """
        ]

        for (index, example) in realWorldExamples.enumerated() {
            let ocrResult = createMockOCRResult(from: example)
            let parsedData = parser.parseNutritionData(from: ocrResult)

            XCTAssertTrue(parsedData.hasBasicNutrition, "Example \(index + 1) should parse basic nutrition")
            XCTAssertGreaterThan(parsedData.confidence.overallScore, 0.5, "Example \(index + 1) should have reasonable confidence")

            print("📊 Real-world Example \(index + 1):")
            print("   - \(parsedData.summary)")
            print("   - Confidence: \(String(format: "%.2f", parsedData.confidence.overallScore))")
        }
    }
}