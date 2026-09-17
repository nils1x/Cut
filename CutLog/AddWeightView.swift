import SwiftUI

struct AddWeightView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kilograms = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("kg", text: $kilograms)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let normalized = kilograms.replacingOccurrences(of: ",", with: ".")
                        if let value = Double(normalized), value > 0 {
                            store.addWeight(value)
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
