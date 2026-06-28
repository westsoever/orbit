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
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
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

/// Simple horizontal-wrapping layout for source chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
