import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var healthError: String?
    @State private var isConnecting = false
    @State private var healthStatus: String?
    @State private var exerciseDBAPIKey = ""

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
                                isConnecting ? "Requesting access…" : (store.settings.healthSyncEnabled ? "Review Health access" : "Connect Apple Health"),
                                systemImage: "heart.fill"
                            )
                            .foregroundStyle(.primary)
                            Spacer()
                            if isConnecting {
                                ProgressView()
                            } else if !store.settings.healthSyncEnabled {
                                Text("Allow")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isConnecting)

                    if store.settings.healthSyncEnabled {
                        Button("Stop syncing", role: .destructive) {
                            store.settings.healthSyncEnabled = false
                        }
                    }

                    if let healthStatus, store.settings.healthSyncEnabled {
                        Text(healthStatus).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let syncError = store.healthSyncError {
                        Label(syncError, systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    Text("Sync is optional and only uses the types you allow. To change a previous choice: Health → profile → Apps → Cut. iOS may not ask again. Existing food and workout history is not uploaded; local deletions do not delete Health records.")
                        .foregroundStyle(.secondary)
                }
                Section("Exercise tutorials") {
                    SecureField("RapidAPI key", text: $exerciseDBAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: exerciseDBAPIKey) { _, key in KeychainStore.setExerciseDBKey(key) }
                    Text("Used only when you open an exercise tutorial. The key stays in your iPhone Keychain and is sent to ExerciseDB through RapidAPI, never bundled in the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("AI meal estimate") {
                    Text("Uses Apple Intelligence on-device when available. It makes a quick estimate from a photo; always edit it if it looks wrong.")
                        .foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("No account, ads or backend. Food, weight, goals and workouts stay in local app storage. Barcode lookup sends only the scanned product code to Open Food Facts. Exercise tutorials use your optional RapidAPI key only when opened.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .task {
                exerciseDBAPIKey = KeychainStore.exerciseDBKey()
                await refreshHealthStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshHealthStatus() } }
            }
            .alert("Health not connected", isPresented: Binding(get: { healthError != nil }, set: { if !$0 { healthError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(healthError ?? "")
            }
        }
    }

    private func connectHealth() {
        guard !isConnecting else { return }
        isConnecting = true
        Task {
            defer { isConnecting = false }
            do {
                let access = try await HealthKitStore.shared.requestAuthorization()
                healthStatus = access.summary
                store.settings.healthSyncEnabled = true
                store.healthSyncError = nil
                await store.importLatestHealthWeight()
            } catch {
                healthError = HealthKitStore.message(for: error)
            }
        }
    }

    private func refreshHealthStatus() async {
        guard store.settings.healthSyncEnabled else { return }
        healthStatus = await HealthKitStore.shared.currentAccess().summary
    }
}
