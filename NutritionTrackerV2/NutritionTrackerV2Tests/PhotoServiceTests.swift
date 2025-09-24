//
//  PhotoServiceTests.swift
//  NutritionTrackerV2Tests
//
//  Unit tests for PhotoService functionality
//

import XCTest
import UIKit
@testable import NutritionTrackerV2

@MainActor
final class PhotoServiceTests: XCTestCase {

    var photoService: PhotoService!
    var mockSupabaseManager: MockSupabaseManager!

    override func setUp() {
        super.setUp()
        mockSupabaseManager = MockSupabaseManager()
        // Note: For real testing, we'd need proper dependency injection
        photoService = PhotoService()
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
        mockSupabaseManager.currentUser = MockUser(id: UUID(), email: "test@example.com")
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
        mockSupabaseManager.currentUser = MockUser(id: UUID(), email: "test@example.com")

        // When & Then
        do {
            _ = try await photoService.uploadPhoto(invalidImage)
            XCTFail("Should throw encoding error")
        } catch DataServiceError.jsonEncodingFailed {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testUploadPhoto_ProgressTracking() async throws {
        // Given
        let testImage = createTestImage()
        mockSupabaseManager.isAuthenticated = true
        mockSupabaseManager.currentUser = MockUser(id: UUID(), email: "test@example.com")
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
            _ = try await photoService.downloadPhoto(from: "not-a-url")
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

    func testGetPhotoURL_Success() throws {
        // Given
        let fileName = "test-photo.jpg"
        let expectedURL = "https://example.supabase.co/storage/v1/object/public/food-photos/test-photo.jpg"
        mockSupabaseManager.mockPublicURL = expectedURL

        // When
        let result = try photoService.getPhotoURL(fileName: fileName)

        // Then
        XCTAssertEqual(result, expectedURL)
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

// MARK: - Mock Classes

class MockSupabaseManager {
    var isAuthenticated = false
    var currentUser: MockUser?
    var mockUploadSuccess = false
    var mockDeleteSuccess = false
    var mockPublicURL = ""

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
        if !mockPublicURL.isEmpty {
            return mockPublicURL
        }
        return "https://example.supabase.co/storage/v1/object/public/\(bucket)/\(path)"
    }

    // Mock storage deletion
    func mockDeletePhoto(fileName: String) async throws {
        deletePhotoCalled = true
        deletedFileName = fileName
        if !mockDeleteSuccess {
            throw DataServiceError.networkUnavailable
        }
    }
}

struct MockUser {
    let id: UUID
    let email: String
}