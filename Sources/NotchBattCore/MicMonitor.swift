import CoreAudio
import Foundation

/// Event-driven watcher for the built-in microphone. Invokes `onChange` with
/// true while any app is recording from a built-in input device, and false when
/// none is. Reads CoreAudio device state only, so it needs no microphone
/// permission. No polling.
public final class MicMonitor {
    public var onChange: ((Bool) -> Void)?
    private var isInUse = false
    private var watched: [AudioObjectID] = []

    private static let system = AudioObjectID(kAudioObjectSystemObject)
    private static var devicesAddress = address(kAudioHardwarePropertyDevices)
    private static var runningAddress = address(kAudioDevicePropertyDeviceIsRunningSomewhere)

    // CoreAudio removes a listener block by identity, so each one is created once.
    private lazy var devicesListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.watchBuiltInInputs()
        self?.refresh()
    }
    private lazy var runningListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.refresh()
    }

    public init() {}

    deinit { stop() }

    /// Starts listening on the main queue and fires an initial reading.
    public func start() {
        let status = AudioObjectAddPropertyListenerBlock(Self.system, &Self.devicesAddress,
                                                         .main, devicesListener)
        if status != noErr {
            NSLog("NotchBatt: failed to watch audio devices (OSStatus \(status))")
        }
        watchBuiltInInputs()
        refresh()
    }

    public func stop() {
        AudioObjectRemovePropertyListenerBlock(Self.system, &Self.devicesAddress,
                                               .main, devicesListener)
        unwatchAll()
    }

    /// Re-reads the in-use state and fires `onChange` if it changed.
    private func refresh() {
        let inUse = watched.contains { Self.isRunningSomewhere($0) }
        guard inUse != isInUse else { return }
        isInUse = inUse
        onChange?(inUse)
    }

    /// Replaces the per-device listeners with ones on the current built-in
    /// inputs. Called at start and whenever devices are added or removed.
    private func watchBuiltInInputs() {
        unwatchAll()
        for id in Self.deviceIDs() where Self.isBuiltInInput(id) {
            let status = AudioObjectAddPropertyListenerBlock(id, &Self.runningAddress,
                                                             .main, runningListener)
            if status == noErr {
                watched.append(id)
            } else {
                NSLog("NotchBatt: failed to watch input device \(id) (OSStatus \(status))")
            }
        }
    }

    private func unwatchAll() {
        for id in watched {
            AudioObjectRemovePropertyListenerBlock(id, &Self.runningAddress, .main, runningListener)
        }
        watched = []
    }

    // MARK: - CoreAudio reads

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private static func deviceIDs() -> [AudioObjectID] {
        var addr = devicesAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func uint32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    /// A built-in device with at least one input stream. On notched Macs the
    /// microphone and speakers are separate devices, so "running" here means
    /// something is recording.
    private static func isBuiltInInput(_ id: AudioObjectID) -> Bool {
        guard uint32(id, kAudioDevicePropertyTransportType) == kAudioDeviceTransportTypeBuiltIn
        else { return false }
        var addr = address(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    private static func isRunningSomewhere(_ id: AudioObjectID) -> Bool {
        (uint32(id, kAudioDevicePropertyDeviceIsRunningSomewhere) ?? 0) != 0
    }
}
