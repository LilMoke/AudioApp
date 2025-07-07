//
//  SettingsView.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI

enum TranscriptionMode: String, CaseIterable, Identifiable {
	case apple = "Use Built-in Apple Speech Only"
	case openai = "Use OpenAI Whisper w/Fallback"

	var id: String { self.rawValue }
}

struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss

	@AppStorage("keepAudioClips") private var keepAudioClips: Bool = false
	@AppStorage("segmentLength") private var segmentLength: Double = 30
	@AppStorage("sampleRate") private var sampleRate: Double = 44100
	@AppStorage("bitDepth") private var bitDepth: Int = 16
	@AppStorage("audioFormat") private var audioFormat: String = "caf"
	@AppStorage("transcriptionMode") private var transcriptionModeRaw: String = TranscriptionMode.apple.rawValue

	@FocusState private var apiKeyFocused: Bool

	@State private var openAIApiKey: String = ""
	@State private var showMissingKeyAlert = false

	var transcriptionMode: TranscriptionMode {
		get { TranscriptionMode(rawValue: transcriptionModeRaw) ?? .apple }
		set { transcriptionModeRaw = newValue.rawValue }
	}

	var body: some View {
		Form {
			Section(header: Text("Transcription Settings").accessibilityAddTraits(.isHeader)) {
				Picker("", selection: $transcriptionModeRaw) {
					ForEach(TranscriptionMode.allCases) { mode in
						Text(mode.rawValue)
							.tag(mode.rawValue)
							.accessibilityLabel(mode.rawValue)
					}
				}
				.pickerStyle(.inline)
				.labelsHidden()

				if transcriptionMode == .openai {
					SecureField("OpenAI API Key", text: $openAIApiKey)
						.accessibilityLabel("OpenAI API Key")
						.accessibilityHint("Enter your OpenAI Whisper API key required for transcription.")
						.focused($apiKeyFocused)
						.onChange(of: openAIApiKey) { _, newValue in
							KeychainHelper.shared.save(Data(newValue.utf8), service: "com.myapp.openai", account: "apiKey")
						}
						.onAppear {
							if let data = KeychainHelper.shared.read(service: "com.myapp.openai", account: "apiKey"),
							   let key = String(data: data, encoding: .utf8) {
								openAIApiKey = key
							}
						}
				}
			}

			Section(header: Text("Audio Settings").accessibilityAddTraits(.isHeader)) {
				Toggle("Keep Audio Clips", isOn: $keepAudioClips)
					.accessibilityLabel("Keep Audio Clips toggle")
					.accessibilityHint("Keeps audio files saved after transcription")

				Stepper("Segment Length: \(Int(segmentLength)) seconds", value: $segmentLength, in: 10...120, step: 10)
					.accessibilityLabel("Segment Length")
					.accessibilityValue("\(Int(segmentLength)) seconds")
					.accessibilityHint("Adjust length of each recorded segment.")

				Stepper("Sample Rate: \(Int(sampleRate)) Hz", value: $sampleRate, in: 8000...48000, step: 1000)
					.accessibilityLabel("Sample Rate")
					.accessibilityValue("\(Int(sampleRate)) Hertz")
					.accessibilityHint("Adjust audio sample rate.")

				Picker("Bit Depth", selection: $bitDepth) {
					ForEach([8, 16, 24, 32], id: \.self) {
						Text("\($0) bit")
					}
				}
				.accessibilityLabel("Bit Depth")
				.accessibilityValue("\(bitDepth) bits")

				// This was removed because the format for OpenAI Whisper needs to be PCM so the data in a .wav or .caf will be
				// the same. Ideally we should save the file after transcribing and then convert to the required user format.
				// However, the feature to save the audio was not part of the requirement, i just wanted to do it. BUT, there was
				// a requirement to have a configurable format setting but I think it is foolish for the reason descriibed.
//				Picker("Format", selection: $audioFormat) {
//					ForEach(["caf", "wav", "m4a"], id: \.self) {
//						Text($0.uppercased())
//					}
//				}
//				.accessibilityLabel("Audio Format")
//				.accessibilityValue(audioFormat.uppercased())
			}
		}
		.navigationTitle("Settings")
		.navigationBarBackButtonHidden(true)
		.toolbar {
			ToolbarItem(placement: .navigationBarLeading) {
				Button {
					if transcriptionMode == .openai && openAIApiKey.trimmingCharacters(in: .whitespaces).isEmpty {
						showMissingKeyAlert = true
					} else {
						dismiss()
					}
				} label: {
					Label("Back", systemImage: "chevron.left")
				}
				.accessibilityLabel("Back to previous screen")
			}
		}
		.alert("API Key Required", isPresented: $showMissingKeyAlert) {
			Button("OK", role: .cancel) { }
		} message: {
			Text("Please enter your OpenAI API key before leaving settings, or switch to Apple Speech mode.")
		}
	}
}

