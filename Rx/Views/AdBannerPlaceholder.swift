import SwiftUI

/// Minimal free-tier ad slot. Replace with a real ad SDK (e.g. AdMob) later if desired.
/// Shown only when the user is not subscribed (Remove Ads).
struct AdBannerPlaceholder: View {
    var body: some View {
        HStack {
            Image(systemName: "rectangle.badge.advertisement")
            Text("Ad placeholder")
                .font(.caption.weight(.medium))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .accessibilityLabel("Advertisement placeholder")
    }
}
