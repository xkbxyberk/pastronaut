# App Store: Pastronaut for iPhone and Mac (v4, 2026-10-22: iPhone 1.2)

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
| | iPhone | Mac |
|---|---|---|
| **English (U.S.)** | `keyboard,snippet,text,widget,template,reply,quick,phrase,note,link,organizer,save,pin,multiple,mac` (98) | `menubar,menu,bar,pasteboard,snippet,text,image,file,search,shortcut,pin,queue,preview,ocr,iphone` (96) |
| **English (U.K.)** | `keyboard,snippet,text,widget,template,reply,quick,phrase,note,link,organiser,save,pin,multiple,mac` (98) | `menubar,menu,bar,pasteboard,snippet,text,image,file,search,shortcut,pin,queue,preview,ocr,iphone` (96) |
| **Turkish** | `klavye,yönetici,geçmiş,kopya,metin,not,bağlantı,parçacık,şablon,hızlı,yanıt,widget,kaydet,mac` (93) | `menü,çubuğu,kısayol,parçacık,metin,görsel,dosya,arama,önizleme,sıra,iphone,yönetici,geçmiş` (90) |

**What these cover, combined with the name and subtitle:**
- **iPhone:** "clipboard keyboard", "copy paste keyboard", "paste keyboard", "text snippets", "quick reply",
  "clipboard widget", "clipboard organizer", "multiple copy paste", "clipboard mac".
- **Mac:** "clipboard menu bar", "pasteboard manager", "clipboard history search", "text snippets", "copy paste
  shortcut", "clipboard iphone".

**Why each language has its own field:**
- English (U.K.) repeats the core set, because it is the English that Türkiye and most countries search. "organiser"
  is the U.K. spelling.
- Turkish is all Turkish. Türkiye already gets the English words from English (U.K.).

**Optional, for the U.S. only: Spanish (Mexico).** It reaches Spanish-speaking U.S. users and adds a second
100-character field. Use it only as a real Spanish page:
- Name: `Pastronaut: Portapapeles`
- Subtitle: `Copiar, pegar y sincronizar`
- Keywords: `historial,teclado,copiar,pegar,texto,notas,fragmento,plantilla,respuesta,rapida,widget,mac`

**After launch:** follow the rankings for a few weeks, then replace the words that never move.

## 5. Promotional text [170] (can change any time, no review)
| | iPhone | Mac |
|---|---|---|
| **EN** | `Every copy you save, one tap away in any app: a clipboard keyboard, smart cards, collections and widgets. Great on its own, even better with your Mac.` (150) | `Your clipboard history in the menu bar. Preview with Space, paste a list in order, find anything with filters, and have it all on your iPhone too.` (146) |
| **TR** | `Kaydettiğin her kopya, her uygulamada bir dokunuş uzağında: pano klavyesi, akıllı kartlar, koleksiyonlar ve widget'lar. Tek başına iyi, Mac'le daha iyi.` (152) | `Pano geçmişin menü çubuğunda. Space ile önizle, listeyi sırayla yapıştır, süzgeçlerle her şeyi bul; hepsi iPhone'unda da olsun.` (127) |

English (U.K.) uses the English texts; only "organizer" becomes "organiser" if it appears.

## 6. Description: iPhone (1.2)
About 2,900 characters each (limit 4,000). The 1.1 text is in git history.

### English
```
Your iPhone remembers only the last thing you copied. Pastronaut remembers what you save — and its keyboard pastes any of it, in any app, with one tap. Use it on its own, or with Pastronaut for Mac to have your Mac's clipboard on your iPhone too.

PASTE ANYTHING, IN ANY APP
– The Pastronaut keyboard shows your clips in a tidy two-column grid, newest first, with link and map thumbnails
– The latest copy from your Mac waits at the top
– Tabs for recent, pinned, Mac, iPhone and each collection; search with letters and numbers
– Paste a list in order: select clips, start a queue, and every tap on the keyboard types the next one

SAVE IN ONE TAP
iOS lets only the app in front read the clipboard, so Pastronaut makes saving one tap:
– Open the app ("Save Clipboard on Opening")
– Tap Paste in the Pastronaut keyboard
– Share text or links to Pastronaut, or tap "Save to Pastronaut" in the share sheet
– Use the Control Center button, Back Tap or the Action button
– Type a new clip with +, or touch and hold + to scan text or a document with the camera

EVERY KIND, ITS OWN CARD
– Addresses and map coordinates: a map and Get Directions
– Links: a page preview (sign-in and reset links are never opened)
– Code in color, colors as swatches, Call and Write Email buttons
– Give any clip a title, so it is easy to spot and to find
– Prefer it calm? Turn previews off for a compact list

PIN, COLLECT, FIND
– Pin what you reuse; keep addresses, snippets or a project's links in collections, and export a collection as a file
– Search by text or title, or filter by kind and date
– Combine several clips into one and copy it
– Deleted something by mistake? Undo

WIDGETS, CONTROLS AND SHORTCUTS
– Recent clips on the Home Screen (also from one collection), the latest on the Lock Screen
– Control Center: save the clipboard, or pause saving for a while
– Shortcuts: Get Clip, Get Latest Clip, Copy Latest Clip, Get Recent Clips, Save to Pastronaut, Add to Collection

ON YOUR MAC TOO
Pastronaut for Mac keeps your whole history in the menu bar — press Space to preview, paste a list in order, filter as you type — and syncs it with your iPhone through your own iCloud.

PRIVATE BY DESIGN
– No account, no servers, no analytics, no ads
– Your clips stay on your devices and in your private iCloud database; text is encrypted on your device before upload, and end-to-end with Advanced Data Protection
– Optional Face ID lock; your clips are covered while the screen is recorded
– One-time codes, card numbers and IBANs are never saved automatically, and the ones you save can stay on this iPhone only
– Scanning reads the text on your iPhone; no photo is kept

FREE AND OPEN SOURCE
No subscription and no in-app purchases. The source code is public.
```

### Türkçe
```
iPhone yalnızca son kopyaladığın şeyi hatırlar. Pastronaut kaydettiklerini hatırlar; klavyesi de istediğini her uygulamada tek dokunuşla yapıştırır. Tek başına kullan ya da Pastronaut for Mac ile Mac'inin panosu da iPhone'unda olsun.

HER ŞEYİ, HER UYGULAMADA YAPIŞTIR
– Pastronaut klavyesi öğelerini en yenisi başta, bağlantı ve harita küçük resimleriyle iki sütunlu düzenli bir ızgarada gösterir
– Mac'ten gelen son kopya en üstte seni bekler
– Son, sabitlenenler, Mac, iPhone ve her koleksiyon için sekmeler; harf ve rakamla arama
– Bir listeyi sırayla yapıştır: öğeleri seç, sırayı başlat; klavyede her dokunuş sıradakini yazar

TEK DOKUNUŞLA KAYDET
iOS panoyu yalnızca öndeki uygulamanın okumasına izin verir; Pastronaut kaydetmeyi tek dokunuşa indirir:
– Uygulamayı aç ("Açılınca Panoyu Kaydet")
– Pastronaut klavyesinde Yapıştır'a dokun
– Metni ya da bağlantıyı Pastronaut'la paylaş ya da paylaşım sayfasında "Pastronaut'a Kaydet"e dokun
– Denetim Merkezi düğmesini, Arkaya Dokun'u ya da Eylem düğmesini kullan
– + ile yeni bir öğe yaz ya da +'ya basılı tutup kamerayla metin veya belge tara

HER TÜRE KENDİ KARTI
– Adres ve harita koordinatı: harita ve Yol Tarifi (Türk adreslerini de tanır)
– Bağlantı: sayfa önizlemesi (giriş ve şifre sıfırlama bağlantıları hiç açılmaz)
– Renkli kod, renk örnekleri, Ara ve E-posta Yaz düğmeleri
– Her öğeye bir başlık ver; kolayca göz at, kolayca bul
– Sade mi istersin? Önizlemeleri kapat, kompakt liste olsun

SABİTLE, KOLEKSİYONLA, BUL
– Sık kullandıklarını sabitle; adresleri, parçacıkları ya da bir projenin bağlantılarını koleksiyonlarda tut, bir koleksiyonu dosya olarak dışa aktar
– Metinle ya da başlıkla ara, türe ve tarihe göre süz
– Birkaç öğeyi birleştirip tek seferde kopyala
– Yanlışlıkla mı sildin? Geri al

WIDGET'LAR, DENETİMLER VE KESTİRMELER
– Ana Ekran'da son öğeler (bir koleksiyondan da), Kilitli Ekran'da son öğe
– Denetim Merkezi: panoyu kaydet ya da kaydetmeyi bir süre duraklat
– Kestirmeler: Öğe Al, Son Öğeyi Al, Son Öğeyi Kopyala, Son Öğeleri Al, Pastronaut'a kaydet, Koleksiyona Ekle

MAC'İNDE DE
Pastronaut for Mac tüm geçmişini menü çubuğunda tutar — Space ile önizle, bir listeyi sırayla yapıştır, yazarken süz — ve kendi iCloud'un üzerinden iPhone'unla eşitler.

GİZLİLİK ÖNCELİKLİ
– Hesap yok, sunucu yok, analiz yok, reklam yok
– Öğelerin cihazlarında ve özel iCloud veritabanında kalır; metin yüklenmeden önce cihazında şifrelenir, Gelişmiş Veri Koruması açıksa uçtan uca şifrelidir
– İsteğe bağlı Face ID kilidi; ekran kaydedilirken öğelerin örtülür
– Tek kullanımlık kodlar, kart numaraları ve IBAN'lar kendiliğinden kaydedilmez; kaydettiklerin istersen yalnızca bu iPhone'da kalır
– Tarama metni iPhone'unda okur; fotoğraf saklanmaz

ÜCRETSİZ VE AÇIK KAYNAK
Abonelik yok, uygulama içi satın alma yok. Kaynak kodu herkese açık.
```

## 7. Description: Mac (for the Mac App Store)
### English
```
Your clipboard normally holds one thing. Pastronaut keeps everything you copy — text, links, images, files — one shortcut away in the menu bar, and on your iPhone too.

NEVER LOSE A COPY
– A fast, keyboard-first history: press ⇧⌘C, type to search, Return to copy, ⌥Return to paste
– Colored icons for links, code, emails, phone numbers, addresses, colors, images and files
– Copies that password managers mark as concealed are never saved

LOOK BEFORE YOU PASTE
– Press Space for a preview that fits the kind: code in color, color swatches, open a link, get directions
– Text in copied images is recognized, so you can find screenshots by their words

PASTE A LIST, IN ORDER
– Select a few items, press Return, and every ⌘V pastes the next one — made for forms and repetitive work
– Paste as plain text whenever you want formatting gone

FIND IT FAST
– Type filters into the search: type:link, app:Safari, date:yesterday, from:iphone
– ⌘G jumps from a result to its place in your history

KEEP WHAT MATTERS
– Pin items, keep collections, pause copying for a while, undo a delete with ⌘Z
– Hide Pastronaut while sharing your screen

ON YOUR IPHONE TOO
With Pastronaut for iPhone, everything syncs through your own private iCloud, and a keyboard pastes your history in any iPhone app.

PRIVATE BY DESIGN
– No account, no servers, no analytics, no ads
– Text is encrypted on your Mac before it reaches iCloud (end-to-end with Advanced Data Protection)
– Keep one-time codes and card numbers out of sync, or sync only what you pin

FREE AND OPEN SOURCE
No subscription and no in-app purchases. Based on Maccy (not affiliated); the source code is public.
```

### Türkçe
```
Panon normalde tek bir şey tutar. Pastronaut kopyaladığın her şeyi — metin, bağlantı, görsel, dosya — menü çubuğunda bir kısayol uzağında tutar; iPhone'unda da.

HİÇBİR KOPYAYI KAYBETME
– Klavyeyle hızlı bir geçmiş: ⇧⌘C'ye bas, yazarak ara, Return ile kopyala, ⌥Return ile yapıştır
– Bağlantı, kod, e-posta, telefon, adres, renk, görsel ve dosya için renkli simgeler
– Parola yöneticilerinin gizli diye işaretlediği kopyalar hiç kaydedilmez

YAPIŞTIRMADAN ÖNCE BAK
– Space'e bas, türe uygun bir önizleme açılsın: renkli kod, renk örneği, bağlantıyı aç, yol tarifi al
– Kopyalanan görsellerdeki metin tanınır; ekran görüntülerini içindeki kelimelerle bulursun

LİSTEYİ SIRAYLA YAPIŞTIR
– Birkaç öğe seç, Return'e bas; her ⌘V sıradakini yapıştırır — formlar ve tekrarlı işler için
– İstediğinde biçimsiz düz metin olarak yapıştır

HIZLA BUL
– Aramaya süzgeç yaz: tür:bağlantı, uygulama:Safari, tarih:dün, cihaz:iphone
– ⌘G ile sonuçtan geçmişteki yerine atla

ÖNEMLİLERİ SAKLA
– Sabitle, koleksiyon tut, kopyalamayı bir süre duraklat, silmeyi ⌘Z ile geri al
– Ekran paylaşırken Pastronaut'u gizle

İPHONE'UNDA DA
Pastronaut for iPhone ile her şey kendi özel iCloud'un üzerinden eşitlenir; bir klavye de geçmişini her iPhone uygulamasında yapıştırır.

GİZLİLİK ÖNCELİKLİ
– Hesap yok, sunucu yok, analiz yok, reklam yok
– Metin iCloud'a gitmeden önce Mac'inde şifrelenir (Gelişmiş Veri Koruması açıksa uçtan uca)
– Tek kullanımlık kodları ve kart numaralarını eşitlemenin dışında tut ya da yalnızca sabitlediklerini eşitle

ÜCRETSİZ VE AÇIK KAYNAK
Abonelik yok, uygulama içi satın alma yok. Maccy'ye dayanır (onunla bağlantılı değildir); kaynak kodu herkese açık.
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

### iPhone (since 1.2): `iphone-1…10.png`, 1320 × 2868 (upload in this order; ten is App Store Connect's limit)
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

### Mac: `mac-1…5.png`, 2880 × 1800 (for the Mac App Store)
| # | Eyebrow | English | Turkish | Picture |
|---|---|---|---|---|
| 1 | PASTRONAUT | Your clipboard, on Mac and iPhone | Panon, Mac'te ve iPhone'da | Panorama, left: the menu bar history |
| 2 | SYNC · EŞİTLE | Copy on one, paste on the other | Birinde kopyala, ötekinde yapıştır | Panorama, right: the iPhone beside the Mac window |
| 3 | PREVIEW · ÖNİZLE | Press Space to look closer | Space'e bas, yakından bak | Code preview |
| 4 | QUEUE · SIRA | Paste a list, in order | Bir listeyi sırayla yapıştır | Three items queued |
| 5 | FIND · BUL | Type a filter, find it fast | Süzgeci yaz, hemen bul | `type:code` / `tür:kod` results |

### Header and search result (optional, iOS 27 and later; can change without a new version)
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
