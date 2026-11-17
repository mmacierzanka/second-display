import AppKit
import AVFoundation
import AVKit

/// Picture in picture, in the mode picked in the Options menu:
/// - app window (default): the main window itself shrinks into a floating corner window;
/// - system: the macOS PiP window. AVCaptureVideoPreviewLayer cannot be its source, so frames are also routed
///   through an AVCaptureVideoDataOutput into an AVSampleBufferDisplayLayer hidden under the preview.
extension App: AVCaptureVideoDataOutputSampleBufferDelegate, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    @objc func togglePip(_ sender: Any?) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didExitFullScreenNotification, object: window)
        // leave whichever PiP is on, even if the mode has changed since
        if let pip, pip.isPictureInPictureActive { return pip.stopPictureInPicture() }
        if window.styleMask.contains(.fullScreen) {
            // neither mode can leave a full-screen Space behind; run again once the exit animation is done
            NotificationCenter.default.addObserver(self, selector: #selector(togglePip(_:)), name: NSWindow.didExitFullScreenNotification, object: window)
            return window.toggleFullScreen(nil)
        }
        if pipFrame != nil || !pipSystem { toggleWindowPip() }
        // without a first frame (e.g. a suspended camera) AVKit lays the PiP window out with NaN and crashes
        else if let pip, pip.isPictureInPicturePossible, pipLayer.isReadyForDisplay { pip.startPictureInPicture() }
        else { NSSound.beep() }
    }

    @objc func pickPipMode(_ s: NSMenuItem) {
        guard let system = s.representedObject as? Bool, system != pipSystem else { return }
        if system {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString("Turn on experimental system Picture in Picture?", comment: "")
            alert.informativeText = NSLocalizedString("This mode shows the video in the macOS Picture in Picture window through a workaround for a system bug, so it may behave unpredictably: the picture may be cropped or fail to appear, especially after a macOS update. It also uses a little more CPU and memory, even while picture in picture is off. If something goes wrong, switch back to App window.", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Turn On", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        if pipFrame != nil || pip?.isPictureInPictureActive == true { togglePip(nil) }
        defaults.set(system, forKey: "pipSystem"); applyPipMode()
    }

    /// The app-window PiP takes the picture's shape when it opens, so after a format or source change it opens again.
    /// (System PiP follows the new frames by itself.)
    func reshapePip() { if pipFrame != nil { toggleWindowPip(); toggleWindowPip() } }

    private func setPipChecked(_ on: Bool) { windowMenu.items.first { $0.action == #selector(togglePip(_:)) }?.state = on ? .on : .off }

    // MARK: app window mode
    /// Toggles a small floating window in the screen corner, shown on every Space and over full-screen apps.
    private func toggleWindowPip() {
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
        setPipChecked(pipFrame != nil)
    }

    // MARK: system mode
    /// Sets up or parks what system mode needs. The extra output costs CPU, so it is only attached in that mode.
    func applyPipMode() {
        let attached = session.outputs.contains(videoOutput)
        session.beginConfiguration()
        if pipSystem, !attached, session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        if !pipSystem, attached { session.removeOutput(videoOutput) }
        session.commitConfiguration()
        guard pipSystem, pip == nil else { return }
        pipLayer.videoGravity = .resizeAspect
        pipLayer.frame = CGRect(x: 0, y: 0, width: 640, height: 360)  // resized to the PiP window once it opens
        window.contentView!.layer!.insertSublayer(pipLayer, below: layer)
        layer.backgroundColor = NSColor.black.cgColor  // opaque, or "fit" shows pipLayer through the letterbox
        pipRenderer = pipLayer.sampleBufferRenderer
        // shortcut: in system mode frames are delivered all the time, not only while PiP is on; gate the output if CPU use matters
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "pip"))
        pip = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: pipLayer, playbackDelegate: self))
        pip?.delegate = self
        pip?.requiresLinearPlayback = true
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // no control timebase: show each live frame as soon as it arrives
        if let a = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true), CFArrayGetCount(a) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(a, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(), Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        pipRenderer?.enqueue(buffer)
    }

    // the main window steps aside while the PiP window is up
    func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) {
        setPipChecked(true); window.orderOut(nil)
        if let content = pipPanelContent {
            content.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(fitPipLayer), name: NSView.frameDidChangeNotification, object: content)
        }
        fitPipLayer()
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)
        setPipChecked(false); showMainWindow()
    }
    func pictureInPictureController(_ c: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) { NSLog("PiP failed: \(error)") }
    func pictureInPictureController(_ c: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler done: @escaping (Bool) -> Void) {
        showMainWindow(); done(true)
    }
    // plain activate() is refused while another app is frontmost, which leaves a full-screen window on its own Space
    private func showMainWindow() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }

    // Workaround for a macOS bug (FB22411168, https://developer.apple.com/forums/thread/821582): the PiP window shows
    // the source layer pixel for pixel instead of scaling it, under an empty black view.
    // So keep the (hidden) source layer the size of the PiP window and hide that view.
    // shortcut: relies on the private class names PIPPanel and AVPictureInPictureCALayerHostView; if macOS renames them the picture is cropped again, remove once Apple fixes the bug
    private var pipPanelContent: NSView? { NSApp.windows.first { $0.className == "PIPPanel" }?.contentView }
    @objc private func fitPipLayer() {
        guard let content = pipPanelContent else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        pipLayer.frame = content.bounds
        CATransaction.commit()
        func hideOverlay(_ v: NSView) { if v.className == "AVPictureInPictureCALayerHostView" { v.isHidden = true }; v.subviews.forEach(hideOverlay) }
        hideOverlay(content)
    }

    // live stream: no pause, no seeking
    func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {}
    func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange { CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity) }
    func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool { false }
    func pictureInPictureController(_ c: AVPictureInPictureController, didTransitionToRenderSize size: CMVideoDimensions) {}
    func pictureInPictureController(_ c: AVPictureInPictureController, skipByInterval interval: CMTime, completion: @escaping () -> Void) { completion() }
}
