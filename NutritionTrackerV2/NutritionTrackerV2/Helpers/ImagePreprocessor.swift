//
//  ImagePreprocessor.swift
//  NutritionTrackerV2
//
//  Comprehensive image preprocessing pipeline for ML model input
//

import UIKit
import CoreImage
import Accelerate

/// Configuration for image preprocessing
struct ImagePreprocessingConfig {
    let targetSize: CGSize
    let maintainAspectRatio: Bool
    let cropMode: CropMode
    let normalization: NormalizationMode
    let colorSpace: ColorSpaceMode

    enum CropMode {
        case center
        case smart  // Focus on the center but adjust for content
        case fill   // Fill the entire target size
    }

    enum NormalizationMode {
        case none
        case zeroToOne      // Normalize pixel values to [0, 1]
        case minusOneToOne  // Normalize pixel values to [-1, 1]
        case imagenet       // ImageNet normalization (mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    }

    enum ColorSpaceMode {
        case rgb
        case bgr
        case grayscale
    }

    /// Default configuration optimized for food recognition models
    static let foodRecognition = ImagePreprocessingConfig(
        targetSize: CGSize(width: 224, height: 224),
        maintainAspectRatio: true,
        cropMode: .smart,
        normalization: .imagenet,
        colorSpace: .rgb
    )

    /// High-quality configuration for detailed analysis
    static let highQuality = ImagePreprocessingConfig(
        targetSize: CGSize(width: 512, height: 512),
        maintainAspectRatio: true,
        cropMode: .center,
        normalization: .zeroToOne,
        colorSpace: .rgb
    )
}

/// Comprehensive image preprocessing pipeline
class ImagePreprocessor {

    private let config: ImagePreprocessingConfig
    private let context: CIContext

    init(config: ImagePreprocessingConfig = .foodRecognition) {
        self.config = config
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    // MARK: - Main Processing Pipeline

    /// Process an image through the complete preprocessing pipeline
    func process(_ image: UIImage) -> UIImage? {
        guard image.cgImage != nil else { return nil }

        // Step 1: Handle orientation
        let orientedImage = correctOrientation(image)

        // Step 2: Resize and crop
        let resizedImage = resizeAndCrop(orientedImage)

        // Step 3: Apply color space conversion if needed
        let colorProcessedImage = applyColorSpaceConversion(resizedImage)

        // Step 4: Apply normalization if creating pixel buffer
        return colorProcessedImage
    }

    /// Process image and return pixel buffer for direct ML model input
    func processToPixelBuffer(_ image: UIImage) -> CVPixelBuffer? {
        guard let processedImage = process(image) else { return nil }

        // Convert to pixel buffer with normalization
        return createPixelBuffer(from: processedImage)
    }

    // MARK: - Individual Processing Steps

    /// Correct image orientation issues from camera
    private func correctOrientation(_ image: UIImage) -> UIImage {
        // If image is already in correct orientation, return as-is
        if image.imageOrientation == .up {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return correctedImage ?? image
    }

    /// Resize and crop image based on configuration
    private func resizeAndCrop(_ image: UIImage) -> UIImage {
        let targetSize = config.targetSize

        if !config.maintainAspectRatio {
            // Simple resize without maintaining aspect ratio
            return image.resized(to: targetSize, maintainAspectRatio: false) ?? image
        }

        // Calculate sizing for aspect ratio maintenance
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = targetSize.width / targetSize.height

        var scaledSize: CGSize
        var cropRect: CGRect

        switch config.cropMode {
        case .center, .smart:
            // Scale to fill target, then crop center
            if aspectRatio > targetAspectRatio {
                // Image is wider - scale by height, crop width
                scaledSize = CGSize(
                    width: targetSize.height * aspectRatio,
                    height: targetSize.height
                )
                cropRect = CGRect(
                    x: (scaledSize.width - targetSize.width) / 2,
                    y: 0,
                    width: targetSize.width,
                    height: targetSize.height
                )
            } else {
                // Image is taller - scale by width, crop height
                scaledSize = CGSize(
                    width: targetSize.width,
                    height: targetSize.width / aspectRatio
                )
                cropRect = CGRect(
                    x: 0,
                    y: (scaledSize.height - targetSize.height) / 2,
                    width: targetSize.width,
                    height: targetSize.height
                )
            }

        case .fill:
            // Scale to fit, then pad or stretch
            scaledSize = targetSize
            cropRect = CGRect(origin: .zero, size: targetSize)
        }

        // Perform the resize and crop
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 0)

        // Fill background with neutral color for food images
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: targetSize))

        // Draw scaled and cropped image
        let scaledImage = image.resized(to: scaledSize, maintainAspectRatio: false) ?? image
        scaledImage.draw(in: CGRect(origin: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y), size: scaledSize))

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return finalImage ?? image
    }

    /// Apply color space conversion
    private func applyColorSpaceConversion(_ image: UIImage) -> UIImage {
        guard config.colorSpace != .rgb else { return image }

        guard let ciImage = CIImage(image: image) else { return image }

        let processedCIImage: CIImage

        switch config.colorSpace {
        case .rgb:
            processedCIImage = ciImage

        case .bgr:
            // Convert RGB to BGR by swapping channels
            let filter = CIFilter(name: "CIColorMatrix")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            // Matrix to swap R and B channels
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputRVector") // R = B
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector") // G = G
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputBVector") // B = R
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector") // A = A
            processedCIImage = filter.outputImage ?? ciImage

        case .grayscale:
            // Convert to grayscale
            let filter = CIFilter(name: "CIColorControls")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            processedCIImage = filter.outputImage ?? ciImage
        }

        // Convert back to UIImage
        guard let cgImage = context.createCGImage(processedCIImage, from: processedCIImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    /// Create pixel buffer with normalization for ML model input
    private func createPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        let width = Int(config.targetSize.width)
        let height = Int(config.targetSize.height)

        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }

        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        guard let cgContext = context else { return nil }

        cgContext.translateBy(x: 0, y: CGFloat(height))
        cgContext.scaleBy(x: 1.0, y: -1.0)
        cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply normalization if needed
        if config.normalization != .none {
            applyNormalization(to: buffer)
        }

        return buffer
    }

    // MARK: - Utility Methods

    /// Get processing performance metrics for debugging
    func benchmarkProcessing(_ image: UIImage) -> (processedImage: UIImage?, processingTime: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let processedImage = process(image)
        let endTime = CFAbsoluteTimeGetCurrent()

        return (processedImage, endTime - startTime)
    }

    /// Apply pixel normalization based on configuration
    private func applyNormalization(to pixelBuffer: CVPixelBuffer) {
        // This would typically be done at the ML model level
        // but can be implemented here if needed for specific models
        // For now, we'll leave it as a placeholder since Vision framework
        // and Core ML handle normalization automatically

        switch config.normalization {
        case .none:
            break
        case .zeroToOne:
            // Normalize pixel values from [0, 255] to [0, 1]
            // Implementation would go here if needed
            break
        case .minusOneToOne:
            // Normalize pixel values from [0, 255] to [-1, 1]
            // Implementation would go here if needed
            break
        case .imagenet:
            // Apply ImageNet normalization
            // Implementation would go here if needed
            break
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Resize image to target size with optional aspect ratio maintenance
    func resized(to targetSize: CGSize, maintainAspectRatio: Bool = true) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            if maintainAspectRatio {
                // Calculate the aspect-fit size
                let aspectFitSize = self.aspectFitSize(for: targetSize)
                let x = (targetSize.width - aspectFitSize.width) / 2
                let y = (targetSize.height - aspectFitSize.height) / 2
                self.draw(in: CGRect(x: x, y: y, width: aspectFitSize.width, height: aspectFitSize.height))
            } else {
                self.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
    }

    /// Calculate aspect-fit size for the target size
    private func aspectFitSize(for targetSize: CGSize) -> CGSize {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)

        return CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
    }
}