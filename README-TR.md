# Kıble Bul — iOS Sürümü — Kurulum Rehberi

Bu depo, Kıble Bul'un iOS (iPhone) sürümünün tam kaynak kodunu içerir:
kıble pusulası, kamera (AR) ekranı, yakındaki camiler haritası, ezan vakti
bildirimleri, AdMob reklamları (banner + açılışta geçiş/interstitial) ve
"Kıble Pro" aylık aboneliği (reklamsız kullanım).

**Önemli:** iOS uygulamaları yalnızca Xcode ile ve yalnızca macOS'ta
derlenip imzalanabilir. Windows'ta bunu yapamazsınız. Bu yüzden bu proje,
Mac'e hiç dokunmadan, Windows'unuzdan yönetebileceğiniz bir bulut
derleme hattı (Codemagic) için hazırlandı.

---

## 1. Adım — GitHub'a yükleyin

Windows'ta PowerShell veya Git Bash açın, bu klasörün içinde:

```powershell
git init
git add .
git commit -m "Kıble Bul iOS - ilk sürüm"
```

Sonra [github.com/new](https://github.com/new) adresinden `kiblebul-ios`
adında **boş** (README eklemeden) bir depo oluşturun, ardından:

```powershell
git remote add origin https://github.com/miktat5535/kiblebul-ios.git
git branch -M main
git push -u origin main
```

---

## 2. Adım — Apple Developer hesabı

Eğer henüz yoksa: [developer.apple.com](https://developer.apple.com/programs/)
üzerinden yıllık 99 USD karşılığı bir "Apple Developer Program" hesabı
açmanız gerekiyor — bu, App Store'a herhangi bir uygulama yüklemenin ön
koşulu (Google Play'in tek seferlik 25 USD'sinden farklı olarak Apple
her yıl yeniler).

---

## 3. Adım — App Store Connect'te uygulamayı ve aboneliği oluşturun

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.
   - Platform: iOS
   - Ad: Kıble Bul
   - Bundle ID: `com.miktat55.kiblebul` (bu listede yoksa önce
     [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list)
     sayfasından aynı isimle bir "App ID" oluşturun).
   - SKU: `kiblebul-ios` (istediğiniz bir metin olabilir)

2. **Abonelik (Kıble Pro) oluşturma:**
   - Uygulamanız içinde **Features → In-App Purchases** (veya
     **Subscriptions**) bölümüne gidin.
   - Yeni bir **Subscription Group** oluşturun (ör. "Kıble Pro").
   - Grup içine yeni bir abonelik ekleyin:
     - **Reference Name:** Kıble Pro Aylık
     - **Product ID:** `com.miktat55.kiblebul.pro.monthly`
       (⚠️ Bu, koddaki `StoreManager.proMonthlyProductID` ile **birebir aynı**
       olmalı — `Sources/Managers/StoreManager.swift` dosyasında tanımlı.)
     - **Süre:** 1 ay
     - **Fiyat:** Fiyat kademesi listesinden **Türkiye için 9,90 TL/ay**
       karşılığına en yakın kademeyi seçin (Apple fiyatları serbest metin
       değil, önceden tanımlı kademelerden seçilir — 9,90 TL'ye en yakın
       kademe otomatik önerilecektir).
     - Abonelik açıklaması ve "yerelleştirme" (Türkçe ad/açıklama) girin.
     - Review Information kısmına bir ekran görüntüsü eklemeniz istenecek
       (uygulamayı Xcode'da simülatörde çalıştırıp Ayarlar ekranının
       görüntüsünü alabilirsiniz).

3. **Uygulama Gizliliği (App Privacy) anketi:** Google Play'deki "Data
   Safety" formunun Apple karşılığı. Şunları işaretleyin:
   - Konum (Location) → Kullanılıyor → Uygulama İşlevselliği için,
     kullanıcıyla ilişkilendirilmiyor, takip için kullanılmıyor.
   - Tanımlayıcılar (Identifiers) → Reklam Kimliği → Reklam/Pazarlama için
     kullanılıyor, üçüncü taraf reklam ağıyla (Google AdMob) paylaşılıyor.
   - Gizlilik politikası URL'si: `https://miktat5535.github.io/kiblebul-privacy-policy/`
     (Android için zaten hazırladığımız sayfa — aynısını kullanabilirsiniz,
     zaten AdMob/Reklam Kimliği kullanımını açıklıyor.)

---

## 4. Adım — Codemagic ile bulutta derleme

1. [codemagic.io](https://codemagic.io) adresinde GitHub hesabınızla ücretsiz kaydolun.
2. **Add application** → GitHub'dan `kiblebul-ios` deposunu seçin.
   Codemagic, depodaki `codemagic.yaml` dosyasını otomatik algılayacaktır.
3. **Code signing:** Sol menüden **Teams → Code signing identities** →
   Apple Developer hesabınızla oturum açıp "Automatic" imzalamayı bağlayın.
   Codemagic sertifika ve provisioning profile'ı sizin adınıza Apple'da
   oluşturur.
4. **App Store Connect entegrasyonu (TestFlight'a otomatik yükleme için):**
   - App Store Connect'te **Users and Access → Integrations → App Store
     Connect API** kısmından yeni bir API anahtarı oluşturun (rol: App
     Manager).
   - Codemagic → **Teams → Integrations → App Store Connect**'e bu anahtarı
     (Issuer ID, Key ID, .p8 dosyası) girin, entegrasyona `app_store_connect`
     adını verin (codemagic.yaml'daki `groups:` kısmıyla eşleşmesi için).
5. **Start new build** ile ilk derlemeyi başlatın. 10-20 dakika içinde:
   - Derleme başarılı olursa `.ipa` dosyasını doğrudan indirebilir **veya**
   - `submit_to_testflight: true` sayesinde otomatik olarak TestFlight'a
     yüklenir — birkaç dakika sonra telefonunuzda TestFlight uygulamasından
     test edebilirsiniz.

Her `git push` sonrası bu işlem otomatik tekrarlanır — Android'de
Android Studio'da elle "Generate Signed Bundle" yapmanız gerekirken,
burada sadece kod değişikliğini GitHub'a göndermeniz yeterli.

---

## 5. Uygulama simgesi (App Icon)

`Resources/Assets.xcassets/AppIcon.appiconset` şu an boş bir yer
tutucudur. App Store'a göndermeden önce 1024×1024 piksel bir PNG simge
eklemeniz gerekir — Android'deki mevcut `ic_launcher` görselinizi
1024×1024'e büyütüp kullanabilirsiniz (ör. Xcode'da "AppIcon.appiconset"
klasörüne sürükleyip bırakarak, ya da [appicon.co](https://appicon.co) gibi
bir araçla tüm boyutları otomatik oluşturarak).

---

## 6. AdMob durumu

- **iOS App ID:** `ca-app-pub-8580294286333632~1988794070`
- **Banner reklam birimi:** `ca-app-pub-8580294286333632/1868490090`
- **Geçiş (interstitial) reklam birimi:** `ca-app-pub-8580294286333632/6785774858`

Bu üçü zaten kodun içinde (`Sources/Managers/AdsManager.swift`) tanımlı,
ek bir işlem gerekmez. Yeni bir AdMob uygulaması olduğu için Android'de
yaşadığımız "app-ads.txt doğrulama" süreci burada da geçerli — uygulama
App Store'a yüklenip gerçek reklam istekleri oluşmaya başladıktan sonra
birkaç gün içinde AdMob otomatik doğrulayacaktır. Aynı
`https://miktat5535.github.io/app-ads.txt` dosyası hem Android hem iOS
için geçerlidir, ayrıca bir şey yapmanıza gerek yok — ama App Store
Connect'teki uygulama sayfasında bir "Marketing URL" alanı varsa oraya da
`https://miktat5535.github.io/` yazmanızı öneririm.

Geliştirme sırasında (Xcode'dan doğrudan simülatörde/cihazda çalıştırırken)
kod otomatik olarak Google'ın test reklam kimliklerini kullanır
(`DEBUG` derlemesi) — gerçek reklamlara yanlışlıkla tıklama riski yoktur.
Codemagic'in ürettiği App Store derlemesi ise gerçek kimlikleri kullanır.

---

## 7. Özellik karşılaştırması (Android ile)

| Özellik | Android | iOS |
|---|---|---|
| Kıble pusulası | ✅ | ✅ |
| Kamera (AR) ekranı | ✅ | ✅ |
| Yakındaki camiler haritası | ✅ (OSM Overpass) | ✅ (aynı API) |
| Ezan vakti bildirimleri | ✅ | ✅ (Diyanet yöntemi, Adhan kütüphanesi) |
| Banner reklam | ✅ | ✅ |
| Geçiş (interstitial) reklam | — | ✅ (açılışta, 4 saatte bir sınırlı) |
| Kıble Pro (reklamsız) | ✅ Google Play Billing | ✅ StoreKit 2, 9,90 TL/ay |

---

## Sorun mu çıktı?

Codemagic derleme loglarını (build başarısız olursa "Logs" sekmesinde tam
hata metni görünür) buraya yapıştırın, birlikte çözelim — tıpkı Android
tarafında Gradle hatalarını çözdüğümüz gibi.
