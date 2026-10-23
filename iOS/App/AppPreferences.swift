import PastronautCore
import SwiftUI
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable {
  case english = "en"
  case turkish = "tr"

  var id: String { rawValue }

  var nativeName: String {
    switch self {
    case .english: "English"
    case .turkish: "Türkçe"
    }
  }

  static func matching(_ identifier: String?) -> AppLanguage {
    guard let identifier, identifier.lowercased().hasPrefix(AppLanguage.turkish.rawValue) else { return .english }
    return .turkish
  }
}

enum AppAppearance: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var interfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .system: .unspecified
    case .light: .light
    case .dark: .dark
    }
  }

  @MainActor
  func applyToWindows() {
    for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
      for window in scene.windows {
        window.overrideUserInterfaceStyle = interfaceStyle
      }
    }
  }
}

@MainActor
@Observable
final class AppPreferences {
  static let shared = AppPreferences()
  static let appearanceKey = "appearance"
  static let onboardingKey = "hasCompletedOnboarding"
  /// Settings › Images & Files › Image Quality: this iPhone's own (`MediaQuality`).
  static let mediaQualityKey = "mediaQuality"
  /// Settings › History › Keep History (`HistoryAge`); forever by default.
  static let historyAgeKey = "historyAge"
  private static let systemLanguagesKey = "AppleLanguages"

  var language: AppLanguage {
    didSet {
      guard language != oldValue else { return }
      UserDefaults.standard.set([language.rawValue], forKey: Self.systemLanguagesKey)
    }
  }

  var locale: Locale {
    Locale(languageCode: Locale.LanguageCode(language.rawValue), languageRegion: Locale.current.region)
  }

  private init() {
    language = AppLanguage.matching(Bundle.main.preferredLocalizations.first)
  }

  func string(_ key: String.LocalizationValue) -> String {
    var resource = LocalizedStringResource(key)
    resource.locale = locale
    return String(localized: resource)
  }

  nonisolated static func registerFirstLaunchDefaults() {
    let standard = UserDefaults.standard
    if standard.object(forKey: PreviewChoice.key) == nil {
      standard.set(PreviewChoice.on.rawValue, forKey: PreviewChoice.key)
    }
    let shared = UserDefaults(suiteName: PastronautIDs.appGroup)
    if shared?.object(forKey: AutoCapture.settingKey) == nil {
      shared?.set(true, forKey: AutoCapture.settingKey)
    }
  }
}

struct AppPreferencesScope: ViewModifier {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(AppPreferences.appearanceKey) private var appearance = AppAppearance.system
  private let preferences = AppPreferences.shared

  func body(content: Content) -> some View {
    content
      .environment(\.locale, preferences.locale)
      .onAppear { appearance.applyToWindows() }
      .onChange(of: appearance) { appearance.applyToWindows() }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { appearance.applyToWindows() }
      }
  }
}

struct SettingsIcon: View {
  let systemImage: String
  let color: Color

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 29, height: 29)
      .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
      .accessibilityHidden(true)
  }
}
