//
//  UserDefaults+AudioApp.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import Foundation

//extension UserDefaults {
//	static var segmentLength: Double {
//		get {
//			let value = UserDefaults.standard.double(forKey: "segmentLength")
//			return value != 0 ? value : 30
//		}
//		set {
//			UserDefaults.standard.set(newValue, forKey: "segmentLength")
//		}
//	}
//
//	static var sampleRate: Double {
//		get {
//			let value = UserDefaults.standard.double(forKey: "sampleRate")
//			return value != 0 ? value : 44100
//		}
//		set {
//			UserDefaults.standard.set(newValue, forKey: "sampleRate")
//		}
//	}
//
//	static var bitDepth: Int {
//		get {
//			let value = UserDefaults.standard.integer(forKey: "bitDepth")
//			return value != 0 ? value : 16
//		}
//		set {
//			UserDefaults.standard.set(newValue, forKey: "bitDepth")
//		}
//	}
//
//	static var audioFormat: String {
//		get {
//			UserDefaults.standard.string(forKey: "audioFormat") ?? "caf"
//		}
//		set {
//			UserDefaults.standard.set(newValue, forKey: "audioFormat")
//		}
//	}
//}

extension Double {
	func nonZeroOr(_ fallback: Double) -> Double {
		self != 0 ? self : fallback
	}
}

extension Int {
	func nonZeroOr(_ fallback: Int) -> Int {
		self != 0 ? self : fallback
	}
}
