//
//  OCRNutritionCorrectionView.swift
//  NutritionTrackerV2
//
//  Manual correction interface for OCR-extracted nutrition data
//

import SwiftUI

struct OCRNutritionCorrectionView: View {
    let extractionResult: NutritionExtractionResult
    let onSave: (Food) -> Void
    let onCancel: () -> Void

    @StateObject private var viewModel = OCRCorrectionViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: CorrectionField?

    @State private var showingValidationErrors = false
    @State private var validationErrors: [CorrectionValidationError] = []
    @State private var showingOriginalData = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with confidence indicator
                headerSection

                // Main correction form
                Form {
                    // Basic Information Section
                    basicInformationSection

                    // Serving Information Section
                    servingInformationSection

                    // Macronutrients Section
                    macronutrientsSection

                    // Micronutrients Section (if detected)
                    if viewModel.hasMicronutrients {
                        micronutrientsSection
                    }

                    // Original OCR Data Section
                    originalDataSection
                }

                // Action Buttons
                actionButtonsSection
            }
            .navigationTitle("Review Nutrition Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFood()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
        }
        .onAppear {
            viewModel.populateFromExtractionResult(extractionResult)
        }
        .alert("Validation Errors", isPresented: $showingValidationErrors) {
            Button("OK") { showingValidationErrors = false }
        } message: {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(validationErrors, id: \.field) { error in
                    Text("• \(error.message)")
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Review & Correct")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Verify OCR-extracted data before saving")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Confidence indicator
                ConfidenceIndicator(
                    score: extractionResult.parsedNutrition.confidence.overallScore,
                    rating: extractionResult.successRating
                )
            }
            .padding(.horizontal)

            if !extractionResult.recommendations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(extractionResult.highPriorityRecommendations.enumerated()), id: \.offset) { _, recommendation in
                            RecommendationBadge(recommendation: recommendation)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }

    // MARK: - Basic Information Section

    private var basicInformationSection: some View {
        Section("Basic Information") {
            TextField("Food Name", text: $viewModel.name)
                .focused($focusedField, equals: .name)

            TextField("Brand (optional)", text: $viewModel.brand)
                .focused($focusedField, equals: .brand)

            TextField("Description (optional)", text: $viewModel.description)
                .focused($focusedField, equals: .description)
        }
    }

    // MARK: - Serving Information Section

    private var servingInformationSection: some View {
        Section {
            HStack {
                Text("Serving Size")
                Spacer()

                TextField("Size", value: $viewModel.servingSize, format: .number.precision(.fractionLength(0...2)))
                    .focused($focusedField, equals: .servingSize)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)

                TextField("Unit", text: $viewModel.servingUnit)
                    .focused($focusedField, equals: .servingUnit)
                    .frame(width: 60)
            }
            .foregroundColor(viewModel.servingSizeConfidence < 0.6 ? .orange : .primary)

            if let grams = viewModel.servingSizeGrams, grams > 0 {
                HStack {
                    Text("Serving Weight")
                    Spacer()
                    Text("\(Int(grams))g")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            HStack {
                Text("Serving Information")
                Spacer()
                if viewModel.servingSizeConfidence < 0.8 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        } footer: {
            if viewModel.servingSizeConfidence < 0.6 {
                Text("Low confidence in serving size detection. Please verify.")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }

    // MARK: - Macronutrients Section

    private var macronutrientsSection: some View {
        Section("Macronutrients") {
            NutrientField(
                label: "Calories",
                value: $viewModel.calories,
                unit: "",
                confidence: viewModel.caloriesConfidence,
                focusedField: $focusedField,
                field: .calories
            )

            NutrientField(
                label: "Protein",
                value: $viewModel.protein,
                unit: "g",
                confidence: viewModel.proteinConfidence,
                focusedField: $focusedField,
                field: .protein
            )

            NutrientField(
                label: "Carbohydrates",
                value: $viewModel.carbohydrates,
                unit: "g",
                confidence: viewModel.carbohydratesConfidence,
                focusedField: $focusedField,
                field: .carbohydrates
            )

            NutrientField(
                label: "Fat",
                value: $viewModel.fat,
                unit: "g",
                confidence: viewModel.fatConfidence,
                focusedField: $focusedField,
                field: .fat
            )

            if viewModel.fiber > 0 {
                NutrientField(
                    label: "Fiber",
                    value: $viewModel.fiber,
                    unit: "g",
                    confidence: viewModel.fiberConfidence,
                    focusedField: $focusedField,
                    field: .fiber
                )
            }

            if viewModel.sugar > 0 {
                NutrientField(
                    label: "Sugar",
                    value: $viewModel.sugar,
                    unit: "g",
                    confidence: viewModel.sugarConfidence,
                    focusedField: $focusedField,
                    field: .sugar
                )
            }
        }
    }

    // MARK: - Micronutrients Section

    private var micronutrientsSection: some View {
        Section("Micronutrients") {
            if viewModel.sodium > 0 {
                NutrientField(
                    label: "Sodium",
                    value: $viewModel.sodium,
                    unit: "mg",
                    confidence: viewModel.sodiumConfidence,
                    focusedField: $focusedField,
                    field: .sodium
                )
            }

            if viewModel.calcium > 0 {
                NutrientField(
                    label: "Calcium",
                    value: $viewModel.calcium,
                    unit: "mg",
                    confidence: viewModel.calciumConfidence,
                    focusedField: $focusedField,
                    field: .calcium
                )
            }

            if viewModel.iron > 0 {
                NutrientField(
                    label: "Iron",
                    value: $viewModel.iron,
                    unit: "mg",
                    confidence: viewModel.ironConfidence,
                    focusedField: $focusedField,
                    field: .iron
                )
            }

            if viewModel.potassium > 0 {
                NutrientField(
                    label: "Potassium",
                    value: $viewModel.potassium,
                    unit: "mg",
                    confidence: viewModel.potassiumConfidence,
                    focusedField: $focusedField,
                    field: .potassium
                )
            }
        }
    }

    // MARK: - Original Data Section

    private var originalDataSection: some View {
        Section("Original OCR Data") {
            DisclosureGroup("View Detected Text", isExpanded: $showingOriginalData) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(extractionResult.ocrResult.ocrResult.recognizedTexts.enumerated()), id: \.offset) { index, textItem in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(textItem.text)
                                    .font(.caption)
                                    .lineLimit(2)

                                Text("Confidence: \(Int(textItem.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Circle()
                                .fill(confidenceColor(for: textItem.confidence))
                                .frame(width: 6, height: 6)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                Button("Save Food Item") {
                    saveFood()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.isValid ? Color.blue : Color.gray)
                .cornerRadius(10)
                .disabled(!viewModel.isValid)
            }

            if !viewModel.isValid {
                Text("Please fill in required fields (name, serving size, calories)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -1)
    }

    // MARK: - Helper Methods

    private func saveFood() {
        let errors = viewModel.validate()
        if !errors.isEmpty {
            validationErrors = errors
            showingValidationErrors = true
            return
        }

        let food = viewModel.createFood()
        onSave(food)
    }

    private func confidenceColor(for confidence: Float) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Supporting Views

struct ConfidenceIndicator: View {
    let score: Double
    let rating: ExtractionSuccessRating

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(rating.color)
                .frame(width: 8, height: 8)

            Text("\(Int(score * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(rating.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(rating.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct RecommendationBadge: View {
    let recommendation: ExtractionRecommendation

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIcon)
                .font(.caption2)
                .foregroundColor(priorityColor)

            Text(recommendation.message)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(priorityColor.opacity(0.1))
        .cornerRadius(6)
    }

    private var priorityIcon: String {
        switch recommendation.priority {
        case .high:
            return "exclamationmark.triangle.fill"
        case .medium:
            return "info.circle.fill"
        case .low:
            return "lightbulb.fill"
        }
    }

    private var priorityColor: Color {
        switch recommendation.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        }
    }
}

struct NutrientField: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let confidence: Double
    @FocusState.Binding var focusedField: CorrectionField?
    let field: CorrectionField

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(confidence < 0.6 ? .orange : .primary)

            Spacer()

            HStack(spacing: 4) {
                TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                    .focused($focusedField, equals: field)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)

                if !unit.isEmpty {
                    Text(unit)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                // Confidence indicator
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Form Field Enumeration

enum CorrectionField: Hashable {
    case name, brand, description
    case servingSize, servingUnit
    case calories, protein, carbohydrates, fat, fiber, sugar
    case sodium, calcium, iron, potassium
}

// MARK: - Validation Error

struct CorrectionValidationError {
    let field: CorrectionField
    let message: String
}

// MARK: - ViewModel

@MainActor
class OCRCorrectionViewModel: ObservableObject {
    // Basic Information
    @Published var name: String = ""
    @Published var brand: String = ""
    @Published var description: String = ""

    // Serving Information
    @Published var servingSize: Double = 1.0
    @Published var servingUnit: String = "serving"
    @Published var servingSizeGrams: Double?
    @Published var servingSizeConfidence: Double = 0.0

    // Macronutrients
    @Published var calories: Double = 0.0
    @Published var protein: Double = 0.0
    @Published var carbohydrates: Double = 0.0
    @Published var fat: Double = 0.0
    @Published var fiber: Double = 0.0
    @Published var sugar: Double = 0.0

    // Micronutrients
    @Published var sodium: Double = 0.0
    @Published var calcium: Double = 0.0
    @Published var iron: Double = 0.0
    @Published var potassium: Double = 0.0

    // Confidence scores
    @Published var caloriesConfidence: Double = 0.0
    @Published var proteinConfidence: Double = 0.0
    @Published var carbohydratesConfidence: Double = 0.0
    @Published var fatConfidence: Double = 0.0
    @Published var fiberConfidence: Double = 0.0
    @Published var sugarConfidence: Double = 0.0
    @Published var sodiumConfidence: Double = 0.0
    @Published var calciumConfidence: Double = 0.0
    @Published var ironConfidence: Double = 0.0
    @Published var potassiumConfidence: Double = 0.0

    var hasMicronutrients: Bool {
        return sodium > 0 || calcium > 0 || iron > 0 || potassium > 0
    }

    var isValid: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               servingSize > 0 &&
               !servingUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               calories >= 0
    }

    func populateFromExtractionResult(_ result: NutritionExtractionResult) {
        let nutrition = result.parsedNutrition

        // Generate a default name if not provided
        self.name = "Scanned Food Item"
        self.brand = ""
        self.description = "Nutrition data extracted from label scan"

        // Serving information
        if let serving = nutrition.servingInfo {
            self.servingSize = serving.size
            self.servingUnit = serving.unit
            self.servingSizeConfidence = nutrition.confidence.servingInfoScore
        }

        // Macronutrients
        if let calories = nutrition.calories {
            self.calories = calories.value
            self.caloriesConfidence = Double(calories.confidence)
        }

        if let protein = nutrition.macronutrients.protein {
            self.protein = protein.value
            self.proteinConfidence = Double(protein.confidence)
        }

        if let carbs = nutrition.macronutrients.carbohydrates {
            self.carbohydrates = carbs.value
            self.carbohydratesConfidence = Double(carbs.confidence)
        }

        if let fat = nutrition.macronutrients.fat {
            self.fat = fat.value
            self.fatConfidence = Double(fat.confidence)
        }

        // Additional macronutrients
        if let fiber = nutrition.macronutrients.fiber {
            self.fiber = fiber.value
            self.fiberConfidence = Double(fiber.confidence)
        }

        if let sugar = nutrition.macronutrients.sugar {
            self.sugar = sugar.value
            self.sugarConfidence = Double(sugar.confidence)
        }

        // Micronutrients
        if let sodium = nutrition.micronutrients.sodium {
            self.sodium = sodium.value
            self.sodiumConfidence = Double(sodium.confidence)
        }

        if let calcium = nutrition.micronutrients.calcium {
            self.calcium = calcium.value
            self.calciumConfidence = Double(calcium.confidence)
        }

        if let iron = nutrition.micronutrients.iron {
            self.iron = iron.value
            self.ironConfidence = Double(iron.confidence)
        }

        if let potassium = nutrition.micronutrients.potassium {
            self.potassium = potassium.value
            self.potassiumConfidence = Double(potassium.confidence)
        }
    }

    func validate() -> [CorrectionValidationError] {
        var errors: [CorrectionValidationError] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(CorrectionValidationError(field: .name, message: "Food name is required"))
        }

        if servingSize <= 0 {
            errors.append(CorrectionValidationError(field: .servingSize, message: "Serving size must be greater than 0"))
        }

        if servingUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(CorrectionValidationError(field: .servingUnit, message: "Serving unit is required"))
        }

        if calories < 0 {
            errors.append(CorrectionValidationError(field: .calories, message: "Calories cannot be negative"))
        }

        if protein < 0 {
            errors.append(CorrectionValidationError(field: .protein, message: "Protein cannot be negative"))
        }

        if carbohydrates < 0 {
            errors.append(CorrectionValidationError(field: .carbohydrates, message: "Carbohydrates cannot be negative"))
        }

        if fat < 0 {
            errors.append(CorrectionValidationError(field: .fat, message: "Fat cannot be negative"))
        }

        return errors
    }

    func createFood() -> Food {
        return Food(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
            barcode: nil,
            description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            servingSize: servingSize,
            servingUnit: servingUnit.trimmingCharacters(in: .whitespacesAndNewlines),
            servingSizeGrams: servingSizeGrams,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            fiber: fiber > 0 ? fiber : nil,
            sugar: sugar > 0 ? sugar : nil,
            saturatedFat: nil,
            unsaturatedFat: nil,
            transFat: nil,
            sodium: sodium > 0 ? sodium : nil,
            potassium: potassium > 0 ? potassium : nil,
            calcium: calcium > 0 ? calcium : nil,
            iron: iron > 0 ? iron : nil,
            vitaminA: nil,
            vitaminC: nil,
            vitaminD: nil,
            vitaminE: nil,
            vitaminK: nil,
            vitaminB1: nil,
            vitaminB2: nil,
            vitaminB3: nil,
            vitaminB6: nil,
            vitaminB12: nil,
            folate: nil,
            magnesium: nil,
            phosphorus: nil,
            zinc: nil,
            category: nil,
            isVerified: false,
            source: .ocrScan,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: UUID()
        )
    }
}

// MARK: - Preview

#if DEBUG
struct OCRNutritionCorrectionView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock extraction result for preview
        let mockResult = createMockExtractionResult()

        OCRNutritionCorrectionView(
            extractionResult: mockResult,
            onSave: { food in
                print("Saved food: \(food.name)")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }

    static func createMockExtractionResult() -> NutritionExtractionResult {
        // Create mock data - this would need to be implemented based on actual data structures
        fatalError("Mock implementation needed for preview")
    }
}
#endif
