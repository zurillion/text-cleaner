import SwiftUI

struct SettingsView: View {
    @State private var shortcut: KeyboardShortcut = HotKeySettings.current

    var body: some View {
        Form {
            Section {
                LabeledContent("Invoke shortcut") {
                    HStack(spacing: 8) {
                        ShortcutRecorder(shortcut: $shortcut)
                            .frame(width: 180, height: 24)
                        Button("Reset") {
                            shortcut = HotKeySettings.defaultShortcut
                        }
                    }
                }
                Text("Click the field and press the desired key combination. The shortcut must include at least one modifier (⌃, ⌥, ⇧, ⌘).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Hotkey")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(TextAction.all) { action in
                        HStack {
                            Image(systemName: action.icon)
                                .frame(width: 18)
                                .foregroundStyle(.secondary)
                            Text(action.title)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Actions")
            }

            Section {
                Text("Text Cleaner needs the Accessibility permission to paste into the active app. The first time you trigger an action, macOS will ask you to grant access in System Settings → Privacy & Security → Accessibility.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 8)
        .onChange(of: shortcut) { _, newValue in
            HotKeySettings.current = newValue
        }
    }
}

#Preview {
    SettingsView()
}
