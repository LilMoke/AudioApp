//
//  RecordingSession.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import SwiftData

/// Class used to hold a recording session of multiple segments
///
/// This model groups together the audio segments recorded in a session and
/// tracks the date, and allowsfor  optional user notes
///
/// - Properties:
///   - id: Unique identifier for the session
///   - date: The date and time when the session was created
///   - segments: A list of `AudioSegment` recorded for the session
///   - notes: Optional notes or metadata associated with the session
@Model
class RecordingSession {
	@Attribute(.unique) var id: UUID
	var date: Date
	var segments: [AudioSegment]
	var notes: String?

	init(id: UUID = UUID(), date: Date = Date(), segments: [AudioSegment] = [], notes: String? = nil) {
		self.id = id
		self.date = date
		self.segments = segments
		self.notes = notes
	}
}
