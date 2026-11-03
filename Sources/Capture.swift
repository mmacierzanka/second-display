import AppKit
import AVFoundation

extension App {
    func observeDevices() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main) { _ in self.restore() }
        nc.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main) { n in
            guard let d = n.object as? AVCaptureDevice else { return }
            if d.uniqueID == self.videoInput?.device.uniqueID { self.swap(&self.videoInput, to: nil) }
            if d.uniqueID == self.audioInput?.device.uniqueID { self.swap(&self.audioInput, to: nil) }
        }
    }

    func quitNoDevices() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("No capture devices found", comment: "")
        alert.informativeText = NSLocalizedString("Connect a camera or capture card and launch Second Display again.", comment: "")
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }

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
        if videoInput == nil {
            if let id = defaults.string(forKey: "video"), let d = videoDevices().first(where: { $0.uniqueID == id }) {
                setVideo(d)
            } else if let d = videoDevices().first { setVideo(d) }
        }
        if audioInput == nil, let id = defaults.string(forKey: "audio"), let d = audioDevices().first(where: { $0.uniqueID == id }) {
            setAudio(d)
        }  // default: audio off until chosen
        if !session.isRunning { session.startRunning() }
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
}
