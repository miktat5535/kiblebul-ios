import SwiftUI

/// Ücretsiz (abone olmayan) kullanıcılar için günlük kullanım hakkı
/// sınırını uygulayan sarmalayıcı görünüm. Pusula, Namaz Vakitleri, Kamera
/// (AR) ve Camiler sekmelerinin HER BİRİ bu sarmalayıcıyla kullanılır; dördü
/// de aynı ortak günlük hak havuzunu (`DailyUsageLimiter`) paylaşır.
///
/// Davranış:
///  - Kıble Pro aktifse (`StoreManager.isProActive`) sınır hiç uygulanmaz,
///    içerik doğrudan ve hak düşürülmeden gösterilir.
///  - Değilse, sekmeye HER GEÇİŞTE (`onAppear`) ortak havuzdan bir hak
///    düşürülür. Gün içinde toplam hak tükenince içerik yerine abonelik
///    teklifi (`UsagePaywallView`) gösterilir.
///  - Hak varken, kullanıcı sınıra ne kadar yaklaştığını görebilsin diye
///    üstte ince bir "bugün kalan hakkınız" şeridi gösterilir.
struct UsageGatedContainer<Content: View>: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var usageLimiter: DailyUsageLimiter

    @State private var isAllowed = true

    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if storeManager.isProActive || isAllowed {
                VStack(spacing: 0) {
                    if !storeManager.isProActive {
                        remainingBanner
                    }
                    content()
                }
            } else {
                UsagePaywallView()
            }
        }
        .onAppear(perform: evaluate)
    }

    private var remainingBanner: some View {
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
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.08))
    }

    /// Sekmeye her geçişte çağrılır. Pro kullanıcıda hiçbir şey yapmaz.
    /// Değilse: gün değiştiyse sayaç önce sıfırlanır, ardından bir hak
    /// düşürülmeye çalışılır — hak kalmadıysa `isAllowed` false olur ve
    /// içerik yerine paywall gösterilir.
    private func evaluate() {
        guard !storeManager.isProActive else {
            isAllowed = true
            return
        }
        isAllowed = usageLimiter.recordUse()
    }
}
