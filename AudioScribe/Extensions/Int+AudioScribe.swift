//
//  Int+AudioScribe.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation

extension Int {
	/// Returns `self` if it is not zero, otherwise returns the fallback
	///
	/// Useful for ensuring a non-zero integer when a default is needed
	///
	/// - Parameter fallback: The value to return if `self` is zero.
	/// - Returns: `self` if non-zero; otherwise `fallback`.
	func nonZeroOr(_ fallback: Int) -> Int {
		self != 0 ? self : fallback
	}
}
