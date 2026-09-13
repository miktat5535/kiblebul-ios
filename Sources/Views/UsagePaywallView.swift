import SwiftUI

/// Ücretsiz kullanıcının günlük kullanım hakkı (Pusula, Namaz Vakitleri,
/// Kamera (AR), Camiler — toplam `DailyUsageLimiter.dailyFreeLimit` hak)
/// tükendiğinde, ilgili sekmenin asıl içeriği YERİNE gösterilen ekran.
///
/// Abonelik teklifi için doğrudan `ProSubscriptionOfferView` kullanılır —
/// bu da Ayarlar ekranındaki abonelik bileşeniyle birebir aynıdır. Böylece
/// App Store İnceleme Kılavuzu 3.1.2'nin aradığı bilgiler (ad, süre, fiyat,
/// otomatik yenileme açıklaması, EULA ve Gizlilik Politikası bağlantıları)
/// burada da satın alma noktasında eksiksiz gösterilir.
struct UsagePaywallView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("usage.paywall.title", systemImage: "hourglass.bottomhalf.filled")
                            .font(.title3.weight(.semibold))

                        Text(
                            String(
                                format: NSLocalizedString(
                                    "usage.paywall.message",
                                    comment: "Bugün ücretsiz kullanım hakkı doldu açıklaması, %d = günlük limit"
                                ),
                                DailyUsageLimiter.dailyFreeLimit
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Text("usage.paywall.reset_note")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ProSubscriptionOfferView()
                }
                .padding()
            }
            .navigationTitle(Text("usage.paywall.title"))
        }
    }
}

#Preview {
    UsagePaywallView()
        .environmentObject(StoreManager())
}
