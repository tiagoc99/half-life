import Foundation

// Agfa Structurix D films plus IX / K equivalents with unique cases (unique ForEach ids).
// Legacy relative exposure factors vs D7=1.0; cross-brand mappings unverified.
// Carestream publishes HS800, not the legacy SH800 label here; no silent remapping.
enum FilmType: String, CaseIterable, Identifiable {
    case d2 = "D2 (C1, Special)"
    case d3 = "D3 (C2, 1)"
    case d4 = "D4 (C3, 1)"
    case d5 = "D5 (C4, 1)"
    case d7 = "D7 (C5, 2)"
    case d8 = "D8 (C6, 3)"
    // Type IX (unique ids — do not share enum cases with each other)
    case ix25 = "IX25"
    case ix50 = "IX50"
    case ix80 = "IX80"
    case ix100 = "IX100"
    // Type K (unique ids)
    case m100 = "M100"
    case sh800 = "SH800"
    case mx125 = "MX125"
    case t200 = "T200"
    case aa400 = "AA400"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    // Stored customFilmFactor now denotes absolute exposure in R. Keep existing
    // numeric preferences unchanged; an absent preference uses the UI default 1 R.
    static var customExposureR: Double {
        (UserDefaults.standard.object(forKey: "customFilmFactor") as? NSNumber)?.doubleValue ?? 1.0
    }

    var displayLabel: String {
        if case .custom = self {
            let factor = Self.customExposureR
            return "Custom (\(String(format: "%.2f", factor)) R)"
        }
        return rawValue
    }
    
    // Relative speed factor by isotope (higher = slower film, longer time).
    func relativeFactor(for isotope: Isotope) -> Double {
        switch self {
        case .d2, .m100, .sh800:
            // M100 / SH800 ≈ D2 class
            let factors: [Isotope: Double] = [.ir192: 8.0, .se75: 6.4, .co60: 9.0, .yb169: 9.0]
            return factors[isotope] ?? 1.0
        case .d3, .mx125:
            let factors: [Isotope: Double] = [.ir192: 5.0, .se75: 3.6, .co60: 5.0, .yb169: 4.1]
            return factors[isotope] ?? 1.0
        case .d4, .t200:
            let factors: [Isotope: Double] = [.ir192: 3.0, .se75: 2.4, .co60: 3.0, .yb169: 3.0]
            return factors[isotope] ?? 1.0
        case .d5, .ix50, .ix80, .aa400:
            // IX50 / IX80 ≈ D5 class (separate cases → unique Picker ids)
            let factors: [Isotope: Double] = [.ir192: 1.5, .se75: 1.4, .co60: 1.5, .yb169: 1.7]
            return factors[isotope] ?? 1.0
        case .d7, .ix100:
            return 1.0
        case .d8, .ix25:
            let factors: [Isotope: Double] = [.ir192: 0.6, .se75: 0.6, .co60: 0.6, .yb169: 0.6]
            return factors[isotope] ?? 1.0
        case .custom:
            return Self.customExposureR / 2.4 // Equivalent relative factor; stored value is absolute R.
        }
    }
}
