import PhotosUI
import SwiftUI

struct AddFoodView: View {
    enum StartMode: String, Identifiable {
        var id: String { rawValue }
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
        _showingBarcodeScanner = State(initialValue: startMode == .barcode)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Int(calories).map { (0...100_000).contains($0) } ?? false)
            && [protein, carbs, fat].allSatisfy { $0.isEmpty || (Int($0).map { (0...100_000).contains($0) } ?? false) }
            && (servingGrams.isEmpty || (Double(servingGrams.replacingOccurrences(of: ",", with: ".")).map { $0.isFinite && $0 >= 0 && $0 <= 100_000 } ?? false))
    }

    var body: some View {
        NavigationStack {
            Group {
                if showingBarcodeScanner {
                    BarcodeScannerView { code in
                        showingBarcodeScanner = false
                        Task { await lookupBarcode(code) }
                    } onFailure: { message in
                        showingBarcodeScanner = false
                        estimationError = message
                    }
                    .overlay(alignment: .bottom) {
                        Button("Enter manually") { showingBarcodeScanner = false }
                            .buttonStyle(.borderedProminent)
                            .padding()
                    }
                } else {
                    foodForm
                }
            }
            .navigationTitle(showingBarcodeScanner ? "Scan barcode" : "Add food")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !hasStartedFlow else { return }
                hasStartedFlow = true
                if startMode == .photo { showingCamera = true }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if !showingBarcodeScanner { Button("Save") { save() }.disabled(!isValid || isEstimating || isLookingUpBarcode) }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    showingCamera = false
                    Task { await estimate(image) }
                } onCancel: { showingCamera = false }
                .ignoresSafeArea()
            }
        }
    }

    private var foodForm: some View {
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

                    Text("Photo estimates run through Apple Intelligence. Barcode scans use public product nutrition facts and, when available, prefill the package size. Review everything before saving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.quickLogFoods.isEmpty {
                    Section("Quick log") {
                        ForEach(store.quickLogFoods) { food in
                            savedFoodRow(food)
                        }
                    }
                }

                if !store.recentFoods.isEmpty {
                    Section("Recents") {
                        ForEach(store.recentFoods) { food in
                            savedFoodRow(food)
                        }
                    }
                }

                Section("Meal") {
                    TextField("What did you eat?", text: $name)
                    nutritionField("Calories", unit: "kcal", text: $calories)
                    nutritionField("Serving", unit: "g", text: $servingGrams, keyboard: .decimalPad)
                        .onChange(of: servingGrams) { _, gramsText in
                            guard let scannedProduct,
                                  let grams = Double(gramsText.replacingOccurrences(of: ",", with: ".")),
                                  grams.isFinite, grams >= 0, grams <= 100_000 else { return }
                            applyPer100g(scannedProduct, grams: grams)
                        }
                    if let packageGrams = scannedProduct?.packageGrams {
                        Text("Package size detected: \(packageGrams == 1_000 ? "1,000" : String(format: "%.0f", packageGrams)) g. Adjust if you ate less.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Macros") {
                    nutritionField("Protein", unit: "g", text: $protein)
                    nutritionField("Carbs", unit: "g", text: $carbs)
                    nutritionField("Fat", unit: "g", text: $fat)
                }

                if isLookingUpBarcode || isEstimating {
                    Section { ProgressView(isLookingUpBarcode ? "Looking up product…" : "Estimating meal…") }
                }
                if let estimationError {
                    Section {
                        Label(estimationError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(isEstimating || isLookingUpBarcode)
    }

    private func savedFoodRow(_ food: FoodEntry) -> some View {
        HStack(spacing: 12) {
            Button { fill(from: food) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name).foregroundStyle(.primary)
                    Text("\(food.calories) kcal · P \(food.protein) g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    store.togglePinned(food)
                } label: {
                    Label(store.isPinned(food) ? "Remove from Quick log" : "Pin to Quick log", systemImage: store.isPinned(food) ? "pin.slash" : "pin")
                }
            } label: {
                Image(systemName: store.isPinned(food) ? "pin.fill" : "pin")
                    .foregroundStyle(store.isPinned(food) ? .orange : .secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(store.isPinned(food) ? "Remove \(food.name) from Quick log" : "Pin \(food.name) to Quick log")
        }
    }

    private func nutritionField(_ title: String, unit: String, text: Binding<String>, keyboard: UIKeyboardType = .numberPad) -> some View {
        HStack {
            TextField("0", text: text)
                .keyboardType(keyboard)
                .monospacedDigit()
                .accessibilityLabel("\(title), \(unit)")
            Text("\(title) · \(unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityHidden(true)
        }
    }

    @MainActor
    private func estimatePhoto(_ item: PhotosPickerItem) async {
        isEstimating = true
        defer { isEstimating = false }
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
        barcode = nil
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
        scannedProduct = nil
        barcode = nil
        defer { isLookingUpBarcode = false }
        do {
            let product = try await BarcodeLookupService.product(for: code)
            barcode = product.barcode
            scannedProduct = product
            name = product.name
            let grams = product.packageGrams ?? 100
            servingGrams = String(format: "%.0f", grams)
            applyPer100g(product, grams: grams)
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
        guard isValid, let calories = Int(calories) else { return }
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
