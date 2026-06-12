//
//  ScootieApp.swift
//  Scootie
//
//  Created by Lasse on 23.01.25.
//

import SwiftUI
import SwiftData

@main
struct ScootieApp: App {
    @StateObject private var scooterManager = UnuScooterManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                WelcomeScreen(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(scooterManager)
            } else {
                ContentView()
                    .environmentObject(scooterManager)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
