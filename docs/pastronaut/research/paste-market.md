# Paste (pasteapp.io) — Pazar Araştırması

> Hazırlanma tarihi: **17 Ekim 2026**. Bütün fiyat, puan ve sürüm bilgileri bu tarihte açık kaynaklardan alındı ve sonradan değişebilir. Uygulama indirilmedi, tersine mühendislik yapılmadı. Yalnızca resmi site, App Store, Setapp, basın, Product Hunt ve Hacker News kullanıldı.
> Kısaltmalar: **[D]** doğrulandı (birincil kaynak) · **[İ]** ikincil kaynak, tek kaynak ya da çelişkili · **[?]** doğrulanamadı.

---

## 0. Yönetici özeti

1. Paste 2015'ten beri piyasada olan, Danimarka merkezli **Paste Team ApS** şirketine ait olgun bir üründür. 2020 civarında tek seferlik satıştan aboneliğe geçti. Fiyatı o günden bu yana yaklaşık üç katına çıktı (yıllık ~$9.99 → $14.99 → **$29.99**). Ömür boyu lisans App Store'da **$99.99**.
2. Paste'in en güçlü olduğu alanlar: görsel kart tasarımı, Mac + iPhone + iPad arasında iCloud eşitlemesi, pinboard'lar ve arama. Paste 6 (Eylül 2025) Liquid Glass tasarımına geçti. 2025–2026 boyunca Apple Intelligence, Paste MCP ve "Intelligent Clipboard" gibi yapay zekâ özellikleri eklendi.
3. Son 500 ABD App Store yorumunun (Eyl 2023 – Eki 2026) yaklaşık **%31'i 1–2 yıldız**. Bu yorumlarda öne çıkan iki tema var: **fiyat ve abonelik** (yaklaşık yarısı) ve **hatalar, çökmeler, eşitleme sorunları ve veri kaybı**. Paste 5 geçişi (Mayıs–Haziran 2025) ciddi bir tepki dalgası yarattı. Yapay zekâ özelliklerinin varsayılan açık gelmesine de tepki var.
4. Gizlilik politikasına göre pano içeriği şirket sunucusuna gitmiyor; yalnızca cihazda ve kullanıcının iCloud'unda tutuluyor. Buna karşın **PostHog analitiği ve Sentry çökme raporları** kullanılıyor ve uygulama içinde **analitikten çıkma anahtarı yok** (en azından politikada belirtilmemiş, bir kullanıcı da bundan şikâyetçi). Şifreleme konusunda açık bir iddia bulunmuyor.
5. Pastronaut için en net boşluk: **ücretsiz + açık kaynak + Mac'te iPhone'la eşitlenen + telemetrisiz + yapay zekâsız** bir pano yöneticisi. Maccy ve ClipBook açık kaynak ama iPhone tarafları yok. PastePal hem Mac'te hem iPhone'da var ama ücretli ve kapalı kaynak. macOS 26'nın Spotlight pano geçmişi ise yalnızca tek Mac'te ve kısa süreli çalışıyor.

---

## 1. Kısa tarihçe

| Tarih | Olay | Kaynak |
|---|---|---|
| Mar–May 2015 | İlk sürüm (App Store kayıt tarihi 21.03.2015). Geliştirici Dmitry Obukhov; 1.0.1 sürümü 5,99 €. İlk tasarım tam ekran pencereydi. | [D] iTunes Lookup `releaseDate` https://itunes.apple.com/lookup?id=967805235 · [İ] https://www.macg.co/logiciels/2015/05/paste-un-gestionnaire-de-copier-coller-elegant-88780 · https://pasteapp.io/blog/paste-evolution-through-the-years |
| 28 Haz 2016 | **Paste 2.0**: alttan açılan panel, birden çok pinboard, Quick Look. Mac App Store'da 9,99 €, mevcut kullanıcılara ücretsiz. Kullanıcılara göre **kalıcı lisanslı son sürüm** bu. | [D] https://www.ifun.de/paste-archiv-fuer-die-mac-zwischenablage-in-version-2-0-erschienen-94327/ · https://mjtsai.com/blog/2023/06/30/paste-4/ (yorum) |
| 13 Mar 2018 | İlk iOS uygulaması (Mac ile eşitlemeli). | [D] https://pasteapp.io/updates |
| Eki 2019 | Paste 2.5 (Catalina). | [D] https://pasteapp.io/updates |
| ~Şub 2020 | **Aboneliğe geçiş duyuruldu.** Bir kullanıcının değerlendirmesi: "$15 once to $10 per year". | [İ] https://honeypot.net/2020/02/10/more-apps-lost.html |
| 2020 | Pano öğesi düzenleme, Siri Shortcuts, bağlantı önizlemeleri, **Paste Stack** (sıralı yapıştırma), Big Sur desteği. | [D] https://pasteapp.io/updates |
| Oca 2021 | Aile Paylaşımı aboneliği. | [D] https://pasteapp.io/updates |
| 5 Şub 2021 | **Paste 3**: iOS ve macOS için evrensel uygulama. Tek abonelik iki platformu kapsıyor (0,99 €/ay veya 10,99 €/yıl). Eski müşterilere ilk yıl ücretsiz verildi. | [D] https://www.appgefahren.de/?p=294616 |
| May 2022 | **Paste Keyboard** (iOS özel klavye). | [D] https://pasteapp.io/updates |
| 30 Haz 2023 | **Paste 4.0** (Mac'te yeniden tasarım, yeniden boyutlanabilir pencere, kompakt mod). Eylül 2023'te iOS tarafı SwiftUI ile yeniden yazıldı. | [D] https://pasteapp.io/updates · https://www.macstories.net/reviews/paste-the-clipboard-management-utility-gets-an-elegant-new-design-on-the-mac/ |
| 2024 | Advanced Pause, görselleri dosya olarak yapıştırma, OCR/metin tanıma, belge tarama. | [D] https://pasteapp.io/updates |
| 26–27 May 2025 | **Paste 5**: Paylaşılan Pinboard'lar ve yeniden yazılmış eşitleme motoru. Geliştiriciye göre "ilk işbirlikçi pano aracı". | [D] https://pasteapp.io/updates · https://news.ycombinator.com/item?id=44105765 |
| 2 Eyl 2025 | **Paste for Teams** (koltuk başına fiyat, toplu fatura). | [D] https://news.ycombinator.com/item?id=45114503 |
| 15–18 Eyl 2025 | **Paste 6**: Liquid Glass ile "OS 26 ailesi" için yeniden tasarlandı. Product Hunt'ta günün 4. ürünü oldu. | [D] https://pasteapp.io/updates · [İ] https://www.hunted.space/product/paste/launches/paste-6 |
| Eki–Ara 2025 | Ekran paylaşımında gizleme (14 Eki), Apple Intelligence yazma araçları (4 Kas), Power Search (filtreler, ekran görüntülerinde OCR; 9 Ara). | [D] https://pasteapp.io/updates |
| 2 Haz 2026 | **Paste MCP**: pano geçmişini Claude, Codex gibi yapay zekâ araçlarına bağlayan yerel MCP sunucusu (sürüm 6.6.0). | [D] https://pasteapp.io/updates · App Store sürüm geçmişi |
| 21 Eyl 2026 | **7.0.0**: yeni SwiftUI altyapısı. iOS tarafında iOS 26 minimum. 7.0.1/7.0.2 sürümlerinde iOS 27 düzeltmeleri. | [D] https://apps.apple.com/us/app/paste-limitless-clipboard/id967805235 |
| 28 Eyl 2026 | **Intelligent Clipboard**: yerel Apple Intelligence modeli ile bir sonraki yapıştırılacak öğeyi öneriyor. Mac'te macOS 26 ve Apple Intelligence gerektiriyor. Product Hunt'ta "Paste 7" adıyla tanıtıldı (~16 Eki 2026). | [D] https://pasteapp.io/blog · https://www.producthunt.com/p/paste/paste-7 |

**Güncel uyumluluk** [D]: Mac için macOS 14+, iPhone/iPad için iOS/iPadOS 26+ ve visionOS 26+ gerekiyor. Son sürüm 7.0.2 (9 Eki 2026). Setapp'te 7.0.3 görünüyor. Kaynaklar: https://apps.apple.com/us/app/paste-limitless-clipboard/id967805235 · https://setapp.com/apps/paste

> Not: Ekim 2026 itibarıyla güncel sistemler macOS/iOS **27**. Paste'in 7.0.x notlarında iOS 27 düzeltmeleri yer alıyor. "macOS 26/iOS 26 uyumu" Paste 6 (Eyl 2025) ile sağlandı.
> [?] Resmi sitede "Paste 7" adı geçmiyor. Bu ad yalnızca Product Hunt'ta ve bir kampanya etiketinde var. App Store sürümü ise 7.0.x.

---

## 2. İş modeli

| Kalem | Fiyat / detay (17.10.2026) | Kaynak |
|---|---|---|
| Ücretsiz katman | **Yok.** Yalnızca 7 günlük deneme var. Yorumlarda "free" etiketinin yanıltıcı olduğu sık sık dile getiriliyor. | [D] https://pasteapp.io/pricing · App Store yorumları |
| Deneme | 7 gün, tüm özellikler. Web sürümünde kart istenmiyor. App Store'da ilk abonelikle birlikte veriliyor. Eski kaynaklarda (Macworld, üçüncü taraf listeler) 14 gün yazıyor. | [D] https://pasteapp.io/help/choose-a-plan · [İ] https://www.macworld.com/article/804417/paste-review.html |
| Aylık | App Store'da **$3.99/ay** | [D] App Store IAP listesi |
| Yıllık | **$29.99/yıl**. Web sitesindeki "$2.49/month" ifadesi yıllık ücretin aylığa bölünmüş hali. | [D] https://pasteapp.io/pricing · App Store |
| Ömür boyu | App Store'da **$99.99**. 2025–2026 kullanıcı yorumlarında $89–90 deniyor, yani fiyat yakın zamanda yükselmiş olabilir **[İ]**. Aile paylaşımını kapsamıyor. | [D] App Store IAP · https://pasteapp.io/help/choose-a-plan |
| Aile | **$59.99/yıl**, 6 kişiye kadar. Yalnızca App Store'da satılıyor. 2021'de 5 kişilikti. | [D] App Store IAP · https://pasteapp.io/pricing |
| "Legacy Plan" | $9.99 olarak listeleniyor. Büyük olasılıkla eski yıllık fiyatla devam eden aboneler için. **[?]** Anlamı resmi olarak açıklanmamış. | App Store IAP |
| Teams | Koltuk başına fiyat, toplu indirim, yalnızca web sitesinden. Fiyat yayımlanmamış. | [D] https://pasteapp.io/help/choose-a-plan |
| Setapp | Setapp üyeliğine dahil, ek ücret yok. iPhone/iPad için iOS içeren Setapp planı gerekiyor. Setapp, Lifetime ve Family seçeneklerini sunmuyor. Setapp sayfası 7.192 oydan %98 olumlu gösteriyor. | [D] https://setapp.com/apps/paste · https://pasteapp.io/pricing |
| İndirimler | Öğrenci ve eğitimcilere ilk yıl %30 indirim. Kampanyalar da yapılıyor: Black Friday 2025'te ilk yıla %50, 10. yıl kodu ile %10. | [D] https://pasteapp.io/pricing · https://news.ycombinator.com/item?id=46045639 |
| Ödeme sağlayıcıları | Apple, Setapp ve Lemon Squeezy (web satışları). | [D] https://pasteapp.io/privacy |

**Fiyat geçmişi** [İ]: 2016'da tek seferlik 9,99 € → 2021'de 10,99 €/yıl → 2025 başında yıllık $9.99'dan $14.99'a ("Wild price increase", Mart 2025 yorumu) → bugün $29.99/yıl. Bu tablo kullanıcı yorumlarından ve basından derlendi, resmi bir fiyat geçmişi bulunamadı. Kaynaklar: https://www.appgefahren.de/?p=294616 · https://www.macworld.com/article/804417/paste-review.html · App Store yorumları (aşağıda).

**Tedarik zinciri**: Pazarlama tarafında HN üzerinden "Show HN" ve kampanya duyuruları ile Product Hunt lansmanları düzenli olarak yapılıyor (Paste 5, 6, 7). Ekip Kopenhag/Avrupa merkezli ve uzaktan çalışıyor (HN iş ilanları: https://news.ycombinator.com/item?id=33093442).

---

## 3. Gizlilik politikası özeti

Kaynak: https://pasteapp.io/privacy (yürürlük tarihi **27 Haziran 2026**) [D]

- **Veri sorumlusu**: Paste Team ApS, Frederiksberg, Danimarka (CVR 43121251).
- **Hesap**: Hesap sistemi yok. Abonelik bilgisi kullanıcının iCloud'unda saklanıyor.
- **Pano içeriği**: Geçmiş ve pinboard'lar cihazda tutuluyor. iCloud Sync açıksa kullanıcının kendi iCloud alanına da yazılıyor. Politikaya göre bu veri şirket sunucularına "not transferred to or stored on our servers". Yardım sayfasında da "Nothing is sent to the Paste Team" deniyor (https://pasteapp.io/help/where-paste-stores-your-data). CloudKit'in adı geçmiyor.
- **Analitik**: Anonimleştirilmiş kullanıcı kimliği, cihaz türü, işletim sistemi, dil, **yaklaşık konum**, uygulama sürümü, abonelik durumu, uygulama içi olaylar ve hata kodları toplanıyor. Uygulama için **PostHog (AB'de barındırılan)**, web sitesi için **Plausible** kullanılıyor.
- **Çökme raporları**: **Sentry**.
- **Destek ve bülten**: Help Scout, Gmail, Sidemail. Web sitesindeki yardım asistanı Anthropic tabanlı ve sohbetler Neon veritabanında saklanabiliyor.
- **App Store gizlilik etiketi** [D]: "Data linked to you" altında Cihaz Kimliği (uygulama işlevi için). "Data not linked to you" altında satın alma geçmişi, ürün etkileşimi ve çökme verisi (analitik için). İzleme (tracking) beyanı yok.
- **Şifreleme**: **Açık bir şifreleme iddiası yok.** Politika yalnızca "industry-appropriate" önlemlerden söz ediyor (güvenli ağlar, sınırlı erişim gibi). Uçtan uca şifreleme ya da iCloud Advanced Data Protection hakkında bir şey yazmıyor. [?]
- **Analitikten çıkış**: Politikada uygulama içi bir çıkış yolu tanımlanmamış. Aralık 2025 tarihli 4 yıldızlı bir yorumda "can't opt out of data collection" deniyor. Ocak 2026 tarihli 1 yıldızlı bir yorumda ise kullanıcı, iCloud kapalıyken bile ağ trafiği gördüğünü söylüyor. Bu trafik büyük olasılıkla analitik veya lisans kontrolü, ama **[?]** doğrulanmadı.
- **Hassas içerik**: "Confidential" ve "transient" olarak işaretlenmiş pano türleri varsayılan olarak atlanıyor. Bazı tarayıcı eklentilerinin kopyaladığı parolalar algılanamayabiliyor. Ignore Applications listesi var. Ekim 2025'te 6.1.0 sürümünde Apple Passwords'ten kopyalanan değerlerle ilgili bir hata bildirildi (yorum). Kaynak: https://pasteapp.io/help/what-paste-captures
- **iOS kısıtı**: iOS arka planda panoyu okumaya izin vermiyor. Bu yüzden Paste kopyalanan öğeyi ancak uygulama açıldığında, paylaşım menüsünden ya da Paste Keyboard üzerinden alabiliyor. iPad'de uygulama görünür kaldığı sürece otomatik yakalama çalışıyor. Klavye, eşitleme için **Full Access** istiyor. Kaynaklar: https://pasteapp.io/help/what-paste-captures · https://pasteapp.io/help/enable-and-use-paste-keyboard

---

## 4. Kullanıcı geri bildirimi

**Yöntem**: Apple'ın herkese açık RSS akışından ABD App Store'daki son **500 yorum** çekildi (Eylül 2023 – Ekim 2026): https://itunes.apple.com/us/rss/customerreviews/id=967805235/sortby=mostrecent/json. Dağılım şöyle: 5★ 282, 4★ 32, 3★ 31, 2★ 37, 1★ 118. Genel puan **4,19 / 1.335 oy** (https://apps.apple.com/us/app/paste-limitless-clipboard/id967805235). Temalar anahtar kelime sayımı ve elle okuma ile çıkarıldı, bu yüzden sayılar yaklaşık. Bunlara HN yorumları, Product Hunt, Setapp ve basın eklendi. Reddit'e doğrudan erişilemedi (403/404), Reddit bilgileri ikincil özetlerden geliyor **[İ]**.

### 4a. En çok övülen 10 şey

1. **Görsel tasarım ve kart önizlemeleri**: renk kodları, görseller, kaynak uygulama ikonu. Olumlu yorumlarda en sık geçen tema bu (~40/314). MacStories bu tasarımı "the kind of clipboard manager Apple might make" diye niteledi. https://www.macstories.net/reviews/paste-the-clipboard-management-utility-gets-an-elegant-new-design-on-the-mac/
2. **Mac ↔ iPhone ↔ iPad eşitlemesi** (iCloud). "Copy on my iPhone, paste on my Mac" türü övgüler sık. App Store yorumları · https://9to5mac.com/2023/06/30/paste-clipboard-manager-macos/
3. **Pinboard'lar**: tekrar kullanılan metinleri, yapay zekâ istemlerini, formülleri ve lisans anahtarlarını saklamak için kullanılıyor. App Store yorumları (2020, 2025)
4. **Arama**: Arşivde arama, ekran görüntülerinde OCR ve Power Search övülüyor. Bazı kullanıcılar "AI search" özelliğini "game changer" olarak anıyor (Nisan 2026). App Store yorumları
5. **Klavye odaklı akış**: ⇧⌘V, ⌘1–9, özel kısayollar, Cmd+Enter ile düz metin yapıştırma. App Store yorumları · MacStories
6. **Paste Stack ve sıralı yapıştırma**: birden çok öğeyi kopyalayıp sırayla yapıştırma. App Store yorumları (2025–2026)
7. **Sınırsız geçmiş ve "hiçbir şey kaybolmuyor" hissi**. https://news.ycombinator.com/item?id=25306479 · App Store yorumları
8. **İş akışına oturması**: "most used app", "top 3 first apps" gibi ifadeler. Uzun süreli kullanıcıların sadakati yüksek. App Store yorumları · https://news.ycombinator.com/item?id=31869243
9. **Gizlilik ayarları**: 1Password gibi uygulamaları yok sayma, iCloud'un kişisel hesapta kalması. https://news.ycombinator.com/item?id=29811285 · App Store yorumu (Ağu 2025)
10. **Düzenli güncellemeler ve kimi zaman iyi destek**: "receives meaningful and useful updates", "great support" (Tem 2025). App Store yorumları. Setapp'te %98 olumlu (https://setapp.com/apps/paste)

### 4b. En çok şikâyet edilen 10 şey

1. **Fiyat ve abonelik**: 155 düşük puanlı yorumun ~73'ünde geçiyor. "$90 for a small clipboard app", "$30/yr is still too much" gibi ifadeler var. Eski tek seferlik alıcılar da kızgın: "don't take away something that I already purchased" (Eyl 2026). Ayrıca https://honeypot.net/2020/02/10/more-apps-lost.html · https://news.ycombinator.com/item?id=40795443 (abonelik sonrası Raycast'e geçen bir kullanıcı)
2. **"Ücretsiz" görünüp deneme sonrası kilitlenmesi**: Kurulum yapıldıktan sonra paywall çıkıyor. "Predatory", "Not actually free" gibi başlıklar sık (2025–2026).
3. **Hatalar ve çökmeler**: ~45 düşük puanlı yorumda geçiyor. Açılışta çökme, M4 Mac'te açılmama, donma, %99 CPU kullanımı (Ağu 2025).
4. **Paste 5 geçişindeki felaket** (May–Haz 2025): "Migrating Data" ekranında saatlerce takılma, iPhone'un "brick" olması, eşitlemenin durması. Bazı kullanıcılar PastePal'e geçtiğini yazdı.
5. **iCloud eşitlemesinin güvenilmezliği**: iPad'de arka plan eşitlemesi hiç çalışmıyor (Şub 2025), "Abysmal Syncing" (Kas 2025), "sync broken" (Eyl 2025).
6. **Veri kaybı**: Pinlenen öğeler kayboluyor, düzenlemeler siliniyor (Eki 2026), eşitleme sırasında öğeler eksik kalıyor (Şub 2026).
7. **Müşteri desteği**: Bazı kullanıcılar yanıt alamadığını, ölü iletişim bağlantıları bulduğunu ve yorumlarının silindiğini iddia ediyor. App Store yorumları (2025–2026) · uygulama sayfasındaki 2025 yorumu
8. **Yapay zekânın dayatılması**: "unacceptable injection of AI", "No AI Garbage" (Eyl–Eki 2026). Kullanıcılar Intelligent Clipboard'ın **varsayılan açık (opt-out)** geldiğinden şikâyetçi. Ocak 2026'da "AI smart search" sonrası aramanın bozulduğu da bildirildi.
9. **iOS deneyiminin zayıf olması**: Arka planda yakalama yok, uygulamaya geçip beklemek gerekiyor. Klavye "intrusive" bulunuyor. iPad'de "Global Key" çalışmıyor. VoiceOver erişilebilirliği zayıf (May 2025).
10. **Kaldırmanın zor olması ve şişkinlik**: Gizli "Paste Helper" süreci yüzünden uygulamanın Terminal olmadan silinemediği iddiası (Şub 2026). "feature-creep and bloat" eleştirisi (Eyl 2026). Paste 5'in temel özellikler yerine "sosyal" özelliklere odaklandığı düşünülüyor (May 2025).

Küçük ama tekrar eden istekler (fırsat listesine girdi olarak):

- Paneli ekranın farklı kenarlarında açabilme. Ultra geniş monitörde tam genişlik şerit rahatsız ediyor (Oca 2026, Nis 2026).
- Kısayolla belirli bir pinboard'u açabilme (Ağu 2026).
- Numaralı snippet'ler ve yalnızca metin görünümü.
- Tek tıkla açma.
- Remote Desktop uyumu.
- Analitik için kapatma anahtarı.

Kaynak: App Store yorumları.

---

## 5. Rakip karşılaştırması

| Uygulama | Model / fiyat (Eki 2026) | Platform | Eşitleme | Açık kaynak | Paste'e göre önde olduğu alanlar | Paste'in önde olduğu alanlar | Kaynak |
|---|---|---|---|---|---|---|---|
| **Paste** | Abonelik $3.99/ay, $29.99/yıl, Lifetime $99.99, Setapp | Mac, iPhone, iPad, visionOS + klavye | iCloud (kişisel) | Hayır | — | Tasarım, Mac+iOS bütünlüğü, paylaşılan pinboard, Teams, MCP | yukarıda |
| **Maccy** | Ücretsiz (GitHub/Homebrew). Mac App Store'da destek amaçlı $9.99. | Yalnızca Mac (macOS 14+) | Yok | **Evet, MIT** (~22k yıldız) | Ücretsiz, hafif, hızlı, şeffaf | iOS yok, eşitleme yok, görsel önizleme sınırlı | https://github.com/p0deje/Maccy · https://apps.apple.com/us/app/maccy/id1527619437 |
| **PastePal** | Ücretsiz indirme, **Pro $14.99 tek seferlik** | Mac, iPhone, iPad, Vision, iMessage + klavye | İsteğe bağlı iCloud | Hayır | Tek seferlik fiyat, **"Data Not Collected"**, 75+ metin dönüşümü, Live Activity | Daha az tanınıyor ve daha az cilalı (4,14★/189 oy) | https://apps.apple.com/us/app/clipboard-manager-pastepal/id1503446680 |
| **Raycast** (Clipboard History) | Ücretsiz plan: 3 ay geçmiş. Pro ~$8/ay (yıllık) ile sınırsız. | Mac (+ ayrı iOS uygulaması, pano eşitlemesi yok) | Pano geçmişi **eşitlenmiyor** (bilinçli tercih) | Hayır | Ücretsiz, zaten kullanılan bir başlatıcının içinde | Mobil eşitleme, pinboard görselliği | [İ] https://www.macstories.net/news/raycast-introduces-a-pro-subscription-with-new-ai-sync-theming-and-clipboard-functionality/ · https://thesweetsetup.com/heres-what-you-need-to-know-about-raycast-pro/ |
| **Alfred** (Powerpack) | £34 (v5) veya £59 (ömür boyu güncelleme), tek seferlik | Yalnızca Mac | Yok | Hayır | Tek seferlik fiyat, iş akışları ve snippet'lerle bütünleşme | Geçmiş en fazla 3 ay, iOS yok | https://www.alfredapp.com/powerpack/buy/ · https://www.alfredapp.com/help/features/clipboard/ |
| **CleanClip** | Kaynaklar çelişkili: $1.99/ay veya ~$19.99 tek seferlik [İ] | Mac (+ iOS sürümüne bağlantı var) | Belirtilmemiş | Hayır | İmlecin yanında açılan popup, Follow Frontmost App, Split Copy | Eşitleme ve olgunluk | https://cleanclip.cc · [İ] https://alternativeto.net/software/cleanclip/about |
| **Pastebot 3** (Tapbots) | **Abonelik**: $2.99/ay, $24.99/yıl (2026'da Pastebot 2'nin tek seferlik modelinden geçti) | Yalnızca Mac (macOS 26.2+) | iCloud (Mac'ler arası) | Hayır | **Filtreler** (yapıştırmadan önce dönüştürme), güçlü sıralı yapıştırma, "Data Not Collected" | iOS yok | https://apps.apple.com/us/app/pastebot-3/id6761201231 · https://mjtsai.com/blog/2023/06/30/paste-4/ |
| **ClipBook** | **$9.99 tek seferlik** (Ekim 2026'da $14.99'a çıkacağı duyurulmuş), 5 gün deneme | Yalnızca Mac (13+) | Yok (dışa/içe aktarma var) | **Evet** (GitHub) | Analitik yok, parola maskeleme, 78 dönüşüm, birleştirme ve bölme | iOS ve eşitleme yok | https://clipbook.app |
| **macOS 26 Spotlight Pano Geçmişi** | Ücretsiz, sistemle birlikte | Yalnızca Mac | Yok | — | Kurulum gerektirmiyor | Saklama en fazla 7 gün (26.1+: 30 dk / 8 sa / 7 gün), pinboard yok, tek Mac | https://pasteapp.io/blog/macos-tahoe-clipboard-history · [İ] https://support.ntiva.com/hc/en-us/articles/39853826658701-macOS-Tahoe-Disable-Clipboard-History-in-Spotlight |
| **Copied** | [?] Listede "Copied: Workspace Keyboard" (Sharply Labs) görünüyor; orijinal Copied ile aynı ürün olup olmadığı doğrulanmadı. | iOS | ? | Hayır | — | — | https://apps.apple.com/us/app/copied-workspace-keyboard/id1517022963 |

**Özetle rakiplerin Paste'ten önde olduğu alanlar:**

- **Fiyat**: Maccy, ClipBook, PastePal ve Alfred tek seferlik ya da ücretsiz.
- **Telemetri yokluğu**: PastePal, Pastebot ve ClipBook "Data Not Collected" diyor ya da analitik kullanmadığını beyan ediyor.
- **Metin dönüşümleri ve filtreler**: Pastebot, PastePal, ClipBook.
- **Hız ve hafiflik**: Maccy.
- **Açık kaynak ve denetlenebilirlik**: Maccy, ClipBook.
- **İmleç yakınında açılan popup**: CleanClip ve Maccy. HN'de bir kullanıcı bunu "feels like a macOS system popup" diye övüyor (https://news.ycombinator.com/item?id=37609067).

**Paste'in hâlâ önde olduğu alanlar**: Mac + iOS + klavye + iCloud paketinin cilası, paylaşılan pinboard'lar ve Teams, ekran görüntülerinde OCR arama, yapay zekâ entegrasyonları (MCP, Apple Intelligence) ve marka bilinirliği (Apple Editors' Choice rozeti, MacStories ve 9to5Mac kapsamı).

---

## 6. Pastronaut için fırsatlar

1. **"Ücretsiz, açık kaynak, Mac + iPhone" kombinasyonu boş bir alan.** Ücretsiz ve açık kaynak olanlar (Maccy, ClipBook) yalnızca Mac'te çalışıyor. Mac + iPhone yapanlar (Paste, PastePal) ücretli ve kapalı kaynak. Pastronaut'un MIT lisanslı Maccy çatalı + iPhone uygulaması + klavye + iCloud kurgusu tam bu boşluğa oturuyor.
2. **Abonelikten bıkanlar büyük bir kitle.** Düşük puanlı yorumların yaklaşık yarısı fiyatla ilgili. 2016–2020 arası kalıcı lisans almış ve kendini "zorla aboneliğe itilmiş" hisseden eski kullanıcılar var. Mesaj "abonelik yok, paywall yok, deneme yok" olabilir. Ancak doğrudan Paste'i hedef alan bir dil kullanılmamalı (bkz. §7).
3. **Gizlilik farkı somut ve ölçülebilir olmalı:**
   - Sıfır analitik ve sıfır çökme SDK'sı, App Store etiketi "Data Not Collected".
   - Ağ erişimi yalnızca CloudKit ile sınırlı ve bu kodda doğrulanabilir.
   - Kişisel iCloud özel veritabanı. Advanced Data Protection ile uyumluysa bu açıkça belgelenmeli. Paste şifreleme konusunda hiçbir şey söylemiyor.
   - Varsayılan olarak hiçbir yapay zekâ özelliği yok. Paste'in opt-out yapay zekâsına gelen tepki bu farkı değerli kılıyor.
   - "Kaldırıldığında iz bırakmaz" belgesi. Paste Helper şikâyeti burada bir referans.
4. **Yalnızca metin eşitlemesi bir eksiklik değil, bir avantaj olarak sunulabilir.** Paste'in en çok şikâyet aldığı alanlar eşitleme, migrasyon ve veri kaybı. Sade bir metin şeması, küçük CloudKit kayıtları ve migrasyonsuz bir veri modeli **güvenilirlik** vaadi olarak konumlanabilir. Sürüm yükseltmelerinde "bloklayan migrasyon ekranı" asla olmamalı.
5. **iOS klavye deneyimi**: Paste klavyesi "intrusive" ve "laborious" bulunuyor. Pastronaut klavyesi yazma klavyesi olmamalı, yalnızca geçmiş ve pinler için **hafif bir seçici** olmalı. Full Access'in neden gerektiği tek ekranda dürüstçe açıklanmalı.
6. **Kullanıcıların isteyip alamadıkları:**
   - İmleç ya da menü çubuğu yakınında açılan küçük bir popup. Ultra geniş ekranda tam genişlik şerit istemeyenler var. Maccy tabanı bunu zaten sağlıyor.
   - Kısayolla belirli bir pinlenmiş koleksiyonu açabilme.
   - Numaralı ve yalnızca metin görünümü.
   - Tam VoiceOver erişilebilirliği.
   - Düz metin olarak dışa ve içe aktarma (JSON/CSV). Paste'in yardım sayfasında manuel dışa aktarma yok.
   - Uygulama bazında yok sayma ve parola maskelemenin varsayılan olarak sıkı olması.
7. **Rekabetin gerçekçi sınırı**: macOS 26 Spotlight geçmişi tek Mac'te ve kısa vadede çalışan ücretsiz bir taban sunuyor. Sadece Mac'te kalan bir ürünün değeri bu yüzden düşüyor. Pastronaut'un ayırt edici değeri **iPhone köprüsü + kalıcı pinler + gizlilik**.
8. **Dağıtım**: Maccy'de olduğu gibi GitHub + Homebrew + (isteğe bağlı) App Store. iOS tarafı App Store zorunluluğu nedeniyle Apple Developer üyeliği ile ücretsiz yayımlanabilir.

---

## 7. Yasal not (hukuki görüş değildir, genel bilgidir)

- **Marka**: Paste'in kullanım şartları "You may not use the brand, the word, or figurative trademarks associated with Paste" diyor ve logo, tasarım ve grafiklerin şirkete ait olduğunu belirtiyor (https://pasteapp.io/terms). **[?]** "PASTE" için tescilli bir marka kaydı (USPTO/EUIPO) bu araştırmada doğrulanamadı. Kelime pano uygulamaları için tanımlayıcı/jenerik nitelikte olabilir (PastePal, Pastebot ve Paste Keyboard gibi pek çok uygulama "paste" kelimesini kullanıyor). Yine de güvenli varsayım şu: **ad, logo ve ikon ayırt edici şekilde farklı olmalı.** "Pastronaut" adı "Paste" kelimesini birebir içermiyor. Tanıtımda "Paste for free" ya da "Paste klonu" gibi ifadelerden kaçınılmalı.
- **App Store kuralları** (https://developer.apple.com/app-store/review/guidelines/):
  - 2.3.7: Metadata'ya "popular app names" veya başka markalar doldurulmamalı. Anahtar kelimelere "Paste", "Maccy" ve benzeri adlar konmamalı.
  - 4.1(a–c): Başka bir uygulamanın adını veya arayüzünü küçük değişikliklerle kopyalamak "copycat" sayılıyor. Başka geliştiricinin ikonu, markası ya da ürün adı izinsiz kullanılamaz.
  - 5.2.1: Üçüncü taraf markası veya telif içeren materyal izinsiz kullanılamaz.
- **İşlev ile görünüş ayrımı**: Fikirler ve işlevler genellikle koruma altında değildir. Alttan açılan yatay kart şeridi, pinboard (koleksiyon), sıralı yapıştırma ve klavyeden geçmişe erişim **işlev olarak** serbest kabul edilir; bu fikirleri pek çok rakip de kullanıyor. Risk **ayırt edici görünüşün birebir taklidinde** (trade dress, tasarım ve telif):
  - Kart başlığında kaynak uygulamanın rengini şerit olarak kullanma, kart oranları, köşe yarıçapları, gölge ve Liquid Glass katman düzeni, tipografi ve ikon dizilimi gibi bir bütün olarak Paste'i çağrıştıran kombinasyonlar.
  - Paste'e özgü terimler: "Pinboard", "Paste Stack", "Limitless Clipboard". Bunların yerine "Pinler", "Koleksiyonlar", "Sıra" gibi kendi terimlerinizi kullanın.
  - Paste'in ikonu, renk paleti, onboarding ekranları, web sitesi düzeni ve pazarlama metinleri.
  - Paste'in ekran görüntüleri, videoları ve App Store görselleri. Karşılaştırma sayfasında bile kullanılmamalı.
- **Pratik kurallar:**
  1. Pastronaut'un varsayılan arayüzü Maccy'nin **dikey popup** dili olsun. Bu hem upstream ile tutarlı hem de Paste'ten belirgin biçimde farklı.
  2. Yatay şerit modu eklenecekse kart tasarımı, renk dili ve animasyonları sıfırdan ve farklı biçimde tasarlanmalı.
  3. Karşılaştırmalı tanıtım yapılacaksa yalnızca doğrulanabilir ve olgusal tablolar kullanılmalı (fiyat, açık kaynak olma, telemetri). Rakip adı düz metin olarak geçebilir, logo kullanılmamalı. Aşağılayıcı ifadelerden ve "resmi alternatif" gibi ilişki ima eden dilden kaçınılmalı.
  4. Paste'in kodu, kaynakları, metinleri ve yerelleştirme dosyaları kesinlikle kullanılmamalı. Bu araştırmada tersine mühendislik de yapılmadı.
  5. Upstream MIT lisansı (Maccy) ve telif bildirimi korunmalı.
- Ticari yayın öncesinde marka ve tasarım riskleri için bir avukata danışılması önerilir.

---

## 8. Doğrulanamayan veya belirsiz noktalar

- Aboneliğe geçişin kesin tarihi (2020 başı olduğu ikincil kaynaklardan çıkarıldı) ve 2025'teki fiyat artışlarının resmi tarihleri.
- "Legacy Plan $9.99" seçeneğinin tam anlamı. Lifetime fiyatının $89.99'dan $99.99'a ne zaman çıktığı.
- Setapp sayfasındaki "From $14.99/month" ifadesi Setapp'in kendi üyelik fiyatını gösteriyor. Setapp planları sık değişiyor.
- "Paste 7" adının resmi olup olmadığı (App Store'da 7.0.x, resmi sitede bu ad geçmiyor).
- iCloud eşitlemesinin CloudKit üzerinden mi yapıldığı ve şifreleme ya da ADP durumu.
- Analitiğin uygulama içinden kapatılıp kapatılamadığı. Politikada yer almıyor, bir kullanıcı kapatılamadığını söylüyor.
- "PASTE" marka tescilinin varlığı ve kapsamı.
- CleanClip'in güncel fiyatı (kaynaklar çelişkili) ve Raycast Pro'nun güncel fiyatı.
- Reddit tartışmaları doğrudan okunamadı. Reddit kaynaklı ifadeler ikincil özetlere dayanıyor.
- Kullanıcı yorumları yalnızca ABD mağazasından ve son 500 yorumdan alındı. Kendini seçen, olumsuza yatkın bir örneklem.
