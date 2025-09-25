//
//  FoodFormViewModel.swift
//  NutritionTrackerV2
//
//  ViewModel for food creation and editing with Supabase integration
//

import Foundation
import Combine
import OSLog

@MainActor
class FoodFormViewModel: ObservableObject {

    // MARK: - Published Properties

    // Basic Info
    @Published var name: String = ""
    @Published var brand: String = ""
    @Published var barcode: String = ""
    @Published var description: String = ""

    // Category and metadata
    @Published var selectedCategory: FoodCategory? = nil
    @Published var isVerified: Bool = false

    // Serving Info
    @Published var servingSize: String = ""
    @Published var servingUnit: String = ""
    @Published var servingSizeGrams: String = ""

    // Macronutrients (required)
    @Published var calories: String = ""
    @Published var protein: String = ""
    @Published var carbohydrates: String = ""
    @Published var fat: String = ""

    // Optional macronutrients
    @Published var fiber: String = ""
    @Published var sugar: String = ""
    @Published var saturatedFat: String = ""
    @Published var unsaturatedFat: String = ""
    @Published var transFat: String = ""

    // Micronutrients
    @Published var sodium: String = ""
    @Published var potassium: String = ""
    @Published var calcium: String = ""
    @Published var iron: String = ""
    @Published var magnesium: String = ""
    @Published var phosphorus: String = ""
    @Published var zinc: String = ""

    // Vitamins
    @Published var vitaminA: String = ""
    @Published var vitaminC: String = ""
    @Published var vitaminD: String = ""
    @Published var vitaminE: String = ""
    @Published var vitaminK: String = ""
    @Published var vitaminB1: String = ""
    @Published var vitaminB2: String = ""
    @Published var vitaminB3: String = ""
    @Published var vitaminB6: String = ""
    @Published var vitaminB12: String = ""
    @Published var folate: String = ""

    // UI State
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showMoreNutrients = false

    // MARK: - Private Properties

    private let foodService: FoodService
    private let logger = Logger(subsystem: "com.nutritiontracker.foodform", category: "FoodFormViewModel")
    private var editingFood: Food?

    // Validation
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !servingSize.trimmingCharacters(in: .whitespaces).isEmpty &&
        !servingUnit.trimmingCharacters(in: .whitespaces).isEmpty &&
        !calories.trimmingCharacters(in: .whitespaces).isEmpty &&
        !protein.trimmingCharacters(in: .whitespaces).isEmpty &&
        !carbohydrates.trimmingCharacters(in: .whitespaces).isEmpty &&
        !fat.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(servingSize) != nil &&
        Double(calories) != nil &&
        Double(protein) != nil &&
        Double(carbohydrates) != nil &&
        Double(fat) != nil
    }

    // MARK: - Closures

    var onSave: (() -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Initialization

    init(foodService: FoodService? = nil) {
        self.foodService = foodService ?? FoodService()
    }

    // MARK: - Public Methods

    func loadFood(_ food: Food) {
        editingFood = food

        // Basic info
        name = food.name
        brand = food.brand ?? ""
        barcode = food.barcode ?? ""
        description = food.description ?? ""

        // Category and metadata
        selectedCategory = food.category
        isVerified = food.isVerified

        // Serving info
        servingSize = String(food.servingSize)
        servingUnit = food.servingUnit
        servingSizeGrams = food.servingSizeGrams?.description ?? ""

        // Required macronutrients
        calories = String(food.calories)
        protein = String(food.protein)
        carbohydrates = String(food.carbohydrates)
        fat = String(food.fat)

        // Optional macronutrients
        fiber = food.fiber?.description ?? ""
        sugar = food.sugar?.description ?? ""
        saturatedFat = food.saturatedFat?.description ?? ""
        unsaturatedFat = food.unsaturatedFat?.description ?? ""
        transFat = food.transFat?.description ?? ""

        // Micronutrients
        sodium = food.sodium?.description ?? ""
        potassium = food.potassium?.description ?? ""
        calcium = food.calcium?.description ?? ""
        iron = food.iron?.description ?? ""
        magnesium = food.magnesium?.description ?? ""
        phosphorus = food.phosphorus?.description ?? ""
        zinc = food.zinc?.description ?? ""

        // Vitamins
        vitaminA = food.vitaminA?.description ?? ""
        vitaminC = food.vitaminC?.description ?? ""
        vitaminD = food.vitaminD?.description ?? ""
        vitaminE = food.vitaminE?.description ?? ""
        vitaminK = food.vitaminK?.description ?? ""
        vitaminB1 = food.vitaminB1?.description ?? ""
        vitaminB2 = food.vitaminB2?.description ?? ""
        vitaminB3 = food.vitaminB3?.description ?? ""
        vitaminB6 = food.vitaminB6?.description ?? ""
        vitaminB12 = food.vitaminB12?.description ?? ""
        folate = food.folate?.description ?? ""
    }

    func save() async {
        guard isFormValid else {
            logger.warning("Form validation failed")
            return
        }

        isLoading = true
        error = nil

        do {
            let food = try buildFood()

            let result: Food
            if let editingFood = editingFood {
                // Update existing food
                var updatedFood = food
                // Preserve the original ID for updates
                result = Food(
                    id: editingFood.id,
                    name: updatedFood.name,
                    brand: updatedFood.brand,
                    barcode: updatedFood.barcode,
                    description: updatedFood.description,
                    servingSize: updatedFood.servingSize,
                    servingUnit: updatedFood.servingUnit,
                    servingSizeGrams: updatedFood.servingSizeGrams,
                    calories: updatedFood.calories,
                    protein: updatedFood.protein,
                    carbohydrates: updatedFood.carbohydrates,
                    fat: updatedFood.fat,
                    fiber: updatedFood.fiber,
                    sugar: updatedFood.sugar,
                    saturatedFat: updatedFood.saturatedFat,
                    unsaturatedFat: updatedFood.unsaturatedFat,
                    transFat: updatedFood.transFat,
                    sodium: updatedFood.sodium,
                    potassium: updatedFood.potassium,
                    calcium: updatedFood.calcium,
                    iron: updatedFood.iron,
                    vitaminA: updatedFood.vitaminA,
                    vitaminC: updatedFood.vitaminC,
                    vitaminD: updatedFood.vitaminD,
                    vitaminE: updatedFood.vitaminE,
                    vitaminK: updatedFood.vitaminK,
                    vitaminB1: updatedFood.vitaminB1,
                    vitaminB2: updatedFood.vitaminB2,
                    vitaminB3: updatedFood.vitaminB3,
                    vitaminB6: updatedFood.vitaminB6,
                    vitaminB12: updatedFood.vitaminB12,
                    folate: updatedFood.folate,
                    magnesium: updatedFood.magnesium,
                    phosphorus: updatedFood.phosphorus,
                    zinc: updatedFood.zinc,
                    category: updatedFood.category,
                    isVerified: updatedFood.isVerified,
                    source: editingFood.source, // Preserve original source
                    createdAt: editingFood.createdAt, // Preserve original creation date
                    updatedAt: Date(), // Update timestamp
                    createdBy: editingFood.createdBy // Preserve original creator
                )
                _ = try await foodService.updateFood(result)
            } else {
                // Create new food
                result = try await foodService.createFood(food)
            }

            logger.info("Successfully saved food: \(result.name)")
            onSave?()

        } catch {
            logger.error("Failed to save food: \(error.localizedDescription)")
            self.error = error
            onError?(error)
        }

        isLoading = false
    }

    func clearError() {
        error = nil
    }

    func resetForm() {
        editingFood = nil

        // Clear all fields
        name = ""
        brand = ""
        barcode = ""
        description = ""
        selectedCategory = nil
        isVerified = false

        servingSize = ""
        servingUnit = ""
        servingSizeGrams = ""

        calories = ""
        protein = ""
        carbohydrates = ""
        fat = ""

        fiber = ""
        sugar = ""
        saturatedFat = ""
        unsaturatedFat = ""
        transFat = ""

        sodium = ""
        potassium = ""
        calcium = ""
        iron = ""
        magnesium = ""
        phosphorus = ""
        zinc = ""

        vitaminA = ""
        vitaminC = ""
        vitaminD = ""
        vitaminE = ""
        vitaminK = ""
        vitaminB1 = ""
        vitaminB2 = ""
        vitaminB3 = ""
        vitaminB6 = ""
        vitaminB12 = ""
        folate = ""

        error = nil
        showMoreNutrients = false
    }

    // MARK: - Private Methods

    private func buildFood() throws -> Food {
        guard let servingSizeValue = Double(servingSize),
              let caloriesValue = Double(calories),
              let proteinValue = Double(protein),
              let carbohydratesValue = Double(carbohydrates),
              let fatValue = Double(fat) else {
            throw DataServiceError.validationFailed([
                ValidationError(field: "form", code: .invalidFormat, message: "Required fields must be valid numbers")
            ])
        }

        return Food(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces).isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces),
            barcode: barcode.trimmingCharacters(in: .whitespaces).isEmpty ? nil : barcode.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
            servingSize: servingSizeValue,
            servingUnit: servingUnit.trimmingCharacters(in: .whitespaces),
            servingSizeGrams: parseOptionalDouble(servingSizeGrams),
            calories: caloriesValue,
            protein: proteinValue,
            carbohydrates: carbohydratesValue,
            fat: fatValue,
            fiber: parseOptionalDouble(fiber),
            sugar: parseOptionalDouble(sugar),
            saturatedFat: parseOptionalDouble(saturatedFat),
            unsaturatedFat: parseOptionalDouble(unsaturatedFat),
            transFat: parseOptionalDouble(transFat),
            sodium: parseOptionalDouble(sodium),
            potassium: parseOptionalDouble(potassium),
            calcium: parseOptionalDouble(calcium),
            iron: parseOptionalDouble(iron),
            vitaminA: parseOptionalDouble(vitaminA),
            vitaminC: parseOptionalDouble(vitaminC),
            vitaminD: parseOptionalDouble(vitaminD),
            vitaminE: parseOptionalDouble(vitaminE),
            vitaminK: parseOptionalDouble(vitaminK),
            vitaminB1: parseOptionalDouble(vitaminB1),
            vitaminB2: parseOptionalDouble(vitaminB2),
            vitaminB3: parseOptionalDouble(vitaminB3),
            vitaminB6: parseOptionalDouble(vitaminB6),
            vitaminB12: parseOptionalDouble(vitaminB12),
            folate: parseOptionalDouble(folate),
            magnesium: parseOptionalDouble(magnesium),
            phosphorus: parseOptionalDouble(phosphorus),
            zinc: parseOptionalDouble(zinc),
            category: selectedCategory,
            isVerified: isVerified,
            source: .userCreated,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: nil // TODO: Add user ID when auth is implemented
        )
    }

    private func parseOptionalDouble(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Double(trimmed)
    }
}