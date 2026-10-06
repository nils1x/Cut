import SwiftUI

/// Adaptive colors. One accent per region: calories apricot, protein periwinkle,
/// training sage. Pastel fills, monochrome base, no gradients.
enum CutLogPalette {
	private static func dynamic(light: UIColor, dark: UIColor) -> Color {
		Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
	}

	/// Empty / no data. Also the consistency grid's level 0.
	static let track = dynamic(light: .init(white: 0, alpha: 0.07), dark: .init(white: 1, alpha: 0.10))

	/// Primary accent. Replaces the old moss everywhere.
	static let apricot = dynamic(light: .init(red: 0.85, green: 0.42, blue: 0.18, alpha: 1),
	                            dark: .init(red: 1.00, green: 0.72, blue: 0.52, alpha: 1))

	/// Protein and secondary data only.
	static let periwinkle = dynamic(light: .init(red: 0.38, green: 0.44, blue: 0.82, alpha: 1),
	                                dark: .init(red: 0.66, green: 0.71, blue: 0.95, alpha: 1))

	/// Training only. Never competes with apricot.
	static let sage = dynamic(light: .init(red: 0.40, green: 0.55, blue: 0.38, alpha: 1),
	                          dark: .init(red: 0.66, green: 0.78, blue: 0.64, alpha: 1))

	static let hairline = dynamic(light: .init(white: 0, alpha: 0.10), dark: .init(white: 1, alpha: 0.12))

	static let surface = dynamic(light: .init(white: 0, alpha: 0.035), dark: .init(white: 1, alpha: 0.06))

	/// The five consistency levels: level 0 is empty, higher levels are more complete
	/// and therefore more saturated. Same direction as GitHub.
	/// Two hues only, so the ramp reads without a legend.
	static func consistency(_ level: Int) -> Color {
		switch level {
		case 4: apricot
		case 3: apricot.opacity(0.60)
		case 2: apricot.opacity(0.30)
		case 1: sage.opacity(0.35)
		default: track
		}
	}
}