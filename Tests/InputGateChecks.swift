import AppKit
@main struct Check {
 static func main() {
  var gesture = EscapeGesture()
  precondition(!gesture.consume(key: 53, repeated: false, time: 1))
  precondition(!gesture.consume(key: 53, repeated: true, time: 1.1))
  precondition(!gesture.consume(key: 53, repeated: false, time: 1.2))
  precondition(gesture.consume(key: 53, repeated: false, time: 1.4))
  precondition(!gesture.consume(key: 53, repeated: false, time: 3))
  precondition(!gesture.consume(key: 53, repeated: false, time: 6))
  precondition(!gesture.consume(key: 0, repeated: false, time: 6.1))
  precondition(!gesture.consume(key: 53, repeated: false, time: 6.2))
  precondition(!gesture.consume(key: 53, repeated: false, time: 6.3))
  precondition(gesture.consume(key: 53, repeated: false, time: 6.4))
  precondition(InputScope.keys.eventNumbers.contains(CGEventType.keyDown.rawValue))
  precondition(!InputScope.keys.eventNumbers.contains(CGEventType.mouseMoved.rawValue))
  precondition(!InputScope.keys.eventNumbers.contains(CGEventType.leftMouseDown.rawValue))
  precondition(InputScope.everything.eventNumbers.isSuperset(of: InputScope.keys.eventNumbers))
  precondition(InputScope.everything.eventNumbers.contains(CGEventType.leftMouseDown.rawValue))
  let gate = InputGate()
  precondition(!gate.running)
  gate.disengage()
  gate.disengage()
  precondition(!gate.running)
  print("PASS: Escape recovery, scope isolation, default unlocked, repeatable teardown")
 }
}
