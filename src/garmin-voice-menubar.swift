// garmin-voice-menubar.swift — menu-bar control + settings for the importer.
// Everything is adjusted here; all state lives in the config the `garmin-voice`
// script reads/writes (path from env GVE_CTL). No Terminal needed for daily use.
//
// Build:  swiftc -O garmin-voice-menubar.swift -o garmin-voice-menubar

import Cocoa

let CTL = ProcessInfo.processInfo.environment["GVE_CTL"] ?? "garmin-voice"

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

func statusField(_ s: String, _ key: String) -> String {
    for line in s.split(separator: "\n") where line.contains(key) {
        if let r = line.range(of: ":") { return line[r.upperBound...].trimmingCharacters(in: .whitespaces) }
    }
    return ""
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    var dest = ""

    func applicationDidFinishLaunching(_ n: Notification) {
        item.button?.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Garmin Voice Memos")
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ m: NSMenu) {
        let s = ctl(["status"])
        let paused  = statusField(s, "auto-import").contains("PAUSED")
        let deleting = statusField(s, "delete-from-watch").hasPrefix("on")
        let transOn = statusField(s, "transcription").hasPrefix("on")
        dest = statusField(s, "destination")

        m.removeAllItems()
        m.addItem(disabled("Garmin Voice Memos"))
        m.addItem(disabled("  " + (paused ? "Paused" : "Active") + (dest.isEmpty ? "" : " · " + (dest as NSString).lastPathComponent)))
        m.addItem(.separator())
        m.addItem(action("Sync now", #selector(syncNow)))
        m.addItem(action("Open folder", #selector(openFolder)))
        m.addItem(.separator())
        m.addItem(check("Delete from watch after import", deleting, #selector(toggleDelete)))
        m.addItem(action("Change destination…", #selector(changeDest)))
        m.addItem(check("Transcribe memos", transOn, #selector(setupTranscription)))
        m.addItem(.separator())
        m.addItem(action(paused ? "Resume auto-import" : "Pause (free watch for other apps)",
                         paused ? #selector(resume) : #selector(pause)))
        m.addItem(action("Quit", #selector(quit)))
    }

    func disabled(_ t: String) -> NSMenuItem { let i = NSMenuItem(title: t, action: nil, keyEquivalent: ""); i.isEnabled = false; return i }
    func action(_ t: String, _ sel: Selector) -> NSMenuItem { let i = NSMenuItem(title: t, action: sel, keyEquivalent: ""); i.target = self; return i }
    func check(_ t: String, _ on: Bool, _ sel: Selector) -> NSMenuItem { let i = action(t, sel); i.state = on ? .on : .off; return i }

    @objc func syncNow()  { DispatchQueue.global().async { ctl(["sync"]) } }
    @objc func openFolder(){ if !dest.isEmpty { NSWorkspace.shared.open(URL(fileURLWithPath: dest)) } }
    @objc func pause()    { ctl(["pause"]) }
    @objc func resume()   { ctl(["resume"]) }
    @objc func quit()     { NSApp.terminate(nil) }

    @objc func toggleDelete() {
        let on = statusField(ctl(["status"]), "delete-from-watch").hasPrefix("on")
        if on { ctl(["unset", "GARMIN_VOICE_DELETE"]) } else { ctl(["set", "GARMIN_VOICE_DELETE", "--delete"]) }
    }

    @objc func changeDest() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = "Use this folder"; panel.message = "Where should voice memos be saved?"
        if panel.runModal() == .OK, let url = panel.url { ctl(["set", "GARMIN_VOICE_DEST", url.path]) }
    }

    @objc func setupTranscription() {
        let dir = (CTL as NSString).deletingLastPathComponent
        let script = "\(dir)/install-transcription.sh"
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "tell application \"Terminal\" to do script \"bash '\(script)'\"", "-e", "tell application \"Terminal\" to activate"]
        try? p.run()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
