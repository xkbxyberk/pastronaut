# Faz 0: risk prototipi

Bu klasör atılacak bir prototiptir; ana uygulamaya kod taşınmaz. Amaç `docs/pastronaut/TASARIM.md` §7'deki
R2 ve R3 risklerini kapatmak.

## Üretme ve derleme
```sh
xcodegen generate
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project PastronautProto.xcodeproj -scheme ProtoMac -destination 'platform=macOS' -allowProvisioningUpdates build
xcodebuild -project PastronautProto.xcodeproj -scheme ProtoiOS -destination 'id=<iPhone UDID>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> <…/Debug-iphoneos/PastronautProto.app>
```

## Test adımları
1. **Mac → iCloud:** Mac uygulamasında "iCloud hesabı: available" görünmeli. Bir metin yaz ve "iCloud'a yaz"a bas; listede görünmeli.
2. **iCloud → iPhone:** iPhone uygulamasında "iCloud: available" ve "App Group: erişilebilir" görünmeli.
   "Buluttan çek → klavyeye aktar"a bas; metin "Klavyedeki öğeler" bölümünde görünmeli.
3. **Klavyeyi ekle:** Ayarlar → Genel → Klavye → Klavyeler → Yeni Klavye Ekle → PastronautProto.
   Önce Tam Erişim'i **kapalı** bırak.
4. **Tam Erişim kapalıyken:** Notlar'da 🌐 ile klavyeye geç.
   - Beklenen: "Geçmiş için Tam Erişim gerekli" mesajı.
   - Boşluk, sil ve enter tuşları çalışmalı; klavye çökmemeli.
5. **Tam Erişim açıkken:** Ayarlar'da PastronautProto → Tam Erişime İzin Ver.
   - Notlar'da klavyeyi aç; öğeler görünmeli, dokununca yazılmalı.
6. **R2: klavyede pano okuma.**
   - Safari'de bir metin kopyala, Notlar'a dönüp klavyeyi aç.
   - **Gözle:** "… adlı uygulamadan yapıştırılsın mı?" penceresi ya da üstte bir yapıştırma bildirimi çıktı mı?
   - Uygulamadaki günlükte "klavye: pano okundu …" satırı ve süresi görünmeli.
7. **R2 karşılaştırma:** Uygulamada "Panoyu uygulamada oku"ya bas ve bu kez onay penceresinin çıkıp çıkmadığını gözle.
8. **iPhone → Mac:** Uygulamada "Klavyenin yakaladıklarını buluta gönder", ardından Mac'te "Yenile".
   Kaynağı `iphone` olan kayıt görünmeli.

## Sonuçlar
| Test | Sonuç | Not |
|---|---|---|
Tur 1: 2026-10-16, iPhone 14 Pro Max, iOS 27.0.1, macOS 27 (Development imzası, CloudKit Development ortamı).

| Test | Sonuç | Not |
|---|---|---|
| 1 Mac → iCloud | ✅ | Hesap `available`, yazma ve okuma çalıştı |
| 2 iCloud → iPhone | ✅ | Çekme ve App Group'a aktarma çalıştı |
| 4 Tam Erişim kapalı | ✅ (beklenenden iyi) | Klavye geçmişi **gösterdi** ve yazdı; temel tuşlar çalıştı. App Group'u Tam Erişim olmadan okuyabiliyor. Yazabildiği doğrulanmadı (tur 2). |
| 5 Tam Erişim açık | ✅ | |
| 6 Klavyede pano okuma (R2) | ⚠️ İzin istendi | Tam Erişim'li klavye panoyu okurken iOS "yapıştırmaya izin ver / verme" sordu. Otomatik okuma her pano değişiminde soru çıkarır. |
| 7 Uygulamada pano okuma | ❓ | Kullanıcı ne olduğunu göremedi; uygulama sonucu görünür biçimde göstermiyordu (tur 2'de düzeltildi) |
| 8 iPhone → Mac | ✅ | `iphone` kaynaklı kayıt Mac'te göründü |
| R3 Developer ID + CloudKit | ⏳ | Developer ID Application sertifikası gerekiyor |

Tur 2: aynı gün, aynı cihaz. Kanıt: kullanıcı gözlemi ve App Group günlüğü (`devicectl device copy from … Library/proto.json`).

| Test | Sonuç | Not |
|---|---|---|
| B Tam Erişim kapalı | okuma ✅, yazma ❌ | Klavye geçmişi Tam Erişim olmadan **gösterebilir**. Yakalama (yazma) için Tam Erişim şart. Günlükte `fullAccess=false` satırı yok; yazma başarısız olduğu için bu beklenen bir sonuç. |
| C Algılama | ✅ izin yok | `changeCount` + `hasStrings` ile "panoda yeni metin var" bilgisi izin penceresi açmadan alınıyor |
| D Klavye, düz okuma | ⚠️ izin istendi | İlk okuma 3,4 sn (kullanıcı onayı bekleniyor), sonrakiler ~30 ms |
| E Klavye, sistem PasteButton | ✅ izin yok | Günlükte metin alınmış (`PasteButton → 39 karakter`). Kullanıcı listede değişiklik görmedi, çünkü aynı metin daha önce eklenmişti (tekrar engelleme). |
| F Uygulama, düz okuma / PasteButton | ⚠️ izin / ✅ izin yok | Uygulamada da aynı davranış |
| G "Diğer Uygulamalardan Yapıştır: İzin Ver" | ✅ izin yok | Ayar **klavye uzantısını da kapsıyor**. Pencere çıkmıyor, yalnızca üstte "PastronautProto, Safari'den yapıştırdı" bildirimi görünüyor. |

**R2 sonucu:** Klavyeden telefon kopyası iki yolla izin penceresi olmadan yakalanabilir:
1. Sistem Yapıştır düğmesiyle tek dokunuş. Ayar gerektirmez.
2. Kullanıcı uygulamaya "Diğer Uygulamalardan Yapıştır: İzin Ver" verirse otomatik okuma. Sistem her seferinde kısa bir bildirim gösterir.

Tam Erişim olmadan geçmiş gösterilebilir ama yakalama yapılamaz.
