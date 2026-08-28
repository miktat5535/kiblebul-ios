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
    /// güncellendiğinde tekrar çağrılmalıdır.
    static func reschedule(for coordinate: CLLocationCoordinate2D, days: Int = 7) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = PrayerTimeCalculator.calculate(for: day, at: coordinate) else { continue }

            for (name, date) in times.namedTimes where date > now {
                scheduleNotification(prayerName: name, at: date, center: center)
            }
        }
    }

    private static func scheduleNotification(prayerName: String, at date: Date, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "Kıble Bul"
        content.body = "\(prayerName) vakti girdi."
        content.sound = .default

        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "ezan-\(prayerName)-\(Int(date.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }
}
