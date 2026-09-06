import Testing
@testable import NudgieCore

@Suite struct QuietPolicyTests {
    let settings = NudgieSettings.defaults

    @Test func nothingBusyMeansNotQuiet() {
        #expect(QuietPolicy.reason(for: QuietState(), settings: settings) == nil)
    }

    @Test func cameraBusyIsQuiet() {
        let s = QuietState(cameraBusy: true, frontmostBundleID: "com.apple.Terminal")
        #expect(QuietPolicy.reason(for: s, settings: settings) == .cameraBusy)
    }

    @Test func micBusyIsQuiet() {
        let s = QuietState(micBusy: true)
        #expect(QuietPolicy.reason(for: s, settings: settings) == .micBusy)
    }

    @Test func cameraRuleCanBeDisabled() {
        var off = settings
        off.quietOnCameraOrMic = false
        let s = QuietState(cameraBusy: true, micBusy: true)
        #expect(QuietPolicy.reason(for: s, settings: off) == nil)
    }

    @Test func browserInFrontIsQuiet() {
        let s = QuietState(frontmostBundleID: "com.google.Chrome")
        #expect(QuietPolicy.reason(for: s, settings: settings) == .quietApp(bundleID: "com.google.Chrome"))
    }

    @Test func chromeWebAppMatchesByPrefix() {
        let id = "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan"
        let s = QuietState(frontmostBundleID: id)
        #expect(QuietPolicy.reason(for: s, settings: settings) == .quietApp(bundleID: id))
    }

    @Test func prefixMatchIsCaseInsensitive() {
        #expect(QuietPolicy.matches(bundleID: "US.ZOOM.XOS", prefixes: ["us.zoom.xos"]))
        #expect(!QuietPolicy.matches(bundleID: "com.apple.Terminal", prefixes: ["com.apple.Safari"]))
    }

    @Test func nonQuietAppInFrontIsNotQuiet() {
        let s = QuietState(frontmostBundleID: "com.apple.Terminal")
        #expect(QuietPolicy.reason(for: s, settings: settings) == nil)
    }

    @Test func appRuleCanBeDisabled() {
        var off = settings
        off.quietOnQuietApps = false
        let s = QuietState(frontmostBundleID: "us.zoom.xos")
        #expect(QuietPolicy.reason(for: s, settings: off) == nil)
    }

    @Test func cameraWinsOverAppWhenBoth() {
        let s = QuietState(cameraBusy: true, frontmostBundleID: "us.zoom.xos")
        #expect(QuietPolicy.reason(for: s, settings: settings) == .cameraBusy)
    }

    @Test func activityAwayRules() {
        #expect(!ActivityState(idleSeconds: 299).isAway)
        #expect(ActivityState(idleSeconds: 300).isAway)
        #expect(ActivityState(idleSeconds: 1, isLocked: true).isAway)
        #expect(ActivityState(idleSeconds: 1, isAsleep: true).isAway)
    }

    @Test func labelsAreHumanReadable() {
        #expect(QuietReason.cameraBusy.label == "Camera is on")
        #expect(QuietReason.micBusy.label == "Mic is on")
        #expect(QuietReason.quietApp(bundleID: "x").label == "Meeting app in front")
    }
}
