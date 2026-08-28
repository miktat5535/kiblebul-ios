import CoreLocation
import Foundation

/// OpenStreetMap Overpass API'sinden gelen bir cami kaydı.
struct Mosque: Identifiable, Equatable {
    let id: Int64
    let name: String
    let coordinate: CLLocationCoordinate2D
    var distanceKm: Double = 0

    static func == (lhs: Mosque, rhs: Mosque) -> Bool { lhs.id == rhs.id }
}

/// Yakındaki camileri Overpass API (OpenStreetMap) üzerinden çeken servis.
///
/// Android sürümüyle aynı, herkese açık ve ücretsiz Overpass uç noktasını
/// kullanır — sunucu tarafında hesap veya API anahtarı gerekmez.
enum OverpassMosqueService {

    private static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!

    /// `center` etrafında `radiusMeters` yarıçapında dinî bina (cami) arar.
    static func fetchNearbyMosques(
        center: CLLocationCoordinate2D,
        radiusMeters: Int = 5000
    ) async throws -> [Mosque] {
        let query = """
        [out:json][timeout:25];
        (
          node["amenity"="place_of_worship"]["religion"="muslim"](around:\(radiusMeters),\(center.latitude),\(center.longitude));
          way["amenity"="place_of_worship"]["religion"="muslim"](around:\(radiusMeters),\(center.latitude),\(center.longitude));
        );
        out center 60;
        """

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = "data=\(query)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).map { Data($0.utf8) }
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OverpassResponse.self, from: data)

        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        let mosques: [Mosque] = response.elements.compactMap { element in
            guard let lat = element.lat ?? element.center?.lat,
                  let lon = element.lon ?? element.center?.lon else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let name = element.tags?["name"] ?? "İsimsiz Cami"
            let distance = CLLocation(latitude: lat, longitude: lon).distance(from: centerLocation) / 1000.0
            return Mosque(id: element.id, name: name, coordinate: coordinate, distanceKm: distance)
        }

        return mosques.sorted { $0.distanceKm < $1.distanceKm }
    }
}

// MARK: - Overpass JSON şeması

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Decodable {
    let id: Int64
    let lat: Double?
    let lon: Double?
    let center: OverpassCenter?
    let tags: [String: String]?
}

private struct OverpassCenter: Decodable {
    let lat: Double
    let lon: Double
}
