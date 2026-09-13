import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var usageLimiter: DailyUsageLimiter

    @State private var notificationsEnabled = false
    @State private var notificationMessage: String?
    @State private var ezanSoundEnabled = EzanSoundSettings.isEnabled
    @State private var ezanSoundStyle = EzanSoundSettings.style

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

                        if let errorMessage = storeManager.lastErrorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } else {
                        // Abone olmadan önce, ücretsiz kullanıcıya bugün
                        // kaç hakkı kaldığını göster — aboneliğin neden
                        // gerekli olduğu burada da açık olsun.
                        Text(
                            String(
                                format: NSLocalizedString(
                                    "usage.banner.remaining",
                                    comment: "Bugün kalan ücretsiz kullanım hakkı, %d = kalan, %d = toplam"
                                ),
                                usageLimiter.remainingUses,
                                DailyUsageLimiter.dailyFreeLimit
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        ProSubscriptionOfferView()
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
                    LabeledContent("settings.about.version", value: "1.2")
                    Link("settings.about.privacy", destination: URL(string: "https://miktat5535.github.io/kiblebul-privacy-policy/")!)
                }
            }
            .navigationTitle(Text("settings.title"))
        }
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
        .environmentObject(DailyUsageLimiter())
}
