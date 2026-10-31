// Run from macOS: swift tool/generate_ios_assets.swift
// Reuses the existing brand assets without extra dependencies.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("ios/Runner/Assets.xcassets")
func render(_ source: URL, to destination: URL, width: Int, height: Int) throws {
  guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else {
    throw NSError(domain: "DailyAssets", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Cannot render \(source.path)"])
  }
  let bounds = CGRect(x: 0, y: 0, width: width, height: height)
  context.setFillColor(red: 247 / 255, green: 246 / 255, blue: 242 / 255, alpha: 1)
  context.fill(bounds)
  context.interpolationQuality = .high
  context.draw(image, in: bounds)
  guard let rendered = context.makeImage(),
    let output = CGImageDestinationCreateWithURL(
      destination as CFURL, UTType.png.identifier as CFString, 1, nil)
  else {
    throw NSError(domain: "DailyAssets", code: 2)
  }
  CGImageDestinationAddImage(output, rendered, nil)
  guard CGImageDestinationFinalize(output) else {
    throw NSError(domain: "DailyAssets", code: 3)
  }
}

let iconSet = assets.appendingPathComponent("AppIcon.appiconset")
let catalog = try JSONSerialization.jsonObject(
  with: Data(contentsOf: iconSet.appendingPathComponent("Contents.json"))) as! [String: Any]
var rendered = Set<String>()
for image in catalog["images"] as! [[String: String]] {
  guard let name = image["filename"], rendered.insert(name).inserted else { continue }
  let points = Double(image["size"]!.components(separatedBy: "x")[0])!
  let scale = Double(image["scale"]!.dropLast())!
  let size = Int(points * scale)
  try render(root.appendingPathComponent("assets/branding/launcher-source.png"),
    to: iconSet.appendingPathComponent(name), width: size, height: size)
}

for scale in 1...3 {
  let suffix = scale == 1 ? "" : "@\(scale)x"
  try render(root.appendingPathComponent("assets/branding/splash-lockup.png"),
    to: assets.appendingPathComponent("LaunchImage.imageset/LaunchImage\(suffix).png"),
    width: 260 * scale, height: 87 * scale)
}
print("Generated \(rendered.count) opaque iOS icons and 3 launch images.")
