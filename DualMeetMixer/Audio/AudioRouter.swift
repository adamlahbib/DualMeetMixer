import AVFoundation
import CoreAudio
import Foundation

@available(macOS 14.2, *)
final class AudioRouter {

    private var tapA: ProcessTap?
    private var tapB: ProcessTap?
    private var aggregateA: AggregateDevice?
    private var aggregateB: AggregateDevice?

    private var captureEngineA: AVAudioEngine?
    private var captureEngineB: AVAudioEngine?
    private var outputEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    private var ringBufferA: AudioRingBuffer?
    private var ringBufferB: AudioRingBuffer?

    private var pidA: pid_t?
    private var pidB: pid_t?

    private var scratchA = [Float](repeating: 0, count: 8192)
    private var scratchB = [Float](repeating: 0, count: 8192)
    private var loggedA = false
    private var loggedB = false

    enum RouterError: Error {
        case missingHeadset
        case engineStartFailed(Error)
        case aggregateCreateFailed(Error)
    }

    private enum Side { case a, b }

    /// Re-create the routing graph for the given source PIDs.
    /// Pass nil for either side to keep that side disconnected.
    func update(pidA: pid_t?, pidB: pid_t?) throws {
        teardown()

        guard pidA != nil || pidB != nil else { return }

        guard let outputDeviceID = DeviceUtils.defaultOutputDevice() else {
            throw RouterError.missingHeadset
        }

        DMMLog.log("[AudioRouter] update pidA=\(String(describing: pidA)) pidB=\(String(describing: pidB))")

        let frameCapacity: AVAudioFrameCount = 4096
        ringBufferA = AudioRingBuffer(channelCount: 1, frameCapacity: frameCapacity * 4)
        ringBufferB = AudioRingBuffer(channelCount: 1, frameCapacity: frameCapacity * 4)

        if let pidA, let tap = makeTap(pid: pidA), let uuid = tap.uid() {
            self.tapA = tap
            do {
                let agg = AggregateDevice(name: "DMM-A")
                try agg.create(subDeviceUIDs: [], tapUUIDs: [uuid])
                self.aggregateA = agg
                self.captureEngineA = try buildCaptureEngine(aggregateID: agg.id, side: .a, frameCapacity: frameCapacity)
            } catch {
                DMMLog.log("[AudioRouter] failed to set up side A: \(error)")
            }
        }
        if let pidB, let tap = makeTap(pid: pidB), let uuid = tap.uid() {
            self.tapB = tap
            do {
                let agg = AggregateDevice(name: "DMM-B")
                try agg.create(subDeviceUIDs: [], tapUUIDs: [uuid])
                self.aggregateB = agg
                self.captureEngineB = try buildCaptureEngine(aggregateID: agg.id, side: .b, frameCapacity: frameCapacity)
            } catch {
                DMMLog.log("[AudioRouter] failed to set up side B: \(error)")
            }
        }

        try setupOutputEngine(outputDeviceID: outputDeviceID)
        self.pidA = pidA
        self.pidB = pidB
    }

    private func makeTap(pid: pid_t) -> ProcessTap? {
        let tap = ProcessTap(pid: pid)
        do {
            try tap.create()
            return tap
        } catch {
            DMMLog.log("[AudioRouter] Failed to create tap for pid \(pid): \(error)")
            return nil
        }
    }

    private func buildCaptureEngine(aggregateID: AudioObjectID,
                                     side: Side,
                                     frameCapacity: AVAudioFrameCount) throws -> AVAudioEngine {
        let engine = AVAudioEngine()
        do {
            try engine.inputNode.setVoiceProcessingEnabled(false)
        } catch {
            DMMLog.log("[AudioRouter] could not disable voice processing on side \(side): \(error)")
        }
        guard let inputUnit = engine.inputNode.audioUnit else {
            throw RouterError.engineStartFailed(NSError(domain: "AudioRouter", code: -1, userInfo: [NSLocalizedDescriptionKey: "inputNode has no audioUnit"]))
        }
        var device = aggregateID
        let setStatus = AudioUnitSetProperty(inputUnit,
                                              kAudioOutputUnitProperty_CurrentDevice,
                                              kAudioUnitScope_Global,
                                              0,
                                              &device,
                                              UInt32(MemoryLayout<AudioObjectID>.size))
        guard setStatus == noErr else {
            throw RouterError.engineStartFailed(NSError(domain: "AudioRouter", code: Int(setStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to bind aggregate to inputNode (\(setStatus))"]))
        }

        let captureFormat = engine.inputNode.outputFormat(forBus: 0)
        DMMLog.log("[AudioRouter] capture side=\(side) format=\(captureFormat) channels=\(captureFormat.channelCount)")

        let bufRef = (side == .a ? ringBufferA : ringBufferB)
        engine.inputNode.installTap(onBus: 0, bufferSize: frameCapacity, format: captureFormat) { [weak self] buffer, _ in
            self?.handleCapture(buffer: buffer, side: side, into: bufRef)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw RouterError.engineStartFailed(error)
        }
        return engine
    }

    private func handleCapture(buffer: AVAudioPCMBuffer,
                               side: Side,
                               into ring: AudioRingBuffer?) {
        guard let ring = ring, let chData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let totalChannels = Int(buffer.format.channelCount)
        guard totalChannels >= 1, frames > 0 else { return }

        switch side {
        case .a:
            if !loggedA {
                loggedA = true
                DMMLog.log("[capture] side=a first buffer: channels=\(totalChannels) frames=\(frames)")
            }
            if scratchA.count < frames { scratchA = [Float](repeating: 0, count: frames) }
            if totalChannels == 1 {
                for f in 0..<frames { scratchA[f] = chData[0][f] }
            } else {
                for f in 0..<frames { scratchA[f] = (chData[0][f] + chData[1][f]) * 0.5 }
            }
            ring.write(scratchA, frames: frames)
        case .b:
            if !loggedB {
                loggedB = true
                DMMLog.log("[capture] side=b first buffer: channels=\(totalChannels) frames=\(frames)")
            }
            if scratchB.count < frames { scratchB = [Float](repeating: 0, count: frames) }
            if totalChannels == 1 {
                for f in 0..<frames { scratchB[f] = chData[0][f] }
            } else {
                for f in 0..<frames { scratchB[f] = (chData[0][f] + chData[1][f]) * 0.5 }
            }
            ring.write(scratchB, frames: frames)
        }
    }

    private func setupOutputEngine(outputDeviceID: AudioObjectID) throws {
        let outputEngine = AVAudioEngine()
        guard let outputUnit = outputEngine.outputNode.audioUnit else {
            throw RouterError.engineStartFailed(NSError(domain: "AudioRouter", code: -1, userInfo: [NSLocalizedDescriptionKey: "outputNode has no audioUnit"]))
        }
        var outputDevice = outputDeviceID
        AudioUnitSetProperty(outputUnit,
                             kAudioOutputUnitProperty_CurrentDevice,
                             kAudioUnitScope_Global,
                             0,
                             &outputDevice,
                             UInt32(MemoryLayout<AudioObjectID>.size))

        let outFormat = outputEngine.outputNode.outputFormat(forBus: 0)
        let sampleRate = outFormat.sampleRate
        DMMLog.log("[AudioRouter] output device format: \(outFormat) sampleRate=\(sampleRate)")

        let source = AVAudioSourceNode(format: AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                              sampleRate: sampleRate,
                                                              channels: 2,
                                                              interleaved: false)!) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let lPtr = abl[0].mData!.assumingMemoryBound(to: Float.self)
            let rPtr = abl[1].mData!.assumingMemoryBound(to: Float.self)
            let frames = Int(frameCount)
            let aFrames = self?.ringBufferA?.read(into: lPtr, frames: frames) ?? 0
            for i in aFrames..<frames { lPtr[i] = 0 }
            let bFrames = self?.ringBufferB?.read(into: rPtr, frames: frames) ?? 0
            for i in bFrames..<frames { rPtr[i] = 0 }
            return noErr
        }
        outputEngine.attach(source)
        outputEngine.connect(source, to: outputEngine.mainMixerNode, format: nil)
        outputEngine.prepare()
        do {
            try outputEngine.start()
        } catch {
            throw RouterError.engineStartFailed(error)
        }

        self.outputEngine = outputEngine
        self.sourceNode = source
    }

    func teardown() {
        captureEngineA?.inputNode.removeTap(onBus: 0)
        captureEngineA?.stop()
        captureEngineB?.inputNode.removeTap(onBus: 0)
        captureEngineB?.stop()
        outputEngine?.stop()
        captureEngineA = nil
        captureEngineB = nil
        outputEngine = nil
        sourceNode = nil
        ringBufferA = nil
        ringBufferB = nil
        tapA?.destroy(); tapA = nil
        tapB?.destroy(); tapB = nil
        try? aggregateA?.destroy(); aggregateA = nil
        try? aggregateB?.destroy(); aggregateB = nil
        pidA = nil
        pidB = nil
        loggedA = false
        loggedB = false
    }
}
