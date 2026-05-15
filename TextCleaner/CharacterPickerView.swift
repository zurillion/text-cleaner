import SwiftUI

final class CharacterPickerModel: ObservableObject {
    let sections: [CharacterSection]
    let flatEntries: [(sectionIndex: Int, entry: CharacterEntry)]

    @Published var selectedIndex: Int = 0
    /// Mouse-hover preview index. When non-nil the header bar reflects
    /// this index instead of `selectedIndex`, so moving the cursor
    /// shows the codepoint without committing to a selection.
    @Published var hoverIndex: Int? = nil

    init(sections: [CharacterSection] = CharacterCatalog.sections) {
        self.sections = sections
        self.flatEntries = sections.enumerated().flatMap { sectionIdx, section in
            section.entries.map { (sectionIdx, $0) }
        }
    }

    var displayedEntry: CharacterEntry? {
        let idx = hoverIndex ?? selectedIndex
        guard flatEntries.indices.contains(idx) else { return nil }
        return flatEntries[idx].entry
    }

    var selectedEntry: CharacterEntry? {
        guard flatEntries.indices.contains(selectedIndex) else { return nil }
        return flatEntries[selectedIndex].entry
    }

    func moveLeft() {
        guard !flatEntries.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
    }

    func moveRight() {
        guard !flatEntries.isEmpty else { return }
        selectedIndex = min(flatEntries.count - 1, selectedIndex + 1)
    }

    func moveUp(columns: Int) {
        guard !flatEntries.isEmpty, columns > 0 else { return }
        selectedIndex = max(0, selectedIndex - columns)
    }

    func moveDown(columns: Int) {
        guard !flatEntries.isEmpty, columns > 0 else { return }
        selectedIndex = min(flatEntries.count - 1, selectedIndex + columns)
    }
}

struct CharacterPickerView: View {
    @ObservedObject var model: CharacterPickerModel
    @ObservedObject var settings: AppSettings
    let onSelect: (String) -> Void

    /// Fixed column count drives both the LazyVGrid layout and the
    /// Up/Down arrow navigation distance, so they stay in sync.
    private let columns: Int = 12
    private let cellSize: CGFloat = 32
    private let cellSpacing: CGFloat = 4

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: columns)
    }

    var body: some View {
        let theme = settings.theme
        VStack(spacing: 0) {
            header(theme: theme)
            Rectangle()
                .fill(theme.borderTint)
                .frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                        ForEach(Array(model.sections.enumerated()), id: \.element.id) { sectionIdx, section in
                            sectionView(sectionIndex: sectionIdx, section: section, theme: theme)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: model.selectedIndex) { _, newValue in
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .frame(width: CGFloat(columns) * cellSize + CGFloat(columns - 1) * cellSpacing + 24,
               height: 460)
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

    // MARK: - Header

    private func header(theme: PopupTheme) -> some View {
        let entry = model.displayedEntry
        return HStack(spacing: 14) {
            Text(entry?.character ?? " ")
                .font(.system(size: 38))
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.foreground.opacity(0.06))
                )
                .foregroundStyle(theme.foreground)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry?.description ?? "Unicode character picker")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.foreground)
                Text(codepoint(for: entry))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.secondaryForeground)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                hint("↩", "Insert", theme: theme)
                hint("⎋", "Cancel", theme: theme)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func codepoint(for entry: CharacterEntry?) -> String {
        guard let entry = entry,
              let scalar = entry.character.unicodeScalars.first else {
            return " "
        }
        // Show the first scalar's codepoint; for graphemes built of
        // multiple scalars the header is informational anyway.
        let primary = String(format: "U+%04X", scalar.value)
        if entry.character.unicodeScalars.count > 1 {
            return "\(primary) + \(entry.character.unicodeScalars.dropFirst().count) more"
        }
        return primary
    }

    private func hint(_ key: String, _ label: String, theme: PopupTheme) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.foreground.opacity(0.10))
                )
            Text(label).font(.system(size: 10))
        }
        .foregroundStyle(theme.secondaryForeground)
    }

    // MARK: - Section / grid

    @ViewBuilder
    private func sectionView(sectionIndex: Int, section: CharacterSection, theme: PopupTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondaryForeground)
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: cellSpacing) {
                ForEach(Array(section.entries.enumerated()), id: \.element.id) { entryIdx, entry in
                    cell(
                        entry: entry,
                        flatIndex: flatIndex(sectionIndex: sectionIndex, entryIndex: entryIdx),
                        theme: theme
                    )
                }
            }
        }
    }

    private func flatIndex(sectionIndex: Int, entryIndex: Int) -> Int {
        var index = 0
        for i in 0..<sectionIndex {
            index += model.sections[i].entries.count
        }
        return index + entryIndex
    }

    @ViewBuilder
    private func cell(entry: CharacterEntry, flatIndex: Int, theme: PopupTheme) -> some View {
        let isSelected = (model.selectedIndex == flatIndex)
        let isHovered = (model.hoverIndex == flatIndex)
        Text(entry.character)
            .font(.system(size: 20))
            .frame(width: cellSize, height: cellSize)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        isSelected ? theme.accent
                        : isHovered ? theme.foreground.opacity(0.08)
                        : Color.clear
                    )
            )
            .foregroundStyle(isSelected ? theme.onAccent : theme.foreground)
            .id(flatIndex)
            .contentShape(Rectangle())
            .onHover { hovering in
                model.hoverIndex = hovering ? flatIndex : nil
            }
            .onTapGesture {
                model.selectedIndex = flatIndex
                onSelect(entry.character)
            }
    }
}
