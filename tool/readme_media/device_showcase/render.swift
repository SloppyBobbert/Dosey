import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let canvasWidth = 1600
let canvasHeight = 880
let root = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()
  .deletingLastPathComponent()
  .deletingLastPathComponent()
let raw = root.appendingPathComponent("media/readme/raw")
let output = root.appendingPathComponent("media/readme/device-showcase.png")

func image(named name: String) -> CGImage {
  let url = raw.appendingPathComponent(name) as CFURL
  guard let source = CGImageSourceCreateWithURL(url, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Could not read \(name)")
  }
  return image
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
  CGColor(
    red: CGFloat((hex >> 16) & 0xff) / 255,
    green: CGFloat((hex >> 8) & 0xff) / 255,
    blue: CGFloat(hex & 0xff) / 255,
    alpha: alpha
  )
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
  CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fill(_ context: CGContext, _ rect: CGRect, _ fill: CGColor, radius: CGFloat) {
  context.addPath(roundedRect(rect, radius: radius))
  context.setFillColor(fill)
  context.fillPath()
}

func stroke(_ context: CGContext, _ rect: CGRect, _ line: CGColor, radius: CGFloat, width: CGFloat = 1) {
  context.addPath(roundedRect(rect, radius: radius))
  context.setStrokeColor(line)
  context.setLineWidth(width)
  context.strokePath()
}

func drawScreen(_ context: CGContext, image: CGImage, in rect: CGRect, radius: CGFloat) {
  context.saveGState()
  context.addPath(roundedRect(rect, radius: radius))
  context.clip()
  context.interpolationQuality = .high
  context.translateBy(x: rect.midX, y: rect.midY)
  context.scaleBy(x: 1, y: -1)
  context.translateBy(x: -rect.midX, y: -rect.midY)
  context.draw(image, in: rect)
  context.restoreGState()
}

func label(_ context: CGContext, _ text: String, centerX: CGFloat, baseline: CGFloat) {
  let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 22, nil)
  let postScriptName = CTFontCopyPostScriptName(font) as String
  guard postScriptName == "HelveticaNeue-Medium" else {
    fatalError("HelveticaNeue-Medium resolved as \(postScriptName)")
  }
  let attributes: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(0x27313a),
  ]
  let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
  let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
  context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
  context.textPosition = CGPoint(x: centerX - width / 2, y: baseline)
  CTLineDraw(line, context)
  context.textMatrix = .identity
}

let android = image(named: "today_android_phone.png")
let iphone = image(named: "today_iphone.png")
let desktop = image(named: "today_desktop_wide.png")

guard let context = CGContext(
  data: nil,
  width: canvasWidth,
  height: canvasHeight,
  bitsPerComponent: 8,
  bytesPerRow: 0,
  space: CGColorSpaceCreateDeviceRGB(),
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create context") }

context.setFillColor(CGColor.white)
context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
context.translateBy(x: 0, y: CGFloat(canvasHeight))
context.scaleBy(x: 1, y: -1)

let graphite = color(0x1d252d)
let rim = color(0x5d6975)
let shadow = color(0x10202d, alpha: 0.14)

// Android: outer bottom 760, screen retains the source's 412:915 aspect ratio.
let androidOuter = CGRect(x: 92, y: 88, width: 310, height: 672)
let androidScreen = CGRect(x: 106, y: 116, width: 282, height: 626.1408)
context.setShadow(offset: CGSize(width: 0, height: 10), blur: 18, color: shadow)
fill(context, androidOuter, graphite, radius: 42)
context.setShadow(offset: .zero, blur: 0, color: nil)
stroke(context, androidOuter.insetBy(dx: 1, dy: 1), rim, radius: 41)
drawScreen(context, image: android, in: androidScreen, radius: 29)
fill(context, CGRect(x: 178, y: 101, width: 138, height: 5), color(0x87919a), radius: 3)

// iPhone: a slightly smaller frame provides a distinct physical silhouette.
let iphoneOuter = CGRect(x: 451, y: 100, width: 304, height: 660)
let iphoneScreen = CGRect(x: 462, y: 126, width: 282, height: 610.656)
context.setShadow(offset: CGSize(width: 0, height: 10), blur: 18, color: shadow)
fill(context, iphoneOuter, graphite, radius: 45)
context.setShadow(offset: .zero, blur: 0, color: nil)
stroke(context, iphoneOuter.insetBy(dx: 1, dy: 1), rim, radius: 44)
drawScreen(context, image: iphone, in: iphoneScreen, radius: 33)
fill(context, CGRect(x: 562, y: 111, width: 82, height: 18), color(0x080b0e), radius: 10)

// Desktop: screen retains 1366:768 aspect ratio; monitor, neck, and base make it unmistakably physical.
let monitorOuter = CGRect(x: 812, y: 132, width: 698, height: 414)
let monitorScreen = CGRect(x: 827, y: 148, width: 668, height: 375.5154)
context.setShadow(offset: CGSize(width: 0, height: 11), blur: 20, color: shadow)
fill(context, monitorOuter, graphite, radius: 20)
context.setShadow(offset: .zero, blur: 0, color: nil)
stroke(context, monitorOuter.insetBy(dx: 1, dy: 1), rim, radius: 19)
drawScreen(context, image: desktop, in: monitorScreen, radius: 8)
fill(context, CGRect(x: 1125, y: 546, width: 72, height: 172), graphite, radius: 8)
stroke(context, CGRect(x: 1125, y: 546, width: 72, height: 172), rim, radius: 8)
fill(context, CGRect(x: 1018, y: 718, width: 286, height: 42), graphite, radius: 20)
stroke(context, CGRect(x: 1018, y: 718, width: 286, height: 42), rim, radius: 20)

label(context, "Android", centerX: androidOuter.midX, baseline: 812)
label(context, "iPhone", centerX: iphoneOuter.midX, baseline: 812)
label(context, "Computer", centerX: monitorOuter.midX, baseline: 812)

guard let result = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
  fatalError("Could not create output")
}
CGImageDestinationAddImage(destination, result, [kCGImagePropertyPNGInterlaceType: false] as CFDictionary)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write output") }
