import AVFoundation
import SwiftUI

/// Kamera (AR) ekranı: canlı kamera görüntüsü üzerine kıble yönünü
/// gösteren bir ok bindirir. Görüntü hiçbir şekilde kaydedilmez veya
/// başka bir yere gönderilmez — yalnızca ekranda anlık gösterilir.
struct CameraARView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @State private var cameraPermissionGranted = false
    @State private var cameraPermissionDenied = false

    private var qiblaBearing: Double? {
        guard let location = locationManager.location else { return nil }
        return QiblaCalculator.bearing(from: location)
    }

    private var arrowRotationDegrees: Double {
        guard let qiblaBearing else { return 0 }
        return qiblaBearing - locationManager.heading
    }

    var body: some View {
        ZStack {
            if cameraPermissionGranted {
                CameraPreviewRepresentable()
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    Image(systemName: "arrow.up")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.white)
                        .shadow(radius: 8)
                        .rotationEffect(.degrees(arrowRotationDegrees))
                        .animation(.easeOut(duration: 0.2), value: arrowRotationDegrees)
                        .padding(.bottom, 120)
                }
            } else if cameraPermissionDenied {
                // Not: ContentUnavailableView iOS 17+ gerektirir; iOS 15/16
                // uyumluluğu için kendi basit karşılığımızı kullanıyoruz.
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Kamera izni gerekli")
                        .font(.headline)
                    Text("Ayarlar uygulamasından Kıble Bul için kamera iznini açabilirsiniz.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                ProgressView("Kamera hazırlanıyor…")
            }
        }
        .task {
            await requestCameraPermission()
        }
    }

    private func requestCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionGranted = granted
            cameraPermissionDenied = !granted
        default:
            cameraPermissionDenied = true
        }
    }
}

/// AVCaptureSession'ı SwiftUI'ye bağlayan ince UIKit köprüsü.
private struct CameraPreviewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.configureSession()
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        private let session = AVCaptureSession()

        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        func configureSession() {
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self, let device = AVCaptureDevice.default(for: .video) else { return }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    self.session.beginConfiguration()
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                    }
                    self.session.commitConfiguration()
                    self.session.startRunning()
                } catch {
                    // Kamera açılamazsa sessizce boş bırak; uygulama çökmez.
                }
            }
        }

        deinit {
            session.stopRunning()
        }
    }
}

#Preview {
    CameraARView()
        .environmentObject(LocationManager())
}
