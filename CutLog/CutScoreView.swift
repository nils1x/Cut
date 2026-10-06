import SwiftUI

/// The Cut score is a weekly retrospective, not a live value, so it lives here
/// rather than between today's numbers on the dashboard.
struct CutScoreView: View {
    @Environment(AppStore.self) private var store

    private var snapshot: CutScoreSnapshot? {
        CutScore.calculate(foods: store.foods, workouts: store.workouts,
                           calorieGoal: store.settings.calorieGoal,
                           proteinGoal: store.settings.proteinGoal)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CutLogStyle.Space.xl) {
                if let snapshot {
                    VStack(alignment: .leading, spacing: CutLogStyle.Space.s) {
                        Text(snapshot.score, format: .number)
                            .font(CutLogStyle.Number.hero)
                            .monospacedDigit()
                            .foregroundStyle(CutLogPalette.apricot)
                        Text("out of 100 · previous 7 days")
                            .font(CutLogStyle.Number.label)
                            .foregroundStyle(.secondary)
                        MetricBar(value: Double(snapshot.score) / 100, height: 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, CutLogStyle.Space.s)

                    Card {
                        VStack(spacing: 0) {
                            KeyValueRow(label: "Calories", value: "\(snapshot.calorieAdherence)%",
                                        valueColor: componentColor(snapshot.calorieAdherence), showsHairline: false)
                            KeyValueRow(label: "Protein", value: "\(snapshot.proteinProgress)%",
                                        valueColor: componentColor(snapshot.proteinProgress), showsHairline: false)
                            KeyValueRow(label: "Training", value: "\(snapshot.trainingConsistency)%",
                                        valueColor: componentColor(snapshot.trainingConsistency))
                        }
                    }

                    Text("Built from \(snapshot.loggedFoodDays) logged food days and \(snapshot.scheduledTrainingDays) scheduled sessions. This is a product consistency score from your own logged data. It is not a medical, fitness or total health assessment.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Not enough data", systemImage: "chart.bar",
                                           description: Text("Log food on 3 different days to unlock your 7-day score."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CutLogStyle.Space.xl)
                }
            }
            .padding(.horizontal, CutLogStyle.Space.l)
            .padding(.vertical, CutLogStyle.Space.l)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cut score")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func componentColor(_ value: Int) -> Color {
        value >= 70 ? CutLogPalette.periwinkle : .secondary
    }
}