import AppKit
import Defaults

enum MenuIcon: String, CaseIterable, Identifiable, Defaults.Serializable {
  // Pastronaut: the raw value "maccy" is kept for saved settings; it is the helmet with a clipboard now.
  case maccy
  case helmet
  case helmetSolid
  case orbit
  case clipboard
  case documents
  case paperclip
  case scissors

  var id: Self { self }

  var image: NSImage {
    switch self {
    case .maccy:
      return NSImage(named: .maccyStatusBar)!
    case .helmet:
      return NSImage(named: .statusBarHelmet)!
    case .helmetSolid:
      return NSImage(named: .statusBarHelmetSolid)!
    case .orbit:
      return NSImage(named: .statusBarOrbit)!
    case .clipboard:
      return NSImage(named: .clipboard)!
    case .documents:
      return NSImage(named: .statusBarDocuments)!
    case .paperclip:
      return NSImage(named: .paperclip)!
    case .scissors:
      return NSImage(named: .scissors)!
    }
  }

  // Pastronaut: names for the settings picker and VoiceOver.
  var title: String {
    switch self {
    case .maccy: String(localized: "Helmet (Pastronaut)", table: "Pastronaut")
    case .helmet: String(localized: "Helmet, outline", table: "Pastronaut")
    case .helmetSolid: String(localized: "Helmet, solid", table: "Pastronaut")
    case .orbit: String(localized: "Clipboard in orbit", table: "Pastronaut")
    case .clipboard: String(localized: "Clipboard", table: "Pastronaut")
    case .documents: String(localized: "Two documents", table: "Pastronaut")
    case .paperclip: String(localized: "Paperclip", table: "Pastronaut")
    case .scissors: String(localized: "Scissors", table: "Pastronaut")
    }
  }
}
