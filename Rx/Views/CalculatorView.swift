// Calculator tab. It collects a source and a setup, asks SourceManager for an exposure time, and can run a countdown of that result.
// The distance and thickness fields keep the typed text. The state properties are named sfdMm and thicknessMm, and the selected unit decides the conversion. On Calculate, the unit "in" multiplies by 25.4 millimeters per inch. Any other unit string, including the default mm, passes the typed number on as millimeters.
// Target density starts as the text 2.5. correctionRatio is the Settings safety margin in percent, default 0. filmCategory defaults to Type D films. customFilmFactor defaults to 1.0 and is the absolute custom exposure in roentgens, the same preference FilmType reads.
// Calculate runs when a source is selected and distance, thickness, and density all parse as Doubles. The button stays disabled when any of those three numbers is less than or equal to zero. The model function also accepts a thickness of exactly zero; this button asks for a thickness above zero.
// calculatedTimeMin is in minutes. The label shows seconds, minutes times 60, when that is under 60 seconds, and shows minutes otherwise. After a positive result, a change to calculationInputs sets resultIsStale and the heading says the previous time is out of date.
// The timer section is shown while a countdown is running, or while a positive result is still current. Start copies the calculated minutes into timeLeft as seconds and schedules a one-second Timer that subtracts one until zero. Stop, and onDisappear, invalidate that timer. A countdown keeps the duration it started with when the inputs later change.
// filteredFilms limits the picker to the Settings category: D2 through D8, the four IX films, the five K films, or the single Custom row. An unrecognized category lists every film. reconcileFilmSelection moves the selection to IX100, T200, Custom, or D7 when the current film is outside the category.
// The default material is copied in the first time this screen appears. A later visit keeps the material chosen here, unless the Settings default itself changes. Source selection follows the UUID. synchronizeSelectedSource clears it when that id is gone. calculationInputs also watches isotope, curies, and date, because Source equality compares ids only.
// The activity caption uses the same becquerel rule as Sources: multiply curies by 3.7e10 when the unit is Bq.

import SwiftUI

// Exposure calculator: source, film, material, SFD, thickness → time + timer.
struct CalculatorView: View {
    @ObservedObject var sourceManager: SourceManager
    @State private var selectedSource: Source?
    @State private var selectedFilmType: FilmType = .d7
    @State private var selectedMaterial: Material = .carbonSteel
    @State private var sfdMm: String = ""
    @State private var thicknessMm: String = ""
    @State private var targetDensity: String = "2.5"
    @State private var calculatedTimeMin: Double = 0
    @State private var resultIsStale = false
    @State private var isTiming = false
    @State private var timeLeft: Double = 0
    @State private var timer: Timer?
    @State private var didApplyDefaultMaterial = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @AppStorage("distanceUnit") private var distanceUnit: String = "mm"
    @AppStorage("thicknessUnit") private var thicknessUnit: String = "mm"
    @AppStorage("radiationUnit") private var radiationUnit: String = "Ci"
    @AppStorage("correctionRatio") private var correctionRatio: Double = 0.0
    @AppStorage("filmCategory") private var filmCategory: String = "Type D films"
    @AppStorage("customFilmFactor") private var customFilmFactor: Double = 1.0
    @AppStorage("defaultMaterial") private var defaultMaterial: String = "Carbon Steel"
    
    private static let bqPerCi: Double = 3.7e10
    
    // Unique FilmType cases per display row (no duplicate ForEach ids).
    // Film rows for the current category. Each FilmType case is a separate picker id.
    private var filteredFilms: [(film: FilmType, display: String)] {
        switch filmCategory {
        case "Type D films":
            return [
                (.d2, FilmType.d2.rawValue),
                (.d3, FilmType.d3.rawValue),
                (.d4, FilmType.d4.rawValue),
                (.d5, FilmType.d5.rawValue),
                (.d7, FilmType.d7.rawValue),
                (.d8, FilmType.d8.rawValue)
            ]
        case "Type IX films":
            return [
                (.ix25, "IX25"),
                (.ix50, "IX50"),
                (.ix80, "IX80"),
                (.ix100, "IX100")
            ]
        case "Type K films":
            return [
                (.m100, "M100"),
                (.sh800, "SH800"),
                (.mx125, "MX125"),
                (.t200, "T200"),
                (.aa400, "AA400")
            ]
        case "Custom":
            return [(.custom, FilmType.custom.displayLabel)]
        default:
            return FilmType.allCases.map { (film: $0, display: $0.rawValue) }
        }
    }
    
    // Shows decayed activity in curies, or in becquerels when that preference is selected.
    private func formatActivityCi(_ activityCi: Double) -> String {
        if radiationUnit == "Bq" {
            return String(format: "%.3e %@", activityCi * Self.bqPerCi, radiationUnit)
        }
        return String(format: "%.2f %@", activityCi, radiationUnit)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Source") {
                    Picker("Source", selection: $selectedSource) {
                        Text("Select a source").tag(nil as Source?)
                        ForEach(sourceManager.sources, id: \.id) { source in
                            Text(source.name).tag(Optional(source))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if let source = selectedSource {
                        let current = sourceManager.calculateCurrentActivity(for: source)
                        Text("Activity: \(formatActivityCi(current))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Setup") {
                    Picker("Film", selection: $selectedFilmType) {
                        ForEach(filteredFilms, id: \.film.id) { item in
                            Text(item.display).tag(item.film)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if filmCategory == "Custom" {
                        TextField("Custom exposure (R)", value: $customFilmFactor, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                .onChange(of: filmCategory) { _, _ in
                    reconcileFilmSelection()
                }
                
                Section("Geometry") {
                    Picker("Material", selection: $selectedMaterial) {
                        ForEach(Material.allCases) { mat in
                            Text(mat.rawValue).tag(mat)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    numericInput("Source-to-film distance", unit: distanceUnit, text: $sfdMm)
                    numericInput("Thickness", unit: thicknessUnit, text: $thicknessMm)
                }

                Section {
                    DisclosureGroup("Exposure options") {
                        numericInput("Target density", unit: "", text: $targetDensity)
                        Text("Default density: 2.5. Safety margin is configured separately in Settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Calculation") {
                    if let source = selectedSource,
                       let sfdInput = Double(sfdMm),
                       let thicknessInput = Double(thicknessMm),
                       let density = Double(targetDensity) {
                        Button("Calculate Exposure Time") {
                            let sfdMmConverted = distanceUnit == "in" ? sfdInput * 25.4 : sfdInput
                            let thicknessMmConverted = thicknessUnit == "in" ? thicknessInput * 25.4 : thicknessInput
                            
                            resultIsStale = false
                            calculatedTimeMin = sourceManager.calculateExposureTime(
                                source: source,
                                sfdMm: sfdMmConverted,
                                thicknessMm: thicknessMmConverted,
                                filmType: selectedFilmType,
                                targetDensity: density,
                                material: selectedMaterial,
                                correctionRatioPercent: correctionRatio
                            )
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Calculates exposure using the selected source and setup.")
                        .disabled(sfdInput <= 0 || thicknessInput <= 0 || density <= 0)
                        
                        if calculatedTimeMin > 0 {
                            let timeSeconds = calculatedTimeMin * 60
                            let displayText = timeSeconds < 60
                                ? "\(String(format: "%.2f", timeSeconds)) seconds"
                                : "\(String(format: "%.2f", calculatedTimeMin)) minutes"
                            VStack(alignment: .leading, spacing: 8) {
                                Text(resultIsStale ? "Previous exposure time — out of date" : "Exposure time")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(displayText)
                                    .font(.title.bold())
                                    .monospacedDigit()
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                            

                        }
                    } else {
                        Button("Calculate Exposure Time") {}
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.borderedProminent)
                            .disabled(true)
                        Text("Select a source and enter distance, thickness, and density to calculate.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if calculatedTimeMin > 0 && resultIsStale {
                    Section {
                        Label("Inputs changed — calculate again. The previous result is out of date.", systemImage: "arrow.clockwise")
                            .font(.footnote)
                    }
                }
                if isTiming || (calculatedTimeMin > 0 && !resultIsStale) {
                    Section("Exposure timer") {
                        Button(isTiming ? "Stop Timer" : "Start Timer") {
                            toggleTimer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.bordered)
                        if isTiming {
                            Text("Time Left: \(String(format: "%.0f", timeLeft)) seconds")
                                .font(.title2)
                                .monospacedDigit()
                            Text("This timer continues its original duration, even if calculator inputs change.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Calculator")
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                reconcileFilmSelection()
                synchronizeSelectedSource()
                if !didApplyDefaultMaterial {
                    if let mat = Material(rawValue: defaultMaterial) {
                        selectedMaterial = mat
                    }
                    didApplyDefaultMaterial = true
                }
            }
            .onChange(of: defaultMaterial) { _, newValue in
                if let mat = Material(rawValue: newValue) {
                    selectedMaterial = mat
                }
            }
            .onChange(of: calculationInputs) { _, _ in
                if calculatedTimeMin > 0 { resultIsStale = true }
            }
            .onChange(of: sourceRecords) { _, _ in
                synchronizeSelectedSource()
            }
            .onDisappear(perform: stopTimer)
        }
    }
    
    // Source equality is UUID-only, so explicitly include all calculation fields.
    // Id, isotope, curies, and date for every saved source, so edits that Source equality ignores still refresh the screen.
    private var sourceRecords: [String] {
        sourceManager.sources.flatMap { source in
            [source.id.uuidString, source.isotope, String(source.initialActivity),
             String(source.initialDate.timeIntervalSinceReferenceDate)]
        }
    }

    // Values that mark an existing result out of date, including the saved source records.
    private var calculationInputs: [String] {
        var values = [sfdMm, thicknessMm, targetDensity, selectedFilmType.rawValue,
                      filmCategory, selectedMaterial.rawValue, String(correctionRatio),
                      String(customFilmFactor), distanceUnit, thicknessUnit, radiationUnit]
        if let source = selectedSource {
            values += [source.id.uuidString, source.isotope, String(source.initialActivity),
                       String(source.initialDate.timeIntervalSinceReferenceDate)]
        }
        return values + sourceRecords
    }

    // Keeps the picker on the same UUID, or clears it after that source is deleted.
    private func synchronizeSelectedSource() {
        guard let source = selectedSource else { return }
        selectedSource = sourceManager.sources.first { $0.id == source.id }
    }

    // Selects a film that belongs to the active category.
    private func reconcileFilmSelection() {
        guard !filteredFilms.contains(where: { $0.film == selectedFilmType }) else { return }
        switch filmCategory {
        case "Type IX films": selectedFilmType = .ix100
        case "Type K films": selectedFilmType = .t200
        case "Custom": selectedFilmType = .custom
        default: selectedFilmType = .d7
        }
    }

    /// Keep field context visible after editing; stack at accessibility text sizes.
    // Decimal field with its unit in the label. Accessibility sizes stack the label above the field. Other sizes try a side-by-side row, then that stack when the row does not fit.
    private func numericInput(_ title: String, unit: String, text: Binding<String>) -> some View {
        let label = unit.isEmpty ? title : "\(title) (\(unit))"
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(label)
                    TextField("Enter value", text: text)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel(label)
                        .frame(minHeight: 44)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        Text(label)
                            .fixedSize(horizontal: true, vertical: true)
                        TextField("Enter value", text: text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel(label)
                            .frame(minWidth: 100, minHeight: 44)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(label)
                        TextField("Enter value", text: text)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel(label)
                            .frame(minHeight: 44)
                    }
                }
            }
        }
        .foregroundStyle(.primary)
    }

    // Starts a one-second countdown from the calculated minutes, or stops the countdown that is running.
    private func toggleTimer() {
        isTiming.toggle()
        if isTiming {
            timeLeft = calculatedTimeMin * 60
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if timeLeft > 0 {
                    timeLeft -= 1
                } else {
                    timer?.invalidate()
                    isTiming = false
                }
            }
        } else {
            stopTimer()
        }
    }
    
    // Invalidates the countdown and clears the running flag.
    private func stopTimer() {
        timer?.invalidate()
        isTiming = false
    }
}
