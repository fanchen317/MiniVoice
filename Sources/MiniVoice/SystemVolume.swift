import CoreAudio
import Foundation

@MainActor
final class SystemVolume: ObservableObject {
    @Published private(set) var value: Float = 0
    @Published private(set) var canSetVolume = false
    @Published private(set) var deviceName = "系统输出设备"
    @Published private(set) var isMuted = false
    @Published private(set) var error: String?
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
