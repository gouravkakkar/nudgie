/// Turns raw meeting signals plus the user's rule toggles into one answer.
public enum QuietPolicy {
    /// Camera and mic are checked first because they are the strongest signal.
    public static func reason(for state: QuietState, settings: NudgieSettings) -> QuietReason? {
        if settings.quietOnCameraOrMic {
            if state.cameraBusy { return .cameraBusy }
            if state.micBusy { return .micBusy }
        }
        if settings.quietOnQuietApps, let id = state.frontmostBundleID,
           matches(bundleID: id, prefixes: settings.quietAppPrefixes) {
            return .quietApp(bundleID: id)
        }
        return nil
    }

    /// Prefix match so "com.google.Chrome.app.<id>" (a Chrome web app) counts as Chrome.
    public static func matches(bundleID: String, prefixes: [String]) -> Bool {
        let id = bundleID.lowercased()
        return prefixes.contains { id.hasPrefix($0.lowercased()) }
    }
}
