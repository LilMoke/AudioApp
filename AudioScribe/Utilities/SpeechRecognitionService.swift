//
//  SpeechRecognitionService.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import Speech
import os

// Logger for this file
private let logger = Logger(subsystem: "AudioScribe", category: "TranscriptionService")

/// A protocol for defineing a common interface for audio transcription services like
/// AppleSpeechRecognizerService and the OpenAI Whisper Service as per requirement
///
/// Type that conform to the protocol provide an async function that takes a local audio file URL
/// and then returns transcribed text or it will throw and error if it fails. This enables swapping
/// between different local or remote transcription implementations as per the requirement
protocol TranscriptionServiceProtocol {
	func transcribeAudioFile(url: URL) async throws -> String
}

// MARK: - Local Apple Speech Recognizer
/// `AppleSpeechRecognizerService`
///
/// This actor implements the `TranscriptionServiceProtocol` using the built-in Apple `SFSpeechRecognizer`.
/// It requests authorization for speech recognition and then does the transcription on the local audio
/// using `SFSpeechURLRecognitionRequest`.
///
/// - The actor is initialized with an optional `onError` closure that is called
///   if speech recognition authorization fails or is denied. This way the UI
///   can display a user-friendly alert.
///
/// - The `transcribeAudioFile(url:)` function asynchronously transcribes the audio
///   file at the URL. It wraps the task in a `withCheckedThrowingContinuation` as to
///   use Swift's structured concurrency
///
/// Example usage:
/// ```swift
/// let service = AppleSpeechRecognizerService(onError: { appError in
///     // Handle permission errors immediately
/// })
/// let text = try await service.transcribeAudioFile(url: audioFileURL)
/// ```
///
actor AppleSpeechRecognizerService: TranscriptionServiceProtocol {
	private let onError: ((AppError) -> Void)?

	init(onError: ((AppError) -> Void)? = nil) {
		self.onError = onError
		SFSpeechRecognizer.requestAuthorization { status in
			switch status {
				case .authorized:
					logger.debug("Speech recognition authorized.")
				default:
					let err = AppError(domain: "SpeechRecognizer", code: Int(status.rawValue), message: "Speech recognition not authorized: \(status.rawValue)")
					onError?(err)
			}
		}
	}

	func transcribeAudioFile(url: URL) async throws -> String {
		return try await withCheckedThrowingContinuation { continuation in
			guard let recognizer = SFSpeechRecognizer() else {
				let errMsg = "No speech recognizer available"
				logger.error("\(errMsg)")
				continuation.resume(throwing: NSError(domain: "SpeechRecognizer", code: -1, userInfo: [NSLocalizedDescriptionKey: errMsg]))
				return
			}

			let request = SFSpeechURLRecognitionRequest(url: url)
			logger.debug("Started transcription for file: \(url.lastPathComponent, privacy: .public)")

			recognizer.recognitionTask(with: request) { result, error in
				if let error = error {
					logger.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
					continuation.resume(throwing: error)
				} else if let result = result, result.isFinal {
					let text = result.bestTranscription.formattedString
					logger.debug("Transcription complete: \(text, privacy: .public)")
					continuation.resume(returning: text)
				}
			}
		}
	}
}

// MARK: - Remote OpenAI Whisper Service
/// `OpenAITranscriptionService`
///
/// This actor implements the `TranscriptionServiceProtocol` by sending audio files
/// to the remote transcription endpointOpenAI Whisper. It handles retrying failed requests and
/// makes sure that requests are performed asynchronously via Swift Concurrency.
///
/// - The actor is initialized with a custom `URLSession`
///
/// - The `transcribeAudioFile(url:)` function uploads the audio file using a
///   multipart/form-data POST request, and decodes the resulting transcription text
///   from the server. It retries failed attempts with increasing delays.
///
/// Example usage:
/// ```swift
/// let service = OpenAITranscriptionService()
/// let text = try await service.transcribeAudioFile(url: audioFileURL)
/// ```
///
actor OpenAITranscriptionService: TranscriptionServiceProtocol {
	private let session: URLSession
	private let maxRetries = 5	// Fallback if transcription failed consecutively for 5+ times. This is per requirement.
	private let initialDelay: TimeInterval = 2

	init() {
		let config = URLSessionConfiguration.default
		config.timeoutIntervalForRequest = 30
		config.httpMaximumConnectionsPerHost = 4
		self.session = URLSession(configuration: config)
	}

	func transcribeAudioFile(url: URL) async throws -> String {
		var attempt = 0
		var delay = initialDelay

		while attempt < maxRetries {
			do {
				let result = try await uploadFile(fileURL: url)
				return result
			} catch {
				attempt += 1
				if attempt >= maxRetries {
					logger.error("Max retries reached. Could not transcribe file: \(url.lastPathComponent, privacy: .public)")
					throw error
				}

				// Add jitter: randomize delay slightly to avoid synchronized retries
				let jitter = Double.random(in: 0.8...1.2)
				let actualDelay = min(delay * jitter, 60)
				logger.warning("Attempt \(attempt) failed for \(url.lastPathComponent, privacy: .public), retrying in \(String(format: "%.2f", actualDelay))s...")

				try await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
				delay *= 2
			}
		}
		throw URLError(.cannotConnectToHost)
	}
	
	private func uploadFile(fileURL: URL) async throws -> String {
		guard let keyData = KeychainHelper.shared.read(service: "com.myapp.openai", account: "apiKey"),
			  let openAIApiKey = String(data: keyData, encoding: .utf8),
			  !openAIApiKey.isEmpty else {
			let error = NSError(
				domain: "OpenAIKeychain",
				code: -1,
				userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not found in Keychain. Please set it in Settings."]
			)
			throw error
		}

		let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		let boundary = UUID().uuidString
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		request.setValue("Bearer \(openAIApiKey)", forHTTPHeaderField: "Authorization")

		let httpBody = try createMultipartBody(fileURL: fileURL, boundary: boundary)
		request.httpBody = httpBody

		logger.debug("Uploading file to OpenAI Whisper endpoint: \(fileURL.lastPathComponent, privacy: .public)")

		let (data, response) = try await session.data(for: request)
		guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
			logger.error("OpenAI Whisper returned bad status: \(response)")
			throw URLError(.badServerResponse)
		}

		let transcription = try parseTranscriptionResponse(data: data)
		logger.debug("OpenAI Whisper transcription complete: \(transcription, privacy: .public)")
		return transcription
	}

	private func createMultipartBody(fileURL: URL, boundary: String) throws -> Data {
		var body = Data()
		let filename = fileURL.lastPathComponent
		let data = try Data(contentsOf: fileURL)

		body.append("--\(boundary)\r\n".data(using: .utf8)!)
		body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
		body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
		body.append(data)
		body.append("\r\n".data(using: .utf8)!)

		// Add the `model` field
		body.append("--\(boundary)\r\n".data(using: .utf8)!)
		body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
		body.append("whisper-1\r\n".data(using: .utf8)!)

		body.append("--\(boundary)--\r\n".data(using: .utf8)!)
		return body
	}

	private func parseTranscriptionResponse(data: Data) throws -> String {
		struct TranscriptionResponse: Decodable {
			let text: String
		}
		let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
		return decoded.text
	}
}
