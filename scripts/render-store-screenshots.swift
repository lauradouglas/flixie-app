// Native macOS compositor: real captures + typography, without altering app UI.
// Called by prepare-store-screenshots.py; no network or external dependencies.
import AppKit
import CoreText

struct Job: Decodable {
    let source: String
    let output: String
    let headline: String
    let width: Int
    let height: Int
}
struct Plan: Decodable {
    let font: String
    let background: String
    let accent: String
    let jobs: [Job]
}
enum RenderError: Error { case invalid(String) }
func color(_ hex: String) throws -> NSColor {
    guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else {
        throw RenderError.invalid("Invalid RGB colour: \(hex)")
    }
    return NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                   green: CGFloat((rgb >> 8) & 255) / 255,
                   blue: CGFloat(rgb & 255) / 255, alpha: 1)
}
let plan = try JSONDecoder().decode(Plan.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let fontURL = URL(fileURLWithPath: plan.font)
guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
      let descriptor = descriptors.first else { throw RenderError.invalid("Missing Manrope font") }
let boldDescriptor = CTFontDescriptorCreateCopyWithVariation(descriptor, NSNumber(value: 0x77676874), 800)
let background = try color(plan.background)
let accent = try color(plan.accent)

func drawText(_ text: String, font: NSFont, color: NSColor, rect: CGRect) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byClipping
    (text as NSString).draw(in: rect, withAttributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        .kern: -font.pointSize * 0.025
    ])
}

for job in plan.jobs {
    try autoreleasepool {
        let w = CGFloat(job.width), h = CGFloat(job.height)
        guard let source = NSImage(contentsOfFile: job.source),
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: job.width,
                  pixelsHigh: job.height, bitsPerSample: 8, samplesPerPixel: 4,
                  hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                  bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw RenderError.invalid("Cannot render \(job.source)")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let cg = graphics.cgContext
        cg.translateBy(x: 0, y: h)
        cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        graphics.imageInterpolation = .high
        background.setFill()
        CGRect(x: 0, y: 0, width: w, height: h).fill()

        // Exact wordmark convention: white flix, purple ie, SF bold on iOS.
        let brandSize = w * 0.052
        let brandFont = NSFont.systemFont(ofSize: brandSize, weight: .heavy)
        let brand = NSMutableAttributedString(string: "flixie", attributes: [
            .font: brandFont, .foregroundColor: NSColor.white, .kern: -brandSize * 0.021
        ])
        brand.addAttribute(.foregroundColor, value: try color("7C4DFF"), range: NSRange(location: 4, length: 2))
        brand.draw(at: CGPoint(x: (w - brand.size().width) / 2, y: h * 0.027))

        let tablet = w / h > 0.65
        let fontSize = w * (tablet ? 0.061 : 0.078)
        let font = CTFontCreateWithFontDescriptor(boldDescriptor, fontSize, nil) as NSFont
        let lines = job.headline.components(separatedBy: "\n")
        guard lines.count == 2 else { throw RenderError.invalid("Use two headline lines") }
        let textTop = h * 0.077
        for (index, line) in lines.enumerated() {
            let measured = (line as NSString).size(withAttributes: [.font: font]).width
            guard measured <= w * 0.90 else { throw RenderError.invalid("Headline too wide: \(line)") }
            drawText(line, font: font, color: index == 0 ? .white : accent,
                     rect: CGRect(x: w * 0.04, y: textTop + CGFloat(index) * fontSize * 1.18,
                                  width: w * 0.92, height: fontSize * 1.4))
        }

        // Contain the entire native screenshot. No cropping, replacement UI,
        // perspective distortion, simulated notch, or fabricated device frame.
        let top = textTop + fontSize * 2.65
        let availableHeight = h - top - h * 0.035
        let scale = min(w * 0.89 / w, availableHeight / h)
        let rect = CGRect(x: (w - w * scale) / 2, y: top,
                          width: w * scale, height: h * scale)
        let edge = max(2, w * 0.0025)
        let radius = w * 0.028
        try color("66517F").setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: -edge, dy: -edge),
                     xRadius: radius + edge, yRadius: radius + edge).fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.invalid("PNG encoding failed")
        }
        try png.write(to: URL(fileURLWithPath: job.output), options: .atomic)
        print("Rendered \(URL(fileURLWithPath: job.output).lastPathComponent)")
    }
}
