import Foundation
import FoundationModels
import UIKit

@available(iOS 27.0, *)
@Generable(description: "A rough nutrition estimate for one complete meal portion. Values must be plausible whole numbers.")
struct MealEstimate: Sendable {
    @Guide(description: "Short, recognizable meal name in the language used by the user.")
    var name: String
    @Guide(description: "Estimated calories for the complete described or visible portion, not per 100 grams, between 0 and 3000.")
    var calories: Int
    @Guide(description: "Estimated protein grams, between 0 and 250.")
    var protein: Int
    @Guide(description: "Estimated carbohydrate grams, between 0 and 300.")
    var carbs: Int
    @Guide(description: "Estimated fat grams, between 0 and 200.")
    var fat: Int
}

enum MealEstimateService {
    enum EstimateError: LocalizedError {
        case unavailable
        case noImage

        var errorDescription: String? {
            switch self {
            case .unavailable: "Apple Intelligence is not ready on this iPhone. Add it manually."
            case .noImage: "This image could not be read."
            }
        }
    }

    static func estimate(from image: UIImage) async throws -> MealEstimate {
        guard SystemLanguageModel.default.isAvailable else { throw EstimateError.unavailable }
        guard let cgImage = image.cgImage else { throw EstimateError.noImage }

        let attachment = Attachment(cgImage).label("meal photo")
        let session = LanguageModelSession(
            instructions: "You estimate nutrition for a calorie tracker. Identify the visible meal and estimate the edible portion only. Be conservative. Return approximate whole-number calories and macros. Never claim accuracy; the user will review every value."
        )
        let response = try await session.respond(generating: MealEstimate.self) {
            "Estimate the meal in this photo."
            attachment
        }
        return response.content
    }

    static func estimate(description: String) async throws -> MealEstimate {
        guard SystemLanguageModel.default.isAvailable else { throw EstimateError.unavailable }
        let session = LanguageModelSession(
            instructions: "You estimate nutrition for a calorie tracker. Interpret the user's food description and estimate the entire eaten portion, including stated counts and serving size. Return total calories and macros for that whole portion, never values per 100 g. If the amount is vague, choose a reasonable typical serving and say the estimate is approximate. Never claim accuracy; the user will review every value."
        )
        let response = try await session.respond(generating: MealEstimate.self) {
            "Estimate the total nutrition for this entire portion: \\(description)"
        }
        return response.content
    }
}
