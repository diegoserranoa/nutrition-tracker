//
//  CameraView.swift
//  NutritionTrackerV2
//
//  SwiftUI camera interface component for capturing food photos
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: View {
    @Binding var capturedImage: UIImage?
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var cameraManager = CameraManager()
    @State private var showingPermissionAlert = false
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    @State private var isProcessing = false
    @State private var processingMessage = "Processing image..."

    var body: some View {
        ZStack {
            // Camera preview background
            Color.black.ignoresSafeArea()

            if cameraManager.isAuthorized {
                // Camera preview with tap to focus
                GeometryReader { geometry in
                    CameraPreviewView(session: cameraManager.session)
                        .ignoresSafeArea()
                        .onTapGesture { location in
                            handleTapToFocus(at: location, in: geometry.size)
                        }
                }

                // Focus indicator overlay
                if showFocusIndicator, let point = focusPoint {
                    FocusIndicatorView()
                        .position(point)
                        .animation(.easeInOut(duration: 0.2), value: focusPoint)
                }

                // Camera controls overlay
                VStack {
                    Spacer()

                    // Bottom controls
                    HStack(spacing: 50) {
                        // Cancel button
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        // Capture button
                        Button(action: capturePhoto) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(cameraManager.isCapturing ? 0.8 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: cameraManager.isCapturing)
                            }
                        }
                        .disabled(cameraManager.isCapturing)

                        // Flash toggle button
                        Button(action: toggleFlash) {
                            Image(systemName: flashIconName)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(cameraManager.flashMode == .on ? .yellow : .white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 50)
                }

                // Processing overlay
                if isProcessing {
                    processingOverlay
                }
            } else {
                // Permission required view
                permissionRequiredView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("CameraView: onAppear - requesting permission")
            cameraManager.requestPermission()
        }
        .onChange(of: cameraManager.isAuthorized) { authorized in
            print("CameraView: Authorization changed to: \(authorized)")
            if authorized {
                print("CameraView: Starting session after authorization")
                // Add small delay to ensure preview layer is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    cameraManager.startSession()
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable camera access in Settings to take food photos.")
        }
    }

    // MARK: - Private Views

    private var permissionRequiredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 12) {
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("To capture food photos for recognition, please allow camera access in your device settings.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                Button("Open Settings") {
                    showingPermissionAlert = true
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 40)

                Button("Cancel") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                // Processing message
                Text(processingMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Analyzing food and detecting weight...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Private Computed Properties

    private var flashIconName: String {
        switch cameraManager.flashMode {
        case .on:
            return "bolt.fill"
        case .off:
            return "bolt.slash.fill"
        case .auto:
            return "bolt.badge.a.fill"
        @unknown default:
            return "bolt.fill"
        }
    }

    // MARK: - Private Methods

    private func capturePhoto() {
        // Show processing immediately when capture starts
        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = true
            processingMessage = "Capturing photo..."
        }

        cameraManager.capturePhoto { image in
            if let image = image {
                capturedImage = image

                // Update processing message
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        processingMessage = "Analyzing image..."
                    }
                }

                // Start the analysis workflow
                onImageCaptured(image)

                // Dismiss after a short delay to allow for workflow initialization
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } else {
                // Hide processing on error
                withAnimation(.easeInOut(duration: 0.3)) {
                    isProcessing = false
                }
            }
        }
    }

    private func toggleFlash() {
        cameraManager.toggleFlash()
    }

    private func handleTapToFocus(at location: CGPoint, in viewSize: CGSize) {
        // Convert the tap location to camera coordinate system (0.0 to 1.0)
        let devicePoint = CGPoint(
            x: location.x / viewSize.width,
            y: location.y / viewSize.height
        )

        // Set focus point for UI indicator
        focusPoint = location
        showFocusIndicator = true

        // Set camera focus
        cameraManager.focusAt(point: devicePoint)

        // Hide focus indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showFocusIndicator = false
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = UIColor.black
        view.session = session

        print("CameraPreviewView: Created preview layer with session: \(session)")
        print("CameraPreviewView: Session is running: \(session.isRunning)")
        print("CameraPreviewView: Session inputs count: \(session.inputs.count)")
        print("CameraPreviewView: Session outputs count: \(session.outputs.count)")

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.session = session
        print("CameraPreviewView: Updated session, running: \(session.isRunning)")
    }
}

class PreviewView: UIView {
    var session: AVCaptureSession? {
        didSet {
            previewLayer.session = session
        }
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupPreviewLayer()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPreviewLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPreviewLayer()
    }

    private func setupPreviewLayer() {
        previewLayer.videoGravity = .resizeAspectFill
        print("PreviewView: Setup preview layer with gravity: \(previewLayer.videoGravity)")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        print("PreviewView: Layout subviews, frame: \(bounds)")
    }
}

// MARK: - Focus Indicator View

struct FocusIndicatorView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 80, height: 80)

            Circle()
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                .frame(width: 60, height: 60)

            Circle()
                .fill(Color.yellow.opacity(0.1))
                .frame(width: 40, height: 40)
        }
        .scaleEffect(1.0)
        .opacity(0.8)
    }
}

// MARK: - Preview

#if DEBUG
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(capturedImage: .constant(nil)) { image in
            print("Captured image: \(image)")
        }
    }
}
#endif