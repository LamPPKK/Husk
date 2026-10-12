// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit

struct GameDetailView: View {
    let app: TLApp
    @ObservedObject var store = TranslationLayerStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var settings: TLAppSettings
    @State private var showingDeleteConfirmation = false
    @State private var selectedTab = 0

    init(app: TLApp) {
        self.app = app
        _settings = State(initialValue: TLAppSettings.load(app.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                if let iconPath = app.iconPath, let nsImage = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
                } else {
                    Image(systemName: "gamecontroller.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .padding(10)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundColor(.accentColor)
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.label)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)

                    if let pkg = app.packageName {
                        Text(pkg)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text(app.screenEngine.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)

                        if let report = app.report {
                            Text(report.verdict)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(report.ok ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundColor(report.ok ? .green : .orange)
                                .cornerRadius(6)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    dismiss()
                    store.markPlayed(app)
                    GameWindowController.play(app: app)
                }) {
                    Label("Play Game", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Launch Settings").tag(0)
                Text("Native Libraries").tag(1)
                Text("Storage & Saves").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedTab == 0 {
                        settingsSection
                    } else if selectedTab == 1 {
                        librariesSection
                    } else {
                        storageSection
                    }
                }
                .padding()
            }

            Divider()

            // Footer actions
            HStack {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Uninstall", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 560, minHeight: 460)
        .confirmationDialog(
            "Are you sure you want to uninstall \(app.label)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                store.remove(app)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the game APKs and all saved data permanently.")
        }
    }

    // MARK: - Sections

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Label("Graphics & Display", systemImage: "display")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Resolution Scale")
                        Spacer()
                        Picker("", selection: $settings.resolution) {
                            ForEach(TLAppSettings.Resolution.allCases, id: \.self) { res in
                                Text(res.title).tag(res)
                            }
                        }
                        .frame(width: 160)
                        .onChange(of: settings.resolution) { _ in
                            settings.save(app.id)
                        }
                    }

                    HStack {
                        Text("Screen Orientation")
                        Spacer()
                        Picker("", selection: $settings.orientation) {
                            ForEach(TLAppSettings.Orientation.allCases, id: \.self) { o in
                                Text(o.title).tag(o)
                            }
                        }
                        .frame(width: 160)
                        .onChange(of: settings.orientation) { _ in
                            settings.save(app.id)
                        }
                    }

                    Toggle("Performance Readout (FPS HUD)", isOn: $settings.showStats)
                        .onChange(of: settings.showStats) { _ in
                            settings.save(app.id)
                        }
                }
                .padding(8)
            }

            if app.packageName == GeodeSupport.gamePackage {
                GroupBox(label: Label("Geode Mod Loader", systemImage: "puzzlepiece.fill")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable Geode Mods for Geometry Dash", isOn: $settings.geode)
                            .onChange(of: settings.geode) { newValue in
                                settings.save(app.id)
                                if newValue {
                                    Task {
                                        await GeodeSupport.shared.prepare(app)
                                    }
                                }
                            }

                        let status = GeodeSupport.shared.current(app)
                        HStack {
                            Text("Status:")
                                .foregroundColor(.secondary)
                            switch status {
                            case .idle:
                                Text("Ready to download")
                                    .foregroundColor(.secondary)
                            case .working(let msg):
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text(msg)
                                    .foregroundColor(.orange)
                            case .ready(let ver):
                                Text("Installed (\(ver))")
                                    .foregroundColor(.green)
                            case .failed(let err):
                                Text("Failed: \(err)")
                                    .foregroundColor(.red)
                            }
                        }
                        .font(.caption)
                    }
                    .padding(8)
                }
            }

            GroupBox(label: Label("Package Information", systemImage: "info.circle")) {
                VStack(alignment: .leading, spacing: 6) {
                    labeledRow("ID", value: app.id)
                    labeledRow("Target Engine", value: app.screenEngine.displayName)
                    if let report = app.report {
                        labeledRow("ABIs", value: report.abis.isEmpty ? "armeabi-v7a (Dex only)" : report.abis.joined(separator: ", "))
                        labeledRow("Dex Count", value: "\(report.dexCount) (\(formatBytes(report.dexBytes)))")
                    }
                    if let first = app.apks.first {
                        let size = (try? FileManager.default.attributesOfItem(atPath: first)[.size] as? Int64) ?? 0
                        labeledRow("Size on Disk", value: formatBytes(size))
                    }
                }
                .padding(8)
            }
        }
    }

    private var librariesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let report = app.report, !report.libraries.isEmpty {
                Text("\(report.libraries.count) Native Shared Libraries (.so)")
                    .font(.headline)

                ForEach(report.libraries) { lib in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lib.name)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text("\(lib.abi) · \(formatBytes(lib.bytes))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(lib.status)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(lib.status == "supported" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .foregroundColor(lib.status == "supported" ? .green : .orange)
                            .cornerRadius(4)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            } else {
                Text("No native ARM64 libraries found in this APK.")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Label("Save Data Management", systemImage: "externaldrive")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Husk saves game state directly into the isolated Translation Layer app data sandbox.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            SaveBackupMac.promptExport(for: app)
                        } label: {
                            Label("Backup Saves…", systemImage: "arrow.up.doc")
                        }

                        Button {
                            SaveBackupMac.promptRestore(for: app) { _ in }
                        } label: {
                            Label("Restore Saves…", systemImage: "arrow.down.doc")
                        }

                        Button {
                            let folder = URL(fileURLWithPath: app.nativeDataDir)
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                        } label: {
                            Label("Reveal Data in Finder", systemImage: "folder")
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Sandbox Location", systemImage: "macwindow")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(app.nativeDataDir)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding(8)
            }
        }
    }

    private func labeledRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .font(.caption)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
