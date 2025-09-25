//
//  NutritionLabelScannerView.swift
//  NutritionTrackerV2
//
//  SwiftUI interface for scanning nutrition labels using OCR
//

import SwiftUI
import Vision

struct NutritionLabelScannerView: View {
    let onTextRecognized: (OCRResult) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var ocr = NutritionLabelOCR(config: .nutritionLabel)
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var ocrResult: OCRResult?
    @State private var errorMessage: String?
    @State private var showingImagePicker = false
    @State private var processingProgress: Double = 0.0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header section
                headerSection

                // Main content based on state
                ScrollView {
                    VStack(spacing: 20) {
                        if let image = capturedImage {
                            capturedImageSection(image)
                        } else {
                            instructionsSection
                        }

                        if let error = errorMessage {
                            errorSection(error)
                        }

                        if let result = ocrResult {
                            ocrResultSection(result)
                        }
                    }
                    .padding()
                }

                // Action buttons
                actionButtonsSection
            }
            .navigationTitle("Scan Nutrition Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if ocrResult != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Use Results") {
                            if let result = ocrResult {
                                onTextRecognized(result)
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(capturedImage: .constant(nil)) { image in
                capturedImage = image
                processImage()
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(image: $capturedImage, onImagePicked: {
                if capturedImage != nil {
                    processImage()
                }
            })
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("Nutrition Label OCR")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)

            if isProcessing {
                ProgressView("Processing image...", value: processingProgress, total: 1.0)
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

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Text("Scan Nutrition Label")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Take a clear photo of a nutrition facts label to automatically extract nutritional information")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Tips section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("Tips for best results:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        tipRow("Good lighting and focus")
                        tipRow("Hold camera steady")
                        tipRow("Fill frame with label")
                        tipRow("Avoid glare and shadows")
                    }
                    .padding(.leading, 24)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Captured Image Section

    private func capturedImageSection(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Text("Captured Image")
                .font(.headline)

            Button(action: {
                // Show full screen image
            }) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            if !isProcessing && ocrResult == nil {
                Button("Process Image") {
                    processImage()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - OCR Result Section

    private func ocrResultSection(_ result: OCRResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Text Recognition Complete")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Found \(result.recognizedTexts.count) text items in \(String(format: "%.2f", result.processingTime))s")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Recognized text preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Recognized Text:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(result.recognizedTexts.enumerated()), id: \.offset) { index, textItem in
                            textItemRow(textItem, index: index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Full text preview
            if !result.fullText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Combined Text:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(result.fullText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func textItemRow(_ textItem: (text: String, confidence: Float, boundingBox: CGRect), index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(textItem.text)
                    .font(.subheadline)
                    .lineLimit(1)

                Text("Confidence: \(Int(textItem.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(confidenceColor(for: textItem.confidence))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 2)
    }

    private func confidenceColor(for confidence: Float) -> Color {
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Error Section

    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Recognition Failed")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                retryProcessing()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if capturedImage == nil {
                HStack(spacing: 16) {
                    Button("Take Photo") {
                        showingCamera = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)

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
            } else {
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
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -1)
    }

    // MARK: - Helper Methods

    private func processImage() {
        guard let image = capturedImage else { return }

        isProcessing = true
        errorMessage = nil
        ocrResult = nil
        processingProgress = 0.0

        // Simulate progress for better UX
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            processingProgress += 0.1
            if processingProgress >= 1.0 || !isProcessing {
                timer.invalidate()
                processingProgress = 1.0
            }
        }

        Task {
            do {
                let result = try await ocr.recognizeText(in: image, timeout: 30.0)
                await MainActor.run {
                    self.ocrResult = result
                    self.isProcessing = false
                    self.processingProgress = 1.0
                    print("✅ OCR completed: \(result.recognizedTexts.count) items found")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                    self.processingProgress = 0.0
                    print("❌ OCR failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func retryProcessing() {
        errorMessage = nil
        if capturedImage != nil {
            processImage()
        }
    }

    private func resetScanner() {
        capturedImage = nil
        ocrResult = nil
        errorMessage = nil
        isProcessing = false
        processingProgress = 0.0
        showingCamera = true
    }
}

// MARK: - Image Picker View

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onImagePicked: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
                parent.onImagePicked()
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NutritionLabelScannerView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionLabelScannerView { result in
            print("OCR Result: \(result.recognizedTexts.count) items")
        }
    }
}
#endif