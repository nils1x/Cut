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
    @State private var search = ""
    @State private var name = ""
    @State private var mealDescription = ""
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

    private var isSearching: Bool { !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var results: [FoodCatalogItem] { store.searchFoods(query: search) }

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
                } else if isSearching {
                    resultsList
                } else {
                    foodForm
                }
            }
            .navigationTitle(showingBarcodeScanner ? "Scan barcode" : (isSearching ? "Log again" : "Add food"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search logged food")
            .onChange(of: search) { _, value in
                guard !value.isEmpty else { return }
                showingBarcodeScanner = false
            }
            .onAppear {
                guard !hasStartedFlow else { return }
                hasStartedFlow = true
                if startMode == .photo { showingCamera = true }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if !showingBarcodeScanner && !isSearching {
                        Button("Save") { save() }.disabled(!isValid || isEstimating || isLookingUpBarcode)
                    }
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

    private var resultsList: some View {
        List {
            if results.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                Section {
                    ForEach(results) { item in
                        Button { log(item) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).foregroundStyle(.primary)
                                    Text("\(item.calories) kcal · P \(item.protein) g")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { fill(from: item) } label: {
                                Label("Edit portion", systemImage: "slider.horizontal.3")
                            }
                        }
                        .swipeActions {
                            Button { fill(from: item) } label: {
                                Label("Edit", systemImage: "slider.horizontal.3")
                            }
                            .tint(CutLogPalette.apricot)
                        }
                    }
                }
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
                }

                if !store.quickLogFoods.isEmpty {
                    Section("Quick log") {
                        ForEach(store.quickLogFoods) { food in
                            savedFoodRow(food)
                        }
                    }
                }

                if !store.relogFavorites.isEmpty {
                    Section("Log again") {
                        ForEach(store.relogFavorites) { item in
                            Button { log(item) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).foregroundStyle(.primary)
                                        Text("\(item.calories) kcal · P \(item.protein) g")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Describe meal") {
                    HStack {
                        TextField("e.g. 3 pieces of Diavola pizza", text: $mealDescription)
                            .textInputAutocapitalization(.sentences)
                        Button("Estimate") { Task { await estimateDescription() } }
                            .disabled(mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEstimating)
                    }
                }

                Section("Meal") {
                    TextField("Food name", text: $name)
                    nutritionField("Calories", unit: "kcal", text: $calories)
                    nutritionField("Portion (optional)", unit: "g", text: $servingGrams, keyboard: .decimalPad)
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

    /// Tap a catalog hit: log the same portion immediately.
    private func log(_ item: FoodCatalogItem) {
        store.addFood(item.entry())
        dismiss()
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
                    .foregroundStyle(store.isPinned(food) ? CutLogPalette.apricot : Color.secondary)
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
    private func estimateDescription() async {
        let description = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return }
        isEstimating = true
        estimationError = nil
        scannedProduct = nil
        barcode = nil
        servingGrams = ""
        defer { isEstimating = false }
        do {
            let result = try await MealEstimateService.estimate(description: description)
            guard MealEstimateService.matchesDescription(result.name, describedAs: description) else {
                throw MealEstimateService.EstimateError.unrelatedResult
            }
            guard MealEstimateService.isPlausibleNutrition(result) else {
                throw MealEstimateService.EstimateError.implausibleNutrition
            }
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
    private func estimate(_ image: UIImage) async {
        isEstimating = true
        estimationError = nil
        scannedProduct = nil
        barcode = nil
        servingGrams = ""
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
        search = ""
        scannedProduct = nil
        name = food.name
        calories = String(food.calories)
        protein = String(food.protein)
        carbs = String(food.carbs)
        fat = String(food.fat)
        servingGrams = food.servingGrams.map { String(format: "%.0f", $0) } ?? ""
        barcode = food.barcode
    }

    private func fill(from item: FoodCatalogItem) {
        fill(from: item.entry())
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