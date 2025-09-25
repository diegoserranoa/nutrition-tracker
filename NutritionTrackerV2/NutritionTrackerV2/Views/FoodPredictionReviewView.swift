//
//  FoodPredictionReviewView.swift
//  NutritionTrackerV2
//
//  Interface for reviewing and confirming ML food recognition predictions
//

import SwiftUI

struct FoodPredictionReviewView: View {
    let capturedImage: UIImage
    let predictedFood: String
    let confidence: Double
    let showConfidence: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingImageDetail = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Image preview section
                imagePreviewSection
                    .background(Color(.systemGray6))

                // Prediction details section
                predictionDetailsSection

                Spacer()

                // Action buttons
                actionButtonsSection
            }
            .navigationTitle("Review Prediction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showingImageDetail) {
            imageDetailView
        }
    }

    // MARK: - Image Preview Section

    private var imagePreviewSection: some View {
        VStack(spacing: 12) {
            Text("Captured Image")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top)

            Button(action: {
                showingImageDetail = true
            }) {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Text("Tap image to view full size")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.bottom)
        }
        .padding(.horizontal)
    }

    // MARK: - Prediction Details Section

    private var predictionDetailsSection: some View {
        VStack(spacing: 16) {
            Divider()

            VStack(spacing: 12) {
                // Prediction result
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Prediction")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(predictedFood.capitalized)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    Spacer()
                }

                // Confidence indicator
                if showConfidence {
                    confidenceIndicator
                }

                // Helpful text
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)

                        Text("Review the prediction")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                    }

                    Text("Does this look correct? You can accept the prediction, try again, or select the food manually.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemBlue).opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            Divider()
        }
    }

    private var confidenceIndicator: some View {
        HStack {
            Image(systemName: confidenceIconName)
                .foregroundColor(confidenceColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(confidenceText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(confidenceColor)
            }

            Spacer()

            // Confidence progress bar
            ProgressView(value: confidence, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
                .frame(width: 80)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(confidenceColor.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary action buttons
            HStack(spacing: 16) {
                // Accept button
                Button(action: onAccept) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)

                        Text("Accept")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Reject button
                Button(action: onReject) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)

                        Text("Not Correct")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // Secondary action button
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)

                    Text("Try Again")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -1)
    }

    // MARK: - Image Detail View

    private var imageDetailView: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Captured Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingImageDetail = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var confidenceIconName: String {
        if confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if confidence >= 0.6 {
            return "questionmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
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

    private var confidenceText: String {
        let percentage = Int(confidence * 100)
        if confidence >= 0.8 {
            return "\(percentage)% - High"
        } else if confidence >= 0.6 {
            return "\(percentage)% - Medium"
        } else {
            return "\(percentage)% - Low"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FoodPredictionReviewView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // High confidence preview
            FoodPredictionReviewView(
                capturedImage: UIImage(systemName: "photo") ?? UIImage(),
                predictedFood: "grilled chicken breast",
                confidence: 0.89,
                showConfidence: true,
                onAccept: { print("Accepted") },
                onReject: { print("Rejected") },
                onRetry: { print("Retry") },
                onCancel: { print("Cancel") }
            )
            .previewDisplayName("High Confidence")

            // Low confidence preview
            FoodPredictionReviewView(
                capturedImage: UIImage(systemName: "photo") ?? UIImage(),
                predictedFood: "vegetable stir fry",
                confidence: 0.45,
                showConfidence: true,
                onAccept: { print("Accepted") },
                onReject: { print("Rejected") },
                onRetry: { print("Retry") },
                onCancel: { print("Cancel") }
            )
            .previewDisplayName("Low Confidence")

            // Without confidence display
            FoodPredictionReviewView(
                capturedImage: UIImage(systemName: "photo") ?? UIImage(),
                predictedFood: "pizza margherita",
                confidence: 0.75,
                showConfidence: false,
                onAccept: { print("Accepted") },
                onReject: { print("Rejected") },
                onRetry: { print("Retry") },
                onCancel: { print("Cancel") }
            )
            .previewDisplayName("No Confidence")
        }
    }
}
#endif