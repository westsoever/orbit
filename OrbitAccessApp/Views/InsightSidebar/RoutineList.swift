import SwiftUI

struct RoutineList: View {
    let routines: [RoutineBlock]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if routines.isEmpty {
            Text("No routines configured")
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 8) {
                ForEach(routines) { routine in
                    OrbitCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routine.title)
                                    .font(.callout.weight(.medium))
                                    .kerning(-0.1)
                                Text(routine.timeRange)
                                    .font(.caption2)
                                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
