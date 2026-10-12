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

enum Theme {
    static let accent = Color.accentColor
    static let good = Color.green
    static let warn = Color.orange
    static let error = Color.red

    static var text: Color { Color.primary }
    static var textDim: Color { Color.secondary }
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
