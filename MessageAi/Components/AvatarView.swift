//
//  AvatarView.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI

struct AvatarView: View {
    let name: String
    let avatarURL: String?
    let size: CGFloat
    let isOnline: Bool

    init(name: String, avatarURL: String? = nil, size: CGFloat = 50, isOnline: Bool = false) {
        self.name = name
        self.avatarURL = avatarURL
        self.size = size
        self.isOnline = isOnline
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar circle
            if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            // Online indicator
            if isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: -2, y: -2)
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(LinearGradient(
                colors: [colorForName(name), colorForName(name).opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    private func colorForName(_ name: String) -> Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .orange, .green, .red, .indigo, .teal, .cyan, .mint
        ]
        let hash = name.hashValue
        return colors[abs(hash) % colors.count]
    }
}

#Preview {
    VStack(spacing: 20) {
        AvatarView(name: "John Doe", size: 60, isOnline: true)
        AvatarView(name: "Jane Smith", size: 50, isOnline: false)
        AvatarView(name: "Bob", size: 40, isOnline: true)
    }
}
