# App Store: Pastronaut for iPhone and Mac (v3, 2026-10-18)

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
- **Mac App Store, later:** "Add Platform › macOS" on the same record. Our Mac bundle ID is the same
  (`com.xkbxyberk.pastronaut`), so it becomes a universal purchase like Paste. First it needs a Mac App Store build:
  - without Sparkle (guideline 2.4.5(vii));
  - with the Accessibility-based paste and queue reviewed: App Review may question them under 2.4.5.

  This file already holds the Mac texts and pictures for that day.

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
  - The extensions' App IDs (`.keyboard`, `.share`, `.widgets`) were created by Xcode and ship inside the app.
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

## 6. Description: iPhone
### English
```
Your iPhone remembers only the last thing you copied. Pastronaut remembers what you save — and its keyboard pastes any of it, in any app, with one tap. Use it on its own, or with Pastronaut for Mac to have your Mac's clipboard on your iPhone too.

PASTE ANYTHING, IN ANY APP
– The Pastronaut keyboard shows your clips in a tidy two-column grid, newest first
– The latest copy from your Mac waits at the top
– Tabs for recent, pinned, Mac, iPhone and each collection; search with letters and numbers

SAVE IN ONE TAP
iOS lets only the app in front read the clipboard, so Pastronaut makes saving one tap:
– Open the app ("Save Clipboard on Opening")
– Tap Paste in the Pastronaut keyboard
– Share text to Pastronaut from any app
– Use the Control Center button, Back Tap or the Action button
– Or type a new clip with +

EVERY KIND, ITS OWN CARD
– Addresses and map coordinates: a map and Get Directions
– Links: a page preview (sign-in and reset links are never opened)
– Code in color, colors as swatches, Call and Write Email buttons
– Prefer it calm? Turn previews off for a compact list

PIN, COLLECT, FIND
– Pin what you reuse; keep addresses, snippets or a project's links in collections
– Search by text, or filter by kind and date

WIDGETS AND SHORTCUTS
– Recent clips on the Home Screen (also from one collection), the latest on the Lock Screen
– Shortcuts: Get Clip, Get Latest Clip, Copy Latest Clip, Get Recent Clips, Save to Pastronaut, Add to Collection

ON YOUR MAC TOO
Pastronaut for Mac keeps your whole history in the menu bar — press Space to preview, paste a list in order, filter as you type — and syncs it with your iPhone through your own iCloud.

PRIVATE BY DESIGN
– No account, no servers, no analytics, no ads
– Your clips stay on your devices and in your private iCloud database; text is encrypted on your device before upload, and end-to-end with Advanced Data Protection
– Optional Face ID lock; one-time codes, card numbers and IBANs are never saved automatically

FREE AND OPEN SOURCE
No subscription and no in-app purchases. The source code is public.
```

### Türkçe
```
iPhone yalnızca son kopyaladığın şeyi hatırlar. Pastronaut kaydettiklerini hatırlar; klavyesi de istediğini her uygulamada tek dokunuşla yapıştırır. Tek başına kullan ya da Pastronaut for Mac ile Mac'inin panosu da iPhone'unda olsun.

HER ŞEYİ, HER UYGULAMADA YAPIŞTIR
– Pastronaut klavyesi öğelerini en yenisi başta, iki sütunlu düzenli bir ızgarada gösterir
– Mac'ten gelen son kopya en üstte seni bekler
– Son, sabitlenenler, Mac, iPhone ve her koleksiyon için sekmeler; harf ve rakamla arama

TEK DOKUNUŞLA KAYDET
iOS panoyu yalnızca öndeki uygulamanın okumasına izin verir; Pastronaut kaydetmeyi tek dokunuşa indirir:
– Uygulamayı aç ("Açılınca Panoyu Kaydet")
– Pastronaut klavyesinde Yapıştır'a dokun
– Herhangi bir uygulamadan metni Pastronaut'la paylaş
– Denetim Merkezi düğmesini, Arkaya Dokun'u ya da Eylem düğmesini kullan
– Ya da + ile yeni bir öğe yaz

HER TÜRE KENDİ KARTI
– Adres ve harita koordinatı: harita ve Yol Tarifi (Türk adreslerini de tanır)
– Bağlantı: sayfa önizlemesi (giriş ve şifre sıfırlama bağlantıları hiç açılmaz)
– Renkli kod, renk örnekleri, Ara ve E-posta Yaz düğmeleri
– Sade mi istersin? Önizlemeleri kapat, kompakt liste olsun

SABİTLE, KOLEKSİYONLA, BUL
– Sık kullandıklarını sabitle; adresleri, parçacıkları ya da bir projenin bağlantılarını koleksiyonlarda tut
– Metinle ara ya da türe ve tarihe göre süz

WIDGET'LAR VE KESTİRMELER
– Ana Ekran'da son öğeler (bir koleksiyondan da), Kilitli Ekran'da son öğe
– Kestirmeler: Öğe Al, Son Öğeyi Al, Son Öğeyi Kopyala, Son Öğeleri Al, Pastronaut'a kaydet, Koleksiyona Ekle

MAC'İNDE DE
Pastronaut for Mac tüm geçmişini menü çubuğunda tutar — Space ile önizle, bir listeyi sırayla yapıştır, yazarken süz — ve kendi iCloud'un üzerinden iPhone'unla eşitler.

GİZLİLİK ÖNCELİKLİ
– Hesap yok, sunucu yok, analiz yok, reklam yok
– Öğelerin cihazlarında ve özel iCloud veritabanında kalır; metin yüklenmeden önce cihazında şifrelenir, Gelişmiş Veri Koruması açıksa uçtan uca şifrelidir
– İsteğe bağlı Face ID kilidi; tek kullanımlık kodlar, kart numaraları ve IBAN'lar kendiliğinden kaydedilmez

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

## 8. What's New (1.0)
- iPhone EN: `First release: your clipboard history, a keyboard that pastes it in any app, and sync with your Mac.`
- iPhone TR: `İlk sürüm: pano geçmişin, onu her uygulamada yapıştıran bir klavye ve Mac'inle eşitleme.`

## 9. Pictures
All pictures use made-up clips only. They are made in four steps:
1. iPhone shots, in each language: SyncStepTests `storeShots` (`PT_SHOTS_LANG` = en / tr).
2. Mac shots: MaccyUITests `testPastronautReadmeShots`. In test mode only, each copy names a plausible source app
   (`TestSourceApp`).
3. Raw shots land in `appstore-screenshots/raw/` (not in git).
4. Compose them: `cd scripts/store && swift run -c release StoreArt ../../appstore-screenshots/raw ../../appstore-screenshots/store`.

The output is opaque PNGs in `appstore-screenshots/store/<lang>/`. Upload the English set to English (U.S.) and
English (U.K.), and the Turkish set to Turkish.

### iPhone: `iphone-1…7.png`, 1320 × 2868 (upload in this order)
| # | Eyebrow | English | Turkish | Picture |
|---|---|---|---|---|
| 1 | PASTRONAUT | Your clipboard, on iPhone and Mac | Panon, iPhone'da ve Mac'te | Panorama, left: iPhone cards in front of the Mac window |
| 2 | KEEP · SAKLA | Never lose a copy again | Hiçbir kopyayı kaybetme | Panorama, right: the Mac window continues |
| 3 | PASTE · YAPIŞTIR | Paste anything in one tap | Her kopya tek dokunuşla | Keyboard pasting an address into a note |
| 4 | FIND · BUL | Find any copy in seconds | Aradığını saniyede bul | Search with kind filters (dark) |
| 5 | ORGANIZE · DÜZENLE | Pin and collect what you reuse | Sabitle, koleksiyonla | A collection |
| 6 | SMART CARDS · AKILLI KARTLAR | Every kind, its own card | Her türe kendi kartı | Cards (dark) |
| 7 | PRIVATE · GİZLİ | No account. No tracking. | Hesap yok. İzleme yok. | The compact list |

Frames 1–3 also appear in search results. Together they say "one clipboard on iPhone and Mac, paste anywhere".

### Mac: `mac-1…5.png`, 2880 × 1800 (for the Mac App Store)
| # | Eyebrow | English | Turkish | Picture |
|---|---|---|---|---|
| 1 | PASTRONAUT | Your clipboard, on Mac and iPhone | Panon, Mac'te ve iPhone'da | Panorama, left: the menu bar history |
| 2 | SYNC · EŞİTLE | Copy on one, paste on the other | Birinde kopyala, ötekinde yapıştır | Panorama, right: the iPhone beside the Mac window |
| 3 | PREVIEW · ÖNİZLE | Press Space to look closer | Space'e bas, yakından bak | Code preview |
| 4 | QUEUE · SIRA | Paste a list, in order | Bir listeyi sırayla yapıştır | Three items queued |
| 5 | FIND · BUL | Type a filter, find it fast | Süzgeci yaz, hemen bul | `type:code` / `tür:kod` results |

### Header and search result (optional, iOS 27 and later; can change without a new version)
- **`header.png`, 3840 × 1646 (21:9):**
  - The wordmark and "Every copy, one tap away." / "Her kopya, bir dokunuş uzağında." sit in the centered safe area
    (1646 × 661).
  - The Mac window and the iPhone at the sides are decoration and may be cropped.
- **`search.png`, 3840 × 2560 (3:2):** it "states the obvious".
  - Wordmark and "Clipboard history + paste keyboard for iPhone and Mac" / "Pano geçmişi ve yapıştırma klavyesi
    iPhone ve Mac için".
  - Below: the keyboard, the Mac window and the cards, all inside the centered safe area (2168 × 1030).

### Rules followed
- every frame shows the real app;
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
- **Privacy manifest:** in the app, keyboard, widgets and Share extension.

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

## 13. App Review notes (iPhone)
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
