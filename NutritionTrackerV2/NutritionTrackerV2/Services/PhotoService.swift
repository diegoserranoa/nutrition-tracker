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

// MARK: - Supabase Manager Protocol

protocol SupabaseManagerProtocol {
    var isAuthenticated: Bool { get async }
    var currentUser: User? { get async }
    var realtime: RealtimeClientV2 { get }

    func uploadFile(bucket: String, path: String, data: Data, contentType: String) async throws -> String
    func getPublicURL(bucket: String, path: String) throws -> String
    func deleteFile(bucket: String, fileName: String) async throws
}

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
                    targetSize: CGSize?,
                    maintainAspectRatio: Bool,
                    progressHandler: ((PhotoUploadProgress) -> Void)?) async throws -> PhotoUploadResult
    func downloadPhoto(from url: String) async throws -> UIImage
    func deletePhoto(fileName: String) async throws
    func getPhotoURL(fileName: String) async throws -> String
    func getCachedPhotoURL(fileName: String) async throws -> String
    func cancelCurrentUpload()
    func clearURLCache()
}

// MARK: - Photo Service Implementation

@MainActor
class PhotoService: ObservableObject, PhotoServiceProtocol {

    // MARK: - Properties

    nonisolated(unsafe) private let supabaseManager: SupabaseManagerProtocol
    private let logger = Logger(subsystem: "com.nutritiontracker.photoservice", category: "PhotoService")
    private let bucketName = "food-photos"

    // Published properties for UI updates
    @Published var isUploading = false
    @Published var uploadProgress: PhotoUploadProgress?
    @Published var currentError: DataServiceError?
    @Published var isRetrying = false
    @Published var retryCount = 0

    // Upload management
    private var currentUploadTask: Task<PhotoUploadResult, Error>?
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0

    // Dependencies
    nonisolated(unsafe) private let imageProcessor: ImageProcessor

    // Configuration
    private struct Config {
        static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
        static let defaultCompressionQuality: CGFloat = 0.8
        static let supportedFormats = ["image/jpeg", "image/png", "image/heic", "image/webp"]
        static let uploadTimeout: TimeInterval = 60.0
    }

    // MARK: - Initialization

    init(supabaseManager: SupabaseManagerProtocol,
         imageProcessor: ImageProcessor = ImageProcessor()) {
        self.supabaseManager = supabaseManager
        self.imageProcessor = imageProcessor
        logger.info("PhotoService initialized")
    }

    // MARK: - Photo Upload

    func uploadPhoto(_ image: UIImage,
                    compressionQuality: CGFloat = Config.defaultCompressionQuality,
                    targetSize: CGSize? = nil,
                    maintainAspectRatio: Bool = true,
                    progressHandler: ((PhotoUploadProgress) -> Void)? = nil) async throws -> PhotoUploadResult {

        logger.info("Starting photo upload with enhanced processing")

        // Set loading state
        isUploading = true
        currentError = nil
        uploadProgress = nil

        defer {
            isUploading = false
            uploadProgress = nil
        }

        do {
            return try await performUploadWithRetry(
                image: image,
                compressionQuality: compressionQuality,
                targetSize: targetSize,
                maintainAspectRatio: maintainAspectRatio,
                progressHandler: progressHandler
            )
        } catch let error as DataServiceError {
            currentError = error
            logger.error("Photo upload failed with DataServiceError: \(error.localizedDescription)")
            throw error
        } catch let error as ImageProcessingError {
            // Re-throw ImageProcessingError without conversion to preserve original error type
            logger.error("Photo upload failed with ImageProcessingError: \(error.localizedDescription)")
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
            guard await supabaseManager.isAuthenticated else {
                throw DataServiceError.authenticationRequired
            }

            // Delete from Supabase Storage
            try await supabaseManager.deleteFile(bucket: bucketName, fileName: fileName)

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

    func getPhotoURL(fileName: String) async throws -> String {
        logger.info("Retrieving public URL for photo: \(fileName)")

        currentError = nil

        do {
            let publicURL = try supabaseManager.getPublicURL(bucket: bucketName, path: fileName)

            // Validate URL format
            guard URL(string: publicURL) != nil else {
                throw DataServiceError.invalidData("Invalid public URL format returned")
            }

            logger.info("Successfully retrieved public URL for photo: \(fileName)")
            return publicURL

        } catch let error as DataServiceError {
            currentError = error
            logger.error("Failed to get photo URL with DataServiceError: \(error.localizedDescription)")
            throw error
        } catch {
            let serviceError = DataServiceErrorFactory.fromSupabaseError(error)
            currentError = serviceError
            logger.error("Failed to get photo URL with unexpected error: \(error.localizedDescription)")
            throw serviceError
        }
    }

    // MARK: - Additional Upload Methods

    /// Upload multiple photos in batch
    func uploadPhotos(_ images: [UIImage],
                     compressionQuality: CGFloat = Config.defaultCompressionQuality,
                     targetSize: CGSize? = nil,
                     maintainAspectRatio: Bool = true,
                     progressHandler: ((Int, Int, PhotoUploadProgress?) -> Void)? = nil) async throws -> [PhotoUploadResult] {

        logger.info("Starting batch photo upload for \(images.count) images")

        var results: [PhotoUploadResult] = []

        for (index, image) in images.enumerated() {
            let result = try await uploadPhoto(
                image,
                compressionQuality: compressionQuality,
                targetSize: targetSize,
                maintainAspectRatio: maintainAspectRatio
            ) { progress in
                progressHandler?(index + 1, images.count, progress)
            }

            results.append(result)
        }

        logger.info("Batch photo upload completed: \(results.count) photos uploaded")
        return results
    }

    /// Generate thumbnail version of uploaded photo
    func generateThumbnail(from image: UIImage) async throws -> UIImage {
        return try await Task {
            try imageProcessor.generateThumbnail(from: image)
        }.value
    }

    // MARK: - Private Helper Methods

    private func processImage(_ image: UIImage,
                            compressionQuality: CGFloat,
                            targetSize: CGSize?,
                            maintainAspectRatio: Bool) async throws -> ImageProcessingResult {
        return try await Task {
            let finalTargetSize = targetSize ?? CGSize(
                width: ImageProcessingConfig.standardWidth,
                height: ImageProcessingConfig.standardHeight
            )

            return try self.imageProcessor.processImageForUpload(
                image,
                targetSize: finalTargetSize,
                compressionQuality: compressionQuality,
                maintainAspectRatio: maintainAspectRatio
            )
        }.value
    }

    private func compressImage(_ image: UIImage, quality: CGFloat) throws -> Data {
        guard let imageData = image.jpegData(compressionQuality: quality) else {
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

    private func performUpload(data: Data, fileName: String, contentType: String) async throws -> String {
        return try await supabaseManager.uploadFile(
            bucket: bucketName,
            path: fileName,
            data: data,
            contentType: contentType
        )
    }

    // MARK: - Upload with Retry Logic

    private func performUploadWithRetry(
        image: UIImage,
        compressionQuality: CGFloat,
        targetSize: CGSize?,
        maintainAspectRatio: Bool,
        progressHandler: ((PhotoUploadProgress) -> Void)?
    ) async throws -> PhotoUploadResult {

        // Create upload task for cancellation support
        let uploadTask = Task<PhotoUploadResult, Error> {
            // Validate authentication
            guard await supabaseManager.isAuthenticated,
                  let currentUser = await supabaseManager.currentUser else {
                throw DataServiceError.authenticationRequired
            }

            // Process image (resize, compress, optimize)
            let processingResult = try await processImage(
                image,
                compressionQuality: compressionQuality,
                targetSize: targetSize,
                maintainAspectRatio: maintainAspectRatio
            )

            // Generate unique filename with UUID
            let fileName = PhotoFileNaming.generateUniqueFileName(for: currentUser.id)

            // Get processed image data
            let imageData = try compressImage(processingResult.processedImage, quality: compressionQuality)

            // Create progress tracking
            let totalBytes = Int64(imageData.count)
            let initialProgress = PhotoUploadProgress(bytesUploaded: 0, totalBytes: totalBytes)
            uploadProgress = initialProgress
            progressHandler?(initialProgress)

            // Attempt upload with retry logic
            var lastError: Error?

            for attempt in 1...maxRetryAttempts {
                do {
                    // Check for cancellation
                    try Task.checkCancellation()

                    retryCount = attempt - 1

                    if attempt > 1 {
                        isRetrying = true
                        logger.info("Retrying photo upload, attempt \(attempt)/\(self.maxRetryAttempts)")

                        // Exponential backoff delay
                        let delay = baseRetryDelay * pow(2.0, Double(attempt - 2))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                        // Check for cancellation after delay
                        try Task.checkCancellation()
                    }

                    // Upload to Supabase Storage
                    let publicURL = try await performUpload(
                        data: imageData,
                        fileName: fileName,
                        contentType: "image/jpeg"
                    )

                    // Success - reset retry state
                    isRetrying = false
                    retryCount = 0

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
                    logger.info("Processing stats - Original: \(processingResult.originalSize.width)x\(processingResult.originalSize.height), Final: \(processingResult.processedSize.width)x\(processingResult.processedSize.height)")
                    logger.info("Compression: \(Int(processingResult.compressionPercent))%, Operations: \(processingResult.appliedOperations.joined(separator: ", "))")

                    return result

                } catch is CancellationError {
                    logger.info("Photo upload cancelled by user")
                    throw DataServiceError.operationCancelled
                } catch {
                    lastError = error
                    logger.warning("Upload attempt \(attempt) failed: \(error.localizedDescription)")

                    // Don't retry on certain errors
                    if isNonRetryableError(error) {
                        break
                    }
                }
            }

            // All retries exhausted
            isRetrying = false
            let finalError = lastError ?? DataServiceError.unknown(NSError(domain: "PhotoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown upload error"]))
            logger.error("Photo upload failed after \(self.maxRetryAttempts) attempts: \(finalError.localizedDescription)")

            throw DataServiceErrorFactory.fromSupabaseError(finalError)
        }

        // Store task for potential cancellation
        currentUploadTask = uploadTask

        defer {
            currentUploadTask = nil
            isRetrying = false
            retryCount = 0
        }

        return try await uploadTask.value
    }

    // MARK: - Upload Cancellation

    nonisolated func cancelCurrentUpload() {
        logger.info("Cancelling current photo upload")
        Task { @MainActor in
            currentUploadTask?.cancel()
            currentUploadTask = nil
            isUploading = false
            isRetrying = false
            retryCount = 0
            uploadProgress = nil
            currentError = DataServiceError.operationCancelled
        }
    }

    // MARK: - Error Classification

    private func isNonRetryableError(_ error: Error) -> Bool {
        if let dataError = error as? DataServiceError {
            switch dataError {
            case .authenticationRequired, .forbidden, .invalidData, .valueTooLarge, .jsonEncodingFailed:
                return true // Don't retry these
            case .networkUnavailable, .requestTimeout, .serverUnavailable, .internalServerError, .networkTimeout:
                return false // Retry these
            case .missingResponseData, .jsonDecodingFailed, .operationCancelled:
                return true // Don't retry these
            default:
                return false // Retry unknown errors
            }
        }
        return false // Retry unknown errors
    }

    // MARK: - Enhanced Batch Upload with Individual Error Handling

    /// Upload multiple photos with individual retry and error handling
    func uploadPhotosWithDetailedResults(
        _ images: [UIImage],
        compressionQuality: CGFloat = Config.defaultCompressionQuality,
        targetSize: CGSize? = nil,
        maintainAspectRatio: Bool = true,
        progressHandler: ((Int, Int, PhotoUploadProgress?) -> Void)? = nil
    ) async -> [(index: Int, result: Result<PhotoUploadResult, Error>)] {

        logger.info("Starting detailed batch photo upload for \(images.count) images")

        return await withTaskGroup(of: (Int, Result<PhotoUploadResult, Error>).self) { group in
            // Add tasks for each image
            for (index, image) in images.enumerated() {
                group.addTask { [weak self] in
                    do {
                        let result = try await self?.uploadPhoto(
                            image,
                            compressionQuality: compressionQuality,
                            targetSize: targetSize,
                            maintainAspectRatio: maintainAspectRatio
                        ) { progress in
                            progressHandler?(index + 1, images.count, progress)
                        }

                        guard let result = result else {
                            throw DataServiceError.unknown(NSError(domain: "PhotoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "PhotoService deallocated during upload"]))
                        }

                        return (index, .success(result))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            // Collect results
            var results: [(Int, Result<PhotoUploadResult, Error>)] = []
            for await result in group {
                results.append(result)
            }

            // Sort by index to maintain original order
            results.sort { $0.0 < $1.0 }

            let successCount = results.compactMap { $0.1.isPhotoUploadSuccess ? 1 : nil }.count
            logger.info("Detailed batch upload completed: \(successCount)/\(results.count) photos uploaded successfully")

            return results
        }
    }

    // MARK: - URL Validation and Caching

    private var urlCache: [String: (url: String, timestamp: Date)] = [:]
    private let urlCacheTimeout: TimeInterval = 300 // 5 minutes

    func getCachedPhotoURL(fileName: String) async throws -> String {
        // Check cache first
        if let cached = urlCache[fileName],
           Date().timeIntervalSince(cached.timestamp) < urlCacheTimeout {
            logger.info("Returning cached URL for photo: \(fileName)")
            return cached.url
        }

        // Get fresh URL
        let url = try await getPhotoURL(fileName: fileName)

        // Cache the result
        urlCache[fileName] = (url: url, timestamp: Date())

        return url
    }

    nonisolated func clearURLCache() {
        Task { @MainActor in
            urlCache.removeAll()
        }
        logger.info("Photo URL cache cleared")
    }
}

// MARK: - Result Extension for Success Check

private extension Result where Success == PhotoUploadResult, Failure == Error {
    var isPhotoUploadSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

// MARK: - Singleton Access

extension PhotoService {
    static let shared = PhotoService(
        supabaseManager: SupabaseManager.shared,
        imageProcessor: ImageProcessor()
    )
}
