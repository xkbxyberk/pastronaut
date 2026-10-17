# Paste araştırması: özet, eksiklerimiz ve beyin fırtınası

> Tarih: 17 Ekim 2026. Bu dosya üç ayrıntılı raporun sentezidir:
> [paste-macos.md](paste-macos.md) · [paste-ios.md](paste-ios.md) · [paste-market.md](paste-market.md).
> Yöntem: yalnızca açık kaynaklar (resmi site, yardım merkezi, App Store, basın, Product Hunt, HN).
> Uygulama indirilmedi, tersine mühendislik yapılmadı. "Nasıl yapıyor" başlıklarının çoğu **tahmindir**;
> kaynak raporlarda [Doğrulandı]/[Tahmin] işaretleri var.
>
> Kural: Fikir ve işlev serbesttir, ifade serbest değildir. Paste'in adı, terimleri ("Pinboard",
> "Paste Stack"), ikonu, renk dili, kart görünümü, metinleri ve ekran görüntüleri kullanılmaz.
> Aşağıdaki her öneri kendi tasarımımızla ve kendi terimlerimizle yapılacak şekilde yazıldı.

---

## 1. Tek paragrafta sonuç

Paste olgun (2015'ten beri), çok cilalı ve özellik bakımından bizden açıkça geniş. Asıl farkları beş
alanda: **koleksiyonlar** (adlı, renkli pin grupları ve bunların paylaşımı), **zengin içerik** (görsel,
dosya, bağlantı önizlemesi, OCR), **güçlü arama** (tür/uygulama/tarih/cihaz filtreleri, jeton arayüzü,
"geçmişte göster"), **iOS'ta daha çok yakalama yolu** (açılışta otomatik kayıt, Paylaş/Eylem uzantıları,
Spotlight) ve **yapay zekâ entegrasyonları** (MCP, Intelligent Clipboard). Buna karşılık en çok şikâyet
aldığı yerler: **abonelik**, **eşitleme hataları ve veri kaybı**, **varsayılan açık yapay zekâ**,
**kapatılamayan analitik** ve zayıf iOS deneyimi. Bizim için en doğru strateji Paste'i kopyalamak değil:
güvenilir eşitleme, gizlilik ve ücretsizlik çekirdeğimizi koruyup **Paste'in iOS'ta hiç kullanmadığı Apple
yüzeylerine** (etkileşimli widget, Denetim Merkezi, Action Button) girmek ve en çok istenen işlevleri
(koleksiyonlar, filtreli arama, iOS yakalama yolları) kendi tarzımızda eklemek.

---

## 2. Yetenek haritası

| Alan | Paste | Pastronaut | Fark |
|---|---|---|---|
| Mac pencere düzeni | Alttan açılan yatay kart şeridi, sürükleyerek boyut, Compact Mode | Maccy dikey popup, gün başlıkları, cihaz filtresi, Liquid Glass | Farklı yaklaşım. Dikey popup **bilerek** korunacak (yasal + kimlik) |
| Pin / koleksiyon | Adlı ve renkli koleksiyonlar, saklama süresinden muaf, sürükle-bırak sıralama | Tekil pin + harf kısayolu | **Eksik** |
| Paylaşılan koleksiyon | iCloud paylaşımı (büyük olasılıkla `CKShare`), okuma/yazma izinleri | Yok | Eksik (düşük öncelik) |
| İçerik türleri (eşitleme) | Metin, bağlantı, görsel, dosya, renk | Yalnızca metin (≤100 KB) | **Eksik**, ama güvenilirlik avantajı da var |
| Bağlantı önizlemesi | Küçük resim + başlık, dahili tarayıcı | Tür simgesi + "Bağlantıyı Aç" | Eksik |
| OCR | Görsel içi metin aranır, önizlemede metin çıkarılır | Mac: Maccy görseldeki metni Vision ile tanıyıp başlık yapıyor, yani aranabiliyor (`HistoryItem.recognizeText`). "Metni kopyala" eylemi yok | Kısmen |
| Arama | Yazım hatasına toleranslı, vurgulu, filtre jetonları (tür/uygulama/cihaz/tarih/koleksiyon), "geçmişte göster" | Maccy araması + cihaz filtresi | **Kısmen** |
| Düzenleme | Başlık verme, içerik düzenleme, yeni öğe (⌘N), görsel döndürme, renk seçici, Writing Tools | Mac: başlık düzenleme (Maccy). iOS: içerik düzenleme | Kısmen |
| Sıralı yapıştırma | Var (ters yön, kopyaları ayıklama) | Maccy'de kod var (`PasteStack`) ama çoklu seçimle başlıyor ve çoklu seçim kapalı, yani kullanılamıyor | Kısmen |
| Çoklu seçim | ⌘/⇧ ile, toplu sil/pinle/yapıştır | Kod var ama kapalı (`AppState.multiSelectionEnabled = false`) | Kısmen |
| Gizlilik: uygulama dışlama, gizli/geçici türler | Var | Var (Maccy) | Eşit |
| Zamanlı duraklatma | 15 dk / 1 sa / elle | Maccy'de yalnızca aç/kapat ("ignoreEvents") | Eksik |
| Ekran paylaşımında gizleme | Var | Yok | Eksik (çok kolay) |
| Süreye göre saklama | 1 gün … sonsuz, varsayılan 1 ay | Adet sınırı (1–999) | Eksik |
| Kod/kart/IBAN filtresi | **Yok** | Var (Luhn, mod-97, tam kelime) | **Biz öndeyiz** |
| Şifreleme | Hiçbir iddia yok | `encryptedValues` (ama bkz. §4) | Biz öndeyiz (bir düzeltmeyle) |
| Telemetri | PostHog + Sentry, kapatma anahtarı yok | Yok | **Biz öndeyiz** |
| iOS yakalama | Açılışta otomatik ("Allow" yönlendirmesi), klavye açılışında, Paylaş + Eylem uzantısı, belge tarama, "+" | PasteButton (uygulama + klavye), "Save to Pastronaut" kısayolu | **Eksik** |
| iOS klavye | Geçmiş, koleksiyonlar, sürükle-bırak, harf/sayı/sembol yazma modları | Geçmiş, Mac'ten son kopya, sekmeler, arama, renk ve uygulama bilgisi | Yakın. Biz daha hafifiz |
| Widget | Liste açan başlatıcı | Yok (1.0 planında) | Fırsat |
| Denetim Merkezi / Action Button / Live Activity | **Yok** | Yok (1.0 planında) | **Fırsat: Paste'te yok** |
| Kısayollar | Ekle / son öğeyi al / n'inci öğeyi al | Mac: Maccy Intents (Get/Select/Delete/Clear). iOS: yalnızca "Save" | Kısmen |
| Spotlight | Var | Yok | Eksik |
| iPad | Kenar çubuğu, görünürken otomatik yakalama, sürükle-bırak | iPad'e özel bir şey yok | Eksik |
| Yapay zekâ | MCP, Intelligent Clipboard, Writing Tools | Yok | Bilinçli fark (bkz. §6) |
| Fiyat | 3,99 $/ay · 29,99 $/yıl · 99,99 $ ömür boyu | Ücretsiz, MIT | **Biz öndeyiz** |
| Dil | 16 dil, **Türkçe yok** | EN + TR | Biz öndeyiz (TR) |

---

## 3. Paste'in bizim yapamadığımız şeyleri nasıl yaptığı

Her madde şu sırayla: ne yapıyor → büyük olasılıkla nasıl → bizde nasıl olur → efor (K küçük, O orta,
B büyük). "Nasıl" kısmındaki Apple API'leri herkese açık, belgelenmiş API'lerdir.

### 3.1 iPhone'da otomatik yakalama (en önemli iOS farkı)
- **Ne:** Paste uygulaması ya da klavyesi öne geldiğinde panodaki yeni içeriği kendiliğinden geçmişe ekliyor.
- **Nasıl:** iOS kısıtını aşmıyor, ön plana gelme anını kullanıyor. Önce `UIPasteboard.changeCount` ile
  "pano değişti mi" diye bakıyor; bu kontrol uyarı çıkarmıyor. Sonra okuyor. Kullanıcıyı Ayarlar → Uygulamalar →
  Paste → "Paste from Other Apps" → **Allow** ayarına yönlendirdiği için okuma da uyarısız. Ayarlarında bu ayara
  giden ayrı bir satır var.
- **Bizde:** Klavyede zaten `changeCount` karşılaştırmamız var (`hasNewClip`), ama yalnızca "yeni kopya var"
  ipucu gösterip PasteButton'a dokunmayı bekliyoruz. İsteğe bağlı bir ayar eklenebilir: **"Açılınca panoyu
  kaydet"** (varsayılan kapalı). Açıldığında uygulama ve klavye, "Allow" ayarı verilmişse panoyu kendiliğinden
  kaydeder. Ayarlar'a giden satır `UIApplication.openSettingsURLString` ile açılır. Gizlilik süzgeçleri
  (kod/kart) bu yolda da uygulanır. **Efor: K–O.**
- **Not:** Art arda yapılan kopyalardan yalnızca sonuncusu yakalanır. Bunu kurulum rehberinde dürüstçe yazalım
  ve çözüm yolu olarak Paylaş uzantısını gösterelim.

### 3.2 Paylaş ve Eylem uzantıları
- **Ne:** Paylaş sayfasından "Pastronaut'a kaydet". Pano izni gerekmiyor; art arda kopyalarda veri kaybetmemenin
  tek güvenilir yolu bu.
- **Nasıl:** Paylaş uzantısı (`com.apple.share-services`) ve arayüzsüz Eylem uzantısı (`com.apple.ui-services`).
  `NSItemProvider` ile metin/URL alınıp ortak veriye yazılıyor ve eşitleme tetikleniyor.
- **Bizde:** Klavyede kurduğumuz yol hazır: önce App Group gelen kutusu (`appendToInbox`), sonra
  `KeyboardCloud.save`. Uzantı aynı kodu kullanır. **Efor: O.** (1.0 kapsamında zaten var.)

### 3.3 Koleksiyonlar
- **Ne:** Adlı ve renkli gruplar. Bir öğe tek bir gruba ait. Saklama süresinden muaf. Sürükle-bırakla sıralanıyor.
  Gruplar arası geçiş için kısayol var.
- **Nasıl (tahmin):** Öğe modelinde tek bir grup kimliği alanı ve ayrı bir grup kaydı.
- **Bizde:** `Clip` içine `collectionID: String?` (şifreli alan) ve ayrı bir `Collection` CloudKit kaydı
  (ad + renk + sıra, şifreli). Mac'te Maccy'nin pin/sıralama mantığı ile birleştirilmeli: "pinli" = herhangi bir
  koleksiyonda olmak. Klavyedeki "Sabit" sekmesi koleksiyon seçicisine dönüşür. **Efor: B.** Şema değişikliği
  gerektirdiği için §4'teki kimlik düzeltmesiyle **aynı sürümde** yapılması mantıklı.
- **Terim:** "Pinboard" değil. Öneri: **Koleksiyon** (EN: *Collection*). Alternatif: *Klasör*, *Raf*.

### 3.4 Filtreli arama ve "bağlamda göster"
- **Ne:** Yazarken "tür: bağlantı", "uygulama: Safari", "cihaz: iPhone", "tarih: dün" gibi öneriler çıkıyor.
  Seçilenler arama alanında jeton (silinebilir çip) olarak duruyor. Bir sonuçtan öğenin geçmişteki yerine
  gidilip çevresindeki kopyalar görülebiliyor.
- **Nasıl (tahmin):** Ayrı bir tam metin arama indeksi (SQLite FTS benzeri) ve jeton arayüzü.
- **Bizde:**
  - iOS'ta SwiftUI'nin yerleşik `.searchable(text:tokens:suggestedTokens:)` API'si tam olarak bu işi yapıyor.
    Sistem bileşeni olduğu için kopyalama sorunu yok. **Efor: O.**
  - Mac'te Maccy'nin arama alanına "önek" sözdizimi (`app:`, `tür:`, `dün`) eklenir ve ayrıştırılan
    filtreler alanın altında küçük çipler olarak gösterilir. Cihaz filtremiz bu modele taşınır. **Efor: O.**
  - "Bağlamda göster": gün başlıklarımız olduğu için doğal bir uyum var. Aramayı kapat, listeyi o öğeye kaydır,
    kısa bir vurgu yap. **Efor: K.**

### 3.5 Görsel eşitleme, bağlantı önizlemesi, OCR
- **Nasıl (tahmin):** Görseller `CKAsset` ile eşitleniyor (sürüm notunda "geçici eşitleme dosyaları diski
  doldurdu" hatası var). Bağlantı önizlemesi büyük olasılıkla `LPMetadataProvider`, OCR ise Vision
  (`VNRecognizeTextRequest` ya da iOS/macOS 26'nın `RecognizeDocumentsRequest`'i).
- **Bizde:**
  - **OCR (yalnız Mac, yalnız yerel):** Kodu okuyunca görüldü: Maccy görselin metnini zaten Vision ile tanıyıp
    öğe başlığı yapıyor, bu yüzden aranabiliyor. Eksik olan yalnızca önizlemede "Metni kopyala" düğmesi. **Efor: K.**
  - **Bağlantı önizlemesi:** Siteye istek atar, yani kopyalanan bağlantı üçüncü taraf sunucuya gider.
    Gizlilik çizgimizle çelişebilir. **Varsayılan kapalı** bir seçenek olabilir. **Efor: O.**
  - **Görsel eşitleme:** `CKAsset` + boyut sınırı (ör. 5 MB) + küçük resim. Klavyenin bellek sınırı yüzünden
    klavyede yalnızca küçük resim gösterilir. **Efor: B.** Paste'in en çok sorun yaşadığı alan bu, bu yüzden
    sonraya bırakılmalı ve "yalnız metin = güvenilir" mesajı şimdilik korunmalı.

### 3.6 Spotlight
- **Nasıl:** Core Spotlight (`CSSearchableIndex`). Öğeler sistem aramasında çıkıyor.
- **Bizde:** Mümkün, ama pano içeriğini sistem indeksine koymak hassas bir karar. **İsteğe bağlı**, yalnızca
  pinler/koleksiyonlar için ve kod/kart süzgecinden geçmiş öğelerle yapılmalı. **Efor: K–O.**

### 3.7 Mac'teki küçük ama kullanışlı şeyler
| Özellik | Nasıl | Efor |
|---|---|---|
| Ekran paylaşımında gizle | `NSWindow.sharingType = .none` (popup ve önizleme pencereleri) + ayar anahtarı | K |
| Zamanlı duraklatma | Mevcut `ignoreEvents` anahtarına bitiş zamanı: 15 dk / 1 saat / yarına kadar; menü çubuğu simgesinde duraklatma işareti | K |
| Süreye göre saklama | Adet sınırına ek olarak "X günden eski öğeleri sil" (pinler muaf); süre kısaltılırken onay | K–O |
| Silmeyi geri al | Son silinen öğeyi kısa süre bellekte tut, ⌘Z ve "Geri al" çipi | K |
| Çoklu seçim | Maccy'deki kapalı kodu açıp toplu sil/pinle; çoklu silmede onay | O (önce neden kapatıldığı incelenmeli) |
| Satıra sağ tık menüsü | Kopyala, düz metin yapıştır, pinle, başlık ver, sil, bağlamda göster; her satırda kısayolu yazar | K–O |
| Yeni öğe | Kopyalamadan metin öğesi oluşturma (iOS'ta "+" , Mac'te kısayol) | K |
| Writing Tools | Mac/iOS düzenleme alanı sistem metin görünümüyse ücretsiz gelir; yalnızca açık olduğu doğrulanır | K |

---

## 4. Karşılaştırmada kendi kodumuzda bulduğum sorun: kimlikler şifreli değil

Paste şifreleme konusunda hiçbir iddiada bulunmuyor. Biz ise ayarlarda ve karşılama penceresinde
**"uçtan uca şifreli"** diyoruz. Metni `encryptedValues` ile şifreliyoruz, bu doğru. Ancak kaydın **adı**
(`recordName`) metnin **tuzsuz SHA-256 özeti** (`Clip.id(for:)` → `ClipRecord.recordID`). Kayıt adları şifrelenmez
ve sunucu tarafında görünür.

- **Sorun:** Kısa metinlerin özeti geri çözülebilir. 6 haneli bir kodun bir milyon olasılığı var; hepsinin
  SHA-256'sı bir saniyenin altında hesaplanır. Aynı şey kısa parolalar, telefon numaraları ve kart numaraları
  için de geçerli. Yani "uçtan uca şifreli" ifademiz kısa içerikler için tam doğru değil.
- **Çözüm önerisi:** Kimliği, kullanıcıya özel gizli bir anahtarla **HMAC-SHA256** olarak üretmek. Anahtar
  cihazlar arasında şu iki yoldan biriyle paylaşılır:
  1. Şifreli alanlı tek bir "ayar" kaydında (`encryptedValues`). Uçtan uca şifreli, ek izin gerekmiyor.
     Önerilen yol bu.
  2. iCloud Anahtar Zinciri'nde (`kSecAttrSynchronizable`). Klavye için anahtar zinciri erişim grubu gerekir.
  Aynı metin her cihazda yine aynı kimliğe gider, yani tekilleştirme bozulmaz.
- **Geçiş:** Eski kayıtlar yeni kimlikle yeniden yüklenir, eskiler silinir. Bloklayan bir geçiş ekranı
  olmadan, arka planda yapılır. (Paste 5'in "Migrating Data" felaketi tam olarak kaçınmamız gereken şey.)
- **Efor: O.** Koleksiyonlar da şema değiştireceği için ikisi aynı sürümde yapılmalı. O zamana kadar
  arayüzdeki ifadeyi "metin şifreli saklanır" diye yumuşatmak dürüst bir ara çözüm olur.

---

## 5. Bizim önde olduğumuz yerler (korunmalı ve anlatılmalı)

1. **Ücretsiz ve açık kaynak, Mac + iPhone birlikte.** Pazarda bu kombinasyonda başka ürün yok. Maccy ve ClipBook
   yalnız Mac'te çalışıyor; Paste ve PastePal ise ücretli ve kapalı kaynak.
2. **Sıfır telemetri.** App Store etiketi "Data Not Collected" olabilir. Paste'te analitik kapatılamıyor.
3. **Hassas içerik süzgeçleri** (kod, kart, IBAN; Luhn ve mod-97 doğrulamalı) Paste'te yok.
4. **Varsayılan yapay zekâ yok.** Paste'in varsayılan açık yapay zekâsına ciddi tepki var.
5. **Türkçe.** Paste'in 16 dili arasında Türkçe yok.
6. **Hafif klavye.** Paste klavyesi "intrusive" ve "laborious" bulunuyor. Bizimki bir seçici: tek dokunuşla
   yazıyor, renk ve uygulama bilgisi gösteriyor.
7. **Akıllı eylemler** (ara, e-posta yaz, bağlantıyı aç). Paste'te belgelenmemiş.
8. **Sağlam eşitleme testleri.** 26 uçtan uca kontrol var. Paste'in sürüm notları ise eşitleme düzeltmeleriyle dolu.

---

## 6. Beyin fırtınası: esinlenerek alabileceklerimiz

### 6.1 Mac
- **Koleksiyonlar:** Popup'ta üstte, cihaz çiplerinin yanında bir koleksiyon seçici. Her koleksiyonun bir rengi
  ve kendine ait bir harf kısayolu olur. Maccy'nin harfli pin kısayolu korunur. Bir koleksiyonu doğrudan açan
  global kısayol da eklenebilir; Paste kullanıcıları bunu istiyor ama Paste'te yok.
- **Filtre çipleri:** `app:Safari`, `tür:bağlantı`, `dün`, `iphone` yazınca filtre olarak tanınır ve çipe dönüşür.
  Çipler mevcut cihaz filtresi tasarımıyla (cam kapsül) aynı görünür.
- **Bağlamda göster:** Arama sonucunda ⌘G ile öğenin gün başlığı altındaki yerine gidilir.
- **Görselde metin (OCR):** Ekran görüntüsündeki metin aranabilir. Önizlemede "Metni Kopyala" düğmesi olur.
- **Space ile büyük önizleme:** Maccy'deki gecikmeli önizleme yerine (ya da ona ek olarak) Space ile anında aç/kapa.
- **Duraklatma ve gizleme:** Menü çubuğundan "15 dk duraklat" seçeneği ve "Ekran paylaşımında gizle" anahtarı.
- **Saklama süresi:** "30 günden eskileri sil (pinler hariç)".
- **Sıralı yapıştırma:** Maccy'de olup olmadığı doğrulanacak. Yoksa kendi adıyla eklenir ("Sıra" / *Queue*).
  Paste'teki ⇧⌘C'nin ⌘C'ye fazla yakın olması şikâyet konusu; biz farklı bir kısayol seçeriz.
- **Dışa/içe aktarma (JSON/düz metin):** Paste'te yok ve isteniyor. Açık kaynak ruhuna da uygun.

### 6.2 iPhone ve iPad
- **"Açılınca panoyu kaydet"** seçeneği ve "Allow" yönlendirmesi (§3.1).
- **Paylaş + Eylem uzantısı** (§3.2).
- **Etkileşimli widget:** Son 3–4 kopya listelenir ve her birinde **kopyala düğmesi** olur (`Button(intent:)`).
  Paste'in widget'ı yalnızca uygulamayı açıyor. Bir de "Mac'ten son kopya" küçük widget'ı ve kilit ekranı
  widget'ı. Doğrulanmalı: widget intent'inin `UIPasteboard`'a yazabildiği.
- **Denetim Merkezi kontrolü ve Action Button:** "Panoyu Pastronaut'a kaydet" (`ControlWidgetButton` +
  `openAppWhenRun`) ile uygulama bir anlığına açılıp kaydeder. Paste'te yok.
- **Kısayollar kataloğu:** "Son kopyayı al", "Mac'ten son kopyayı al", "n'inci öğeyi al", "Koleksiyona ekle"
  (`AppEntity` + `AppShortcutsProvider`). Kurulum rehberinde hazır bir Back Tap tarifi de verilebilir.
- **Filtre jetonları** (`.searchable(tokens:)`) ve uzun basma menüsünde "Bağlamda göster".
- **Seçim modu:** Düzenle → çoklu seçim → toplu sil (onaylı) ya da pinle.
- **"+" ile yeni öğe:** Mevcut `ClipEditor` yeniden kullanılır.
- **iPad:** Görünür olduğu sürece (yan yana / Stage Manager) otomatik yakalama (`UIPasteboard.changedNotification`),
  listeye ve listeden sürükle-bırak (`Transferable`), kenar çubuğu.
- **Klavye:** Sayı/sembol satırı (arama için), klavyeden sürükle-bırak, koleksiyon seçici. Hafiflik korunmalı:
  tam bir yazma klavyesi yapmak hedefimiz değil.

### 6.3 iOS 27'nin yerleşik "son kopyayı yapıştır" önerisi
iOS 27 klavyesi son kopyayı tek dokunuşla öneriyor. Bu, "Mac'ten son kopya" çipimizin değerini kısmen azaltıyor.
Bizim farkımız **geçmiş**, **pinler/koleksiyonlar** ve **Mac'te yapılan, Universal Clipboard'un erişemediği eski
kopyalar**. Tanıtımda ve kurulum rehberinde bu farkı anlatmalıyız.

### 6.4 Yapay zekâ: ne yapmalı?
- **Intelligent Clipboard:** Ekran Kaydı izni ve Apple Intelligence gerektiriyor; gizlilik konumumuzla çelişiyor.
  **Yapmayalım.**
- **MCP sunucusu (Mac):** Geçmişi Claude Code gibi araçlara açan **yerel**, varsayılan kapalı bir seçenek.
  Sizin iş akışınıza uygun olabilir. Yalnızca açıkça açılırsa çalışır, kod/kart süzgeçleri burada da uygulanır,
  ağ dinlemez (stdio). **"Sonra" listesine** koyalım.
- **Writing Tools:** Sistemden ücretsiz geliyor; yalnızca düzenleyicide açık olduğunu doğrularız.

---

## 7. UI/UX referansları (Paste'ten çıkarılan ilkeler, kendi tasarımımızla)

### 7.1 Mac
1. **Tanımak okumaktan hızlıdır:** Satırda türe özgü küçük önizleme var (renk örneği, görsel küçük resmi,
   bağlantıda alan adı) ve kaynak uygulama simgesi. Bizde çoğu var; görsel küçük resmi ve alan adı eklenebilir.
2. **Değiştirici tuşla ipucu:** ⌥ basılıyken satırlarda "düz metin" göstergesi, ⌘ basılıyken kısayol rozetleri
   görünür. Keşfedilebilirliği artırır.
3. **Tek kural, her yerde:** Düz metin değiştiricisi Return'de, ⌘1–9'da ve menüde aynı olsun ve menüde yazsın.
4. **Her klavye eyleminin sağ tık karşılığı** olsun; menüde kısayol da görünsün.
5. **Yıkıcı eylemlerde onay + geri al:** Çoklu silmede onay, tekil silmede ⌘Z.
6. **Yoğunluk:** Ayarlarda "Rahat / Sıkı" satır yüksekliği. Paste'teki gibi sürükleyerek boyut değiştirmek yerine
   Maccy'nin dikey yapısına uygun bir seçim.
7. **Karşılama:** Üç karar yeter: açma kısayolu, iCloud anahtarı, Erişilebilirlik izni (doğrudan yapıştırma için).
   İzin yoksa "panoya kopyala, sen yapıştır" moduna zarifçe geç (Maccy zaten böyle yapıyor; karşılamada anlatalım).

### 7.2 iOS
1. **Başparmak bölgesi:** iOS 26'da arama alt araç çubuğunda duruyor (sistem davranışı). Cihaz filtresi ve
   koleksiyon seçici de alta, arama jetonlarına taşınabilir.
2. **Net jest sözleşmesi** her yüzeyde aynı olmalı: dokun = kopyala/yaz, uzun bas = önizleme + menü,
   kaydır = sil/pinle. Uygulama, klavye ve widget aynı dili konuşmalı. Şu anki davranışımızı buna göre gözden
   geçirelim.
3. **Kısıtları saklamamak:** Kurulum rehberinde "iPhone arka planda panoyu okuyamaz; art arda kopyalarda
   sonuncusu kalır; şu üç yolu kullan" diye açıkça yazalım.
4. **İzni ürünleştirmek:** Ayarlarda "Diğer uygulamalardan yapıştırmaya izin ver" satırı iOS Ayarlar'a gider.
   Klavyede Tam Erişim yoksa boş liste yerine kısa bir kurulum kartı gösterilir (bizde zaten var).
5. **Klavye bellek bütçesi:** İlk çizim yerel önbellekten (bizde var), uzun listeler tembel yüklenir, görsel
   gelirse yalnızca küçük resim gösterilir.
6. **Kart cilası:** Kenar çizgisi yok, tutarlı köşe yarıçapları; eşitleme göstergesi seçim modunda gizlenir.
7. **Erişilebilirlik:** Paste VoiceOver konusunda eleştiriliyor. Tüm satırlarda anlamlı etiketler, Dynamic Type
   ve "renkten bağımsız" ipuçları denetlenmeli. Bu ucuz ama ayırt edici bir alan.

---

## 8. Bilerek yapmayacaklarımız

- Alttan açılan **yatay kart şeridi** ana görünüm olmayacak. Hem Paste'in ayırt edici görünüşü (trade dress) hem de
  ultra geniş ekranda şikâyet konusu. Maccy'nin dikey popup'ı bizim kimliğimiz.
- Kart başlığını kaynak uygulamanın rengine boyamak, Paste'in kart oranları, renk dili ve animasyonları.
- "Pinboard", "Paste Stack", "Limitless Clipboard" terimleri. Bizim terimlerimiz: **Koleksiyon**, **Sıra**,
  **Pin**.
- Telemetri, varsayılan açık yapay zekâ, abonelik ya da paywall.
- Bloklayan veri geçişi ekranı. Şema değişiklikleri arka planda ve geri alınabilir yapılmalı.
- App Store anahtar kelimelerinde "Paste" ya da "Maccy" gibi başka ürün adları.

---

## 9. Önceliklendirilmiş öneri (yayın öncesi geliştirme)

**Dalga 1: hızlı kazanımlar (birkaç oturum)**
1. Kimlik düzeltmesinin tasarımı (§4). Uygulanması Dalga 3'te, ama arayüz metni şimdi dürüstleştirilir.
2. Mac: ekran paylaşımında gizle, zamanlı duraklatma, süreye göre saklama, silmeyi geri al.
3. Mac: satır sağ tık menüsü ve "bağlamda göster".
4. iOS: "Açılınca panoyu kaydet" seçeneği ve "Allow" yönlendirmesi (uygulama + klavye).
5. iOS: "+" ile yeni öğe, seçim modu ve toplu silme.
6. Renk algılama: `#` olmadan, en az bir A–F harfi içeren 6 haneli hex'leri de renk say (rakamdan ibaret
   altı haneli değerler kod sayılmaya devam eder). Kural ortak bir fikir; kodu bizim.

**Dalga 2: 1.0 yüzeyleri (zaten kararlaştırılan kapsamla birleşiyor)**
1. Paylaş + Eylem uzantısı.
2. Etkileşimli widget'lar (kopyala düğmeli), kilit ekranı widget'ı.
3. Denetim Merkezi kontrolü ve Action Button.
4. Kısayollar kataloğu (okuma eylemleri).
5. Filtre jetonlu arama (iOS `.searchable(tokens:)`, Mac önek sözdizimi).
6. Face ID kilidi (zaten planlı).

**Dalga 3: büyük yapısal işler** (2026-10-17'de uygulandı; ayrıntı TASARIM §8 durum 4.7)
1. Koleksiyonlar + HMAC kimlik geçişi (tek şema değişikliği).
2. Mac önizlemesinde "Görseldeki metni kopyala" (OCR Maccy'de zaten var).
3. Spotlight (isteğe bağlı, yalnız pinler).
4. iPad: kenar çubuğu, görünürken yakalama, sürükle-bırak.
5. Dışa/içe aktarma.

**Sonra / belki:** görsel eşitleme (`CKAsset`), bağlantı önizlemesi (varsayılan kapalı), paylaşılan koleksiyonlar
(`CKShare`), yerel MCP sunucusu (varsayılan kapalı), klavyede sayı/sembol satırı ve sürükle-bırak.

---

## 10. Açık sorular (karar sizin)

1. Dalga sırası bu şekilde uygun mu, yoksa koleksiyonlar gibi büyük bir özellik öne mi alınsın?
2. "Koleksiyon" terimi uygun mu (EN: *Collection*)?
3. iOS'ta "Açılınca panoyu kaydet" varsayılan olarak **kapalı** mı gelsin (önerim), yoksa açık mı?
4. Görsel eşitleme 1.0'a girsin mi, yoksa "yalnız metin = güvenilir" mesajıyla 1.0 sonrasına mı kalsın (önerim)?
5. Yerel MCP sunucusu ilginizi çekiyor mu? (Varsayılan kapalı ve yalnızca yerel olur.)

---

## Ek: geliştirme sırasında görülenler (2026-10-17)

- **Maccy'den gelen bir pencere hatası:** Önizleme paneli solda açılırken (popup ekranın sağ kenarındayken) hemen
  arama yazılırsa pencere sağa kayıp ekrandan çıkabiliyor (`SlideoutController.togglePreview`, animasyon sürerken
  ikinci değişiklik). Bizim kodumuz değil; upstream'de aranıp gerekirse ayrı bir düzeltme olarak ele alınacak.
- **Popup'taki mavi leke:** Ekran görüntülerinde görülen mavi bulanıklık bir hata değil. Popup'ın camı yarı saydam
  olduğu için arkadaki pencerenin mavi düğmesi bulanık olarak görünüyor.
