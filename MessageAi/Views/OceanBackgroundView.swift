import SwiftUI

struct OceanBackgroundView: View {
    @State private var bubbleOffsets: [CGFloat] = Array(repeating: 0, count: 15)
    @State private var bubbleDelays: [Double] = (0..<15).map { _ in Double.random(in: 0...3) }
    @State private var lightRayOffsets: [CGFloat] = Array(repeating: 0, count: 5)

    var body: some View {
        ZStack {
            // Deep ocean gradient
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.2, blue: 0.35),
                    Color(red: 0.0, green: 0.3, blue: 0.45),
                    Color(red: 0.0, green: 0.4, blue: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Light rays from top
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<5, id: \.self) { index in
                        LightRay(width: geometry.size.width, offset: lightRayOffsets[index])
                            .offset(x: CGFloat(index - 2) * geometry.size.width / 4)
                            .opacity(0.15)
                    }
                }
                .onAppear {
                    for i in 0..<5 {
                        withAnimation(.easeInOut(duration: Double.random(in: 3...5)).repeatForever(autoreverses: true).delay(Double(i) * 0.3)) {
                            lightRayOffsets[i] = 20
                        }
                    }
                }
            }

            // Animated bubbles
            GeometryReader { geometry in
                ForEach(0..<15, id: \.self) { index in
                    Bubble(size: CGFloat.random(in: 4...12))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: geometry.size.height + bubbleOffsets[index]
                        )
                        .onAppear {
                            withAnimation(.linear(duration: Double.random(in: 8...15)).repeatForever(autoreverses: false).delay(bubbleDelays[index])) {
                                bubbleOffsets[index] = -geometry.size.height - 100
                            }
                        }
                }
            }
        }
    }
}

struct LightRay: View {
    let width: CGFloat
    let offset: CGFloat

    var body: some View {
        Path { path in
            let topWidth: CGFloat = 50
            let bottomWidth: CGFloat = 150

            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: topWidth, y: 0))
            path.addLine(to: CGPoint(x: bottomWidth, y: 1000))
            path.addLine(to: CGPoint(x: -bottomWidth + topWidth, y: 1000))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.1),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .offset(x: offset)
        .blur(radius: 8)
    }
}

struct Bubble: View {
    let size: CGFloat
    @State private var opacity: Double = 0.6

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.5),
                        Color.cyan.opacity(0.3),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 1...2)).repeatForever(autoreverses: true)) {
                    opacity = Double.random(in: 0.3...0.8)
                }
            }
    }
}

#Preview {
    OceanBackgroundView()
}
