import XCTest
@testable import FocusSync

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

    func testSuppressInterruptionsWinsOverActive() {
        XCTAssertEqual(
            FocusStatusObserver.isOn(willSuppressInterruptions: true, isActive: false),
            true
        )
        XCTAssertEqual(
            FocusStatusObserver.isOn(willSuppressInterruptions: false, isActive: true),
            false
        )
    }

    func testActiveUsedWhenSuppressUnknown() {
        XCTAssertEqual(
            FocusStatusObserver.isOn(willSuppressInterruptions: nil, isActive: true),
            true
        )
        XCTAssertEqual(
            FocusStatusObserver.isOn(willSuppressInterruptions: nil, isActive: false),
            false
        )
        XCTAssertNil(FocusStatusObserver.isOn(willSuppressInterruptions: nil, isActive: nil))
    }
}
