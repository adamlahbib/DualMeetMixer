import SwiftUI

@main
struct DualMeetMixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences = Preferences.shared

    var body: some Scene {
        Settings {
            SettingsView(preferences: preferences, viewModel: appDelegate.viewModel)
        }
    }
}
