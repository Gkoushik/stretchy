import SwiftUI
import AppKit
import WebKit

// MARK: - Move catalogue (loaded from moves.json)

struct Move: Codable {
    let key: String
    let label: String
    var detail: String? = nil
    var type: String? = nil        // "hold" | "reps" | "flow"
    var cycle: Double? = nil       // seconds per animation loop
    var sides: [String]? = nil     // labels for the two halves of a hold
    var reps: Int? = nil
    var eyes: Bool? = nil          // zoom to the face and show the target dot
}

struct MoveGroup: Codable {
    let name: String
    let moves: [Move]
}

private struct MoveCatalog: Codable {
    let groups: [MoveGroup]
}

enum MochiMoves {
    static private(set) var groups: [MoveGroup] = []
    static private(set) var all: [Move] = []

    static func load() {
        if let url = Bundle.main.url(forResource: "moves", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let catalog = try? JSONDecoder().decode(MoveCatalog.self, from: data),
           catalog.groups.contains(where: { !$0.moves.isEmpty }) {
            groups = catalog.groups.filter { !$0.moves.isEmpty }
        } else {
            NSLog("moves.json missing or invalid, using built-in defaults")
            groups = fallback
        }
        all = groups.flatMap { $0.moves }
    }

    static func move(_ key: String) -> Move? { all.first { $0.key == key } }

    private static let fallback: [MoveGroup] = [
        MoveGroup(name: "Neck", moves: [
            Move(key: "turn", label: "Head turn", detail: "Hold 15s each side", type: "hold", cycle: 6, sides: ["Left", "Right"]),
            Move(key: "tilt", label: "Ear to shoulder", detail: "15s each side, shoulders down", type: "hold", cycle: 6, sides: ["Left", "Right"]),
        ]),
        MoveGroup(name: "Shoulders", moves: [
            Move(key: "shrug", label: "Shoulder shrug", detail: "Up to your ears, then drop", type: "reps", cycle: 3, reps: 5),
        ]),
        MoveGroup(name: "Full body", moves: [
            Move(key: "reach", label: "Reach up", detail: "Stretch tall · hold 15s", type: "hold", cycle: 6),
        ]),
    ]
}

// MARK: - Routine store (shared by the editor window and the scheduler)

@MainActor
final class RoutineStore: ObservableObject {
    @Published var order: [String] = []
    private let key = "routineKeys"

    func load() {
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        let valid = saved.filter { k in MochiMoves.all.contains { $0.key == k } }
        order = valid.isEmpty ? MochiMoves.all.map { $0.key } : valid
    }
    func save() { UserDefaults.standard.set(order, forKey: key) }

    var available: [Move] { MochiMoves.all.filter { m in !order.contains(m.key) } }
    func label(_ k: String) -> String { MochiMoves.move(k)?.label ?? k }

    func move(from: IndexSet, to: Int) { order.move(fromOffsets: from, toOffset: to); save() }
    func removeAt(_ offsets: IndexSet) {
        guard order.count - offsets.count >= 1 else { return }
        order.remove(atOffsets: offsets); save()
    }
    func remove(_ k: String) {
        guard order.count > 1 else { return }
        order.removeAll { $0 == k }; save()
    }
    func add(_ k: String) { guard !order.contains(k) else { return }; order.append(k); save() }
}

// MARK: - Draggable routine editor (SwiftUI)

struct RoutineEditorView: View {
    @ObservedObject var store: RoutineStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your routine").font(.headline)
                Text("Drag the ≡ handles to reorder. Exercises play in this order on each break.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)

            List {
                ForEach(store.order, id: \.self) { key in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(store.label(key))
                        Spacer()
                        Button {
                            store.remove(key)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(store.order.count <= 1)
                        .help("Remove from routine")
                    }
                    .padding(.vertical, 2)
                }
                .onMove { store.move(from: $0, to: $1) }
                .onDelete { store.removeAt($0) }
            }

            if !store.available.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add exercise").font(.subheadline).bold()
                    FlowChips(moves: store.available) { store.add($0) }
                }
                .padding(12)
            }
        }
        .frame(minWidth: 340, minHeight: 420)
    }
}

/// Simple wrapping row of "+ label" chips for the available exercises.
struct FlowChips: View {
    let moves: [Move]
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(moves, id: \.key) { mv in
                Button {
                    onTap(mv.key)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
                        Text(mv.label).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Sizes

enum BuddySize: String, CaseIterable {
    case small  = "Small"
    case medium = "Medium"
    case large  = "Large"
    /// Card size: character stage plus caption, progress bar and buttons.
    var size: NSSize {
        switch self {
        case .small:  return NSSize(width: 150, height: 270)
        case .medium: return NSSize(width: 190, height: 320)
        case .large:  return NSSize(width: 240, height: 380)
        }
    }
}

// MARK: - Popup panel

final class OverlayPanel: NSPanel {
    init(contentView: NSView, size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.contentView = contentView
    }
    // Never take keyboard focus away from what the user is doing.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the Done/Snooze buttons respond to the first click in a non-key panel.
final class ClickThroughWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Weak proxy so the web view's user content controller does not retain the app delegate.
final class ScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(c, didReceive: message)
    }
}

// MARK: - Menu bar glyph

enum MenuBarGlyph {
    /// Template image of Mochi's head. The fill rises from the bottom as the next break approaches.
    static func head(fill fraction: CGFloat) -> NSImage {
        let f = max(0, min(1, fraction))
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            let head = NSRect(x: 2.6, y: 1.4, width: 12.8, height: 12.8)
            let earL = NSRect(x: 1.6, y: 10.6, width: 5.2, height: 5.6)
            let earR = NSRect(x: 11.2, y: 10.6, width: 5.2, height: 5.6)
            let shapes = [earL, earR, head]
            NSColor.black.set()

            // Outline of the union: stroke every shape, then clear each interior.
            for r in shapes {
                let p = NSBezierPath(ovalIn: r); p.lineWidth = 1.5; p.stroke()
            }
            cg.setBlendMode(.clear)
            for r in shapes { NSBezierPath(ovalIn: r.insetBy(dx: 0.75, dy: 0.75)).fill() }
            cg.setBlendMode(.normal)

            // Eyes: closed happy arcs.
            let eyes = NSBezierPath()
            eyes.move(to: NSPoint(x: 5.6, y: 7.6)); eyes.curve(to: NSPoint(x: 8.0, y: 7.6),
                controlPoint1: NSPoint(x: 6.2, y: 9.2), controlPoint2: NSPoint(x: 7.4, y: 9.2))
            eyes.move(to: NSPoint(x: 10.0, y: 7.6)); eyes.curve(to: NSPoint(x: 12.4, y: 7.6),
                controlPoint1: NSPoint(x: 10.6, y: 9.2), controlPoint2: NSPoint(x: 11.8, y: 9.2))
            eyes.lineWidth = 1.3; eyes.lineCapStyle = .round
            eyes.stroke()

            // Fuel gauge fill, with the eyes knocked out of the filled part.
            if f > 0 {
                cg.saveGState()
                NSBezierPath(rect: NSRect(x: 0, y: 0, width: 18, height: 1.4 + 14.8 * f)).setClip()
                for r in shapes { NSBezierPath(ovalIn: r).fill() }
                cg.setBlendMode(.clear)
                eyes.stroke()
                cg.restoreGState()
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Colored Mochi face, shown only while a break is in progress.
    static let colored: NSImage? = {
        guard let url = Bundle.main.url(forResource: "menubar", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 18, height: 18)
        return img
    }()
}

// MARK: - Menu options

private let intervalOptions: [(label: String, seconds: TimeInterval)] = [
    ("1 minute (test)", 60),
    ("15 minutes",      15 * 60),
    ("30 minutes",      30 * 60),
    ("45 minutes",      45 * 60),
    ("1 hour",          60 * 60),
    ("2 hours",         120 * 60),
]

private let durationOptions: [(label: String, seconds: TimeInterval)] = [
    ("15 seconds", 15),
    ("30 seconds", 30),
    ("1 minute",   60),
    ("2 minutes",  120),
]

private let snoozeSeconds: TimeInterval = 5 * 60

// MARK: - App delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var panel: OverlayPanel?
    private var webView: WKWebView!
    private var webReady = false
    private var routineWindow: NSWindow?

    private var buddySize: BuddySize = .small
    private let store = RoutineStore()

    // Schedule
    private var reminderSeconds: TimeInterval = 60 * 60
    private var showSeconds: TimeInterval = 30
    private var shuffle = false
    private var reminderTimer: Timer?
    private var hideTimer: Timer?
    private var glyphTimer: Timer?
    private var nextFireDate: Date?
    private var cycleLength: TimeInterval = 60 * 60   // length of the current countdown (interval or snooze)
    private var breakShowing = false

    private var currentKey = "turn"
    private var dayKey = ""              // position in the daytime rotation

    // Bedtime yawn: night-only, on its own repeat interval. Settings persist.
    private let bedtimeKey = "yawn"
    private let bedtimeEndHour = 6
    private var bedtimeEnabled = UserDefaults.standard.object(forKey: "bedtimeEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(bedtimeEnabled, forKey: "bedtimeEnabled") }
    }
    private var bedtimeHour = UserDefaults.standard.object(forKey: "bedtimeHour") as? Int ?? 22 {
        didSet { UserDefaults.standard.set(bedtimeHour, forKey: "bedtimeHour") }
    }
    private var bedtimeRepeat = UserDefaults.standard.object(forKey: "bedtimeRepeat") as? Double ?? 15 * 60 {
        didSet { UserDefaults.standard.set(bedtimeRepeat, forKey: "bedtimeRepeat") }
    }
    private var bedtimeTimer: Timer?
    private var lastBedtimeShow: Date?
    private var showingBedtime = false
    private var bedtimeOnItem: NSMenuItem!
    private var bedtimeHourItems: [Int: NSMenuItem] = [:]
    private var bedtimeRepeatItems: [Int: NSMenuItem] = [:]

    // Menu refs
    private var nextItem: NSMenuItem!
    private var menuTimer: Timer?
    private var sizeItems: [BuddySize: NSMenuItem] = [:]
    private var intervalItems: [Int: NSMenuItem] = [:]
    private var durationItems: [Int: NSMenuItem] = [:]
    private var orderInOrderItem: NSMenuItem!
    private var orderShuffleItem: NSMenuItem!

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Single instance: if another Stretchy is already running, quit this one.
        let me = NSRunningApplication.current
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == me.bundleIdentifier && $0.processIdentifier != me.processIdentifier
        }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Stretchy: movement breaks"

        MochiMoves.load()
        store.load()
        currentKey = store.order.first ?? currentKey

        buildMenu()
        preparePanel()
        scheduleReminder()
        startBedtimeWatch()
    }

    // MARK: Popup

    private func preparePanel() {
        let s = buddySize.size
        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: s))
        container.material = .popover
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.masksToBounds = true

        let config = WKWebViewConfiguration()
        config.userContentController.add(ScriptMessageProxy(self), name: "stretchy")
        let web = ClickThroughWebView(frame: NSRect(origin: .zero, size: s), configuration: config)
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
        web.autoresizingMask = [.width, .height]
        web.setAccessibilityElement(false)   // the announcement carries the content for VoiceOver
        self.webView = web
        container.addSubview(web)

        let panel = OverlayPanel(contentView: container, size: s)
        self.panel = panel

        guard let url = Bundle.main.url(forResource: "player", withExtension: "html") else {
            NSLog("player.html missing from bundle"); return
        }
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webReady = true
        applyMove()
    }

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.body as? String {
        case "done":   hideBreak()
        case "snooze": snoozeAny()
        default: break
        }
    }

    private func applyMove() {
        guard webReady, let mv = MochiMoves.move(currentKey) else { return }
        var payload: [String: Any] = [
            "key": mv.key,
            "label": showingBedtime ? "Bedtime stretch" : mv.label,
            "detail": showingBedtime ? "It's late · big yawn, then wind down" : (mv.detail ?? ""),
            "cycle": mv.cycle ?? 6, "eyes": mv.eyes ?? false, "showSeconds": showSeconds,
        ]
        if let sides = mv.sides { payload["sides"] = sides }
        if let reps = mv.reps { payload["reps"] = reps }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("setMove(\(json))", completionHandler: nil)
    }

    /// The popup hangs just below the Stretchy icon in the menu bar.
    private func restingFrame() -> NSRect {
        let s = buddySize.size
        let buttonFrame = statusItem.button?.window?.frame
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let anchorX = buttonFrame?.midX ?? (vf.maxX - s.width / 2 - 16)
        let x = min(max(anchorX - s.width / 2, vf.minX + 8), vf.maxX - s.width - 8)
        return NSRect(x: x, y: vf.maxY - s.height - 6, width: s.width, height: s.height)
    }

    private func showBreak(advance: Bool = true) {
        guard let panel = panel else { return }
        if advance { nextExercise() }
        applyMove()
        breakShowing = true
        updateGlyph()
        announce()

        let rest = restingFrame()
        panel.alphaValue = 0
        panel.setFrame(reduceMotion ? rest : rest.offsetBy(dx: 0, dy: 16), display: false)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? 0.25 : 0.5
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1.0)
            panel.animator().alphaValue = 1
            if !reduceMotion { panel.animator().setFrame(rest, display: true) }
        }

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: showSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.hideBreak() }
        }
    }

    private func hideBreak() {
        hideTimer?.invalidate(); hideTimer = nil
        breakShowing = false
        showingBedtime = false
        updateGlyph()
        guard let panel = panel, panel.isVisible else { return }
        let f = panel.frame
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = reduceMotion ? 0.2 : 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            panel.animator().alphaValue = 0
            if !reduceMotion { panel.animator().setFrame(f.offsetBy(dx: 0, dy: 16), display: true) }
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    /// VoiceOver: say what the break is without moving focus.
    private func announce() {
        guard let mv = MochiMoves.move(currentKey) else { return }
        let text = "Stretch break: \(mv.label). \(mv.detail ?? "")"
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    // MARK: Scheduling

    private func scheduleReminder() {
        startCountdown(reminderSeconds)
        reminderTimer = Timer.scheduledTimer(withTimeInterval: reminderSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.startCountdown(self.reminderSeconds, keepTimer: true)
                self.showBreak()
            }
        }
    }

    private func startCountdown(_ seconds: TimeInterval, keepTimer: Bool = false) {
        if !keepTimer { reminderTimer?.invalidate(); reminderTimer = nil }
        cycleLength = seconds
        nextFireDate = Date().addingTimeInterval(seconds)
        // About 40 glyph steps per countdown, never more than once a second.
        glyphTimer?.invalidate()
        glyphTimer = Timer.scheduledTimer(withTimeInterval: max(1, min(30, seconds / 40)), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateGlyph() }
        }
        updateGlyph()
        updateNextItem()
    }

    /// Show the same exercise again in 5 minutes, then resume the regular schedule.
    private func snooze() {
        hideBreak()
        startCountdown(snoozeSeconds)
        reminderTimer = Timer.scheduledTimer(withTimeInterval: snoozeSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.scheduleReminder()
                self.showBreak(advance: false)
            }
        }
    }

    private func updateGlyph() {
        guard let button = statusItem?.button else { return }
        if breakShowing, let colored = MenuBarGlyph.colored {
            button.image = colored
            return
        }
        var fraction: CGFloat = 0
        if let d = nextFireDate, cycleLength > 0 {
            fraction = CGFloat(1 - d.timeIntervalSinceNow / cycleLength)
        }
        button.image = MenuBarGlyph.head(fill: fraction)
    }

    /// Daytime rotation. The yawn is bedtime-only, so it never appears here.
    private func nextExercise() {
        var keys = store.order.filter { $0 != bedtimeKey }
        if keys.isEmpty { keys = store.order }
        guard !keys.isEmpty else { return }
        if shuffle {
            dayKey = keys.filter { $0 != dayKey }.randomElement() ?? keys[0]
        } else if let i = keys.firstIndex(of: dayKey) {
            dayKey = keys[(i + 1) % keys.count]
        } else {
            dayKey = keys[0]
        }
        currentKey = dayKey
    }

    // MARK: Bedtime yawn

    private func startBedtimeWatch() {
        bedtimeTimer?.invalidate()
        bedtimeTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkBedtime() }
        }
        checkBedtime()
    }

    /// Night window runs from the bedtime hour until 6 AM.
    private func isNight(_ date: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        if bedtimeHour > bedtimeEndHour { return h >= bedtimeHour || h < bedtimeEndHour }
        return h >= bedtimeHour && h < bedtimeEndHour
    }

    private func checkBedtime() {
        guard bedtimeEnabled, isNight(), !breakShowing, MochiMoves.move(bedtimeKey) != nil else { return }
        if let last = lastBedtimeShow, Date().timeIntervalSince(last) < bedtimeRepeat { return }
        showBedtime()
    }

    private func showBedtime() {
        lastBedtimeShow = Date()
        showingBedtime = true
        currentKey = bedtimeKey
        showBreak(advance: false)
    }

    /// Snoozing a bedtime yawn delays only the bedtime schedule, not the daytime one.
    private func snoozeAny() {
        if showingBedtime {
            hideBreak()
            lastBedtimeShow = Date().addingTimeInterval(snoozeSeconds - bedtimeRepeat)
        } else {
            snooze()
        }
    }

    // MARK: Countdown display (menu)

    func menuWillOpen(_ menu: NSMenu) {
        updateNextItem()
        menuTimer?.invalidate()
        menuTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateNextItem() }
        }
        RunLoop.main.add(menuTimer!, forMode: .eventTracking)
    }

    func menuDidClose(_ menu: NSMenu) {
        menuTimer?.invalidate(); menuTimer = nil
    }

    private func updateNextItem() {
        guard let nextItem = nextItem else { return }
        if breakShowing {
            nextItem.title = "Exercise showing now"
        } else if let d = nextFireDate {
            let remaining = max(0, Int(d.timeIntervalSinceNow.rounded()))
            nextItem.title = String(format: "Next exercise in %d:%02d", remaining / 60, remaining % 60)
        } else {
            nextItem.title = "Next exercise in —"
        }
    }

    // MARK: Routine editor window

    @objc private func openRoutineEditor() {
        if routineWindow == nil {
            let host = NSHostingController(rootView: RoutineEditorView(store: store))
            let w = NSWindow(contentViewController: host)
            w.title = "Edit Routine"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 360, height: 440))
            routineWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        routineWindow?.center()
        routineWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        nextItem = NSMenuItem(title: "Next exercise in —", action: nil, keyEquivalent: "")
        nextItem.isEnabled = false
        menu.addItem(nextItem)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Stretch now", action: #selector(stretchNow), keyEquivalent: "s").target = self

        let stop = NSMenuItem(title: "Stop current exercise", action: #selector(stopCurrent), keyEquivalent: ".")
        stop.target = self
        menu.addItem(stop)

        let snz = NSMenuItem(title: "Snooze 5 minutes", action: #selector(snoozeCurrent), keyEquivalent: "z")
        snz.target = self
        menu.addItem(snz)

        let edit = NSMenuItem(title: "Edit routine… (drag to reorder)",
                              action: #selector(openRoutineEditor), keyEquivalent: "e")
        edit.target = self
        menu.addItem(edit)

        menu.addItem(.separator())

        let everyParent = NSMenuItem(title: "Show every…", action: nil, keyEquivalent: "")
        let everyMenu = NSMenu()
        for opt in intervalOptions {
            let item = NSMenuItem(title: opt.label, action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = opt.seconds
            intervalItems[Int(opt.seconds)] = item
            everyMenu.addItem(item)
        }
        everyParent.submenu = everyMenu
        menu.addItem(everyParent)

        let forParent = NSMenuItem(title: "Show for…", action: nil, keyEquivalent: "")
        let forMenu = NSMenu()
        for opt in durationOptions {
            let item = NSMenuItem(title: opt.label, action: #selector(setDuration(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = opt.seconds
            durationItems[Int(opt.seconds)] = item
            forMenu.addItem(item)
        }
        forParent.submenu = forMenu
        menu.addItem(forParent)

        let orderParent = NSMenuItem(title: "Exercise order", action: nil, keyEquivalent: "")
        let orderMenu = NSMenu()
        orderInOrderItem = NSMenuItem(title: "In order", action: #selector(setOrderInOrder), keyEquivalent: "")
        orderInOrderItem.target = self
        orderShuffleItem = NSMenuItem(title: "Shuffle", action: #selector(setOrderShuffle), keyEquivalent: "")
        orderShuffleItem.target = self
        orderMenu.addItem(orderInOrderItem); orderMenu.addItem(orderShuffleItem)
        orderParent.submenu = orderMenu
        menu.addItem(orderParent)

        let bedParent = NSMenuItem(title: "Bedtime yawn", action: nil, keyEquivalent: "")
        let bedMenu = NSMenu()
        bedtimeOnItem = NSMenuItem(title: "On", action: #selector(toggleBedtime), keyEquivalent: "")
        bedtimeOnItem.target = self
        bedMenu.addItem(bedtimeOnItem)
        bedMenu.addItem(.separator())
        let startsHeader = NSMenuItem(title: "Starts at", action: nil, keyEquivalent: ""); startsHeader.isEnabled = false
        bedMenu.addItem(startsHeader)
        for (label, hour) in [("9:00 PM", 21), ("10:00 PM", 22), ("11:00 PM", 23), ("12:00 AM", 0)] {
            let item = NSMenuItem(title: "   " + label, action: #selector(setBedtimeHour(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = hour
            bedtimeHourItems[hour] = item
            bedMenu.addItem(item)
        }
        let repeatHeader = NSMenuItem(title: "Repeat every", action: nil, keyEquivalent: ""); repeatHeader.isEnabled = false
        bedMenu.addItem(repeatHeader)
        for (label, secs) in [("15 minutes", 15.0 * 60), ("30 minutes", 30.0 * 60), ("1 hour", 60.0 * 60)] {
            let item = NSMenuItem(title: "   " + label, action: #selector(setBedtimeRepeat(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = secs
            bedtimeRepeatItems[Int(secs)] = item
            bedMenu.addItem(item)
        }
        bedMenu.addItem(.separator())
        let until = NSMenuItem(title: "Runs until 6:00 AM", action: nil, keyEquivalent: ""); until.isEnabled = false
        bedMenu.addItem(until)
        let preview = NSMenuItem(title: "Preview now", action: #selector(previewBedtime), keyEquivalent: "")
        preview.target = self
        bedMenu.addItem(preview)
        bedParent.submenu = bedMenu
        menu.addItem(bedParent)

        menu.addItem(.separator())

        let sizeParent = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for sz in BuddySize.allCases {
            let item = NSMenuItem(title: sz.rawValue, action: #selector(setSize(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = sz.rawValue
            sizeItems[sz] = item
            sizeMenu.addItem(item)
        }
        sizeParent.submenu = sizeMenu
        menu.addItem(sizeParent)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        refreshStates()
    }

    private func refreshStates() {
        for (sz, item) in sizeItems { item.state = (sz == buddySize) ? .on : .off }
        for (secs, item) in intervalItems { item.state = (Int(reminderSeconds) == secs) ? .on : .off }
        for (secs, item) in durationItems { item.state = (Int(showSeconds) == secs) ? .on : .off }
        orderInOrderItem.state = shuffle ? .off : .on
        orderShuffleItem.state = shuffle ? .on : .off
        bedtimeOnItem.state = bedtimeEnabled ? .on : .off
        for (h, item) in bedtimeHourItems { item.state = (h == bedtimeHour) ? .on : .off }
        for (s, item) in bedtimeRepeatItems { item.state = (s == Int(bedtimeRepeat)) ? .on : .off }
    }

    // MARK: Actions

    @objc private func stretchNow() { showBreak() }
    @objc private func stopCurrent() { hideBreak() }
    @objc private func snoozeCurrent() { snoozeAny() }

    @objc private func toggleBedtime() { bedtimeEnabled.toggle(); refreshStates(); checkBedtime() }

    @objc private func setBedtimeHour(_ sender: NSMenuItem) {
        guard let h = sender.representedObject as? Int else { return }
        bedtimeHour = h; refreshStates(); checkBedtime()
    }

    @objc private func setBedtimeRepeat(_ sender: NSMenuItem) {
        guard let secs = sender.representedObject as? Double else { return }
        bedtimeRepeat = secs; refreshStates()
    }

    @objc private func previewBedtime() { showBedtime() }

    /// Stop and Snooze are only enabled while a break is on screen.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(stopCurrent) || menuItem.action == #selector(snoozeCurrent) {
            return breakShowing
        }
        return true
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let secs = sender.representedObject as? TimeInterval else { return }
        reminderSeconds = secs; refreshStates(); scheduleReminder()
    }

    @objc private func setDuration(_ sender: NSMenuItem) {
        guard let secs = sender.representedObject as? TimeInterval else { return }
        showSeconds = secs; refreshStates()
    }

    @objc private func setOrderInOrder() { shuffle = false; refreshStates() }
    @objc private func setOrderShuffle() { shuffle = true; refreshStates() }

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let raw = sender.restedSize else { return }
        buddySize = raw
        refreshStates()
        if let panel = panel {
            panel.setContentSize(raw.size)
            if panel.isVisible { panel.setFrame(restingFrame(), display: true) }
        }
    }
}

private extension NSMenuItem {
    var restedSize: BuddySize? { (representedObject as? String).flatMap(BuddySize.init(rawValue:)) }
}

// MARK: - Entry point

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
