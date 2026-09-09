import AVFoundation
import Foundation

/// Vakit girdiğinde gerçek ezan sesini çalar.
///
/// İki senaryo var:
///  1. Uygulama arka plandayken/kapalıyken: bildirimin kendi sesi çalar
///     (iOS kısıtlaması: en fazla 30 saniye, .caf/.aiff/.wav formatında,
///     uygulama paketinin köküne eklenmiş olmalı — bkz. NotificationManager
///     ve `notificationSoundFileName(for:)`).
///  2. Uygulama açıkken (ön planda): `PrayerTimesView`'daki saniyelik
///     zamanlayıcı vaktin girdiğini fark ettiğinde burada tam uzunlukta
///     (dakikalarca sürebilen) gerçek ezan sesi çalınabilir.
///
/// ÖNEMLİ — TELİF HAKKI: Ses dosyaları bu depoya dahil edilmemiştir.
/// Ünlü bir müezzin/hafızın telifli kaydı izinsiz kullanılamaz. Bunun
/// yerine App Store/Play Store'da satılan bir uygulamada kullanılabilir,
/// lisansı uygun (CC0, "royalty-free" veya açıkça izinli) ezan kayıtları
/// eklenmelidir. Aday kaynaklar için bkz. README-TR.md → "Ezan Sesi Ekleme".
///
/// Dosya bulunamazsa oynatma sessizce başarısız olur (uygulama çökmez);
/// `lastPlaybackFailed` bunu Ayarlar ekranına yansıtmak için kullanılabilir.
@MainActor
final class AdhanPlayer: NSObject, ObservableObject {

    /// Kullanıcının Ayarlar'dan seçebileceği okuyuş/makam stilleri.
    ///
    /// `assetBaseName`, `Resources/Sounds/` klasörüne eklenecek ses
    /// dosyasının (uzantısız) temel adını belirtir. Tam uzunluktaki dosya
    /// doğrudan bu adla (ör. "adhan_makam_hicaz.m4a"), bildirim için
    /// kısaltılmış (≤30 sn) sürümü ise "_notification" ekiyle
    /// (ör. "adhan_makam_hicaz_notification.caf") eklenmelidir.
    enum ReciterStyle: String, CaseIterable, Identifiable, Hashable {
        case classic
        case hicaz
        case saba
        case rast

        var id: String { rawValue }

        var assetBaseName: String {
            switch self {
            case .classic: return "adhan_classic"
            case .hicaz: return "adhan_makam_hicaz"
            case .saba: return "adhan_makam_saba"
            case .rast: return "adhan_makam_rast"
            }
        }

        var localizedName: String {
            switch self {
            case .classic: return NSLocalizedString("settings.ezan_sound.style.classic", comment: "Klasik")
            case .hicaz: return NSLocalizedString("settings.ezan_sound.style.hicaz", comment: "Hicaz Makamı")
            case .saba: return NSLocalizedString("settings.ezan_sound.style.saba", comment: "Saba Makamı")
            case .rast: return NSLocalizedString("settings.ezan_sound.style.rast", comment: "Rast Makamı")
            }
        }
    }

    static let shared = AdhanPlayer()

    private var player: AVAudioPlayer?

    /// Son oynatma denemesi başarısız oldu mu (ör. dosya henüz eklenmedi).
    @Published private(set) var lastPlaybackFailed = false

    private override init() {
        super.init()
    }

    /// Belirtilen okuyuş stiliyle, tam uzunlukta ezan sesini çalar
    /// (uygulama ön plandayken kullanılır).
    func playFullAdhan(style: ReciterStyle) {
        guard let url = Self.resourceURL(baseName: style.assetBaseName) else {
            lastPlaybackFailed = true
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            lastPlaybackFailed = false
        } catch {
            lastPlaybackFailed = true
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    /// `Resources/Sounds/` altında kullanıcının eklediği tam uzunluktaki ses
    /// dosyasını arar (m4a, mp3, caf, wav, aiff sırasıyla denenir).
    private static func resourceURL(baseName: String) -> URL? {
        let extensions = ["m4a", "mp3", "caf", "wav", "aiff"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: baseName, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    /// Bildirim (arka plan) sesinin uygulama paketinde mevcut olup
    /// olmadığını kontrol eder. iOS kuralı: yalnızca .caf/.aiff/.wav,
    /// en fazla 30 saniye, dosya paket köküne eklenmiş olmalı.
    /// Bulunamazsa `nil` döner ve sistemin varsayılan bildirim sesi kullanılır.
    nonisolated static func notificationSoundFileName(for style: ReciterStyle) -> String? {
        let candidate = "\(style.assetBaseName)_notification"
        for ext in ["caf", "aiff", "wav"] {
            if Bundle.main.url(forResource: candidate, withExtension: ext) != nil {
                return "\(candidate).\(ext)"
            }
        }
        return nil
    }
}

/// Ezan sesi tercihlerini `UserDefaults`'ta saklar — hem `SettingsView`
/// hem `NotificationManager` hem de `PrayerTimesView` tarafından okunur.
enum EzanSoundSettings {
    private static let enabledKey = "ezanSoundEnabled"
    private static let styleKey = "ezanSoundStyle"

    /// Varsayılan olarak kapalı — kullanıcı Ayarlar'dan açıp ses dosyalarını
    /// eklediğinde devreye girer.
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var style: AdhanPlayer.ReciterStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: styleKey),
                  let style = AdhanPlayer.ReciterStyle(rawValue: raw) else {
                return .classic
            }
            return style
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: styleKey) }
    }
}
