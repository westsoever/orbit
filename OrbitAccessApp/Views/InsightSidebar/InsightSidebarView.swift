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
                DailyScheduleTimeline(slots: model.insightStore.schedule)

                SectionHeader(title: "Routines")
                RoutineList(routines: model.insightStore.routines)

                SectionHeader(title: "Context Stream")
                RecentCaptureList(events: model.insightStore.recentCaptures)
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
