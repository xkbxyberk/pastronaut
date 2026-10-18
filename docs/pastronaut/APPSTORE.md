# App Store Connect: Pastronaut for iPhone (draft, 2026-10-18)

Copy-ready metadata (English primary, Turkish localization) and the answers for App Store Connect. Character limits
in brackets. Checked against the app as of commit `daf0da7`.

## Where each field goes in App Store Connect
- **App Information** (General): name, subtitle, category, content rights, age rating, license agreement (Apple's
  standard EULA). Encryption documentation: nothing to upload (only the OS's encryption; Info.plist says so).
  Digital Services Act: non-trader (free, non-commercial). Server notifications, shared secret: not used.
- **iOS App › 1.0 Prepare for Submission**: screenshots, promotional text, description, keywords, support and
  marketing URLs, copyright, App Review information (sign-in not required, contact, notes), build.
- **Trust & Safety › App Privacy**: privacy policy URL, data collection ("No").
- **Monetization › Pricing and Availability**: free, all countries.

## App information
- **Name** [30]: `Pastronaut` · TR: `Pastronaut: Pano Geçmişi` (24). App names are unique per localization, and
  "Pastronaut" is already reserved by someone else for Turkish (seen 2026-10-18), so the Turkish name adds a
  descriptor. The Home Screen still shows "Pastronaut" (from the app bundle).
- **Subtitle** [30]: `Your Mac clipboard on iPhone` (28) · TR: `Mac panon artık iPhone'da` (25)
- **Bundle ID:** `com.xkbxyberk.pastronaut` · **SKU:** `pastronaut-ios`
- **Primary category:** Productivity · **Secondary:** Utilities
- **Content rights:** optional link previews show the title and image of pages the user copied (like Messages'
  link previews), so answer "Yes, it contains, shows or accesses third-party content" honestly (owner's decision).
- **Bundle IDs:** the app record uses `com.xkbxyberk.pastronaut`; `.keyboard`, `.share` and `.widgets` are the
  extensions' App IDs that Xcode's automatic signing created ("XC …"). They ship inside the app; keep them.
- **Privacy Policy URL:** https://xkbxyberk.github.io/pastronaut/privacy.html
- **Support URL:** https://github.com/xkbxyberk/pastronaut/issues (contact e-mail is on the privacy page)
- **Marketing URL:** https://xkbxyberk.github.io/pastronaut/
- **Copyright:** `2026 Berk Akbay`
- **Price:** Free · no in-app purchases

## Promotional text [170]
EN: `Copy on your Mac, paste on your iPhone: your clipboard history in an app, a one-tap keyboard, widgets and Shortcuts. Free, open source, no tracking.` (148)

TR: `Mac'te kopyala, iPhone'da yapıştır: pano geçmişin bir uygulamada, tek dokunuşla yazan klavyede, widget'larda ve Kestirmeler'de. Ücretsiz, açık kaynak.` (150)

## Keywords [100, comma-separated]
No Apple trademarks (iCloud, Universal Clipboard) or other apps' names in keywords (guideline 2.3.7); they stay in the description.
EN: `clipboard,clipboard manager,paste,copy,history,keyboard,snippets,mac,sync,text,links,copy paste` (95)

TR: `pano,pano yöneticisi,kopyala,yapıştır,geçmiş,klavye,mac,eşitleme,not,parçacık,bağlantı,metin` (92)

## Description [4000]
### English
```
Pastronaut brings your Mac's clipboard history to your iPhone through your own iCloud.

Everything you copy on your Mac shows up here: in the app, in a keyboard that types any item with one tap, in widgets and in Shortcuts. Copies you save on your iPhone go back to the Mac.

YOUR HISTORY, EVERYWHERE YOU TYPE
• The Pastronaut keyboard puts the latest copy from your Mac at the top, with tabs for pinned items, Mac, iPhone and your collections, and search with letters and numbers.
• Cards by kind: links with a page preview, addresses with a map and directions, code in color, colors as swatches, phone numbers and emails with a button. Prefer a compact list? Turn previews off.
• Collections keep snippets, addresses or a project's links together, on every device.

FAST WAYS TO SAVE
iOS lets only the app in front read the clipboard, so Pastronaut saves a copy with one tap: open the app, tap Paste in the keyboard, share text to Pastronaut, or use the Control Center button, Back Tap or the Action button.

WIDGETS AND SHORTCUTS
• Recent clips on the Home Screen (also from one collection), the latest clip on the Lock Screen.
• Shortcuts actions: Get Clip, Get Latest Clip, Copy Latest Clip, Get Recent Clips, Save to Pastronaut, Add to Collection.

PRIVATE BY DESIGN
• No account, no servers, no analytics, no ads.
• Clips sync through the private iCloud database of your Apple Account. Text is encrypted on your device before upload, and end-to-end encrypted with Advanced Data Protection.
• Optional Face ID lock. One-time codes, card numbers and IBANs are never saved automatically.
• Link and map previews are off until you allow them.

FREE AND OPEN SOURCE
Pastronaut is free, with no in-app purchases, and its source code is public. It works with Pastronaut for Mac, a free menu bar clipboard manager based on Maccy (not affiliated). Download the Mac app from the website.
```

### Türkçe
```
Pastronaut, Mac'inin pano geçmişini kendi iCloud'un üzerinden iPhone'una taşır.

Mac'te kopyaladığın her şey burada: uygulamada, herhangi bir öğeyi tek dokunuşla yazan klavyede, widget'larda ve Kestirmeler'de. iPhone'da kaydettiğin kopyalar da Mac'e geri gider.

GEÇMİŞİN, YAZDIĞIN HER YERDE
• Pastronaut klavyesi Mac'ten gelen son kopyayı en üstte tutar; sabitlenenler, Mac, iPhone ve koleksiyonlar için sekmeler ve harf ve rakamlarla arama sunar.
• Türe göre kartlar: sayfa önizlemeli bağlantılar, haritalı ve yol tarifli adresler, renkli kod, renk örnekleri, düğmeli telefon ve e-postalar. Sade bir liste mi istersin? Önizlemeleri kapat.
• Koleksiyonlar parçacıkları, adresleri ya da bir projenin bağlantılarını her cihazda bir arada tutar.

HIZLI KAYDETME YOLLARI
iOS panoyu yalnızca öndeki uygulamanın okumasına izin verir; bu yüzden Pastronaut bir kopyayı tek dokunuşla kaydeder: uygulamayı aç, klavyede Yapıştır'a dokun, metni Pastronaut'la paylaş ya da Denetim Merkezi düğmesini, Arkaya Dokun'u veya Eylem düğmesini kullan.

WIDGET'LAR VE KESTİRMELER
• Ana Ekran'da son öğeler (bir koleksiyondan da), Kilitli Ekran'da son öğe.
• Kestirmeler eylemleri: Öğe Al, Son Öğeyi Al, Son Öğeyi Kopyala, Son Öğeleri Al, Pastronaut'a kaydet, Koleksiyona Ekle.

GİZLİLİK ÖNCELİKLİ
• Hesap yok, sunucu yok, analiz yok, reklam yok.
• Öğeler Apple Hesabının özel iCloud veritabanı üzerinden eşitlenir. Metin yüklenmeden önce cihazında şifrelenir; Gelişmiş Veri Koruması açıksa uçtan uca şifrelidir.
• İsteğe bağlı Face ID kilidi. Tek kullanımlık kodlar, kart numaraları ve IBAN'lar kendiliğinden kaydedilmez.
• Bağlantı ve harita önizlemeleri sen izin verene kadar kapalıdır.

ÜCRETSİZ VE AÇIK KAYNAK
Pastronaut ücretsizdir, uygulama içi satın alma yoktur ve kaynak kodu herkese açıktır. Maccy'ye dayanan (onunla bağlantılı olmayan) ücretsiz menü çubuğu pano yöneticisi Pastronaut for Mac ile çalışır. Mac uygulamasını web sitesinden indir.
```

## App Privacy (privacy "nutrition" label)
- **Do you or your third-party partners collect data from this app?** → **No, we do not collect data from this app.**
  Result: "Data Not Collected". Basis: Apple's definition of "collect" (data sent off the device in a way the developer
  or partners can access); data in the user's own CloudKit private database and Apple Maps lookups are Apple's
  services, which developers don't disclose. Crash reports shared through Apple's opt-in are not counted either.
- **Tracking:** No. **Privacy manifest:** included in the app, keyboard, widgets and Share extension.

## Age rating
All content questions: **None / No**. Unrestricted web access: **No** (links open in Safari; previews only show a
title and image). Gambling, contests, user-generated content shared with others: **No**. Made for Kids: **No**.
Expected rating: **4+**.

## Encryption (export compliance)
`ITSAppUsesNonExemptEncryption = NO` in Info.plist: the app uses only encryption provided by Apple's operating system
(CloudKit encrypted fields, HTTPS). Review before submitting; not legal advice.

## App Review notes [4000]
```
Pastronaut is the iPhone companion of a free, open-source Mac clipboard manager (https://github.com/xkbxyberk/pastronaut). No account or sign-in is needed.

How to try it without a Mac: open the app, tap + to add a text clip, or copy text in another app and come back (Settings › Save Clipboard on Opening). Clips sync through the user's private CloudKit database when signed in to iCloud.

Keyboard: Settings › General › Keyboard › Keyboards › Add New Keyboard › Pastronaut. The keyboard works without Full Access (it shows the history and types an item). Full Access is used only to read and update the history shared with the app (App Group), to fetch the user's own iCloud data, and to save a copy when the user taps Paste. It does not log or transmit keystrokes and has no network access other than the user's iCloud.

Previews: link and map previews are off until the user allows them (asked once). Sign-in, reset and other one-time-looking links are never fetched.

Privacy policy: in the app at Settings › About › Privacy Policy, and at https://xkbxyberk.github.io/pastronaut/privacy.html
```

## Screenshots and header (made 2026-10-18)
Made from device screenshots with made-up clips only (`PT_DEMO`), per language: SyncStepTests `storeShots`
(`PT_SHOTS_LANG` = en / tr) → `appstore-screenshots/raw/<lang>/`, then `cd scripts/store && swift run -c release
StoreArt ../../appstore-screenshots/raw ../../appstore-screenshots/store`. Output (not in git), opaque PNGs:
- `store/<lang>/screenshot-1…5.png`, 1320 × 2868 (iPhone 6.9"; App Store Connect scales them for smaller iPhones).
  Order tells the story; the first three also appear in search results:
  1. Your Mac clipboard, on iPhone · Mac panon, artık iPhone'da (cards, light)
  2. Type any copy in one tap · Her kopya tek dokunuşla (keyboard, dark)
  3. Smart cards for every kind · Her türe akıllı kart (cards, dark)
  4. Keep what you reuse together · Sık kullandıkların bir arada (a collection, light)
  5. Private by design · Gizlilik öncelikli (list, light)
- `store/<lang>/header-universal.png`, 5244 × 2950: one file for both the product page header (21:9) and the search
  result (3:2) slots (iOS 27 and later; optional). Wordmark and tagline inside the centered safe area; app screens at
  the sides may be cropped.
- Rules followed: real UI in every frame, short benefit captions, no prices, "free", URLs, awards or other
  platforms; status bar removed (time and Focus icons).
- **iPad:** not needed — the first release is iPhone-only (`TARGETED_DEVICE_FAMILY 1` for every target in
  `iOS/project.yml`). iPad comes back after testing it in the simulator.
