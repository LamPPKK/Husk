// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import QuartzCore
import GameController
import SwiftUI

// MARK: - AppKit Game Metal View

final class MacGameView: NSView {
    private let app: TLApp
    private let settings: TLAppSettings
    private var launched = false
    private var activeTouches: [String: Int32] = [:]

    var onPerformanceUpdate: ((String, Int) -> Void)?

    init(app: TLApp, settings: TLAppSettings) {
        self.app = app
        self.settings = settings
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer = makeBackingLayer()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func makeBackingLayer() -> CALayer {
        let metal = CAMetalLayer()
        metal.pixelFormat = .bgra8Unorm
        metal.framebufferOnly = true
        metal.isOpaque = true
        return metal
    }

    override var wantsUpdateLayer: Bool { true }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            layoutIfReady()
        }
    }

    override func layout() {
        super.layout()
        layoutIfReady()
    }

    private func layoutIfReady() {
        guard !launched, window != nil, bounds.width > 10, bounds.height > 10 else { return }

        let scale = settings.resolution.scale
        guard let metal = layer as? CAMetalLayer else { return }
        metal.contentsScale = scale

        let w = Int((bounds.width * scale).rounded())
        let h = Int((bounds.height * scale).rounded())
        metal.drawableSize = CGSize(width: w, height: h)

        launched = true
        launchEngine(width: w, height: h)
    }

    // MARK: - Engine Launch

    private func launchEngine(width: Int, height: Int) {
        guard let apk = app.apks.first else { return }

        let dataDir = app.nativeDataDir
        let caPath = Bundle.main.path(forResource: "cacert", ofType: "pem") ?? ""
        let anglePath = detectAnglePath()

        HuskLog.log("engine", "Launching \(app.label) (\(app.screenEngine.displayName)) at \(width)x\(height)")
        HuskLog.log("engine", "ANGLE library: \(anglePath)")

        let metalLayerPtr = Unmanaged.passUnretained(layer!).toOpaque()

        // Set shared storage
        husk_native_set_shared_storage(TranslationLayer.sharedStorage.path)

        // Add split packages if any
        for extra in app.apks.dropFirst().prefix(15) {
            husk_native_add_package(extra)
        }

        var started = false
        switch app.screenEngine {
        case .unity:
            started = husk_unity_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .cocos:
            // Check Geode
            let geodeFolder = GeodeSupport.folder(app.id)
            let geodeZip = geodeFolder.appendingPathComponent("geode-android64.zip").path
            let launcherApk = geodeFolder.appendingPathComponent("geode-launcher.apk").path
            if settings.geode && FileManager.default.fileExists(atPath: geodeZip) && FileManager.default.fileExists(atPath: launcherApk) {
                husk_cocos_set_geode(geodeZip, launcherApk)
            }
            started = husk_cocos_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .minecraft:
            started = husk_gameactivity_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .sdl:
            started = husk_sdl_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .gta:
            started = husk_gta_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .ue4:
            started = husk_ue4_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .godot:
            started = husk_godot_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .nativeactivity:
            started = husk_ue4_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .gamemaker:
            started = husk_gamemaker_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .flutter:
            husk_flutter_set_pixel_ratio(Float(settings.resolution.scale))
            started = husk_flutter_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        case .java:
            started = husk_java_launch(apk, dataDir, metalLayerPtr, Int32(width), Int32(height), anglePath, caPath)
        }

        if !started {
            HuskLog.log("engine", "Engine launch refused or failed to start")
        }
    }

    private func detectAnglePath() -> String {
        // 1. App Bundle private framework
        if let bundleFrameworks = Bundle.main.privateFrameworksPath {
            let inside = (bundleFrameworks as NSString).appendingPathComponent("libANGLE-shared.dylib")
            if FileManager.default.fileExists(atPath: inside) { return inside }
            let insideEGL = (bundleFrameworks as NSString).appendingPathComponent("libEGL.dylib")
            if FileManager.default.fileExists(atPath: insideEGL) { return insideEGL }
        }

        // 2. Custom environment variable
        if let env = ProcessInfo.processInfo.environment["TL_ANGLE_EGL"], FileManager.default.fileExists(atPath: env) {
            return env
        }

        // 3. Known system/app paths
        let candidates = [
            "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/Current/Libraries/libEGL.dylib",
            "/Applications/Visual Studio Code.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries/libEGL.dylib",
            "/Applications/Brave Browser.app/Contents/Frameworks/Brave Browser Framework.framework/Versions/Current/Libraries/libEGL.dylib",
            "/opt/homebrew/lib/libEGL.dylib",
            "/usr/local/lib/libEGL.dylib"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }

        return "libEGL.dylib"
    }

    // MARK: - Mouse Input

    private func sendTouch(phase: Int32, event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let scale = settings.resolution.scale
        let x = Float(p.x * scale)
        let y = Float(p.y * scale)
        husk_unity_touch(phase, 0, x, y)
    }

    override func mouseDown(with event: NSEvent) {
        sendTouch(phase: 0, event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        sendTouch(phase: 1, event: event)
    }

    override func mouseUp(with event: NSEvent) {
        sendTouch(phase: 2, event: event)
    }

    // MARK: - Keyboard Input

    override func keyDown(with event: NSEvent) {
        let scale = Float(settings.resolution.scale)
        let cx = Float(bounds.width * CGFloat(scale) / 2)
        let cy = Float(bounds.height * CGFloat(scale) / 2)
        let dist = 150.0 * scale

        // Arrow keys: swipe emulation
        var dx: Float = 0
        var dy: Float = 0
        switch event.keyCode {
        case 123: dx = -dist // Left
        case 124: dx = dist  // Right
        case 126: dy = -dist // Up
        case 125: dy = dist  // Down
        case 49:             // Space: tap middle
            husk_unity_touch(0, 0, cx, cy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                husk_unity_touch(2, 0, cx, cy)
            }
            return
        default:
            // Send to SDL or Java key handlers if applicable
            let key = Int32(event.keyCode)
            husk_sdl_key(key, 1)
            husk_java_key(key, 1)
            return
        }

        // Perform swipe
        husk_unity_touch(0, 0, cx, cy)
        for i in 1...5 {
            let stepX = cx + dx * Float(i) / 5.0
            let stepY = cy + dy * Float(i) / 5.0
            husk_unity_touch(1, 0, stepX, stepY)
            usleep(8000)
        }
        husk_unity_touch(2, 0, cx + dx, cy + dy)
    }

    override func keyUp(with event: NSEvent) {
        let key = Int32(event.keyCode)
        husk_sdl_key(key, 0)
        husk_java_key(key, 0)
    }
}

// MARK: - Game Window Controller

@MainActor
public final class GameWindowController: NSWindowController, NSWindowDelegate {
    public static var current: GameWindowController?

    private let app: TLApp
    private let settings: TLAppSettings
    private var perfTimer: Timer?
    private var hudLabel: NSTextField?

    public init(app: TLApp) {
        self.app = app
        self.settings = TLAppSettings.load(app.id)

        // Choose window size based on orientation
        let isPortrait = settings.orientation == .portrait || (settings.orientation == .auto && app.screenEngine == .flutter)
        let width: CGFloat = isPortrait ? 480 : 1024
        let height: CGFloat = isPortrait ? 960 : 576

        let rect = NSRect(x: 100, y: 100, width: width, height: height)
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = app.label
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.center()

        super.init(window: window)
        window.delegate = self

        let gameView = MacGameView(app: app, settings: settings)
        gameView.frame = NSRect(origin: .zero, size: rect.size)
        gameView.autoresizingMask = [.width, .height]
        window.contentView = gameView

        if settings.showStats {
            setupHUD(in: window)
        }

        startPerfMonitoring()
    }

    required init?(coder: NSCoder) { fatalError() }

    public static func play(app: TLApp) {
        if let existing = current {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = GameWindowController(app: app)
        current = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupHUD(in window: NSWindow) {
        guard let contentView = window.contentView else { return }
        let hud = NSTextField(labelWithString: "Starting…")
        hud.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        hud.textColor = .white
        hud.backgroundColor = NSColor.black.withAlphaComponent(0.65)
        hud.isBezeled = false
        hud.isEditable = false
        hud.alignment = .center
        hud.wantsLayer = true
        hud.layer?.cornerRadius = 6
        hud.layer?.masksToBounds = true
        hud.frame = NSRect(x: contentView.bounds.width - 150, y: 10, width: 140, height: 22)
        hud.autoresizingMask = [.minXMargin, .maxYMargin]
        contentView.addSubview(hud)
        self.hudLabel = hud
    }

    private func startPerfMonitoring() {
        perfTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            var perf = husk_unity_perf()
            husk_unity_perf_snapshot(&perf)
            let frames = husk_unity_frames()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if perf.fps > 0 {
                    let text = String(format: "%.0f FPS · %.1f ms", perf.fps, perf.mean_ms)
                    self.hudLabel?.stringValue = text
                } else if frames > 0 {
                    self.hudLabel?.stringValue = "\(frames) frames"
                }
            }
        }
    }

    public func windowWillClose(_ notification: Notification) {
        perfTimer?.invalidate()
        perfTimer = nil
        husk_unity_set_paused(true)
        GameWindowController.current = nil
    }
}
