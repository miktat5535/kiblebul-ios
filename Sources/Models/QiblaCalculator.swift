import CoreLocation
import Foundation

/// Kâbe'ye olan kıble açısını (büyük daire / great-circle bearing) hesaplar.
///
/// Bu, coğrafyada standart kabul edilen tek doğru yöntemdir; hangi kıble
/// pusulası uygulamasına bakarsanız bakın aynı formülü kullanır.
enum QiblaCalculator {

    /// Kâbe'nin enlem/boylamı (Mescid-i Haram, Mekke).
    static let kaaba = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    /// Verilen konumdan Kâbe'ye olan açıyı, kuzeyden saat yönünde derece
    /// cinsinden (0°–360°) döndürür.
    static func bearing(from location: CLLocationCoordinate2D) -> Double {
        let lat1 = location.latitude.degreesToRadians
        let lon1 = location.longitude.degreesToRadians
        let lat2 = kaaba.latitude.degreesToRadians
        let lon2 = kaaba.longitude.degreesToRadians

        let deltaLon = lon2 - lon1

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        let bearingRadians = atan2(y, x)
        let bearingDegrees = bearingRadians.radiansToDegrees

        return (bearingDegrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Kâbe'ye kuş uçuşu mesafe (kilometre).
    static func distanceKm(from location: CLLocationCoordinate2D) -> Double {
        let kaabaLocation = CLLocation(latitude: kaaba.latitude, longitude: kaaba.longitude)
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return userLocation.distance(from: kaabaLocation) / 1000.0
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}
