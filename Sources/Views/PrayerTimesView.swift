import CoreLocation
import SwiftUI

/// Bulunduğunuz konuma göre günün namaz vakitlerini ve bir sonraki vakte
/// kalan süreyi gösterir. Hesaplama tamamen cihazda, Adhan kütüphanesiyle
/// (Türkiye / Hanefî) yapılır — internet gerekmez.
struct PrayerTimesView: View {
    @EnvironmentObject private var locationManager: LocationManager

    @State private var now = Date()

    /// Uygulama ön plandayken tam uzunlukta ezan sesi çalındığında aynı
    /// vaktin tekrar tekrar tetiklenmemesi için işaretlenen kimlikler.
    @State private var firedAdhanIdentifiers: Set<String> = []

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Listede satır olarak kullanılan basit model.
    ///
    /// Not: `ForEach` demet (tuple) dizileriyle çalışmaz — Swift'te demet
    /// elemanlarına KeyPath tanımlanamaz. Bu yüzden `namedTimes` çıktısı
    /// burada Identifiable bir yapıya dönüştürülür.
    private struct Row: Identifiable {
        let prayer: Prayer
        let date: Date
        var id: String { prayer.rawValue }
    }

    private func rows(for date: Date) -> [Row]? {
        guard let location = locationManager.location,
              let times = PrayerTimeCalculator.calculate(for: date, at: location) else { return nil }
        return times.namedTimes.map { Row(prayer: $0.prayer, date: $0.date) }
    }

    private var todayRows: [Row]? { rows(for: now) }

    /// Bugünün kalan vakitleri bittiyse yarının ilk vaktine geçer.
    private var nextPrayer: Row? {
        if let upcoming = todayRows?.first(where: { $0.date > now }) {
            return upcoming
        }
        guard let tomorrow = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: now) else {
            return nil
        }
        return rows(for: tomorrow)?.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let todayRows {
                    List {
                        if let nextPrayer {
                            Section {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(String(format: NSLocalizedString("prayer_times.next", comment: "Sıradaki vakit: %@"), nextPrayer.prayer.localizedName))
                                        .font(.headline)
                                    Text(countdownText(to: nextPrayer.date))
                                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.tint)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Section(NSLocalizedString("prayer_times.today_section", comment: "Bugünün Vakitleri")) {
                            ForEach(todayRows) { item in
                                HStack {
                                    Text(item.prayer.localizedName)
                                    Spacer()
                                    Text(Self.timeFormatter.string(from: item.date))
                                        .monospacedDigit()
                                        .foregroundStyle(item.date > now ? Color.primary : Color.secondary)
                                }
                            }
                        }

                        Section {
                            Text("prayer_times.disclaimer")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("prayer_times.waiting_location")
                            .font(.headline)
                        Text("prayer_times.waiting_location_detail")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("prayer_times.request_permission") {
                            locationManager.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(Text("prayer_times.title"))
        }
        .onReceive(ticker) { value in
            now = value
            triggerAdhanIfNeeded()
        }
    }

    /// Uygulama ön plandayken tam vakti geçen bir namaz olup olmadığını
    /// kontrol eder; varsa ve kullanıcı ezan sesini açtıysa tam uzunlukta
    /// gerçek ezan sesini çalar. Bildirimler (arka plan/kapalıyken) ayrıca
    /// `NotificationManager` üzerinden, iOS'un 30 saniyelik sınırına tabi
    /// kısaltılmış sesle çalışır — bu ikisi birbirini tamamlar.
    private func triggerAdhanIfNeeded() {
        guard EzanSoundSettings.isEnabled, let rows = todayRows else { return }
        for row in rows where row.prayer != .sunrise {
            let elapsed = now.timeIntervalSince(row.date)
            guard elapsed >= 0, elapsed < 2 else { continue }
            let identifier = "\(row.prayer.rawValue)-\(Int(row.date.timeIntervalSince1970))"
            guard !firedAdhanIdentifiers.contains(identifier) else { continue }
            firedAdhanIdentifiers.insert(identifier)
            AdhanPlayer.shared.playFullAdhan(style: EzanSoundSettings.style)
        }
    }

    private func countdownText(to date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Saat formatı, uygulamanın gösterildiği dile göre değişir (ör. bazı
    /// dillerde farklı rakam/ayraç kuralları) ama her zaman 24 saatlik
    /// "HH:mm" biçimini kullanır — namaz vakti uygulamalarında yaygın olan
    /// ve karışıklığı önleyen kural.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    PrayerTimesView()
        .environmentObject(LocationManager())
}
