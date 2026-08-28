import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var adsManager: AdsManager
    @StateObject private var locationManager = LocationManager()

    @State private var didShowLaunchInterstitial = false

    var body: some View {
        TabView {
            CompassView()
                .tabItem { Label("Pusula", systemImage: "location.north.circle") }

            CameraARView()
                .tabItem { Label("Kamera", systemImage: "camera") }

            MosqueMapView()
                .tabItem { Label("Camiler", systemImage: "map") }

            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
        .environmentObject(locationManager)
        .safeAreaInset(edge: .bottom) {
            BannerAdView(show: !storeManager.isProActive)
        }
        .onAppear {
            locationManager.requestPermission()
            showLaunchInterstitialOnce()
        }
        .onChange(of: storeManager.isProActive) { _, isPro in
            adsManager.updateProStatus(isPro)
        }
    }

    /// Kullanıcı isteği: açılışta AdMob geçiş (interstitial) reklamı.
    /// Aynı oturumda yalnızca bir kez tetiklenir; `AdsManager` içindeki
    /// sıklık sınırı (varsayılan 4 saat) ayrıca açılışlar arasında da uygulanır.
    private func showLaunchInterstitialOnce() {
        guard !didShowLaunchInterstitial else { return }
        didShowLaunchInterstitial = true

        // Reklamın, ilk ekran tamamen göründükten hemen sonra çıkması için
        // kısa bir gecikme — aniden üstüne binmesin diye.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let rootViewController = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?.rootViewController
            adsManager.showInterstitialIfAppropriate(from: rootViewController)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreManager())
        .environmentObject(AdsManager())
}
