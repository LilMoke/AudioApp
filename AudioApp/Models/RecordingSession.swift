//
//  RecordingSession.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import SwiftData

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
