import Foundation

/// Which clips may leave the device.
public struct SyncPolicy: Sendable, Equatable {
  /// Larger texts stay local. CloudKit allows ~1 MB per record; this keeps records small and quota use low.
  public var maxTextBytes: Int

  public init(maxTextBytes: Int = 100_000) {
    self.maxTextBytes = maxTextBytes
  }

  public static let `default` = SyncPolicy()

  public func isEligible(_ text: String) -> Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.utf8.count <= maxTextBytes
  }

  /// Text by its size; media by having files. How large media may be is a shared setting (`MediaSettings`),
  /// checked when it is staged.
  public func isEligible(_ clip: Clip) -> Bool {
    clip.media.map { !$0.files.isEmpty } ?? isEligible(clip.text)
  }
}
