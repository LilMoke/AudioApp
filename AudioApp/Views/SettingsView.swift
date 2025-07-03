//
//  SettingsView.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI

struct SettingsView: View {
	@AppStorage("keepAudioClips") private var keepAudioClips: Bool = false
	@AppStorage("segmentLength") private var segmentLength: Double = 30
	@AppStorage("sampleRate") private var sampleRate: Double = 44100
	@AppStorage("bitDepth") private var bitDepth: Int = 16
	@AppStorage("audioFormat") private var audioFormat: String = "caf"

	var body: some View {
		Form {
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
	}
}


