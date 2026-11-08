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
