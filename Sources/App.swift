import AppKit
import AVFoundation
import IOKit.pwr_mgt

final class App: NSObject, NSApplicationDelegate {
    let session = AVCaptureSession()
    let preview = AVCaptureAudioPreviewOutput()
    var videoInput: AVCaptureDeviceInput?
    var audioInput: AVCaptureDeviceInput?
    var window: NSWindow!
    let videoMenu = NSMenu(), audioMenu = NSMenu(), optionsMenu = NSMenu(), windowMenu = NSMenu()
    var sleepAssertion: IOPMAssertionID = 0
    var keepAwake = false
    var layer: AVCaptureVideoPreviewLayer!
    var muted = false
    let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ n: Notification) {
        guard !videoDevices().isEmpty else { return quitNoDevices() }
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


        buildMainMenu()

        keepAwake = defaults.object(forKey: "keepAwake") as? Bool ?? true
        setKeepAwake(keepAwake)

        preview.volume = 1
        session.beginConfiguration()
        if session.canAddOutput(preview) { session.addOutput(preview) }
        session.commitConfiguration()

        observeDevices()

        AVCaptureDevice.requestAccess(for: .video) { _ in
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { self.restore() }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ a: NSApplication) -> Bool { true }
}
