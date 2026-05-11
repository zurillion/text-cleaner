import SwiftUI

final class PopupViewModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    let actions: [TextAction]

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
}

struct PopupView: View {
    @ObservedObject var model: PopupViewModel
    let onSelect: (TextAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Cleaner")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.top, 2)

            VStack(spacing: 2) {
                ForEach(Array(model.actions.enumerated()), id: \.element.id) { index, action in
                    row(index: index, action: action)
                }
            }
        }
        .padding(10)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 18, y: 6)
        )
    }

    @ViewBuilder
    private func row(index: Int, action: TextAction) -> some View {
        let isSelected = index == model.selectedIndex
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected
                              ? Color.white.opacity(0.25)
                              : Color.primary.opacity(0.08))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.7))

            Image(systemName: action.icon)
                .frame(width: 16)
                .foregroundStyle(isSelected ? Color.white : Color.primary)

            Text(action.title)
                .foregroundStyle(isSelected ? Color.white : Color.primary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { model.selectedIndex = index }
        }
        .onTapGesture {
            onSelect(action)
        }
    }
}
