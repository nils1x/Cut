import SwiftUI

enum CutLogStyle {
    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 10
        static let cell: CGFloat = 3
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Number {
        /// Default, not .rounded: the rounded look is the "easy Swift" style this app drops.
        static let design: Font.Design = .default
        /// Exactly one hero per screen. Calories only.
        static let hero = Font.system(size: 52, weight: .semibold, design: design)
        static let metric = Font.system(size: 26, weight: .semibold, design: design)
        static let value = Font.system(size: 17, weight: .medium, design: design)
        static let label = Font.caption.weight(.medium)
    }

    static let gridGap: CGFloat = 3
    static let gridCell: CGFloat = 15
}

/// Hairline track with a flat filled portion. Square ends, 2pt by default.
struct MetricBar: View {
    let value: Double
    var tint: Color = CutLogPalette.apricot
    var height: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(CutLogPalette.hairline)
                Rectangle()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Flat card surface. No shadow, no material.
struct Card<Content: View>: View {
    var padding: CGFloat = CutLogStyle.Space.l
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CutLogPalette.surface, in: RoundedRectangle(cornerRadius: CutLogStyle.Radius.card, style: .continuous))
    }
}

/// Section label with an optional trailing accessory, aligned to the same left edge as values.
struct SectionLabel<Accessory: View>: View {
    let title: String
    let accessory: Accessory

    init(_ title: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(CutLogStyle.Number.label)
                .foregroundStyle(.secondary)
            Spacer(minLength: CutLogStyle.Space.s)
            accessory
        }
    }
}

extension SectionLabel where Accessory == EmptyView {
    init(_ title: String) { self.init(title) { EmptyView() } }
}

/// Label left, value right, hairline bottom. Replaces hand-rolled rows.
struct KeyValueRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var showsHairline = true

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: CutLogStyle.Space.m)
            Text(value)
                .font(CutLogStyle.Number.value)
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if showsHairline {
                Rectangle().fill(CutLogPalette.hairline).frame(height: 0.5)
            }
        }
    }
}

/// Value plus label, no surface. For use inside a card.
struct StatTile: View {
    let value: String
    let label: String
    var color: Color = .primary
    var bar: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: CutLogStyle.Space.xs) {
            Text(value)
                .font(CutLogStyle.Number.value)
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(CutLogStyle.Number.label)
                .foregroundStyle(.secondary)
            if let bar {
                MetricBar(value: bar, height: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Hairline range/segment pill. Replaces the system segmented Picker in History.
struct RangePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CutLogStyle.Number.label)
                .foregroundStyle(isSelected ? CutLogPalette.apricot : Color.secondary)
                .padding(.horizontal, CutLogStyle.Space.m)
                .padding(.vertical, 6)
                .background(isSelected ? CutLogPalette.apricot.opacity(0.12) : Color.clear,
                            in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isSelected ? CutLogPalette.apricot.opacity(0.35) : CutLogPalette.hairline,
                                           lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }
}