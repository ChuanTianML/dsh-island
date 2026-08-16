import Foundation

/// A resolved sRGB color expressed without importing any UI framework, so the token layer stays testable.
public struct IslandColor: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double
  public let opacity: Double

  /// - Parameters:
  ///   - red: Red channel in `0...1`.
  ///   - green: Green channel in `0...1`.
  ///   - blue: Blue channel in `0...1`.
  ///   - opacity: Alpha channel in `0...1`.
  public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
    self.red = red
    self.green = green
    self.blue = blue
    self.opacity = opacity
  }

  /// - Parameters:
  ///   - hex: Packed `0xRRGGBB` value; any higher bits are ignored.
  ///   - opacity: Alpha channel in `0...1`.
  public init(hex: UInt32, opacity: Double = 1) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: opacity)
  }

  /// - Parameter opacity: Replacement alpha channel in `0...1`.
  /// - Returns: The same chromaticity at the given alpha.
  public func withOpacity(_ opacity: Double) -> IslandColor {
    IslandColor(red: red, green: green, blue: blue, opacity: opacity)
  }

  public static let clear = IslandColor(red: 0, green: 0, blue: 0, opacity: 0)
}

/// A type family choice. The App target maps each case to a concrete font with its own fallbacks.
public enum IslandFontFace: Equatable, Sendable {
  case system
  case monospaced
  case serifDisplay
  case editorialSerif
  case condensed
  case humanist
}

/// The weight axis exposed to themes.
public enum IslandFontWeight: Equatable, Sendable {
  case regular
  case medium
  case semibold
  case bold
}

/// How the expanded header visualizes the aggregate of all sessions.
public enum IslandSummaryVisual: Equatable, Sendable {
  case signalRail
  case constellation
  case orbit
  case count
  case veins
}

/// How one session row separates itself from its neighbours.
public enum IslandRowStyle: Equatable, Sendable {
  case card
  case divider
  case grid
  case ledger
  case vein
}

/// How a row renders its status mark.
public enum IslandGlyphStyle: Equatable, Sendable {
  case symbol
  case ring
  case geometric
  case index
  case organic
}

/// Every size a theme controls. Values are points in the panel's own coordinate space.
public struct IslandThemeMetrics: Equatable, Sendable {
  public let collapsedWidth: Double
  public let collapsedHeight: Double
  public let expandedWidth: Double
  public let collapsedCornerRadius: Double
  public let expandedCornerRadius: Double
  public let rowHeight: Double
  public let rowSpacing: Double
  public let rowCornerRadius: Double
  public let headerPadding: Double
  public let listPadding: Double
  public let listVerticalPadding: Double
  public let toolbarHeight: Double
  public let summaryHeight: Double
  public let brandTileSize: Double
  public let brandCornerRadius: Double
  public let chromeHeight: Double
  public let maxVisibleRows: Int
  public let minExpandedHeight: Double
  public let maxExpandedHeight: Double

  /// - Parameter visibleRowCount: Session rows the panel wants to show, before clamping.
  /// - Returns: The expanded panel height, clamped to the theme's own bounds so the panel always fits on screen.
  public func expandedHeight(visibleRowCount: Int) -> Double {
    let rows = min(max(visibleRowCount, 0), maxVisibleRows)
    let content = chromeHeight + Double(rows) * (rowHeight + rowSpacing)
    return min(max(content, minExpandedHeight), maxExpandedHeight)
  }
}

/// Every color a theme controls, including one explicit color per status class.
public struct IslandThemePalette: Equatable, Sendable {
  public let surfaceTop: IslandColor
  public let surfaceBottom: IslandColor
  public let border: IslandColor
  public let borderHighContrast: IslandColor
  public let separator: IslandColor
  public let primaryText: IslandColor
  public let secondaryText: IslandColor
  public let tertiaryText: IslandColor
  public let rowBackground: IslandColor
  public let rowBorder: IslandColor
  public let accentRowOpacity: Double
  public let brandFill: IslandColor
  /// `nil` means the brand tile takes its outline from the aggregate status color instead of a fixed stroke.
  public let brandStroke: IslandColor?
  public let whaleFill: IslandColor
  public let controlFill: IslandColor
  public let attention: IslandColor
  public let failure: IslandColor
  public let running: IslandColor
  public let completed: IslandColor
  public let idle: IslandColor
  public let offline: IslandColor

  /// - Parameter status: The status class to render.
  /// - Returns: The theme's color for that class. Total by construction, so a new status forces a decision here.
  public func color(for status: IslandStatus) -> IslandColor {
    switch status {
    case .attention: return attention
    case .failure: return failure
    case .running: return running
    case .completed: return completed
    case .idle: return idle
    case .offline: return offline
    }
  }
}

/// Every type choice a theme controls.
public struct IslandThemeTypography: Equatable, Sendable {
  public let titleFace: IslandFontFace
  public let titleSize: Double
  public let titleWeight: IslandFontWeight
  public let subtitleFace: IslandFontFace
  public let subtitleSize: Double
  public let subtitleUppercase: Bool
  public let subtitleTracking: Double
  public let rowTitleFace: IslandFontFace
  public let rowTitleSize: Double
  public let rowTitleWeight: IslandFontWeight
  public let rowDetailFace: IslandFontFace
  public let rowDetailSize: Double
  public let rowDetailUppercase: Bool
  public let rowStatusSize: Double
  public let rowTimeSize: Double
}

/// Structural presentation choices that are neither color nor type.
public struct IslandThemeChrome: Equatable, Sendable {
  public let summaryVisual: IslandSummaryVisual
  public let rowStyle: IslandRowStyle
  public let glyphStyle: IslandGlyphStyle
  public let showsToolbarNote: Bool
  public let showsHeaderSeparator: Bool
  public let usesBackgroundBlur: Bool
  /// Editorial is the only light theme; the App target resolves the color scheme from this.
  public let prefersLightSurface: Bool
}

/// The five shipped presentations.
///
/// A theme changes presentation only. Business status, available actions, ordering, and accessibility
/// information are identical across all cases, so the interaction contract does not vary by theme.
public enum IslandTheme: String, Codable, CaseIterable, Equatable, Sendable {
  case original
  case quiet
  case orbital
  case editorial
  case pulse

  /// The theme used whenever a stored preference is missing or unrecognized.
  public static let fallback: IslandTheme = .original

  /// - Parameter rawValue: A persisted identifier, possibly absent or written by a newer build.
  /// - Returns: The matching theme, or ``fallback`` when the value is absent or unknown.
  public static func resolve(_ rawValue: String?) -> IslandTheme {
    guard let rawValue, let theme = IslandTheme(rawValue: rawValue) else { return fallback }
    return theme
  }

  /// The name shown in Settings.
  public var displayName: String {
    switch self {
    case .original: return "Original Signal"
    case .quiet: return "Quiet Glass"
    case .orbital: return "Orbital Deck"
    case .editorial: return "Editorial"
    case .pulse: return "Pulse Garden"
    }
  }

  /// A one-line character summary shown under ``displayName``.
  public var tagline: String {
    switch self {
    case .original: return "Shipped · clear · compact"
    case .quiet: return "Native · calm · low-density"
    case .orbital: return "Technical · focused · dense"
    case .editorial: return "Typographic · ordered · distinct"
    case .pulse: return "Ambient · legible · gentle"
    }
  }

  public var metrics: IslandThemeMetrics {
    switch self {
    case .original:
      return IslandThemeMetrics(
        collapsedWidth: 400, collapsedHeight: 68, expandedWidth: 500,
        collapsedCornerRadius: 34, expandedCornerRadius: 28,
        rowHeight: 69, rowSpacing: 7, rowCornerRadius: 15,
        headerPadding: 17, listPadding: 12, listVerticalPadding: 12,
        toolbarHeight: 48, summaryHeight: 4,
        brandTileSize: 42, brandCornerRadius: 11,
        chromeHeight: 150, maxVisibleRows: 5,
        minExpandedHeight: 280, maxExpandedHeight: 570)
    case .quiet:
      return IslandThemeMetrics(
        collapsedWidth: 372, collapsedHeight: 60, expandedWidth: 440,
        collapsedCornerRadius: 30, expandedCornerRadius: 26,
        rowHeight: 58, rowSpacing: 0, rowCornerRadius: 14,
        headerPadding: 15, listPadding: 14, listVerticalPadding: 10,
        toolbarHeight: 48, summaryHeight: 6,
        brandTileSize: 30, brandCornerRadius: 15,
        chromeHeight: 152, maxVisibleRows: 5,
        minExpandedHeight: 280, maxExpandedHeight: 570)
    case .orbital:
      return IslandThemeMetrics(
        collapsedWidth: 400, collapsedHeight: 68, expandedWidth: 500,
        collapsedCornerRadius: 24, expandedCornerRadius: 22,
        rowHeight: 58, rowSpacing: 0, rowCornerRadius: 0,
        headerPadding: 15, listPadding: 17, listVerticalPadding: 10,
        toolbarHeight: 48, summaryHeight: 20,
        brandTileSize: 36, brandCornerRadius: 8,
        chromeHeight: 166, maxVisibleRows: 5,
        minExpandedHeight: 280, maxExpandedHeight: 570)
    case .editorial:
      return IslandThemeMetrics(
        collapsedWidth: 416, collapsedHeight: 76, expandedWidth: 500,
        collapsedCornerRadius: 20, expandedCornerRadius: 20,
        rowHeight: 62, rowSpacing: 0, rowCornerRadius: 0,
        headerPadding: 15, listPadding: 16, listVerticalPadding: 10,
        toolbarHeight: 48, summaryHeight: 34,
        brandTileSize: 42, brandCornerRadius: 0,
        chromeHeight: 188, maxVisibleRows: 5,
        minExpandedHeight: 280, maxExpandedHeight: 570)
    case .pulse:
      return IslandThemeMetrics(
        collapsedWidth: 400, collapsedHeight: 80, expandedWidth: 500,
        collapsedCornerRadius: 40, expandedCornerRadius: 34,
        rowHeight: 64, rowSpacing: 0, rowCornerRadius: 18,
        headerPadding: 20, listPadding: 25, listVerticalPadding: 8,
        toolbarHeight: 48, summaryHeight: 22,
        brandTileSize: 42, brandCornerRadius: 21,
        chromeHeight: 178, maxVisibleRows: 5,
        minExpandedHeight: 280, maxExpandedHeight: 570)
    }
  }

  public var palette: IslandThemePalette {
    switch self {
    case .original:
      return IslandThemePalette(
        surfaceTop: IslandColor(hex: 0x0E12_19, opacity: 0.96),
        surfaceBottom: IslandColor(hex: 0x0506_0A, opacity: 0.985),
        border: IslandColor(hex: 0xFFFF_FF, opacity: 0.13),
        borderHighContrast: IslandColor(hex: 0xFFFF_FF, opacity: 0.34),
        separator: IslandColor(hex: 0xFFFF_FF, opacity: 0.07),
        primaryText: IslandColor(hex: 0xFFFF_FF),
        secondaryText: IslandColor(hex: 0xFFFF_FF, opacity: 0.56),
        tertiaryText: IslandColor(hex: 0xFFFF_FF, opacity: 0.38),
        rowBackground: IslandColor(hex: 0xFFFF_FF, opacity: 0.035),
        rowBorder: IslandColor(hex: 0xFFFF_FF, opacity: 0.07),
        accentRowOpacity: 0.07,
        brandFill: IslandColor(hex: 0xF4F2_EC, opacity: 0.96),
        brandStroke: nil,
        whaleFill: IslandColor(hex: 0x0505_05),
        controlFill: IslandColor(hex: 0xFFFF_FF, opacity: 0.045),
        attention: IslandColor(hex: 0xFFB8_4D),
        failure: IslandColor(hex: 0xFF66_5E),
        running: IslandColor(hex: 0x55D7_FF),
        completed: IslandColor(hex: 0x63E6_B1),
        idle: IslandColor(hex: 0x8993_A4),
        offline: IslandColor(hex: 0x7D85_99))
    case .quiet:
      return IslandThemePalette(
        surfaceTop: IslandColor(hex: 0x1F21_26, opacity: 0.96),
        surfaceBottom: IslandColor(hex: 0x0F10_13, opacity: 0.985),
        border: IslandColor(hex: 0xFFFF_FF, opacity: 0.14),
        borderHighContrast: IslandColor(hex: 0xFFFF_FF, opacity: 0.36),
        separator: IslandColor(hex: 0xFFFF_FF, opacity: 0.07),
        primaryText: IslandColor(hex: 0xEEF2_F8),
        secondaryText: IslandColor(hex: 0xEEF2_F8, opacity: 0.5),
        tertiaryText: IslandColor(hex: 0xEEF2_F8, opacity: 0.38),
        rowBackground: .clear,
        rowBorder: .clear,
        accentRowOpacity: 0.08,
        brandFill: IslandColor(hex: 0xEEF2_F8, opacity: 0.92),
        brandStroke: nil,
        whaleFill: IslandColor(hex: 0x0505_05),
        controlFill: IslandColor(hex: 0xFFFF_FF, opacity: 0.035),
        attention: IslandColor(hex: 0xFF9F_0A),
        failure: IslandColor(hex: 0xFF45_3A),
        running: IslandColor(hex: 0x0A84_FF),
        completed: IslandColor(hex: 0x30D1_58),
        idle: IslandColor(hex: 0x8993_A4),
        offline: IslandColor(hex: 0x8993_A4))
    case .orbital:
      return IslandThemePalette(
        surfaceTop: IslandColor(hex: 0x0D12_15),
        surfaceBottom: IslandColor(hex: 0x080C_0F),
        border: IslandColor(hex: 0x2934_3B),
        borderHighContrast: IslandColor(hex: 0x6E82_8D),
        separator: IslandColor(hex: 0x2632_3A),
        primaryText: IslandColor(hex: 0xDCE7_E8),
        secondaryText: IslandColor(hex: 0x7D8D_96),
        tertiaryText: IslandColor(hex: 0x7381_8A),
        rowBackground: .clear,
        rowBorder: .clear,
        accentRowOpacity: 0.09,
        brandFill: IslandColor(hex: 0xDCE7_E8),
        brandStroke: IslandColor(hex: 0x3444_4E),
        whaleFill: IslandColor(hex: 0x0505_05),
        controlFill: IslandColor(hex: 0xFFFF_FF, opacity: 0.04),
        attention: IslandColor(hex: 0xFFB8_4D),
        failure: IslandColor(hex: 0xFF66_5E),
        running: IslandColor(hex: 0x59D8_FF),
        completed: IslandColor(hex: 0x63E6_B1),
        idle: IslandColor(hex: 0x7D8D_96),
        offline: IslandColor(hex: 0x7D8D_96))
    case .editorial:
      return IslandThemePalette(
        surfaceTop: IslandColor(hex: 0xF2EF_E8),
        surfaceBottom: IslandColor(hex: 0xEDE9_E0),
        border: IslandColor(hex: 0x2E2D_2A),
        borderHighContrast: IslandColor(hex: 0x1212_11),
        separator: IslandColor(hex: 0x0B0B_0C, opacity: 0.22),
        primaryText: IslandColor(hex: 0x0B0B_0C),
        secondaryText: IslandColor(hex: 0x716D_66),
        tertiaryText: IslandColor(hex: 0x7771_6A),
        rowBackground: .clear,
        rowBorder: .clear,
        accentRowOpacity: 0.1,
        brandFill: .clear,
        brandStroke: IslandColor(hex: 0x2424_24),
        whaleFill: IslandColor(hex: 0x0505_05),
        controlFill: IslandColor(hex: 0x0B0B_0C, opacity: 0.05),
        attention: IslandColor(hex: 0xB249_34),
        failure: IslandColor(hex: 0xC440_49),
        running: IslandColor(hex: 0x286C_A8),
        completed: IslandColor(hex: 0x3977_50),
        idle: IslandColor(hex: 0x7771_6A),
        offline: IslandColor(hex: 0x7771_6A))
    case .pulse:
      return IslandThemePalette(
        surfaceTop: IslandColor(hex: 0x0B21_1F),
        surfaceBottom: IslandColor(hex: 0x0714_12),
        border: IslandColor(hex: 0x80F0_D3, opacity: 0.18),
        borderHighContrast: IslandColor(hex: 0x80F0_D3, opacity: 0.44),
        separator: IslandColor(hex: 0xB7E7_DE, opacity: 0.11),
        primaryText: IslandColor(hex: 0xE9FF_F7),
        secondaryText: IslandColor(hex: 0xE9FF_F7, opacity: 0.46),
        tertiaryText: IslandColor(hex: 0xE9FF_F7, opacity: 0.42),
        rowBackground: .clear,
        rowBorder: .clear,
        accentRowOpacity: 0.09,
        brandFill: IslandColor(hex: 0xC8F7_DF),
        brandStroke: nil,
        whaleFill: IslandColor(hex: 0x0505_05),
        controlFill: IslandColor(hex: 0xE9FF_F7, opacity: 0.055),
        attention: IslandColor(hex: 0xFFC4_6B),
        failure: IslandColor(hex: 0xFF7F_76),
        running: IslandColor(hex: 0x55D8_FF),
        completed: IslandColor(hex: 0x64E2_AE),
        idle: IslandColor(hex: 0x8FB3_AC),
        offline: IslandColor(hex: 0x8FB3_AC))
    }
  }

  public var typography: IslandThemeTypography {
    switch self {
    case .original:
      return IslandThemeTypography(
        titleFace: .serifDisplay, titleSize: 15, titleWeight: .semibold,
        subtitleFace: .monospaced, subtitleSize: 10.5, subtitleUppercase: true,
        subtitleTracking: 0.7,
        rowTitleFace: .system, rowTitleSize: 13.5, rowTitleWeight: .semibold,
        rowDetailFace: .system, rowDetailSize: 11.5, rowDetailUppercase: false,
        rowStatusSize: 9.5, rowTimeSize: 10)
    case .quiet:
      return IslandThemeTypography(
        titleFace: .system, titleSize: 15, titleWeight: .semibold,
        subtitleFace: .system, subtitleSize: 11, subtitleUppercase: false, subtitleTracking: 0,
        rowTitleFace: .system, rowTitleSize: 13, rowTitleWeight: .medium,
        rowDetailFace: .system, rowDetailSize: 11, rowDetailUppercase: false,
        rowStatusSize: 9, rowTimeSize: 10)
    case .orbital:
      return IslandThemeTypography(
        titleFace: .condensed, titleSize: 17, titleWeight: .semibold,
        subtitleFace: .monospaced, subtitleSize: 10, subtitleUppercase: true,
        subtitleTracking: 0.4,
        rowTitleFace: .condensed, rowTitleSize: 14, rowTitleWeight: .semibold,
        rowDetailFace: .monospaced, rowDetailSize: 10, rowDetailUppercase: true,
        rowStatusSize: 9, rowTimeSize: 10)
    case .editorial:
      return IslandThemeTypography(
        titleFace: .editorialSerif, titleSize: 16, titleWeight: .semibold,
        subtitleFace: .monospaced, subtitleSize: 9, subtitleUppercase: true, subtitleTracking: 0.5,
        rowTitleFace: .editorialSerif, rowTitleSize: 14, rowTitleWeight: .semibold,
        rowDetailFace: .monospaced, rowDetailSize: 9, rowDetailUppercase: false,
        rowStatusSize: 9, rowTimeSize: 9)
    case .pulse:
      return IslandThemeTypography(
        titleFace: .humanist, titleSize: 15, titleWeight: .semibold,
        subtitleFace: .humanist, subtitleSize: 11, subtitleUppercase: false, subtitleTracking: 0,
        rowTitleFace: .humanist, rowTitleSize: 13, rowTitleWeight: .semibold,
        rowDetailFace: .humanist, rowDetailSize: 10, rowDetailUppercase: false,
        rowStatusSize: 9, rowTimeSize: 9)
    }
  }

  public var chrome: IslandThemeChrome {
    switch self {
    case .original:
      return IslandThemeChrome(
        summaryVisual: .signalRail, rowStyle: .card, glyphStyle: .symbol,
        showsToolbarNote: true, showsHeaderSeparator: false,
        usesBackgroundBlur: true, prefersLightSurface: false)
    case .quiet:
      return IslandThemeChrome(
        summaryVisual: .constellation, rowStyle: .divider, glyphStyle: .ring,
        showsToolbarNote: false, showsHeaderSeparator: false,
        usesBackgroundBlur: true, prefersLightSurface: false)
    case .orbital:
      return IslandThemeChrome(
        summaryVisual: .orbit, rowStyle: .grid, glyphStyle: .geometric,
        showsToolbarNote: true, showsHeaderSeparator: true,
        usesBackgroundBlur: false, prefersLightSurface: false)
    case .editorial:
      return IslandThemeChrome(
        summaryVisual: .count, rowStyle: .ledger, glyphStyle: .index,
        showsToolbarNote: true, showsHeaderSeparator: true,
        usesBackgroundBlur: false, prefersLightSurface: true)
    case .pulse:
      return IslandThemeChrome(
        summaryVisual: .veins, rowStyle: .vein, glyphStyle: .organic,
        showsToolbarNote: false, showsHeaderSeparator: false,
        usesBackgroundBlur: true, prefersLightSurface: false)
    }
  }
}
