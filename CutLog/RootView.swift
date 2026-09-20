import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "target") }
            TrainingPlanView()
                .tabItem { Label("Plan", systemImage: "figure.strengthtraining.traditional") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.orange)
        .task { await store.importLatestHealthWeight() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshWidget()
                Task { await store.importLatestHealthWeight() }
            }
        }
    }
}
