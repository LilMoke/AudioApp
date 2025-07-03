//
//  MyAudioLevelBar.swift
//  AudioApp
//
//  Created by Tony Scamurra on 7/2/25.
//

import SwiftUI
import os

private let logger = Logger(subsystem: "AudioApp.AudioManager", category: "Waveform")

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
			.frame(height: maxHeight)
			.onChange(of: level) { _, newLevel in
				let newHeight = CGFloat(newLevel) * maxHeight * CGFloat.random(in: 0.8...1.2)
				withAnimation(.easeOut(duration: 0.1)) {
					bars.append(newHeight)
					bars.removeFirst()
				}
				if newLevel > 0.8 {
					logger.debug("🔊 ScrollingWaveform level spike: \(String(format: "%.2f", newLevel))")
				}
			}
		}
		.frame(height: maxHeight)
	}

	private func gradient(for height: CGFloat) -> LinearGradient {
		let base = Color.green
		let highlight = height > maxHeight * 0.7 ? Color.orange : base
		return LinearGradient(
			gradient: Gradient(colors: [highlight, base]),
			startPoint: .bottom,
			endPoint: .top
		)
	}
}

struct MyAudioLevelBar: View {
	var level: Float // expects normalized 0.0 - 1.0

	private let barCount = 20

	var body: some View {
		HStack(alignment: .center, spacing: 3) {
			ForEach(0..<barCount, id: \.self) { index in
				let heightFactor = CGFloat(level) * CGFloat.random(in: 0.5...1.0)
				RoundedRectangle(cornerRadius: 2)
					.fill(gradient(for: heightFactor))
					.frame(width: 3, height: 20 * heightFactor)
			}
		}
		.frame(height: 24)
		.animation(.easeOut(duration: 0.1), value: level)
		.onChange(of: level) { _, newLevel in
			if newLevel > 0.8 {
				logger.debug("🔊 MyAudioLevelBar level spike: \(String(format: "%.2f", newLevel))")
			}
		}
	}

	private func gradient(for height: CGFloat) -> LinearGradient {
		let startColor = Color.green.opacity(0.7)
		let endColor = height > 0.7 ? Color.orange : startColor
		return LinearGradient(
			gradient: Gradient(colors: [startColor, endColor]),
			startPoint: .bottom,
			endPoint: .top
		)
	}
}

struct RealTimeWaveform: View {
	var level: Float // expects 0.0 to 1.0

	private let barCount = 30

	var body: some View {
		HStack(alignment: .center, spacing: 2) {
			ForEach(0..<barCount, id: \.self) { index in
				let randomFactor = CGFloat.random(in: 0.6...1.2)
				let height = CGFloat(level) * 40 * randomFactor
				Capsule()
					.fill(color(for: height))
					.frame(width: 2, height: max(4, height))
			}
		}
		.frame(height: 50)
		.animation(.easeOut(duration: 0.1), value: level)
		.onChange(of: level) { _, newLevel in
			if newLevel > 0.8 {
				logger.debug("🔊 RealTimeWaveform high input: \(String(format: "%.2f", newLevel))")
			}
		}
	}

	private func color(for height: CGFloat) -> Color {
		if height > 30 {
			return .red
		} else if height > 20 {
			return .orange
		} else {
			return .green
		}
	}
}
