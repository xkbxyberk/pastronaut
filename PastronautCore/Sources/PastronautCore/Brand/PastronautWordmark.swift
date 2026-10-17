import SwiftUI

/// The Pastronaut logotype (design 1a): "Pastronaut" in Unbounded Bold, its "o" replaced by the app icon's helmet in
/// its orbit. Drawn from vector paths, so the apps don't ship the font and it stays sharp at any size.
///
/// The letter outlines come from `scripts/brand/wordmark.swift` (Unbounded, SIL Open Font License 1.1; see
/// `docs/brand/`). Coordinates: 1 em = 100, y downwards, baseline at 0. The helmet reuses the icon's artwork
/// (`Maccy/AppIcon.icon`), a 100-unit box centred on 50,44.
public struct PastronautWordmark: View {
  /// Size of the letters' em square in points; the logotype is about 7.2 times as wide.
  public var size: CGFloat
  @Environment(\.colorScheme) private var colorScheme

  public init(size: CGFloat = 26) {
    self.size = size
  }

  public var body: some View {
    let scale = size / 100
    Canvas { context, _ in
      context.translateBy(x: -Self.bounds.minX * scale, y: -Self.bounds.minY * scale)
      context.scaleBy(x: scale, y: scale)
      Self.draw(in: &context, dark: colorScheme == .dark)
    }
    .frame(width: Self.bounds.width * scale, height: Self.bounds.height * scale)
    .accessibilityElement()
    .accessibilityLabel(Text(verbatim: "Pastronaut"))
    .accessibilityAddTraits(.isHeader)
  }

  // MARK: - Drawing

  /// Letters and orbit, with a little room around the satellite.
  static let bounds = CGRect(x: 4.96, y: -77, width: 718.32, height: 80.64)
  static let helmetCenter = CGPoint(x: 388.42, y: -30)
  /// Em units per icon unit: the helmet (radius 27 in the icon) is 0.6 em wide.
  static let helmetScale: CGFloat = 0.6 * 100 / 54

  struct Palette {
    let ink, sky, amber, visor: Color
    let helmetStroke: Color?

    static let light = Palette(
      ink: Color(red: 0.055, green: 0.133, blue: 0.212),
      sky: Color(red: 0.118, green: 0.435, blue: 0.659),
      amber: Color(red: 0.910, green: 0.600, blue: 0.165),
      visor: Color(red: 0.055, green: 0.133, blue: 0.212),
      // A white helmet needs an outline on a light background.
      helmetStroke: Color(red: 0.055, green: 0.133, blue: 0.212)
    )
    static let dark = Palette(
      ink: Color(red: 0.969, green: 0.984, blue: 0.992),
      sky: Color(red: 0.529, green: 0.808, blue: 0.922),
      amber: Color(red: 0.949, green: 0.647, blue: 0.255),
      visor: Color(red: 0.043, green: 0.102, blue: 0.161),
      helmetStroke: nil
    )
  }

  static func draw(in context: inout GraphicsContext, dark: Bool) {
    let palette = dark ? Palette.dark : Palette.light
    let white = Color(red: 0.969, green: 0.984, blue: 0.992)
    let glintColor = Color(red: 0.529, green: 0.808, blue: 0.922)
    context.fill(letters, with: .color(palette.ink))

    var helmet = context
    helmet.translateBy(x: helmetCenter.x - 50 * helmetScale, y: helmetCenter.y - 44 * helmetScale)
    helmet.scaleBy(x: helmetScale, y: helmetScale)
    let orbitLine = StrokeStyle(lineWidth: 6, lineCap: .round)
    helmet.stroke(orbit.back, with: .color(palette.sky.opacity(0.7)), style: orbitLine)
    for x in [17.5, 74.5] {
      helmet.fill(Path(roundedRect: CGRect(x: x, y: 36, width: 8, height: 17), cornerRadius: 4), with: .color(palette.sky))
    }
    let shell = Path(ellipseIn: CGRect(x: 23, y: 17, width: 54, height: 54))
    helmet.fill(shell, with: .color(white))
    if let stroke = palette.helmetStroke {
      helmet.stroke(shell, with: .color(stroke), lineWidth: 4)
    }
    helmet.fill(Path(roundedRect: CGRect(x: 30, y: 30.5, width: 40, height: 28), cornerRadius: 13.5), with: .color(palette.visor))
    var glint = Path()
    glint.move(to: CGPoint(x: 34, y: 40))
    glint.addQuadCurve(to: CGPoint(x: 47, y: 33.5), control: CGPoint(x: 38, y: 34))
    helmet.stroke(glint, with: .color(glintColor), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    helmet.fill(Path(roundedRect: CGRect(x: 43.5, y: 36, width: 13, height: 18), cornerRadius: 2.4), with: .color(palette.amber))
    helmet.fill(Path(roundedRect: CGRect(x: 46.6, y: 34, width: 6.8, height: 4.2), cornerRadius: 1.4), with: .color(white))
    helmet.stroke(orbit.front, with: .color(palette.sky), style: orbitLine)
    helmet.fill(Path(ellipseIn: CGRect(x: 82.1, y: 28.9, width: 13, height: 13)), with: .color(palette.amber))
  }

  /// The icon's tilted orbit (an ellipse 84 by 22 around 50,46, turned 16° anticlockwise), split where it passes
  /// behind the helmet and where it comes back in front.
  static let orbit: (back: Path, front: Path) = {
    let turn = CGAffineTransform(translationX: 50, y: 46).rotated(by: -16 * .pi / 180).translatedBy(x: -50, y: -46)
    let ellipse = Path(ellipseIn: CGRect(x: 8, y: 35, width: 84, height: 22)).applying(turn)
    // The ellipse starts at its right end and runs through its lower half first (y grows downwards).
    return (back: ellipse.trimmedPath(from: 0.5, to: 1), front: ellipse.trimmedPath(from: 0, to: 0.5))
  }()

  static let letters = path(from: letterOutlines)

  /// Absolute M, L, Q, C and Z commands, as `scripts/brand/wordmark.swift` writes them.
  static func path(from commands: String) -> Path {
    var path = Path()
    var command: Character = "M"
    var numbers: [CGFloat] = []
    for token in commands.split(separator: " ") {
      var rest = Substring(token)
      if let first = rest.first, first.isLetter {
        command = first
        rest = rest.dropFirst()
        numbers.removeAll()
        if command == "Z" {
          path.closeSubpath()
          continue
        }
      }
      guard let value = Double(rest) else { continue }
      numbers.append(CGFloat(value))
      let p = numbers
      switch command {
      case "M" where p.count == 2:
        path.move(to: CGPoint(x: p[0], y: p[1]))
      case "L" where p.count == 2:
        path.addLine(to: CGPoint(x: p[0], y: p[1]))
      case "Q" where p.count == 4:
        path.addQuadCurve(to: CGPoint(x: p[2], y: p[3]), control: CGPoint(x: p[0], y: p[1]))
      case "C" where p.count == 6:
        path.addCurve(to: CGPoint(x: p[4], y: p[5]), control1: CGPoint(x: p[0], y: p[1]), control2: CGPoint(x: p[2], y: p[3]))
      default:
        continue
      }
      numbers.removeAll()
    }
    return path
  }

  // Generated by scripts/brand/wordmark.swift: "Pastr" and "naut", Unbounded weight 700, tracking -0.01 em.
  static let letterOutlines =
    "M49.06 -75 Q58.54 -75 65.35 -71.79 Q72.16 -68.58 75.78 -62.75 Q79.40 -56.92 79.40 -49.14 Q79.40 -41.36 75.78 " +
    "-35.53 Q72.16 -29.70 65.35 -26.49 Q58.54 -23.28 49.06 -23.28 L16.56 -23.28 L16.56 -39.90 L47.84 -39.90 Q52.84 " +
    "-39.90 55.64 -42.36 Q58.44 -44.82 58.44 -49.14 Q58.44 -53.52 55.64 -55.95 Q52.84 -58.38 47.84 -58.38 L18.40 " +
    "-58.38 L27.72 -67.98 L27.72 0 L6.96 0 L6.96 -75 Z M137.56 0 L134.94 -20.58 L137.72 -28.54 L134.94 -36.40 " +
    "L137.56 -57.14 L158.76 -57.14 L155.16 -28.60 L158.76 0 Z M142.34 -28.54 Q140.98 -19.46 136.85 -12.67 Q132.72 " +
    "-5.88 126.33 -2.12 Q119.94 1.64 111.86 1.64 Q103.50 1.64 97.13 -2.14 Q90.76 -5.92 87.19 -12.74 Q83.62 -19.56 " +
    "83.62 -28.54 Q83.62 -37.62 87.19 -44.42 Q90.76 -51.22 97.13 -55 Q103.50 -58.78 111.86 -58.78 Q119.94 -58.78 " +
    "126.33 -55.05 Q132.72 -51.32 136.90 -44.55 Q141.08 -37.78 142.34 -28.54 Z M104.26 -28.54 Q104.26 -24.28 106.01 " +
    "-21.01 Q107.76 -17.74 110.87 -15.86 Q113.98 -13.98 118.02 -13.98 Q122.16 -13.98 125.86 -15.86 Q129.56 -17.74 " +
    "132.39 -21.01 Q135.22 -24.28 136.60 -28.54 Q135.22 -32.80 132.39 -36.10 Q129.56 -39.40 125.86 -41.28 Q122.16 " +
    "-43.16 118.02 -43.16 Q113.98 -43.16 110.87 -41.28 Q107.76 -39.40 106.01 -36.10 Q104.26 -32.80 104.26 -28.54 Z " +
    "M233.78 -18.64 Q233.78 -12.04 229.80 -7.51 Q225.82 -2.98 218.39 -0.67 Q210.96 1.64 200.56 1.64 Q189.86 1.64 " +
    "181.83 -0.97 Q173.80 -3.58 169.27 -8.29 Q164.74 -13 164.44 -19.22 L185.20 -19.22 Q185.86 -16.92 187.94 -15.25 " +
    "Q190.02 -13.58 193.41 -12.73 Q196.80 -11.88 201.44 -11.88 Q207.56 -11.88 210.70 -13.08 Q213.84 -14.28 213.84 " +
    "-16.66 Q213.84 -18.64 211.48 -19.59 Q209.12 -20.54 203.26 -21 L193.18 -21.76 Q183.04 -22.50 177.09 -24.83 " +
    "Q171.14 -27.16 168.58 -30.92 Q166.02 -34.68 166.02 -39.52 Q166.02 -45.98 170.07 -50.24 Q174.12 -54.50 181.36 " +
    "-56.64 Q188.60 -58.78 198.24 -58.78 Q207.88 -58.78 215.38 -56.27 Q222.88 -53.76 227.40 -49.32 Q231.92 -44.88 " +
    "232.60 -38.94 L211.84 -38.94 Q211.38 -40.82 209.70 -42.37 Q208.02 -43.92 205 -44.89 Q201.98 -45.86 197.30 " +
    "-45.86 Q191.74 -45.86 188.90 -44.69 Q186.06 -43.52 186.06 -41.34 Q186.06 -39.56 187.80 -38.58 Q189.54 -37.60 " +
    "194.42 -37.24 L207.70 -36.24 Q217.62 -35.56 223.31 -33.31 Q229 -31.06 231.39 -27.38 Q233.78 -23.70 233.78 " +
    "-18.64 Z M236.34 -42.04 L236.34 -50.94 L247.96 -55.60 L256.78 -72.48 L268.40 -72.48 L268.40 -57.14 L292.42 " +
    "-57.14 L292.42 -42.04 L268.40 -42.04 L268.40 -25.16 Q268.40 -19.02 270.88 -16.53 Q273.36 -14.04 280.02 -14.04 " +
    "Q284.18 -14.04 287.43 -14.75 Q290.68 -15.46 293.42 -16.66 L293.42 -1.34 Q290.34 -0.22 285.47 0.71 Q280.60 1.64 " +
    "275.36 1.64 Q265.92 1.64 259.86 -1.29 Q253.80 -4.22 250.88 -9.64 Q247.96 -15.06 247.96 -22.38 L247.96 -42.04 Z " +
    "M298.02 -57.14 L318.82 -57.14 L322.22 -36.72 L322.22 0 L301.78 0 L301.78 -37.90 Z M348.94 -58.02 L348.94 " +
    "-40.56 Q346.02 -41.16 343.36 -41.43 Q340.70 -41.70 338.52 -41.70 Q334.04 -41.70 330.34 -39.93 Q326.64 -38.16 " +
    "324.43 -34.16 Q322.22 -30.16 322.22 -23.50 L318.32 -28.34 Q319.08 -34.46 320.67 -39.95 Q322.26 -45.44 325 " +
    "-49.67 Q327.74 -53.90 331.86 -56.34 Q335.98 -58.78 341.86 -58.78 Q343.56 -58.78 345.36 -58.59 Q347.16 -58.40 " +
    "348.94 -58.02 Z M430.36 -57.14 L450.80 -57.14 L454.56 -34.28 L454.56 0 L434.12 0 L434.12 -37.38 Z M475.50 " +
    "-58.78 Q483.74 -58.78 489.52 -55.49 Q495.30 -52.20 498.37 -46.19 Q501.44 -40.18 501.44 -31.96 L501.44 0 L481 0 " +
    "L481 -28.96 Q481 -35.40 477.75 -38.78 Q474.50 -42.16 468.42 -42.16 Q464.18 -42.16 461.05 -40.37 Q457.92 -38.58 " +
    "456.24 -35.29 Q454.56 -32 454.56 -27.48 L448.22 -30.76 Q449.42 -39.92 453.30 -46.15 Q457.18 -52.38 462.92 " +
    "-55.58 Q468.66 -58.78 475.50 -58.78 Z M562.52 0 L559.90 -20.58 L562.68 -28.54 L559.90 -36.40 L562.52 -57.14 " +
    "L583.72 -57.14 L580.12 -28.60 L583.72 0 Z M567.30 -28.54 Q565.94 -19.46 561.81 -12.67 Q557.68 -5.88 551.29 " +
    "-2.12 Q544.90 1.64 536.82 1.64 Q528.46 1.64 522.09 -2.14 Q515.72 -5.92 512.15 -12.74 Q508.58 -19.56 508.58 " +
    "-28.54 Q508.58 -37.62 512.15 -44.42 Q515.72 -51.22 522.09 -55 Q528.46 -58.78 536.82 -58.78 Q544.90 -58.78 " +
    "551.29 -55.05 Q557.68 -51.32 561.86 -44.55 Q566.04 -37.78 567.30 -28.54 Z M529.22 -28.54 Q529.22 -24.28 530.97 " +
    "-21.01 Q532.72 -17.74 535.83 -15.86 Q538.94 -13.98 542.98 -13.98 Q547.12 -13.98 550.82 -15.86 Q554.52 -17.74 " +
    "557.35 -21.01 Q560.18 -24.28 561.56 -28.54 Q560.18 -32.80 557.35 -36.10 Q554.52 -39.40 550.82 -41.28 Q547.12 " +
    "-43.16 542.98 -43.16 Q538.94 -43.16 535.83 -41.28 Q532.72 -39.40 530.97 -36.10 Q529.22 -32.80 529.22 -28.54 Z " +
    "M617.12 1.58 Q609.14 1.58 603.48 -1.71 Q597.82 -5 594.83 -11.03 Q591.84 -17.06 591.84 -25.18 L591.84 -57.14 " +
    "L612.28 -57.14 L612.28 -28.14 Q612.28 -21.80 615.37 -18.42 Q618.46 -15.04 624.20 -15.04 Q628.50 -15.04 631.43 " +
    "-16.75 Q634.36 -18.46 635.93 -21.77 Q637.50 -25.08 637.50 -29.66 L643.80 -26.38 Q642.70 -17.32 638.89 -11.07 " +
    "Q635.08 -4.82 629.47 -1.62 Q623.86 1.58 617.12 1.58 Z M641.22 0 L637.50 -22.86 L637.50 -57.14 L657.94 -57.14 " +
    "L657.94 -19.72 L661.66 0 Z M664.20 -42.04 L664.20 -50.94 L675.82 -55.60 L684.64 -72.48 L696.26 -72.48 L696.26 " +
    "-57.14 L720.28 -57.14 L720.28 -42.04 L696.26 -42.04 L696.26 -25.16 Q696.26 -19.02 698.74 -16.53 Q701.22 -14.04 " +
    "707.88 -14.04 Q712.04 -14.04 715.29 -14.75 Q718.54 -15.46 721.28 -16.66 L721.28 -1.34 Q718.20 -0.22 713.33 " +
    "0.71 Q708.46 1.64 703.22 1.64 Q693.78 1.64 687.72 -1.29 Q681.66 -4.22 678.74 -9.64 Q675.82 -15.06 675.82 " +
    "-22.38 L675.82 -42.04 Z"
}

#Preview {
  VStack(spacing: 24) {
    PastronautWordmark(size: 40)
    PastronautWordmark(size: 20)
  }
  .padding()
}
