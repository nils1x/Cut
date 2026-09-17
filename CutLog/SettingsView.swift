import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var healthError: String?

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Daily targets") {
                    Stepper("Calories: \(store.settings.calorieGoal)", value: $store.settings.calorieGoal, in: 1_200...5_000, step: 50)
                    Stepper("Protein: \(store.settings.proteinGoal) g", value: $store.settings.proteinGoal, in: 50...300, step: 5)
                }
                Section("Nudge") {
                    Toggle("Remind me at 6 PM when training is due", isOn: $store.settings.reminderEnabled)
                        .onChange(of: store.settings.reminderEnabled) { _, enabled in
                            Task { await WorkoutReminder.refresh(isDue: store.workoutIsDue, enabled: enabled) }
                        }
                }
                Section("Apple Health") {
                    Button(action: connectHealth) {
                        HStack {
                            Label(
                                store.settings.healthSyncEnabled ? "Health connected" : "Connect Apple Health",
                                systemImage: store.settings.healthSyncEnabled ? "checkmark.circle.fill" : "heart.fill"
                            )
                            .foregroundStyle(store.settings.healthSyncEnabled ? .green : .primary)
                            Spacer()
                            if !store.settings.healthSyncEnabled {
                                Text("Allow")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(store.settings.healthSyncEnabled)

                    if store.settings.healthSyncEnabled {
                        Button("Stop syncing", role: .destructive) {
                            store.settings.healthSyncEnabled = false
                        }
                    }

                    Text("Tap Connect Apple Health to choose permissions. New food, weight and strength workouts sync after you allow them; existing local history stays local.")
                        .foregroundStyle(.secondary)
                }
                Section("AI meal estimate") {
                    Text("Uses Apple Intelligence on-device when available. It makes a quick estimate from a photo; always edit it if it looks wrong.")
                        .foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("No account, ads or server. Food, weight, goals and workouts stay in local app storage. Barcode lookup sends only the scanned product code to Open Food Facts.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Health not connected", isPresented: Binding(get: { healthError != nil }, set: { if !$0 { healthError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(healthError ?? "")
            }
        }
    }

    private func connectHealth() {
        Task {
            let granted = await HealthKitStore.shared.requestAuthorization()
            if granted {
                store.settings.healthSyncEnabled = true
                await store.importLatestHealthWeight()
            } else {
                healthError = "Health access was not enabled. CutLog still works normally."
            }
        }
    }
}
