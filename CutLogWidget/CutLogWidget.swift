import Charts
import SwiftUI
import WidgetKit

struct CutLogWidget: Widget {
    let kind = "CutLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CutLogWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Cut.")
        .description("Calories left and a small seven-day calorie history.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, data: .preview) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, data: context.isPreview ? .preview : readData()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date.now
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        let data = readData()
        // The next day's entry is ready even if the app is not opened overnight.
        let entries = [Entry(date: now, data: data), Entry(date: midnight, data: data)]
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(3600))))
    }

    private func readData() -> CutLogWidgetData? {
        guard let data = UserDefaults(suiteName: CutLogWidgetStore.suiteName)?.data(forKey: CutLogWidgetStore.key) else { return nil }
        return try? JSONDecoder().decode(CutLogWidgetData.self, from: data)
    }
}

private struct Entry: TimelineEntry {
    let date: Date
    let data: CutLogWidgetData?
}

private struct CutLogWidgetView: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Cut.").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let data = entry.data {
                let remaining = data.caloriesLeft(on: entry.date)
                Text(abs(remaining), format: .number)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                Text(remaining >= 0 ? "kcal left" : "kcal over")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 3)
                calorieGraph(data)
                Text("kcal · 7 days").font(.caption2).foregroundStyle(.secondary)
            } else {
                Spacer()
                Text("Open Cut.").font(.headline)
                Text("Log your first meal to start.").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func calorieGraph(_ data: CutLogWidgetData) -> some View {
        let week = data.week(endingAt: entry.date)
        let start = week.first?.date ?? entry.date
        let end = Calendar.current.date(byAdding: .day, value: 1, to: week.last?.date ?? entry.date)!
        let maxCalories = max(data.calorieGoal, week.compactMap(\.calories).max() ?? 0, 1)
        return Chart {
            RuleMark(y: .value("Goal", data.calorieGoal))
                .foregroundStyle(.secondary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            ForEach(week) { day in
                if let calories = day.calories {
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Calories", calories))
                        .foregroundStyle(Calendar.current.isDate(day.date, inSameDayAs: entry.date) ? Color.orange : Color.primary.opacity(0.35))
                        .cornerRadius(2)
                }
            }
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: 0...(Double(maxCalories) * 1.1))
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .frame(height: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories logged over seven days; dashed line is the daily goal")
        .accessibilityValue(week.map { "\($0.date.formatted(.dateTime.weekday(.abbreviated))): \($0.calories.map(String.init) ?? "not logged")" }.joined(separator: ", "))
    }
}

private extension CutLogWidgetData {
    static var preview: CutLogWidgetData {
        let today = Calendar.current.startOfDay(for: .now)
        return CutLogWidgetData(calorieGoal: 2450, days: [2300, 2450, 2100, 2500, 2200, 2400, 1030].enumerated().map { index, calories in
            CalorieDay(date: Calendar.current.date(byAdding: .day, value: index - 6, to: today)!, calories: calories)
        })
    }
}

@main
struct CutLogWidgetBundle: WidgetBundle {
    var body: some Widget { CutLogWidget() }
}
