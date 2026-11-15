import AppKit
import AVFoundation

extension App {
    /// Toggles a small floating window in the screen corner, shown on every Space and over full-screen apps.
    @objc func togglePip(_ sender: Any?) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didExitFullScreenNotification, object: window)
        if window.styleMask.contains(.fullScreen) {
            // the style changes below need a regular window; run again once the exit animation is done
            NotificationCenter.default.addObserver(self, selector: #selector(togglePip(_:)), name: NSWindow.didExitFullScreenNotification, object: window)
            return window.toggleFullScreen(nil)
        }
        if let frame = pipFrame {
            pipFrame = nil
            window.styleMask.remove(.fullSizeContentView)
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            window.collectionBehavior = []
            window.contentResizeIncrements = NSSize(width: 1, height: 1)  // clears contentAspectRatio
            window.setFrame(frame, display: true, animate: true)
        } else {
            pipFrame = window.frame
            let dims = videoInput.map { CMVideoFormatDescriptionGetDimensions($0.device.activeFormat.formatDescription) }
            let ratio = dims.map { NSSize(width: Int($0.width), height: Int($0.height)) } ?? NSSize(width: 16, height: 9)
            let screen = (window.screen ?? NSScreen.main!).visibleFrame
            let size = NSSize(width: screen.width / 4, height: screen.width / 4 * ratio.height / ratio.width)
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentAspectRatio = ratio
            window.setFrame(NSRect(x: screen.maxX - size.width - 20, y: screen.minY + 20, width: size.width, height: size.height), display: true, animate: true)
        }
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { window.standardWindowButton(b)?.isHidden = pipFrame != nil }
        window.level = onTop || pipFrame != nil ? .floating : .normal
        windowMenu.items.first { $0.action == #selector(togglePip(_:)) }?.state = pipFrame != nil ? .on : .off
    }
}
