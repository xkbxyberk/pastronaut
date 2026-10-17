import AppKit
import SwiftUI
import Testing
@testable import PastronautCore

@MainActor
@Suite struct BrandTests {
  @Test func lettersFitTheirBounds() {
    let letters = PastronautWordmark.letters.boundingRect
    #expect(!letters.isEmpty)
    #expect(PastronautWordmark.bounds.contains(letters))
    // "Pastr", then the helmet, then "naut": the helmet sits between the two words.
    #expect(letters.minX < PastronautWordmark.helmetCenter.x && PastronautWordmark.helmetCenter.x < letters.maxX)
  }

  @Test func orbitHalvesMeetAtTheEnds() {
    let back = PastronautWordmark.orbit.back.boundingRect
    let front = PastronautWordmark.orbit.front.boundingRect
    #expect(abs(back.minX - front.minX) < 1 && abs(back.maxX - front.maxX) < 1)
  }

  @Test func rendersAtTheRequestedSize() throws {
    for dark in [false, true] {
      let view = PastronautWordmark(size: 40)
        .padding(12)
        .background(dark ? Color(red: 0.055, green: 0.133, blue: 0.212) : Color.white)
        .environment(\.colorScheme, dark ? .dark : .light)
      let renderer = ImageRenderer(content: view)
      renderer.scale = 2
      let image = try #require(renderer.nsImage)
      #expect(abs(image.size.width - (PastronautWordmark.bounds.width * 0.4 + 24)) < 1)
      // Set PT_WORDMARK_PNG to a folder to look at the result.
      if let folder = ProcessInfo.processInfo.environment["PT_WORDMARK_PNG"],
         let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
         let png = bitmap.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: folder).appending(path: dark ? "wordmark-dark.png" : "wordmark-light.png"))
      }
    }
  }
}
