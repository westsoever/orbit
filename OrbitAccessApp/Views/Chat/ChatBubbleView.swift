import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedAtom: SearchHit?

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            bubbleContent
            if message.role != .user { Spacer(minLength: 60) }
        }
        .sheet(item: $selectedAtom) { atom in
            ContextAtomDetailSheet(atom: atom)
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            Text(message.content)
                .font(.body)
                .kerning(-0.1)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if message.role == .user {
                        RoundedRectangle(cornerRadius: 12).fill(Color.orbitAccent)
                    } else if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orbitCardLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orbitCardBorderLight, lineWidth: 1)
                            )
                    }
                }
                .foregroundStyle(message.role == .user ? .white : .primary)

            if message.role == .assistant, !message.sourceAtoms.isEmpty {
                sourceChips
            }

            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
        }
    }

    private var sourceChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(message.sourceAtoms) { atom in
                ContextSourceChip(atom: atom) {
                    selectedAtom = atom
                }
            }
        }
    }
}
