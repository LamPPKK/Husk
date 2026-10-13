// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsViewMac: View {
    @AppStorage("customAnglePath") private var customAnglePath: String = ""
    @AppStorage("defaultResolution") private var defaultResolution: String = "retina"
    @AppStorage("verboseLogging") private var verboseLogging: Bool = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            graphicsTab
                .tabItem {
                    Label("Graphics", systemImage: "display")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "hammer")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 380)
        .padding()
    }

    private var generalTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Translation Layer Sandbox")
                        .font(.headline)
                    Text(TranslationLayer.root.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)

                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: TranslationLayer.root.path)
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Shared Storage (Android /sdcard)")
                        .font(.headline)
                    Text(TranslationLayer.sharedStorage.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)

                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: TranslationLayer.sharedStorage.path)
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var graphicsTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ANGLE / OpenGL ES Driver")
                        .font(.headline)
                    Text("Husk uses ANGLE to translate OpenGL ES 2.0 / 3.0 API calls into native Apple Metal commands.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("Auto-detect (System / Chromium / Homebrew)", text: $customAnglePath)
                            .textFieldStyle(.roundedBorder)

                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.title = "Select libEGL.dylib or libANGLE-shared.dylib"
                            if let dylibType = UTType(filenameExtension: "dylib") {
                                panel.allowedContentTypes = [dylibType]
                            }
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                customAnglePath = url.path
                            }
                        }
                    }

                    if !customAnglePath.isEmpty {
                        Button("Reset to Default") {
                            customAnglePath = ""
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var advancedTab: some View {
        Form {
            Section {
                Toggle("Verbose Translation Layer Logs", isOn: $verboseLogging)
                    .help("Prints detailed linker and bionic syscall traces to stderr.")

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Cache & Maintenance")
                        .font(.headline)

                    Button("Reload Library") {
                        TranslationLayerStore.shared.reload()
                    }

                    Button("Run Translation Layer Diagnostics") {
                        TranslationLayerStore.shared.runChecks()
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Husk for macOS")
                .font(.title2.weight(.bold))

            #if arch(x86_64)
            Text("Version 1.0.0 (Intel x86_64)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Husk executes Android binaries on Intel macOS with a high-performance translation layer, Dalvik virtual machine, Bionic libc shim, and Metal graphics backend.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            #else
            Text("Version 1.0.0 (Native Apple Silicon ARM64)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Husk executes 64-bit ARM64 Android binaries directly on Apple Silicon CPUs with a high-performance native translation layer, Bionic libc shim, and Metal graphics backend.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            #endif

            Spacer()

            Link("GitHub Repository", destination: URL(string: "https://github.com/LamPPKK/Husk")!)
                .font(.caption)
        }
        .padding()
    }
}
