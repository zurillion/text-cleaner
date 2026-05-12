import SwiftUI

struct PreviewView: View {
    @ObservedObject var model: PopupViewModel
    @ObservedObject var settings: AppSettings
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let onBeginEdit: () -> Void

    var body: some View {
        let theme = settings.theme
        VStack(alignment: .leading, spacing: 8) {
            header(theme: theme)
            content(theme: theme)
            if model.isEditing {
                buttons(theme: theme)
            }
        }
        .padding(10)
        .frame(
            minWidth: 320, idealWidth: 420, maxWidth: .infinity,
            minHeight: 220, idealHeight: 320, maxHeight: .infinity
        )
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

    // MARK: - Subviews

    private func header(theme: PopupTheme) -> some View {
        HStack(spacing: 10) {
            Text(model.isEditing ? "Edit" : "Preview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondaryForeground)
            Spacer()
            if !model.isEditing {
                hint(key: "⇥", label: "Edit", theme: theme)
            } else {
                hint(key: "⌘T", label: "Style", theme: theme)
                hint(key: "⇧↩", label: "Confirm", theme: theme)
                hint(key: "⎋", label: "Cancel", theme: theme)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    private func content(theme: PopupTheme) -> some View {
        let attributed: NSAttributedString = {
            if model.isEditing { return model.editedAttributed }
            let value = model.currentPreviewAttributed
            return value.length == 0 ? NSAttributedString(string: "—") : value
        }()

        return RichTextView(
            attributedString: attributed,
            isEditable: model.isEditing,
            theme: theme,
            onChange: model.isEditing ? { newValue in
                model.editedAttributed = newValue
            } : nil,
            onBeginEditRequested: model.isEditing ? nil : onBeginEdit
        )
        .frame(minHeight: 160, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.foreground.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            model.isEditing
                                ? theme.accent.opacity(0.6)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
    }

    private func buttons(theme: PopupTheme) -> some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Annulla", action: onCancel)
            Button("Conferma", action: onConfirm)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 2)
    }

    private func hint(key: String, label: String, theme: PopupTheme) -> some View {
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
