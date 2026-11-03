import AppKit
import AVFoundation
import IOKit.pwr_mgt

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let session = AVCaptureSession()
    let preview = AVCaptureAudioPreviewOutput()
    var videoInput: AVCaptureDeviceInput?
    var audioInput: AVCaptureDeviceInput?
    var window: NSWindow!
    let videoMenu = NSMenu(), audioMenu = NSMenu(), optionsMenu = NSMenu()
    var sleepAssertion: IOPMAssertionID = 0
    var keepAwake = false
    var layer: AVCaptureVideoPreviewLayer!
    var muted = false
    let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ n: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Second Display"
        window.contentView!.wantsLayer = true
        layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = gravity
        window.level = onTop ? .floating : .normal
        layer.frame = window.contentView!.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        window.contentView!.layer!.addSublayer(layer)
        window.contentView!.layer!.backgroundColor = NSColor.black.cgColor
        window.center()
        window.makeKeyAndOrderFront(nil)
        if startFull { window.toggleFullScreen(nil) }

        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: NSLocalizedString("Quit Second Display", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for (title, sub) in [("", appMenu), (NSLocalizedString("Video", comment: ""), videoMenu), (NSLocalizedString("Audio", comment: ""), audioMenu), (NSLocalizedString("Options", comment: ""), optionsMenu)] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            sub.title = title; sub.delegate = self; item.submenu = sub
            main.addItem(item)
        }
        NSApp.mainMenu = main

        keepAwake = defaults.object(forKey: "keepAwake") as? Bool ?? true
        setKeepAwake(keepAwake)

        preview.volume = 1
        session.beginConfiguration()
        if session.canAddOutput(preview) { session.addOutput(preview) }
        session.commitConfiguration()

        AVCaptureDevice.requestAccess(for: .video) { _ in
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { self.restore() }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ a: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ n: Notification) { setKeepAwake(false) }

    // MARK: devices
    func videoDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                         mediaType: .video, position: .unspecified).devices
    }
    func audioDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external],
                                         mediaType: .audio, position: .unspecified).devices
    }

    func restore() {
        if let id = defaults.string(forKey: "video"), let d = videoDevices().first(where: { $0.uniqueID == id }) {
            setVideo(d)
        } else if let d = videoDevices().first { setVideo(d) }
        if let id = defaults.string(forKey: "audio"), let d = audioDevices().first(where: { $0.uniqueID == id }) {
            setAudio(d)
        }  // default: audio off until chosen
        session.startRunning()
    }

    func swap(_ old: inout AVCaptureDeviceInput?, to device: AVCaptureDevice?) {
        session.beginConfiguration()
        if let o = old { session.removeInput(o); old = nil }
        if let d = device, let i = try? AVCaptureDeviceInput(device: d), session.canAddInput(i) {
            session.addInput(i); old = i
        }
        session.commitConfiguration()
    }

    func setVideo(_ d: AVCaptureDevice?) {
        swap(&videoInput, to: d)
        defaults.set(d?.uniqueID, forKey: "video")
        if let d = d { applyFormat(d) }
    }

    // MARK: formats
    func dims(_ f: AVCaptureDevice.Format) -> CMVideoDimensions { CMVideoFormatDescriptionGetDimensions(f.formatDescription) }
    func fps(_ f: AVCaptureDevice.Format) -> Int { Int((f.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0).rounded()) }
    func label(_ f: AVCaptureDevice.Format) -> String { "\(dims(f).width)x\(dims(f).height) @ \(fps(f)) fps" }

    func applyFormat(_ d: AVCaptureDevice) {
        guard let l = defaults.string(forKey: "format.\(d.uniqueID)"),
              let f = d.formats.first(where: { label($0) == l }), (try? d.lockForConfiguration()) != nil else { return }
        d.activeFormat = f
        d.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps(f)))
        d.activeVideoMaxFrameDuration = d.activeVideoMinFrameDuration
        d.unlockForConfiguration()
    }
    func setAudio(_ d: AVCaptureDevice?) {
        swap(&audioInput, to: d)
        // Preview output plays to default system output; null = follow default
        preview.outputDeviceUniqueID = nil
        defaults.set(d?.uniqueID, forKey: "audio")
    }

    // MARK: sleep
    func setKeepAwake(_ on: Bool) {
        if on && sleepAssertion == 0 {
            IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), "Second Display active" as CFString, &sleepAssertion)
        } else if !on && sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion); sleepAssertion = 0
        }
        keepAwake = on
        defaults.set(on, forKey: "keepAwake")
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
            let off = NSMenuItem(title: NSLocalizedString("Off", comment: ""), action: #selector(pickAudio(_:)), keyEquivalent: "")
            off.target = self; off.state = audioInput == nil ? .on : .off
            menu.addItem(off)
            menu.addItem(.separator())
            for d in audioDevices() {
                let it = NSMenuItem(title: d.localizedName, action: #selector(pickAudio(_:)), keyEquivalent: "")
                it.target = self; it.representedObject = d
                it.state = d.uniqueID == audioInput?.device.uniqueID ? .on : .off
                menu.addItem(it)
            }
        } else if menu === optionsMenu {
            menu.removeAllItems()
            let k = NSMenuItem(title: NSLocalizedString("Prevent display sleep", comment: ""), action: #selector(toggleAwake), keyEquivalent: "")
            k.target = self; k.state = keepAwake ? .on : .off
            let f = NSMenuItem(title: NSLocalizedString("Start in full screen", comment: ""), action: #selector(toggleFull), keyEquivalent: "")
            f.target = self; f.state = startFull ? .on : .off
            let t = NSMenuItem(title: NSLocalizedString("Always on top", comment: ""), action: #selector(toggleTop), keyEquivalent: "")
            t.target = self; t.state = onTop ? .on : .off
            let m = NSMenuItem(title: NSLocalizedString("Mute", comment: ""), action: #selector(toggleMute), keyEquivalent: "m")
            m.target = self; m.state = muted ? .on : .off
            let fs = NSMenuItem(title: NSLocalizedString("Toggle full screen", comment: ""), action: #selector(fullScreen), keyEquivalent: "f")
            fs.target = self
            menu.addItem(k); menu.addItem(f); menu.addItem(t); menu.addItem(m); menu.addItem(fs)
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
    var startFull: Bool { defaults.object(forKey: "startFull") as? Bool ?? true }
    @objc func toggleFull() { defaults.set(!startFull, forKey: "startFull") }
    var onTop: Bool { defaults.bool(forKey: "onTop") }
    var gravity: AVLayerVideoGravity {
        switch defaults.string(forKey: "gravity") { case "fill": return .resizeAspectFill; case "stretch": return .resize; default: return .resizeAspect }
    }
    @objc func pickFormat(_ s: NSMenuItem) {
        guard let d = videoInput?.device else { return }
        defaults.set(s.title, forKey: "format.\(d.uniqueID)"); applyFormat(d)
    }
    @objc func toggleTop() { defaults.set(!onTop, forKey: "onTop"); window.level = onTop ? .floating : .normal }
    @objc func toggleMute() { muted.toggle(); preview.volume = muted ? 0 : 1 }
    @objc func fullScreen() { window.toggleFullScreen(nil) }
    @objc func pickGravity(_ s: NSMenuItem) { defaults.set(s.representedObject as? String, forKey: "gravity"); layer.videoGravity = gravity }
    @objc func toggleAwake() { setKeepAwake(!keepAwake) }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
