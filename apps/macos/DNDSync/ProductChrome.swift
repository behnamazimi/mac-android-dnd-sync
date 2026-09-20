import AppKit
import Observation
import SwiftUI

struct ChromeActions {
    var openSettings: () -> Void = {}
    var closeSettings: () -> Void = {}
    var openDiagnostics: () -> Void = {}
}

private enum ChromeActionsKey: EnvironmentKey {
    static let defaultValue = ChromeActions()
}

extension EnvironmentValues {
    var chromeActions: ChromeActions {
        get { self[ChromeActionsKey.self] }
        set { self[ChromeActionsKey.self] = newValue }
    }
}

/// Sticky close row for overlay panels. Pass a title for Settings; leave it
/// empty for informational panels where the heading lives in the content.
struct SheetCloseHeader: View {
    var title: String = ""
    var close: () -> Void

    var body: some View {
        HStack {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            Spacer()
            Button(ProductCopy.close, systemImage: "xmark.circle.fill", action: close)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.title3)
                .foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction)
                .help(ProductCopy.close)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, title.isEmpty ? 0 : 4)
    }
}

/// In-window card + dimming scrim. System modal sheets swallow clicks on the
/// parent, so click-outside has to be a real view behind the card.
struct DismissibleOverlay<Content: View>: View {
    var onDismiss: () -> Void
    /// Settings should fill up to the cap so its form can scroll. Informational
    /// sheets hug their copy instead of stretching to that same height.
    var hugContent: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            let cap = geo.size.height * 0.8
            ZStack {
                Color.black.opacity(0.28)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityHidden(true)

                // `frame(maxHeight:)` is flexible — in a full-size ZStack it
                // grows to the cap. Hugging cards skip that so they size to
                // copy; ViewThatFits then falls back to a capped scroller
                // instead of clipping a line of text in half.
                Group {
                    if hugContent {
                        ViewThatFits(in: .vertical) {
                            sheetChrome(content.fixedSize(horizontal: false, vertical: true))
                            sheetChrome(
                                ScrollView {
                                    content.fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxHeight: cap)
                            )
                        }
                    } else {
                        sheetChrome(content.frame(maxHeight: cap))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onExitCommand(perform: onDismiss)
    }

    private func sheetChrome<V: View>(_ view: V) -> some View {
        view
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
    }
}

@Observable
final class ProductPresentation {
    var settingsPresented = false
}

/// Owns the app's status item and windows. Renamed in spirit (this is no
/// longer *only* menu-bar chrome) but kept as `ProductChrome` / this file to
/// avoid an Xcode project reference churn. Shows/hides two plain top-level
/// `NSWindow`s — the main flow and (Debug builds only) a standalone
/// Diagnostics window — plus Settings, presented as an overlay on the
/// main window rather than a window of its own. AppKit `NSWindow`, not a
/// SwiftUI `WindowGroup`/`Window` scene: plain windows we show/hide on
/// demand are a smaller, more predictable surface than juggling SwiftUI's
/// scene lifecycle for this.
///
/// The Dock icon and the status-bar icon are complementary, not
/// alternatives: the status item is always present (a stable place to
/// reopen the app), while the Dock icon/app-switcher entry only appears
/// while a window is actually open — accessory-app-style — so a fully
/// dismissed app doesn't linger in the Dock.
@MainActor
final class ProductChrome: NSObject, NSWindowDelegate {
    let model = FocusHarnessModel()
    let presentation = ProductPresentation()

    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    #if DEBUG
    private var diagnosticsWindow: NSWindow?
    #endif

    override init() {
        super.init()
        installStatusItem()
        showMainWindow()
        observeDestination()
    }

    func becomeActive() {
        model.becomeActive()
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.makeStatusBarImage()
            button.toolTip = ProductCopy.appName
            button.setAccessibilityLabel(ProductCopy.appName)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    /// Template brand mark (moon + sync) so the system tints it for light and
    /// dark menu bars. Catalog image is 18pt @1x / 36pt @2x.
    private static func makeStatusBarImage() -> NSImage {
        let image: NSImage
        if let named = NSImage(named: "StatusBarIcon")?.copy() as? NSImage {
            image = named
        } else if let fallback = NSImage(
            systemSymbolName: "moon.stars",
            accessibilityDescription: ProductCopy.appName
        ) {
            image = fallback
        } else {
            image = NSImage(size: NSSize(width: 18, height: 18))
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent, event.type == .rightMouseUp else {
            showMainWindow()
            return
        }
        // Hiding the Dock icon when every window is closed means Cmd+Q isn't
        // always reachable from the app menu — this menu is the fallback way
        // to quit, and to reopen without needing the Dock.
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Open \(ProductCopy.appName)",
            action: #selector(openFromStatusMenu),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(ProductCopy.appName)", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func openFromStatusMenu() {
        showMainWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Windows

    func showMainWindow() {
        if let mainWindow {
            orderFrontAppWindow(mainWindow)
            return
        }
        let window = makeWindow(
            title: Self.windowTitle(for: model.destination),
            size: NSSize(width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            content: hosted(MainChromeView(model: model, presentation: presentation))
        )
        // Content min, not frame min: `minSize` includes the title bar, so a
        // 420-pt floor there leaves ~392 pt for SwiftUI and clips Home's
        // "How does this work?" inset (and the help sheet) in half.
        window.contentMinSize = NSSize(
            width: ProductWindowMetrics.minWidth,
            height: ProductWindowMetrics.minHeight
        )
        mainWindow = window
        orderFrontAppWindow(window)
    }

    /// Onboarding steps show "Set up DND Sync" in the title bar. Welcome
    /// and the everyday Home screen just show the app name.
    private static func windowTitle(for destination: MacDestination) -> String {
        switch destination {
        case .welcome, .status:
            return ProductCopy.appName
        case .automation, .shortcuts, .loginItem, .qr:
            return "Set up \(ProductCopy.appName)"
        }
    }

    /// Keeps the main window's title in sync with the onboarding step /
    /// Home, mirroring the design's title-bar text per screen.
    private func observeDestination() {
        withObservationTracking {
            _ = model.destination
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.mainWindow?.title = Self.windowTitle(for: self.model.destination)
                self.observeDestination()
            }
        }
    }

    /// Settings is an overlay on the main window, not a system sheet —
    /// opening it always brings the main window forward first. A real
    /// dimming view behind the card is what makes click-outside work.
    func showSettings() {
        showMainWindow()
        presentation.settingsPresented = true
    }

    private func closeSettingsSheet() {
        presentation.settingsPresented = false
    }

    #if DEBUG
    private func showDiagnostics() {
        if let diagnosticsWindow {
            orderFrontAppWindow(diagnosticsWindow)
            return
        }
        let window = makeWindow(
            title: ProductCopy.diagnostics,
            size: NSSize(width: 640, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            content: hosted(DiagnosticsScreen(model: model))
        )
        diagnosticsWindow = window
        orderFrontAppWindow(window)
    }
    #endif

    /// Accessory apps (no Dock icon) are not given key-window status, so
    /// `makeKeyAndOrderFront` + `activate()` while still `.accessory` is
    /// what left the Dock icon showing with the window still behind.
    /// Flip to `.regular` first, then raise. `orderFrontRegardless` covers
    /// the already-visible-but-behind case where cooperative `activate()`
    /// is ignored.
    private func orderFrontAppWindow(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        raiseAppWindow(window)
        // Policy changes land on the next turn; raise again once AppKit
        // has a Dock icon, otherwise the first click can still lose.
        Task { @MainActor [weak self, weak window] in
            guard let self, let window else { return }
            // Don't resurrect a window the user already dismissed.
            guard window.isVisible || window.isMiniaturized else { return }
            self.raiseAppWindow(window)
        }
    }

    private func raiseAppWindow(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate()
    }

    /// Whether any of our top-level windows is currently visible — the sole
    /// input to `updateActivationPolicy()`. Settings is an overlay on
    /// `mainWindow`, so it's never visible while `mainWindow` isn't.
    private func windowsVisible() -> Bool {
        if mainWindow?.isVisible == true { return true }
        #if DEBUG
        if diagnosticsWindow?.isVisible == true { return true }
        #endif
        return false
    }

    /// Dock icon / Cmd+Tab entry tracks window visibility: present while any
    /// window is open, hidden once everything is closed (the status item
    /// stays put regardless, as the stable way back in).
    private func updateActivationPolicy() {
        NSApp.setActivationPolicy(windowsVisible() ? .regular : .accessory)
    }

    private func hosted<Content: View>(_ content: Content) -> some View {
        content.environment(\.chromeActions, ChromeActions(
            openSettings: { [weak self] in self?.showSettings() },
            closeSettings: { [weak self] in self?.closeSettingsSheet() },
            openDiagnostics: { [weak self] in
                #if DEBUG
                self?.showDiagnostics()
                #endif
            }
        ))
    }

    private func makeWindow<Content: View>(
        title: String,
        size: NSSize,
        styleMask: NSWindow.StyleMask,
        content: Content
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = title
        // Kept alive and just hidden on close (see `windowShouldClose`), not
        // torn down — syncing must keep running whether or not any window is
        // currently visible, so there's nothing to release.
        window.isReleasedWhenClosed = false
        // Status-item clicks should surface the window on the Space the
        // user is looking at, not leave it stranded on an old one.
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.center()
        window.contentView = NSHostingView(rootView: content)
        window.delegate = self
        return window
    }

    /// Closing any of these windows (red traffic light or ⌘W) hides it
    /// rather than destroying it — the sync engine (LAN listener, APNs
    /// handling, command server) lives on the same process regardless of
    /// which windows are open, so there's no reason a close should tear
    /// anything down. Quitting the app is a separate, explicit action
    /// (⌘Q / app menu Quit), unaffected by this.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === mainWindow {
            presentation.settingsPresented = false
        }
        sender.orderOut(nil)
        updateActivationPolicy()
        return false
    }
}

private struct MainChromeView: View {
    @Bindable var model: FocusHarnessModel
    var presentation: ProductPresentation
    @Environment(\.chromeActions) private var chrome

    var body: some View {
        ProductRootView(model: model)
            .overlay {
                if presentation.settingsPresented {
                    DismissibleOverlay(onDismiss: chrome.closeSettings) {
                        SettingsScreen(model: model)
                    }
                }
            }
            // Settings is a Home overlay. Pair again / Unpair / a peer
            // unpair all leave Home for the QR step; don't keep the sheet
            // sitting on top of that.
            .onChange(of: model.destination) { _, _ in
                chrome.closeSettings()
            }
    }
}
