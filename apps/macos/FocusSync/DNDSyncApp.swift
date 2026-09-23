import SwiftUI

@main
struct DNDSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.openSettingsFromMenuCommand()
                }
                .keyboardShortcut(",")
            }
        }
    }
}
