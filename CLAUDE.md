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
1. `git fetch upstream && git merge upstream/master` komutlarını çalıştır. Çakışan çeviri dosyalarında upstream sürümünü al.
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
