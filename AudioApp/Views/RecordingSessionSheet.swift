//
//  RecordingSessionSheet.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI
import os

// Logger for this file
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AudioApp", category: "RecordingSessionSheet")

struct RecordingSessionSheet: View {
	@Environment(\.modelContext) private var context
	@Bindable var audioManager: AudioManager
	var onClose: (Bool) -> Void // true = discard confirmed
	var onDone: () -> Void

	@State private var recordingTime: TimeInterval = 0
	@State private var timer: Timer?
	@State private var isPaused = false
	@State private var confirmCancelRecording = false

	var body: some View {
		NavigationStack {
			VStack(spacing: 20) {
				Text(timeString(from: recordingTime))
					.font(.largeTitle.monospacedDigit())
					.padding(.top)

				HStack(spacing: 30) {
					Button {
						if !audioManager.isRecording && !isPaused {
							audioManager.startRecording()
							startTimer()
							logger.info("Started recording.")
						} else if audioManager.isRecording {
							audioManager.pauseRecording()
							stopTimer()
							isPaused = true
							logger.info("Paused recording.")
						} else if isPaused {
							audioManager.resumeRecording()
							startTimer()
							isPaused = false
							logger.info("Resumed recording.")
						}
					} label: {
						if !audioManager.isRecording && !isPaused {
							Label("Start", systemImage: "record.circle")
						} else if audioManager.isRecording {
							Label("Pause", systemImage: "pause.circle")
						} else {
							Label("Resume", systemImage: "play.circle")
						}
					}

					Button {
						audioManager.stopRecording()
						stopTimer()
						isPaused = false
						logger.info("Stopped recording.")
					} label: {
						Label("Stop", systemImage: "stop.circle")
					}
					.disabled(!audioManager.isRecording && !isPaused)
				}
				.font(.title2)

				ScrollingWaveform(level: audioManager.inputLevel)
					.frame(height: 50)
					.padding(.horizontal)

				List {
					if let segments = audioManager.currentSession?.segments, !segments.isEmpty {
						ForEach(segments, id: \.id) { segment in
							VStack(alignment: .leading) {
								Text("File: \(segment.fileURL.lastPathComponent)").font(.caption)
								if let text = segment.transcription?.text {
									Text(text)
								} else if segment.isUploaded {
									Text("🚀 Transcribing...").foregroundColor(.blue)
								} else {
									Text("⏳ Pending upload").foregroundColor(.orange)
								}
							}
							.padding(.vertical, 4)
						}
					} else {
						Text("No segments recorded yet.")
							.font(.footnote)
							.foregroundColor(.gray)
					}
				}
			}
			.navigationTitle("Recording")
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button("Done") {
						stopTimer()
						onDone()
						logger.info("Closed sheet with Done.")
					}
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						stopTimer()
						if audioManager.currentSession?.segments.isEmpty ?? true {
							onClose(true)
							logger.info("Closed sheet without segments.")
						} else {
							confirmCancelRecording = true
							logger.info("Asked to confirm discard of current session.")
						}
					} label: {
						Image(systemName: "xmark")
					}
				}
			}
			.alert("Discard this recording?", isPresented: $confirmCancelRecording) {
				Button("Discard", role: .destructive) {
					onClose(true)
					logger.info("Discarded current recording session after confirmation.")
				}
				Button("Cancel", role: .cancel) {
					logger.info("Cancelled discard.")
				}
			} message: {
				Text("Any recorded segments will be deleted.")
			}
		}
	}

	private func startTimer() {
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
			Task { @MainActor in
				recordingTime += 1
			}
		}
	}
	
	private func stopTimer() {
		timer?.invalidate()
		timer = nil
	}

	private func timeString(from interval: TimeInterval) -> String {
		let minutes = Int(interval) / 60
		let seconds = Int(interval) % 60
		return String(format: "%02d:%02d", minutes, seconds)
	}
}
