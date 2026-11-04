import AppKit
import AVFoundation

extension App: NSMenuDelegate {
    func buildMainMenu() {
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: NSLocalizedString("About Second Display", comment: ""), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: NSLocalizedString("Quit Second Display", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for (title, sub) in [("", appMenu), (NSLocalizedString("Video", comment: ""), videoMenu), (NSLocalizedString("Audio", comment: ""), audioMenu), (NSLocalizedString("Autostart", comment: ""), autostartMenu), (NSLocalizedString("Options", comment: ""), optionsMenu), (NSLocalizedString("Window", comment: ""), windowMenu)] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            sub.title = title; sub.delegate = self; item.submenu = sub
            main.addItem(item)
        }
        func L(_ k: String) -> String { NSLocalizedString(k, comment: "") }
        windowMenu.addItem(NSMenuItem(title: L("Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: L("Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        let fs = NSMenuItem(title: L("Enter Full Screen"), action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fs.keyEquivalentModifierMask = [.command, .control]
        windowMenu.addItem(fs)
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: L("Bring All to Front"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        NSApp.windowsMenu = windowMenu  // AppKit adds the system tiling ("Move & Resize") items
        NSApp.mainMenu = main
    }

    // MARK: menu
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === videoMenu {
            menu.removeAllItems()
            for d in videoDevices() {
                let it = NSMenuItem(title: d.localizedName, action: #selector(pickVideo(_:)), keyEquivalent: "")
                it.target = self; it.representedObject = d
                it.state = d.uniqueID == videoInput?.device.uniqueID ? .on : .off
                menu.addItem(it)
            }
            if menu.items.isEmpty { menu.addItem(header(NSLocalizedString("No devices", comment: ""))) }
            if let d = videoInput?.device {
                menu.addItem(.separator())
                menu.addItem(header(NSLocalizedString("Format", comment: "")))
                var seen = Set<String>()
                for f in d.formats.sorted(by: { (dims($0).width, fps($0)) > (dims($1).width, fps($1)) }) where seen.insert(label(f)).inserted {
                    let it = NSMenuItem(title: label(f), action: #selector(pickFormat(_:)), keyEquivalent: "")
                    it.target = self; it.state = f == d.activeFormat ? .on : .off
                    menu.addItem(it)
                }
            }
        } else if menu === audioMenu {
            menu.removeAllItems()
            let pick = micBlocked ? nil : #selector(pickAudio(_:))  // no action = greyed out
            if micBlocked {
                menu.addItem(header(NSLocalizedString("Microphone access denied. Enable it in System Settings.", comment: "")))
                menu.addItem(.separator())
            }
            let off = NSMenuItem(title: NSLocalizedString("Off", comment: ""), action: pick, keyEquivalent: "")
            off.target = self; off.state = audioInput == nil ? .on : .off
            menu.addItem(off)
            menu.addItem(.separator())
            for d in audioDevices() {
                let it = NSMenuItem(title: d.localizedName, action: pick, keyEquivalent: "")
                it.target = self; it.representedObject = d
                it.state = d.uniqueID == audioInput?.device.uniqueID ? .on : .off
                menu.addItem(it)
            }
        } else if menu === autostartMenu {
            fillAutostartMenu(menu)
        } else if menu === optionsMenu {
            menu.removeAllItems()
            let k = NSMenuItem(title: NSLocalizedString("Prevent display sleep", comment: ""), action: #selector(toggleAwake), keyEquivalent: "")
            k.target = self; k.state = keepAwake ? .on : .off
            let f = NSMenuItem(title: NSLocalizedString("Start in full screen", comment: ""), action: #selector(toggleFull), keyEquivalent: "")
            f.target = self; f.state = startFull ? .on : .off
            let t = NSMenuItem(title: NSLocalizedString("Always on top", comment: ""), action: #selector(toggleTop), keyEquivalent: "")
            t.target = self; t.state = onTop ? .on : .off
            let m = NSMenuItem(title: NSLocalizedString("Mute", comment: ""), action: #selector(toggleMute), keyEquivalent: "M")
            m.target = self; m.state = muted ? .on : .off
            menu.addItem(k); menu.addItem(f); menu.addItem(t); menu.addItem(m)
            menu.addItem(.separator())
            menu.addItem(header(NSLocalizedString("Scaling", comment: "")))
            for (key, name) in [("fit", "Fit"), ("fill", "Fill"), ("stretch", "Stretch")] {
                let it = NSMenuItem(title: NSLocalizedString(name, comment: ""), action: #selector(pickGravity(_:)), keyEquivalent: "")
                it.target = self; it.representedObject = key; it.state = (defaults.string(forKey: "gravity") ?? "fit") == key ? .on : .off
                menu.addItem(it)
            }
        }
    }
    func header(_ s: String) -> NSMenuItem { let i = NSMenuItem(title: s, action: nil, keyEquivalent: ""); i.isEnabled = false; return i }
    @objc func pickVideo(_ s: NSMenuItem) { setVideo(s.representedObject as? AVCaptureDevice) }
    @objc func pickAudio(_ s: NSMenuItem) { setAudio(s.representedObject as? AVCaptureDevice) }
    @objc func toggleFull() { defaults.set(!startFull, forKey: "startFull") }
    @objc func pickFormat(_ s: NSMenuItem) {
        guard let d = videoInput?.device else { return }
        defaults.set(s.title, forKey: "format.\(d.uniqueID)"); applyFormat(d)
    }
    @objc func toggleTop() { defaults.set(!onTop, forKey: "onTop"); window.level = onTop ? .floating : .normal }
    @objc func toggleMute() { muted.toggle(); preview.volume = muted ? 0 : 1 }
    @objc func pickGravity(_ s: NSMenuItem) { defaults.set(s.representedObject as? String, forKey: "gravity"); layer.videoGravity = gravity }
    @objc func toggleAwake() { setKeepAwake(!keepAwake) }
}
