import CoreLocation
import Foundation
import UserNotifications

/// Ezan vakti hatırlatma bildirimlerini planlar.
///
/// Android'deki AlarmManager + BootReceiver ikilisinin iOS karşılığı:
/// `UNUserNotificationCenter` ile önümüzdeki 7 gün için vakit bildirimleri
/// önceden planlanır (iOS'ta arka planda sürekli çalışan bir servis yerine
/// bu şekilde "önceden planlama" yaklaşımı kullanılır — pil dostu ve resmi
/// olarak desteklenen yöntemdir).
///
/// Kullanıcı Ayarlar'dan "Ezan Sesini Çal"ı açtıysa ve ilgili ses dosyası
/// uygulama paketine eklenmişse, bildirimler sistemin varsayılan sesi yerine
/// gerçek (kısaltılmış, ≤30 sn) ezan sesiyle gelir — bkz. `AdhanPlayer`.
/// Uygulama ön plandayken tam uzunluktaki ezan sesi `PrayerTimesView`
/// üzerinden ayrıca tetiklenir (bildirim sesleri iOS'ta 30 saniyeyle
/// sınırlıdır).
enum NotificationManager {

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Planlanmış tüm ezan vakti bildirimlerini iptal eder.
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Var olan tüm ezan vakti bildirimlerini temizleyip önümüzdeki `days`
    /// gün için yeniden planlar. Konum değiştiğinde veya ayarlar
    /// güncellendiğinde (ör. ezan sesi aç/kapat) tekrar çağrılmalıdır.
    static func reschedule(for coordinate: CLLocationCoordinate2D, days: Int = 7) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = PrayerTimeCalculator.calculate(for: day, at: coordinate) else { continue }

            for (prayer, date) in times.namedTimes where date > now {
                scheduleNotification(prayer: prayer, at: date, center: center)
            }
        }
    }

    private static func scheduleNotification(prayer: Prayer, at date: Date, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.title", comment: "Bildirim başlığı — uygulama adı")

        let bodyFormat = NSLocalizedString(
            "notification.body",
            comment: "Bildirim gövdesi, %@ = vakit adı (İmsak, Öğle, vb.)"
        )
        content.body = String(format: bodyFormat, prayer.localizedName)

        // Güneş doğuşunda ezan okunmaz — sadece bilgilendirme bildirimi;
        // gerçek ezan sesi yalnızca 5 vakit namaz için kullanılır.
        if prayer != .sunrise,
           EzanSoundSettings.isEnabled,
           let fileName = AdhanPlayer.notificationSoundFileName(for: EzanSoundSettings.style) {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(fileName))
        } else {
            content.sound = .default
        }

        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        // Kimlik dile bağlı olmayan `prayer.rawValue` (ör. "fajr") kullanır —
        // önceki sürümlerde yerelleştirilmiş isim (ör. "İmsak") kullanılıyordu,
        // bu artık dil değiştiğinde kimliklerin tutarsız kalmasını önler.
        let identifier = "ezan-\(prayer.rawValue)-\(Int(date.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }
}
