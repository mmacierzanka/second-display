import AppKit
import AVFoundation

extension App {
    var startFull: Bool { defaults.object(forKey: "startFull") as? Bool ?? true }
    var quitOnDisconnect: Bool { defaults.bool(forKey: "quitOnDisconnect") }
    var onTop: Bool { defaults.bool(forKey: "onTop") }
    var gravity: AVLayerVideoGravity {
        switch defaults.string(forKey: "gravity") { case "fill": return .resizeAspectFill; case "stretch": return .resize; default: return .resizeAspect }
    }
}
