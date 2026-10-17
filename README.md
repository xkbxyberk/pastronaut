<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/brand/pastronaut-wordmark-dark.svg">
  <img width="320" src="docs/brand/pastronaut-wordmark-light.svg" alt="Pastronaut">
</picture>

**Copy on your Mac, paste on your iPhone.** Pastronaut is a free, open-source clipboard manager for macOS that
brings your history to iPhone and iPad through your own iCloud: a history in the menu bar on the Mac; cards, a
keyboard, widgets and Shortcuts on the iPhone.

> Pastronaut is based on [Maccy](https://github.com/p0deje/Maccy) (MIT) and is **not affiliated with Maccy** or its
> author. Thank you, Maccy.

Türkçe: Mac'te kopyaladığın her şey, kendi iCloud'un üzerinden iPhone'da. Ücretsiz, açık kaynak, reklamsız.

* [Features](#features)
* [Privacy](#privacy)
* [Requirements](#requirements)
* [Mac usage](#mac-usage)
* [iPhone usage](#iphone-usage)
* [Building](#building)
* [License](#license)

## Features

**Mac** (macOS 14 or later)
* Everything Maccy does: fast, keyboard-first history in the menu bar, search, pins, ignore rules.
* Colored icons by kind: text, link, code, email, phone, address (also map coordinates), color, image, file.
* Space shows a preview that fits the kind: code in color, a color swatch, buttons to open a link, get directions,
  write an email or call.
* Queue: select several items and paste them one after another, each ⌘V the next one.
* Filters typed into the search: `type:link`, `app:Safari`, `date:yesterday`, `from:iphone`
  (also `tür:`, `uygulama:`, `tarih:`, `cihaz:`). ⌘G shows a found item in the whole history.
* Collections, a timed pause, undo after deleting, hiding from screen sharing, export and import.

**iPhone and iPad** (iOS 17 or later)
* The shared history as a list, or as cards with link and map previews (optional, asked once).
* A keyboard that types any item with one tap, with categories, collections and search.
* Widgets, a Control Center button and Shortcuts actions: Get Clip, Get Latest Clip, Copy Latest Clip, Get Recent
  Clips, Save to Pastronaut, Add to Collection.
* Copies made on the iPhone join the history when you open the app, tap Paste in the keyboard, share text to
  Pastronaut, or use the Control Center button, Back Tap or the Action button. (iOS doesn't let apps read the
  clipboard in the background.)

## Privacy

Pastronaut collects no data and runs no servers. Clips are synced through your **private** iCloud database; text,
source app and collection names are end-to-end encrypted, and record names are derived with a key unique to your
account. Concealed copies (password managers) are never saved, and one-time codes and card numbers can be kept out
of sync. Read the full [privacy policy](docs/site/privacy.html).

## Requirements

* macOS 14 or later, iOS 17 or later.
* The same Apple Account signed in to iCloud on both devices, for sync.

## Mac usage

1. <kbd>⇧</kbd> <kbd>⌘</kbd> <kbd>C</kbd> opens the history, or click the menu bar icon.
2. Type to search; <kbd>Return</kbd> copies, <kbd>⌥</kbd> <kbd>Return</kbd> pastes, <kbd>⌘</kbd> + `n` picks item `n`.
3. <kbd>Space</kbd> (with the search empty) shows the preview; <kbd>⌥</kbd> <kbd>P</kbd> pins; <kbd>⌥</kbd> <kbd>⌫</kbd> deletes.
4. <kbd>⌘</kbd>-click or <kbd>⇧</kbd> <kbd>↓</kbd> selects several items; <kbd>Return</kbd> starts a queue.
5. Right-click the menu bar icon to pause copying for a while.

Pasting and the queue need Pastronaut in System Settings › Privacy & Security › Accessibility
("Device Control and Data Access" on macOS 27).

## iPhone usage

1. Open Pastronaut and follow the keyboard setup (Settings › General › Keyboard › Keyboards › Add New Keyboard,
   then Allow Full Access).
2. Switch to the Pastronaut keyboard with 🌐 in any app and tap an item to type it.

## Building

* Mac: `xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Debug build`
  (the Swift module is still called `Maccy` to keep merging upstream easy).
* iPhone: `cd iOS && xcodegen generate`, then build the `Pastronaut` scheme of `iOS/Pastronaut-iOS.xcodeproj`.
* Shared code and its tests: `cd PastronautCore && swift test`.

Design notes (Turkish): [docs/pastronaut/TASARIM.md](docs/pastronaut/TASARIM.md).

## License

[MIT](./LICENSE). The Maccy copyright notice is kept; third-party licenses are listed in the apps (Settings ›
Licenses). The wordmark uses the Unbounded typeface ([SIL OFL](docs/brand/Unbounded-OFL.txt)).
