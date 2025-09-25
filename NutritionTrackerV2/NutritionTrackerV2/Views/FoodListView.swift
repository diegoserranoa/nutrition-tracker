//
//  FoodListView.swift
//  NutritionTrackerV2
//
//  Main food list interface with search, add, edit, and delete functionality
//

import SwiftUI
import Vision
import PhotosUI

struct FoodListView: View {
    @StateObject private var viewModel = FoodListViewModel()
    @State private var showingAddOptions = false
    @State private var showingManualForm = false
    @State private var showingImagePicker = false
    @State private var showEditFoodForm = false
    @State private var showDeleteConfirm = false
    @State private var useCamera = false
    @State private var previewData: IdentifiablePreviewData?
    @State private var editingFood: Food?
    @State private var confirmDeleteFood: Food?
    @State private var parsedFood: Food?
    @State private var showingPreview = false
    @State private var searchFocused = false

    struct IdentifiablePreviewData: Identifiable, Equatable {
        let id = UUID()
        let image: UIImage
        let textBoxes: [CGRect]
        let parsedFood: Food?
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading foods...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
                    } else if let error = viewModel.error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                                .symbolEffect(.bounce, value: viewModel.error?.localizedDescription)

                            Text("Error loading foods")
                                .font(.headline)
                                .foregroundColor(.red)

                            Text(error.localizedDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Try Again") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.clearError()
                                    viewModel.fetchFoods()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.4), value: viewModel.error != nil)
                    } else if viewModel.foods.isEmpty && !viewModel.searchText.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                                .symbolEffect(.pulse, value: viewModel.searchText)

                            Text("No foods found")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.foods.isEmpty)
                    } else if viewModel.foods.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                                .symbolEffect(.bounce.up, value: viewModel.foods.isEmpty)

                            Text("No foods yet")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Text("Tap the + button to add your first food")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .animation(.easeInOut(duration: 0.4), value: viewModel.foods.isEmpty)
                    } else {
                        List {
                            ForEach(viewModel.filteredFoods) { food in
                                NavigationLink(destination: FoodDetailView(food: food)) {
                                    FoodRowView(food: food)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        confirmDeleteFood = food
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        editingFood = food
                                        showEditFoodForm = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                        .searchable(
                            text: $viewModel.searchText,
                            isPresented: $searchFocused,
                            prompt: "Search foods..."
                        )
                        .onAppear {
                            searchFocused = true
                        }
                        .refreshable {
                            viewModel.refreshFoods()
                        }
                    }
                }
                .navigationTitle("Foods")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        RealtimeConnectionStatusView(realtimeManager: RealtimeManager.shared)
                    }
                }
                .onAppear {
                    if viewModel.foods.isEmpty && !viewModel.isLoading {
                        viewModel.fetchFoods()
                    }
                    viewModel.startRealtimeUpdates()
                }
                .onDisappear {
                    viewModel.stopRealtimeUpdates()
                }

                // Floating Action Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingAddOptions = true
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .scaleEffect(showingAddOptions ? 0.95 : 1.0)
                        .rotationEffect(.degrees(showingAddOptions ? 45 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingAddOptions)
                }
                .padding()
                .confirmationDialog("Add Food", isPresented: $showingAddOptions) {
                    Button("Add Food Manually") {
                        showingManualForm = true
                    }
                    Button("Take Photo with Camera") {
                        useCamera = true
                        showingImagePicker = true
                    }
                    Button("Choose from Gallery") {
                        useCamera = false
                        showingImagePicker = true
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force single view on iPad
        // Sheets for forms and actions
        .sheet(isPresented: $showingManualForm) {
            FoodFormView(prefilledFood: parsedFood) {
                showingManualForm = false
                parsedFood = nil
                viewModel.refreshFoods()
            }
        }
        .sheet(item: $editingFood) { food in
            FoodFormView(prefilledFood: food) {
                showEditFoodForm = false
                editingFood = nil
                viewModel.refreshFoods()
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                sourceType: useCamera ? .camera : .photoLibrary
            ) { image in
                parseImage(image)
            }
        }
        .sheet(item: $previewData) { identifiable in
            OCRPreviewView(image: identifiable.image, boxes: identifiable.textBoxes)
                .onTapGesture {
                    parsedFood = identifiable.parsedFood
                    previewData = nil
                    showingManualForm = true
                }
        }
        .alert("Delete Food?", isPresented: $showDeleteConfirm, presenting: confirmDeleteFood) { food in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteFood(food)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { food in
            Text("Are you sure you want to delete \"\(food.name)\"? This action cannot be undone.")
        }
    }

    private func parseImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { request, error in
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }

            let text = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")

            // Save normalized bounding boxes for preview
            let boxes = results.map { $0.boundingBox }

            DispatchQueue.main.async {
                let parsedFood = parseNutritionFacts(from: text, image: image)
                previewData = IdentifiablePreviewData(
                    image: image,
                    textBoxes: boxes,
                    parsedFood: parsedFood
                )
            }
        }

        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    private func extractServingSize(from text: String) -> (Double?, String?) {
        // Matches numbers followed by a unit like g/ml/oz etc.
        let pattern = #"(?i)(\d+(\.\d+)?)\s?(g|ml|oz|mg|mcg|l)\b"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                if let valueRange = Range(match.range(at: 1), in: text),
                   let unitRange = Range(match.range(at: 3), in: text) {
                    let valueString = String(text[valueRange])
                    let unit = String(text[unitRange])
                    let value = Double(valueString)
                    return (value, unit.lowercased())
                }
            }
        }

        return (nil, nil)
    }

    private func parseNutritionFacts(from text: String, image: UIImage) -> Food {
        let lines = text.lowercased().components(separatedBy: .newlines)

        func extract(_ key: String) -> Double? {
            lines.first { $0.contains(key) }?
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Double($0) }
                .first
        }

        let (servingValue, unit) = extractServingSize(from: text.lowercased())

        // Create a Food model with parsed data
        return Food(
            id: UUID(),
            name: "", // User will need to fill this in
            brand: nil,
            barcode: nil,
            description: "Parsed from nutrition label",
            servingSize: servingValue ?? 1.0,
            servingUnit: unit ?? "serving",
            servingSizeGrams: servingValue,
            calories: extract("calories") ?? 0,
            protein: extract("protein") ?? 0,
            carbohydrates: extract("carbohydrate") ?? 0,
            fat: extract("total fat") ?? 0,
            fiber: extract("fiber"),
            sugar: extract("total sugars"),
            saturatedFat: extract("saturated fat"),
            unsaturatedFat: nil,
            transFat: nil,
            sodium: extract("sodium"),
            potassium: extract("potassium"),
            calcium: extract("calcium"),
            iron: extract("iron"),
            vitaminA: nil,
            vitaminC: extract("vitamin c"),
            vitaminD: extract("vitamin d"),
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
            source: .manual,
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: nil
        )
    }
}

// MARK: - Food Row View

struct FoodRowView: View {
    let food: Food

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                    .lineLimit(1)

                if let brand = food.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("\(Int(food.calories)) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(food.servingSize.formatted()) \(food.servingUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
struct FoodListView_Previews: PreviewProvider {
    static var previews: some View {
        FoodListView()
    }
}
#endif