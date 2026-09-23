import XCTest
@testable import FocusSync

@MainActor
final class FocusApplyTests: XCTestCase {
    func testApplyBlockedAndNotifiesOnceWhenShortcutsMissing() {
        let focus = InMemoryFocusApply()
        focus.onExists = false
        focus.offExists = false

        focus.apply(on: true, notifyOnFailure: true)
        focus.apply(on: false, notifyOnFailure: true)

        XCTAssertTrue(focus.applyDropped)
        XCTAssertEqual(focus.notifyCount, 1)
        XCTAssertTrue(focus.applied.isEmpty)
    }

    func testApplyOnRecordsOn() {
        let focus = InMemoryFocusApply()
        focus.assumeShortcutsPresent()

        focus.apply(on: true, notifyOnFailure: true)

        XCTAssertEqual(focus.applied, [true])
        XCTAssertTrue(focus.focusOn)
        XCTAssertFalse(focus.applyDropped)
        XCTAssertEqual(focus.notifyCount, 0)
    }

    func testProbeMapsDenied() {
        let focus = InMemoryFocusApply()
        focus.nextProbe = .denied
        focus.probe(showMissing: true)

        XCTAssertTrue(focus.automationDenied)
        XCTAssertTrue(focus.probedAutomation)
        XCTAssertFalse(focus.onExists)
        XCTAssertFalse(focus.offExists)
        XCTAssertFalse(focus.showShortcutMissingError)
    }

    func testProbeMapsMissing() {
        let focus = InMemoryFocusApply()
        focus.nextProbe = .ready(onExists: true, offExists: false)
        focus.probe(showMissing: true)

        XCTAssertFalse(focus.automationDenied)
        XCTAssertTrue(focus.probedAutomation)
        XCTAssertTrue(focus.onExists)
        XCTAssertFalse(focus.offExists)
        XCTAssertTrue(focus.showShortcutMissingError)
    }

    func testProbeMapsUnavailable() {
        let focus = InMemoryFocusApply()
        focus.nextProbe = .unavailable
        focus.probe(showMissing: true)

        XCTAssertFalse(focus.automationDenied)
        XCTAssertTrue(focus.probedAutomation)
        XCTAssertFalse(focus.onExists)
        XCTAssertFalse(focus.offExists)
        XCTAssertEqual(focus.shortcutStepError, ShortcutRunError.shortcutsUnavailable.errorDescription)
    }

    func testProofSucceedsWhenBothRunsSucceed() {
        let outcome = FocusApplyPolicy.mapProof(results: [.success(()), .success(())])
        XCTAssertTrue(outcome.shortcutsProven)
        XCTAssertFalse(outcome.automationDenied)
        XCTAssertNil(outcome.shortcutStepError)
    }

    func testProofStopsWhenAutomationIsDenied() {
        let outcome = FocusApplyPolicy.mapProof(results: [.failure(.automationDenied)])
        XCTAssertFalse(outcome.shortcutsProven)
        XCTAssertTrue(outcome.automationDenied)
        XCTAssertNil(outcome.shortcutStepError)
    }

    func testProofSurfacesALaterRunFailure() {
        let outcome = FocusApplyPolicy.mapProof(results: [
            .success(()),
            .failure(.shortcutNotFound(ShortcutNames.off)),
        ])
        XCTAssertFalse(outcome.shortcutsProven)
        XCTAssertFalse(outcome.automationDenied)
        XCTAssertEqual(
            outcome.shortcutStepError,
            ShortcutRunError.shortcutNotFound(ShortcutNames.off).errorDescription
        )
    }
}
