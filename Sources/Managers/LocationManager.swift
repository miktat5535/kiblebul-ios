import CoreLocation
import Foundation

/// Cihazın konumunu ve pusula (manyetik + gerçek kuzey) yönünü yayınlayan
/// tek kaynak. Tüm hesaplamalar cihazda yapılır; konum hiçbir sunucuya
/// gönderilmez (yalnızca cami arama için Overpass API'sine enlem/boylam
/// gönderilir — bkz. Mosque.swift).
@MainActor
final class LocationManager: NSObject, ObservableObject {

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocationCoordinate2D?
    @Published var heading: CLLocationDirection = 0
    @Published var headingAccuracy: CLLocationDirection = -1

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 1
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // İzin daha önce verilmişse `locationManagerDidChangeAuthorization`
            // tekrar tetiklenmeyebilir; güncellemeleri burada elle başlatıyoruz.
            start()
        default:
            break
        }
    }

    func start() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.location = coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // trueHeading, konum servisleri açık ve doğruysa gerçek kuzeye göre;
        // değilse manyetik kuzeye göre yönü kullanır.
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.heading = value
            self.headingAccuracy = newHeading.headingAccuracy
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Sessizce yut — konum alınamazsa ekran kullanıcıya izin/GPS uyarısı gösterir.
    }
}
