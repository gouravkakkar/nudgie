import AppKit
import CoreAudio
import CoreMediaIO
import NudgieCore
import os

/// Camera and mic "is running somewhere" flags plus the frontmost app.
/// We never open a device, so no permission prompt appears.
final class QuietProbe: QuietSampling {
    static let deviceCheckInterval: TimeInterval = 2
    private static let log = Logger(subsystem: "com.gouravkakkar.nudgie", category: "probe")
    private static var loggedCameraFailure = false
    private static var loggedMicFailure = false

    private var cachedCameraBusy = false
    private var cachedMicBusy = false
    /// Uptime, not wall clock, so a clock change cannot freeze the cadence.
    private var lastDeviceCheckUptime: TimeInterval = -.infinity

    init() {}

    func sample(now: Date = Date()) -> QuietState {
        let uptime = ProcessInfo.processInfo.systemUptime
        if uptime - lastDeviceCheckUptime >= Self.deviceCheckInterval {
            cachedCameraBusy = Self.isAnyCameraRunning()
            cachedMicBusy = Self.isAnyMicRunning()
            lastDeviceCheckUptime = uptime
        }
        return QuietState(cameraBusy: cachedCameraBusy,
                          micBusy: cachedMicBusy,
                          frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    static func appName(forBundleID id: String) -> String? {
        NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName
    }

    // MARK: Camera (CoreMediaIO)

    static func isAnyCameraRunning() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == 0 else {
            logOnce(&loggedCameraFailure, "camera device list size query failed")
            return false
        }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &ids) == 0 else {
            logOnce(&loggedCameraFailure, "camera device list query failed")
            return false
        }
        for id in ids {
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            var running: UInt32 = 0
            let wanted = UInt32(MemoryLayout<UInt32>.size)
            var got: UInt32 = 0
            if CMIOObjectGetPropertyData(id, &runningAddress, 0, nil, wanted, &got, &running) == 0, running != 0 {
                return true
            }
        }
        return false
    }

    // MARK: Microphone (CoreAudio)

    /// Prefer the per-process "is running input" flag (macOS 14.2+). Fall back to the
    /// device-wide flag on older systems, accepting its duplex-device false positives there.
    static func isAnyMicRunning() -> Bool {
        if #available(macOS 14.2, *) {
            return isAnyProcessCapturingInput()
        }
        return isAnyInputDeviceRunning()
    }

    @available(macOS 14.2, *)
    static func isAnyProcessCapturingInput() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == 0 else {
            logOnce(&loggedMicFailure, "audio process list size query failed")
            return false
        }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == 0 else {
            logOnce(&loggedMicFailure, "audio process list query failed")
            return false
        }
        for id in ids {
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunningInput,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(id, &runningAddress, 0, nil, &runningSize, &running) == 0, running != 0 {
                return true
            }
        }
        return false
    }

    static func isAnyInputDeviceRunning() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == 0 else {
            logOnce(&loggedMicFailure, "audio device list size query failed")
            return false
        }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == 0 else {
            logOnce(&loggedMicFailure, "audio device list query failed")
            return false
        }
        for id in ids {
            // Only devices with input streams can be microphones.
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &inputAddress, 0, nil, &inputSize) == 0, inputSize > 0 else { continue }
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(id, &runningAddress, 0, nil, &runningSize, &running) == 0, running != 0 {
                return true
            }
        }
        return false
    }

    private static func logOnce(_ flag: inout Bool, _ message: String) {
        guard !flag else { return }
        flag = true
        log.error("\(message, privacy: .public)")
    }
}
