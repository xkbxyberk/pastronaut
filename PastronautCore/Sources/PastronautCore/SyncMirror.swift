import Foundation

/// Clips and collections a device keeps although iCloud no longer has them: iCloud data was deleted, or the
/// device signed out of (or switched) its iCloud account. They are never sent on their own; "Upload to iCloud
/// Again" (`ClipSync.uploadLocalOnly`) sends them.
public struct LocalOnlyIDs: Codable, Equatable, Sendable {
  public var clips: Set<String>
  public var collections: Set<String>

  public init(clips: Set<String> = [], collections: Set<String> = []) {
    self.clips = clips
    self.collections = collections
  }

  public var isEmpty: Bool { clips.isEmpty && collections.isEmpty }
}

/// The mirror's rules, kept apart from CloudKit so they can be tested without an iCloud account.
extension ClipSync.PersistedState {
  var localOnly: LocalOnlyIDs {
    LocalOnlyIDs(
      clips: Set(entries.filter(\.value.isLocalOnly).keys),
      collections: Set(collections.filter(\.value.isLocalOnly).keys)
    )
  }

  /// Clips that may be sent to iCloud.
  var uploadableClipIDs: [String] {
    entries.filter { !$0.value.isLocalOnly }.map(\.key)
  }

  /// Clips and collections never saved under the current key, and not held back as local-only.
  var unsentClipIDs: [String] {
    entries.filter { $0.value.systemFields == nil && !$0.value.isLocalOnly }.map(\.key)
  }

  var unsentCollectionIDs: [String] {
    collections.filter { $0.value.systemFields == nil && !$0.value.isLocalOnly }.map(\.key)
  }

  /// Merges a local change into the mirror; false when the clip is not eligible or nothing changed.
  /// A later copy time marks the clip as copied here since the server last had it. A capture (the text was
  /// copied again) is new data and syncs even for a local-only clip; tapping, pinning or editing one doesn't.
  ///
  /// `privacy` keeps matching clips (codes, cards) on this device: a new one is local-only from the start, and a
  /// capture never sends one.
  mutating func stage(
    _ clip: Clip,
    policy: SyncPolicy,
    isCapture: Bool = false,
    privacy: PrivacyOptions = PrivacyOptions()
  ) -> Bool {
    guard policy.isEligible(clip.text) else { return false }
    let existing = entries[clip.id]
    let merged = existing.map { $0.clip.merged(with: clip) } ?? clip
    let allowed = privacy.allows(merged.text, pinned: merged.pinned)
    let isLocalOnly = existing.map { $0.isLocalOnly && !(isCapture && allowed) } ?? !allowed
    let releases = existing?.isLocalOnly == true && !isLocalOnly
    guard merged != existing?.clip || releases else { return false }
    let copiedAgain = merged.lastCopiedAt > existing?.clip.lastCopiedAt ?? .distantPast
    entries[clip.id] = ClipSync.MirrorEntry(
      clip: merged,
      systemFields: existing?.systemFields,
      isLocalOnly: isLocalOnly,
      hasUnsentCopy: (existing?.hasUnsentCopy ?? false) || copiedAgain
    )
    legacyTombstones.remove(clip.id)
    return true
  }

  /// iCloud lost the zone. Clips in `keeping` were changed here and never arrived: they are sent again under
  /// the new key. Everything else is dropped, or kept as local-only when the mirror is the device's history.
  /// Returns the collections the caller should forget.
  mutating func forgetCloud(keeping: Set<String>, keepsLocalHistory: Bool) -> [ClipChange] {
    if keepsLocalHistory {
      entries = entries.mapValues { entry in
        var entry = entry
        entry.isLocalOnly = entry.isLocalOnly || !keeping.contains(entry.clip.id)
        entry.systemFields = nil
        entry.hasUnsentCopy = false
        return entry
      }
      collections = collections.mapValues { entry in
        var entry = entry
        entry.isLocalOnly = true
        entry.systemFields = nil
        return entry
      }
      return []
    }
    let forgotten = collections.keys.map { ClipChange.collectionDeleted(id: $0) }
    entries = entries.filter { keeping.contains($0.key) }.mapValues {
      ClipSync.MirrorEntry(clip: $0.clip, systemFields: nil)
    }
    collections.removeAll()
    return forgotten
  }

  /// The device signed out of iCloud or switched accounts: nothing of the old account may reach a new one.
  mutating func forgetAccount(keepsLocalHistory: Bool) {
    guard keepsLocalHistory else {
      entries.removeAll()
      return
    }
    _ = forgetCloud(keeping: [], keepsLocalHistory: true)
  }

  /// Clears the local-only marks so the clips and collections are sent again. Returns what was released.
  /// Clips that `privacy` keeps on this device stay.
  mutating func releaseLocalOnly(privacy: PrivacyOptions = PrivacyOptions()) -> LocalOnlyIDs {
    var released = localOnly
    released.clips = released.clips.filter { id in
      entries[id].map { privacy.allows($0.clip.text, pinned: $0.clip.pinned) } ?? false
    }
    for id in released.clips {
      entries[id]?.isLocalOnly = false
    }
    for id in released.collections {
      collections[id]?.isLocalOnly = false
    }
    return released
  }

  enum DeletedElsewhere: Equatable {
    /// Copied here since: the new copy brings the clip back.
    case recreate
    /// Only changed here (pin, collections): the deletion wins and the clip leaves the mirror.
    case deleted
  }

  /// A save failed because another device deleted the clip's record.
  mutating func resolveDeletedElsewhere(clipID: String) -> DeletedElsewhere {
    guard let entry = entries[clipID] else { return .deleted }
    if entry.hasUnsentCopy {
      entries[clipID]?.systemFields = nil
      return .recreate
    }
    entries.removeValue(forKey: clipID)
    return .deleted
  }
}
