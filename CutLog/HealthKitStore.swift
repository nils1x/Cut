import Foundation
import HealthKit

actor HealthKitStore {
    static let shared = HealthKitStore()
    private let store = HKHealthStore()

    private var canUseHealthKit: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard canUseHealthKit else { return false }
        let toShare: Set<HKSampleType> = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.bodyMass),
            HKObjectType.workoutType()
        ]
        let toRead: Set<HKObjectType> = [HKQuantityType(.bodyMass)]
        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
            return true
        } catch {
            return false
        }
    }

    func save(food: FoodEntry, isEnabled: Bool) async {
        guard isEnabled, canUseHealthKit else { return }
        let samples: [HKQuantitySample] = [
            HKQuantitySample(type: HKQuantityType(.dietaryEnergyConsumed), quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(food.calories)), start: food.date, end: food.date),
            HKQuantitySample(type: HKQuantityType(.dietaryProtein), quantity: HKQuantity(unit: .gram(), doubleValue: Double(food.protein)), start: food.date, end: food.date),
            HKQuantitySample(type: HKQuantityType(.dietaryCarbohydrates), quantity: HKQuantity(unit: .gram(), doubleValue: Double(food.carbs)), start: food.date, end: food.date),
            HKQuantitySample(type: HKQuantityType(.dietaryFatTotal), quantity: HKQuantity(unit: .gram(), doubleValue: Double(food.fat)), start: food.date, end: food.date)
        ]
        try? await store.save(samples)
    }

    func save(weight: WeightEntry, isEnabled: Bool) async {
        guard isEnabled, canUseHealthKit else { return }
        let sample = HKQuantitySample(type: HKQuantityType(.bodyMass), quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight.kilograms), start: weight.date, end: weight.date)
        try? await store.save(sample)
    }

    func save(workout: WorkoutEntry, isEnabled: Bool) async {
        guard isEnabled, canUseHealthKit else { return }
        let workout = HKWorkout(activityType: .traditionalStrengthTraining, start: workout.completedAt, end: workout.completedAt)
        try? await store.save(workout)
    }

    func latestWeight() async -> WeightEntry? {
        guard canUseHealthKit else { return nil }
        let type = HKQuantityType(.bodyMass)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type)], sortDescriptors: [SortDescriptor(\HKQuantitySample.endDate, order: .reverse)], limit: 1)
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return WeightEntry(kilograms: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), date: sample.endDate)
    }
}
