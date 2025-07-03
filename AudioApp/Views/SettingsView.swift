//
//  SettingsView.swift
//  AudioApp
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

	@State private var openAIApiKey: String = ""
	@FocusState private var apiKeyFocused: Bool
	@State private var showMissingKeyAlert = false

	var transcriptionMode: TranscriptionMode {
		get { TranscriptionMode(rawValue: transcriptionModeRaw) ?? .apple }
		set { transcriptionModeRaw = newValue.rawValue }
	}

	var body: some View {
		Form {
			Section(header: Text("Transcription Settings")) {
				Picker("", selection: $transcriptionModeRaw) {
					ForEach(TranscriptionMode.allCases) { mode in
						Text(mode.rawValue).tag(mode.rawValue)
					}
				}
				.pickerStyle(.inline)
				.labelsHidden()

				if transcriptionMode == .openai {
					SecureField("OpenAI API Key", text: $openAIApiKey)
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

			Section(header: Text("Audio Settings")) {
				Toggle("Keep Audio Clips", isOn: $keepAudioClips)
				Stepper("Segment Length: \(Int(segmentLength)) sec", value: $segmentLength, in: 10...120, step: 10)
				Stepper("Sample Rate: \(Int(sampleRate)) Hz", value: $sampleRate, in: 8000...48000, step: 1000)
				Picker("Bit Depth", selection: $bitDepth) {
					ForEach([8, 16, 24, 32], id: \.self) { Text("\($0) bit") }
				}
				Picker("Format", selection: $audioFormat) {
					ForEach(["caf", "wav", "m4a"], id: \.self) { Text($0.uppercased()) }
				}
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
			}
		}
		.alert("API Key Required", isPresented: $showMissingKeyAlert) {
			Button("OK", role: .cancel) { }
		} message: {
			Text("Please enter your OpenAI API key before leaving settings, or switch to Apple Speech mode.")
		}
	}
}

