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
    var notificationsDenied = false
    var focusAccess: FocusStatusAccess = .notDetermined
    var notificationsRequested = false
    var probedAutomation = false
    var automationDenied = false
    var shortcutsProven = false
    var provingShortcuts = false
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
    /// Set by `ProductChrome`. The QR screen only talks to the forwarder
    /// (create the pair, poll for the phone) while someone can see it.
    private(set) var mainWindowVisible = false

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
            notificationsGranted: notificationsGranted,
            automationDenied: automationDenied,
            probedAutomation: probedAutomation,
            onExists: onExists,
            offExists: offExists,
            shortcutsProven: shortcutsProven,
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
    /// Set when the user opens Automation settings from setup, so coming
    /// back runs the shortcuts again instead of waiting for a real Focus flip.
    private var retryProofOnNextActive = false
    private let pathMonitor = NetworkPathMonitor()
    private var readyAtSessionStart: Bool?
    private var coldLaunch = true
    private var offlineTask: Task<Void, Never>?

    private static let hasSeenWelcomeKey = "hasSeenWelcome"
    private static let notifyOnSyncFailureKey = "notifyOnSyncFailure"
    private static let shortcutsProvenKey = "shortcutsProven"

    /// `make test-mac` hosts XCTest inside this app's own process
    /// (`TEST_HOST` in the Xcode project), so this checks the environment
    /// XCTest sets rather than a build setting.
    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        if UserDefaults.standard.bool(forKey: Self.shortcutsProvenKey) {
            focusApply.markShortcutsProven()
        }
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
        apns.onReceive = { [weak self] source, _ in
            Task { @MainActor in
                self?.lastApnsText = "Last APNs: \(source)"
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
        Task {
            await refreshNotificationAuthorization()
            // Installs set up before Focus Status existed were never asked.
            if notificationsGranted, focusAccess == .notDetermined {
                focusAccess = await FocusStatusAccess.request()
            }
        }
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
        shortcutsProven = focusApply.shortcutsProven
        provingShortcuts = focusApply.provingShortcuts
        if shortcutsProven {
            UserDefaults.standard.set(true, forKey: Self.shortcutsProvenKey)
        }
        applyDropped = focusApply.applyDropped
        shortcutStepError = focusApply.shortcutStepError
        showShortcutMissingError = focusApply.showShortcutMissingError
        lastRunText = focusApply.lastRunText
        focusStatusText = focusApply.focusStatusText
        proveShortcutsIfReady()
    }

    /// Once both shortcuts are in Shortcuts, run them before leaving this
    /// step. That is the Apple Event that raises the control prompt.
    /// Skipped under XCTest: the test host is this app, and a proof run
    /// would flip Focus on the machine running `make test-mac`.
    private func proveShortcutsIfReady() {
        guard !Self.isRunningUnderXCTest else { return }
        guard destination == .shortcuts else { return }
        focusApply.proveShortcuts()
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

    func recheckShortcuts() {
        focusApply.prepareShortcutProofRetry()
        probeShortcuts(showMissing: true)
    }

    func becomeActive() {
        refreshLoginItemStatus()
        focusApply.noteBecameActive()
        if retryProofOnNextActive {
            retryProofOnNextActive = false
            focusApply.prepareShortcutProofRetry()
        }
        Task { await refreshNotificationAuthorization() }
        if destination == .shortcuts || destination == .automation || paired {
            probeShortcuts(showMissing: destination == .shortcuts)
        }
        if paired {
            Task { await pair.refreshPairOrUnpair() }
        }
        handleDestination(destination)
    }

    func handleDestination(_ destination: MacDestination) {
        if destination == .shortcuts {
            probeShortcuts(showMissing: true)
        }
        if destination == .qr {
            if apnsTokenHex.isEmpty {
                pair.qrMessage = ProductCopy.waitingApns
                pullPairState()
            } else if !pair.createdPairForCurrentId {
                if mainWindowVisible {
                    Task { await pair.create() }
                }
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
        guard mainWindowVisible, destination == .qr, pair.createdPairForCurrentId, !pair.joined else {
            return
        }
        pair.startPeerPoll { [weak self] in
            guard let self else { return false }
            return self.mainWindowVisible && self.destination == .qr
        }
    }

    func setMainWindowVisible(_ visible: Bool) {
        guard visible != mainWindowVisible else { return }
        mainWindowVisible = visible
        if visible {
            handleDestination(destination)
        } else {
            pair.stopPeerPoll()
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
        retryProofOnNextActive = true
        focusApply.openAutomationSettings()
    }

    func openNotificationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func dismissWelcome() {
        guard !hasSeenWelcome else { return }
        hasSeenWelcome = true
        UserDefaults.standard.set(true, forKey: Self.hasSeenWelcomeKey)
    }

    /// Grant Access screen's Continue action: fires the Automation probe
    /// and requests Notifications, then Focus Status, authorization. Setup
    /// stays on this step until notifications are authorized.
    func requestGrantAccessPermissions() {
        continueAutomation()
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            notificationsRequested = true
            if FocusStatusAccess.current == .notDetermined {
                focusAccess = await FocusStatusAccess.request()
            }
            await refreshNotificationAuthorization()
        }
    }

    func openFocusStatusSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Focus",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Focus",
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func refreshNotificationAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsGranted = settings.authorizationStatus == .authorized
        notificationsDenied = settings.authorizationStatus == .denied
        focusAccess = FocusStatusAccess.current
        if notificationsGranted {
            ApnsPushReceiver.reregisterIfAuthorized()
        }
        refreshOffline()
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
