import StoreKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var locationManager: LocationManager

    @State private var notificationsEnabled = false
    @State private var isPurchasing = false
    @State private var notificationMessage: String?
    @State private var selectedPlan: PlanOption = .yearly
    @State private var ezanSoundEnabled = EzanSoundSettings.isEnabled
    @State private var ezanSoundStyle = EzanSoundSettings.style

    private enum PlanOption: Equatable {
        case monthly
        case yearly
    }

    var body: some View {
        NavigationStack {
            Form {
                // App Store İnceleme Kılavuzu 3.1.2 gereği, otomatik yenilenen
                // aboneliklerin satın alma noktasında şunlar GÖRÜNMEK ZORUNDA:
                // adı, süresi, ne sunduğu, fiyatı ve dönemi, otomatik yenileme
                // açıklaması, Kullanım Koşulları (EULA) ve Gizlilik Politikası
                // bağlantıları. Aylık VE yıllık plan için de bu bölüm hepsini
                // karşılar.
                Section("settings.pro.section") {
                    if storeManager.isProActive {
                        Label("settings.pro.active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)

                        Text("settings.pro.manage")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("settings.pro.restore") {
                            Task { await storeManager.restorePurchases() }
                        }
                    } else {
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
                        }
                        .padding(.vertical, 4)

                        Text("settings.pro.legal_disclaimer")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Link("settings.pro.eula", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Link("settings.pro.privacy", destination: URL(string: "https://miktat5535.github.io/kiblebul-privacy-policy/")!)

                        Button("settings.pro.restore") {
                            Task { await storeManager.restorePurchases() }
                        }
                    }

                    if let errorMessage = storeManager.lastErrorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("settings.ezan_sound.section") {
                    Toggle("settings.ezan_sound.enable", isOn: $ezanSoundEnabled)
                        .onChange(of: ezanSoundEnabled) { _, isOn in
                            EzanSoundSettings.isEnabled = isOn
                            rescheduleIfPossible()
                        }

                    if ezanSoundEnabled {
                        Picker("settings.ezan_sound.style", selection: $ezanSoundStyle) {
                            ForEach(AdhanPlayer.ReciterStyle.allCases) { style in
                                Text(style.localizedName).tag(style)
                            }
                        }
                        .onChange(of: ezanSoundStyle) { _, newStyle in
                            EzanSoundSettings.style = newStyle
                            rescheduleIfPossible()
                        }
                    }

                    Text("settings.ezan_sound.explanation")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("settings.notifications.section") {
                    Toggle("settings.notifications.toggle", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, isOn in
                            handleNotificationToggle(isOn)
                        }
                    if let notificationMessage {
                        Text(notificationMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    Text("settings.notifications.privacy_note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("settings.about.section") {
                    LabeledContent("settings.about.version", value: "1.0")
                    Link("settings.about.privacy", destination: URL(string: "https://miktat5535.github.io/kiblebul-privacy-policy/")!)
                }
            }
            .navigationTitle(Text("settings.title"))
            // Uygulama açılışında ürün bilgisi çekilemediyse (ağ yok, App Store
            // yavaş yanıt verdi vb.) bu ekrana her gelişte tekrar denenir —
            // aksi halde abone olma butonu kalıcı olarak pasif kalabiliyordu.
            .task {
                if storeManager.monthlyProduct == nil, storeManager.yearlyProduct == nil {
                    await storeManager.loadProducts()
                }
            }
        }
    }

    // MARK: - Plan seçimi (aylık / yıllık)

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

    // MARK: - Bildirimler

    private func handleNotificationToggle(_ isOn: Bool) {
        guard isOn else {
            notificationMessage = nil
            // Kullanıcı kapattıysa planlı bildirimleri temizle.
            NotificationManager.cancelAll()
            return
        }

        Task { @MainActor in
            let granted = await NotificationManager.requestPermission()

            guard granted else {
                notificationsEnabled = false
                notificationMessage = NSLocalizedString(
                    "settings.notifications.permission_denied",
                    comment: "Bildirim izni verilmedi hata mesajı"
                )
                return
            }

            guard let location = locationManager.location else {
                notificationsEnabled = false
                notificationMessage = NSLocalizedString(
                    "settings.notifications.location_pending",
                    comment: "Konum henüz alınamadı hata mesajı"
                )
                return
            }

            NotificationManager.reschedule(for: location)
            notificationMessage = NSLocalizedString(
                "settings.notifications.scheduled",
                comment: "Bildirimler kuruldu bilgi mesajı"
            )
        }
    }

    /// Ezan sesi tercihi değiştiğinde (aç/kapat veya makam), bildirimler zaten
    /// açıksa yeni tercihin bildirime yansıması için yeniden planlar.
    private func rescheduleIfPossible() {
        guard notificationsEnabled, let location = locationManager.location else { return }
        NotificationManager.reschedule(for: location)
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
        .environmentObject(LocationManager())
}
