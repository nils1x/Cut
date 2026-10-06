import Foundation

/// Catalog identity and construction. Pure, so both logic and tests can use it
/// without standing up the store.
enum FoodCatalog {
	/// Identity for pinning and for the catalog: normalized name, portion, barcode.
	/// Macros are excluded so the same item with a corrected label stays one item.
	static func key(for food: FoodEntry) -> String {
		let name = FoodSearch.normalize(food.name)
		let grams = food.servingGrams.map { String(Int($0.rounded())) } ?? ""
		return "\(name)|\(grams)|\(food.barcode ?? "")"
	}

	/// Re-log a known food at a fresh date. Never reuse the source entry's date.
	static func entry(at date: Date = .now, from food: FoodEntry) -> FoodEntry {
		FoodEntry(name: food.name, calories: food.calories, protein: food.protein, carbs: food.carbs,
		          fat: food.fat, servingGrams: food.servingGrams, barcode: food.barcode, date: date)
	}

	static func build(from foods: [FoodEntry]) -> [FoodCatalogItem] {
		var byID: [String: FoodCatalogItem] = [:]
		for food in foods {
			let id = key(for: food)
			if var existing = byID[id] {
				existing.absorb(food)
				byID[id] = existing
			} else {
				byID[id] = FoodCatalogItem(food: food, id: id)
			}
		}
		return Array(byID.values)
	}
}

/// Pure fuzzy name matching over the food catalog. No index, no tokenizer, no dependency.
enum FoodSearch {
	static let limit = 25

	static func search(_ items: [FoodCatalogItem], query raw: String) -> [FoodCatalogItem] {
		let query = normalize(raw)
		guard !query.isEmpty else {
			return items.sorted {
				$0.useCount == $1.useCount
					? $0.lastUsedAt > $1.lastUsedAt
					: $0.useCount > $1.useCount
			}.prefix(limit).map { $0 }
		}
		let queryTokens = query.split(separator: " ").map(String.init)
		return items.compactMap { item -> (FoodCatalogItem, Int)? in
			guard let score = score(name: normalize(item.name), query: query, queryTokens: queryTokens) else { return nil }
			return (item, score)
		}
		.sorted { lhs, rhs in
			lhs.1 == rhs.1 ? lhs.0.lastUsedAt > rhs.0.lastUsedAt : lhs.1 > rhs.1
		}
		.prefix(limit)
		.map(\.0)
	}

	/// Lowercased, diacritics folded, punctuation collapsed to single spaces.
	static func normalize(_ text: String) -> String {
		let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
		let mapped = folded.map { character -> Character in
			character.isLetter || character.isNumber ? character : " "
		}
		return String(mapped).split(separator: " ").joined(separator: " ")
	}

	/// Higher is better. nil means no match at all.
	static func score(name: String, query: String, queryTokens: [String]) -> Int? {
		let nameTokens = name.split(separator: " ").map(String.init)
		guard !nameTokens.isEmpty else { return nil }

		if name == query { return 1000 }
		// A name that *is* the query plus a qualifier ("banana" vs "banana bread") beats a
		// name where the query is buried mid-string.
		if name.hasPrefix(query) { return 900 - min(300, name.count - query.count) }
		if nameTokens.first?.hasPrefix(query) == true { return 880 }
		if let index = nameTokens.firstIndex(where: { $0.hasPrefix(query) }) { return 700 - index * 10 }
		if name.contains(query) { return 400 }

		if !queryTokens.isEmpty, queryTokens.allSatisfy({ queryToken in nameTokens.contains(where: { $0.hasPrefix(queryToken) }) }) {
			return 300
		}
		for queryToken in queryTokens {
			if nameTokens.contains(where: { $0.hasPrefix(queryToken) }) { return 120 }
		}
		// Typo tolerance last and only for words long enough that a distance of 2 is unlikely
		// to be a different food entirely.
		for queryToken in queryTokens where queryToken.count >= 4 {
			for nameToken in nameTokens where nameToken.count >= 4 {
				if let distance = editDistance(queryToken, nameToken, limit: 2) { return 80 - distance * 20 }
			}
		}
		return nil
	}

	/// Levenshtein distance, two-row DP. nil when it exceeds `limit`.
	static func editDistance(_ lhs: String, _ rhs: String, limit: Int) -> Int? {
		if lhs == rhs { return 0 }
		let a = Array(lhs), b = Array(rhs)
		if abs(a.count - b.count) > limit { return nil }
		if a.isEmpty { return b.count <= limit ? b.count : nil }
		if b.isEmpty { return a.count <= limit ? a.count : nil }

		var previous = Array(0...b.count)
		var current = [Int](repeating: 0, count: b.count + 1)
		for i in 1...a.count {
			current[0] = i
			var rowBest = i
			for j in 1...b.count {
				current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
				rowBest = min(rowBest, current[j])
			}
			if rowBest > limit { return nil }
			swap(&previous, &current)
		}
		let distance = previous[b.count]
		return distance <= limit ? distance : nil
	}
}