import AppKit
import WebKit

// Offscreen WKWebView snapshot of an HTML file -> PNG.
// Usage: iconrender <input.html> <output.png> <sizePx>

let args = CommandLine.arguments
guard args.count == 4,
      let px = Double(args[3]) else {
    FileHandle.standardError.write("usage: iconrender <input.html> <output.png> <sizePx>\n".data(using: .utf8)!)
    exit(2)
}
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let side = CGFloat(px)

final class Snapper: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let out: URL
    let side: CGFloat
    init(side: CGFloat, out: URL) {
        self.side = side
        self.out = out
        let cfg = WKWebViewConfiguration()
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: side, height: side), configuration: cfg)
        super.init()
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
    }
    func load(_ url: URL) {
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give the layout a beat, then snapshot.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let cfg = WKSnapshotConfiguration()
            cfg.rect = NSRect(x: 0, y: 0, width: self.side, height: self.side)
            webView.takeSnapshot(with: cfg) { image, err in
                guard let image = image,
                      let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    FileHandle.standardError.write("snapshot failed: \(String(describing: err))\n".data(using: .utf8)!)
                    exit(1)
                }
                do { try png.write(to: self.out) } catch {
                    FileHandle.standardError.write("write failed: \(error)\n".data(using: .utf8)!)
                    exit(1)
                }
                exit(0)
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let snapper = Snapper(side: side, out: outURL)
snapper.load(inURL)
app.run()
