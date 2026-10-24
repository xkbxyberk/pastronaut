# 1.3 planı: iPhone 1.3 ve Mac 1.3 birlikte (taslak)

> Tarih: 2026-10-23. Durum: **Adım 0–4 bitti (Koşu 6: 74/75, T66 testi düzeltildi ve ayrıca geçti). Sıradaki: commit, Adım 5 (şema Production'a)**
> (tuval: https://claude.ai/artifact/L86xntrWRgjkSfAyegqo8V).
> Bu belge eski `MAC-1.3-PLAN.md`'nin yerini alır. iPhone 1.2'nin kararları ve bulguları (K1–K17)
> `IOS-1.2-PLAN.md`'de kalır. Yayın adımları `SURUM.md`'de.

## Kararlar (kullanıcı, 2026-10-23)
Bu bölüm, belgenin geri kalanıyla çelişirse geçerli olandır.

1. **Tek bir ortak 1.3.** iPhone ve Mac birlikte geliştirilir ve üç kanalda birlikte çıkar. Mac'e özel bir ara sürüm
   yok.
2. **Görseller ve dosyalar ayrı bir bölgede durmaz; her cihaz hepsini indirir** (§2, seçenek C).
3. **Mac iCloud'dan yalnızca kendi kopyalarını siler.** iPhone'dan gelenleri yalnızca kendi geçmişinden kaldırır.
4. **Dosyalar ve PDF'ler de 1.3'te gelir** (§3.1).
5. **Görsel ve dosya ayarları:** kullanıcı "ne mantıklıysa" dedi. Seçimin gerekçesi §3.2'de:
   - Hesap genelinde ortak olanlar: eşitlemenin açık olup olmadığı, en büyük öğe boyutu, iCloud alanı.
   - Cihaza özel olan: görsel kalitesi.
   - Mobil veri ayarı kaldırıldı.
   - Önceden kararlaştırılanlar da geçerli: varsayılan olarak açık, sınır aşılınca öğe silinmez.

## Adım 0 sonuçları (prototip, 2026-10-23)
Prototip: `Prototypes/Media13` (ayrı paket kimlikleri, iCloud Development ortamı, kendi test bölgesi; gerçek veriye
dokunmadı, test bölgesi ve dosyalar silindi). Hepsi Mac'te, geliştirme imzasıyla ölçüldü.

| Soru | Sonuç |
|---|---|
| Motor büyük şifreli dosyaları gönderip alıyor mu? | **Evet.** 10, 25 ve 50 MB (AES-GCM) tek grupta gönderildi, hatasız. 85 MB'ın yüklenmesi 15–60 sn (ağa göre). Ayrı bir uygulamadaki yeni bir motor, veritabanının tamamını çekerken (otomatik eşitlemenin yaptığı gibi) dosyaları **kendiliğinden indirdi**: 6,8 sn. Üçü de açıldı, baytlar aynı. **C kararı tutuyor.** |
| İndirilen dosya ne kadar yaşıyor? | Motor dosyayı uygulamanın `Caches/CloudKit/…/Assets` klasörüne koyuyor. Olaydan sonra ve 10 sn sonra hâlâ duruyordu. Ama bir önbellek klasörü, sistem silebilir: plandaki gibi **olay sırasında hemen kendi depomuza kopyalanır.** |
| Dosya inmeden kayıt gelebilir mi? | **Evet.** Bir denemede kayıt geldi, iki dosyanın indirmesi ayrı ayrı başarısız oldu (CKError 1013 "Fetching asset failed", kısmi hata). Bir sonraki denemede hepsi indi. Tasarıma eklenir: dosyası inmemiş kayıt "dosya bekleniyor" olarak tutulur ve dosya sonra yeniden istenir. |
| Mac, Finder'da kopyalanan dosyanın içeriğini okuyabiliyor mu? | **Evet**, Maccy'nin bugünkü yetkileriyle; yeni bir yetki gerekmiyor. Pano, dosyaya erişimi de veriyor. Ama Masaüstü ve İndirilenler için macOS **klasör başına bir kez izin soruyor** ("… İndirilenler klasörünüzdeki dosyalara erişmek istiyor"). Belgeler için de aynısı beklenir. Sonuç: dosya **kopyalandığı anda** okunur (izin o anki süreç için geçerli). İzin verilmezse dosya "yalnızca bu Mac'te" kalır; Ayarlar ve kurulum rehberi bu pencereyi önceden anlatır. Not: kopya, Finder'ın yazdığı biçimde bir yardımcıyla yapıldı; ilk gerçek ⌘C denemesi Adım 2'de. |
| Mac'e gelen dosya başka bir uygulamaya yapıştırılabiliyor mu? | **Evet.** Dosya uygulamanın kendi klasörüne yazılıp panoya konunca korumalı alandaki başka bir uygulama okudu; Finder'a ⌘V ile PDF olarak yapıştı (kullanıcı denedi). İndirilenler yetkisine gerek yok. |
| Ölçülmeyenler | iPhone'da indirme (motor iOS'ta aynı; hücresel veri ve bellek Adım 4'teki iki cihazlı testte), Mac App Store imzası (korumalı alan kuralları yetkilerle aynı, imza türüyle değişmez). |

Yan bulgu: Yeni bir paket kimliğinin iCloud kapsayıcısında tanınması 10–15 dakika sürdü. Yalnızca yeni hedefler
(prototip, yeni uzantı) için önemli.

## Adım 1 sonuçları (çekirdek, 2026-10-23)
Arayüzsüz; `PastronautCore` 174 test (24'ü yeni, `MediaTests`), `MaccyTests` 109 test geçti; Mac ve iPhone derleniyor.

- **Model:** `Clip.media` (`ClipMedia`: tür, dosyalar, piksel boyutu, tanınan metin). Medya öğesinin metni boş, kimliği
  "media-" ile başlar ve kopyalanan içeriğin özetinden çıkar. `Clip.Kind`'a `image`, `pdf`, `file` eklendi.
- **Şifreleme:** `MediaCipher` (AES-GCM; anahtar hesabın `SyncKey`'inden HKDF ile türer; her dosya kendi öğesine bağlı).
- **Kayıtlar** (şema §4, kesinleşti):
  - `Media`: şifreli `clipID`, `info` (ClipMedia JSON'u), `thumbnail`, `sourceApp`, `sourceAppName`, `collections`,
    `title`; düz `kind`, `sourceDevice`, tarihler, `pinned`, `titleModifiedAt`, `schemaVersion` (3); dosyalar `files`
    (şifreli `CKAsset` listesi). Dosyalar ve küçük resim yalnızca ilk kayıtta gider; sabitleme ya da başlık değişince
    yeniden yüklenmez.
  - `AppIcon`: şifreli `bundleIdentifier`, `name`, `png`; düz `modifiedAt`, `schemaVersion`. Kayıt adı "a-" + anahtarlı özet.
  - `Settings`: şifreli `shared` (SharedSyncSettings JSON'u: gizlilik süzgeçleri ve Görseller ve Dosyalar). Anahtar
    alanına dokunulmaz.
  - JSON alanları eksik alanlara dayanıklı okunur; sonraki sürümler şema değiştirmeden alan ekleyebilir.
- **Cihazdaki depo:** `MediaStore` (öğe başına klasör, dosyalar kendi adlarıyla, `thumbnail.jpg`; iPhone'da App Group).
- **Görsel işleri:** `MediaProcessing` (HEIC'e çevirme ve 4096 px sınırı, ≤ 60 KB JPEG küçük resim, PDF ilk sayfa ve metin).
- **Eşitleme (`ClipSync`):** Medya kayıtları alınır, dosyalar olay sırasında çözülüp depoya yazılır; inmeyen dosya
  "bekliyor" olur ve `fetchPendingFiles` ile tek tek çekilir. Yetişme çekmesi dosyaları atlar (prototiple doğrulandı).
  Alan sınırı ve en büyük öğe sınırı paylaşılan ayarlardan; aşan öğe "yalnızca bu cihazda". iCloud dolarsa
  (`quotaExceeded`) medya o cihazda kalır. Ortak ayarlar en yeni değişiklikle birleşir. Simgeler: `publishAppIcon`,
  `appIcon(for:)`. Mac'in budaması için `dismiss(ids:)` (karar 3): öğe iCloud'da kalır, ancak yeniden kopyalanırsa
  geri gelir.
- **Uygulamalar şimdilik medyayı göstermiyor:** Mac köprüsü ve iPhone listesi medya öğelerini atlıyor (Adım 2 ve 3'te
  açılacak). Henüz hiçbir uygulama medya göndermiyor.

## Adım 2 sonuçları (Mac, 2026-10-23)
`MaccyTests` 118 test (9'u yeni, `SyncMediaTests`), çekirdek 174 test geçti; Mac ve iPhone derleniyor. Gerçek kopyalarla
ve iCloud'la deneme henüz yapılmadı: Debug derlemesi gerçek veriyi açar (kullanıcıya sorulur), asıl deneme Adım 4.

- **Gönderme** (`Maccy/Sync/SyncMedia.swift`): Panodaki görsel (Optimized ise HEIC), PDF verisi ve Finder'da
  kopyalanan dosyalar (kopyalandığı anda okunur; klasörler ve sınırı aşanlar Mac'te kalır) ana iş parçacığı dışında
  okunur, küçük resim ve metin (görselde Vision, PDF'te PDFKit) çıkarılır, gizlilik süzgeçlerinden ve paylaşılan
  sınırlardan geçerse gönderilir. Öğe, gönderildiği kimliği (`com.xkbxyberk.pastronaut.media-id`) yanında saklar;
  yeniden kopyalanınca aynı öğe öne çıkar. Universal Clipboard'dan gelen görseller gönderilmez (gönderen cihaz kendi
  eşitler). 1.3'ten önce kopyalanan görseller ve dosyalar gönderilmez.
- **Alma:** Görsel kendi biçimiyle ve PNG olarak (her uygulama alsın diye), PDF ve dosyalar eşitleme deposundaki
  dosya olarak geçmişe eklenir; dosyaları inmemiş öğe, dosyalar gelince eklenir.
- **Başlıklar:** iPhone'da verilen başlık Mac'te görünür; menüde "Başlık Ekle…", "Başlığı Düzenle…", "Başlığı
  Kaldır" (eşitleme açıkken). Düzenlenen metin başlığını korur.
- **Hatalar:** iCloud'da sabitli öğe, Mac'te sabitleme harfi kalmasa da korunur (geçmiş sınırı silmez). Başka
  cihazda yeniden kopyalanan öğe Mac'te öne çıkar (`History.reorder`).
- **Budama (karar 3):** Geçmiş sınırı ve "Geçmişi sakla" süresi, başka cihazdan gelen öğeleri yalnızca Mac'ten
  kaldırır (`ClipSync.dismiss`); Mac'in kendi kopyalarını iCloud'dan siler.
- **Ortak ayarlar:** Gizlilik anahtarları ve Görseller ve Dosyalar (eşitle, en büyük öğe, iCloud alanı) bütün
  cihazlarda ortak; görsel kalitesi Mac'in kendi ayarı. İlk açılışta iCloud'da hiç değiştirilmemişse Mac'teki eski
  anahtarlar herkesin olur.
- **Simgeler:** Mac, geçmişteki ve yeni kopyalardaki uygulamaların simgelerini (96 px PNG) bir kez gönderir.
- **Ayarlar › Eşitleme:** "Görseller ve Dosyalar" bölümü (kullanılan iCloud alanıyla), metinler Türkçe.
- **Maccy dosyalarına dokunuş:** `History.swift`'te geçmiş sınırı `SyncBridge.pruning` içinde çalışır ve
  `reorder` eklendi (ikisi de "// Pastronaut" işaretli).

## Adım 3 sonuçları (iPhone, 2026-10-23)
Çekirdek 180 test, `MaccyTests` 118 test geçti; iPhone uygulaması ve bütün uzantıları derleniyor. Telefonda göz kontrolü
(`SyncStepTests` adımı `shots13`, yalnızca tanıtım verisi) ve gerçek iCloud denemesi (Adım 4) kaldı.

- **Kutular:** görsel kutuyu doldurur (başlık varsa üstünde şerit), PDF ilk sayfasıyla ve adıyla, dosyalar simgeleriyle;
  inen dosyada dönen gösterge, "yalnızca bu iPhone'da" rozeti. Alt satır türün renginde şerit (`ClipKind.strip`);
  Mac'ten gelen kartta uygulamanın gerçek simgesi.
- **Üst satır:** ortalanmış; "Tümü" yazılı, Mac, iPhone, Görseller, Dosyalar ve Koleksiyonlar simgeli.
- **Liste:** türün renginde etiket, görsel/PDF küçük resmi.
- **Ayrıntı:** görsel Canlı Metin ile (VisionKit), tam ekran Quick Look, İşaretle (düzenlenen kopya yeni öğe olur),
  görseldeki/PDF'teki metin ve "Metni Kopyala", Kopyala, Paylaş, Fotoğraflar'a/Dosyalar'a Kaydet.
- **Menü ve sürükleme:** "Metni Kopyala", dosyaları paylaşma; kartı başka uygulamaya görsel/dosya olarak sürükleme.
- **Kaydetme:** Yapıştır düğmesi görsel/PDF/dosya da alır; "Açılınca Panoyu Kaydet" görsel ve PDF'i de kaydeder (içinde
  kod ya da kart görünen görsel otomatik kaydedilmez); Belge Tara sayfaları PDF olarak da saklar; Paylaş ve Eylem
  fotoğraf, video, PDF ve dosya alır (öğe başına 50 MB; uygulama açılınca iCloud'a gider).
- **Klavye:** görsel ve dosyalar küçük resimle; dokununca panoya kopyalar (Tam Erişim gerekir, yoksa kilit ve açıklama);
  kutuların altında tür şeridi.
- **Ayarlar:** Eşitleme › Görseller ve Dosyalar sayfası (ortak ayarlar, görsel kalitesi, iCloud ve iPhone'da kullanılan
  alan, iCloud'a yeniden yükle); gizlilik anahtarları artık ortak (1.2'deki iPhone anahtarları ilk açılışta herkesin
  olur); "Geçmişi Sakla" (iPhone'un kendi kopyalarını her yerden siler, Mac'tekileri yalnızca iPhone'dan kaldırır).
- **Widget, Kestirmeler, Spotlight:** yalnızca metin öğeleri (görseller bu sürümde orada yok).
- **Yeni izin:** Fotoğraflar'a yalnızca ekleme (`NSPhotoLibraryAddUsageDescription`), TR çevirisiyle.

## Adım 4 sonuçları (iki cihazlı E2E, 2026-10-23)

Medya senaryoları T35–T45 eklendi (`scripts/e2e/sync_e2e.py`; iPhone tarafı `SyncStepTests` autoSaveImage/saveFile,
Mac tarafı E2EControl pinMedia/deleteMedia/pruneMedia/mediaSync).

- **Koşu 1 (150448):** T38, T39, T44 geçti; diğer medya senaryoları düştü. Nedenler betikteydi: iPhone uygulaması
  beklerken kapalıydı (artık `devicectl` ile açık tutuluyor), T41'de işlem adı yanlış yazılmıştı, PDF yalnızca PDF
  olarak kopyalanıyordu (Maccy yalnızca PDF olan panoyu yok sayar; Önizleme PDF'in yanına resmini de koyar).
- **Koşu 2:** T35, T37, T38, T39, T41, T42, T43, T44, T45 geçti. Uygulamada bulunan ve düzeltilen hatalar:
  1. **Mac, PDF'i resmi yüzünden atıyordu.** Önizleme tarzı kopyada resim 27 MB çıktı, sınırı aştı ve PDF'e hiç
     bakılmadı. Artık önce PDF alınıyor (`MediaCapture.read`, test: `testAPDFCopiedWithAPictureOfItIsSentAsThePDF`).
  2. **İkon kayıtları dakikada bir sonsuza dek gönderiliyordu.** iCloud'da eski anahtarla adlandırılmış ikon kayıtları
     vardı; Mac onların sistem alanlarını saklayıp kaydı o adla gönderiyordu, bekleyen kayıt hiç kapanmıyordu.
     Artık başıboş ikon kaydı silinip doğru adla kaydediliyor ve başka bir kaydın sistem alanları kullanılmıyor
     (`ClipSync.base(_:for:)`, `AppIconRecord.isNamed`; test: `strayIconRecordsAndForeignSystemFieldsAreNotUsed`).
  3. **Çakışmada gereksiz yeniden gönderme.** Sunucu bizdekinin aynısını ya da daha yenisini tutuyorsa artık yeniden
     gönderilmiyor (ikon, metin/medya, koleksiyon); birleştirilen sonuç arayüze bildiriliyor
     (`AppIconEntry.replaces`; test: `iconConflictResendsOnlyANewerDifferentIcon`).
- T01'deki tek metin farkı betiğin karakter saymasındandı (Swift harf kümesi sayar); betik artık Swift gibi sayıyor.
- **Koşu 3 (son):** T00–T45 geçti (T36 PDF aynı baytlarla ve metniyle, T40 PDF iğnesi 13 s, T01 62/62); T13 (arka plan sessiz bildirimi) her zamanki gibi WARN. Koşu boyunca ikon döngüsü yok.
- **Koşu 4 hazırlığı (genişletilmiş test):** T46–T70 eklendi. Kapsam:
  - iPhone kapalıyken gelen görsel (+ klavye küçük resmi), Mac kapalıyken gelen görsel
  - çoklu Finder dosyası (Türkçe harf, emoji, virgül adlarda), Largest Item'ı aşan dosya (iki tarafta)
  - aynı içerik iki cihazda tek öğe, görseldeki tek kullanımlık kod
  - medya başlığı (iki yön), koleksiyon, iPhone'da sabitleme ve silme
  - geçmiş sınırıyla gizlenenin geri gelmesi, iki tarafta "yalnızca sabitlenenler"
  - ortak ayar iPhone→Mac ve aynı anda iki cihazdan değişiklik
  - 15 hızlı kopya ve sıra, yeniden kopyalayınca öne çıkma, sil-hemen-kopyala, silme ile kopyalama yarışı
  - aynı anda sabitleme + başlık, boştayken gönderim olmaması (döngü yakalayıcı)
  - iki aynanın alan alan karşılaştırılması, koşu boyunca kayıt hatası
  Koddan önceden şüphelenilenler (koşu doğrulayacak): T57 (Mac'te yalnızca sabitlenenler + görsel: sabitlenince
  gitmiyor olabilir), T58 (iPhone'da yalnızca sabitlenenler: sabitlenen öğe yerel kalıyor olabilir), T60b (ortak
  ayarlar bütün olarak son yazan kazanır; aynı anda iki değişiklikten biri kaybolur).
- **Koşu 4 (2026-10-23 19:39):** 76 senaryodan 66'sı geçti, 8 FAIL, 2 WARN. Bulunan ve düzeltilen uygulama hataları:
  1. **Finder dosyalarının sırası rastgele.** Maccy içerikleri sırasız saklıyor; medya kimliği sıraya bağlı olduğu
     için aynı seçim farklı öğe olabiliyordu. Artık ad sırası (`didAddMedia`).
  2. **T57, Mac "yalnızca sabitlenenler" + görsel:** görsel hiç saklanmıyor, sabitlenince de gitmiyordu. Artık
     yakalanıp bu Mac'te tutuluyor (Mac gizlilik kurallarını ClipSync'e de veriyor), sabitlenince gidiyor.
  3. **T58, iPhone "yalnızca sabitlenenler":** sabitlenen öğe yerel kalıyordu. Artık yalnızca gizlilik kuralı
     yüzünden tutulan öğe, kurala uyunca gönderiliyor (`SyncMirror.stage`; testler
     `pinningAClipHeldBackByPinnedOnlySendsIt`, `pinningAKeptCodeDoesNotSendIt`).
  Test sorunları: T47 (JXA yalnızca ilk dosyayı yazıyordu → `scripts/e2e/copy_files.swift`), T54/T55 (T52'ye
  bağlıydı), T01 (bekleme sırasında iPhone uygulaması kapalıydı). T52/T66 iPhone'da başlık ara sıra kayboluyor;
  elle 4 denemede yeniden üretilemedi, adım artık yazılanı raporluyor. **Karar bekleyen:** T60b, ortak ayarlar
  bütün olarak son yazan kazanır; iki cihazdan aynı anda farklı anahtar değişirse biri kaybolur.
- **T60b kararı (kullanıcı, 2026-10-24):** her ortak ayar kendi değişiklik tarihiyle birleşir
  (`SharedSyncSettings.fieldModifiedAt`, `merged(with:)`, `stamp(changesSince:at:)`; 3 yeni test). Alan tarihi olmayan
  kayıtlar `modifiedAt` ile okunur.
- **Koşu 5 (2026-10-24 00:55):** 70 geçti. Koşu 4'ün düzeltmeleri doğrulandı (T47, T52, T54, T55, T57'de sabitlenince
  5 s'de iPhone'da, T58, T60b). Düşenler test kaynaklı: başlık penceresinde iki "Kaydet" (biri klavye tuşu; ara sıra
  başlık kaybının nedeni buydu), T57 yerel kalan kaydı iCloud'da sanıyordu, T60 birleştirilmiş ayarın yeniden
  gönderimini (CKSyncEngine ~36 s bekletti) beklemiyordu, T00b/T66'da test çalıştırıcısı başlamadı. Test düzeltildi;
  doğrulama koşusu (Koşu 6) bekliyor.
- **Koşu 6 (2026-10-24 02:02):** 74 geçti, T13 WARN (her zamanki gibi). Tek FAIL T66: Mac'in sabitlemesi iPhone'da
  menü açılırken geldi, satır Sabitlenenler'e taşındı ve menü kapandı ("title action missing"); veri kaybı yok. Test,
  iki değişikliği iCloud'da çakıştıracak şekilde yeniden yazıldı ve tek başına iki cihazda geçti (ikisinde de
  sabitli + başlıklı). **Adım 4 bitti.**

## iPhone filtre çubuğu (2026-10-24, kullanıcı kararı: C2)

Tasarım tuvali: https://claude.ai/artifact/5FSzpfhWsBi7qESDL11Y3c (C2 seçildi).
- Kapsülde Tümü / Mac / iPhone; yanında filtre düğmesi. Menüde **Tür ›** alt menüsü (uygulamanın bütün türleri,
  içinde öğe olmayanlar gizli; PDF ve Dosya ayrı), koleksiyonlar, Yeni Koleksiyon, seçiliyken Yeniden Adlandır /
  Dışa Aktar / Sil ve "Filtreleri Temizle".
- Kaynak, tür ve koleksiyon birlikte seçilir (`HistoryScope` artık üç alanlı bir yapı). Seçilenler çubuğun altında
  kaldırılabilir etiket olarak görünür.
- Aramadaki tür önerileri aynı tür filtresidir (`SearchChip`): aramada seçmek menüde de seçer. Mac'in arama
  belirteçleri değişmedi.
- **Hata düzeltmesi:** menü `glassEffect`/`glassEffectID` ile cam kabın içindeydi; çubuğun altındaki dokunuşlar
  listeye gidiyordu. Artık sistem menüsü + cam düğme stili. Kanıt: `menuProbe` adımı (satırın 5 noktasına
  dokunma, 5/5 seçildi), `filterCheck` adımı (tür, birleşim, etiket, temizle), `filterShots` ekran görüntüleri.
- iPad kenar çubuğu: Kaynak, Tür, Koleksiyonlar bölümleri.
- 2026-10-24 düzeltmeleri: çubuk inceldi (kapsül 38 pt, filtre düğmesi 34 pt); Tümü simge + ad, Mac ve iPhone
  yalnızca simge (VoiceOver adlarını okur). Kaynak kapsülünde parmak kaydırılarak seçilir: mercek parmağı izler,
  bırakınca en yakına oturur, seçenek değişince hafif titreşim (`SourcePicker`; test `sourceSlide`). Yapıştır
  düğmesi artık her sonucu bildiriyor ("Panodan kaydedildi" vb.); önce sessiz kaydediyordu.
- Yapıştır "+" menüsüne taşındı (kullanıcı kararı C): "+" dokununca menü açar (Yapıştır, Yazarak Ekle, Metni Tara,
  Belge Tara); Yapıştır yalnızca panoda bir şey varken görünür (pano içeriği okunmadan, `changeCount` ve
  `numberOfItems` ile). Üstteki mavi düğme kalktı. **Açık:** sistem Yapıştır düğmesinin menü içinde izin penceresi
  açmadan çalıştığı Apple'ca belgeli değil; kullanıcı telefonda elle deneyecek. Pencere çıkarsa yedek plan: düğme
  "+"nın yanında, yine yalnızca panoda bir şey varken.
- Kullanıcı denedi (2026-10-24): menüdeki Yapıştır izin penceresi açmadan yapıştırıyor; kaydırmalı filtre doğru.
  Bulunan hata: Safari'den kopyalanan bağlantı `bplist00…` önekiyle kaydediliyordu (bağlantı bir property list
  içinde geliyor, bayt olarak okunuyordu). `MediaIntake.webURL(fromURLItem:)` listeyi açıyor; test
  `linksCopiedAsPropertyListsArePastedAsTheirAddress`.

## Kurulum rehberi ve Mac ayarları (2026-10-24, kullanıcı kararları)

Tuval: https://claude.ai/artifact/Gbwuweu2E3QmnUV3bCAiGX
- **iPhone kurulum (Klavye A):** adım başına tek görev ve duruma göre değişen alt düğme; kaydırmadan görünür.
  Klavye: Ayarlar ("Ayarlar'ı Aç") › Dene ("Pastronaut Klavyesini Dene", alan + küre tuşu ipucu; 8 sn sonra
  Tam Erişim ipucu) › Hazır ("Devam"). "Neden Tam Erişim?" ayrı sayfada. "Şimdilik Geç" her aşamada.
- **Yapıştır adımı:** "Açılınca Panoyu Kaydet" üstte; açıksa İzin Ver › Kontrol › Hazır. Uygulama içi kopyayla
  deneme yapılamaz (iOS kendi kopyasını okurken izin sormaz); bunun yerine dönüşte kendiliğinden kontrol ve
  Pastronaut'un kendi kopyasını tanıma (`ClipboardTrial.ownCopy`). "Zaten İzin Verdim, Kontrol Et" kısayolu.
- **Mac çubuğu:** simgeli kaynak kapsülü (Tümü adıyla), filtre menüsünde Tür › (görsel, PDF, dosya dahil),
  koleksiyonlar, Sabitlenenler/Bugün/Bu Hafta, Filtreleri Temizle; seçilenler aramanın altında etiket
  (`History.kindFilter`, `ActiveFilterChips`).
- **Mac Gelişmiş:** `PastronautAdvancedPane` (Maccy'nin sayfası dosyada duruyor, ayarlar listesinde yerine bu):
  Kopyalamayı Duraklat, Yalnızca Sonraki Kopyayı Yok Say, kısayol satırı, komutlar kapalı bölümde kopyalama
  düğmeleriyle, temizleme seçeneklerine açıklama.
- Testler: iOS `OnboardingFlowTests` (yeni akış), `setupShots`; Mac `testPastronautFilterMenu` (alt menü,
  etiket), `testPastronaut13Shots` (Gelişmiş). PT_DEMO'da gizlilik örtüsü kapalı (Xcode test kaydı örtüyü
  açıyordu).

## 0. Kısaca
- **Sürümler:** 1.3 = iPhone 1.3 (derleme 5) + Mac 1.3 (derleme 2).
  - Mac 1.3, Mac App Store'a ve GitHub'a aynı numarayla çıkar.
  - GitHub kullanıcıları 0.1.0'dan doğrudan 1.3'e geçer.
- **Ana iş: görseller, dosyalar ve PDF'ler.** Yanında şunlar gelir:
  - görseldeki ve PDF'teki metin,
  - kartta kaynak uygulamanın simgesi,
  - gizlilik ayarlarının eşitlenmesi,
  - Mac'te başlıklar, K3 ve Mac hataları,
  - iPhone'da sürükle-bırak ve saklama süresi.
- **İş sırası:** prototip → çekirdek → Mac → iPhone → iki cihazlı test → şema → mağaza → üç kanalda yayın (§5).

## 1. Başlangıç noktası (2026-10-23)

| Kanal | Yayında | Sıradaki |
|---|---|---|
| iPhone (App Store) | 1.2 (4) | **1.3 (5)** |
| Mac App Store | 1.0 (1) | **1.3 (2)** |
| Mac GitHub (Sparkle) | 0.1.0 (1), etiket `v0.1.0` → `1d72abe` | **1.3 (2)** |

- **Mac'in iki kanalı:** aynı kaynaktan, aynı derleme numarasıyla çıkar.
  - Ana dal Sparkle'lıdır. `scripts/appstore/build-mas.sh`, Sparkle'ı yalnızca geçici bir kopyada çıkarır.
  - Her Mac sürümünde iki derleme vardır: Developer ID + notarize + appcast, ve App Store paketi.
  - Sparkle güncellemeyi derleme numarasıyla anlar: 2 > 1.
- **0.1.0'dan beri Mac'i etkileyen değişiklikler az:** Kestirme metinlerinden Maccy adı kaldırıldı (`5d2c31f`) ve Mac
  App Store betiği eklendi. 1.3 sürüm notu 0.1.0 → 1.3 atlamasını açıklar.
- **Mac uygulaması iki kanalda da korumalı alanda (sandbox) çalışıyor** (`Maccy/Maccy.entitlements`). Bu, dosyalar
  için önemli (§3.1).

## 2. Görsellerin ve dosyaların iCloud'daki yeri (karar: C)

**Neden eski plan değişti:**
- 1.2 planına göre tam boy dosyalar ayrı bir `Blobs` bölgesinde duracak, yalnızca açılınca inecekti.
- Eşitleme motorumuz (CKSyncEngine) otomatik çalışıyor ve özel veritabanındaki **her bölgeyi** çekiyor
  (`ClipSync.swift`, `handleFetched`).
- Bir bölgeyi dışarıda bırakma seçeneği yalnızca elle çağrılan `fetchChanges`'te var.

**Seçenekler ve karar:**
- A: ayrı bir iCloud kapsayıcısı.
- B: otomatik eşitlemeyi kapatmak.
- **C (seçildi): Her şey `Library` bölgesinde durur ve her cihaz her şeyi indirir.**

**C'nin sonuçları:**
- **Basit:** Yeni bir kapsayıcı, yetki ya da ikinci bir şema yok. Çalışan eşitleme düzeni değişmez.
- **Her cihaz iCloud'daki görsel ve dosyaların tamamını indirir.** Üst sınırı "iCloud Alanı" ayarı belirler (varsayılan
  1 GB). Bu yüzden ayarın "sınırsız" seçeneği kaldırıldı (§3.2).
- **Mobil veri:** Uygulamanın içinden kapatılamaz, çünkü indirmeyi motor kendisi yapar. Kullanıcı isterse iOS
  Ayarlar › Hücresel'den Pastronaut için kapatır. Ayarlar ekranında bu yazar.
- **Güncellenmemiş cihazlar:** Mac 1.0 ve iPhone 1.2 de bu kayıtları indirir, sonra yok sayar. Hesaptaki bir cihaz 1.3'e
  geçip görsel göndermeye başlarsa, güncellenmemiş cihaz her yeni görseli bir kez boşuna indirir. Bozulma olmaz; iki
  sürümün aynı gün yayınlanması bu süreyi kısaltır.
- **Bekleme süresi:** Motor indirdiği dosyayı geçici bir yere koyar. Dosya olay işlenirken hemen kendi depomuza
  kopyalanmalı.
- **Uçtan uca şifreleme:** Dosyalar yüklenmeden önce kendi anahtarımızla AES-GCM ile şifrelenir. `encryptedValues` dosya
  alanını (`CKAsset`) kabul etmez.

## 3. Kapsam

### 3.1 Görseller, dosyalar ve PDF'ler (iki taraf)

**Kullanıcı ne görür:**
- Mac'te kopyaladığı ekran görüntüsü, PDF ya da Finder'da kopyaladığı dosya birkaç saniye içinde iPhone'da kart olarak
  görünür.
- iPhone'da kopyaladığı ya da Paylaş/Eylem ile kaydettiği fotoğraf veya belge Mac'in geçmişine düşer.

**Kayıt:**
- `Library` bölgesinde yeni bir `Media` kayıt türü.
  - Şifreli alanlar: küçük resim (en fazla 60 KB), tanınan metin, dosya adları, kaynak uygulama, başlık, koleksiyonlar.
  - Düz alanlar: tür (görsel, PDF, dosya), biçim (UTI), piksel boyutu, bayt boyutu, cihaz, tarihler, sabitlenmiş mi,
    şema sürümü.
  - Dosyalar: kendi anahtarımızla şifrelenmiş bir `CKAsset` listesi.
- **Birden çok dosya:** Bir kopyada birden çok dosya varsa tek bir öğe olur (Maccy'nin bir öğesi gibi). Toplam boyut en
  büyük öğe sınırına tabidir.
- **Kimlik:** Metinlerdeki `Clip.id` kuralı gibi içeriğin özetinden çıkar. Kayıt adı anahtarla üretilir.
- **Eski istemciler:** Mac 1.0 ve iPhone 1.2 bu türü yok sayar (`ClipSync.apply`, `default: break`). Bu kayıtları silmez,
  değiştirmez.
- **Çekirdek modeli:** `Clip` medyayı nasıl taşıyacak, Adım 1'de belirlenir. Mevcut `Clip` kaydının biçimi değişmez.
- **Klasörler eşitlenmez.** Sınırı aşan dosyalar (ör. büyük videolar) yalnızca o cihazda kalır.

**Mac:**
- **Bugün:** `SyncBridge.syncableText` görsel ya da dosya içeren her kopyayı atlıyor.
- **Görsel:** Panodaki görsel verisi gönderilir. Kalite "Optimized" ise önce HEIC'e çevrilir.
- **PDF:** Panodaki PDF verisi gönderilir (ör. Önizleme'den kopyalanan).
- **Finder'da kopyalanan dosya:** Panoda dosyanın içeriği değil, yalnızca yolu var.
  - İçerik **kopyalandığı anda** okunur. Bugünkü yetkiler yetiyor (Adım 0).
  - Masaüstü, İndirilenler ve Belgeler için macOS klasör başına bir kez izin sorar. İzin yoksa dosya "yalnızca bu
    Mac'te" kalır.
- **Gelen öğe:**
  - Görsel ve PDF, Maccy geçmişine panodaki gibi eklenir.
  - Dosya, uygulamanın kendi klasörüne yazılır ve öğe o dosyayı gösterir. Yapıştırılınca dosya olarak gider (Adım 0'da
    doğrulandı: Finder ve korumalı alandaki başka bir uygulama).
  - "iPhone'dan" işareti korunur.
- **Yok sayma kuralları:** Maccy'nin yok sayılan uygulama, tür ve düzenli ifade kuralları görseller ve dosyalar için de
  geçerli. Bunun testi zorunlu.

**iPhone:**
- **Yakalama:**
  - Yapıştır düğmesi ve "Açılınca Panoyu Kaydet": görsel ve PDF.
  - Paylaş ve Eylem uzantıları: fotoğraflar, PDF'ler ve dosyalar; birden çok öğe olabilir.
  - Belge Tara: tanınan metnin yanında PDF olarak da kaydedilir.
  - Klavye: Tam Erişim varsa panodaki görsel.
- **Gösterme:**
  - Görsel kartı, PDF kartı (ilk sayfa), dosya kartı (simge, ad, boyut).
  - Ayrıntı ekranında QuickLook önizlemesi; Dosyalar'a kaydetme ve paylaşma.
  - Görsellerde Canlı Metin (metin seçme) ve QuickLook ile işaretleme. İşaretlenen görsel yeni bir öğe olur.
- **Klavye:**
  - Yalnızca küçük resimleri okur (bellek sınırı, K8).
  - Dokununca öğe panoya gider; bunun için Tam Erişim gerekir, yoksa bir açıklama çıkar.
  - Dosya bir metin alanına yazılamaz.
- **Widget'lar:** Son görselin küçük resmi.
- **Sürükle-bırak:** `Clip` için `Transferable`; metin, bağlantı, görsel ve dosya olarak.

### 3.2 Ayarlar › Görseller ve Dosyalar (iki uygulamada da)

| Ayar | Seçenekler | Varsayılan | Kimin |
|---|---|---|---|
| Görselleri ve Dosyaları Eşitle | açık / kapalı | **açık** | **Ortak** (hesap) |
| Görsel Kalitesi | Optimized (HEIC, uzun kenar en fazla 4096 px) / Original | **Optimized** | **Bu cihaz** |
| En Büyük Öğe | 5 / 10 / 25 / 50 MB | **10 MB** | **Ortak** |
| iCloud Alanı | 500 MB / 1 GB / 2 GB / 5 GB | **1 GB** | **Ortak** |

**Gerekçeler:**
- **Eşitle ortak:** Her cihaz her şeyi indirdiği için cihaz başına bir "kapalı" düğmesi indirmeyi durduramaz; yalnızca
  göndermeyi durdururdu. Bu yanıltıcı olur. Kapatınca hiçbir cihaz yeni görsel ya da dosya göndermez. iCloud'dakiler
  kalır; istersen öğeleri silebilirsin.
- **iCloud Alanı ortak:** Bu değer artık her cihazdaki disk kullanımının da üst sınırı. İki cihazın farklı sınırları
  olamaz. "Sınırsız" seçeneği kaldırıldı.
- **En Büyük Öğe ortak:** iCloud'a neyin gireceğini belirliyor. Bir cihazın 50 MB, ötekinin 10 MB göndermesi alanı
  tutarsız doldurur.
- **Kalite cihaza özel:** Gönderen cihazın tercihi. Mac'te tasarım için "Original", iPhone'da "Optimized" mantıklı
  olabilir.
- **Mobil Veri ayarı kaldırıldı** (§2). Yerine iOS'un kendi Hücresel ayarı anlatılır.

**Ortak ayarların yeri ve kuralları:**
- Ortak ayarlar `Settings` kaydında, şifreli alanlarda durur; son değişiklik geçerli olur.
- **Sınır aşılınca** (önceki karar): Öğe silinmez; o cihazda "yalnızca bu cihazda" olarak kalır ve bir kez bilgi verilir.
- **Alan nasıl boşalır:** Alanı Mac'in geçmiş sınırı (yalnızca kendi kopyaları, karar 3) ve iPhone'un saklama süresi
  boşaltır. Kullanıcı öğe silerek de boşaltabilir.

### 3.3 Görseldeki ve PDF'teki metin (iki taraf)
- **Mac:**
  - Maccy görseldeki metni zaten tanıyor (`HistoryItem.recognizeText`). Bu metin `Media` kaydının şifreli
    `recognizedText` alanına yazılır.
  - PDF'lerin metni PDFKit ile alınır.
  - Maccy'nin yerel başlık olarak kullandığı OCR metni eşitlenmez.
- **iPhone:**
  - Görsellerde çekirdekteki `TextRecognition` (Vision) bir kez çalışır.
  - PDF'lerin metni PDFKit ile alınır.
- **Arama:** İki tarafta da bu metni tarar. Türkçe kurallar (ı/i, aksan) burada da geçerli.
- **Gizlilik:** Tanınan metinde kod ya da kart numarası varsa aynı süzgeçler uygulanır.
  - Gizlilik ayarı açıksa böyle bir öğe gönderilmez.
  - "Süzülmemiş içerik eşitlenemez" kuralının testi bu öğeler için de yazılır.

### 3.4 Kartta kaynak uygulamanın simgesi (iki taraf)
- iPhone, kendi kopyalarının hangi uygulamadan geldiğini bilemez; başka uygulamaların simgelerini de alamaz. Simgeyi
  yalnızca Mac gönderebilir.
- **Yeni `AppIcon` kaydı** (`Library` bölgesi):
  - Her uygulama için bir kez yazılır.
  - İçinde şifreli küçük bir PNG (ör. 96 px) ve uygulamanın adı bulunur.
  - Kayıt adı, paket kimliğinin anahtarlı özetidir.
- iPhone simgeyi önbelleğe alır ve Mac'ten gelen kartlarda gösterir. Simge yoksa bugünkü cihaz rozeti kalır.
- Mac'teki kartlarda simge zaten var (Maccy).

### 3.5 Gizlilik ayarlarının eşitlenmesi (iki taraf; K7, A6)
- Şu anahtarlar `Settings` kaydında şifreli alanlar olur: "Kodları eşitleme", "Kartları eşitleme", "Yalnızca
  sabitlenenler".
  - Her cihaz yazabilir; son değişiklik geçerli olur.
  - İki uygulama da bu ayarları kendi yakaladıklarına uygular.
- **Eski istemciler bu alanları silmez:** `Settings` kaydını yalnızca anahtar henüz yokken yazıyorlar
  (`SettingsRecord.fetchOrCreateKey`).

### 3.6 Yalnızca Mac
- **Başlıklar:**
  - iPhone'da verilen `title`, Maccy'nin başlığında görünür.
  - Mac'ten de başlık verilebilir (`Clip.setTitle`).
  - Mac'te metin düzenlenince (`SyncBridge.didEdit`) yeni öğe başlığı `takeTitle(from:)` ile taşır.
- **K3:** Silinen öğe geri gelmez. Çekirdekte hazır; Mac'te test edilir.
- **Budama (karar 3):**
  - Mac'in geçmiş sınırı yalnızca Mac'in kendi kopyalarını iCloud'dan siler.
  - iPhone'dan gelen öğeleri yalnızca Mac'in geçmişinden kaldırır; bu öğeler iCloud'da ve iPhone'da kalır.
  - Sonra yeniden gelmemeleri gerekir, yani Mac bunları "burada gizli" diye hatırlar. Bu bir test gerektirir.
  - Not: Yayındaki Mac 1.0 eski davranışla çalışmaya devam eder; düzeltme Mac 1.3 ile gelir.
- **Hatalar:**
  - **Sabitleme kaybı:** Mac'te boş sabitleme harfi kalmayınca uzaktan sabitlenen öğe sabitsiz ekleniyor
    (`SyncBridge.insert`).
  - **Sıralama:** Uzaktan gelen güncellemede yalnızca sabitleme uygulanıyor, `lastCopiedAt` uygulanmıyor
    (`SyncBridge.apply`). Bu yüzden iPhone'da yeniden kopyalanan öğe Mac'te öne çıkmıyor.
- **İsteğe bağlı:** Kurulum rehberine Mac adımı.

### 3.7 Yalnızca iPhone
- **Saklama süresi ayarı:** iPhone geçmişine bir sınır (K8). Görseller ve dosyalar için iCloud alanını da boşaltır.
- **Klavyenin hafif anlık görüntüsü:** Önce Instruments ile bellek ölçülür, karar sonra verilir.
- **1.2'den kalan küçük işler:** K14 (İngilizce çoğullar), K16 (önizleme önbelleğinin temizlenmesi: `CachePruner` var,
  yalnızca bağlanacak).

### 3.8 1.3'te olmayanlar
- Paylaşılan koleksiyonlar (CKShare)
- iPad
- ⌘ kısayolları
- Canlı Etkinlik ile sıra

## 4. Şema eklemeleri (Production'a eklenir, geri alınamaz)

| Nerede | Ne |
|---|---|
| `Library` bölgesi | `Media` kayıt türü (§3.1, §3.3), `AppIcon` kayıt türü (§3.4) |
| `Settings` kaydı | Ortak görsel ve dosya ayarları (§3.2) ve gizlilik ayarları (§3.5), şifreli |

- Yeni kapsayıcı ya da yeni bölge yok (karar 2).
- Kayıt türleri önce Development ortamında oluşur; iki cihazlı test onları yazar.
- Production'a sen gönderirsin. Bu, ilk 1.3 derlemesi App Store Connect'e yüklenmeden önce yapılmalı.
- Alan adları ve türleri Production'a gittikten sonra değişmez. Bu yüzden Adım 1'de testlerle sabitlenir.

### Adım 5 kontrol listesi: CloudKit Console (2026-10-24)

Kapsayıcı `iCloud.com.xkbxyberk.pastronaut`. Production'a giden alan ve tür geri alınamaz.
1. Development › Schema › Record Types'ta prototipten kalan `ProtoMedia` varsa sil (ProtoMedia13 bölgesi
   silinmişti, kaydı yok). Production'a gitmemeli.
2. Development'ta beklenenler (E2E hepsini yazdı):
   - `Media`: clipID (Encrypted String), info (Encrypted Bytes), thumbnail (Encrypted Bytes), sourceApp,
     sourceAppName, title (Encrypted String), collections (Encrypted String List), kind, sourceDevice (String),
     firstCopiedAt, lastCopiedAt, modifiedAt, titleModifiedAt (Date/Time), pinned, schemaVersion (Int(64)),
     files (Asset List).
   - `AppIcon`: bundleIdentifier, name (Encrypted String), png (Encrypted Bytes), modifiedAt (Date/Time),
     schemaVersion (Int(64)).
   - `Settings`: yeni alan shared (Encrypted Bytes); idKey zaten Production'da.
3. Deploy Schema Changes… özetinde yalnızca bunlar olmalı: yeni türler Media, AppIcon; Settings.shared. Başka
   bir şey görünürse yayınlamadan dur.
4. Deploy; sonra Production › Record Types'ta Media, AppIcon ve Settings.shared'ı doğrula.
5. Sıra: ilk 1.3 derlemesi App Store Connect'e yüklenmeden önce. Dizin (index) gerekmez: eşitleme sorgu
   kullanmıyor, bölge değişikliklerini çekiyor.
- **Sonuç (2026-10-24):** kullanıcı ProtoMedia'yı Development'tan sildi, Deploy özetinde yalnızca Settings'te 1 alan,
  Media ve AppIcon türleri, 4 + 18 dizin ve üç rolün izinleri vardı. Production'da Media (22), AppIcon (11),
  Settings (idKey, shared) doğrulandı. **Adım 5 tamam.**

## 5. İş sırası
Her adımın sonunda commit ve kısa bir rapor olur.

0. **Prototip (1–2 gün; gerçek veriye dokunmaz).** `Prototypes/Faz0` üzerinde şunlar ölçülür:
   - Motor 10 ve 50 MB'lık şifreli bir dosyayı gönderip alıyor mu? Ne kadar sürüyor? İndirilen geçici dosya ne kadar
     yaşıyor?
   - Mac'te korumalı alandaki uygulama, Finder'da kopyalanan bir dosyanın içeriğini okuyabiliyor mu (Developer ID ve Mac
     App Store imzalarıyla)?
   - Mac'te gelen bir dosya, başka bir uygulamaya dosya olarak yapıştırılabiliyor mu?
   - Sonuçlar dosyalarla ilgili yolu belirler (§3.1). Sorun çıkarsa sana seçenek getiririm.
1. **Çekirdek (arayüzsüz):**
   - Yapılacaklar: medya modeli, şifreleme, küçük resim üretimi, PDF metni, kayıt eşlemeleri, alan sınırı, simge kaydı,
     ortak ayar alanları.
   - Testler:
     - Eski istemcilerle uyum.
     - Gizlilik süzgeçleri (§3.3).
     - Sınır aşımı, şifre çözme hatası.
     - Mac budamasının iPhone öğelerini iCloud'dan silmemesi (karar 3).
2. **Mac:**
   - Yapılacaklar: görsel, PDF ve dosya gönderme ve alma, Ayarlar › Görseller ve Dosyalar, simge gönderme, başlıklar, K3,
     budama ve hatalar (§3.6), gizlilik ayarları, yok sayma kuralları.
   - Testler: `MaccyTests`.
3. **iPhone:**
   - Yapılacaklar: App Group'ta yerel medya deposu, kartlar, ayrıntı ekranı ve QuickLook, klavyede küçük resim, Paylaş ve
     Eylem'de görseller ve dosyalar, Belge Tara ile PDF, widget, sürükle-bırak, metin tanıma, Ayarlar › Görseller ve
     Dosyalar, saklama süresi.
   - Arayüz için önce bir tasarım önerisi (1.2'deki gibi bir tuval) gelir; kod onaydan sonra yazılır.
4. **İki cihazlı uçtan uca test:**
   - Mevcut 35 adım ve yeni senaryolar: görsel, PDF ve dosya iki yönde, büyük öğe, alan sınırı, silme, iCloud silme, Mac
     budaması, eski istemci.
   - Önce sana sorulur: Debug derlemesi gerçek veriyi açar.
5. **Şema:** Development'tan Production'a sen gönderirsin.
6. **Mağaza:**
   - Gizlilik politikası güncellenir: görseller, dosyalar, metin tanıma, uygulama simgeleri, her cihazın her şeyi
     indirmesi.
   - What's New, iPhone ve Mac ekran görüntüleri (`PT_DEMO` ile), inceleme notları.
   - App Privacy etiketi "Data Not Collected" olarak kalır, çünkü veri kullanıcının kendi iCloud'unda durur.
7. **Yayın** (`SURUM.md`):
   - Numaralar: iPhone 1.3 (5), Mac 1.3 (2).
   - App Store Connect'e yükleme yalnızca sen "yükle" deyince yapılır.
   - İki App Store sürümü de "Manually release" ile incelemeye gönderilir. İkisi de onaylanınca aynı gün yayınlanır.
   - GitHub Release ve appcast en son, senin onayınla.
