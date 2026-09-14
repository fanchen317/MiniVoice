import CoreAudio
import Foundation

@MainActor
final class SystemVolume: ObservableObject {
    struct Device: Identifiable, Equatable {
        let id: AudioDeviceID
        let name: String
    }

    @Published private(set) var value: Float = 0
    @Published private(set) var canSetVolume = false
    @Published private(set) var deviceName = "系统输出设备"
    @Published private(set) var isMuted = false
    @Published private(set) var error: String?
    @Published private(set) var inputDevices: [Device] = []
    @Published private(set) var outputDevices: [Device] = []
    @Published private(set) var inputDeviceID = AudioDeviceID(0)
    @Published private(set) var outputDeviceID = AudioDeviceID(0)
    private var device = AudioDeviceID(0)
    private var elements: [AudioObjectPropertyElement] = []
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    private func address(_ selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement = 0) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
    }
    func refresh() {
        refreshDevices()
        var defaultAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var current = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &size, &current) == noErr else { canSetVolume = false; return }
        device = current
        var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var name: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        if AudioObjectGetPropertyData(device, &nameAddress, 0, nil, &size, &name) == noErr { deviceName = name?.takeRetainedValue() as String? ?? "系统输出设备" }
        elements = []
        var values: [Float] = []
        for element: AudioObjectPropertyElement in [0, 1, 2] {
            var property = address(kAudioDevicePropertyVolumeScalar, element: element)
            var settable = DarwinBoolean(false), volume: Float32 = 0
            size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectHasProperty(device, &property),
               AudioObjectIsPropertySettable(device, &property, &settable) == noErr, settable.boolValue,
               AudioObjectGetPropertyData(device, &property, 0, nil, &size, &volume) == noErr {
                elements.append(element); values.append(volume)
                if element == 0 { break }
            }
        }
        canSetVolume = !elements.isEmpty
        if !values.isEmpty { value = min(1, max(0, values.reduce(0, +) / Float(values.count))) }
        var muteAddress = address(kAudioDevicePropertyMute)
        var muted: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        isMuted = AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &muted) == noErr && muted != 0
    }

    func selectInputDevice(_ id: AudioDeviceID) {
        setDefaultDevice(id, selector: kAudioHardwarePropertyDefaultInputDevice, failure: "无法切换 Mac 输入设备")
    }

    func selectOutputDevice(_ id: AudioDeviceID) {
        setDefaultDevice(id, selector: kAudioHardwarePropertyDefaultOutputDevice, failure: "无法切换 Mac 输出设备")
    }

    private func refreshDevices() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return }
        var ids = Array(repeating: AudioDeviceID(0), count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return }
        inputDevices = devices(ids, scope: kAudioDevicePropertyScopeInput)
        outputDevices = devices(ids, scope: kAudioDevicePropertyScopeOutput)
        inputDeviceID = defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        outputDeviceID = defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
    }

    private func devices(_ ids: [AudioDeviceID], scope: AudioObjectPropertyScope) -> [Device] {
        ids.compactMap { id in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: 0)
            guard AudioObjectHasProperty(id, &streams) else { return nil }
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &size) == noErr, size > 0 else { return nil }
            return Device(id: id, name: deviceName(for: id))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var id = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    private func deviceName(for id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr else { return "未知设备" }
        return name?.takeRetainedValue() as String? ?? "未知设备"
    }

    private func setDefaultDevice(_ id: AudioDeviceID, selector: AudioObjectPropertySelector, failure: String) {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var selected = id
        error = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &selected) == noErr ? nil : failure
        refresh()
    }
    func set(_ requested: Float) {
        refresh()
        guard canSetVolume else { return }
        var volume = min(1, max(0, requested))
        error = nil
        for element in elements {
            var property = address(kAudioDevicePropertyVolumeScalar, element: element)
            if AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume) != noErr { error = "无法调整当前设备音量" }
        }
        if volume > 0 && isMuted {
            var property = address(kAudioDevicePropertyMute), muted: UInt32 = 0
            _ = AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muted)
        }
        refresh()
    }
}
