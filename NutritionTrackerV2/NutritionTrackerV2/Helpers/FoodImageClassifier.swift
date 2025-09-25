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

    init?() {
        do {
            let mlModel = try FoodClassifier(configuration: MLModelConfiguration()).model
            let coreMLModel = try VNCoreMLModel(for: mlModel)
            self.model = coreMLModel
        } catch {
            print("Failed to load FoodClassifier model: \(error)")
            return nil
        }
    }

    func classify(image: UIImage, completion: @escaping (String?) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(nil)
            return
        }

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
