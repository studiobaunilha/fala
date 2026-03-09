@preconcurrency import AVFoundation

/// Converts any AVAudioFile to a [Float] array at 16 kHz mono,
/// which is the format expected by WhisperKit.
public enum AudioConverter {
    public static func toFloat16k(from url: URL) throws -> [Float] {
        let sourceFile = try AVAudioFile(forReading: url)
        let sourceFormat = sourceFile.processingFormat

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else { throw AudioError.invalidFormat }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw AudioError.conversionFailed
        }

        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(sourceFile.length) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            throw AudioError.bufferAllocationFailed
        }

        let chunkSize: AVAudioFrameCount = 8192
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: chunkSize) else {
            throw AudioError.bufferAllocationFailed
        }

        var conversionError: NSError?

        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            do {
                try sourceFile.read(into: inputBuffer)
                outStatus.pointee = inputBuffer.frameLength > 0 ? .haveData : .endOfStream
                return inputBuffer
            } catch {
                outStatus.pointee = .endOfStream
                return nil
            }
        }

        if status == .error {
            throw conversionError ?? AudioError.conversionFailed
        }

        guard let channelData = outputBuffer.floatChannelData?[0] else {
            return []
        }

        return Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
    }

    public static func write16kMonoWAV(
        from inputURL: URL,
        to outputURL: URL,
        cancellationCheck: @escaping @Sendable () throws -> Void = {}
    ) throws {
        try cancellationCheck()
        let samples = try toFloat16k(from: inputURL)
        try cancellationCheck()

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioError.invalidFormat
        }

        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData?[0]
        else {
            throw AudioError.bufferAllocationFailed
        }

        buffer.frameLength = frameCount
        if !samples.isEmpty {
            samples.withUnsafeBufferPointer { pointer in
                if let sourceBaseAddress = pointer.baseAddress {
                    channelData.update(from: sourceBaseAddress, count: samples.count)
                }
            }
        }

        let file = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings)
        try file.write(from: buffer)
    }
}
