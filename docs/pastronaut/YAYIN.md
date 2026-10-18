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
1. ✅ iOS 1.0 (build 1) App Store Connect'e yüklendi (2026-10-18; Release arşivi, yalnızca iPhone).
   Sırada: TestFlight iç testi, sonra sürüm sayfasında build seçilip kullanıcı onayıyla incelemeye gönderilir.
   Build 1'e Apple'dan ITMS-90626 uyarısı geldi: Kestirmeler/Siri tanımlarında (eylem adı, açıklaması, seçenek
   adları, Siri cümleleri, kimlikler) Apple ürün adı ("Mac", "iPhone") olamaz. Düzeltildi: seçenekler
   "Computer/Bilgisayar" ve "Phone/Telefon" (kimlikler `computer`, `phone`), açıklamalar ve Siri cümlesi
   "computer / other devices". ✅ Build 2 yüklendi (2026-10-18). Sonraki yükleme: build 3.
   ✅ TestFlight iç testi geçti (2026-10-18): iPhone'da TestFlight build 2 + Mac'te GitHub 0.1.0, ikisi de
   Production iCloud ortamında; eşitleme ve klavye sorunsuz. Sırada: sürüm sayfasında build 2 seçilip kullanıcı
   onayıyla incelemeye gönderilir.
   Kural: App Intent metinlerine Apple ürün adı yazma. Uygulamanın kendi ekranlarındaki "Mac", "iPhone" serbest.
2. Mac App Store sürümü (universal purchase: aynı kayıt, "Add Platform › macOS"; paket kimliği aynı).
   ✅ iOS 1.0 (build 2) incelemeye gönderildi, "Manually release" seçildi (2026-10-18).
   ✅ Derleme yolu hazır: `scripts/appstore/build-mas.sh` (yükleme için `--upload`). HEAD'den geçici bir
   worktree açar, `mas-transform.py` ile Sparkle'ı, güncelleme ayarlarını, `SU*` anahtarlarını ve Sparkle'ın
   sandbox istisnasını çıkarır; gizlilik bildirimini (`scripts/appstore/PrivacyInfo.xcprivacy`) ve
   değerlendirme isteğini ekler. Ana dal Sparkle'lı kalır (GitHub sürümü değişmez).
   ✅ 1.0 (1) dışa aktarıldı (yüklenmedi): Apple Distribution imzası, Mac App Store profili, iCloud ve push
   Production, sandbox açık, içinde Sparkle yok. Kestirme metinlerinde "Maccy" adı kaldırıldı.
   ✅ 1.0 (1) App Store Connect'e yüklendi (2026-10-18, `MAS_BUILD=1 … --upload`). Sırada: App Store
   Connect'te "Add Platform › macOS", macOS 1.0 sayfası (`APPSTORE.md` §7, `mac-1…5.png`), build seçimi ve
   inceleme notu (Erişilebilirlik izninin neden gerektiği). Sonraki Mac App Store yüklemesi: `MAS_BUILD=2`.
3. iPad: simülatörde test, sonra `TARGETED_DEVICE_FAMILY "1,2"` ve iPad ekran görüntüleri.
4. Sonra: Homebrew cask; bir sonraki Mac sürümünde `CURRENT_PROJECT_VERSION` artırılır (Sparkle sürümleri bu
   numarayla karşılaştırır).

