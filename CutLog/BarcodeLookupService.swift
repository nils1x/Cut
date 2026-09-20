import Foundation

struct BarcodeProduct {
    let barcode: String
    let name: String
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    /// The net package mass supplied by Open Food Facts, when it is safely usable as grams.
    let packageGrams: Double?
}

enum BarcodeLookupError: LocalizedError {
    case invalidCode
    case notFound
    case missingNutrition
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCode: "That barcode is not a food barcode."
        case .notFound: "No product found. Add it manually."
        case .missingNutrition: "This product has no usable nutrition facts. Add them from the label."
        case .network: "Could not look up this barcode. Check your connection or add it manually."
        }
    }
}

enum BarcodeLookupService {
    private struct Response: Decodable {
        let status: Int
        let product: Product?
    }

    private struct Product: Decodable {
        let productName: String?
        let brands: String?
        let productQuantity: FlexibleDouble?
        let productQuantityUnit: String?
        let quantity: String?
        let nutriments: Nutriments?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands, quantity, nutriments
            case productQuantity = "product_quantity"
            case productQuantityUnit = "product_quantity_unit"
        }
    }

    private struct FlexibleDouble: Decodable {
        let value: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                value = number
            } else if let text = try? container.decode(String.self) {
                value = Double(text.replacingOccurrences(of: ",", with: "."))
            } else {
                value = nil
            }
        }
    }

    private struct Nutriments: Decodable {
        let calories: Double?
        let energy: Double?
        let protein: Double?
        let carbs: Double?
        let fat: Double?

        enum CodingKeys: String, CodingKey {
            case calories = "energy-kcal_100g"
            case energy = "energy_100g"
            case protein = "proteins_100g"
            case carbs = "carbohydrates_100g"
            case fat = "fat_100g"
        }
    }

    static func product(for barcode: String) async throws -> BarcodeProduct {
        guard barcode.allSatisfy(\.isNumber), barcode.count >= 8 else { throw BarcodeLookupError.invalidCode }
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name,brands,product_quantity,product_quantity_unit,quantity,nutriments")!
        var request = URLRequest(url: url)
        request.setValue("CutLog/1.0 (personal iOS calorie tracker)", forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw BarcodeLookupError.network
        }

        guard let response = try? JSONDecoder().decode(Response.self, from: data), response.status == 1, let product = response.product else {
            throw BarcodeLookupError.notFound
        }
        guard let nutriments = product.nutriments,
              let calories = nutriments.calories ?? nutriments.energy.map({ $0 / 4.184 }) else {
            throw BarcodeLookupError.missingNutrition
        }

        guard calories.isFinite, (0...10_000).contains(calories),
              [nutriments.protein, nutriments.carbs, nutriments.fat].compactMap({ $0 })
                .allSatisfy({ $0.isFinite && (0...1_000).contains($0) }) else {
            throw BarcodeLookupError.missingNutrition
        }

        let title = [product.brands, product.productName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " — ")

        return BarcodeProduct(
            barcode: barcode,
            name: title.isEmpty ? "Scanned product" : title,
            caloriesPer100g: calories,
            proteinPer100g: nutriments.protein ?? 0,
            carbsPer100g: nutriments.carbs ?? 0,
            fatPer100g: nutriments.fat ?? 0,
            packageGrams: packageGrams(
                productQuantity: product.productQuantity?.value,
                unit: product.productQuantityUnit,
                quantity: product.quantity
            )
        )
    }

    static func packageGrams(productQuantity: Double?, unit: String?, quantity: String?) -> Double? {
        if let productQuantity, productQuantity.isFinite, productQuantity > 0 {
            let normalizedUnit = unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let grams: Double?
            switch normalizedUnit {
            case nil, "", "g", "gram", "grams": grams = productQuantity
            case "kg", "kilogram", "kilograms": grams = productQuantity * 1_000
            default: grams = nil
            }
            if let grams, (0...100_000).contains(grams) { return grams }
        }

        guard let quantity else { return nil }
        let normalized = quantity
            .lowercased()
            .replacingOccurrences(of: ",", with: ".")

        if let match = normalized.range(of: #"([0-9]+(?:\.[0-9]+)?)\s*[x×]\s*([0-9]+(?:\.[0-9]+)?)\s*(kg|g)\b"#, options: .regularExpression) {
            let values = String(normalized[match])
                .replacingOccurrences(of: "×", with: "x")
                .components(separatedBy: "x")
            guard values.count == 2,
                  let count = Double(values[0].trimmingCharacters(in: .whitespaces)),
                  let sizeAndUnit = values.last?.split(separator: " "),
                  let sizeText = sizeAndUnit.first,
                  let size = Double(sizeText),
                  let unitText = sizeAndUnit.last else { return nil }
            let grams = count * (unitText == "kg" ? size * 1_000 : size)
            return grams.isFinite && (0...100_000).contains(grams) ? grams : nil
        }

        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(kg|g)\b"#
        guard let match = normalized.range(of: pattern, options: .regularExpression) else { return nil }
        let valueAndUnit = String(normalized[match])
        let components = valueAndUnit.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let valueText = components.first,
              let value = Double(valueText),
              let unitText = components.last else { return nil }
        let grams = unitText == "kg" ? value * 1_000 : value
        return grams.isFinite && (0...100_000).contains(grams) ? grams : nil
    }
}
