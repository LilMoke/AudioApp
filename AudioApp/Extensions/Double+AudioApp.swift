//
//  Double+AudioApp.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation

extension Double {
	/// Returns the original value if it is non-zero; otherwise returns the specified fallback.
	///
	/// A simple utility to help replace zero values with a default. Useful when
	/// reading settings that might be unintentionally zero.
	///
	/// - Parameter fallback: The value to return if `self` is zero.
	/// - Returns: `self` if not zero, or `fallback` if `self` is zero.
	func nonZeroOr(_ fallback: Double) -> Double {
		self != 0 ? self : fallback
	}
}
