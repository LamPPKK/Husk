// SPDX-License-Identifier: GPL-2.0-or-later
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import SwiftUI
import Combine

// MARK: - UIKit Typealiases
public typealias UIColor = NSColor
public typealias UIImage = NSImage
public typealias UIFont = NSFont
public typealias UIEdgeInsets = NSEdgeInsets

public enum UIUserInterfaceStyle: Int {
    case unspecified = 0
    case light = 1
    case dark = 2
}

// MARK: - UIDevice Shim
public final class UIDevice {
    public static let current = UIDevice()
    public enum UIUserInterfaceIdiom: Int {
        case unspecified = -1
        case phone = 0
        case pad = 1
        case tv = 2
        case carPlay = 3
        case mac = 5
    }
    // Return .pad so tablet/desktop sizing is used
    public var userInterfaceIdiom: UIUserInterfaceIdiom { .pad }
    public var model: String { "Mac" }
    public var systemName: String { "macOS" }
    public var systemVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }
    public var name: String { Host.current().localizedName ?? "Mac" }
}

// MARK: - UIApplication Shim
public enum UIApplicationState: Int {
    case active = 0, inactive = 1, background = 2
}

public typealias UIBackgroundTaskIdentifier = UIApplication.UIBackgroundTaskIdentifier

public final class UIApplication {
    public static let shared = UIApplication()
    public static let willResignActiveNotification = NSApplication.willResignActiveNotification
    public static let didBecomeActiveNotification = NSApplication.didBecomeActiveNotification

    public var applicationState: UIApplicationState { .active }
    public var alternateIconName: String? { nil }
    public var supportsAlternateIcons: Bool { false }
    public func setAlternateIconName(_ name: String?, completionHandler: ((Error?) -> Void)? = nil) {
        completionHandler?(nil)
    }
    public func open(_ url: URL, options: [String: Any] = [:], completionHandler: ((Bool) -> Void)? = nil) {
        let ok = NSWorkspace.shared.open(url)
        completionHandler?(ok)
    }
    public struct UIBackgroundTaskIdentifier: RawRepresentable, Equatable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let invalid = UIBackgroundTaskIdentifier(rawValue: 0)
    }
    public func beginBackgroundTask(withName name: String? = nil, expirationHandler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier {
        .invalid
    }
    public func beginBackgroundTask(expirationHandler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier {
        .invalid
    }
    public func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {}
}

// MARK: - Pasteboard Shim
public final class UIPasteboard {
    public static let general = UIPasteboard()
    public var string: String? {
        get { NSPasteboard.general.string(forType: .string) }
        set {
            if let newValue {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(newValue, forType: .string)
            }
        }
    }
}

// MARK: - Haptic Feedback Shims
public final class UIImpactFeedbackGenerator {
    public enum FeedbackStyle { case light, medium, heavy, soft, rigid }
    public init(style: FeedbackStyle = .medium) {}
    public func prepare() {}
    public func impactOccurred() {}
}

public final class UINotificationFeedbackGenerator {
    public enum FeedbackType { case success, warning, error }
    public init() {}
    public func prepare() {}
    public func notificationOccurred(_ type: FeedbackType) {}
}

// MARK: - NSColor iOS Extensions
public extension NSColor {
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }
    static var tertiarySystemGroupedBackground: NSColor { .controlBackgroundColor }
    static var secondarySystemBackground: NSColor { .controlBackgroundColor }
    static var tertiarySystemFill: NSColor { .quaternaryLabelColor }
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var label: NSColor { .labelColor }
    static var secondaryLabel: NSColor { .secondaryLabelColor }
    static var tertiaryLabel: NSColor { .tertiaryLabelColor }
    static var quaternaryLabel: NSColor { .quaternaryLabelColor }
    static var separator: NSColor { .separatorColor }
    static var opaqueSeparator: NSColor { .separatorColor }
    static var link: NSColor { .linkColor }
    
    func getRed(_ r: inout CGFloat, green g: inout CGFloat, blue b: inout CGFloat, alpha a: inout CGFloat) {
        if let rgb = self.usingColorSpace(.sRGB) {
            rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        } else {
            r = 0; g = 0; b = 0; a = 1
        }
    }
}

// MARK: - SwiftUI Color & Image Bridges
public extension Color {
    init(uiColor: NSColor) { self.init(nsColor: uiColor) }
}

public extension Image {
    init(uiImage: NSImage) { self.init(nsImage: uiImage) }
}

public extension NSEdgeInsets {
    static let zero = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
}

public extension EdgeInsets {
    init() { self.init(top: 0, leading: 0, bottom: 0, trailing: 0) }
}

// MARK: - Navigation & Toolbar Shims
public extension ToolbarItemPlacement {
    static var topBarTrailing: ToolbarItemPlacement { .primaryAction }
    static var topBarLeading: ToolbarItemPlacement { .cancellationAction }
    static var bottomBar: ToolbarItemPlacement { .status }
}

public extension ToolbarPlacement {
    static var navigationBar: ToolbarPlacement { .automatic }
    static var bottomBar: ToolbarPlacement { .automatic }
}

// MARK: - NSImage / CGImage Support
public extension NSImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

// MARK: - Text Input & Sheets Shims
public enum TextInputAutocapitalization {
    case never, words, sentences, characters
}

public enum UIKeyboardType {
    case defaultType, URL, emailAddress, numbersAndPunctuation, numberPad, phonePad
    public static let `default` = UIKeyboardType.defaultType
}

public extension View {
    func textInputAutocapitalization(_ style: TextInputAutocapitalization?) -> some View {
        self
    }

    func keyboardType(_ type: UIKeyboardType) -> some View {
        self
    }

    func fullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        self.sheet(item: item, onDismiss: onDismiss, content: content)
    }

    func fullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
}

// MARK: - ShareSheet Shim
public struct ShareSheet: View {
    public let items: [Any]
    public init(items: [Any]) { self.items = items }
    public var body: some View {
        VStack(spacing: 12) {
            Text("Share")
                .font(.headline)
            ForEach(0..<items.count, id: \.self) { idx in
                if let str = items[idx] as? String {
                    Text(str).lineLimit(3)
                } else if let url = items[idx] as? URL {
                    Text(url.lastPathComponent)
                }
            }
            Button("Copy to Clipboard") {
                if let first = items.first as? String {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(first, forType: .string)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(minWidth: 240, minHeight: 120)
    }
}

// MARK: - C Bridge Stubs
public func husk_ios_jit_self_route() -> UnsafePointer<CChar>? { nil }
public func husk_apk_is_game(_ path: String) -> Int32 { 0 }

#endif

