//
//  AppError.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/3/25.
//

import Foundation
import os

/// For use in SwiftUI alerts and logging
///
/// `AppError` wraps any Swift `Error` into a uniform structure, capturing its domain, code,
/// and user-friendly message. It also conforms to `Identifiable` for SwiftUI and `CustomStringConvertible`
/// to make logging easy
///
/// - Properties:
///   - id: A unique identifier
///   - domain: Domain of the error from `NSError.domain`
///   - code: Error code from `NSError.code`
///   - message: The human-readable description of the error
///
/// - Usage:
///   You can initialize it directly from any `Error`, or create one manually with a domain, code and message
///   The static `handle` helper logs the error and assigns it into a binding, to be used with `@State`
///   to drive an alert in the UI
///
/// - Example:
///   ```swift
///   @State private var activeError: AppError?
///
///   do {
///       try someFunctionThatThrows()
///   } catch {
///       AppError.handle(error, into: &activeError, logger: logger)
///   }
///   ```
struct AppError: Identifiable, CustomStringConvertible {
	let id = UUID()
	let domain: String
	let code: Int
	let message: String

	var description: String {
		"\(domain) [\(code)]: \(message)"
	}

	init(error: Error) {
		let nsError = error as NSError
		self.domain = nsError.domain
		self.code = nsError.code
		self.message = nsError.localizedDescription
	}

	init(domain: String, code: Int, message: String) {
		self.domain = domain
		self.code = code
		self.message = message
	}

	static func handle(_ error: Error, into binding: inout AppError?, logger: Logger, message: String? = nil) {
		let appError = AppError(error: error)
		binding = appError
		if let message {
			logger.error("\(message): \(appError)")
		} else {
			logger.error("\(appError)")
		}
	}
}
