//
//  NutritionTrackerV2App.swift
//  NutritionTrackerV2
//
//  Created by Diego Serrano on 9/22/25.
//

import SwiftUI

@main
struct NutritionTrackerV2App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
