//
//  ScrollingWaveform.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI
import os

private let logger = Logger(subsystem: "AudioApp.AudioManager", category: "Waveform")

/// A live scrolling audio waveform view similiar to iOS Voice Memos
///
/// `ScrollingWaveform` displays a horizontal row of animated bars that represent
/// audio input levels, simulating a waveform line in the iOS Voice Memos App. As new
/// `level` values arrive they push existing bars to the left, creating the scrolling effect
///
/// The waveform height changes with animation and also highlights
/// bars in orange when exceeding a certain threshold.
///
/// - Parameters:
///   - level: A `Float` from `0.0` to `1.0` representing the normalized
///     audio input level from the microphone
///
/// ## Example Usage
/// ```swift
/// ScrollingWaveform(level: audioManager.inputLevel)
///     .frame(height: 50)
/// ```
struct ScrollingWaveform: View {
	var level: Float // 0.0 to 1.0

	@State private var bars: [CGFloat] = Array(repeating: 0.0, count: 50)
	private let maxHeight: CGFloat = 50

	var body: some View {
		GeometryReader { geometry in
			HStack(alignment: .center, spacing: 2) {
				ForEach(0..<bars.count, id: \.self) { index in
					Capsule()
						.fill(gradient(for: bars[index]))
						.frame(width: 3, height: max(4, bars[index]))
				}
			}
			.frame(maxWidth: .infinity, maxHeight: maxHeight)
			.onChange(of: level) { _, newLevel in
				let newHeight = CGFloat(newLevel) * maxHeight * CGFloat.random(in: 0.8...1.2)
				withAnimation(.easeOut(duration: 0.1)) {
					bars.append(newHeight)
					bars.removeFirst()
				}
				if newLevel > 0.8 {
					logger.debug("ScrollingWaveform level spike: \(String(format: "%.2f", newLevel))")
				}
			}
		}
		.frame(height: maxHeight)
	}

	private func gradient(for height: CGFloat) -> LinearGradient {
		let base = Color.white
		let highlight = height > maxHeight * 0.4 ? .audioAppRed : base
		return LinearGradient(
			gradient: Gradient(colors: [highlight, base]),
			startPoint: .bottom,
			endPoint: .top
		)
	}
}
