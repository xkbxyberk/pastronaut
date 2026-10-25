#if DEBUG
import PastronautCore
import UIKit

/// Made-up images, a PDF and files for screenshots (`PT_DEMO=1`), drawn here so nothing personal is on screen. Their
/// files go to the media store like real ones; nothing is synced, and the next real launch prunes them.
/// The Mac apps are made up (DemoIcons): no real app's icon shows up in store pictures.
enum DemoMedia {
  private static var isTurkish: Bool { Bundle.main.preferredLocalizations.first == "tr" }

  static func make() async -> [Clip] {
    guard let store = MediaFiles.store else { return [] }
    let tr = isTurkish
    let now = Date.now
    var clips: [Clip] = []

    func add(_ parts: [MediaIntake.Part], minutesAgo: Double, device: Clip.Device, app: String? = nil,
             bundle: String? = nil, pinned: Bool = false, title: String? = nil, collections: [String] = []) async {
      let date = now.addingTimeInterval(-minutesAgo * 60)
      guard var prepared = await MediaIntake.prepare(
        parts, sourceApp: bundle, sourceAppName: app, device: device, copiedAt: date, pinned: pinned
      ) else { return }
      prepared.clip.collectionIDs = collections
      if let title { prepared.clip.setTitle(title, at: date) }
      try? MediaIntake.store(prepared, in: store)
      clips.append(prepared.clip)
    }

    if let shot = screenshot(tr: tr).pngData(),
       let part = MediaIntake.image(shot, quality: .optimized, maxBytes: 10_000_000) {
      await add([part], minutesAgo: 2, device: .mac, app: DemoIcons.viewer.name, bundle: DemoIcons.viewer.bundleIdentifier)
    }
    if let photo = landscape().jpegData(compressionQuality: 0.8),
       let part = MediaIntake.image(photo, quality: .optimized, maxBytes: 10_000_000) {
      await add([part], minutesAgo: 12, device: .iphone, title: tr ? "Kapadokya, ikinci gün" : "Cappadocia, day two",
                collections: ["col-demo-travel"])
    }
    // Its words are only in the picture, so searching them shows text recognition at work.
    if let poster = poster(tr: tr).jpegData(compressionQuality: 0.85),
       let part = MediaIntake.image(poster, quality: .optimized, maxBytes: 10_000_000) {
      // The title doesn't give the poster's words away.
      await add([part], minutesAgo: 30, device: .iphone, title: tr ? "Konser afişi" : "Concert poster")
    }
    await add([MediaIntake.pdf(invoice(tr: tr), name: tr ? "Fatura-2026-10.pdf" : "Invoice-2026-10.pdf")],
              minutesAgo: 6, device: .mac, app: DemoIcons.mail.name, bundle: DemoIcons.mail.bundleIdentifier, pinned: true)
    await add([
      MediaIntake.file(named: tr ? "rapor-q3.pdf" : "report-q3.pdf", data: invoice(tr: tr)),
      MediaIntake.file(named: tr ? "butce-2026.xlsx" : "budget-2026.xlsx", data: Data(repeating: 7, count: 48_000)),
      MediaIntake.file(named: tr ? "notlar.txt" : "notes.txt", data: Data((tr ? "Toplantı notları" : "Meeting notes").utf8))
    ], minutesAgo: 70, device: .mac, app: DemoIcons.files.name, bundle: DemoIcons.files.bundleIdentifier)
    return clips
  }

  /// A browser-like page with a boarding pass, so the text in it can be read.
  private static func screenshot(tr: Bool) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 1240, height: 820)).image { context in
      UIColor(red: 0.86, green: 0.91, blue: 0.95, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1240, height: 820))
      let card = UIBezierPath(roundedRect: CGRect(x: 320, y: 90, width: 600, height: 640), cornerRadius: 36)
      UIColor.white.setFill()
      card.fill()
      func draw(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight, _ y: CGFloat, _ color: UIColor = .black) {
        (text as NSString).draw(at: CGPoint(x: 370, y: y), withAttributes: [
          .font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
        ])
      }
      draw(tr ? "BİNİŞ KARTI" : "BOARDING PASS", 30, .bold, 140, .darkGray)
      draw("IST → LIS", 92, .heavy, 190)
      draw(tr ? "İstanbul → Lizbon · 18:40" : "Istanbul → Lisbon · 18:40", 34, .regular, 320, .darkGray)
      draw(tr ? "Kapı B12        Koltuk 14A" : "Gate B12        Seat 14A", 36, .semibold, 420)
      UIColor(red: 0.12, green: 0.44, blue: 0.66, alpha: 1).setFill()
      context.fill(CGRect(x: 370, y: 540, width: 500, height: 120))
    }
  }

  /// A photo of a concert poster: its words exist only in the picture.
  private static func poster(tr: Bool) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600)).image { context in
      UIColor(red: 0.93, green: 0.90, blue: 0.84, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
      let sheet = CGRect(x: 170, y: 140, width: 860, height: 1320)
      UIColor(red: 0.10, green: 0.16, blue: 0.29, alpha: 1).setFill()
      UIBezierPath(rect: sheet).fill()
      UIColor(red: 0.95, green: 0.71, blue: 0.27, alpha: 1).setFill()
      UIBezierPath(ovalIn: CGRect(x: 380, y: 260, width: 440, height: 440)).fill()
      func draw(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight, _ y: CGFloat, _ color: UIColor) {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        (text as NSString).draw(at: CGPoint(x: 600 - width / 2, y: y), withAttributes: [.font: font, .foregroundColor: color])
      }
      let cream = UIColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1)
      draw(tr ? "CAZ GECESİ" : "JAZZ NIGHT", 112, .heavy, 780, cream)
      draw(tr ? "7 Kasım · 21:00" : "November 7 · 9 pm", 60, .semibold, 940, cream)
      draw(tr ? "Lumen Sahnesi" : "Lumen Stage", 60, .regular, 1030, cream)
      draw(tr ? "Bilet kapıda" : "Tickets at the door", 44, .regular, 1250, cream.withAlphaComponent(0.8))
    }
  }

  /// Hills under a sky: a holiday photo without anyone in it.
  private static func landscape() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1200)).image { context in
      UIColor(red: 0.75, green: 0.88, blue: 0.95, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1200))
      UIColor(red: 0.95, green: 0.71, blue: 0.27, alpha: 1).setFill()
      UIBezierPath(ovalIn: CGRect(x: 1120, y: 180, width: 200, height: 200)).fill()
      let back = UIBezierPath()
      back.move(to: CGPoint(x: 0, y: 900)); back.addLine(to: CGPoint(x: 430, y: 500)); back.addLine(to: CGPoint(x: 780, y: 820))
      back.addLine(to: CGPoint(x: 1050, y: 620)); back.addLine(to: CGPoint(x: 1600, y: 980)); back.addLine(to: CGPoint(x: 1600, y: 1200))
      back.addLine(to: CGPoint(x: 0, y: 1200)); back.close()
      UIColor(red: 0.44, green: 0.64, blue: 0.50, alpha: 1).setFill()
      back.fill()
      let front = UIBezierPath()
      front.move(to: CGPoint(x: 0, y: 1060)); front.addLine(to: CGPoint(x: 500, y: 820)); front.addLine(to: CGPoint(x: 940, y: 1010))
      front.addLine(to: CGPoint(x: 1400, y: 860)); front.addLine(to: CGPoint(x: 1600, y: 920)); front.addLine(to: CGPoint(x: 1600, y: 1200))
      front.addLine(to: CGPoint(x: 0, y: 1200)); front.close()
      UIColor(red: 0.31, green: 0.54, blue: 0.39, alpha: 1).setFill()
      front.fill()
    }
  }

  /// A one-page invoice with no real amounts.
  private static func invoice(tr: Bool) -> Data {
    UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { context in
      context.beginPage()
      func draw(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight, _ y: CGFloat) {
        (text as NSString).draw(at: CGPoint(x: 60, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: weight)])
      }
      draw(tr ? "FATURA" : "INVOICE", 30, .heavy, 70)
      draw(tr ? "No 2026-104 · 21 Ekim 2026" : "No 2026-104 · 21 October 2026", 13, .regular, 115)
      draw(tr ? "Hizmet bedeli" : "Services", 14, .regular, 220)
      draw(tr ? "KDV" : "VAT", 14, .regular, 250)
      draw(tr ? "Toplam" : "Total", 16, .bold, 300)
    }
  }
}
#endif
