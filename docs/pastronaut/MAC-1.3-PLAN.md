# Mac 1.3 planı: iPhone 1.2/1.3 ile gereken Mac işleri (taslak)

> Tarih: 2026-10-22. Durum: **not, onaylanmadı.** iPhone planı: `IOS-1.2-PLAN.md`. Bu belgedeki hiçbir iş iPhone
> 1.2'nin önünü kesmez. Mac'e dokunan her iş, ayrı onayla ve üç kanal kuralıyla (`SURUM.md`) yapılır.

## 1. Mac'in bugünkü sürüm durumu (2026-10-22'de doğrulandı)

| Kanal | Sürüm (derleme) | Nasıl üretiliyor | Kanıt |
|---|---|---|---|
| Mac GitHub (Sparkle) | **0.1.0 (1)**, etiket `v0.1.0` → `1d72abe` (2026-10-18) | Ana dal, Developer ID, notarize, Sparkle | `pastronaut-appcast.xml`, `git tag` |
| Mac App Store | **1.0 (1)**, 2026-10-18'de yüklendi; 2026-10-22'de **"In Review"** | `scripts/appstore/build-mas.sh` HEAD'den Sparkle'sız geçici bir kopya üretir | `YAYIN.md` §D, kullanıcı |
| Projedeki numaralar | `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` (iki satır) | `Maccy.xcodeproj` | `project.pbxproj:1902-1954` |

- **Sparkle farkı:** GitHub ve Mac App Store **aynı kaynaktan** çıkıyor. Ana dal hep Sparkle'lı kalıyor;
  `mas-transform.py`, Sparkle'ı ve güncelleme ayarlarını yalnızca geçici kopyada çıkarıyor. Yani iki ayrı kod dalı
  yok, ama **her Mac sürümünde iki ayrı derleme** var: Developer ID + notarize + appcast ve App Store paketi.
- **Ortak numara:** İki Mac kanalı aynı derleme numarasını kullanıyor. Sıradaki numara **2**. Sparkle güncellemeyi
  bu numarayla anlar: 2 > 1 olduğu için GitHub kullanıcıları 0.1.0'dan doğrudan yeni sürüme geçer.
- **Görünen sürüm:** iPhone'da 1.1 kullanıldı, iPhone 1.2 de tek başına çıkacak. `SURUM.md` kuralına göre
  (aynı numara iki farklı içerikle çıkmaz) Mac'in sıradaki görünen sürümü **1.3** olur. GitHub kullanıcıları
  0.1.0 → 1.3 atlar. Sürüm notunda bu atlama açıklanır.
- **0.1.0'dan beri Mac'i etkileyen değişiklikler az:** Kestirme açıklamalarından Maccy adı kaldırıldı (`5d2c31f`),
  Mac App Store betiği eklendi, çekirdekte iPhone 1.1 için bazı metinler değişti.
- **Mac App Store 1.0 (1) incelemede** (2026-10-22). Onaylanırsa Mac 1.3 bunun üzerine kurulur. Ret gelirse düzeltme
  yalnızca Mac App Store'a **1.0 (2)** olarak gider. Kod değişirse GitHub'a da aynı derleme çıkar; o durumda Mac
  1.3'ün derleme numarası 3 olur.

## 2. Mac 1.3'ün kapsamı (öneri)

### 2.1 Görseller (iPhone 1.3 ile birlikte; ana iş)
- `SyncBridge` görselleri de gönderir:
  - Bugün `syncableText` görsel ya da dosya içeren her kopyayı atlıyor (`Maccy/Sync/SyncBridge.swift:437-467`).
  - Yeni yol: Maccy'nin görsel içeriği (PNG/TIFF/HEIC) bir `Media` kaydı olur. Biçim ve sınırlar iPhone'daki
    Ayarlar › Görseller değerleriyle aynıdır.
- **OCR metni:** Maccy'nin tanıdığı metin (`HistoryItem.recognizeText`) şifreli `recognizedText` alanına yazılır.
  Böylece iPhone'da Vision yeniden çalışmaz.
- **Gelen görseller:** iPhone'dan gelen görsel Mac geçmişine normal bir görsel kopya gibi eklenir (`History.add`),
  "iPhone'dan" işareti korunur.
- **Ayarlar:** Ayarlar › Eşitleme'de aynı görsel ayarları (aç/kapat, kalite, en büyük boyut, iCloud alanı).
- **Dosyalar ve PDF:** Mac'teki dosya yolları telefonda anlamsız (`TASARIM.md` §1). Yalnızca **içeriği panoda
  olan** PDF'ler ve küçük dosyalar düşünülür; dosya yolu eşitlenmez. Ayrı bir karar gerekir.

### 2.2 iPhone 1.2'nin çekirdek değişikliklerini Mac'e taşımak
Bu değişiklikler `PastronautCore` içinde olduğu için Mac'te derlenip test edilir, ama Mac kullanıcılarına ancak bir
Mac sürümüyle ulaşır.
- **K3:** Silme işaretleri; silinen öğenin `.unknownItem` ile geri gelmemesi.
- **K2 / K1:** Mac'in kendi deposu olduğu için Mac'te etkileri yok. Yine de testleri Mac'te de koşar.
- **Gizlilik ayarlarının eşitlenmesi (K7):** Mac, iPhone'un yazdığı ortak gizlilik ayarını okur. Kod ve kart
  süzgeçleri iki yönde aynı çalışır.
- **Öğe başlığı:** iPhone'daki `title` alanı Maccy'nin yerel başlığına (`HistoryItem.title`) eşlenir. Mac'teki
  başlık da buluta yazılır (`Clip.setTitle`). Mac'te metin düzenlenince (`SyncBridge.didEdit`) yeni öğe başlığı
  `takeTitle(from:)` ile almalı; bugün yeni bir `Clip` kuruluyor ve başlık düşerdi. Maccy'nin görsellerde OCR
  metnini başlık olarak kullandığına dikkat: o başlık eşitlenmemeli.
- **Gizlilik ayarlarının eşitlenmesi (iPhone planındaki A6, buraya taşındı):** Kod, kart ve "yalnızca
  sabitlenenler" anahtarları `Settings` kaydında şifreli alanlar olarak durur. Mac yazar, iPhone okuyup kendi
  yakaladıklarına uygular. Bu bir şema eklemesidir.

### 2.3 Mac'te bulunan hatalar (iPhone denetiminde yan bulgu)
- **Sabitleme kaybı:** Mac'te boş pin harfi kalmayınca uzaktan sabitlenen öğe sabitsiz ekleniyor
  (`SyncBridge.swift:428-430`). Sonra Mac'in geçmiş sınırı onu buluttan, yani iPhone'dan da siliyor.
- **Mac'in budaması iPhone öğelerini de siliyor:** Bulut Mac'in geçmiş sınırını izliyor (`TASARIM.md` §4.4,
  bilinçli karar). Görseller gelince bu daha önemli hale gelir; yeniden değerlendirilmeli.
- **iPhone'da yeniden kopyalama Mac'te sıralamayı değiştirmiyor:** Uzaktan gelen güncellemede yalnızca pin
  güncelleniyor, `lastCopiedAt` güncellenmiyor (`SyncBridge.swift:390-397`).

## 3. Yayın adımları (özet; ayrıntı `SURUM.md`)
1. `MARKETING_VERSION = 1.3`, `CURRENT_PROJECT_VERSION = 2` (iki satır). Commit.
2. Testler: `MaccyTests`, çekirdek, iki cihazlı uçtan uca test (görsel senaryolarıyla birlikte).
3. CloudKit şeması: `Media` ve `Blobs` iPhone 1.2 ile zaten Production'a gitmiş olacak. Mac için yeni alan
   gerekirse önce o eklenir.
4. Kanal 2: `build-mas.sh` → kullanıcı "yükle" deyince `--upload`.
5. Kanal 3: Developer ID arşivi, notarize, `sign_update`, GitHub Release taslağı, appcast en son (kullanıcı onayıyla).
6. `YAYIN.md` §D ve `SURUM.md` "Şu an" satırı güncellenir.
