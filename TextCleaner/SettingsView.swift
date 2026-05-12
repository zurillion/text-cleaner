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
                ForEach(Array(settings.actionPreferences.enumerated()), id: \.element.kind) { index, pref in
                    actionRow(index: index, pref: pref)
                }
                HStack {
                    Text("The number is the keyboard shortcut while the popup is open. Disabled actions don't get a number; reordering changes which one is 1, 2, 3, …")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Reset") {
                        settings.actionPreferences = AppSettings.defaultActionPreferences
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func actionRow(index: Int, pref: ActionPreference) -> some View {
        let action = TextAction.all.first { $0.kind == pref.kind }
        let position = positionLabel(for: pref)
        let count = settings.actionPreferences.count
        HStack(spacing: 10) {
            Text(position)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(pref.enabled ? 0.08 : 0.04))
                )
                .foregroundStyle(pref.enabled ? Color.secondary : Color.secondary.opacity(0.5))
            Image(systemName: action?.icon ?? "questionmark")
                .frame(width: 18)
                .foregroundStyle(pref.enabled ? Color.secondary : Color.secondary.opacity(0.5))
            Text(action?.title ?? pref.kind.rawValue)
                .foregroundStyle(pref.enabled ? Color.primary : Color.secondary)
            Spacer()
            Button {
                move(from: index, to: index - 1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            Button {
                move(from: index, to: index + 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == count - 1)
            Toggle("", isOn: enabledBinding(for: pref.kind))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    private func positionLabel(for pref: ActionPreference) -> String {
        guard pref.enabled else { return "·" }
        let enabledKinds = settings.actionPreferences.filter(\.enabled).map(\.kind)
        if let idx = enabledKinds.firstIndex(of: pref.kind) {
            return "\(idx + 1)"
        }
        return "·"
    }

    private func enabledBinding(for kind: TextActionKind) -> Binding<Bool> {
        Binding(
            get: {
                settings.actionPreferences.first { $0.kind == kind }?.enabled ?? false
            },
            set: { newValue in
                guard let idx = settings.actionPreferences.firstIndex(where: { $0.kind == kind })
                else { return }
                settings.actionPreferences[idx].enabled = newValue
            }
        )
    }

    private func move(from source: Int, to destination: Int) {
        var prefs = settings.actionPreferences
        guard prefs.indices.contains(source),
              prefs.indices.contains(destination),
              source != destination else { return }
        let moved = prefs.remove(at: source)
        prefs.insert(moved, at: destination)
        settings.actionPreferences = prefs
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
