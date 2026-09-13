import StoreKit
import SwiftUI

/// Kıble Pro abonelik teklifi: aylık/yıllık plan seçimi, satın alma butonu,
/// yasal uyarı metni, EULA/Gizlilik bağlantıları ve satın almaları geri
/// yükleme.
///
/// App Store İnceleme Kılavuzu 3.1.2 gereği, otomatik yenilenen
/// aboneliklerin satın alma NOKTASINDA şunları göstermesi ZORUNLUDUR: adı,
/// süresi, ne sunduğu, fiyatı/dönemi, otomatik yenileme açıklaması, EULA ve
/// Gizlilik Politikası bağlantıları. Bu bileşen hem Ayarlar ekranındaki
/// abonelik bölümünde hem de günlük ücretsiz kullanım hakkı dolduğunda
/// gösterilen paywall'da (`UsagePaywallView`) kullanılır — aynı uyumlu
/// içerik her iki yerde de gösterilir, kopya kod tutmaya gerek kalmaz.
struct ProSubscriptionOfferView: View {
    @EnvironmentObject private var storeManager: StoreManager

    @State private var isPurchasing = false
    @State private var selectedPlan: PlanOption = .yearly

    private enum PlanOption: Equatable {
        case monthly
        case yearly
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("settings.pro.description")
                .font(.subheadline)

            planPicker

            Button {
                Task {
                    isPurchasing = true
                    await purchaseSelectedPlan()
                    isPurchasing = false
                }
            } label: {
                if isPurchasing {
                    ProgressView()
                } else {
                    Text(subscribeButtonTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedProduct == nil || isPurchasing)

            if storeManager.monthlyProduct == nil,
               storeManager.yearlyProduct == nil,
               !storeManager.isLoadingProducts {
                Button("settings.pro.retry") {
                    Task { await storeManager.loadProducts() }
                }
                .font(.footnote)
            }

            Text("settings.pro.legal_disclaimer")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Link("settings.pro.eula", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Link("settings.pro.privacy", destination: URL(string: "https://miktat5535.github.io/kiblebul-privacy-policy/")!)

            Button("settings.pro.restore") {
                Task { await storeManager.restorePurchases() }
            }

            if let errorMessage = storeManager.lastErrorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
        // Ürün bilgisi çekilemediyse (ağ yok, App Store yavaş yanıt verdi
        // vb.) bu görünüm her göründüğünde tekrar denenir — aksi halde
        // abone olma butonu kalıcı olarak pasif kalabiliyordu.
        .task {
            if storeManager.monthlyProduct == nil, storeManager.yearlyProduct == nil {
                await storeManager.loadProducts()
            }
        }
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case .monthly: return storeManager.monthlyProduct
        case .yearly: return storeManager.yearlyProduct
        }
    }

    private var subscribeButtonTitle: LocalizedStringKey {
        selectedPlan == .monthly ? "settings.pro.subscribe_monthly" : "settings.pro.subscribe_yearly"
    }

    private func purchaseSelectedPlan() async {
        guard let product = selectedProduct else { return }
        await storeManager.purchase(product)
    }

    @ViewBuilder
    private var planPicker: some View {
        VStack(spacing: 10) {
            if let monthly = storeManager.monthlyProduct {
                planRow(
                    title: "settings.pro.monthly_title",
                    priceText: String(format: NSLocalizedString("settings.pro.per_month", comment: "%@ / ay"), monthly.displayPrice),
                    isSelected: selectedPlan == .monthly,
                    badge: nil
                ) {
                    selectedPlan = .monthly
                }
            }
            if let yearly = storeManager.yearlyProduct {
                planRow(
                    title: "settings.pro.yearly_title",
                    priceText: String(format: NSLocalizedString("settings.pro.per_year", comment: "%@ / yıl"), yearly.displayPrice),
                    isSelected: selectedPlan == .yearly,
                    badge: "settings.pro.savings_badge"
                ) {
                    selectedPlan = .yearly
                }
            }
            if storeManager.monthlyProduct == nil, storeManager.yearlyProduct == nil {
                if storeManager.isLoadingProducts {
                    Text("settings.pro.price_loading")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("settings.pro.price_unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            // Yıllık ürün mevcutsa varsayılan seçili plan olsun (daha
            // avantajlı fiyat); yoksa aylığa düşer.
            if storeManager.yearlyProduct == nil { selectedPlan = .monthly }
        }
    }

    private func planRow(
        title: LocalizedStringKey,
        priceText: String,
        isSelected: Bool,
        badge: LocalizedStringKey?,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(priceText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProSubscriptionOfferView()
        .environmentObject(StoreManager())
}
