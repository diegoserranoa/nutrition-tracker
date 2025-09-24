//
//  ImageProcessor.swift
//  NutritionTrackerV2
//
//  Image processing utilities for compression, resizing, and optimization
//

import UIKit
import OSLog

// MARK: - Image Processing Configuration

struct ImageProcessingConfig {
    static let standardWidth: CGFloat = 800
    static let standardHeight: CGFloat = 600
    static let thumbnailWidth: CGFloat = 300
    static let thumbnailHeight: CGFloat = 225
    static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
    static let defaultCompressionQuality: CGFloat = 0.8
    static let highQualityCompression: CGFloat = 0.9
    static let lowQualityCompression: CGFloat = 0.6
}

// MARK: - Image Processing Result

struct ImageProcessingResult {
    let processedImage: UIImage
    let originalSize: CGSize
    let processedSize: CGSize
    let compressionRatio: Double
    let fileSizeBytes: Int
    let processingTime: TimeInterval
    let appliedOperations: [String]

    var compressionPercent: Double {
        return (1.0 - compressionRatio) * 100
    }
}

// MARK: - Image Processing Errors

enum ImageProcessingError: Error, LocalizedError {
    case invalidImage
    case resizingFailed
    case compressionFailed
    case fileSizeTooLarge(current: Int64, max: Int64)
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid or corrupted image"
        case .resizingFailed:
            return "Failed to resize image"
        case .compressionFailed:
            return "Failed to compress image"
        case .fileSizeTooLarge(let current, let max):
            return "File size (\(current / 1024 / 1024)MB) exceeds maximum allowed (\(max / 1024 / 1024)MB)"
        case .unsupportedFormat:
            return "Unsupported image format"
        }
    }
}

// MARK: - Image Processor

class ImageProcessor {
    private let logger = Logger(subsystem: "com.nutritiontracker.imageprocessor", category: "ImageProcessor")

    // MARK: - Main Processing Method

    func processImageForUpload(
        _ image: UIImage,
        targetSize: CGSize = CGSize(width: ImageProcessingConfig.standardWidth,
                                   height: ImageProcessingConfig.standardHeight),
        compressionQuality: CGFloat = ImageProcessingConfig.defaultCompressionQuality,
        maintainAspectRatio: Bool = true
    ) throws -> ImageProcessingResult {

        let startTime = Date()
        var appliedOperations: [String] = []

        logger.info("Starting image processing - Original size: \(image.size.width)x\(image.size.height)")

        // Validate input image
        guard image.cgImage != nil else {
            throw ImageProcessingError.invalidImage
        }

        // Step 1: Resize image if needed
        var processedImage = image
        let originalSize = image.size

        if shouldResize(image, targetSize: targetSize) {
            processedImage = try resizeImage(processedImage,
                                           targetSize: targetSize,
                                           maintainAspectRatio: maintainAspectRatio)
            appliedOperations.append("resize")
            logger.info("Image resized to: \(processedImage.size.width)x\(processedImage.size.height)")
        }

        // Step 2: Optimize orientation
        processedImage = normalizeImageOrientation(processedImage)
        appliedOperations.append("normalize_orientation")

        // Step 3: Apply compression and get data
        let processedData = try compressImage(processedImage, quality: compressionQuality)
        appliedOperations.append("compress")

        // Step 4: Validate final file size
        try validateFileSize(Int64(processedData.count))

        // Step 5: Create final image from compressed data (to get accurate size)
        guard let finalImage = UIImage(data: processedData) else {
            throw ImageProcessingError.compressionFailed
        }

        let processingTime = Date().timeIntervalSince(startTime)
        let compressionRatio = Double(processedData.count) / Double(estimateUncompressedSize(originalSize))

        logger.info("Image processing completed in \(processingTime)s - Final size: \(processedData.count) bytes")

        return ImageProcessingResult(
            processedImage: finalImage,
            originalSize: originalSize,
            processedSize: finalImage.size,
            compressionRatio: compressionRatio,
            fileSizeBytes: processedData.count,
            processingTime: processingTime,
            appliedOperations: appliedOperations
        )
    }

    // MARK: - Thumbnail Generation

    func generateThumbnail(
        from image: UIImage,
        size: CGSize = CGSize(width: ImageProcessingConfig.thumbnailWidth,
                             height: ImageProcessingConfig.thumbnailHeight)
    ) throws -> UIImage {
        return try resizeImage(image, targetSize: size, maintainAspectRatio: true)
    }

    // MARK: - Batch Processing

    func processImagesForUpload(_ images: [UIImage],
                               targetSize: CGSize? = nil,
                               compressionQuality: CGFloat? = nil) async throws -> [ImageProcessingResult] {
        let finalTargetSize = targetSize ?? CGSize(width: ImageProcessingConfig.standardWidth,
                                                  height: ImageProcessingConfig.standardHeight)
        let finalQuality = compressionQuality ?? ImageProcessingConfig.defaultCompressionQuality

        return try await withThrowingTaskGroup(of: ImageProcessingResult.self) { group in
            // Add tasks for each image
            for image in images {
                group.addTask {
                    return try self.processImageForUpload(image,
                                                        targetSize: finalTargetSize,
                                                        compressionQuality: finalQuality)
                }
            }

            // Collect results
            var results: [ImageProcessingResult] = []
            for try await result in group {
                results.append(result)
            }

            return results
        }
    }

    // MARK: - Private Helper Methods

    private func shouldResize(_ image: UIImage, targetSize: CGSize) -> Bool {
        let imageSize = image.size
        return imageSize.width > targetSize.width || imageSize.height > targetSize.height
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize, maintainAspectRatio: Bool) throws -> UIImage {
        let finalSize: CGSize

        if maintainAspectRatio {
            finalSize = calculateAspectFitSize(originalSize: image.size, targetSize: targetSize)
        } else {
            finalSize = targetSize
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: finalSize, format: format)

        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: finalSize))
        }

        guard resizedImage.cgImage != nil else {
            throw ImageProcessingError.resizingFailed
        }

        return resizedImage
    }

    private func calculateAspectFitSize(originalSize: CGSize, targetSize: CGSize) -> CGSize {
        let aspectRatio = originalSize.width / originalSize.height
        let targetAspectRatio = targetSize.width / targetSize.height

        if aspectRatio > targetAspectRatio {
            // Image is wider - fit by width
            let newWidth = targetSize.width
            let newHeight = newWidth / aspectRatio
            return CGSize(width: newWidth, height: newHeight)
        } else {
            // Image is taller - fit by height
            let newHeight = targetSize.height
            let newWidth = newHeight * aspectRatio
            return CGSize(width: newWidth, height: newHeight)
        }
    }

    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        // If image is already in correct orientation, return as-is
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: image.size))

        guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image // Return original if normalization fails
        }

        return normalizedImage
    }

    private func compressImage(_ image: UIImage, quality: CGFloat) throws -> Data {
        guard let imageData = image.jpegData(compressionQuality: quality) else {
            throw ImageProcessingError.compressionFailed
        }
        return imageData
    }

    private func validateFileSize(_ size: Int64) throws {
        guard size <= ImageProcessingConfig.maxFileSize else {
            throw ImageProcessingError.fileSizeTooLarge(current: size, max: ImageProcessingConfig.maxFileSize)
        }
    }

    private func estimateUncompressedSize(_ imageSize: CGSize) -> Int {
        // Estimate uncompressed size (RGBA: 4 bytes per pixel)
        return Int(imageSize.width * imageSize.height * 4)
    }
}

// MARK: - File Naming Utility

struct PhotoFileNaming {

    // MARK: - File Naming Methods

    static func generateUniqueFileName(for userId: UUID,
                                     prefix: String = "photo",
                                     extension: String = "jpg") -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.lowercased()
        return "\(userId)/\(prefix)_\(timestamp)_\(uuid).\(`extension`)"
    }

    static func generateThumbnailFileName(from originalFileName: String) -> String {
        let components = originalFileName.split(separator: ".")
        guard components.count >= 2 else {
            return "thumb_\(originalFileName)"
        }

        let nameWithoutExtension = components.dropLast().joined(separator: ".")
        let fileExtension = components.last!
        return "\(nameWithoutExtension)_thumb.\(fileExtension)"
    }

    static func extractUserIdFromFileName(_ fileName: String) -> UUID? {
        let components = fileName.split(separator: "/")
        guard let userIdString = components.first,
              let userId = UUID(uuidString: String(userIdString)) else {
            return nil
        }
        return userId
    }

    // MARK: - Path Utilities

    static func generateUserPhotoPath(for userId: UUID) -> String {
        return "\(userId)/"
    }

    static func isValidPhotoFileName(_ fileName: String) -> Bool {
        let pattern = #"^[a-fA-F0-9\-]{36}/\w+_\d+_[a-fA-F0-9\-]{36}\.(jpg|jpeg|png|heic|webp)$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: fileName.utf16.count)
        return regex?.firstMatch(in: fileName, options: [], range: range) != nil
    }
}