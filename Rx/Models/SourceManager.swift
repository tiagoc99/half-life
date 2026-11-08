// Source list, decay math, and the provisional exposure-time estimate.
// Persistence uses UserDefaults key "sources". The value is a JSON encoding of the Source array. addSource and deleteSource change the array and save immediately. A missing or unreadable value leaves the list empty.
// calculateCurrentActivity returns curies. Elapsed days are the seconds from initialDate until now, divided by 86400. Activity is initialActivity * 0.5 ^ (days / halfLifeDays). A future initialDate makes days negative, so the result is higher than the stored activity. An isotope string that is not in the enum returns initialActivity unchanged.
// calculateExposureTime returns minutes. It returns 0 when the inputs cannot produce a usable exposure, and callers treat that 0 as no result. Thickness may be 0 mm, which means no steel attenuation. Distance, initial activity, decayed activity, target density, and the film exposure must be finite and greater than 0. The safety margin must be finite and at least 0 percent. This function does not cap the percent. The initial date must have a finite time interval.
// Distance enters in millimeters and is divided by 1000 to become meters, because gammaConstant is in R·m²/(h·Ci). Activity stays in curies. (film exposure * attenuation * distance in meters squared) / (gammaConstant * activity) is a number of hours. Multiplying by 60 yields minutes.
// Film exposure is in roentgens. Custom uses FilmType.customExposureR. Every other film uses 2.4 R times relativeFactor(for:). 2.4 R is the legacy D7 exposure at optical density 2.5.
// Density correction is 10 ^ (0.4 * (targetDensity - 2.5)). The 0.4 is 1/2.5 from an assumed constant H&D gradient of 2.5. At density 2.5 the factor is 1. That gradient depends on the film and the process.
// The safety multiplier is 1 + correctionRatioPercent / 100. Zero percent leaves the time unchanged. 100 percent doubles it. It is applied beside the density correction, as its own multiplier.
// Equivalent steel millimeters are thicknessMm * the material factor. Attenuation is 2 ^ (equivalent millimeters / hvtSteelMm), so each half-value thickness doubles the time.
// The product is a provisional estimate from these presets. A matched source, film, and technique calibration is still required before the minutes are used to choose an exposure.

import Foundation

// Central source manager: persistence (UserDefaults), decay, and exposure calculations.
class SourceManager: ObservableObject {
    @Published var sources: [Source] = []
    
    private let storageKey = "sources"
    
    init() {
        loadSources()
    }
    
    // Appends the source and writes the JSON list.
    func addSource(_ source: Source) {
        sources.append(source)
        saveSources()
    }
    
    // Removes the list rows in offsets and writes the JSON list.
    func deleteSource(at offsets: IndexSet) {
        sources.remove(atOffsets: offsets)
        saveSources()
    }
    
    // Current activity via exponential decay: A = A0 * 0.5^(days / halfLife).
    // Decayed activity in curies for this source at the current date and time.
    func calculateCurrentActivity(for source: Source) -> Double {
        guard let isotope = Isotope(rawValue: source.isotope) else { return source.initialActivity }
        let daysPassed = Date().timeIntervalSince(source.initialDate) / 86400.0
        let decayFactor = pow(0.5, daysPassed / isotope.halfLifeDays)
        return source.initialActivity * decayFactor
    }
    
    // Provisional exposure estimate; not a validated ASTM/ISO technique.
    // Time (min) = 60 * [FilmFactor * Attenuation * (SFD_m)^2] / (Gamma * Activity).
    // correctionRatioPercent: 0 = no extra margin; 100 ≈ 2× time (aligns with Settings "~100% longer").
    // Estimated exposure in minutes from activity, distance, thickness, film, density, material, and safety margin.
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
    
    // Replaces sources when the JSON under "sources" decodes.
    private func loadSources() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedSources = try? JSONDecoder().decode([Source].self, from: data) {
            sources = savedSources
        }
    }
    
    // Encodes the current array and stores it under the "sources" key.
    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
