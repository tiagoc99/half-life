// Sheet for adding one source. SourcesView owns the bound fields and clears the name and activity text when the sheet closes.
// The activity field uses the decimal pad. Its label includes the radiationUnit preference, which defaults to Ci.
// Save stays disabled until the name is non-empty and the activity text parses as a Double. Cancel dismisses the sheet without writing a source.
// The saved initialActivity is always curies. When radiationUnit is Bq, the typed number is divided by 3.7e10, the becquerels in one curie. Otherwise the typed number is stored as curies.
// The isotope picker lists every Isotope raw value. The date picker records a calendar date. SourceManager measures decay from that Date value.

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
                    // Converts the typed activity into curies, builds a Source, and asks SourceManager to append and save it.
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
