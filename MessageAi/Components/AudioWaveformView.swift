//
//  AudioWaveformView.swift
//  MessageAi
//
//  Visualizes audio waveform with optional scrubbing
//

import SwiftUI

struct AudioWaveformView: View {
    let samples: [Float]
    let color: Color
    let progress: Double // 0.0 to 1.0
    var isInteractive: Bool = false
    var onSeek: ((Double) -> Void)?

    private let barSpacing: CGFloat = 2
    private let minBarHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(Array(normalizedSamples.enumerated()), id: \.offset) { index, sample in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: barWidth(geometry: geometry), height: barHeight(sample: sample, geometry: geometry))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                isInteractive ? DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let seekPosition = value.location.x / geometry.size.width
                        onSeek?(min(max(seekPosition, 0), 1))
                    } : nil
            )
        }
    }

    private var normalizedSamples: [Float] {
        guard !samples.isEmpty else {
            return Array(repeating: 0.3, count: 50) // Default placeholder
        }
        return samples
    }

    private func barWidth(geometry: GeometryProxy) -> CGFloat {
        let totalSpacing = barSpacing * CGFloat(normalizedSamples.count - 1)
        let availableWidth = geometry.size.width - totalSpacing
        return max(2, availableWidth / CGFloat(normalizedSamples.count))
    }

    private func barHeight(sample: Float, geometry: GeometryProxy) -> CGFloat {
        let maxHeight = geometry.size.height
        let calculatedHeight = CGFloat(sample) * maxHeight
        return max(minBarHeight, calculatedHeight)
    }

    private func barColor(for index: Int) -> Color {
        let sampleProgress = Double(index) / Double(normalizedSamples.count)
        return sampleProgress <= progress ? color : color.opacity(0.3)
    }
}

// Recording waveform (live visualization)
struct RecordingWaveformView: View {
    let samples: [Float]

    var body: some View {
        AudioWaveformView(
            samples: samples,
            color: .red,
            progress: 1.0,
            isInteractive: false
        )
        .frame(height: 40)
    }
}

// Playback waveform (with scrubbing)
struct PlaybackWaveformView: View {
    let samples: [Float]
    let progress: Double
    let onSeek: (Double) -> Void

    var body: some View {
        AudioWaveformView(
            samples: samples,
            color: .blue,
            progress: progress,
            isInteractive: true,
            onSeek: onSeek
        )
        .frame(height: 50)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Recording preview
        RecordingWaveformView(samples: (0..<50).map { _ in Float.random(in: 0.2...1.0) })
            .padding()

        // Playback preview
        PlaybackWaveformView(
            samples: (0..<50).map { _ in Float.random(in: 0.2...1.0) },
            progress: 0.6,
            onSeek: { position in
                print("Seeking to \(position)")
            }
        )
        .padding()
    }
}
