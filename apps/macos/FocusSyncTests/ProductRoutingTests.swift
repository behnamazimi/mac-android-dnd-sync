import XCTest
@testable import FocusSync

final class ProductRoutingTests: XCTestCase {
    func testWelcomeShownBeforeAnythingElse() {
        XCTAssertEqual(MacRouting.destination(progress()), .welcome)
    }

    func testAutomationWinsUntilProbed() {
        XCTAssertEqual(MacRouting.destination(progress(hasSeenWelcome: true)), .automation)
    }

    func testShortcutsStepWhenOffMissing() {
        XCTAssertEqual(
            MacRouting.destination(progress(
                hasSeenWelcome: true,
                notificationsGranted: true,
                probedAutomation: true,
                onExists: true
            )),
            .shortcuts
        )
    }

    func testShortcutsStepWhenOnMissing() {
        XCTAssertEqual(
            MacRouting.destination(progress(
                hasSeenWelcome: true,
                notificationsGranted: true,
                probedAutomation: true,
                offExists: true
            )),
            .shortcuts
        )
    }

    func testLoginItemBeforeQRWhenNotSkipped() {
        XCTAssertEqual(
            MacRouting.destination(progress(
                hasSeenWelcome: true,
                notificationsGranted: true,
                probedAutomation: true,
                onExists: true,
                offExists: true
            )),
            .loginItem
        )
    }

    func testQRAfterLoginSkip() {
        XCTAssertEqual(
            MacRouting.destination(progress(
                hasSeenWelcome: true,
                notificationsGranted: true,
                probedAutomation: true,
                onExists: true,
                offExists: true,
                loginSkipped: true
            )),
            .qr
        )
    }

    func testNotificationsBlockPairedMac() {
        XCTAssertEqual(
            MacRouting.destination(progress(
                hasSeenWelcome: true,
                paired: true,
                probedAutomation: true,
                onExists: true,
                offExists: true,
                loginSkipped: true
            )),
            .automation
        )
    }

    func testPairedSkipsWizardEvenIfShortcutsMissing() {
        XCTAssertEqual(
            MacRouting.destination(progress(
                hasSeenWelcome: true,
                paired: true,
                notificationsGranted: true,
                automationDenied: true,
                probedAutomation: true
            )),
            .status
        )
    }

    func testUnpairFromStatusReturnsToQR() {
        let paired = progress(
            hasSeenWelcome: true,
            paired: true,
            notificationsGranted: true,
            probedAutomation: true,
            onExists: true,
            offExists: true,
            loginSkipped: true
        )
        XCTAssertEqual(MacRouting.destination(paired), .status)
        var unpaired = paired
        unpaired.paired = false
        XCTAssertEqual(MacRouting.destination(unpaired), .qr)
    }

    func testPairedSkipsWelcomeEvenIfNeverSeen() {
        XCTAssertEqual(
            MacRouting.destination(progress(
                paired: true,
                notificationsGranted: true,
                probedAutomation: true,
                onExists: true,
                offExists: true,
                loginEnabled: true,
                loginSkipped: true
            )),
            .status
        )
    }

    func testOfflineAfterLocalWizardStaysOnQR() {
        XCTAssertEqual(
            MacRouting.destination(progress(
                hasSeenWelcome: true,
                notificationsGranted: true,
                probedAutomation: true,
                onExists: true,
                offExists: true,
                loginEnabled: true
            )),
            .qr
        )
    }

    func testLocalWizardDoesNotNeedNetwork() {
        XCTAssertFalse(MacRouting.needsNetwork(progress()))
        XCTAssertFalse(
            MacRouting.needsNetwork(progress(
                hasSeenWelcome: true,
                notificationsGranted: true,
                probedAutomation: true,
                onExists: true,
                offExists: true
            ))
        )
        XCTAssertTrue(
            MacRouting.needsNetwork(progress(
                hasSeenWelcome: true,
                notificationsGranted: true,
                probedAutomation: true,
                onExists: true,
                offExists: true,
                loginSkipped: true
            ))
        )
        XCTAssertFalse(
            MacRouting.needsNetwork(progress(
                hasSeenWelcome: true,
                paired: true,
                automationDenied: true,
                probedAutomation: true
            ))
        )
        XCTAssertTrue(
            MacRouting.needsNetwork(progress(
                hasSeenWelcome: true,
                paired: true,
                notificationsGranted: true,
                automationDenied: true,
                probedAutomation: true
            ))
        )
    }

    func testPairingExpiredOutranksShortcuts() {
        XCTAssertEqual(
            MacRouting.lastError(
                paired: true,
                pairingExpired: true,
                automationDenied: true,
                onExists: false,
                offExists: false,
                applyDropped: true,
                lastCloudError: "timeout",
                lastLanError: "bonjour",
                lanBlocking: true
            ),
            ProductCopy.pairingExpired
        )
    }

    func testShortcutsMissingBeforeCloud() {
        XCTAssertEqual(
            MacRouting.lastError(
                paired: true,
                pairingExpired: false,
                automationDenied: false,
                onExists: true,
                offExists: false,
                applyDropped: false,
                lastCloudError: "timeout",
                lastLanError: nil,
                lanBlocking: false
            ),
            ProductCopy.shortcutsMissing
        )
    }

    func testLastSyncEventLineMapsMacAndPhone() {
        XCTAssertEqual(
            LastSyncPresentation.eventLine(sender: "android", on: true, peerName: "Pixel 9"),
            "Pixel 9 turned Focus on"
        )
        XCTAssertEqual(
            LastSyncPresentation.eventLine(sender: "mac", on: false, peerName: "Pixel 9"),
            "This Mac turned Focus off"
        )
        XCTAssertEqual(LastSyncPresentation.peerLabel(""), ProductCopy.phoneFallback)
        XCTAssertEqual(LastSyncPresentation.pathLabel(viaLan: true), ProductCopy.pathNearby)
        XCTAssertEqual(LastSyncPresentation.truncatedPairId("dndsync-dev-abc12345"), "…abc12345")
        XCTAssertFalse(LastSyncPresentation.hasSync(0))
        XCTAssertTrue(LastSyncPresentation.hasSync(42))
    }

    func testRecentActivityStateLabelAndLine() {
        XCTAssertEqual(RecentActivity.stateLabel(on: true), ProductCopy.dndOnShort)
        XCTAssertEqual(RecentActivity.stateLabel(on: false), ProductCopy.dndOffShort)
        XCTAssertEqual(RecentActivity.actorLabel(sender: "mac"), ProductCopy.byThisMac)
        XCTAssertEqual(RecentActivity.actorLabel(sender: "android"), ProductCopy.byThePhone)
        // Unrecognized senders (should never happen, but don't crash the row) read as the phone.
        XCTAssertEqual(RecentActivity.actorLabel(sender: ""), ProductCopy.byThePhone)
        XCTAssertEqual(
            RecentActivity.line(on: true, sender: "mac"),
            "On by \(ProductCopy.byThisMac)"
        )
        XCTAssertEqual(
            RecentActivity.line(on: false, sender: "android"),
            "Off by \(ProductCopy.byThePhone)"
        )
    }

    func testRecentActivityAppendingPrependsDedupesAndCaps() {
        var trail: [SyncEvent] = []
        for unixMs in Int64(1)...Int64(RecentActivity.maxEvents) {
            trail = RecentActivity.appending(SyncEvent(unixMs: unixMs, on: true, sender: "mac"), to: trail)
        }
        XCTAssertEqual(trail.map(\.unixMs), [5, 4, 3, 2, 1])

        // One more event should push out the oldest, keeping the cap.
        trail = RecentActivity.appending(SyncEvent(unixMs: 6, on: false, sender: "android"), to: trail)
        XCTAssertEqual(trail.map(\.unixMs), [6, 5, 4, 3, 2])

        // Re-appending an existing unixMs moves it to the front without duplicating it.
        trail = RecentActivity.appending(SyncEvent(unixMs: 4, on: true, sender: "mac"), to: trail)
        XCTAssertEqual(trail.map(\.unixMs), [4, 6, 5, 3, 2])
    }

    func testRecentActivityAppendingZeroClearsTrail() {
        let trail = [SyncEvent(unixMs: 1, on: true, sender: "mac")]
        XCTAssertEqual(RecentActivity.appending(SyncEvent(unixMs: 0, on: false, sender: "android"), to: trail), [])
    }

    private func progress(
        hasSeenWelcome: Bool = false,
        paired: Bool = false,
        notificationsGranted: Bool = false,
        automationDenied: Bool = false,
        probedAutomation: Bool = false,
        onExists: Bool = false,
        offExists: Bool = false,
        loginEnabled: Bool = false,
        loginSkipped: Bool = false
    ) -> OnboardingProgress {
        OnboardingProgress(
            hasSeenWelcome: hasSeenWelcome,
            paired: paired,
            notificationsGranted: notificationsGranted,
            automationDenied: automationDenied,
            probedAutomation: probedAutomation,
            onExists: onExists,
            offExists: offExists,
            loginEnabled: loginEnabled,
            loginSkipped: loginSkipped
        )
    }
}
