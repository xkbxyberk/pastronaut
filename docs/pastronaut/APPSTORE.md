# App Store: Pastronaut for iPhone and Mac (v5, 2026-10-24: 1.3 for iPhone and Mac)

Copy-ready App Store Connect metadata for one product on two devices, the research behind it, and every form
answer. Character counts were measured. Everything describes the app as it is at this commit.

## 1. Research summary

### How Paste presents itself (the category leader, studied 2026-10-18)
- **One record for every device.** A single App Store record (id 967805235) covers iPhone, iPad and Mac: a "universal
  purchase", bought once for all devices.
- **Subtitle:** "Copy, Search, Manage, Share" (verbs).
- **Description:**
  - opens with the problem ("your clipboard holds one item");
  - continues in benefit sections (keep, find, paste fast, everywhere, organize, private);
  - ends with plain pricing and contact.
- **Screenshots, iPhone (9) and Mac (8):**
  - Every frame has a small colored eyebrow word (KEEP, SEARCH, ORGANIZE, KEYBOARD, SYNC…) and a two-line headline.
  - The background is light and calm.
  - Frames show real UI: whole devices, or single UI parts enlarged (a search field, a list of boards, a code card).
- **Both devices in one picture.** The first two or three frames form one panorama: a MacBook crosses the seam between
  frames 1 and 2, an iPhone stands in front, an iPad crosses the next seam. The Mac set opens with a Mac and an iPhone
  in the same frame. The message "one product, every device" comes before any feature.
- **What we take:** the techniques only: panorama, eyebrow plus headline, story order, enlarged real UI.
- **What we don't take:** Paste's wording, colors, card design or names (Pinboards, Paste Stack). Our pictures use our
  own palette (the kind colors) and our own UI.

### Search (ASO): how App Store search works, as far as can be verified
- **Indexed fields:** the name (30), subtitle (30) and keyword field (100) are indexed; the description is not. Apple
  combines single words across the three fields into phrases. So:
  - list single words, separated by commas without spaces;
  - never repeat a word that is already in the name or subtitle;
  - use either the singular or the plural, not both;
  - leave out the category name and "app".
- **Which languages count where.** Each storefront also indexes a second localization:
  - United States: English (U.S.) + Spanish (Mexico).
  - Türkiye, the UK and almost every other country: their own language + **English (U.K.)**.
  - Apple doesn't document this; it is community-measured (sources below).
  - **Consequence:** English (U.K.) must carry the core English keywords for Türkiye and the rest of the world. The
    Turkish keyword field can then be all Turkish.
- **Per platform or shared:** the name and subtitle are shared by all platforms of one record. Keywords, description,
  promotional text and screenshots are set per platform.
- **Not allowed:** other apps' names in keywords or text fields (guideline 2.3.7). We also leave Apple's marks (iCloud,
  Universal Clipboard) out of the keyword field to be safe; the description may name iCloud.
- **What people search for in this category (store survey):**
  - clipboard, clipboard manager, clipboard history;
  - copy paste, copy paste keyboard, paste keyboard;
  - snippets, text templates, quick replies;
  - on Mac: menu bar, pasteboard.

### Positioning
**Pastronaut is one clipboard on iPhone and Mac. Each app is complete on its own, and better together.**
- **iPhone:**
  - a history of what you save, and a keyboard that pastes any of it in any app;
  - smart cards by kind, pins and collections, search;
  - widgets and Shortcuts.
- **Mac:**
  - the full menu bar clipboard manager;
  - Space preview, paste a list in order, typed filters;
  - pins, collections, privacy tools.
- **Together:** everything copied on either device shows up on the other, through the user's own private iCloud.
- **Differences from the category:**
  - free, with no subscription or tier;
  - no account, no servers, no tracking;
  - open source;
  - Turkish UI and Turkish address recognition.
- **Honest limit (iPhone):** iOS lets only the app in front read the clipboard. Copies are saved with one tap, which
  every iPhone clipboard app has to do; the description says so plainly.

## 2. Release plan and where things go

### Release plan
- **Now: iPhone.** The App Store record already exists (iOS).
- **Mac now:** GitHub (Developer ID, notarized), as today.
- **Mac App Store, next:** "Add Platform › macOS" on the same record. Our Mac bundle ID is the same
  (`com.xkbxyberk.pastronaut`), so it becomes a universal purchase like Paste. The build:
  - `scripts/appstore/build-mas.sh` makes it without Sparkle (guideline 2.4.5(vii)), with a privacy manifest;
  - the Accessibility-based paste and queue stay; the review notes (§13) explain them, since App Review may ask
    under 2.4.5.

### Where each field goes in App Store Connect
- **App Information (shared by all platforms):**
  - name, subtitle, category, content rights, age rating;
  - license agreement: Apple's standard EULA;
  - encryption: nothing to upload; the app uses only the OS's encryption;
  - Digital Services Act: non-trader.
- **Each platform's version page (iOS App › 1.0, later macOS App › 1.0):**
  - screenshots, header and search result images;
  - promotional text, description, keywords, support and marketing URLs, copyright;
  - App Review information, build.
- **Languages:** fill **English (U.S.)**, **English (U.K.)** and **Turkish**. Add them from the language menu at the
  top right of App Information and of the version page. Spanish (Mexico) is optional (§4).
- **Trust & Safety › App Privacy:** privacy policy URL; data collection: "No".
- **Pricing and Availability:** free, all countries.

## 3. App Information (shared)
| Field | English (U.S.) | English (U.K.) | Turkish |
|---|---|---|---|
| Name [30] | `Pastronaut: Clipboard History` (29) | `Pastronaut: Clipboard History` (29) | `Pastronaut: Pano Geçmişi` (24) |
| Subtitle [30] | `Copy & Paste Manager + Sync` (27) | `Copy & Paste Manager + Sync` (27) | `Kopyala, Yapıştır ve Eşitle` (27) |

- **Name and subtitle together** form searches for: clipboard history, clipboard manager, copy paste, paste manager,
  clipboard sync.
- **The subtitle names no device,** so it fits the iPhone and the Mac pages alike.
- **Turkish name:** "Pastronaut" alone is reserved by another account for Turkish, hence the descriptor. The Home
  Screen always shows "Pastronaut".
- **Category:** Productivity (primary), Utilities (secondary). **Content rights:** Yes, because link previews show
  page titles and images.
- **Bundle ID:** `com.xkbxyberk.pastronaut`.
  - The extensions' App IDs (`.keyboard`, `.share`, `.widgets`, and `.action` since 1.2) were created by Xcode and
    ship inside the app.
- **SKU:** `pastronaut-ios`.
- **URLs:**
  - Privacy: https://xkbxyberk.github.io/pastronaut/privacy.html
  - Support: https://github.com/xkbxyberk/pastronaut/issues
  - Marketing: https://xkbxyberk.github.io/pastronaut/
- **Copyright:** `2026 Berk Akbay`.
- **Price:** Free, no in-app purchases.

## 4. Keywords [100] (single words, no spaces, nothing from the name or subtitle)
For 1.3 the iPhone fields trade the weakest words of 1.2 (reply, quick, phrase, multiple) for what 1.3 adds (image,
pdf, file, screenshot); the Mac fields swap queue and preview for pdf and screenshot. The 1.2 sets are in git history.

| | iPhone | Mac |
|---|---|---|
| **English (U.S.)** | `keyboard,snippet,text,image,pdf,file,screenshot,widget,template,note,link,organizer,save,pin,mac` (96) | `menubar,menu,bar,pasteboard,snippet,text,image,pdf,file,screenshot,search,shortcut,pin,ocr,iphone` (97) |
| **English (U.K.)** | `keyboard,snippet,text,image,pdf,file,screenshot,widget,template,note,link,organiser,save,pin,mac` (96) | `menubar,menu,bar,pasteboard,snippet,text,image,pdf,file,screenshot,search,shortcut,pin,ocr,iphone` (97) |
| **Turkish** | `klavye,yönetici,geçmiş,kopya,metin,görsel,pdf,dosya,ekran,görüntüsü,parçacık,şablon,widget,mac` (94) | `menü,çubuğu,kısayol,parçacık,metin,görsel,pdf,dosya,ekran,görüntüsü,arama,önizleme,iphone,geçmiş` (96) |

**What these cover, combined with the name and subtitle:**
- **iPhone:** "clipboard keyboard", "copy paste keyboard", "text snippets", "clipboard image", "pdf clipboard",
  "screenshot sync", "clipboard widget", "clipboard organizer", "clipboard mac".
- **Mac:** "clipboard menu bar", "pasteboard manager", "screenshot clipboard", "clipboard history search", "copy paste
  shortcut", "clipboard iphone", "ocr".
- **Turkish:** "pano klavye", "ekran görüntüsü", "kopya geçmişi", "pdf", "metin şablonu".

**Why each language has its own field:**
- English (U.K.) repeats the core set, because it is the English that Türkiye and most countries search. "organiser"
  is the U.K. spelling.
- Turkish is all Turkish. Türkiye already gets the English words from English (U.K.).

**Optional, for the U.S. only: Spanish (Mexico).** It reaches Spanish-speaking U.S. users and adds a second
100-character field. Use it only as a real Spanish page:
- Name: `Pastronaut: Portapapeles`
- Subtitle: `Copiar, pegar y sincronizar`
- Keywords: `historial,teclado,copiar,pegar,texto,notas,fragmento,plantilla,imagen,pdf,archivo,widget,mac`

**After launch:** follow the rankings for a few weeks, then replace the words that never move.

## 5. Promotional text [170] (can change any time, no review)
| | iPhone | Mac |
|---|---|---|
| **EN** | `Text, links, photos, PDFs and files from your Mac and iPhone, one tap away in any app. New in 1.3: pictures and files sync too, and the words inside them are searchable.` (169) | `Your clipboard history in the menu bar, now with screenshots, PDFs and files that sync to your iPhone. Preview with Space, filter by kind, paste a list in order.` (161) |
| **TR** | `Mac'inden ve iPhone'undan metin, bağlantı, fotoğraf, PDF ve dosya, her uygulamada bir dokunuşla. 1.3'te yeni: resimler ve dosyalar da eşitleniyor, içleri de aranıyor.` (166) | `Pano geçmişin menü çubuğunda; artık iPhone'unla eşitlenen ekran görüntüleri, PDF'ler ve dosyalarla. Space ile önizle, türe göre süz, listeyi sırayla yapıştır.` (158) |

English (U.K.) uses the English texts; only "organizer" becomes "organiser" if it appears.

## 6. Description: iPhone (1.3)
How the 1.3 texts are written (research in §1 and §14):
- **The first two lines sell.** Only about 170–255 characters show before "more". They say what you get (everything you
  copy, on both devices, pasted anywhere) and remove the first doubts (no account, no subscription, no tracking).
- **The description is not searched,** so it is written to convince, not stuffed with keywords (those are in §4).
- **Apple's marketing rules:** Apple product names are never set in capitals (so "ON YOUR iPhone TOO", not "IPHONE"),
  products are named instead of "iOS" or "macOS", and the other app is "Pastronaut for Mac / for iPhone".
- **Short benefit bullets,** one idea each; the honest iPhone limit (only the app on screen reads the clipboard)
  stays, said plainly.

About 2,993 characters in English and 3,163 in Turkish (limit 4,000). The 1.2 text is in git history.

### English
```
Everything you copy on iPhone and Mac — text, links, photos, PDFs and files — in one private history, with a keyboard that pastes any of it in any app. No account. No subscription. No tracking.

ONE CLIPBOARD, TWO DEVICES
– Copy on your Mac, find it on your iPhone a moment later, and the other way round
– Screenshots, photos, PDFs and files travel too, not just text
– It all syncs through your own iCloud; there are no Pastronaut servers
– Great on its own as well: Pastronaut for Mac is optional

PASTE ANYTHING, IN ANY APP
– The Pastronaut keyboard shows your clips as tidy thumbnails, newest first, with the latest copy from your Mac on top
– Tap a clip to type it; with Full Access, tap a photo or file to put it on the clipboard
– Paste a list in order: start a queue, and every tap types the next one

PHOTOS, PDFS AND FILES
– Screenshots and photos show as pictures, PDFs show their first page, files show their name and size
– The words inside images and PDFs are searchable: type "invoice", find the invoice
– Select text with Live Text, mark up a copy, save to Photos or Files, or share it
– You choose the largest item and how much iCloud space they may use

FIND IT IN SECONDS
– Search text, titles and the words inside pictures
– Filter by source (All, Mac, iPhone), by kind (links, code, addresses, images, PDFs and more) and by collection, all at once
– Give any clip a title so it's easy to spot

SAVE IN ONE TAP
iPhone lets only the app on screen read the clipboard, so Pastronaut makes saving a single tap:
– Open the app (Save Clipboard on Opening), or tap + and then Paste
– Share text, links, photos and files to Pastronaut, or tap "Save to Pastronaut" in the share sheet
– Use the Control Center button, Back Tap or the Action button
– Scan text or a document with the camera

EVERY KIND, ITS OWN CARD
– Addresses with a map and directions, links with a page preview, code in color, colors as swatches
– Call and Write Email buttons, and the icon of the Mac app a copy came from

PIN, COLLECT, ORGANIZE
– Pin what you reuse; keep addresses, snippets or a project's links in collections
– Combine clips into one, export a collection, undo a delete
– Keep History for a day, a week, a month, a year or forever

WIDGETS, CONTROLS AND SHORTCUTS
– Recent clips on the Home Screen, the latest on the Lock Screen
– Control Center: save the clipboard, or pause saving for a while
– Shortcuts: get, copy and save clips, and add them to a collection

PRIVATE BY DESIGN
– No account, no servers, no analytics, no ads
– Text, titles and files are encrypted on your device before they reach iCloud, end-to-end with Advanced Data Protection
– One-time codes, card numbers and IBANs are never saved automatically, and one switch keeps them off iCloud on every device
– Optional Face ID lock; your clips are covered while the screen is recorded

FREE AND OPEN SOURCE
No subscription, no in-app purchases, and the source code is public. Pastronaut for Mac is free on the Mac App Store.
```

### Türkçe
```
iPhone'da ve Mac'te kopyaladığın her şey — metin, bağlantı, fotoğraf, PDF ve dosya — tek bir özel geçmişte; klavyesi de istediğini her uygulamada yapıştırır. Hesap yok. Abonelik yok. İzleme yok.

TEK PANO, İKİ CİHAZ
– Mac'te kopyala, bir an sonra iPhone'unda bul; tersi de geçerli
– Yalnızca metin değil: ekran görüntüleri, fotoğraflar, PDF'ler ve dosyalar da gider gelir
– Hepsi kendi iCloud'un üzerinden eşitlenir; Pastronaut'un sunucusu yok
– Tek başına da harika: Pastronaut for Mac isteğe bağlı

HER ŞEYİ, HER UYGULAMADA YAPIŞTIR
– Pastronaut klavyesi öğelerini en yenisi başta, düzenli küçük resimlerle gösterir; Mac'ten gelen son kopya en üstte
– Bir öğeye dokun, yazılsın; Tam Erişim'le bir fotoğrafa ya da dosyaya dokun, panoya gitsin
– Bir listeyi sırayla yapıştır: sırayı başlat, her dokunuş sıradakini yazsın

FOTOĞRAFLAR, PDF'LER VE DOSYALAR
– Ekran görüntüleri ve fotoğraflar resim olarak, PDF'ler ilk sayfasıyla, dosyalar adı ve boyutuyla görünür
– Görsellerdeki ve PDF'lerdeki kelimeler aranabilir: "fatura" yaz, faturayı bul
– Canlı Metin'le metni seç, bir kopyasını işaretle, Fotoğraflar'a ya da Dosyalar'a kaydet, paylaş
– En büyük öğeyi ve ne kadar iCloud alanı kullanacaklarını sen seçersin

SANİYELER İÇİNDE BUL
– Metinde, başlıklarda ve resimlerin içindeki kelimelerde ara
– Kaynağa (Tümü, Mac, iPhone), türe (bağlantı, kod, adres, görsel, PDF ve fazlası) ve koleksiyona göre, hepsi birlikte süz
– Her öğeye bir başlık ver, kolayca göze çarpsın

TEK DOKUNUŞLA KAYDET
iPhone panoyu yalnızca ekrandaki uygulamanın okumasına izin verir; Pastronaut kaydetmeyi tek dokunuşa indirir:
– Uygulamayı aç (Açılınca Panoyu Kaydet) ya da +'ya, ardından Yapıştır'a dokun
– Metni, bağlantıyı, fotoğrafı ve dosyayı Pastronaut'la paylaş ya da paylaşım sayfasında "Pastronaut'a Kaydet"e dokun
– Denetim Merkezi düğmesini, Arkaya Dokun'u ya da Eylem düğmesini kullan
– Kamerayla metin ya da belge tara

HER TÜRE KENDİ KARTI
– Haritası ve yol tarifiyle adresler (Türk adreslerini de tanır), sayfa önizlemesiyle bağlantılar, renkli kod, renk örnekleri
– Ara ve E-posta Yaz düğmeleri; Mac'ten gelen kopyada geldiği uygulamanın simgesi

SABİTLE, KOLEKSİYONLA, DÜZENLE
– Sık kullandığını sabitle; adresleri, parçacıkları ya da bir projenin bağlantılarını koleksiyonlarda tut
– Öğeleri birleştir, bir koleksiyonu dışa aktar, silmeyi geri al
– Geçmişi bir gün, bir hafta, bir ay, bir yıl ya da süresiz sakla

WIDGET'LAR, DENETİMLER VE KESTİRMELER
– Ana Ekran'da son öğeler, Kilitli Ekran'da en sonuncusu
– Denetim Merkezi: panoyu kaydet ya da kaydetmeyi bir süre duraklat
– Kestirmeler: öğe al, kopyala, kaydet ve koleksiyona ekle

GİZLİLİK ÖNCELİKLİ
– Hesap yok, sunucu yok, analiz yok, reklam yok
– Metinler, başlıklar ve dosyalar iCloud'a gitmeden önce cihazında şifrelenir; Gelişmiş Veri Koruması açıksa uçtan uca
– Tek kullanımlık kodlar, kart numaraları ve IBAN'lar kendiliğinden kaydedilmez; tek bir anahtar onları her cihazda iCloud'un dışında tutar
– İsteğe bağlı Face ID kilidi; ekran kaydedilirken öğelerin örtülür

ÜCRETSİZ VE AÇIK KAYNAK
Abonelik yok, uygulama içi satın alma yok, kaynak kodu herkese açık. Pastronaut for Mac, Mac App Store'da ücretsiz.
```

## 7. Description: Mac (for the Mac App Store, 1.3)
Rewritten for 1.3: the 1.0 text didn't know images, PDFs and files sync, the new filter menu, titles or the plain
Advanced settings. Same rules as §6. About 2,163 characters in English and 2,239 in Turkish.

### English
```
Everything you copy — text, links, screenshots, PDFs and files — in a fast history in your menu bar, and on your iPhone too. No account. No subscription. No tracking.

NEVER LOSE A COPY
– Press ⇧⌘C, type to search, Return to copy, ⌥Return to paste right where you were typing
– Colored icons for links, code, emails, phone numbers, addresses, colors, images, PDFs and files
– Copies that password managers mark as concealed are never saved

LOOK BEFORE YOU PASTE
– Press Space for a preview that fits: code in color, color swatches, the picture itself, open a link, get directions
– Text in screenshots and PDFs is recognized, so you can find them by their words

FIND IT FAST
– One filter menu for source (All, This Mac, iPhone), kind and collection; what you pick shows as chips you can remove
– Or type filters into the search: type:link, app:Safari, date:yesterday, from:iphone
– ⌘G jumps from a result to its place in your history

PASTE A LIST, IN ORDER
– Select a few items, press Return, and every ⌘V pastes the next one; made for forms and repetitive work
– Paste as plain text whenever you want formatting gone

ON YOUR iPhone TOO
– Copy a screenshot here and it's on your iPhone a moment later; save a photo there and it's in your history here
– Pins, titles and collections stay in step, and privacy switches are set once for both
– Pastronaut for iPhone adds a keyboard that pastes your history in any app

KEEP WHAT MATTERS
– Pin items, keep collections, give items a title
– Pause copying, or ignore only the next copy, from the menu bar icon or Settings
– Undo a delete with ⌘Z; hide Pastronaut while you share your screen

PRIVATE BY DESIGN
– No account, no servers, no analytics, no ads
– Text and files are encrypted on your Mac before they reach iCloud, end-to-end with Advanced Data Protection
– Keep one-time codes and card numbers out of sync, or sync only what you pin
– Choose the largest image or file and how much iCloud space they may use, or keep them on this Mac

FREE AND OPEN SOURCE
No subscription and no in-app purchases. Based on Maccy (not affiliated); the source code is public. Pastronaut for iPhone is free on the App Store.
```

### Türkçe
```
Kopyaladığın her şey — metin, bağlantı, ekran görüntüsü, PDF ve dosya — menü çubuğunda hızlı bir geçmişte; iPhone'unda da. Hesap yok. Abonelik yok. İzleme yok.

HİÇBİR KOPYAYI KAYBETME
– ⇧⌘C'ye bas, yazarak ara, Return ile kopyala, ⌥Return ile tam yazdığın yere yapıştır
– Bağlantı, kod, e-posta, telefon, adres, renk, görsel, PDF ve dosya için renkli simgeler
– Parola yöneticilerinin gizli diye işaretlediği kopyalar hiç kaydedilmez

YAPIŞTIRMADAN ÖNCE BAK
– Space'e bas, türe uygun önizleme açılsın: renkli kod, renk örneği, resmin kendisi, bağlantıyı aç, yol tarifi al
– Ekran görüntülerindeki ve PDF'lerdeki metin tanınır; onları içindeki kelimelerle bulursun

HIZLA BUL
– Kaynak (Tümü, Bu Mac, iPhone), tür ve koleksiyon için tek bir süzgeç menüsü; seçtiklerin kaldırılabilir etiketler olarak görünür
– Ya da aramaya süzgeç yaz: tür:bağlantı, uygulama:Safari, tarih:dün, cihaz:iphone
– ⌘G ile sonuçtan geçmişteki yerine atla

LİSTEYİ SIRAYLA YAPIŞTIR
– Birkaç öğe seç, Return'e bas; her ⌘V sıradakini yapıştırır, formlar ve tekrarlı işler için
– İstediğinde biçimsiz düz metin olarak yapıştır

iPhone'UNDA DA
– Burada bir ekran görüntüsü kopyala, bir an sonra iPhone'unda olsun; orada bir fotoğraf kaydet, buradaki geçmişine düşsün
– Sabitlemeler, başlıklar ve koleksiyonlar uyumlu kalır; gizlilik anahtarlarını iki cihaz için bir kez ayarlarsın
– Pastronaut for iPhone, geçmişini her uygulamada yapıştıran bir klavye ekler

ÖNEMLİLERİ SAKLA
– Sabitle, koleksiyon tut, öğelere başlık ver
– Kopyalamayı duraklat ya da yalnızca sonraki kopyayı yok say: menü çubuğu simgesinden ya da Ayarlar'dan
– Silmeyi ⌘Z ile geri al; ekran paylaşırken Pastronaut'u gizle

GİZLİLİK ÖNCELİKLİ
– Hesap yok, sunucu yok, analiz yok, reklam yok
– Metinler ve dosyalar iCloud'a gitmeden önce Mac'inde şifrelenir; Gelişmiş Veri Koruması açıksa uçtan uca
– Tek kullanımlık kodları ve kart numaralarını eşitlemenin dışında tut ya da yalnızca sabitlediklerini eşitle
– En büyük görseli ya da dosyayı ve ne kadar iCloud alanı kullanacaklarını seç ya da onları bu Mac'te tut

ÜCRETSİZ VE AÇIK KAYNAK
Abonelik yok, uygulama içi satın alma yok. Maccy'ye dayanır (onunla bağlantılı değildir); kaynak kodu herkese açık. Pastronaut for iPhone, App Store'da ücretsiz.
```

## 8. What's New
### 1.0
- iPhone EN: `First release: your clipboard history, a keyboard that pastes it in any app, and sync with your Mac.`
- iPhone TR: `İlk sürüm: pano geçmişin, onu her uygulamada yapıştıran bir klavye ve Mac'inle eşitleme.`

### 1.1 (iPhone only; build 3)
Light and a little playful. Same English text for English (U.S.) and English (U.K.).

English:
```
Pastronaut 1.1: fewer mysteries, more clipboard.

• A new setup guide walks you through the keyboard, Full Access and Paste from Other Apps, with buttons that jump straight to Settings. No treasure map needed.
• Try the keyboard and the paste permission right inside the guide, and see them turn green.
• Pick your language (English or Türkçe) and your theme (System, Light or Dark) in Settings.
• Your history now shows up the moment you open the app. The "No clips yet" ghost has left the building.
• Scrolled down? New clips from your Mac wait politely at the top (↑ 3 new) instead of pushing your list around.
• A small "Syncing…" badge lets you know iCloud is on it.
• Full Access is now recognized once you open the keyboard, so Settings stops saying "Not finished" when it is.
• Link previews and Save Clipboard on Opening now start on. Prefer them off? One switch in Settings.
```

Türkçe:
```
Pastronaut 1.1: daha az gizem, daha çok pano.

• Yeni kurulum rehberi klavyeyi, Tam Erişim'i ve Diğer Uygulamalardan Yapıştır iznini adım adım anlatıyor; düğmeler seni doğrudan Ayarlar'a götürüyor. Hazine haritasına gerek yok.
• Klavyeyi ve yapıştırma iznini rehberin içinde dene, yeşile döndüklerini gör.
• Dili (Türkçe ya da English) ve temayı (Sistem, Açık, Karanlık) Ayarlar'dan seç.
• Geçmişin artık uygulamayı açtığın anda karşında. "Henüz öğe yok" hayaleti binayı terk etti.
• Listenin aşağısındayken Mac'ten gelen yeni kopyalar araya dalmıyor; en üstte kibarca sırasını bekliyor (↑ 3 yeni).
• Küçük bir "Eşitleniyor…" rozeti iCloud'un iş başında olduğunu haber veriyor.
• Klavyeyi bir kez açınca Tam Erişim tanınıyor; Ayarlar artık açıkken "Tamamlanmadı" demiyor.
• Bağlantı önizlemeleri ve Açılınca Panoyu Kaydet artık açık başlıyor. Kapalı mı seversin? Ayarlar'da tek dokunuş.
```

### 1.2 (iPhone only; build 4)
Same light tone as 1.1. App Store Connect refuses some symbols here ("This field contains one or more invalid
characters"): "✕" (U+2715) was one, so the text says "X key", and "›" is avoided to be safe. Bullets (•) and
"↑" were accepted in 1.1. Same English text for English (U.S.) and English (U.K.).

English:
```
Pastronaut 1.2: a fresh coat of paint and a pocket full of new tricks.

• A new look: your history is a tidy grid of equal cards with page and map thumbnails, and the list got a makeover too. The keyboard matches.
• Scan Text and Scan Document: touch and hold + and point the camera. The text is read right on your iPhone.
• Give a clip a title, so "that address" finally has a name. Titles show up in search.
• Paste a list in order: select clips, choose More, then Start Queue, and the keyboard types them one by one, oldest first. The X key ends it early.
• Combine & Copy joins the clips you select into one, and saves the result as a new clip.
• "Save to Pastronaut" now lives in the share sheet's actions. Share several links at once, and drop them into a collection right after saving.
• Pause Saving for 15 minutes, an hour or longer, from Settings or Control Center.
• Your clips are covered while the screen is recorded, and can hide in the app switcher too.
• Keep one-time codes and card numbers on this iPhone only, if you prefer.
• Deleted by mistake? Undo. Every clip's menu also has Show in History, Open Link and Edit.
• Export a single collection as a file.
• Clearing iCloud no longer takes your clips with it: they stay "Only on This iPhone" until you upload them again.
```

Türkçe:
```
Pastronaut 1.2: yeni bir kat boya ve cep dolusu yeni numara.

• Yeni görünüm: geçmişin sayfa ve harita küçük resimli, eşit kartlardan oluşan düzenli bir ızgara; liste de yenilendi. Klavye de onlara uydu.
• Metni Tara ve Belge Tara: +'ya basılı tut, kamerayı tut. Metin doğrudan iPhone'unda okunuyor.
• Öğelere başlık ver; "o adres"in nihayet bir adı olsun. Başlıklar aramada da çıkıyor.
• Bir listeyi sırayla yapıştır: öğeleri seç, Diğer'den Sırayı Başlat'ı seç; klavye onları en eskisinden başlayarak tek tek yazsın. X tuşuyla erken bitir.
• Birleştirip Kopyala seçtiğin öğeleri tek metinde topluyor ve sonucu yeni bir öğe olarak kaydediyor.
• "Pastronaut'a Kaydet" artık paylaşım sayfasının eylemlerinde. Birkaç bağlantıyı birden paylaş, kaydeder kaydetmez bir koleksiyona at.
• Kaydetmeyi 15 dakika, bir saat ya da daha uzun süre duraklat: Ayarlar'dan ya da Denetim Merkezi'nden.
• Ekran kaydedilirken öğelerin örtülüyor; istersen uygulama değiştiricide de gizleniyor.
• İstersen tek kullanımlık kodları ve kart numaralarını yalnızca bu iPhone'da tut.
• Yanlışlıkla mı sildin? Geri Al. Her öğenin menüsünde artık Geçmişte Göster, Bağlantıyı Aç ve Düzenle de var.
• Tek bir koleksiyonu dosya olarak dışa aktar.
• iCloud'u temizlemek artık öğelerini de götürmüyor: yeniden yükleyene kadar "Yalnızca Bu iPhone'da" kalıyorlar.
```

### 1.3 (iPhone build 5, Mac build 2)
Light and a little playful, like 1.1 and 1.2. No "✕" or "›" (App Store Connect refused "✕" in 1.2); bullets (•) are
fine. Same English text for English (U.S.) and English (U.K.).

**The Mac's jump from 1.0 to 1.3** is explained in its first lines: the iPhone app went through 1.1 and 1.2, and from
1.3 both apps share one version number. GitHub users come from 0.1.0; their release notes (Sparkle, Adım 7) say the
same with "0.1.0".

iPhone, English (1,353):
```
Pastronaut 1.3: your clipboard learned to carry pictures.

• Photos, screenshots, PDFs and files now travel between your Mac and your iPhone. Copy a screenshot on the Mac, and it's on your iPhone before your coffee cools.
• The words inside images and PDFs are searchable. Type "invoice", find the invoice. Revolutionary, we know.
• Open a picture to select its text with Live Text, mark up a copy, save it to Photos or Files, or share it.
• A new filter bar: All, Mac and iPhone in one glass capsule you can slide your finger along, and a filter button for every kind (PDFs included) and your collections. Mix them freely.
• The + button now holds Paste, Type a Clip, Scan Text and Scan Document. Paste shows up only when there's something to paste.
• Settings has a new Images & Files page: the largest item, how much iCloud space to use, and image quality.
• Privacy switches are now shared with your Mac. Set them once, enjoy them twice.
• Cards from your Mac show the icon of the app they came from.
• Keep History: let old clips go after a day, a week, a month or a year. Pinned clips and collections stay.
• The setup guide was rebuilt: one task at a time, one big button, no scrolling treasure hunt. It even checks the paste permission by itself.
• Sync got sturdier, thanks to a very picky test that tossed copies between two devices for hours.
```

iPhone, Türkçe (1,409):
```
Pastronaut 1.3: panon resim taşımayı öğrendi.

• Fotoğraflar, ekran görüntüleri, PDF'ler ve dosyalar artık Mac'inle iPhone'un arasında gidip geliyor. Mac'te bir ekran görüntüsü kopyala; kahven soğumadan iPhone'unda.
• Görsellerdeki ve PDF'lerdeki kelimeler aranabiliyor. "Fatura" yaz, faturayı bul. Devrim niteliğinde, biliyoruz.
• Bir resmi aç: Canlı Metin'le metnini seç, bir kopyasını işaretle, Fotoğraflar'a ya da Dosyalar'a kaydet ya da paylaş.
• Yeni süzgeç çubuğu: Tümü, Mac ve iPhone parmağınla kaydırabildiğin tek bir cam kapsülde; yanındaki süzgeç düğmesinde her tür (PDF'ler dahil) ve koleksiyonların. Dilediğin gibi birleştir.
• + düğmesinde artık Yapıştır, Yazarak Ekle, Metni Tara ve Belge Tara var. Yapıştır yalnızca yapıştıracak bir şey varken görünüyor.
• Ayarlar'da yeni bir Görseller ve Dosyalar sayfası: en büyük öğe, ne kadar iCloud alanı kullanılacağı ve görsel kalitesi.
• Gizlilik anahtarları artık Mac'inle ortak. Bir kez ayarla, iki cihazda keyfini sür.
• Mac'ten gelen kartlarda geldiği uygulamanın simgesi var.
• Geçmişi Sakla: eski öğeler bir gün, bir hafta, bir ay ya da bir yıl sonra gitsin. Sabitlenenler ve koleksiyondakiler kalır.
• Kurulum rehberi baştan yapıldı: her seferinde tek iş, tek büyük düğme, kaydırmalı hazine avı yok. Yapıştırma iznini de kendisi kontrol ediyor.
• Eşitleme sağlamlaştı; iki cihaz arasında saatlerce kopya atıp tutan çok titiz bir test sayesinde.
```

Mac, English (1,154):
```
Pastronaut for Mac 1.3. Yes, straight from 1.0: the iPhone app took 1.1 and 1.2 for a spin, and from now on both apps share one version number. The Mac didn't miss a thing; it just arrived fashionably late.

• Screenshots, images, PDFs and files now sync with your iPhone. Copy one here, find it there.
• Text in screenshots and PDFs is searchable on both devices.
• A new filter bar: All, This Mac and iPhone in one capsule, and a filter button for every kind, your collections, pins and dates. What you pick shows as chips you can remove.
• Give items a title, and titles you give on your iPhone show here too.
• A new Images & Files section in Settings: sync on or off, the largest item, iCloud space and image quality.
• Privacy switches are shared with your iPhone. Set them once.
• Advanced settings in plain words: Pause Copying and Ignore Only the Next Copy. The command-line tricks are still there, tucked away.
• The history limit now removes only this Mac's own copies from iCloud; what you copied on your iPhone stays there.
• Fixes: pins that arrive from your iPhone are kept, and copying something again moves it to the top on both devices.
```

Mac, Türkçe (1,240):
```
Pastronaut for Mac 1.3. Evet, 1.0'dan doğrudan 1.3'e: 1.1 ve 1.2'yi iPhone uygulaması bizim için denedi, bundan sonra iki uygulama aynı sürüm numarasını taşıyor. Mac hiçbir şey kaçırmadı; yalnızca şık bir gecikmeyle geldi.

• Ekran görüntüleri, görseller, PDF'ler ve dosyalar artık iPhone'unla eşitleniyor. Burada kopyala, orada bul.
• Ekran görüntülerindeki ve PDF'lerdeki metin iki cihazda da aranabiliyor.
• Yeni süzgeç çubuğu: Tümü, Bu Mac ve iPhone tek bir kapsülde; yanındaki süzgeç düğmesinde her tür, koleksiyonların, sabitlenenler ve tarihler. Seçtiklerin kaldırılabilir etiketler olarak görünüyor.
• Öğelere başlık ver; iPhone'da verdiğin başlıklar da burada görünüyor.
• Ayarlar'da yeni Görseller ve Dosyalar bölümü: eşitlemeyi aç ya da kapat, en büyük öğe, iCloud alanı ve görsel kalitesi.
• Gizlilik anahtarları iPhone'unla ortak. Bir kez ayarla.
• Gelişmiş ayarlar artık anlaşılır: Kopyalamayı Duraklat ve Yalnızca Sonraki Kopyayı Yok Say. Komut satırı numaraları hâlâ orada, bir kenarda.
• Geçmiş sınırı artık iCloud'dan yalnızca bu Mac'in kendi kopyalarını siliyor; iPhone'da kopyaladıkların orada kalıyor.
• Düzeltmeler: iPhone'dan gelen sabitlemeler korunuyor; bir şeyi yeniden kopyalayınca iki cihazda da en üste çıkıyor.
```

## 9. Pictures
All pictures use made-up clips only (`PT_DEMO`; `DemoClips.swift`). They are made in four steps:
1. iPhone shots, in each language: SyncStepTests `storeShots12` (`PT_SHOTS_LANG` = en / tr). It passes
   `-appearance system`, so the app's own theme setting can't turn the dark shots light.
2. Mac shots: MaccyUITests `testPastronautReadmeShots`. In test mode only, each copy names a plausible source app
   (`TestSourceApp`).
3. Raw shots go to `appstore-screenshots/raw/<lang>/12-…png` and `raw/mac/` (not in git).
4. Compose them: `cd scripts/store && swift run -c release StoreArt ../../appstore-screenshots/raw ../../appstore-screenshots/store`.

The output is opaque PNGs in `appstore-screenshots/store/<lang>/`. Upload the English set to English (U.S.) and
English (U.K.), and the Turkish set to Turkish.

### 1.3 set (built 2026-10-24; upload with 1.3)
How to make it:
1. iPhone, per language: SyncStepTests `storeShots13` (`TEST_RUNNER_PT_SHOTS_LANG` = en / tr) → `s13-<lang>-….png`.
2. Mac: MaccyUITests `testPastronaut13StoreShots` (quit the real Pastronaut first; `PT_SHOTS_LANGS`) → `m13-….png`.
3. Raw shots in `appstore-screenshots/raw13/{en,tr,mac}/` (not in git).
4. `cd scripts/store && swift run -c release StoreArt bezel13 ../../appstore-screenshots/raw13
   ../../appstore-screenshots/bezels ../../appstore-screenshots/store13` → `store13/<lang>/iphone-1…10.png`
   (1320 × 2868) and `mac-1…6.png` (2880 × 1800), opaque.

Research behind it (sources in §14):
- Only the first three frames show in search results, so they carry the story: sync, the new kinds, the keyboard.
- One message per frame, a caption of at most ~6 words above the device, readable at thumbnail size.
- Device frames: **Apple's own bezels** (Apple Design Resources: iPhone 18 Pro Max Silver/Black, MacBook Air M5
  13-inch Sky Blue), used as they are: never tilted, cropped or shadowed; the caption beside the device, not on it;
  true relative size when the Mac and the iPhone stand together (Mac frame 2). The license allows them only in
  mock-ups of apps for Apple platforms, not on the website or in the README; the files stay in
  `appstore-screenshots/bezels/` (not in git) and are never shared.
- **Bezel or not** (user's choice): the iPhone frames and Mac frames 1–2 show the whole device; Mac frames 3–6 show
  the right part of the real screen (menu bar, popup and what opens beside it) at its own size, without a bezel,
  so the popup can be read.
- **Sheets on the iPhone** (frames 3, 8, 10): iOS dims the screen above a sheet; inside the taller iPhone 18 bezel
  that band read as a grey stripe, so `StoreArt` gives it the sheet's own color (status bar glyphs kept). Nothing
  else in a screenshot is changed.
- **Real screens** (2026-10-24, the user's choice): status bar and menu bar as they are, nothing redrawn. iPhone
  shots on an iPhone 14 Pro Max with Do Not Disturb on; Mac shots of the whole screen of a MacBook Air at the
  1470 × 956 scale, other apps hidden, TextEdit in front in the shot's language (so the menu bar matches).
- **Made-up content only**: `PT_DEMO` on the iPhone (DemoClips, DemoMedia: a boarding pass screenshot, a holiday
  drawing, a concert poster whose words exist only in the picture, an invoice PDF, three files); the Mac test copies
  the same items (`MaccyUITests/DemoArt.swift`) into its in-memory history. No app icons in the pictures: Apple's
  rules don't allow Apple app icons in marketing, so clips show letter badges.
- Sizes: iPhone 1320 × 2868 (6.9"; App Store Connect scales it down for smaller phones). Mac 2880 × 1800. Opaque PNG.
- Same order, palette and pictures in both languages; only the captions and the app language change.

**iPhone, `iphone-1…10.png`**
| # | Eyebrow | English | Turkish | Picture |
|---|---|---|---|---|
| 1 | SYNC · EŞİTLE | Copy on your Mac, paste on your iPhone | Mac'te kopyala, iPhone'da yapıştır | History with Mac clips, a picture from the Mac on top |
| 2 | NEW · YENİ | Photos, PDFs and files, too | Fotoğraf, PDF ve dosya da | Grid: image, PDF and file cards beside text cards |
| 3 | PASTE · YAPIŞTIR | Paste anything, in any app | Her kopya, her uygulamada | Keyboard with an image tile, "Copied" message |
| 4 | FIND · BUL | Find the words inside pictures | Resimdeki yazıyı bile bul | Search hit inside a screenshot's text |
| 5 | FILTER · SÜZ | Source, kind, collection: one tap | Kaynak, tür, koleksiyon: tek dokunuş | Scope bar with the Kind submenu open |
| 6 | LOOK · BAK | Select text, mark up, save | Yazıyı seç, işaretle, kaydet | An image open full screen with its actions |
| 7 | SMART CARDS · AKILLI KARTLAR | Every kind, its own card | Her türe kendi kartı | Map, code and link cards (dark) |
| 8 | QUEUE · SIRA | Paste a list, in order | Bir listeyi sırayla yapıştır | Keyboard queue (dark) |
| 9 | ORGANIZE · DÜZENLE | Pin it, name it, collect it | Sabitle, adlandır, topla | A clip's menu with title and collections |
| 10 | PRIVATE · GİZLİ | No account. No tracking. | Hesap yok. İzleme yok. | Settings: encryption note and privacy switches |

**Mac, `mac-1…6.png`**
| # | Eyebrow | English | Turkish | Picture |
|---|---|---|---|---|
| 1 | PASTRONAUT | Your clipboard history, one click away | Pano geçmişin, bir tık uzağında | Menu bar history with image and PDF rows |
| 2 | SYNC · EŞİTLE | Copy on one, paste on the other | Birinde kopyala, ötekinde yapıştır | MacBook and iPhone side by side, true to size |
| 3 | PREVIEW · ÖNİZLE | Press Space to look closer | Space'e bas, yakından bak | Image or PDF preview |
| 4 | FILTER · SÜZ | Filter by device, kind or collection | Cihaza, türe, koleksiyona göre süz | Filter menu with the Kind submenu and chips |
| 5 | FIND · BUL | Find screenshots by their words | Ekran görüntüsünü yazısıyla bul | Search hit in a screenshot's text |
| 6 | QUEUE · SIRA | Paste a list, in order | Bir listeyi sırayla yapıştır | Three items queued |

### 1.2 set (live) · iPhone: `iphone-1…10.png`, 1320 × 2868 (upload in this order; ten is App Store Connect's limit)
Each frame shows the whole phone (a body drawn from simple shapes, a clean "9:41" status bar), a large caption, and
enlarged pieces of the same real screen ("callouts", positions in `Gallery.swift`). One orbit line with stars runs
through all ten frames. Light and dark frames alternate.

| # | Eyebrow | English | Turkish | Picture |
|---|---|---|---|---|
| 1 | PASTRONAUT | Your clipboard, on iPhone and Mac | Panon, iPhone'da ve Mac'te | Panorama, left: the card grid in front of the Mac window |
| 2 | SYNC · EŞİTLE | Copy on your Mac, paste on your iPhone | Mac'te kopyala, iPhone'da yapıştır | Panorama, right: the Mac window, an iPhone showing Mac clips (dark) |
| 3 | PASTE · YAPIŞTIR | Paste anything, in any app | Her kopya, her uygulamada | Keyboard; callout: "From Mac" bar and tiles |
| 4 | QUEUE · SIRA | Paste a list, in order | Bir listeyi sırayla yapıştır | Keyboard queue (dark); callout: the queue bar |
| 5 | SMART CARDS · AKILLI KARTLAR | Every kind, its own card | Her türe kendi kartı | Cards (dark); callouts: map card, code card with title |
| 6 | SCAN · TARA | Scan text with your camera | Kamerayla metin tara | Touch and hold +; callout: Scan Document / Scan Text |
| 7 | TITLES · BAŞLIKLAR | Name it, edit it, find it again | Adını koy, düzenle, bul | A clip's menu; callout: Edit Title, Edit |
| 8 | FIND · BUL | Find any copy in seconds | Aradığını saniyede bul | Search (dark); callout: kind and date filters |
| 9 | ORGANIZE · DÜZENLE | Collect, combine, export | Topla, birleştir, dışa aktar | Select mode; callouts: a selected card, Combine & Copy / Start Queue |
| 10 | PRIVATE · GİZLİ | No account. No tracking. | Hesap yok. İzleme yok. | Settings; callout: the privacy switches |

The 1.0–1.1 set (seven frames, screens cropped at the bottom) is in git history.

### 1.2 set (live) · Mac: `mac-1…5.png`, 2880 × 1800 (for the Mac App Store)
| # | Eyebrow | English | Turkish | Picture |
|---|---|---|---|---|
| 1 | PASTRONAUT | Your clipboard, on Mac and iPhone | Panon, Mac'te ve iPhone'da | Panorama, left: the menu bar history |
| 2 | SYNC · EŞİTLE | Copy on one, paste on the other | Birinde kopyala, ötekinde yapıştır | Panorama, right: the iPhone beside the Mac window |
| 3 | PREVIEW · ÖNİZLE | Press Space to look closer | Space'e bas, yakından bak | Code preview |
| 4 | QUEUE · SIRA | Paste a list, in order | Bir listeyi sırayla yapıştır | Three items queued |
| 5 | FIND · BUL | Type a filter, find it fast | Süzgeci yaz, hemen bul | `type:code` / `tür:kod` results |

### Header and search result for 1.3 (`store13/<lang>/header.png`, `search.png`; made by `StoreArt bezel13`)
Same rules as the 1.3 frames: Apple's iPhone bezels, straight and whole, real 1.3 screens, made-up content. Only
iPhones (these pictures are for the iPhone product page; a Mac at true size next to them would be tiny). Pills for
1.3: Paste keyboard, Photos & PDFs, Text in pictures, Mac sync.
- **`header.png`, 3840 × 1646, dark:** wordmark, "Every copy, one tap away." / "Her kopya, bir dokunuş uzağında."
  and the pills in the centered safe area (1646 × 661); two iPhones on each side (search, history, cards, queue)
  as decoration that narrow screens may cut.
- **`search.png`, 3840 × 2560, light:** everything inside the centered safe area (2168 × 1030) with a margin: on the
  left the wordmark, "Clipboard history + paste keyboard" / "Pano geçmişi ve yapıştırma klavyesi", "Text, photos,
  PDFs and files. iPhone and Mac, in your own iCloud." and the pills; on the right the history and a picture's
  detail (the poster with the text read from it).

### Header and search result of 1.2 (live until 1.3; optional, iOS 27 and later; can change without a new version)
Redone for 1.2 in the gallery's style (`Gallery.swift`: `HeaderArt2`, `SearchArt2`): drawn phone bodies, one orbit
line with stars, four feature pills (Paste keyboard, Smart cards, Scan text, Mac sync).
- **`header.png`, 3840 × 1646 (21:9), dark:**
  - In the centered safe area (1646 × 661): the wordmark, "Every copy, one tap away." / "Her kopya, bir dokunuş
    uzağında." and the pills.
  - Decoration at the sides, may be cropped: the Mac window (left), the queue and the dark cards on two phones (right).
- **`search.png`, 3840 × 2560 (3:2), light:** it "states the obvious". Everything that matters is inside the
  centered safe area (2168 × 1030):
  - left: the wordmark, "Clipboard history + paste keyboard" / "Pano geçmişi ve yapıştırma klavyesi", "for iPhone
    and Mac, synced in your iCloud" and the pills in two rows;
  - right: two phones (cards, keyboard).
  - The Mac window behind them is decoration and may be cropped.

### Rules followed
- every frame shows the real app; callouts are enlarged parts of the same screenshot;
- no prices, "free", URLs, awards, ratings or other platforms;
- the iPhone status bar is removed;
- 4+ content only;
- same palette, type and order in both languages.

### iPad
Not needed: the first release is iPhone-only. iPad comes back after it is tested in the simulator.

## 10. App Privacy
- **Do you or your third-party partners collect data from this app?** → **No.** The label becomes "Data Not
  Collected".
  - Data in the user's own CloudKit private database and Apple Maps lookups are Apple's services.
  - Crash reports shared through Apple's opt-in aren't "collected" by the developer.
- **Tracking:** No.
- **Privacy manifest:** in the iPhone app, keyboard, widgets, Share and Save to Pastronaut (action, 1.2) extensions,
  and in the Mac App Store build.
- **Camera (1.2):** used only while the user scans text or a document; the text is read on the device and nothing
  is stored or sent. Still "Data Not Collected".
- **Images, PDFs and files (1.3):** stored on the user's devices and, with sync on, in their private iCloud database,
  encrypted on the device. The developer receives nothing: still "Data Not Collected".
- **Photos (1.3):** add-only permission (`NSPhotoLibraryAddUsageDescription`), asked when the user saves an image to
  Photos; the library is never read. Nothing to declare.

## 11. Age rating (expected 4+)
- **Features:** No to every question:
  - Parental Controls, Age Assurance;
  - Unrestricted Web Access (links open in Safari);
  - User-Generated Content (clips go only to the user's own devices);
  - Social Media, Messaging and Chat, Advertising.
- **Content:** None to everything; No for Gambling and Loot Boxes.
- **Age Categories and Override:** Not Applicable. Leave the Age Suitability URL empty.

## 12. Encryption
`ITSAppUsesNonExemptEncryption = NO`: the app uses only the encryption built into Apple's OS (CloudKit encrypted fields,
HTTPS). Not legal advice.

## 13. App Review notes
### iPhone (1.3)
The 1.2 text below, plus this block after the 1.2 block:
```
New in 1.3:
- Images, PDFs and files: saved from the clipboard (the system Paste button in the + menu at the bottom, or Save Clipboard on Opening), from the Share sheet and "Save to Pastronaut", and from Scan Document. With iCloud sync they go to the user's private CloudKit database; file contents are encrypted on the device before upload. Settings › Sync › Images & Files sets the largest item and the iCloud space they may use.
- Photos: add-only permission, asked only when the user taps "Save to Photos" on an image. The app never reads the photo library.
- Text in images and PDFs is recognized on the device (Apple's text recognition and PDFKit) so it can be searched. Nothing is sent anywhere for this.
- Keyboard: tapping a text clip types it, as before, with or without Full Access. Tapping an image or file puts it on the clipboard; that needs Full Access, and without it the keyboard shows a short explanation instead.
- Paste moved from the top bar into the + menu. It is the system Paste button and appears only while the clipboard holds something.
- App icons on cards come from the user's own Mac through the same private iCloud database.
```

### Mac (1.3)
The Mac text below, plus:
```
New in 1.3:
- With iCloud sync on (off until the user turns it on in Settings › Sync), images, PDFs and files copied on the Mac sync to the user's iPhone, and the iPhone's reach this Mac. File contents are encrypted on the Mac before upload. Settings › Sync › Images & Files can turn this off and sets the largest item and the iCloud space.
- A file copied in Finder is read at the moment it is copied, inside the app sandbox. For files in Desktop, Documents or Downloads macOS may ask once for access to that folder; without it the item stays on this Mac only.
- Text in screenshots and PDFs is recognized on the Mac (Apple's text recognition and PDFKit) for search.
- Settings › Advanced: Pause Copying and Ignore Only the Next Copy (the same switches as Option-click and Option-Shift-click on the menu bar icon).
```

### iPhone (1.2)
The 1.1 text below, plus this block after "The app can be shown in English or Turkish":
```
New in 1.2:
- Camera: used only for Scan Text and Scan Document (touch and hold the + button at the bottom of the history). Text recognition runs on the device; no photo or video is stored or sent. The camera permission is asked the first time a scan starts.
- "Save to Pastronaut" is an Action extension in the share sheet. Like the Share extension, it saves the shared text or links to the user's history; nothing else is read.
- Hide During Screen Recording is on by default. If you record the screen while reviewing, the history is covered with a notice; tap "Show Anyway", or turn it off in Settings › Privacy.
- Pause Saving (Settings, or the Control Center control) stops automatic saving for the chosen time. Explicit saves still work.
- Paste a list in order: in the history tap Select, choose some clips, then More › Start Queue. In the Pastronaut keyboard a wide key then types the next clip on each tap.
```

### iPhone (1.1)
```
Pastronaut is a clipboard manager and clipboard keyboard for iPhone. It works on its own; the Mac app is optional. No account or sign-in is needed.

On first launch a short setup guide explains the keyboard, Full Access (optional) and the system setting Paste from Other Apps, with buttons that open the app's page in Settings. It can be skipped, and opened again from Settings › Setup Guide.

To try it:
1. Copy some text in any app, then open Pastronaut, or tap + to type a clip, or share text to Pastronaut. Save Clipboard on Opening is on by default (Settings can turn it off) and starts after the setup guide; iOS shows its own paste prompt unless Paste from Other Apps is set to Allow.
2. Add the keyboard: Settings › Pastronaut › Keyboards, or Settings › General › Keyboard › Keyboards › Add New Keyboard › Pastronaut. In any text field, switch to it with the globe key and tap a clip to type it. The setup guide has a field to try it.

The keyboard works without Full Access: it shows the saved history and types an item. Full Access is used only to read and update the history shared with the app (App Group), to fetch the user's own iCloud data, and to save a copy when the user taps Paste. It does not log or transmit keystrokes and has no network access other than the user's iCloud.

Link and map previews are on by default; the setup guide and Settings show a switch for them. Sign-in, reset and other one-time-looking links are never fetched, and previews stay on the device.

The app can be shown in English or Turkish (Settings › Language).

Sync uses the user's private CloudKit database when signed in to iCloud. The optional Mac app: https://github.com/xkbxyberk/pastronaut

Privacy policy: in the app at Settings › About › Privacy Policy, and at https://xkbxyberk.github.io/pastronaut/privacy.html
```

### iPhone (1.0)
```
Pastronaut is a clipboard manager and clipboard keyboard for iPhone. It works on its own; the Mac app is optional. No account or sign-in is needed.

To try it:
1. Copy some text in any app, then open Pastronaut — or tap + to type a clip, or share text to Pastronaut. (Settings › Save Clipboard on Opening saves copies when the app opens; iOS shows its own paste prompt.)
2. Add the keyboard: Settings › General › Keyboard › Keyboards › Add New Keyboard › Pastronaut. In any text field, switch to it with the globe key and tap a clip to type it.

The keyboard works without Full Access: it shows the saved history and types an item. Full Access is used only to read and update the history shared with the app (App Group), to fetch the user's own iCloud data, and to save a copy when the user taps Paste. It does not log or transmit keystrokes and has no network access other than the user's iCloud.

Link and map previews are off until the user allows them (asked once). Sign-in, reset and other one-time-looking links are never fetched.

Sync uses the user's private CloudKit database when signed in to iCloud. The optional Mac app: https://github.com/xkbxyberk/pastronaut

Privacy policy: in the app at Settings › About › Privacy Policy, and at https://xkbxyberk.github.io/pastronaut/privacy.html
```

### Mac
```
Pastronaut is a clipboard history manager that lives in the menu bar (no Dock icon). No account or sign-in is needed.

To try it:
1. Copy a few texts in any app. Open the history with ⇧⌘C or by clicking the clipboard icon in the menu bar.
2. Type to search, press Return to copy the selected item, press Space for a preview. Settings: press ⌘, while the history is open.

Accessibility permission (optional): Pastronaut asks for it only the first time the user pastes an item (⌥Return) or starts a list to paste in order. It is used for one thing: after the user picks an item, Pastronaut sends a single ⌘V to the frontmost app so the item is pasted where the user was typing. The same permission lets "paste a list in order" notice the user's ⌘V and move to the next item. Pastronaut does not read other apps' content, record keystrokes or send any data. Without the permission, items are copied and the user pastes with ⌘V.

Copies that password managers mark as concealed or transient are never saved.

iCloud sync is off until the user turns it on in Settings › Sync. It uses only the user's private CloudKit database, shared with the iPhone app on the same App Store record.

Privacy policy: Settings › Sync › Privacy Policy, and https://xkbxyberk.github.io/pastronaut/privacy.html
```

## 14. Sources
- [Paste on the App Store](https://apps.apple.com/us/app/paste-limitless-clipboard/id967805235): listing, description,
  iPhone, iPad and Mac screenshots; looked up 2026-10-18.
- [Apple: asset best practices](https://developer.apple.com/app-store/asset-best-practices/) ·
  [creative assets specs](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) ·
  [screenshot specs](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [How Apple indexes App Store keywords](https://storeboard.digitalsauce.io/blog/how-apple-indexes-app-store-keywords) ·
  [Cross-localization by storefront](https://storelit.co/blog/app-store-cross-localization-double-keywords) ·
  [English keywords by country](https://storeboard.digitalsauce.io/blog/english-keywords-by-country) ·
  [Keyword field guide 2026](https://www.applaunchflow.com/blog/app-store-keyword-field-guide-2026)
- Category survey: App Store search results for "clipboard keyboard", "clipboard manager", "copy paste keyboard" (U.S.)
  and "pano klavye", "kopyala yapıştır" (Türkiye), 2026-10-18.
- 1.3 research (2026-10-24):
  - [Apple: Marketing Resources and Identity Guidelines](https://developer.apple.com/app-store/marketing/guidelines/)
    (product bezels "as is", no cropping, tilting, shadows or simulated devices; product names never in capitals;
    name products, not iOS or macOS)
  - [Apple Design Resources](https://developer.apple.com/design/resources/) (iPhone 18 and MacBook Pro M5 bezels;
    license: mock-ups of apps that run only on Apple platforms, the files themselves are not redistributed)
  - [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
    (iPhone 1320 × 2868, Mac 2880 × 1800, up to 10 each, no transparency)
  - Description: [AppTweak](https://www.apptweak.com/en/aso-blog/app-store-description-best-practices),
    [AppFollow](https://appfollow.io/blog/aso-description), [Adjust](https://www.adjust.com/blog/mobile-app-description/)
    (first 170–255 characters; outcome first; remove doubts early; short benefit bullets)
  - Screenshots: [AppFollow](https://appfollow.io/blog/aso-screenshots-best-practices),
    [AppTweak](https://www.apptweak.com/en/aso-blog/how-to-optimize-your-app-screenshots)
    (the first three frames carry the pitch; one benefit per frame; captions readable at thumbnail size; real UI)
