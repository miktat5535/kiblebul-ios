import GoogleMobileAds
import SwiftUI

/// Ekranın altında gösterilen banner reklam.
///
/// `show` false olduğunda (yani kullanıcı "Kıble Pro" abonesiyse) hiçbir
/// şey çizilmez — abonelerin arayüzü tamamen reklamsızdır.
struct BannerAdView: View {
    let show: Bool

    var body: some View {
        Group {
            if show {
                BannerAdRepresentable()
                    .frame(height: 50)
            }
        }
        // Banner hiçbir zaman kendi 50 puanlık alanının dışına taşmaz ve
        // altındaki/üstündeki hiçbir kontrolün dokunuşunu yutmaz.
        .clipped()
    }
}

private struct BannerAdRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdConfig.effectiveBannerUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        // Reklam yüklenemezse (ağ yok, doldurulamadı vb.) sessizce boş kalır;
        // ekran düzeni bozulmaz, uygulama çalışmaya devam eder.
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
