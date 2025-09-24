//
//  FoodFormView.swift
//  NutritionTrackerV2
//
//  Form for creating and editing food items
//

import SwiftUI

struct FoodFormView: View {
    let prefilledFood: Food?
    let onSave: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                Text("Food Form View")
                    .font(.title)
                    .padding()

                Text("Form for creating/editing foods will be implemented in task 6.3")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
            }
            .navigationTitle(prefilledFood != nil ? "Edit Food" : "New Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSave()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct FoodFormView_Previews: PreviewProvider {
    static var previews: some View {
        FoodFormView(prefilledFood: nil) {
            // Preview completion
        }
    }
}
#endif