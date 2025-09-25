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

    var body: some View {
        ZStack {
            // Camera preview background
            Color.black.ignoresSafeArea()

            if cameraManager.isAuthorized {
                // Camera preview
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()

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
            } else {
                // Permission required view
                permissionRequiredView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.requestPermission()
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
        cameraManager.capturePhoto { image in
            if let image = image {
                capturedImage = image
                onImageCaptured(image)
                dismiss()
            }
        }
    }

    private func toggleFlash() {
        cameraManager.toggleFlash()
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
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