#if DEBUG
import Foundation
import PastronautCore

/// Made-up clips for screenshots (README, App Store): launched with `PT_DEMO=1`, the app shows these instead of
/// the synced history and never starts sync, so nothing personal is on screen and nothing is written to iCloud.
enum DemoClips {
  static var isOn: Bool { ProcessInfo.processInfo.environment["PT_DEMO"] == "1" }

  /// Turkish clips when the app runs in Turkish (store screenshots for the Turkish page).
  private static var isTurkish: Bool { Bundle.main.preferredLocalizations.first == "tr" }

  static var snippets: ClipCollection {
    ClipCollection(id: "col-demo-snippets", name: isTurkish ? "Parçacıklar" : "Snippets", order: 0)
  }
  static var travel: ClipCollection {
    ClipCollection(id: "col-demo-travel", name: isTurkish ? "Seyahat" : "Travel", order: 1)
  }
  static var collections: [ClipCollection] { [snippets, travel] }

  static var clips: [Clip] {
    let now = Date.now
    let tr = isTurkish
    func clip(
      _ text: String, _ device: Clip.Device, minutesAgo: Double, app: String? = nil, pinned: Bool = false,
      in collections: [ClipCollection] = []
    ) -> Clip {
      let date = now.addingTimeInterval(-minutesAgo * 60)
      return Clip(
        text: text, sourceAppName: app, sourceDevice: device, firstCopiedAt: date, pinned: pinned,
        collectionIDs: collections.map(\.id)
      )
    }
    let greeting = tr ? "Merhaba" : "Hello"
    return [
      clip("https://developer.apple.com/documentation/cloudkit", .mac, minutesAgo: 1, app: "Safari"),
      clip("Galata Kulesi, Bereketzade Mah., Galata Kulesi Sk., 34421 Beyoğlu/İstanbul", .iphone, minutesAgo: 4,
           in: [travel]),
      clip("""
      func greet(_ name: String) -> String {
        // \(tr ? "Selam ver" : "Say hello")
        return "\(greeting), \\(name)!"
      }
      """, .mac, minutesAgo: 9, app: "Xcode", in: [snippets]),
      clip("#5B4BD0", .mac, minutesAgo: 15, app: "Figma"),
      clip(tr ? "Toplantı perşembe 14:00'e alındı, 3B salonu. Basılı slaytları getir."
              : "Meeting moved to Thursday 2 pm, room 3B. Bring the printed slides.", .iphone, minutesAgo: 22),
      clip(tr ? "merhaba@example.com" : "hello@example.com", .mac, minutesAgo: 35, app: "Mail", pinned: true),
      clip("+1 555 0100 2030", .iphone, minutesAgo: 48),
      clip("git push origin main", .mac, minutesAgo: 60, app: "Terminal", in: [snippets]),
      clip("41.0256, 28.9741", .iphone, minutesAgo: 80, in: [travel]),
      clip(tr ? "B12 kapısı · Biniş 18:40 · Koltuk 14A" : "Gate B12 · Boarding 18:40 · Seat 14A", .iphone,
           minutesAgo: 120, pinned: true, in: [travel]),
      clip("swift test --parallel", .mac, minutesAgo: 180, app: "Terminal", in: [snippets])
    ]
  }
}
#endif
