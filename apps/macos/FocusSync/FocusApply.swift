import AppKit
import Foundation

/// Observe Mac Focus and apply a remote on/off. Two adapters: Shortcuts
/// (production) and in-memory (tests). Callers never name shortcuts or the
/// private DND notifications.
@MainActor
protocol FocusApply: AnyObject {
    var focusOn: Bool { get }
    var onExists: Bool { get }
    var offExists: Bool { get }
    var automationDenied: Bool { get }
    var probedAutomation: Bool { get }
    var applyDropped: Bool { get }
    var shortcutStepError: String? { get }
    var showShortcutMissingError: Bool { get }
    var lastRunText: String { get }
    var focusStatusText: String { get }

    var onLocalChange: ((Bool, String) -> Void)? { get set }
    var onStateChange: (() -> Void)? { get set }

    func apply(on: Bool, notifyOnFailure: Bool)
    func turnOn()
    func turnOff()
    func probe(showMissing: Bool)
    func importOn()
    func importOff()
    func continueAutomation()
    func assumeShortcutsPresent()
    func openAutomationSettings()
}

enum FocusApplyPolicy {
    struct ProbeOutcome {
        var automationDenied: Bool
        var probedAutomation: Bool
        var onExists: Bool
        var offExists: Bool
        var shortcutStepError: String?
        var showShortcutMissingError: Bool
        var ignore: Bool
    }

    static func shouldDrop(automationDenied: Bool, onExists: Bool, offExists: Bool) -> Bool {
        automationDenied || !onExists || !offExists
    }

    static func mapProbe(
        onResult: Result<Bool, ShortcutRunError>,
        offResult: Result<Bool, ShortcutRunError>,
        showMissing: Bool,
        automationPromptPending: Bool
    ) -> ProbeOutcome {
        if isUnavailable(onResult) || isUnavailable(offResult) {
            if automationPromptPending {
                return ProbeOutcome(
                    automationDenied: false,
                    probedAutomation: false,
                    onExists: false,
                    offExists: false,
                    shortcutStepError: nil,
                    showShortcutMissingError: false,
                    ignore: true
                )
            }
            return ProbeOutcome(
                automationDenied: false,
                probedAutomation: true,
                onExists: false,
                offExists: false,
                shortcutStepError: ShortcutRunError.shortcutsUnavailable.errorDescription,
                showShortcutMissingError: showMissing,
                ignore: false
            )
        }
        if isDenied(onResult) || isDenied(offResult) {
            if automationPromptPending {
                return ProbeOutcome(
                    automationDenied: false,
                    probedAutomation: false,
                    onExists: false,
                    offExists: false,
                    shortcutStepError: nil,
                    showShortcutMissingError: false,
                    ignore: true
                )
            }
            return ProbeOutcome(
                automationDenied: true,
                probedAutomation: true,
                onExists: false,
                offExists: false,
                shortcutStepError: nil,
                showShortcutMissingError: false,
                ignore: false
            )
        }
        let onExists = (try? onResult.get()) ?? false
        let offExists = (try? offResult.get()) ?? false
        return ProbeOutcome(
            automationDenied: false,
            probedAutomation: true,
            onExists: onExists,
            offExists: offExists,
            shortcutStepError: nil,
            showShortcutMissingError: showMissing && (!onExists || !offExists),
            ignore: false
        )
    }

    private static func isDenied(_ result: Result<Bool, ShortcutRunError>) -> Bool {
        if case .failure(.automationDenied) = result {
            return true
        }
        return false
    }

    private static func isUnavailable(_ result: Result<Bool, ShortcutRunError>) -> Bool {
        if case .failure(.shortcutsUnavailable) = result {
            return true
        }
        return false
    }
}

@MainActor
final class ShortcutsFocusApply: FocusApply {
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

    private let observer = FocusStatusObserver()
    private var probeGeneration = 0
    private var automationPromptPending = false

    init() {
        observer.onChange = { [weak self] enabled, text in
            Task { @MainActor in
                self?.handleFocusChange(enabled: enabled, text: text)
            }
        }
    }

    func apply(on: Bool, notifyOnFailure: Bool) {
        if FocusApplyPolicy.shouldDrop(
            automationDenied: automationDenied,
            onExists: onExists,
            offExists: offExists
        ) {
            let wasDropped = applyDropped
            applyDropped = true
            publish()
            if !wasDropped && notifyOnFailure {
                FailedApplyNotifier.notifyFailedApply()
            }
            return
        }
        applyDropped = false
        publish()
        if on {
            turnOn()
        } else {
            turnOff()
        }
    }

    func turnOn() {
        runShortcut(named: ShortcutNames.on)
    }

    func turnOff() {
        runShortcut(named: ShortcutNames.off)
    }

    func probe(showMissing: Bool) {
        let generation = probeGeneration
        Task {
            let onResult = await Task.detached { ShortcutRunner.exists(named: ShortcutNames.on) }.value
            let offResult = await Task.detached { ShortcutRunner.exists(named: ShortcutNames.off) }.value
            guard generation == probeGeneration else { return }
            let outcome = FocusApplyPolicy.mapProbe(
                onResult: onResult,
                offResult: offResult,
                showMissing: showMissing,
                automationPromptPending: automationPromptPending
            )
            guard !outcome.ignore else { return }
            automationDenied = outcome.automationDenied
            probedAutomation = outcome.probedAutomation
            onExists = outcome.onExists
            offExists = outcome.offExists
            shortcutStepError = outcome.shortcutStepError
            showShortcutMissingError = outcome.showShortcutMissingError
            publish()
        }
    }

    func importOn() {
        importShortcut(named: ShortcutNames.on)
    }

    func importOff() {
        importShortcut(named: ShortcutNames.off)
    }

    func continueAutomation() {
        automationPromptPending = true
        probeGeneration += 1
        probe(showMissing: false)
    }

    func assumeShortcutsPresent() {
        probedAutomation = true
        onExists = true
        offExists = true
        automationDenied = false
        publish()
    }

    func openAutomationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func noteBecameActive() {
        if automationPromptPending {
            automationPromptPending = false
            probeGeneration += 1
        }
    }

    private func handleFocusChange(enabled: Bool, text: String) {
        focusStatusText = text
        focusOn = enabled
        publish()
        onLocalChange?(enabled, text)
    }

    private func importShortcut(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "shortcut") else {
            lastRunText = "Import error: \(name).shortcut is missing from the app bundle."
            publish()
            return
        }
        let opened = NSWorkspace.shared.open(url)
        if !opened {
            lastRunText = "Import error: could not open \(url.lastPathComponent)."
            publish()
            return
        }
        lastRunText = "Import: opened \(name). Tap Add in Shortcuts."
        showShortcutMissingError = false
        publish()
    }

    private func runShortcut(named name: String) {
        lastRunText = "Last run: running \(name)…"
        publish()
        Task {
            let result = await Task.detached {
                ShortcutRunner.run(named: name)
            }.value
            switch result {
            case .success:
                lastRunText = "Last run: \(name) succeeded"
            case .failure(let error):
                lastRunText = "Last run: \(error.localizedDescription)"
            }
            publish()
        }
    }

    private func publish() {
        onStateChange?()
    }
}
