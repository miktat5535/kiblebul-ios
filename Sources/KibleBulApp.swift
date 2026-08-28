import SwiftUI

/// Kıble Bul — iOS uygulamasının giriş noktası.
///
/// Android sürümüyle aynı iş mantığı: kıble pusulası, kamera (AR) ekranı,
/// yakındaki camiler haritası ve ezan vakti bildirimleri. Reklamlar AdMob
/// üzerinden (banner + açılışta geçiş reklamı) gösterilir; "Kıble Pro"
/// aboneleri hiç reklam görmez.
@main
struct KibleBulApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var storeManager = StoreManager()
    @StateObject private var adsManager = AdsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeManager)
                .environmentObject(adsManager)
                .task {
                    // Uygulama ilk açıldığında: rıza (UMP) akışını başlat,
                    // ardından reklam altyapısını ve abonelik durumunu yükle.
                    await storeManager.refreshEntitlements()
                    adsManager.start(isProUser: storeManager.isProActive)
                }
        }
    }
}

/// UIKit köprüsü — AdMob'un rıza (UMP) akışı ve geçiş reklamının doğru
/// zamanda (uygulama tamamen ön plana geldiğinde) gösterilebilmesi için
/// bir UIApplicationDelegate'e ihtiyaç var.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }
}
