import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draw the unmasked 1024 px source. iOS applies the Home Screen corner mask.
let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: 1, y: -1)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r / 255, g / 255, b / 255, a])!
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fill(_ path: CGPath, _ ink: CGColor) {
    context.addPath(path)
    context.setFillColor(ink)
    context.fillPath()
}

func stroke(_ path: CGPath, _ ink: CGColor, _ width: CGFloat) {
    context.addPath(path)
    context.setStrokeColor(ink)
    context.setLineWidth(width)
    context.strokePath()
}

func gradient(_ colors: [CGColor], in rect: CGRect, from top: CGPoint, to bottom: CGPoint) {
    context.saveGState()
    context.clip(to: rect)
    let stops = (0..<colors.count).map { CGFloat($0) / CGFloat(colors.count - 1) }
    let value = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: stops)!
    context.drawLinearGradient(value, start: top, end: bottom, options: [])
    context.restoreGState()
}

let whole = CGRect(x: 0, y: 0, width: size, height: size)
gradient([color(27, 31, 35), color(10, 14, 18)], in: whole,
         from: CGPoint(x: 512, y: 0), to: CGPoint(x: 512, y: 1024))
let halo = CGGradient(colorsSpace: colorSpace,
                      colors: [color(184, 113, 51, 0.24), color(184, 113, 51, 0)] as CFArray,
                      locations: [0, 1])!
context.drawRadialGradient(halo, startCenter: CGPoint(x: 512, y: 435), startRadius: 60,
                           endCenter: CGPoint(x: 512, y: 435), endRadius: 560,
                           options: [.drawsAfterEndLocation])

// A six-blade darkroom enlarger lens. Keep the silhouette bold at small sizes.
let center = CGPoint(x: 512, y: 362)
let outer: CGFloat = 236
let inner: CGFloat = 103
let ring = CGPath(ellipseIn: CGRect(x: center.x - outer - 16,
                                    y: center.y - outer - 16,
                                    width: (outer + 16) * 2,
                                    height: (outer + 16) * 2), transform: nil)
stroke(ring, color(238, 192, 126, 0.33), 8)

func point(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
    CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
}
for blade in 0..<6 {
    let angle = CGFloat(blade) * .pi / 3 - .pi / 2
    let path = CGMutablePath()
    let vertices = [
        point(inner, angle + 0.14), point(outer, angle - 0.43),
        point(outer, angle + 0.57), point(inner, angle + 1.04),
    ]
    path.move(to: vertices[0])
    vertices.dropFirst().forEach { path.addLine(to: $0) }
    path.closeSubpath()
    fill(path, color(206 + CGFloat(blade % 2) * 15,
                     151 + CGFloat(blade % 2) * 13,
                     88 + CGFloat(blade % 2) * 10))
    stroke(path, color(250, 215, 162, 0.46), 3)
}
let aperture = CGPath(ellipseIn: CGRect(x: center.x - inner + 6,
                                        y: center.y - inner + 6,
                                        width: (inner - 6) * 2,
                                        height: (inner - 6) * 2), transform: nil)
fill(aperture, color(27, 25, 25))
stroke(aperture, color(255, 223, 170, 0.82), 9)
let light = CGPath(ellipseIn: CGRect(x: center.x - 33, y: center.y - 33,
                                     width: 66, height: 66), transform: nil)
fill(light, color(255, 227, 169))

// A narrow cone of enlarger light falls onto a fresh print.
let beam = CGMutablePath()
beam.move(to: CGPoint(x: 492, y: 451))
beam.addLine(to: CGPoint(x: 332, y: 670))
beam.addLine(to: CGPoint(x: 692, y: 670))
beam.addLine(to: CGPoint(x: 532, y: 451))
beam.closeSubpath()
fill(beam, color(244, 192, 117, 0.11))

let paper = CGRect(x: 237, y: 619, width: 550, height: 271)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: 17), blur: 35,
                  color: color(0, 0, 0, 0.55))
fill(rounded(paper, 31), color(243, 221, 181))
context.restoreGState()
stroke(rounded(paper, 31), color(255, 241, 210, 0.85), 5)

let image = CGRect(x: 266, y: 648, width: 492, height: 213)
context.saveGState()
context.addPath(rounded(image, 13))
context.clip()
gradient([color(202, 134, 88), color(89, 110, 108), color(33, 59, 68)],
         in: image, from: CGPoint(x: 512, y: 648), to: CGPoint(x: 512, y: 861))
let horizon = CGMutablePath()
horizon.move(to: CGPoint(x: 266, y: 792))
horizon.addCurve(to: CGPoint(x: 758, y: 768),
                 control1: CGPoint(x: 410, y: 723), control2: CGPoint(x: 570, y: 840))
horizon.addLine(to: CGPoint(x: 758, y: 861))
horizon.addLine(to: CGPoint(x: 266, y: 861))
horizon.closeSubpath()
fill(horizon, color(22, 46, 53))
context.restoreGState()

guard CommandLine.arguments.count == 2,
      let bitmap = context.makeImage() else {
    fatalError("Usage: swift make-app-icon.swift /path/to/AppIcon-1024.png")
}
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let writer = CGImageDestinationCreateWithURL(destination as CFURL,
                                             UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(writer, bitmap, nil)
guard CGImageDestinationFinalize(writer) else { fatalError("Could not write icon") }
