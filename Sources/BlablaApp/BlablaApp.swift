import SwiftUI

@main
struct BlablaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.shared

    init() {
        AppController.shared.bootstrap()
    }

    var body: some Scene {
        MenuBarExtra("Blabla", systemImage: controller.menuBarSymbolName) {
            MenuBarContentView()
                .environmentObject(controller)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(controller)
                .frame(width: 600, height: 680)
        }
    }
}
