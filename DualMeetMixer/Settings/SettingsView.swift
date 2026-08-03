import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var viewModel: MixerViewModel

    var body: some View {
        Form {
            Section("Labels") {
                TextField("Window A label", text: Binding(
                    get: { preferences.labelA == "Window A" ? "" : preferences.labelA },
                    set: { preferences.labelA = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                TextField("Window B label", text: Binding(
                    get: { preferences.labelB == "Window B" ? "" : preferences.labelB },
                    set: { preferences.labelB = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Text("Default labels are 'Window A' and 'Window B'. Set custom names like 'Google' or 'Apple'.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dead-Man Switch") {
                Stepper(value: Binding(
                    get: { preferences.keepAliveSeconds },
                    set: { preferences.keepAliveSeconds = $0 }
                ), in: 10...60) {
                    Text("Keep-alive timeout: \(preferences.keepAliveSeconds) seconds")
                }
            }

            Section("Hotkeys") {
                HStack {
                    Text("\(preferences.labelA):")
                        .frame(width: 120, alignment: .leading)
                    KeyRecorder(hotKey: Binding(
                        get: { preferences.hotkeyA },
                        set: { preferences.hotkeyA = $0 }
                    ))
                    Spacer()
                    Button("Reset") { preferences.hotkeyA = .leftArrow }
                        .buttonStyle(.bordered)
                }
                HStack {
                    Text("\(preferences.labelB):")
                        .frame(width: 120, alignment: .leading)
                    KeyRecorder(hotKey: Binding(
                        get: { preferences.hotkeyB },
                        set: { preferences.hotkeyB = $0 }
                    ))
                    Spacer()
                    Button("Reset") { preferences.hotkeyB = .rightArrow }
                        .buttonStyle(.bordered)
                }
                HStack {
                    Text("Mute all:")
                        .frame(width: 120, alignment: .leading)
                    KeyRecorder(hotKey: Binding(
                        get: { preferences.hotkeyMuteAll },
                        set: { preferences.hotkeyMuteAll = $0 }
                    ))
                    Spacer()
                    Button("Reset") { preferences.hotkeyMuteAll = .downArrow }
                        .buttonStyle(.bordered)
                }
                Text("Click the key combo to record a new shortcut. Must include at least one modifier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Microphone Input") {
                Picker("Source:", selection: Binding(
                    get: { preferences.inputDeviceUID ?? "" },
                    set: { newValue in
                        preferences.inputDeviceUID = newValue.isEmpty ? nil : newValue
                    }
                )) {
                    Text("(System default)").tag("")
                    ForEach(AudioInputDevice.enumerate(), id: \.uid) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                Text("Pick the microphone source for both meetings (e.g., your headset). Changes apply immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Camera") {
                Toggle(isOn: Binding(
                    get: { preferences.cameraFollowsTalker },
                    set: { newValue in
                        preferences.cameraFollowsTalker = newValue
                        if newValue { viewModel.ensureAccessibilityPermissionIfNeeded() }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Camera follows the active meeting")
                        Text("Sends ⌘E to toggle Meet's camera on the active side and off on the other. Requires Accessibility permission. Assumes both cameras start OFF when DMM launches.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Reset camera state") {
                        viewModel.resetCameraState()
                    }
                    .buttonStyle(.bordered)
                    Text("Click after manually turning both cameras off in Meet, to re-sync DMM's belief.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Mic Mute Mode") {
                Toggle(isOn: Binding(
                    get: { preferences.useCmdDForMicMute },
                    set: { newValue in
                        preferences.useCmdDForMicMute = newValue
                        if newValue { viewModel.ensureAccessibilityPermissionIfNeeded() }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Use ⌘D (Meet's native mute) instead of BlackHole gain")
                        Text("ON: DMM sends ⌘D to mute/unmute the active Meet window — set both Meet mics to your real headset (e.g., Jabra) for natural-sounding voice. OFF: DMM controls audio via BlackHole gain (Meet mics must be BlackHole-A / BlackHole-B). Requires Accessibility permission. Assumes both Meet windows start muted when DMM launches.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Reset mic state") {
                        viewModel.resetMicState()
                    }
                    .buttonStyle(.bordered)
                    Text("Click after manually muting both Meet windows, to re-sync DMM's belief.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle(isOn: Binding(
                    get: { preferences.cmdDBeltAndSuspenders },
                    set: { newValue in
                        preferences.cmdDBeltAndSuspenders = newValue
                        if newValue { viewModel.ensureAccessibilityPermissionIfNeeded() }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Also send ⌘D on every transition (belt-and-suspenders)")
                        Text("Only applies in BlackHole-gain mode. Off by default.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(preferences.useCmdDForMicMute)
            }
        }
        .padding(20)
        .frame(width: 460, height: 600)
    }
}

#Preview {
    SettingsView(preferences: Preferences(), viewModel: MixerViewModel())
}
