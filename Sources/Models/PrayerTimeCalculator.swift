import Adhan
import CoreLocation
import Foundation

/// Bir günün namaz vakti isimlerini temsil eder.
///
/// `rawValue` sabittir ve bildirim kimliklerinde (identifier) kullanılır —
/// dile göre değişmez. Ekranda gösterilecek isim için `localizedName`
/// kullanılır; bu, `Localizable.strings` üzerinden 9 dilde çevrilmiştir.
enum Prayer: String, CaseIterable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    var localizedName: String {
        switch self {
        case .fajr: return NSLocalizedString("prayer.fajr", comment: "İmsak")
        case .sunrise: return NSLocalizedString("prayer.sunrise", comment: "Güneş")
        case .dhuhr: return NSLocalizedString("prayer.dhuhr", comment: "Öğle")
        case .asr: return NSLocalizedString("prayer.asr", comment: "İkindi")
        case .maghrib: return NSLocalizedString("prayer.maghrib", comment: "Akşam")
        case .isha: return NSLocalizedString("prayer.isha", comment: "Yatsı")
        }
    }
}

/// Ezan vakitlerini hesaplar.
///
/// Kendi astronomik formülümüzü yazmak yerine, yaygın olarak kullanılan ve
/// iyi test edilmiş açık kaynak "Adhan" kütüphanesini (batoulapps/Adhan)
/// kullanıyoruz. Hesaplama yöntemi olarak Türkiye/Diyanet parametreleri
/// (.turkey) seçildi — Android sürümüyle tutarlı olması için. Bu hesaplama
/// yöntemi, uygulama dili ne olursa olsun (bkz. Localizable.strings)
/// değişmez — sadece vakit isimlerinin gösterildiği dil değişir.
enum PrayerTimeCalculator {

    struct DailyTimes {
        let fajr: Date
        let sunrise: Date
        let dhuhr: Date
        let asr: Date
        let maghrib: Date
        let isha: Date

        /// Bildirim planlamak ve listelemek için vakit → tarih eşlemesi.
        var namedTimes: [(prayer: Prayer, date: Date)] {
            [
                (.fajr, fajr),
                (.sunrise, sunrise),
                (.dhuhr, dhuhr),
                (.asr, asr),
                (.maghrib, maghrib),
                (.isha, isha),
            ]
        }
    }

    static func calculate(for date: Date, at coordinate: CLLocationCoordinate2D) -> DailyTimes? {
        let coordinates = Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day], from: date
        )
        components.calendar = Calendar(identifier: .gregorian)

        var params = CalculationMethod.turkey.params
        params.madhab = .hanafi // Türkiye'de yaygın fıkhi görüş — ikindi vaktini biraz geciktirir

        guard let prayerTimes = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params) else {
            return nil
        }

        return DailyTimes(
            fajr: prayerTimes.fajr,
            sunrise: prayerTimes.sunrise,
            dhuhr: prayerTimes.dhuhr,
            asr: prayerTimes.asr,
            maghrib: prayerTimes.maghrib,
            isha: prayerTimes.isha
        )
    }
}
