//
//  AppError.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/3/25.
//

import Foundation
import os

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
