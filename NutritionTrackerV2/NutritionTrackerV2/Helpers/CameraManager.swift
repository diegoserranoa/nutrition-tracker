//
//  CameraManager.swift
//  NutritionTrackerV2
//
//  Camera session management and photo capture functionality
//

import AVFoundation
import UIKit
import SwiftUI

@MainActor
class CameraManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isAuthorized = false
    @Published var isCapturing = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto

    // MARK: - Private Properties

    let session = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?

    private var photoCaptureCompletion: ((UIImage?) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        setupCamera()
    }

    // MARK: - Public Methods

    /// Request camera permission from the user
    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.startSession()
                    }
                }
            }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    /// Capture a photo
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard !isCapturing else { return }

        isCapturing = true
        photoCaptureCompletion = completion

        let settings = AVCapturePhotoSettings()

        // Configure flash
        if let device = device, device.hasFlash {
            settings.flashMode = flashMode
        }

        // Configure image quality and format
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = .init(width: 1920, height: 1920)
        } else {
            settings.isHighResolutionPhotoEnabled = false
        }
        settings.photoQualityPrioritization = .balanced

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    /// Toggle flash mode
    func toggleFlash() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        @unknown default:
            flashMode = .auto
        }
    }

    /// Start the camera session
    func startSession() {
        guard !session.isRunning else { return }

        Task.detached { [weak self] in
            await MainActor.run {
                self?.session.startRunning()
            }
        }
    }

    /// Stop the camera session
    func stopSession() {
        guard session.isRunning else { return }

        Task.detached { [weak self] in
            await MainActor.run {
                self?.session.stopRunning()
            }
        }
    }

    // MARK: - Private Methods

    private func setupCamera() {
        // Configure session for high quality photo capture
        session.sessionPreset = .photo

        // Setup camera device (prefer back camera)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera device")
            return
        }

        self.device = camera

        do {
            // Setup device input
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                deviceInput = input
            }

            // Setup photo output
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)

                // Configure photo output settings
                if #available(iOS 16.0, *) {
                    photoOutput.maxPhotoDimensions = .init(width: 1920, height: 1920)
                } else {
                    photoOutput.isHighResolutionCaptureEnabled = false
                }
                photoOutput.maxPhotoQualityPrioritization = .balanced
            }

        } catch {
            print("Failed to setup camera: \(error)")
        }
    }

    private func processPhoto(_ photoData: Data) -> UIImage? {
        guard let image = UIImage(data: photoData) else {
            return nil
        }

        // Resize image for optimal processing while maintaining quality
        let targetSize = CGSize(width: 1024, height: 1024)
        return image.resized(to: targetSize)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: @preconcurrency AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.isCapturing = false
            }
        }

        if let error = error {
            print("Photo capture error: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.photoCaptureCompletion?(nil)
                self?.photoCaptureCompletion = nil
            }
            return
        }

        guard let photoData = photo.fileDataRepresentation() else {
            print("Failed to get photo data")
            DispatchQueue.main.async { [weak self] in
                self?.photoCaptureCompletion?(nil)
                self?.photoCaptureCompletion = nil
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let processedImage = self.processPhoto(photoData)
            self.photoCaptureCompletion?(processedImage)
            self.photoCaptureCompletion = nil
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Photo has been captured, could add capture feedback here (haptics, sound, etc.)
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let size = self.size

        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        // Determine the scale factor that preserves aspect ratio
        let scaleFactor = min(widthRatio, heightRatio)

        // Calculate the new size
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        // Create the new image
        let renderer = UIGraphicsImageRenderer(size: scaledImageSize)

        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledImageSize))
        }

        return scaledImage
    }
}