import AppKit
import AVFoundation

extension App {
    func observeDevices() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main) { n in
            // the autostart device takes over the picture as soon as it appears
            if let d = n.object as? AVCaptureDevice, d.hasMediaType(.video), d.uniqueID == self.autostartID { self.setVideo(d) }
            self.restore()
        }
        nc.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main) { n in
            guard let d = n.object as? AVCaptureDevice else { return }
            if d.uniqueID == self.videoInput?.device.uniqueID {
                // the autostart agent keeps waiting and relaunches the app when the device returns
                if self.quitOnDisconnect { return NSApp.terminate(nil) }
                self.swap(&self.videoInput, to: nil)
            }
            if d.uniqueID == self.audioInput?.device.uniqueID { self.swap(&self.audioInput, to: nil) }
        }
    }

    func quitWithError(_ title: String, _ info: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }
    func quitNoDevices() {
        quitWithError(NSLocalizedString("No capture devices found", comment: ""),
                      NSLocalizedString("Connect a camera or capture card and launch Second Display again.", comment: ""))
    }
    func quitCameraDenied() {
        quitWithError(NSLocalizedString("Camera access denied", comment: ""),
                      NSLocalizedString("Allow camera access for Second Display in System Settings > Privacy & Security > Camera, then launch it again.", comment: ""))
    }
    // .notDetermined is not blocked: the prompt is still to come
    var micBlocked: Bool { [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .audio)) }

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
            let devices = videoDevices()
            let preferred = [autostartID, defaults.string(forKey: "video")].compactMap { id in devices.first { $0.uniqueID == id } }
            if let d = preferred.first ?? devices.first { setVideo(d) }
        }
        if audioInput == nil, !micBlocked, let id = defaults.string(forKey: "audio"), let d = audioDevices().first(where: { $0.uniqueID == id }) {
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
    func codec(_ f: AVCaptureDevice.Format) -> String {
        let c = CMFormatDescriptionGetMediaSubType(f.formatDescription)
        let names: [FourCharCode: String] = [
            kCVPixelFormatType_422YpCbCr8_yuvs: "YUY2", kCVPixelFormatType_422YpCbCr8: "UYVY",
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: "NV12", kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: "NV12",
            kCMVideoCodecType_JPEG_OpenDML: "MJPEG", kCMVideoCodecType_JPEG: "JPEG"]
        return names[c] ?? String(bytes: [24, 16, 8, 0].map { UInt8(c >> $0 & 0xFF) }, encoding: .ascii) ?? "?"
    }
    func key(_ f: AVCaptureDevice.Format) -> String { "\(dims(f).width)x\(dims(f).height)@\(fps(f))/\(codec(f))" }

    /// The three independent format attributes: menu title, displayed value, sort order.
    var attributes: [(title: String, value: (AVCaptureDevice.Format) -> String, order: (AVCaptureDevice.Format) -> Int)] {
        [(NSLocalizedString("Resolution", comment: ""), { "\(self.dims($0).width)x\(self.dims($0).height)" }, { Int(self.dims($0).width) * 10000 + Int(self.dims($0).height) }),
         (NSLocalizedString("Frame rate", comment: ""), { "\(self.fps($0)) fps" }, { self.fps($0) }),
         (NSLocalizedString("Pixel format", comment: ""), { self.codec($0) }, { _ in 0 })]
    }

    func applyFormat(_ d: AVCaptureDevice) {
        guard let l = defaults.string(forKey: "format.\(d.uniqueID)"),
              let f = d.formats.first(where: { key($0) == l }), (try? d.lockForConfiguration()) != nil else { return }
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
