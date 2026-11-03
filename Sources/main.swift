import AppKit
import XPC

// Acknowledge launchd's USB-match events (see Autostart.swift); unacknowledged ones make launchd relaunch the job every 10 s.
xpc_set_event_stream_handler("com.apple.iokit.matching", nil) { _ in }

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
