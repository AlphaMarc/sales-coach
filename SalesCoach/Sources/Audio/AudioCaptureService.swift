import Foundation
import AVFoundation
import CoreAudio

/// Service for capturing audio from the microphone
actor AudioCaptureService {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let targetFormat: AVAudioFormat
    private var isRunning = false
    
    /// Callback for audio buffer data
    private var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    /// Set the audio buffer callback
    func setAudioBufferHandler(_ handler: @escaping (AVAudioPCMBuffer) -> Void) {
        onAudioBuffer = handler
    }
    
    /// Available audio input devices
    static var availableInputDevices: [AudioDevice] {
        var devices: [AudioDevice] = []
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { return devices }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else { return devices }
        
        for deviceID in deviceIDs {
            // Check if device has input channels
            var inputChannels: UInt32 = 0
            var channelPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var channelDataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &channelPropertyAddress, 0, nil, &channelDataSize)
            
            if status == noErr && channelDataSize > 0 {
                let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
                defer { bufferList.deallocate() }
                
                status = AudioObjectGetPropertyData(deviceID, &channelPropertyAddress, 0, nil, &channelDataSize, bufferList)
                
                if status == noErr {
                    let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
                    for buffer in buffers {
                        inputChannels += buffer.mNumberChannels
                    }
                }
            }
            
            guard inputChannels > 0 else { continue }
            
            // Get device name
            var namePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            var deviceName: CFString = "" as CFString
            
            status = AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &nameSize, &deviceName)
            
            let name = status == noErr ? deviceName as String : "Unknown Device"
            
            devices.append(AudioDevice(id: String(deviceID), name: name, deviceID: deviceID))
        }
        
        return devices
    }
    
    /// Default input device
    static var defaultInputDevice: AudioDevice? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        
        guard status == noErr else { return nil }
        
        return availableInputDevices.first { $0.deviceID == deviceID }
    }
    
    init() {
        // whisper.cpp expects: 16kHz, mono, 16-bit PCM
        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!
    }
    
    /// Start audio capture
    func start() async throws {
        guard !isRunning else { return }
        
        // Request microphone permission
        let granted = await requestMicrophonePermission()
        guard granted else {
            throw AudioCaptureError.permissionDenied
        }
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw AudioCaptureError.engineCreationFailed
        }
        
        inputNode = engine.inputNode
        guard let input = inputNode else {
            throw AudioCaptureError.noInputNode
        }
        
        let inputFormat = input.outputFormat(forBus: 0)
        
        // Install tap on input node
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            Task { [weak self] in
                await self?.processAudioBuffer(buffer, format: inputFormat)
            }
        }
        
        try engine.start()
        isRunning = true
    }
    
    /// Stop audio capture
    func stop() {
        guard isRunning else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isRunning = false
    }
    
    /// Pause audio capture
    func pause() {
        audioEngine?.pause()
    }
    
    /// Resume audio capture
    func resume() throws {
        try audioEngine?.start()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        // Convert to target format if needed
        guard let convertedBuffer = convertBuffer(buffer, from: format, to: targetFormat) else {
            return
        }
        
        onAudioBuffer?(convertedBuffer)
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, from sourceFormat: AVAudioFormat, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return nil
        }
        
        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return nil
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Audio conversion error: \(error)")
            return nil
        }
        
        return outputBuffer
    }
    
    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

/// Represents an audio input device
struct AudioDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let deviceID: AudioDeviceID
}

/// Audio capture errors
enum AudioCaptureError: LocalizedError {
    case permissionDenied
    case engineCreationFailed
    case noInputNode
    case startFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied. Please enable in System Settings > Privacy & Security > Microphone."
        case .engineCreationFailed:
            return "Failed to create audio engine"
        case .noInputNode:
            return "No audio input available"
        case .startFailed(let reason):
            return "Failed to start audio capture: \(reason)"
        }
    }
}
