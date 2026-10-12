// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit

struct StoreViewMac: View {
    @ObservedObject var downloads = DownloadsManagerMac.shared
    @State private var filterEngine: String = "All"
    @State private var searchText: String = ""

    private let categories = ["All", "SDL", "Godot", "Android Java"]

    private var filteredGames: [CatalogGame] {
        StoreCatalog.sampleItems.filter { game in
            let matchesCategory = filterEngine == "All" || game.engine == filterEngine
            let matchesSearch = searchText.isEmpty ||
                game.name.localizedCaseInsensitiveContains(searchText) ||
                game.description.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Bar
            HStack {
                Picker("Category", selection: $filterEngine) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search catalog…", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .frame(width: 220)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Catalog Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 16)], spacing: 16) {
                    ForEach(filteredGames) { game in
                        CatalogGameCard(game: game)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct CatalogGameCard: View {
    let game: CatalogGame
    @ObservedObject var downloads = DownloadsManagerMac.shared

    private var activeDownload: DownloadTaskItem? {
        downloads.items.first(where: { $0.url.absoluteString == game.downloadUrl && !$0.isComplete })
    }

    private var isInstalled: Bool {
        TranslationLayerStore.shared.apps.contains(where: {
            $0.packageName == game.id || $0.label.localizedCaseInsensitiveCompare(game.name) == .orderedSame
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(game.engine)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)

                        Text(game.sizeText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text(game.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            if let dl = activeDownload {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: dl.progress)
                    Text(dl.status)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if isInstalled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Installed")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                Button(action: {
                    if let url = URL(string: game.downloadUrl) {
                        downloads.download(url: url, title: game.name)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Get APK")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(14)
        .frame(height: 190)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
