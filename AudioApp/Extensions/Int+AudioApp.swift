//
//  Int+AudioApp.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation

extension Int {
	func nonZeroOr(_ fallback: Int) -> Int {
		self != 0 ? self : fallback
	}
}
