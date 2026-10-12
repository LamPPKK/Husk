// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Native Engines

public enum TLNativeEngine: String, Codable, CaseIterable {
    case unity
    case cocos
    case minecraft
    case sdl
    case gta
    case ue4
    case godot
    case nativeactivity
    case gamemaker
    case java
    case flutter

    public var displayName: String {
        switch self {
        case .unity: return "Unity"
        case .cocos: return "Cocos2d-x"
        case .minecraft: return "Minecraft"
        case .sdl: return "SDL"
        case .gta: return "Rockstar"
        case .ue4: return "Unreal Engine"
        case .godot: return "Godot"
        case .nativeactivity: return "NativeActivity"
        case .gamemaker: return "GameMaker"
        case .java: return "Android Java"
        case .flutter: return "Flutter"
        }
    }
}

// MARK: - Web Apps & Scan Report

public enum WebAppKind: String {
    case capacitor, cordova
    public var assetFolder: String { self == .capacitor ? "public" : "www" }
    public var scheme: String { self == .capacitor ? "capacitor" : "app" }
    public var name: String { self == .capacitor ? "Capacitor" : "Cordova" }
}

public struct TLLibrary: Decodable, Identifiable {
    public let name: String
    public let abi: String
    public let apk: String
    public let bytes: Int64
    public let compressed: Bool
    public let status: String
    public let notes: [String]
    public let maxAlign: Int?
    public let pages: Int?
    public let execPages: Int?
    public let writePages: Int?
    public let conflictPages: Int?
    public let layout: String?
    public let svc: Int?
    public let tpidrReads: Int?
    public let tpidrWrites: Int?
    public let tls: Bool?
    public let textrel: Bool?
    public let relocations: Int?
    public let tlsRelocations: Int?
    public let unsupportedRelocations: Int?
    public let packing: String?
    public let imports: Int?
    public let soname: String?
    public let needed: [String]?

    public var id: String { "\(apk)/\(abi)/\(name)" }
}

public struct TLReport: Decodable {
    public let ok: Bool
    public let error: String?
    public let verdict: String
    public let summary: String
    public let engine: String?
    public let hasManifest: Bool
    public let dexCount: Int
    public let dexBytes: Int64
    public let abis: [String]
    public let systemLibraries: [String]
    public let libraries: [TLLibrary]

    public var webKind: WebAppKind? {
        switch engine {
        case "Capacitor": return .capacitor
        case "Cordova": return .cordova
        default: return nil
        }
    }

    public var nativeEngine: TLNativeEngine? {
        guard ok else { return nil }
        if !abis.isEmpty && !abis.contains("arm64-v8a") { return nil }
        if abis.isEmpty { return dexCount > 0 && webKind == nil ? .java : nil }
        if engine == "Unity 6" { return .java }
        if engine?.hasPrefix("Unity") == true { return .unity }
        if engine == "Cocos" { return libraries.contains(where: { $0.name == "libfmod.so" }) ? .cocos : .java }
        if engine == "Minecraft" { return .minecraft }
        if engine == "SDL", libraries.contains(where: { $0.name.hasPrefix("libdxvk") }) { return .sdl }
        if engine == "SDL" || engine == "Python" { return .java }
        if engine == "Unreal Engine" { return .ue4 }
        if engine == "Rockstar" { return .gta }
        if engine == "Godot" { return .godot }
        if engine == "NativeActivity" { return .nativeactivity }
        if engine == "Flutter" { return .java }
        if engine == "GameMaker" { return .gamemaker }
        if engine == "libGDX" || engine == "Java" || engine == "React Native" || engine == ".NET / Xamarin" { return .java }
        if engine == nil, dexCount > 0 { return .java }
        return nil
    }

    public var runsOnNativeRuntime: Bool { nativeEngine != nil }

    public var nativeEngineName: String {
        engine == "Python" ? "Python (Kivy)" :
        nativeEngine == .cocos ? "Cocos2d-x" :
        nativeEngine == .minecraft ? "Minecraft" :
        nativeEngine == .sdl ? "SDL" :
        nativeEngine == .ue4 ? "Unreal Engine" :
        nativeEngine == .gta ? "Rockstar" :
        nativeEngine == .godot ? "Godot" :
        nativeEngine == .nativeactivity ? "NativeActivity" :
        nativeEngine == .flutter ? "Flutter" :
        nativeEngine == .gamemaker ? "GameMaker" :
        nativeEngine == .java ? (engine == "libGDX" ? "libGDX" : engine == "SDL" ? "SDL" : engine == "Flutter" ? "Flutter" : "Android") : "Unity"
    }

    public var displaySummary: String {
        guard runsOnNativeRuntime else { return summary }
        let flagged = libraries.filter { $0.abi == "arm64-v8a" && $0.status != "ok" }.count
        let total = libraries.filter { $0.abi == "arm64-v8a" }.count
        var text = nativeEngine == .flutter
            ? "A Flutter app. Its engine and its compiled Dart run natively through Husk's translation layer, which loads its \(total) arm64 libraries itself."
            : nativeEngine == .java && engine != "libGDX"
            ? "An Android app. Husk runs its code on its own Java runtime" + (total > 0 ? " and loads its \(total) arm64 libraries itself." : ".")
            : "A \(nativeEngineName) game. It runs through Husk's native runtime, which loads its \(total) arm64 libraries itself."
        if nativeEngine == .cocos || nativeEngine == .minecraft || nativeEngine == .ue4 || nativeEngine == .gta { text += " It is a landscape game: Husk turns the screen for it." }
        else if nativeEngine == .sdl || nativeEngine == .nativeactivity || nativeEngine == .godot || nativeEngine == .gamemaker { text += " Husk turns the screen the way the game asks for." }
        if flagged > 0 {
            text += " \(flagged) of them use tricks the older loader could not handle; the native runtime handles those too, "
                  + "except for optional anti-tamper code, which it leaves out."
        }
        return text
    }
}

public struct TLCheck: Decodable, Identifiable {
    public let id: String
    public let title: String
    public let status: String
    public let detail: String
}

// MARK: - TLApp Model

public struct TLApp: Identifiable, Hashable {
    public let id: String
    public var label: String
    public var iconPath: String?
    public var apks: [String]
    public var report: TLReport?
    public var lastPlayed: Date?
    public var packageName: String?

    public var isGameCategory: Bool { false }

    public var isGame: Bool {
        if let engine = report?.nativeEngine {
            return engine != .flutter
        }
        return report?.engine != "Flutter"
    }


    public var screenEngine: TLNativeEngine {
        report?.nativeEngine ?? .unity
    }

    public var nativeDataDir: String {
        let dir = TranslationLayer.root.appendingPathComponent(id, isDirectory: true)
        let sub: String
        switch screenEngine {
        case .unity: sub = "unity-data"
        case .cocos: sub = "cocos-data"
        case .minecraft: sub = "minecraft-data"
        case .sdl: sub = "sdl-data"
        case .ue4: sub = "ue4-data"
        case .gta: sub = "gta-data"
        case .godot: sub = "godot-data"
        case .nativeactivity: sub = "na-data"
        case .flutter: sub = "flutter-data"
        case .gamemaker: sub = "gm-data"
        case .java: sub = "java-data"
        }
        let folder = dir.appendingPathComponent(sub, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.path
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: TLApp, rhs: TLApp) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Translation Layer Store for macOS

@MainActor
public final class TranslationLayerStore: ObservableObject {
    public static let shared = TranslationLayerStore()

    @Published public private(set) var apps: [TLApp] = []
    @Published public private(set) var busy: String?
    @Published public private(set) var checks: [TLCheck] = []
    @Published public private(set) var checking = false
    @Published public var lastError: String?

    nonisolated public static let scanVersion = 8

    private init() {
        reload()
    }

    public func reload() {
        let root = TranslationLayer.root
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        apps = dirs.compactMap(Self.load).sorted {
            $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    public func markPlayed(_ app: TLApp) {
        let dir = TranslationLayer.root.appendingPathComponent(app.id, isDirectory: true)
        try? "\(Date().timeIntervalSince1970)".write(to: dir.appendingPathComponent("last-played.txt"), atomically: true, encoding: .utf8)
        reload()
    }

    public func rename(_ app: TLApp, to name: String) {
        let dir = TranslationLayer.root.appendingPathComponent(app.id, isDirectory: true)
        try? name.write(to: dir.appendingPathComponent("label.txt"), atomically: true, encoding: .utf8)
        HuskLog.log("tl", "Renamed \(app.label) to \(name)")
        reload()
    }

    public func remove(_ app: TLApp) {
        let dir = TranslationLayer.root.appendingPathComponent(app.id, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        HuskLog.log("tl", "Removed \(app.label)")
        reload()
    }

    public func add(_ urls: [URL], move: Bool = false) {
        guard !urls.isEmpty, busy == nil else { return }
        busy = urls.count == 1 ? "Adding \(urls[0].lastPathComponent)…" : "Adding \(urls.count) APKs…"
        Task.detached(priority: .userInitiated) {
            let failure = Self.ingest(urls, move: move)
            await MainActor.run {
                self.busy = nil
                self.lastError = failure
                self.reload()
            }
        }
    }

    public func runChecks() {
        guard !checking else { return }
        checking = true
        Task.detached(priority: .userInitiated) {
            HuskLog.log("tl", "Running device checks on macOS...")
            // On Apple Silicon Mac, JIT execution is tested directly
            let raw = husk_tl_run_checks(true)
            let json = raw.map { String(cString: $0) } ?? "[]"
            husk_tl_free(raw)
            let parsed = (try? JSONDecoder().decode([TLCheck].self, from: Data(json.utf8))) ?? []
            HuskLog.log("tl", "Device checks finished with \(parsed.count) results")
            await MainActor.run {
                self.checks = parsed
                self.checking = false
            }
        }
    }

    // MARK: - Internal Load & Ingest

    nonisolated private static func load(_ dir: URL) -> TLApp? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return nil }
        let names = files.filter { $0.lowercased().hasSuffix(".apk") }
        let apks = names.sorted { a, b in
            let ra = BundleUnpacker.rank(a, siblings: names)
            let rb = BundleUnpacker.rank(b, siblings: names)
            return ra != rb ? ra < rb : a < b
        }.map { dir.appendingPathComponent($0).path }

        guard let first = apks.first else { return nil }

        let saved = try? String(contentsOf: dir.appendingPathComponent("label.txt"), encoding: .utf8)
        let label = saved?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let icon = dir.appendingPathComponent("icon.png").path
        let report = (try? Data(contentsOf: dir.appendingPathComponent("report.json")))
            .flatMap { try? JSONDecoder().decode(TLReport.self, from: $0) }
        let played = (try? String(contentsOf: dir.appendingPathComponent("last-played.txt"), encoding: .utf8))
            .flatMap { TimeInterval($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .map { Date(timeIntervalSince1970: $0) }
        let pkg = (try? String(contentsOf: dir.appendingPathComponent("package.txt"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return TLApp(
            id: dir.lastPathComponent,
            label: label.isEmpty ? (first as NSString).lastPathComponent : label,
            iconPath: fm.fileExists(atPath: icon) ? icon : nil,
            apks: apks,
            report: report,
            lastPlayed: played,
            packageName: pkg
        )
    }

    nonisolated private static func ingest(_ urls: [URL], move: Bool = false) -> String? {
        let fm = FileManager.default
        let dir = TranslationLayer.root.appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }

                let ext = url.pathExtension.lowercased()
                if BundleUnpacker.extensions.contains(ext) {
                    let names = try BundleUnpacker.unpack(url, into: dir)
                    HuskLog.log("tl", "Unpacked \(url.lastPathComponent): \(names.joined(separator: ", "))")
                    if move { try? fm.removeItem(at: url) }
                    continue
                }

                var name = url.lastPathComponent
                if !name.lowercased().hasSuffix(".apk") { name += ".apk" }
                let dest = dir.appendingPathComponent(name)
                if move {
                    try fm.moveItem(at: url, to: dest)
                } else {
                    try fm.copyItem(at: url, to: dest)
                }
            }
        } catch {
            try? fm.removeItem(at: dir)
            HuskLog.log("tl", "Failed to add APK: \(error.localizedDescription)")
            return "Failed to import APK: \(error.localizedDescription)"
        }

        let apks = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
            .filter { $0.hasSuffix(".apk") }.sorted()
            .map { dir.appendingPathComponent($0).path }

        describe(apks, into: dir)
        let json = scan(apks)
        try? Data(json.utf8).write(to: dir.appendingPathComponent("report.json"))
        try? "\(scanVersion)".write(to: dir.appendingPathComponent("scan-version.txt"), atomically: true, encoding: .utf8)
        HuskLog.log("tl", "Report generated for \(dir.lastPathComponent)")
        return nil
    }

    nonisolated private static func describe(_ apks: [String], into dir: URL) {
        func size(_ path: String) -> Int {
            ((try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? NSNumber)?.intValue ?? 0
        }
        let ordered = apks.sorted { a, b in
            let aBase = (a as NSString).lastPathComponent == "base.apk"
            let bBase = (b as NSString).lastPathComponent == "base.apk"
            return aBase != bBase ? aBase : size(a) > size(b)
        }

        for apk in ordered {
            guard let manifest = entry(apk, "AndroidManifest.xml", limit: 8 << 20),
                  let arsc = entry(apk, "resources.arsc", limit: 64 << 20) else { continue }
            let info = ApkMetadata.read(manifest: manifest, resources: arsc)
            guard info.label != nil || info.iconEntry != nil else { continue }

            if let package = ApkMetadata.packageName(manifest) {
                try? package.write(to: dir.appendingPathComponent("package.txt"), atomically: true, encoding: .utf8)
            }
            if let label = info.label {
                try? label.write(to: dir.appendingPathComponent("label.txt"), atomically: true, encoding: .utf8)
            }

            if let iconEntry = info.iconEntry {
                if iconEntry.hasSuffix(".xml") {
                    if let layers = adaptiveLayers(apk, xml: iconEntry, resources: arsc) {
                        if let comp = NSImage.composeAdaptive(background: layers.back, backgroundColor: layers.color, foreground: layers.fore),
                           let png = comp.pngData() {
                            try? png.write(to: dir.appendingPathComponent("icon.png"))
                        }
                    }
                } else if let data = entry(apk, iconEntry, limit: 16 << 20),
                          let img = NSImage(data: data),
                          let png = img.pngData() {
                    try? png.write(to: dir.appendingPathComponent("icon.png"))
                }
            }
            return
        }
    }

    nonisolated private static func adaptiveLayers(_ apk: String, xml: String, resources: Data) -> (fore: NSImage?, back: NSImage?, color: UInt32?)? {
        guard let data = entry(apk, xml, limit: 4 << 20) else { return nil }
        let layers = ApkMetadata.adaptiveLayers(data)
        func picture(_ id: UInt32?) -> NSImage? {
            guard let id, let path = ApkMetadata.bitmap(for: id, resources: resources), !path.hasSuffix(".xml"),
                  let bytes = entry(apk, path, limit: 16 << 20) else { return nil }
            return NSImage(data: bytes)
        }
        let fore = picture(layers.foreground)
        let back = picture(layers.background)
        var color = layers.backgroundColor
        if color == nil, back == nil, let id = layers.background {
            color = ApkMetadata.color(for: id, resources: resources)
        }
        guard fore != nil || back != nil || color != nil else { return nil }
        return (fore: fore, back: back, color: color)
    }

    nonisolated public static func entry(_ apk: String, _ name: String, limit: Int) -> Data? {
        var length = 0
        guard let bytes = husk_tl_read_entry(apk, name, limit, &length) else { return nil }
        defer { husk_tl_free(bytes) }
        return Data(bytes: bytes, count: length)
    }

    nonisolated public static func scan(_ paths: [String]) -> String {
        let owned = paths.map { strdup($0) }
        defer { owned.forEach { free($0) } }
        let pointers = owned.map { UnsafePointer<CChar>($0) }
        let raw = pointers.withUnsafeBufferPointer {
            husk_tl_scan($0.baseAddress, Int32($0.count))
        }
        defer { husk_tl_free(raw) }
        return raw.map { String(cString: $0) } ?? "{}"
    }
}
