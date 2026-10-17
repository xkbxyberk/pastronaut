import CoreLocation
import LinkPresentation
import MapKit
import Observation
import PastronautCore
import SwiftUI
import UIKit

/// What the person chose when asked about previews. Until they answer, the history is a list and a card asks.
enum PreviewChoice: Int {
  case unasked = 0
  case on = 1
  case off = 2

  static let key = "richPreviews"

  /// Debug builds: the end-to-end test keeps the list (`PT_E2E`), screenshot steps can force a layout
  /// (`PT_E2E_PREVIEWS` = 1, 0 or ask).
  static var override: PreviewChoice? {
    #if DEBUG
    let environment = ProcessInfo.processInfo.environment
    if let forced = environment["PT_E2E_PREVIEWS"] {
      return forced == "1" ? .on : forced == "0" ? .off : .unasked
    }
    if environment["PT_E2E"] != nil { return .off }
    #endif
    return nil
  }

  static var current: PreviewChoice {
    override ?? PreviewChoice(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .unasked
  }
}

/// Map and page previews for the iPhone's cards. Only fetched with previews on, only for addresses and links that
/// `LinkPreviewPolicy` allows, and kept on this iPhone (Caches), never synced. Code coloring needs none of this.
@MainActor
@Observable
final class PreviewStore {
  static let shared = PreviewStore()

  struct Preview {
    var image: UIImage?
    var title: String?
  }

  private(set) var previews: [String: Preview] = [:]
  @ObservationIgnored private var attempted: Set<String> = []
  @ObservationIgnored private let directory = URL.cachesDirectory.appending(path: "Previews")

  private init() {}

  static var isEnabled: Bool {
    PreviewChoice.current == .on
  }

  func preview(for clip: Clip) -> Preview? {
    previews[clip.id]
  }

  /// Loads the clip's preview from the cache, or fetches it once per launch.
  func load(_ clip: Clip) async {
    guard Self.isEnabled, previews[clip.id] == nil, !attempted.contains(clip.id) else { return }
    let content = clip.content
    switch content {
    case .link, .address: break
    default: return
    }
    attempted.insert(clip.id)
    if let cached = readCache(clip.id) {
      previews[clip.id] = cached
      return
    }
    let fetched: Preview?
    switch content {
    case .link(let url):
      fetched = LinkPreviewPolicy.mayFetch(url) ? await fetchPage(url) : nil
    case .address(let address):
      fetched = await fetchMap(address)
    default:
      fetched = nil
    }
    guard let fetched else { return }
    previews[clip.id] = fetched
    writeCache(fetched, id: clip.id)
  }

  /// Drops every cached preview (previews turned off).
  func clear() {
    previews.removeAll()
    attempted.removeAll()
    try? FileManager.default.removeItem(at: directory)
  }

  // MARK: - Fetching

  private func fetchPage(_ url: URL) async -> Preview? {
    let provider = LPMetadataProvider()
    provider.timeout = 10
    guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return nil }
    var preview = Preview(image: nil, title: metadata.title)
    if let imageProvider = metadata.imageProvider ?? metadata.iconProvider {
      preview.image = await Self.loadImage(from: imageProvider)
    }
    return preview.title == nil && preview.image == nil ? nil : preview
  }

  private static func loadImage(from provider: NSItemProvider) async -> UIImage? {
    await withCheckedContinuation { continuation in
      _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
        let image = (object as? UIImage).flatMap { $0.preparingThumbnail(of: Self.fit($0.size, maxSide: 640)) }
        nonisolated(unsafe) let result = image
        continuation.resume(returning: result)
      }
    }
  }

  private nonisolated static func fit(_ size: CGSize, maxSide: CGFloat) -> CGSize {
    let scale = min(1, maxSide / max(size.width, size.height, 1))
    return CGSize(width: size.width * scale, height: size.height * scale)
  }

  private func fetchMap(_ address: String) async -> Preview? {
    // Turkish addresses often hold more than the map knows (building, floor, flat): try simpler forms in turn,
    // and show a wider area when only the district was found.
    var found: (CLLocationCoordinate2D, Int)?
    // Coordinates copied from a map app need no lookup.
    if let coordinates = Coordinates.parse(address) {
      found = (CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude), 0)
    }
    for (index, candidate) in TurkishAddress.geocodingCandidates(for: address).prefix(4).enumerated() where found == nil {
      if let coordinate = await Self.geocode(candidate) {
        found = (coordinate, index)
        break
      }
    }
    guard let (coordinate, index) = found else { return nil }
    let meters: CLLocationDistance = index >= 2 ? 4000 : 900
    let options = MKMapSnapshotter.Options()
    options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters)
    options.size = CGSize(width: 360, height: 200)
    options.pointOfInterestFilter = .excludingAll
    guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
    let point = snapshot.point(for: coordinate)
    let image = UIGraphicsImageRenderer(size: snapshot.image.size).image { _ in
      snapshot.image.draw(at: .zero)
      // A pin in the address color (ClipKind.address).
      let pin = CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)
      UIColor(red: 0.75, green: 0.34, blue: 0.06, alpha: 1).setFill()
      UIBezierPath(ovalIn: pin).fill()
      UIColor.white.setFill()
      UIBezierPath(ovalIn: pin.insetBy(dx: 7, dy: 7)).fill()
    }
    return Preview(image: image, title: nil)
  }

  private static func geocode(_ address: String) async -> CLLocationCoordinate2D? {
    if #available(iOS 26.0, *) {
      guard let request = MKGeocodingRequest(addressString: address),
            let item = try? await request.mapItems.first else { return nil }
      return item.location.coordinate
    }
    let placemarks = try? await CLGeocoder().geocodeAddressString(address)
    return placemarks?.first?.location?.coordinate
  }

  // MARK: - Cache

  private struct Stored: Codable {
    var title: String?
    var hasImage: Bool
  }

  private func readCache(_ id: String) -> Preview? {
    guard let data = try? Data(contentsOf: directory.appending(path: "\(id).json")),
          let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return nil }
    let image = stored.hasImage ? UIImage(contentsOfFile: directory.appending(path: "\(id).jpg").path) : nil
    return Preview(image: image, title: stored.title)
  }

  private func writeCache(_ preview: Preview, id: String) {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if let jpeg = preview.image?.jpegData(compressionQuality: 0.8) {
      try? jpeg.write(to: directory.appending(path: "\(id).jpg"))
    }
    let stored = Stored(title: preview.title, hasImage: preview.image != nil)
    try? JSONEncoder().encode(stored).write(to: directory.appending(path: "\(id).json"))
  }
}
