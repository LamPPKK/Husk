// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import os

// MARK: - Core Paths & Environment

enum TranslationLayer {
    static let devInfoKey = "husk.devInfo"

    /// The base folder for Husk data on macOS: ~/Library/Application Support/Husk
    static var baseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Husk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// TranslationLayer folder: one folder per app
    static var root: URL {
        let dir = baseDirectory.appendingPathComponent("TranslationLayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Shared storage: what Android apps see as /sdcard
    static var sharedStorage: URL {
        let dir = baseDirectory.appendingPathComponent("Shared Storage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Check if currently executing on Apple Silicon
    static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Logging

enum HuskLog {
    private static let osLog = Logger(subsystem: "com.husk.mac", category: "husk")
    private static let lock = NSLock()
    private static var ring: [String] = []
    private static let ringLimit = 4000
    private static let startTime = Date()

    static var logFileURL: URL {
        TranslationLayer.baseDirectory.appendingPathComponent("husk.log")
    }

    static func start() {
        // Rotate previous log
        let prev = TranslationLayer.baseDirectory.appendingPathComponent("husk-prev.log")
        try? FileManager.default.removeItem(at: prev)
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            try? FileManager.default.moveItem(at: logFileURL, to: prev)
        }
        log("boot", "================ Husk macOS Starting ================")
        log("boot", "OS: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        log("boot", "Architecture: \(isAppleSiliconArch ? "arm64 (Apple Silicon)" : "x86_64")")
        log("boot", "Physical Memory: \(ProcessInfo.processInfo.physicalMemory / (1024 * 1024)) MiB")
        log("boot", "Root Directory: \(TranslationLayer.root.path)")
    }

    private static var isAppleSiliconArch: Bool {
        var sysinfo = utsname(); uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return machine.contains("arm64")
    }

    static func log(_ category: String, _ message: String) {
        let t = Date().timeIntervalSince(startTime) * 1000
        let line = String(format: "[%9.2fms][%@] %@", t, category, message)
        
        lock.lock()
        ring.append(line)
        if ring.count > ringLimit { ring.removeFirst(ring.count - ringLimit) }
        lock.unlock()

        osLog.log("\(line, privacy: .public)")

        if let data = (line + "\n").data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: logFileURL, options: .atomic)
            }
        }
    }

    static var deviceModel: String { "Mac (Apple Silicon)" }

    static func flushNow() {}

    static func recentLines(_ count: Int = 400) -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(ring.suffix(count))
    }
}

// MARK: - NSImage Extensions for Adaptive Icons

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Compose an Android adaptive icon: background + foreground on standard canvas
    static func composeAdaptive(background: NSImage?, backgroundColor: UInt32?, foreground: NSImage?, size: CGFloat = 256) -> NSImage? {
        guard background != nil || backgroundColor != nil || foreground != nil else { return nil }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)

        // Android 108 unit grid, with 72 unit visible safe circle/square in the center.
        // Scale ratio: 108 / 72 = 1.5x canvas size
        let canvasSide = size * 1.5
        let offset = -(canvasSide - size) / 2
        let canvasRect = NSRect(x: offset, y: offset, width: canvasSide, height: canvasSide)

        // Draw background
        if let colorVal = backgroundColor {
            let a = CGFloat((colorVal >> 24) & 0xFF) / 255.0
            let r = CGFloat((colorVal >> 16) & 0xFF) / 255.0
            let g = CGFloat((colorVal >> 8) & 0xFF) / 255.0
            let b = CGFloat(colorVal & 0xFF) / 255.0
            NSColor(red: r, green: g, blue: b, alpha: a).setFill()
            rect.fill()
        } else if background == nil {
            NSColor.white.setFill()
            rect.fill()
        }

        background?.draw(in: canvasRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        foreground?.draw(in: canvasRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        image.unlockFocus()
        return image
    }
}

// MARK: - Theme System for macOS

extension Theme {
    static let warn = Color.orange
    static let error = Color.red

    static var background: Color { Color(NSColor.windowBackgroundColor) }
    static var secondaryBackground: Color { Color(NSColor.controlBackgroundColor) }
    static var cardBackground: Color { Color(NSColor.alternatingContentBackgroundColors.first ?? .controlBackgroundColor) }
    static var border: Color { Color(NSColor.separatorColor) }

    static func engineBadgeColor(for engine: TLNativeEngine?) -> Color {
        switch engine {
        case .unity: return .purple
        case .cocos: return .blue
        case .minecraft: return .green
        case .sdl: return .orange
        case .ue4: return .indigo
        case .godot: return .cyan
        case .gta: return .yellow
        case .flutter: return .teal
        case .gamemaker: return .pink
        case .java: return .brown
        default: return .gray
        }
    }
}

// MARK: - Native Mac Card Modifier

struct MacCardStyle: ViewModifier {
    var isHovered: Bool = false
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.9 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isHovered ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: isHovered ? Color.black.opacity(0.2) : Color.black.opacity(0.08), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
    }
}

extension View {
    func macCard(isHovered: Bool = false, cornerRadius: CGFloat = 14) -> some View {
        self.modifier(MacCardStyle(isHovered: isHovered, cornerRadius: cornerRadius))
    }
}

// MARK: - Compatibility Shims for Original Husk UI

@MainActor
final class AndroidHost: ObservableObject {
    static let shared = AndroidHost()

    struct Package: Identifiable, Hashable, Codable {
        var id: String { name }
        var name: String
        var label: String
        var category: String?
        var iconPath: String?
        var lastUsed: Date?
        var version: String? = nil
        var sizeBytes: Int64? = nil
        var bitness: String? = "64-bit"

        init(name: String, label: String, category: String? = nil, iconPath: String? = nil, lastUsed: Date? = nil, version: String? = nil, sizeBytes: Int64? = nil, bitness: String? = "64-bit") {
            self.name = name
            self.label = label
            self.category = category
            self.iconPath = iconPath
            self.lastUsed = lastUsed
            self.version = version
            self.sizeBytes = sizeBytes
            self.bitness = bitness
        }
    }

    struct GuestEntry: Identifiable, Hashable {
        var id: String { path }
        var path: String
        var name: String
        var isDirectory: Bool
        var size: Int64
        var modified: Date?
    }

    @Published private(set) var packages: [Package] = []
    @Published var busy: String? = nil
    @Published var toast: Toast? = nil
    var isReady: Bool { true }

    func waitForReady() {}
    func launch(_ package: String, then: @escaping () -> Void) { then() }
    func install(_ urls: [URL]) {
        TranslationLayerStore.shared.add(urls)
    }
    static func forgetIcons() {}
    func list(_ where_: String) throws -> [GuestEntry] { [] }
    func freeSpace(at: String) -> (free: Int64, total: Int64)? {
        (free: 100 * 1024 * 1024 * 1024, total: 256 * 1024 * 1024 * 1024)
    }
    static func quote(_ s: String) -> String { "\"\(s)\"" }
    static func pretty(_ s: String) -> String { s }
    func refreshPackages() async {}
    func sendFiles(_ urls: [URL], to: String) {}
    func installFromGuest(_ path: String, name: String) {}
    func uninstall(_ package: String) {}
}

enum JITMethod: String, CaseIterable, Identifiable {
    case builtIn = "Native Apple Silicon"
    case stikDebug = "Debugger"
    case trollStore = "TrollStore"
    case jailbreak = "Jailbreak"
    case automatic = "Automatic"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .builtIn: return "Apple Silicon"
        case .stikDebug: return "Debugger"
        case .trollStore: return "TrollStore"
        case .jailbreak: return "Jailbreak"
        case .automatic: return "Automatic"
        }
    }
}

@MainActor
final class JITCoordinator: ObservableObject {
    static let shared = JITCoordinator()
    static let autoEnableKey = "husk.jit.auto"

    enum PairingSource: Equatable {
        case onDevice
        case imported
    }

    @Published var attachGeneration: Int = 0
    @Published var error: String? = nil
    @Published var method: JITMethod = .builtIn
    @Published var busy: Bool = false
    @Published var status: String? = nil
    @Published var showSetup: Bool = false
    @Published var pairingSource: PairingSource? = nil

    var automaticDescription: String { "Native Apple Silicon hardware JIT is active." }
    var resolvedMethod: JITMethod { .builtIn }
    func enable() {}
}

enum HuskBuiltInJIT {
    static var isAvailable: Bool { true }
    static var unavailableReason: String? { nil }
}

enum JITBootstrap {
    static var ready: Bool { true }
    static var keepDebuggerAttached: Bool = false
    static var isStikDebugInstalled: Bool { true }
    static var isTrollStoreInstalled: Bool { false }
    static var isInstalledWithTrollStore: Bool { false }
    static var debuggedAtLaunch: Bool { false }
    static var isJailbroken: Bool { false }
    static var isDebuggerAttached: Bool { true }
    static var isLive: Bool { true }
    static var prewarmed: Bool { true }
    static var deviceEnforcesTXM: Bool { false }
    static var mapJITResult: Bool? { true }
    static var detached: Bool { false }
    static var lastFailure: String? { nil }
    static func prewarm() {}
    static func requestTrollStoreAttach() -> Bool { false }
}

@MainActor
final class GuestImage: ObservableObject {
    static let shared = GuestImage()
    static let askUpdatesKey = "husk.guest.updates"
    static var imageVersion: String { "macOS ARM" }

    struct UpdateInfo {
        var isSomething: Bool { false }
        var title: String { "Android System Update" }
        init() {}
    }

    enum State: Equatable {
        case missing
        case downloading(progress: Double, received: Int64, total: Int64)
        case installing
        case failed(String)
        case ready
    }

    @Published var state: State = .ready
    @Published var exists: Bool = true
    @Published var isRunning: Bool = false
    @Published var update: UpdateInfo = UpdateInfo()

    func download() {}
    func applyUpdate() {}
    func cancel() {}
}

@MainActor
final class QemuRunner: ObservableObject {
    static let shared = QemuRunner()
    nonisolated(unsafe) static var lastGuestRes = (w: 1920, h: 1080)
    static func validResolution(w: Int, h: Int) -> (w: Int, h: Int)? {
        guard w > 0 && h > 0 else { return nil }
        return (w: w, h: h)
    }

    enum DisplayKind: Equatable { case undecided, gl, software }

    @Published var isRunning: Bool = false
    @Published var fps: Double = 60.0
    @Published var bootProgress: Int = 0
    @Published var setupMessage: String? = nil
    @Published var isSavingState: Bool = false
    @Published var displayKind: DisplayKind = .gl

    var hasSnapshot: Bool { false }
    var snapshotDisplay: String? { nil }

    func forgetSnapshot() {}
    func forgetSnapshot(mode: String) -> Bool { false }
    func saveState(reason: String) {}
}

// MARK: - AppWindows & Multitasking Shim

@MainActor
final class AppWindows: ObservableObject {
    static let shared = AppWindows()
    static let defaultKey = "husk.multitask"
    static var defaultWindowed: Bool { true }

    static func opensInWindow(_ app: TLApp) -> Bool { true }

    func open(_ app: TLApp) {
        GameWindowController.shared.launchGame(app)
    }

    func close(_ only: TLApp? = nil) {}
}

// MARK: - Onboarding & AppClip Shim

enum Onboarding {
    static var needed: Bool { false }
    static var autoStart: Bool { false }
    static func complete() {}
}

enum AppClip {
    static func generate(for app: TLApp) {}
}

// MARK: - HuskFilePicker Shim

@MainActor
enum HuskFilePicker {
    static func present(types: [UTType] = [.item], multiple: Bool = true,
                        onPick: @escaping ([URL]) -> Void, onFail: ((String) -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = multiple
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = types
        if panel.runModal() == .OK {
            onPick(panel.urls)
        }
    }
}

extension View {
    func huskFilePicker(isPresented: Binding<Bool>, types: [UTType] = [.item], multiple: Bool = true,
                        onPick: @escaping ([URL]) -> Void) -> some View {
        self.onChange(of: isPresented.wrappedValue) { show in
            if show {
                isPresented.wrappedValue = false
                HuskFilePicker.present(types: types, multiple: multiple, onPick: onPick)
            }
        }
    }
}

// MARK: - TLAttemptView & CrashReport

struct TLAttemptView: View {
    let app: TLApp
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Launching \(app.label)…")
                .font(.headline)
            ProgressView()
            Button("Done") { dismiss() }
        }
        .padding()
        .frame(minWidth: 260, minHeight: 160)
        .onAppear {
            TranslationLayerStore.shared.markPlayed(app)
            GameWindowController.shared.launchGame(app)
        }
    }
}

@MainActor
final class CrashReport: ObservableObject {
    static let shared = CrashReport()
    static func gameStarted(_ app: TLApp) {}
    static func gameEnded() {}
}

final class GuestBridge {
    static let shared = GuestBridge()
    func shell(_ cmd: String, timeout: TimeInterval = 10) throws -> String { "" }
    func run(_ cmd: String, timeout: TimeInterval = 10) throws -> String { "" }
    func isAlive(attempts: Int = 1) -> Bool { false }
}

// MARK: - Diagnostic & Test Views

struct JITCard: View {
    init() {}
    var body: some View {
        HStack {
            Image(systemName: "bolt.badge.checkmark.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Native Apple Silicon Execution")
                    .font(.subheadline.weight(.semibold))
                Text("Direct execution via macOS ARM hardware hypervisor/JIT permissions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MassTestView: View {
    init() {}
    var body: some View {
        VStack(spacing: 12) {
            Text("Automated APK Compatibility Testing")
                .font(.headline)
            Text("Batch verification engine for translation-layer compatibility")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 250)
    }
}

struct LogView: View {
    var isSheet = true
    @Environment(\.dismiss) private var dismiss
    @State private var lines: [String] = []
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(isSheet: Bool = true) { self.isSheet = isSheet }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .onReceive(tick) { _ in
            lines = HuskLog.recentLines(500)
        }
        .navigationTitle("Logs")
        .frame(minWidth: 500, minHeight: 350)
    }
}

typealias TLChecksView = DeviceChecksViewMac


