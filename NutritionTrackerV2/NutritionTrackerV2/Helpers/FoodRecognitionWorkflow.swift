//
//  FoodRecognitionWorkflow.swift
//  NutritionTrackerV2
//
//  Complete workflow coordinator from camera capture to food logging with ML recognition
//

import SwiftUI
import UIKit

/// Configuration for the food recognition workflow
struct FoodRecognitionConfig {
    /// Minimum confidence threshold for automatic acceptance (0.0 to 1.0)
    let confidenceThreshold: Double
    /// Whether to show prediction confidence to user
    let showConfidenceScore: Bool
    /// Whether to allow manual fallback when confidence is low
    let allowManualFallback: Bool
    /// Timeout for ML prediction in seconds
    let predictionTimeout: TimeInterval

    static let `default` = FoodRecognitionConfig(
        confidenceThreshold: 0.7,
        showConfidenceScore: true,
        allowManualFallback: true,
        predictionTimeout: 10.0
    )

    static let strict = FoodRecognitionConfig(
        confidenceThreshold: 0.85,
        showConfidenceScore: true,
        allowManualFallback: true,
        predictionTimeout: 8.0
    )

    static let lenient = FoodRecognitionConfig(
        confidenceThreshold: 0.5,
        showConfidenceScore: false,
        allowManualFallback: true,
        predictionTimeout: 15.0
    )
}

/// Result of food recognition workflow
enum FoodRecognitionResult {
    case success(recognizedFood: String, confidence: Double, image: UIImage)
    case lowConfidence(recognizedFood: String?, confidence: Double?, image: UIImage)
    case failed(error: FoodRecognitionError, image: UIImage?)
    case cancelled
    case manualFallback(image: UIImage)
}

/// Errors that can occur during food recognition workflow
enum FoodRecognitionError: LocalizedError {
    case cameraPermissionDenied
    case imageCaptureError
    case imageProcessingError
    case mlModelError(String)
    case timeout
    case networkError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Camera permission is required to capture food photos"
        case .imageCaptureError:
            return "Failed to capture photo. Please try again"
        case .imageProcessingError:
            return "Failed to process the captured image"
        case .mlModelError(let detail):
            return "Food recognition failed: \(detail)"
        case .timeout:
            return "Food recognition timed out. Please try again"
        case .networkError:
            return "Network error occurred during recognition"
        case .unknown(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
}

/// Workflow state for UI updates
enum FoodRecognitionWorkflowState: Equatable {
    case idle
    case capturingImage
    case processingImage
    case recognizingFood
    case reviewingPrediction
    case selectingFoodManually
    case loggingFood
    case completed
    case error(FoodRecognitionError)

    static func == (lhs: FoodRecognitionWorkflowState, rhs: FoodRecognitionWorkflowState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.capturingImage, .capturingImage),
             (.processingImage, .processingImage), (.recognizingFood, .recognizingFood),
             (.reviewingPrediction, .reviewingPrediction), (.selectingFoodManually, .selectingFoodManually),
             (.loggingFood, .loggingFood), (.completed, .completed):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Main workflow coordinator class
@MainActor
class FoodRecognitionWorkflow: ObservableObject {

    // MARK: - Published Properties

    @Published var state: FoodRecognitionWorkflowState = .idle
    @Published var capturedImage: UIImage?
    @Published var recognitionResult: String?
    @Published var recognitionConfidence: Double = 0.0
    @Published var isProcessing: Bool = false

    // MARK: - Private Properties

    private let config: FoodRecognitionConfig
    private let classifier: FoodImageClassifier
    private var workflowCompletion: ((FoodRecognitionResult) -> Void)?
    private var processingStartTime: Date?

    // MARK: - Initialization

    init(config: FoodRecognitionConfig = .default) {
        self.config = config
        guard let classifier = FoodImageClassifier() else {
            fatalError("Failed to initialize FoodImageClassifier")
        }
        self.classifier = classifier
    }

    // MARK: - Public Methods

    /// Start the complete food recognition workflow
    func startWorkflow(completion: @escaping (FoodRecognitionResult) -> Void) {
        guard state == .idle else {
            completion(.failed(error: .unknown(NSError(domain: "WorkflowError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Workflow already in progress"])), image: nil))
            return
        }

        workflowCompletion = completion
        state = .capturingImage

        print("🚀 Starting food recognition workflow with config: threshold=\(config.confidenceThreshold)")
    }

    /// Process captured image through ML recognition
    func processImage(_ image: UIImage) {
        guard state == .capturingImage || state == .reviewingPrediction else { return }

        capturedImage = image
        state = .processingImage
        isProcessing = true
        processingStartTime = Date()

        print("📸 Processing captured image: \(image.size)")

        // Start ML recognition with timeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(config.predictionTimeout * 1_000_000_000))
            if !Task.isCancelled && isProcessing {
                handleRecognitionTimeout()
            }
        }

        Task {
            await performMLRecognition(image: image, timeoutTask: timeoutTask)
        }
    }

    /// Accept the ML prediction and proceed to logging
    func acceptPrediction() {
        guard state == .reviewingPrediction,
              let image = capturedImage,
              let foodName = recognitionResult else { return }

        state = .loggingFood
        let result = FoodRecognitionResult.success(
            recognizedFood: foodName,
            confidence: recognitionConfidence,
            image: image
        )
        finishWorkflow(with: result)
    }

    /// Reject the ML prediction and fall back to manual selection
    func rejectPrediction() {
        guard state == .reviewingPrediction,
              let image = capturedImage else { return }

        if config.allowManualFallback {
            state = .selectingFoodManually
            let result = FoodRecognitionResult.manualFallback(image: image)
            finishWorkflow(with: result)
        } else {
            // Restart workflow
            retryRecognition()
        }
    }

    /// Retry the recognition process with the same image
    func retryRecognition() {
        guard let image = capturedImage else { return }
        processImage(image)
    }

    /// Cancel the entire workflow
    func cancelWorkflow() {
        state = .idle
        isProcessing = false
        capturedImage = nil
        recognitionResult = nil
        recognitionConfidence = 0.0
        finishWorkflow(with: .cancelled)
    }

    // MARK: - Private Methods

    private func performMLRecognition(image: UIImage, timeoutTask: Task<Void, Error>) async {
        state = .recognizingFood

        await withCheckedContinuation { continuation in
            classifier.classify(image: image) { [weak self] result in
                Task { @MainActor in
                    timeoutTask.cancel()
                    self?.handleRecognitionResult(result, continuation: continuation)
                }
            }
        }
    }

    private func handleRecognitionResult(_ result: String?, continuation: CheckedContinuation<Void, Never>) {
        isProcessing = false
        let processingTime = processingStartTime?.timeIntervalSinceNow.magnitude ?? 0

        guard let foodName = result else {
            print("❌ ML recognition failed")
            state = .error(.mlModelError("No food detected in image"))
            finishWorkflow(with: .failed(error: .mlModelError("No food detected in image"), image: capturedImage))
            continuation.resume()
            return
        }

        // For demo purposes, we'll use a confidence based on food name patterns
        // In a real implementation, this would come from the ML model
        let confidence = calculateConfidence(for: foodName)
        recognitionResult = foodName
        recognitionConfidence = confidence

        print("✅ ML recognition completed in \(String(format: "%.2f", processingTime))s: \(foodName) (confidence: \(String(format: "%.2f", confidence)))")

        if confidence >= config.confidenceThreshold {
            // High confidence - proceed directly to logging
            state = .loggingFood
            guard let image = capturedImage else { return }
            finishWorkflow(with: .success(recognizedFood: foodName, confidence: confidence, image: image))
        } else {
            // Low confidence - show review interface
            state = .reviewingPrediction
            print("⚠️ Low confidence prediction, showing review interface")
        }

        continuation.resume()
    }

    private func handleRecognitionTimeout() {
        isProcessing = false
        state = .error(.timeout)
        print("⏰ ML recognition timed out after \(config.predictionTimeout)s")
        finishWorkflow(with: .failed(error: .timeout, image: capturedImage))
    }

    private func finishWorkflow(with result: FoodRecognitionResult) {
        let completion = workflowCompletion
        workflowCompletion = nil

        if case .completed = state {
            return // Already completed
        }

        if case .error = state {
            // Keep error state for UI
        } else {
            state = .completed
        }

        print("🏁 Food recognition workflow finished with result: \(result)")
        completion?(result)
    }

    /// Calculate confidence score based on food name (demo implementation)
    private func calculateConfidence(for foodName: String) -> Double {
        // This is a simplified confidence calculation for demo purposes
        // In a real ML model, confidence would come directly from the model

        let commonFoods = ["apple", "banana", "pizza", "burger", "salad", "chicken", "rice", "bread"]
        let lowercasedFood = foodName.lowercased()

        if commonFoods.contains(where: lowercasedFood.contains) {
            return Double.random(in: 0.75...0.95)
        } else {
            return Double.random(in: 0.45...0.75)
        }
    }
}

/// Extension for UI state helpers
extension FoodRecognitionWorkflow {

    var isIdle: Bool {
        switch state {
        case .idle:
            return true
        default:
            return false
        }
    }

    var showProgressIndicator: Bool {
        switch state {
        case .processingImage, .recognizingFood, .loggingFood:
            return true
        default:
            return false
        }
    }

    var progressMessage: String {
        switch state {
        case .idle:
            return "Ready to capture"
        case .capturingImage:
            return "Take a photo of your food"
        case .processingImage:
            return "Processing image..."
        case .recognizingFood:
            return "Recognizing food..."
        case .reviewingPrediction:
            return "Review prediction"
        case .selectingFoodManually:
            return "Select food manually"
        case .loggingFood:
            return "Logging food..."
        case .completed:
            return "Complete"
        case .error(let error):
            return error.localizedDescription
        }
    }

    var shouldShowPredictionReview: Bool {
        switch state {
        case .reviewingPrediction:
            return true
        default:
            return false
        }
    }

    var canRetry: Bool {
        switch state {
        case .error, .reviewingPrediction:
            return capturedImage != nil
        default:
            return false
        }
    }

    var showConfidenceToUser: Bool {
        return config.showConfidenceScore && recognitionConfidence > 0
    }

    var confidenceDescription: String {
        let percentage = Int(recognitionConfidence * 100)
        return "\(percentage)% confident"
    }

    var isHighConfidence: Bool {
        return recognitionConfidence >= config.confidenceThreshold
    }
}