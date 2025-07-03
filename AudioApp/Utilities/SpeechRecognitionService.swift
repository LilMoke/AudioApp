//
//  SpeechRecognitionService.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation
import Speech
import os

// Logger for this file
private let logger = Logger(subsystem: "AudioApp", category: "TranscriptionService")

protocol TranscriptionServiceProtocol {
	func transcribeAudioFile(url: URL) async throws -> String
}

// MARK: - Local Apple Speech Recognizer
actor AppleSpeechRecognizerService: TranscriptionServiceProtocol {
	init() {
		SFSpeechRecognizer.requestAuthorization { status in
			switch status {
				case .authorized:
					logger.debug("Speech recognition authorized.")
				default:
					logger.error("Speech not authorized: \(status.rawValue, privacy: .public)")
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
actor OpenAITranscriptionService: TranscriptionServiceProtocol {
	private let session: URLSession
	private let maxRetries = 5
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
				logger.warning("Attempt \(attempt) failed for \(url.lastPathComponent, privacy: .public), retrying in \(delay, privacy: .public)s...")
				try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
				delay *= 2
			}
		}
		throw URLError(.cannotConnectToHost)
	}

	private func uploadFile(fileURL: URL) async throws -> String {
		let endpoint = URL(string: "https://your-transcription-api.com/transcribe")!
		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		let boundary = UUID().uuidString
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		request.setValue("Bearer YOUR_API_KEY", forHTTPHeaderField: "Authorization")

		let httpBody = try createMultipartBody(fileURL: fileURL, boundary: boundary)
		request.httpBody = httpBody

		logger.debug("Uploading file: \(fileURL.lastPathComponent, privacy: .public) to remote transcription service.")

		let (data, response) = try await session.data(for: request)
		guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
			logger.error("Bad server response during transcription upload.")
			throw URLError(.badServerResponse)
		}

		let transcription = try parseTranscriptionResponse(data: data)
		logger.debug("Remote transcription complete: \(transcription, privacy: .public)")
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
