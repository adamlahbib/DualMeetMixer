import AVFoundation
import Foundation
import os

/// Simple lock-protected float ring buffer. Adequate for moderate audio rates.
final class AudioRingBuffer {
    private var buffer: [Float]
    private let capacity: Int
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var available: Int = 0
    private let lock = OSAllocatedUnfairLock()

    init(channelCount: Int, frameCapacity: AVAudioFrameCount) {
        self.capacity = Int(frameCapacity)
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    func write(_ samples: [Float], frames: Int) {
        samples.withUnsafeBufferPointer { buf in
            write(buf.baseAddress!, frames: frames)
        }
    }

    func write(_ samples: UnsafePointer<Float>, frames: Int) {
        lock.withLock {
            for i in 0..<frames {
                buffer[writeIndex] = samples[i]
                writeIndex = (writeIndex + 1) % capacity
                if available < capacity {
                    available += 1
                } else {
                    // overrun: advance read to drop oldest
                    readIndex = (readIndex + 1) % capacity
                }
            }
        }
    }

    @discardableResult
    func read(into dest: UnsafeMutablePointer<Float>, frames: Int) -> Int {
        return lock.withLock {
            let n = min(frames, available)
            for i in 0..<n {
                dest[i] = buffer[readIndex]
                readIndex = (readIndex + 1) % capacity
            }
            available -= n
            return n
        }
    }
}
