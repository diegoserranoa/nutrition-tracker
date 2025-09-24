# PhotoService Usage Guide

## Overview
The PhotoService class provides a comprehensive solution for uploading, downloading, and managing photos in the Supabase Storage bucket. It includes progress tracking, error handling, and follows the established service patterns in the codebase.

## Basic Usage

### Uploading a Photo

```swift
import UIKit

// Initialize the PhotoService (using singleton)
let photoService = PhotoService.shared

// Upload a photo with progress tracking
func uploadFoodPhoto(_ image: UIImage) async {
    do {
        let result = try await photoService.uploadPhoto(
            image,
            compressionQuality: 0.8
        ) { progress in
            // Handle upload progress
            print("Upload progress: \(progress.percentage)%")
            DispatchQueue.main.async {
                // Update UI with progress
                self.uploadProgressView.progress = Float(progress.percentage / 100)
            }
        }

        // Success - use the result
        print("Photo uploaded successfully: \(result.publicURL)")
        print("File size: \(result.fileSize) bytes")

    } catch {
        // Handle upload error
        print("Upload failed: \(error.localizedDescription)")
    }
}
```

### Downloading a Photo

```swift
func downloadPhoto(from url: String) async {
    do {
        let image = try await photoService.downloadPhoto(from: url)

        // Success - display the image
        DispatchQueue.main.async {
            self.imageView.image = image
        }

    } catch {
        // Handle download error
        print("Download failed: \(error.localizedDescription)")
    }
}
```

### Deleting a Photo

```swift
func deletePhoto(fileName: String) async {
    do {
        try await photoService.deletePhoto(fileName: fileName)
        print("Photo deleted successfully")

    } catch {
        // Handle deletion error
        print("Delete failed: \(error.localizedDescription)")
    }
}
```

### Getting a Photo URL

```swift
func getPhotoURL(fileName: String) {
    do {
        let url = try photoService.getPhotoURL(fileName: fileName)
        print("Photo URL: \(url)")

    } catch {
        print("Failed to get URL: \(error.localizedDescription)")
    }
}
```

## Integration with SwiftUI

### PhotoUploader View Example

```swift
import SwiftUI

struct PhotoUploaderView: View {
    @StateObject private var photoService = PhotoService.shared
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var uploadedPhotoURL: String?

    var body: some View {
        VStack(spacing: 20) {
            // Image display
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .cornerRadius(10)
            }

            // Upload progress
            if photoService.isUploading {
                if let progress = photoService.uploadProgress {
                    ProgressView(value: progress.percentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("\(Int(progress.percentage))% uploaded")
                }
            }

            // Buttons
            HStack {
                Button("Select Photo") {
                    showImagePicker = true
                }
                .disabled(photoService.isUploading)

                Button("Upload") {
                    uploadPhoto()
                }
                .disabled(selectedImage == nil || photoService.isUploading)
            }

            // Error display
            if let error = photoService.currentError {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // Success display
            if let url = uploadedPhotoURL {
                Text("Uploaded successfully!")
                    .foregroundColor(.green)
                Text("URL: \(url)")
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }

    private func uploadPhoto() {
        guard let image = selectedImage else { return }

        Task {
            do {
                let result = try await photoService.uploadPhoto(
                    image,
                    compressionQuality: 0.8
                ) { progress in
                    // Progress is automatically published by @Published uploadProgress
                }

                await MainActor.run {
                    uploadedPhotoURL = result.publicURL
                }

            } catch {
                print("Upload error: \(error)")
            }
        }
    }
}
```

## Configuration

### File Size and Quality Settings

```swift
// Upload with custom compression
let result = try await photoService.uploadPhoto(
    image,
    compressionQuality: 0.6  // Lower quality = smaller file size
)

// The service automatically validates file size (50MB max)
// Compression quality: 0.0 (lowest) to 1.0 (highest)
```

### Supported File Types

The PhotoService supports:
- JPEG (.jpg)
- PNG (.png)
- HEIC (.heic)
- WebP (.webp)

Files are automatically converted to JPEG format for upload to ensure compatibility.

## File Naming Convention

Photos are automatically named using the pattern:
```
{user_id}/{timestamp}_{random_id}.jpg
```

Example: `550e8400-e29b-41d4-a716-446655440000/1640995200_abc12345.jpg`

This ensures:
- User isolation (photos are organized by user)
- Uniqueness (timestamp + random ID)
- Consistent format

## Error Handling

The PhotoService uses the project's unified error handling system:

```swift
do {
    let result = try await photoService.uploadPhoto(image)
} catch DataServiceError.authenticationRequired {
    // User needs to sign in
} catch DataServiceError.networkUnavailable {
    // Check internet connection
} catch DataServiceError.valueTooLarge(let field, let max) {
    // File too large - show max size
} catch {
    // Handle other errors
    print("Unexpected error: \(error)")
}
```

## Security Considerations

- ✅ Upload requires authentication
- ✅ Public read access for viewing photos in app
- ✅ Users can only modify their own photos
- ✅ File size limits prevent abuse
- ✅ File type restrictions ensure only images
- ✅ Automatic user-based folder structure

## Performance Tips

1. **Compression**: Use appropriate compression quality (0.7-0.8 recommended)
2. **Caching**: Consider implementing client-side caching for downloaded images
3. **Async/Await**: Always use async/await for non-blocking operations
4. **Progress Tracking**: Use progress handlers for better UX on large uploads

## Integration with Food Models

```swift
// Example: Adding photo URL to Food model
struct Food: Codable {
    let id: UUID
    let name: String
    // ... other properties
    let photoURL: String?

    mutating func setPhotoURL(_ url: String) {
        self.photoURL = url
    }
}

// Usage in food creation flow
func createFoodWithPhoto(_ food: Food, image: UIImage) async throws -> Food {
    var updatedFood = food

    // Upload photo first
    let photoResult = try await PhotoService.shared.uploadPhoto(image)
    updatedFood.setPhotoURL(photoResult.publicURL)

    // Then create food record with photo URL
    return try await FoodService.shared.createFood(updatedFood)
}
```