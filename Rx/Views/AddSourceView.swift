import SwiftUI

// Sheet to add a new source. Activity input respects radiationUnit (Ci / Bq); stored as Ci.
struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var sourceManager: SourceManager
    @Binding var newSourceName: String
    @Binding var newSourceActivity: String
    @Binding var newSourceIsotope: Isotope
    @Binding var newSourceDate: Date
    
    @AppStorage("radiationUnit") private var radiationUnit: String = "Ci"
    
    private static let bqPerCi: Double = 3.7e10
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Source Name", text: $newSourceName)
                Picker("Isotope", selection: $newSourceIsotope) {
                    ForEach(Isotope.allCases) { isotope in
                        Text(isotope.rawValue).tag(isotope)
                    }
                }
                TextField("Initial Activity (\(radiationUnit))", text: $newSourceActivity)
                    .keyboardType(.decimalPad)
                DatePicker("Initial Date", selection: $newSourceDate, displayedComponents: .date)
            }
            .navigationTitle("Add Source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let activityInput = Double(newSourceActivity), !newSourceName.isEmpty {
                            // Persist always in Ci.
                            let activityCi = radiationUnit == "Bq"
                                ? activityInput / Self.bqPerCi
                                : activityInput
                            let newSource = Source(
                                name: newSourceName,
                                isotope: newSourceIsotope.rawValue,
                                initialActivity: activityCi,
                                initialDate: newSourceDate
                            )
                            sourceManager.addSource(newSource)
                            dismiss()
                        }
                    }
                    .disabled(newSourceName.isEmpty || Double(newSourceActivity) == nil)
                }
            }
        }
    }
}
