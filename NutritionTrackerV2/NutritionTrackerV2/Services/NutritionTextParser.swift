//
//  NutritionTextParser.swift
//  NutritionTrackerV2
//
//  Intelligent text parsing system for extracting nutrition data from OCR results
//

import Foundation
import RegexBuilder

// MARK: - Data Structures

/// Parsed nutrition information from OCR text
struct ParsedNutritionData: Equatable {
    let servingInfo: ServingInfo?
    let calories: NutrientValue?
    let macronutrients: MacronutrientValues
    let micronutrients: MicronutrientValues
    let otherNutrients: [String: NutrientValue]
    let confidence: ParsedDataConfidence
    let rawMatches: [NutritionMatch]
    let parseTimestamp: Date

    /// Check if basic nutrition info was found
    var hasBasicNutrition: Bool {
        return calories != nil || !macronutrients.isEmpty
    }

    /// Get summary of parsed data
    var summary: String {
        var items: [String] = []
        if calories != nil { items.append("calories") }
        if macronutrients.protein != nil { items.append("protein") }
        if macronutrients.carbohydrates != nil { items.append("carbs") }
        if macronutrients.fat != nil { items.append("fat") }
        if macronutrients.fiber != nil { items.append("fiber") }
        if macronutrients.sugar != nil { items.append("sugar") }
        if macronutrients.saturatedFat != nil { items.append("saturated fat") }
        if macronutrients.transFat != nil { items.append("trans fat") }
        if micronutrients.sodium != nil { items.append("sodium") }
        if micronutrients.cholesterol != nil { items.append("cholesterol") }
        if micronutrients.potassium != nil { items.append("potassium") }
        if micronutrients.calcium != nil { items.append("calcium") }
        if micronutrients.iron != nil { items.append("iron") }
        if micronutrients.vitaminA != nil { items.append("vitamin A") }
        if micronutrients.vitaminC != nil { items.append("vitamin C") }
        if micronutrients.vitaminD != nil { items.append("vitamin D") }
        if servingInfo != nil { items.append("serving") }

        return items.isEmpty ? "No nutrition data found" : "Found: \(items.joined(separator: ", "))"
    }
}

/// Serving size information
struct ServingInfo: Equatable {
    let size: Double
    let unit: String
    let description: String?
    let servingsPerContainer: Double?
    let confidence: Double

    var displayText: String {
        let sizeText = size == 1.0 ? unit : "\(size.formatted()) \(unit)"
        if let desc = description, !desc.isEmpty {
            return "\(sizeText) (\(desc))"
        }
        return sizeText
    }
}

/// Individual nutrient value with metadata
struct NutrientValue: Equatable {
    let value: Double
    let unit: String
    let originalText: String
    let confidence: Double
    let isEstimated: Bool

    var displayValue: String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = value < 10 ? 1 : 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var displayText: String {
        return "\(displayValue)\(unit)"
    }
}

/// Macronutrient values
struct MacronutrientValues: Equatable {
    let protein: NutrientValue?
    let carbohydrates: NutrientValue?
    let fat: NutrientValue?
    let fiber: NutrientValue?
    let sugar: NutrientValue?
    let saturatedFat: NutrientValue?
    let transFat: NutrientValue?

    var isEmpty: Bool {
        return protein == nil && carbohydrates == nil && fat == nil
    }

    var allValues: [String: NutrientValue] {
        var values: [String: NutrientValue] = [:]
        if let protein = protein { values["protein"] = protein }
        if let carbs = carbohydrates { values["carbohydrates"] = carbs }
        if let fat = fat { values["fat"] = fat }
        if let fiber = fiber { values["fiber"] = fiber }
        if let sugar = sugar { values["sugar"] = sugar }
        if let saturatedFat = saturatedFat { values["saturated_fat"] = saturatedFat }
        if let transFat = transFat { values["trans_fat"] = transFat }
        return values
    }
}

/// Micronutrient values
struct MicronutrientValues: Equatable {
    let sodium: NutrientValue?
    let cholesterol: NutrientValue?
    let potassium: NutrientValue?
    let calcium: NutrientValue?
    let iron: NutrientValue?
    let vitaminA: NutrientValue?
    let vitaminC: NutrientValue?
    let vitaminD: NutrientValue?

    var isEmpty: Bool {
        return sodium == nil && cholesterol == nil && potassium == nil &&
               calcium == nil && iron == nil && vitaminA == nil &&
               vitaminC == nil && vitaminD == nil
    }

    var allValues: [String: NutrientValue] {
        var values: [String: NutrientValue] = [:]
        if let sodium = sodium { values["sodium"] = sodium }
        if let cholesterol = cholesterol { values["cholesterol"] = cholesterol }
        if let potassium = potassium { values["potassium"] = potassium }
        if let calcium = calcium { values["calcium"] = calcium }
        if let iron = iron { values["iron"] = iron }
        if let vitaminA = vitaminA { values["vitamin_a"] = vitaminA }
        if let vitaminC = vitaminC { values["vitamin_c"] = vitaminC }
        if let vitaminD = vitaminD { values["vitamin_d"] = vitaminD }
        return values
    }
}

/// Confidence scoring for parsed data
struct ParsedDataConfidence: Equatable {
    let overallScore: Double
    let servingInfoScore: Double
    let caloriesScore: Double
    let macronutrientsScore: Double
    let micronutrientsScore: Double
    let formatRecognitionScore: Double

    static let none = ParsedDataConfidence(
        overallScore: 0.0,
        servingInfoScore: 0.0,
        caloriesScore: 0.0,
        macronutrientsScore: 0.0,
        micronutrientsScore: 0.0,
        formatRecognitionScore: 0.0
    )
}

/// Individual nutrition match from parsing
struct NutritionMatch: Equatable {
    let nutrientType: NutrientType
    let value: Double
    let unit: String
    let originalText: String
    let range: Range<String.Index>
    let confidence: Double

    enum NutrientType: String, CaseIterable {
        // Macronutrients
        case calories = "calories"
        case protein = "protein"
        case carbohydrates = "carbohydrates"
        case fat = "fat"
        case fiber = "fiber"
        case sugar = "sugar"
        case saturatedFat = "saturated_fat"
        case transFat = "trans_fat"

        // Micronutrients
        case sodium = "sodium"
        case cholesterol = "cholesterol"
        case potassium = "potassium"
        case calcium = "calcium"
        case iron = "iron"
        case vitaminA = "vitamin_a"
        case vitaminC = "vitamin_c"
        case vitaminD = "vitamin_d"

        // Serving info
        case servingSize = "serving_size"
        case servingsPerContainer = "servings_per_container"

        var displayName: String {
            switch self {
            case .calories: return "Calories"
            case .protein: return "Protein"
            case .carbohydrates: return "Carbohydrates"
            case .fat: return "Total Fat"
            case .fiber: return "Dietary Fiber"
            case .sugar: return "Total Sugars"
            case .saturatedFat: return "Saturated Fat"
            case .transFat: return "Trans Fat"
            case .sodium: return "Sodium"
            case .cholesterol: return "Cholesterol"
            case .potassium: return "Potassium"
            case .calcium: return "Calcium"
            case .iron: return "Iron"
            case .vitaminA: return "Vitamin A"
            case .vitaminC: return "Vitamin C"
            case .vitaminD: return "Vitamin D"
            case .servingSize: return "Serving Size"
            case .servingsPerContainer: return "Servings Per Container"
            }
        }
    }
}

// MARK: - Parser Configuration

struct NutritionParserConfig {
    /// Minimum confidence required for a match
    let minimumMatchConfidence: Double
    /// Enable fuzzy matching for common misspellings
    let enableFuzzyMatching: Bool
    /// Include percentage daily values in parsing
    let includePercentageValues: Bool
    /// Maximum distance for unit from value
    let maxUnitDistance: Int
    /// Enable contextual parsing (using surrounding text)
    let enableContextualParsing: Bool

    static let `default` = NutritionParserConfig(
        minimumMatchConfidence: 0.6,
        enableFuzzyMatching: true,
        includePercentageValues: true,
        maxUnitDistance: 3,
        enableContextualParsing: true
    )

    static let strict = NutritionParserConfig(
        minimumMatchConfidence: 0.8,
        enableFuzzyMatching: false,
        includePercentageValues: false,
        maxUnitDistance: 2,
        enableContextualParsing: false
    )
}

// MARK: - Nutrition Text Parser

class NutritionTextParser {

    // MARK: - Private Properties

    private let config: NutritionParserConfig
    private let unitConverter: NutritionUnitConverter

    // MARK: - Initialization

    init(config: NutritionParserConfig = .default) {
        self.config = config
        self.unitConverter = NutritionUnitConverter()
    }

    // MARK: - Public Methods

    /// Parse nutrition data from OCR text results
    func parseNutritionData(from ocrResult: OCRResult) -> ParsedNutritionData {
        let startTime = Date()

        // Combine all OCR text into a single string with position information
        let combinedText = combineOCRText(ocrResult.recognizedTexts)

        // Find all nutrition matches
        let matches = findNutritionMatches(in: combinedText)

        // Parse serving information
        let servingInfo = parseServingInfo(from: matches, text: combinedText)

        // Parse macronutrients
        let macronutrients = parseMacronutrients(from: matches)

        // Parse micronutrients
        let micronutrients = parseMicronutrients(from: matches)

        // Extract calories
        let calories = parseCalories(from: matches)

        // Parse other nutrients
        let otherNutrients = parseOtherNutrients(from: matches)

        // Calculate confidence scores
        let confidence = calculateConfidence(
            servingInfo: servingInfo,
            calories: calories,
            macronutrients: macronutrients,
            micronutrients: micronutrients,
            matches: matches,
            originalText: combinedText
        )

        let result = ParsedNutritionData(
            servingInfo: servingInfo,
            calories: calories,
            macronutrients: macronutrients,
            micronutrients: micronutrients,
            otherNutrients: otherNutrients,
            confidence: confidence,
            rawMatches: matches,
            parseTimestamp: startTime
        )

        let parseTime = Date().timeIntervalSince(startTime)
        print("🧠 Nutrition parsing completed in \(String(format: "%.3f", parseTime))s: \(result.summary)")

        return result
    }

    // MARK: - Private Parsing Methods

    private func combineOCRText(_ recognizedTexts: [(text: String, confidence: Float, boundingBox: CGRect)]) -> String {
        // Sort by reading order (top to bottom, left to right)
        let sortedTexts = recognizedTexts.sorted { first, second in
            let firstY = 1.0 - first.boundingBox.midY
            let secondY = 1.0 - second.boundingBox.midY

            if abs(firstY - secondY) > 0.05 {
                return firstY < secondY
            }
            return first.boundingBox.midX < second.boundingBox.midX
        }

        return sortedTexts.map { $0.text }.joined(separator: "\n")
    }

    private func findNutritionMatches(in text: String) -> [NutritionMatch] {
        var matches: [NutritionMatch] = []

        for nutrientType in NutritionMatch.NutrientType.allCases {
            let nutrientMatches = findMatches(for: nutrientType, in: text)
            matches.append(contentsOf: nutrientMatches)
        }

        // Sort by position and confidence
        return matches.sorted { first, second in
            if first.range.lowerBound != second.range.lowerBound {
                return first.range.lowerBound < second.range.lowerBound
            }
            return first.confidence > second.confidence
        }
    }

    private func findMatches(for nutrientType: NutritionMatch.NutrientType, in text: String) -> [NutritionMatch] {
        var matches: [NutritionMatch] = []

        let patterns = getPatterns(for: nutrientType)

        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                let regexMatches = regex.matches(in: text, options: [], range: range)

                for regexMatch in regexMatches {
                    if let match = processRegexMatch(regexMatch, in: text, for: nutrientType) {
                        matches.append(match)
                    }
                }
            } catch {
                print("⚠️ Regex error for \(nutrientType.rawValue): \(error)")
            }
        }

        return matches
    }

    private func getPatterns(for nutrientType: NutritionMatch.NutrientType) -> [String] {
        switch nutrientType {
        case .calories:
            return [
                #"(?:calories?|kcal|cal)\s*:?\s*(\d+(?:\.\d+)?)"#,
                #"(\d+(?:\.\d+)?)\s*(?:calories?|kcal|cal)"#,
                #"energy\s*:?\s*(\d+(?:\.\d+)?)\s*(?:kcal|cal)"#
            ]
        case .protein:
            return [
                #"(?:protein|prot)\s*:?\s*(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\s*protein"#
            ]
        case .carbohydrates:
            return [
                #"(?:total\s+)?(?:carbohydrat\w*|carbs?)\s*:?\s*(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\s*(?:carbohydrat\w*|carbs?)"#
            ]
        case .fat:
            return [
                #"(?:total\s+)?fat\s*:?\s*(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\s*(?:total\s+)?fat"#
            ]
        case .fiber:
            return [
                #"(?:dietary\s+)?fiber?\s*:?\s*(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\s*(?:dietary\s+)?fiber?"#
            ]
        case .sugar:
            return [
                #"(?:total\s+)?sugars?\s*:?\s*(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\s*(?:total\s+)?sugars?"#
            ]
        case .saturatedFat:
            return [
                #"saturated\s+fat\s*:?\s*(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\s*saturated\s+fat"#
            ]
        case .transFat:
            return [
                #"trans\s+fat\s*:?\s*(\d+(?:\.\d+)?)\s*g"#,
                #"(\d+(?:\.\d+)?)\s*g\s*trans\s+fat"#
            ]
        case .sodium:
            return [
                #"sodium\s*:?\s*(\d+(?:\.\d+)?)\s*(?:mg|g)"#,
                #"(\d+(?:\.\d+)?)\s*(?:mg|g)\s*sodium"#
            ]
        case .cholesterol:
            return [
                #"cholesterol\s*:?\s*(\d+(?:\.\d+)?)\s*mg"#,
                #"(\d+(?:\.\d+)?)\s*mg\s*cholesterol"#
            ]
        case .potassium:
            return [
                #"potassium\s*:?\s*(\d+(?:\.\d+)?)\s*mg"#,
                #"(\d+(?:\.\d+)?)\s*mg\s*potassium"#
            ]
        case .calcium:
            return [
                #"calcium\s*:?\s*(\d+(?:\.\d+)?)\s*mg"#,
                #"(\d+(?:\.\d+)?)\s*mg\s*calcium"#
            ]
        case .iron:
            return [
                #"iron\s*:?\s*(\d+(?:\.\d+)?)\s*mg"#,
                #"(\d+(?:\.\d+)?)\s*mg\s*iron"#
            ]
        case .vitaminA:
            return [
                #"vitamin\s*a\s*:?\s*(\d+(?:\.\d+)?)\s*(?:mcg|µg|iu)"#,
                #"(\d+(?:\.\d+)?)\s*(?:mcg|µg|iu)\s*vitamin\s*a"#
            ]
        case .vitaminC:
            return [
                #"vitamin\s*c\s*:?\s*(\d+(?:\.\d+)?)\s*mg"#,
                #"(\d+(?:\.\d+)?)\s*mg\s*vitamin\s*c"#
            ]
        case .vitaminD:
            return [
                #"vitamin\s*d\s*:?\s*(\d+(?:\.\d+)?)\s*(?:mcg|µg|iu)"#,
                #"(\d+(?:\.\d+)?)\s*(?:mcg|µg|iu)\s*vitamin\s*d"#
            ]
        case .servingSize:
            return [
                #"serving\s+size\s*:?\s*(\d+(?:\.\d+)?)\s*(\w+)"#,
                #"(\d+(?:\.\d+)?)\s*(\w+)\s*per\s+serving"#
            ]
        case .servingsPerContainer:
            return [
                #"servings?\s+per\s+container\s*:?\s*(\d+(?:\.\d+)?)"#,
                #"about\s+(\d+(?:\.\d+)?)\s+servings?"#
            ]
        }
    }

    private func processRegexMatch(_ regexMatch: NSTextCheckingResult, in text: String, for nutrientType: NutritionMatch.NutrientType) -> NutritionMatch? {
        guard regexMatch.numberOfRanges >= 2 else { return nil }

        let fullRange = regexMatch.range(at: 0)
        let valueRange = regexMatch.range(at: 1)

        guard let fullSwiftRange = Range(fullRange, in: text),
              let valueSwiftRange = Range(valueRange, in: text) else { return nil }

        let originalText = String(text[fullSwiftRange])
        let valueText = String(text[valueSwiftRange])

        guard let value = Double(valueText) else { return nil }

        // Determine unit
        let unit = extractUnit(from: originalText, nutrientType: nutrientType)

        // Calculate confidence based on pattern match quality
        let confidence = calculateMatchConfidence(originalText: originalText, nutrientType: nutrientType)

        return NutritionMatch(
            nutrientType: nutrientType,
            value: value,
            unit: unit,
            originalText: originalText,
            range: fullSwiftRange,
            confidence: confidence
        )
    }

    private func extractUnit(from text: String, nutrientType: NutritionMatch.NutrientType) -> String {
        let lowercased = text.lowercased()

        // Common unit patterns
        if lowercased.contains("mg") { return "mg" }
        if lowercased.contains("mcg") || lowercased.contains("µg") { return "mcg" }
        if lowercased.contains("iu") { return "IU" }
        if lowercased.contains(" g") || lowercased.contains("g ") || text.hasSuffix("g") { return "g" }
        if lowercased.contains("cal") || lowercased.contains("kcal") { return "kcal" }

        // Default units by nutrient type
        switch nutrientType {
        case .calories:
            return "kcal"
        case .protein, .carbohydrates, .fat, .fiber, .sugar, .saturatedFat, .transFat:
            return "g"
        case .sodium, .cholesterol, .potassium, .calcium, .iron, .vitaminC:
            return "mg"
        case .vitaminA, .vitaminD:
            return "mcg"
        case .servingSize:
            return "serving"
        case .servingsPerContainer:
            return ""
        }
    }

    private func calculateMatchConfidence(originalText: String, nutrientType: NutritionMatch.NutrientType) -> Double {
        var confidence = 0.7 // Base confidence

        // Bonus for exact keyword match
        if originalText.lowercased().contains(nutrientType.rawValue.lowercased()) {
            confidence += 0.2
        }

        // Bonus for proper formatting
        if originalText.contains(":") { confidence += 0.1 }
        if originalText.contains("mg") || originalText.contains("g") { confidence += 0.1 }

        return min(1.0, confidence)
    }

    // MARK: - Data Extraction Methods

    private func parseServingInfo(from matches: [NutritionMatch], text: String) -> ServingInfo? {
        let servingSizeMatches = matches.filter { $0.nutrientType == .servingSize }
        let servingsPerContainerMatches = matches.filter { $0.nutrientType == .servingsPerContainer }

        guard let servingSizeMatch = servingSizeMatches.first else { return nil }

        let servingsPerContainer = servingsPerContainerMatches.first?.value

        return ServingInfo(
            size: servingSizeMatch.value,
            unit: servingSizeMatch.unit,
            description: nil,
            servingsPerContainer: servingsPerContainer,
            confidence: servingSizeMatch.confidence
        )
    }

    private func parseCalories(from matches: [NutritionMatch]) -> NutrientValue? {
        let calorieMatches = matches.filter { $0.nutrientType == .calories }
        guard let match = calorieMatches.first else { return nil }

        return NutrientValue(
            value: match.value,
            unit: match.unit,
            originalText: match.originalText,
            confidence: match.confidence,
            isEstimated: false
        )
    }

    private func parseMacronutrients(from matches: [NutritionMatch]) -> MacronutrientValues {
        func findNutrient(_ type: NutritionMatch.NutrientType) -> NutrientValue? {
            guard let match = matches.first(where: { $0.nutrientType == type }) else { return nil }
            return NutrientValue(
                value: match.value,
                unit: match.unit,
                originalText: match.originalText,
                confidence: match.confidence,
                isEstimated: false
            )
        }

        return MacronutrientValues(
            protein: findNutrient(.protein),
            carbohydrates: findNutrient(.carbohydrates),
            fat: findNutrient(.fat),
            fiber: findNutrient(.fiber),
            sugar: findNutrient(.sugar),
            saturatedFat: findNutrient(.saturatedFat),
            transFat: findNutrient(.transFat)
        )
    }

    private func parseMicronutrients(from matches: [NutritionMatch]) -> MicronutrientValues {
        func findNutrient(_ type: NutritionMatch.NutrientType) -> NutrientValue? {
            guard let match = matches.first(where: { $0.nutrientType == type }) else { return nil }
            return NutrientValue(
                value: match.value,
                unit: match.unit,
                originalText: match.originalText,
                confidence: match.confidence,
                isEstimated: false
            )
        }

        return MicronutrientValues(
            sodium: findNutrient(.sodium),
            cholesterol: findNutrient(.cholesterol),
            potassium: findNutrient(.potassium),
            calcium: findNutrient(.calcium),
            iron: findNutrient(.iron),
            vitaminA: findNutrient(.vitaminA),
            vitaminC: findNutrient(.vitaminC),
            vitaminD: findNutrient(.vitaminD)
        )
    }

    private func parseOtherNutrients(from matches: [NutritionMatch]) -> [String: NutrientValue] {
        // For now, return empty - could be extended for additional nutrients
        return [:]
    }

    private func calculateConfidence(
        servingInfo: ServingInfo?,
        calories: NutrientValue?,
        macronutrients: MacronutrientValues,
        micronutrients: MicronutrientValues,
        matches: [NutritionMatch],
        originalText: String
    ) -> ParsedDataConfidence {

        let servingScore = servingInfo?.confidence ?? 0.0
        let caloriesScore = calories?.confidence ?? 0.0

        let macroScores = macronutrients.allValues.values.map { $0.confidence }
        let macroScore = macroScores.isEmpty ? 0.0 : macroScores.reduce(0, +) / Double(macroScores.count)

        let microScores = micronutrients.allValues.values.map { $0.confidence }
        let microScore = microScores.isEmpty ? 0.0 : microScores.reduce(0, +) / Double(microScores.count)

        // Check for nutrition facts formatting patterns
        let formatScore = originalText.lowercased().contains("nutrition facts") ? 0.9 : 0.5

        let overallScore = (servingScore * 0.2 + caloriesScore * 0.3 + macroScore * 0.3 + microScore * 0.1 + formatScore * 0.1)

        return ParsedDataConfidence(
            overallScore: overallScore,
            servingInfoScore: servingScore,
            caloriesScore: caloriesScore,
            macronutrientsScore: macroScore,
            micronutrientsScore: microScore,
            formatRecognitionScore: formatScore
        )
    }
}

// MARK: - Unit Converter Helper

private class NutritionUnitConverter {

    func convertToStandardUnit(_ value: Double, from unit: String, nutrientType: NutritionMatch.NutrientType) -> (value: Double, unit: String) {
        let lowerUnit = unit.lowercased()

        switch nutrientType {
        case .vitaminA, .vitaminD:
            // Convert IU to mcg if needed
            if lowerUnit == "iu" {
                let mcgValue = convertIUToMcg(value, nutrientType: nutrientType)
                return (mcgValue, "mcg")
            }
            return (value, unit)

        default:
            return (value, unit)
        }
    }

    private func convertIUToMcg(_ value: Double, nutrientType: NutritionMatch.NutrientType) -> Double {
        switch nutrientType {
        case .vitaminA:
            return value * 0.3 // Approximate conversion
        case .vitaminD:
            return value * 0.025 // Approximate conversion
        default:
            return value
        }
    }
}