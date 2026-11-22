import AppKit

#if EDITOR_CHECKS
exit(runEditorChecks())
#else
let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
#endif
