//
//  ContentView.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI
import SwiftData
import os

// Logger for this file
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AudioApp", category: "ContentView")

struct ContentView: View {
	@Environment(\.modelContext) private var context
	@Query var sessions: [RecordingSession]
	@State private var audioManager: AudioManager?
	@State private var showRecordingSheet = false
	@State private var confirmCancelRecording = false
	@State private var activeError: AppError?
	@State private var deferredError: AppError?

	var body: some View {
		NavigationStack {
			List {
				ForEach(sessions) { session in
					NavigationLink {
						SessionDetailView(session: session)
					} label: {
						VStack(alignment: .leading) {
							Text("Session")
								.accessibilityLabel("Recording Session")
							Text(session.date.formatted())
								.font(.caption)
								.accessibilityLabel("Date")
								.accessibilityValue(session.date.formatted(date: .abbreviated, time: .shortened))
						}
					}
					.swipeActions(edge: .trailing) {
						Button(role: .destructive) {
							deleteSession(session)
						} label: {
							Label("Delete", systemImage: "trash")
						}
						.accessibilityLabel("Delete session recorded on \(session.date.formatted(date: .abbreviated, time: .shortened))")
					}
				}
			}
			.navigationTitle("Sessions")
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button("Start Recording") {
						audioManager = AudioManager(context: context)
						audioManager?.onError = { appError in
							deferredError = appError
							showRecordingSheet = false
						}
						showRecordingSheet = true
						logger.info("Start Recording tapped.")
					}
					.accessibilityLabel("Start new recording")
					.accessibilityHint("Opens the recording screen to start recording audio.")
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					NavigationLink {
						SettingsView()
					} label: {
						Image(systemName: "gear")
					}
					.accessibilityLabel("Settings")
					.accessibilityHint("Open the application settings.")
				}
			}
		}
		.sheet(item: $audioManager, onDismiss: {
			if let appError = deferredError {
				activeError = appError
				deferredError = nil
			}
		}) { manager in
			RecordingSessionSheet(
				audioManager: manager,
				onClose: { confirmed in
					if confirmed {
						if let session = manager.currentSession {
							context.delete(session)
							do {
								try context.save()
								logger.info("Recording session deleted from model context.")
							} catch {
								logger.error("Failed to save after deleting session: \(error.localizedDescription)")
							}
						}
						audioManager = nil
						logger.info("Recording sheet closed after cancel.")
					}
				},
				onDone: {
					audioManager = nil
					logger.info("Recording sheet closed via Done.")
				}
			)
			.presentationDetents([.large])
			.presentationDragIndicator(.hidden)
		}
		.alert(item: $activeError) { error in
			Alert(title: Text("Error"),
				  message: Text("\(error.message) (\(error.domain) \(error.code))"),
				  dismissButton: .default(Text("OK")))
		}
		.alert("Discard this recording?", isPresented: $confirmCancelRecording) {
			Button("Discard", role: .destructive) {
				showRecordingSheet = false
				audioManager = nil
				logger.info("Discarded current recording session via alert.")
			}
			.accessibilityLabel("Discard recording")
			Button("Cancel", role: .cancel) {
				logger.info("Discard alert cancelled.")
			}
		} message: {
			Text("Any recorded segments will be deleted.")
		}
	}

	private func deleteSession(_ session: RecordingSession) {
		context.delete(session)
		do {
			try context.save()
			logger.info("Deleted existing recording session.")
		} catch {
			logger.error("Failed to save context after deleting session: \(error.localizedDescription)")
		}
	}
}

#Preview {
	ContentView()
		.modelContainer(for: Item.self, inMemory: true)
}
