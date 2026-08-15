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

  let cornerPoints = [
    (0, 0),
    (image.pixelsWide - 1, 0),
    (0, image.pixelsHigh - 1),
    (image.pixelsWide - 1, image.pixelsHigh - 1),
  ]
  for (x, y) in cornerPoints {
    guard let color = image.colorAt(x: x, y: y), color.alphaComponent <= 0.16 else {
      fputs("PNG corner is not transparent at \(x),\(y): \(path)\n", stderr)
      exit(1)
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
