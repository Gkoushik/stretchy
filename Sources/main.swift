import SwiftUI
import AppKit
import WebKit

// MARK: - Mochi move catalogue (loaded from moves.json)

struct Move: Codable {
    let key: String
    let label: String
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
            NSLog("moves.json missing or invalid — using built-in defaults")
            groups = fallback
        }
        all = groups.flatMap { $0.moves }
    }

    private static let fallback: [MoveGroup] = [
        MoveGroup(name: "Eyes", moves: [
            Move(key: "ecirc", label: "Eye circles"),
            Move(key: "eud",   label: "Look up and down"),
            Move(key: "elr",   label: "Look side to side"),
        ]),
        MoveGroup(name: "Neck", moves: [
            Move(key: "turn", label: "Head turn"),
            Move(key: "tilt", label: "Ear to shoulder"),
            Move(key: "roll", label: "Neck roll"),
        ]),
        MoveGroup(name: "Shoulders", moves: [
            Move(key: "shrug",   label: "Shrug"),
            Move(key: "circles", label: "Shoulder rolls"),
            Move(key: "cross",   label: "Cross-body pull"),
        ]),
        MoveGroup(name: "Full body", moves: [
            Move(key: "reach", label: "Reach up"),
            Move(key: "side",  label: "Side bend"),
            Move(key: "yawn",  label: "Big yawn"),
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
    func label(_ k: String) -> String { MochiMoves.all.first { $0.key == k }?.label ?? k }

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
    var width: CGFloat {
        switch self {
        case .small:  return 104
        case .medium: return 150
        case .large:  return 210
        }
    }
    var size: NSSize { NSSize(width: width, height: (width * 290 / 216).rounded()) }
}

// MARK: - Transparent click-through overlay panel

final class OverlayPanel: NSPanel {
    init(contentView: NSView, size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false   // allow clicking the Stop button
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.contentView = contentView
    }
    override var canBecomeKey: Bool { true }
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

// MARK: - App delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var panel: OverlayPanel?
    private var webView: WKWebView!
    private var webReady = false
    private var closeButton: NSButton?
    private var routineWindow: NSWindow?

    private let margin: CGFloat = 16
    private var buddySize: BuddySize = .small

    private let store = RoutineStore()

    // Schedule
    private var enabled = true
    private var reminderSeconds: TimeInterval = 60 * 60
    private var showSeconds: TimeInterval = 30
    private var shuffle = false
    private var reminderTimer: Timer?
    private var hideTimer: Timer?

    private var currentKey = "roll"
    private var guides = false

    // Menu refs
    private var nextItem: NSMenuItem!
    private var nextFireDate: Date?
    private var menuTimer: Timer?
    private var sizeItems: [BuddySize: NSMenuItem] = [:]
    private var intervalItems: [Int: NSMenuItem] = [:]
    private var durationItems: [Int: NSMenuItem] = [:]
    private var orderInOrderItem: NSMenuItem!
    private var orderShuffleItem: NSMenuItem!

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
        if let img = Self.menuBarImage() {
            statusItem.button?.image = img
            statusItem.button?.imagePosition = .imageOnly
        } else {
            statusItem.button?.title = "🧘"
        }
        statusItem.button?.toolTip = "Stretchy — movement breaks"

        MochiMoves.load()
        store.load()
        currentKey = store.order.first ?? "roll"

        buildMenu()
        preparePanel()
        scheduleReminder()
    }

    // MARK: Web view

    private func preparePanel() {
        let s = buddySize.size
        let container = NSView(frame: NSRect(origin: .zero, size: s))
        container.wantsLayer = true

        let web = WKWebView(frame: NSRect(origin: .zero, size: s),
                            configuration: WKWebViewConfiguration())
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
        web.wantsLayer = true
        web.layer?.backgroundColor = NSColor.clear.cgColor
        web.autoresizingMask = [.width, .height]
        self.webView = web
        container.addSubview(web)

        // Stop (×) button, pinned top-right, stays there as size changes.
        let btn = NSButton(frame: closeButtonFrame(for: s))
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.title = ""
        btn.imagePosition = .imageOnly
        if let x = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Stop") {
            let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            btn.image = x.withSymbolConfiguration(cfg)
            btn.contentTintColor = NSColor(calibratedWhite: 0.25, alpha: 0.85)
        } else {
            btn.title = "×"
        }
        btn.target = self
        btn.action = #selector(stopCurrent)
        btn.toolTip = "Stop this exercise"
        btn.autoresizingMask = [.minXMargin, .minYMargin]  // keep top-right
        self.closeButton = btn
        container.addSubview(btn)

        guard let url = Bundle.main.url(forResource: "player", withExtension: "html") else {
            NSLog("player.html missing from bundle"); return
        }
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

        let panel = OverlayPanel(contentView: container, size: s)
        self.panel = panel
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            panel.setFrame(NSRect(x: vf.maxX + 4, y: vf.maxY - s.height - margin,
                                  width: s.width, height: s.height), display: false)
        }
    }

    private func closeButtonFrame(for s: NSSize) -> NSRect {
        let d: CGFloat = 22
        return NSRect(x: s.width - d - 2, y: s.height - d - 2, width: d, height: d)
    }

    /// Small Mochi face for the menu bar (bundled menubar.png), sized for the status bar.
    private static func menuBarImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "menubar", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = false
        return img
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webReady = true
        applyMove()
    }

    private func applyMove() {
        guard webReady else { return }
        webView.evaluateJavaScript("setMove('\(currentKey)', \(guides ? "true" : "false"))",
                                   completionHandler: nil)
    }

    // MARK: Scheduling

    private func scheduleReminder() {
        reminderTimer?.invalidate(); reminderTimer = nil
        guard enabled else { nextFireDate = nil; updateNextItem(); return }
        nextFireDate = Date().addingTimeInterval(reminderSeconds)
        reminderTimer = Timer.scheduledTimer(withTimeInterval: reminderSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.nextFireDate = Date().addingTimeInterval(self.reminderSeconds)
                self.showBreak()
            }
        }
        updateNextItem()
    }

    // MARK: Countdown display (menu)

    func menuWillOpen(_ menu: NSMenu) {
        updateNextItem()
        menuTimer?.invalidate()
        menuTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateNextItem() }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        menuTimer?.invalidate(); menuTimer = nil
    }

    private func updateNextItem() {
        guard let nextItem = nextItem else { return }
        if !enabled {
            nextItem.title = "Reminders paused"
        } else if let panel = panel, panel.isVisible {
            nextItem.title = "Exercise showing now"
        } else if let d = nextFireDate {
            let remaining = max(0, Int(d.timeIntervalSinceNow.rounded()))
            let m = remaining / 60, s = remaining % 60
            nextItem.title = String(format: "Next exercise in %d:%02d", m, s)
        } else {
            nextItem.title = "Next exercise in —"
        }
    }

    private func nextExercise() {
        let keys = store.order
        guard !keys.isEmpty else { return }
        if shuffle {
            currentKey = keys.filter { $0 != currentKey }.randomElement() ?? keys[0]
        } else if let i = keys.firstIndex(of: currentKey) {
            currentKey = keys[(i + 1) % keys.count]
        } else {
            currentKey = keys[0]
        }
    }

    private func showBreak() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        nextExercise()
        applyMove()

        let s = buddySize.size
        let vf = screen.visibleFrame
        let y = vf.maxY - s.height - margin
        let onX = vf.maxX - s.width - margin
        let offX = vf.maxX + 4

        panel.setFrame(NSRect(x: offX, y: y, width: s.width, height: s.height), display: false)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(NSRect(x: onX, y: y, width: s.width, height: s.height), display: true)
        }

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: showSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.hideBreak() }
        }
    }

    private func hideBreak() {
        hideTimer?.invalidate(); hideTimer = nil
        guard let panel = panel, panel.isVisible, let screen = NSScreen.main else { return }
        let f = panel.frame
        let vf = screen.visibleFrame
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(NSRect(x: vf.maxX + 4, y: f.origin.y, width: f.width, height: f.height), display: true)
        }, completionHandler: {
            panel.orderOut(nil)
        })
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
    }

    // MARK: Actions

    @objc private func stretchNow() { showBreak() }

    @objc private func stopCurrent() { hideBreak() }

    /// Enable "Stop current exercise" only while the character is on screen.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(stopCurrent) {
            return panel?.isVisible ?? false
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
        guard let raw = sender.representedObject as? String, let sz = BuddySize(rawValue: raw) else { return }
        buddySize = sz
        refreshStates()
        if let panel = panel, panel.isVisible, let screen = NSScreen.main {
            let s = sz.size
            let vf = screen.visibleFrame
            panel.setFrame(NSRect(x: vf.maxX - s.width - margin, y: vf.maxY - s.height - margin,
                                  width: s.width, height: s.height), display: true)
        }
    }

    @objc private func toggleGuides() { guides.toggle(); refreshStates(); applyMove() }
}

// MARK: - Entry point

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
