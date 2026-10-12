// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum NavigationSection: String, CaseIterable, Identifiable {
    case library = "Library"
    case store = "Discover & Store"
    case downloads = "Downloads"
    case checks = "Diagnostics"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library: return "square.grid.2x2.fill"
        case .store: return "bag.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .checks: return "checkmark.shield.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var store = TranslationLayerStore.shared
    @ObservedObject var downloads = DownloadsManagerMac.shared

    @State private var selectedSection: NavigationSection = .library
    @State private var searchText: String = ""
    @State private var engineFilter: String = "All"
    @State private var selectedAppForDetail: TLApp? = nil
    @State private var isTargetedForDrop: Bool = false

    private var filteredApps: [TLApp] {
        store.apps.filter { app in
            let matchesSearch = searchText.isEmpty ||
                app.label.localizedCaseInsensitiveContains(searchText) ||
                (app.packageName?.localizedCaseInsensitiveContains(searchText) ?? false)

            let matchesEngine: Bool
            if engineFilter == "All" {
                matchesEngine = true
            } else if engineFilter == "Games" {
                matchesEngine = app.isGame
            } else {
                matchesEngine = app.screenEngine.displayName == engineFilter
            }
            return matchesSearch && matchesEngine
        }
    }

    private var activeDownloadsCount: Int {
        downloads.items.filter { !$0.isComplete && !$0.isFailed }.count
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .frame(minWidth: 800, minHeight: 520)
        .toolbar {
            toolbarContent
        }
        .sheet(item: $selectedAppForDetail) { app in
            GameDetailView(app: app)
        }
        .overlay {
            if let busy = store.busy {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(busy)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Alert(
                title: Text("Import Failed"),
                message: Text(store.lastError ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(NavigationSection.allCases, selection: $selectedSection) { section in
            NavigationLink(value: section) {
                HStack {
                    Label(section.rawValue, systemImage: section.icon)
                    Spacer()
                    if section == .downloads && activeDownloadsCount > 0 {
                        Text("\(activeDownloadsCount)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    } else if section == .library {
                        Text("\(store.apps.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180, idealWidth: 200)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .library:
            libraryView
        case .store:
            StoreViewMac()
        case .downloads:
            DownloadsViewMac()
        case .checks:
            DeviceChecksViewMac()
        case .settings:
            SettingsViewMac()
        }
    }

    // MARK: - Library View

    private var libraryView: some View {
        VStack(spacing: 0) {
            // Filter Bar
            HStack {
                Picker("Engine", selection: $engineFilter) {
                    Text("All").tag("All")
                    Text("Games").tag("Games")
                    Text("Unity").tag("Unity")
                    Text("Cocos2d-x").tag("Cocos2d-x")
                    Text("SDL").tag("SDL")
                    Text("Godot").tag("Godot")
                    Text("Unreal").tag("Unreal Engine")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 440)

                Spacer()

                Button {
                    promptAddAPK()
                } label: {
                    Label("Add APK", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if store.apps.isEmpty {
                emptyLibraryState
            } else if filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No matching applications")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)], spacing: 20) {
                        ForEach(filteredApps) { app in
                            AppCardView(app: app, onPlay: {
                                store.markPlayed(app)
                                GameWindowController.play(app: app)
                            }, onInspect: {
                                selectedAppForDetail = app
                            })
                        }
                    }
                    .padding(20)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers)
        }
        .overlay {
            if isTargetedForDrop {
                ZStack {
                    Color.accentColor.opacity(0.15)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        Text("Drop APK or XAPK here to import")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.accentColor)
                    }
                    .padding(32)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    .cornerRadius(16)
                    .shadow(radius: 12)
                }
            }
        }
    }

    private var emptyLibraryState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("Your Library is Empty")
                .font(.title2.weight(.bold))

            Text("Drag & drop an .apk, .xapk, or .apkm file here,\nor click '+ Add APK' to get started.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 12) {
                Button("Browse APK Files…") {
                    promptAddAPK()
                }
                .buttonStyle(.borderedProminent)

                Button("Browse Store") {
                    selectedSection = .store
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 140)
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Button {
                promptAddAPK()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add APK, XAPK, or APKM file")

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: TranslationLayer.sharedStorage.path)
            } label: {
                Image(systemName: "folder")
            }
            .help("Open Android Shared Storage in Finder")
        }
    }

    // MARK: - Import Helpers

    private func promptAddAPK() {
        let panel = NSOpenPanel()
        panel.title = "Select Android Package"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "apk") ?? .data,
            UTType(filenameExtension: "xapk") ?? .data,
            UTType(filenameExtension: "apkm") ?? .data,
            UTType(filenameExtension: "apks") ?? .data
        ]

        if panel.runModal() == .OK {
            store.add(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let valid = urls.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["apk", "xapk", "apkm", "apks"].contains(ext)
            }
            if !valid.isEmpty {
                self.store.add(valid)
            }
        }
        return true
    }
}

// MARK: - App Card View

struct AppCardView: View {
    let app: TLApp
    let onPlay: () -> Void
    let onInspect: () -> Void

    @State private var isHovered = false
    @State private var renameText = ""
    @State private var isRenaming = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if let iconPath = app.iconPath, let img = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(isHovered ? 0.35 : 0.2), radius: isHovered ? 8 : 4, y: 3)
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: 88, height: 88)
                        .overlay(
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 38))
                                .foregroundColor(.accentColor)
                        )
                }

                if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: -27, y: -27)
                    .transition(.opacity)
                }
            }
            .frame(width: 88, height: 88)

            Text(app.label)
                .font(.headline)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            Text(app.screenEngine.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .cornerRadius(12)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            onPlay()
        }
        .onTapGesture(count: 1) {
            onInspect()
        }
        .contextMenu {
            Button("Play") { onPlay() }
            Divider()
            Button("Game Details…") { onInspect() }
            Button("Backup Saves…") { SaveBackupMac.promptExport(for: app) }
            Button("Restore Saves…") { SaveBackupMac.promptRestore(for: app) { _ in } }
            Divider()
            Button("Reveal in Finder") {
                let folder = TranslationLayer.root.appendingPathComponent(app.id)
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
            }
            Button(role: .destructive) {
                TranslationLayerStore.shared.remove(app)
            } label: {
                Text("Delete")
            }
        }
    }
}
