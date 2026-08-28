import Foundation
import StoreKit

/// "Kıble Bul Pro" aylık aboneliğini (StoreKit 2) yönetir.
///
/// Fiyat (9,90 TL/ay) kodda TANIMLANMAZ — App Store Connect'te oluşturacağınız
/// abonelik ürününün fiyatı orada belirlenir, StoreKit bunu otomatik çeker.
/// Bkz. README-TR.md → "App Store Connect'te abonelik oluşturma" bölümü.
///
/// Ürün kimliği (Product ID) App Store Connect'te birebir bu şekilde
/// oluşturulmalıdır: "com.miktat55.kiblebul.pro.monthly"
@MainActor
final class StoreManager: ObservableObject {

    static let proMonthlyProductID = "com.miktat55.kiblebul.pro.monthly"

    @Published private(set) var isProActive = false
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var isLoadingProducts = false
    @Published var lastErrorMessage: String?

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Ürünleri yükleme

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: [Self.proMonthlyProductID])
            monthlyProduct = products.first
        } catch {
            lastErrorMessage = "Abonelik bilgisi yüklenemedi. İnternet bağlantınızı kontrol edin."
        }
    }

    // MARK: - Satın alma

    func purchase() async {
        guard let product = monthlyProduct else {
            lastErrorMessage = "Abonelik şu anda kullanılamıyor, lütfen daha sonra tekrar deneyin."
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled:
                break
            case .pending:
                lastErrorMessage = "Satın alma onay bekliyor (ör. Ekran Zamanı izni)."
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = "Satın alma tamamlanamadı: \(error.localizedDescription)"
        }
    }

    /// Kullanıcı yeni bir cihaza geçtiğinde veya uygulamayı sildiyse
    /// aboneliğini geri yüklemesi için.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = "Satın almalar geri yüklenemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - Yetki (entitlement) kontrolü

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proMonthlyProductID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isProActive = active
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
}
