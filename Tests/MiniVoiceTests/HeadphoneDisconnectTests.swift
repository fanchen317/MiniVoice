import XCTest
@testable import MiniVoice

final class HeadphoneDisconnectTests: XCTestCase {
    typealias Route = HeadphoneDisconnectPolicy.Route
    func testDisconnectedBluetoothPauses() {
        XCTAssertTrue(HeadphoneDisconnectPolicy.shouldPause(previous: Route(id: 2, isHeadphones: true), current: Route(id: 1, isHeadphones: false), availableIDs: [1]))
    }
    func testUnpluggedJackWithSameDeviceIDPauses() {
        XCTAssertTrue(HeadphoneDisconnectPolicy.shouldPause(previous: Route(id: 1, isHeadphones: true), current: Route(id: 1, isHeadphones: false), availableIDs: [1]))
    }
    func testIntentionalSwitchAndInitialConnectionDoNotPause() {
        XCTAssertFalse(HeadphoneDisconnectPolicy.shouldPause(previous: Route(id: 2, isHeadphones: true), current: Route(id: 1, isHeadphones: false), availableIDs: [1, 2]))
        XCTAssertFalse(HeadphoneDisconnectPolicy.shouldPause(previous: nil, current: Route(id: 2, isHeadphones: true), availableIDs: [2]))
        XCTAssertFalse(HeadphoneDisconnectPolicy.shouldPause(previous: Route(id: 1, isHeadphones: false), current: Route(id: 2, isHeadphones: true), availableIDs: [1, 2]))
    }
    func testUnchangedHeadphonesDoNotPause() {
        XCTAssertFalse(HeadphoneDisconnectPolicy.shouldPause(previous: Route(id: 2, isHeadphones: true), current: Route(id: 2, isHeadphones: true), availableIDs: [2]))
    }
}
