import Cocoa

// Usage: makeicon <input.png> <output.png> <size>
let args = CommandLine.arguments
guard args.count == 4, let outSize = Int(args[3]) else {
    FileHandle.standardError.write("usage: makeicon in.png out.png size\n".data(using: .utf8)!)
    exit(1)
}
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

guard let src = NSImage(contentsOf: inURL),
      let tiff = src.tiffRepresentation,
      let bmp = NSBitmapImageRep(data: tiff) else {
    FileHandle.standardError.write("cannot read input\n".data(using: .utf8)!); exit(1)
}

let w = bmp.pixelsWide, h = bmp.pixelsHigh

// The blue squircle is the content; the border is green grunge with black blotches.
// Find the bounding box of clearly-blue pixels (blue dominant + reasonably bright).
func isContent(_ c: NSColor) -> Bool {
    let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
    // Solid squircle blue: blue clearly dominant over red. Excludes the soft
    // greenish outer glow (where b ≈ r) and the green/black grunge border.
    return b > 0.45 && b > r + 0.18 && b > g - 0.02
}

// Count content pixels per row/column, then take the bounding box of rows/cols
// whose count exceeds a fraction of the peak. This ignores isolated stray
// blue-ish pixels in the grunge that would otherwise distort the box.
let step = max(1, w / 800)
var rowCount = [Int](repeating: 0, count: h)
var colCount = [Int](repeating: 0, count: w)
for y in stride(from: 0, to: h, by: step) {
    for x in stride(from: 0, to: w, by: step) {
        guard let c = bmp.colorAt(x: x, y: y), isContent(c) else { continue }
        rowCount[y] += 1
        colCount[x] += 1
    }
}
func bounds(_ counts: [Int]) -> (Int, Int) {
    let peak = counts.max() ?? 0
    let thresh = max(1, peak / 10)        // ignore rows/cols with < 10% of peak
    let lo = counts.firstIndex { $0 >= thresh } ?? 0
    let hi = counts.lastIndex { $0 >= thresh } ?? (counts.count - 1)
    return (lo, hi)
}
var (minY, maxY) = bounds(rowCount)
var (minX, maxX) = bounds(colCount)
if minX >= maxX || minY >= maxY { minX = 0; minY = 0; maxX = w - 1; maxY = h - 1 }

// Make the crop square (the icon content is square).
var cropW = maxX - minX, cropH = maxY - minY
let side = max(cropW, cropH)
var cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
var ox = cx - side / 2, oy = cy - side / 2
ox = max(0, min(ox, w - side)); oy = max(0, min(oy, h - side))
// Inset to eat the soft anti-aliased edge so no border bleeds through.
let inset = Double(side) * 0.028
let cropRect = NSRect(x: Double(ox) + inset, y: Double(oy) + inset,
                      width: Double(side) - inset * 2, height: Double(side) - inset * 2)

// Draw cropped content into an exact-pixel canvas with a rounded-rect (squircle) mask.
let dim = CGFloat(outSize)
guard let outBmp = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: outSize, pixelsHigh: outSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    FileHandle.standardError.write("cannot alloc canvas\n".data(using: .utf8)!); exit(1)
}
outBmp.size = NSSize(width: dim, height: dim)   // 1 point == 1 pixel
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: outBmp)
NSGraphicsContext.current?.imageInterpolation = .high
let dest = NSRect(x: 0, y: 0, width: dim, height: dim)
let radius = dim * 0.30                         // round enough to exclude grunge corners
NSBezierPath(roundedRect: dest, xRadius: radius, yRadius: radius).addClip()
src.draw(in: dest, from: cropRect, operation: .copy, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let png = outBmp.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("cannot encode output\n".data(using: .utf8)!); exit(1)
}
try? png.write(to: outURL)
print("cropped green border -> \(Int(cropRect.width))px square, output \(outSize)px")
