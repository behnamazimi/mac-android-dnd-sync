import Foundation
@testable import DNDSync

@MainActor
final class InMemoryFocusApply: FocusApply {
    enum ProbeFixture {
        case ready(onExists: Bool, offExists: Bool)
        case denied
        case unavailable
    }

    var focusOn = false
    var onExists = false
    var offExists = false
    var automationDenied = false
    var probedAutomation = false
    var applyDropped = false
    var shortcutStepError: String?
    var showShortcutMissingError = false
    var lastRunText = "Last run: —"
    var focusStatusText = "Focus: unknown"

    var onLocalChange: ((Bool, String) -> Void)?
    var onStateChange: (() -> Void)?

    var nextProbe: ProbeFixture = .ready(onExists: true, offExists: true)
    var applied: [Bool] = []
    var importedOn = 0
    var importedOff = 0
    var notifyCount = 0
    var openedAutomationSettings = false

    func apply(on: Bool, notifyOnFailure: Bool) {
        if FocusApplyPolicy.shouldDrop(
            automationDenied: automationDenied,
            onExists: onExists,
            offExists: offExists
        ) {
            let wasDropped = applyDropped
            applyDropped = true
            onStateChange?()
            if !wasDropped && notifyOnFailure {
                notifyCount += 1
            }
            return
        }
        applyDropped = false
        applied.append(on)
        focusOn = on
        focusStatusText = on ? "Focus: on" : "Focus: off"
        onStateChange?()
        onLocalChange?(on, focusStatusText)
    }

    func turnOn() {
        apply(on: true, notifyOnFailure: false)
    }

    func turnOff() {
        apply(on: false, notifyOnFailure: false)
    }

    func probe(showMissing: Bool) {
        let onResult: Result<Bool, ShortcutRunError>
        let offResult: Result<Bool, ShortcutRunError>
        switch nextProbe {
        case .ready(let onExists, let offExists):
            onResult = .success(onExists)
            offResult = .success(offExists)
        case .denied:
            onResult = .failure(.automationDenied)
            offResult = .failure(.automationDenied)
        case .unavailable:
            onResult = .failure(.shortcutsUnavailable)
            offResult = .failure(.shortcutsUnavailable)
        }
        let outcome = FocusApplyPolicy.mapProbe(
            onResult: onResult,
            offResult: offResult,
            showMissing: showMissing,
            automationPromptPending: false
        )
        guard !outcome.ignore else { return }
        automationDenied = outcome.automationDenied
        probedAutomation = outcome.probedAutomation
        onExists = outcome.onExists
        offExists = outcome.offExists
        shortcutStepError = outcome.shortcutStepError
        showShortcutMissingError = outcome.showShortcutMissingError
        onStateChange?()
    }

    func importOn() {
        importedOn += 1
        onExists = true
        showShortcutMissingError = false
        onStateChange?()
    }

    func importOff() {
        importedOff += 1
        offExists = true
        showShortcutMissingError = false
        onStateChange?()
    }

    func continueAutomation() {
        probe(showMissing: false)
    }

    func assumeShortcutsPresent() {
        probedAutomation = true
        onExists = true
        offExists = true
        automationDenied = false
        onStateChange?()
    }

    func openAutomationSettings() {
        openedAutomationSettings = true
    }

    func simulateLocalChange(on: Bool) {
        focusOn = on
        focusStatusText = on ? "Focus: on" : "Focus: off"
        onStateChange?()
        onLocalChange?(on, focusStatusText)
    }
}
