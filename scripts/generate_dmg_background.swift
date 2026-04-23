#!/usr/bin/env swift

import AppKit

let arguments = CommandLine.arguments
let outputPath = arguments.dropFirst().first ?? "Assets/dmg-background.png"

let canvasSize = NSSize(width: 720, height: 420)
let canvasRect = NSRect(origin: .zero, size: canvasSize)

extension NSColor {
    static func fala(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }
}

func drawCard(_ rect: NSRect, fill: NSColor, stroke: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = NSSize(width: 0, height: -6)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    fill.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    stroke.setStroke()
    path.lineWidth = 1
    path.stroke()
}

func drawWaveform(center: CGPoint) {
    let heights: [CGFloat] = [84, 154, 196, 166, 112, 146, 138, 66]
    let barWidth: CGFloat = 18
    let gap: CGFloat = 14
    let totalWidth = (CGFloat(heights.count) * barWidth) + (CGFloat(heights.count - 1) * gap)
    let originX = center.x - (totalWidth / 2)

    for (index, height) in heights.enumerated() {
        let barOriginX = originX + CGFloat(index) * (barWidth + gap)
        let rect = NSRect(x: barOriginX, y: center.y - (height / 2), width: barWidth, height: height)
        let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
        let fill = NSColor.fala(red: 124, green: 124, blue: 255, alpha: 0.18)
        fill.setFill()
        path.fill()
    }
}

func drawArrow(from start: CGPoint, to end: CGPoint) {
    let shaft = NSBezierPath()
    shaft.move(to: start)
    shaft.line(to: end)
    shaft.lineWidth = 16
    shaft.lineCapStyle = .round

    let arrowColor = NSColor.fala(red: 255, green: 110, blue: 94, alpha: 0.92)
    let shadow = NSShadow()
    shadow.shadowColor = arrowColor.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 16
    shadow.shadowOffset = .zero

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    arrowColor.setStroke()
    shaft.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let arrowHead = NSBezierPath()
    arrowHead.move(to: CGPoint(x: end.x + 26, y: end.y))
    arrowHead.line(to: CGPoint(x: end.x - 6, y: end.y + 22))
    arrowHead.line(to: CGPoint(x: end.x - 6, y: end.y - 22))
    arrowHead.close()

    arrowColor.setFill()
    arrowHead.fill()
}

let image = NSImage(size: canvasSize)
image.lockFocus()

guard let backgroundGradient = NSGradient(
    colors: [
        NSColor.fala(red: 246, green: 246, blue: 248),
        NSColor.fala(red: 239, green: 240, blue: 244)
    ]
) else {
    fputs("error: falha ao criar gradiente de background\n", stderr)
    exit(1)
}
backgroundGradient.draw(in: canvasRect, angle: 0)

let framePath = NSBezierPath(roundedRect: canvasRect.insetBy(dx: 16, dy: 16), xRadius: 34, yRadius: 34)
NSColor.white.withAlphaComponent(0.78).setStroke()
framePath.lineWidth = 1
framePath.stroke()

let leftCard = NSRect(x: 70, y: 74, width: 210, height: 238)
let rightCard = NSRect(x: 440, y: 74, width: 210, height: 238)
drawCard(
    leftCard,
    fill: NSColor.white.withAlphaComponent(0.72),
    stroke: NSColor.white.withAlphaComponent(0.9)
)
drawCard(
    rightCard,
    fill: NSColor.white.withAlphaComponent(0.68),
    stroke: NSColor.white.withAlphaComponent(0.86)
)

drawWaveform(center: CGPoint(x: 360, y: 184))
drawArrow(from: CGPoint(x: 309, y: 193), to: CGPoint(x: 391, y: 193))

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("error: falha ao renderizar PNG\n", stderr)
    exit(1)
}

bitmap.size = canvasSize

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("background gerado em \(outputPath)")
} catch {
    fputs("error: falha ao salvar background em \(outputPath): \(error)\n", stderr)
    exit(1)
}
