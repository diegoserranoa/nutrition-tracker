//
//  NutritionLabelScanView.swift
//  NutritionTrackerV2
//
//  Enhanced nutrition label scanning interface with full OCR + parsing pipeline
//

import SwiftUI
import UIKit

struct NutritionLabelScanView: View {
    let onNutritionExtracted: (NutritionExtractionResult) -> Void
    let onFoodCreated: ((Food) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @StateObject private var extractionService = NutritionExtractionService()
    @StateObject private var cameraManager = CameraManager()

    @State private var scanningStage: ScanningStage = .instructions
    @State private var capturedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingImageReview = false
    @State private var showingFullScreenImage = false
    @State private var showingCorrectionView = false

    init(onNutritionExtracted: @escaping (NutritionExtractionResult) -> Void, onFoodCreated: ((Food) -> Void)? = nil) {
        self.onNutritionExtracted = onNutritionExtracted
        self.onFoodCreated = onFoodCreated
    }

    // MARK: - Scanning Stages

    enum ScanningStage {
        case instructions
        case camera
        case imageReview
        case processing
        case results
        case error
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // Main content based on scanning stage
                VStack(spacing: 0) {
                    // Header with progress
                    headerSection

                    // Main content area
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            switch scanningStage {
                            case .instructions:
                                instructionsSection
                            case .camera:
                                cameraSection
                            case .imageReview:
                                imageReviewSection
                            case .processing:
                                processingSection
                            case .results:
                                resultsSection
                            case .error:
                                errorSection
                            }
                        }
                        .padding()
                    }

                    // Bottom action buttons
                    actionButtonsSection
                }
            }
            .navigationTitle("Nutrition Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        extractionService.cancelExtraction()
                        dismiss()
                    }
                }

                if scanningStage == .results, let result = extractionService.lastResult, result.hasUsableData {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Use Results") {
                            onNutritionExtracted(result)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(capturedImage: $capturedImage) { image in
                capturedImage = image
                scanningStage = .imageReview
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(image: $capturedImage, onImagePicked: {
                if capturedImage != nil {
                    scanningStage = .imageReview
                }
            })
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let image = capturedImage {
                FullScreenImageView(image: image, isPresented: $showingFullScreenImage)
            }
        }
        .sheet(isPresented: $showingCorrectionView) {
            if let result = extractionService.lastResult {
                OCRNutritionCorrectionView(
                    extractionResult: result,
                    onSave: { food in
                        onFoodCreated?(food)
                        showingCorrectionView = false
                        dismiss() // Go back to Dashboard
                    },
                    onCancel: {
                        showingCorrectionView = false
                    }
                )
            }
        }
        .onChange(of: extractionService.isProcessing) { oldValue, isProcessing in
            if isProcessing {
                scanningStage = .processing
            }
        }
        .onChange(of: extractionService.lastResult) { oldValue, result in
            if result != nil && !extractionService.isProcessing {
                scanningStage = .results
            }
        }
        .onChange(of: extractionService.isProcessing) { oldValue, isProcessing in
            // Handle error state when processing stops without a result
            if !isProcessing && extractionService.lastResult == nil && extractionService.lastError != nil {
                scanningStage = .error
            }
        }
        .onAppear {
            cameraManager.requestPermission()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                // Stage indicator
                HStack(spacing: 8) {
                    Image(systemName: stageIcon)
                        .font(.title2)
                        .foregroundColor(stageColor)
                        .symbolEffect(.pulse, isActive: extractionService.isProcessing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stageTitle)
                            .font(.headline)
                            .fontWeight(.semibold)

                        if !stageSubtitle.isEmpty {
                            Text(stageSubtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Processing indicator
                if extractionService.isProcessing {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("\(Int(extractionService.processingProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            // Processing progress bar
            if extractionService.isProcessing {
                VStack(spacing: 8) {
                    ProgressView(value: extractionService.processingProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                    Text(extractionService.processingStage.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // Extraction service status (if available)
            if scanningStage == .results || scanningStage == .processing {
                NutritionExtractionStatusView(service: extractionService)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(spacing: 32) {
            // Main icon and title
            VStack(spacing: 16) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Scan Nutrition Label")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Description
            Text("Capture a photo of a nutrition facts label to automatically extract and parse nutritional information with confidence scoring.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Nutrition label frame guide
            NutritionLabelFrameGuide()

            // Tips section
            TipsSection()

            // Feature highlights
            VStack(spacing: 16) {
                FeatureHighlight(
                    icon: "camera.viewfinder",
                    title: "Smart Camera Capture",
                    description: "Optimized for nutrition label recognition"
                )

                FeatureHighlight(
                    icon: "text.magnifyingglass",
                    title: "Advanced OCR Processing",
                    description: "Extract text with high accuracy and confidence"
                )

                FeatureHighlight(
                    icon: "brain.head.profile",
                    title: "Intelligent Parsing",
                    description: "Parse calories, macros, and micronutrients automatically"
                )

                FeatureHighlight(
                    icon: "checkmark.seal.fill",
                    title: "Confidence Scoring",
                    description: "Get reliability scores for extracted data"
                )
            }
        }
    }

    // MARK: - Camera Section

    private var cameraSection: some View {
        VStack(spacing: 24) {
            Text("Position the nutrition label within the frame")
                .font(.headline)
                .multilineTextAlignment(.center)

            // Camera preview would go here
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.1))
                .frame(height: 300)
                .overlay(
                    VStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Camera Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
    }

    // MARK: - Image Review Section

    private var imageReviewSection: some View {
        VStack(spacing: 24) {
            if let image = capturedImage {
                VStack(spacing: 16) {
                    Text("Review Captured Image")
                        .font(.headline)

                    Button(action: { showingFullScreenImage = true }) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    Text("Tap image to view full screen")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Button("Retake") {
                            capturedImage = nil
                            scanningStage = .instructions
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                        Button("Process Image") {
                            processImage()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    // MARK: - Processing Section

    private var processingSection: some View {
        VStack(spacing: 24) {
            // Processing animation
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()

                Text("Processing Nutrition Label")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(extractionService.processingStage.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Progress details
            VStack(spacing: 12) {
                ProgressView(value: extractionService.processingProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                Text("\(Int(extractionService.processingProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Scanned image preview during processing
            if let image = capturedImage {
                VStack(spacing: 8) {
                    Text("Processing Image")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Button(action: { showingFullScreenImage = true }) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Processing steps
            ProcessingStepsView(currentStage: extractionService.processingStage)

            // Cancel processing button
            Button("Cancel Processing") {
                extractionService.cancelExtraction()
                scanningStage = .imageReview
            }
            .font(.subheadline)
            .foregroundColor(.red)
            .padding(.top)
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 24) {
            if let result = extractionService.lastResult {
                // Success header
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(result.successRating.color)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extraction Complete")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(result.successRating.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Scanned image preview
                if let image = capturedImage {
                    ScannedImagePreviewCard(image: image, onTapToExpand: { showingFullScreenImage = true })
                }

                // Nutrition data preview
                NutritionDataPreviewCard(result: result)

                // Extraction metrics
                ExtractionMetricsCard(metrics: result.extractionMetrics)

                // Recommendations (if any)
                if !result.recommendations.isEmpty {
                    RecommendationsCard(recommendations: result.recommendations)
                }

                // Action buttons
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button("Scan Another") {
                            resetScanner()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                        Button("Review & Edit") {
                            showingCorrectionView = true
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }

                    if result.hasUsableData {
                        Button("Use Raw Data") {
                            onNutritionExtracted(result)
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    // MARK: - Error Section

    private var errorSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            VStack(spacing: 12) {
                Text("Processing Failed")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let error = extractionService.lastError {
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            // Show the image that failed to process
            if let image = capturedImage {
                VStack(spacing: 8) {
                    Text("Failed to Process")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Button(action: { showingFullScreenImage = true }) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            VStack(spacing: 12) {
                Button("Try Again") {
                    if capturedImage != nil {
                        processImage()
                    } else {
                        scanningStage = .instructions
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)

                Button("Scan Different Label") {
                    resetScanner()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            switch scanningStage {
            case .instructions:
                HStack(spacing: 16) {
                    Button("Take Photo") {
                        showingCamera = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(cameraManager.isAuthorized ? Color.blue : Color.gray)
                    .cornerRadius(12)
                    .disabled(!cameraManager.isAuthorized)

                    Button("Choose Photo") {
                        showingImagePicker = true
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

            case .imageReview, .results, .error:
                EmptyView() // Buttons are handled in content sections

            case .processing:
                EmptyView() // No buttons during processing

            case .camera:
                Button("Cancel") {
                    scanningStage = .instructions
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -1)
    }

    // MARK: - Computed Properties

    private var stageIcon: String {
        switch scanningStage {
        case .instructions:
            return "text.viewfinder"
        case .camera:
            return "camera.viewfinder"
        case .imageReview:
            return "photo"
        case .processing:
            return "gearshape.2.fill"
        case .results:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var stageColor: Color {
        switch scanningStage {
        case .instructions, .camera, .imageReview:
            return .blue
        case .processing:
            return .orange
        case .results:
            return extractionService.lastResult?.successRating.color ?? .green
        case .error:
            return .red
        }
    }

    private var stageTitle: String {
        switch scanningStage {
        case .instructions:
            return "Ready to Scan"
        case .camera:
            return "Position Label"
        case .imageReview:
            return "Review Image"
        case .processing:
            return "Processing"
        case .results:
            return "Extraction Complete"
        case .error:
            return "Processing Failed"
        }
    }

    private var stageSubtitle: String {
        switch scanningStage {
        case .instructions:
            return "Take or choose a photo to begin"
        case .camera:
            return "Center nutrition label in frame"
        case .imageReview:
            return "Verify image quality before processing"
        case .processing:
            return extractionService.processingStage.description
        case .results:
            if let result = extractionService.lastResult {
                return result.summary
            }
            return ""
        case .error:
            return "Tap 'Try Again' to retry"
        }
    }

    // MARK: - Helper Methods

    private func processImage() {
        guard let image = capturedImage else { return }

        extractionService.clearResults()

        Task {
            let _ = await extractionService.extractNutrition(from: image)
        }
    }

    private func resetScanner() {
        capturedImage = nil
        extractionService.clearResults()
        scanningStage = .instructions
    }
}

// MARK: - Supporting Views

struct NutritionLabelFrameGuide: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Ideal Framing")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundColor(.blue)
                .frame(width: 200, height: 120)
                .overlay(
                    VStack(spacing: 4) {
                        Text("NUTRITION FACTS")
                            .font(.caption2)
                            .fontWeight(.bold)

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Serving Size 1 cup")
                                .font(.caption2)
                            Text("Calories 250")
                                .font(.caption2)
                                .fontWeight(.semibold)
                            Text("Total Fat 12g")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .foregroundColor(.primary)
                )

            Text("Fill most of the frame with the nutrition label")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text("Tips for Best Results:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 6) {
                TipRow(icon: "sun.max.fill", text: "Good, even lighting", color: .yellow)
                TipRow(icon: "camera.fill", text: "Hold camera steady", color: .blue)
                TipRow(icon: "viewfinder", text: "Fill frame with label", color: .green)
                TipRow(icon: "eye.slash.fill", text: "Avoid glare and shadows", color: .purple)
                TipRow(icon: "textformat", text: "Ensure text is readable", color: .primary)
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ProcessingStepsView: View {
    let currentStage: NutritionExtractionService.ProcessingStage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processing Steps:")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(spacing: 4) {
                ProcessingStepRow(
                    title: "Image Quality Check",
                    isActive: currentStage == .imageQualityCheck,
                    isComplete: isStageComplete(.imageQualityCheck)
                )

                ProcessingStepRow(
                    title: "Text Recognition (OCR)",
                    isActive: currentStage == .ocrProcessing,
                    isComplete: isStageComplete(.ocrProcessing)
                )

                ProcessingStepRow(
                    title: "Nutrition Parsing",
                    isActive: currentStage == .textParsing,
                    isComplete: isStageComplete(.textParsing)
                )

                ProcessingStepRow(
                    title: "Generating Recommendations",
                    isActive: currentStage == .generatingRecommendations,
                    isComplete: isStageComplete(.generatingRecommendations)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func isStageComplete(_ stage: NutritionExtractionService.ProcessingStage) -> Bool {
        let stages: [NutritionExtractionService.ProcessingStage] = [
            .imageQualityCheck, .ocrProcessing, .textParsing, .generatingRecommendations, .completed
        ]

        guard let currentIndex = stages.firstIndex(of: currentStage),
              let stageIndex = stages.firstIndex(of: stage) else {
            return false
        }

        return currentIndex > stageIndex
    }
}

struct ProcessingStepRow: View {
    let title: String
    let isActive: Bool
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
            .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundColor(isActive ? .primary : (isComplete ? .green : .secondary))

            Spacer()
        }
    }
}

struct ScannedImagePreviewCard: View {
    let image: UIImage
    let onTapToExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("Scanned Image")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: onTapToExpand) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                        Text("Expand")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }

            Button(action: onTapToExpand) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            Text("Tap image to view full screen")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct NutritionDataPreviewCard: View {
    let result: NutritionExtractionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Extracted Nutrition Data")
                .font(.headline)
                .fontWeight(.semibold)

            let nutrition = result.parsedNutrition

            // Basic nutrition info
            if let calories = nutrition.calories {
                ScanNutrientRow(
                    name: "Calories",
                    value: "\(Int(calories.value))",
                    unit: "",
                    confidence: Float(calories.confidence)
                )
            }

            // Macronutrients
            if let protein = nutrition.macronutrients.protein {
                ScanNutrientRow(
                    name: "Protein",
                    value: String(format: "%.1f", protein.value),
                    unit: protein.unit,
                    confidence: Float(protein.confidence)
                )
            }

            if let carbs = nutrition.macronutrients.carbohydrates {
                ScanNutrientRow(
                    name: "Carbohydrates",
                    value: String(format: "%.1f", carbs.value),
                    unit: carbs.unit,
                    confidence: Float(carbs.confidence)
                )
            }

            if let fat = nutrition.macronutrients.fat {
                ScanNutrientRow(
                    name: "Total Fat",
                    value: String(format: "%.1f", fat.value),
                    unit: fat.unit,
                    confidence: Float(fat.confidence)
                )
            }

            // Extended macronutrients
            if let saturatedFat = nutrition.macronutrients.saturatedFat {
                ScanNutrientRow(
                    name: "Saturated Fat",
                    value: String(format: "%.1f", saturatedFat.value),
                    unit: saturatedFat.unit,
                    confidence: Float(saturatedFat.confidence)
                )
            }

            if let transFat = nutrition.macronutrients.transFat {
                ScanNutrientRow(
                    name: "Trans Fat",
                    value: String(format: "%.1f", transFat.value),
                    unit: transFat.unit,
                    confidence: Float(transFat.confidence)
                )
            }

            if let fiber = nutrition.macronutrients.fiber {
                ScanNutrientRow(
                    name: "Dietary Fiber",
                    value: String(format: "%.1f", fiber.value),
                    unit: fiber.unit,
                    confidence: Float(fiber.confidence)
                )
            }

            if let sugar = nutrition.macronutrients.sugar {
                ScanNutrientRow(
                    name: "Total Sugars",
                    value: String(format: "%.1f", sugar.value),
                    unit: sugar.unit,
                    confidence: Float(sugar.confidence)
                )
            }

            // Micronutrients
            if let sodium = nutrition.micronutrients.sodium {
                ScanNutrientRow(
                    name: "Sodium",
                    value: String(format: "%.0f", sodium.value),
                    unit: sodium.unit,
                    confidence: Float(sodium.confidence)
                )
            }

            if let cholesterol = nutrition.micronutrients.cholesterol {
                ScanNutrientRow(
                    name: "Cholesterol",
                    value: String(format: "%.0f", cholesterol.value),
                    unit: cholesterol.unit,
                    confidence: Float(cholesterol.confidence)
                )
            }

            if let potassium = nutrition.micronutrients.potassium {
                ScanNutrientRow(
                    name: "Potassium",
                    value: String(format: "%.0f", potassium.value),
                    unit: potassium.unit,
                    confidence: Float(potassium.confidence)
                )
            }

            if let calcium = nutrition.micronutrients.calcium {
                ScanNutrientRow(
                    name: "Calcium",
                    value: String(format: "%.0f", calcium.value),
                    unit: calcium.unit,
                    confidence: Float(calcium.confidence)
                )
            }

            if let iron = nutrition.micronutrients.iron {
                ScanNutrientRow(
                    name: "Iron",
                    value: String(format: "%.1f", iron.value),
                    unit: iron.unit,
                    confidence: Float(iron.confidence)
                )
            }

            // Vitamins
            if let vitaminA = nutrition.micronutrients.vitaminA {
                ScanNutrientRow(
                    name: "Vitamin A",
                    value: String(format: "%.0f", vitaminA.value),
                    unit: vitaminA.unit,
                    confidence: Float(vitaminA.confidence)
                )
            }

            if let vitaminC = nutrition.micronutrients.vitaminC {
                ScanNutrientRow(
                    name: "Vitamin C",
                    value: String(format: "%.0f", vitaminC.value),
                    unit: vitaminC.unit,
                    confidence: Float(vitaminC.confidence)
                )
            }

            if let vitaminD = nutrition.micronutrients.vitaminD {
                ScanNutrientRow(
                    name: "Vitamin D",
                    value: String(format: "%.1f", vitaminD.value),
                    unit: vitaminD.unit,
                    confidence: Float(vitaminD.confidence)
                )
            }

            // Serving size
            if let serving = nutrition.servingInfo {
                Divider()

                HStack {
                    Text("Serving Size:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(String(format: "%.1f", serving.size)) \(serving.unit)")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ScanNutrientRow: View {
    let name: String
    let value: String
    let unit: String
    let confidence: Float

    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
                Text("\(value) \(unit)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Circle()
                    .fill(confidenceColor)
                    .frame(width: 8, height: 8)
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

struct ExtractionMetricsCard: View {
    let metrics: ExtractionMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Metrics")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                MetricRow(
                    label: "Total Time",
                    value: String(format: "%.2fs", metrics.totalProcessingTime)
                )

                MetricRow(
                    label: "OCR Accuracy",
                    value: String(format: "%.1f%%", metrics.textRecognitionAccuracy * 100)
                )

                MetricRow(
                    label: "Parsing Accuracy",
                    value: String(format: "%.1f%%", metrics.nutritionParsingAccuracy * 100)
                )

                MetricRow(
                    label: "Image Quality",
                    value: String(format: "%.1f%%", metrics.imageQualityScore * 100)
                )

                Divider()

                HStack {
                    Text("Overall Efficiency")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(metrics.efficiency.description)
                        .font(.subheadline)
                        .foregroundColor(efficiencyColor(metrics.efficiency))
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func efficiencyColor(_ efficiency: ExtractionMetrics.ExtractionEfficiency) -> Color {
        switch efficiency {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .acceptable:
            return .orange
        case .poor:
            return .red
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct RecommendationsCard: View {
    let recommendations: [ExtractionRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { _, recommendation in
                    RecommendationRow(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct RecommendationRow: View {
    let recommendation: ExtractionRecommendation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: priorityIcon)
                .foregroundColor(priorityColor)
                .font(.caption)
                .frame(width: 16)

            Text(recommendation.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.vertical, 2)
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

struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
            }
            .navigationTitle("Captured Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NutritionLabelScanView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionLabelScanView(
            onNutritionExtracted: { result in
                print("Nutrition extracted: \(result.summary)")
            },
            onFoodCreated: { food in
                print("Food created: \(food.name)")
            }
        )
    }
}
#endif
