//
//  ImageProcessorTests.swift
//  NutritionTrackerV2Tests
//
//  Unit tests for ImageProcessor functionality
//

import XCTest
import UIKit
@testable import NutritionTrackerV2

@MainActor
final class ImageProcessorTests: XCTestCase {

    var imageProcessor: ImageProcessor!

    override func setUp() {
        super.setUp()
        imageProcessor = ImageProcessor()
    }

    override func tearDown() {
        imageProcessor = nil
        super.tearDown()
    }

    // MARK: - Image Processing Tests

    func testProcessImageForUpload_Success() throws {
        // Given
        let testImage = createTestImageWithScale1(size: CGSize(width: 1600, height: 1200))
        let targetSize = CGSize(width: 800, height: 600)

        // When
        let result = try imageProcessor.processImageForUpload(
            testImage,
            targetSize: targetSize,
            compressionQuality: 0.8,
            maintainAspectRatio: true
        )

        // Then
        XCTAssertNotNil(result.processedImage)

        // For aspect-fit scaling, at least one dimension should be at the target size limit
        // and both dimensions should be within the bounds
        let fitsWithinBounds = result.processedSize.width <= targetSize.width &&
                              result.processedSize.height <= targetSize.height
        XCTAssertTrue(fitsWithinBounds, "Processed size \(result.processedSize) should fit within target \(targetSize)")

        // With aspect ratio 1600:1200 = 4:3, and target 800:600 = 4:3, should exactly match target
        let aspectRatioMatches = abs(result.processedSize.width / result.processedSize.height - 4.0/3.0) < 0.1
        XCTAssertTrue(aspectRatioMatches, "Should maintain aspect ratio")
        XCTAssertGreaterThan(result.compressionRatio, 0)
        XCTAssertTrue(result.appliedOperations.contains("resize"))
        XCTAssertTrue(result.appliedOperations.contains("compress"))
        XCTAssertGreaterThan(result.processingTime, 0)
    }

    func testProcessImageForUpload_SmallImage() throws {
        // Given
        let testImage = createTestImageWithScale1(size: CGSize(width: 400, height: 300))
        let targetSize = CGSize(width: 800, height: 600)

        // When
        let result = try imageProcessor.processImageForUpload(
            testImage,
            targetSize: targetSize,
            compressionQuality: 0.8,
            maintainAspectRatio: true
        )

        // Then
        XCTAssertNotNil(result.processedImage)
        XCTAssertEqual(result.originalSize, CGSize(width: 400, height: 300))
        // Small image should not be resized up
        XCTAssertEqual(result.processedSize.width, 400)
        XCTAssertEqual(result.processedSize.height, 300)
        XCTAssertFalse(result.appliedOperations.contains("resize"))
    }

    func testProcessImageForUpload_AspectRatioMaintained() throws {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1600, height: 800)) // 2:1 aspect ratio
        let targetSize = CGSize(width: 800, height: 600)

        // When
        let result = try imageProcessor.processImageForUpload(
            testImage,
            targetSize: targetSize,
            compressionQuality: 0.8,
            maintainAspectRatio: true
        )

        // Then
        XCTAssertNotNil(result.processedImage)
        let processedAspectRatio = result.processedSize.width / result.processedSize.height
        let originalAspectRatio = result.originalSize.width / result.originalSize.height
        XCTAssertEqual(processedAspectRatio, originalAspectRatio, accuracy: 0.1)
    }

    func testProcessImageForUpload_InvalidImage() {
        // Given
        let invalidImage = UIImage() // Empty image

        // When & Then
        XCTAssertThrowsError(try imageProcessor.processImageForUpload(invalidImage)) { error in
            XCTAssertTrue(error is ImageProcessingError)
        }
    }

    // MARK: - Thumbnail Generation Tests

    func testGenerateThumbnail_Success() throws {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1600, height: 1200))

        // When
        let thumbnail = try imageProcessor.generateThumbnail(from: testImage)

        // Then
        XCTAssertNotNil(thumbnail)
        XCTAssertTrue(thumbnail.size.width <= ImageProcessingConfig.thumbnailWidth)
        XCTAssertTrue(thumbnail.size.height <= ImageProcessingConfig.thumbnailHeight)
    }

    // MARK: - Batch Processing Tests

    func testProcessImagesForUpload_MultipleImages() async throws {
        // Given
        let images = [
            createTestImage(size: CGSize(width: 1600, height: 1200)),
            createTestImage(size: CGSize(width: 1200, height: 1600)),
            createTestImage(size: CGSize(width: 800, height: 600))
        ]

        // When
        let results = try await imageProcessor.processImagesForUpload(images)

        // Then
        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertNotNil(result.processedImage)
            XCTAssertGreaterThan(result.processingTime, 0)
        }
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> UIImage {
        // Use default scale (maintains existing test behavior)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Add some detail to make it more realistic
            UIColor.white.setStroke()
            context.stroke(CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20))
        }
    }

    private func createTestImageWithScale1(size: CGSize) -> UIImage {
        // Use scale 1.0 to ensure consistent test results regardless of device/simulator scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Add some detail to make it more realistic
            UIColor.white.setStroke()
            context.stroke(CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20))
        }
    }
}

// MARK: - Photo File Naming Tests

final class PhotoFileNamingTests: XCTestCase {

    func testGenerateUniqueFileName_ValidFormat() {
        // Given
        let userId = UUID()

        // When
        let fileName = PhotoFileNaming.generateUniqueFileName(for: userId)

        // Then
        XCTAssertTrue(fileName.hasPrefix("\(userId)/"))
        XCTAssertTrue(fileName.hasSuffix(".jpg"))
        XCTAssertTrue(fileName.contains("photo_"))
        XCTAssertTrue(PhotoFileNaming.isValidPhotoFileName(fileName))
    }

    func testGenerateUniqueFileName_CustomParameters() {
        // Given
        let userId = UUID()
        let prefix = "food"
        let fileExtension = "png"

        // When
        let fileName = PhotoFileNaming.generateUniqueFileName(
            for: userId,
            prefix: prefix,
            extension: fileExtension
        )

        // Then
        XCTAssertTrue(fileName.hasPrefix("\(userId)/"))
        XCTAssertTrue(fileName.hasSuffix(".png"))
        XCTAssertTrue(fileName.contains("food_"))
    }

    func testGenerateThumbnailFileName_Success() {
        // Given
        let originalFileName = "user-id/photo_123456789_uuid.jpg"

        // When
        let thumbnailFileName = PhotoFileNaming.generateThumbnailFileName(from: originalFileName)

        // Then
        XCTAssertTrue(thumbnailFileName.contains("_thumb"))
        XCTAssertTrue(thumbnailFileName.hasSuffix(".jpg"))
    }

    func testExtractUserIdFromFileName_Success() {
        // Given
        let userId = UUID()
        let fileName = "\(userId)/photo_123456789_uuid.jpg"

        // When
        let extractedUserId = PhotoFileNaming.extractUserIdFromFileName(fileName)

        // Then
        XCTAssertEqual(extractedUserId, userId)
    }

    func testExtractUserIdFromFileName_InvalidFormat() {
        // Given
        let invalidFileName = "invalid/format/file.jpg"

        // When
        let extractedUserId = PhotoFileNaming.extractUserIdFromFileName(invalidFileName)

        // Then
        XCTAssertNil(extractedUserId)
    }

    func testIsValidPhotoFileName_ValidNames() {
        // Given
        let validNames = [
            "550e8400-e29b-41d4-a716-446655440000/photo_1640995200_a1b2c3d4-e5f6-7890-1234-567890abcdef.jpg",
            "550e8400-e29b-41d4-a716-446655440000/food_1640995200_a1b2c3d4-e5f6-7890-1234-567890abcdef.png",
            "550e8400-e29b-41d4-a716-446655440000/image_1640995200_a1b2c3d4-e5f6-7890-1234-567890abcdef.heic"
        ]

        // When & Then
        for name in validNames {
            XCTAssertTrue(PhotoFileNaming.isValidPhotoFileName(name), "Should be valid: \(name)")
        }
    }

    func testIsValidPhotoFileName_InvalidNames() {
        // Given
        let invalidNames = [
            "invalid-format.jpg",
            "no-uuid/file.jpg",
            "550e8400/photo_123.jpg", // Missing full UUID
            "550e8400-e29b-41d4-a716-446655440000/photo.jpg" // Missing timestamp and UUID
        ]

        // When & Then
        for name in invalidNames {
            XCTAssertFalse(PhotoFileNaming.isValidPhotoFileName(name), "Should be invalid: \(name)")
        }
    }

    func testGenerateUserPhotoPath_Success() {
        // Given
        let userId = UUID()

        // When
        let path = PhotoFileNaming.generateUserPhotoPath(for: userId)

        // Then
        XCTAssertEqual(path, "\(userId)/")
    }
}
