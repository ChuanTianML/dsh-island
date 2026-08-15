import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2,
  let processID = Int32(CommandLine.arguments[1])
else {
  fputs("usage: window-id <process-id>\n", stderr)
  exit(64)
}

let windows =
  CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], .zero)
  as? [[String: Any]] ?? []

let candidates = windows.compactMap { window -> (number: Int, area: CGFloat)? in
  guard
    window[kCGWindowOwnerPID as String] as? Int32 == processID,
    let number = window[kCGWindowNumber as String] as? Int,
    let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary
  else {
    return nil
  }
  var bounds = CGRect.zero
  guard CGRectMakeWithDictionaryRepresentation(boundsDictionary, &bounds) else {
    return nil
  }
  return (number, bounds.width * bounds.height)
}

guard let window = candidates.max(by: { $0.area < $1.area }) else {
  exit(1)
}

print(window.number)
