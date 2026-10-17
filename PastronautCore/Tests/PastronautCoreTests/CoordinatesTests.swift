import Foundation
import Testing
@testable import PastronautCore

@Suite struct CoordinatesTests {
  private func near(_ coordinates: Coordinates?, _ latitude: Double, _ longitude: Double) -> Bool {
    guard let coordinates else { return false }
    return abs(coordinates.latitude - latitude) < 0.0001 && abs(coordinates.longitude - longitude) < 0.0001
  }

  @Test func googleMapsDecimal() {
    #expect(near(Coordinates.parse("38.4237, 27.1428"), 38.4237, 27.1428))
    #expect(near(Coordinates.parse("38.42370512,27.14281234"), 38.4237, 27.1428))
    #expect(near(Coordinates.parse("(-33.8688, 151.2093)"), -33.8688, 151.2093))
  }

  @Test func appleMapsHemispheres() {
    #expect(near(Coordinates.parse("38.4237° N, 27.1428° E"), 38.4237, 27.1428))
    #expect(near(Coordinates.parse("38,4237° K, 27,1428° D"), 38.4237, 27.1428))
    #expect(near(Coordinates.parse("40.7128° N, 74.0060° W"), 40.7128, -74.006))
    #expect(near(Coordinates.parse("33,8688° G, 151,2093° D"), -33.8688, 151.2093))
  }

  @Test func degreesMinutesSeconds() {
    #expect(near(Coordinates.parse(#"38°25'25.3"N 27°08'34.1"E"#), 38.423694, 27.142806))
    #expect(near(Coordinates.parse("38°25′25.3″N 27°08′34.1″E"), 38.423694, 27.142806))
  }

  @Test func notCoordinates() {
    for text in ["1.5, 2.25", "12.345, 678.901", "2026-10-17", "38.4237", "0532 123 45 67", "Fiyat: 12.500, 13.750",
                 "91.0000, 27.0000", "38.4237° E, 27.1428° N"] {
      #expect(Coordinates.parse(text) == nil, "\(text)")
    }
  }

  @Test func coordinatesAreAddresses() {
    #expect(ClipContent("38.4237, 27.1428").kind == .address)
    #expect(ClipContent("38,4237° K, 27,1428° D").kind == .address)
    let url = Coordinates.directionsURL(to: #"38°25'25.3"N 27°08'34.1"E"#)?.absoluteString ?? ""
    #expect(url.contains("daddr=38.423694,27.142806"))
  }
}
