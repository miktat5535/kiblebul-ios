import CoreLocation
import SwiftUI

/// Kıble pusulası ana ekranı. Telefonu düz tutup döndürdükçe ok, Kâbe
/// yönünü gösterir. Ok ekranın tepesini (kuzeyi değil, telefonun kendi
/// yönünü) gösterdiğinde kullanıcı kıbleye dönük demektir.
struct CompassView: View {
    @EnvironmentObject private var locationManager: LocationManager

    private var qiblaBearing: Double? {
        guard let location = locationManager.location else { return nil }
        return QiblaCalculator.bearing(from: location)
    }

    /// Ekranda gösterilecek ok açısı: kıble açısı - cihazın baktığı yön.
    private var arrowRotationDegrees: Double {
        guard let qiblaBearing else { return 0 }
        return qiblaBearing - locationManager.heading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                statusHeader

                ZStack {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 280, height: 280)

                    ForEach(Array(stride(from: 0, to: 360, by: 30)), id: \.self) { degree in
                        compassTick(degree: Double(degree))
                    }

                    Image(systemName: "location.north.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(arrowRotationDegrees))
                        .animation(.easeOut(duration: 0.2), value: arrowRotationDegrees)

                    Text("🕋")
                        .font(.system(size: 28))
                        .offset(y: -150)
                        .rotationEffect(.degrees(arrowRotationDegrees))
                        .animation(.easeOut(duration: 0.2), value: arrowRotationDegrees)
                }
                .frame(width: 300, height: 300)

                if let location = locationManager.location {
                    Text("Kâbe'ye uzaklık: \(Int(QiblaCalculator.distanceKm(from: location))) km")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Kıble Bul")
        }
    }

    @ViewBuilder
    private var statusHeader: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            Label("Konum izni bekleniyor…", systemImage: "location")
                .foregroundStyle(.secondary)
        case .denied, .restricted:
            Label("Konum izni verilmedi — Ayarlar'dan izin verin", systemImage: "location.slash")
                .foregroundStyle(.red)
        default:
            if locationManager.location == nil {
                Label("Konum aranıyor…", systemImage: "location")
                    .foregroundStyle(.secondary)
            } else if locationManager.headingAccuracy < 0 {
                Label("Pusula kalibre ediliyor — telefonu 8 çizerek sallayın", systemImage: "gyroscope")
                    .foregroundStyle(.orange)
            } else {
                Label("Hazır", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func compassTick(degree: Double) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 2, height: degree == 0 ? 16 : 8)
            .offset(y: -140)
            .rotationEffect(.degrees(degree - locationManager.heading))
    }
}

#Preview {
    CompassView()
        .environmentObject(LocationManager())
}
