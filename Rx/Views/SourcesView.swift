import SwiftUI

// Lists sources with decayed activity; respects radiationUnit and lowActivityWarning.
struct SourcesView: View {
    @ObservedObject var sourceManager: SourceManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingAddSource = false
    @State private var newSourceName = ""
    @State private var newSourceActivity = ""
    @State private var newSourceIsotope: Isotope = .ir192
    @State private var newSourceDate = Date()
    
    @AppStorage("radiationUnit") private var radiationUnit: String = "Ci"
    @AppStorage("lowActivityWarning") private var lowActivityWarning: Double = 50.0
    
    private static let bqPerCi: Double = 3.7e10
    
    private func displayActivity(_ activityCi: Double) -> String {
        if radiationUnit == "Bq" {
            return String(format: "%.3e %@", activityCi * Self.bqPerCi, radiationUnit)
        }
        return String(format: "%.2f %@", activityCi, radiationUnit)
    }
    
    /// Short label for isotope badge (e.g. Ir-192).
    private func isotopeShortLabel(_ isotopeName: String) -> String {
        switch Isotope(rawValue: isotopeName) {
        case .ir192: return "Ir-192"
        case .se75: return "Se-75"
        case .co60: return "Co-60"
        case .yb169: return "Yb-169"
        case .none: return String(isotopeName.prefix(6))
        }
    }
    
    /// SF Symbol for each isotope.
    private func isotopeSymbol(_ isotopeName: String) -> String {
        switch Isotope(rawValue: isotopeName) {
        case .ir192: return "atom"
        case .se75: return "circle.hexagongrid.fill"
        case .co60: return "bolt.circle.fill"
        case .yb169: return "sparkles"
        case .none: return "circle.fill"
        }
    }
    
    /// Accent color for isotope badge.
    private func isotopeColor(_ isotopeName: String) -> Color {
        switch Isotope(rawValue: isotopeName) {
        case .ir192: return .purple
        case .se75: return .teal
        case .co60: return .blue
        case .yb169: return .indigo
        case .none: return .secondary
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if sourceManager.sources.isEmpty {
                    ScrollView {
                    ContentUnavailableView {
                        Label("No Sources", systemImage: "archivebox")
                    } description: {
                        Text("Add an isotope source to start tracking decay and exposure.")
                    } actions: {
                        Button {
                            showingAddSource = true
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .frame(minHeight: 44)
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    }
                } else {
                    List {
                        Section("Active sources") {
                            ForEach(sourceManager.sources) { source in
                                sourceRow(for: source)
                            }
                            .onDelete(perform: sourceManager.deleteSource)
                        }
                        Section {
                            Button {
                                showingAddSource = true
                            } label: {
                                Label("Add Source", systemImage: "plus")
                                    .frame(minHeight: 44)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .listRowSpacing(8)
                }
            }
            .navigationTitle("Half-Life")
            .sheet(isPresented: $showingAddSource) {
                AddSourceView(
                    sourceManager: sourceManager,
                    newSourceName: $newSourceName,
                    newSourceActivity: $newSourceActivity,
                    newSourceIsotope: $newSourceIsotope,
                    newSourceDate: $newSourceDate
                )
                .onDisappear {
                    newSourceName = ""
                    newSourceActivity = ""
                }
            }
        }
    }
    
    @ViewBuilder
    private func sourceRow(for source: Source) -> some View {
        let currentActivity = sourceManager.calculateCurrentActivity(for: source)
        let remainingPercent = source.initialActivity > 0
            ? (currentActivity / source.initialActivity) * 100.0
            : 100.0
        let isLow = remainingPercent < lowActivityWarning
        let progress = min(max(remainingPercent / 100.0, 0), 1)
        
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        rowLayout {
            // Isotope badge: colored capsule with short label + SF Symbol
            VStack(spacing: 2) {
                Image(systemName: isotopeSymbol(source.isotope))
                    .font(.caption)
                Text(isotopeShortLabel(source.isotope))
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(minWidth: 56, minHeight: 44)
            .padding(.horizontal, 4)
            .background(isotopeColor(source.isotope), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.headline)
                Text("Current: \(displayActivity(currentActivity))")
                    .font(.caption)
                    .foregroundColor(isLow ? .orange : .green)
                ProgressView(value: progress)
                    .tint(isLow ? .orange : .green)
                if isLow {
                    Text("Low activity (< \(Int(lowActivityWarning))% of initial)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
