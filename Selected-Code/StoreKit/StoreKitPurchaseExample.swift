import Foundation
import StoreKit

/// Curated StoreKit 2 example derived from the production purchase
/// architecture used by True Lock Tuner.
///
/// Demonstrates:
/// - product loading
/// - async/await purchase flows
/// - StoreKit transaction verification
/// - entitlement refresh
/// - transaction update monitoring
/// - purchase restoration
/// - UI-facing state isolated to the MainActor
///
/// Product identifiers, analytics, logging, and application-specific
/// entitlement management are intentionally omitted.
@MainActor
final class StoreKitPurchaseExample: ObservableObject {

    // MARK: - Published State

    @Published private(set) var product: Product?
    @Published private(set) var hasProAccess = false
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var purchaseInProgress = false

    @Published var statusMessage: String?
    @Published var errorMessage: String?

    // MARK: - Configuration

    /// Placeholder used only for this public example.
    private let productID = "com.example.app.pro"

    // MARK: - Transaction Monitoring

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        startTransactionListener()

        Task {
            await refreshEntitlementStatus()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProduct() async {
        isLoadingProduct = true
        errorMessage = nil

        defer {
            isLoadingProduct = false
        }

        do {
            let products = try await Product.products(
                for: [productID]
            )

            product = products.first

            if product == nil {
                errorMessage = "The product is currently unavailable."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase

    func purchasePro() async {
        errorMessage = nil
        statusMessage = nil

        if product == nil {
            await loadProduct()
        }

        guard let product else {
            errorMessage = "Unable to load the Pro upgrade."
            return
        }

        purchaseInProgress = true

        defer {
            purchaseInProgress = false
        }

        do {
            let result = try await product.purchase()

            switch result {

            case .success(let verification):
                let transaction = try checkVerified(
                    verification
                )

                guard transaction.productID == productID else {
                    await transaction.finish()
                    return
                }

                hasProAccess = true

                await transaction.finish()

                statusMessage = "Pro unlocked."

            case .pending:
                statusMessage =
                    "Purchase is waiting for approval."

            case .userCancelled:
                break

            @unknown default:
                break
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        errorMessage = nil
        statusMessage = nil

        do {
            try await AppStore.sync()

            await refreshEntitlementStatus()

            statusMessage = hasProAccess
                ? "Purchases restored."
                : "No previous Pro purchase was found."

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Entitlements

    func refreshEntitlementStatus() async {
        var unlocked = false

        for await result in Transaction.currentEntitlements {

            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.productID == productID {
                unlocked = true
                break
            }
        }

        hasProAccess = unlocked
    }

    // MARK: - Transaction Updates

    private func startTransactionListener() {
        let expectedProductID = productID

        transactionUpdatesTask = Task.detached {
            for await result in Transaction.updates {

                guard
                    case .verified(let transaction) = result
                else {
                    continue
                }

                guard transaction.productID == expectedProductID else {
                    await transaction.finish()
                    continue
                }

                await MainActor.run {
                    self.hasProAccess = true
                }

                await transaction.finish()
            }
        }
    }

    // MARK: - Verification

    private nonisolated func checkVerified<T>(
        _ result: VerificationResult<T>
    ) throws -> T {

        switch result {

        case .verified(let value):
            return value

        case .unverified:
            throw StoreKitError.failedVerification
        }
    }
}


// MARK: - Showcase Error

enum StoreKitError: Error {
    case failedVerification
}
