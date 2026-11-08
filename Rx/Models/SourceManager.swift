import Foundation

// Central source manager: persistence (UserDefaults), decay, and exposure calculations.
class SourceManager: ObservableObject {
    @Published var sources: [Source] = []
    
    private let storageKey = "sources"
    
    init() {
        loadSources()
    }
    
    func addSource(_ source: Source) {
        sources.append(source)
        saveSources()
    }
    
    func deleteSource(at offsets: IndexSet) {
        sources.remove(atOffsets: offsets)
        saveSources()
    }
    
    // Current activity via exponential decay: A = A0 * 0.5^(days / halfLife).
    func calculateCurrentActivity(for source: Source) -> Double {
        guard let isotope = Isotope(rawValue: source.isotope) else { return source.initialActivity }
        let daysPassed = Date().timeIntervalSince(source.initialDate) / 86400.0
        let decayFactor = pow(0.5, daysPassed / isotope.halfLifeDays)
        return source.initialActivity * decayFactor
    }
    
    // Provisional exposure estimate; not a validated ASTM/ISO technique.
    // Time (min) = 60 * [FilmFactor * Attenuation * (SFD_m)^2] / (Gamma * Activity).
    // correctionRatioPercent: 0 = no extra margin; 100 ≈ 2× time (aligns with Settings "~100% longer").
    func calculateExposureTime(
        source: Source,
        sfdMm: Double,
        thicknessMm: Double,
        filmType: FilmType = .d7,
        targetDensity: Double = 2.5,
        material: Material = .carbonSteel,
        correctionRatioPercent: Double = 0.0
    ) -> Double {
        // Zero is the existing API's unavailable sentinel, never a valid exposure.
        // Zero thickness is valid (unattenuated reference); distance/activity must be positive.
        // Match the UI's nonnegative safety-margin domain without an arbitrary upper cap.
        guard let isotope = Isotope(rawValue: source.isotope),
              source.initialActivity.isFinite, source.initialActivity > 0,
              source.initialDate.timeIntervalSinceReferenceDate.isFinite,
              sfdMm.isFinite, sfdMm > 0,
              thicknessMm.isFinite, thicknessMm >= 0,
              targetDensity.isFinite, targetDensity > 0,
              correctionRatioPercent.isFinite, correctionRatioPercent >= 0 else { return 0 }
        let activity = calculateCurrentActivity(for: source)
        guard activity.isFinite, activity > 0 else { return 0 }
        let sfdM = sfdMm / 1000.0
        // Legacy 2.4 R D7 normalization: provenance/processing conditions unverified.
        let baseFilmFactor: Double = 2.4
        let relativeFactor = filmType.relativeFactor(for: isotope)
        let filmFactor = filmType == .custom ? FilmType.customExposureR : baseFilmFactor * relativeFactor
        guard filmFactor.isFinite, filmFactor > 0 else { return 0 }
        let refDensity: Double = 2.5
        // Assumed constant H&D gradient 2.5; film/process-dependent, not universally validated.
        let densityCorrection = pow(10.0, 0.4 * (targetDensity - refDensity))
        // Settings correction: 100% longer ≈ 2× exposure (not density-mangled into ~10×).
        let safetyCorrection = 1.0 + (correctionRatioPercent / 100.0)
        let adjustedFilmFactor = filmFactor * densityCorrection * safetyCorrection
        let equivThickness = thicknessMm * material.equivalenceFactor(for: isotope)
        let attenuation = pow(2.0, equivThickness / isotope.hvtSteelMm)
        let distanceSquared = pow(sfdM, 2.0)
        let denominator = isotope.gammaConstant * activity
        let numerator = adjustedFilmFactor * attenuation * distanceSquared
        guard densityCorrection.isFinite, densityCorrection > 0,
              safetyCorrection.isFinite, safetyCorrection > 0,
              adjustedFilmFactor.isFinite, adjustedFilmFactor > 0,
              equivThickness.isFinite, attenuation.isFinite, attenuation > 0,
              distanceSquared.isFinite, distanceSquared > 0,
              denominator.isFinite, denominator > 0,
              numerator.isFinite, numerator > 0 else { return 0 }
        let timeMinutes = (numerator / denominator) * 60.0
        return timeMinutes.isFinite && timeMinutes > 0 ? timeMinutes : 0
    }
    
    private func loadSources() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedSources = try? JSONDecoder().decode([Source].self, from: data) {
            sources = savedSources
        }
    }
    
    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
