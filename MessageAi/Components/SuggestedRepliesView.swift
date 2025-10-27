//
//  SuggestedRepliesView.swift
//  MessageAi
//
//  Created by Apple on 10/26/25.
//

import SwiftUI

struct SuggestedRepliesView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    let isExpanded: Bool

    var body: some View {
        if isExpanded && !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: { onSelect(suggestion) }) {
                            Text(suggestion)
                                .font(.system(size: 14))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .systemGray6))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack {
        Spacer()
        SuggestedRepliesView(
            suggestions: ["Hola, ¿cómo estás?", "Sí, me gusta", "¿Y tú?"],
            onSelect: { print($0) },
            isExpanded: true
        )
        Rectangle()
            .fill(.blue)
            .frame(height: 50)
    }
}
