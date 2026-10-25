#if DEBUG
import UIKit

/// Made-up Mac apps for the demo clips (`PT_DEMO`), with icons drawn here: store pictures show where a clip came
/// from without Apple's or anyone else's app icons. Plain shapes only (no SF Symbols, whose license excludes icons).
enum DemoIcons {
  struct App {
    let bundleIdentifier: String
    let name: String
  }

  static let browser = App(bundleIdentifier: "demo.pastronaut.nimbo", name: "Nimbo")
  static let editor = App(bundleIdentifier: "demo.pastronaut.codera", name: "Codera")
  static let design = App(bundleIdentifier: "demo.pastronaut.huebox", name: "Huebox")
  static let mail = App(bundleIdentifier: "demo.pastronaut.mailo", name: "Mailo")
  static let terminal = App(bundleIdentifier: "demo.pastronaut.shellby", name: "Shellby")
  static let viewer = App(bundleIdentifier: "demo.pastronaut.viewly", name: "Viewly")
  static let files = App(bundleIdentifier: "demo.pastronaut.filo", name: "Filo")

  nonisolated(unsafe) private static var cache: [String: UIImage] = [:]

  static func image(for bundleIdentifier: String) -> UIImage? {
    guard bundleIdentifier.hasPrefix("demo.pastronaut.") else { return nil }
    if let hit = cache[bundleIdentifier] { return hit }
    let image = draw(bundleIdentifier)
    cache[bundleIdentifier] = image
    return image
  }

  private static func draw(_ bundleIdentifier: String) -> UIImage? {
    let side: CGFloat = 120
    let rect = CGRect(x: 0, y: 0, width: side, height: side)
    return UIGraphicsImageRenderer(size: rect.size).image { context in
      let cg = context.cgContext
      UIBezierPath(roundedRect: rect, cornerRadius: side * 0.225).addClip()
      func fill(_ top: UIColor, _ bottom: UIColor) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
          cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: side), options: [])
        }
      }
      func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1) }
      func stroke(_ path: UIBezierPath, _ color: UIColor, width: CGFloat) {
        color.setStroke()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
      }
      switch bundleIdentifier {
      case browser.bundleIdentifier:
        // A globe: a ring and its meridian.
        fill(rgb(86, 170, 255), rgb(30, 100, 220))
        stroke(UIBezierPath(ovalIn: rect.insetBy(dx: 28, dy: 28)), .white, width: 8)
        stroke(UIBezierPath(ovalIn: CGRect(x: 46, y: 28, width: 28, height: 64)), .white, width: 6)
        let equator = UIBezierPath()
        equator.move(to: CGPoint(x: 30, y: 60)); equator.addLine(to: CGPoint(x: 90, y: 60))
        stroke(equator, .white, width: 6)
      case editor.bundleIdentifier:
        // Angle brackets.
        fill(rgb(58, 52, 110), rgb(28, 24, 60))
        let left = UIBezierPath()
        left.move(to: CGPoint(x: 50, y: 38)); left.addLine(to: CGPoint(x: 30, y: 60)); left.addLine(to: CGPoint(x: 50, y: 82))
        let right = UIBezierPath()
        right.move(to: CGPoint(x: 70, y: 38)); right.addLine(to: CGPoint(x: 90, y: 60)); right.addLine(to: CGPoint(x: 70, y: 82))
        stroke(left, rgb(190, 170, 255), width: 9)
        stroke(right, rgb(190, 170, 255), width: 9)
      case design.bundleIdentifier:
        // Three overlapping colors.
        fill(rgb(250, 250, 252), rgb(232, 232, 240))
        for (center, color) in [(CGPoint(x: 48, y: 50), rgb(255, 95, 109)), (CGPoint(x: 72, y: 50), rgb(91, 75, 208)),
                                (CGPoint(x: 60, y: 72), rgb(255, 184, 76))] {
          color.withAlphaComponent(0.85).setFill()
          UIBezierPath(ovalIn: CGRect(x: center.x - 22, y: center.y - 22, width: 44, height: 44)).fill()
        }
      case mail.bundleIdentifier:
        // An envelope.
        fill(rgb(48, 200, 190), rgb(10, 140, 150))
        let body = CGRect(x: 26, y: 38, width: 68, height: 46)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: body, cornerRadius: 6).fill()
        let flap = UIBezierPath()
        flap.move(to: CGPoint(x: 28, y: 42)); flap.addLine(to: CGPoint(x: 60, y: 66)); flap.addLine(to: CGPoint(x: 92, y: 42))
        stroke(flap, rgb(10, 140, 150), width: 5)
      case terminal.bundleIdentifier:
        // A prompt.
        fill(rgb(48, 52, 58), rgb(16, 18, 22))
        let prompt = UIBezierPath()
        prompt.move(to: CGPoint(x: 32, y: 42)); prompt.addLine(to: CGPoint(x: 50, y: 58)); prompt.addLine(to: CGPoint(x: 32, y: 74))
        stroke(prompt, rgb(90, 230, 140), width: 8)
        let cursor = UIBezierPath()
        cursor.move(to: CGPoint(x: 58, y: 78)); cursor.addLine(to: CGPoint(x: 86, y: 78))
        stroke(cursor, rgb(90, 230, 140), width: 8)
      case viewer.bundleIdentifier:
        // A picture frame with a hill and a sun.
        fill(rgb(255, 170, 80), rgb(240, 110, 40))
        let frame = UIBezierPath(roundedRect: CGRect(x: 26, y: 32, width: 68, height: 56), cornerRadius: 8)
        UIColor.white.setFill()
        frame.fill()
        let hill = UIBezierPath()
        hill.move(to: CGPoint(x: 32, y: 82)); hill.addLine(to: CGPoint(x: 52, y: 58)); hill.addLine(to: CGPoint(x: 66, y: 72))
        hill.addLine(to: CGPoint(x: 74, y: 64)); hill.addLine(to: CGPoint(x: 88, y: 82)); hill.close()
        rgb(240, 110, 40).setFill()
        hill.fill()
        rgb(255, 190, 80).setFill()
        UIBezierPath(ovalIn: CGRect(x: 70, y: 40, width: 12, height: 12)).fill()
      case files.bundleIdentifier:
        // A folder.
        fill(rgb(120, 190, 255), rgb(60, 130, 230))
        let tab = UIBezierPath(roundedRect: CGRect(x: 26, y: 34, width: 30, height: 16), cornerRadius: 5)
        rgb(225, 240, 255).setFill()
        tab.fill()
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(x: 26, y: 42, width: 68, height: 46), cornerRadius: 7).fill()
      default:
        break
      }
    }
  }
}
#endif
