//
//  Transcription.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import SwiftData

/// Model for a transcription
///
/// Stores the transcribed text and the timestamp when the transcription was created
///
/// - Properties:
///   - text: Transcribed text from speech recognition.
///   - created: The date and time when this transcription was created
@Model
class Transcription {
	var text: String
	var created: Date

	init(text: String, created: Date = Date()) {
		self.text = text
		self.created = created
	}
}
