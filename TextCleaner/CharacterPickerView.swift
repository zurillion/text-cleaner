import SwiftUI

final class CharacterPickerModel: ObservableObject {
    let sections: [CharacterSection]

    /// Free-form filter text. Empty → show everything. Non-empty matches
    /// against the entry's custom description (if any), the Unicode
    /// scalar's official name (so "alpha" finds α without needing a
    /// per-entry description), and the literal character.
    @Published var query: String = "" {
        didSet {
            if oldValue != query {
                selectedIndex = 0
                hoverIndex = nil
            }
        }
    }

    @Published var selectedIndex: Int = 0
    /// Mouse-hover preview index. When non-nil the header bar reflects
    /// this index instead of `selectedIndex`.
    @Published var hoverIndex: Int? = nil
    /// Updated by the view when the window resizes so arrow Up/Down
    /// jumps match the visible grid.
    @Published var columns: Int = 12
    /// Refreshed by the controller on each `show()` from
    /// `AppSettings.recentPickedCharacters`. Rendered as a dynamic
    /// section above the static catalog when non-empty.
    @Published var recents: [CharacterEntry] = []

    init(sections: [CharacterSection] = CharacterCatalog.sections) {
        self.sections = sections
    }

    // MARK: - Filter

    /// All sections in display order — Recent first (when populated)
    /// followed by the static catalog.
    private var displayedSections: [CharacterSection] {
        var result: [CharacterSection] = []
        if !recents.isEmpty {
            result.append(CharacterSection(title: "Recent", entries: recents))
        }
        result.append(contentsOf: sections)
        return result
    }

    var filteredSections: [CharacterSection] {
        let base = displayedSections
        guard !query.isEmpty else { return base }
        let q = query.lowercased()
        return base.compactMap { section in
            let filtered = section.entries.filter { matches($0, query: q) }
            guard !filtered.isEmpty else { return nil }
            return CharacterSection(title: section.title, entries: filtered)
        }
    }

    var visibleEntries: [CharacterEntry] {
        filteredSections.flatMap { $0.entries }
    }

    private func matches(_ entry: CharacterEntry, query q: String) -> Bool {
        if let desc = entry.description?.lowercased(), desc.contains(q) {
            return true
        }
        if let scalar = entry.character.unicodeScalars.first,
           let name = scalar.properties.name?.lowercased(),
           name.contains(q) {
            return true
        }
        if entry.character == q { return true }
        return false
    }

    // MARK: - Selection

    var displayedEntry: CharacterEntry? {
        let entries = visibleEntries
        let idx = hoverIndex ?? selectedIndex
        guard entries.indices.contains(idx) else { return nil }
        return entries[idx]
    }

    var selectedEntry: CharacterEntry? {
        let entries = visibleEntries
        guard entries.indices.contains(selectedIndex) else { return nil }
        return entries[selectedIndex]
    }

    // MARK: - Navigation

    func moveLeft() {
        let count = visibleEntries.count
        guard count > 0 else { return }
        selectedIndex = max(0, selectedIndex - 1)
    }

    func moveRight() {
        let count = visibleEntries.count
        guard count > 0 else { return }
        selectedIndex = min(count - 1, selectedIndex + 1)
    }

    func moveUp() {
        let count = visibleEntries.count
        guard count > 0, columns > 0 else { return }
        selectedIndex = max(0, selectedIndex - columns)
    }

    func moveDown() {
        let count = visibleEntries.count
        guard count > 0, columns > 0 else { return }
        selectedIndex = min(count - 1, selectedIndex + columns)
    }
}

struct CharacterPickerView: View {
    @ObservedObject var model: CharacterPickerModel
    @ObservedObject var settings: AppSettings
    let onSelect: (String) -> Void

    private let cellSize: CGFloat = 32
    private let cellSpacing: CGFloat = 4
    private let horizontalPadding: CGFloat = 12

    @FocusState private var searchFocused: Bool

    var body: some View {
        let theme = settings.theme
        VStack(spacing: 0) {
            header(theme: theme)
            searchField(theme: theme)
            Rectangle()
                .fill(theme.borderTint)
                .frame(height: 1)
            gridSection(theme: theme)
        }
        .frame(minWidth: 320, minHeight: 260)
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
        .onAppear { searchFocused = true }
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
                Text(label(for: entry))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(2)
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

    private func label(for entry: CharacterEntry?) -> String {
        if let desc = entry?.description, !desc.isEmpty { return desc }
        if let scalar = entry?.character.unicodeScalars.first,
           let name = scalar.properties.name {
            // Unicode names are SHOUT_CASE; lowercase for readability.
            return name.lowercased()
        }
        return "Unicode character picker"
    }

    private func codepoint(for entry: CharacterEntry?) -> String {
        guard let entry = entry,
              let scalar = entry.character.unicodeScalars.first else {
            return " "
        }
        let primary = String(format: "U+%04X", scalar.value)
        let extras = entry.character.unicodeScalars.dropFirst().count
        return extras > 0 ? "\(primary) + \(extras) more" : primary
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

    // MARK: - Search field

    private func searchField(theme: PopupTheme) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(theme.secondaryForeground)
            TextField("Filter by name or description", text: $model.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(.system(size: 13))
                .foregroundStyle(theme.foreground)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryForeground)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.foreground.opacity(0.06))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Grid

    private func gridSection(theme: PopupTheme) -> some View {
        GeometryReader { geo in
            let usable = geo.size.width - horizontalPadding * 2
            let cols = max(4, Int(usable / (cellSize + cellSpacing)))
            let gridColumns = Array(
                repeating: GridItem(.fixed(cellSize), spacing: cellSpacing),
                count: cols
            )
            let sections = model.filteredSections
            let offsets = sectionOffsets(sections)

            ScrollViewReader { proxy in
                ScrollView {
                    if sections.isEmpty {
                        emptyResults(theme: theme)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(sections.enumerated()), id: \.element.title) { sectionIdx, section in
                                sectionView(
                                    section: section,
                                    sectionOffset: offsets[sectionIdx],
                                    gridColumns: gridColumns,
                                    theme: theme
                                )
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 12)
                    }
                }
                .onChange(of: model.selectedIndex) { _, _ in
                    guard let entry = model.selectedEntry else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(entry.id, anchor: .center)
                    }
                }
            }
            .onAppear { model.columns = cols }
            .onChange(of: cols) { _, new in model.columns = new }
        }
    }

    /// Pre-computed starting flat index of each visible section. Avoids
    /// scanning `visibleEntries` from each cell for its global index
    /// (which would be O(N²) on every render).
    private func sectionOffsets(_ sections: [CharacterSection]) -> [Int] {
        var offsets: [Int] = []
        var sum = 0
        for section in sections {
            offsets.append(sum)
            sum += section.entries.count
        }
        return offsets
    }

    @ViewBuilder
    private func emptyResults(theme: PopupTheme) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(theme.secondaryForeground)
            Text("No matches")
                .font(.system(size: 12))
                .foregroundStyle(theme.secondaryForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private func sectionView(
        section: CharacterSection,
        sectionOffset: Int,
        gridColumns: [GridItem],
        theme: PopupTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondaryForeground)
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: cellSpacing) {
                ForEach(Array(section.entries.enumerated()), id: \.element.id) { idx, entry in
                    cell(entry: entry, flatIndex: sectionOffset + idx, theme: theme)
                }
            }
        }
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
            .id(entry.id)
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
