import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var shortcut: KeyboardShortcut = HotKeySettings.current

    private let themeColumns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                generalSection
                hotkeySection
                themeSection
                actionsSection
                permissionsSection
            }
            .padding(20)
        }
        .frame(width: 500, height: 560)
    }

    // MARK: - Sections

    private var generalSection: some View {
        section(title: "General") {
            Toggle(isOn: $settings.showDockIcon) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show icon in Dock")
                    Text("When off, Text Cleaner runs as a menu bar app only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var hotkeySection: some View {
        section(title: "Shortcuts") {
            HStack {
                Text("Invoke")
                Spacer()
                ShortcutRecorder(shortcut: $shortcut)
                    .frame(width: 180, height: 24)
                Button("Reset") {
                    shortcut = HotKeySettings.defaultShortcut
                }
            }
            HStack {
                Text("Re-center popup")
                Spacer()
                ShortcutRecorder(shortcut: $settings.centerShortcut)
                    .frame(width: 180, height: 24)
                Button("Reset") {
                    settings.centerShortcut = AppSettings.defaultCenterShortcut
                }
            }
            Text("Click a field and press the desired combination. Must include at least one modifier (⌃, ⌥, ⇧, ⌘). The re-center shortcut only fires while the popup is open.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: shortcut) { _, newValue in
            HotKeySettings.current = newValue
        }
    }

    private var themeSection: some View {
        section(title: "Theme") {
            LazyVGrid(columns: themeColumns, spacing: 12) {
                ForEach(PopupTheme.allCases) { theme in
                    ThemeSwatch(
                        theme: theme,
                        isSelected: settings.theme == theme
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        settings.theme = theme
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        section(title: "Actions") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(TextAction.all.enumerated()), id: \.element.id) { index, action in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .frame(width: 18, height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.08))
                            )
                            .foregroundStyle(.secondary)
                        Image(systemName: action.icon)
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        Text(action.title)
                        Spacer()
                    }
                }
            }
        }
    }

    private var permissionsSection: some View {
        section(title: "Permissions") {
            Text("Text Cleaner needs the Accessibility permission to paste into the active app. The first time you trigger an action, macOS will ask you to grant access in System Settings → Privacy & Security → Accessibility.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Layout helpers

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Theme swatch

private struct ThemeSwatch: View {
    let theme: PopupTheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.background)
                    .overlay(
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.accent)
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.foreground.opacity(0.3))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.foreground.opacity(0.3))
                                .frame(height: 6)
                        }
                        .padding(8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : theme.borderTint,
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
            }
            .frame(height: 56)

            Text(theme.displayName)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings.shared)
}
