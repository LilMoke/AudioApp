//
//  Error+AudioApp.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/3/25.
//

import Foundation

extension Error {
	var asNSError: NSError { self as NSError }
	var code: Int { (self as NSError).code }
	var domain: String { (self as NSError).domain }
}
