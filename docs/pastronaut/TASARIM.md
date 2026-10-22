# Pastronaut: tasarım belgesi (taslak 1, 2026-10-16)

Temel alınan upstream: `p0deje/Maccy` @ `7e14eb8` (2.7.1'den 10 commit ileride).

## 1. Hedef
Kullanıcı iPhone'da bir klavye açar. Klavyede hem Mac'te hem iPhone'da kopyaladığı öğelerin ortak geçmişini görür ve
bir dokunuşla yazdığı alana ekler.

**MVP kapsamı:** düz metin ve bağlantılar, iki yönlü eşitleme, iOS uygulaması ve klavye.
**Sonra:** görseller, sabit öğeler bölümü, Paylaş uzantısı, Mac App Store sürümü.
**Kapsam dışı:** dosya eşitlemesi (Mac'teki dosya yolları telefonda anlamsız), Android, sunucu.

## 2. Mevcut koddan önemli gerçekler
| Gerçek | Yer | Tasarıma etkisi |
|---|---|---|
| Model: `HistoryItem` (application, firstCopiedAt, lastCopiedAt, numberOfCopies, pin, title, contents) + `HistoryItemContent` (type, value: Data) | `Maccy/Models/` | Alanların hepsinde varsayılan değer var ve ilişki isteğe bağlı. Modele dokunmadan ayrı bir eşitleme katmanı kurulabilir. |
| Tekrar kopyalanınca eski öğe **siliniyor**, yeni öğe ekleniyor (`History.add` → `findSimilarItem` → `deleteFromStorage`) | `Maccy/Observables/History.swift` | Eşitleme kimliği SwiftData nesnesine bağlanırsa her tekrar bulutta "sil + ekle" olur. Bu yüzden **içerik özetinden türeyen sabit bir kimlik** gerekiyor (§4.2). |
| Yok sayma kuralları kayıttan önce uygulanıyor (`Clipboard.checkForChangesInPasteboard`) | `Maccy/Clipboard.swift` | Eşitleme yalnızca geçmişe girmiş öğeleri görür. Gizli içerik zaten elenmiş olur; bunu bir testle güvenceye alacağız. |
| Geçmiş sınırı yalnızca sabit olmayan öğelere uygulanıyor (varsayılan 200) | `History.limitHistorySize` | Bulutta tutulacak kümeyi de aynı mantıkla sınırla. |
| Sabitleme harfi, Mac klavye kısayollarına bağlı | `HistoryItem.supportedPins` | Harf eşitlenmez. Yalnızca "sabit mi" bilgisi eşitlenir. |
| Depo: `Application Support/Maccy/Storage.sqlite` | `Maccy/Storage.swift` | Mac'te dokunulmaz. Eşitleme durumu ayrı bir dosyada tutulur. |
| Yetkiler: sandbox, Sparkle mach-lookup istisnaları; ekip `MN3X4648SC`, kimlik `org.p0deje.Maccy` | `Maccy/Maccy.entitlements`, pbxproj | Kimlik, ekip ve iCloud yetkisi değişecek (§5). |
| Kısayollar uygulaması için App Intents zaten var (Get/Select/Delete/Clear) | `Maccy/Intents/` | iOS'ta "panoyu kaydet" eylemi için aynı kalıp kullanılabilir. |

### 2.1 Upstream'deki ilgili dallar (2026-10-16'da görüldü)
- **`claude/maccy-ios-port-plan-01CUvtrfg7fJoWznj2iwCQtP`** (son commit 2025-12-07, o tarihten beri hareketsiz):
  - Bir "iOS yardımcı uygulama" planı (`iOS-PORT-PLAN.md`) ve kısmi bir uygulama; 25 dosya, yaklaşık 1000 satır.
  - Yaklaşım: SwiftData'nın otomatik CloudKit eşitlemesi, kapsayıcı `iCloud.org.p0deje.Maccy`.
  - iOS tarafı **salt okunur**: görüntüle ve kopyala. Klavye ve telefon kopyalarını yakalama yok.
  - Ortak kod için `Maccy/Platform/` soyutlamaları eklenmiş. Xcode hedefi, yetkiler ve testler "TODO" durumunda.
  - Sonuç: proje sahibi bir iOS yardımcı uygulamayı düşünmüş. Klavye ve iki yönlü yakalama bizim farkımız.
    `Platform/` soyutlamaları MIT kapsamında yeniden kullanılabilir.
- **`appstore`:** Mac App Store sürümü için Sparkle'ı ve güncelleme ayarlarını kaldıran fark. Bu fark, bizim Mac App Store yapılandırmamız için örnek alınabilir.

## 3. Mimari
```
┌──────────── macOS (Pastronaut) ─────────────┐        ┌──────── iCloud ────────┐        ┌────────────── iOS ───────────────┐
│ Clipboard (mevcut) → yok sayma → History    │        │ Özel veritabanı        │        │ Uygulama: liste/arama/kopyala    │
│                      │ (add/delete/clear)   │        │ Bölge: "History"       │        │   │ CKSyncEngine                 │
│                      ▼                      │  ⇄     │ Kayıt türü: Clip       │   ⇄    │   ▼                              │
│ Sync/ClipMirror → CKSyncEngine              │        │ (şifreli alanlar)      │        │ App Group deposu (SwiftData)     │
└─────────────────────────────────────────────┘        └────────────────────────┘        │   ▲ okur / yazar                 │
                                                                                         │ Klavye uzantısı (Tam Erişim)     │
                                                                                         │ App Intent: "Panoyu kaydet"      │
                                                                                         └──────────────────────────────────┘
```
- **PastronautCore (paylaşılan Swift paketi):** `Clip` veri yapısı, içerik özeti, CloudKit kayıt eşlemesi, eşitleme
  motoru sarmalayıcısı. AppKit ve UIKit içermez; iki platformda derlenir ve test edilir.
- **Mac:** Mevcut kod en az değişiklikle `History.add/delete/clear` noktalarından bir "ayna" (`ClipMirror`) bileşenine
  olay yollar. Buluttan gelen öğeler normal bir kopya gibi `History.add` ile eklenir ve kaynak cihazı işaretlenir.
- **iOS:** Uygulama ve klavye aynı App Group deposunu kullanır. Eşitlemeyi yalnızca uygulama yapar. Klavye ağa
  çıkmaz, yalnızca depoyu okur ve yeni kopyaları depoya yazar.

## 4. Eşitleme tasarımı
### 4.1 Neden CKSyncEngine (SwiftData'nın otomatik CloudKit'i değil)
- Hangi öğelerin eşitleneceğini biz seçeriz: yalnızca metin, sınırlı sayı ve boyut.
- Alan düzeyinde uçtan uca şifreleme mümkün (`encryptedValues`).
- Kimliği biz belirleriz. Bu, tekrar birleştirme sorununu çözer (§4.2).
- Mac'in mevcut deposuna ve şemasına dokunmayız. Upstream'le birleştirmek kolay kalır.

### 4.2 Kimlik ve tekrarlar
- `clipID = SHA-256(normalize(birincil içerik))`. Birincil içerik düz metin ya da URL; normalize etme yalnızca satır
  sonlarını tekleştirmek demek, boşluklara dokunulmaz.
- CloudKit kayıt adı (Dalga 3'ten beri) = `"c-" + HMAC-SHA256(hesap anahtarı, clipID)`. Hesap anahtarı (`SyncKey`,
  256 bit) "Library" bölgesindeki tek `Settings` kaydının şifreli `idKey` alanında durur; ilk cihaz oluşturur, aynı
  anda oluşturan ikinci cihazın kaydı sunucuda reddedilir ve o cihaz kaydedilmiş anahtarı alır. Aynı metin yine her
  cihazda aynı kayda düşer (cihazlar arası tekrar birleştirme kendiliğinden olur), ama ad anahtarsız bir şey söylemez.
  Yerelde (ayna, App Group dosyaları, Mac geçmişi) kimlik hâlâ `clipID`'dir. iOS uzantıları anahtarı App Group'taki
  `sync-key.json`'dan okur; yoksa `Settings` kaydından alır.
- Anahtar başka bir cihazca değiştirilmişse (iCloud verisi silinip yeniden kurulduğunda) cihaz eski adlı kayıtlarını
  siler ve yenileriyle yeniden yazar; başka anahtarla yazılmış bir kayıt görülürse içeriği alınır, kayıt doğru ada taşınır.
- Mac'te bir öğe silinip "aynısı" eklendiğinde aynı `clipID` üretilir. Bu bulutta bir **güncelleme** olur
  (lastCopiedAt), silme olmaz.

### 4.3 Kayıt alanları (`Clip`)
| Alan | Tür | Şifreli | Not |
|---|---|---|---|
| text | String | evet | En fazla 100 KB (MVP). Daha uzunsa eşitlenmez. |
| kind | String | hayır | `text` / `url` (Sonra: `image`) |
| sourceApp | String? | evet | Paket kimliği |
| sourceDevice | String | hayır | `mac` / `iphone` / `ipad` |
| firstCopiedAt, lastCopiedAt | Date | hayır | Çakışmada lastCopiedAt büyük olan kazanır |
| pinned | Bool | hayır | Harf eşitlenmez |
| collections | [String] | evet | Koleksiyon kimlikleri (`col-<UUID>`); pin gibi en yeni değişiklik kazanır (Dalga 3) |
| title | String? | evet | 1.2. Kullanıcının verdiği ad. Yalnızca bir kez verildiğinde ya da temizlendiğinde yazılır |
| titleModifiedAt | Date? | hayır | 1.2. Başlık bu saate göre birleşir; başlığı bilmeyen bir sürüm onu silemez |
| deleted | — | — | Silme, kaydın silinmesiyle yayılır |

Koleksiyon kaydı (`Collection`, ad = `col-<UUID>`): `name` (şifreli), `order`, `createdAt`, `modifiedAt`. Koleksiyonu
silmek öğelerini silmez; silen cihaz üyelikleri de temizler. Koleksiyondaki öğe "saklanır": Mac'te geçmiş sınırı,
"Geçmişi sakla" ve Temizle ona dokunmaz (Tümünü Temizle dokunur). Açık bir silme her yerden siler.

Kopya sayısı eşitlenmez; her cihaz kendi sayısını tutar. Toplama işlemi eşitlemede tutarlı kalmıyor.

### 4.4 Sınırlar ve silme (Faz 1'de uygulandığı haliyle)
- Bulut için ayrı bir sınır yok. Mac kendi geçmiş sınırını (varsayılan 200 sabit olmayan) uygularken sildiği öğeler
  buluttan da silinir. Böylece bulut Mac'in geçmişini izler.
  - Ayrı bir bulut sınırı denendi ve bırakıldı: cihazlar arasında "biri tutar, öteki siler" çelişkisi doğuruyordu.
  - iPhone'un kendi budaması Faz 2'de ele alınacak.
- "Öğeyi sil", "Temizle" (sabit olmayanlar) ve "Hepsini temizle" diğer cihazlara yansır.
- Ayar: "Sync history with iCloud" (varsayılan kapalı). Kapatmak bulut verisini silmez; ayrıca "Delete iCloud Data"
  düğmesi var. Bulut verisi silinince diğer cihazlar yalnızca eşitleme kopyalarını unutur; **yerel geçmişleri korunur**.
- Hesaptan çıkış ya da hesap değişikliğinde eşitleme kopyası unutulur; yerel geçmiş korunur.
- **iPhone (1.2):** iPhone'un geçmişi eşitleme aynasının kendisi. Bu yüzden bulut silinince ya da hesap değişince
  öğeler ve koleksiyonlar silinmez, "yalnızca bu iPhone'da" işaretiyle kalır (`ClipSync(keepsLocalHistory: true)`,
  `SyncMirror.swift`). Bu öğeler kendiliğinden gönderilmez; yalnızca "iCloud'a Yeniden Yükle" ya da aynı metnin
  yeniden yakalanması gönderir. Klavye ve widget bu öğeleri `local-only.json` üzerinden görmeye devam eder.

### 4.5 Push'a güvenmeme (Faz 2 uçtan uca testinden)
CKSyncEngine bir bölgeyi yalnızca o bölgenin değiştiğini push'tan öğrenince çeker. Push kaybolursa `fetchChanges()`,
açık bölge kapsamı verilse bile hiçbir şey sormaz (günlük: `no zone IDs needing to be fetched`). Bu yüzden:
- `ClipSync.syncNow()` motorun çekmesinden sonra kendi **yakalama çekmesini** (`catchUp`) yapar. Bölgeyi kendi değişiklik
  işaretimizle doğrudan ister; sonuç motorunkiyle aynı birleştirmeden geçer, aynı değişikliği iki kez görmek zararsızdır.
  İlk (işaretsiz) çekmede sunucuda artık olmayan ve yeniden gönderilmeyi beklemeyen kayıtlar silinmiş sayılır.
- `syncNow()` şu anlarda çağrılır. Mac: açılışta, push gelince, dakikada bir ve bir penceresi öne gelince (en sık 10 sn'de bir).
  iPhone: açılışta, öne gelince, push gelince, aşağı çekince ve açıkken dakikada bir.
- iPhone her yerel değişiklikten sonra hemen gönderir (`sendNow`) ve bunu kısa bir arka plan göreviyle güvenceye alır.
  Motorun kendi gönderimi birkaç saniye bekliyor; uygulama bu sırada askıya alınırsa değişiklik bir sonraki açılışa kalıyordu.

### 4.6 Gizlilik
- Yalnızca Mac'te yok sayma kurallarından geçip geçmişe giren öğeler eşitlenir. Gizli işaretli kopyalar zaten geçmişe girmez.
- iPhone'da yakalanan kopyalar için de aynı düzenli ifade kuralları uygulanır (kurallar eşitlenen bir ayar kaydında tutulur; Sonra).
- Şifreli alanlar Apple'ın uçtan uca şifrelemesiyle korunur; geliştirici CloudKit panosunda içeriği göremez.
- **Kapandı (Dalga 3):** kayıt adları artık anahtarlı (§4.2). Aşağıdaki not tarihçe için duruyor. Arayüz yeniden
  "uçtan uca şifreli" diyor; kapsamı: metin, kaynak uygulama ve koleksiyon adları. Tarihler, tür ve pin düz kalır.
- **Açık (2026-10-17, Paste araştırmasında bulundu):** kayıt adı (`recordName`) metnin tuzsuz SHA-256'sı ve şifrelenmez.
  Kısa metinler (6 haneli kod, kısa parola, kart) bu özetten geri bulunabilir. Çözüm: kimliği kullanıcıya özel bir
  anahtarla HMAC-SHA256 olarak üretmek; anahtar şifreli alanlı tek bir ayar kaydında eşitlenir. Geçiş arka planda,
  bloklamadan yapılır; koleksiyonlarla aynı şema değişikliğinde. O zamana kadar arayüz "uçtan uca şifreli" demez,
  "metin şifreli saklanır" der.

## 5. macOS değişiklikleri
1. Kimlik: `PRODUCT_BUNDLE_IDENTIFIER` yeni bir kimliğe, `DEVELOPMENT_TEAM` kullanıcının ekibine, görünen ad ve ikon
   Pastronaut'a geçer.
2. Yetkiler: iCloud (CloudKit) ve `iCloud.<kimlik>` kapsayıcısı, uzak bildirimler (`aps-environment`). Sparkle istisnaları
   Developer ID sürümünde kalır, Mac App Store yapılandırmasında çıkarılır.
3. `Maccy/Sync/`: `ClipMirror`, eşitleme ayarı, ayarlar ekranında yeni bir "Eşitleme" sekmesi.
4. `History.swift`'e en fazla 3 kanca: ekleme, silme, temizleme.
5. Lisanslar ekranı.
6. Dağıtım: önce Developer ID + noter onayı ve GitHub sürümleri. Mac App Store sonra değerlendirilir.

## 6. iOS uygulaması ve klavye
- **Uygulama (SwiftUI):** geçmiş listesi, arama, dokununca kopyala, sabitle, sil, eşitleme durumu, klavye kurulum rehberi, lisanslar.
- **Klavye uzantısı:**
  - Üstte arama, altta son öğeler. Dokununca metni doğrudan yazar.
  - Görseller (Sonra) panoya kopyalanır ve kullanıcı yapıştırır.
  - Temel bir giriş satırı: boşluk, sil, enter, sonraki klavye düğmesi.
  - Tam Erişim kapalıysa geçmiş yerine nasıl açılacağını anlatan bir görünüm ve temel tuşlar gösterilir.
  - Bellek sınırı için yalnızca başlıklar ve sayfalı sorgular kullanılır; görsel önizleme yok.
- **Telefondaki kopyaları yakalama** (arka planda sürekli izleme iOS'ta mümkün değil):
  1. Uygulama öne geldiğinde pano okunur. Kullanıcı ayarlardan "Diğer uygulamalardan yapıştır: İzin ver" seçmezse sistem onay sorar.
  2. Klavye (Faz 0 sonucuna göre; bkz. `Prototypes/Faz0/README.md`):
     - Klavye açılınca panonun değişip değişmediği izin istemeden algılanır (`changeCount`, `hasStrings`).
     - Değiştiyse "Panodakini kaydet" alanında sistemin **Yapıştır düğmesi** gösterilir; tek dokunuşla, izin penceresi olmadan yakalanır.
     - Kullanıcı ayarlardan "Diğer Uygulamalardan Yapıştır: İzin Ver" seçerse "otomatik kaydet" açılabilir. Sistem her okumada kısa bir bildirim gösterir; kurulum rehberinde bu açıklanmalı.
     - Tam Erişim kapalıysa klavye geçmişi gösterir ve yazar ama yakalama yapamaz (App Group'a yazamıyor).
  3. App Intent "Panoyu Pastronaut'a kaydet": Kısayollar, Arkaya Dokun ve Eylem düğmesi için.
  4. (Sonra) Paylaş uzantısı.
  5. Universal Clipboard: telefon Mac'e yakınken telefonda yapılan kopya Mac'e düşer ve oradan eşitlenir.
     Bu kopyalar panoda `com.apple.is-remote-clipboard` türüyle işaretli gelir. Proje sahibi bu türü yok sayma
     listesine eklemeyi önermiş (#182, 2024). Kullanıcı eklemişse bu yol kapanır; Eşitleme ayarlarında bu durum belirtilmeli.
     Bu tür, kaynağı "iPhone" olarak işaretlemek için de kullanılabilir.
- Eşitleme: CKSyncEngine yalnızca uygulamada çalışır. Sessiz anlık bildirimle uyanır; iOS arka plan push'larını
  kıstığı için bu en iyi çabadır (Faz 2, T13).
- **Klavyenin kendi bulut erişimi (Faz 3, `KeyboardCloud`), yalnızca Tam Erişim'le:**
  - Klavye açılınca (en sık 5 sn'de bir) "Library" bölgesini (Dalga 3 öncesi "Clips") kendi değişiklik işaretiyle çeker ve `keyboard-cache.json`'a
    yazar. Liste, uygulamanın anlık görüntüsünden ya da daha yeniyse bu önbellekten oluşur, üstüne gelen kutusu eklenir.
  - Yakalanan kopya önce gelen kutusuna yazılır (kaybolmasın), sonra tek kayıt olarak doğrudan buluta kaydedilir;
    başarılıysa gelen kutusundan çıkarılır. Çevrimdışıysa uygulama sonra gönderir.
  - Klavyede ikinci bir CKSyncEngine yok: iki motor aynı durumu paylaşamaz. Uygulama, klavyenin yazdığı kaydı
    herhangi bir uzak değişiklik gibi çeker.
- **Yeniden kopyalama sabitlemeyi korur** (`Clip.copiedAgain`, `ClipSync.recordCopy`): yakalanan kopya sabitleme
  bilgisi taşımaz; düz birleştirme ("yeni olan kazanır") sabitli bir metni yeniden kopyalayınca sabitlemeyi kaldırıyordu.
- **Kısayollar eylemi** `SaveTextIntent` ("Save to Pastronaut", metin parametresi). Önerilen kısayol:
  "Panoyu Al → Save to Pastronaut"; Arkaya Dokun veya Eylem düğmesine bağlanabilir. Metni Kısayollar okuduğu için
  uygulama ayrıca yapıştırma izni sormaz.

## 7. Riskler ve doğrulanacaklar
| # | Konu | Nasıl doğrulanır |
|---|---|---|
| R1 | Klavye kuralları (App Review 4.4.1): giriş işlevi, sonraki klavye düğmesi, Tam Erişim olmadan çalışma | Güncel kural metni ve küçük bir prototip ile TestFlight dış inceleme |
| R2 | Klavye uzantısı Tam Erişim'le panoyu okurken iOS onay penceresi çıkıyor mu? | ✅ Kapandı (Faz 0, iOS 27.0.1): düz okumada çıkıyor. Sistem Yapıştır düğmesinde ve "İzin Ver" ayarıyla çıkmıyor. iOS 17–26'da doğrulanmadı. |
| R3 | CloudKit Developer ID ile dağıtılan Mac uygulamasında sorunsuz çalışıyor mu? | ✅ Kapandı (Faz 0): çalışıyor, ama yalnızca Production ortamında. Şema yayından önce Production'a deploy edilmeli; şema yalnızca eklemeye açık olduğu için önce kesinleşmeli. Noter onayı ayrıca denenmedi. |
| R4 | Klavye bellek sınırı | Faz 2'de Instruments ile ölçüm |
| R5 | "Pastronaut" adının App Store'da ve marka olarak uygunluğu | App Store Connect'te ad ayırma, marka araması |
| R6 | Upstream değişiklikleriyle birleşme maliyeti | Değişiklikleri kanca ve ayrı klasörlerle sınırlamak |
| R7 | Mac'te CloudKit push'u uygulamaya ulaşmıyor | ✅ Kapandı (2026-10-16): uygulama hatası değil, ortam sorunu. Uygulama `/private/tmp` altındaki DerivedData'dan çalışınca `usernoted` onu "eksik uygulama" sayıp push kaydını siliyor (günlük: `Removing missing application`); push'lar düşüyor. `~/Applications` altından çalışınca push geliyor: iPhone → Mac kaydetme, sabitleme, silme ≈ 2 sn. Mac'i test ederken uygulamayı bir Uygulamalar klasöründen çalıştır. |

## 8. Fazlar ve kabul ölçütleri
- **Faz 0: Riskleri kapatan prototip (1 hafta).** CloudKit'e yazan minimal bir Mac uygulaması, okuyan bir iOS uygulaması
  ve panoyu okuyan bir klavye. Ölçüt: R2 ve R3 yanıtlanır.
- **Faz 1: Mac eşitlemesi. ✅ (2026-10-16, Development ortamı; commit `8be6c29`)** Ölçütler:
  - ✅ Ayar açıkken kopyalanan metin 10 saniye içinde bulutta. Kullanıcı gözlemi: sayaç ve "Last sync" 10 sn içinde güncellendi.
  - ✅ Tekrar kopyalama yeni kayıt açmaz (kullanıcı gözlemi).
  - ✅ Yok sayılan bir türdeki kopya buluta gitmez: `SyncBridgeTests.testConcealedCopiesNeverReachHistory`
    ve mevcut `ClipboardTests` yok sayma testleri.
  - ✅ Silme buluta yayılır (kullanıcı gözlemi: sayaç azaldı). Diğer cihaza yayılması Faz 2'de doğrulanacak.
  - ~~Günlükte hata yok.~~ **Geçersiz:** sorgular zsh'nin yerleşik `log` komutuna gitmiş ve boş dönmüştü. Artık
    `/usr/bin/log` kullanılıyor. Testler: 104 MaccyTests, 15 PastronautCore.
- **Faz 2: iOS uygulaması ve klavye (yalnızca metin).** Ölçütler `scripts/e2e/sync_e2e.py` ile iki gerçek cihazda
  otomatik sınanır (§10). Son koşu 2026-10-16 19:19, Development ortamı: 15 zorunlu kontrolün 15'i geçti, 2 uyarı.
  - ✅ Mac'te kopyalanan metin iPhone klavyesinde görünür ve dokunulunca yazılır. Tam Erişim kapalıyken de görünür
    (önceden boş görünüyordu, bkz. aşağıda) — T02, T14 (ayrı koşuda geçti).
  - ✅ Tam Erişim kapalıyken klavye çökmez ve yönlendirme gösterir — T14 tanısı ("fullAccessHint").
  - ✅ İki yönde ekleme, sabitleme, sabit kaldırma, silme (T02–T07, T11, T12). Mac → açık iPhone ≈ 23 sn,
    iPhone → Mac ≈ 45–55 sn DerivedData'dan çalışırken (push düşüyor, dakikalık yoklama), `~/Applications`'tan
    çalışırken ≈ 2 sn (push; bkz. R7).
  - ✅ Türkçe, emoji, çok satırlı metin bayt bayt aynı (T08). Gizli (parola) kopya hiçbir yere gitmez (T09).
    100 KB üstü metin Mac'te kalır (T10).
  - ✅ Mac kapalıyken iPhone'da yapılanlar Mac açılınca gelir (T15, 2 sn). İlk kurulum geçmişi çeker (T01).
  - ⚠️ Uygulama arka plandayken sessiz push'la klavye verisinin tazelenmesi: bir koşuda 51 sn'de geçti, son koşuda
    3 dakikada gelmedi (iOS arka plan push'larını kısar). En iyi çaba; Faz 3'te klavyenin kendisi çekebilir (Tam Erişim'le).
  - Elle doğrulanır: sistem Yapıştır düğmesi (otomasyondan gelen dokunuşu reddeder), Tam Erişim açıkken klavyeden yakalama.
  - Testin bulduğu hatalar: (1) Mac push'suz hiç çekmiyordu, (2) iPhone değişiklikleri uygulama askıya alınınca
    gönderilmiyordu, (3) Tam Erişim kapalıyken klavye `NSFileCoordinator` ile okuyamadığı için listeyi boş gösteriyordu
    (geri alınarak doğrulandı). Üçü de düzeltildi.
- **Faz 3: Telefon kopyaları. ✅ (2026-10-16, commit `aed6e23`)** Ölçüt: uygulama, klavye ve Kısayol ile yakalanan kopya Mac geçmişinde görünür.
  Son koşu 2026-10-16 20:07 (Mac `~/Applications`'tan, push açık): 21 zorunlu kontrolün 21'i geçti, 1 uyarı (T13).
  - ✅ Uygulama çalışmıyorken klavye Mac'teki yeni öğeyi kendisi çeker (T18; ayrıca 3/3 tekrar, uygulama anlık
    görüntüsünde öğe yokken). Bu sayede T14 de geçiyor.
  - ✅ Klavyenin doğrudan yüklemesi Mac'e ≈ 2 sn'de ulaşır (T19; Debug kancasıyla aynı `KeyboardCloud.save`).
  - ✅ Sabitli metni yeniden kopyalamak sabitlemeyi korur, doğrudan ve uygulama yolunda (T20).
  - ✅ iPhone → Mac tüm işlemler ≈ 2 sn (push).
  - ✅ Elle (kullanıcı, 2026-10-16 20:30–20:36): uygulama kapalıyken klavyenin Yapıştır düğmesiyle yakalama
    ("cloud: saved") ve "Panoyu Al → Save to Pastronaut" kısayolu ("Saved to Pastronaut."). İkisinde de metin önce
    Evrensel Pano'yla Mac'e düştü; iPhone'un bulut kaydı push'la 9–40 sn sonra geldi ve aynı öğeyle birleşti
    (Mac günlüğü: `remote notification received`, `1 changes`). Çift kayıt oluşmadı.
  - Bir koşuda T14/T18 klavye çekmesi başarısız oldu, nedeni görülemedi (hata sessizdi). Klavye artık Debug'da son
    bulut işleminin sonucunu gösteriyor; tekrar olursa test çıktısında görünecek.
- **Faz 4: Ürünleşme (1.0 kapsamı, §9).** Önce zorunlu temizlik (Maccy ikonu ve menü simgesi), yerelleştirme altyapısı ve
  testlerin kimlik tabanlı olması; sonra görsel kimlik, Mac popup'ı, iOS ekranları, klavye, widget'lar ve uzantılar.
  - ✅ 4.1 Kendi ikonlar (commit `30d3fa6`).
  - ✅ 4.2 Yerelleştirme altyapısı: iOS uygulama/klavye/çekirdek için `Localizable.xcstrings` (EN temel, TR tam),
    Mac için ayrı `Pastronaut` tablosu (`Maccy/Sync/Pastronaut.xcstrings`); Kısayollar eylemi de katalogdan.
    Testler etiket yerine erişilebilirlik kimliğiyle çalışıyor; Türkçe cihazda tam koşu geçti (T21: uygulama
    "Ayarlar" başlığıyla açılıyor). Mac Sync ekranının metinleri yeniden tasarımında tabloya taşınacak.
  - ✅ 4.3a iOS uygulaması yeni tasarım (Liquid Glass): gruplu geçmiş (Sabitlenenler/Bugün/Dün/Bu hafta/Daha eski),
    Tümü/Mac/iPhone filtresi, içerik türü simgeleri (`ClipContent`: bağlantı, e-posta, telefon, renk, kod, metin),
    kaynak uygulama adı (yeni şifreli alan `sourceAppName`, Mac çözer), dokununca kopyala + bildirim, bağlam menüsü,
    ayrıntı ekranı (akıllı eylem, paylaş, sabitle, düzenle, sil), canlı kurulum rehberi (klavye eklendi mi:
    `AppleKeyboards`; Tam Erişim: klavyenin App Group'a yazdığı işaret), yeni Ayarlar. Gece paleti varlık
    kataloğunda; koyu tema vurgusu #6F5FEB (beyaz yazı ve siyah zemin ile ≈ 4,5:1). Tam E2E koşusu geçti.
  - ✅ 4.3b Klavye yeni tasarım, sistem klavyesine yakın: zemin sistemin (iOS 26+ cam), tuşlar açıkta beyaz, koyuda
    yarı saydam; işlev tuşları koyu; tuş tıklama sesi (`UIInputViewAudioFeedback`). Tuş görünümünde "Mac'ten son kopya",
    Sabit/Son/Mac/iPhone sekmeleri, cihaz diline göre Türkçe Q / QWERTY harf düzeniyle arama, uzun basınca eylem
    paneli (tam metin, Yaz, Sabitle, iki dokunuşla Sil). Sabitleme ve silme klavyeden doğrudan iCloud'a
    (`KeyboardCloud.setPinned`, `delete`). iOS 26'nın kaydırma kenarı bulanıklığı listede kapatıldı (ilk satırı
    örtüyordu). Açık/koyu ekran görüntüleriyle kontrol edildi; E2E T22 (klavyeden sabitleme → Mac 2 sn) ve T23
    (klavyeden silme → Mac 2 sn) dahil tam koşu geçti.
  - ✅ 4.4a Mac popup'ı (Maccy'nin popup'ı üzerine, macOS 26 cam zemini korunarak): Tümü/Bu Mac/iPhone filtresi (arama
    ile birlikte uygulanır, ⌘1–9 görünen listeyi izler), Sabitlenenler ve gün başlıkları (tarihe göre sıralıyken,
    arama yokken), içerik simgeleri (renkte örnek), "uygulama · zaman" alt satırı ve iPhone rozeti, önizlemede tür ve
    kaynak, altbilgide eşitleme durumu. Gece vurgusu (`AccentColor`; macOS yalnızca "Çok renkli" vurguda kullanır).
    Başlıktaki uygulama adı varsayılan kapalı (Pastronaut taşıma adımı; Maccy 2.x taşıması her kurulumda açıyordu).
    iPhone'dan eşitlenen öğeler Mac'te `com.xkbxyberk.pastronaut.from-iphone` işaretiyle saklanır: rozet için ve Mac
    onları değiştirince (ör. sabitleme) cihaz bilgisi Mac'e dönmesin diye. Ekran görüntüleri Maccy UI testinden
    (`testPastronautScreenshots`, ayrı test deposu); tam E2E geçti.
  - ✅ 4.4b Liquid Glass geçişi: iOS'ta cam kapsül filtre (sayılarla, seçim akarak geçer, `safeAreaBar`), ayrı kart
    satırlar ve cam içerik simgeleri; Mac'te cam filtre, cam arama alanı, renkli cam seçim (çoklu seçimde düz), daha
    yuvarlak satırlar. 17–25 / 14–25'te önceki görünüm.
  - ✅ 4.4c Mac Eşitleme ayarları (gruplu form; durum, gizlilik, iPhone QR'ı, eylemler) ve ilk açılış karşılama
    penceresi. Gizlilik anahtarları (`SensitiveContent`, `PrivacyOptions`; varsayılan kapalı): tek kullanımlık kod
    (yalnız 4–8 hane ya da tam kelime olarak kod sözcüğü + 4–8 hane; Mac'te 5 dk sonra silinir), kart (Luhn) ve IBAN
    (mod 97), yalnızca sabitlenenler. Anahtar açılınca bu Mac'in kurala uymayan öğeleri buluttan kalkar (iPhone'un
    yakaladıklarına ve yerel geçmişe dokunulmaz), kapanınca yeniden yüklenir. E2E T24 (kod Mac'te kalır), T25 (yalnız
    sabitlenenler) geçti. QR şimdilik GitHub proje sayfası; App Store bağlantısı Faz 5'te. Ayarlar penceresinin
    görüntüsü UI testinde alınamadı (pencere test ortamında açılmıyor); elle bakılmalı.
  - ✅ 4.5 Dalga 1 (Paste araştırmasından, `research/paste-ozet.md` §9):
    - Mac (`Maccy/Sync/PopupExtras.swift`, Maccy dosyalarında tek satırlık kancalar): menü çubuğu simgesine sağ tık /
      ⌃-tık menüsü (15 dk / 1 saat / yarına kadar / ben sürdürene kadar duraklat, sürdür, aç, ayarlar, çık). Duraklatma
      Maccy'nin `ignoreEvents` anahtarını kullanır, süre bitince kendiliğinden kalkar ve popup altında "Sürdür"
      düğmeli bir bildirim görünür. Depolama ayarında "Geçmişi sakla" seçeneği (süresiz / 1 gün / 1 hafta / 1 ay / 1 yıl;
      sabitlenenler muaf, kısaltırken onay istenir, saatte bir uygulanır). Görünüm ayarında "Ekran paylaşımında ve
      kayıtta gizle" (`sharingType = .none`). Satıra sağ tık menüsü (kopyala, yapıştır, düz metin yapıştır, görseldeki
      metni kopyala, sabitle, geçmişte göster, sil). Silinenler 8 sn içinde ⌘Z ya da "Geri Al" ile geri gelir.
      Kurallar `PastronautCore/HistoryRules.swift` içinde ve test edildi. UI testi: `testPastronautPopupExtras`.
    - iOS: Ayarlar › Pano › "Açılınca Panoyu Kaydet" (varsayılan kapalı, App Group'ta paylaşılır). Uygulama öne
      gelince ve klavye açılınca yeni kopyayı kendisi kaydeder; kod, kart ve IBAN atlanır (`AutoCapture`). İzin sorusunu
      kaldırmak için iOS Ayarlar'ına giden düğme var. Panodaki metin geçmişte zaten varsa dokunulmaz: Mac'in
      kopyaları Evrensel Pano'yla iPhone panosuna da düşüyor; yoksa "iPhone" diye yeniden etiketlenip öne taşınıyor,
      iPhone'da silinen ya da sabitlemesi kaldırılan öğe geri geliyordu (E2E 2. koşu, T05/T11). "+" ile yeni öğe, "Seç" ile çoklu seçim, toplu sabitleme ve
      onaylı toplu silme.
    - Renk: `#` olmadan, rakam ve A–F harfi karışık 6 haneli hex de renk sayılır ("facade" ve "235442" metin kalır).
    - Arayüz artık "uçtan uca şifreli" demiyor (bkz. §4.6, kayıt adı sorunu).
    - E2E: T26 (iPhone'da "+" → Mac), T27 (toplu silme → Mac), T28 (açılışta kaydetme → Mac), T29 (kod atlanır).
      Test aracı arka planda olduğu için panoya yazamıyor; T28/T29'da metni Debug kancası (`PT_E2E_PASTEBOARD`)
      uygulamanın kendi panosuna koyuyor. iOS'un izin sorusu elle denenecek.
  - ✅ 4.6 Dalga 2 (1.0 yüzeyleri):
    - Widget uzantısı (`iOS/Widgets`, App Group'tan okur, `SharedClipFiles.currentClips`): ana ekranda "Son Öğeler"
      (küçük/orta/büyük; kaynak seçilebilir: tümü, Mac, iPhone, sabitlenenler), her satırda kopyala düğmesi
      (`CopyClipIntent`, kısa bir onay işareti); Kilitli Ekran'da "Son Öğe" (dikdörtgen ve satır içi, iPhone
      kilitliyken `privacySensitive` ile gizli); iOS 18+ "Panoyu Kaydet" kontrolü (Denetim Merkezi, Kilitli Ekran,
      Action Button). iPhone'da panoyu yalnızca öndeki uygulama okuyabildiği için kontrol Pastronaut'u açar ve
      uygulama panoyu kaydeder (`SaveClipboardIntent`, bekleyen istek bayrağı). Uygulama geçmiş değişince widget'ları
      yeniler.
    - Paylaş uzantısı (`iOS/Share`): Paylaş › Pastronaut metni ya da bağlantıyı doğrudan iCloud'a yazar
      (`KeyboardCloud.capture`; önce gelen kutusu, yükleme olmazsa uygulama sonra gönderir). Panoya dokunmadığı için
      art arda kopyalarda kayıp yok.
    - Kısayollar: Son Öğeyi Al, Son Öğeleri Al, Son Öğeyi Kopyala (varsayılan Mac'ten), Panoyu Kaydet; Siri
      ifadeleri EN/TR (`AppShortcuts.xcstrings`). Okuma eylemleri kilidi açık iPhone ister.
    - Arama: iPhone'da arama alanına çipler (sabitlenenler, bugün, bu hafta, bağlantı, e-posta, telefon, renk, kod,
      metin); aynı gruptakiler genişletir, farklı gruplar daraltır; "ı" ile "i" aramada eşit. Mac'te cihaz çiplerinin
      yanında aynı seçenekleri sunan filtre menüsü (`ClipFilterMenu`). Kurallar `PastronautCore/ClipSearch.swift`.
    - Face ID kilidi: Ayarlar › Gizlilik › "Face ID ile Kilitle" (açarken bir kez doğrulanır). Uygulama açılırken
      ister, uygulama değiştiricide geçmişi örter, widget'lar öğeleri gizler. Klavye açık kalır (iPhone klavyeleri
      Face ID isteyemez); E2E sırasında devre dışı.
    - Testler: çekirdek 43/43, Mac 104/104, Mac UI `testPastronautFilterMenu`, E2E 31/31 (+T13 uyarısı). Widget,
      kontrol, Paylaş, Siri ve Face ID sistem yüzeyleri olduğu için elle denenir.
  - 4.7 Dalga 3 (2026-10-17, uygulandı; iPad elle doğrulanmadı):
    - Gizli kayıt adları ve yeni bölge: kayıtlar "Library" bölgesinde, adları hesap anahtarıyla HMAC (§4.2). Sürüm 1
      verisi arka planda taşınır: ayna `clip-sync-v1.json` olarak yedeklenir, eski bölge okunur, öğeler yeni bölgeye
      yazılır, hepsi gönderilince eski "Clips" bölgesi silinir. Taşıma sırasında silinenler geri gelmez
      (`legacyTombstones`). Henüz güncellenmemiş bir cihaz eski bölgeye yazarsa yeni cihazlar onu yine taşır; güncellenmemiş
      cihaz yerel geçmişini korur ama yeni bölgeyi göremez (tüm cihazlar güncellenmeli). Bilinen sınır: bir cihaz
      taşındıktan sonra silinen bir öğe, geç taşınan başka bir cihazın aynasından geri gelebilir.
      Gerçek veride denendi: iPhone 56 öğe, Mac 56 öğe ve 62 öğelik geçmiş aynen korundu; iki cihaz aynı anahtarda.
    - Koleksiyonlar: iPhone'da cihaz çiplerinin yanında koleksiyon çipleri (+ yeni), satır menüsünde ve seçim modunda
      "Koleksiyona Ekle", ayrıntıda koleksiyon satırı, çipte basılı tutunca Yeniden Adlandır/Sil. Mac'te satır sağ tık
      menüsü, filtre menüsünde Koleksiyonlar bölümü, önizlemede koleksiyon adları, Ayarlar › Eşitleme'de yönetim.
      Klavyede koleksiyon sekmesi (klasör simgesi, yalnızca koleksiyon varsa). Mac'te koleksiyonlar iCloud eşitlemesi
      açıkken vardır.
    - Mac önizlemesinde "Görseldeki Metin" ve "Metni Kopyala" (Maccy'nin tanıdığı metin).
    - Dışa/içe aktarma: `ClipArchive` (JSON, `pastronaut-archive` sürüm 1). Mac: Ayarlar › Depolama › Dışa aktar;
      iPhone: Ayarlar › Verilerin. İçe aktarma yalnızca ekler, aynı adlı koleksiyonu yeniden kullanır, iki kez
      aktarmak bir şey değiştirmez.
    - Spotlight (iPhone, varsayılan kapalı): yalnızca sabitlenenler; seçilen sonuç kopyalanır; Face ID kilidi
      açıkken dizin boşaltılır.
    - iPad: `TARGETED_DEVICE_FAMILY 1,2`, geniş ekranda kenar çubuğu (cihazlar + koleksiyonlar, koleksiyona
      bırakma), sürükle-bırak (satırlar yalnızca iPad'de sürüklenir: iPhone'da sürükleme bağlam menüsünü "meşgul"
      tutup UI testini dakikalarca bekletiyordu), "Açılınca kaydet" açıkken uygulama ekrandayken yeni kopyaları
      kaydeder. Bu Mac'te iOS simülatörü yüklü olmadığından iPad yalnızca derlendi.
    - Testler: çekirdek 69/69, Mac 108/108, Mac UI `testPastronautPopupExtras` ve `testPastronautFilterMenu`. E2E son
      tur 34 geçti + T13 uyarısı; yeni T30–T33 (ortak anahtar ve eski bölgenin silinmesi, koleksiyon Mac→iPhone,
      iPhone→Mac ve koleksiyon silme) üç turda da geçti. T15 yalnızca test adımı yüzünden düştü (eski satır ekran
      dışındaydı); adım düzeltildi ve senaryo tek başına 3/3 geçti.
    - Turlarda bulunan hatalar: iPhone'da açık koleksiyon başka cihazda silinince liste boş kalıyordu (artık Tümü'ne
      döner); iPhone'da sürüklenebilir satırlar bağlam menüsünü kilitliyordu (sürükleme yalnızca iPad'de).
  - ✅ 4.8 Dalga 4 (tasarım; kararlar ve uygulama 2026-10-17, taslaklar: claude.ai/artifact/9vFzTdRTriSotafFwJ6SKf):
    - Uygulandı: logotip 1a (`PastronautWordmark`, vektör; harfler `scripts/brand/wordmark.swift` ile Unbounded'dan
      bir kez çıkarıldı, OFL), sabit üst çubuk, ortak tür renkleri (`ClipKind`), adres türü, kartlar ve önizlemeler
      (`PreviewStore`, `LinkPreviewPolicy`, `CodeHighlighter`), ilk açılış sorusu, yeni klavye düzeni, koleksiyonlara
      kimlikten türetilen sabit renk. Ekran görüntüleriyle denetlendi (iPhone açık/koyu, klavye açık/koyu, Mac popup).
    - Elle denemeden sonra (2026-10-17): sistemin adres tanıyıcısı Türk adreslerinin çoğunu kaçırıyordu (numaralı
      sokak, önce mahalle, apartman/kat/daire, "ilçe / il"). `TurkishAddress` cihazda ek kural uygular: sokak düzeyi
      bir kelime ve kapı numarası, posta kodu (01–81 ile başlayan 5 hane) ya da 81 ilden biri. Harita, bulunamazsa
      apartman ayrıntısız adresi, sonra yalnızca ilçe/ili dener. Çip çubuğu artık kaymaz: koleksiyonlar tek bir
      menü çipinde; yer daralınca sayılar, sonra başlıklar düşer. Kartlar tahmini yüksekliğe göre kısa sütuna yerleşir.
    - Tür renkleri her yerde aynı: metin kurşuni, bağlantı mavi, kod mor, e-posta camgöbeği, telefon yeşil, adres
      turuncu, görsel pembe, dosya toprak; renk öğesi kendi rengi, görsel küçük resmi. Mac'te "renkli simge" stili
      (soluk zemin + renkli simge); seçili satırda simge beyaz zemine geçer. Simgesiz kalan satırlar düzeltilecek.
    - iPhone: önizlemeler açıkken türe göre kartlar (iki sütun); adreste harita (NSDataDetector + MKMapSnapshotter),
      bağlantıda sayfa önizlemesi (LinkPresentation), kodda cihazda renklendirme. Tek kullanımlık görünen
      bağlantılar (token, reset, verify, login, unsubscribe, uzun sorgu) hiç açılmaz. Önizlemeler ilk açılışta bir
      kez sorulur; kapalıyken uygulama Mac'e benzer bir liste görünümüyle açılır.
    - Başlık sabit: büyük, kayan başlık yerine sabit bir üst çubukta logotip (kaydırırken titreme hatası da bununla
      gider). Logotip seçimi sürüyor (sekiz seçenek).
    - Klavye: iki sütunlu ızgara + alt kategori çubuğu (son, sabit, Mac, iPhone, koleksiyonlar renkli baş harfle) +
      tuş sırası (ara, boşluk, sil, satır başı); üstte "Mac'ten son" kutusu.
  - 4.9 Dalga 5 (2026-10-17, uygulandı; iPhone eylemleri ve widget elle denenecek):
    - Mac, Space ile önizleme: arama kutusu boşken Space önizlemeyi açıp kapatır (⌃Space de çalışır; yazı varken
      Space aramaya gider). Önizleme türe göre: kod koyu panelde renkli (iPhone kartlarıyla aynı `CodeTheme`), renk
      büyük örnek + RGB, bağlantı/adres/e-posta/telefon için tek düğme (Bağlantıyı Aç, Yol Tarifi, E-posta Yaz, Ara).
    - Mac, Sıra: ⌘-tık ya da ⇧↑/⇧↓ ile birkaç satır seçilir, Return (ya da alttaki "Sırayı Başlat") ilkini panoya
      koyar; başka uygulamada her ⌘V'den sonra sıradaki panoya geçer, son öğede sıra biter. Maccy'nin kapatılmış
      çoklu seçim ve yapıştırma yığını altyapısı açıldı; eklenenler: açıklayan alt satır ("3 seçili · Return ile
      sıra başlar", "Sıra: 2 kaldı", Sırayı Bitir), ⌘ basılıyken fareyle geçilen satırın seçimi değiştirmemesi ve
      sıranın başında otomatik yapıştırma yapılmaması (sıradaki öğe yapıştırma bitmeden panoya geçebiliyordu).
      Başka bir kopya sırayı bitirir. Genel ⌘V dinleyicisi Erişilebilirlik izni ister (yapıştırma için zaten var).
    - Mac, arama filtreleri: `app:`/`uygulama:`, `type:`/`tür:` (bağlantı, kod, renk, adres, e-posta, telefon,
      metin, görsel, dosya), `date:`/`tarih:` (bugün, dün, hafta), `from:`/`cihaz:` (mac, iphone); boşluklu değer
      tırnakla. Bilinmeyen anahtar ya da değer düz metin kalır, filtre yoksa arama metni hiç değişmez (Maccy'nin
      tam ve regex aramaları için). Ayrıştırıcı çekirdekte (`ClipQuery`). ⌘G: arama/filtre varken seçili satırı
      geçmişteki yerinde gösterir. Filtre menüsünün altında örnek satırı.
    - iPhone Kısayollar: "Öğe Al" (n'inci öğe; kaynak ve isteğe bağlı koleksiyon), "Koleksiyona Ekle" (metni kaydeder
      ve koleksiyona katar), "Son Öğeleri Al"a koleksiyon seçeneği. Widget "Son Öğeler" bir koleksiyonu
      gösterebilir (başlıkta koleksiyon adı). Koleksiyon seçimi `CollectionEntity` (app group'taki collections.json).
    - Klavye aramasında 123/ABC tuşu: rakamlar ve aranan işaretler (- / : ; ( ) ₺ & @ " . , ? ! ' # % +).
    - Elle denemeden sonra: harita uygulamalarından kopyalanan koordinatlar (Google `38.4237, 27.1428` ve
      `38°25'25.3"N 27°08'34.1"E`, Apple `38,4237° K, 27,1428° D`) adres türü sayılır; iPhone haritası koordinatı
      doğrudan kullanır, yol tarifi koordinata gider (`Coordinates`). Sıra, Erişilebilirlik izni yoksa ⌘V'yi
      göremez ve hep ilk öğe yapıştırılır: seçim/sıra satırının üstünde uyarı ve "İzin Ver…" (sistem isteği, izin
      sayfası ve uygulamayı Finder'da gösterme). macOS 27'de sayfanın adı "Aygıt Denetimi ve Veri Erişimi"; uygulama
      ~/Applications'tayken istek onu listeye eklemedi, sürükleyerek eklendi. Elle denendi: sıralı yapıştırma çalışıyor.
    - Kurulum rehberinde "iPhone'da ne beklemeli" kartı: Mac'ten gelen kendiliğinden; iPhone'dan kopya tek dokunuşla
      (açılınca kaydet, klavyede Yapıştır, Denetim Merkezi/Arkaya Dokun/Eylem düğmesi, Paylaş).
- **Faz 5: Yayın.** Gizlilik politikası (GitHub Pages), App Store Gizlilik Etiketi, CloudKit Production şeması,
  TestFlight ve App Store; Mac için GitHub Releases, Homebrew tap, Mac App Store.
- **Sonra:** görseller, sabit bölümü, Paylaş uzantısı, iPad, Mac App Store.

## 9. Kararlar (2026-10-16)
| Konu | Karar |
|---|---|
| Paket kimliği | `com.xkbxyberk.pastronaut`. Türetilenler: `….keyboard` (klavye uzantısı), `….tests` |
| App Group | `group.com.xkbxyberk.pastronaut` |
| iCloud kapsayıcısı | `iCloud.com.xkbxyberk.pastronaut` |
| Apple ekibi | `V88QY49A4T` |
| En düşük sürümler | iOS 17, macOS 14 (upstream ile aynı) |
| Fiyat | Ücretsiz, uygulama içi satın alma yok |
| Upstream'e not | Taslak: `docs/pastronaut/upstream-not.md`. Kullanıcı onayı olmadan gönderilmez. |
| Mac popup'ı (2026-10-16) | Kendi tasarımımız, 1.0'da: gruplar (Sabitlenenler/Bugün/Dün), cihaz filtresi, önizleme paneli, eşitleme durum satırı. Bedeli: upstream'den güncelleme büyük ölçüde elle seçmeli aktarıma döner (R6 kabul edildi). |
| 1.0 kapsamı (2026-10-16) | Geniş: Mac yeni popup + ayarlar + ilk açılış rehberi; iOS ana ekran, ayrıntı, canlı kurulum rehberi; klavyede "Mac'ten son kopya", sekmeler ve arama; widget'lar, kilit ekranı, Denetim Merkezi (iOS 18+), Paylaş uzantısı, ek Kısayollar eylemleri, Face ID kilidi; kendi ikonlar; EN/TR yerelleştirme. |
| Hassas veri (2026-10-16) | Varsayılan: her şey eşitlenir (parola yöneticisi kopyaları hariç, bugünkü gibi). Ayarlarda ayrı anahtarlar, varsayılanı kapalı: "Tek kullanımlık kodları eşitleme" (Mac'te 5 dk sonra siler), "Kart ve IBAN numaralarını eşitleme", "Yalnızca sabitlenenleri eşitle". |
| Yerelleştirme (2026-10-16) | İngilizce temel, Türkçe tam. iOS: String Catalog (`.xcstrings`) her hedefte; Mac: Maccy'nin `.strings` dosyalarına dokunulmaz, bizim metinler ayrı `Pastronaut.xcstrings` tablosunda. Testler etiket değil erişilebilirlik kimliğiyle öğe bulur. |
| Dağıtım (2026-10-16) | iOS: App Store (TestFlight önce). Mac: GitHub Releases (Developer ID + noter onayı + Sparkle) → kendi Homebrew tap'i → Mac App Store (iOS ile aynı paket kimliği, Universal Purchase). |
| Görsel kimlik v2 (2026-10-16) | Taslaklar: https://claude.ai/artifact/VgG1CnRShnUMFaLNVLLvgM ("Kimlik v2"). **Gökyüzü paleti:** gök #87CEEB (marka, ikon, koyu temada vurgu), derin gök #1E6FA8 (açık temada vurgu; beyaz yazı 5:1), gece #0E2236, sis #E3F3FA, güneş #F2A541 (sabitler; açık temada #C77A12). iOS'ta koyu temada dolgulu düğme yazısı gece rengi (`AccentForeground`; beyaz yazı gök mavisinde 1,8:1). Mac'te seçim beyaz yazı taşıdığı için koyu tema vurgusu #2A7DBA, simgeler `BrandColor` (koyuda gök). **İkon:** "Ufuk" + yörünge: gece zemini, gezegen ufku, yıldızlar, kask, vizörde turuncu pano, gök mavisi yörünge (üst yarı arkada, alt yarı uyduyla önde); Icon Composer'ın 4 grup sınırına göre katmanlı. **Menü çubuğu:** varsayılan "Kask + pano" (halka, vizörde pano silueti, yan ışıklar, boyunluk); Görünüm ayarlarında adlarıyla 8 seçenek. |
| Paste araştırması (2026-10-17) | Kaynak: `research/paste-ozet.md`. Sıra Dalga 1 → 2 → 3. Pin grupları "Koleksiyon" (EN *Collection*); "Pinboard", "Paste Stack" ve yatay kart şeridi kullanılmaz, dikey popup korunur. iOS'ta açılışta otomatik kayıt varsayılan kapalı. Görsel eşitleme 1.0 sonrası ("yalnız metin = güvenilir"). Telemetri ve varsayılan açık yapay zekâ yok; yerel MCP sunucusu "Sonra" listesinde. (Kullanıcı soruları yanıtlamadan "devam et" dedi; öneriler varsayılan alındı, değiştirilebilir.) |
| Liquid Glass (2026-10-16) | iOS/macOS 26+'nın cam tasarımı korunur ve desteklenir. Sistem bileşenleri (gezinme ve araç çubukları, arama, sayfalar, listeler) özel arka planla örtülmez; cam kendiliğinden gelir. Özel yüzeyler (Mac popup'ı, klavye çipleri, widget'lar) 26+'da `glassEffect`, 17–25'te materyal kullanır. İkon Icon Composer biçiminde (`AppIcon.icon`, katmanlı); eski sürümler için Xcode düz ikon üretir. Taslaklardaki opak yüzeyler yalnızca yerleşimi gösterir. |

## 10. Geliştirme ortamı
- **PastronautCore testleri:** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test` (paket artık
  String Catalog içeriyor; Komut Satırı Araçları'nın `swift`'inde katalog derleyicisi yok).
- **Ekran görüntüsü:** `TEST_RUNNER_PT_OP=screenshot` adımı geçmiş, ayrıntı, Ayarlar ve kurulum ekranlarını sonuç paketine
  ekler; `xcrun xcresulttool export attachments` ile çıkarılır.
- **İki cihazlı uçtan uca test:** Mac Debug derlemesi ve iOS `build-for-testing` sonrası
  `scripts/e2e/sync_e2e.py --mac-app <Pastronaut.app> --xctestrun <…xctestrun> --device <UDID>`. Mac push'unun
  çalışması için `--mac-app` bir Uygulamalar klasöründeki kopya olmalı (ör. `ditto … ~/Applications/Pastronaut.app`; R7). iPhone kilidi açık ve
  bağlı kalmalı; ~13 dk sürer. Mac yalnızca Debug derlemesindeki `E2EControl` ile, iPhone XCUITest adımlarıyla
  (`iOS/UITests`) sürülür; durum Mac'te birleşik günlükten, iPhone'da `devicectl` ile App Group dosyalarından okunur.
  `test-without-building` değişen uygulamayı her zaman yeniden kurmuyor; betik bu yüzden önce `devicectl` ile kurar.
- **UI otomasyon izni (2026-10-17):** macOS'ta Otomasyon Modu parolasız açılacak şekilde ayarlandı
  (`sudo automationmodetool enable-automationmode-without-authentication`, kullanıcı onayıyla). Bu ayar yokken Mac ve
  iPhone UI testleri "Timed out while enabling automation mode" ile başlamadan düşüyor. Durum: `automationmodetool`.
- Xcode 27.1 `/Applications/Xcode.app` içinde. `xcode-select` Komut Satırı Araçları'nı gösteriyor; bu yüzden komutlar
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ile çalıştırılır.
- iOS SDK 27.1 kurulu. iOS simülatör çalışma zamanı **yok**. Faz 0 için ya simülatör indirilecek (birkaç GB, onay gerekir)
  ya da gerçek iPhone kullanılacak. Klavye ve pano testleri için gerçek cihaz zaten daha güvenilir.
