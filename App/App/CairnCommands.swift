#if os(macOS)
import SwiftUI

/// macOS menu-bar commands and keyboard shortcuts, so the Mac build is a real
/// desktop citizen rather than a ported phone app.
struct CairnCommands: Commands {
    let env: AppEnvironment

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Task") {
                NotificationCenter.default.post(name: .cairnNewTask, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        CommandMenu("Water") {
            Button("Add 8 oz") { Task { await env.addWater(8) } }.keyboardShortcut("1", modifiers: [.command, .shift])
            Button("Add 16 oz") { Task { await env.addWater(16) } }.keyboardShortcut("2", modifiers: [.command, .shift])
            Button("Add 20 oz") { Task { await env.addWater(20) } }.keyboardShortcut("3", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .help) {
            Button("Cairn Privacy") {
                NotificationCenter.default.post(name: .cairnShowPrivacy, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let cairnNewTask = Notification.Name("cairnNewTask")
    static let cairnShowPrivacy = Notification.Name("cairnShowPrivacy")
}
#endif
