import AppKit

extension App {
    /// Hides the pointer over the window after 2 s without movement; it reappears on the next move.
    func hideCursorWhenIdle() {
        window.acceptsMouseMovedEvents = true
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.cursorTimer?.invalidate()
            self?.cursorTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
                guard let w = self?.window, w.isKeyWindow,
                      w.contentView!.bounds.contains(w.mouseLocationOutsideOfEventStream) else { return }
                NSCursor.setHiddenUntilMouseMoves(true)
            }
            return event
        }
    }
}
