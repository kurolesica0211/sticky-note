import AppKit

final class Launcher: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let sibling = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Sticky Note.app")
        let target = FileManager.default.fileExists(atPath: sibling.path) ? sibling :
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: "io.github.kurolesica0211.StickyNote")
        guard let target else {
            let alert = NSAlert()
            alert.messageText = "Install Sticky Note first"
            alert.informativeText = "Keep Sticky Note and Delete Sticky Note together in your Applications folder."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([URL(string: "stickynote://delete")!], withApplicationAt: target, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error { NSAlert(error: error).runModal() }
                NSApp.terminate(nil)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = Launcher()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
