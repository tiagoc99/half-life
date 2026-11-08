// Settings tab. Each control is an AppStorage property, so SwiftUI writes it to UserDefaults and the other screens read the same key.
// distanceUnit and thicknessUnit store mm or in, default mm. radiationUnit stores Ci or Bq, default Ci. This screen stores the choice. The calculator converts inches to millimeters, and the activity fields convert becquerels to curies.
// defaultMaterial is a Material raw value, default Carbon Steel. correctionRatio is the exposure safety margin in percent, from 0 to 100 in steps of 5, default 0. At 100 the exposure math multiplies time by 2. lowActivityWarning is the Sources threshold in percent of the original activity, from 20 to 80 in steps of 10, default 50.
// filmCategory is Type D films, Type IX films, Type K films, or Custom. customFilmFactor is the absolute custom exposure in roentgens, default 1.0, and the field is shown when the category is Custom. Built-in film factors live in FilmType.
// Reset All writes those preference defaults again. Saved sources stay under the separate sources key.
// The Remove Ads section uses the PurchaseManager from ContentView. A true isSubscribed shows the subscribed label. Otherwise the button calls purchaseRemoveAds. The title includes the StoreKit display price per month when that product is loaded, and is Remove Ads when it is not. Restore calls restorePurchases. A lastErrorMessage is shown when one is present.

import SwiftUI

// Settings: units, defaults, alerts — persisted via AppStorage / UserDefaults.
struct SettingsView: View {
    @AppStorage("distanceUnit") private var distanceUnit: String = "mm"
    @AppStorage("radiationUnit") private var radiationUnit: String = "Ci"
    @AppStorage("thicknessUnit") private var thicknessUnit: String = "mm"
    @AppStorage("defaultMaterial") private var defaultMaterial: String = "Carbon Steel"
    @AppStorage("correctionRatio") private var correctionRatio: Double = 0.0
    @AppStorage("lowActivityWarning") private var lowActivityWarning: Double = 50.0
    @AppStorage("customFilmFactor") private var customFilmFactor: Double = 1.0
    @AppStorage("filmCategory") private var filmCategory: String = "Type D films"
    
    @EnvironmentObject private var purchaseManager: PurchaseManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Distance", selection: $distanceUnit) {
                        Text("mm").tag("mm")
                        Text("in").tag("in")
                    }
                    Picker("Radiation", selection: $radiationUnit) {
                        Text("Ci").tag("Ci")
                        Text("Bq").tag("Bq")
                    }
                    Picker("Thickness", selection: $thicknessUnit) {
                        Text("mm").tag("mm")
                        Text("in").tag("in")
                    }
                }
                
                Section("Defaults") {
                    Picker("Default Material", selection: $defaultMaterial) {
                        ForEach(Material.allCases, id: \.rawValue) { mat in
                            Text(mat.rawValue).tag(mat.rawValue)
                        }
                    }
                    Text("Standard material loaded in the Calculator (e.g. Carbon Steel for common welds).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $correctionRatio, in: 0...100, step: 5) {
                        Text("Correction Ratio: \(Int(correctionRatio))%")
                    }
                    // Aligned with math: safetyCorrection = 1 + ratio/100 → 100% ≈ 2× exposure time.
                    Text("Safety margin on exposure time (0% = none; 100% ≈ twice as long). Independent of H&D density correction.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Film Type") {
                    Picker("Film Type", selection: $filmCategory) {
                        Text("Type D films").tag("Type D films")
                        Text("Type IX films").tag("Type IX films")
                        Text("Type K films").tag("Type K films")
                        Text("Custom").tag("Custom")
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if filmCategory == "Custom" {
                        TextField("Custom exposure (R)", value: $customFilmFactor, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    Text("Custom exposure is an absolute value in roentgens (R), before density and safety corrections. Built-in film factors are unchanged.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Remove Ads") {
                    if purchaseManager.isSubscribed {
                        Label("Subscribed — ads removed", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Remove Ads subscription. Purchase availability depends on the App Store configuration.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            Task { await purchaseManager.purchaseRemoveAds() }
                        } label: {
                            if purchaseManager.purchaseInProgress {
                                ProgressView()
                            } else {
                                Text(removeAdsButtonTitle)
                            }
                        }
                        .frame(minHeight: 44)
                        .disabled(purchaseManager.purchaseInProgress)
                    }
                    Button("Restore Purchases") {
                        Task { await purchaseManager.restorePurchases() }
                    }
                    .frame(minHeight: 44)
                    if let err = purchaseManager.lastErrorMessage {
                        Text(err)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Source Alerts") {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("Low Activity Warning")
                                .fixedSize(horizontal: true, vertical: true)
                            Spacer(minLength: 16)
                            Text("\(Int(lowActivityWarning))%")
                                .fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Low Activity Warning")
                            Text("\(Int(lowActivityWarning))%")
                        }
                    }
                    Slider(value: $lowActivityWarning, in: 20...80, step: 10)
                    Text("Alert if current activity < \(Int(lowActivityWarning))% of initial.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset All") {
                        distanceUnit = "mm"
                        radiationUnit = "Ci"
                        thicknessUnit = "mm"
                        defaultMaterial = "Carbon Steel"
                        correctionRatio = 0.0
                        lowActivityWarning = 50.0
                        customFilmFactor = 1.0
                        filmCategory = "Type D films"
                    }
                }
            }
        }
    }
    
    // Purchase button title, including the loaded product's display price when StoreKit has returned it.
    private var removeAdsButtonTitle: String {
        if let product = purchaseManager.products.first(where: { $0.id == PurchaseManager.removeAdsProductID }) {
            return "Remove Ads — \(product.displayPrice)/mo"
        }
        return "Remove Ads"
    }
}
