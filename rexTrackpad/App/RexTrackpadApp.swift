import SwiftUI

/// Menu-bar-only app (`LSUIElement = YES`, no Dock icon).
/// The UI lives in `MenuBarController`; windows are presented on demand.
@main
struct RexTrackpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A SwiftUI App needs at least one scene. Settings are opened from the
        // status menu through `WindowPresenter`, so this stays empty.
        Settings {
            EmptyView()
        }
    }
}
