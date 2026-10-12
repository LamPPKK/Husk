// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import Foundation

enum SaveBackupMac {
    @MainActor
    static func promptExport(for app: TLApp) {
        do {
            let tempZip = try SaveBackup.export(app)
            let panel = NSSavePanel()
            panel.title = "Backup Saves"
            panel.prompt = "Save"
            panel.nameFieldStringValue = tempZip.lastPathComponent
            panel.allowedContentTypes = [.zip]

            panel.begin { response in
                guard response == .OK, let targetURL = panel.url else { return }
                try? FileManager.default.removeItem(at: targetURL)
                try? FileManager.default.copyItem(at: tempZip, to: targetURL)
                HuskLog.log("saves", "Exported save backup to \(targetURL.path)")
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Save Backup Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @MainActor
    static func promptRestore(for app: TLApp, completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Restore Saves"
        panel.prompt = "Restore"
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let zipURL = panel.url else {
                completion(false)
                return
            }
            do {
                let count = try SaveBackup.restore(app, from: zipURL)
                let alert = NSAlert()
                alert.messageText = "Saves Restored"
                alert.informativeText = "Successfully restored \(count) save file(s) for \(app.label)."
                alert.alertStyle = .informational
                alert.runModal()
                completion(true)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Restore Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
                completion(false)
            }
        }
    }
}
