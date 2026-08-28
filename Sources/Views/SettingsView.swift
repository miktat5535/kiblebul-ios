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
                // App Store İnceleme Kılavuzu 3.1.2 gereği, otomatik yenilenen
                // aboneliğin satın alma noktasında şunlar GÖRÜNMEK ZORUNDA:
                // adı, süresi, ne sunduğu, fiyatı ve dönemi, otomatik yenileme
                // açıklaması, Kullanım Koşulları (EULA) ve Gizlilik Politikası
                // bağlantıları. Bu bölüm hepsini karşılar.
                Section("Kıble Bul Pro") {
                    if storeManager.isProActive {
                        Label("Aboneliğiniz aktif — reklamsız kullanım", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)

                        Text("Aboneliğinizi iPhone Ayarlar > Apple Kimliği > Abonelikler bölümünden yönetebilir veya iptal edebilirsiniz.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Satın Almaları Geri Yükle") {
                            Task { await storeManager.restorePurchases() }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Kıble Pro Aylık")
                                .font(.headline)

                            Text("1 aylık, otomatik yenilenen abonelik. Uygulamadaki tüm reklamları (alt banner ve açılış reklamı) kaldırır. Uygulamanın diğer tüm özellikleri abonelik olmadan da tam olarak çalışır.")
                                .font(.subheadline)

                            if let product = storeManager.monthlyProduct {
                                Text("\(product.displayPrice) / ay")
                                    .font(.title3.weight(.semibold))
                            } else if storeManager.isLoadingProducts {
                                Text("Fiyat yükleniyor…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Fiyat şu anda alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
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

                            if storeManager.monthlyProduct == nil && !storeManager.isLoadingProducts {
                                Button("Tekrar Dene") {
                                    Task { await storeManager.loadProducts() }
                                }
                                .font(.footnote)
                            }
                        }
                        .padding(.vertical, 4)

                        Text("""
                        Ödeme, satın almayı onayladığınızda Apple Kimliği hesabınızdan tahsil edilir. Abonelik, içinde bulunduğunuz dönem bitmeden en az 24 saat önce iptal edilmezse otomatik olarak yenilenir ve yenileme ücreti dönem bitiminden önceki 24 saat içinde alınır. Aboneliğinizi iPhone Ayarlar > Apple Kimliği > Abonelikler bölümünden istediğiniz zaman yönetebilir veya otomatik yenilemeyi kapatabilirsiniz.
                        """)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        Link("Kullanım Koşulları (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Link("Gizlilik Politikası", destination: URL(string: "https://miktat5535.github.io/kiblebul-privacy-policy/")!)

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
            // Uygulama açılışında ürün bilgisi çekilemediyse (ağ yok, App Store
            // yavaş yanıt verdi vb.) bu ekrana her gelişte tekrar denenir —
            // aksi halde abone olma butonu kalıcı olarak pasif kalabiliyordu.
            .task {
                if storeManager.monthlyProduct == nil {
                    await storeManager.loadProducts()
                }
            }
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
