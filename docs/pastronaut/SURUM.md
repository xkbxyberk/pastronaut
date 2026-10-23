# Sürüm çıkarma rehberi (üç kanal)

Pastronaut'un her sürümü **üç kanalda birden** çıkar. Biri unutulursa kullanıcılar farklı sürümlerde kalır:

| Kanal | Ne | Nasıl güncellenir |
|---|---|---|
| 1. **iPhone (App Store)** | `iOS/` projesi: uygulama, klavye, widget'lar, paylaşım | App Store Connect, App Review |
| 2. **Mac App Store** | Sparkle'sız Mac derlemesi (`scripts/appstore/build-mas.sh`) | App Store Connect, App Review |
| 3. **Mac GitHub sürümü** | Sparkle'lı, Developer ID ile imzalı, notarize edilmiş Mac derlemesi | GitHub Releases + `pastronaut-appcast.xml` (Sparkle kendini günceller) |

Kanal 2 ile 3 aynı kaynaktan çıkar; farkı yalnızca `mas-transform.py`'nin geçici kopyada yaptıkları (Sparkle yok,
gizlilik bildirimi var, değerlendirme isteği açık). Ana dal her zaman Sparkle'lı kalır.

Bir değişiklik yalnızca bir platformu ilgilendiriyorsa (ör. yalnızca klavye), yalnızca o kanal çıkabilir; ama
Mac'e dokunan her değişiklik **hem kanal 2 hem kanal 3** demektir.

## Sürüm numaraları
- **Görünen sürüm (`MARKETING_VERSION`) üç kanalda aynıdır:** `iOS/project.yml` ve `Maccy.xcodeproj` (iki satır).
  Kural: hata düzeltmesi son rakamı (1.1.1), yeni özellik ortadakini (1.2) artırır. Yalnızca bir kanal çıkarsa
  öbürleri o numarayı atlar; bir sonraki sürümleri en yüksek numaradan devam eder (aynı numara iki farklı içerikle
  çıkmaz).
  Şu an (2026-10-23): iPhone **1.2** ve Mac **1.0** (Mac App Store) yayında, GitHub **0.1.0**. Sıradaki sürüm ortak
  **1.3**: iPhone ve Mac birlikte, üç kanalda (`PLAN-1.3.md`).
- **Derleme numarası (`CURRENT_PROJECT_VERSION`) her yüklemede artar:**
  - iPhone: `iOS/project.yml`. Yüklenen son: **4** (1.2, 2026-10-22) → sonraki **5**. Ayarlar'daki
    "1.2 (4)" bu numarayı gösterir; TestFlight ile App Store sürümünü ve hata bildirimlerini ayırt etmeye yarar.
  - Mac: `Maccy.xcodeproj`. Mac App Store ile GitHub aynı numarayı kullanır. Yayınlanan son: **1** (Mac App
    Store 1.0 (1); GitHub 0.1.0 (1)) → sonraki **2**. Sparkle güncellemeyi bu numarayla anlar: küçülürse veya
    aynı kalırsa güncelleme görünmez.
- App Store Connect aynı derleme numarasını ikinci kez kabul etmez; yükleme reddedilirse numarayı bir artır.

## Yayından önce (her kanal için)
1. Testler geçsin:
   - Mac: `xcodebuild -project Maccy.xcodeproj -scheme Maccy -only-testing:MaccyTests test`
   - Çekirdek: `swift test --package-path PastronautCore`
   - iPhone: `iOS/` içinde `xcodegen generate`, sonra şemanın testleri.
2. **CloudKit şeması değiştiyse** (yeni alan veya kayıt türü): CloudKit Console'da Development → **Deploy
   Schema Changes to Production**. Yoksa yayındaki sürümler yeni alanları yazamaz.
3. Kestirmeler (App Intents) metinlerinde **Apple ürün adı yok** ("Mac", "iPhone", "iPad"): yoksa ITMS-90626.
   `build-mas.sh` Mac için bunu kendisi denetler; iPhone arşivinde `Metadata.appintents` taranır.
4. Sürüm ve derleme numaralarını artır, commit'le.

## Kanal 1: iPhone (App Store)
```bash
cd iOS && xcodegen generate && cd ..
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
R=build/ios; rm -rf "${R:?}/Pastronaut.xcarchive" "${R:?}/upload"
env -u SDKROOT xcodebuild -project iOS/Pastronaut-iOS.xcodeproj -scheme Pastronaut -configuration Release \
  -destination 'generic/platform=iOS' -archivePath $R/Pastronaut.xcarchive -allowProvisioningUpdates archive
# ExportOptions: method app-store-connect, destination upload, teamID V88QY49A4T, signingStyle automatic,
# uploadSymbols true, manageAppVersionAndBuildNumber false
env -u SDKROOT xcodebuild -exportArchive -archivePath $R/Pastronaut.xcarchive \
  -exportOptionsPlist $R/ExportOptions.plist -exportPath $R/upload -allowProvisioningUpdates
```
Yüklemeyi **yalnızca kullanıcı "yükle" deyince** yap. Sonra kullanıcı App Store Connect'te:
- yeni sürümü açar (iOS App › "+"), "What's New" metnini girer;
- TestFlight'ta dener, build'i seçer, incelemeye gönderir.

## Kanal 2: Mac App Store
```bash
scripts/appstore/build-mas.sh            # derle ve denetle, yükleme yok (build/mas/export/Pastronaut.pkg)
scripts/appstore/build-mas.sh --upload   # kullanıcı "yükle" deyince
```
Sürüm ve derleme numarasını HEAD'deki projeden alır; **önce commit'le**. Kullanıcı App Store Connect'te
macOS App › "+" ile yeni sürümü açar, build'i seçer, incelemeye gönderir.

## Kanal 3: Mac GitHub sürümü (Sparkle)
Gerekenler bu Mac'te kurulu: Developer ID sertifikası, `notarytool` profili `pastronaut`, Sparkle'ın gizli
anahtarı anahtar zincirinde (hesap `pastronaut`; yedeği kullanıcıda). Anahtar kaybolursa eski sürümler
güncelleme alamaz.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
V=1.0.1; R=build/github; DD=build/github-dd
rm -rf "${R:?}/Pastronaut.xcarchive" "${R:?}/export"
env -u SDKROOT xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Release \
  -derivedDataPath $DD -archivePath $R/Pastronaut.xcarchive archive
# ExportOptions: method developer-id, signingStyle automatic, teamID V88QY49A4T
env -u SDKROOT xcodebuild -exportArchive -archivePath $R/Pastronaut.xcarchive \
  -exportOptionsPlist $R/ExportOptions.plist -exportPath $R/export -allowProvisioningUpdates

cd $R
ditto -c -k --keepParent export/Pastronaut.app Pastronaut-$V.zip
xcrun notarytool submit Pastronaut-$V.zip --keychain-profile pastronaut --wait   # status: Accepted olmalı
xcrun stapler staple export/Pastronaut.app
spctl -a -vv export/Pastronaut.app          # "Notarized Developer ID" görmelisin
rm -f Pastronaut-$V.zip && ditto -c -k --keepParent export/Pastronaut.app Pastronaut-$V.zip
../../$DD/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update --account pastronaut Pastronaut-$V.zip
shasum -a 256 Pastronaut-$V.zip
```
`sign_update` bir `sparkle:edSignature` ve `length` verir. Sonra:
1. `pastronaut-appcast.xml` dosyasında `<channel>` içine, **en üste** yeni bir `<item>` ekle (eski öğeler kalır):
   başlık, tarih, `sparkle:version` = derleme numarası, `sparkle:shortVersionString` = $V,
   `minimumSystemVersion` 14.0, sürüm notu bağlantısı, `enclosure` (zip adresi, imza, uzunluk).
2. Sürüm notlarını yaz (İngilizce, altta kısa Türkçe; Maccy'ye dayanır notu, gizlilik bağlantısı, SHA-256).
3. Kullanıcı onayıyla: `gh release create v$V build/github/Pastronaut-$V.zip --repo xkbxyberk/pastronaut
   --draft --target pastronaut --title "Pastronaut $V" --notes-file …`; denetle; sonra
   `gh release edit v$V --draft=false --latest`.
4. **Appcast'i en son** commit'le ve push'la (zip yayında değilken Sparkle güncellemeye çalışmasın).
5. Denetle: ham appcast adresinde yeni imza görünüyor mu; indirilen zip `sign_update --verify` ile doğrulanıyor mu.

Notlar:
- Push için gerekirse: `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`.
- İlk Homebrew cask hâlâ yapılmadı (YAYIN.md).

## Sürümden sonra
- `docs/pastronaut/YAYIN.md` "D. Durum" bölümüne ne yayınlandığını ve sıradaki derleme numaralarını yaz.
- Yeni özellik mağaza metinlerini değiştiriyorsa `APPSTORE.md` ve ekran görüntülerini güncelle (yalnızca
  `PT_DEMO` verisiyle; gerçek pano verisi asla görsellere girmez).
