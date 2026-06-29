import Cocoa
import ServiceManagement

// MARK: - Shortcut storage

struct Shortcut {
    var key: String                       // e.g. "f"
    var mods: NSEvent.ModifierFlags       // e.g. [.command]

    var display: String {
        if key.isEmpty { return "None" }
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        return s + key.uppercased()
    }
}

enum Action: String, CaseIterable {
    case flush, cloudflare, reset
    var label: String {
        switch self {
        case .flush:      return "Flush DNS Cache"
        case .cloudflare: return "Set DNS → Cloudflare"
        case .reset:      return "Reset DNS → Automatic"
        }
    }
    var defaultShortcut: Shortcut {
        switch self {
        case .flush:      return Shortcut(key: "f", mods: [.command])
        case .cloudflare: return Shortcut(key: "c", mods: [.command])
        case .reset:      return Shortcut(key: "r", mods: [.command])
        }
    }
}

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    func shortcut(for a: Action) -> Shortcut {
        guard let key = d.string(forKey: "\(a.rawValue).key") else { return a.defaultShortcut }
        let raw = UInt(d.integer(forKey: "\(a.rawValue).mods"))
        return Shortcut(key: key, mods: NSEvent.ModifierFlags(rawValue: raw))
    }
    func set(_ s: Shortcut, for a: Action) {
        d.set(s.key, forKey: "\(a.rawValue).key")
        d.set(Int(s.mods.rawValue), forKey: "\(a.rawValue).mods")
    }
}

// MARK: - Shortcut recorder control

final class ShortcutRecorder: NSButton {
    var onChange: ((Shortcut) -> Void)?
    private var recording = false
    private var current: Shortcut

    init(_ shortcut: Shortcut) {
        current = shortcut
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(begin)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func begin() {
        recording = true
        title = "Type shortcut…"
        window?.makeFirstResponder(self)
    }
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let key = (event.charactersIgnoringModifiers ?? "").lowercased()
        guard !key.isEmpty else { return }
        current = Shortcut(key: key, mods: mods)
        recording = false
        refresh()
        onChange?(current)
    }
    private func refresh() { title = current.display }
}

// MARK: - Settings window

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 180),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "DNS Tool — Shortcuts"
        w.center()
        self.init(window: w)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        for a in Action.allCases {
            let row = NSStackView()
            row.orientation = .horizontal
            row.distribution = .fill
            let label = NSTextField(labelWithString: a.label)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let recorder = ShortcutRecorder(Settings.shared.shortcut(for: a))
            recorder.onChange = { Settings.shared.set($0, for: a); NotificationCenter.default.post(name: .shortcutsChanged, object: nil) }
            recorder.widthAnchor.constraint(equalToConstant: 110).isActive = true
            row.addArrangedSubview(label)
            row.addArrangedSubview(recorder)
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        }

        let hint = NSTextField(wrappingLabelWithString: "Click a shortcut, then press the key combo you want.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hint)

        w.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            stack.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
        ])
    }
}

extension Notification.Name { static let shortcutsChanged = Notification.Name("shortcutsChanged") }

// MARK: - App

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var statusLine: NSMenuItem!
    var loginItem: NSMenuItem!
    var settingsWC: SettingsWindowController?
    var actionItems: [Action: NSMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "network", accessibilityDescription: "DNS") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "DNS"
            }
        }

        let menu = NSMenu()
        menu.delegate = self

        statusLine = NSMenuItem(title: "Current DNS: …", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(NSMenuItem.separator())

        let flush = makeItem(.flush, #selector(flushDNS))
        menu.addItem(flush)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem(.cloudflare, #selector(setCloudflare)))
        menu.addItem(makeItem(.reset, #selector(resetDNS)))
        menu.addItem(NSMenuItem.separator())

        loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu

        NotificationCenter.default.addObserver(self, selector: #selector(applyShortcuts),
                                               name: .shortcutsChanged, object: nil)
    }

    private func makeItem(_ a: Action, _ sel: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: a.label, action: sel, keyEquivalent: "")
        item.target = self
        actionItems[a] = item
        applyShortcut(a, to: item)
        return item
    }
    private func applyShortcut(_ a: Action, to item: NSMenuItem) {
        let s = Settings.shared.shortcut(for: a)
        item.keyEquivalent = s.key
        item.keyEquivalentModifierMask = s.mods
    }
    @objc private func applyShortcuts() {
        for (a, item) in actionItems { applyShortcut(a, to: item) }
    }

    // Refresh dynamic items every time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        let out = shell("/usr/sbin/networksetup", ["-getdnsservers", "Wi-Fi"])
        let servers = out.contains("aren't") || out.isEmpty
            ? "Automatic (DHCP)"
            : out.split(separator: "\n").joined(separator: ", ")
        statusLine.title = "Current DNS: \(servers)"
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc func toggleLoginItem() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled {
                try svc.unregister()
            } else {
                try svc.register()
            }
        } catch {
            notify("Failed", "Couldn't change Launch at Login:\n\(error.localizedDescription)")
        }
        loginItem.state = (svc.status == .enabled) ? .on : .off
    }

    @discardableResult
    private func shell(_ launchPath: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runAsAdmin(_ command: String, successMessage: String) {
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: appleScript)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                if let error = error {
                    let code = (error["NSAppleScriptErrorNumber"] as? Int) ?? 0
                    if code != -128 {
                        self.notify("Failed", error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error")
                    }
                } else {
                    self.notify("Done", successMessage)
                }
            }
        }
    }

    @objc func flushDNS() {
        runAsAdmin("dscacheutil -flushcache; killall -HUP mDNSResponder", successMessage: "DNS cache flushed.")
    }
    @objc func setCloudflare() {
        runAsAdmin("networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1; dscacheutil -flushcache; killall -HUP mDNSResponder",
                   successMessage: "DNS set to Cloudflare (1.1.1.1).")
    }
    @objc func resetDNS() {
        runAsAdmin("networksetup -setdnsservers Wi-Fi Empty; dscacheutil -flushcache; killall -HUP mDNSResponder",
                   successMessage: "DNS reset to automatic (DHCP).")
    }

    @objc func openSettings() {
        if settingsWC == nil { settingsWC = SettingsWindowController() }
        NSApp.activate(ignoringOtherApps: true)
        settingsWC?.showWindow(nil)
        settingsWC?.window?.makeKeyAndOrderFront(nil)
    }

    private func notify(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = (title == "Failed") ? .warning : .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quit() { NSApplication.shared.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
