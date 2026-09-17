import SwiftUI
import WidgetKit

struct CutLogWidget: Widget {
    let kind = "CutLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CutLogWidgetView(data: entry.data)
                .containerBackground(.orange.opacity(0.12), for: .widget)
        }
        .configurationDisplayName("Cut.")
        .description("Calories, protein and today’s workout.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, data: .preview) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now, data: readData())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: .now, data: readData())
        completion(Timeline(entries: [entry], policy: .after(Calendar.current.date(byAdding: .hour, value: 1, to: .now)!)))
    }

    private func readData() -> CutLogWidgetData {
        guard let data = UserDefaults(suiteName: CutLogWidgetStore.suiteName)?.data(forKey: CutLogWidgetStore.key),
              let decoded = try? JSONDecoder().decode(CutLogWidgetData.self, from: data) else { return .preview }
        return decoded
    }
}

private struct Entry: TimelineEntry {
    let date: Date
    let data: CutLogWidgetData
}

private struct CutLogWidgetView: View {
    let data: CutLogWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CUT.").font(.caption2.weight(.black)).foregroundStyle(.orange)
            Text("\(max(0, data.caloriesLeft))")
                .font(.system(size: 42, weight: .bold, design: .rounded))
            Text(data.caloriesLeft >= 0 ? "kcal left" : "kcal over")
                .font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(data.protein), total: Double(data.proteinGoal)).tint(.mint)
            Text("P \(data.protein) / \(data.proteinGoal)g")
                .font(.caption.weight(.semibold))
            Spacer(minLength: 0)
            Label(data.workoutDue ? data.workoutTitle : "Training done", systemImage: data.workoutDue ? "figure.strengthtraining.traditional" : "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(data.workoutDue ? .orange : .green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "cutlog://today"))
    }
}

private extension CutLogWidgetData {
    static let preview = CutLogWidgetData(caloriesLeft: 1_420, calorieGoal: 2_200, protein: 96, proteinGoal: 180, workoutTitle: "Upper A", workoutDue: true)
}

@main
struct CutLogWidgetBundle: WidgetBundle {
    var body: some Widget { CutLogWidget() }
}
