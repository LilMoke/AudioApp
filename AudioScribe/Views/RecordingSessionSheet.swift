//
//  RecordingSessionSheet.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI
import os

// Logger for this file
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AudioScribe", category: "RecordingSessionSheet")

struct RecordingSessionSheet: View {
	@Environment(\.modelContext) private var context

	@Bindable var audioManager: AudioManager

	var onClose: (Bool) -> Void
	var onDone: () -> Void

	@State private var startTime: Date?
	@State private var displayTimer: Timer?
	@State private var currentElapsed: TimeInterval = 0
	@State private var isPaused = false
	@State private var confirmCancelRecording = false

	var body: some View {
		NavigationStack {
			VStack(spacing: 20) {
				Text(timeString(from: currentElapsed))
					.font(.largeTitle.monospacedDigit())
					.padding(.top)
					.accessibilityLabel("Recording time")
					.accessibilityValue("\(Int(currentElapsed)) seconds elapsed")

				HStack(spacing: 30) {
					Button {
						if !audioManager.isRecording && !isPaused {
							audioManager.startRecording()
							startNewClock()
							logger.info("Started recording.")
						} else if audioManager.isRecording {
							audioManager.pauseRecording()
							pauseClock()
							isPaused = true
							logger.info("Paused recording.")
						} else if isPaused {
							audioManager.resumeRecording()
							resumeClock()
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
						stopClock()
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
					.frame(maxWidth: .infinity)
					.padding(.horizontal)
					.background(.audioScribeGray)
					.accessibilityLabel("Audio waveform level")

				List {
					if let segments = audioManager.currentSession?.segments, !segments.isEmpty {
						ForEach(Array(segments.enumerated()), id: \.element.id) { (index, segment) in
							VStack(alignment: .leading) {
//								Text("File: \(segment.fileURL.lastPathComponent)")
//									.font(.caption)
//									.accessibilityLabel("Recorded file")
//									.accessibilityValue(segment.fileURL.lastPathComponent)
								Text("Segment #\(index + 1)")
									.font(.caption)
									.accessibilityLabel("Recorded segment number \(index + 1)")

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
						stopClock()
						onDone()
						logger.info("Closed sheet with Done.")
					}
					.accessibilityLabel("Done")
					.accessibilityHint("Finish and close the recording screen.")
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						stopClock()
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

	// MARK: - Clock logic
	private func startNewClock() {
		startTime = Date()
		startDisplayTimer()
	}

	private func resumeClock() {
		if let pausedDuration = startTime.map({ Date().timeIntervalSince($0) }) {
			startTime = Date().addingTimeInterval(-pausedDuration)
		} else {
			startTime = Date()
		}
		startDisplayTimer()
	}

	private func pauseClock() {
		displayTimer?.invalidate()
	}

	private func stopClock() {
		displayTimer?.invalidate()
		displayTimer = nil
	}

	private func startDisplayTimer() {
		displayTimer?.invalidate()
		displayTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
			Task { @MainActor in
				if let start = startTime {
					currentElapsed = Date().timeIntervalSince(start)
				}
			}
		}
	}

	private func timeString(from interval: TimeInterval) -> String {
		let minutes = Int(interval) / 60
		let seconds = Int(interval) % 60
		let milliseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 1000)
		return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
	}
}
