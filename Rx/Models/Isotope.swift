// The four industrial radiography isotopes this app can store: Ir-192, Se-75, Co-60, and Yb-169.
// Each case carries the numbers the exposure math reads:
// halfLifeDays is the half-life in days. Current activity uses A = A0 * 0.5 ^ (days / halfLifeDays).
// gammaConstant is the specific gamma-ray constant in R·m²/(h·Ci): roentgen square meters per hour per curie.
// hvtSteelMm is a carbon-steel half-value thickness in millimeters. In the exposure formula, one of these thicknesses doubles the time.
// The stored values are Ir-192: 74 days, 0.592 R·m²/(h·Ci), 12 mm; Se-75: 120 days, 0.203, 8 mm; Co-60: 1925 days (about 5.27 years), 1.37, 22 mm; Yb-169: 32 days, 0.125, 3.5 mm.
// These presets are provisional. The comments already in this file record that IAEA TCS 3 (1992) Table 3.2 lists Ir 0.50 and Co 1.33, and that capsule construction, certificate output, and film calibration still have to be reconciled.
// Se-75 stays at the typical industrial 0.203. A QSA figure near 0.180 belongs to a particular capsule, and applying both would double-correct the output.
// Yb-169 stays at 0.125. The steel half-value numbers are a legacy preset and are a different quantity from shielding half-value layers used for equal film density.
// id is the raw value, the full isotope name. Source stores that string, and SourceManager looks it up again with Isotope(rawValue:).

// Enum for RT NDT isotopes (Ir-192, Se-75, Co-60, Yb-169).
// Half-life days; exposure constant R·m²/(h·Ci); provisional steel HVT mm.
// Presets require source/technique provenance; no standards-compliance claim.
enum Isotope: String, CaseIterable, Identifiable {
    case ir192 = "Iridium-192"
    case se75 = "Selenium-75"
    case co60 = "Cobalt-60"
    case yb169 = "Ytterbium-169"
    
    var id: String { rawValue }
    
    // Half-life in days (A = A0 * 0.5^(days / halfLife)).
    var halfLifeDays: Double {
        switch self {
        case .ir192: return 74.0
        case .se75: return 120.0
        case .co60: return 1925.0  // ~5.27 years
        case .yb169: return 32.0
        }
    }
    
    // Specific gamma-ray constant Γ in R·m²/(h·Ci).
    // Legacy Ir/Co presets retained pending matched source/film calibration.
    // IAEA TCS 3 (1992) Table 3.2 lists Ir 0.50 and Co 1.33; definitions must be reconciled.
    // Se-75: 0.203 R·m²/(h·Ci) — typical industrial radiography value
    //   QSA reports ~0.180 for a particular capsule/pigtail; do not double-correct certificate output.
    // Yb-169: 0.125 R·m²/(h·Ci) — typical industrial RT value
    //   Historical IAEA value agrees; intended source construction remains unverified.
    var gammaConstant: Double {
        switch self {
        case .ir192: return 0.592
        case .se75: return 0.203
        case .co60: return 1.37
        case .yb169: return 0.125
        }
    }
    
    // Legacy carbon-steel HVT mm: 2^(thickness/HVT). Numeric radiographic provenance unresolved;
    // shielding HVLs are not interchangeable with equal-film-density technique values.
    var hvtSteelMm: Double {
        switch self {
        case .ir192: return 12.0
        case .se75: return 8.0
        case .co60: return 22.0
        case .yb169: return 3.5
        }
    }
}
