//
//  AudioScribeApp.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI
import SwiftData

@main
struct AudioScribeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
			RecordingSession.self,
			AudioSegment.self,
			Transcription.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
