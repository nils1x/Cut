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
        .description("Today's calories and macros, plus your last seven days.")
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

/// Same silhouette as the dashboard energy block: number, goal, bar, macros.
/// No consistency grid, no captions, no header row.
private struct CutLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    private static let barHeight: CGFloat = 26

    var body: some View {
        Group {
            if let data = entry.data {
                if family == .systemMedium { medium(data) } else { small(data) }
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Data

    private var calories: Int? { entry.data?.calories(on: entry.date) }
    private var goal: Int { entry.data?.calorieGoal ?? 0 }
    private var isOverGoal: Bool { (calories ?? 0) > goal }
    private var progress: Double { goal > 0 ? Double(calories ?? 0) / Double(goal) : 0 }

    private func number(_ size: CGFloat) -> some View {
        Text(calories.map { $0.formatted() } ?? "—")
            .font(.system(size: size, weight: .semibold, design: .default))
            .monospacedDigit()
            .foregroundStyle(isOverGoal ? Color.red : Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var goalCaption: some View {
        Text(isOverGoal ? "over \(goal) kcal" : "kcal")
            .font(CutLogStyle.Number.label)
            .foregroundStyle(.secondary)
    }

    private var progressBar: some View {
        MetricBar(value: progress, tint: isOverGoal ? Color.red : CutLogPalette.apricot, height: 3)
    }

    private func macro(_ label: String, _ value: Int?, bar: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(value.map { $0.formatted() } ?? "—")
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
            }
            if let bar {
                MetricBar(value: bar, height: 2)
            } else {
                Rectangle().fill(CutLogPalette.hairline).frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Small

    private func small(_ data: CutLogWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                number(32)
                goalCaption
            }
            Spacer(minLength: 4)
            progressBar
            macroRow(data, compact: true)
            Spacer(minLength: 6)
            weekBars(data)
        }
    }

    // MARK: - Medium

    private func medium(_ data: CutLogWidgetData) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    number(32)
                    goalCaption
                }
                Spacer(minLength: 4)
                progressBar
                macroRow(data, compact: false)
                Spacer(minLength: 0)
            }
            Rectangle()
                .fill(CutLogPalette.hairline)
                .frame(width: 0.5)
            weekBars(data)
                .frame(maxHeight: .infinity)
        }
    }

    private func macroRow(_ data: CutLogWidgetData, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            macro("P", data.protein?.current,
                  bar: data.protein.map { Double($0.current) / Double(max(1, $0.goal)) })
            macro("C", data.carbsToday, bar: nil)
            macro("F", data.fatToday, bar: nil)
        }
    }

    /// Seven columns, height relative to the daily goal. An unlogged day stays a 1pt tick,
    /// never a zero bar, so missing never looks like zero.
    private func weekBars(_ data: CutLogWidgetData) -> some View {
        let week = data.week(endingAt: entry.date)
        let scale = max(data.calorieGoal, week.compactMap(\.calories).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(week) { day in
                let isToday = Calendar.current.isDate(day.date, inSameDayAs: entry.date)
                Group {
                    if let logged = day.calories {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isToday ? CutLogPalette.apricot : CutLogPalette.track)
                            .frame(height: barHeight(for: logged, scale: scale))
                    } else {
                        Rectangle().fill(CutLogPalette.track).frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(height: Self.barHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories over the last seven days")
        .accessibilityValue(week.map {
            "\($0.date.formatted(.dateTime.weekday(.abbreviated))): \($0.calories.map { "\($0) calories" } ?? "not logged")"
        }.joined(separator: ", "))
    }

    private func barHeight(for calories: Int, scale: Int) -> CGFloat {
        // Floor of 2pt so a very low day is still visibly logged.
        max(2, Self.barHeight * CGFloat(calories) / CGFloat(scale))
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("—")
                    .font(.system(size: 32, weight: .semibold, design: .default))
                    .foregroundStyle(.tertiary)
                Text("kcal")
                    .font(CutLogStyle.Number.label)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            progressBar
            macroRow(.init(calorieGoal: 0, days: []), compact: true)
            Spacer(minLength: 6)
            Text("Open Cut.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private extension CutLogWidgetData {
    static var preview: CutLogWidgetData {
        let today = Calendar.current.startOfDay(for: .now)
        return CutLogWidgetData(calorieGoal: 2450,
            days: [2300, 2450, 2100, 2500, 2200, 2400, 1030].enumerated().map { index, calories in
                CalorieDay(date: Calendar.current.date(byAdding: .day, value: index - 6, to: today)!, calories: calories)
            },
            proteinGoal: 190, proteinToday: 154, carbsToday: 198, fatToday: 61)
    }
}

@main
struct CutLogWidgetBundle: WidgetBundle {
    var body: some Widget { CutLogWidget() }
}