import CoreLocation
import MapKit
import SwiftUI

/// Yakındaki camileri harita üzerinde gösterir. Veri, ücretsiz ve herkese
/// açık OpenStreetMap Overpass API'sinden gelir (bkz. Mosque.swift) —
/// Android sürümüyle aynı veri kaynağı.
struct MosqueMapView: View {
    @EnvironmentObject private var locationManager: LocationManager

    @State private var mosques: [Mosque] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var didCenterOnUser = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    ForEach(mosques) { mosque in
                        Marker(mosque.name, systemImage: "building.columns.fill", coordinate: mosque.coordinate)
                            .tint(.green)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }

                if isLoading {
                    ProgressView("Camiler aranıyor…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 24)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 24)
                } else if !mosques.isEmpty {
                    Text("\(mosques.count) cami bulundu")
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 24)
                }
            }
            // Cami verisi OpenStreetMap'ten (Overpass API) gelir. ODbL lisansı
            // verinin gösterildiği yerde kaynak belirtmeyi zorunlu kılar.
            //
            // Not: Bilerek `safeAreaInset` KULLANILMIYOR — bu değiştirici alt
            // sekme çubuğunun üzerine bindirip dokunuşları yutabiliyor.
            // `overlay` yalnızca bu görünümün kendi sınırları içinde çizer.
            .overlay(alignment: .bottomLeading) {
                Text("Cami verisi © OpenStreetMap katkıda bulunanlar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.leading, 8)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)
            }
            .navigationTitle("Yakındaki Camiler")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let location = locationManager.location else { return }
                        Task { await searchNearbyMosques(around: location) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(locationManager.location == nil || isLoading)
                }
            }
            // Sekmeye geçildiğinde konum ZATEN biliniyorsa `onChange` bir daha
            // tetiklenmez; bu yüzden ilk aramayı burada da başlatıyoruz.
            // (Kullanıcı Pusula sekmesinde beklerken konum gelir, sonra
            // Camiler sekmesine geçerdi ve harita hiç arama yapmazdı.)
            .task {
                guard mosques.isEmpty, !isLoading, let location = locationManager.location else { return }
                didCenterOnUser = true
                cameraPosition = .region(
                    MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                )
                await searchNearbyMosques(around: location)
            }
            // Not: CLLocationCoordinate2D'nin Equatable uygunluğu SDK'ya göre
            // değişebildiği için onChange anahtarı olarak sade bir Double?
            // (enlem) kullanıyoruz — belirsizlik veya "redundant conformance"
            // derleme hatası riskini tamamen ortadan kaldırır.
            .onChange(of: locationManager.location?.latitude) { _, _ in
                guard let newLocation = locationManager.location, !didCenterOnUser else { return }
                didCenterOnUser = true
                cameraPosition = .region(
                    MKCoordinateRegion(center: newLocation, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                )
                Task { await searchNearbyMosques(around: newLocation) }
            }
        }
    }

    private func searchNearbyMosques(around coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            mosques = try await OverpassMosqueService.fetchNearbyMosques(center: coordinate)
        } catch {
            errorMessage = "Camiler yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin."
        }
    }
}

#Preview {
    MosqueMapView()
        .environmentObject(LocationManager())
}
