import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation

/// Mic routing using raw CoreAudio HAL units instead of AVAudioEngine.
/// AVAudioEngine on macOS doesn't reliably handle different physical devices
/// for input and output in the same engine — engines started without errors
/// but never pulled samples. The HAL approach below is more verbose but it's
/// how pro audio apps do this and it works.
///
/// Topology:
///   Jabra (input HALOutput, bus 1) ──[input render cb]──► ringA, ringB
///   ringA ──[output render cb A]──► BlackHole-A (HALOutput, bus 0)
///   ringB ──[output render cb B]──► BlackHole-B (HALOutput, bus 0)
///   gainA / gainB are applied during the per-side output callback.
final class MicMixer {

    enum MixerError: Error {
        case blackHoleAMissing
        case blackHoleBMissing
        case startFailed(OSStatus, String)
    }

    /// Per-output-side state held by reference so we can pass an UnsafeRawPointer
    /// to the render callback as refcon.
    final class OutputContext {
        weak var owner: MicMixer?
        let side: Side
        let ring: AudioRingBuffer
        var firstBufferLogged = false
        var renderCount = 0
        init(owner: MicMixer, side: Side, ring: AudioRingBuffer) {
            self.owner = owner
            self.side = side
            self.ring = ring
        }
    }

    private var inputUnit: AudioUnit?
    private var outputUnitA: AudioUnit?
    private var outputUnitB: AudioUnit?

    private var inputDeviceID: AudioObjectID = 0
    private var outputDeviceA: AudioObjectID = 0
    private var outputDeviceB: AudioObjectID = 0

    private var inputFormat = AudioStreamBasicDescription()

    private let ringA = AudioRingBuffer(channelCount: 1, frameCapacity: 16384)
    private let ringB = AudioRingBuffer(channelCount: 1, frameCapacity: 16384)

    private var contextA: OutputContext?
    private var contextB: OutputContext?

    private var gainA: Float = 0
    private var gainB: Float = 0

    private var inputBufferStorage: UnsafeMutablePointer<Float>?
    private let inputBufferCapacity = 4096

    private var diagFirstInputLogged = false
    private var diagInputBufferCount = 0
    private var diagInputPeak: Float = 0

    func start(inputDeviceUID: String? = nil) throws {
        DMMLog.log("[MicMixer] start called inputDeviceUID=\(inputDeviceUID ?? "nil")")

        let bh = BlackHoleDevices.detect()
        guard let aID = bh.a else { throw MixerError.blackHoleAMissing }
        guard let bID = bh.b else { throw MixerError.blackHoleBMissing }
        outputDeviceA = aID
        outputDeviceB = bID
        DMMLog.log("[MicMixer] BlackHole-A id=\(aID), name=\(DeviceUtils.name(of: aID) ?? "?")")
        DMMLog.log("[MicMixer] BlackHole-B id=\(bID), name=\(DeviceUtils.name(of: bID) ?? "?")")

        inputDeviceID = resolveInputDevice(uid: inputDeviceUID)
        DMMLog.log("[MicMixer] using input device id=\(inputDeviceID), name=\(DeviceUtils.name(of: inputDeviceID) ?? "?")")

        try buildInputUnit()

        contextA = OutputContext(owner: self, side: .a, ring: ringA)
        contextB = OutputContext(owner: self, side: .b, ring: ringB)
        try buildOutputUnit(side: .a, deviceID: aID, context: contextA!)
        try buildOutputUnit(side: .b, deviceID: bID, context: contextB!)

        inputBufferStorage = UnsafeMutablePointer<Float>.allocate(capacity: inputBufferCapacity)
        inputBufferStorage?.initialize(repeating: 0, count: inputBufferCapacity)

        try checkStart(AudioOutputUnitStart(inputUnit!), label: "input")
        try checkStart(AudioOutputUnitStart(outputUnitA!), label: "output-A")
        try checkStart(AudioOutputUnitStart(outputUnitB!), label: "output-B")
        DMMLog.log("[MicMixer] all units started")
    }

    func stop() {
        if let u = inputUnit { AudioOutputUnitStop(u); AudioUnitUninitialize(u); AudioComponentInstanceDispose(u) }
        if let u = outputUnitA { AudioOutputUnitStop(u); AudioUnitUninitialize(u); AudioComponentInstanceDispose(u) }
        if let u = outputUnitB { AudioOutputUnitStop(u); AudioUnitUninitialize(u); AudioComponentInstanceDispose(u) }
        inputUnit = nil
        outputUnitA = nil
        outputUnitB = nil
        contextA = nil
        contextB = nil
        inputBufferStorage?.deallocate()
        inputBufferStorage = nil
        diagFirstInputLogged = false
        diagInputBufferCount = 0
        diagInputPeak = 0
    }

    func setGain(_ side: Side, _ value: Float) {
        let prev: Float
        switch side {
        case .a: prev = gainA; gainA = value
        case .b: prev = gainB; gainB = value
        }
        DMMLog.log("[MicMixer] setGain side=\(side) value=\(value) (was \(prev))")
    }

    private func resolveInputDevice(uid: String?) -> AudioObjectID {
        if let uid, let id = DeviceUtils.find(byUID: uid) { return id }
        if let uid {
            DMMLog.log("[MicMixer] input UID \(uid) not found; falling back to system default")
        }
        return DeviceUtils.defaultInputDevice() ?? 0
    }

    // MARK: - Unit construction

    private func buildInputUnit() throws {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let comp = AudioComponentFindNext(nil, &desc) else {
            throw MixerError.startFailed(-1, "input HALOutput component not found")
        }
        var unit: AudioUnit?
        try check(AudioComponentInstanceNew(comp, &unit), label: "input AudioComponentInstanceNew")
        guard let unit else { throw MixerError.startFailed(-1, "nil input unit") }

        var enableInput: UInt32 = 1
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1,
                                        &enableInput, UInt32(MemoryLayout<UInt32>.size)),
                  label: "input enable IO input bus")
        var disableOutput: UInt32 = 0
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0,
                                        &disableOutput, UInt32(MemoryLayout<UInt32>.size)),
                  label: "input disable IO output bus")

        var device = inputDeviceID
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                        &device, UInt32(MemoryLayout<AudioObjectID>.size)),
                  label: "input set CurrentDevice")

        var hw = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1,
                                        &hw, &size),
                  label: "input get hw format")
        DMMLog.log("[MicMixer] input hw format: \(hw.mSampleRate)Hz \(hw.mChannelsPerFrame)ch")

        // Force a deinterleaved Float32 mono format on the output scope of bus 1.
        inputFormat = AudioStreamBasicDescription(
            mSampleRate: hw.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        try check(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,
                                        &inputFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)),
                  label: "input set client format")

        var cb = AURenderCallbackStruct(
            inputProc: MicMixer.inputRenderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0,
                                        &cb, UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                  label: "input set callback")

        try check(AudioUnitInitialize(unit), label: "input AudioUnitInitialize")
        inputUnit = unit
        DMMLog.log("[MicMixer] input unit built and initialized")
    }

    private func buildOutputUnit(side: Side, deviceID: AudioObjectID, context: OutputContext) throws {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let comp = AudioComponentFindNext(nil, &desc) else {
            throw MixerError.startFailed(-1, "output HALOutput component not found")
        }
        var unit: AudioUnit?
        try check(AudioComponentInstanceNew(comp, &unit), label: "output \(side) AudioComponentInstanceNew")
        guard let unit else { throw MixerError.startFailed(-1, "nil output unit") }

        var device = deviceID
        try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                        &device, UInt32(MemoryLayout<AudioObjectID>.size)),
                  label: "output \(side) set CurrentDevice")

        // BlackHole expects 2ch interleaved Float32 at its native rate. Read its
        // hw format from input scope of bus 0 (the data we send into it).
        var hw = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                        &hw, &size),
                  label: "output \(side) get hw format")
        DMMLog.log("[MicMixer/\(side)] output hw format: \(hw.mSampleRate)Hz \(hw.mChannelsPerFrame)ch flags=\(hw.mFormatFlags)")

        // Override to a stereo non-interleaved Float32 client format. We control
        // the data we deliver, so pick a format we can fill cleanly.
        var clientFormat = AudioStreamBasicDescription(
            mSampleRate: hw.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        try check(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                                        &clientFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)),
                  label: "output \(side) set client format")

        var cb = AURenderCallbackStruct(
            inputProc: MicMixer.outputRenderCallback,
            inputProcRefCon: Unmanaged.passUnretained(context).toOpaque()
        )
        try check(AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0,
                                        &cb, UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                  label: "output \(side) set render callback")

        try check(AudioUnitInitialize(unit), label: "output \(side) AudioUnitInitialize")
        switch side {
        case .a: outputUnitA = unit
        case .b: outputUnitB = unit
        }
        DMMLog.log("[MicMixer/\(side)] output unit built and initialized")
    }

    private func checkStart(_ status: OSStatus, label: String) throws {
        try check(status, label: "start \(label)")
    }

    private func check(_ status: OSStatus, label: String) throws {
        if status != noErr {
            DMMLog.log("[MicMixer] FAIL: \(label) status=\(status)")
            throw MixerError.startFailed(status, label)
        }
    }

    // MARK: - Render callbacks

    private static let inputRenderCallback: AURenderCallback = {
        (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, _) -> OSStatus in
        let mixer = Unmanaged<MicMixer>.fromOpaque(inRefCon).takeUnretainedValue()
        return mixer.handleInputRender(actionFlags: ioActionFlags,
                                        timestamp: inTimeStamp,
                                        busNumber: inBusNumber,
                                        frames: inNumberFrames)
    }

    private func handleInputRender(actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                                    timestamp: UnsafePointer<AudioTimeStamp>,
                                    busNumber: UInt32,
                                    frames: UInt32) -> OSStatus {
        guard let unit = inputUnit, let storage = inputBufferStorage else { return noErr }
        let frameCount = min(Int(frames), inputBufferCapacity)

        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(frameCount * MemoryLayout<Float>.size),
                mData: UnsafeMutableRawPointer(storage)
            )
        )
        let status = AudioUnitRender(unit, actionFlags, timestamp, busNumber, UInt32(frameCount), &bufferList)
        if status != noErr { return status }

        var peak: Float = 0
        for i in 0..<frameCount {
            let v = abs(storage[i])
            if v > peak { peak = v }
        }
        if !diagFirstInputLogged {
            diagFirstInputLogged = true
            DMMLog.log("[MicMixer] FIRST input buffer received: peak=\(peak) frames=\(frameCount)")
        }
        diagInputPeak = max(diagInputPeak, peak)
        diagInputBufferCount += 1
        if diagInputBufferCount % 50 == 0 {
            DMMLog.log("[MicMixer] input peak over last 50 buffers: \(diagInputPeak) (count=\(diagInputBufferCount))")
            diagInputPeak = 0
        }

        // Fan out to both ring buffers. Each output side reads independently.
        ringA.write(UnsafePointer(storage), frames: frameCount)
        ringB.write(UnsafePointer(storage), frames: frameCount)
        return noErr
    }

    private static let outputRenderCallback: AURenderCallback = {
        (inRefCon, _, _, _, inNumberFrames, ioData) -> OSStatus in
        let context = Unmanaged<OutputContext>.fromOpaque(inRefCon).takeUnretainedValue()
        guard let owner = context.owner, let ioData else { return noErr }
        return owner.handleOutputRender(context: context, frames: inNumberFrames, ioData: ioData)
    }

    private func handleOutputRender(context: OutputContext,
                                     frames: UInt32,
                                     ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(ioData)
        let frameCount = Int(frames)
        guard abl.count >= 2 else { return noErr }

        let lPtr = abl[0].mData?.assumingMemoryBound(to: Float.self)
        let rPtr = abl[1].mData?.assumingMemoryBound(to: Float.self)
        guard let lPtr, let rPtr else { return noErr }

        // Read mono samples from this side's ring buffer. read() advances the
        // ring's read position, so each side consumes its own copy at its own
        // rate.
        let read = context.ring.read(into: lPtr, frames: frameCount)
        let gain = (context.side == .a ? gainA : gainB)
        // Copy left → right and apply gain.
        for i in 0..<read {
            lPtr[i] *= gain
            rPtr[i] = lPtr[i]
        }
        for i in read..<frameCount {
            lPtr[i] = 0
            rPtr[i] = 0
        }
        if !context.firstBufferLogged {
            context.firstBufferLogged = true
            DMMLog.log("[MicMixer/\(context.side)] FIRST output render: requested=\(frameCount) got=\(read) gain=\(gain)")
        }
        context.renderCount += 1
        if context.renderCount % 200 == 0 {
            DMMLog.log("[MicMixer/\(context.side)] output render count=\(context.renderCount) gain=\(gain)")
        }
        return noErr
    }
}
