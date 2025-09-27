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
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("CameraManager: Current permission status: \(status.rawValue) (\(statusDescription(status)))")

        switch status {
        case .authorized:
            print("CameraManager: Camera authorized, starting session")
            isAuthorized = true
            // Add small delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startSession()
            }
        case .notDetermined:
            print("CameraManager: Requesting camera permission")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    print("CameraManager: Permission granted: \(granted)")
                    self?.isAuthorized = granted
                    if granted {
                        print("CameraManager: Permission granted, starting session")
                        // Add small delay to ensure UI is ready after permission dialog
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self?.startSession()
                        }
                    } else {
                        print("CameraManager: Permission denied by user")
                    }
                }
            }
        case .denied, .restricted:
            print("CameraManager: Camera access denied or restricted")
            isAuthorized = false
        @unknown default:
            print("CameraManager: Unknown camera permission status")
            isAuthorized = false
        }
    }

    private func statusDescription(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
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
            // Use supported dimensions from the active format
            if let device = device,
               let supportedDimensions = device.activeFormat.supportedMaxPhotoDimensions.first {
                settings.maxPhotoDimensions = supportedDimensions
            }
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

    /// Focus camera at a specific point
    func focusAt(point: CGPoint) {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                print("CameraManager: Focus set to point: \(point)")
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
                print("CameraManager: Exposure set to point: \(point)")
            }

            device.unlockForConfiguration()
        } catch {
            print("CameraManager: Failed to set focus/exposure: \(error.localizedDescription)")
        }
    }

    /// Reset focus and exposure to continuous auto mode
    func resetFocus() {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
            print("CameraManager: Focus and exposure reset to center")
        } catch {
            print("CameraManager: Failed to reset focus/exposure: \(error.localizedDescription)")
        }
    }

    /// Start the camera session
    func startSession() {
        guard !session.isRunning else {
            print("CameraManager: Session already running")
            return
        }

        print("CameraManager: Starting camera session...")
        print("CameraManager: Session inputs: \(session.inputs.count), outputs: \(session.outputs.count)")

        // Check if session is properly configured
        if session.inputs.isEmpty {
            print("CameraManager: ❌ No inputs configured, running setup again")
            setupCamera()
        }

        Task.detached { [session] in
            // Start session on background queue - this is blocking
            print("CameraManager: About to start session...")
            session.startRunning()

            await MainActor.run {
                print("CameraManager: Session started, running: \(session.isRunning)")
                if !session.isRunning {
                    print("CameraManager: ❌ Session failed to start!")
                } else {
                    print("CameraManager: ✅ Session started successfully")
                }
            }
        }
    }

    /// Stop the camera session
    func stopSession() {
        guard session.isRunning else {
            print("CameraManager: Session not running")
            return
        }

        print("CameraManager: Stopping camera session...")
        Task.detached { [session] in
            // Stop session on background queue - this is blocking
            session.stopRunning()
            print("CameraManager: Session stopped")
        }
    }

    // MARK: - Private Methods

    private func setupCamera() {
        print("CameraManager: Starting camera setup...")

        // Configure session for high quality photo capture
        session.sessionPreset = .photo
        print("CameraManager: Set session preset to photo")

        // Setup camera device (prefer back camera)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("CameraManager: ❌ Failed to get back camera device")
            // Try front camera as fallback
            if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                print("CameraManager: Using front camera as fallback")
                self.device = frontCamera
                setupCameraInput(frontCamera)
            }
            return
        }

        print("CameraManager: ✅ Got back camera device: \(camera.localizedName)")
        self.device = camera
        setupCameraInput(camera)
    }

    private func setupCameraInput(_ camera: AVCaptureDevice) {
        do {
            // Setup device input
            let input = try AVCaptureDeviceInput(device: camera)

            if session.canAddInput(input) {
                session.addInput(input)
                deviceInput = input
                print("CameraManager: ✅ Added camera input successfully")
            } else {
                print("CameraManager: ❌ Cannot add camera input to session")
                return
            }

            // Setup photo output
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                print("CameraManager: ✅ Added photo output successfully")

                // Configure photo output settings
                if #available(iOS 16.0, *) {
                    // Use the maximum supported dimensions from the active format
                    let supportedDimensions = camera.activeFormat.supportedMaxPhotoDimensions
                    if let maxDimensions = supportedDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                        photoOutput.maxPhotoDimensions = maxDimensions
                        print("CameraManager: Using max photo dimensions: \(maxDimensions.width) x \(maxDimensions.height)")
                    } else {
                        // Fallback: don't set maxPhotoDimensions, use default
                        print("CameraManager: Using default photo dimensions - no supported dimensions found")
                    }
                } else {
                    photoOutput.isHighResolutionCaptureEnabled = false
                    print("CameraManager: Set high resolution capture to false (iOS < 16)")
                }
                photoOutput.maxPhotoQualityPrioritization = .balanced
                print("CameraManager: ✅ Camera setup completed successfully")
            } else {
                print("CameraManager: ❌ Cannot add photo output to session")
            }

        } catch {
            print("CameraManager: ❌ Failed to setup camera input: \(error.localizedDescription)")
        }
    }

    private func processPhoto(_ photoData: Data) -> UIImage? {
        guard let image = UIImage(data: photoData) else {
            return nil
        }

        // Perform basic sizing for efficient processing
        // The ImagePreprocessor will handle final ML model formatting
        let targetSize = CGSize(width: 1024, height: 1024)
        return image.resized(to: targetSize)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {

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