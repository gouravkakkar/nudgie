import Foundation

/// A throwaway UserDefaults suite that deletes its plist when the test is done.
///
/// `removePersistentDomain(forName:)` alone is not enough: on this toolchain it clears the
/// in-memory/cfprefsd-cached values but does **not** unlink the backing plist file under
/// `~/Library/Preferences/`. Any test that writes to the suite (e.g. via `Store.save`) leaves a
/// stray `nudgie.tests.<UUID>.plist` behind even after calling it. So `cleanUp()` also removes
/// the file directly — safe here because `name` is a UUID we generated ourselves, so the path
/// can only ever refer to this suite's own file.
@MainActor final class TestDefaults {
    let name = "nudgie.tests.\(UUID().uuidString)"
    let defaults: UserDefaults
    init() { defaults = UserDefaults(suiteName: name)! }

    func cleanUp() {
        defaults.removePersistentDomain(forName: name)
        let path = ("~/Library/Preferences/\(name).plist" as NSString).expandingTildeInPath
        try? FileManager.default.removeItem(atPath: path)
    }
}
