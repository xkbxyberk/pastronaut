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

**iPhone 1.1 (build 3), 2026-10-20:** kurulum rehberi, uygulama içi dil (TR/EN) ve tema, açılışta anında
geçmiş, "↑ yeni" düğmesi ve "Eşitleniyor…" rozeti, Tam Erişim tespiti düzeltmesi; önizlemeler ve "Açılınca Panoyu
Kaydet" varsayılan açık. Yalnızca iPhone kanalı (Mac değişmedi). Durum: ✅ App Store Connect'e yüklendi
(2026-10-20; 1.0 o sırada "Ready for Distribution", macOS 1.0 "Waiting for Review"). Sıradaki adımlar:
1. ✅ Gizlilik politikası güncellendi ve yayınlandı (gh-pages `288c2ed`, 2026-10-20): 1.1'den itibaren önizlemeler
   ve "Açılınca Panoyu Kaydet" varsayılan açık, 1.0'da kapalı; İngilizce ve Türkçe, "Son güncelleme" 20 Ekim.
2. 1.0'ın durumu: "Pending Developer Release" ise önce yayınlanır; sonra iOS App › "+" › 1.1.
3. ✅ Build 3 yüklendi; TestFlight'ta denendi, 1.1 sayfası dolduruldu ve incelemeye gönderildi (2026-10-20,
   "Manually release").
4. ✅ **iPhone 1.1 (3) onaylandı ve App Store'da yayında** (kullanıcı, 2026-10-22).
5. ⏳ **Mac App Store 1.0 (1): "In Review"** (2026-10-22). Onay gelince yayınlanır; ret gelirse düzeltme 1.0 (2).

**iPhone 1.2 (build 4), hazırlık 2026-10-22.** Yalnızca iPhone kanalı; plan `IOS-1.2-PLAN.md`. Mac işleri ayrı:
`MAC-1.3-PLAN.md` (Mac'in sıradaki görünen sürümü 1.3, derleme 2).
1. ✅ CloudKit şemasında `Clip.title` ve `Clip.titleModifiedAt` (ve `titleModifiedAt` için queryable/sortable
   dizinleri) Production'a gönderildi (kullanıcı, 2026-10-22; Production'da doğrulandı).
2. ✅ `MARKETING_VERSION` 1.2, `CURRENT_PROJECT_VERSION` 4 (`iOS/project.yml`). Release derlemesi hatasız; uygulama
   ve beş uzantının hepsi 1.2 (4) ve gizlilik bildirimli; Kestirme metinlerinde Apple ürün adı yok (ITMS-90626).
3. ✅ Mağaza metinleri `APPSTORE.md`: iPhone açıklaması (§6), What's New 1.2 (§8), inceleme notu 1.2 (§13: kamera
   yalnızca tarama için, Eylem uzantısı, ekran kaydı örtüsü), App Privacy notu (§10, hâlâ "Data Not Collected").
4. ✅ Gizlilik politikası yayında (gh-pages `ecae837`, 2026-10-22; kamera, başlıklar, iPhone gizlilik seçenekleri,
   Eylem uzantısı).
5. ✅ Ekran görüntüleri (2026-10-22): yeni tasarımla 10 kare, İngilizce ve Türkçe (`storeShots12` + `StoreArt`,
   yalnızca tanıtım verisi); `APPSTORE.md` §9. Kullanıcı 1.2 sayfasında eski yedi görselin yerine yükler.
6. ⏳ Kullanıcı "yükle" deyince arşiv ve yükleme (`SURUM.md` kanal 1). Eylem simgesi saydam (şablon); App Store
   doğrulaması bunu kabul etmezse burada görülür.
7. ⏳ Kullanıcı: App Store Connect › iOS App › "+" › 1.2; What's New ve inceleme notu; TestFlight'ta deneme (Production'da
   başlık ver, Ayarlar › Eşitleme'de hata yok; Metni Tara; Pastronaut'a Kaydet); build seçimi ve incelemeye gönderme.

**Sürüm kuralı (2026-10-18'den sonra):** her sürüm üç kanalda çıkar (iPhone, Mac App Store, Mac GitHub/Sparkle);
adımlar `SURUM.md`'de. Görünen sürüm: iPhone 1.1, Mac 1.0 (Mac'in sıradaki sürümü en az 1.2). Sıradaki derleme
numaraları: iPhone **4**, Mac **2** (Mac App Store ve GitHub ortak). Mac GitHub kullanıcıları hâlâ 0.1.0'da; bir sonraki Mac sürümüyle
GitHub'a da 1.0.x çıkar.

