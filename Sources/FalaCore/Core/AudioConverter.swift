@preconcurrency import AVFoundation

private final class AudioConversionState: @unchecked Sendable {
    var cancellationError: Error?
}

/// Converts any AVAudioFile to a [Float] array at 16 kHz mono,
/// which is the format expected by WhisperKit.
public enum AudioConverter {
    public static func toFloat16k(
        from url: URL,
        cancellationCheck: @escaping @Sendable () throws -> Void = {}
    ) throws -> [Float] {
        let sourceFile = try AVAudioFile(forReading: url)
        let targetFormat = try make16kMonoFloatFormat()

        guard let converter = AVAudioConverter(
            from: sourceFile.processingFormat,
            to: targetFormat
        ) else {
            throw AudioError.conversionFailed
        }

        let ratio = targetFormat.sampleRate / sourceFile.processingFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(sourceFile.length) * ratio) + 1
        let outputBuffer = try makePCMBuffer(
            format: targetFormat,
            frameCapacity: outputCapacity
        )
        let inputBuffer = try makePCMBuffer(
            format: sourceFile.processingFormat,
            frameCapacity: 8_192
        )

        try convertFile(
            sourceFile,
            with: converter,
            inputBuffer: inputBuffer,
            outputBuffer: outputBuffer,
            cancellationCheck: cancellationCheck
        )
        try cancellationCheck()

        return samples(from: outputBuffer)
    }

    private static func convertFile(
        _ sourceFile: AVAudioFile,
        with converter: AVAudioConverter,
        inputBuffer: AVAudioPCMBuffer,
        outputBuffer: AVAudioPCMBuffer,
        cancellationCheck: @escaping @Sendable () throws -> Void
    ) throws {
        var conversionError: NSError?
        let state = AudioConversionState()

        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            do {
                try cancellationCheck()
                try sourceFile.read(into: inputBuffer)
                outStatus.pointee = inputBuffer.frameLength > 0 ? .haveData : .endOfStream
                return inputBuffer
            } catch is CancellationError {
                state.cancellationError = CancellationError()
                outStatus.pointee = .endOfStream
                return nil
            } catch {
                outStatus.pointee = .endOfStream
                return nil
            }
        }

        if let cancellationError = state.cancellationError {
            throw cancellationError
        }
        if status == .error {
            throw conversionError ?? AudioError.conversionFailed
        }
    }

    public static func write16kMonoWAV(
        from inputURL: URL,
        to outputURL: URL,
        cancellationCheck: @escaping @Sendable () throws -> Void = {}
    ) throws {
        try cancellationCheck()
        let samples = try toFloat16k(
            from: inputURL,
            cancellationCheck: cancellationCheck
        )
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
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: frameCount
        ),
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

    private static func make16kMonoFloatFormat() throws -> AVAudioFormat {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioError.invalidFormat
        }
        return format
    }

    private static func makePCMBuffer(
        format: AVAudioFormat,
        frameCapacity: AVAudioFrameCount
    ) throws -> AVAudioPCMBuffer {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCapacity
        ) else {
            throw AudioError.bufferAllocationFailed
        }
        return buffer
    }

    private static func samples(from outputBuffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = outputBuffer.floatChannelData?[0] else {
            return []
        }

        return Array(
            UnsafeBufferPointer(
                start: channelData,
                count: Int(outputBuffer.frameLength)
            )
        )
    }
}
