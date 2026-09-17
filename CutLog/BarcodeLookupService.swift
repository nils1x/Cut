import Foundation

struct BarcodeProduct {
    let barcode: String
    let name: String
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
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
        let nutriments: Nutriments?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands, nutriments
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
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name,brands,nutriments")!
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
            fatPer100g: nutriments.fat ?? 0
        )
    }
}
