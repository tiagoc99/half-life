import SwiftUI

// App entry tabs: Sources, Calculator, Settings.
// Keep Liquid Glass: do NOT apply .glassEffect() to the full TabView.
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
