import AppKit
import WebKit
import ImageIO
import UniformTypeIdentifiers

// Render an animated GIF from a page that defines frameCount() and showFrame(i).
// Usage: gifrender <input.html> <output.gif> <widthPt> <heightPt> <outWidthPx> <frameDelaySeconds>

let args = CommandLine.arguments
guard args.count == 7,
      let wPt = Double(args[3]), let hPt = Double(args[4]),
      let outW = Int(args[5]), let delay = Double(args[6]) else {
    FileHandle.standardError.write("usage: gifrender <in.html> <out.gif> <widthPt> <heightPt> <outWidthPx> <delay>\n".data(using: .utf8)!)
    exit(2)
}
struct Config {
    let inURL: URL, outURL: URL
    let wPt: Double, hPt: Double
    let outW: Int, outH: Int
    let delay: Double
}
let config = Config(inURL: URL(fileURLWithPath: args[1]), outURL: URL(fileURLWithPath: args[2]),
                    wPt: wPt, hPt: hPt, outW: outW, outH: Int((Double(outW) * hPt / wPt).rounded()), delay: delay)

final class GifRenderer: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let c: Config
    var dest: CGImageDestination!
    var count = 0
    let frameProps: CFDictionary

    init(_ c: Config) {
        self.c = c
        frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: c.delay]] as CFDictionary
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: c.wPt, height: c.hPt), configuration: WKWebViewConfiguration())
        super.init()
        web.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        web.evaluateJavaScript("frameCount()") { result, _ in
            self.count = (result as? Int) ?? 0
            guard self.count > 0,
                  let d = CGImageDestinationCreateWithURL(self.c.outURL as CFURL, UTType.gif.identifier as CFString, self.count, nil) else {
                FileHandle.standardError.write("no frames or cannot create GIF\n".data(using: .utf8)!); exit(1)
            }
            CGImageDestinationSetProperties(d, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            self.dest = d
            self.step(0)
        }
    }

    func step(_ i: Int) {
        if i == count {
            guard CGImageDestinationFinalize(dest) else { FileHandle.standardError.write("finalize failed\n".data(using: .utf8)!); exit(1) }
            print("wrote \(count) frames, \(c.outW)x\(c.outH)")
            exit(0)
        }
        web.evaluateJavaScript("showFrame(\(i))") { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                let cfg = WKSnapshotConfiguration()
                cfg.rect = NSRect(x: 0, y: 0, width: self.c.wPt, height: self.c.hPt)
                self.web.takeSnapshot(with: cfg) { image, err in
                    guard let image, let frame = self.scaled(image) else {
                        FileHandle.standardError.write("snapshot failed: \(String(describing: err))\n".data(using: .utf8)!); exit(1)
                    }
                    CGImageDestinationAddImage(self.dest, frame, self.frameProps)
                    self.step(i + 1)
                }
            }
        }
    }

    /// Redraw the snapshot at the exact output pixel size.
    func scaled(_ image: NSImage) -> CGImage? {
        var r = CGRect(origin: .zero, size: image.size)
        guard let src = image.cgImage(forProposedRect: &r, context: nil, hints: nil),
              let ctx = CGContext(data: nil, width: c.outW, height: c.outH, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: c.outW, height: c.outH))
        return ctx.makeImage()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let renderer = GifRenderer(config)
renderer.web.loadFileURL(config.inURL, allowingReadAccessTo: config.inURL.deletingLastPathComponent())
app.run()
