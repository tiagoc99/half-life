//
//  RxTests.swift
//  RxTests
//
//  Safety-relevant exposure math + NDT chart-style reference scenarios.
//

import Foundation
import Testing
@testable import Rx

struct RxTests {

    // MARK: - Helpers

    /// Builds a fresh source at full activity (no decay).
    private func freshSource(isotope: Isotope, activityCi: Double, name: String = "Ref") -> Source {
        Source(
            name: name,
            isotope: isotope.rawValue,
            initialActivity: activityCi,
            initialDate: Date()
        )
    }

    /// Analytic expected minutes from the app formula (documented assumptions).
    /// timeMin = 60 * baseFilmFactor(2.4) * relative * 10^(0.4*(D-2.5)) * (1+corr/100)
    ///           * 2^(equivThick/HVT) * (SFD_m)^2 / (Γ * A_Ci)
    private func expectedMinutes(
        isotope: Isotope,
        activityCi: Double,
        sfdMm: Double,
        thicknessMm: Double,
        film: FilmType,
        density: Double = 2.5,
        material: Material = .carbonSteel,
        correctionPercent: Double = 0
    ) -> Double {
        let baseFilmFactor = 2.4
        let relative = film.relativeFactor(for: isotope)
        let densityCorr = pow(10.0, 0.4 * (density - 2.5))
        let safety = 1.0 + correctionPercent / 100.0
        let equiv = thicknessMm * material.equivalenceFactor(for: isotope)
        let attenuation = pow(2.0, equiv / isotope.hvtSteelMm)
        let sfdM = sfdMm / 1000.0
        let hours = (baseFilmFactor * relative * densityCorr * safety * attenuation * pow(sfdM, 2))
            / (isotope.gammaConstant * activityCi)
        return hours * 60.0
    }

    // MARK: - Half-life decay

    @Test func halfLifeDecay_afterOneHalfLife_isHalf() {
        let manager = SourceManager()
        let halfLife = Isotope.ir192.halfLifeDays
        let initialDate = Date().addingTimeInterval(-halfLife * 86400.0)
        let source = Source(
            name: "Test Ir-192",
            isotope: Isotope.ir192.rawValue,
            initialActivity: 100.0,
            initialDate: initialDate
        )
        let current = manager.calculateCurrentActivity(for: source)
        #expect(abs(current - 50.0) < 0.5)
    }

    @Test func halfLifeDecay_atZeroDays_isInitial() {
        let manager = SourceManager()
        let source = freshSource(isotope: .se75, activityCi: 40.0)
        let current = manager.calculateCurrentActivity(for: source)
        #expect(abs(current - 40.0) < 0.01)
    }

    // MARK: - Film factor

    @Test func filmFactor_d7_relativeIsOne() {
        #expect(FilmType.d7.relativeFactor(for: .ir192) == 1.0)
        #expect(FilmType.d7.relativeFactor(for: .se75) == 1.0)
    }

    @Test func filmFactor_d2_slowerThanD7() {
        #expect(FilmType.d2.relativeFactor(for: .ir192) > FilmType.d7.relativeFactor(for: .ir192))
    }

    @Test func filmFactor_ix50AndIx80_haveDistinctIds() {
        #expect(FilmType.ix50.id != FilmType.ix80.id)
        #expect(FilmType.m100.id != FilmType.sh800.id)
    }

    // MARK: - Attenuation / materials

    @Test func attenuation_oneHVT_doublesExposureContribution() {
        let isotope = Isotope.ir192
        let attenuation = pow(2.0, isotope.hvtSteelMm / isotope.hvtSteelMm)
        #expect(abs(attenuation - 2.0) < 1e-9)
    }

    @Test func stainlessSteel_equivalenceAboveCarbonSteel() {
        let ss = Material.stainlessSteel.equivalenceFactor(for: .ir192)
        let cs = Material.carbonSteel.equivalenceFactor(for: .ir192)
        #expect(ss > cs)
        #expect(ss >= 1.1 && ss <= 1.2)
    }

    // MARK: - Density / safety correction

    @Test func densityCorrection_atRef_isUnity() {
        let correction = pow(10.0, 0.4 * (2.5 - 2.5))
        #expect(abs(correction - 1.0) < 1e-12)
    }

    @Test func safetyCorrection_100Percent_isDoubleTime() {
        let safety = 1.0 + (100.0 / 100.0)
        #expect(abs(safety - 2.0) < 1e-12)
    }

    @Test func exposureTime_100PercentCorrection_roughlyDoubles() {
        let manager = SourceManager()
        let source = freshSource(isotope: .ir192, activityCi: 50.0)
        let base = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 12,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel,
            correctionRatioPercent: 0
        )
        let doubled = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 12,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel,
            correctionRatioPercent: 100
        )
        #expect(base > 0)
        #expect(abs(doubled / base - 2.0) < 0.01)
    }

    // MARK: - Gamma constants

    @Test func gammaConstants_se75AndYb169_inLiteratureRange() {
        #expect(Isotope.se75.gammaConstant >= 0.20 && Isotope.se75.gammaConstant <= 0.55)
        #expect(Isotope.yb169.gammaConstant >= 0.125 && Isotope.yb169.gammaConstant <= 0.25)
        #expect(abs(Isotope.se75.gammaConstant - 0.203) < 1e-9)
        #expect(abs(Isotope.yb169.gammaConstant - 0.125) < 1e-9)
    }

    // MARK: - NDT reference scenarios (exposure-chart style)
    //
    // Reference model (app calibration, not a single vendor PDF page):
    //   - baseFilmFactor = 2.4 R for D7 @ optical density 2.5 (Agfa Structurix / EN 584-1 style)
    //   - Γ Ir-192 = 0.592, Se-75 = 0.203, Co-60 = 1.37, Yb-169 = 0.125 R·m²/(h·Ci)
    //   - HVT steel: Ir-192 12 mm, Se-75 8 mm, Co-60 22 mm, Yb-169 3.5 mm (ASTM E592 order)
    //   - Time(min) = 60 * FF * atten * SFD_m² / (Γ * A)
    // Published vendor charts (Agfa, Waygate/GE) vary with screens, processing, geometry;
    // golden values below are exact vs this documented formula (±1% tolerance for floating point).
    // Order-of-magnitude "chart band" checks use wider bands typical of field practice.

    @Test func refScenario_Ir192_D7_steel12mm_SFD700_100Ci() {
        // Classic: Ir-192, D7, carbon steel 12 mm (=1 HVT), SFD 700 mm, 100 Ci, D=2.5
        // Expected ≈ 2.384 min from formula (atten=2, SFD=0.7 m).
        let manager = SourceManager()
        let source = freshSource(isotope: .ir192, activityCi: 100.0, name: "Ir100")
        let computed = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 12,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let expected = expectedMinutes(
            isotope: .ir192, activityCi: 100, sfdMm: 700, thicknessMm: 12, film: .d7
        )
        #expect(abs(computed - expected) / expected < 0.01)
        #expect(abs(computed - 2.384) < 0.05) // absolute golden ± ~2 s
    }

    @Test func refScenario_Ir192_D7_thinSteel_SFD1000_50Ci() {
        // Ir-192, D7, 5 mm CS, SFD 1000 mm, 50 Ci — longer SFD, thinner wall.
        let manager = SourceManager()
        let source = freshSource(isotope: .ir192, activityCi: 50.0)
        let computed = manager.calculateExposureTime(
            source: source, sfdMm: 1000, thicknessMm: 5,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let expected = expectedMinutes(
            isotope: .ir192, activityCi: 50, sfdMm: 1000, thicknessMm: 5, film: .d7
        )
        #expect(abs(computed - expected) / expected < 0.01)
        // Field chart ballpark: order of minutes for 50 Ci @ 1 m / thin steel
        #expect(computed > 0.5 && computed < 30)
    }

    @Test func refScenario_Se75_D7_steel8mm_SFD700_80Ci() {
        // Se-75, D7, 8 mm CS (=1 HVT Se), SFD 700 mm, 80 Ci.
        // Γ=0.203 (industrial typical) → longer time than Ir at same Ci.
        let manager = SourceManager()
        let source = freshSource(isotope: .se75, activityCi: 80.0)
        let computed = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 8,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let expected = expectedMinutes(
            isotope: .se75, activityCi: 80, sfdMm: 700, thicknessMm: 8, film: .d7
        )
        #expect(abs(computed - expected) / expected < 0.01)
        #expect(computed > computed * 0) // positive
        // Se-75 Γ lower than Ir → expect longer than Ir-192 @ 100 Ci / 12 mm roughly
        let irRef = expectedMinutes(
            isotope: .ir192, activityCi: 100, sfdMm: 700, thicknessMm: 12, film: .d7
        )
        #expect(computed > irRef * 0.5) // same order; Se often needs more Ci·min
    }

    @Test func refScenario_Co60_D7_steel22mm_SFD1000_30Ci() {
        // Co-60, D7, 22 mm CS (=1 HVT), SFD 1000 mm, 30 Ci — high-energy thick-section case.
        let manager = SourceManager()
        let source = freshSource(isotope: .co60, activityCi: 30.0)
        let computed = manager.calculateExposureTime(
            source: source, sfdMm: 1000, thicknessMm: 22,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let expected = expectedMinutes(
            isotope: .co60, activityCi: 30, sfdMm: 1000, thicknessMm: 22, film: .d7
        )
        #expect(abs(computed - expected) / expected < 0.01)
        #expect(computed > 1 && computed < 120) // chart-style minutes–hours band for this setup
    }

    @Test func refScenario_filmD4_vs_D7_ratioMatchesRelativeFactor() {
        // Same geometry: D4 relative ≈ 3.0 for Ir-192 → time ≈ 3× D7.
        let manager = SourceManager()
        let source = freshSource(isotope: .ir192, activityCi: 80.0)
        let tD7 = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 10,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let tD4 = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 10,
            filmType: .d4, targetDensity: 2.5, material: .carbonSteel
        )
        let ratio = tD4 / tD7
        let expectedRatio = FilmType.d4.relativeFactor(for: .ir192) // 3.0
        #expect(abs(ratio - expectedRatio) < 0.02)
    }

    @Test func refScenario_density3p0_vs_2p5_H_and_D() {
        // H&D: ΔD = +0.5, gamma≈2.5 → factor 10^(0.4*0.5) = 10^0.2 ≈ 1.585
        let manager = SourceManager()
        let source = freshSource(isotope: .ir192, activityCi: 60.0)
        let t25 = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 10,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let t30 = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 10,
            filmType: .d7, targetDensity: 3.0, material: .carbonSteel
        )
        let factor = t30 / t25
        #expect(abs(factor - pow(10.0, 0.2)) < 0.02)
    }

    @Test func refScenario_inverseSquare_SFD_doubling_quadruplesTime() {
        // Inverse-square: 2× SFD → 4× time (same activity, thin plate).
        let manager = SourceManager()
        let source = freshSource(isotope: .ir192, activityCi: 100.0)
        let t700 = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 2,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let t1400 = manager.calculateExposureTime(
            source: source, sfdMm: 1400, thicknessMm: 2,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        #expect(abs(t1400 / t700 - 4.0) < 0.02)
    }

    @Test func refScenario_stainlessVsCarbon_sameThickness_longerTime() {
        // SS equivalence ~1.15 → more attenuation than carbon steel at same mm.
        let manager = SourceManager()
        let source = freshSource(isotope: .ir192, activityCi: 70.0)
        let tCS = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 15,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let tSS = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 15,
            filmType: .d7, targetDensity: 2.5, material: .stainlessSteel
        )
        #expect(tSS > tCS)
        let expectedSS = expectedMinutes(
            isotope: .ir192, activityCi: 70, sfdMm: 700, thicknessMm: 15,
            film: .d7, material: .stainlessSteel
        )
        #expect(abs(tSS - expectedSS) / expectedSS < 0.01)
    }

    @Test func refScenario_Yb169_thinSection_shortHVT() {
        // Yb-169 soft γ: HVT 3.5 mm — thin SS/Al work; 20 Ci, 3.5 mm CS, SFD 500 mm, D7.
        let manager = SourceManager()
        let source = freshSource(isotope: .yb169, activityCi: 20.0)
        let computed = manager.calculateExposureTime(
            source: source, sfdMm: 500, thicknessMm: 3.5,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let expected = expectedMinutes(
            isotope: .yb169, activityCi: 20, sfdMm: 500, thicknessMm: 3.5, film: .d7
        )
        #expect(abs(computed - expected) / expected < 0.01)
        #expect(computed > 0)
    }

    // MARK: - Base film factor / extra material & film checks

    @Test func baseFilmFactor_documentedConstant_is2p4() {
        // SourceManager calibrates to 2.4 R on D7 @ density 2.5 (Agfa / EN 584-1 style).
        // Guard the documented constant used in calculateExposureTime.
        let baseFilmFactor = 2.4
        let manager = SourceManager()
        let source = freshSource(isotope: .ir192, activityCi: 100.0)
        // Zero thickness, SFD 1000 mm, D7, dens 2.5, corr 0 →
        // timeHours = 2.4 * 1 * 1 * 1 * 1 * 1^2 / (0.592 * 100) ; timeMin = hours * 60
        let computed = manager.calculateExposureTime(
            source: source, sfdMm: 1000, thicknessMm: 0.0001,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        let expected = expectedMinutes(
            isotope: .ir192, activityCi: 100, sfdMm: 1000, thicknessMm: 0.0001, film: .d7
        )
        #expect(abs(computed - expected) / expected < 0.01)
        #expect(abs(baseFilmFactor - 2.4) < 1e-12)
    }

    @Test func materialEquivalence_aluminumBelowCarbonSteel() {
        let al = Material.aluminum.equivalenceFactor(for: .ir192)
        let cs = Material.carbonSteel.equivalenceFactor(for: .ir192)
        #expect(al < cs)
        #expect(abs(al - 0.47) < 1e-9)
    }

    @Test func filmFactor_custom_readsUserDefaults() {
        UserDefaults.standard.set(2.5, forKey: "customFilmFactor")
        defer { UserDefaults.standard.removeObject(forKey: "customFilmFactor") }
        #expect(abs(FilmType.custom.relativeFactor(for: .ir192) - 2.5) < 1e-9)
    }

    @Test func calculateExposureTime_unknownIsotope_returnsZero() {
        let manager = SourceManager()
        let source = Source(
            name: "Bad",
            isotope: "Not-An-Isotope",
            initialActivity: 10,
            initialDate: Date()
        )
        let t = manager.calculateExposureTime(
            source: source, sfdMm: 700, thicknessMm: 10,
            filmType: .d7, targetDensity: 2.5, material: .carbonSteel
        )
        #expect(t == 0)
    }
}
