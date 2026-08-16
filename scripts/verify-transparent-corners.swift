import AppKit
import Foundation
import SwiftUI

let specifications = Array(CommandLine.arguments.dropFirst())
guard !specifications.isEmpty, specifications.count.isMultiple(of: 2) else {
  fputs("usage: verify-transparent-corners <png> <corner-radius> [...]\n", stderr)
  exit(64)
}

for index in stride(from: 0, to: specifications.count, by: 2) {
  let path = specifications[index]
  guard let cornerRadius = Double(specifications[index + 1]), cornerRadius > 0 else {
    fputs("invalid corner radius for PNG: \(path)\n", stderr)
    exit(64)
  }
  guard
    let data = FileManager.default.contents(atPath: path),
    let image = NSBitmapImageRep(data: data)
  else {
    fputs("could not read PNG: \(path)\n", stderr)
    exit(1)
  }
  guard image.hasAlpha else {
    fputs("PNG has no alpha channel: \(path)\n", stderr)
    exit(1)
  }

  // Native capture is downsampled from Retina resolution, so tolerate a narrow
  // antialias fringe while checking the entire region outside the intended curve.
  let antialiasAllowance: CGFloat = 1.5
  let imageBounds = CGRect(
    x: 0,
    y: 0,
    width: CGFloat(image.pixelsWide),
    height: CGFloat(image.pixelsHigh))
  let allowedShape = RoundedRectangle(
    cornerRadius: CGFloat(cornerRadius) + antialiasAllowance,
    style: .continuous
  ).path(in: imageBounds.insetBy(dx: -antialiasAllowance, dy: -antialiasAllowance))
  let cornerExtent = min(
    Int(ceil(cornerRadius + Double(antialiasAllowance))) + 1,
    min(image.pixelsWide, image.pixelsHigh) / 2)
  for xOffset in 0..<cornerExtent {
    for yOffset in 0..<cornerExtent {
      let cornerPoints = [
        (xOffset, yOffset),
        (image.pixelsWide - 1 - xOffset, yOffset),
        (xOffset, image.pixelsHigh - 1 - yOffset),
        (image.pixelsWide - 1 - xOffset, image.pixelsHigh - 1 - yOffset),
      ]
      for (x, y) in cornerPoints {
        let samplePoint = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
        guard !allowedShape.contains(samplePoint) else { continue }
        guard let color = image.colorAt(x: x, y: y), color.alphaComponent <= 0.01 else {
          fputs(
            "PNG alpha \(colorAt(image, x: x, y: y)) exceeds 0.01 outside radius "
              + "\(cornerRadius) at \(x),\(y): \(path)\n",
            stderr
          )
          exit(1)
        }
      }
    }
  }

  let surfacePoints = [
    (image.pixelsWide / 2, 0),
    (image.pixelsWide / 2, image.pixelsHigh - 1),
    (0, image.pixelsHigh / 2),
    (image.pixelsWide - 1, image.pixelsHigh / 2),
  ]
  for (x, y) in surfacePoints {
    guard let color = image.colorAt(x: x, y: y), color.alphaComponent >= 0.95 else {
      fputs("PNG surface edge is unexpectedly transparent at \(x),\(y): \(path)\n", stderr)
      exit(1)
    }
  }

  print("transparent rounded corners: \(path)")
}

private func colorAt(_ image: NSBitmapImageRep, x: Int, y: Int) -> String {
  guard let color = image.colorAt(x: x, y: y) else { return "unavailable" }
  return String(format: "%.4f", color.alphaComponent)
}
