// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct HuskMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add APK…") {
                    promptAddAPK()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Shared Storage") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: TranslationLayer.sharedStorage.path)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("Translation Layer") {
                Button("Run Diagnostics") {
                    TranslationLayerStore.shared.runChecks()
                }

                Button("Reload Library") {
                    TranslationLayerStore.shared.reload()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsViewMac()
        }
    }

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
            TranslationLayerStore.shared.add(panel.urls)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HuskLog.start()
        #if arch(x86_64)
        HuskLog.log("app", "Husk for macOS initialized on Intel (x86_64).")
        #else
        HuskLog.log("app", "Husk for macOS initialized on Apple Silicon.")
        #endif
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let valid = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return ["apk", "xapk", "apkm", "apks"].contains(ext)
        }
        if !valid.isEmpty {
            TranslationLayerStore.shared.add(valid)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
