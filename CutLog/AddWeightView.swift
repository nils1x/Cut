import SwiftUI

struct AddWeightView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// nil means "add"; non-nil means "edit this weigh-in".
    let editing: WeightEntry?
    @State private var kilograms = ""

    init(editing: WeightEntry? = nil) {
        self.editing = editing
        _kilograms = State(initialValue: editing.map { String(format: "%.1f", $0.kilograms) } ?? "")
    }

    private var normalized: Double? {
        guard let value = Double(kilograms.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("0.0", text: $kilograms)
                            .keyboardType(.decimalPad)
                            .font(CutLogStyle.Number.metric)
                            .monospacedDigit()
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    if let editing {
                        Text(editing.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(editing == nil ? "Log weight" : "Edit weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(normalized == nil)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        guard let value = normalized else { return }
        if let editing, let index = store.weights.firstIndex(where: { $0.id == editing.id }) {
            store.weights[index].kilograms = value
        } else {
            store.addWeight(value)
        }
        dismiss()
    }
}