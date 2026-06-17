import SwiftUI

/// Maps a row position to its keyboard shortcut and back. Positions
/// 0–8 use the digits 1–9, positions 9–34 use the letters a–z, and
/// anything past that gets no shortcut (the action is still usable by
/// arrow + Return or mouse).
enum ActionShortcutKey {
    private static let letterCount = 26  // a–z

    /// The label shown in the row badge, or nil when the position has
    /// no shortcut.
    static func label(for index: Int) -> String? {
        switch index {
        case 0..<9:
            return String(index + 1)
        case 9..<(9 + letterCount):
            return String(UnicodeScalar(UInt8(97 + (index - 9))))  // 'a' = 97
        default:
            return nil
        }
    }

    /// The 0-based action index a typed character selects, or nil if the
    /// character isn't a shortcut key. Digits 1–9 → 0–8, letters a–z
    /// (case-insensitive) → 9–34.
    static func index(for character: Character) -> Int? {
        if let digit = character.wholeNumberValue, (1...9).contains(digit) {
            return digit - 1
        }
        guard let lower = character.lowercased().unicodeScalars.first,
              lower.value >= 97, lower.value <= 122 else {
            return nil
        }
        return 9 + Int(lower.value - 97)
    }
}

final class PopupViewModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var showsPreview: Bool = false
    @Published var isEditing: Bool = false
    @Published var editedAttributed: NSAttributedString = NSAttributedString()
    @Published var actions: [TextAction] = [] {
        didSet {
            if selectedIndex >= actions.count {
                selectedIndex = max(0, actions.count - 1)
            }
        }
    }
    /// Indices into `actions` after which a separator line is drawn.
    @Published var separatorAfterIndex: Set<Int> = []

    var sourceAttributed: NSAttributedString = NSAttributedString()

    /// True when the most recent `selectedIndex` change came from
    /// keyboard navigation. Mouse hover sets it false so the list
    /// doesn't auto-scroll and "chase" the cursor — a hovered row is by
    /// definition already visible.
    var selectionFromKeyboard = false

    /// Hover events are ignored until this instant. Keyboard navigation
    /// pushes it a little into the future so that rows sliding under a
    /// *stationary* cursor during the scroll don't hijack the selection
    /// (which otherwise makes arrow-key nav fight the mouse).
    var ignoreHoverUntil: Date = .distantPast

    func moveUp() {
        guard !actions.isEmpty else { return }
        selectionFromKeyboard = true
        ignoreHoverUntil = Date().addingTimeInterval(0.25)
        selectedIndex = (selectedIndex - 1 + actions.count) % actions.count
    }

    func moveDown() {
        guard !actions.isEmpty else { return }
        selectionFromKeyboard = true
        ignoreHoverUntil = Date().addingTimeInterval(0.25)
        selectedIndex = (selectedIndex + 1) % actions.count
    }

    func moveToStart() {
        guard !actions.isEmpty else { return }
        selectionFromKeyboard = true
        ignoreHoverUntil = Date().addingTimeInterval(0.25)
        selectedIndex = 0
    }

    func moveToEnd() {
        guard !actions.isEmpty else { return }
        selectionFromKeyboard = true
        ignoreHoverUntil = Date().addingTimeInterval(0.25)
        selectedIndex = actions.count - 1
    }

    /// Attributed text shown in the preview pane for the current state.
    var currentPreviewAttributed: NSAttributedString {
        if isEditing { return editedAttributed }
        guard actions.indices.contains(selectedIndex) else {
            return NSAttributedString()
        }
        return actions[selectedIndex].transform(sourceAttributed)
    }
}

struct PopupView: View {
    @ObservedObject var model: PopupViewModel
    @ObservedObject var settings: AppSettings
    let onSelect: (TextAction) -> Void
    let onDragBegan: (NSPoint) -> Void
    let onDragChanged: (NSPoint) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        let theme = settings.theme
        VStack(alignment: .leading, spacing: 8) {
            titleBar(theme: theme)

            // ~10 rows fit before scrolling kicks in. Once the user
            // enables more actions than that, the list scrolls instead
            // of pushing the popup off-screen, and the selection auto-
            // scrolls into view as the user moves with arrow keys.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(model.actions.enumerated()), id: \.element.id) { index, action in
                            row(index: index, action: action, theme: theme)
                                .id(action.id)
                            if model.separatorAfterIndex.contains(index) {
                                separatorLine(theme: theme)
                            }
                        }
                    }
                }
                .frame(maxHeight: 360)
                .modifier(AutomaticScrollIndicatorsIfAvailable())
                .onChangeCompat(of: model.selectedIndex) { newValue in
                    // Only follow keyboard navigation. Hover-driven
                    // selection must not scroll, or the list chases the
                    // cursor (the hovered row is already on screen).
                    guard model.selectionFromKeyboard else { return }
                    guard model.actions.indices.contains(newValue) else { return }
                    // anchor: nil scrolls the minimum needed to reveal the
                    // row (a no-op when it's already visible), and no
                    // withAnimation so held-key repeats don't stack
                    // overlapping scroll animations and flicker.
                    proxy.scrollTo(model.actions[newValue].id, anchor: nil)
                }
            }

            HStack(spacing: 10) {
                hint("⎵", "Preview")
                hint("⇥", "Edit")
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 2)
        }
        .padding(10)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.borderTint, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        )
        .preferredColorScheme(theme.preferredColorScheme)
    }

    @ViewBuilder
    private func titleBar(theme: PopupTheme) -> some View {
        HStack {
            Text("TextMagician")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondaryForeground)
                .allowsHitTesting(false)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 22)
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .background(
            WindowDragHandle(
                onBegan: onDragBegan,
                onChanged: onDragChanged,
                onEnded: onDragEnded
            )
        )
    }

    private func separatorLine(theme: PopupTheme) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(theme.foreground.opacity(0.25))
            .frame(height: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
    }

    @ViewBuilder
    private func row(index: Int, action: TextAction, theme: PopupTheme) -> some View {
        let isSelected = index == model.selectedIndex
        HStack(spacing: 10) {
            Text(ActionShortcutKey.label(for: index) ?? "")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected
                              ? theme.onAccent.opacity(0.25)
                              : theme.chipBackground)
                )
                .foregroundStyle(isSelected ? theme.onAccent : theme.secondaryForeground)

            Image(systemName: action.displayIcon)
                .frame(width: 16)
                .foregroundStyle(isSelected ? theme.onAccent : theme.foreground)

            Text(action.title)
                .foregroundStyle(isSelected ? theme.onAccent : theme.foreground)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? theme.accent : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            // Ignore hover that fires merely because a row slid under a
            // stationary cursor during a keyboard scroll.
            guard hovering, !model.isEditing, Date() >= model.ignoreHoverUntil
            else { return }
            model.selectionFromKeyboard = false
            model.selectedIndex = index
        }
        .onTapGesture {
            // Don't let a stray click on the main popup discard an
            // in-progress edit. The user must explicitly Annulla / Esc /
            // Conferma / ⇧Return to leave edit mode.
            guard !model.isEditing else { return }
            onSelect(action)
        }
    }

    @ViewBuilder
    private func hint(_ key: String, _ label: String) -> some View {
        let theme = settings.theme
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.foreground.opacity(0.10))
                )
            Text(label)
                .font(.system(size: 10))
        }
        .foregroundStyle(theme.secondaryForeground)
    }
}

/// Applies `.scrollIndicators(.automatic)` on macOS 13+ and is a no-op
/// on earlier systems (where `scrollIndicators` doesn't exist). The
/// default ScrollView behavior on macOS 12 already matches `.automatic`
/// — indicators appear during interaction and fade out — so dropping
/// the modifier on Monterey doesn't change the visible result.
private struct AutomaticScrollIndicatorsIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 13, *) {
            content.scrollIndicators(.automatic)
        } else {
            content
        }
    }
}

extension View {
    /// Version-tolerant `onChange`. Uses the current two-parameter API on
    /// macOS 14+ (where the single-parameter `onChange(of:perform:)` is
    /// deprecated) and the original single-parameter form on macOS 12–13.
    /// Modern systems stay on the non-deprecated path, so if a future
    /// macOS ever drops the old API it only affects the branch those
    /// systems never execute.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform action: @escaping (V) -> Void
    ) -> some View {
        if #available(macOS 14, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            // Reached only on macOS 12–13. The single-parameter overload is
            // deprecated as of macOS 14 (hence the gate above); the one
            // deprecation warning this line emits is the cost of the
            // back-deployment and is intentional.
            onChange(of: value, perform: action)
        }
    }
}
