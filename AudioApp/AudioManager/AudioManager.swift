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

	func stopRecording() {
		audioEngine.inputNode.removeTap(onBus: 0)
		audioEngine.stop()
		isRecording = false

		writeCurrentSegmentToDisk()
		segmentBuffers = []
		currentSegmentAccumulatedTime = 0
		segmentStartTime = nil
	}

	func pauseRecording() {
		audioEngine.pause()
		isRecording = false
		logger.info("Recording paused.")
	}

	func resumeRecording() {
		do {
			try audioEngine.start()
			isRecording = true
			logger.info("Recording resumed.")
		} catch {
			logger.error("Failed to resume: \(error)")
		}
	}

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

	private func writeCurrentSegmentToDisk() {
		guard !segmentBuffers.isEmpty else { return }

		let keepAudioClips = UserDefaults.standard.bool(forKey: "keepAudioClips")
		let baseURL = keepAudioClips
		? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		: FileManager.default.temporaryDirectory

		let filename = "segment_\(UUID().uuidString).\(audioFileExtension)"
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
		}
	}

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

	private func transcribeSegment(segmentID: UUID) async {
		let service: TranscriptionServiceProtocol = AppleSpeechRecognizerService()
		let keepAudioClips = UserDefaults.standard.bool(forKey: "keepAudioClips")

		do {
			let request = FetchDescriptor<AudioSegment>(predicate: #Predicate { $0.id == segmentID })
			if let segment = try? context.fetch(request).first {
				let text = try await service.transcribeAudioFile(url: segment.fileURL)
				segment.transcription = Transcription(text: text)
				segment.isUploaded = true
				try context.save()
				logger.info("Transcribed: \(text)")

				if !keepAudioClips {
					try? FileManager.default.removeItem(at: segment.fileURL)
					logger.info("Deleted audio file: \(segment.fileURL.lastPathComponent)")
				}
			}
		} catch {
			logger.error("Failed transcription: \(error.localizedDescription)")
		}
	}
}

// MARK: - Audio Session
extension AudioManager {
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

	private func restartAudioEngine() {
		stopRecording()
		startRecording()
	}
}
