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
- CloudKit kayıt adı = `clipID`. Aynı metin hangi cihazda kopyalanırsa kopyalansın tek kayda düşer
  (cihazlar arası tekrar birleştirme kendiliğinden olur).
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
| deleted | — | — | Silme, kaydın silinmesiyle yayılır |

Kopya sayısı eşitlenmez; her cihaz kendi sayısını tutar. Toplama işlemi eşitlemede tutarlı kalmıyor.

### 4.4 Sınırlar ve silme
- Bulutta en fazla `syncLimit` (varsayılan 200) sabit olmayan kayıt ve tüm sabit kayıtlar tutulur. En eskiler
  buluttan silinir; yereldeki geçmiş etkilenmez.
- "Öğeyi sil" ve "Temizle" diğer cihazlara yansır. Ayarlarda "yalnızca bu cihazda temizle" seçeneği de olur.
- Ayar: "iCloud eşitlemesi" (varsayılan kapalı). Kapatınca bulut verisini silme seçeneği sunulur.

### 4.5 Gizlilik
- Yalnızca Mac'te yok sayma kurallarından geçip geçmişe giren öğeler eşitlenir. Gizli işaretli kopyalar zaten geçmişe girmez.
- iPhone'da yakalanan kopyalar için de aynı düzenli ifade kuralları uygulanır (kurallar eşitlenen bir ayar kaydında tutulur; Sonra).
- Şifreli alanlar Apple'ın uçtan uca şifrelemesiyle korunur; geliştirici CloudKit panosunda içeriği göremez.

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
  2. Klavye açıldığında pano değiştiyse okunur (Tam Erişim gerekir).
  3. App Intent "Panoyu Pastronaut'a kaydet": Kısayollar, Arkaya Dokun ve Eylem düğmesi için.
  4. (Sonra) Paylaş uzantısı.
  5. Universal Clipboard: telefon Mac'e yakınken telefonda yapılan kopya Mac'e düşer ve oradan eşitlenir.
     Bu kopyalar panoda `com.apple.is-remote-clipboard` türüyle işaretli gelir. Proje sahibi bu türü yok sayma
     listesine eklemeyi önermiş (#182, 2024). Kullanıcı eklemişse bu yol kapanır; Eşitleme ayarlarında bu durum belirtilmeli.
     Bu tür, kaynağı "iPhone" olarak işaretlemek için de kullanılabilir.
- Eşitleme: CKSyncEngine uygulamada çalışır. Sessiz anlık bildirim ve arka plan yenilemesiyle uyanır. Klavyenin
  yazdığı yeni kopyalar bir sonraki uyanışta gönderilir.

## 7. Riskler ve doğrulanacaklar
| # | Konu | Nasıl doğrulanır |
|---|---|---|
| R1 | Klavye kuralları (App Review 4.4.1): giriş işlevi, sonraki klavye düğmesi, Tam Erişim olmadan çalışma | Güncel kural metni ve küçük bir prototip ile TestFlight dış inceleme |
| R2 | Klavye uzantısı Tam Erişim'le panoyu okurken iOS onay penceresi çıkıyor mu? | Faz 0 prototipi |
| R3 | CloudKit Developer ID ile dağıtılan Mac uygulamasında sorunsuz çalışıyor mu? | Faz 0 prototipi |
| R4 | Klavye bellek sınırı | Faz 2'de Instruments ile ölçüm |
| R5 | "Pastronaut" adının App Store'da ve marka olarak uygunluğu | App Store Connect'te ad ayırma, marka araması |
| R6 | Upstream değişiklikleriyle birleşme maliyeti | Değişiklikleri kanca ve ayrı klasörlerle sınırlamak |

## 8. Fazlar ve kabul ölçütleri
- **Faz 0: Riskleri kapatan prototip (1 hafta).** CloudKit'e yazan minimal bir Mac uygulaması, okuyan bir iOS uygulaması
  ve panoyu okuyan bir klavye. Ölçüt: R2 ve R3 yanıtlanır.
- **Faz 1: Mac eşitlemesi.** Ölçütler:
  - Ayar açıkken kopyalanan metin 10 saniye içinde bulutta.
  - Tekrar kopyalama yeni kayıt açmaz.
  - Yok sayılan bir türdeki kopya buluta gitmez (birim test).
  - Silme ve temizleme yayılır.
- **Faz 2: iOS uygulaması ve klavye (yalnızca metin).** Ölçütler:
  - Mac'te kopyalanan metin iPhone klavyesinde görünür ve dokunulunca yazılır.
  - Tam Erişim kapalıyken klavye çökmez ve yönlendirme gösterir.
- **Faz 3: Telefon kopyaları.** Ölçüt: uygulama, klavye ve Kısayol ile yakalanan kopya Mac geçmişinde görünür.
- **Faz 4: Yayın.** Lisans ekranı, gizlilik politikası (App Store zorunlu), App Store Gizlilik Etiketi, TestFlight, başvuru.
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

## 10. Geliştirme ortamı
- Xcode 27.1 `/Applications/Xcode.app` içinde. `xcode-select` Komut Satırı Araçları'nı gösteriyor; bu yüzden komutlar
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ile çalıştırılır.
- iOS SDK 27.1 kurulu. iOS simülatör çalışma zamanı **yok**. Faz 0 için ya simülatör indirilecek (birkaç GB, onay gerekir)
  ya da gerçek iPhone kullanılacak. Klavye ve pano testleri için gerçek cihaz zaten daha güvenilir.
