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
    private var sourceRecords: [String] {
        sourceManager.sources.flatMap { source in
            [source.id.uuidString, source.isotope, String(source.initialActivity),
             String(source.initialDate.timeIntervalSinceReferenceDate)]
        }
    }

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

    private func synchronizeSelectedSource() {
        guard let source = selectedSource else { return }
        selectedSource = sourceManager.sources.first { $0.id == source.id }
    }

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
    
    private func stopTimer() {
        timer?.invalidate()
        isTiming = false
    }
}
