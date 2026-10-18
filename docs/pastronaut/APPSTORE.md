# App Store: Pastronaut for iPhone (v2, 2026-10-18)

Copy-ready App Store Connect metadata (English primary, Turkish localization), the reasoning behind it, and the
answers for every App Store Connect form. Character counts were measured. Checked against the app as of this commit.

## 1. Positioning

**What the iPhone app is:** a clipboard manager and clipboard keyboard that works on its own. It doesn't need a Mac.
- iPhone remembers only the last thing you copied. Pastronaut keeps a history of what you save.
- Its keyboard pastes any saved item in any app with one tap. The latest copy sits on top, with tabs (recent, pinned,
  Mac, iPhone, collections) and search.
- You save a copy by opening the app, with "+", with the keyboard's Paste button, from the Share sheet, with the Control
  Center button, or with Back Tap / Action button through Shortcuts.
- Every saved item becomes a smart card by kind: a map for addresses (also coordinates), a page preview for links,
  colored code, color swatches, call and email buttons.
- Pins, collections, search by text, kind or date, widgets (Home and Lock Screen), Shortcuts actions, Face ID lock.
- Your iCloud keeps it in sync between your devices.
- **Extra, not the core:** the free Pastronaut for Mac brings everything copied on a Mac along automatically.

**Who it's for:** anyone who re-types or hunts for the same things on iPhone, such as addresses, links, emails, IBANs,
order numbers, code and replies. Mac users get more.

**Honest limits, said up front:** iOS lets only the app in front read the clipboard. So copies are saved with one tap
rather than in the background; every clipboard app on iPhone works within this limit. The description says it plainly,
so nobody expects automatic capture.

**How the category looks (App Store, 2026-10-18):**
- Names follow a "Brand – Clipboard Manager / Paste Keyboard" pattern.
- Most of the well-known apps charge a subscription or sell a premium tier, and some add AI or servers.
- The Turkish storefront has almost no Turkish-language listings.

**What sets Pastronaut apart:**
- free, with no subscription or tier;
- no account, no servers, no tracking;
- open source;
- smart cards by kind;
- a two-column keyboard with categories;
- Turkish addresses and Turkish UI;
- the optional free Mac app.

**Search (ASO) rules used:**
- Only the name, subtitle and the 100-character keyword field are indexed on iOS; the description isn't.
- Words are never repeated across those three fields.
- No other apps' names and no Apple trademarks (iCloud, Universal Clipboard) appear in the keyword field. Guideline 2.3.7
  forbids other apps' names; Apple's own marks are left out to be safe.
- The keyword field has no spaces after commas.
- The words people search with: clipboard, keyboard, paste, copy, manager, history, snippets.

## 2. Where each field goes in App Store Connect
- **General › App Information:**
  - name, subtitle, category, content rights, age rating;
  - license agreement: Apple's standard EULA;
  - encryption documentation: nothing to upload; the app uses only the OS's encryption, and Info.plist says so;
  - Digital Services Act: non-trader (free, non-commercial).
- **iOS App › 1.0 Prepare for Submission:**
  - screenshots, header and search asset;
  - promotional text, description, keywords, support and marketing URLs, copyright;
  - App Review information, then the build.
- **Trust & Safety › App Privacy:** privacy policy URL, data collection ("No").
- **Monetization › Pricing and Availability:** free, all countries.

## 3. App information
| Field | English (U.S.) | Turkish |
|---|---|---|
| Name [30] | `Pastronaut: Clipboard History` (29) | `Pastronaut: Pano Geçmişi` (24) |
| Subtitle [30] | `Paste Keyboard & Snippets` (25) | `Kopyala Yapıştır Klavyesi` (25) |

- The Turkish name has a descriptor because "Pastronaut" alone is reserved by another account for Turkish.
- The Home Screen always shows "Pastronaut", which comes from the app bundle.
- **Category:** Productivity (primary), Utilities (secondary).
- **Content rights:** "Yes". Optional link previews show the title and image of pages the user copied, as Messages
  does. Owner's decision.
- **Bundle ID:** `com.xkbxyberk.pastronaut`.
  - `.keyboard`, `.share` and `.widgets` are the extensions' App IDs, created by Xcode ("XC …"). They ship inside the
    app; keep them.
- **SKU:** `pastronaut-ios`.
- **Privacy Policy URL:** https://xkbxyberk.github.io/pastronaut/privacy.html
- **Support URL:** https://github.com/xkbxyberk/pastronaut/issues. The contact e-mail is on the privacy page.
- **Marketing URL:** https://xkbxyberk.github.io/pastronaut/
- **Copyright:** `2026 Berk Akbay` · **Price:** Free, no in-app purchases.

## 4. Keywords [100, no spaces, no words already in the name or subtitle]
- **EN** (100):
  `copy,manager,clips,saver,text,notes,links,collections,widget,pin,board,save,sync,mac,multi,favorites`
- **TR** (99):
  `klavye,yönetici,kopya,metin,not,bağlantı,koleksiyon,widget,parçacık,kaydet,clipboard,keyboard,paste`
  - English words are included because Turkish users often search in English.

## 5. Promotional text [170] (can change without a new version)
- **EN** (153): `iPhone remembers only your last copy. Pastronaut keeps them all and pastes any of them in one tap with its keyboard. No account, no ads, no subscription.`
- **TR** (152): `iPhone yalnızca son kopyanı hatırlar. Pastronaut hepsini saklar ve klavyesiyle istediğini tek dokunuşla yapıştırır. Hesap yok, reklam yok, abonelik yok.`

## 6. Description [4000]
### English
```
iPhone remembers only the last thing you copied. Pastronaut keeps a history of what you save — and its keyboard pastes any of it, in any app, with one tap.

PASTE ANYTHING, IN ANY APP
• The Pastronaut keyboard shows your clips as a tidy two-column grid, newest first, so the thing you just copied is always on top.
• Tabs for recent, pinned, Mac, iPhone and each of your collections, plus search with letters and numbers.
• Tap a clip to type it. Long-press for more.

SAVE IN ONE TAP
iOS lets only the app in front read the clipboard, so Pastronaut makes saving a single tap:
• Open the app — with "Save Clipboard on Opening" it saves what you copied.
• Tap Paste in the Pastronaut keyboard.
• Share text to Pastronaut from any app.
• Use the Save Clipboard button in Control Center, Back Tap or the Action button.
• Or type a new clip with +.

SMART CARDS FOR EVERY KIND
• Addresses (and copied map coordinates) get a map and Get Directions.
• Links get a page preview; sign-in and reset links are never opened.
• Code is colored, colors show a swatch with RGB, phone numbers and emails get Call and Write Email.
• Prefer something calmer? Switch previews off for a compact list.

PIN, COLLECT, FIND
• Pin what you reuse; group addresses, snippets or a project's links into collections.
• Search by text, or filter by kind (links, code, addresses, colors…) and date.

WIDGETS AND SHORTCUTS
• Recent clips on the Home Screen — also from a single collection — and the latest clip on the Lock Screen.
• Shortcuts actions: Get Clip, Get Latest Clip, Copy Latest Clip, Get Recent Clips, Save to Pastronaut, Add to Collection.

PRIVATE BY DESIGN
• No account, no servers, no analytics, no ads.
• Your clips sync between your devices through your own private iCloud database. Text is encrypted on your device before upload, and end-to-end encrypted with Advanced Data Protection.
• Optional Face ID lock. One-time codes, card numbers and IBANs are never saved automatically.

ALSO ON YOUR MAC (OPTIONAL)
Using a Mac? The free Pastronaut for Mac — a menu bar clipboard manager based on Maccy (not affiliated) — brings everything you copy on your Mac to your iPhone automatically. Get it from the website.

FREE AND OPEN SOURCE
No subscription, no in-app purchases, and the source code is public.
```

### Türkçe
```
iPhone yalnızca son kopyaladığın şeyi hatırlar. Pastronaut kaydettiklerinin geçmişini tutar; klavyesi de istediğini, her uygulamada, tek dokunuşla yapıştırır.

HER ŞEYİ, HER UYGULAMADA YAPIŞTIR
• Pastronaut klavyesi öğelerini en yenisi başta olmak üzere iki sütunlu düzenli bir ızgarada gösterir; az önce kopyaladığın hep en üsttedir.
• Son, sabitlenenler, Mac, iPhone ve her koleksiyonun için sekmeler; harf ve rakamlarla arama.
• Bir öğeye dokun, yazılsın. Basılı tut, fazlası çıksın.

TEK DOKUNUŞLA KAYDET
iOS panoyu yalnızca öndeki uygulamanın okumasına izin verir; Pastronaut kaydetmeyi tek dokunuşa indirir:
• Uygulamayı aç: "Açılınca Panoyu Kaydet" açıksa kopyaladığını kaydeder.
• Pastronaut klavyesinde Yapıştır'a dokun.
• Herhangi bir uygulamadan metni Pastronaut'la paylaş.
• Denetim Merkezi'ndeki Panoyu Kaydet düğmesini, Arkaya Dokun'u ya da Eylem düğmesini kullan.
• Ya da + ile yeni bir öğe yaz.

HER TÜRE AKILLI KART
• Adresler (ve kopyalanan harita koordinatları) harita ve Yol Tarifi ile gelir; Türk adreslerini de tanır.
• Bağlantılar sayfa önizlemesiyle gelir; giriş ve şifre sıfırlama bağlantıları hiç açılmaz.
• Kod renklenir, renkler RGB'li örnekle gösterilir, telefon ve e-postalarda Ara ve E-posta Yaz düğmeleri olur.
• Daha sade mi istersin? Önizlemeleri kapat, kompakt liste olsun.

SABİTLE, KOLEKSİYONLA, BUL
• Sık kullandıklarını sabitle; adresleri, parçacıkları ya da bir projenin bağlantılarını koleksiyonlarda topla.
• Metinle ara ya da türe (bağlantı, kod, adres, renk…) ve tarihe göre süz.

WIDGET'LAR VE KESTİRMELER
• Ana Ekran'da son öğeler (tek bir koleksiyondan da), Kilitli Ekran'da son öğe.
• Kestirmeler eylemleri: Öğe Al, Son Öğeyi Al, Son Öğeyi Kopyala, Son Öğeleri Al, Pastronaut'a kaydet, Koleksiyona Ekle.

GİZLİLİK ÖNCELİKLİ
• Hesap yok, sunucu yok, analiz yok, reklam yok.
• Öğelerin, kendi özel iCloud veritabanın üzerinden cihazların arasında eşitlenir. Metin yüklenmeden önce cihazında şifrelenir; Gelişmiş Veri Koruması açıksa uçtan uca şifrelidir.
• İsteğe bağlı Face ID kilidi. Tek kullanımlık kodlar, kart numaraları ve IBAN'lar kendiliğinden kaydedilmez.

MAC'İNDE DE (İSTEĞE BAĞLI)
Mac kullanıyor musun? Ücretsiz Pastronaut for Mac — Maccy'ye dayanan (onunla bağlantılı olmayan) bir menü çubuğu pano yöneticisi — Mac'te kopyaladığın her şeyi iPhone'una kendiliğinden getirir. Web sitesinden indir.

ÜCRETSİZ VE AÇIK KAYNAK
Abonelik yok, uygulama içi satın alma yok; kaynak kodu herkese açık.
```

## 7. What's New (1.0)
- EN: `First release: your clipboard history and a keyboard that pastes it, on iPhone.`
- TR: `İlk sürüm: pano geçmişin ve onu yapıştıran bir klavye, iPhone'da.`

## 8. Screenshots and header/search asset
All are made from device screenshots with made-up clips only (`PT_DEMO`), in each language.
1. SyncStepTests `storeShots` (`PT_SHOTS_LANG` = en / tr) saves them to `appstore-screenshots/raw/<lang>/`.
2. `cd scripts/store && swift run -c release StoreArt ../../appstore-screenshots/raw ../../appstore-screenshots/store`
   turns them into opaque PNGs (not in git).

**`store/<lang>/screenshot-1…6.png`, 1320 × 2868 (iPhone 6.9"):**
- App Store Connect scales them for smaller iPhones.
- The first three also show in search, so they carry the core: paste, smart cards, organize.
- The Mac comes last, as an extra.
- Captions name a benefit in a few words; every frame shows the real app.

| # | English | Turkish | Screen |
|---|---|---|---|
| 1 | Paste anything in one tap · Your clipboard history as a keyboard, in every app. | Her kopya tek dokunuşla · Pano geçmişin, her uygulamada klavyende. | Keyboard pasting an address into a note (light) |
| 2 | Smart cards for every kind · Maps for addresses, previews for links, colored code. | Her türe akıllı kart · Adrese harita, bağlantıya önizleme, koda renk. | Cards (light) |
| 3 | Pin and collect what you reuse · Addresses, snippets and links, together. | Sabitle, koleksiyonla · Adresler, parçacıklar, bağlantılar bir arada. | A collection (light) |
| 4 | Find any copy in seconds · Search by text, kind or date. | Aradığını saniyede bul · Metne, türe ya da tarihe göre ara. | Search with kind filters and the keyboard (dark) |
| 5 | Private by design · No account. No tracking. No ads. | Gizlilik öncelikli · Hesap yok. İzleme yok. Reklam yok. | List (light) |
| 6 | Also on your Mac · Your Mac copies arrive on their own. | Mac'inde de · Mac kopyaların kendiliğinden gelir. | Cards from the Mac (dark) |

**`store/<lang>/header-universal.png`, 5244 × 2950:**
- One file fills both the product page header (21:9) and the search result (3:2) slots. Both are optional and need iOS 27.
- The wordmark and the line "Every copy, one tap away. / Her kopya, bir dokunuş uzağında." sit in the centered safe
  area. The keyboard and card screens at the sides may be cropped.

**Rules followed:**
- every frame shows the real app;
- no prices, "free", URLs, awards or other platforms;
- the status bar is removed (time and Focus icons);
- 4+ content only.

**iPad:** not needed. The first release is iPhone-only (`TARGETED_DEVICE_FAMILY 1` for every target in
`iOS/project.yml`); iPad comes back after it is tested in the simulator.

## 9. App Privacy
- **Do you or your third-party partners collect data from this app?** → **No, we do not collect data from this app.**
  - The label becomes "Data Not Collected".
  - Apple's definition of "collect" is data sent off the device where the developer or partners can access it.
  - Data in the user's own CloudKit private database and Apple Maps lookups are Apple's services, which developers
    don't disclose.
  - Crash reports shared through Apple's opt-in aren't counted.
- **Tracking:** No.
- **Privacy manifest:** included in the app, keyboard, widgets and Share extension.

## 10. Age rating (expected 4+)
- **Step 1 Features:** No to all: Parental Controls, Age Assurance, Unrestricted Web Access, User-Generated Content,
  Social Media, Messaging and Chat, Advertising.
  - Links open in Safari.
  - The user's clips go only to their own devices.
- **Content steps:** None to everything (mature themes, medical/wellness, sexuality, violence, simulated gambling,
  contests). No for Gambling and Loot Boxes.
- **Age Categories and Override:** Not Applicable. Leave the Age Suitability URL empty.

## 11. Encryption (export compliance)
- `ITSAppUsesNonExemptEncryption = NO`: only the encryption built into Apple's OS (CloudKit encrypted fields, HTTPS).
- Nothing to upload. Not legal advice.

## 12. App Review notes [4000]
```
Pastronaut is a clipboard manager and clipboard keyboard for iPhone. It works on its own; a Mac is optional. No account or sign-in is needed.

To try it:
1. Copy some text in any app, then open Pastronaut — or tap + to type a clip, or share text to Pastronaut. (Settings › Save Clipboard on Opening saves copies when the app opens; iOS shows its own paste prompt.)
2. Add the keyboard: Settings › General › Keyboard › Keyboards › Add New Keyboard › Pastronaut. In any text field, switch to it with the globe key and tap a clip to type it.

The keyboard works without Full Access: it shows the saved history and types an item. Full Access is used only to read and update the history shared with the app (App Group), to fetch the user's own iCloud data, and to save a copy when the user taps Paste. It does not log or transmit keystrokes and has no network access other than the user's iCloud.

Link and map previews are off until the user allows them (asked once). Sign-in, reset and other one-time-looking links are never fetched.

Sync uses the user's private CloudKit database when signed in to iCloud. The optional Mac app is at https://github.com/xkbxyberk/pastronaut.

Privacy policy: in the app at Settings › About › Privacy Policy, and at https://xkbxyberk.github.io/pastronaut/privacy.html
```
