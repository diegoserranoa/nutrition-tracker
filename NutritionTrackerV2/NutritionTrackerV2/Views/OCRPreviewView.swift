//
//  OCRPreviewView.swift
//  NutritionTrackerV2
//
//  Preview view for OCR text recognition results
//

import SwiftUI

struct OCRPreviewView: View {
    let image: UIImage
    let boxes: [CGRect]

    var body: some View {
        NavigationView {
            VStack {
                Text("OCR Preview")
                    .font(.title)
                    .padding()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 300)
                    .cornerRadius(8)

                Text("OCR text detection overlay will be implemented in task 9 (OCR Nutrition Label Scanning)")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Text("Tap anywhere to use extracted data")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding()

                Spacer()
            }
            .navigationTitle("OCR Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
struct OCRPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "photo") {
            OCRPreviewView(image: image, boxes: [])
        }
    }
}
#endif