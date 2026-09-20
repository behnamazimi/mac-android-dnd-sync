import XCTest
@testable import DNDSync

final class FocusStatusObserverTests: XCTestCase {
    func testEmptyEnabledNotificationIsOn() {
        let notification = Notification(name: FocusStatusObserver.enabledName)
        XCTAssertTrue(FocusStatusObserver.resolveEnabled(notification))
    }

    func testEmptyDisabledNotificationIsOff() {
        let notification = Notification(name: FocusStatusObserver.disabledName)
        XCTAssertFalse(FocusStatusObserver.resolveEnabled(notification))
    }

    func testPayloadOverridesEnabledName() {
        let notification = Notification(
            name: FocusStatusObserver.enabledName,
            object: NSNumber(value: false)
        )
        XCTAssertFalse(FocusStatusObserver.resolveEnabled(notification))
    }

    func testUserInfoEnabledKey() {
        let notification = Notification(
            name: FocusStatusObserver.disabledName,
            object: nil,
            userInfo: ["enabled": true]
        )
        XCTAssertTrue(FocusStatusObserver.resolveEnabled(notification))
    }
}
