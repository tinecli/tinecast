import AudioToolbox
import CoreAudio

private let volumeStep: Float32 = 1 / 16

func changeOutputVolume(by steps: Float32) -> Bool {
    guard let device: AudioObjectID = audioProperty(kAudioHardwarePropertyDefaultOutputDevice, of: AudioObjectID(kAudioObjectSystemObject), scope: kAudioObjectPropertyScopeGlobal),
          let volume: Float32 = audioProperty(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, of: device)
    else { return false }
    _ = setAudioProperty(kAudioDevicePropertyMute, of: device, to: UInt32(0))
    return setAudioProperty(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, of: device, to: min(max(volume + steps * volumeStep, 0), 1))
}

func toggleOutputMute() -> Bool {
    guard let device: AudioObjectID = audioProperty(kAudioHardwarePropertyDefaultOutputDevice, of: AudioObjectID(kAudioObjectSystemObject), scope: kAudioObjectPropertyScopeGlobal),
          let muted: UInt32 = audioProperty(kAudioDevicePropertyMute, of: device)
    else { return false }
    return setAudioProperty(kAudioDevicePropertyMute, of: device, to: UInt32(muted == 0 ? 1 : 0))
}

private func audioProperty<Value: Numeric & BitwiseCopyable>(_ selector: AudioObjectPropertySelector, of object: AudioObjectID, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeOutput) -> Value? {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    var size = UInt32(MemoryLayout<Value>.size)
    var value = Value.zero
    guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
    return value
}

private func setAudioProperty<Value: Numeric & BitwiseCopyable>(_ selector: AudioObjectPropertySelector, of object: AudioObjectID, to newValue: Value) -> Bool {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    var value = newValue
    return AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<Value>.size), &value) == noErr
}
