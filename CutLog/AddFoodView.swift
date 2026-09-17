import PhotosUI
import SwiftUI

struct AddFoodView: View {
    enum StartMode {
        case manual
        case photo
        case barcode
    }

    let startMode: StartMode

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var servingGrams = "100"
    @State private var barcode: String?
    @State private var scannedProduct: BarcodeProduct?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isEstimating = false
    @State private var estimationError: String?
    @State private var showingCamera = false
    @State private var showingBarcodeScanner = false
    @State private var isLookingUpBarcode = false
    @State private var hasStartedFlow = false

    init(startMode: StartMode = .manual) {
        self.startMode = startMode
    }

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && Int(calories) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showingCamera = true } label: {
                        Label("Take meal photo", systemImage: "camera")
                    }
                    .disabled(isEstimating)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose meal photo", systemImage: "photo")
                    }
                    .disabled(isEstimating)
                    .onChange(of: selectedPhoto) { _, item in
                        guard let item else { return }
                        Task { await estimatePhoto(item) }
                    }

                    Button { showingBarcodeScanner = true } label: {
                        Label(isLookingUpBarcode ? "Looking up barcode…" : "Scan barcode", systemImage: "barcode.viewfinder")
                    }
                    .disabled(isLookingUpBarcode)

                    Text("Photo estimates run through Apple Intelligence. Barcode scans look up public product nutrition facts. Review everything before saving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.recentFoods.isEmpty {
                    Section("Quick add") {
                        ForEach(store.recentFoods) { food in
                            Button { fill(from: food) } label: {
                                HStack {
                                    Text(food.name).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(food.calories) kcal").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Meal") {
                    TextField("What did you eat?", text: $name)
                    TextField("Calories", text: $calories).keyboardType(.numberPad)
                    TextField("Serving (g)", text: $servingGrams)
                        .keyboardType(.decimalPad)
                        .onChange(of: servingGrams) { _, gramsText in
                            guard let scannedProduct,
                                  let grams = Double(gramsText.replacingOccurrences(of: ",", with: ".")),
                                  grams >= 0 else { return }
                            applyPer100g(scannedProduct, grams: grams)
                        }
                }

                Section("Macros") {
                    TextField("Protein (g)", text: $protein).keyboardType(.numberPad)
                    TextField("Carbs (g)", text: $carbs).keyboardType(.numberPad)
                    TextField("Fat (g)", text: $fat).keyboardType(.numberPad)
                }

                if let estimationError {
                    Section {
                        Label(estimationError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !hasStartedFlow else { return }
                hasStartedFlow = true
                switch startMode {
                case .manual:
                    break
                case .photo:
                    showingCamera = true
                case .barcode:
                    showingBarcodeScanner = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!isValid) }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    showingCamera = false
                    Task { await estimate(image) }
                } onCancel: {
                    showingCamera = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                NavigationStack {
                    BarcodeScannerView { code in
                        showingBarcodeScanner = false
                        Task { await lookupBarcode(code) }
                    } onFailure: { message in
                        showingBarcodeScanner = false
                        estimationError = message
                    }
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingBarcodeScanner = false } }
                    }
                }
            }
        }
    }

    @MainActor
    private func estimatePhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                throw MealEstimateService.EstimateError.noImage
            }
            await estimate(image)
        } catch {
            estimationError = error.localizedDescription
        }
    }

    @MainActor
    private func estimate(_ image: UIImage) async {
        isEstimating = true
        estimationError = nil
        scannedProduct = nil
        defer { isEstimating = false }
        do {
            let result = try await MealEstimateService.estimate(from: image)
            name = result.name
            calories = String(result.calories)
            protein = String(result.protein)
            carbs = String(result.carbs)
            fat = String(result.fat)
        } catch {
            estimationError = error.localizedDescription
        }
    }

    @MainActor
    private func lookupBarcode(_ code: String) async {
        isLookingUpBarcode = true
        estimationError = nil
        defer { isLookingUpBarcode = false }
        do {
            let product = try await BarcodeLookupService.product(for: code)
            barcode = product.barcode
            scannedProduct = product
            name = product.name
            servingGrams = "100"
            applyPer100g(product, grams: 100)
        } catch {
            estimationError = error.localizedDescription
        }
    }

    private func applyPer100g(_ product: BarcodeProduct, grams: Double) {
        let multiplier = grams / 100
        calories = String(Int((product.caloriesPer100g * multiplier).rounded()))
        protein = String(Int((product.proteinPer100g * multiplier).rounded()))
        carbs = String(Int((product.carbsPer100g * multiplier).rounded()))
        fat = String(Int((product.fatPer100g * multiplier).rounded()))
    }

    private func fill(from food: FoodEntry) {
        scannedProduct = nil
        name = food.name
        calories = String(food.calories)
        protein = String(food.protein)
        carbs = String(food.carbs)
        fat = String(food.fat)
        servingGrams = food.servingGrams.map { String(format: "%.0f", $0) } ?? "100"
        barcode = food.barcode
    }

    private func save() {
        guard let calories = Int(calories) else { return }
        let grams = Double(servingGrams.replacingOccurrences(of: ",", with: "."))
        store.addFood(FoodEntry(
            name: name.trimmingCharacters(in: .whitespaces),
            calories: calories,
            protein: Int(protein) ?? 0,
            carbs: Int(carbs) ?? 0,
            fat: Int(fat) ?? 0,
            servingGrams: grams,
            barcode: barcode
        ))
        dismiss()
    }
}
