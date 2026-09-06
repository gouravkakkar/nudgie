import AppKit

/// Plays one of the built-in macOS alert sounds.
enum Sound {
    static let available = ["Pop", "Tink", "Glass", "Ping", "Purr", "Blow", "Bottle", "Frog",
                            "Funk", "Hero", "Morse", "Submarine", "Basso", "Sosumi"]
    nonisolated(unsafe) private static var current: NSSound?

    nonisolated static func play(_ name: String) {
        let path = "/System/Library/Sounds/\(name).aiff"
        guard let sound = NSSound(contentsOfFile: path, byReference: true) else { return }
        current = sound   // keep it alive until it finishes
        sound.play()
    }
}
