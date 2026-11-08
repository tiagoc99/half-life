# Half-Life

Half-Life is a Swift/SwiftUI iOS app for tracking isotope source decay and exploring radiographic film-exposure estimates.

## Features

- **Sources:** add isotope sources and view their calculated current activity.
- **Calculator:** estimate film-exposure time from source activity, distance, material thickness, film and correction settings; includes a countdown timer.
- **Settings:** choose units, film defaults and source-activity alerts.
- Supports **Ir-192, Se-75, Co-60 and Yb-169**.
- Includes a StoreKit 2 **Remove Ads subscription scaffold** and purchase-state settings. Real products require App Store Connect configuration; the ad placeholder is not shown, and no live ad SDK is included. This is not a claim that subscriptions gate the calculator.

## Open and run

1. Open `Rx.xcodeproj` in Xcode.
2. Select the **Rx** scheme and an iPhone simulator or connected iPhone destination.
3. Click **Run** (Product > Run).

**Xcode 27+ is recommended.** The current project was compiled with Xcode 27.2 for the iOS Simulator. Its deployment target is **iOS 18.5+**, not iOS 27.3+. A physical iPhone running iOS 27.3 was detected, but installation and launch on that phone were not verified.

For a physical iPhone, Xcode may require a development team/signing setup, device pairing and Trust, and Developer Mode. Simulator builds do not establish physical-device signing readiness.

## Important calculation limitations

**Not validated for operational radiography, exposure decisions or radiation safety.** Use requires matched source/film/technique calibration and qualified independent verification.

The retained Ir-192 output constant is **0.592 R·m²/(Ci·h)**. Its applicability remains unvalidated: an independent IAEA/manufacturer cross-check identified discrepancies, but these have not been reconciled against source encapsulation, certificate conventions and the film-exposure calibration. Other film, density, attenuation and material presets also remain provisional. Numerical regression checks are not physical calibration.

## Icon attribution

See [ICON-PROVENANCE.md](ICON-PROVENANCE.md) and [Apple sample-code license](LICENSES/Apple-Sample-Code.txt). The third-party notice does not assign a license to the entire app.
