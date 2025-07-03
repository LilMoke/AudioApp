//
//  Transcription.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import SwiftData

@Model
class Transcription {
	var text: String
	var confidence: Double
	var created: Date

	init(text: String, confidence: Double = 0.0, created: Date = Date()) {
		self.text = text
		self.confidence = confidence
		self.created = created
	}
}

@MainActor
class TranscriptionModel: ObservableObject {
	private let transcriptionService: TranscriptionServiceProtocol = AppleSpeechRecognizerService()
	
	@Published var transcriptionResult: String?
	@Published var isTranscribing: Bool = false
	@Published var errorMessage: String?

	func transcribeAudioSegment(_ url: URL) {
		let transcriptionService = self.transcriptionService // capture safely
		Task {
			isTranscribing = true
			do {
				let text = try await transcriptionService.transcribeAudioFile(url: url)
				transcriptionResult = text
			} catch {
				errorMessage = "Failed: \(error.localizedDescription)"
			}
			isTranscribing = false
		}
	}
}

