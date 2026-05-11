import SwiftUI

struct PreviewView: View {
    @ObservedObject var model: PopupViewModel
    @ObservedObject var settings: AppSettings
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @FocusState private var editorFocused: Bool

    var body: some View {
        let theme = settings.theme
        VStack(alignment: .leading, spacing: 8) {
            header(theme: theme)

            if model.isEditing {
                editor(theme: theme)
                buttons(theme: theme)
            } else {
                viewer(theme: theme)
            }
        }
        .padding(10)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.borderTint, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        )
        .onChange(of: model.isEditing) { _, editing in
            // Defer to next runloop so the TextEditor exists when we focus it.
            DispatchQueue.main.async { editorFocused = editing }
        }
    }

    // MARK: - Subviews

    private func header(theme: PopupTheme) -> some View {
        HStack {
            Text(model.isEditing ? "Edit" : "Preview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondaryForeground)
            Spacer()
            if !model.isEditing {
                hint(key: "⇥", label: "Edit", theme: theme)
            } else {
                hint(key: "⇧↩", label: "Confirm", theme: theme)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    private func viewer(theme: PopupTheme) -> some View {
        ScrollView {
            Text(displayText.isEmpty ? "—" : displayText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(displayText.isEmpty ? theme.secondaryForeground : theme.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(10)
        }
        .frame(minHeight: 140, maxHeight: 360)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.foreground.opacity(0.06))
        )
    }

    private func editor(theme: PopupTheme) -> some View {
        TextEditor(text: $model.editedText)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(theme.foreground)
            .scrollContentBackground(.hidden)
            .focused($editorFocused)
            .padding(6)
            .frame(minHeight: 140, maxHeight: 360)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.foreground.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(theme.accent.opacity(0.6), lineWidth: 1.5)
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

    private var displayText: String {
        model.currentPreviewText
    }
}
