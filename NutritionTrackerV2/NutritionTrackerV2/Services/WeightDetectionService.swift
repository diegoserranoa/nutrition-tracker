//
//  WeightDetectionService.swift
//  NutritionTrackerV2
//
//  Service for detecting weight values from kitchen scales and food containers in images
//

import Foundation
import UIKit
import Vision
import CoreImage
import OSLog

// MARK: - Weight Detection Result

struct WeightDetectionResult {
    let detectedWeights: [DetectedWeight]
    let processingTime: TimeInterval
    let confidence: Double

    /// Get the most likely weight value
    var bestWeight: DetectedWeight? {
        return detectedWeights.max(by: { $0.confidence < $1.confidence })
    }

    /// Check if any valid weight was detected
    var hasValidWeight: Bool {
        return !detectedWeights.isEmpty && (bestWeight?.confidence ?? 0) > 0.5
    }
}

struct DetectedWeight {
    let value: Double
    let unit: WeightUnit
    let confidence: Double
    let boundingBox: CGRect
    let originalText: String

    /// Convert to grams for standardization
    var valueInGrams: Double {
        return unit.convertToGrams(value)
    }

    /// Format as display string
    var displayString: String {
        if value == floor(value) {
            return "\(Int(value)) \(unit.symbol)"
        } else {
            return String(format: "%.1f", value) + " \(unit.symbol)"
        }
    }
}

enum WeightUnit: String, CaseIterable {
    case grams = "g"
    case kilograms = "kg"
    case ounces = "oz"
    case pounds = "lb"
    case milliliters = "ml"
    case liters = "l"

    var symbol: String {
        return rawValue
    }

    var displayName: String {
        switch self {
        case .grams: return "grams"
        case .kilograms: return "kilograms"
        case .ounces: return "ounces"
        case .pounds: return "pounds"
        case .milliliters: return "milliliters"
        case .liters: return "liters"
        }
    }

    func convertToGrams(_ value: Double) -> Double {
        switch self {
        case .grams: return value
        case .kilograms: return value * 1000
        case .ounces: return value * 28.3495
        case .pounds: return value * 453.592
        case .milliliters: return value // Assuming water-like density
        case .liters: return value * 1000
        }
    }
}

// MARK: - Weight Detection Service

@MainActor
class WeightDetectionService: ObservableObject {

    // MARK: - Properties

    @Published var isProcessing = false

    // MARK: - Public Methods

    /// Detect weight values from an image containing kitchen scales, food containers, etc.
    func detectWeight(from image: UIImage) async throws -> WeightDetectionResult {
        guard !isProcessing else {
            throw WeightDetectionError.serviceUnavailable
        }

        isProcessing = true
        defer { isProcessing = false }

        let startTime = Date()
        print("🔍 Starting weight detection for image size: \(image.size)")

        do {
            // Step 1: Preprocess the image for better LED/LCD screen detection
            let preprocessedImages = preprocessImageForLEDDetection(image)

            // Step 2: Perform OCR on original and preprocessed images
            var allTextObservations: [VNRecognizedTextObservation] = []

            // OCR on original image
            let originalObservations = try await performOCR(on: image)
            allTextObservations.append(contentsOf: originalObservations)

            // OCR on preprocessed images for LED screens
            for processedImage in preprocessedImages {
                let processedObservations = try await performOCR(on: processedImage)
                allTextObservations.append(contentsOf: processedObservations)
            }

            // Step 3: Parse text for weight patterns
            let detectedWeights = parseWeightFromText(allTextObservations)

            let processingTime = Date().timeIntervalSince(startTime)
            let confidence = calculateOverallConfidence(detectedWeights)

            let result = WeightDetectionResult(
                detectedWeights: detectedWeights,
                processingTime: processingTime,
                confidence: confidence
            )

            print("✅ Weight detection completed in \(String(format: "%.2f", processingTime))s, found \(detectedWeights.count) weights from \(preprocessedImages.count + 1) image variants")

            return result

        } catch {
            print("❌ Weight detection failed: \(error.localizedDescription)")
            throw WeightDetectionError.processingFailed(error)
        }
    }

    // MARK: - Private Methods

    /// Preprocess image to enhance LED/LCD screen digit detection
    private func preprocessImageForLEDDetection(_ image: UIImage) -> [UIImage] {
        var processedImages: [UIImage] = []

        guard let cgImage = image.cgImage else {
            return processedImages
        }

        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)

        // 1. High contrast version for LED screens
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(2.0, forKey: kCIInputContrastKey) // Increase contrast
            contrastFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
            contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Desaturate

            if let outputImage = contrastFilter.outputImage,
               let cgImageResult = context.createCGImage(outputImage, from: outputImage.extent) {
                processedImages.append(UIImage(cgImage: cgImageResult))
            }
        }

        // 2. Inverted version (white text on black background)
        if let invertFilter = CIFilter(name: "CIColorInvert") {
            invertFilter.setValue(ciImage, forKey: kCIInputImageKey)

            if let outputImage = invertFilter.outputImage,
               let cgImageResult = context.createCGImage(outputImage, from: outputImage.extent) {
                processedImages.append(UIImage(cgImage: cgImageResult))
            }
        }

        // 3. Threshold version (black and white only)
        if let thresholdFilter = CIFilter(name: "CIColorControls") {
            thresholdFilter.setValue(ciImage, forKey: kCIInputImageKey)
            thresholdFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
            thresholdFilter.setValue(3.0, forKey: kCIInputContrastKey) // Very high contrast
            thresholdFilter.setValue(0.2, forKey: kCIInputBrightnessKey) // Slight brightness boost

            if let outputImage = thresholdFilter.outputImage,
               let cgImageResult = context.createCGImage(outputImage, from: outputImage.extent) {
                processedImages.append(UIImage(cgImage: cgImageResult))
            }
        }

        // 4. Sharpened version for better edge definition
        if let sharpenFilter = CIFilter(name: "CIUnsharpMask") {
            sharpenFilter.setValue(ciImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(2.5, forKey: kCIInputIntensityKey) // Sharpening intensity
            sharpenFilter.setValue(2.5, forKey: kCIInputRadiusKey) // Sharpening radius

            if let outputImage = sharpenFilter.outputImage,
               let cgImageResult = context.createCGImage(outputImage, from: outputImage.extent) {
                processedImages.append(UIImage(cgImage: cgImageResult))
            }
        }

        // 5. LED-specific preprocessing: boost red/green channels (common LED colors)
        if let colorMatrixFilter = CIFilter(name: "CIColorMatrix") {
            colorMatrixFilter.setValue(ciImage, forKey: kCIInputImageKey)
            // Boost red channel
            colorMatrixFilter.setValue(CIVector(x: 1.5, y: 0, z: 0, w: 0), forKey: "inputRVector")
            // Boost green channel
            colorMatrixFilter.setValue(CIVector(x: 0, y: 1.5, z: 0, w: 0), forKey: "inputGVector")
            // Reduce blue channel
            colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0.5, w: 0), forKey: "inputBVector")

            if let outputImage = colorMatrixFilter.outputImage,
               let cgImageResult = context.createCGImage(outputImage, from: outputImage.extent) {
                processedImages.append(UIImage(cgImage: cgImageResult))
            }
        }

        print("📸 Generated \(processedImages.count) preprocessed image variants for LED detection")
        return processedImages
    }

    private func performOCR(on image: UIImage) async throws -> [VNRecognizedTextObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: WeightDetectionError.invalidImage)
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: WeightDetectionError.ocrFailed)
                    return
                }

                continuation.resume(returning: observations)
            }

            // Configure for accurate number recognition, especially for LED displays
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]

            // Optimize for LED/LCD displays
            if #available(iOS 16.0, *) {
                request.automaticallyDetectsLanguage = false
                // Force recognition of digits and common weight symbols
                request.revision = VNRecognizeTextRequestRevision3
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseWeightFromText(_ observations: [VNRecognizedTextObservation]) -> [DetectedWeight] {
        var detectedWeights: [DetectedWeight] = []

        // First, try to find weight values between M and PCS buttons (common on kitchen scales)
        let contextualWeights = findWeightsBetweenMAndPCS(observations)
        detectedWeights.append(contentsOf: contextualWeights)

        // Then, parse individual text observations for weight patterns
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let text = topCandidate.string
            let confidence = topCandidate.confidence

            // Parse weight patterns from the text
            if let weight = parseWeightValue(from: text, confidence: confidence, boundingBox: observation.boundingBox) {
                detectedWeights.append(weight)
            }
        }

        // Filter out duplicates and low confidence results
        return filterAndRankWeights(detectedWeights)
    }

    /// Find weight values specifically positioned between M and PCS buttons on kitchen scales
    private func findWeightsBetweenMAndPCS(_ observations: [VNRecognizedTextObservation]) -> [DetectedWeight] {
        var contextualWeights: [DetectedWeight] = []

        // Create spatial map of text observations
        var mButtons: [VNRecognizedTextObservation] = []
        var pcsButtons: [VNRecognizedTextObservation] = []
        var numbers: [VNRecognizedTextObservation] = []
        var units: [VNRecognizedTextObservation] = []

        // Categorize detected text
        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string.lowercased() else { continue }

            // M button variations (M, MODE, MEM, MEMORY)
            if (text.contains("m") && text.count <= 4) || text.contains("mode") || text.contains("mem") {
                mButtons.append(observation)
            }
            // PCS button variations (PCS, PC, PIECES, COUNT)
            else if text.contains("pcs") || text.contains("pc") || text.contains("piece") || text.contains("count") {
                pcsButtons.append(observation)
            }
            // Numbers (including decimal values)
            else if text.range(of: #"\d+\.?\d*"#, options: .regularExpression) != nil {
                numbers.append(observation)
            }
            // Weight units
            else if ["g", "kg", "oz", "lb", "ml", "l", "grams", "gram"].contains(where: text.contains) {
                units.append(observation)
            }
        }

        print("🔍 Scale button analysis: M=\(mButtons.count), PCS=\(pcsButtons.count), Numbers=\(numbers.count), Units=\(units.count)")

        // Find numbers positioned between M and PCS buttons
        for mButton in mButtons {
            for pcsButton in pcsButtons {
                let mCenter = CGPoint(
                    x: mButton.boundingBox.midX,
                    y: mButton.boundingBox.midY
                )
                let pcsCenter = CGPoint(
                    x: pcsButton.boundingBox.midX,
                    y: pcsButton.boundingBox.midY
                )

                // Look for numbers between M and PCS buttons
                for numberObs in numbers {
                    let numberCenter = CGPoint(
                        x: numberObs.boundingBox.midX,
                        y: numberObs.boundingBox.midY
                    )

                    // Check if number is spatially between M and PCS
                    if isPointBetween(numberCenter, point1: mCenter, point2: pcsCenter, tolerance: 0.3) {
                        guard let numberText = numberObs.topCandidates(1).first?.string,
                              let confidence = numberObs.topCandidates(1).first?.confidence else { continue }

                        // Find nearby unit
                        var detectedUnit: WeightUnit = .grams // Default to grams for scale displays
                        for unitObs in units {
                            let unitCenter = CGPoint(
                                x: unitObs.boundingBox.midX,
                                y: unitObs.boundingBox.midY
                            )
                            let distance = sqrt(pow(numberCenter.x - unitCenter.x, 2) + pow(numberCenter.y - unitCenter.y, 2))

                            if distance < 0.2, // Close proximity
                               let unitText = unitObs.topCandidates(1).first?.string.lowercased() {
                                for unit in WeightUnit.allCases {
                                    if unitText.contains(unit.rawValue) {
                                        detectedUnit = unit
                                        break
                                    }
                                }
                            }
                        }

                        // Extract numeric value
                        if let value = extractNumericValue(from: numberText) {
                            let contextualWeight = DetectedWeight(
                                value: value,
                                unit: detectedUnit,
                                confidence: Double(confidence) * 1.2, // Boost confidence for contextual detection
                                boundingBox: numberObs.boundingBox,
                                originalText: "M[\(numberText)]PCS context"
                            )
                            contextualWeights.append(contextualWeight)
                            print("✅ Found contextual weight between M and PCS: \(contextualWeight.displayString) (from raw text: '\(numberText)')")
                        }
                    }
                }
            }
        }

        return contextualWeights
    }

    /// Check if a point is between two other points with some tolerance
    private func isPointBetween(_ point: CGPoint, point1: CGPoint, point2: CGPoint, tolerance: Double) -> Bool {
        // Calculate if point is roughly on the line between point1 and point2
        let distance1to2 = sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
        let distanceToPoint1 = sqrt(pow(point.x - point1.x, 2) + pow(point.y - point1.y, 2))
        let distanceToPoint2 = sqrt(pow(point.x - point2.x, 2) + pow(point.y - point2.y, 2))

        // Point is between if sum of distances to endpoints is approximately equal to distance between endpoints
        let totalDistance = distanceToPoint1 + distanceToPoint2
        return abs(totalDistance - distance1to2) < tolerance
    }

    /// Extract numeric value from text, handling spaced digits and other variations
    private func extractNumericValue(from text: String) -> Double? {
        // Handle various numeric formats from LED displays
        let cleanText = text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Double(cleanText) else { return nil }

        // Apply decimal point correction for scale values
        return correctDecimalPoint(value)
    }

    /// Correct decimal point position for scale values assuming one decimal place
    private func correctDecimalPoint(_ value: Double) -> Double {
        // If the value already has a decimal point, don't modify it
        if value != floor(value) {
            return value
        }

        // Check if the value looks like a scale reading without decimal point
        let intValue = Int(value)
        let digitCount = String(intValue).count

        // Apply decimal correction based on typical scale patterns
        switch digitCount {
        case 4: // e.g., 3099 -> 309.9g, 1234 -> 123.4g
            if intValue >= 1000 && intValue <= 9999 {
                let correctedValue = Double(intValue) / 10.0
                print("🔧 Decimal correction: \(intValue) -> \(correctedValue) (4-digit correction)")
                return correctedValue
            }
        case 3: // e.g., 999 -> 99.9g, 543 -> 54.3g
            if intValue >= 100 && intValue <= 999 {
                let correctedValue = Double(intValue) / 10.0
                print("🔧 Decimal correction: \(intValue) -> \(correctedValue) (3-digit correction)")
                return correctedValue
            }
        case 5: // e.g., 12345 -> 1234.5g (for larger scales)
            if intValue >= 10000 && intValue <= 99999 {
                let correctedValue = Double(intValue) / 10.0
                print("🔧 Decimal correction: \(intValue) -> \(correctedValue) (5-digit correction)")
                return correctedValue
            }
        case 2: // e.g., 99 -> 9.9g (for small values)
            if intValue >= 10 && intValue <= 99 {
                let correctedValue = Double(intValue) / 10.0
                print("🔧 Decimal correction: \(intValue) -> \(correctedValue) (2-digit correction)")
                return correctedValue
            }
        default:
            // For single digits or very large numbers, don't apply correction
            break
        }

        // Special cases for very common scale readings
        if intValue == 0 {
            return 0.0 // Zero is zero
        }

        // If the value is in a reasonable range for direct reading, keep it
        if value >= 0.1 && value <= 50.0 {
            return value // Already reasonable as-is
        }

        // Additional check: if value is suspiciously large but could be a missing decimal
        if intValue >= 500 && intValue <= 50000 {
            // Values like 1500 could be 150.0g or could be 1.5kg
            // Apply decimal correction for values that seem too large for typical food portions
            let correctedValue = Double(intValue) / 10.0
            print("🔧 Large value decimal correction: \(intValue) -> \(correctedValue) (suspected missing decimal)")
            return correctedValue
        }

        print("🔧 No decimal correction applied to: \(value)")
        return value
    }

    private func parseWeightValue(from text: String, confidence: Float, boundingBox: CGRect) -> DetectedWeight? {
        // Enhanced patterns for LED/LCD displays and traditional scales
        let patterns = [
            // LED display patterns: "354.2 g", "1.2 kg", "12.5 oz" (case insensitive)
            #"(\d+\.?\d*)\s*([gG][rR]?[aA]?[mM]?[sS]?|[kK][gG]|[oO][zZ]|[lL][bB][sS]?|[mM][lL]|[lL])\b"#,

            // Spaced LED digits: "3 5 4 . 2 g" or "354.2 g"
            #"(\d+(?:\s*\.\s*\d+)?)\s*([gG]|[kK][gG]|[oO][zZ]|[lL][bB]|[mM][lL]|[lL])\b"#,

            // LED with separated digits: "3 5 4 2 g" (common misread pattern)
            #"(\d(?:\s+\d)*)\s*([gG]|[kK][gG]|[oO][zZ]|[lL][bB]|[mM][lL]|[lL])\b"#,

            // Container labels: "Net Wt. 16 oz", "Weight: 500g"
            #"(?:[Ww]eight|[Ww]t\.?|[Nn]et)\s*:?\s*(\d+\.?\d*)\s*([gG]|[kK][gG]|[oO][zZ]|[lL][bB]|[mM][lL]|[lL])"#,

            // Scale display patterns: just numbers with units nearby
            #"(\d{1,4}\.?\d{0,2})\s*([gG]|[kK][gG]|[oO][zZ]|[lL][bB]|[mM][lL]|[lL])"#,

            // LED with colon separator (some displays use : instead of .)
            #"(\d+):(\d+)\s*([gG]|[kK][gG]|[oO][zZ]|[lL][bB]|[mM][lL]|[lL])"#,

            // Pure number patterns (when unit is detected separately)
            #"^(\d{1,4}\.?\d{0,3})$"#
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])

                // Extract number and unit
                if let weightInfo = extractNumberAndUnit(from: matchedText) {
                    let adjustedConfidence = Double(confidence) * getPatternConfidence(text: text)

                    return DetectedWeight(
                        value: weightInfo.value,
                        unit: weightInfo.unit,
                        confidence: adjustedConfidence,
                        boundingBox: boundingBox,
                        originalText: text
                    )
                }
            }
        }

        return nil
    }

    private func extractNumberAndUnit(from text: String) -> (value: Double, unit: WeightUnit)? {
        // Extract numeric value and unit from matched text
        var numericValue: Double?
        var detectedUnit: WeightUnit?

        // Handle colon separator (LED displays sometimes show 354:2 instead of 354.2)
        if text.contains(":") {
            let colonComponents = text.components(separatedBy: ":")
            if colonComponents.count == 2,
               let wholePart = Double(colonComponents[0].trimmingCharacters(in: .whitespacesAndNewlines)),
               let decimalPart = Double(colonComponents[1].components(separatedBy: CharacterSet.letters)[0].trimmingCharacters(in: .whitespacesAndNewlines)) {
                // Convert colon format to decimal (354:2 -> 354.2)
                numericValue = wholePart + (decimalPart / 10.0)
            }
        }

        // Handle spaced digits (LED displays sometimes separate digits with spaces)
        if numericValue == nil && text.contains(" ") {
            let spacedDigits = text.components(separatedBy: CharacterSet.letters)[0]
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            numericValue = Double(spacedDigits)
        }

        // Standard number extraction
        if numericValue == nil {
            let numberPattern = #"\d+\.?\d*"#
            if let range = text.range(of: numberPattern, options: .regularExpression) {
                let numberString = String(text[range])
                numericValue = Double(numberString)
            }
        }

        // Find the unit with enhanced detection
        let unitText = text.lowercased()

        // Check for exact matches first
        for unit in WeightUnit.allCases {
            if unitText.contains(unit.rawValue) {
                detectedUnit = unit
                break
            }
        }

        // Check for common LED display variations
        if detectedUnit == nil {
            if unitText.contains("gram") || unitText.contains("gr") {
                detectedUnit = .grams
            } else if unitText.contains("kilo") {
                detectedUnit = .kilograms
            } else if unitText.contains("ounce") || unitText.contains("oz") {
                detectedUnit = .ounces
            } else if unitText.contains("pound") || unitText.contains("lbs") {
                detectedUnit = .pounds
            } else if unitText.contains("milli") {
                detectedUnit = .milliliters
            } else if unitText.contains("liter") || unitText.contains("litre") {
                detectedUnit = .liters
            }
        }

        guard let rawValue = numericValue, let unit = detectedUnit else { return nil }

        // Apply decimal point correction before validation
        let correctedValue = correctDecimalPoint(rawValue)

        // Validate reasonable ranges
        let gramsValue = unit.convertToGrams(correctedValue)
        guard gramsValue > 0.1 && gramsValue < 50000 else { return nil } // 0.1g to 50kg seems reasonable

        return (value: correctedValue, unit: unit)
    }

    private func getPatternConfidence(text: String) -> Double {
        // Enhanced confidence scoring for LED displays and traditional scales
        let lowerText = text.lowercased()
        var confidence = 0.5

        // Maximum confidence for explicit weight references
        if lowerText.contains("scale") || lowerText.contains("weight") {
            confidence = 1.0
        }
        // High confidence for LED display patterns
        else if text.contains(":") && text.count < 12 {
            // LED displays often use colon separator
            confidence = 0.95
        }
        // High confidence for clean decimal patterns
        else if text.contains(".") && text.count < 10 {
            confidence = 0.9
        }
        // Good confidence for spaced digits (common LED misreading)
        else if text.range(of: #"\d\s+\d"#, options: .regularExpression) != nil {
            confidence = 0.85
        }
        // Good confidence for clean number + unit patterns
        else if text.range(of: #"^\d+\.?\d*\s*[a-zA-Z]+$"#, options: .regularExpression) != nil {
            confidence = 0.8
        }
        // Moderate confidence for numbers with weight units
        else if lowerText.contains("g") || lowerText.contains("kg") || lowerText.contains("oz") || lowerText.contains("lb") {
            confidence = 0.7
        }

        // Boost confidence for typical weight ranges
        if let range = text.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
            let numberString = String(text[range])
            if let value = Double(numberString) {
                // Typical kitchen scale ranges
                if value >= 1 && value <= 5000 {
                    confidence += 0.1
                }
                // Very likely weight values
                if value >= 50 && value <= 2000 {
                    confidence += 0.1
                }
            }
        }

        return min(confidence, 1.0)
    }

    private func filterAndRankWeights(_ weights: [DetectedWeight]) -> [DetectedWeight] {
        // Filter out very low confidence results
        let filtered = weights.filter { $0.confidence > 0.3 }

        // Group by similar values (within 5% or 5g) and keep the highest confidence
        var grouped: [DetectedWeight] = []

        for weight in filtered {
            let isDuplicate = grouped.contains { existing in
                let gramsDiff = abs(weight.valueInGrams - existing.valueInGrams)
                return gramsDiff < max(5.0, weight.valueInGrams * 0.05)
            }

            if !isDuplicate {
                grouped.append(weight)
            } else {
                // Replace if this one has higher confidence, or if it's a contextual detection
                if let index = grouped.firstIndex(where: { existing in
                    let gramsDiff = abs(weight.valueInGrams - existing.valueInGrams)
                    return gramsDiff < max(5.0, weight.valueInGrams * 0.05)
                }) {
                    let isContextualDetection = weight.originalText.contains("M[") && weight.originalText.contains("]PCS context")
                    let existingIsContextual = grouped[index].originalText.contains("M[") && grouped[index].originalText.contains("]PCS context")

                    // Prefer contextual detections or higher confidence
                    if (isContextualDetection && !existingIsContextual) || weight.confidence > grouped[index].confidence {
                        grouped[index] = weight
                    }
                }
            }
        }

        // Sort by contextual detection first, then by confidence
        return grouped.sorted { weight1, weight2 in
            let isContextual1 = weight1.originalText.contains("M[") && weight1.originalText.contains("]PCS context")
            let isContextual2 = weight2.originalText.contains("M[") && weight2.originalText.contains("]PCS context")

            if isContextual1 && !isContextual2 {
                return true // Contextual detection comes first
            } else if !isContextual1 && isContextual2 {
                return false // Contextual detection comes first
            } else {
                return weight1.confidence > weight2.confidence // Sort by confidence
            }
        }
    }

    private func calculateOverallConfidence(_ weights: [DetectedWeight]) -> Double {
        guard !weights.isEmpty else { return 0.0 }

        // Use the highest confidence as overall confidence
        return weights.map { $0.confidence }.max() ?? 0.0
    }
}

// MARK: - Errors

enum WeightDetectionError: LocalizedError {
    case invalidImage
    case ocrFailed
    case serviceUnavailable
    case processingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format for weight detection"
        case .ocrFailed:
            return "Failed to extract text from image"
        case .serviceUnavailable:
            return "Weight detection service is currently processing another request"
        case .processingFailed(let error):
            return "Weight detection failed: \(error.localizedDescription)"
        }
    }
}

