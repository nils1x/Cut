import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var showingFoodSheet = false
    @State private var showingWorkout = false
    @State private var showingWeight = false
    @State private var foodStartMode: AddFoodView.StartMode = .manual

    private var totals: DailyTotals { store.todayTotals }
    private var caloriesLeft: Int { store.settings.calorieGoal - totals.calories }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(max(0, caloriesLeft))")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(caloriesLeft >= 0 ? "kcal left" : "kcal over — log it anyway")
                            .font(.headline)
                            .foregroundStyle(caloriesLeft >= 0 ? Color.secondary : Color.orange)
                        ProgressView(value: Double(totals.calories), total: Double(store.settings.calorieGoal))
                            .tint(.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                    HStack(spacing: 12) {
                        MetricCard(
                            title: "Protein",
                            value: "\(totals.protein) / \(store.settings.proteinGoal)g",
                            progress: Double(totals.protein) / Double(store.settings.proteinGoal),
                            tint: .mint
                        )
                        Button { showingWeight = true } label: {
                            WeightMetricCard(latestWeight: store.latestWeight?.kilograms, trend: store.sevenDayWeightTrend)
                        }
                        .buttonStyle(.plain)
                    }

                    Button { showingWorkout = true } label: {
                        WorkoutStatusCard(template: store.nextWorkout, isDue: store.workoutIsDue)
                    }
                    .buttonStyle(.plain)

                    FoodActionsCard { mode in
                        foodStartMode = mode
                        showingFoodSheet = true
                    }

                    if !store.recentFoods.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.recentFoods.prefix(4)) { food in
                                    Button {
                                        store.addFood(FoodEntry(
                                            name: food.name,
                                            calories: food.calories,
                                            protein: food.protein,
                                            carbs: food.carbs,
                                            fat: food.fat,
                                            servingGrams: food.servingGrams,
                                            barcode: food.barcode
                                        ))
                                    } label: {
                                        Text(food.name)
                                            .lineLimit(1)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(.secondary.opacity(0.10), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if store.todayFoods.isEmpty {
                        ContentUnavailableView(
                            "Nothing logged",
                            systemImage: "fork.knife",
                            description: Text("Add food. Rough beats imaginary.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(store.todayFoods) { food in
                            FoodRow(food: food)
                                .contextMenu {
                                    Button(role: .destructive) { store.deleteFood(food) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Cut.")
            .task(id: store.workouts.count) {
                await WorkoutReminder.refresh(isDue: store.workoutIsDue, enabled: store.settings.reminderEnabled)
            }
            .sheet(isPresented: $showingFoodSheet) { AddFoodView(startMode: foodStartMode) }
            .sheet(isPresented: $showingWorkout) { WorkoutView(template: store.nextWorkout) }
            .sheet(isPresented: $showingWeight) { AddWeightView() }
        }
    }

}

private struct FoodActionsCard: View {
    let select: (AddFoodView.StartMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Log food", systemImage: "fork.knife")
                .font(.headline)
                .foregroundStyle(.orange)

            HStack(spacing: 10) {
                FoodActionButton(title: "Barcode", symbol: "barcode.viewfinder") {
                    select(.barcode)
                }
                FoodActionButton(title: "Photo", symbol: "camera") {
                    select(.photo)
                }
                FoodActionButton(title: "Manual", symbol: "square.and.pencil") {
                    select(.manual)
                }
            }
        }
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct FoodActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.primary)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log food with \(title)")
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let progress: Double?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(tint)
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let progress { ProgressView(value: min(progress, 1)).tint(tint) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WeightMetricCard: View {
    let latestWeight: Double?
    let trend: [WeightTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "scalemass.fill")
                .foregroundStyle(.indigo)
            Text(trend.last.map { String(format: "%.1f kg", $0.kilograms) } ?? latestWeight.map { String(format: "%.1f kg", $0) } ?? "Log it")
                .font(.headline)
            Text(trend.isEmpty ? "Weight" : "7-day average")
                .font(.caption)
                .foregroundStyle(.secondary)
            WeightSparkline(points: trend)
                .frame(height: 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WeightSparkline: View {
    let points: [WeightTrendPoint]

    var body: some View {
        GeometryReader { proxy in
            if points.count > 1 {
                let values = points.map(\.kilograms)
                let low = values.min() ?? 0
                let high = values.max() ?? low
                let range = max(high - low, 0.1)
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(values.count - 1)
                        let y = proxy.size.height * (1 - CGFloat((value - low) / range))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(.indigo, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else {
                Capsule().fill(.secondary.opacity(0.15))
            }
        }
    }
}

private struct WorkoutStatusCard: View {
    let template: WorkoutTemplate
    let isDue: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isDue ? "figure.strengthtraining.traditional" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isDue ? .orange : .green)
                .frame(width: 42, height: 42)
                .background((isDue ? Color.orange : .green).opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(isDue ? "Training due" : "Training done")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isDue ? .orange : .green)
                Text(isDue ? template.title : "Good. Recover.")
                    .font(.headline)
                Text(isDue ? template.subtitle : "Next: \(template.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(18)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct FoodRow: View {
    let food: FoodEntry

    var body: some View {
        HStack {
            Image(systemName: "fork.knife")
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(.orange.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name).fontWeight(.medium)
                Text("P \(food.protein)g · C \(food.carbs)g · F \(food.fat)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(food.calories)").fontWeight(.semibold)
            Text("kcal").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
