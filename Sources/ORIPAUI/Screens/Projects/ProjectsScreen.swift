// Projects screen — port of `com.origamitoolbox.oripa.ProjectsActivity`.
//
// Android layout: `activity_projects.xml` (SwipeRefreshLayout + RecyclerView
// `projects_container` + `main_toolbar` + `FloatingActionButton`), adapters
// `project_grid_single_item.xml` / `project_list_single_item.xml`, menus
// `projects_action_bar.xml` (Import / Sort / View / About) and `projects_second_bar.xml`
// (Delete, contextual action mode).
//
// Behaviour is 1:1 with `src/js/ui/screens/projects.js`:
//   * default grid view, sorted by last modified (descending);
//   * toolbar title `plurals.projects_title` ("0 Files" / "1 File" / "N Files");
//   * grid columns = round(contentWidth / 180dp), min 1;
//   * long press (500 ms) or right click starts the selection action mode (grey_600 bar,
//     "N selected", Delete All), tapping the list thumbnail also starts selection;
//   * per-item overflow menu: Rename / Make a copy / Delete with the exact dialogs and
//     snackbars; FAB "New File"; Import through the system document picker.
import SwiftUI

// MARK: - Selection state

/// Selection state kept in an object so the router back handler always sees the live value
/// (a `@State` captured in a closure stored outside the view would go stale).
@MainActor
private final class ProjectsSelectionModel: ObservableObject {
    @Published var actionMode = false
    @Published var selected: Set<String> = []

    var count: Int { selected.count }

    init(selected: Set<String> = [], actionMode: Bool = false) {
        self.selected = selected
        self.actionMode = actionMode
    }

    func start(with name: String) {
        actionMode = true
        selected = [name]
    }

    func toggle(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }

    func finish() {
        actionMode = false
        selected.removeAll()
    }
}

// MARK: - Screen

public struct ProjectsScreen: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.oripaNavID) private var navID

    @StateObject private var selection = ProjectsSelectionModel()

    // Activity-instance state (Android fields doShowList / doSortLastModified).
    @State private var doShowList = false
    @State private var doSortLastModified = true
    @State private var items: [ProjectInfo] = []
    @State private var thumbnails: [String: Image] = [:]
    @State private var loadedThumbMtimes: [String: Date] = [:]
    /// Incremented on sort/view changes to scroll the list back to the top (the JS port
    /// scrolls the RecyclerView to position 0).
    @State private var scrollResetToken = 0

    public init() {}

    /// Snapshot/QA only: seed the activity-instance state (grid/list, sort, selection mode).
    init(initialShowList: Bool = false,
         initialSortLastModified: Bool = true,
         initialSelection: Set<String> = [],
         initialActionMode: Bool = false) {
        _doShowList = State(initialValue: initialShowList)
        _doSortLastModified = State(initialValue: initialSortLastModified)
        _selection = StateObject(wrappedValue: ProjectsSelectionModel(selected: initialSelection,
                                                                     actionMode: initialActionMode))
    }

    private var isTop: Bool { app.navigation.last?.id == navID }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrTheme.background)
        .overlay(alignment: .bottomTrailing) {
            OrFAB(icon: "ic_add_light_24dp", title: ProjectDialogStrings.newFileTitle) {
                if selection.actionMode { selection.finish() }
                app.openNewFile()
            }
            .padding(OrTheme.fabMargin)
        }
        .onAppear {
            refresh(resetScroll: true)
            registerBackHandler()
        }
        .onDisappear {
            app.removeBackHandler(for: navID)
        }
        .onChange(of: app.navigation.last?.id) { topID in
            // `resume()` of the JS router: returning from preview/editor refreshes the list
            // (Android starts a fresh ProjectsActivity after the editor).
            guard topID == navID else { return }
            refresh()
            app.store.cleanupStaging()
        }
        .onChange(of: selection.actionMode) { _ in
            registerBackHandler()
        }
    }

    // MARK: Top bar (Toolbar <-> contextual ActionBar)

    @ViewBuilder
    private var topBar: some View {
        if selection.actionMode {
            OrActionBar(
                title: ProjectDialogStrings.selectedTitle(count: selection.count),
                onClose: { selection.finish() },
                actions: [
                    OrToolbarAction(icon: "ic_delete_light_24dp",
                                    title: ProjectDialogStrings.delete,
                                    condensedLabel: ProjectDialogStrings.delete,
                                    showAs: .withText) {
                        confirmDeleteSelected()
                    },
                ]
            )
        } else {
            OrToolbar(title: ProjectDialogStrings.projectsTitle(count: items.count),
                      nav: .none,
                      actions: toolbarActions)
        }
    }

    private var toolbarActions: [OrToolbarAction] {
        var actions: [OrToolbarAction] = []
        actions.append(OrToolbarAction(icon: "ic_folder_dark_24dp",
                                       title: ProjectDialogStrings.importTitle,
                                       showAs: .withText) {
            onImport()
        })
        if doSortLastModified {
            actions.append(OrToolbarAction(icon: "ic_sort_by_alpha_dark_24dp",
                                           title: ProjectDialogStrings.sortByName) {
                toggleSort()
            })
        } else {
            actions.append(OrToolbarAction(icon: "ic_access_time_dark_24dp",
                                           title: ProjectDialogStrings.sortByLastModified) {
                toggleSort()
            })
        }
        if doShowList {
            actions.append(OrToolbarAction(icon: "ic_view_module_dark_24dp",
                                           title: ProjectDialogStrings.viewGrid,
                                           condensedLabel: ProjectDialogStrings.viewGridCondensed,
                                           showAs: .withText) {
                toggleView()
            })
        } else {
            actions.append(OrToolbarAction(icon: "ic_view_list_dark_24dp",
                                           title: ProjectDialogStrings.viewList,
                                           condensedLabel: ProjectDialogStrings.viewListCondensed,
                                           showAs: .withText) {
                toggleView()
            })
        }
        actions.append(OrToolbarAction(icon: "ic_info_outline_dark_24dp",
                                       title: ProjectDialogStrings.about) {
            AboutDialog.show(app: app)
        })
        return actions
    }

    // MARK: Content

    private var content: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let columns = max(1, Int((width / OrTheme.gridImageDimension).rounded()))
            ZStack {
                if items.isEmpty {
                    emptyState
                        .frame(width: width, height: height)
                } else if doShowList {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            Color.clear.frame(height: 0).id("projects-top")
                            projectList
                        }
                        .onChange(of: scrollResetToken) { _ in
                            proxy.scrollTo("projects-top", anchor: .top)
                        }
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            Color.clear.frame(height: 0).id("projects-top")
                            projectGrid(columns: columns)
                        }
                        .onChange(of: scrollResetToken) { _ in
                            proxy.scrollTo("projects-top", anchor: .top)
                        }
                    }
                }
            }
        }
    }

    /// The Android layout has no empty view: only the ORIPA wordmark watermark is shown
    /// (no invented strings), with the toolbar title reading "0 Files".
    private var emptyState: some View {
        ZStack {
            if let logo = AssetLoader.image("oripa_logo_text_v2_raster") {
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150)
                    .opacity(0.16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: OrTheme.projectGridGap),
                                 count: max(1, columns)),
                  spacing: OrTheme.projectGridGap) {
            ForEach(items) { item in
                ProjectGridItem(
                    item: item,
                    thumbnail: thumbnails[item.name],
                    isSelected: selection.selected.contains(item.name),
                    overflowItems: itemMenuItems(name: item.name),
                    onTap: { handleTap(item.name) },
                    onLongPress: { startActionMode(item.name) }
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
        .padding(.bottom, 72)
    }

    private var projectList: some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { item in
                ProjectListRow(
                    item: item,
                    thumbnail: thumbnails[item.name],
                    isSelected: selection.selected.contains(item.name),
                    overflowItems: itemMenuItems(name: item.name),
                    onTap: { handleTap(item.name) },
                    onThumbnailTap: {
                        // ProjectsActivity lambda$onCreateViewHolder$0: tapping the list
                        // thumbnail starts/extends the selection.
                        if selection.actionMode { selection.toggle(item.name) }
                        else { startActionMode(item.name) }
                    },
                    onLongPress: { startActionMode(item.name) },
                    onRename: {
                        ProjectDialogs.rename(app: app, name: item.name) { _ in refresh() }
                    },
                    onCopy: {
                        ProjectDialogs.copy(app: app, name: item.name) { _ in refresh() }
                    },
                    onDelete: {
                        ProjectDialogs.deleteOne(app: app, name: item.name) { refresh() }
                    }
                )
            }
        }
        .padding(.bottom, 72)
    }

    // MARK: Thumbnails

    private func refreshThumbnails(force: Bool = false) {
        let mtimes = app.store.thumbMtimes
        var images = thumbnails
        var keys = loadedThumbMtimes
        var changed = false
        for item in items {
            let mtime = mtimes[item.name]
            if !force, images[item.name] != nil, keys[item.name] == mtime { continue }
            if let data = app.store.readThumb(name: item.name), let image = OripaImage.image(data: data) {
                images[item.name] = image
                keys[item.name] = mtime
                changed = true
            } else if let generated = app.store.regenerateThumb(name: item.name),
                      let image = OripaImage.image(data: generated) {
                // Lead-requested port addition: repair missing thumbnails from the OPXC.
                images[item.name] = image
                keys[item.name] = app.store.thumbMtimes[item.name]
                changed = true
            } else {
                images[item.name] = nil
                keys[item.name] = nil
            }
        }
        // Drop cached images of deleted projects.
        let existing = Set(items.map(\.name))
        for name in images.keys where !existing.contains(name) {
            images[name] = nil
            keys[name] = nil
            changed = true
        }
        if changed || force {
            thumbnails = images
            loadedThumbMtimes = keys
        }
    }

    // MARK: Actions

    private func handleTap(_ name: String) {
        if selection.actionMode {
            selection.toggle(name)
            if selection.count == 0 { selection.finish() }
        } else {
            app.openPreview(name: name)
        }
    }

    private func startActionMode(_ name: String) {
        if selection.actionMode {
            selection.toggle(name)
            if selection.count == 0 { selection.finish() }
        } else {
            selection.start(with: name)
        }
    }

    private func confirmDeleteSelected() {
        let names = Array(selection.selected)
        guard !names.isEmpty else { return }
        ProjectDialogs.deleteMultiple(app: app, count: names.count) {
            for name in names {
                try? app.store.delete(name: name)
            }
            selection.finish()
            refresh()
        }
    }

    private func onImport() {
        if selection.actionMode { selection.finish() }
        Task { @MainActor in
            let files = await app.fileExchange.pickImport()
            // The Android picker returned one file; accept the first (and stage any extra
            // only one at a time, like the reference flow).
            guard let file = files.first else { return }
            if !app.openImportedFile(file) {
                ProjectDialogs.showError(app: app, message: ProjectDialogStrings.copyError)
            }
            refresh()
        }
    }

    private func toggleSort() {
        doSortLastModified.toggle()
        refresh(resetScroll: true)
    }

    private func toggleView() {
        doShowList.toggle()
        refresh(resetScroll: true)
    }

    private func itemMenuItems(name: String) -> [OrMenuItem] {
        [
            OrMenuItem(label: ProjectDialogStrings.rename) {
                ProjectDialogs.rename(app: app, name: name) { _ in refresh() }
            },
            OrMenuItem(label: ProjectDialogStrings.copy) {
                ProjectDialogs.copy(app: app, name: name) { _ in refresh() }
            },
            OrMenuItem(label: ProjectDialogStrings.remove) {
                ProjectDialogs.deleteOne(app: app, name: name) { refresh() }
            },
        ]
    }

    // MARK: Refresh / back

    private func refresh(resetScroll: Bool = false) {
        if resetScroll { scrollResetToken &+= 1 }
        app.store.reload()
        var newItems = app.store.projects
        if doSortLastModified {
            newItems.sort(by: ProjectInfo.compareByModified)
        } else {
            newItems.sort(by: ProjectInfo.compareByName)
        }
        items = newItems
        // Drop selections of deleted projects and leave action mode when empty.
        let existing = Set(newItems.map(\.name))
        selection.selected = selection.selected.filter { existing.contains($0) }
        if selection.actionMode && selection.selected.isEmpty {
            selection.finish()
        }
        refreshThumbnails(force: resetScroll)
    }

    private func registerBackHandler() {
        app.setBackHandler(for: navID) { [weak selection] in
            guard let selection, selection.actionMode else { return false }
            selection.finish()
            return true
        }
    }
}

// MARK: - Grid item

private struct ProjectGridItem: View {
    let item: ProjectInfo
    let thumbnail: Image?
    let isSelected: Bool
    let overflowItems: [OrMenuItem]
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                thumbnailArea
                if isSelected {
                    MaterialIcon("ic_check_circle_dark_24px_custom", size: 40)
                        .padding(8)
                        .frame(width: OrTheme.projectCheckBadgeSize,
                               height: OrTheme.projectCheckBadgeSize,
                               alignment: .topLeading)
                        .allowsHitTesting(false)
                }
            }
            infoArea
        }
        .background(isSelected ? OrTheme.selectedItemBackground : OrTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var thumbnailArea: some View {
        ZStack {
            OrTheme.surface
            if let thumbnail {
                thumbnail
                    .resizable()
                    .scaledToFit()
                    .opacity(isSelected ? 0.5 : 1)
            } else if let logo = AssetLoader.image("oripa_logo_v3_raster") {
                logo
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .opacity(isSelected ? 0.25 : 0.45)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: OrTheme.longPressDuration) { onLongPress() }
        .accessibilityLabel(Text(item.name))
    }

    private var infoArea: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(OrTheme.projectGridTitle())
                    .foregroundColor(OrTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(ProjectStore.modifiedTextShort(item.modifiedAt))
                    .font(OrTheme.projectGridDate())
                    .foregroundColor(OrTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.trailing, 40)
            .padding(.vertical, 16)
            .frame(minHeight: 72, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onLongPressGesture(minimumDuration: OrTheme.longPressDuration) { onLongPress() }

            OrMenuIconButton(icon: "ic_more_vert_dark_24dp",
                             title: ProjectDialogStrings.overflow,
                             items: overflowItems,
                             size: OrTheme.projectOverflowSize,
                             iconSize: 24)
                .padding(.trailing, 0)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - List row

private struct ProjectListRow: View {
    let item: ProjectInfo
    let thumbnail: Image?
    let isSelected: Bool
    let overflowItems: [OrMenuItem]
    let onTap: () -> Void
    let onThumbnailTap: () -> Void
    let onLongPress: () -> Void
    let onRename: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if isSelected {
                    MaterialIcon("ic_check_circle_dark_24px_custom", size: 32)
                } else if let thumbnail {
                    thumbnail
                        .resizable()
                        .scaledToFit()
                        .opacity(1)
                } else if let logo = AssetLoader.image("oripa_logo_v3_raster") {
                    logo.resizable().scaledToFit().opacity(0.45)
                }
            }
            .frame(width: OrTheme.projectListThumbSize, height: OrTheme.projectListThumbSize)
            .contentShape(Rectangle())
            .onTapGesture { onThumbnailTap() }
            .onLongPressGesture(minimumDuration: OrTheme.longPressDuration) { onLongPress() }

            VStack(alignment: .leading, spacing: 0) {
                Text(item.name)
                    .font(OrTheme.projectListTitle())
                    .foregroundColor(OrTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(ProjectStore.modifiedText(item.modifiedAt))
                    .font(OrTheme.projectListDate())
                    .foregroundColor(OrTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.leading, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onLongPressGesture(minimumDuration: OrTheme.longPressDuration) { onLongPress() }

            OrMenuIconButton(icon: "ic_more_vert_dark_24dp",
                             title: ProjectDialogStrings.overflow,
                             items: overflowItems,
                             size: OrTheme.projectOverflowSize,
                             iconSize: 24)
                .frame(maxHeight: .infinity)
                .padding(.trailing, 4)
        }
        .padding(.leading, 16)
        .frame(height: OrTheme.projectListRowHeight)
        .background(isSelected ? OrTheme.selectedItemBackground : OrTheme.surface)
        .overlay(alignment: .bottom) {
            if !isSelected {
                OrDivider()
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            // Desktop right click: the JS port used it as a long press for selection mode.
            // A context menu is the native macOS equivalent, with the item actions on top.
            Button(ProjectDialogStrings.rename) { onRename() }
            Button(ProjectDialogStrings.copy) { onCopy() }
            Button(ProjectDialogStrings.remove) { onDelete() }
            Divider()
            Button("Select") { onLongPress() }
        }
    }
}
