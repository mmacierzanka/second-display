import AppKit
import AVFoundation

// Launch-on-connect: a per-user LaunchAgent that opens the app when the chosen USB device is attached.
extension App {
    static let agentLabel = "com.mmacierzanka.second-display.autostart"
    var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(Self.agentLabel).plist")
    }
    var autostartID: String? { defaults.string(forKey: "autostart") }

    // UVC cameras report e.g. "UVC Camera VendorID_21325 ProductID_8457" (decimal); other devices have no USB ids.
    func usbIDs(_ d: AVCaptureDevice) -> (vendor: Int, product: Int)? {
        func number(after key: String) -> Int? {
            guard let r = d.modelID.range(of: key) else { return nil }
            return Int(d.modelID[r.upperBound...].prefix(while: \.isNumber))
        }
        guard let v = number(after: "VendorID_"), let p = number(after: "ProductID_") else { return nil }
        return (v, p)
    }

    func launchctl(_ args: String...) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardError = FileHandle.nullDevice
        try? p.run(); p.waitUntilExit()
    }

    func setAutostart(_ d: AVCaptureDevice?) {
        let domain = "gui/\(getuid())"
        launchctl("bootout", "\(domain)/\(Self.agentLabel)")
        guard let d = d, let ids = usbIDs(d) else {
            try? FileManager.default.removeItem(at: agentURL)
            defaults.removeObject(forKey: "autostart"); defaults.removeObject(forKey: "autostartName")
            return
        }
        let plist: [String: Any] = [
            "Label": Self.agentLabel,
            "ProgramArguments": [Bundle.main.executablePath ?? ""],  // the job itself must be the app so it can acknowledge the event
            "LimitLoadToSessionType": "Aqua",
            "LaunchEvents": ["com.apple.iokit.matching": ["attach": [
                "IOProviderClass": "IOUSBHostDevice", "idVendor": ids.vendor, "idProduct": ids.product, "IOMatchLaunchStream": true]]],
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
        try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: agentURL)
        defaults.set(d.uniqueID, forKey: "autostart"); defaults.set(d.localizedName, forKey: "autostartName")
        launchctl("bootstrap", domain, agentURL.path)  // fires at once if the device is already attached
    }

    @objc func pickAutostart(_ s: NSMenuItem) { setAutostart(s.representedObject as? AVCaptureDevice) }

    func fillAutostartMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let off = NSMenuItem(title: NSLocalizedString("Off", comment: ""), action: #selector(pickAutostart(_:)), keyEquivalent: "")
        off.target = self; off.state = autostartID == nil ? .on : .off
        menu.addItem(off)
        menu.addItem(.separator())
        let devices = videoDevices()
        for d in devices {
            let it = NSMenuItem(title: d.localizedName, action: usbIDs(d) == nil ? nil : #selector(pickAutostart(_:)), keyEquivalent: "")
            it.target = self; it.representedObject = d
            it.state = d.uniqueID == autostartID ? .on : .off
            menu.addItem(it)
        }
        if let id = autostartID, !devices.contains(where: { $0.uniqueID == id }) {
            let it = NSMenuItem(title: "\(defaults.string(forKey: "autostartName") ?? id) \(NSLocalizedString("(not connected)", comment: ""))", action: nil, keyEquivalent: "")
            it.state = .on
            menu.addItem(it)
        }
    }
}
