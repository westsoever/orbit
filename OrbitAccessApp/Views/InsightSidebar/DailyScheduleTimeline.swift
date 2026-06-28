import SwiftUI

struct DailyScheduleTimeline: View {
    let slots: [HourSlot]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if slots.isEmpty {
            Text("No activity recorded today")
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(slots) { slot in
                    timelineRow(slot)
                }
            }
        }
    }

    private func timelineRow(_ slot: HourSlot) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.orbitAccent)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1)
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TimeChip(time: "\(slot.hour):00")
                    Text(slot.appName)
                        .font(.callout.weight(.medium))
                        .kerning(-0.1)
                }
                Text("\(slot.eventCount) events")
                    .font(.caption2)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            }
            .padding(.bottom, 12)
        }
    }
}
