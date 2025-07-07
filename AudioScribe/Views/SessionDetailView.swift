//
//  SessionDetailView.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI
import AVFoundation
import os

// Logger for this file
private let logger = Logger(subsystem: "AudioScribe", category: "SessionDetailView")

struct SessionDetailView: View {
	@Environment(\.modelContext) private var context
	@Bindable var session: RecordingSession

	@State private var showDeleteAlert = false
	@State private var segmentToDeleteFile: AudioSegment?
	@State private var audioPlayer: AVAudioPlayer?

	var body: some View {
		List {
			if session.segments.isEmpty {
				Text("No segments yet. Recording in progress or not started.")
					.font(.footnote)
					.foregroundColor(.gray)
					.accessibilityLabel("No segments yet")
			} else {
				ForEach(session.segments, id: \.id) { segment in
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("File: \(segment.fileURL.lastPathComponent)")
								.font(.subheadline)
								.foregroundColor(.secondary)
								.accessibilityLabel("Audio file")
								.accessibilityValue(segment.fileURL.lastPathComponent)

							Spacer()

							if FileManager.default.fileExists(atPath: segment.fileURL.path) {
								HStack(spacing: 16) {
									Button {
										playAudio(at: segment.fileURL)
									} label: {
										Image(systemName: "play.circle")
											.font(.title2)
									}
									.buttonStyle(.borderless)
									.accessibilityLabel("Play audio file \(segment.fileURL.lastPathComponent)")

									Button(role: .destructive) {
										segmentToDeleteFile = segment
										showDeleteAlert = true
									} label: {
										Image(systemName: "trash")
											.font(.title2)
									}
									.buttonStyle(.borderless)
									.accessibilityLabel("Delete audio file \(segment.fileURL.lastPathComponent)")
								}
							}
						}

						if let transcription = segment.transcription {
							Text(transcription.text)
								.font(.body)
								.accessibilityLabel("Transcription")
								.accessibilityValue(transcription.text)
						} else if segment.isUploaded {
							Text("🚀 Transcribing...")
								.font(.footnote)
								.foregroundColor(.blue)
								.accessibilityLabel("Transcription in progress")
						} else {
							Text("⏳ Pending upload")
								.font(.footnote)
								.foregroundColor(.orange)
								.accessibilityLabel("Pending upload")
						}
					}
					.padding(.vertical, 6)
				}
			}
		}
		.navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
		.accessibilityLabel("Session details for \(session.date.formatted(date: .abbreviated, time: .shortened))")
		.alert("Delete Audio File?", isPresented: $showDeleteAlert) {
			Button("Delete", role: .destructive) {
				if let segment = segmentToDeleteFile {
					deleteAudioFile(for: segment)
				}
			}
			.accessibilityLabel("Confirm delete audio file")
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Are you sure you want to delete the audio file? The transcription will remain.")
		}
	}

	private func playAudio(at url: URL) {
		do {
			audioPlayer = try AVAudioPlayer(contentsOf: url)
			audioPlayer?.play()
			logger.debug("Playing audio at \(url.lastPathComponent, privacy: .public)")
		} catch {
			logger.error("Failed to play audio: \(error.localizedDescription, privacy: .public)")
		}
	}

	private func deleteAudioFile(for segment: AudioSegment) {
		if FileManager.default.fileExists(atPath: segment.fileURL.path) {
			do {
				try FileManager.default.removeItem(at: segment.fileURL)
				logger.debug("Deleted audio file at: \(segment.fileURL.lastPathComponent, privacy: .public)")
			} catch {
				logger.error("Failed to delete audio file: \(error.localizedDescription, privacy: .public)")
			}
		}
	}
}

