# Paste (macOS) — Rakip Araştırması

> Kapsam: Yalnızca açık web kaynakları (resmi site, yardım merkezi, blog, güncelleme sayfası, App Store, Setapp, incelemeler). Uygulama indirilmedi, tersine mühendislik yapılmadı.
> Araştırma tarihi: 2026-10-17. Güncel sürüm: App Store'da 7.0.2 (9 Ekim 2026), Setapp'te 7.0.3.
> İşaretler: **doğrulanamadı** = açık kaynakta bulunamadı; **tahmin** = benim çıkarımım, kaynakla desteklenmiyor.

## 0. Künye

- **Geliştirici:** App Store'da satıcı "Paste Team", telif "Paste Team ApS" (Danimarka limited şirketi). Hakkında sayfasına göre ekip "Danimarka ve dünyanın çeşitli yerlerinden" küçük bir geliştirici/tasarımcı grubu. Product Hunt'ta Paste 7 lansmanında "maker" olarak **Dmitry Obukhov** yanıt veriyor.
  - **FIFTYSIX bağlantısı: doğrulanamadı.** Hiçbir kaynakta FIFTYSIX adı geçmiyor.
- **Platformlar:** Mac (macOS 14+), iPhone/iPad (iOS/iPadOS 26+), visionOS 26+. Tek satın alma ile tüm platformlar.
- **Fiyat:** 7 gün deneme. Aylık 3,99 $, yıllık 29,99 $, Lifetime 99,99 $, Family 59,99 $ (6 kişiye kadar, Lifetime'da yok), Teams (koltuk başı, 5 kişi yıllık 134,95 $). Setapp aboneliğine dahil. Web'den alınırsa lisans anahtarı ile "Direct" sürüm.
- **Tarihçe kısaca:** 2015 tam ekran uygulama, 2016 alttan açılan panel + pinboard, 2018 iOS + sync + Paste Stack, 2020 düzenleme/Siri/bağlantı önizleme, 2023 Paste 4 (yeniden boyutlanabilir pencere, Compact Mode), 2024 4.4 (zengin önizleme, OCR, renk seçici), 2025 Paste 5 (paylaşılan pinboard, yeni sync motoru), Paste 6 (Liquid Glass), Kasım 2025 Writing Tools, Aralık 2025 Power Search, Mart 2026 pinboard filtresi, Nisan 2026 Jump to History, Haziran 2026 Paste MCP, Eylül/Ekim 2026 Paste 7 Intelligent Clipboard.
- Kaynaklar: https://apps.apple.com/us/app/paste-limitless-clipboard/id967805235 · https://pasteapp.io/about · https://pasteapp.io/help/choose-a-plan · https://pasteapp.io/teams · https://pasteapp.io/blog/paste-evolution-through-the-years · https://www.producthunt.com/p/paste/paste-7 · https://setapp.com/apps/paste

---

## 1. Ana arayüz

### 1.1 Alttan açılan yatay şerit
- **Ne yapar:** Kopyalanan her şey en yeniden eskiye doğru yatay bir "görsel zaman çizelgesi" olarak, ekranın alt kenarına yapışık bir pencerede gösterilir. Açılınca aşağıdan yukarı kayarak gelir.
- **Nasıl kullanılır:** ⇧⌘V veya menü çubuğu simgesine tıklama. ←/→ ile gezinme, trackpad/fare ile kaydırma, Esc ile kapatma. Pencerenin üst kenarı sürüklenerek yükseklik (ve dolayısıyla kart boyutu / görünen kart sayısı) değiştirilir. Çoklu ekranda o an çalışılan ekranda açılır; belirli bir ekrana sabitleme seçeneği yok.
- **Konum seçenekleri:** Yardım belgesinde yalnızca alt şerit anlatılıyor; sol/sağ/üst konum seçeneği **doğrulanamadı** (büyük olasılıkla yok).
- **Teknik ipucu:** Aktif ekranda açılması, odaktaki pencerenin bulunduğu `NSScreen`'in seçildiğini düşündürüyor (**tahmin**). Paste 4'ten beri SwiftUI kullanıldığı, 6.6.10'da "SwiftUI temeli yeniden inşa" edildiği sürüm notlarında var.
- **Pastronaut'ta var mı:** **Yok** (Pastronaut menü çubuğu/popup listesi).
- **Kaynak:** https://pasteapp.io/help/paste-on-mac · https://www.macstories.net/reviews/paste-the-clipboard-management-utility-gets-an-elegant-new-design-on-the-mac/ · https://www.macworld.com/article/804417/paste-review.html

### 1.2 Kart tasarımı
- **Ne yapar:** Her öğe kare bir kart. Üst bölümde düzenlenebilir başlık, kopyalanma zamanı ve (büyük boyutta) kaynak uygulamanın simgesi; gövdede içerik önizlemesi; altbilgide türe göre ayrıntı (bağlantıda sayfa başlığı + URL, metinde karakter sayısı). 9to5Mac arayüzü "renkli" olarak tanımlıyor.
- **Paste 6 (Liquid Glass):** Yuvarlatılmış kart şekilleri, sistem paletinden canlı vurgu renkleri; büyük kart ile Compact Mode arasında birkaç boyut, hepsi aynı cam karakteri koruyor.
- **Kart başlığının kaynak uygulamanın rengine boyanması:** Kullanıcı ekran görüntülerinden bilinen bir detay ama metin kaynağında açıkça yazmıyor → **doğrulanamadı**.
- **Pastronaut'ta var mı:** **Kısmen** (satır + içerik türü simgesi + kaynak bilgisi var; kart düzeni, karakter sayısı/URL altbilgisi yok).
- **Kaynak:** MacStories (Paste 4.0, 28 Haz 2023) · https://9to5mac.com/2023/06/30/paste-clipboard-manager-macos/ · https://pasteapp.io/blog/paste-in-liquid-glass

### 1.3 Compact Mode
- **Ne yapar:** Pencere küçültüldüğünde otomatik olarak içerik/önizleme odaklı yoğun görünüme geçer; daha çok öğe sığar.
- **Nasıl kullanılır:** Ayrı bir anahtar değil, pencere yüksekliğine bağlı (sürükleyerek).
- **Teknik ipucu:** Yükseklik eşiğine göre düzen değiştiren duyarlı (responsive) görünüm (**tahmin**).
- **Pastronaut'ta var mı:** **Yok.**
- **Kaynak:** https://pasteapp.io/help/paste-on-mac · https://pasteapp.io/updates

### 1.4 Önizleme türleri
- **Ne yapar:** Metin, zengin metin, görsel, video, PDF, dosya, bağlantı (küçük resimli zengin önizleme), renk (renk örneği). Bağlantılar dahili bir tarayıcıda açılır.
- **Renk algılama kuralı (somut ve kopyalanabilir):** 6 haneli hex kodu yalnızca başında `#` varsa **veya** en az bir A–F harfi içeriyorsa renk sayılır (`#1A2B3C` ve `1a2b3c` renk; `235442` metin). 3 haneli (`#FFF`), `rgb()`, renk adları ve çevresinde başka metin olan hex'ler düz metin kalır.
- **Kod önizlemesi / sözdizimi renklendirme:** **doğrulanamadı** (Setapp "kod parçacıklarını sakla" diyor ama ayrı kod türü/renklendirme belgelenmemiş).
- **Pastronaut'ta var mı:** **Kısmen** (önizleme paneli ve tür simgeleri var; zengin bağlantı önizlemesi/dahili tarayıcı yok; renk türü var — algılama kuralı karşılaştırılmalı).
- **Kaynak:** https://pasteapp.io/help/what-paste-captures · https://pasteapp.io/updates (Link Previews, 6 May 2020)

### 1.5 Quick Look / büyük önizleme
- **Ne yapar:** Space ile seçili öğenin büyük önizlemesi (metin, görsel, PDF, bağlantı). 4.4'ten beri önizleme aynı zamanda bir düzenleme alanı: başlık değiştirme, sabitleme ve paylaşma doğrudan önizlemeden yapılabilir. 6.6.9'da önizleme öğe metnini gösterecek şekilde iyileştirilmiş.
- **Nasıl kullanılır:** Space; ⌘O ile bağlantı/dosyayı varsayılan uygulamada açma.
- **Pastronaut'ta var mı:** **Kısmen** (önizleme paneli var; Space ile Quick Look tarzı büyütme ve önizlemeden düzenleme/paylaşma yok — doğrulanmalı).
- **Kaynak:** https://pasteapp.io/help/paste-on-mac · https://alternativeto.net/news/2024/7/paste-4-4-released-with-enhanced-previews-text-recognition-and-seamless-document-scanning

### 1.6 Kaynak uygulama ve zaman gösterimi
- **Ne yapar:** Her kartta kaynak uygulama ve kopyalama zamanı. Zaman biçimi (göreli mi mutlak mı) **doğrulanamadı**.
- **Pastronaut'ta var mı:** **Var** (gün başlıkları ile; Paste'te gün başlığı olup olmadığı **doğrulanamadı**).
- **Kaynak:** https://pasteapp.io/help/paste-on-mac

---

## 2. Pinboard'lar (koleksiyonlar)

### 2.1 Oluşturma, ad, renk
- **Ne yapar:** Konuya/projeye göre gruplanmış, süresi dolmayan öğe listeleri. Pinboard'lar geçmiş saklama süresinden muaftır.
- **Nasıl kullanılır:** Araç çubuğundaki **+** ya da ⇧⌘N → ad + renk seç. Düzenleme/silme bağlam menüsünden. **Pinboard silinirse içindeki tüm öğeler de silinir.** Simge (ikon) seçimi belgelenmemiş → **doğrulanamadı**.
- **Pastronaut'ta var mı:** **Yok** (sadece tekil sabitleme var).
- **Kaynak:** https://pasteapp.io/help/organize-with-pinboards

### 2.2 Öğe ekleme, sürükle-bırak, sıralama
- **Ne yapar / nasıl:** Bağlam menüsünden **Pin** → pinboard seç; öğeyi pinboard'a sürükle; ⌘A veya ⇧-tık ile toplu seçip sağ tık → Pin. Pinboard içinde öğeler sürükle-bırak ile yeniden sıralanır; pinboard'ların kendisi de listede sürüklenerek sıralanır.
- **Kurallar:** Bir öğe aynı anda yalnızca bir pinboard'da olabilir (taşımak = başka pinboard'a almak). Sabitlemek öğeyi geçmişten çıkarmaz; geçmişten düşse bile pinboard'da kalır.
- **Gezinme:** ⌘← / ⌘→ ile önceki/sonraki pinboard (özelleştirilebilir). Eski sürümlerde ⇧⌘V'ye tekrar basmak pinboard'lar arasında dolaşıyordu (2.5).
- **Teknik ipucu:** "Tek pinboard" kuralı, öğe modelinde tek bir `pinboardID` alanı olduğunu düşündürüyor (**tahmin**).
- **Pastronaut'ta var mı:** **Yok** (harf kısayollu sabitleme var, koleksiyon yok).
- **Kaynak:** https://pasteapp.io/help/organize-with-pinboards · https://pasteapp.io/help/keyboard-shortcuts · https://pasteapp.io/updates

### 2.3 Paylaşılan pinboard'lar (Paste 5, Mayıs 2025)
- **Ne yapar:** Bir pinboard'u ekip, aile veya müşterilerle paylaşma. Herkes aynı içeriği görür, değişiklikler otomatik eşitlenir.
- **Nasıl kullanılır:** Pinboard'a sağ tık → Paylaş; Mesajlar/Mail ile davet ya da bağlantı kopyala. İzinler: salt okunur, yalnız davetliler, bağlantıya sahip herkes; ortaklar ekleyip silebilir. "Manage Shared Pinboard" ile katılımcı çıkarma, "Stop Sharing" ile herkesten anında kaldırma. Katılımcıların Paste kurulu ve iCloud'a giriş yapmış olması gerekir.
- **Teknik ipucu:** "Apple'ın yerel iCloud paylaşımı" kullanıldığı söyleniyor; davet/izin modeli (Mesajlar/Mail, bağlantı, okuma/yazma) CloudKit `CKShare` + paylaşılan veritabanı ile birebir örtüşüyor (**tahmin**, kaynak CloudKit adını vermiyor). Uyarı: sync kapatılırsa sahip olunan paylaşılan pinboard'lar tüm katılımcılardan silinir — bu da `CKShare` sahiplik davranışına uyuyor (**tahmin**).
- **Teams:** Kişisel geçmiş herkese özel; yalnızca paylaşılan pinboard görünür. Tek lisans anahtarı, cihaz başı koltuk; yönetim paneli/SSO yok.
- **Pastronaut'ta var mı:** **Yok.**
- **Kaynak:** https://pasteapp.io/help/shared-pinboards · https://pasteapp.io/teams · https://pasteapp.io/help/icloud-sync-doesn-t-work

---

## 3. Arama ve filtreler

### 3.1 Anında arama
- **Ne yapar:** Başlık, içerik, meta veri ve görsellerdeki metin üzerinde yazdıkça güncellenen arama. Yazım hatası toleranslı; sıralama alaka + yenilik karışımı. Eşleşen metin sonuçlarda vurgulanır.
- **Nasıl kullanılır:** Paste açıkken doğrudan yazmaya başla veya ⌘F. Return ile sonuçlara geç, ←/→ ile gez (her zaman bir sonuç seçili), Return ile yapıştır, Tab ile alan↔sonuç arası geçiş, Esc kapatır.
- **Teknik ipucu:** Ayrı bir "search index" var (sürüm notlarında "search index auto-rebuild", "search indexing" düzeltmeleri; 6.5.1'de öneriler kelime sınırında eşleşiyor). Muhtemelen SQLite FTS veya benzeri tam metin indeksi (**tahmin**). 6.3.2'de "bloklamayan arama" yani arka planda çalışan sorgu.
- **Pastronaut'ta var mı:** **Var** (arama var; OCR, bulanık eşleşme, vurgulama karşılaştırılmalı).
- **Kaynak:** https://pasteapp.io/help/search-and-filters · https://pasteapp.io/blog/paste-power-search

### 3.2 Filtreler (Power Search, Aralık 2025)
- **Ne yapar:** Tür (metin, görsel, dosya, bağlantı), kaynak uygulama, cihaz (Mac/iPhone…), tarih aralığı ve (Mart 2026'dan beri) bir veya birden çok pinboard'a göre süzme. Filtreler birleştirilebilir.
- **Nasıl kullanılır:** Yazarken filtre önerileri satır içinde çıkar; seçilen filtreler arama alanında "token" (çip) olarak görünür. Tüm filtreler için filtre düğmesi veya arama etkinken ⌘F'ye ikinci kez basmak. Özel sözdizimi (ör. `app:`) belgelenmemiş → **doğrulanamadı**.
- **Pastronaut'ta var mı:** **Kısmen** (Tümü/Bu Mac/iPhone cihaz filtresi var; tür/uygulama/tarih/koleksiyon filtresi ve token arayüzü yok).
- **Kaynak:** https://pasteapp.io/blog/paste-power-search · https://pasteapp.io/updates

### 3.3 Görsellerde metin (OCR)
- **Ne yapar:** Ekran görüntüsü, not/beyaz tahta fotoğrafı, taranmış belge içindeki metinler aranabilir; ayrıca önizlemede görselden metin çıkarma (4.4).
- **Teknik ipucu:** Motor adı verilmiyor; macOS'ta yerel OCR için akla gelen Vision `VNRecognizeTextRequest` / VisionKit (**tahmin**).
- **Pastronaut'ta var mı:** **Yok.**
- **Kaynak:** https://pasteapp.io/help/search-and-filters · https://pasteapp.io/updates

### 3.4 Jump to History (Nisan 2026)
- **Ne yapar:** Bir arama sonucundan, öğenin geçmişteki ya da pinboard'daki asıl yerine gider; çevresindeki öğelerle birlikte "oturum bağlamını" gösterir.
- **Nasıl kullanılır:** Sonuca sağ tık → "Show in Clipboard" / "Show in <Pinboard>", veya ⌘G (tek seçimde). Arama kapanır, liste o öğeye kayar.
- **Pastronaut'ta var mı:** **Yok.**
- **Kaynak:** https://pasteapp.io/blog/jump-to-history · https://pasteapp.io/help/search-and-filters

### 3.5 Akıllı arama / Intelligent Clipboard
- Bkz. §11.2. Anlamsal (semantik) arama ayrıca belgelenmemiş → **doğrulanamadı**.

---

## 4. Klavye odaklı kullanım

### 4.1 Kısayol tablosu (Mac, resmi)
| Eylem | Kısayol |
|---|---|
| Paste'i aç/kapat | ⇧⌘V (özelleştirilebilir) |
| Paste Stack | ⇧⌘C (özelleştirilebilir) |
| Kapat | Esc |
| Sonraki/önceki öğe | → / ← |
| İlk/son öğe | ⌘↑ / ⌘↓ |
| Seçimi genişlet | ⇧→ / ⇧← |
| Tümünü seç | ⌘A |
| Yapıştır / düz metin yapıştır | Return / ⇧Return |
| Hızlı yapıştır 1–9 / düz metin | ⌘1–9 / ⇧⌘1–9 |
| Panoya kopyala | ⌘C |
| Quick Look | Space |
| Bağlantı/dosyayı aç | ⌘O |
| Yeniden adlandır / düzenle | ⌘R / ⌘E |
| Yeni metin öğesi | ⌘N |
| Sil / geri al | Delete / ⌘Z |
| Ara / tüm filtreler | ⌘F / ⌘F (tekrar) |
| Arama alanı ↔ sonuçlar | Tab |
| Geçmişte göster | ⌘G |
| Yeni pinboard | ⇧⌘N |
| Sonraki/önceki pinboard | ⌘→ / ⌘← (özelleştirilebilir) |
| Duraklat | ⌘T |
| Ayarlar / çık | ⌘, / ⌘Q |

- **Özelleştirme:** Yalnızca 4 kısayol (aç/kapat, Paste Stack, sonraki/önceki pinboard) değiştirilebilir; ayrıca Hızlı Yapıştır'ın ⌘ değiştiricisi ve Düz Metin modunun ⇧ değiştiricisi tek bir başka tuşla (⌘/⇧/⌃/⌥) değiştirilebilir. "Sıfırla" seçeneği var. Belirli bir öğeye özel global kısayol **yok** (yardım belgesi "ileride planlanıyor" diyor). Setapp sayfası "hızlı eylemler için özel kısayollar" diyor ama bu resmi belgeyle çelişiyor → **doğrulanamadı**.
- **Pastronaut'ta var mı:** **Kısmen** (Maccy'den gelen ⌘1–9 tarzı kısayollar ve harf kısayollu sabitleme var; ⌘E/⌘R/⌘N/⌘G/⌘T gibi zengin set ve ⇧-ile-düz-metin değiştiricisi karşılaştırılmalı).
- **Kaynak:** https://pasteapp.io/help/keyboard-shortcuts · https://pasteapp.io/help/quick-paste-with-numbered-shortcuts

### 4.2 Sayılarla hızlı yapıştırma
- **Ne yapar:** Paste açıkken ⌘ basılı tutulunca kartlarda numara görünür; ⌘+rakam o öğeyi yapıştırır. Geçerli listeye (geçmiş veya pinboard) uygulanır. Paste kapalıyken çalışmaz.
- **Pastronaut'ta var mı:** **Var** (Maccy kalıtımı).
- **Kaynak:** https://pasteapp.io/help/paste-on-mac · https://pasteapp.io/help/quick-paste-with-numbered-shortcuts

### 4.3 Çoklu seçim
- **Ne yapar:** ⌘/⇧ ile birden çok öğe seçip birlikte yapıştırma, kopyalama, silme (6.3.8'den beri çoklu silmede onay), toplu sabitleme. Birlikte yapıştırmada ayırıcı karakter (satır sonu vb.) seçeneği **doğrulanamadı**.
- **Pastronaut'ta var mı:** **Doğrulanmalı** (Maccy'de çoklu seçim sınırlı; Pastronaut kodu kontrol edilmeli).
- **Kaynak:** https://pasteapp.io/help/paste-on-mac · App Store sürüm notları

### 4.4 Paste Stack (sıralı yapıştırma)
- **Ne yapar:** ⇧⌘C ile açılan "geçici, ad hoc pinboard". Açıkken kopyalanan her şey sırayla yığına eklenir; her ⌘V sıradaki öğeyi yapıştırır (yukarıdan aşağı). Ok düğmesiyle yön tersine çevrilir. Yığında zaten olan bir öğe yeniden kopyalanırsa eski kopya otomatik silinir. Öğe silme: bağlam menüsü veya iki parmakla sola kaydırma.
- **Teknik ipucu:** Erişilebilirlik izniyle ön plandaki uygulamaya sentetik ⌘V (yığın modunda ⌘C de) gönderiyor — resmi belge bunu açıkça söylüyor. Muhtemelen `CGEvent` klavye olayları (**tahmin**).
- **Bilinen zayıflıklar (Macworld 2022):** Yığın oturumlar arası kalıcı değil; ⇧⌘C kısayolu ⌘C'ye çok yakın, yanlışlıkla yığını silebiliyor.
- **Pastronaut'ta var mı:** **Var** (Maccy'den). Ters yön düğmesi ve yinelenenleri ayıklama karşılaştırılmalı.
- **Kaynak:** https://pasteapp.io/help/using-paste-stack · https://pasteapp.io/help/paste-directly-to-other-applications · https://www.macworld.com/article/804417/paste-review.html

### 4.5 Düz metin olarak yapıştırma
- **Ne yapar / nasıl:** ⇧Return, ⇧⌘1–9 veya bağlam menüsü "Paste as Plain Text". Genel ayar "Always paste as Plain Text" (Ayarlar → General) her şeyi biçimsiz yapıştırır. Değiştirici tuş özelleştirilebilir.
- **Pastronaut'ta var mı:** **Var** (Maccy'de ⌥ ile düz metin var; değiştirici seçimi kontrol edilmeli).
- **Kaynak:** https://pasteapp.io/help/paste-as-plain-text

### 4.6 Doğrudan yapıştırma
- **Ne yapar:** Seçilen öğeyi doğrudan aktif uygulamaya yapıştırır ("Paste items: To active app"). Erişilebilirlik izni yoksa öğeyi panoya koyar, kullanıcı ⌘V'ye basar. macOS 27'de izin bölümü "Device Control and Data Access" adını almış.
- **Pastronaut'ta var mı:** **Var** (Maccy kalıtımı).
- **Kaynak:** https://pasteapp.io/help/paste-directly-to-other-applications · https://pasteapp.io/help/copy-paste-not-working

---

## 5. Metin işlemleri

| Özellik | Ne yapar / nasıl | Pastronaut | Kaynak |
|---|---|---|---|
| Düzenleme | ⌘E, bağlam menüsü veya doğrudan önizlemede; değişiklik öğeye yerinde kaydedilir, biçim korunur; düzenlemeler cihazlar arasında eşitlenir | **Var** | /help/edit-items-before-pasting |
| Yeniden adlandırma (etiket/başlık) | ⌘R, bağlam menüsü veya başlığa tıklama; başlık aramada kullanılır | **Doğrulanmalı** (Pastronaut'ta öğe başlığı yok sanıyorum) | aynı |
| Yeni öğe oluşturma | ⌘N ile kopyalamadan metin veya bağlantı öğesi | **Doğrulanmalı** | /updates (Tem 2024) |
| Bağlantı düzenleme | Dahili tarayıcıda URL düzenleme | **Yok** | /updates |
| Görsel döndürme | Önizlemede hızlı eylem | **Yok** | /help/edit-items-before-pasting |
| Görselden metin çıkarma | Önizlemede OCR | **Yok** | aynı |
| Renk seçici | Kopyalanmış rengi ayarlama | **Yok** | /updates |
| Apple Intelligence Writing Tools | Düzenlerken yeniden yazma, düzeltme, özetleme (Kasım 2025) | **Yok** | /updates · /help/paste-on-mac |
| Büyük/küçük harf vb. dönüşümler | **doğrulanamadı** (hiçbir kaynakta yok) | — | — |
| Öğeleri birleştirme (merge) | **doğrulanamadı** (App Store açıklamasında yok) | — | — |
| Dosya/.docx/HTML/kodu düz metne çevirme | Setapp sayfası iddia ediyor; resmi belgede ayrıca yok → kısmen doğrulandı | **Kısmen** | setapp.com/apps/paste |

- **Teknik ipucu:** Writing Tools, macOS 15.1+/26'da standart `NSTextView`'a otomatik gelir; Paste'in editörü sistem metin görünümü kullanıyorsa ekstra kod gerekmeden çıkar (**tahmin**).

---

## 6. Eşitleme (iCloud)

- **Ne yapar:** Geçmiş ve pinboard'lar (adları ve içerikleri dahil) Mac, iPhone ve iPad arasında kullanıcının özel iCloud hesabı üzerinden eşitlenir. Sunucu yok; "hiçbir zaman bizim sunucularımıza dokunmaz".
- **Nasıl kullanılır:** Varsayılan **kapalı**, cihaz başına açılır (Ayarlar → General → iCloud sync). Elle eşitleme düğmesi yok, otomatik. İlk büyük eşitleme için uygulamanın birkaç dakika açık kalması öneriliyor, sonrası öğe öğe. Sıfırlama: Sistem Ayarları → Apple Hesabı → iCloud → Yönet → Paste → iCloud'dan Sil.
- **İçerik türleri:** App Store açıklaması metin, bağlantı, görsel ve dosyaların saklandığını ve iCloud ile eşitlendiğini söylüyor; yani **görseller ve dosyalar da eşitleniyor** gibi görünüyor, ancak her türün eşitlenip eşitlenmediği ve **boyut sınırı resmi olarak belgelenmemiş → doğrulanamadı**. Product Hunt'ta büyük öğelerin (görsel, kod blokları) nasıl eşitlendiği sorulmuş, yanıt yok.
- **Uçtan uca şifreleme:** Gizlilik politikası ve yardım belgeleri E2E veya Advanced Data Protection'dan **bahsetmiyor → doğrulanamadı**. Yalnızca "özel iCloud" ifadesi var.
- **Ek iOS/çapraz cihaz:** Handoff ile öğe aktarma, Universal Clipboard ile birlikte çalışma, iOS'ta Paste Keyboard, paylaşım eklentileri, widget.
- **Teknik ipucu:** "Özel iCloud", "ayarlar → iCloud → Paste → Delete from iCloud" yolu ve paylaşılan pinboard yapısı CloudKit özel + paylaşılan veritabanına işaret ediyor (**tahmin**). Paste 5'te "sync motoru baştan yazıldı"; 6.5.2'de "geçici sync dosyalarının diski doldurması" hatası düzeltilmiş → görseller/dosyalar `CKAsset` gibi geçici dosya üzerinden yükleniyor olabilir (**tahmin**). Birçok sürüm notunda "duplicate" ve sync düzeltmeleri var → eşitleme, Paste'in de sürekli sorun yaşadığı alan.
- **Pastronaut'ta var mı:** **Kısmen** (CloudKit ile yalnızca METİN; görsel/dosya ve pinboard eşitlemesi yok).
- **Kaynak:** https://pasteapp.io/help/icloud-sync-doesn-t-work · https://pasteapp.io/help/where-paste-stores-your-data · https://pasteapp.io/privacy · App Store sayfası · https://www.producthunt.com/p/paste (Paste 6 yorumları)

### 6.1 Veri saklama, yedekleme, taşıma
- Veriler cihazda yerel; Time Machine yedeğine dahil. Yeni Mac'e geçiş için aynı Apple hesabı + iCloud sync. Elle dışa/içe aktarma özelliği **belgelenmemiş** (muhtemelen yok). Dosya yolu/veritabanı biçimi **doğrulanamadı**.
- **Pastronaut'ta var mı:** **Kısmen** (yerel depolama var; dışa aktarma durumu kontrol edilmeli).
- **Kaynak:** https://pasteapp.io/help/where-paste-stores-your-data

---

## 7. Gizlilik

| Özellik | Ne yapar / nasıl | Pastronaut | Kaynak |
|---|---|---|---|
| Ignore Applications | Ayarlar → Privacy → +/− ile uygulama dışlama; yalnızca yeni kopyalara etki eder. Varsayılan dışlanan uygulama listesi **doğrulanamadı** | **Var** | /help/exclude-apps |
| Ignore confidential content | Parola yöneticilerinin "gizli" olarak işaretlediği içerik kaydedilmez. Tarayıcı eklentisi tabanlı parola yöneticileri algılanamayabilir → tarayıcıyı dışla önerisi | **Var** (Maccy'de concealed türü yok sayılır) | /help/what-paste-captures |
| Ignore transient content | Uygulamaların "geçici" işaretlediği veriyi atlar | **Var** | aynı |
| Teknik ipucu | nspasteboard.org'daki `org.nspasteboard.ConcealedType` / `TransientType` konvansiyonları (**tahmin**, Maccy ile aynı mekanizma olması muhtemel) | — | — |
| Pause Paste | ⌘T veya menü çubuğu; belirli bir süre (seçilebilir) ya da elle devam; duraklarken hiçbir şey kaydedilmez (Şubat 2024 "Advanced Pause") | **Doğrulanmalı** (Maccy'de "Ignore/Pause" var) | /help/paste-on-mac · /updates |
| Ekran paylaşımında gizleme | "Show during screen sharing" anahtarı (Ekim 2025); App Store "ekran paylaşımı ve kayıtlardan gizle" diyor | **Yok** | /updates · App Store |
| Teknik ipucu | `NSWindow.sharingType = .none` ile pencereyi ekran yakalamadan hariç tutma (**tahmin**) | — | — |
| Geçmiş saklama süresi | 1 Gün / 1 Hafta / **1 Ay (varsayılan)** / 1 Yıl / Sonsuz. Süre kısaltılınca eski öğeleri silmek için onay ister (geri alınamaz). Sabitlenen/pinboard öğeleri muaf. "Erase History" düğmesi | **Kısmen** (Maccy sayı tabanlı sınır; süre tabanlı saklama kontrol edilmeli) | /help/control-history-retention |
| Regex / pano türü kuralları | **Paste'te belgelenmemiş** → Pastronaut bu konuda ileride | Pastronaut **daha güçlü** | — |
| Tek kullanımlık kod/kart/IBAN filtresi | **Paste'te belgelenmemiş** | Pastronaut **daha güçlü** | — |
| Intelligent Clipboard gizliliği | Parola alanlarında öneri yok; dışlanan uygulamalar okunmaz; ekran yalnız pencere açıkken okunur, saklanmaz | — | /help/intelligent-clipboard |
| Telemetri | PostHog (AB, anonim kullanım), Sentry (çökme), web için Plausible | — | /privacy |

---

## 8. Kurallar / otomasyon

- **Shortcuts (Kestirmeler):** Paste 3.1 (Ekim 2021) ile macOS Monterey'de. Belgelenen eylemler: pinboard'a metin/bağlantı ekle, pinboard'dan son metni/bağlantıyı al, pinboard'dan sıradaki (index) öğeyi al. MacStories 2023 adlarını "Add Item, Get Latest Item, Get Item at Index" olarak veriyor. Siri ifadeleri Ayarlar → "Siri & Shortcuts" bölümünden bağlanıyor (2020). Güncel (2026) eylem listesi **doğrulanamadı**; 6.3.3'te "Siri Shortcut düzeltmesi" var, yani hâlâ mevcut.
- **AppleScript:** Hiçbir kaynakta **yok/doğrulanamadı**.
- **"Rules":** App Store'daki "rules" kelimesi yalnızca parola/hassas içerik atlama kurallarını ifade ediyor; içerik dönüştüren ya da otomatik pinboard'a atan "akıllı kurallar" **belgelenmemiş**.
- **Paste MCP (Haziran 2026, yalnız Mac):** Yerleşik yerel MCP sunucusu. Bağlanan AI aracı (Claude Desktop/Code, Codex, Cursor, VS Code, Windsurf, özel) geçmişi zaman/tür/uygulamaya göre arayabilir, öğeleri bağlam olarak okuyabilir, yeni öğe kaydedebilir ve pinboard oluşturup yönetebilir. Ayarlar → Intelligence → MCP & AI tools → Enable MCP → Connect AI Tool. Özel araç için "Server URL" + "Token" veriliyor. Bağlı araçlar listelenip erişim geri alınabiliyor.
  - **Teknik ipucu:** URL + token verilmesi, stdio değil yerel HTTP (localhost) taşıyıcısı olduğunu düşündürüyor (**tahmin**). Araç adları/şemaları **doğrulanamadı**. Hassas içerik maskeleme (redaction) sorusu yanıtsız.
- **Pastronaut'ta var mı:** Shortcuts **doğrulanmalı** (Maccy'de App Intents var olabilir), MCP **Yok**, AppleScript **Yok**.
- **Kaynak:** https://pasteapp.io/blog/hey-siri · https://pasteapp.io/updates · https://pasteapp.io/help/paste-mcp · https://pasteapp.io/help/connect-custom-mcp · https://pasteapp.io/blog/paste-mcp · MacStories 2023

---

## 9. Paylaşım

- **Sürükle-bırak:** Öğeleri başka uygulamalara sürükleyip bırakma; Mayıs 2024'ten beri görseller **dosya olarak** sürüklenebiliyor (web sayfalarına yükleme vb.). Kopyalanan dosyaların hangi uygulamayla açılacağını seçme.
- **Paylaş menüsü / AirDrop:** 4.4'ten beri önizlemeden "paylaş"; Setapp sayfası AirDrop ile gönderimi belirtiyor. Mac'te sistem paylaşım menüsü (`NSSharingServicePicker`) kullanılıyor olabilir (**tahmin**).
- **Handoff:** Cihazlar arası öğe devri (App Store).
- **Paylaşılan pinboard:** §2.3.
- **Pastronaut'ta var mı:** Sürükle-bırak **doğrulanmalı**, paylaşım menüsü **Yok**, Handoff **Yok**.
- **Kaynak:** https://pasteapp.io/updates · https://setapp.com/apps/paste · App Store

---

## 10. Ayarlar ve özelleştirme

| Ayar | Bilinen | Kaynak |
|---|---|---|
| General | Keep History (süre), Erase History, iCloud sync, "Paste items to active app", "Always paste as Plain Text", Run in background (App Store sürümü) | /help/control-history-retention · /help/copy-paste-not-working |
| Privacy | Ignore Applications, Ignore confidential content, Ignore transient content, Show during screen sharing | /help/exclude-apps · /updates |
| Shortcuts | 4 kısayol + 2 değiştirici + sıfırla | /help/keyboard-shortcuts |
| Intelligence | Intelligent Clipboard anahtarı, MCP & AI tools | /help/intelligent-clipboard |
| Siri & Shortcuts | Siri ifadeleri (2020 kaynağı) | /blog/hey-siri |
| Menü çubuğu simgesi | Gizlenebilir; ⌃-tık ile ek menü (Mayıs 2024) | /help/copy-paste-not-working · /updates |
| Tema | Sistem açık/koyu modu takip ediyor (2018'den beri koyu mod); ayrı tema seçimi **doğrulanamadı** | evolution blog |
| Konum | Yalnız alt şerit; başka konum **doğrulanamadı** | /help/paste-on-mac |
| Kart boyutu | Pencere yüksekliği ile (sürükleme), birkaç boyut + Compact Mode | /help/paste-on-mac · Liquid Glass blog |
| Ses | 2015 civarı bir incelemede kopyala/yapıştır sesleri ve kapatma seçeneği; güncel sürümde **doğrulanamadı** | sspai.com/post/29966 |
| Erişilebilirlik | VoiceOver, Larger Text, Dark Interface, Differentiate Without Color | App Store |
| Dil | 16 dil (Türkçe **yok**) | App Store |

- **Pastronaut'ta var mı:** **Kısmen** (Maccy ayarları: geçmiş boyutu, yok sayma, görünüm; konum/kart boyutu kavramı yok).

---

## 11. En yeni sürümler (2025–2026)

### 11.1 Paste 6 — Liquid Glass (15 Eylül 2025)
- macOS 26 Tahoe ve "OS 26 ailesi"ne göre baştan tasarım: yüzen, yarı saydam derinlikli ana pencere; kenarları "dokunulmamış" cam hissi; yuvarlak kartlar; sistem paletinden vurgu renkleri; önizlemeler ana pencereyle hizalı; Ayarlar Tahoe stilinde yeniden; yeni simge. Product Hunt'ta günün 4.'sü. 6.6.10'da (Eylül 2026) SwiftUI temeli yeniden inşa.
- **Pastronaut'ta var mı:** **Var** (Liquid Glass görünüm).
- **Kaynak:** https://pasteapp.io/blog/paste-in-liquid-glass · https://www.hunted.space/product/paste/launches/paste-6

### 11.2 Paste 7 — Intelligent Clipboard (blog 28 Eylül 2026; App Store 7.0.0 21 Eylül; PH lansmanı ~16 Ekim 2026)
- **Ne yapar:** Araç çubuğundaki Suggestions (kıvılcım simgeli) düğmesiyle, o an yapıştırılacak hedef uygulamaya/ekran bağlamına göre geçmişten en olası öğeleri sıralayan kısa bir öneri satırı. Önce en olası öğe. Tekrar tıklayınca tam geçmiş. "Öneriyor, karar vermiyor."
- **Gereksinim:** macOS 26+, Apple Intelligence açık, **Ekran Kaydı izni** (ilk kullanımda istenir, uygulama yeniden başlatılır).
- **Gizlilik:** Ekran yalnızca Paste penceresi açıkken okunur, veri saklanmaz/gönderilmez; parola alanları ve dışlanan uygulamalar hariç. Ayarlar → Intelligence veya düğmeye sağ tık → Turn Off.
- **Teknik ipucu:** Ekran Kaydı izni → ScreenCaptureKit ile hedef pencere görüntüsü/metni alınıyor; sıralama cihaz üstü Apple Foundation Models ile (maker "Apple'ın yerleşik cihaz üstü modelleri" dedi). Klavyeyle tetikleme sorusu yanıtsız → klavye kısayolu **doğrulanamadı**.
- **Pastronaut'ta var mı:** **Yok.**
- **Kaynak:** https://pasteapp.io/help/intelligent-clipboard · https://pasteapp.io/blog/intelligent-clipboard · https://www.producthunt.com/p/paste/paste-7

### 11.3 Diğer 2025–2026 eklemeleri
- Writing Tools (Kasım 2025), ekran paylaşımında gizleme (Ekim 2025), Power Search + OCR (Aralık 2025), pinboard filtresi (Mart 2026), Jump to History + iOS klavye yenilemesi (Nisan 2026), Paste MCP (Haziran 2026), büyük geçmişlerde performans ve arama indeksi otomatik yeniden oluşturma (Haziran–Ağustos 2026).
- macOS 26'da Spotlight'ın kendi pano geçmişi (⌘Space → ⌘4; 30 dk/8 sa/7 gün) geldi; Paste kendini kalıcı arşiv + çapraz cihaz + pinboard + görsel/dosya ile konumluyor.
- **Kaynak:** https://pasteapp.io/updates · https://pasteapp.io/blog/macos-tahoe-clipboard-history

---

## 12. UI/UX'in güçlü yanları

- **Görsel tarama:** Büyük, türe özel önizlemeler (görsel küçük resmi, bağlantı kapağı, renk örneği) kelime okumadan tanımayı sağlıyor. Kaynak uygulama simgesi ikinci bir tanıma ipucu.
- **Tek eksenli gezinme:** Her şey ←/→ ile; ⌘↑/⌘↓ uçlara; ⌘←/⌘→ pinboard'lar arası. Öğrenme yükü düşük.
- **Yoğunluk kontrolü doğrudan manipülasyonla:** Ayar menüsü yerine pencere kenarını sürükleyerek kart boyutu/Compact Mode.
- **Animasyon:** Alttan kayarak açılma; Paste 6 ile daha akıcı geçişler (ayrıntı belgelenmemiş).
- **Keşfedilebilirlik:** ⌘ basılı tutunca kartlarda numaralar beliriyor; filtreler yazarken satır içi öneri; aktif filtreler token olarak görünür; her eylemin bağlam menüsü karşılığı var.
- **İlk açılış rehberi:** Kısa kurulum — nasıl açılacağı (kısayol), ne kadar geçmiş tutulacağı, macOS/diğer uygulamalarla entegrasyon (erişilebilirlik izni). İzin yoksa zarif geri düşüş (panoya kopyala).
- **Boş durumlar:** Belgelenmemiş → **doğrulanamadı**.
- **Bağlamı koruma:** Jump to History, aramayı "çıkmaz sokak" olmaktan çıkarıyor.
- **Sorunlu yanlar (incelemelerden):** abonelik tepkisi (9to5Mac yorumları), Paste Stack kalıcı değil ve ⇧⌘C ⌘C'ye çok yakın (Macworld), müşteri desteği eleştirisi (App Store yorumları), sık sync/yineleme hataları (sürüm notları).

---

## Pastronaut'ta olmayan en önemli 10 özellik

1. **Pinboard'lar (adlandırılmış, renkli koleksiyonlar)** — sürükle-bırakla ekleme/sıralama, saklama süresinden muaf, eşitlenen.
2. **Paylaşılan pinboard'lar** — iCloud paylaşımıyla (muhtemelen `CKShare`) okuma/yazma izinli ortak koleksiyonlar.
3. **Görsel ve dosyaların iCloud ile eşitlenmesi** (Pastronaut yalnız metin eşitliyor; Paste'te boyut sınırı belirsiz).
4. **Görsellerde metin arama (OCR) + önizlemede metin çıkarma.**
5. **Zengin filtreler: tür / kaynak uygulama / tarih aralığı / koleksiyon, satır içi öneri ve token arayüzü.**
6. **Intelligent Clipboard** — hedef uygulama bağlamına göre cihaz üstü (Apple Intelligence) öneri satırı.
7. **Paste MCP** — geçmişi Claude/Cursor gibi AI araçlarına yerel MCP sunucusuyla açma (okuma + öğe kaydetme + pinboard yönetimi).
8. **Ekran paylaşımı/kayıttan gizleme** anahtarı.
9. **Jump to History (⌘G)** — arama sonucunu çevresindeki öğelerle asıl yerinde gösterme.
10. **Önizlemede zengin düzenleme araçları:** başlık/etiket (⌘R), yeni öğe (⌘N), bağlantı düzenleme + dahili tarayıcı, görsel döndürme, renk seçici, Writing Tools; ayrıca Handoff ve paylaşım menüsü.

(Ek adaylar: süre tabanlı saklama seçenekleri — 1 gün…sonsuz; zamanlı duraklatma; Shortcuts eylemleri; görselleri dosya olarak sürükleme.)

## UI/UX'ten öğrenilecek 10 şey

1. **Önizleme öncelikli kartlar:** Tanıma, okumaktan hızlıdır — türe özel büyük önizleme + kaynak uygulama simgesi.
2. **Yoğunluğu sürükleyerek ayarlama:** Ayrı ayar yerine pencere boyutuna duyarlı düzen (normal ↔ compact).
3. **Değiştirici tuşla ipucu gösterme:** ⌘ basılınca numaralar beliriyor; Pastronaut'taki harf kısayollu sabitlemeler için aynı "basılı tutunca rozet göster" yaklaşımı.
4. **Filtreleri arama alanına gömmek:** Yazarken satır içi filtre önerisi, seçilince silinebilir token; ayrı filtre paneline gerek bırakmıyor.
5. **Tutarlı değiştirici semantiği:** ⇧ = düz metin (Return, ⌘1–9 hepsinde aynı). Tek kural, her yerde.
6. **Her klavye eyleminin bağlam menüsü karşılığı** (ve tersi) — keşfedilebilirlik için menüde kısayolu göstermek.
7. **İzin reddinde zarif geri düşüş:** Erişilebilirlik izni yoksa "panoya kopyala, sen yapıştır" moduna geç; kullanıcıyı kilitleme.
8. **Kısa ve karar odaklı ilk açılış:** Yalnızca 3 soru (kısayol, saklama süresi, entegrasyon/izin).
9. **Bağlamı kaybettirmeyen arama:** Sonuçtan "geçmişte göster" ile kronolojik bağlama dönüş; Pastronaut'un gün başlıklarıyla doğal uyum.
10. **Yıkıcı eylemlerde onay ve geri al:** Çoklu silmede onay (6.3.8), saklama süresi kısaltılınca uyarı, ⌘Z geri alma; ayrıca kişisel sezgisel kural gibi küçük ama açık belgelenmiş davranışlar (ör. hex renk algılama kuralı) kullanıcı güvenini artırıyor.

---

## Doğrulanamayan noktalar (özet)

- FIFTYSIX ile bağlantı (yalnızca Paste Team ApS ve maker Dmitry Obukhov doğrulandı).
- Görsel/dosya eşitlemesinin boyut sınırları; uçtan uca şifreleme / Advanced Data Protection desteği; CloudKit kullanımı (yalnızca "özel iCloud" deniyor).
- Kod önizlemesi/sözdizimi renklendirme, büyük/küçük harf dönüşümü, öğe birleştirme (merge), çoklu yapıştırmada ayırıcı.
- AppleScript desteği; güncel Shortcuts eylem listesi; Intelligent Clipboard için klavye kısayolu.
- Alt şerit dışında konum seçeneği, ses ayarı (güncel), tema seçimi, boş durum tasarımı, zaman damgası biçimi, gün başlıkları.
- MCP taşıyıcısı (HTTP olduğu tahmin) ve araç adları.
