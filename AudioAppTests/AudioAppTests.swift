//
//  AudioAppTests.swift
//  AudioAppTests
//
//  Created by Tony Scamurra on 7/2/25.
//

import Testing
import XCTest
import SwiftData
import AVFAudio

@testable import AudioApp

final class AudioAppTests: XCTestCase {

	// MARK: - Unit Tests

	/// Test to make sure that adding an `AudioSegment` to a `RecordingSession` correctly stores the segment
	///
	/// This test verifies the following:
	/// - A new `RecordingSession` starts with an empty segments array.
	/// - Appending an `AudioSegment` increases the count to 1
	/// - The duration of the first segment matches the expected value
	func testRecordingSessionAddsSegment() {
		let duration = 10.0
		let session = RecordingSession(date: Date(), segments: [])
		let segment = AudioSegment(fileURL: URL(fileURLWithPath: "/tmp/test.wav"), duration: duration)
		session.segments.append(segment)

		XCTAssertEqual(session.segments.count, 1)
		XCTAssertEqual(session.segments.first?.duration, duration)
	}

	/// This test makes sure an `AudioSegment`  stores and returns the file URL and the duration
	///
	/// Make sure the `AudioSegment` model initializes with the right values
	/// and that its `fileURL` and `duration` properties return the correct values
	func testAudioSegmentStoresData() {
		let url = URL(fileURLWithPath: "/tmp/file.m4a")
		let segment = AudioSegment(fileURL: url, duration: 5.5)
		XCTAssertEqual(segment.fileURL, url)
		XCTAssertEqual(segment.duration, 5.5)
	}

	/// Tests saving and reading back from the `KeychainHelper`
	///
	/// Verifies that the `KeychainHelper` correctly stores data under
	/// a specified service and account, and then retrieve the same data to
	/// make sure the data can be retrieved
	func testKeychainHelperSavesAndReads() {
		let helper = KeychainHelper.shared
		let data = "TestData".data(using: .utf8)!
		helper.save(data, service: "com.test.keychain", account: "test")

		let loaded = helper.read(service: "com.test.keychain", account: "test")
		XCTAssertEqual(loaded, data)
	}

	func testAppErrorCreatesProperly() {
		let err = AppError(domain: "TestDomain", code: 42, message: "Testing")
		XCTAssertEqual(err.domain, "TestDomain")
		XCTAssertEqual(err.code, 42)
		XCTAssertEqual(err.message, "Testing")
	}

	// MARK: - Integration Tests

	/// Tests that the `AudioManager` writes audio segments properly to disk and records them in the session
	func testAudioManagerWritesFile() async throws {
		await createTestContainer { container, context in
			let audioManager = AudioManager(context: context)

			// use this test helper extension function because segmentDuration is a private var
			audioManager.testOnlySetSegmentDuration(0.01)

			let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
			let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
			buffer.frameLength = 1024

			audioManager.startRecording()
			for _ in 0..<5 {
				// use this test helper extension function because the accumulateSegment function is a private func
				audioManager.testOnlyAccumulateSegment(buffer: buffer, time: AVAudioTime(hostTime: 0))
			}

			audioManager.stopRecording()
			XCTAssertNotNil(audioManager.currentSession)
			XCTAssertTrue(audioManager.currentSession!.segments.count > 0)
		}
	}

	// MARK: - Edge Cases

	// TODO: Create edge case tests

	// MARK: - Performance
	/// Measures the performance of inserting/saving a lot of `AudioSegment` models into SwiftData
	///
	/// It sets up an in-memory `ModelContext` using `createTestContainer` and inserts
	/// 1,000 `AudioSegment` objects with unique file paths. It uses XCTest’s `measure` to log
	/// how long it takes to perform inserts saves
		await createTestContainer { container, context in
			measure {
				for _ in 0..<1000 {
					let segment = AudioSegment(fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).wav"), duration: 5)
					context.insert(segment)
				}
				try? context.save()
			}
		}
	}

	// MARK: - Helper for Swift 6 concurrency
	/// Helper function to create a fresh in-memory SwiftData container and context for testing on the main actor
	///
	/// This is used to make sure:
	/// - A new `ModelContainer` is set up with `RecordingSession` and `AudioSegment` models
	private func createTestContainer(_ work: @MainActor (ModelContainer, ModelContext) throws -> Void) async rethrows {
		try await MainActor.run {
			let container = try ModelContainer(
				for: RecordingSession.self, AudioSegment.self,
				configurations: ModelConfiguration(isStoredInMemoryOnly: true)
			)
			let context = container.mainContext
			try work(container, context)
		}
	}
}


