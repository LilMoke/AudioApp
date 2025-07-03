//
//  AudioManager.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import SwiftData
import os

// Logger for this file
private let logger = Logger(subsystem: "AudioApp", category: "AudioManager")

/// AudioManager
///
/// ## Performance Requirements
/// ***As per iOS Audio Recording & Transcription Take-Home Assignment***
///
/// - **Memory Management:**
///   My implementation will efficiently manage memory usage by buffering
///   a single segment of audio data at a time in `segmentBuffers`.
///   Each segment is immediately freed up after writing to disk which allows it
///   to handle long recordings without accumulating a large amount of data in
///   memory buffers.
///
/// - **Battery Optimization:**
///   The audio hardware is managed with `.pause()` and `.stop()` calls in
///   my `AVAudioEngine` to release resources when not recording or paused.
///   This will minimizes the power consumption during long sessions or idle periods.
///   The audio session uses `.notifyOthersOnDeactivation` for use with
///   other audio apps.
///
/// - **Storage Management:**
///   The app cleans up audio files by automatically by deleting segments after
///   transcription is complete, unless the user enables the "Keep Audio Clips"
///   option in the Settings view. This prevents excessive disk usage and gives
///   the user control over whether pr not they want to save the audio file for
///   playback later.
///
@Observable
class AudioManager {
	// Audio session/engine
	private var audioEngine: AVAudioEngine
	private var audioSession: AVAudioSession
	private var inputNode: AVAudioInputNode?
	private var mixerNode: AVAudioMixerNode
	// Buffering/segments
	private var audioFileExtension: String
	private let audioFileFormat: AVAudioFormat
	private var currentSegmentAccumulatedTime: TimeInterval = 0
	private var lastSegmentWriteTime: Date?
	private var segmentBuffers: [AVAudioPCMBuffer] = []
	private var segmentCounter = 0
	private var segmentDuration: TimeInterval
	private var segmentStartTime: AVAudioTime?
	// SwiftData
	private var context: ModelContext
	var currentSession: RecordingSession?
	// Misc
	private var cancellables = Set<AnyCancellable>()
	var inputLevel: Float = 0.0
	var isRecording: Bool = false
	var onBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?
	var onError: ((AppError) -> Void)?

	init(context: ModelContext) {
		self.audioEngine = AVAudioEngine()
		self.audioSession = AVAudioSession.sharedInstance()
		self.mixerNode = AVAudioMixerNode()
		self.context = context

		let sampleRate = UserDefaults.standard.double(forKey: "sampleRate").nonZeroOr(44100)
		let bitDepth = UserDefaults.standard.integer(forKey: "bitDepth").nonZeroOr(16)
		let formatID = kAudioFormatLinearPCM
		let settings: [String: Any] = [
			AVFormatIDKey: formatID,
			AVSampleRateKey: sampleRate,
			AVNumberOfChannelsKey: 1,
			AVLinearPCMBitDepthKey: bitDepth,
			AVLinearPCMIsFloatKey: false
		]

		self.audioFileFormat = AVAudioFormat(settings: settings)!
		self.audioFileExtension = UserDefaults.standard.string(forKey: "audioFormat") ?? "caf"
		self.segmentDuration = UserDefaults.standard.double(forKey: "segmentLength").nonZeroOr(30)

		setupNotifications()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}

// MARK: - Recording Control
extension AudioManager {
	/// Starts a new audio recording session.
	///
	/// This function:
	/// - Configures the AVAudioSession for recording.
	/// - Creates and inserts a new `RecordingSession` into the SwiftData ModelContext.
	/// - Sets up an audio tap on the input node to capture microphone data
	/// - Trys to start the `AVAudioEngine`.
	///
	/// If the engine fails to start, it logs the error and triggers the `onError` callback
	/// to show an alert to the user.
	///
	/// Call this function from the UI when you want to start a new recording.
	func startRecording() {
		configureSession()

		let newSession = RecordingSession(date: Date(), segments: [])
		context.insert(newSession)
		currentSession = newSession

		let inputNode = audioEngine.inputNode
		let format = inputNode.outputFormat(forBus: 0)

		inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
			guard let self = self else { return }
			self.onBuffer?(buffer, time)
			self.calculateInputLevel(buffer: buffer)
			self.accumulateSegment(buffer: buffer, time: time)
		}

		do {
			try audioEngine.start()
			isRecording = true
		} catch {
			let appError = AppError(error: error)
			logger.error("Failed to start audio engine: \(appError)")
			onError?(appError)
		}
	}

	/// Gathers the audio data and writes segments to disk when the bufferDuration is met.
	///
	/// Appends incoming `AVAudioPCMBuffer` data to the segmentBuffers array.
	/// Once the total is >= `segmentDuration` it writes the current segment to disk
	/// and resets the  timer, and clears the buffers to start collecting another segment.
	///
	/// - Parameters:
	///   - buffer: The audio data to save.
	///   - time: The time the data started toi be collected, used to track the time the segment statretd.
	///
	private func accumulateSegment(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
		if segmentStartTime == nil {
			segmentStartTime = time
			currentSegmentAccumulatedTime = 0
		}

		segmentBuffers.append(buffer)
		let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
		currentSegmentAccumulatedTime += bufferDuration

		if currentSegmentAccumulatedTime >= segmentDuration {
			writeCurrentSegmentToDisk()
			currentSegmentAccumulatedTime = 0
			segmentBuffers = []
			segmentStartTime = nil
		}
	}

	/// Stops the audio recording session.
	///
	/// Removes the tap and stops the `AVAudioEngine`.
	/// Writes remaining audio data to disk
	/// clears buffer and resets time
	///
	func stopRecording() {
		audioEngine.inputNode.removeTap(onBus: 0)
		audioEngine.stop()
		isRecording = false

		writeCurrentSegmentToDisk()
		segmentBuffers = []
		currentSegmentAccumulatedTime = 0
		segmentStartTime = nil
	}

	/// Pauses the audio engine but does not remove the tap in case it is stared again,
	/// temporarily halts capture and marks `isRecording` false
	///
	func pauseRecording() {
		audioEngine.pause()
		isRecording = false
		logger.info("Recording paused.")
	}

	/// Trys to resume(start) the engine after being paused and
	/// sets `isRecording` to true
	///
	func resumeRecording() {
		do {
			try audioEngine.start()
			isRecording = true
			logger.info("Recording resumed.")
		} catch {
			logger.error("Failed to resume: \(error)")
		}
	}

	/// Calculates the input level for UI
	///
	/// Computes the RMS and power DB from the `AVAudioPCMBuffer` and
	/// updates `inputLevel` on the main thread with a normalized value between
	/// 0 and 1 for waveform.
	///
	/// - Parameter buffer: Buffer containing PCM data to analyze
	private func calculateInputLevel(buffer: AVAudioPCMBuffer) {
		guard let channelData = buffer.floatChannelData?[0] else { return }
		let channelDataValueArray = stride(
			from: 0,
			to: Int(buffer.frameLength),
			by: buffer.stride
		).map { channelData[$0] }

		let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
		let avgPower = 20 * log10(rms)

		logger.debug("RMS: \(rms), avgPower: \(avgPower, privacy: .public) dB")

		DispatchQueue.main.async {
			self.inputLevel = max(0, (avgPower + 50) / 50)
		}
	}

	/// Writes the audio buffer to disk as a  audio file.
	///
	/// Puts the current `segmentBuffers` into an `AVAudioFile` and saves it to the
	/// documents directory or a temporary directory depending on the `keepAudioClips`
	/// setting. Makes a unique filename for each segment.
	/// After writing calls `saveSegmentInSwiftData` to keep track of it in the SwiftData model.
	///
	private func writeCurrentSegmentToDisk() {
		guard !segmentBuffers.isEmpty else { return }

		let keepAudioClips = UserDefaults.standard.bool(forKey: "keepAudioClips")
		let baseURL = keepAudioClips
		? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		: FileManager.default.temporaryDirectory

//		let filename = "segment_\(UUID().uuidString).\(audioFileExtension)"
		let filename = "segment_\(UUID().uuidString).wav"	// Must be .wav for OpenAI Whisper
		let fileURL = baseURL.appendingPathComponent(filename)

		do {
			let file = try AVAudioFile(forWriting: fileURL, settings: audioFileFormat.settings)
			for buffer in segmentBuffers {
				try file.write(from: buffer)
			}
			logger.info("Wrote segment to \(fileURL.path)")
			saveSegmentInSwiftData(url: fileURL, duration: segmentDuration)
		} catch {
			logger.error("Failed writing segment: \(error)")
			onError?(AppError(error: error))
		}
	}

	/// Save a `AudioSegment` in the SwiftData model and starts transcription.
	///
	/// Creates an `AudioSegment` object with the given file `url` and `duration`,
	/// inserts it into the current SwiftData `context`, and appends it to the
	/// `currentSession` segments list.
	///
	/// After saving, it trys to start an asynchronous task to transcribe it
	///
	/// - Parameters:
	///   - url: The file URL where the audio segment was saved
	///   - duration: The length of the audio segment in seconds
	private func saveSegmentInSwiftData(url: URL, duration: Double) {
		let segment = AudioSegment(fileURL: url, duration: duration)
		context.insert(segment)

		currentSession?.segments.append(segment)

		do {
			try context.save()
		} catch {
			logger.error("Failed to save context: \(error)")
		}

		Task {
			await transcribeSegment(segmentID: segment.id)
		}
	}

	/// Transcribes a segment and updates the model data for it
	///
	/// Gets the `AudioSegment` by its `UUID` from the SwiftData context,
	/// sends the audio file to a `TranscriptionServiceProtocol` for transcription,
	/// and updates the segment with the returned text. Marks it as uploaded
	/// and attempts to save it
	///
	/// If the user preference `keepAudioClips` is off, deletes the audio file
	/// from disk after it is transcribed
	///
	/// - Parameter segmentID: Identifier of the `AudioSegment` to transcribe
	private func transcribeSegment(segmentID: UUID) async {
		let keepAudioClips = UserDefaults.standard.bool(forKey: "keepAudioClips")

		do {
			let request = FetchDescriptor<AudioSegment>(predicate: #Predicate { $0.id == segmentID })
			guard let segment = try? context.fetch(request).first else {
				logger.error("Could not fetch segment for ID \(segmentID)")
				return
			}

			var text: String
			do {
				let openAIService = OpenAITranscriptionService()
				logger.info("Attempting transcription via OpenAI Whisper service.")
				text = try await openAIService.transcribeAudioFile(url: segment.fileURL)
				logger.info("Transcription via OpenAI Whisper succeeded.")
			} catch {
				logger.warning("OpenAI Whisper transcription failed: \(error.localizedDescription). Falling back to local Apple Speech.")
				do {
					let appleService = AppleSpeechRecognizerService(onError: onError)
					text = try await appleService.transcribeAudioFile(url: segment.fileURL)
					logger.info("Transcription via Apple Speech succeeded.")
				} catch {
					logger.error("Fallback to Apple Speech also failed: \(error.localizedDescription)")
					onError?(AppError(error: error))
					return
				}
			}

			segment.transcription = Transcription(text: text)
			segment.isUploaded = true
			try context.save()
			logger.info("Saved transcription: \(text)")

			if !keepAudioClips {
				try? FileManager.default.removeItem(at: segment.fileURL)
				logger.info("Deleted audio file after transcription: \(segment.fileURL.lastPathComponent)")
			}

		} catch {
			logger.error("Failed transcription pipeline: \(error.localizedDescription)")
			onError?(AppError(error: error))
		}
	}
//	private func transcribeSegment(segmentID: UUID) async {
//		let keepAudioClips = UserDefaults.standard.bool(forKey: "keepAudioClips")
//
//		do {
//			let request = FetchDescriptor<AudioSegment>(predicate: #Predicate { $0.id == segmentID })
//			guard let segment = try? context.fetch(request).first else {
//				logger.error("Could not fetch segment for ID \(segmentID)")
//				return
//			}
//
//			var text: String
//			do {
//				let openAIService = OpenAITranscriptionService()
//				logger.info("Attempting transcription via OpenAI Whisper service.")
//				text = try await openAIService.transcribeAudioFile(url: segment.fileURL)
//				logger.info("Transcription via OpenAI succeeded.")
//			} catch {
//				logger.warning("OpenAI transcription failed: \(error.localizedDescription). Falling back to Apple Speech.")
//				do {
//					let appleService = AppleSpeechRecognizerService(onError: onError)
//					text = try await appleService.transcribeAudioFile(url: segment.fileURL)
//					logger.info("Transcription via Apple Speech succeeded.")
//				} catch {
//					logger.error("Fallback to Apple Speech also failed: \(error.localizedDescription)")
//					onError?(AppError(error: error))
//					return
//				}
//			}
//
//			segment.transcription = Transcription(text: text)
//			segment.isUploaded = true
//			try context.save()
//			logger.info("Saved transcription: \(text)")
//
//			if !keepAudioClips {
//				try? FileManager.default.removeItem(at: segment.fileURL)
//				logger.info("Deleted audio file after transcription: \(segment.fileURL.lastPathComponent)")
//			}
//
//		} catch {
//			logger.error("Failed transcription pipeline: \(error.localizedDescription)")
//			onError?(AppError(error: error))
//		}
//	}
}

// MARK: - Audio Session
extension AudioManager {
	/// Configures the `AVAudioSession` to record and play
	///
	/// Sets the audio session with `.playAndRecord` for input and output also enables
	/// speaker playback with Bluetooth support.  It also activates the session
	/// with `.notifyOthersOnDeactivation` to handle audio interruptions gracefully as
	/// per requirement
	///
	private func configureSession() {
		do {
			try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
			try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
		} catch {
			logger.error("Failed to set up AVAudioSession: \(error.localizedDescription)")
		}
	}
}

// MARK: - Notifications
extension AudioManager {
	/// Sets up notifications for the route changes and any interruptions
	///
	/// Registers observers for `AVAudioSession.routeChangeNotification` and
	/// `AVAudioSession.interruptionNotification` to handle the cases like
	/// headphones being plugged or unplugged or phone calls interrupting audio
	private func setupNotifications() {
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleRouteChange),
			name: AVAudioSession.routeChangeNotification,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleInterruption),
			name: AVAudioSession.interruptionNotification,
			object: nil
		)
	}

	/// Handles changes to the audio route like headphones being plugged and unplugged
	///
	/// Called automatically by the NotificationCenter. If a device like headphones is unplugged while
	/// recording it restarts the engine to keep consistent input/output
	@objc private func handleRouteChange(notification: Notification) {
		guard let userInfo = notification.userInfo,
			  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
			  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

		switch reason {
			case .newDeviceAvailable:
				logger.info("New device available (e.g. headphones plugged in).")
			case .oldDeviceUnavailable:
				logger.info("Old device removed (e.g. headphones unplugged).")
				if isRecording {
					restartAudioEngine()
				}
			case .categoryChange:
				logger.info("Audio session category changed.")
			default:
				break
		}
	}

	/// Handles interruptions to the session like a phone call or Siri
	///
	/// If an interruption happens while recording it stops recording
	/// When the interruption stops it checks if the session should resume automatically
	/// and restarts recording
	@objc private func handleInterruption(notification: Notification) {
		guard let userInfo = notification.userInfo,
			  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
			  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

		if type == .began {
			logger.info("Audio session interruption began.")
			if isRecording {
				stopRecording()
			}
		} else if type == .ended {
			logger.info("Audio session interruption ended.")
			if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
				let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
				if options.contains(.shouldResume) && !isRecording {
					startRecording()
				}
			}
		}
	}

	/// Stops and Starts the engine to restart it
	///
	/// Called after a route change like unplugging headphones, etc.
	private func restartAudioEngine() {
		stopRecording()
		startRecording()
	}
}
