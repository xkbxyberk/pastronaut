# Paste (iOS/iPadOS) — Rakip Araştırması

> Hazırlanma: 2026-10-17. Yöntem: yalnızca açık web kaynakları (resmi site, yardım merkezi, blog, App Store sayfası ve sürüm geçmişi, üçüncü taraf haberleri). Uygulama indirilmedi, tersine mühendislik yapılmadı.
> İşaretler: **[Doğrulandı]** resmi kaynakta açıkça yazıyor · **[Tahmin]** kaynaktaki ipucundan benim teknik çıkarımım · **[Doğrulanamadı]** kaynak bulunamadı ya da kaynaklar çelişiyor.

## 0. Kimlik ve genel durum

- **App Store adı:** "Paste – Limitless Clipboard", alt başlığı "Copy, Search, Manage, Share". Geliştirici: Paste Team ApS. Tek uygulama Mac, iPhone, iPad ve Vision Pro'yu kapsıyor (Universal Purchase). [Doğrulandı] — https://apps.apple.com/us/app/paste-limitless-clipboard/id967805235
- **Güncel sürüm:** 7.0.2 (9 Ekim 2026). En düşük sürümler iOS/iPadOS 26.0, macOS 14.0 ve visionOS 26.0. Boyut yaklaşık 165 MB. Puan 4.2 (yaklaşık 1,3 bin değerlendirme). "Editors' Choice" rozeti var. [Doğrulandı] — App Store
- **Fiyat:** İndirmesi ücretsiz, 7 günlük deneme sunuyor. Planlar: aylık 3,99 $, yıllık 29,99 $, aile 59,99 $, ömür boyu 99,99 $ ve "Legacy" 9,99 $. Tek abonelik Mac ve iOS'u birlikte kapsıyor. [Doğrulandı] — App Store
- **Gizlilik etiketi:** Kimliğe bağlı veri olarak yalnızca cihaz kimliği (uygulama işlevi için) toplanıyor. Kimliğe bağlı olmayan veriler satın alma, ürün etkileşimi ve çökme verisi (analitik için). Analitik PostHog'da (AB'de barındırılıyor), çökme raporları Sentry'de. [Doğrulandı] — App Store, https://pasteapp.io/privacy
- **Kısa tarihçe:** iOS uygulaması 2018'de çıktı. 2021'de Paste 3 widget, Spotlight ve uzantıları getirdi. Klavye 2022'de eklendi. 2023'te SwiftUI ile sıfırdan yeniden yazıldı. 2025'te Paste 5 (paylaşılan pinboard'lar ve yeni eşitleme motoru) ile Paste 6 (Liquid Glass) çıktı. 2026'da Paste 7 geldi. [Doğrulandı] — https://pasteapp.io/updates

---

## 1. Kopyaları iPhone'da yakalama

Paste kısıtı açıkça kabul ediyor: iOS arka planda pano okumaya izin vermediği için her kopyayı sessizce kaydedemiyor. Başka bir uygulamada art arda birkaç şey kopyalanırsa yalnızca sonuncusu kalıyor. [Doğrulandı] — https://pasteapp.io/help/what-paste-captures , https://pasteapp.io/help/clipboard-history-on-iphone

### 1.1 Uygulama açılınca otomatik kaydetme
- **Ne yapar:** Paste ya da Paste Klavyesi etkin hale geldiğinde panodaki içeriği geçmişe ekler. Ayarlarda "Automatically Collect Clipboard Content" seçeneğiyle kapatılabiliyor.
- **Nasıl:** Kullanıcı kopyalar, sonra Paste'i açar ve öğe kendiliğinden listeye düşer.
- **iOS kısıtını nasıl aşıyor:** Kısıtı aşmıyor; ön plana geçiş anını kullanıyor. Tahminim şu akış: sahne `active` olunca `UIPasteboard.changeCount` son okunan değerle karşılaştırılıyor, değiştiyse pano okunuyor. [Tahmin]
- **Pastronaut'ta:** **Yok.** Biz yalnızca `PasteButton` ile kullanıcının açıkça kaydetmesine dayanıyoruz.
- **Kaynak:** https://pasteapp.io/help/paste-on-iphone , https://pasteapp.io/help/what-paste-captures

### 1.2 "Paste from Other Apps" iznini "Allow" yaptırmak
- **Ne yapar:** iOS 16.1'den beri her uygulama için "Ask / Allow / Deny" ayarı var ve varsayılan "Ask". Paste kullanıcıyı bu ayarı **Allow** yapmaya yönlendiriyor. Bunun için Paste Ayarları'nda "Allow Paste from Other Apps" adlı bir satır var ve iOS Ayarlar'a götüren yönergeler gösteriyor. Ayar Allow olunca **hem uygulama hem klavye** her seferinde sormadan okuyabiliyor.
- **Nasıl:** Ayarlar → Uygulamalar → Paste → Paste from Other Apps → Allow.
- **iOS kısıtını nasıl aşıyor:** Kısıtı kaldırmıyor, yalnızca açılıştaki "Allow Paste" uyarısını ortadan kaldırıyor. Paste'in blogu, sistemin kendi yapıştır denetimlerinin (düzenleme menüsündeki Yapıştır, iPad'de ⌘V ve iOS'un uygulamalara verdiği yapıştır düğmesi) uyarı çıkarmadığını, uygulamanın kendi çizdiği düğmenin ise çıkarabildiğini anlatıyor. Ayar düğmesi büyük olasılıkla `UIApplication.openSettingsURLString` ile açılıyor. [Tahmin]
- **Pastronaut'ta:** **Kısmen.** `PasteButton` uyarısız çalışıyor ama "Allow" yönlendirmesi ve buna bağlı otomatik kayıt yok.
- **Kaynak:** https://pasteapp.io/help/allow-paste-permissions-in-ios , https://pasteapp.io/blog/allow-paste-iphone

### 1.3 Paylaş uzantısı ("Paste") ve Eylem uzantısı ("Copy to Clipboard History")
- **Ne yapar:** İki ayrı uzantı var.
  - **Paste Paylaş uzantısı:** İçeriği geçmişe ya da seçilen bir pinboard'a gönderir.
  - **"Copy to Clipboard History" eylemi:** Tek dokunuşla geçmişe ekler.
- **Nasıl:** Safari'de Paylaş → Diğer → Düzenle yolundan Paste açılıyor. Eylem uzantısı "Edit Actions…" listesinden Favoriler'e ekleniyor.
- **iOS kısıtını nasıl aşıyor:** Kullanıcı içeriği paylaşım sayfasıyla kendisi teslim ettiği için pano izni hiç gerekmiyor. Paste 3 duyurusu, uzantıların veriyi "Paste arka plandayken bile" bütün cihazlara ulaştırdığını söylüyor. Bundan uzantının doğrudan iCloud'a yazdığı ya da App Group'taki ortak veritabanına yazıp eşitlemeyi tetiklediği sonucunu çıkarıyorum. [Tahmin] Uzantı tanımlayıcıları büyük olasılıkla `com.apple.share-services` (Paylaş) ve `com.apple.ui-services` (Eylem). [Tahmin]
- **Bilinen sorun:** Geri bildirim panosunda, iOS 26.2 ve Paste 6.3.2'de Paylaş uzantısının seçilen pinboard'a hiçbir şey kaydetmediğini bildiren bir kullanıcı gönderisi var. Sayfa 403 döndürdüğü için içeriği okunamadı, bilgi yalnızca arama özetinden geliyor. [Doğrulanamadı] — https://pasteapp.nolt.io/574
- **Pastronaut'ta:** **Yok.**
- **Kaynak:** https://pasteapp.io/help/how-to-enable-paste-extensions , https://pasteapp.io/blog/paste-3-for-iphone-and-ipad

### 1.4 Klavye üzerinden yakalama
- **Ne yapar:** Yardım metinleri, kopyanın "Paste Klavyesi kullanılarak" da yakalandığını söylüyor. Klavye etkin hale gelince panodakini geçmişe ekliyor.
- **iOS kısıtını nasıl aşıyor:** Tam Erişim'li bir klavye uzantısı `UIPasteboard.general`'ı okuyabiliyor. "Allow" ayarı klavyeyi de kapsıyor, yani klavye her açılışta uyarısız okuyup kaydedebiliyor. Sonuç olarak kullanıcının bir sonraki yazma anı fiilen bir yakalama noktasına dönüşüyor. [Doğrulandı + Tahmin]
- **Pastronaut'ta:** **Kısmen** (doğrulanmalı). Klavyemiz Tam Erişim'le CloudKit'e yazıyor; açılışta panoyu otomatik kaydedip kaydetmediğini kodda kontrol edin.
- **Kaynak:** https://pasteapp.io/help/allow-paste-permissions-in-ios , https://pasteapp.io/blog/iphone-clipboard-history

### 1.5 Widget ile yakalama
- Widget yalnızca listeleri açmaya yarıyor; yakalama yapmıyor. Ayrıntılar §3'te.

### 1.6 Kısayollar, Back Tap ve Action Button
- **Ne yapar:** Paste'in Kısayollar eylemleri var (§3.3). "Add Text/Link to Pinboard" eylemi girdi alıyor; bu sayede "Panoyu Al → Paste'e ekle" gibi bir kısayol kurulabilir. Yine de Paste'in Back Tap ya da Action Button için hazır bir tarif yayımladığına dair kaynak bulamadım.
- **Pastronaut'ta:** **Var.** "Save to Pastronaut" eylemimiz bu işi açıkça yapıyor; bu konuda Paste'ten daha belirgin bir çözüm sunuyoruz.
- **Kaynak:** https://pasteapp.io/blog/hey-siri. Back Tap ve Action Button için kaynak yok. [Doğrulanamadı]

### 1.7 Dynamic Island, Live Activity ve Denetim Merkezi
- Hiçbir resmi kaynakta geçmiyor. [Doğrulanamadı; büyük olasılıkla yok]

### 1.8 Universal Clipboard'dan otomatik alma
- **Ne yapar:** Paste iPhone'da Universal Clipboard'u ayrıca dinlemiyor. Mac'te kopyalananlar, **Mac uygulaması onları yakalayıp iCloud'a yazdığı için** iPhone geçmişinde beliriyor. Paste kendi blogunda Universal Clipboard'u "tek öğelik, kısa ömürlü" diye tarif edip kendini onun tamamlayıcısı olarak konumluyor.
- **Pastronaut'ta:** **Var.** Mimari aynı: Mac'ten iCloud ile geliyor.
- **Kaynak:** https://pasteapp.io/blog/copy-and-paste-across-apple-devices

### 1.9 iPad: görünürken otomatik yakalama
- **Ne yapar:** iPad'de Paste ekranda **görünür** olduğu sürece (yan yana, Stage Manager ya da Slide Over'da) her kopyayı Mac'teki gibi kendiliğinden yakalıyor.
- **iOS kısıtını nasıl aşıyor:** Çok pencereli düzende uygulama arka planda sayılmıyor, ön planda ve etkin kalıyor. Bu yüzden `UIPasteboard.changedNotification` dinlenebiliyor ya da `changeCount` periyodik olarak yoklanabiliyor; "Allow" ayarıyla birlikte uyarı da çıkmıyor. [Tahmin]
- **Pastronaut'ta:** **Yok.**
- **Kaynak:** https://pasteapp.io/help/paste-on-ipad , https://pasteapp.io/help/what-paste-captures

### 1.10 Diğer giriş yolları
- **"+" düğmesi:** Elle yeni metin ya da bağlantı öğesi oluşturuyor (Paste 6 ile geldi). [Doğrulandı] — https://pasteapp.io/blog/paste-in-liquid-glass
- **iPhone ile belge tarama:** Taranan belge doğrudan Paste'e giriyor (2024). VisionKit'teki `VNDocumentCameraViewController` kullanılıyor olabilir. [Doğrulandı / Tahmin] — https://pasteapp.io/updates
- **Pastronaut'ta:** **Yok.**

---

## 2. Özel klavye (Paste Keyboard)

- **Ne yapar:** Klavyeden geçmişte ve pinboard'larda gezilip öğe doğrudan yazılan alana yapıştırılıyor. Klavyeden başka uygulamalara **sürükle-bırak** yapılabiliyor. Bir öğeye uzun basınca açılan bağlam menüsünde "düz metin olarak kopyala" gibi eylemler var. iPad'de hem yatay hem dikey düzen destekleniyor.
- **Son değişiklikler (sürüm notları):**
  - 6.5.0 (Nisan 2026): Klavye yeni görünüm, düzen ve dokunsal geri bildirimle baştan tasarlandı.
  - 6.6.4 (Ağustos 2026): **Yazma modları** eklendi (harf, sayı, sembol). Klavyeden çıkmadan **son kopyaları gösteren bir şerit** geldi. Görseller dahil öğeler daha az bellekle yükleniyor, böylece iOS klavyeyi daha seyrek sonlandırıyor. Araç çubuğu simgeleri büyütüldü.
  - 6.6.2: Klavye ve widget daha hızlı açılıyor.
  - 7.0.2: Klavye daha hızlı ve tepkili.
  - [Doğrulandı] Not: App Store sürüm notlarının hangi sürüm numarasına ait olduğu sayfada belirsiz; ±1 sürüm kayabilir.
- **Tam Erişim:** Zorunlu. Tam Erişim yoksa klavye öğe yerine kendi kurulum yönergelerini gösteriyor. Paste'in gerekçesi, Tam Erişim'in "diğer uygulamalarla iletişim ve eşitleme" için gerektiği. Kurulum uygulama içinden yapılıyor: Ayarlar → Klavye → "Enable Paste Keyboard" ve yönlendirmeli adımlar. [Doğrulandı]
- **Nasıl açılıyor:** Küre simgesine uzun basıp Paste seçiliyor. Yardım metni, tek dokunuşun yalnızca sıradaki klavyeye geçtiği uyarısını özellikle yapıyor. [Doğrulandı]
- **Arama ve pinboard seçimi:** Pinboard'lara klavyeden erişilebildiği yazıyor. Klavye içi arama olup olmadığı ve pinboard seçicisinin nasıl göründüğü resmi metinlerde anlatılmıyor. [Doğrulanamadı]
- **Veri katmanı:** 6.6.4 notunda "klavye ve widget **ortak veritabanı** güncellenirken artık çökmüyor, bunun yerine Paste'i açma istemi gösteriyor" diyor. Buradan klavye ve widget'ın App Group'taki **yerel ortak veritabanını** okuduğu, CloudKit'e doğrudan bağlanmadığı sonucunu çıkarıyorum. Bizim mimarimizden farklı. [Tahmin, güçlü ipucu]
- **iOS kısıtını nasıl aşıyor:** Klavye, kullanıcının her yazma anında açılan, böylece "ön planda kod çalıştırma" fırsatı veren bir uzantı. Yazma modları da kullanıcının sistem klavyesine geri dönme ihtiyacını azaltıyor.
- **Pastronaut'ta:** **Var**, bazı farklarla. Geçmiş, Mac'ten son kopya, sekmeler, kendi harf düzenimizle arama ve uzun basma paneli bizde var. Paste'te olup bizde olmayanlar: klavyeden sürükle-bırak, pinboard'lar ve sayı/sembol modlu tam yazma deneyimi (bizim harf düzenimiz yalnızca arama için).
- **Kaynak:** https://pasteapp.io/help/enable-and-use-paste-keyboard , https://pasteapp.io/blog/introducing-paste-keyboar , App Store sürüm geçmişi

### 2.1 Bağlam: iOS 27'nin yerleşik yapıştır önerisi
- iOS 27'de sistem klavyesi, kopyalamadan hemen sonra QuickType çubuğunda **son kopyayı** tek dokunuşla yapıştırma önerisi gösteriyor. Bu öneri tek öğe tutuyor ve geçmiş sunmuyor. Paste blogu buna "son kopya için yerel düğme, geri kalan her şey için Paste" diye konum alıyor. Bu, bizim "Mac'ten son kopya" özelliğimizin değerini kısmen azaltıyor. [Doğrulandı] — https://pasteapp.io/blog/ios-27-keyboard-paste-button

---

## 3. Widget, Denetim Merkezi, Siri/App Intents ve Spotlight

### 3.1 Ana ekran widget'ı
- **Ne yapar:** Küçük ve orta boyları var. Widget düzenlenerek hangi listelerin (Clipboard History ya da herhangi bir pinboard) görüneceği seçiliyor. Bir listeye dokununca o liste Paste'te açılıyor. 2021'deki ilk sürümde "4 kısayola kadar pinboard veya arama" atanabiliyordu.
- **Nasıl:** Yapılandırılabilir bir widget. Büyük olasılıkla `AppIntentConfiguration` (eskiden `IntentConfiguration`) ile listeler seçtiriliyor ve dokununca deep link açılıyor. [Tahmin]
- **Etkileşimli widget ve kilit ekranı widget'ı:** Kaynaklarda geçmiyor. Anlatılana göre widget yalnızca uygulamayı açan bir başlatıcı. [Doğrulanamadı]
- **Pastronaut'ta:** **Yok.**
- **Kaynak:** https://pasteapp.io/help/paste-on-iphone , https://pasteapp.io/blog/paste-3-for-iphone-and-ipad , 6.6.2 ve 6.6.4 sürüm notları

### 3.2 Denetim Merkezi kontrolleri (iOS 18+)
- Hiçbir kaynakta yok. [Doğrulanamadı; büyük olasılıkla yok]

### 3.3 Siri ve Kısayollar
- **Ne yapar:** 2020'den beri üç eylem var: "Add Text/Link to Pinboard", "Get recent Text/Link from Pinboard" ve "Get an item at Index from Pinboard". Hepsi girdi ve çıktı alıyor. Paste Ayarları → Siri & Shortcuts bölümünden kişisel Siri ifadeleri atanabiliyor (örnek: "Notes pinboard'una yeni öğe ekle" dendiğinde Siri ne ekleneceğini soruyor). 2021'de eylemler tüm platformlara yayıldı. 6.3.3 notunda bir Siri Kısayolu düzeltmesi var, yani eylemler hâlâ yaşıyor.
- **Nasıl:** Başlangıçta SiriKit Intents tanımları kullanılıyordu. Bugün App Intents'e geçip geçmedikleri belli değil. [Tahmin]
- **Pastronaut'ta:** **Kısmen.** Bizde yalnızca "Save to Pastronaut" var; "son öğeyi al" ya da "n'inci öğeyi al" gibi okuma eylemleri yok.
- **Kaynak:** https://pasteapp.io/blog/hey-siri , https://pasteapp.io/updates

### 3.4 Spotlight
- **Ne yapar:** Geçmişteki ve pinboard'lardaki öğeler iOS Spotlight'ta aranabiliyor (2021'den beri "Universal Search"). 6.6.0 notundaki "Spotlight yeniden indekslenirken çökme düzeltildi" ifadesi özelliğin hâlâ etkin olduğunu doğruluyor.
- **Nasıl:** Core Spotlight (`CSSearchableIndex`) kullanılıyor. [Tahmin, güçlü]
- **Pastronaut'ta:** **Yok.**
- **Kaynak:** https://pasteapp.io/blog/paste-3-for-iphone-and-ipad , https://pasteapp.io/help/paste-on-ipad , App Store 6.6.0

---

## 4. iOS'ta pinboard'lar

- **Ne yapar:** Geçmişten bağımsız, kalıcı koleksiyonlar. Her öğe yalnızca bir pinboard'da duruyor ve başka bir pinboard'a taşınabiliyor. Bir öğeyi pinlemek onu geçmişten silmiyor.
- **Nasıl (iPhone):** Alt araç çubuğundaki **geçerli liste adına** dokununca tüm pinboard'ların listelendiği bir sayfa açılıyor. Oluşturma, düzenleme ve silme bu sayfadan, "+" düğmesiyle yapılıyor. Pinboard'un adı ve **rengi** var. Silme işlemi pinboard'un içindekileri de siliyor. 7.0.0'da bu sayfa yenilendi: başlık önceden seçili geliyor ki doğrudan üzerine yazılsın, klavyedeki Done tuşu kaydediyor, renk seçici sayfanın içinde çalışıyor. Paylaş uzantısıyla doğrudan bir pinboard'a gönderme de mümkün.
- **Sürükle-bırak:** Pinboard'lar ve öğeler sürüklenerek yeniden sıralanabiliyor. Ancak yardım metni platform belirtmiyor, bu yüzden iPhone'da da çalıştığı kesin değil. iPad'de koleksiyon görünümünden sürükle-bırak var (6.3.2'de düzeltildi). [Kısmen doğrulandı]
- **Paylaşma (Paste 5, Mayıs 2025):** Pinboard'a uzun basıp "Share Pinboard" seçiliyor, izinler belirlenip davet Mesajlar, Mail ya da bağlantı kopyalayarak gönderiliyor. İki seçenek var: yalnızca davet edilenler ya da bağlantısı olan herkes; ayrıca salt okunur ya da düzenleyebilir izni. Katılımcıların Paste'i kurmuş ve iCloud'a girmiş olması gerekiyor. Paylaşım durdurulursa pinboard herkesin cihazından siliniyor.
- **iOS kısıtını nasıl aşıyor:** "Apple'ın iCloud paylaşımı" kullanılıyor; bu neredeyse kesin olarak `CKShare` ile zone ya da kayıt paylaşımı demek. [Tahmin, güçlü]
- **Filtre:** 6.4.0 ile arama pinboard'a göre süzülebiliyor.
- **Pastronaut'ta:** **Yok.**
- **Kaynak:** https://pasteapp.io/help/organize-with-pinboards , https://pasteapp.io/help/shared-pinboards , App Store 7.0.0, 6.4.0 ve 6.3.2

---

## 5. Zengin içerik

- **Türler:** Metin, bağlantı, görsel, dosya ve renk. Hepsi eşitleniyor. [Doğrulandı]
- **Renk algılama kuralı:** Tek başına kopyalanmış bir hex kod, başında `#` varsa ya da en az bir A–F harfi içeriyorsa renk öğesi oluyor. `235442` gibi altı rakamlı bir değer metin olarak kalıyor ki doğrulama kodları renk örneğine dönüşmesin. `#FFF`, `rgb()` ve renk adları da metin sayılıyor. [Doğrulandı] — https://pasteapp.io/help/what-paste-captures
- **Bağlantı önizlemeleri:** 2020'den beri küçük resim ve Quick Look önizlemesi var. Bağlantı yerleşik tarayıcıda düzenlenebiliyor. Muhtemelen `LinkPresentation` ve `LPMetadataProvider` kullanılıyor. [Doğrulandı / Tahmin]
- **Görseller:** Görselin içindeki metin aranabiliyor (OCR) ve önizlemede metin çıkarılabiliyor. Görsel döndürülebiliyor. Muhtemelen Vision'daki `VNRecognizeTextRequest` kullanılıyor. [Doğrulandı / Tahmin]
- **Önizleme ve düzenleme:** Uzun basınca öğenin kendi metni önizlemede görünüyor (6.6.9). Öğeye başlık verilebiliyor (yeniden adlandırma), içerik düzenlenebiliyor. Düzenleme sırasında Apple Intelligence Writing Tools (yeniden yaz, düzelt, ton değiştir) kullanılabiliyor; blog bunun iPhone ve iPad'de de olduğunu söylüyor.
- **Hassas içerik:** Parola yöneticilerinin "gizli" ya da "geçici" olarak işaretlediği içerik atlanıyor. Bu, `org.nspasteboard.ConcealedType` ve `TransientType` işaretlerine dayanıyor. Bu işaretler Mac için kesin; iOS'ta nasıl uygulandığı belli değil. [Tahmin]
- **Pastronaut'ta:** **Kısmen.** Yalnızca metin var. Bağlantı, e-posta ve telefon için akıllı eylemlerimiz var ama görsel, dosya, renk, bağlantı önizlemesi ve OCR yok.
- **Kaynak:** https://pasteapp.io/updates , https://pasteapp.io/blog/apple-intelligence-in-paste , https://pasteapp.io/help/edit-items-before-pasting

---

## 6. Arama, filtre ve kaynak uygulama

- **Ne yapar:** Alt araç çubuğundaki arama simgesine dokununca arama alanı klavyenin hemen üstünde açılıyor ve sonuçlar yazdıkça güncelleniyor. Başlık, içerik, meta veri ve görsel içi metin aranıyor; yazım hatalarına toleranslı. Filtreler: içerik türü, **kaynak uygulama**, tarih, **cihaz** ve pinboard. Yazarken uygun filtreler satır içinde öneriliyor ve etkin filtreler arama alanında **jeton (token)** olarak duruyor. "Jump to History" (Nisan 2026) ile bir sonuca uzun basıp "Show in → Clipboard/pinboard adı" seçilince öğenin geçmişteki yerine gidiliyor.
- **Kaynak uygulama iOS'ta nasıl gösteriliyor:** iPad yardım sayfası öğe küçük resminde "tür, kopyalama zamanı ve kaynak uygulama" gösterildiğini söylüyor. Ancak iOS'ta yakalanan öğelerin kaynak uygulamasının nasıl belirlendiği **hiçbir yerde anlatılmıyor.** `UIPasteboard`'da kaynak uygulamayı veren herkese açık bir API yok. Benim tahminim: kaynak uygulama yalnızca Mac'te yakalanıp eşitlenen öğelerde dolu geliyor, iOS'ta yakalananlar ise yalnızca **cihaz** bilgisiyle (iPhone/iPad) etiketleniyor. Bu yüzden "cihaz" filtresi ayrı bir filtre olarak var. [Doğrulanamadı / Tahmin]
- **Pastronaut'ta:** **Kısmen.** Tümü/Mac/iPhone filtremiz Paste'in cihaz filtresine denk geliyor. Tür, tarih ve uygulama filtresi, jeton arayüzü, OCR ve Jump to History bizde yok.
- **Kaynak:** https://pasteapp.io/help/search-and-filters , https://pasteapp.io/blog/paste-power-search , https://pasteapp.io/blog/jump-to-history , https://pasteapp.io/help/paste-on-ipad

---

## 7. Eşitleme mimarisi

- **Altyapı:** Kullanıcının **özel iCloud hesabı.** "Sunucularımıza hiç dokunmaz" deniyor. CloudKit adı resmi metinlerde açıkça geçmiyor. Ancak iCloud ayarlarında "Saved to iCloud → Paste" diye bir satır olması ve "iCloud verisini sil" yolunun gösterilmesi bir CloudKit kapsayıcısına işaret ediyor. [Doğrulandı: iCloud. Tahmin: CloudKit özel veritabanı]
- **Varsayılan durum:** Eşitleme **her cihazda ayrı ayrı açılıyor ve varsayılan olarak kapalı.** Ayar Paste Ayarları → General → iCloud sync altında. Elle eşitleme düğmesi yok. [Doğrulandı]
- **Eşitleme motoru:** Paste 5 (Mayıs 2025) ile "tamamen yeniden yazıldı". Teknik ayrıntı verilmiyor; CKSyncEngine kullanılıyor olabilir ama bu doğrulanamadı. İlk büyük eşitleme "birkaç dakika" sürebiliyor ve bu sırada uygulamanın açık tutulması öneriliyor. Sonrasında öğeler tek tek ve hızlı eşitleniyor. Gerçek zamanlılık için somut bir süre verilmiyor. Macworld 2022'de Mac'teki kopyanın "neredeyse ⌘C'ye basar basmaz" diğer cihazlarda göründüğünü yazmıştı. [Doğrulandı / Tahmin]
- **Sürüm notlarındaki sorunlar:** "senkron çakışmaları", "silinen öğeler silinmiş kalsın", "çift kayıt" ve "geçici eşitleme dosyalarının diski doldurması" gibi düzeltmeler 2026'da sık geçiyor. Eşitleme hâlâ en sorunlu alanlardan biri gibi görünüyor. [Doğrulandı]
- **Uçtan uca şifreleme:** **İddia yok.** Gizlilik politikası yalnızca "uygun teknik ve organizasyonel önlemler"den söz ediyor. Advanced Data Protection konusu hiç geçmiyor. [Doğrulandı: iddia yok]
- **Kota:** Ne kotadan ne öğe veya boyut sınırından söz ediliyor. Veri kullanıcının iCloud alanından düşüyor olmalı. [Doğrulanamadı]
- **Geçmiş saklama süresi:** Mac'te 1 gün, 1 hafta, 1 ay (varsayılan), 1 yıl ya da sonsuz seçilebiliyor. **iPhone ve iPad'de bu ayar yok.** Orada yalnızca liste adına dokunup ⋯ → Erase ile geçmiş silinebiliyor; pinboard'lar korunuyor. [Doğrulandı]
- **Uyarı:** Eşitlemeyi kapatmak, sahibi olunan paylaşılan pinboard'ları tüm katılımcılardan siliyor. [Doğrulandı]
- **Pastronaut'ta:** **Var**, ama yalnızca metin. Biz CKSyncEngine kullanıyoruz; klavye de doğrudan CloudKit'ten okuyup yazıyor. Paste'te klavye büyük olasılıkla yerel ortak veritabanını okuyor (§2).
- **Kaynak:** https://pasteapp.io/help/icloud-sync-doesn-t-work , https://pasteapp.io/help/where-paste-stores-your-data , https://pasteapp.io/privacy , https://pasteapp.io/help/control-history-retention , https://alternativeto.net/news/2025/5/clipboard-manager-paste-5-0-adds-shared-pinboards-rebuilt-sync-engine-and-performance-gains

---

## 8. iPad'e özgü özellikler

- **Kenar çubuğu:** Clipboard History ve pinboard'lar arasında seçim yapılıyor. Paste 6'dan beri gezinme çubuğu üstte duruyor ve içerik alanı geniş.
- **Stage Manager, Slide Over ve yan yana düzen:** Paste kendi yeniden boyutlandırılabilir penceresinde çalışıyor ve görünür olduğu sürece panoyu kendiliğinden yakalıyor (§1.9). Çoklu pencere desteği var.
- **Sürükle-bırak:** Paste'e ve Paste'ten diğer uygulamalara sürükle-bırak yapılabiliyor. Öğeyi sağa kaydırmak kopyalıyor. Uzun basınca açılan menüde düz metin kopyalama ve tam ekran önizleme var.
- **Klavye:** iPad için yatay ve dikey düzende optimize edilmiş.
- **Klavye kısayolları:** iPad'e özgü kısayollar belgelenmemiş. [Doğrulanamadı]
- **Pastronaut'ta:** **Yok.** iPad'e özel bir düzenimiz, sürükle-bırakımız ya da görünürken yakalamamız yok.
- **Kaynak:** https://pasteapp.io/help/paste-on-ipad , https://pasteapp.io/blog/paste-in-liquid-glass

---

## 9. UI/UX

- **iPhone ana ekranı (Paste 6–7):** Gezinme ve arama, başparmağın erişebilmesi için **alttaki araç çubuğunda** toplanmış. Araç çubuğunda arama simgesi, geçerli liste adı (dokununca pinboard sayfası açılıyor), "+" ve Edit düğmeleri var. Geçmiş en yenisi üstte olacak şekilde kronolojik ve tek sütunlu bir zaman akışı. 2023'teki yeniden yazımda Mac'in kompakt moduna benzer bir sütun görünümü seçilmişti. [Doğrulandı]
- **Kartlar:** Liquid Glass derinliği ve yuvarlatılmış köşeler kullanılıyor. 6.6.9'da ince kenar çizgisi kaldırıldı ve görsel önizlemeler yeniden yuvarlatıldı. Kartta tür, zaman ve (varsa) kaynak uygulama görünüyor. Bir eşitleme göstergesi var ve seçim modunda gizleniyor. [Doğrulandı]
- **Jestler:**
  - Dokunmak sistem panosuna kopyalıyor.
  - Uzun basmak bağlam menüsü ve önizlemeyi açıyor: önizleme, düzenleme, düz metin kopyalama, pinleme, "Show in" ve paylaşma.
  - iPad'de sağa kaydırmak kopyalıyor.
  - Edit düğmesiyle çoklu seçim yapılıyor; birden fazla öğe silinirken onay soruluyor (6.3.8).
  - [Doğrulandı]
- **Liquid Glass ve iOS 26:** Paste 6 (Eylül 2025) ile tüm arayüz Liquid Glass'a geçti, ayarlar ekranı ve küçük düğmeler iOS 26'ya uyumlu hale geldi. Paste 7 (Eylül 2026) bütün gezinme, sayfa (sheet) ve tam ekran görünümleri SwiftUI üzerine yeniden kurdu. iOS 26 artık en düşük gereksinim. [Doğrulandı]
- **İlk açılış rehberi ve boş durumlar:** Bir onboarding var; 6.6.10'da "iPhone ekranını dolduracak" şekilde düzeltildi. Deneme sürümü tek dokunuşla başlıyor ve bildirim izni sormuyor. "What's New" ekranı iPhone, iPad ve Mac'te aynı görünüyor. Klavyenin boş durumu (Tam Erişim yokken) kurulum yönergelerinden oluşuyor. Ana listenin boş durumunun neye benzediği doğrulanamadı. [Kısmen doğrulandı]
- **Erişilebilirlik:** VoiceOver, büyük metin, koyu arayüz ve "rengi ayırt etmeden" seçenekleri destekleniyor. [Doğrulandı — App Store]
- **Pastronaut'ta:** **Kısmen.** Kart satırlarımız, gruplu geçmişimiz, ayrıntı ekranımız ve kurulum rehberimiz var. Alt araç çubuğu, liste değiştirici, çoklu seçim, kaydırma jestleri ve "+" ile elle öğe ekleme yok.
- **Kaynak:** https://pasteapp.io/blog/paste-in-liquid-glass , https://pasteapp.io/blog/the-all-new-paste-for-ios , https://pasteapp.io/help/paste-on-iphone , App Store sürüm notları

---

## 10. Son büyük özellikler (2024–2026)

| Tarih | Sürüm/özellik | iOS'a etkisi |
|---|---|---|
| Tem 2024 | Zengin önizleme ve düzenleme, görselden metin çıkarma, renk seçici, iPhone ile belge tarama | Var |
| May 2025 | **Paste 5:** paylaşılan pinboard'lar ve yeniden yazılmış eşitleme motoru | Var |
| Eyl 2025 | **Paste 6:** Liquid Glass, iPhone'da alt gezinme, "+" ve Edit, iPad'de üst gezinme ve çoklu pencere | Var |
| Kas 2025 | Paste'te Apple Intelligence Writing Tools | iPhone ve iPad dahil (blog öyle diyor) |
| Ara 2025 | **Power Search:** tür, uygulama, cihaz ve tarih filtreleri, OCR, satır içi filtre önerileri | Var |
| Mar 2026 | Pinboard'a göre filtreleme (6.4.0) | Var |
| Nis 2026 | **Jump to History** ve **yeniden tasarlanan klavye** (6.5.0) | Var |
| Haz 2026 | **Paste MCP:** yerel sunucuyla Claude, Codex ve Cursor'a pano geçmişi verme | Yalnızca Mac |
| Ağu 2026 | Klavyede yazma modları ve son kopya şeridi, büyük geçmişte performans (6.6.4–6.6.6) | Var |
| Eyl 2026 | **Paste 7:** SwiftUI ile yeniden yazım, pinboard sayfası, iOS 26 asgari | Var |
| Eyl 2026 | **Intelligent Clipboard:** ekrana bakıp sıradaki yapıştırılacak öğeyi önerme | Yalnızca Mac (macOS 26 ve Apple Intelligence) |
| Eki 2026 | 7.0.1–7.0.2: iOS 27 düzen düzeltmeleri, daha hızlı klavye | Var |

Kaynaklar: https://pasteapp.io/updates , https://pasteapp.io/blog , App Store sürüm geçmişi.

---

## Özet tablo: Pastronaut karşılaştırması

| Özellik | Paste | Pastronaut |
|---|---|---|
| Açılışta otomatik yakalama ve "Allow" yönlendirmesi | Var | Yok |
| Sistem `PasteButton` ile kayıt | Belirsiz | Var |
| Paylaş ve Eylem uzantıları | Var | Yok |
| Klavye (geçmiş, yapıştırma) | Var | Var |
| Klavyede tam yazma modları | Var | Kısmen (yalnızca arama için harf düzeni) |
| Klavyeden sürükle-bırak | Var | Yok |
| Widget | Var (başlatıcı) | Yok |
| Kısayollar ile kaydetme | Var (pinboard'a ekle) | Var |
| Kısayollar ile okuma | Var | Yok |
| Spotlight | Var | Yok |
| Pinboard'lar ve CKShare ile paylaşma | Var | Yok |
| Görsel, dosya ve renk eşitleme | Var | Yok |
| OCR ve gelişmiş filtreler | Var | Yok (yalnızca cihaz filtresi) |
| iPad'de görünürken yakalama ve sürükle-bırak | Var | Yok |
| Akıllı eylemler (ara, e-posta, bağlantı) | Belgelenmemiş | Var |
| Denetim Merkezi, Live Activity, Action Button | Bulunamadı | Yok |

---

## iOS'ta bizim yapamadığımız ama yapılabilir görünen 10 şey (hangi Apple API ile)

1. **Ön plana gelişte otomatik kayıt:** SwiftUI `scenePhase == .active` (ya da `UIApplication.didBecomeActiveNotification`) anında `UIPasteboard.general.changeCount` son değerle karşılaştırılır, değiştiyse okunur. Kullanıcıyı `UIApplication.openSettingsURLString` ile "Paste from Other Apps → Allow" ayarına yönlendiren isteğe bağlı bir ayar eklenebilir. Okumadan önce `UIPasteboard.detectPatterns(for:)` ya da `hasStrings` ile içerik **türü** uyarı çıkarmadan kontrol edilebilir.
2. **Klavye açılışında yakalama:** Klavye uzantısının `viewWillAppear` anında aynı `changeCount` karşılaştırmasıyla otomatik kayıt yapılır. Bunun için Tam Erişim ve "Allow" ayarı gerekir. Bizde zaten CloudKit yazımı olduğu için ek maliyet düşük.
3. **Paylaş uzantısı:** `NSExtensionPointIdentifier = com.apple.share-services` ile `NSItemProvider`'dan metin ve URL alınır, App Group ya da CloudKit'e yazılır. Bu, art arda yapılan kopyaları kaybetmemenin tek güvenilir yolu.
4. **Tek dokunuşluk Eylem uzantısı ("Pastronaut'a Kaydet"):** `com.apple.ui-services` kullanılır. Arayüzü olmayan bir eylemle anında kaydedip kapanır.
5. **Widget (WidgetKit):** Son N metni gösterir. iOS 17'nin **etkileşimli widget'larıyla** `Button(intent:)` üzerinden "kopyala" sağlanabilir. Bu Paste'te de yok, bizim için fark yaratacak bir fırsat. App Intent'in widget'tan `UIPasteboard`'a yazabilmesi doğrulanmalı. [Tahmin]
6. **Denetim Merkezi, kilit ekranı ve Action Button kontrolü:** iOS 18'in `ControlWidgetButton` + `AppIntent`'i kullanılır. Panoyu okumak arka planda uyarı ya da izin sorununa takılabileceği için güvenli yol `OpenIntent` / `openAppWhenRun`: uygulamayı açıp 1. maddedeki akışla kaydetmek. Paste'te yok.
7. **Spotlight indeksleme:** `CSSearchableIndex` ve `CSSearchableItem` ya da iOS 18'in `IndexedEntity` ile geçmiş öğeleri sistem aramasında görünür olur. Spotlight'tan seçilen öğe `NSUserActivity` ile kopyalanır.
8. **Zengin App Intents kataloğu:** Geçmiş öğeleri için bir `AppEntity`, "Son kopyayı al", "N'inci öğeyi al" ve "Mac'ten son kopyayı al" eylemleri ve ifadeleri hazır gelen bir `AppShortcutsProvider`. Ayrıca kurulum rehberinden tek dokunuşla eklenen hazır bir Back Tap ya da Action Button kısayolu bağlantısı sunulabilir.
9. **iPad'de görünürken yakalama ve sürükle-bırak:** Çoklu pencerede `UIPasteboard.changedNotification` dinlenir. Listede `.draggable` / `.dropDestination` (Transferable) kullanılır, klavyeden de `NSItemProvider` ile sürükleme desteklenir.
10. **Görsel ve bağlantı zenginliği:** Görselleri `CKAsset` ile eşitlemek, Vision'daki `VNRecognizeTextRequest` (ya da iOS 26'nın `RecognizeDocumentsRequest`'i) ile görsel içi metin aramak, `LPMetadataProvider` ile bağlantı önizlemesi göstermek. Ek olarak `CKShare` ile paylaşılan pinboard'lar ve `UITextView` düzenlemede kendiliğinden gelen Writing Tools.

## UI/UX'ten öğrenilecek 10 şey

1. **Başparmak bölgesi:** Arama ve liste değiştirici alttaki araç çubuğunda duruyor. Geçerli liste adına dokunulduğunda açılan sayfa hem liste değiştirme hem pinboard yönetimi işini görüyor.
2. **Net jest sözleşmesi:** Dokunmak kopyalar, uzun basmak önizleme ve bağlam menüsünü açar, iPad'de sağa kaydırmak da kopyalar. Her yüzeyde (uygulama, klavye, widget) aynı anlamı taşıyor.
3. **Kısıtı saklamamak:** Yardım metni "arka planda yakalayamıyoruz; art arda kopyalarsan sonuncusu kalır; uzantıyı ya da klavyeyi kullan" diye açıkça anlatıyor. Bizim kurulum rehberimiz de aynı dürüstlükte, üstelik çözüm yollarını göstererek bunu söylemeli.
4. **İzin ekranını ürünleştirmek:** Ayarlar'da adı doğrudan "Allow Paste from Other Apps" olan, iOS Ayarlar'a götüren bir satır var. Klavyede Tam Erişim yokken boş liste yerine kurulum yönergeleri gösteriliyor.
5. **Klavyeden çıkmamak:** Yazma modları (harf, sayı, sembol) ve son kopya şeridi sayesinde kullanıcı sistem klavyesine geri dönmek zorunda kalmıyor. Bizim sekmelerimiz bunu kısmen yapıyor; tam yazma modu düşünülmeli.
6. **Klavye bellek bütçesi:** Paste, klavyenin iOS tarafından öldürülmemesi için öğe yüklemeyi ayrıca optimize etti (6.6.4) ve açılış hızına iki sürümde yatırım yaptı. Bu sorun bizde de çıkacaktır: önizlemeler tembel yüklenmeli ve sayfalanmalı, ilk çizim CloudKit beklenmeden yerel önbellekten yapılmalı.
7. **Arama jetonları:** Filtreler arama alanının içinde jeton olarak duruyor ve yazarken öneriliyor. Sonuçlardan "Show in" ile öğenin geçmişteki bağlamına dönülebiliyor. Tümü/Mac/iPhone segmentimiz bu modele taşınabilir.
8. **Akıllı tür algılama, ama temkinli:** Altı rakamlı OTP'ler renk sayılmıyor, `#` ya da A–F harfi olmadan hex kabul edilmiyor. Bizim akıllı eylemlerimiz de yanlış pozitiften kaçınan benzer kurallarla çalışmalı (örneğin her sayı telefon numarası değil).
9. **Kart cilası:** Kenar çizgisi yok, görseller yuvarlatılmış, Liquid Glass derinliği var. Eşitleme göstergesi seçim modunda gizleniyor. Önizlemede başlık tekrarlanmıyor, öğenin kendi içeriği gösteriliyor. Kısacası küçük ve tutarlı ayrıntılar.
10. **Hızlı oluşturma ve toplu işlem:** "+" ile elle öğe eklenebiliyor. Edit ile çoklu seçim yapılıp toplu silmede onay soruluyor. Yeni pinboard sayfasında başlık önceden seçili geliyor ve Done tuşu kaydediyor. Onboarding tam ekran ve sade, deneme sürümü tek dokunuşla başlıyor.

---

## Doğrulanamayanlar ve açık sorular

- iOS'ta yakalanan öğelerde **kaynak uygulamanın** nasıl belirlendiği. Herkese açık bir API yok; büyük olasılıkla yalnızca cihaz bilgisi tutuluyor.
- Eşitleme altyapısının **CloudKit veya CKSyncEngine** olduğu (resmi metinlerde yalnızca "private iCloud" geçiyor), **uçtan uca şifreleme**, **kota** ve gerçek zamanlılık süreleri.
- **Etkileşimli widget**, **kilit ekranı widget'ı**, **Denetim Merkezi kontrolü**, **Live Activity**, **Action Button** ve Back Tap desteği. Hiçbir kaynakta geçmiyor.
- Kısayollar eylemlerinin bugün **App Intents**'e taşınıp taşınmadığı ve güncel eylem adları (2020 listesi biliniyor).
- Klavye içinde **arama** olup olmadığı ve pinboard seçicisinin görünümü.
- iPhone'da pinboard'larda **sürükleyerek sıralamanın** çalışıp çalışmadığı.
- App Store sürüm notlarının sürüm numaralarıyla birebir eşleşmesi (±1 kayma olabilir).
- **Reddit:** r/apple, r/iOS ve r/macapps'ten ilgili bir başlığa erişilemedi; aramalar sonuç döndürmedi ve doğrudan erişim de engelliydi. Bağımsız kullanıcı görüşü pratikte yalnızca Product Hunt yorumlarından ve tek bir geri bildirim panosu gönderisinden geliyor. MacStories, 9to5Mac ve iMore'da iOS sürümüne odaklanan güncel bir inceleme bulunamadı; Macworld (2022) ve MacStories'in Paste 4 yazısı Mac odaklı.
- Bir düşük güvenilirlikli sitede geçen "Kısayollar'da Kopyalama tetikleyicili otomasyon" iddiası Apple kaynaklarında doğrulanamadı; güvenilmemeli.
