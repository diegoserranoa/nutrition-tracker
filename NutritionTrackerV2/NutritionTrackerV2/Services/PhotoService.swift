//
//  PhotoService.swift
//  NutritionTrackerV2
//
//  Photo service layer for upload and download operations with Supabase Storage
//

import Foundation
import UIKit
import Supabase
import OSLog

// MARK: - Photo Upload Progress

struct PhotoUploadProgress {
    let bytesUploaded: Int64
    let totalBytes: Int64
    let percentage: Double

    init(bytesUploaded: Int64, totalBytes: Int64) {
        self.bytesUploaded = bytesUploaded
        self.totalBytes = totalBytes
        self.percentage = totalBytes > 0 ? Double(bytesUploaded) / Double(totalBytes) * 100 : 0
    }
}

// MARK: - Photo Upload Result

struct PhotoUploadResult {
    let publicURL: String
    let fileName: String
    let fileSize: Int64
    let contentType: String
    let uploadedAt: Date

    init(publicURL: String, fileName: String, fileSize: Int64, contentType: String) {
        self.publicURL = publicURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.contentType = contentType
        self.uploadedAt = Date()
    }
}

// MARK: - Photo Service Protocol

protocol PhotoServiceProtocol {
    func uploadPhoto(_ image: UIImage,
                    compressionQuality: CGFloat,
                    progressHandler: ((PhotoUploadProgress) -> Void)?) async throws -> PhotoUploadResult
    func downloadPhoto(from url: String) async throws -> UIImage
    func deletePhoto(fileName: String) async throws
    func getPhotoURL(fileName: String) throws -> String
}

// MARK: - Photo Service Implementation

@MainActor
class PhotoService: ObservableObject, PhotoServiceProtocol {

    // MARK: - Properties

    private let supabaseManager: SupabaseManager
    private let logger = Logger(subsystem: "com.nutritiontracker.photoservice", category: "PhotoService")
    private let bucketName = "food-photos"

    // Published properties for UI updates
    @Published var isUploading = false
    @Published var uploadProgress: PhotoUploadProgress?
    @Published var currentError: DataServiceError?

    // Configuration
    private struct Config {
        static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
        static let defaultCompressionQuality: CGFloat = 0.8
        static let supportedFormats = ["image/jpeg", "image/png", "image/heic", "image/webp"]
        static let uploadTimeout: TimeInterval = 60.0
    }

    // MARK: - Initialization

    init(supabaseManager: SupabaseManager = SupabaseManager.shared) {
        self.supabaseManager = supabaseManager
        logger.info("PhotoService initialized")
    }

    // MARK: - Photo Upload

    func uploadPhoto(_ image: UIImage,
                    compressionQuality: CGFloat = Config.defaultCompressionQuality,
                    progressHandler: ((PhotoUploadProgress) -> Void)? = nil) async throws -> PhotoUploadResult {

        logger.info("Starting photo upload with compression quality: \(compressionQuality)")

        // Set loading state
        isUploading = true
        currentError = nil
        uploadProgress = nil

        defer {
            isUploading = false
            uploadProgress = nil
        }

        do {
            // Validate authentication
            guard supabaseManager.isAuthenticated,
                  let currentUser = supabaseManager.currentUser else {
                throw DataServiceError.authenticationRequired
            }

            // Prepare image data
            let imageData = try prepareImageData(image, compressionQuality: compressionQuality)

            // Validate file size
            try validateFileSize(imageData.count)

            // Generate unique filename
            let fileName = generateFileName(for: currentUser.id)

            // Create progress tracking
            let totalBytes = Int64(imageData.count)
            let initialProgress = PhotoUploadProgress(bytesUploaded: 0, totalBytes: totalBytes)
            uploadProgress = initialProgress
            progressHandler?(initialProgress)

            // Upload to Supabase Storage
            let publicURL = try await performUpload(
                data: imageData,
                fileName: fileName,
                contentType: "image/jpeg"
            )

            // Final progress update
            let finalProgress = PhotoUploadProgress(bytesUploaded: totalBytes, totalBytes: totalBytes)
            uploadProgress = finalProgress
            progressHandler?(finalProgress)

            let result = PhotoUploadResult(
                publicURL: publicURL,
                fileName: fileName,
                fileSize: Int64(imageData.count),
                contentType: "image/jpeg"
            )

            logger.info("Photo upload completed successfully: \(fileName)")
            return result

        } catch let error as DataServiceError {
            currentError = error
            logger.error("Photo upload failed with DataServiceError: \(error.localizedDescription)")
            throw error
        } catch {
            let serviceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = serviceError
            logger.error("Photo upload failed with unexpected error: \(error.localizedDescription)")
            throw serviceError
        }
    }

    // MARK: - Photo Download

    func downloadPhoto(from url: String) async throws -> UIImage {
        logger.info("Starting photo download from URL: \(url)")

        currentError = nil

        do {
            guard let downloadURL = URL(string: url) else {
                throw DataServiceError.invalidData("Invalid photo URL format")
            }

            let (data, response) = try await URLSession.shared.data(from: downloadURL)

            // Validate HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                guard 200...299 ~= httpResponse.statusCode else {
                    throw DataServiceErrorFactory.fromHTTPStatusCode(httpResponse.statusCode, message: "Failed to download photo")
                }
            }

            // Validate data
            guard !data.isEmpty else {
                throw DataServiceError.missingResponseData
            }

            // Create image from data
            guard let image = UIImage(data: data) else {
                throw DataServiceError.invalidData("Unable to create image from downloaded data")
            }

            logger.info("Photo download completed successfully")
            return image

        } catch let error as DataServiceError {
            currentError = error
            logger.error("Photo download failed with DataServiceError: \(error.localizedDescription)")
            throw error
        } catch {
            let serviceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = serviceError
            logger.error("Photo download failed with unexpected error: \(error.localizedDescription)")
            throw serviceError
        }
    }

    // MARK: - Photo Deletion

    func deletePhoto(fileName: String) async throws {
        logger.info("Starting photo deletion: \(fileName)")

        currentError = nil

        do {
            // Validate authentication
            guard supabaseManager.isAuthenticated else {
                throw DataServiceError.authenticationRequired
            }

            // Delete from Supabase Storage
            try await supabaseManager.storage
                .from(bucketName)
                .remove(paths: [fileName])

            logger.info("Photo deletion completed successfully: \(fileName)")

        } catch let error as DataServiceError {
            currentError = error
            logger.error("Photo deletion failed with DataServiceError: \(error.localizedDescription)")
            throw error
        } catch {
            let serviceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = serviceError
            logger.error("Photo deletion failed with unexpected error: \(error.localizedDescription)")
            throw serviceError
        }
    }

    // MARK: - Get Photo URL

    func getPhotoURL(fileName: String) throws -> String {
        do {
            return try supabaseManager.getPublicURL(bucket: bucketName, path: fileName)
        } catch {
            throw DataServiceErrorFactory.fromSupabaseError(error)
        }
    }

    // MARK: - Private Helper Methods

    private func prepareImageData(_ image: UIImage, compressionQuality: CGFloat) throws -> Data {
        // Convert to JPEG with specified compression
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw DataServiceError.jsonEncodingFailed("Failed to convert image to JPEG data")
        }

        return imageData
    }

    private func validateFileSize(_ size: Int) throws {
        guard size <= Config.maxFileSize else {
            let maxSizeMB = Config.maxFileSize / (1024 * 1024)
            throw DataServiceError.valueTooLarge(field: "fileSize", max: Double(maxSizeMB))
        }
    }

    private func generateFileName(for userId: UUID) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomId = UUID().uuidString.prefix(8)
        return "\(userId)/\(timestamp)_\(randomId).jpg"
    }

    private func performUpload(data: Data, fileName: String, contentType: String) async throws -> String {
        return try await supabaseManager.uploadFile(
            bucket: bucketName,
            path: fileName,
            data: data,
            contentType: contentType
        )
    }
}

// MARK: - Singleton Access

extension PhotoService {
    static let shared = PhotoService()
}