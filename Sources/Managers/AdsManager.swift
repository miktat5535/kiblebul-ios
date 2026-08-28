import Foundation
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Reklam kimlikleri.
///
/// GERÇEK ADMOB KİMLİKLERİ (28 Ağustos 2026'da admob.google.com üzerinden
/// oluşturuldu, hesap: miktat55@gmail.com). Android sürümündeki aynı AdMob
/// hesabı altında, ayrı bir iOS uygulaması olarak kaydedildi.
///
///   - AdMob iOS uygulama kimliği: ca-app-pub-8580294286333632~1988794070
///     (Info.plist içindeki GADApplicationIdentifier ile eşleşir.)
///   - Banner reklam birimi: Kible_Bul_iOS_Banner
///     ID: ca-app-pub-8580294286333632/1868490090
///   - Geçiş (interstitial) reklam birimi: Kible_Bul_iOS_Gecis
///     ID: ca-app-pub-8580294286333632/6785774858
///
/// Yeni oluşturulan reklam birimlerinin gerçek reklam göstermeye başlaması
/// AdMob tarafında ilk 1 saat kadar sürebilir. Ayrıca bu iOS uygulaması
/// App Store'a hiç yüklenmediği/onaylanmadığı sürece AdMob tarafında
/// "inceleme gerekli" durumunda kalır ve reklam sunumu sınırlı olabilir —
/// bu normaldir, uygulama yayınlanıp gerçek reklam istekleri oluştukça
/// kendiliğinden düzelir (Android tarafında app-ads.txt için izlediğimiz
/// süreçle aynı mantık).
///
/// UYARI: Kendi reklamlarınıza tıklamayın veya test amacıyla uygulamayı
/// defalarca açıp kapatmayın — AdMob bunu geçersiz trafik sayar ve
/// hesabınız askıya alınabilir. Geliştirme sırasında Google'ın resmi test
/// kimliklerini (aşağıda `test` sabitleri) kullanın.
enum AdConfig {
    static let appID = "ca-app-pub-8580294286333632~1988794070"

    static let bannerUnitID = "ca-app-pub-8580294286333632/1868490090"
    static let interstitialUnitID = "ca-app-pub-8580294286333632/6785774858"

    /// Google'ın resmî test birimleri — yalnızca geliştirme/simülatörde kullanın.
    enum test {
        static let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"
        static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    }

    /// DEBUG derlemelerinde otomatik olarak test kimliklerine geçer; böylece
    /// geliştirirken yanlışlıkla gerçek reklamlara tıklama riski olmaz.
    static var effectiveBannerUnitID: String {
        #if DEBUG
        return test.bannerUnitID
        #else
        return bannerUnitID
        #endif
    }

    static var effectiveInterstitialUnitID: String {
        #if DEBUG
        return test.interstitialUnitID
        #else
        return interstitialUnitID
        #endif
    }
}

/// Reklam altyapısının başlatılması, AB/UK (GDPR) rıza akışı ve açılış
/// geçiş (interstitial) reklamının yönetimi.
///
/// Tüm çağrılar savunmacı biçimde sarmalanmıştır: reklam altyapısı
/// herhangi bir nedenle başlatılamazsa uygulama reklamsız olarak sorunsuz
/// çalışmaya devam eder — asla çökmez.
@MainActor
final class AdsManager: NSObject, ObservableObject {

    @Published private(set) var canShowAds = false
    @Published private(set) var isProUser = false

    private var interstitial: InterstitialAd?
    private var lastInterstitialShownAt: Date?

    /// İki geçiş reklamı arasında en az bu kadar süre geçmesini zorunlu
    /// kılar — Apple/AdMob'un "aşırı reklam" politikalarına takılmamak ve
    /// kullanıcı deneyimini korumak için.
    private let minimumIntervalBetweenInterstitials: TimeInterval = 4 * 60 * 60 // 4 saat

    private static let userDefaultsLastShownKey = "kiblebul.lastInterstitialShownAt"

    func start(isProUser: Bool) {
        self.isProUser = isProUser
        if let saved = UserDefaults.standard.object(forKey: Self.userDefaultsLastShownKey) as? Date {
            lastInterstitialShownAt = saved
        }

        guard !isProUser else { return }

        Task {
            await requestConsentIfNeeded()
            await startMobileAdsIfAllowed()
        }
    }

    /// Abonelik durumu değiştiğinde (satın alma / restore sonrası) çağrılır.
    func updateProStatus(_ isPro: Bool) {
        isProUser = isPro
        if isPro {
            interstitial = nil
        }
    }

    // MARK: - Rıza (UMP)

    private func requestConsentIfNeeded() async {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }

        guard ConsentInformation.shared.formStatus == .available else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentForm.loadAndPresentIfRequired(from: nil) { _ in
                continuation.resume()
            }
        }
    }

    // MARK: - Başlatma

    private func startMobileAdsIfAllowed() async {
        guard ConsentInformation.shared.canRequestAds || ConsentInformation.shared.formStatus == .unavailable else {
            canShowAds = false
            return
        }

        await MobileAds.shared.start()
        canShowAds = true
        loadInterstitial()
    }

    // MARK: - Geçiş (interstitial) reklamı

    private func loadInterstitial() {
        guard canShowAds, !isProUser else { return }
        Task {
            do {
                interstitial = try await InterstitialAd.load(
                    with: AdConfig.effectiveInterstitialUnitID,
                    request: GADRequest()
                )
                interstitial?.fullScreenContentDelegate = self
            } catch {
                interstitial = nil
            }
        }
    }

    /// Uygulama açılışında (veya ön plana geldiğinde) çağrılır. Sıklık
    /// sınırına uyar ve Pro kullanıcılarda hiçbir şey yapmaz.
    func showInterstitialIfAppropriate(from viewController: UIViewController?) {
        guard canShowAds, !isProUser, let viewController else { return }

        if let lastShown = lastInterstitialShownAt,
           Date().timeIntervalSince(lastShown) < minimumIntervalBetweenInterstitials {
            return
        }

        guard let interstitial else {
            loadInterstitial() // bir sonraki açılış için hazırla
            return
        }

        interstitial.present(from: viewController)
        lastInterstitialShownAt = Date()
        UserDefaults.standard.set(lastInterstitialShownAt, forKey: Self.userDefaultsLastShownKey)
    }
}

extension AdsManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadInterstitial() // bir sonraki gösterim için yenisini önceden yükle
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
        loadInterstitial()
    }
}
