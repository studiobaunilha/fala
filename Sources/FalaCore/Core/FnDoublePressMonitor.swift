import CoreGraphics
import Foundation

/// Detects a **double-press of the Fn/Globe key** as a trigger, matching the
/// gesture that macOS itself uses to start native Dictation.
///
/// Implementation uses a `CGEventTap` on `.flagsChanged` events. This runs
/// under the same Accessibility permission the app already requires for text
/// insertion — it does **not** need separate Input Monitoring consent.
///
/// Thread-safe: the tap callback runs on a dedicated thread; the user-facing
/// action is dispatched on the main actor.
public final class FnDoublePressMonitor: @unchecked Sendable {
    /// Max interval between two Fn presses to count as a double-press.
    /// Matches the feel of macOS native Dictation.
    private static let doublePressWindow: TimeInterval = 0.35

    /// Virtual keycode for the Fn / Globe (🌐) key.
    private static let fnKeyCode: Int64 = 0x3F

    private let action: @MainActor @Sendable () -> Void
    private let lock = NSLock()
    private var lastPressTimestamp: TimeInterval = 0
    private var enabled: Bool = false
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public init(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    /// Enable or disable detection without tearing down the event tap.
    /// Safe to call from any thread.
    public func setEnabled(_ value: Bool) {
        lock.lock()
        enabled = value
        if !value {
            lastPressTimestamp = 0
        }
        lock.unlock()
    }

    /// Install the event tap on the current run loop. Idempotent.
    @MainActor
    public func start() {
        guard tap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, _, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<FnDoublePressMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handle(event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let machPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("[Fala] FnDoublePressMonitor: tapCreate failed (AX permission missing?)")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: machPort, enable: true)

        self.tap = machPort
        self.runLoopSource = source
    }

    /// Remove the event tap and release resources.
    @MainActor
    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil

        lock.lock()
        lastPressTimestamp = 0
        lock.unlock()
    }

    private func handle(event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Self.fnKeyCode else { return }

        // `.flagsChanged` fires on both press and release. Only count presses
        // (when the Fn flag becomes active).
        guard event.flags.contains(.maskSecondaryFn) else { return }

        let now = CFAbsoluteTimeGetCurrent()

        lock.lock()
        guard enabled else {
            lock.unlock()
            return
        }

        let isDoublePress = lastPressTimestamp > 0
            && (now - lastPressTimestamp) < Self.doublePressWindow

        if isDoublePress {
            lastPressTimestamp = 0
        } else {
            lastPressTimestamp = now
        }
        lock.unlock()

        guard isDoublePress else { return }

        let action = self.action
        Task { @MainActor in
            action()
        }
    }
}
