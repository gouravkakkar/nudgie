/// Meeting signals from the OS, as plain values.
public struct QuietState: Equatable, Sendable {
    public var cameraBusy: Bool
    public var micBusy: Bool
    public var frontmostBundleID: String?

    public init(cameraBusy: Bool = false, micBusy: Bool = false, frontmostBundleID: String? = nil) {
        self.cameraBusy = cameraBusy
        self.micBusy = micBusy
        self.frontmostBundleID = frontmostBundleID
    }
}

/// Why Nudgie is holding its tongue right now.
public enum QuietReason: Equatable, Sendable {
    case cameraBusy
    case micBusy
    case quietApp(bundleID: String)

    public var label: String {
        switch self {
        case .cameraBusy: "Camera is on"
        case .micBusy: "Mic is on"
        case .quietApp: "Meeting app in front"
        }
    }
}
