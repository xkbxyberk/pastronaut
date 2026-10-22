// Draws the "Save to Pastronaut" action icon: a one-color, simplified app icon (helmet, visor, clipboard). iOS shows an action extension's icon as a template, so only the alpha counts; holes are transparent.
// Usage: swift scripts/icons/action-glyph.swift <output.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let scale = CGFloat(size) / 100
let context = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
// The app icon's art is drawn on a 100 × 100 grid with y going down.
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: scale, y: -scale)
context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
  CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

func fill(_ path: CGPath) {
  context.addPath(path)
  context.fillPath()
}

func clear(_ path: CGPath) {
  context.setBlendMode(.clear)
  fill(path)
  context.setBlendMode(.normal)
}

// Helmet with ears.
fill(CGPath(ellipseIn: CGRect(x: 15, y: 13, width: 70, height: 70), transform: nil))
fill(roundedRect(6, 34, 12, 28, 6))
fill(roundedRect(82, 34, 12, 28, 6))

// The visor is a window; the clipboard sits in it, with its lines cut out.
clear(roundedRect(24, 28, 52, 40, 18))
fill(roundedRect(37, 34, 26, 30, 4))
clear(roundedRect(42.5, 31, 15, 8.5, 3))
fill(roundedRect(44.5, 29.5, 11, 7.5, 2.5))
clear(roundedRect(42, 44, 16, 3.6, 1.8))
clear(roundedRect(42, 50.5, 12, 3.6, 1.8))
clear(roundedRect(42, 57, 14, 3.6, 1.8))

let image = context.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination))
