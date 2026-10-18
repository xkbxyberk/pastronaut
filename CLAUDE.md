# Pastronaut

## Amaç
Maccy'nin (MIT) çatalı. macOS pano geçmişini iCloud üzerinden iPhone'a taşır. iPhone'da geçmişi gösteren
bir uygulama ve özel klavye sunar. Telefonda kopyalanan öğeler de aynı geçmişe katılır.
Hedef platformlar: macOS 14+ (mevcut uygulama), iOS 17+ (yeni uygulama ve klavye uzantısı).

## Bu proje bir MIT çatalıdır: RE-Lab temiz oda kuralı UYGULANMAZ
- Kaynak, `upstream` uzağındaki (https://github.com/p0deje/Maccy) açık kaynak koddur. Doğrudan okunup değiştirilebilir.
- `hedefler/`, `kanitlar/` ve REA çıktıları bu projede **kullanılmaz**. Gerekirse kaynak koda bak.
- `../../CLAUDE.md` dosyasındaki diğer kırmızı çizgiler (gizli anahtarlar, sistem korumaları vb.) geçerlidir.

## Lisans yükümlülükleri
- Kök `LICENSE` dosyasındaki Maccy telif satırı ve MIT metni korunur. Kendi değişikliklerimizin telif satırı altına eklenir.
- Uygulamada (macOS ve iOS) bir "Lisanslar" ekranı olur: Maccy, Sparkle, Defaults, KeyboardShortcuts, Settings,
  LaunchAtLogin-Modern, Sauce, fuse-swift, swift-log, SwiftHEXColors.
- "Maccy" adı, logosu ve ikonu kullanılmaz. README'de "Maccy'ye dayanır, onunla bağlantılı değildir" notu bulunur.

## Teknoloji
- Swift 6, SwiftUI, SwiftData (yerel depo), CloudKit / CKSyncEngine (eşitleme). Ayrıntı için `docs/pastronaut/TASARIM.md`.
- Xcode projesi: `Maccy.xcodeproj` (yeniden adlandırma ayrı bir adımda yapılacak).
- Derleme: `xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Debug build`
- Test: `xcodebuild -project Maccy.xcodeproj -scheme Maccy test`

## Upstream ile birleştirme
1. `git fetch upstream && git merge upstream/master` komutlarını çalıştır. Çakışan çeviri dosyalarında upstream sürümünü al. `README.md` ve `LICENSE` çakışırsa bizim sürümümüz kalır (Pastronaut README'si, ek telif satırı).
2. `scripts/pastronaut-rebrand.sh` betiğini çalıştır. Betik kimlik, ad ve besleme adresini yeniden uygular; tekrar çalıştırmak güvenlidir.
3. Paket bağımlılıkları değiştiyse `scripts/generate-acknowledgements.sh` betiğini çalıştır.
4. Derle ve testleri çalıştır: `xcodebuild … -only-testing:MaccyTests test`.

Swift modül adı bilerek `Maccy` bırakıldı (`PRODUCT_MODULE_NAME`). Ürün adı ve paket kimliği Pastronaut.

## Çalışma kuralları
- Yerel SwiftData deposu `cloudKitDatabase: .none` ile açılır (`Maccy/Storage.swift`). Bu ayar kaldırılırsa iCloud
  yetkisi yüzünden SwiftData otomatik CloudKit eşitlemesine geçer ve depo açılmaz. Eşitleme yalnızca kendi katmanımızla yapılır.
- Upstream ile birleşmeyi kolay tutmak için mevcut dosyalarda en az değişiklik yap. Yeni kodu ayrı dosyalara
  ve klasörlere koy (`Maccy/Sync/`, `Shared/`, `PastronautiOS/`, `PastronautKeyboard/`).
- Kabul ölçütleri teste dönüşmeden bir özelliğe "bitti" deme.
- Eşitleme, yok sayma kurallarından geçmemiş hiçbir içeriği gönderemez. Bunun için test zorunludur.
- Commit ve push yalnızca kullanıcı isteyince yapılır.

## Yayın: üç kanal (unutma)
Pastronaut **üç kanalda** yayınlanır ve Mac'e dokunan her sürüm hem Mac App Store'a hem GitHub'a çıkar:
1. **iPhone (App Store):** `iOS/` projesi.
2. **Mac App Store:** Sparkle'sız derleme, `scripts/appstore/build-mas.sh` (ana dalı değiştirmez).
3. **Mac GitHub sürümü:** Sparkle'lı, Developer ID + notarize; zip GitHub Releases'e, kayıt `pastronaut-appcast.xml`'e.

Adımlar, sürüm ve derleme numarası kuralları: `docs/pastronaut/SURUM.md`. Durum ve sıradaki işler:
`docs/pastronaut/YAYIN.md` ("D. Durum ve kalan işler"). Bir yayın işini bitirince ikisini de güncelle.
Ana dal her zaman Sparkle'lı kalır; Sparkle'ı ana daldan kaldırma.

## Kullanıcıyla çalışma kuralları (Pastronaut)
- Türkçe, sade; her yanıtın sonunda: ne yapıldı, hangi dosyalar değişti, sıradaki adım.
- Kurulum ve yapılandırma değişikliklerinde: plan → onay → uygula → doğrula.
- App Store Connect'e yükleme **yalnızca kullanıcı "yükle" deyince**. İncelemeye gönderme ve yayınlama kullanıcının işi.
  GitHub Release yayınlama ve appcast push'u da kullanıcı onayıyla.
- Görsellerde gerçek pano verisi asla olmaz: `PT_DEMO` kullan. Kişisel veri içeren ekran görüntüsünü saklama.
  Kullanıcının geçmişinde bir kez uygulamaya özel parola çıktı; gizli bilgileri maskele.
- Kestirmeler / Siri metinlerinde (App Intents başlık, açıklama, seçenek adları ve kimlikleri, Siri cümleleri)
  "Mac", "iPhone", "iPad" yazma: App Review ITMS-90626 gönderir.
- Klavye Tam Erişim olmadan da çalışmalı (Guideline 4.4.1).
- Başka uygulamaların kodunu, görselini, adını veya ayırt edici görünüşünü kopyalama (ör. Paste); yalnızca teknik fikir.
- Kabuk: `rm -rf`'i değişkenli yolla kullanma (`"${R:?}/…"`), `log` yerine `/usr/bin/log`,
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ve `env -u SDKROOT`.
- Mac arayüz testlerinden önce gerçek Pastronaut'u kapat
  (`osascript -e 'tell application id "com.xkbxyberk.pastronaut" to quit'`), sonra `~/Applications/Pastronaut.app`'i yeniden aç.
