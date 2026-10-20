import AppKit
import XCTest
@testable import MiniVoice

@MainActor
final class MusicWallButtonInputTests: XCTestCase {
    func testButtonTapPassesThroughButDragReleasesOutsideButton() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let input = MusicWallScrollInput.ScrollInputView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView = input
        defer { input.stop(); window.close() }
        input.onDown = { _, _ in .button }
        var pans: [CGSize] = []
        var releases = 0
        input.onDrag = { pans.append($0) }
        input.onUp = { _, _, dragged, _ in XCTAssertTrue(dragged); releases += 1 }
        func event(_ type: NSEvent.EventType, x: CGFloat, time: TimeInterval) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: 400),
                modifierFlags: [], timestamp: time, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        }
        let down = try event(.leftMouseDown, x: 200, time: 1)
        let tapUp = try event(.leftMouseUp, x: 200, time: 1.1)
        XCTAssertTrue(input.route(down) === down)
        XCTAssertTrue(input.route(tapUp) === tapUp)
        XCTAssertTrue(pans.isEmpty)
        XCTAssertEqual(releases, 0)

        XCTAssertNotNil(input.route(try event(.leftMouseDown, x: 200, time: 2)))
        XCTAssertNotNil(input.route(try event(.leftMouseDragged, x: 240, time: 2.1)))
        let release = try XCTUnwrap(input.route(try event(.leftMouseUp, x: 240, time: 2.2)))
        XCTAssertEqual(pans, [CGSize(width: 40, height: 0)])
        XCTAssertEqual(releases, 1)
        XCTAssertLessThan(release.locationInWindow.x, 0)
        XCTAssertLessThan(release.locationInWindow.y, 0)
    }
}
