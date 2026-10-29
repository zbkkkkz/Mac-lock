// Written for this project against Apple's public CoreGraphics interfaces.
import AppKit
@preconcurrency import ApplicationServices

struct EscapeGesture {
    private var presses: [TimeInterval] = []
    mutating func consume(key: Int64, repeated: Bool, time: TimeInterval) -> Bool {
        if repeated { return false }
        guard key == 53 else { presses.removeAll(); return false }
        presses = presses.filter { time - $0 <= 2 }
        presses.append(time)
        guard presses.count >= 3 else { return false }
        presses.removeAll()
        return true
    }
}

enum InputScope: String, CaseIterable {
    case keys = "仅锁键盘"
    case everything = "全锁"
    var eventNumbers: Set<UInt32> {
        let keys: Set<UInt32> = [CGEventType.keyDown.rawValue, CGEventType.keyUp.rawValue, CGEventType.flagsChanged.rawValue, UInt32(NSEvent.EventType.systemDefined.rawValue)]
        guard self == .everything else { return keys }
        let pointer: Set<UInt32> = [CGEventType.leftMouseDown.rawValue, CGEventType.leftMouseUp.rawValue, CGEventType.rightMouseDown.rawValue, CGEventType.rightMouseUp.rawValue, CGEventType.mouseMoved.rawValue, CGEventType.leftMouseDragged.rawValue, CGEventType.rightMouseDragged.rawValue, CGEventType.scrollWheel.rawValue, CGEventType.otherMouseDown.rawValue, CGEventType.otherMouseUp.rawValue, CGEventType.otherMouseDragged.rawValue]
        let gestures = [NSEvent.EventType.gesture, .magnify, .swipe, .rotate, .beginGesture, .endGesture, .smartMagnify, .pressure].map { UInt32($0.rawValue) }
        return keys.union(pointer).union(gestures)
    }
}

// All event handling and teardown happen on the main run loop. No input is recorded.
final class InputGate {
    enum Failure: Error { case permission, unavailable }
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var escape = EscapeGesture()
    var didStop: ((Bool) -> Void)?
    var running: Bool { port != nil }

    func engage(_ scope: InputScope) throws {
        precondition(Thread.isMainThread)
        guard !running else { return }
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { throw Failure.permission }
        escape = EscapeGesture()
        let interest = scope.eventNumbers.reduce(CGEventMask(0)) { mask, number in mask | (CGEventMask(1) << number) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let gate = Unmanaged<InputGate>.fromOpaque(context).takeUnretainedValue()
            return gate.filter(type, event)
        }
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: interest, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { throw Failure.unavailable }
        guard let runSource = CFMachPortCreateRunLoopSource(nil, created, 0) else {
            CFMachPortInvalidate(created)
            throw Failure.unavailable
        }
        port = created
        source = runSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
    }
    func disengage() {
        precondition(Thread.isMainThread)
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        port = nil
        source = nil
        escape = EscapeGesture()
    }
    private func filter(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            disengage()
            didStop?(true)
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown && escape.consume(key: event.getIntegerValueField(.keyboardEventKeycode), repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, time: ProcessInfo.processInfo.systemUptime) {
            disengage()
            didStop?(false)
        }
        return nil
    }
}
