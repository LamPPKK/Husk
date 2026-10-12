// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum NavigationSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case library = "Library"
    case store = "Store (Google Play)"
    case downloads = "Downloads"
    case files = "Files"
    case faq = "FAQ"
    case settings = "Settings"
    case checks = "Diagnostics"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "square.grid.2x2.fill"
        case .store: return "bag.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .files: return "folder.fill"
        case .faq: return "questionmark.circle.fill"
        case .settings: return "gearshape.fill"
        case .checks: return "stethoscope"
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var store = TranslationLayerStore.shared
    @ObservedObject var router = Router.shared
    @ObservedObject var downloads = Downloads.shared
    @ObservedObject var incoming = IncomingFiles.shared

    @State private var selectedSection: NavigationSection = .home
    @State private var isTargetedForDrop: Bool = false

    private var activeDownloadsCount: Int {
        downloads.jobs.filter { !$0.complete && !$0.failed }.count
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .frame(minWidth: 920, minHeight: 600)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $router.showDownloads) {
            DownloadsTab()
        }
        .sheet(isPresented: $router.showFiles) {
            FilesTab()
        }
        .sheet(isPresented: Binding(
            get: { !incoming.waiting.isEmpty },
            set: { if !$0 { incoming.discard() } }
        )) {
            IncomingChooser()
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers)
        }
        .onChange(of: router.tab) { newTab in
            switch newTab {
            case .home: selectedSection = .home
            case .library: selectedSection = .library
            case .store: selectedSection = .store
            case .help: selectedSection = .faq
            case .settings: selectedSection = .settings
            }
        }
        .onChange(of: selectedSection) { newSection in
            switch newSection {
            case .home: router.tab = .home
            case .library: router.tab = .library
            case .store: router.tab = .store
            case .faq: router.tab = .help
            case .settings: router.tab = .settings
            case .downloads, .files, .checks: break
            }
        }
        .overlay {
            if let busy = store.busy ?? incoming.preparing {
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
                title: Text("Notice"),
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
        .frame(minWidth: 190, idealWidth: 220)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .home:
            HomeView()
        case .library:
            LibraryScreen()
        case .store:
            StoreView()
        case .downloads:
            DownloadsTab()
        case .files:
            FilesTab()
        case .faq:
            FAQTab()
        case .settings:
            SettingsTab()
        case .checks:
            DeviceChecksViewMac()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                router.addSomething()
            } label: {
                Label("Add APK", systemImage: "plus")
            }
            .help("Import APK, XAPK, or APKS")
        }

        ToolbarItem(placement: .automatic) {
            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: TranslationLayer.sharedStorage.path)
            } label: {
                Label("Shared Storage", systemImage: "folder")
            }
            .help("Open Shared Storage folder")
        }

        ToolbarItem(placement: .automatic) {
            Button {
                store.runChecks()
                selectedSection = .checks
            } label: {
                Label("Diagnostics", systemImage: "stethoscope")
            }
            .help("Run Translation Layer checks")
        }
    }

    // MARK: - Drag and Drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    let ext = url.pathExtension.lowercased()
                    if ["apk", "xapk", "apkm", "apks"].contains(ext) {
                        urls.append(url)
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                IncomingFiles.shared.receive(urls)
            }
        }
        return true
    }
}
