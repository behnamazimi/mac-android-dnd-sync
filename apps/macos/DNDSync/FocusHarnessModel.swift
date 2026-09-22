import AppKit
import Foundation
import Observation
import ServiceManagement
import UserNotifications

@Observable
@MainActor
final class FocusHarnessModel {
    var focusStatusText = "Focus: unknown"
    var lastRunText = "Last run: —"
    var lastRemoteCommandText = "Last remote command: —"
    var lanAdvertising = false
    var lanBrowsing = false
    var lanConnected = false
    var lastInboundText = "Last inbound: —"
    var lastLanErrorText = "Last LAN error: —"
    var apnsTokenHex = ""
    var apnsStatusText = "APNs: waiting for token"
    var lastApnsText = "Last APNs: —"
    var forwarderURLText = "Forwarder: —"
    var lastRegisterText = "Last register: —"
    var lastEnvelopePostText = "Last envelope POST: —"
    var lastCloudErrorText = "Last cloud error: —"
    var pairStatusText = "Pair: not created"
    var pairPayloadJSON = ""
    var qrImage: NSImage?

    var hasSeenWelcome = false
    var notifyOnSyncFailure = true {
        didSet {
            UserDefaults.standard.set(notifyOnSyncFailure, forKey: Self.notifyOnSyncFailureKey)
        }
    }
    var notificationsGranted = false
    var notificationsRequested = false
    var probedAutomation = false
    var automationDenied = false
    var onExists = false
    var offExists = false
    var showShortcutMissingError = false
    var loginItemEnabled = SMAppService.mainApp.status == .enabled
    var loginSkipped = false
    var loginItemError: String?
    var showOffline = false
    var pathSatisfied = true
    var focusOn = false
    var pairingExpired = false
    var applyDropped = false
    var qrNeedsRetry = false
    var qrMessage: String?
    var shortcutStepError: String?
    var lastSyncUnixMs: Int64 = 0
    var lastSyncOn = false
    var lastSyncSender = ""
    var lastSyncViaLan = false
    /// Mirrors `PairSession.recentActivity` — Home's "Recent activity" trail,
    /// persisted there so it survives quitting and relaunching the app.
    var recentActivity: [SyncEvent] = []
    /// Copied from pair session in `pullPairState()`. Must be stored so
    /// Observation invalidates `destination` when the user unpairs.
    var paired = false

    var pairIdText: String { pair.pairId }

    var thisDeviceName: String {
        Host.current().localizedName ?? "Mac"
    }

    var peerDeviceName: String { ProductCopy.phoneFallback }

    var destination: MacDestination {
        MacRouting.destination(onboardingProgress)
    }

    var productLastError: String {
        MacRouting.lastError(
            paired: paired,
            pairingExpired: pairingExpired,
            automationDenied: automationDenied,
            onExists: onExists,
            offExists: offExists,
            applyDropped: applyDropped,
            lastCloudError: lastCloudErrorText.replacing("Last cloud error: ", with: ""),
            lastLanError: lastLanErrorText.replacing("Last LAN error: ", with: ""),
            lanBlocking: false
        )
    }

    var apnsReadyText: String {
        if apnsTokenHex.isEmpty {
            return apnsStatusText
        }
        return "APNs: registered"
    }

    private var currentNeedsNetwork: Bool {
        MacRouting.needsNetwork(onboardingProgress)
    }

    var onboardingProgress: OnboardingProgress {
        OnboardingProgress(
            hasSeenWelcome: hasSeenWelcome,
            paired: paired,
            automationDenied: automationDenied,
            probedAutomation: probedAutomation,
            onExists: onExists,
            offExists: offExists,
            loginEnabled: loginItemEnabled,
            loginSkipped: loginSkipped
        )
    }

    private let focusApply = ShortcutsFocusApply()
    private let commandServer = LocalCommandServer()
    private let lanService: LanSyncService
    private let forwarder: ForwarderClient
    private let pair: PairSession
    private let sync: SyncSession
    private var nextImportIsOff = false
    private let pathMonitor = NetworkPathMonitor()
    private var readyAtSessionStart: Bool?
    private var coldLaunch = true
    private var offlineTask: Task<Void, Never>?

    private static let hasSeenWelcomeKey = "hasSeenWelcome"
    private static let notifyOnSyncFailureKey = "notifyOnSyncFailure"

    /// `make test-mac` hosts XCTest inside this app's own process
    /// (`TEST_HOST` in the Xcode project), so this checks the environment
    /// XCTest sets rather than a build setting.
    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        let lan = LanSyncService()
        let forwarder = ForwarderClient()
        let pair = PairSession(
            forwarder: forwarder,
            store: PairStore(),
            apnsToken: { ApnsPushReceiver.shared.deviceTokenHex }
        )
        self.lanService = lan
        self.forwarder = forwarder
        self.pair = pair
        self.sync = SyncSession(lan: lan, cloud: forwarder, pair: pair)
        hasSeenWelcome = UserDefaults.standard.bool(forKey: Self.hasSeenWelcomeKey)
        if UserDefaults.standard.object(forKey: Self.notifyOnSyncFailureKey) != nil {
            notifyOnSyncFailure = UserDefaults.standard.bool(forKey: Self.notifyOnSyncFailureKey)
        }
        focusApply.onLocalChange = { [weak self] enabled, _ in
            self?.pullFocusApplyState()
            self?.sync.onLocalFocusChange(on: enabled)
        }
        focusApply.onStateChange = { [weak self] in
            self?.pullFocusApplyState()
            self?.refreshOffline()
        }
        pullFocusApplyState()
        pair.onStateChange = { [weak self] in
            self?.pullPairState()
            self?.refreshOffline()
            // `create()`/`retryCreate()` run on a detached Task, so this is
            // the one place that reliably notices "just finished creating
            // the pair" and starts the background check — no user tap
            // needed, and no-op if the poll loop is already running.
            self?.maybeStartPeerPoll()
        }
        pair.onPairIdChange = { [weak self] pairId in
            self?.sync.setPairId(pairId)
        }
        pair.onJoined = { [weak self] in
            self?.readyAtSessionStart = true
            self?.sync.startLANIfJoined()
        }
        pair.onCleared = { [weak self] in
            self?.sync.stopLAN()
            self?.readyAtSessionStart = false
        }
        pair.onNotifyPeerUnpair = { [weak self] context in
            await self?.sync.sendUnpair(context)
        }
        sync.onApplyRemote = { [weak self] on in
            guard let self else { return }
            self.focusApply.apply(on: on, notifyOnFailure: self.notifyOnSyncFailure)
            self.pullFocusApplyState()
        }
        sync.onStateChange = { [weak self] in
            self?.pullSyncState()
        }
        commandServer.onCommand = { [weak self] command in
            Task { @MainActor in
                self?.handleRemoteCommand(command)
            }
        }
        let apns = ApnsPushReceiver.shared
        apns.onCommand = { [weak self] command in
            Task { @MainActor in
                self?.handleRemoteCommand(command)
            }
        }
        apns.onReceive = { [weak self] userInfo in
            Task { @MainActor in
                let kind = userInfo["envelope_b64"] != nil ? "envelope" : "received"
                self?.lastApnsText = "Last APNs: \(kind)"
            }
        }
        apns.onJoinedWake = { [weak self] in
            Task { @MainActor in
                guard let self, !self.pair.joined else { return }
                await self.pair.fetchPeer()
            }
        }
        apns.onEnvelope = { [weak self] envelope in
            Task { @MainActor in
                self?.sync.onInboundEnvelope(envelope)
            }
        }
        apns.onEnvelopeError = { [weak self] message in
            Task { @MainActor in
                self?.lastCloudErrorText = "Last cloud error: \(message)"
            }
        }
        apns.onRegistrationChange = { [weak self] in
            Task { @MainActor in
                self?.syncApnsRegistration()
            }
        }
        restorePair()
        syncApnsRegistration()
        // Debug-only, and never under XCTest: a hosted test launches this
        // full app process, and a stray `:8787` listener both fights a
        // previous run for the port and is dead weight the tests don't
        // need. Release must never expose the loopback bypass at all.
        #if DEBUG
        if !Self.isRunningUnderXCTest {
            if !commandServer.start() {
                lastRemoteCommandText = "Last remote command: listener failed to bind :\(LocalCommandServer.portNumber)"
            }
        }
        #endif
        pathMonitor.onChange = { [weak self] satisfied in
            Task { @MainActor in
                self?.handlePath(satisfied)
            }
        }
        pathMonitor.start()
        refreshLoginItemStatus()
        if pair.createdPairForCurrentId || pair.joined {
            loginSkipped = true
            focusApply.assumeShortcutsPresent()
            pullFocusApplyState()
            probeShortcuts(showMissing: false)
            // An already-paired install predates the Welcome screen (or the
            // user simply re-launched) — never show it retroactively.
            dismissWelcome()
        }
        if pair.joined {
            sync.startLANIfJoined()
        }
        readyAtSessionStart = paired
        refreshOffline()
    }

    func importOn() {
        focusApply.importOn()
    }

    func importOff() {
        focusApply.importOff()
    }

    func importShortcuts() {
        if nextImportIsOff {
            importOff()
        } else {
            importOn()
        }
        nextImportIsOff.toggle()
    }

    func turnOn() {
        focusApply.turnOn()
    }

    func turnOff() {
        focusApply.turnOff()
    }

    func copyApnsToken() {
        guard !apnsTokenHex.isEmpty else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(apnsTokenHex, forType: .string)
    }

    func copyPairPayload() {
        guard !pairPayloadJSON.isEmpty else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pairPayloadJSON, forType: .string)
    }

    func createPair() {
        Task {
            await pair.create()
        }
    }

    func rePair(notifyPeer: Bool = true) {
        loginSkipped = true
        focusApply.assumeShortcutsPresent()
        pullFocusApplyState()
        pair.unpair(notifyPeer: notifyPeer)
        refreshOffline()
    }

    private func restorePair() {
        pair.restore()
        pullPairState()
    }

    private func pullFocusApplyState() {
        focusOn = focusApply.focusOn
        onExists = focusApply.onExists
        offExists = focusApply.offExists
        automationDenied = focusApply.automationDenied
        probedAutomation = focusApply.probedAutomation
        applyDropped = focusApply.applyDropped
        shortcutStepError = focusApply.shortcutStepError
        showShortcutMissingError = focusApply.showShortcutMissingError
        lastRunText = focusApply.lastRunText
        focusStatusText = focusApply.focusStatusText
    }

    private func pullPairState() {
        paired = pair.joined
        pairPayloadJSON = pair.pairPayloadJSON
        qrImage = pair.qrImage
        pairStatusText = pair.pairStatusText
        qrMessage = pair.qrMessage
        qrNeedsRetry = pair.qrNeedsRetry
        pairingExpired = pair.pairingExpired
        lastSyncUnixMs = pair.lastSyncUnixMs
        lastSyncOn = pair.lastSyncOn
        lastSyncSender = pair.lastSyncSender
        lastSyncViaLan = pair.lastSyncViaLan
        recentActivity = pair.recentActivity
        lastRegisterText = pair.lastRegisterText
        lastCloudErrorText = pair.lastCloudErrorText
        forwarderURLText = pair.forwarderURLText
    }

    private func pullSyncState() {
        lanAdvertising = sync.lanAdvertising
        lanBrowsing = sync.lanBrowsing
        lanConnected = sync.lanConnected
        lastInboundText = sync.lastInboundText
        lastLanErrorText = sync.lastLanErrorText
        lastEnvelopePostText = sync.lastEnvelopePostText
    }

    private func syncApnsRegistration() {
        let apns = ApnsPushReceiver.shared
        if let error = apns.registrationError {
            apnsStatusText = "APNs: \(error)"
            apnsTokenHex = ""
            return
        }
        if apns.deviceTokenHex.isEmpty {
            apnsStatusText = "APNs: waiting for token"
            apnsTokenHex = ""
            return
        }
        apnsTokenHex = apns.deviceTokenHex
        apnsStatusText = "APNs: registered"
        pair.refreshPayload()
        pullPairState()
        Task {
            await pair.registerDevice()
        }
        handleDestination(destination)
    }

    private func handleRemoteCommand(_ command: String) {
        lastRemoteCommandText = "Last remote command: \(command)"
        switch command {
        case "on":
            turnOn()
        case "off":
            turnOff()
        default:
            break
        }
    }

    func continueAutomation() {
        focusApply.continueAutomation()
    }

    func probeShortcuts(showMissing: Bool = true) {
        focusApply.probe(showMissing: showMissing)
        refreshOffline()
    }

    func becomeActive() {
        refreshLoginItemStatus()
        focusApply.noteBecameActive()
        if destination == .shortcuts || destination == .automation || paired {
            probeShortcuts(showMissing: destination == .shortcuts)
        }
        if paired {
            Task { await pair.refreshPairOrUnpair() }
        }
        handleDestination(destination)
    }

    func handleDestination(_ destination: MacDestination) {
        if destination == .qr {
            if apnsTokenHex.isEmpty {
                pair.qrMessage = ProductCopy.waitingApns
                pullPairState()
            } else if !pair.createdPairForCurrentId {
                Task { await pair.create() }
            } else if pair.qrMessage == nil || pair.qrMessage == ProductCopy.waitingApns {
                pair.qrMessage = ProductCopy.waitingPhone
                pullPairState()
            }
            if pair.createdPairForCurrentId, pair.qrImage == nil {
                pair.refreshPayload()
                pullPairState()
            }
            maybeStartPeerPoll()
        } else {
            pair.stopPeerPoll()
        }
        refreshOffline()
    }

    /// Background check for the phone joining — runs automatically once a
    /// pair exists, instead of behind a manual "Check again" tap.
    /// `startPeerPoll` no-ops if a poll loop is already running.
    private func maybeStartPeerPoll() {
        guard destination == .qr, pair.createdPairForCurrentId, !pair.joined else {
            return
        }
        pair.startPeerPoll { [weak self] in
            self?.destination == .qr
        }
    }

    func retryCreatePair() {
        Task { await pair.retryCreate() }
    }

    func enableLoginItem() {
        do {
            try SMAppService.mainApp.register()
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        refreshLoginItemStatus()
        refreshOffline()
    }

    func skipLoginItem() {
        loginSkipped = true
        refreshOffline()
    }

    /// Settings screen's "Launch at login" toggle, turned off. Distinct from
    /// `skipLoginItem()` (the onboarding step's "Skip for now", which never
    /// registered in the first place) — this actively unregisters.
    func disableLoginItem() {
        do {
            try SMAppService.mainApp.unregister()
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        refreshLoginItemStatus()
    }

    func refreshLoginItemStatus() {
        loginItemEnabled = SMAppService.mainApp.status == .enabled
    }

    func openAutomationSettings() {
        focusApply.openAutomationSettings()
    }

    func dismissWelcome() {
        guard !hasSeenWelcome else { return }
        hasSeenWelcome = true
        UserDefaults.standard.set(true, forKey: Self.hasSeenWelcomeKey)
    }

    /// Grant Access screen's Continue action: fires the Automation probe
    /// (same as the old standalone "Allow Shortcuts" step) and, in the same
    /// tap, requests Notifications authorization — both permissions are
    /// pre-explained together on that screen before either system prompt fires.
    func requestGrantAccessPermissions() {
        continueAutomation()
        Task {
            let granted = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            notificationsGranted = granted ?? false
            notificationsRequested = true
        }
    }

    private func handlePath(_ satisfied: Bool) {
        pathSatisfied = satisfied
        refreshOffline()
    }

    private func refreshOffline() {
        if pathSatisfied {
            offlineTask?.cancel()
            offlineTask = nil
            showOffline = false
            if coldLaunch { coldLaunch = false }
            return
        }
        if !currentNeedsNetwork {
            offlineTask?.cancel()
            offlineTask = nil
            if coldLaunch { coldLaunch = false }
            return
        }
        if showOffline {
            if coldLaunch { coldLaunch = false }
            return
        }
        if coldLaunch {
            showOffline = true
            coldLaunch = false
            return
        }
        if offlineTask != nil { return }
        offlineTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !self.pathSatisfied && self.currentNeedsNetwork {
                self.showOffline = true
            }
            self.offlineTask = nil
        }
    }
}
