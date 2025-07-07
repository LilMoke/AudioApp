//
//  AudioSegment.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import SwiftData

/// Class use to hold a single recorded audio segmen
///
/// Keeps track of the file path, duration, transcription result, and upload state
/// Automatically computes the `fileURL` from the stored path
///
/// - Properties:
///   - id: Unique identifier for the segment
///   - filePath: Local file system path where the audio is located
///   - duration: Length of the audio in seconds
///   - transcription: Ttranscription data for ther segment
///   - isUploaded: Indicates whether the segment has been uploaded or not
///   - fileURL: Convenience computed URL from `filePath` because we cannot stroe a URL in SwiftData
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

