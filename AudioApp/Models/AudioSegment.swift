//
//  AudioSegment.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import SwiftData

@Model
class AudioSegment {
	@Attribute(.unique) var id: UUID
	var filePath: String
	var duration: Double
	var transcription: Transcription?
	var isUploaded: Bool

	var fileURL: URL {
		URL(fileURLWithPath: filePath)
	}

	init(id: UUID = UUID(), fileURL: URL, duration: Double, transcription: Transcription? = nil, isUploaded: Bool = false) {
		self.id = id
		self.filePath = fileURL.path
		self.duration = duration
		self.transcription = transcription
		self.isUploaded = isUploaded
	}
}

