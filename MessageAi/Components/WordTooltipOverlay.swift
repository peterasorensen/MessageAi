//
//  WordTooltipOverlay.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

struct WordTooltipOverlay: View {
    let wordTranslation: WordTranslation
    let wordPosition: CGRect
    let onDismiss: () -> Void
    let onShowDetails: () -> Void

    @State private var tooltipPosition: TooltipPosition = .below

    enum TooltipPosition {
        case above, below
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dismiss background
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            onDismiss()
                        }
                    }

                // Tooltip card positioned relative to word
                VStack(spacing: 0) {
                    // Arrow pointing to word (when below)
                    if tooltipPosition == .below {
                        Triangle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(width: 20, height: 10)
                            .offset(x: calculateArrowOffset(in: geometry), y: 0)
                    }

                    // Tooltip content
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(wordTranslation.originalWord)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(wordTranslation.translation)
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                            Spacer(minLength: 12)
                            Button {
                                withAnimation {
                                    onDismiss()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(wordTranslation.partOfSpeech)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(Capsule())

                        Button {
                            onShowDetails()
                        } label: {
                            HStack(spacing: 6) {
                                Text("More details")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .shadow(color: .black.opacity(0.3), radius: 15, y: 5)
                    )

                    // Arrow pointing to word (when above)
                    if tooltipPosition == .above {
                        Triangle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(width: 20, height: 10)
                            .rotationEffect(.degrees(180))
                            .offset(x: calculateArrowOffset(in: geometry), y: 0)
                    }
                }
                .frame(width: 280)
                .offset(x: calculateTooltipX(in: geometry), y: calculateTooltipY(in: geometry))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .onAppear {
                    updateTooltipPosition(geometry: geometry)
                }
                .onChange(of: wordPosition) { _, _ in
                    updateTooltipPosition(geometry: geometry)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    private func calculateTooltipX(in geometry: GeometryProxy) -> CGFloat {
        let tooltipWidth: CGFloat = 280
        let screenWidth = geometry.size.width

        // Try to center tooltip on word, but keep it on screen
        var x = wordPosition.midX - screenWidth / 2

        // Keep tooltip within screen bounds (with 16pt padding)
        let minX = -screenWidth / 2 + tooltipWidth / 2 + 16
        let maxX = screenWidth / 2 - tooltipWidth / 2 - 16

        x = min(max(x, minX), maxX)

        return x
    }

    private func calculateTooltipY(in geometry: GeometryProxy) -> CGFloat {
        let tooltipHeight: CGFloat = 170 // Approximate
        let arrowHeight: CGFloat = 10
        let spacing: CGFloat = 2

        // We're using .offset() which offsets from the view's natural center position
        // The VStack will be centered by default, so we need to calculate offset from center
        let screenCenterY = geometry.size.height / 2

        if tooltipPosition == .below {
            // Position tooltip below word
            // Calculate where tooltip center should be: word bottom + arrow + spacing + half tooltip
            let desiredTooltipCenterY = wordPosition.maxY - arrowHeight - spacing
            // Convert to offset from screen center
            return desiredTooltipCenterY - screenCenterY
        } else {
            // Position tooltip above word
            // Calculate where tooltip center should be: word top - arrow - spacing - half tooltip
            let desiredTooltipCenterY = wordPosition.minY - arrowHeight - spacing - tooltipHeight
            // Convert to offset from screen center
            return desiredTooltipCenterY - screenCenterY
        }
    }

    private func calculateArrowOffset(in geometry: GeometryProxy) -> CGFloat {
        let tooltipCenterX = calculateTooltipX(in: geometry) + geometry.size.width / 2
        return wordPosition.midX - tooltipCenterX
    }

    private func updateTooltipPosition(geometry: GeometryProxy) {
        // Determine if tooltip should be above or below word based on screen position
        let screenMid = geometry.size.height / 2
        let wordMid = wordPosition.midY
        tooltipPosition = wordMid < screenMid ? .below : .above
    }
}

// Triangle shape for tooltip arrow
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
