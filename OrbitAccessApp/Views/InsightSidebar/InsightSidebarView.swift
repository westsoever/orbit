import SwiftUI

struct InsightSidebarView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProductivityScoreGauge(score: model.insightStore.productivityScore.value)

                SectionHeader(title: "Recommended Tasks")
                TaskCardList()

                SectionHeader(title: "Today's Schedule")
                CalendarScheduleView(
                    events: model.insightStore.calendarEvents,
                    isConnected: model.insightStore.isCalendarConnected
                )

                SectionHeader(title: "Routines")
                RoutineList(routines: model.insightStore.routines)

                SectionHeader(title: "Recent Notes")
                RecentNotesList(notes: model.insightStore.recentNotes)
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            model.insightStore.refreshAggregates()
        }
    }
}
