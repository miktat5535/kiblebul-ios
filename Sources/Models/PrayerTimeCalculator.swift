import Adhan
import CoreLocation
import Foundation

/// Ezan vakitlerini hesaplar.
///
/// Kendi astronomik formülümüzü yazmak yerine, yaygın olarak kullanılan ve
/// iyi test edilmiş açık kaynak "Adhan" kütüphanesini (batoulapps/Adhan)
/// kullanıyoruz. Hesaplama yöntemi olarak Türkiye/Diyanet parametreleri
/// (.turkey) seçildi — Android sürümüyle tutarlı olması için.
enum PrayerTimeCalculator {

    struct DailyTimes {
        let fajr: Date
        let sunrise: Date
        let dhuhr: Date
        let asr: Date
        let maghrib: Date
        let isha: Date

        /// Bildirim planlamak için isim → tarih eşlemesi.
        var namedTimes: [(name: String, date: Date)] {
            [
                ("İmsak", fajr),
                ("Güneş", sunrise),
                ("Öğle", dhuhr),
                ("İkindi", asr),
                ("Akşam", maghrib),
                ("Yatsı", isha),
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
