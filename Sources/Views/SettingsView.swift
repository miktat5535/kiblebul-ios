import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var locationManager: LocationManager

    @State private var notificationsEnabled = false
    @State private var isPurchasing = false
    @State private var notificationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Kıble Bul Pro") {
                    if storeManager.isProActive {
                        Label("Aboneliğiniz aktif — reklamsız kullanım", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Aylık abonelikle tüm reklamlar kaldırılır.")
                            if let product = storeManager.monthlyProduct {
                                Text(product.displayPrice + " / ay")
                                    .font(.headline)
                            }
                            Button {
                                Task {
                                    isPurchasing = true
                                    await storeManager.purchase()
                                    isPurchasing = false
                                }
                            } label: {
                                if isPurchasing {
                                    ProgressView()
                                } else {
                                    Text("Kıble Pro'ya Abone Ol")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(storeManager.monthlyProduct == nil || isPurchasing)
                        }

                        Button("Satın Almaları Geri Yükle") {
                            Task { await storeManager.restorePurchases() }
                        }
                    }

                    if let errorMessage = storeManager.lastErrorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Ezan Vakti Bildirimleri") {
                    Toggle("Bildirimleri Aç", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, isOn in
                            handleNotificationToggle(isOn)
                        }
                    if let notificationMessage {
                        Text(notificationMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    Text("Bildirimler yalnızca cihazınızda hesaplanır; konumunuz hiçbir sunucuya gönderilmez.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Hakkında") {
                    LabeledContent("Sürüm", value: "1.0")
                    Link("Gizlilik Politikası", destination: URL(string: "https://miktat5535.github.io/kiblebul-privacy-policy/")!)
                }
            }
            .navigationTitle("Ayarlar")
        }
    }

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
                notificationMessage = "Bildirim izni verilmedi. iPhone Ayarlar > Bildirimler > Kıble Bul bölümünden açabilirsiniz."
                return
            }

            guard let location = locationManager.location else {
                notificationsEnabled = false
                notificationMessage = "Konum henüz alınamadı. Konum bulunduktan sonra tekrar deneyin."
                return
            }

            NotificationManager.reschedule(for: location)
            notificationMessage = "Önümüzdeki 7 gün için vakit bildirimleri kuruldu."
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
        .environmentObject(LocationManager())
}
