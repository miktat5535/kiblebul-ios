import Foundation

/// Ücretsiz (abone olmayan) kullanıcılar için günlük kullanım hakkı sayacı.
///
/// Kıble Bul'un ücretsiz sürümünde kullanıcı; Pusula (kıble), Namaz
/// Vakitleri, Kamera (AR) ve Camiler sekmelerini GÜNDE TOPLAM
/// `dailyFreeLimit` kez kullanabilir — dördü de aynı ortak günlük havuzu
/// paylaşır. Hak, her takvim günü (cihaz saat dilimine göre) otomatik
/// sıfırlanır. Kıble Pro aboneliği aktifken bu sınır hiç uygulanmaz (bkz.
/// `StoreManager.isProActive` — çağıran taraf bu kontrolü yapar).
///
/// Tasarım notu: Bu, App Store'dan satın alınan bir "tüketilebilir"
/// (consumable) ürün değildir; yalnızca yazılımsal bir günlük kota
/// sayacıdır. Kullanıcıya ne sunulduğu (günde 3 ücretsiz kullanım, sonrası
/// abonelik) satın alma teklifinde (`ProSubscriptionOfferView`) açıkça
/// belirtilir — App Store İnceleme Kılavuzu 3.1.2'nin aradığı şeffaflık bu
/// şekilde sağlanır.
@MainActor
final class DailyUsageLimiter: ObservableObject {

    /// Ücretsiz kullanıcının günlük toplam kullanım hakkı.
    static let dailyFreeLimit = 3

    private static let usageCountKey = "dailyUsage.count"
    private static let usageDateKey = "dailyUsage.date"

    /// Bugün için kalan hak sayısı (0...dailyFreeLimit).
    @Published private(set) var remainingUses: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Başlangıç değeri geçici; gerçek değer aşağıdaki resetIfNewDay()
        // içinde (gerekirse sıfırlayarak) hesaplanır.
        self.remainingUses = Self.dailyFreeLimit
        resetIfNewDay()
    }

    var hasRemainingUses: Bool { remainingUses > 0 }

    /// Cihazın takvim günü son kayıttan beri değiştiyse sayaç sıfırlanır.
    /// Uygulama gece yarısını geçerken açık kalsa da, ilgili ekrana her
    /// girişte bu çağrıldığı için kullanıcı yeni gününün hakkını hemen görür.
    func resetIfNewDay() {
        let today = Self.todayKey()
        let storedDate = defaults.string(forKey: Self.usageDateKey)
        if storedDate != today {
            defaults.set(today, forKey: Self.usageDateKey)
            defaults.set(0, forKey: Self.usageCountKey)
        }
        let used = defaults.integer(forKey: Self.usageCountKey)
        remainingUses = max(0, Self.dailyFreeLimit - used)
    }

    /// Ortak havuzdan bir kullanım hakkı düşürmeye çalışır.
    ///
    /// - Returns: Hak düşürülebildiyse `true` (içerik gösterilebilir);
    ///   hak kalmadıysa `false` (paywall gösterilmeli).
    @discardableResult
    func recordUse() -> Bool {
        resetIfNewDay()
        guard remainingUses > 0 else { return false }
        let used = defaults.integer(forKey: Self.usageCountKey) + 1
        defaults.set(used, forKey: Self.usageCountKey)
        remainingUses = max(0, Self.dailyFreeLimit - used)
        return true
    }

    private static func todayKey() -> String {
        // Sabit "yyyy-MM-dd" biçimi: cihazın yerel takvim gününü, dil/bölge
        // ayarından bağımsız ve karşılaştırılabilir bir anahtara çevirir.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}
