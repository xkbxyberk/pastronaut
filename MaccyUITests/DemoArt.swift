import AppKit

/// Made-up pictures for the Mac's store screenshots, drawn like the iPhone's demo (iOS/App/DemoMedia.swift) so both
/// devices show the same story. Nothing personal; PNG and PDF bytes ready for the pasteboard.
enum DemoArt {
  private static func png(_ size: CGSize, _ draw: @escaping (CGContext) -> Void) -> Data {
    let image = NSImage(size: size, flipped: true) { _ in
      if let context = NSGraphicsContext.current?.cgContext { draw(context) }
      return true
    }
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
  }

  private static func text(_ string: String, size: CGFloat, weight: NSFont.Weight, at point: CGPoint,
                           color: NSColor = .black, centeredIn width: CGFloat? = nil) {
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
    var origin = point
    if let width { origin.x = (width - (string as NSString).size(withAttributes: attributes).width) / 2 }
    (string as NSString).draw(at: origin, withAttributes: attributes)
  }

  /// A browser-like page with a boarding pass, so the text in it can be read.
  static func boardingPass(tr: Bool) -> Data {
    png(CGSize(width: 1240, height: 820)) { context in
      context.setFillColor(NSColor(red: 0.86, green: 0.91, blue: 0.95, alpha: 1).cgColor)
      context.fill(CGRect(x: 0, y: 0, width: 1240, height: 820))
      context.setFillColor(NSColor.white.cgColor)
      context.addPath(CGPath(roundedRect: CGRect(x: 320, y: 90, width: 600, height: 640), cornerWidth: 36, cornerHeight: 36, transform: nil))
      context.fillPath()
      text(tr ? "BİNİŞ KARTI" : "BOARDING PASS", size: 30, weight: .bold, at: CGPoint(x: 370, y: 140), color: .darkGray)
      text("IST → LIS", size: 92, weight: .heavy, at: CGPoint(x: 370, y: 190))
      text(tr ? "İstanbul → Lizbon · 18:40" : "Istanbul → Lisbon · 18:40", size: 34, weight: .regular, at: CGPoint(x: 370, y: 320), color: .darkGray)
      text(tr ? "Kapı B12        Koltuk 14A" : "Gate B12        Seat 14A", size: 36, weight: .semibold, at: CGPoint(x: 370, y: 420))
      context.setFillColor(NSColor(red: 0.12, green: 0.44, blue: 0.66, alpha: 1).cgColor)
      context.fill(CGRect(x: 370, y: 540, width: 500, height: 120))
    }
  }

  /// A photo of a concert poster: its words exist only in the picture.
  static func poster(tr: Bool) -> Data {
    png(CGSize(width: 1200, height: 1600)) { context in
      context.setFillColor(NSColor(red: 0.93, green: 0.90, blue: 0.84, alpha: 1).cgColor)
      context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
      context.setFillColor(NSColor(red: 0.10, green: 0.16, blue: 0.29, alpha: 1).cgColor)
      context.fill(CGRect(x: 170, y: 140, width: 860, height: 1320))
      context.setFillColor(NSColor(red: 0.95, green: 0.71, blue: 0.27, alpha: 1).cgColor)
      context.fillEllipse(in: CGRect(x: 380, y: 260, width: 440, height: 440))
      let cream = NSColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1)
      text(tr ? "CAZ GECESİ" : "JAZZ NIGHT", size: 112, weight: .heavy, at: CGPoint(x: 0, y: 780), color: cream, centeredIn: 1200)
      text(tr ? "7 Kasım · 21:00" : "November 7 · 9 pm", size: 60, weight: .semibold, at: CGPoint(x: 0, y: 940), color: cream, centeredIn: 1200)
      text(tr ? "Lumen Sahnesi" : "Lumen Stage", size: 60, weight: .regular, at: CGPoint(x: 0, y: 1030), color: cream, centeredIn: 1200)
      text(tr ? "Bilet kapıda" : "Tickets at the door", size: 44, weight: .regular, at: CGPoint(x: 0, y: 1250),
           color: cream.withAlphaComponent(0.8), centeredIn: 1200)
    }
  }

  /// Hills under a sky: a holiday photo without anyone in it.
  static func landscape() -> Data {
    png(CGSize(width: 1600, height: 1200)) { context in
      context.setFillColor(NSColor(red: 0.75, green: 0.88, blue: 0.95, alpha: 1).cgColor)
      context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1200))
      context.setFillColor(NSColor(red: 0.95, green: 0.71, blue: 0.27, alpha: 1).cgColor)
      context.fillEllipse(in: CGRect(x: 1120, y: 180, width: 200, height: 200))
      func hills(_ points: [CGPoint], _ color: NSColor) {
        context.setFillColor(color.cgColor)
        context.addLines(between: points + [CGPoint(x: 1600, y: 1200), CGPoint(x: 0, y: 1200)])
        context.fillPath()
      }
      hills([CGPoint(x: 0, y: 900), CGPoint(x: 430, y: 500), CGPoint(x: 780, y: 820), CGPoint(x: 1050, y: 620), CGPoint(x: 1600, y: 980)],
            NSColor(red: 0.44, green: 0.64, blue: 0.50, alpha: 1))
      hills([CGPoint(x: 0, y: 1060), CGPoint(x: 500, y: 820), CGPoint(x: 940, y: 1010), CGPoint(x: 1400, y: 860), CGPoint(x: 1600, y: 920)],
            NSColor(red: 0.31, green: 0.54, blue: 0.39, alpha: 1))
    }
  }

  /// A one-page invoice with no real amounts.
  static func invoice(tr: Bool) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 595, height: 842)
    guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
    context.beginPDFPage(nil)
    // A white page, as printed: a page picture without it would be see-through.
    context.setFillColor(NSColor.white.cgColor)
    context.fill(box)
    // Flipped, so the lines go top down like the iPhone's.
    context.translateBy(x: 0, y: 842)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    text(tr ? "FATURA" : "INVOICE", size: 30, weight: .heavy, at: CGPoint(x: 60, y: 70))
    text(tr ? "No 2026-104 · 21 Ekim 2026" : "No 2026-104 · 21 October 2026", size: 13, weight: .regular, at: CGPoint(x: 60, y: 115))
    text(tr ? "Hizmet bedeli" : "Services", size: 14, weight: .regular, at: CGPoint(x: 60, y: 220))
    text(tr ? "KDV" : "VAT", size: 14, weight: .regular, at: CGPoint(x: 60, y: 250))
    text(tr ? "Toplam" : "Total", size: 16, weight: .bold, at: CGPoint(x: 60, y: 300))
    NSGraphicsContext.restoreGraphicsState()
    context.endPDFPage()
    context.closePDF()
    return data as Data
  }
}
