//
//  FoodImageClassifier.swift
//  NutritionTracker
//
//  Created by Diego Serrano on 7/3/25.
//
import CoreML
import Vision
import UIKit

class FoodImageClassifier {
    private let model: VNCoreMLModel
    private let preprocessor: ImagePreprocessor

    init?() {
        do {
            let mlModel = try FoodClassifier(configuration: MLModelConfiguration()).model
            let coreMLModel = try VNCoreMLModel(for: mlModel)
            self.model = coreMLModel
            self.preprocessor = ImagePreprocessor(config: .foodRecognition)
        } catch {
            print("Failed to load FoodClassifier model: \(error)")
            return nil
        }
    }

    func classify(image: UIImage, completion: @escaping (String?) -> Void) {
        print("🔄 Starting food classification for image: \(image.size)")

        // Preprocess the image for optimal ML model input
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let processedImage = preprocessor.process(image),
              let ciImage = CIImage(image: processedImage) else {
            print("❌ Failed to preprocess image for classification")
            completion(nil)
            return
        }

        let preprocessTime = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ Image preprocessed in \(String(format: "%.3f", preprocessTime))s: \(processedImage.size)")

        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("Vision request error: \(error)")
                completion(nil)
                return
            }

            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else {
                print("No classification results found")
                completion(nil)
                return
            }

            print("Classification result: \(topResult.identifier) (confidence: \(topResult.confidence))")
            completion(topResult.identifier)
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform vision request: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
