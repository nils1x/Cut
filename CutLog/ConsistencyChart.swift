import SwiftUI

/// GitHub-style contribution grid of the last 30 calendar days. Seven columns per week,
/// oldest row on top. Level rises with how complete the day was, same direction as GitHub:
/// more things logged means a more saturated cell.
struct ConsistencyChart: View {
	let days: [ConsistencyDay]
	var columns = 7

    private var rows: [[ConsistencyDay]] {
        stride(from: 0, to: days.count, by: columns).map { start in
            Array(days[start..<min(start + columns, days.count)])
        }
    }

    var body: some View {
        VStack(spacing: CutLogStyle.gridGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                HStack(spacing: CutLogStyle.gridGap) {
                    ForEach(week) { cell($0) }
                    if week.count < columns {
                        ForEach(0..<(columns - week.count), id: \.self) { _ in
                            Color.clear.frame(width: CutLogStyle.gridCell, height: CutLogStyle.gridCell)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Logging consistency, last \(days.count) days")
        .accessibilityValue(accessibilityValue)
    }

    /// No visible legend: the ramp is self-evident, and VoiceOver carries the detail.
    private var accessibilityValue: String {
        let logged = days.count { $0.level > .none }
        let detail = days.suffix(7).map { day in
            "\(day.date.formatted(.dateTime.weekday(.abbreviated))) \(description(day.level))"
        }.joined(separator: ", ")
        return "\(logged) of \(days.count) days logged. \(detail)"
    }

    private func description(_ level: ConsistencyDay.Level) -> String {
        switch level {
        case .none: return "nothing logged"
        case .weightOnly: return "weight only"
        case .food: return "food logged"
        case .trained: return "trained"
        case .full: return "food and training"
        }
    }

    private func cell(_ day: ConsistencyDay) -> some View {
        RoundedRectangle(cornerRadius: CutLogStyle.Radius.cell, style: .continuous)
            .fill(CutLogPalette.consistency(day.level.rawValue))
            .frame(width: CutLogStyle.gridCell, height: CutLogStyle.gridCell)
            .overlay {
                if Calendar.current.isDateInToday(day.date) {
                    RoundedRectangle(cornerRadius: CutLogStyle.Radius.cell, style: .continuous)
                        .strokeBorder(CutLogPalette.hairline, lineWidth: 1)
                }
            }
    }
}