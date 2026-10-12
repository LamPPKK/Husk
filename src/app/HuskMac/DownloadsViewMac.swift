// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit

struct DownloadsViewMac: View {
    @ObservedObject var downloads = DownloadsManagerMac.shared

    var body: some View {
        VStack(spacing: 0) {
            if downloads.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Active Downloads")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Games downloaded from Discover or the Store will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(downloads.items) { item in
                        DownloadRow(item: item)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct DownloadRow: View {
    let item: DownloadTaskItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : (item.isFailed ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill"))
                .font(.title2)
                .foregroundColor(item.isComplete ? .green : (item.isFailed ? .red : .accentColor))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)

                if !item.isComplete && !item.isFailed {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                }

                Text(item.status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if item.isComplete {
                Text("Installed")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 6)
    }
}
