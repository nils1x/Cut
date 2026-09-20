import Foundation
import HealthKit

actor HealthKitStore {
    static let shared = HealthKitStore()
    private let store = HKHealthStore()

    private var canUseHealthKit: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryProtein),
         HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryFatTotal),
         HKQuantityType(.bodyMass), HKObjectType.workoutType()]
    }

    struct Access: Sendable {
        let writableTypes: Int
        let requestedTypes: Int
        var summary: String {
            "Write access: \(writableTypes)/\(requestedTypes) types. Weight read access is private; no results can also mean no recorded weight."
        }
    }

    enum ConnectionError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Apple Health is unavailable on this device. Local tracking still works." }
    }

    func requestAuthorization() async throws -> Access {
        guard canUseHealthKit else { throw ConnectionError.unavailable }
        try await store.requestAuthorization(toShare: shareTypes, read: [HKQuantityType(.bodyMass)])
        // A successful request is not proof that read or write permission was granted.
        return currentAccess()
    }

    func currentAccess() -> Access {
        Access(writableTypes: shareTypes.filter { store.authorizationStatus(for: $0) == .sharingAuthorized }.count, requestedTypes: shareTypes.count)
    }

    nonisolated static func message(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.localizedDescription.localizedCaseInsensitiveContains("entitlement") {
            return "This installed build is missing its HealthKit entitlement. In Xcode, enable HealthKit under Signing & Capabilities for CutLog, select a valid team, and install again with Run. Local data is safe."
        }
        if nsError.domain == HKErrorDomain && nsError.code == HKError.Code.errorAuthorizationDenied.rawValue {
            return "Health permission was denied. Open Health → profile → Apps → Cut. to review access. Local data is safe."
        }
        return "\(error.localizedDescription) (\(nsError.domain), \(nsError.code)). Local tracking is unaffected."
    }

    func save(food: FoodEntry) async throws {
        guard canUseHealthKit else { throw ConnectionError.unavailable }
        let samples: [HKQuantitySample] = [
            HKQuantitySample(type: HKQuantityType(.dietaryEnergyConsumed), quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(food.calories)), start: food.date, end: food.date),
            HKQuantitySample(type: HKQuantityType(.dietaryProtein), quantity: HKQuantity(unit: .gram(), doubleValue: Double(food.protein)), start: food.date, end: food.date),
            HKQuantitySample(type: HKQuantityType(.dietaryCarbohydrates), quantity: HKQuantity(unit: .gram(), doubleValue: Double(food.carbs)), start: food.date, end: food.date),
            HKQuantitySample(type: HKQuantityType(.dietaryFatTotal), quantity: HKQuantity(unit: .gram(), doubleValue: Double(food.fat)), start: food.date, end: food.date)
        ]
        let allowed = samples.filter { store.authorizationStatus(for: $0.sampleType) == .sharingAuthorized }
        guard !allowed.isEmpty else { return }
        try await store.save(allowed)
    }

    func save(weight: WeightEntry) async throws {
        guard canUseHealthKit else { throw ConnectionError.unavailable }
        let type = HKQuantityType(.bodyMass)
        guard store.authorizationStatus(for: type) == .sharingAuthorized else { return }
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight.kilograms), start: weight.date, end: weight.date)
        try await store.save(sample)
    }

    func save(workout: WorkoutEntry) async throws {
        guard canUseHealthKit else { throw ConnectionError.unavailable }
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized,
              workout.completedSetCount > 0,
              let start = workout.startedAt, start < workout.completedAt else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
        try await builder.beginCollection(at: start)
        try await builder.endCollection(at: workout.completedAt)
        // Elapsed session time only; no guessed energy expenditure.
        _ = try await builder.finishWorkout()
    }

    func latestWeight() async throws -> WeightEntry? {
        guard canUseHealthKit else { throw ConnectionError.unavailable }
        let type = HKQuantityType(.bodyMass)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type)], sortDescriptors: [SortDescriptor(\HKQuantitySample.endDate, order: .reverse)], limit: 1)
        guard let sample = try await descriptor.result(for: store).first else { return nil }
        return WeightEntry(kilograms: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), date: sample.endDate)
    }
}
