# 1.3 planı: iPhone 1.3 ve Mac 1.3 birlikte (taslak)

> Tarih: 2026-10-23. Durum: **Adım 0 (prototip) ve Adım 1 (çekirdek) bitti; Adım 2 (Mac) onay bekliyor.**
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
