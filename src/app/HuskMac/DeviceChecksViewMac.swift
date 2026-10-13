// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit

struct DeviceChecksViewMac: View {
    @ObservedObject var store = TranslationLayerStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Translation Layer Diagnostics")
                        .font(.title2.weight(.bold))
                    #if arch(x86_64)
                    Text("Verify system readiness for JIT execution and Android code translation on macOS (x86_64).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    #else
                    Text("Verify system readiness for native ARM64 Android code translation on macOS.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    #endif
                }

                Spacer()

                Button(action: {
                    store.runChecks()
                }) {
                    if store.checking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Run Diagnostics", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.checking)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if store.checks.isEmpty && !store.checking {
                VStack(spacing: 16) {
                    Image(systemName: "cpu")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Diagnostics Ready")
                        .font(.headline)
                    Text("Click 'Run Diagnostics' to test JIT memory execution, Bionic shims, ANGLE graphics, and AudioToolbox output.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)

                    Button("Run Now") {
                        store.runChecks()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.checks) { check in
                        CheckRow(check: check)
                    }
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            if store.checks.isEmpty {
                store.runChecks()
            }
        }
    }
}

struct CheckRow: View {
    let check: TLCheck

    private var isPass: Bool {
        check.status.lowercased() == "pass" || check.status.lowercased() == "ok"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isPass ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(isPass ? .green : .red)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(check.title)
                        .font(.headline)
                    Spacer()
                    Text(check.status.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundColor(isPass ? .green : .red)
                }

                Text(check.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
