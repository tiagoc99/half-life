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
@MainActor
final class PurchaseManager: ObservableObject {
    static let removeAdsProductID = "com.tiagocosta.HalfLife.removeAds"
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var purchaseInProgress: Bool = false
    @Published var lastErrorMessage: String?
    
    private var updatesTask: Task<Void, Never>?
    
    init() {
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [Self.removeAdsProductID])
            products = storeProducts.sorted { $0.displayName < $1.displayName }
        } catch {
            lastErrorMessage = "Could not load products: \(error.localizedDescription)"
        }
    }
    
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
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
    
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }
}
