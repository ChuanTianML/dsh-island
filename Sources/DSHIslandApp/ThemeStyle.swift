import AppKit
import DSHIslandCore
import SwiftUI

extension IslandColor {
  /// The SwiftUI color represented by this framework-independent theme token.
  var swiftUIColor: Color {
    Color(
      .sRGB,
      red: red,
      green: green,
      blue: blue,
      opacity: opacity)
  }
}

extension IslandFontWeight {
  fileprivate var swiftUIWeight: Font.Weight {
    switch self {
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    }
  }
}

extension IslandFontFace {
  /// Resolves the theme face through an ordered list of installed macOS families.
  ///
  /// - Parameters:
  ///   - size: Point size requested by the theme.
  ///   - weight: Weight requested by the theme.
  /// - Returns: A SwiftUI font using the first installed family or a semantic system fallback.
  func swiftUIFont(size: Double, weight: IslandFontWeight) -> Font {
    let pointSize = CGFloat(size)
    let resolvedWeight = weight.swiftUIWeight
    switch self {
    case .system:
      return .system(size: pointSize, weight: resolvedWeight)
    case .monospaced:
      return .system(size: pointSize, weight: resolvedWeight, design: .monospaced)
    case .serifDisplay:
      return resolvedFont(
        candidates: ["New York", "NewYork-Regular", "Georgia"],
        size: pointSize,
        weight: resolvedWeight,
        fallbackDesign: .serif)
    case .editorialSerif:
      return resolvedFont(
        candidates: ["Charter", "Georgia", "Times New Roman"],
        size: pointSize,
        weight: resolvedWeight,
        fallbackDesign: .serif)
    case .condensed:
      return resolvedFont(
        candidates: ["Avenir Next Condensed", "Arial Narrow"],
        size: pointSize,
        weight: resolvedWeight,
        fallbackDesign: .default)
    case .humanist:
      return resolvedFont(
        candidates: ["Avenir Next", "Trebuchet MS"],
        size: pointSize,
        weight: resolvedWeight,
        fallbackDesign: .rounded)
    }
  }

  private func resolvedFont(
    candidates: [String],
    size: CGFloat,
    weight: Font.Weight,
    fallbackDesign: Font.Design
  ) -> Font {
    if let installedName = candidates.first(where: { NSFont(name: $0, size: size) != nil }) {
      return .custom(installedName, size: size).weight(weight)
    }
    return .system(size: size, weight: weight, design: fallbackDesign)
  }
}

extension IslandTheme {
  var preferredColorScheme: ColorScheme {
    chrome.prefersLightSurface ? .light : .dark
  }
}

extension IslandVectorPath {
  /// Projects the vector into a centered aspect-fit SwiftUI path.
  ///
  /// - Parameter rect: Destination bounds.
  /// - Returns: A path that preserves the official asset's aspect ratio.
  func swiftUIPath(in rect: CGRect) -> Path {
    let sourceWidth = CGFloat(Self.deepSeekWhaleViewBoxWidth)
    let sourceHeight = CGFloat(Self.deepSeekWhaleViewBoxHeight)
    let scale = min(rect.width / sourceWidth, rect.height / sourceHeight)
    let offset = CGPoint(
      x: rect.minX + (rect.width - sourceWidth * scale) / 2,
      y: rect.minY + (rect.height - sourceHeight * scale) / 2)

    func project(_ point: IslandVectorPoint) -> CGPoint {
      CGPoint(
        x: offset.x + CGFloat(point.x) * scale,
        y: offset.y + CGFloat(point.y) * scale)
    }

    var path = Path()
    for command in commands {
      switch command {
      case .move(let point):
        path.move(to: project(point))
      case .line(let point):
        path.addLine(to: project(point))
      case .curve(let control1, let control2, let point):
        path.addCurve(
          to: project(point),
          control1: project(control1),
          control2: project(control2))
      case .close:
        path.closeSubpath()
      }
    }
    return path
  }
}

/// The official DeepSeek whale projected without modifying its geometry.
struct WhaleShape: Shape {
  func path(in rect: CGRect) -> Path {
    IslandVectorPath.deepSeekWhale.swiftUIPath(in: rect)
  }
}
