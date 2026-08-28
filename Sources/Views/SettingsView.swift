import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var locationManager: LocationManager

    @State private var notificationsEnabled = false
    @State private var isPurchasing = false

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
            // Kullanıcı kapattıysa planlı bildirimleri temizle.
            Task { @MainActor in
                if let location = locationManager.location {
                    NotificationManager.reschedule(for: location, days: 0)
                }
            }
            return
        }

        Task {
            let granted = await NotificationManager.requestPermission()
            guard granted, let location = locationManager.location else {
                await MainActor.run { notificationsEnabled = false }
                return
            }
            NotificationManager.reschedule(for: location)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
        .environmentObject(LocationManager())
}
