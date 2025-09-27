//
//  SmartFoodCaptureView.swift
//  NutritionTrackerV2
//
//  Complete smart food capture interface with ML recognition and manual fallback
//

import SwiftUI

struct SmartFoodCaptureView: View {
    let mealType: MealType
    let selectedDate: Date
    let onFoodCaptured: (Food, Double, String, Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var workflow = FoodRecognitionWorkflow(config: .default)
    @StateObject private var foodListViewModel = FoodListViewModel()
    @State private var showingCamera = false
    @State private var showingPredictionReview = false
    @State private var showingManualSelection = false
    @State private var showingQuantityEntry = false
    @State private var selectedFood: Food?
    @State private var quantity: String = "1"
    @State private var selectedUnit: String = "serving"

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with meal info
                mealInfoHeader

                // Main content based on workflow state
                Group {
                    switch workflow.state {
                    case .idle:
                        welcomeView
                    case .capturingImage:
                        captureInstructionsView
                    case .processingImage, .recognizingFood:
                        processingView
                    case .reviewingPrediction:
                        predictionReviewContainer
                    case .selectingFoodManually:
                        manualSelectionContainer
                    case .loggingFood:
                        loggingView
                    case .completed:
                        successView
                    case .error(let error):
                        errorView(error)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: workflow.state)
            }
            .navigationTitle("Smart Food Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        workflow.cancelWorkflow()
                        dismiss()
                    }
                }

                if workflow.canRetry {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Retry") {
                            workflow.retryRecognition()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(capturedImage: .constant(nil)) { image in
                workflow.processImage(image)
            }
        }
        .sheet(isPresented: $showingQuantityEntry) {
            if let food = selectedFood {
                quantityEntrySheet(for: food)
            }
        }
        .onAppear {
            startWorkflow()
            // Automatically show camera when the view appears for immediate capture
            showingCamera = true
        }
    }

    // MARK: - Header Views

    private var mealInfoHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: mealType.systemImage)
                    .foregroundColor(mealType.uiColor)
                    .font(.title2)

                Text(mealType.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if workflow.showProgressIndicator {
                ProgressView(workflow.progressMessage)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }

    // MARK: - State Views

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("Smart Food Recognition")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Capture a photo and let AI identify your food automatically")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                Button("Take Photo") {
                    showingCamera = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal, 40)

                Button("Select Manually") {
                    showingManualSelection = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }

            Spacer()
        }
        .padding()
    }

    private var captureInstructionsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("Taking Photo...")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Position your food clearly in the frame for best recognition")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }

    private var processingView: some View {
        VStack(spacing: 24) {
            if let image = workflow.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)

                Text(workflow.progressMessage)
                    .font(.headline)
                    .fontWeight(.medium)

                Text("This may take a few seconds...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var predictionReviewContainer: some View {
        Group {
            if let image = workflow.capturedImage,
               let prediction = workflow.recognitionResult {
                FoodPredictionReviewView(
                    capturedImage: image,
                    predictedFood: prediction,
                    confidence: workflow.recognitionConfidence,
                    showConfidence: workflow.showConfidenceToUser,
                    detectedWeight: workflow.detectedWeight,
                    onAccept: {
                        // Find the food in the database and proceed to quantity entry
                        findAndSelectFood(named: prediction, detectedWeight: workflow.detectedWeight)
                    },
                    onReject: {
                        workflow.rejectPrediction()
                    },
                    onRetry: {
                        workflow.retryRecognition()
                    },
                    onCancel: {
                        workflow.cancelWorkflow()
                        dismiss()
                    }
                )
            }
        }
    }

    private var manualSelectionContainer: some View {
        VStack(spacing: 0) {
            if let image = workflow.capturedImage {
                // Show captured image at top
                VStack(spacing: 8) {
                    Text("Captured Image")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .padding()
                .background(Color(.systemGray6))
            }

            // Manual food selection
            FoodSelectionView(
                mealType: mealType,
                selectedDate: selectedDate
            ) { food, quantity, unit, date in
                onFoodCaptured(food, quantity, unit, date)
                dismiss()
            }
        }
    }

    private var loggingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Logging Food...")
                .font(.headline)
                .fontWeight(.medium)

            if let foodName = workflow.recognitionResult {
                Text("Adding \(foodName.capitalized) to your \(mealType.displayName.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("Food Logged Successfully!")
                    .font(.title2)
                    .fontWeight(.bold)

                if let foodName = workflow.recognitionResult {
                    Text("\(foodName.capitalized) has been added to your \(mealType.displayName.lowercased())")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .cornerRadius(12)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    private func errorView(_ error: FoodRecognitionError) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            VStack(spacing: 12) {
                Text("Recognition Failed")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                if workflow.canRetry {
                    Button("Try Again") {
                        workflow.retryRecognition()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }

                Button("Select Manually") {
                    showingManualSelection = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)

                Button("Take New Photo") {
                    showingCamera = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Quantity Entry Sheet

    private func quantityEntrySheet(for food: Food) -> some View {
        NavigationView {
            VStack(spacing: 20) {
                // Food info
                VStack(spacing: 8) {
                    Text(food.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let brand = food.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Quantity input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quantity")
                        .font(.headline)

                    HStack {
                        TextField("Amount", text: $quantity)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(availableUnits(for: food), id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Spacer()

                // Confirm button
                Button("Add to Log") {
                    if let quantityValue = Double(quantity) {
                        onFoodCaptured(food, quantityValue, selectedUnit, selectedDate)
                        dismiss()
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .disabled(quantity.isEmpty)
            }
            .padding()
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingQuantityEntry = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func startWorkflow() {
        workflow.startWorkflow { result in
            switch result {
            case .success(let recognizedFood, _, _, let detectedWeight):
                print("✅ Workflow completed successfully: \(recognizedFood)")
                findAndSelectFood(named: recognizedFood, detectedWeight: detectedWeight)
            case .lowConfidence(let recognizedFood, _, _, _):
                print("⚠️ Low confidence result: \(recognizedFood ?? "unknown")")
                // The workflow will handle showing the review interface
            case .failed(let error, _):
                print("❌ Workflow failed: \(error.localizedDescription)")
            case .cancelled:
                print("❌ Workflow cancelled")
                dismiss()
            case .manualFallback(_, let detectedWeight):
                // Store detected weight for manual selection
                if let weight = detectedWeight {
                    prefillQuantityWithWeight(weight)
                }
                showingManualSelection = true
            }
        }
    }

    private func findAndSelectFood(named foodName: String, detectedWeight: DetectedWeight? = nil) {
        // Search for the food in the database
        Task { @MainActor in
            await foodListViewModel.searchFoods(query: foodName)

            if let foundFood = foodListViewModel.foods.first {
                selectedFood = foundFood

                // Prefill quantity and unit based on detected weight
                if let weight = detectedWeight {
                    prefillQuantityWithWeight(weight, for: foundFood)
                } else {
                    selectedUnit = availableUnits(for: foundFood).first ?? "serving"
                    quantity = "1"
                }

                showingQuantityEntry = true
            } else {
                // If not found in database, show manual selection instead
                if let weight = detectedWeight {
                    prefillQuantityWithWeight(weight)
                }
                showingManualSelection = true
            }
        }
    }

    private func prefillQuantityWithWeight(_ weight: DetectedWeight, for food: Food? = nil) {
        // Convert weight to appropriate unit for the food
        if let food = food {
            // Try to match the detected weight unit with food's serving unit
            let availableUnits = availableUnits(for: food)

            if availableUnits.contains(weight.unit.rawValue) {
                // Direct unit match
                selectedUnit = weight.unit.rawValue
                quantity = formatQuantity(weight.value)
            } else if weight.unit == .grams && availableUnits.contains("g") {
                selectedUnit = "g"
                quantity = formatQuantity(weight.value)
            } else if let servingSizeGrams = food.servingSizeGrams, servingSizeGrams > 0 {
                // Convert to servings based on food's serving size in grams
                let totalGrams = weight.valueInGrams
                let servings = totalGrams / servingSizeGrams
                selectedUnit = food.servingUnit
                quantity = formatQuantity(servings)
            } else {
                // Fallback to grams
                selectedUnit = "g"
                quantity = formatQuantity(weight.valueInGrams)
            }
        } else {
            // No specific food, use detected weight as-is
            selectedUnit = weight.unit.rawValue
            quantity = formatQuantity(weight.value)
        }

        print("📏 Prefilled quantity from detected weight: \(quantity) \(selectedUnit)")
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == floor(value) {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }

    private func availableUnits(for food: Food) -> [String] {
        var units = [food.servingUnit]
        let standardUnits = ["g", "oz", "cup", "tbsp", "tsp", "ml", "piece", "slice", "serving"]

        for unit in standardUnits {
            if !units.contains(where: { $0.lowercased() == unit.lowercased() }) {
                units.append(unit)
            }
        }

        return units
    }
}

// MARK: - Preview

#if DEBUG
struct SmartFoodCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        SmartFoodCaptureView(
            mealType: .lunch,
            selectedDate: Date()
        ) { food, quantity, unit, date in
            print("Food captured: \(food.displayName), \(quantity) \(unit)")
        }
    }
}
#endif