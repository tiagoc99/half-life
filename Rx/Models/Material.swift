// Provisional steel-equivalence presets used to turn a typed thickness into equivalent carbon steel.
// equivalenceFactor(for:) returns a unitless multiplier for one material and one isotope.
// Equivalent steel thickness, in millimeters, is the entered thickness times this factor. Carbon steel is 1.0 for every isotope.
// A factor below 1 treats the material as easier to penetrate than the same thickness of carbon steel, so the calculated time is shorter. A factor above 1 lengthens the time.
// The tables differ by isotope because each preset is for that gamma energy. Composition, density, spectrum, and technique still have to match a real calibration. A missing pair falls back to 1.0.
// Ir-192: stainless 1.15, aluminum 0.47, copper 1.37, titanium 1.06, nickel 1.30, zinc 1.25, plastic 0.05, concrete 0.10.
// Se-75: stainless 1.15, aluminum 0.50, copper 1.40, titanium 1.05, nickel 1.30, zinc 1.25, plastic 0.05, concrete 0.10.
// Co-60: stainless 1.12, aluminum 0.27, copper 1.21, titanium 0.85, nickel 1.14, zinc 1.10, plastic 0.03, concrete 0.08.
// Yb-169: stainless 1.18, aluminum 0.60, copper 1.30, titanium 1.10, nickel 1.25, zinc 1.20, plastic 0.10, concrete 0.15.

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
    // Looks up the steel-equivalence factor for this material and the source isotope.
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
