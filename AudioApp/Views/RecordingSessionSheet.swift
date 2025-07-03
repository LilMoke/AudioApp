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

	var onClose: (Bool) -> Void
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
					.accessibilityLabel("Recording time")
					.accessibilityValue("\(Int(recordingTime)) seconds elapsed")

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
								.accessibilityLabel("Start recording")
								.accessibilityHint("Begins recording audio.")
						} else if audioManager.isRecording {
							Label("Pause", systemImage: "pause.circle")
								.accessibilityLabel("Pause recording")
								.accessibilityHint("Pauses the current recording.")
						} else {
							Label("Resume", systemImage: "play.circle")
								.accessibilityLabel("Resume recording")
								.accessibilityHint("Resumes paused recording.")
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
					.accessibilityLabel("Stop recording")
					.accessibilityHint("Stops and saves the current recording session.")
				}
				.font(.title2)

				ScrollingWaveform(level: audioManager.inputLevel)
					.frame(height: 50)
					.padding(.horizontal)
					.accessibilityLabel("Audio waveform level")

				List {
					if let segments = audioManager.currentSession?.segments, !segments.isEmpty {
						ForEach(segments, id: \.id) { segment in
							VStack(alignment: .leading) {
								Text("File: \(segment.fileURL.lastPathComponent)")
									.font(.caption)
									.accessibilityLabel("Recorded file")
									.accessibilityValue(segment.fileURL.lastPathComponent)

								if let text = segment.transcription?.text {
									Text(text)
										.accessibilityLabel("Transcription")
										.accessibilityValue(text)
								} else if segment.isUploaded {
									Text("🚀 Transcribing...").foregroundColor(.blue)
										.accessibilityLabel("Transcription in progress")
								} else {
									Text("⏳ Pending upload").foregroundColor(.orange)
										.accessibilityLabel("Pending upload")
								}
							}
							.padding(.vertical, 4)
						}
					} else {
						Text("No segments recorded yet.")
							.font(.footnote)
							.foregroundColor(.gray)
							.accessibilityLabel("No segments recorded yet")
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
					.accessibilityLabel("Done")
					.accessibilityHint("Finish and close the recording screen.")
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
					.accessibilityLabel("Close recording")
					.accessibilityHint("Discard or exit the recording session.")
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

