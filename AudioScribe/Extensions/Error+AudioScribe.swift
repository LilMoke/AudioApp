//
//  Error+AudioScribe.swift
//  AudioScribe
//
//  Created by Tony Scamurra on 7/3/25.
//

import Foundation

/// Convenience extensions to extract `NSError` properties from any `Error`.
///
/// Provides easy access to the underlying `NSError`, its `code`, and `domain`
/// for easier logging and error handling
extension Error {
	var asNSError: NSError {  self as NSError }
	var code:      Int     { (self as NSError).code }
	var domain:    String  { (self as NSError).domain }
}
