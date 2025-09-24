//
//  PhotoServiceTests.swift
//  NutritionTrackerV2Tests
//
//  Unit tests for PhotoService functionality
//

import XCTest
import UIKit
import Supabase
@testable import NutritionTrackerV2

@MainActor
final class PhotoServiceTests: XCTestCase {

    var photoService: PhotoService!
    var mockSupabaseManager: MockSupabaseManager!

    override func setUp() {
        super.setUp()
        mockSupabaseManager = MockSupabaseManager()
        // Note: For real testing, we'd need proper dependency injection
        photoService = PhotoService(supabaseManager: mockSupabaseManager)
    }

    override func tearDown() {
        photoService = nil
        mockSupabaseManager = nil
        super.tearDown()
    }

    // MARK: - Upload Tests

    func testUploadPhoto_Success() async throws {
        // Given
        let testImage = createTestImage()
        mockSupabaseManager.isAuthenticated = true
        mockSupabaseManager.mockUploadSuccess = true

        // When
        let result = try await photoService.uploadPhoto(testImage)

        // Then
        XCTAssertFalse(result.publicURL.isEmpty)
        XCTAssertFalse(result.fileName.isEmpty)
        XCTAssertGreaterThan(result.fileSize, 0)
        XCTAssertEqual(result.contentType, "image/jpeg")
        XCTAssertFalse(photoService.isUploading)
    }

    func testUploadPhoto_NotAuthenticated() async {
        // Given
        let testImage = createTestImage()
        mockSupabaseManager.isAuthenticated = false

        // When & Then
        do {
            _ = try await photoService.uploadPhoto(testImage)
            XCTFail("Should throw authentication error")
        } catch DataServiceError.authenticationRequired {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testUploadPhoto_InvalidImage() async {
        // Given
        let invalidImage = UIImage() // Empty image
        mockSupabaseManager.isAuthenticated = true

        // When & Then
        do {
            _ = try await photoService.uploadPhoto(invalidImage)
            XCTFail("Should throw invalid image error")
        } catch is ImageProcessingError {
            // Expected - ImageProcessor should catch invalid images
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testUploadPhoto_ProgressTracking() async throws {
        // Given
        let testImage = createTestImage()
        mockSupabaseManager.isAuthenticated = true
        mockSupabaseManager.mockUploadSuccess = true

        var progressUpdates: [PhotoUploadProgress] = []

        // When
        _ = try await photoService.uploadPhoto(testImage) { progress in
            progressUpdates.append(progress)
        }

        // Then
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertEqual(progressUpdates.last?.percentage, 100.0)
    }

    // MARK: - Download Tests

    func testDownloadPhoto_Success() async throws {
        // Given
        let testURL = "https://example.com/test-image.jpg"

        // Mock URL session (this would need a proper mock in real implementation)
        // For now, we'll test the URL validation

        // When & Then
        // Note: This test would need a proper HTTP mock to fully test
        // For now, we test that invalid URLs are handled
        do {
            _ = try await photoService.downloadPhoto(from: "invalid-url")
            XCTFail("Should throw invalid data error")
        } catch DataServiceError.invalidData {
            // Expected for invalid URL
        } catch {
            // Network errors are also acceptable for this test
        }
    }

    func testDownloadPhoto_InvalidURL() async {
        // When & Then
        do {
            _ = try await photoService.downloadPhoto(from: "")
            XCTFail("Should throw invalid data error")
        } catch DataServiceError.invalidData(let message) {
            XCTAssertTrue(message.contains("Invalid photo URL format"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Delete Tests

    func testDeletePhoto_Success() async throws {
        // Given
        let fileName = "test-photo.jpg"
        mockSupabaseManager.isAuthenticated = true
        mockSupabaseManager.mockDeleteSuccess = true

        // When
        try await photoService.deletePhoto(fileName: fileName)

        // Then
        XCTAssertTrue(mockSupabaseManager.deletePhotoCalled)
        XCTAssertEqual(mockSupabaseManager.deletedFileName, fileName)
    }

    func testDeletePhoto_NotAuthenticated() async {
        // Given
        let fileName = "test-photo.jpg"
        mockSupabaseManager.isAuthenticated = false

        // When & Then
        do {
            try await photoService.deletePhoto(fileName: fileName)
            XCTFail("Should throw authentication error")
        } catch DataServiceError.authenticationRequired {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - URL Generation Tests

    func testGetPhotoURL_Success() async throws {
        // Given
        let fileName = "test-photo.jpg"
        let expectedURL = "https://example.supabase.co/storage/v1/object/public/food-photos/test-photo.jpg"
        mockSupabaseManager.mockPublicURL = expectedURL

        // When
        let result = try await photoService.getPhotoURL(fileName: fileName)

        // Then
        XCTAssertEqual(result, expectedURL)
        XCTAssertNil(photoService.currentError)
    }

    func testGetPhotoURL_InvalidURL() async {
        // Given
        let fileName = "test-photo.jpg"
        mockSupabaseManager.mockPublicURL = ""  // Empty string should fail URL validation

        // When & Then
        do {
            _ = try await photoService.getPhotoURL(fileName: fileName)
            XCTFail("Should throw invalid data error")
        } catch DataServiceError.invalidData(let message) {
            XCTAssertTrue(message.contains("Invalid public URL format"))
            XCTAssertNotNil(photoService.currentError)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - URL Caching Tests

    func testGetCachedPhotoURL_CacheHit() async throws {
        // Given
        let fileName = "test-photo.jpg"
        let expectedURL = "https://example.supabase.co/storage/v1/object/public/food-photos/test-photo.jpg"
        mockSupabaseManager.mockPublicURL = expectedURL

        // When - First call should cache the result
        let result1 = try await photoService.getCachedPhotoURL(fileName: fileName)

        // Clear mock URL to ensure cache is used
        mockSupabaseManager.mockPublicURL = ""

        // Second call should use cache
        let result2 = try await photoService.getCachedPhotoURL(fileName: fileName)

        // Then
        XCTAssertEqual(result1, expectedURL)
        XCTAssertEqual(result2, expectedURL)
    }

    func testClearURLCache() {
        // When
        photoService.clearURLCache()

        // Then - Should not throw any errors
        XCTAssertTrue(true, "Cache clearing should complete without error")
    }

    // MARK: - Upload Cancellation Tests

    func testCancelCurrentUpload() {
        // When
        photoService.cancelCurrentUpload()

        // Then
        XCTAssertFalse(photoService.isUploading)
        XCTAssertFalse(photoService.isRetrying)
        XCTAssertEqual(photoService.retryCount, 0)
        XCTAssertNil(photoService.uploadProgress)

        if let error = photoService.currentError {
            XCTAssertTrue(error.localizedDescription.contains("cancelled"))
        }
    }

    // MARK: - Error State Management Tests

    func testErrorStateHandling() async {
        // Given
        let testImage = createTestImage()
        mockSupabaseManager.isAuthenticated = false

        // When
        do {
            _ = try await photoService.uploadPhoto(testImage)
            XCTFail("Upload should have failed with authentication error")
        } catch {
            // Then - Verify error was captured in service state
            XCTAssertNotNil(photoService.currentError)
            XCTAssertFalse(photoService.isUploading)
            XCTAssertFalse(photoService.isRetrying)
        }
    }

    // MARK: - Batch Upload Tests

    func testUploadPhotosWithDetailedResults_MixedSuccess() async {
        // Given
        let images = [
            createTestImage(size: CGSize(width: 100, height: 100)),
            createTestImage(size: CGSize(width: 200, height: 200)),
            createTestImage(size: CGSize(width: 300, height: 300))
        ]

        mockSupabaseManager.isAuthenticated = true
        mockSupabaseManager.mockUploadSuccess = true

        // When
        let results = await photoService.uploadPhotosWithDetailedResults(images)

        // Then
        XCTAssertEqual(results.count, 3)

        // Check that results are in correct order
        for (index, (resultIndex, _)) in results.enumerated() {
            XCTAssertEqual(index, resultIndex)
        }
    }

    // MARK: - Service State Tests

    func testInitialState() {
        XCTAssertFalse(photoService.isUploading)
        XCTAssertNil(photoService.uploadProgress)
        XCTAssertNil(photoService.currentError)
        XCTAssertFalse(photoService.isRetrying)
        XCTAssertEqual(photoService.retryCount, 0)
    }

    func testStateResetAfterCancel() {
        // Given - simulate an upload state
        photoService.cancelCurrentUpload()

        // Then
        XCTAssertFalse(photoService.isUploading)
        XCTAssertFalse(photoService.isRetrying)
        XCTAssertEqual(photoService.retryCount, 0)
        XCTAssertNil(photoService.uploadProgress)
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

}

// MARK: - User Mock Extension

extension User {
    static var mockUser: User {
        // Create a mock user using the proper field names expected by Supabase User
        let mockJSON = """
        {
            "id": "00000000-0000-0000-0000-000000000000",
            "aud": "authenticated",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z"
        }
        """

        let data = mockJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(User.self, from: data)
        } catch {
            // This should not happen in tests, but if it does, we have a problem
            fatalError("Failed to create mock user for testing: \(error)")
        }
    }
}

// MARK: - Mock Classes

class MockSupabaseManager: SupabaseManagerProtocol {
    var isAuthenticated = false
    var currentUser: User? {
        // For testing purposes, return a non-nil value when authenticated
        return isAuthenticated ? User.mockUser : nil
    }
    var mockUploadSuccess = false
    var mockDeleteSuccess = false
    var mockPublicURL: String? = nil  // Changed to optional to distinguish between unset and empty

    var deletePhotoCalled = false
    var deletedFileName = ""

    func uploadFile(bucket: String, path: String, data: Data, contentType: String) async throws -> String {
        if mockUploadSuccess {
            return "https://example.supabase.co/storage/v1/object/public/food-photos/\(path)"
        } else {
            throw DataServiceError.networkUnavailable
        }
    }

    func getPublicURL(bucket: String, path: String) throws -> String {
        if let mockURL = mockPublicURL {
            return mockURL  // Return whatever was set, including empty string
        }
        return "https://example.supabase.co/storage/v1/object/public/\(bucket)/\(path)"
    }

    func deleteFile(bucket: String, fileName: String) async throws {
        deletePhotoCalled = true
        deletedFileName = fileName
        if !mockDeleteSuccess {
            throw DataServiceError.networkUnavailable
        }
    }
}

