# Faz 5: yayın kontrol listesi (2026-10-17)

Durum işaretleri: ✅ bitti · ⏳ onay ya da kullanıcı adımı bekliyor · ⬜ yapılmadı.

## A. Yerelde hazırlananlar
- ✅ iPhone gizlilik bildirimi (`PrivacyInfo.xcprivacy`): uygulama, klavye, widget, Paylaş. Veri toplanmıyor, izleme yok.
  Gerekçeli API'ler: UserDefaults (CA92.1 uygulama, 1C8F.1 App Group), dosya tarihi (C617.1, App Group'taki anlık
  görüntü dosyası).
- ✅ Release derlemeleri: Mac ve iOS Release yapılandırmasında hatasız derleniyor (yalnızca DEBUG'daki test kancaları
  çıkıyor).
- ✅ Gizlilik politikası ve tanıtım sayfası: `docs/site/` (Türkçe + İngilizce, açık/koyu, telefona uygun).
- ✅ README Pastronaut'a göre yeniden yazıldı; "Maccy'ye dayanır, bağlantılı değildir" notu var. LICENSE'a telif
  satırımız eklendi (Maccy satırı korunuyor).
- ✅ İmza: anahtar zincirinde "Developer ID Application" sertifikası var (Mac'i App Store dışında dağıtmak için).

## B. Onay ya da kullanıcı adımı gerekenler (dışa dönük)
1. ✅ **GitHub depo bilgileri** (2026-10-17): açıklama Pastronaut'a, ana sayfa Pages adresine, varsayılan dal
   `pastronaut`'a geçti (önceden Maccy'nin açıklaması, `maccy.app` ve `master`).
2. ✅ **GitHub Pages** (2026-10-17): `gh-pages` dalındaki Maccy sitesi ve `CNAME = maccy.app` kaldırıldı, yerine
   `docs/site/` kondu. Adres: `https://xkbxyberk.github.io/pastronaut/`, gizlilik: `…/privacy.html` (App Store'a
   verilecek adres). Siteyi güncellemek: `docs/site/` değişince `gh-pages` dalına kopyalanır.
3. ⏳ **CloudKit Production şeması:** App Store, TestFlight ve Developer ID sürümleri Production ortamını kullanır;
   şema oraya gönderilmeden bu sürümlerde eşitleme çalışmaz. CloudKit Console › Pastronaut kapsayıcısı › "Deploy
   Schema Changes" (tarayıcıdan, senin hesabınla). Geri alınamaz: Production'a giden alan ve tür silinemez.
4. ✅ **Sparkle güncelleme anahtarı** (2026-10-17): EdDSA anahtar çifti; gizli anahtar anahtar zincirinde (`pastronaut`
   hesabı) ve **yedeklenmeli** (kaybolursa yüklü sürümler güncelleme alamaz). Açık anahtar `Info.plist`'te ve rebrand
   betiğinde.
5. ⏳ **Notarization bilgileri:** `xcrun notarytool store-credentials pastronaut --apple-id <e-posta> --team-id
   V88QY49A4T` (Apple Hesabı'nda üretilen uygulamaya özel parola ile; parolayı yalnızca sen girersin).
6. ⏳ **Mac sürümü 0.1.0** (arşiv ve Developer ID dışa aktarımı hazır: imza doğru, Production ortamı; notarization
   bilgileri bekleniyor): arşivle → Developer ID ile dışa aktar → notarize et → staple → zip/dmg → Sparkle imzası →
   `pastronaut-appcast.xml` girdisi → GitHub Release. Homebrew tap sonra.
7. ⬜ **App Store Connect:** uygulama kaydı (iOS; Mac App Store sonra), gizlilik etiketi "Veri Toplanmıyor",
   gizlilik adresi (madde 2), kategori, yaş derecesi, açıklama ve ekran görüntüleri (TR/EN).
8. ⬜ **TestFlight:** iOS arşivi yükle, iç test.
9. ⏳ **Şifreleme beyanı:** `ITSAppUsesNonExemptEncryption = false` yazıyor. Uygulama alanları CryptoKit ile
   şifreliyor (standart algoritma, Apple'ın kitaplığı). Bu genellikle muafiyet kapsamında sayılır ama beyanı App
   Store Connect'te gözden geçirmek gerekir. Hukuki görüş değildir.
10. ⬜ **Ad kontrolü:** "Pastronaut" için marka araması (TÜRKPATENT, EUIPO, USPTO, App Store'da aynı ad).

## C. Sonra
- Mac App Store yapılandırması (Sparkle'sız, ayrı yetkiler) ve Mac için gizlilik bildirimi.
- Homebrew tap.

## D. Durum ve kalan işler (2026-10-18)
**Bitti:**
- Mac 0.1.0 GitHub'da (Developer ID, notarize, Sparkle appcast).
- Site ve gizlilik politikası yayında (İngilizce önce). README.
- App Store Connect'te iOS kaydı açıldı:
  - App Information (EN, EN-GB, TR), yaş derecesi 4+, App Privacy yayınlandı ("Data Not Collected"),
    metinler ve görseller (`APPSTORE.md`).
  - Türkçe ad hatası sayfa yenilenince geçti.
- iOS sürümü App Store Connect'teki "1.0" ile eşleşsin diye `MARKETING_VERSION` 0.1.0 → 1.0 yapıldı. Mac GitHub
  sürümü 0.1.0 olarak kalır.

**Sırada:**
1. iOS 1.0 (build 1) arşivlenip App Store Connect'e yüklenir. Bunu **kullanıcı "yükle" deyince** yap.
   Ardından TestFlight iç testi; sürüm sayfasında build seçilip incelemeye gönderilir.
2. Mac App Store sürümü (universal purchase: aynı kayıt, "Add Platform › macOS"; paket kimliği aynı). Gerekenler:
   - Sparkle'sız bir Mac App Store yapılandırması. Maccy'nin `upstream/appstore` dalı örnek: Sparkle'ı ve
     `SoftwareUpdater`'ı çıkarır, değerlendirme isteğini açar. Bizde ayrı bir derleme ayarı ya da dal olarak.
   - Mac için gizlilik bildirimi (`PrivacyInfo.xcprivacy`).
   - Mac App Store imza ve profil; Erişilebilirlik ile yapıştırma aynen kalır (Maccy Mac App Store'da bu
     şekilde kabul edilmiş).
   - Görseller hazır: `appstore-screenshots/store/<lang>/mac-1…5.png`. Metinler `APPSTORE.md` §7'de.
3. iPad: simülatörde test, sonra `TARGETED_DEVICE_FAMILY "1,2"` ve iPad ekran görüntüleri.
4. Sonra: Homebrew cask; bir sonraki Mac sürümünde `CURRENT_PROJECT_VERSION` artırılır (Sparkle sürümleri bu
   numarayla karşılaştırır).

