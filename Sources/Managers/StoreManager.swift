import Foundation
import StoreKit

/// "Kıble Bul Pro" aboneliğini (StoreKit 2) yönetir.
///
/// İki ürün sunulur — aylık ve yıllık (yıllık, aylığa göre indirimli). Her
/// ikisi de App Store Connect'te aynı abonelik grubunda ("Kıble Pro")
/// tanımlıdır; kullanıcı ikisinden birine abone olabilir, ikisi de aynı
/// "reklamları kaldır" yetkisini (entitlement) verir.
///
/// Fiyatlar kodda TANIMLANMAZ — App Store Connect'te oluşturacağınız
/// abonelik ürünlerinin fiyatı orada belirlenir, StoreKit bunu otomatik çeker.
/// Bkz. README-TR.md → "App Store Connect'te abonelik oluşturma" bölümü.
///
/// Ürün kimlikleri (Product ID) App Store Connect'te birebir bu şekilde
/// oluşturulmalıdır:
///   - "com.miktat55.kiblebul.pro.monthly"
///   - "com.miktat55.kiblebul.pro.yearly"
@MainActor
final class StoreManager: ObservableObject {

    static let proMonthlyProductID = "com.miktat55.kiblebul.pro.monthly"
    static let proYearlyProductID = "com.miktat55.kiblebul.pro.yearly"

    private static var allProductIDs: [String] { [proMonthlyProductID, proYearlyProductID] }

    @Published private(set) var isProActive = false
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var isLoadingProducts = false
    @Published var lastErrorMessage: String?

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
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
            let products = try await Product.products(for: Self.allProductIDs)
            monthlyProduct = products.first(where: { $0.id == Self.proMonthlyProductID })
            yearlyProduct = products.first(where: { $0.id == Self.proYearlyProductID })
        } catch {
            lastErrorMessage = NSLocalizedString(
                "settings.pro.price_unavailable",
                comment: "Abonelik bilgisi yüklenemedi hata mesajı"
            )
        }
    }

    // MARK: - Satın alma

    /// Belirtilen ürünü (aylık veya yıllık) satın alır.
    func purchase(_ product: Product) async {
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
                lastErrorMessage = NSLocalizedString(
                    "settings.pro.purchase_pending",
                    comment: "Satın alma onay bekliyor hata mesajı"
                )
            @unknown default:
                break
            }
        } catch {
            let format = NSLocalizedString(
                "settings.pro.purchase_failed",
                comment: "Satın alma tamamlanamadı hata mesajı, %@ = hata açıklaması"
            )
            lastErrorMessage = String(format: format, error.localizedDescription)
        }
    }

    /// Geriye dönük uyumluluk için: parametresiz çağrı aylık ürünü satın alır.
    func purchase() async {
        guard let product = monthlyProduct else {
            lastErrorMessage = NSLocalizedString(
                "settings.pro.unavailable",
                comment: "Abonelik şu anda kullanılamıyor hata mesajı"
            )
            return
        }
        await purchase(product)
    }

    /// Kullanıcı yeni bir cihaza geçtiğinde veya uygulamayı sildiyse
    /// aboneliğini geri yüklemesi için.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            let format = NSLocalizedString(
                "settings.pro.restore_failed",
                comment: "Satın almalar geri yüklenemedi hata mesajı, %@ = hata açıklaması"
            )
            lastErrorMessage = String(format: format, error.localizedDescription)
        }
    }

    // MARK: - Yetki (entitlement) kontrolü

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.allProductIDs.contains(transaction.productID),
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
