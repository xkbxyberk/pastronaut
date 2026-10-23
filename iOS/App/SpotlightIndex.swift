import CoreSpotlight
import Foundation
import PastronautCore
import UniformTypeIdentifiers

/// Optional: pinned clips in the iPhone's search (Spotlight). Off by default, and kept empty while the app lock is
/// on, since Spotlight would show what the lock hides. Choosing a result copies the clip.
@MainActor
enum SpotlightIndex {
  static let settingKey = "spotlightPinnedClips"
  private static let domain = "pinned"
  /// What is indexed now, so an unchanged history doesn't rebuild the index on every reload.
  private static let signatureKey = "spotlightIndexedClips"

  static var isEnabled: Bool {
    UserDefaults.standard.bool(forKey: settingKey) && !SharedSettings.isAppLockEnabled
  }

  static func update(with clips: [Clip]) {
    let pinned = isEnabled ? clips.filter { $0.pinned && !$0.isMedia } : []
    let signature = pinned.map(\.id).sorted().joined(separator: ",")
    let defaults = UserDefaults.standard
    guard signature != defaults.string(forKey: signatureKey) ?? "" else { return }
    defaults.set(signature, forKey: signatureKey)

    let items = pinned.map(item(for:))
    let index = CSSearchableIndex.default()
    index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
      guard !items.isEmpty else { return }
      index.indexSearchableItems(items)
    }
  }

  static func clipID(from activity: NSUserActivity) -> String? {
    activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
  }

  private static func item(for clip: Clip) -> CSSearchableItem {
    let attributes = CSSearchableItemAttributeSet(contentType: .text)
    attributes.title = String(clip.preview.prefix(120))
    attributes.contentDescription = String(clip.text.prefix(500))
    attributes.displayName = attributes.title
    let item = CSSearchableItem(uniqueIdentifier: clip.id, domainIdentifier: domain, attributeSet: attributes)
    item.expirationDate = .distantFuture
    return item
  }
}
