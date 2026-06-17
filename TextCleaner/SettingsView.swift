import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
            if AppSettings.supportsLaunchAtLogin {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                        Text("Start TextMagician automatically after you log in to macOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show icon in Dock")
                    Text("When off, TextMagician runs as a menu bar app only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settings.showDockIcon)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
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
                Text("Unicode picker")
                Spacer()
                ShortcutRecorder(shortcut: $settings.pickerShortcut)
                    .frame(width: 180, height: 24)
                Button("Reset") {
                    settings.pickerShortcut = AppSettings.defaultPickerShortcut
                }
            }
            HStack {
                Text("Emoji picker")
                Spacer()
                ShortcutRecorder(shortcut: $settings.emojiPickerShortcut)
                    .frame(width: 180, height: 24)
                Button("Reset") {
                    settings.emojiPickerShortcut = AppSettings.defaultEmojiPickerShortcut
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
        .onChangeCompat(of: shortcut) { newValue in
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
                actionsList
                HStack(alignment: .top) {
                    Text("Drag a row by its handle to reorder. The badge (1–9 then a–z) is the keyboard shortcut while the popup is open; positions past the 35th and disabled actions get none. Disabled rows sink below the enabled ones. ⌥-click a gap between two rows to add a separator there (it shows in the popup too); ⌥-click it again to remove it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Reset") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            settings.actionPreferences = AppSettings.defaultActionPreferences
                            settings.separatorAfterKinds = AppSettings.defaultSeparatorAfterKinds
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var actionsList: some View {
        VStack(spacing: 0) {
            dropStrip(slot: 0)
            ForEach(Array(settings.actionPreferences.enumerated()), id: \.element.kind) { index, pref in
                actionRow(pref: pref)
                    .padding(.vertical, 2)
                dropStrip(slot: index + 1)
            }
        }
    }

    private var enabledCount: Int {
        settings.actionPreferences.filter(\.enabled).count
    }

    @ViewBuilder
    private func dropStrip(slot: Int) -> some View {
        // The action immediately above this gap, if any. A separator is
        // anchored to it (⌥-click toggles), so it survives reordering
        // and enable/disable.
        let aboveKind: TextActionKind? = slot >= 1
            && settings.actionPreferences.indices.contains(slot - 1)
            ? settings.actionPreferences[slot - 1].kind
            : nil
        // Only slots within the enabled section (0…enabledCount) can
        // accept a drop. Strips below the enabled/disabled boundary
        // still render at the same height so the layout doesn't jump
        // mid-drag, but they refuse the drop and stay blank.
        DropStripView(
            isValid: slot <= enabledCount,
            hasSeparator: aboveKind.map { settings.separatorAfterKinds.contains($0) } ?? false,
            onDrop: { rawKind in
                guard let kind = TextActionKind(rawValue: rawKind) else { return }
                moveAction(kind: kind, toSlot: slot)
            },
            onOptionClick: {
                guard let kind = aboveKind else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    settings.toggleSeparator(afterKind: kind)
                }
            }
        )
    }

    @ViewBuilder
    private func actionRow(pref: ActionPreference) -> some View {
        let action = TextAction.all.first { $0.kind == pref.kind }
        HStack(spacing: 10) {
            dragHandle(pref: pref, action: action)
            Text(positionLabel(for: pref))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(pref.enabled ? 0.08 : 0.04))
                )
                .foregroundStyle(pref.enabled ? Color.secondary : Color.secondary.opacity(0.5))
            Image(systemName: action?.displayIcon ?? "questionmark")
                .frame(width: 18)
                .foregroundStyle(pref.enabled ? Color.secondary : Color.secondary.opacity(0.5))
            Text(action?.title ?? pref.kind.rawValue)
                .foregroundStyle(pref.enabled ? Color.primary : Color.secondary)
            Spacer()
            Toggle("", isOn: enabledBinding(for: pref.kind))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    /// `line.3.horizontal` is the canonical SF Symbols 4 (macOS 13) name;
    /// on Monterey it renders blank, so use the original `line.horizontal.3`
    /// there. macOS 13+ keeps the canonical glyph.
    private var dragHandleSymbol: String {
        if #available(macOS 13, *) {
            return "line.3.horizontal"
        } else {
            return "line.horizontal.3"
        }
    }

    @ViewBuilder
    private func dragHandle(pref: ActionPreference, action: TextAction?) -> some View {
        let icon = Image(systemName: dragHandleSymbol)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 16, height: 18)
            .contentShape(Rectangle())
        if pref.enabled {
            // `.draggable(_:preview:)` is macOS 13+. On Monterey fall back
            // to `.onDrag` (macOS 11+); same payload (the kind's rawValue
            // as text), only the drag image differs — the system uses a
            // snapshot of the handle instead of our custom card preview.
            if #available(macOS 13, *) {
                icon
                    .foregroundStyle(.secondary)
                    .draggable(pref.kind.rawValue) {
                        dragPreview(pref: pref, action: action)
                    }
            } else {
                icon
                    .foregroundStyle(.secondary)
                    .onDrag { NSItemProvider(object: pref.kind.rawValue as NSString) }
            }
        } else {
            // Greyed out and inert — disabled rows can only be brought
            // back via the toggle, per the user's spec.
            icon
                .foregroundStyle(Color.secondary.opacity(0.25))
                .allowsHitTesting(false)
        }
    }

    private func dragPreview(pref: ActionPreference, action: TextAction?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: action?.displayIcon ?? "questionmark")
            Text(action?.title ?? pref.kind.rawValue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        )
    }

    private func positionLabel(for pref: ActionPreference) -> String {
        guard pref.enabled else { return "·" }
        let enabledKinds = settings.actionPreferences.filter(\.enabled).map(\.kind)
        if let idx = enabledKinds.firstIndex(of: pref.kind) {
            // 1–9 then a–z; positions past that have no shortcut.
            return ActionShortcutKey.label(for: idx) ?? "·"
        }
        return "·"
    }

    private func enabledBinding(for kind: TextActionKind) -> Binding<Bool> {
        Binding(
            get: {
                settings.actionPreferences.first { $0.kind == kind }?.enabled ?? false
            },
            set: { newValue in
                var prefs = settings.actionPreferences
                guard let idx = prefs.firstIndex(where: { $0.kind == kind }) else { return }
                prefs[idx].enabled = newValue
                // normalize() puts a just-disabled row at the start of
                // the disabled section and a just-enabled row at the
                // end of the enabled section — exactly the placement
                // requested by the spec.
                withAnimation(.easeInOut(duration: 0.18)) {
                    settings.actionPreferences = normalize(prefs)
                }
            }
        )
    }

    private func moveAction(kind: TextActionKind, toSlot slot: Int) {
        var prefs = settings.actionPreferences
        guard let sourceIdx = prefs.firstIndex(where: { $0.kind == kind }) else { return }
        let item = prefs.remove(at: sourceIdx)
        // The slot was computed against the original list; after
        // removing the source, indices above it shift down by one.
        let target = slot > sourceIdx ? slot - 1 : slot
        prefs.insert(item, at: min(target, prefs.count))
        withAnimation(.easeInOut(duration: 0.18)) {
            settings.actionPreferences = normalize(prefs)
        }
    }

    private func normalize(_ prefs: [ActionPreference]) -> [ActionPreference] {
        prefs.filter(\.enabled) + prefs.filter { !$0.enabled }
    }

    private var permissionsSection: some View {
        section(title: "Permissions") {
            Text("TextMagician needs the Accessibility permission to paste into the active app. The first time you trigger an action, macOS will ask you to grant access in System Settings → Privacy & Security → Accessibility.")
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

// MARK: - Drag-and-drop strip

/// Thin strip rendered between rows in the actions list. Reports as a
/// drop target via `onDrop`; when the dragged payload hovers
/// over a strip that's inside the enabled section, a horizontal accent
/// bar appears at that position to show where the row will land.
/// Strips below the enabled/disabled boundary stay laid out (so the
/// row spacing doesn't change mid-drag) but refuse the drop.
private struct DropStripView: View {
    let isValid: Bool
    let hasSeparator: Bool
    let onDrop: (String) -> Void
    let onOptionClick: () -> Void
    @State private var isTargeted: Bool = false

    var body: some View {
        Color.clear
            .frame(height: 10)
            .overlay {
                if isTargeted && isValid {
                    // Drag insertion indicator.
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor)
                        .frame(height: 3)
                        .padding(.horizontal, 6)
                } else if hasSeparator {
                    // Persistent user-placed separator.
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.secondary.opacity(0.55))
                        .frame(height: 2)
                        .padding(.horizontal, 6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // ⌥-click toggles a separator in this gap; a plain click
                // is ignored so it doesn't interfere with row dragging.
                if NSEvent.modifierFlags.contains(.option) { onOptionClick() }
            }
            .modifier(ReorderDropTarget(
                isValid: isValid,
                isTargeted: $isTargeted,
                onDrop: onDrop
            ))
    }
}

/// Drop target for the reorder strip. Prefers `.dropDestination`
/// (Transferable, macOS 13+) and falls back to `.onDrop` (macOS 11+) on
/// Monterey, so modern systems use the current API while macOS 12 still
/// works. Both decode the same plain-text payload (a `TextActionKind`
/// rawValue) and report hover via the shared `isTargeted` binding.
private struct ReorderDropTarget: ViewModifier {
    let isValid: Bool
    @Binding var isTargeted: Bool
    let onDrop: (String) -> Void

    func body(content: Content) -> some View {
        if #available(macOS 13, *) {
            content.dropDestination(for: String.self) { items, _ in
                guard isValid, let raw = items.first else { return false }
                onDrop(raw)
                return true
            } isTargeted: { isTargeted = $0 }
        } else {
            // The payload arrives as an NSItemProvider whose text
            // representation we load asynchronously, then hop to the main
            // queue to mutate the model.
            content.onDrop(of: [.text], isTargeted: $isTargeted) { providers in
                guard isValid, let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: String.self) { raw, _ in
                    guard let raw else { return }
                    DispatchQueue.main.async { onDrop(raw) }
                }
                return true
            }
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
