// garmin-voice-menubar.swift — a lightweight macOS menu-bar control for the importer.
// Shows status and offers Sync now / Open folder / Pause-Resume / Quit. All actions
// shell out to the `garmin-voice` control script (path from env GVE_CTL).
//
// Build:  swiftc -O garmin-voice-menubar.swift -o garmin-voice-menubar
// Run as a LoginItem/LaunchAgent with GVE_CTL and GVE_DEST set (see install-menubar.sh).

import Cocoa

let CTL  = ProcessInfo.processInfo.environment["GVE_CTL"]  ?? "garmin-voice"
let DEST = ProcessInfo.processInfo.environment["GVE_DEST"] ?? "\(NSHomeDirectory())/Documents/Voice Memos"

@discardableResult
func ctl(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = [CTL] + args
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
    do { try p.run() } catch { return "" }
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()

    func applicationDidFinishLaunching(_ n: Notification) {
        if let b = item.button {
            b.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Garmin Voice Memos")
        }
        menu.delegate = self
        item.menu = menu
    }

    // rebuild each time it opens so status is live
    func menuNeedsUpdate(_ m: NSMenu) {
        m.removeAllItems()
        let status = ctl(["status"])
        let paused = status.contains("PAUSED")
        m.addItem(header("Garmin Voice Memos"))
        m.addItem(info(paused ? "Auto-import: paused" : "Auto-import: active"))
        for line in ["destination", "delete-from-watch", "transcription"] {
            if let l = status.split(separator: "\n").first(where: { $0.contains(line) }) {
                m.addItem(info(l.trimmingCharacters(in: .whitespaces)))
            }
        }
        m.addItem(.separator())
        m.addItem(action("Sync now", #selector(syncNow)))
        m.addItem(action("Open Voice Memos folder", #selector(openFolder)))
        m.addItem(action(paused ? "Resume auto-import" : "Pause (free watch for other apps)",
                         paused ? #selector(resume) : #selector(pause)))
        m.addItem(.separator())
        m.addItem(action("Quit", #selector(quit)))
    }

    func header(_ s: String) -> NSMenuItem { let i = NSMenuItem(title: s, action: nil, keyEquivalent: ""); i.isEnabled = false; return i }
    func info(_ s: String) -> NSMenuItem { let i = NSMenuItem(title: "  \(s)", action: nil, keyEquivalent: ""); i.isEnabled = false; return i }
    func action(_ s: String, _ sel: Selector) -> NSMenuItem { let i = NSMenuItem(title: s, action: sel, keyEquivalent: ""); i.target = self; return i }

    @objc func syncNow()    { DispatchQueue.global().async { ctl(["sync"]) } }
    @objc func openFolder() { NSWorkspace.shared.open(URL(fileURLWithPath: DEST)) }
    @objc func pause()      { ctl(["pause"]) }
    @objc func resume()     { ctl(["resume"]) }
    @objc func quit()       { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
