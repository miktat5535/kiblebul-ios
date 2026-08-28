import CoreLocation
import SwiftUI

/// Bulunduğunuz konuma göre günün namaz vakitlerini ve bir sonraki vakte
/// kalan süreyi gösterir. Hesaplama tamamen cihazda, Adhan kütüphanesiyle
/// (Türkiye / Hanefî) yapılır — internet gerekmez.
struct PrayerTimesView: View {
    @EnvironmentObject private var locationManager: LocationManager

    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Listede satır olarak kullanılan basit model.
    ///
    /// Not: `ForEach` demet (tuple) dizileriyle çalışmaz — Swift'te demet
    /// elemanlarına KeyPath tanımlanamaz. Bu yüzden `namedTimes` çıktısı
    /// burada Identifiable bir yapıya dönüştürülür.
    private struct Row: Identifiable {
        let name: String
        let date: Date
        var id: String { name }
    }

    private func rows(for date: Date) -> [Row]? {
        guard let location = locationManager.location,
              let times = PrayerTimeCalculator.calculate(for: date, at: location) else { return nil }
        return times.namedTimes.map { Row(name: $0.name, date: $0.date) }
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
                                    Text("Sıradaki vakit: \(nextPrayer.name)")
                                        .font(.headline)
                                    Text(countdownText(to: nextPrayer.date))
                                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.tint)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Section("Bugünün Vakitleri") {
                            ForEach(todayRows) { item in
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    Text(Self.timeFormatter.string(from: item.date))
                                        .monospacedDigit()
                                        .foregroundStyle(item.date > now ? Color.primary : Color.secondary)
                                }
                            }
                        }

                        Section {
                            Text("Vakitler bulunduğunuz konuma göre cihazınızda hesaplanır (Türkiye / Hanefî). Farklı şehirlerde küçük farklar olabilir.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Konum bekleniyor")
                            .font(.headline)
                        Text("Namaz vakitlerini hesaplayabilmek için konum iznine ihtiyaç var. İzin verdikten sonra vakitler otomatik gelir.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Konum İznini İste") {
                            locationManager.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Namaz Vakitleri")
        }
        .onReceive(ticker) { value in
            now = value
        }
    }

    private func countdownText(to date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    PrayerTimesView()
        .environmentObject(LocationManager())
}
