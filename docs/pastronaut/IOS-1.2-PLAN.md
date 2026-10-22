# iPhone 1.2+ planı: Faz 1 (keşif, doğrulama, mimari yol haritası)

> Tarih: 2026-10-22. Durum: **kararlar alındı (aşağıda), Faz 2 onayı bekleniyor.** Bu belge üretim koduna
> dokunmadan hazırlandı.
> Kaynaklar: `research/paste-ios.md` ve `research/paste-ozet.md` (2026-10-17), `TASARIM.md` §8–9, kod tabanının
> üç alt ajanla taranması (veri/eşitleme, iOS uygulaması, uzantılar). En ağır bulgular ayrıca kodda elle doğrulandı.
> Paste için yalnızca kendi açık kaynaklarındaki işlev bilgisi kullanıldı. Ad, terim, görünüm ve metin alınmadı.

---

## Kararlar (2026-10-22, kullanıcı)

Bu bölüm, belgenin geri kalanında çelişen her şeyin önüne geçer.

1. **iPhone 1.1 App Store'da yayında.** 1.2 bunun üzerine kurulur. Sıradaki iPhone derlemesi 4.
2. **Mac işleri ayrı bir planda:** `MAC-1.3-PLAN.md`. 1.2 yalnızca iPhone'dur.
   - Sürüm kuralı (`SURUM.md`): iPhone 1.2'yi tek başına çıkarırsa Mac bu numarayı atlar. Mac'in sıradaki sürümü
     **1.3** olur.
   - Görseller **iPhone 1.3 ve Mac 1.3**'te birlikte gelir (üç kanal).
3. **K1:** Bulut silinince ya da iCloud'dan çıkılınca öğeler iPhone'da **"Yalnızca bu iPhone'da"** olarak kalır.
   - Ayarlar'da **"iCloud'a Yeniden Yükle"** düğmesi olur.
   - Kendiliğinden yüklenmez. Hesap değiştiyse eski hesabın öğeleri yeni hesaba kullanıcı istemedikçe gitmez.
4. **K1–K3 ayrı bir hata düzeltmesi olmaz, 1.2'nin içinde çıkar.**
5. **Görseller varsayılan olarak açık.** Sınırları Ayarlar'dan değiştirilebilir (ayrıntı §1, madde 1).
6. **Adlar İngilizce'de açık ve sade olacak.** Tema adları (Mürettebat, Radyo Sessizliği, Vizör) bırakıldı. Yeni ad
   listesi §4'te.
7. **Paylaşılan koleksiyonlar (CKShare) ertelendi** ve "Sonra" listesine alındı. 1.3'ten sonra kullanıcı isteğine göre
   yeniden değerlendirilir. 1.2'de yerine **"Koleksiyonu Dışa Aktar"** gelir (mevcut arşiv biçimiyle).
   - Gerekçe: büyük bir yapısal değişiklik gerekiyor (bölge başına paylaşım, ikinci bir eşitleme motoru, yeni kimlik
     şeması). Paste'te de bu alan hatalı. Mac güncellenmeden yarım kalır. Görseller daha çok kullanıcıya daha çok
     değer veriyor.

---

## 0. Önce düzeltilmesi gereken öncüller

1. **`paste-ios.md` artık eskimiş durumda.** Belge 17 Ekim'de yazıldı. "Pastronaut'ta: Yok" dediği şeylerin çoğu
   aynı gün Dalga 1–5'te yapıldı: Paylaş uzantısı, widget'lar, Denetim Merkezi kontrolü, Spotlight, koleksiyonlar,
   açılınca kaydetme, "+" ile yeni öğe, çoklu seçim, arama jetonları, okuma kısayolları ve bağlantı önizlemesi.
   Aşağıdaki matris belgeye göre değil, koda göre yazıldı.
2. **Madde 1, 3 ve 4'ün bir kısmı yalnızca iOS'ta yapılırsa işe yaramaz.**
   - Mac bugün görselleri ve dosyaları hiç göndermiyor. `SyncBridge.syncableText` görsel ya da dosya içeren
     kopyayı atlıyor.
   - Görsel eşitlemesinin asıl değeri "Mac'te ekran görüntüsü al, iPhone'da kullan" akışı. Bu akış Mac'te bir
     değişiklik gerektirir.
   - Paylaşılan koleksiyonlar ve öğe adları da Mac güncellenmeden yalnızca telefonda görünür.
   - "Yalnızca iOS" sınırı korunursa bu maddeler yarım kalır. Önerim §6'da: veri modeli şimdi iki platformla uyumlu
     tasarlansın, Mac tarafı ayrı ve onaylı bir fazda (Mac 1.2) yapılsın.
3. **`PastronautCore` ortak bir paket.** İçine yapılan her değişiklik Mac'te de derlenir ve Mac testlerinden
   geçmelidir. Ayrıca CloudKit Production şeması geri alınamaz, yalnızca ekleme yapılabilir.
4. **Parçalara bölme (chunking) gerekmiyor.** Kaydın kendisi 1 MB ile sınırlı, ama `CKAsset` bundan ayrı tutuluyor
   ve büyük dosyaları kaldırıyor. Asıl sınır kullanıcının iCloud kotası. Parçalama yalnızca karmaşıklık ekler.
5. **macOS'a ait kısayollar** (⌘E, ⌘R, ⌘N, ⌘G, ⌘T) iPhone'da yalnızca donanım klavyesiyle anlamlı ve hedef bugün
   yalnızca iPhone (`TARGETED_DEVICE_FAMILY "1"`). Bunların asıl yeri iPad sürümü. iPhone'daki karşılıkları
   dokunmatik: bağlam menüsü, sayfa (sheet) ve araç çubuğu.
6. **Paste iOS 26 ve sonrasını, biz iOS 17 ve sonrasını destekliyoruz.** Önerilen API'lerin hepsi iOS 17'de var.
   Tek istisna Vision'ın yeni belge tanıma isteği (iOS 26). O yalnızca iOS 26'da açılır, öncesinde
   `VNRecognizeTextRequest` kullanılır.
7. **Klavyede gerçek "yığın" mümkün, uygulamada değil.** iOS başka bir uygulamada yapıştırmanın ne zaman olduğunu
   bildirmez. Bu yüzden Mac'teki "her ⌘V'de sıradakine geç" düzeni iPhone panosunda kurulamaz. Ama metni yazan
   bizim klavyemiz olduğunda kurulabilir (§2, madde 9).

---

## 1. Doğrulama matrisi (9 madde)

Kısaltmalar: **Var** / **Kısmen** / **Yok**. Kanıtlar `dosya:satır` biçiminde.

### 1. Görsel, dosya ve PDF eşitlemesi; 100 KB sınırı
- **Mevcut durum: Yok.**
  - Model yalnızca metin tutuyor: `Clip.Kind` içinde yalnızca `text` ve `url` var (`PastronautCore/.../Clip.swift:6-9`).
  - 100 KB sınırı `SyncPolicy.swift:8` dosyasında tanımlı ve yedi yerde uygulanıyor.
  - Hiçbir yerde `CKAsset` kullanılmıyor. Mac görselleri atlıyor (`Maccy/Sync/SyncBridge.swift:437-467`).
  - iPhone'da yerel bir depo yok. Geçmiş, eşitleme aynasının (`clip-sync.json`) kendisi.
- **iOS gerçekliği:**
  - Büyük içerik `CKAsset` alanında tutulur.
  - `encryptedValues` alanı `CKAsset` kabul etmez. Uçtan uca gizlilik için baytları kendi anahtarımızla
    (`SyncKey`, AES-GCM) şifreleyip öyle yüklemek gerekir.
  - CKSyncEngine bölgedeki her kaydı varlıklarıyla birlikte indirir. Bu yüzden büyük dosyalar ayrı bir bölgede
    durmalı ve motorun çekme kapsamından (`FetchChangesOptions.scope`) çıkarılmalı. Gerektiğinde tek tek indirilir.
- **Eski sürümlerle uyum (koddan doğrulandı):**
  - Eski istemciler tanımadıkları kayıt türlerini yok sayar (`ClipSync.swift` içindeki `apply`, `default: break`).
  - `text` alanı olmayan bir `Clip` kaydını da geçersiz sayıp atlarlar (`ClipRecord.clip(from:)`).
  - Bu yüzden görseller ayrı bir kayıt türünde tutulursa Mac 1.0 ve iPhone 1.1 bozulmaz.
- **Pastronaut'ta nasıl yapılır, neden daha iyi:**
  - **Kayıtlar:** Yeni bir `Media` kaydı. İçinde tür, boyut, şifreli küçük resim (≤ 60 KB, ayrıntı aşağıda) ve
    şifreli tanınan metin bulunur. Tam dosya ayrı `Blobs` bölgesinde, kendi anahtarımızla şifrelenmiş olarak durur.
    Küçük resim klavye ve widget'a yeter; tam dosya yalnızca açılınca iner.
  - **Sınırlar (karar 5, varsayılanlar):** Ayarlar › Görseller (EN *Images*) bölümünde şunlar olur:

    | Ayar (EN / TR) | Seçenekler | Varsayılan |
    |---|---|---|
    | *Sync Images* / Görselleri Eşitle | açık / kapalı | **açık** |
    | *Image Quality* / Görsel Kalitesi | *Optimized* (HEIC, uzun kenar en fazla 4096 px) / *Original* | **Optimized** |
    | *Largest Image* / En Büyük Görsel | 5 / 10 / 25 / 50 MB | **10 MB** |
    | *iCloud Space for Images* / Görseller İçin iCloud Alanı | 500 MB / 1 GB / 2 GB / 5 GB / sınırsız | **1 GB** |
    | *Use Mobile Data* / Mobil Veri Kullan | açık / kapalı | **açık** |

    - **Neden bu değerler:** iPhone ekran görüntüsü HEIC'e çevrilince genellikle 1 MB'nin altına iner. 48 MP bir
      fotoğraf 4096 px'e küçültülünce birkaç MB olur. 10 MB, neredeyse her şeyi kalite kaybı olmadan geçirir.
      Ücretsiz iCloud planı 5 GB olduğu için 1 GB'lık alan, kullanıcının yedeklerini tehlikeye atmaz.
    - **Sınır aşılınca:** Büyük görsel ya da dolan alan durumunda görsel silinmez. "Yalnızca bu iPhone'da" olarak
      kalır ve bir kez bilgi verilir. Kota dolunca da aynısı olur.
    - **Hep inenler:** Küçük resim ve tanınan metin her zaman iner. Tam dosya yalnızca açılınca ya da kopyalanınca
      iner.
    - **Gizlilik politikası güncellenir:** görseller ve cihazda yapılan metin tanıma eklenir. App Store gizlilik
      etiketi değişmez ("Data Not Collected"), çünkü veri kullanıcının kendi iCloud'unda kalır.
  - **Paste'e göre fark:** Paste şifreleme konusunda hiçbir iddiada bulunmuyor ve sürüm notları "geçici eşitleme
    dosyaları diski doldurdu" düzeltmeleriyle dolu. Bizde dosyalar uçtan uca şifreli olur ve yerel önbellek
    sınırlı (LRU: en eski kullanılanı ilk silen) tutulur.
  - **Ön koşul:** Önce §3'teki K1 (iPhone'da yerel depo) düzeltilmeli. Yoksa bir iCloud silmesi görselleri de götürür.

### 2. Görseldeki metin (OCR), Canlı Metin ve belge tarayıcı
- **Mevcut durum:** iOS'ta yok. Mac'te Maccy görseldeki metni tanıyor; bu metin yalnızca yerel başlık olarak
  kalıyor ve eşitlenmiyor (`Maccy/Models/HistoryItem.swift:106-118`).
- **iOS gerçekliği:**
  - Metin tanıma: `VNRecognizeTextRequest`, iOS 13+. iOS 26'da yeni belge tanıma isteği de var.
  - Görsel üzerinde metin seçme: VisionKit `ImageAnalysisInteraction`, iOS 16+.
  - Belge tarama: `VNDocumentCameraViewController`.
  - Kameradan canlı metin alma: `DataScannerViewController`, iOS 16+, A12 ve sonrası.
  - Türkçe tanıma desteği çalışma anında `supportedRecognitionLanguages` ile kontrol edilmeli; şimdilik
    doğrulanmadı.
- **Pastronaut'ta:**
  - Tanıma telefonda, bir kez yapılır. Sonuç `Media` kaydının şifreli `recognizedText` alanına yazılır, böylece
    diğer cihazlar ve klavye Vision'ı yeniden çalıştırmadan arar. Klavyenin bellek sınırı için bu önemli.
  - **"Kameradan Metin" (hızlı kazanç):** DataScanner ile kameradan tutulan satır doğrudan **metin öğesi** olur.
    Görsel eşitlemesine bağlı değildir, 1.2'ye girebilir.
  - **Belge tarama:** Önce tanınan metin öğesi olarak kaydedilir. PDF olarak kaydetme madde 1'den sonra gelir.
  - **Paste'e göre fark:** Paste OCR'ı yalnızca görsel için yapıyor. Biz kameradan doğrudan aranabilir metin
    yakalıyoruz, metin telefonda kalıyor ve Türkçe arama kurallarımız (ı/i, aksan) OCR metnine de uygulanıyor.

### 3. Paylaşılan koleksiyonlar (CKShare)
- **Mevcut durum: Yok.** Projede `CKShare` ya da `sharedCloudDatabase` kullanılmıyor.
- **Mimari engeller (koddan):**
  - "Library" bölgesinin tamamını paylaşmak olmaz: içinde hesap anahtarını tutan `Settings` kaydı da var.
  - Kayıt hiyerarşisiyle paylaşım da uymuyor. Koleksiyon üyeliği çoka-çok bir dizi; bir kaydın ise tek ebeveyni
    olabiliyor.
  - Kayıt adları sahibin özel HMAC anahtarından türüyor, katılımcılar bu adları üretemez.
  - Kod bugün "Library" dışındaki her bölgeyi yok sayıyor (`ClipSync.swift:713-715`, `KeyboardCloud.swift:128`).
- **iOS gerçekliği:** Paylaşılan her koleksiyon için ayrı bir bölge açılır ve bölgenin tamamı
  `CKShare(recordZoneID:)` ile paylaşılır. Paylaşılan veritabanında ikinci bir CKSyncEngine çalışır. Davet
  `UICloudSharingController` ya da `ShareLink` ile gönderilir. Info.plist'e `CKSharingSupported` eklenir ve
  davet kabulü sahne temsilcisinde karşılanır. Bu yolun iOS 17'de çalıştığı açık kaynak örneklerde görülüyor.
- **Değerlendirme:** Efor büyük, risk yüksek. Paste'te de bu alan sorunlu: geliştirici forumlarında paylaşılan
  bölgenin kaybolduğuna dair kayıtlar var. Mac güncellenmeden Mac'te görünmez.
- **Karar (7):** Ertelendi. Yerine 1.2'de küçük bir ara adım:
  - **"Koleksiyonu Dışa Aktar"** (EN *Export Collection…*): Koleksiyonun anlık bir kopyası düz metin ya da arşiv
    (mevcut `ClipArchive`) olarak paylaşım sayfasından gönderilir. Alan kişi Pastronaut'ta "İçe aktar" der.
  - Gerçek paylaşılan koleksiyonlar (EN *Shared Collections*) 1.3'ten sonra ayrı bir tasarım belgesiyle yeniden
    değerlendirilir.

### 4. Yerinde düzenleme, ad verme, yeni öğe, renk/görsel düzenleme, donanım klavyesi
- **Mevcut durum:**
  - Düzenleme var, ama yalnızca ayrıntı ekranından (`ClipDetailView.swift:85-117`).
  - "+" ile yeni öğe var (`HistoryView.swift:138-142`).
  - **Ad verme yok:** `Clip` modelinde başlık alanı bulunmuyor.
  - Renk ve görsel düzenleme yok.
  - Donanım klavyesi desteği yok: hiç `.keyboardShortcut` ya da `UIKeyCommand` kullanılmıyor.
- **Kimlik sorunu:** Kimlik metnin özeti olduğu için düzenleme "eskiyi sil, yenisini ekle" demek
  (`ClipStore.swift:161-186`). Sonuçları:
  - Başka cihaz aynı anda eski öğeyi değiştirirse sunucu `.unknownItem` döner ve silinen öğe geri gelir
    (`ClipSync.swift:851-858`).
  - Önizleme önbelleği ve Spotlight kimliğe bağlı olduğu için boşa düşer.
  - Mevcut bir metne dönüştürülen öğe, aynı kimlikli ikinci bir satır olarak listeye eklenir.
- **iOS karşılıkları:**
  - **Ad ver:** Bağlam menüsü ve ayrıntı ekranında "Ad Ver…". Modelde `Clip` kaydına şifreli, isteğe bağlı bir
    `title` alanı eklenir. Bu bir eklemedir; eski istemciler alanı yok sayar.
  - **Düzenle:** Bağlam menüsüne de eklenir. Metin görünümü sistem bileşeni olduğu için Writing Tools
    kendiliğinden gelir.
  - **Renk:** Renk öğesinde SwiftUI `ColorPicker`. Seçilen renk yeni bir öğe olarak kaydedilir; ad "renk varyantı".
  - **Görsel:** Madde 1'den sonra QuickLook'un işaretleme (markup) düzenlemesiyle yapılır.
  - **⌘ kısayolları:** iPad sürümüyle gelir (§6). iPhone'da etkisi yok denecek kadar az.
- **Daha iyisi:**
  - Ad, aramada ve klavyede metnin yerine gösterilir. Örneğin "IBAN – iş" adı, uzun bir metnin önüne geçer.
  - Ad bir kez verildikten sonra, aynı metin yeniden kopyalansa da kalır (`copiedAgain` kuralına eklenir).

### 5. Paylaş ve Eylem uzantıları
- **Mevcut durum:** Paylaş uzantısı **kısmen** var, Eylem uzantısı **yok**.
  - Paylaş yalnızca metin ve tek bağlantı kabul ediyor (`iOS/Share/Info.plist:27-33`) ve yalnızca ilk öğeyi alıyor.
  - Eksikler:
    - İptal düğmesi yok, zaman aşımı yok. Yavaş ağda "Kaydediliyor…" ekranında takılı kalabiliyor
      (`ShareViewController.swift:28-32`).
    - Yüklemeden sonra öğe, uygulama eşitlenene kadar klavye ve widget'ta görünmeyebiliyor
      (`KeyboardCloud.swift:188, 233-235`).
    - `keyboard-cache.json` dosyasına ikinci, eşgüdümsüz bir yazan oluyor.
    - App Group açılamazsa yanlış mesaj gösteriliyor.
- **iOS karşılıkları:**
  - **Eylem uzantısı** (`com.apple.ui-services`): Arayüzsüz, tek dokunuşla "Pastronaut'a Kaydet". Paylaşım
    sayfasının eylem listesinde görünür.
  - **Paylaş uzantısında birden çok öğe:** Seçilen birkaç fotoğraf ya da metin birlikte kaydedilir. Görseller ve
    PDF'ler madde 1'den sonra gelir.
- **Daha iyisi: "Önce kaydet, sonra düzenle".**
  - Paylaş anında hemen kaydeder.
  - Ardından birkaç saniye "Koleksiyona ekle / Ad ver" seçenekleri görünür.
  - Ağ beklenmez: gelen kutusu zaten güvenli, yükleme arka planda sürer. Böylece takılma sorunu kökten biter.
  - Paste'in Paylaş uzantısının koleksiyona kaydetmediğine dair bir kullanıcı bildirimi de var (doğrulanamadı).

### 6. Geçmişte göster ve zengin önizleme
- **Mevcut durum:**
  - **Geçmişte göster:** iOS'ta yok; Mac'te ⌘G ile var. iOS'ta `ScrollViewReader` yalnızca "N yeni" düğmesi için
    kullanılıyor (`HistoryView.swift:35, 238-261`). Spotlight sonucuna dokunmak yalnızca öğeyi kopyalıyor.
  - **Önizleme:** Bağlantı önizlemesi kartlarda var (`LPMetadataProvider`, `PreviewStore.swift:97-121`). Ayrıntı
    ekranında önizleme yok, QuickLook yok. Önizleme önbelleği silinen öğelerden hiç temizlenmiyor ve boyut sınırı yok.
- **iOS karşılıkları:**
  - Aramadaki bir sonucun bağlam menüsünde "Geçmişte Göster" (Mac'teki adla aynı). Arama ve jetonlar kapanır,
    kapsam "Tümü"ne döner, öğeye kaydırılır ve kısa bir vurgu yapılır.
  - Spotlight'tan gelen sonuç da aynı yolla açılır, yalnızca kopyalamakla kalmaz.
  - Ayrıntı ekranında büyük önizleme ve "Uygulama içinde aç" (`SFSafariViewController`).
- **Daha iyisi:**
  - Geçmişte gösterilen öğenin çevresinde, aynı dakikada kopyalanan öğeler de ayrıca vurgulanır.
  - Bağlantı önizlemesi gizlilik süzgecinden (`LinkPreviewPolicy`) geçer. Paste'te böyle bir süzgeç yok.

### 7. Ekran paylaşımında gizlilik ve süreli duraklatma
- **Mevcut durum:** iOS'ta ikisi de yok. Ekran kaydı algılanmıyor. Uygulama değiştiricideki örtü yalnızca Face ID
  kilidi açıkken çalışıyor. Duraklatma yalnızca Mac'te var (`HistoryRules.swift:37-52`).
- **iOS gerçekliği:**
  - iOS'ta bir pencereyi kayıttan dışlamanın yolu yok (Mac'teki `sharingType` karşılığı bulunmuyor). Yalnızca
    algılanabilir: iOS 17+ `sceneCaptureState` ya da eski `isCaptured`. Ekran görüntüsü engellenemez, yalnızca
    alındıktan sonra fark edilir.
  - "Pano dinlemeyi durdurmak" iPhone'da şu anlama gelir: açılınca kaydetme ve klavyenin otomatik kaydı belirli bir
    süre çalışmaz.
- **Pastronaut'ta:**
  - **Ekran Kaydında Gizle** (EN *Hide During Screen Recording*; Mac'teki "Ekran paylaşımında ve kayıtta gizle"
    ayarının karşılığı):
    - Ekran kaydı ya da yansıtma algılanınca içerik bulanıklaşır ve "Göster" düğmesi çıkar. Varsayılan açık.
    - Uygulama değiştiricide gizleme (EN *Hide in App Switcher*) kilitten bağımsız bir seçenek olur.
    - Klavye de ekran kaydı sırasında önizleme metinlerini gizler.
  - **Kaydetmeyi Duraklat** (EN *Pause Saving*):
    - Seçenekler: 15 dk, 1 saat, yarına kadar, ben açana kadar.
    - Uygulamada, klavyede ve Denetim Merkezi kontrolünde aynı durum kullanılır (App Group).
    - Kalan süre kilit ekranında bir Canlı Etkinlik (Live Activity) olarak gösterilebilir.
- **Daha iyisi:** Paste'in iOS'ta ikisi de yok. Denetim Merkezi'nden tek dokunuşla duraklatmak Paste'te
  bulunmayan bir yüzey.

### 8. Sürükle-bırak ve bağlantı küçük resimleri
- **Mevcut durum:**
  - Sürükleme yalnızca iPad'de, yalnızca liste satırlarında ve yalnızca metin olarak var
    (`HistoryView.swift:746-758`). iPad bugün dağıtımda değil.
  - iPhone'da kapatılmış, çünkü UI testinde bağlam menüsünü kilitliyordu.
  - Bağlantı küçük resmi var ve önbelleğe alınıyor (yukarıda). Kartlarda sürükleme yok.
- **iOS gerçekliği:**
  - iPhone'da uygulamalar arası sürükleme iOS 15'ten beri var.
  - `Transferable` ile bir öğe birden çok temsil sunabilir: düz metin, URL, PNG verisi ya da önerilen dosya adıyla
    bir dosya.
  - Klavye uzantısından sürükleme olası değil.
- **Pastronaut'ta:**
  - `Clip` öğesine çok temsilli bir `Transferable` uyarlaması eklenir. Görsel, alan uygulamaya hem görsel hem dosya
    olarak gider.
  - iPhone'da sürükleme yeniden açılır. Test sorunu, testte sürüklemeyi kapatan bir başlatma bayrağıyla çözülür.
  - Önizleme önbelleği temizlik ve boyut sınırı alır.

### 9. Çoklu seçimle toplu yapıştırma ve sıra
- **Mevcut durum:**
  - Çoklu seçim var, ama içinde toplu kopyalama ya da paylaşma yok.
  - Sıra yalnızca Mac'te var (`Maccy/PasteStack.swift`).
  - Klavyede çoklu seçim, kuyruk ve Canlı Etkinlik yok.
- **iOS gerçekliği:** Uygulama başka bir uygulamadaki yapıştırmayı göremez, bu yüzden pano tabanlı bir sıra
  ilerleyemez. Klavye ise metni kendisi yazdığı için sırayı yönetebilir.
- **Pastronaut'ta:**
  - **Klavyede Sıra:**
    - Uygulamada ya da klavyede öğeler seçilir ve "Sırayı Başlat"a dokunulur.
    - Klavyede büyük bir "Sıradaki (2/5)" tuşu belirir. Her dokunuş sıradaki öğeyi yazar.
    - ⇄ ile yön değiştirilir. Uzun basınca "Atla" ve "Bitir" seçenekleri çıkar.
    - Ad Mac'teki **Sıra** (EN *Queue*) ile aynı olur; iki platformda tutarlılık temadan önemli.
    - Sıra durumu App Group'ta küçük bir dosyada tutulur. Tam Erişim gerekmez; klavye yalnızca okur.
  - **Toplu Kopyala:** Seçilen öğeler seçilen ayraçla (yeni satır, virgül ya da boş satır) tek metin olarak kopyalanır.
  - **Canlı Etkinlik ile sıra:** Kilit ekranından "sıradakini panoya al" düğmesi. Arka planda panoya yazmanın
    güvenilir olup olmadığı belirsiz; önce küçük bir prototiple denenmeli. 1.2'ye zorunlu değil.
- **Daha iyisi:** Paste'in iPhone'da sıralı yapıştırması belgelenmiyor. Klavyede sıra, iOS'ta gerçekten çalışan
  tek yöntem.

---

## 2. Matris özeti

| # | Madde | Bugün | iOS'ta uygulanabilir mi | Mac gerekir mi | Önerilen sürüm |
|---|---|---|---|---|---|
| 1 | Görsel, dosya, PDF eşitlemesi | Yok | Evet (ayrı kayıt, şifreli varlık) | **Evet** (Mac'in görsel göndermesi) | 1.3 (iPhone + Mac) |
| 2a | Kameradan Metin (DataScanner) | Yok | Evet | Hayır | **1.2** |
| 2b | OCR ve Canlı Metin | Yok (Mac'te yerel) | Evet | Mac'in OCR metnini göndermesi isteğe bağlı | 1.3 |
| 2c | Belge tarama | Yok | Evet | Hayır | 1.2 (metin), 1.3 (PDF) |
| 3 | Paylaşılan koleksiyon | Yok | Evet, ama büyük iş | Evet | Sonra ("Koleksiyonu Dışa Aktar" 1.2'de) |
| 4 | Ad ver, düzenle, renk | Kısmen | Evet | Ad için Mac sonra | **1.2** |
| 4b | ⌘ kısayolları | Yok | Yalnızca iPad'de anlamlı | Hayır | iPad sürümü |
| 5 | Paylaş ve Eylem | Kısmen | Evet | Hayır | **1.2** (görseller 1.3) |
| 6 | Geçmişte göster, önizleme | Kısmen | Evet | Hayır | **1.2** |
| 7 | Ekran kaydında gizleme, duraklatma | Yok | Evet (yalnızca algılama) | Hayır | **1.2** |
| 8 | Sürükle-bırak | Kısmen (iPad) | Evet | Hayır | 1.2 (metin), 1.3 (görsel) |
| 9 | Sıra ve toplu kopyalama | Yok | Evet (klavyede) | Hayır | **1.2** |

---

## 3. Ek bulgular: v1.1'deki hatalar ve eksikler

Önem sırasıyla. ✔ işaretliler kodda elle doğrulandı, diğerleri alt ajan bulgusu.

### Kritik
- **K1 ✔ iPhone geçmişi bir iCloud silmesinde ya da hesaptan çıkışta tamamen gidiyor.**
  - Uygulama "iCloud verisi silindi; yerel geçmiş korundu" diyor (`ClipSync.swift:625`), ama iPhone'da yerel geçmiş
    aynanın ta kendisi (`ClipStore.swift:8`).
  - `forgetCloudState` aynayı boşaltıyor (`ClipSync.swift:590-603`). Hesaptan çıkışta ise `entries.removeAll()`
    çağrılıyor (`:690-697`).
  - Mac'te sorun yok, çünkü Mac'in kendi deposu var.
  - Görseller gelmeden önce kapatılmalı.
- **K2 Açılışta gelen kutusundaki kopyalar kaybolabilir.**
  - `start()`, `isStarted` bayrağını motor kurulmadan önce `true` yapıyor (`ClipStore.swift:78-98`).
  - Aynı anda gelen bir `refresh()` gelen kutusunu boşaltabilir. O sırada motor henüz yoksa `store` false döner
    (`ClipSync.swift:470`) ve kopyalar düşer.
  - Etkilenenler: klavye ve Paylaş yakalamaları. Zaman aralığı dar, testle doğrulanmalı.
- **K3 Silinen öğe geri gelebilir.**
  - Sunucu `.unknownItem` dönünce kayıt yeniden yaratılıyor (`ClipSync.swift:851-858`). Bir cihaz silerken öteki
    sabitlerse silme kaybolur.
  - Başarısız silmeler de hiç incelenmiyor (`handleSent`).

### Yüksek
- **K4 ✔ Kilit açılmasa da pano okunuyor.** Face ID başarısız olduktan sonra da `autoSaveClipboard` ve `refresh`
  çalışıyor (`PastronautApp.swift:26-31`).
  - Kilit örtüsü sayfaları (düzenleyici, Ayarlar) kapatmıyor.
  - VoiceOver için kipli (modal) değil, yani kilitliyken alttaki geçmişi okuyabilir (`AppLock.swift:91-115`).
- **K5 Görünmeyen öğeler toplu işleme girebiliyor.** Kapsam ya da arama değişince seçim korunuyor. `selectedClips`
  ise yalnızca görünenleri değil, bütün öğeleri süzüyor (`HistoryView.swift:284-286`). Toplu silme gizli öğeleri de
  siler.
- **K6 Kaydırarak ve menüden silmede ne onay ne geri alma var.** Mac'te 8 saniyelik geri alma var.
- **K7 Gizlilik süzgeçleri iki platformda farklı.**
  - Mac'in "kodları ve kartları eşitleme" anahtarları iPhone'a eşitlenmiyor.
  - iPhone'da elle yapılan kayıtlar (Yapıştır, Paylaş, Kısayollar) hiç süzülmüyor.
  - Sonuç: iPhone'da kaydedilen bir kod, Mac'te anahtar açık olsa da Mac'e gidiyor.
- **K8 Klavye ve widget bellek riski.**
  - Her açılışta geçmişin tamamı çözülüyor ve 200 öğe × 100 KB bellekte tutulabiliyor.
  - Her kutucukta her çizimde `NSDataDetector` çalışıyor (`KeyboardViewController.swift:329-340, 599, 615`).
  - Widget da her zaman çizelgesinde geçmişin tamamını çözüyor.
  - iPhone geçmişinin bir sınırı yok.

### Orta
- **K9 ✔ Kopyalamak Mac öğesini "iPhone" yapıyor** (`ClipStore.swift:150`). Öğe Mac filtresinden iPhone filtresine
  geçiyor. Bu, açılışta kaydetmedeki "yeniden etiketleme" kuralıyla çelişiyor.
- **K10 Sessiz hatalar.** Yeni öğe, düzenleme ve Yapıştır düğmesi 100 KB'yi aşınca hiçbir şey söylemiyor.
  Yapıştır düğmesi başarıda da bildirim göstermiyor.
- **K11 Paylaş uzantısı takılabiliyor** ve yanlış mesaj gösterebiliyor (madde 5).
- **K12 Ana iş parçacığında ağır işler.**
  - Bölümler her çizimde birkaç kez yeniden hesaplanıyor.
  - Kartlar tembel yüklenmiyor. Her kartın önizleme görevi aynı anda başlıyor.
  - Önizleme önbelleği ana iş parçacığında diske yazıyor.
- **K13 Klavye göz atma kipinde harf tuşu yok** (yalnızca boşluk, sil, satır başı).
  - 1.0 bu haliyle onaylandı, ama Guideline 4.4.1 "metin girişi" bekliyor.
  - Sıra tuşu eklenirken klavye düzeni yeniden tasarlanacağı için risk akılda tutulmalı.

### Düşük
- **K14 İngilizce çoğullar eksik:** "Imported 1 new clips", "%lld selected".
- **K15 Önizleme sorusu kartı ölü kod:** varsayılan değer `.on` yazılıyor (`AppPreferences.swift:88-90`).
- **K16 Önizleme önbelleği hiç temizlenmiyor:** silinen öğelerin dosyaları kalıyor.
- **K17 Eşitleme çekirdeğinin birim testi yok.**
  - `ClipSync`'in mirror, taşıma, çakışma ve yakalama mantığı yalnızca iki cihazlı uçtan uca testle sınanıyor.
  - CLAUDE.md'nin "süzülmemiş içerik eşitlenemez" testi yalnızca uçtan uca testte var.
  - Önerim: bir CloudKit soyutlaması ve sahte (mock) bir uygulamasıyla birim testi eklemek.

---

## 4. Özgünleştirme ilkeleri ve adlar

- **Görünüm:**
  - Paste'in yatay kart şeridi, kart oranları, kaynak uygulama rengiyle boyanan başlıkları ve animasyonları
    kullanılmaz.
  - Mevcut kimliğimiz korunur: gökyüzü paleti, tür renkleri (`ClipKind`), iki sütunlu kartlar, cam filtre çipleri.
  - Yeni ekranlar kullanıcının paylaşacağı ekran görüntülerinden **yalnızca mekânsal ilke** alınarak tasarlanır.
- **Terimler (karar 6):** Tema adı kullanılmaz. Ad, önce İngilizce'de ne yaptığını söylemeli. Apple'ın kendi sistem
  terimi varsa o kullanılır (ör. *Scan Text*), çünkü kullanıcı onu zaten tanır. Mac'te adı olan işlev aynı adı alır.
  Paste'in terimleri ("Pinboard", "Paste Stack") kullanılmaz.

| İşlev | EN (temel) | TR | Not |
|---|---|---|---|
| Süreli duraklatma | *Pause Saving* · *For 15 Minutes / For 1 Hour / Until Tomorrow / Until I Resume* | Kaydetmeyi Duraklat | Mac menüsündeki süreler |
| Ekran kaydında gizleme | *Hide During Screen Recording* | Ekran Kaydında Gizle | Mac ayarının karşılığı |
| Uygulama değiştiricide gizleme | *Hide in App Switcher* | Uygulama Değiştiricide Gizle | |
| Sıralı yazma | *Queue* · *Start Queue* · *Next (2 of 5)* | Sıra · Sırayı Başlat · Sıradaki (2/5) | Mac'te zaten bu ad |
| Toplu kopyalama | *Combine & Copy* | Birleştirip Kopyala | Ayraç seçilir |
| Bağlamda gösterme | *Show in History* | Geçmişte Göster | Mac'te zaten bu ad |
| OCR | *Text in Image* · *Copy Text* | Görseldeki Metin · Metni Kopyala | Mac'te zaten bu ad |
| Kameradan metin | *Scan Text* | Metni Tara | Apple'ın sistem terimi |
| Belge tarama | *Scan Document* | Belge Tara | |
| Öğe başlığı | *Add Title…* / *Edit Title…* | Başlık Ekle… / Başlığı Düzenle… | |
| Eylem uzantısı | *Save to Pastronaut* | Pastronaut'a Kaydet | Kısayol adıyla aynı |
| Koleksiyonu gönderme | *Export Collection…* | Koleksiyonu Dışa Aktar… | |
| Yalnızca yerel öğe | *Only on This iPhone* · *Upload to iCloud Again* | Yalnızca Bu iPhone'da · iCloud'a Yeniden Yükle | K1 |
| Paylaşılan koleksiyon (sonra) | *Shared Collections* | Paylaşılan Koleksiyonlar | Ertelendi |

- **Kurallar:**
  - App Intents metinlerine "Mac", "iPhone" ya da "iPad" yazılmaz (ITMS-90626).
  - Klavye Tam Erişim olmadan da çalışır; Sıra da Tam Erişim istemez.

---

## 5. Uygulama yol haritası (bağımlılık sırasıyla)

Her adımın sonunda yapılacaklar:
- Mac derlemesi ve `MaccyTests`.
- iOS derlemesi ve çekirdek testleri.
- Gerekirse iki cihazlı uçtan uca test.

Arayüz kodu yalnızca **Adım D**'de yazılır, ekran görüntüleri geldikten sonra.

### Adım A: Sağlamlaştırma (veri katmanı, arayüzsüz) → 1.2'nin ilk parçası (karar 4)

> **Durum (2026-10-22):** A1–A4 yapıldı ve test edildi: çekirdekte 113 test (17'si yeni), Mac'te 109 test, iOS
> derlemesi. A6 şema değişikliği olduğu için Adım B'ye taşındı.
> - **İki cihazlı uçtan uca test (2026-10-22): 35 kontrol geçti**, T13 (arka plan push'u) her zamanki gibi uyarı verdi.
>   Test bir hata buldu: başlatma kendini bekliyordu ve iPhone'daki her kayıt asılı kalıyordu (`68b0122` ile
>   düzeltildi). Test düzeneği de 1.1'e uyarlandı: kart görünümü ve "N yeni" düğmesi adımları bozuyordu.
>   Not: Debug derlemeleri gerçek uygulamanın verisini açıyor (aynı paket kimliği, Development ortamı); kullanıcı
>   bunu kabul ederek "olduğu gibi" koşturdu.
> - **A5, kısmen yapıldı:**
>   - İçerik algılama artık öğe kimliğine göre önbellekte (`ClipContentCache`); uygulama, klavye ve widget'ta geçerli.
>   - Klavyenin uzun basma paneli en fazla 4.000 karakter gösteriyor; "Yaz" yine metnin tamamını yazıyor.
>   - **Ertelendi:** Hafif anlık görüntü (`clips-lite.json`), cihazda Instruments ile bellek ölçülünce karar
>     verilecek. Bulut Mac'in geçmiş sınırını izlediği için Mac kullanan birinin iPhone geçmişi zaten sınırlı.
>     Hafif dosya, klavye aramasını kısaltılmış metinle sınırlardı.
>   - **Ertelendi:** iPhone'da saklama süresi bir Ayarlar seçeneği gerektiriyor, Adım D'ye kaldı. Kural hazır
>     (`HistoryAge`).
> - **Uygulanan kural:** Aynı metnin yeniden yakalanması (Yapıştır, açılınca kaydetme, Paylaş, klavye) yeni veri
>   sayılır ve eşitlenir. Dokunup kopyalama, sabitleme, koleksiyon ve düzenleme yalnızca yerel öğeyi yerelde tutar.
> - **Klavye:** Yalnızca yerel öğelerde Sabitle ve Sil göstermez, çünkü bu işlemler doğrudan iCloud'a yazıyor.
> - **Başka cihazda silinen öğe:** Burada yalnızca sabitlendiyse ya da koleksiyona eklendiyse silme kazanır.
>   Burada yeniden kopyalandıysa öğe geri gelir.
1. **K1:** iPhone'da yerel geçmiş aynadan ayrılır. Bulut silindiğinde ya da hesaptan çıkıldığında öğeler
   "Yalnızca bu iPhone'da" olarak kalır (karar 3).
   - Kendiliğinden yüklenmezler; yalnızca Ayarlar'daki "iCloud'a Yeniden Yükle" ile gönderilirler.
   - Klavye ve widget bu öğeleri görmeye devam eder.
   - Test: bölge silme, hesaptan çıkış, hesap değiştirme ve yeniden yükleme için birim testleri.
2. **K2:** `start()` tek bir göreve bağlanır (bekleyen görev paylaşılır). Gelen kutusu, motor hazır olmadan
   boşaltılmaz.
3. **K3:** Silme işaretleri (tombstone) tutulur. `.unknownItem` alan bir kayıt, yerelde silme işareti varsa yeniden
   yaratılmaz. Başarısız silmeler yeniden denenir.
4. **K17:** `ClipSync` için CloudKit soyutlaması ve sahte uygulaması. K1–K3'ün ve "süzülmemiş içerik gitmez"
   kuralının birim testleri.
5. **K8, veri tarafı:** Klavye ve widget için hafif bir anlık görüntü (`clips-lite.json`): kısaltılmış önizleme,
   tür ve ad. Tam metin yalnızca yazılırken okunur. iPhone geçmişine saklama süresi eklenir; Mac'teki
   `HistoryAge` kuralı (`HistoryRules.swift`) yeniden kullanılır.
6. **K7:** Gizlilik seçenekleri `Settings` kaydında eşitlenir. Bu bir şema eklemesidir. Mac bunu okuyana kadar her
   cihaz kendi ayarını uygular.

### Adım B: Şema eklemeleri

> **Durum (2026-10-22):** Kapsam daraltıldı. Yalnızca öğe başlığı eklendi; çekirdekte 125 test (12'si yeni), Mac'te
> 109 test, iOS derlemesi.
> - **`Clip.title`** (şifreli) ve **`Clip.titleModifiedAt`** (tarih): Başlık kendi saatine göre birleşir. Başlığı
>   bilmeyen bir kaynak (Mac 1.0, iPhone 1.1, Mac'te yeniden kopyalama) onu silemez; başlık açıkça
>   temizlenebilir. Kayıt alanları yalnızca başlık bir kez verildiğinde ya da temizlendiğinde yazılır. Başlık
>   aramada da bulunur; arşivde taşınır, içe aktarma yalnızca ekler. Arayüzü Adım D'de.
> - **Ertelendi, gizlilik ayarlarının eşitlenmesi (A6):** iPhone 1.2'de bu ayarları ne yazan ne okuyan var. Mac 1.3
>   planına taşındı. K7'nin iPhone tarafı şemasız çözülecek: iPhone'da süzülen öğeler "yalnızca bu iPhone'da" kalır
>   (Adım D, gizlilik ekranı).
> - **Ertelendi, `Media` ve `Blobs`:** Production şemasına alan ve tür eklemek sonradan da serbest. Görsel şeması
>   uygulamasıyla birlikte 1.3'te kesinleşir.
> - **Yayından önce:** Development'ta başlıklı en az bir kayıt kaydedilmeli (alanlar o zaman oluşur), sonra CloudKit
>   Console'da *Deploy Schema Changes to Production*. Bunu kullanıcı yapar; yapılmazsa 1.2 başlık yazamaz.

Özgün plan (tarihçe için):
- `Clip.title` (şifreli).
- Gizlilik ayarları (madde A6).
- `Media` kayıt türü ve `Blobs` bölgesi tanımı. Görseller 1.3'te açılsa da şema bir kez kesinleşsin.
- Eski istemci uyumu testle güvenceye alınır: Mac 1.0 ve iPhone 1.1, `Media` kaydını ve `title` alanını yok sayar,
  bozmaz.
- CloudKit'e yapılan kaydetmelerin yalnızca değişen alanları gönderip gönderdiği burada doğrulanır.

### Adım C: Servisler ve uzantılar (arayüzsüz ya da var olan arayüzle)

> **Durum (2026-10-22):** Çekirdekte 141 test (16'sı yeni), Mac'te 109 test, iOS derlemesi. Uçtan uca test bu
> adımdan sonra koşmadı.
> - **Yapıldı:**
>   - **Sıra:** `QueueRequest`'i uygulama yazar, `ClipQueue` klavyenin kendi ilerlemesidir. Tam Erişim
>     olmadan da çalışır. Birleştirip Kopyala'nın mantığı da hazır (`combinedText`, dört ayraç).
>   - **Kaydetmeyi Duraklat:** `SavingPause`, Mac'in süreleriyle. Uygulamanın ve klavyenin otomatik kaydını
>     durdurur; açık istekler (Yapıştır, Paylaş, Kısayollar, kontrol) yine kaydeder.
>   - **Paylaş:** Birden çok bağlantı ya da metin (en fazla 20) kaydedilir. iCloud için en fazla 8 sn
>     beklenir, sonra çevrimdışı kaydedilir. Dosya adresleri metin sayılmaz. Paylaşılan öğe, uygulama alana kadar
>     gelen kutusunda kalır ve klavyede ile widget'ta hemen görünür. Klavye önbelleğinin yeniden tek yazanı var.
>     "Kaydedilemedi" durumu eklendi.
>   - **Metin tanıma:** `TextRecognition` (Vision, cihazda). Kişinin dilleri, sonra Türkçe ve İngilizce
>     denenir; macOS 27'de `tr-TR` var.
>   - **Önizleme önbelleği:** Silinen öğelerin dosyaları her açılışta temizlenir, klasör 50 MB ile sınırlı
>     (`CachePruner`).
>   - **Hata düzeltmeleri:**
>     - K9: Kopyalamak Mac öğesini "iPhone" yapmıyor.
>     - K10: Yeni öğe ve Yapıştır 100 KB üstünde bildirim gösteriyor.
>     - K4: Face ID açılmadan pano okunmuyor; kilit açılınca bekleyen kayıt çalışıyor.
>     - K5: Toplu işlemler yalnızca görünen seçili öğelere uygulanıyor.
>     - Klavye 100 KB üstü yakalamayı gelen kutusuna yazmıyor.
> - **Adım D'ye kaldı (görünüm gerektiriyor):**
>   - Eylem uzantısı (ikonu ve adı paylaşım sayfasında görünüyor)
>   - Duraklatma için Denetim Merkezi kontrolü ve Kısayol
>   - Ekran kaydı algılayıcı (örtüyle birlikte)
>   - Metni Tara / Belge Tara kamera ekranları
>   - Paylaş'ta "kaydettikten sonra seçenekler"
>   - `Transferable` ve iPhone'da sürükleme
1. **Sıra durumu:** App Group'ta bir model, klavyenin okuyacağı biçimde. Toplu kopyalama mantığı ve testleri.
2. **Ekran Kaydında Gizle:** yakalama durumu izleyicisi. **Kaydetmeyi Duraklat:** bitiş zamanı, otomatik kayıt
   kapıları, Denetim Merkezi kontrolünün intent'i.
3. **Paylaş uzantısı:** "Önce kaydet" akışı, zaman aşımı ve İptal, birden çok öğe. Paylaşılanlar hemen klavye ve
   widget'ta görünür. Önbelleğe tek yazan kalır.
4. **Eylem uzantısı** (yeni hedef, `xcodegen generate`).
5. **Kameradan Metin ve belge tarama** servisleri: metin öğesi üretir. Türkçe dil desteği çalışma anında denetlenir.
6. **Önizleme önbelleği** temizliği ve boyut sınırı. **K9, K10** düzeltmeleri.
7. **`Clip` için `Transferable`** (metin ve URL; görsel temsili 1.3'te).

### Adım D: Arayüz (ekran görüntüleri ve onay sonrası)

> **Durum (2026-10-22):** Geçmiş ekranı (eşit kutular), liste, menü, klavye ve Sıra (`a50b154`, `cf36ac8`);
> örtü penceresi, Kaydetmeyi Duraklat, geri alma, yalnızca yerel öğeler, iPhone gizlilik seçenekleri, ayrıntı
> ekranı (`178dd96`); Metni Tara, Belge Tara, "Pastronaut'a Kaydet" eylemi, Paylaş'ta koleksiyon seçimi (`7dc19a7`).
> Cihazda tanıtım verisiyle denetlendi. Uçtan uca test (2026-10-22, son koşu): 35 geçti, T13 uyarı, T16 zamanlama
> (Mac'in silmeleri 2 dk'yı aşınca geldi; hemen ardından T17 sayıları eşit, hata yok; bir önceki koşuda geçmişti).
> T34 başlığın iCloud'a gittiğini doğruladı; başlık alanları Development şemasında oluştu. Eylem uzantısını kullanıcı
> elle dener.
- Ad Ver ve bağlam menüsünde Düzenle; Geçmişte Göster ve vurgu.
- Seçim çubuğunda Toplu Kopyala ve Sırayı Başlat.
- Klavyede Sıra tuşu (K13'ü de düşünerek).
- Ekran kaydı örtüsü ve Kaydetmeyi Duraklat (Ayarlar, kontrol, isteğe bağlı Canlı Etkinlik).
- Metni Tara ve Belge Tara girişleri; Koleksiyonu Dışa Aktar.
- "Yalnızca bu iPhone'da" rozeti ve "iCloud'a Yeniden Yükle" düğmesi (K1).
- Silmede geri alma (K6); K4 ve K5 düzeltmeleri.
- Erişilebilirlik: kip örtüsü, bildirim duyuruları, kart eylemleri.

### 1.3: Görseller (iPhone 1.3 ve Mac 1.3, üç kanal)
- **Çekirdek:** Medya deposu, kendi anahtarımızla AES-GCM, küçük resim, OCR metni, `Blobs` bölgesinin isteğe bağlı
  indirilmesi, kota, iCloud alan sınırı, LRU önbellek ve Ayarlar › Görseller (§1, madde 1).
- **Mac:** `MAC-1.3-PLAN.md`. Ayrı onayla yapılır.
- **iOS:** Görsel kartı, Canlı Metin, QuickLook işaretleme, görselin dosya olarak sürüklenmesi, Paylaş'ta görsel/PDF,
  klavyede küçük resim (dokununca panoya kopyalar; Tam Erişim gerekir).

### Sonra
- Paylaşılan koleksiyonlar (CKShare), 1.3'ten sonra yeniden değerlendirilir.
- iPad sürümü ve ⌘ kısayolları (`.keyboardShortcut`, ⌘ basılı tutunca kısayol listesi).
- Canlı Etkinlik ile sıra.

---

## 6. Platform sınırı önerisi

- 1.2 tamamen iOS'tur. Mac'te arayüz ve davranış değişmez.
- Ortak çekirdekteki değişiklikler (A ve B) Mac'te derlenip test edilir, ama Mac sürümü çıkarmayı gerektirmez.
  - A6 (gizlilik ayarları) ve B (şema), Mac güncellenene kadar Mac'te etkisiz kalır.
- Görseller (1.3) bir Mac sürümü gerektirir. Bu, CLAUDE.md'deki üç kanal kuralına bağlıdır, ayrı bir planda
  (`MAC-1.3-PLAN.md`) durur ve ayrı bir onayla yapılır.

---

## 7. Sorular

Faz 1 soruları 2026-10-22'de yanıtlandı (yukarıdaki "Kararlar" bölümü). Açık kalan tek soru:
- Mac App Store 1.0 (1) incelemeden geçti mi? Bu, Mac planındaki başlangıç noktasını belirler (`MAC-1.3-PLAN.md`).

## Kaynaklar (web, 2026-10-22)
- CloudKit kayıt ve varlık sınırları: https://developer.apple.com/forums/thread/827897 ,
  https://developer-mdn.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/PropertyMetrics.html
- Bölgenin tamamını paylaşma (CKShare) ve CKSyncEngine: https://developer.apple.com/documentation/cloudkit/ckshare ,
  https://github.com/markbattistella/SwiftDataSync , https://developer.apple.com/forums/thread/822937

---

## Production'a gönderme: başlık alanları (kullanıcı yapar, 1.2 incelemeye gitmeden önce)

**Neden:** 1.2, `Clip` kaydına iki yeni alan yazar: `title` (şifreli metin) ve `titleModifiedAt` (tarih). App Store
sürümü CloudKit'in **Production** ortamını kullanır. Production'da olmayan bir alana yazılamaz; bu alanlar yoksa
başlık vermek iCloud'da hata verir. Alanlar önce **Development** ortamında oluşur (Debug derlemesi başlıklı bir öğe
kaydettiğinde; uçtan uca testin T34 adımı bunu yapar), sonra elle Production'a gönderilir. **Geri alınamaz:**
Production'a gönderilen alan bir daha silinemez. Eski sürümler (iPhone 1.1, Mac 1.0) bu alanlardan etkilenmez.

1. **Giriş:** https://icloud.developer.apple.com adresine geliştirici Apple hesabınla gir → **CloudKit Database**.
   Ekip **V88QY49A4T**, kapsayıcı **iCloud.com.xkbxyberk.pastronaut** seçili olsun.
2. **Development'ı denetle:** Üstteki ortam seçicide **Development** seç → sol menüde **Schema › Record Types** →
   **Clip**. Alan listesinde şunlar olmalı:
   - `title` (türü şifreli metin; Konsol "Encrypted String" ya da benzeri gösterir)
   - `titleModifiedAt` (Date/Time)
   Yoksa dur: önce Debug derlemesiyle bir öğeye başlık verilmeli (ya da uçtan uca test T34 koşmalı).
3. **Production'ı denetle (isteğe bağlı):** Ortamı **Production** yap → **Clip**. Bu iki alan henüz olmamalı.
4. **Gönder:** Ortam **Development**'tayken **Deploy Schema Changes…** düğmesine bas (Konsol sürümüne göre sol
   menünün altında ya da sağ üstte durur). Açılan pencere gönderilecek değişiklikleri listeler. **Yalnızca** şunlar
   olmalı:
   - Record type **Clip** › yeni alan **title**
   - Record type **Clip** › yeni alan **titleModifiedAt**
   Listede başka bir şey varsa (yeni bir kayıt türü, başka alanlar, dizinler) **gönderme**, bana sor.
5. **Onayla:** **Deploy** ile gönder. Birkaç saniye sürer.
6. **Doğrula:** Ortamı **Production** yap → **Schema › Record Types › Clip**. İki alan artık görünmeli.
7. **Sonra:** TestFlight'taki 1.2 derlemesinde bir öğeye başlık ver; Ayarlar › Eşitleme'de hata çıkmamalı, başlık
   Mac'e (1.0, alanı yok sayar) dokunmadan iCloud'a gider.

**Development'ı temizlemek istersen (isteğe bağlı):** Uçtan uca testler gerçek geçmişini Development ortamına da
yükledi. Temizlemek için Development'ta **Reset Development Environment** kullanılabilir; bu, Development verisini
siler ve şemayı Production'daki haline döndürür. **Sırası önemli:** sıfırlama başlık alanlarını da Development'tan
siler. Bu yüzden ya önce Production'a gönder, sonra sıfırla; ya da sıfırladıktan sonra alanları yeniden oluştur
(Debug derlemesinde bir öğeye başlık ver ya da uçtan uca testi yeniden koştur) ve sonra gönder.
