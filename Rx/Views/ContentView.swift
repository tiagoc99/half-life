// Root screen after launch. One SourceManager is shared by the Sources and Calculator tabs. Settings is the third tab.
// PurchaseManager is created here and injected with environmentObject, so SettingsView can load, buy, and restore the Remove Ads subscription.
// The container is an ordinary TabView. The comments in this file keep Liquid Glass off that full tab view on every OS version the project supports.

import SwiftUI

// App entry tabs: Sources, Calculator, Settings.
// Keep Liquid Glass: do NOT apply .glassEffect() to the full TabView.
// The state objects live with this view. The preview at the bottom builds another ContentView with its own managers.
struct ContentView: View {
    @StateObject private var sourceManager = SourceManager()
    @StateObject private var purchaseManager = PurchaseManager()
    
    var body: some View {
        VStack(spacing: 0) {
            tabRoot
        }
        .environmentObject(purchaseManager)
    }
    
    @ViewBuilder
    private var tabRoot: some View {
        // Same TabView on all supported OS versions — no full-TabView glassEffect.
        TabView {
            SourcesView(sourceManager: sourceManager)
                .tabItem { Label("Sources", systemImage: "archivebox") }
            
            CalculatorView(sourceManager: sourceManager)
                .tabItem { Label("Calculator", systemImage: "timer") }
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

#Preview {
    ContentView()
}
