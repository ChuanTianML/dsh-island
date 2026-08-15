import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
  fputs("usage: verify-transparent-corners <png> [...]\n", stderr)
  exit(64)
}

for path in CommandLine.arguments.dropFirst() {
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

  let probeDepth = min(8, min(image.pixelsWide, image.pixelsHigh) / 8)
  for xOffset in 0..<probeDepth {
    for yOffset in 0..<probeDepth {
      let cornerPoints = [
        (xOffset, yOffset),
        (image.pixelsWide - 1 - xOffset, yOffset),
        (xOffset, image.pixelsHigh - 1 - yOffset),
        (image.pixelsWide - 1 - xOffset, image.pixelsHigh - 1 - yOffset),
      ]
      for (x, y) in cornerPoints {
        guard let color = image.colorAt(x: x, y: y), color.alphaComponent <= 0.01 else {
          fputs(
            "PNG corner alpha \(colorAt(image, x: x, y: y)) exceeds 0.01 at \(x),\(y): \(path)\n",
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
