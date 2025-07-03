//
//  Transcription.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import SwiftData

/// Model for a transcription
///
/// Stores the transcribed text, a confidence score and the timestamp when the transcription was created
///
/// - Properties:
///   - text: Transcribed text from speech recognition.
///   - confidence: A numeric confidence level for the transcription
///   - created: The date and time when this transcription was created
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
