import Foundation

// Provisional material steel-equivalence presets; gamma-specific provenance unverified.
// Composition, density, spectrum and technique must match before field calibration.
// equiv. thickness = thickness * factor; carbon steel = 1.0.
enum Material: String, CaseIterable, Identifiable {
    case carbonSteel = "Carbon Steel"
    case stainlessSteel = "Stainless Steel"
    case aluminum = "Aluminum"
    case copper = "Copper"
    case titanium = "Titanium"
    case nickel = "Nickel"
    case zinc = "Zinc"
    case plastic = "Plastic"
    case concrete = "Concrete"
    
    var id: String { rawValue }
    
    // Steel-equivalence by isotope (lower = more penetration, shorter time).
    func equivalenceFactor(for isotope: Isotope) -> Double {
        let factors: [Isotope: Double]
        switch self {
        case .carbonSteel:
            factors = [.ir192: 1.0, .se75: 1.0, .co60: 1.0, .yb169: 1.0]
        case .stainlessSteel:
            // SS denser / higher Z than carbon steel → ~1.15 steel-equivalence (typical 1.1–1.2).
            factors = [.ir192: 1.15, .se75: 1.15, .co60: 1.12, .yb169: 1.18]
        case .aluminum:
            factors = [.ir192: 0.47, .se75: 0.50, .co60: 0.27, .yb169: 0.60]
        case .copper:
            factors = [.ir192: 1.37, .se75: 1.40, .co60: 1.21, .yb169: 1.30]
        case .titanium:
            factors = [.ir192: 1.06, .se75: 1.05, .co60: 0.85, .yb169: 1.10]
        case .nickel:
            factors = [.ir192: 1.30, .se75: 1.30, .co60: 1.14, .yb169: 1.25]
        case .zinc:
            factors = [.ir192: 1.25, .se75: 1.25, .co60: 1.10, .yb169: 1.20]
        case .plastic:
            factors = [.ir192: 0.05, .se75: 0.05, .co60: 0.03, .yb169: 0.10]
        case .concrete:
            factors = [.ir192: 0.10, .se75: 0.10, .co60: 0.08, .yb169: 0.15]
        }
        return factors[isotope] ?? 1.0
    }
}
