import SwiftUI

final class PopupViewModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var showsPreview: Bool = false
    @Published var isEditing: Bool = false
    @Published var editedAttributed: NSAttributedString = NSAttributedString()

    let actions: [TextAction]
    var sourceAttributed: NSAttributedString = NSAttributedString()

    init(actions: [TextAction]) {
        self.actions = actions
    }

    func moveUp() {
        guard !actions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + actions.count) % actions.count
    }

    func moveDown() {
        guard !actions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % actions.count
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

    var body: some View {
        let theme = settings.theme
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Cleaner")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondaryForeground)
                .padding(.horizontal, 6)
                .padding(.top, 2)

            VStack(spacing: 2) {
                ForEach(Array(model.actions.enumerated()), id: \.element.id) { index, action in
                    row(index: index, action: action, theme: theme)
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
    }

    @ViewBuilder
    private func row(index: Int, action: TextAction, theme: PopupTheme) -> some View {
        let isSelected = index == model.selectedIndex
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected
                              ? theme.onAccent.opacity(0.25)
                              : theme.chipBackground)
                )
                .foregroundStyle(isSelected ? theme.onAccent : theme.secondaryForeground)

            Image(systemName: action.icon)
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
            if hovering && !model.isEditing { model.selectedIndex = index }
        }
        .onTapGesture {
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
