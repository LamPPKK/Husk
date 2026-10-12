// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import SwiftUI

// MARK: - Download Item Model

public struct DownloadTaskItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let url: URL
    public var progress: Double = 0.0
    public var status: String = "Downloading…"
    public var isComplete: Bool = false
    public var isFailed: Bool = false
}

// MARK: - Downloads Manager for macOS

@MainActor
public final class DownloadsManagerMac: NSObject, ObservableObject, @preconcurrency URLSessionDownloadDelegate {
    public static let shared = DownloadsManagerMac()

    @Published public private(set) var items: [DownloadTaskItem] = []
    private var activeSessions: [Int: UUID] = [:]
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    public func download(url: URL, title: String) {
        let item = DownloadTaskItem(title: title, url: url)
        items.insert(item, at: 0)
        let task = session.downloadTask(with: url)
        activeSessions[task.taskIdentifier] = item.id
        task.resume()
        HuskLog.log("downloads", "Started download for \(title) from \(url.absoluteString)")
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = activeSessions[downloadTask.taskIdentifier],
              let idx = items.firstIndex(where: { $0.id == id }),
              totalBytesExpectedToWrite > 0 else { return }

        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        items[idx].progress = fraction
        items[idx].status = String(format: "%.1f MB / %.1f MB (%.0f%%)",
                                   Double(totalBytesWritten) / 1_048_576.0,
                                   Double(totalBytesExpectedToWrite) / 1_048_576.0,
                                   fraction * 100)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = activeSessions[downloadTask.taskIdentifier],
              let idx = items.firstIndex(where: { $0.id == id }) else { return }

        items[idx].progress = 1.0
        items[idx].isComplete = true
        items[idx].status = "Importing into Library…"

        let fileName = downloadTask.originalRequest?.url?.lastPathComponent ?? "app.apk"
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: location, to: dest)

        TranslationLayerStore.shared.add([dest])
        items[idx].status = "Completed & Installed"
        HuskLog.log("downloads", "Finished downloading and imported \(fileName)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error,
              let id = activeSessions[task.taskIdentifier],
              let idx = items.firstIndex(where: { $0.id == id }) else { return }

        items[idx].isFailed = true
        items[idx].status = "Failed: \(error.localizedDescription)"
        HuskLog.log("downloads", "Download error: \(error.localizedDescription)")
    }
}

// MARK: - Store Catalog for macOS

public struct CatalogGame: Identifiable {
    public let id: String
    public let name: String
    public let engine: String
    public let description: String
    public let iconUrl: String?
    public let downloadUrl: String
    public let sizeText: String
}

public enum StoreCatalog {
    public static let sampleItems: [CatalogGame] = [
        CatalogGame(
            id: "org.artsoft.rocksndiamonds",
            name: "Rocks'n'Diamonds",
            engine: "SDL",
            description: "Classic arcade puzzle game reminiscent of Boulder Dash, Supaplex, and Emerald Mine.",
            iconUrl: nil,
            downloadUrl: "https://f-droid.org/repo/org.artsoft.rocksndiamonds_4020200.apk",
            sizeText: "18 MB"
        ),
        CatalogGame(
            id: "com.simondalvai.pocketbroomball",
            name: "Pocket Broomball",
            engine: "Godot",
            description: "Fast-paced arcade sports game built with Godot 3 engine.",
            iconUrl: nil,
            downloadUrl: "https://f-droid.org/repo/com.simondalvai.pocketbroomball_100.apk",
            sizeText: "14 MB"
        ),
        CatalogGame(
            id: "org.xolatgames.burgers",
            name: "Burgers",
            engine: "Godot",
            description: "Fun retro cooking and puzzle arcade game powered by Godot 4.",
            iconUrl: nil,
            downloadUrl: "https://f-droid.org/repo/org.xolatgames.burgers_7.apk",
            sizeText: "22 MB"
        ),
        CatalogGame(
            id: "com.dozingcatsoftware.mouse_pounce",
            name: "Mouse Pounce",
            engine: "Android Java",
            description: "Arcade cat & mouse challenge using Android native and OpenGL ES drawing.",
            iconUrl: nil,
            downloadUrl: "https://f-droid.org/repo/com.dozingcatsoftware.mouse_pounce_10.apk",
            sizeText: "8 MB"
        )
    ]
}
