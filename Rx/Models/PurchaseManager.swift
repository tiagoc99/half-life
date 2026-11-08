// StoreKit 2 helper for the Remove Ads auto-renewable subscription.
// The product id is com.tiagocosta.HalfLife.removeAds. It has to match the product created in App Store Connect. Configuration.storekit can supply the same id when the Xcode scheme selects that StoreKit configuration.
// init starts listenForTransactions, which watches Transaction.updates, and a second task that loads products and then refreshes entitlements. deinit cancels the updates task.
// loadProducts requests that product id and sorts the results by display name. A thrown error is copied into lastErrorMessage.
// refreshEntitlements sets isSubscribed. The flag becomes true only when Transaction.currentEntitlements yields a verified transaction whose productID equals removeAdsProductID. Unverified results are skipped. With no matching entitlement the flag stays false.
// purchaseRemoveAds prefers the loaded product with that id. If the id is absent and some other product was returned, it uses the first product. An empty list triggers one reload, and a still-empty list sets an error string.
// buy wraps product.purchase() with purchaseInProgress. A verified success calls transaction.finish() and refreshes entitlements. Cancellation leaves the message as it was. A pending purchase sets a pending-approval message.
// restorePurchases calls AppStore.sync() and then refreshes entitlements. Later verified updates from listenForTransactions are finished and the flag is refreshed again.
// SettingsView reads isSubscribed, purchaseInProgress, products, and lastErrorMessage. Sources and Calculator do not read the subscription flag. The manual App Store Connect steps are in the comment on the class below.

import Foundation
import StoreKit

/// StoreKit 2 manager for the free + Remove Ads subscription.
///
/// Product ID (must match App Store Connect exactly):
///   `com.tiagocosta.HalfLife.removeAds` — auto-renewable subscription
///
/// MARK: - Manual steps for Tiago (App Store Connect / Apple Developer)
/// 1. Enroll in the Apple Developer Program (paid membership).
/// 2. Sign Paid Applications Agreement + banking/tax in App Store Connect → Agreements, Tax, and Banking.
/// 3. In App Store Connect → this app → Monetization → Subscriptions:
///    - Create a Subscription Group (e.g. "Half-Life Premium").
///    - Add auto-renewable product with Product ID exactly: com.tiagocosta.HalfLife.removeAds
///    - Set price, duration (e.g. monthly), localizations, review screenshot/notes.
/// 4. Attach the subscription to the app version for review when ready to ship.
/// 5. For local Xcode testing: use Configuration.storekit (StoreKit Configuration) —
///    Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration.
/// 6. Do NOT rely on this scaffold alone for production; test with Sandbox Apple ID.
/// This code does NOT create real ASC products — Tiago must create them manually.
// Main-actor observable object. The published properties drive the Settings purchase section.
@MainActor
final class PurchaseManager: ObservableObject {
    static let removeAdsProductID = "com.tiagocosta.HalfLife.removeAds"
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var purchaseInProgress: Bool = false
    @Published var lastErrorMessage: String?
    
    private var updatesTask: Task<Void, Never>?
    
    // Begins listening for transactions, then loads the product and the current entitlement.
    init() {
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }
    
    // Stops the transaction-update listener.
    deinit {
        updatesTask?.cancel()
    }
    
    // Fetches the Remove Ads product and sorts by localized display name.
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [Self.removeAdsProductID])
            products = storeProducts.sorted { $0.displayName < $1.displayName }
        } catch {
            lastErrorMessage = "Could not load products: \(error.localizedDescription)"
        }
    }
    
    // Sets isSubscribed from a verified current entitlement for this product id.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.removeAdsProductID {
                active = true
                break
            }
        }
        isSubscribed = active
    }
    
    // Buys the Remove Ads product, reloading the product list once when it is empty.
    func purchaseRemoveAds() async {
        guard let product = products.first(where: { $0.id == Self.removeAdsProductID })
                ?? products.first else {
            // Retry load once if empty (StoreKit config / network).
            await loadProducts()
            guard let product = products.first(where: { $0.id == Self.removeAdsProductID })
                    ?? products.first else {
                lastErrorMessage = "Remove Ads product unavailable. Check StoreKit config / ASC."
                return
            }
            await buy(product)
            return
        }
        await buy(product)
    }
    
    // Presents the StoreKit purchase and finishes a verified transaction.
    private func buy(_ product: Product) async {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = "Purchase could not be verified."
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                lastErrorMessage = "Purchase pending approval."
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
    
    // Syncs App Store purchases for this Apple ID, then rereads entitlements.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
    
    // Finishes later verified transactions, such as a renewal, and refreshes isSubscribed.
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }
}
