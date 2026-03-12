import AVFoundation
import XCTest

private enum AudioFixtureError: Error {
    case exportSessionUnavailable
    case exportIncomplete(AVAssetExportSession.Status)
}

func makeSilentAudioFile(
    sampleRate: Double,
    durationSeconds: Double,
    channels: AVAudioChannelCount = 1,
    fileExtension: String
) throws -> URL {
    if fileExtension == "m4a" {
        let sourceURL = try makeSilentPCMFile(
            sampleRate: sampleRate,
            durationSeconds: durationSeconds,
            channels: channels,
            fileExtension: "wav",
            interleaved: true
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try exportAudioAssetToM4A(sourceURL: sourceURL, outputURL: outputURL)
        return outputURL
    }

    return try makeSilentPCMFile(
        sampleRate: sampleRate,
        durationSeconds: durationSeconds,
        channels: channels,
        fileExtension: fileExtension
    )
}

func makeSilentWAV(sampleRate: Double, durationSeconds: Double) throws -> URL {
    try makeSilentAudioFile(
        sampleRate: sampleRate,
        durationSeconds: durationSeconds,
        fileExtension: "wav"
    )
}

func makeExportedAACM4A(
    sampleRate: Double,
    durationSeconds: Double,
    channels: AVAudioChannelCount = 2,
    testCase: XCTestCase
) throws -> URL {
    _ = testCase
    let sourceURL = try makeSilentPCMFile(
        sampleRate: sampleRate,
        durationSeconds: durationSeconds,
        channels: channels,
        fileExtension: "wav",
        interleaved: true
    )
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-exported-\(UUID().uuidString)")
        .appendingPathExtension("m4a")

    defer { try? FileManager.default.removeItem(at: sourceURL) }
    try exportAudioAssetToM4A(sourceURL: sourceURL, outputURL: outputURL)
    return outputURL
}

func exportAudioAssetToM4A(sourceURL: URL, outputURL: URL) throws {
    let asset = AVURLAsset(url: sourceURL)
    guard let session = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetAppleM4A
    ) else {
        throw AudioFixtureError.exportSessionUnavailable
    }

    session.outputURL = outputURL
    session.outputFileType = .m4a

    let semaphore = DispatchSemaphore(value: 0)
    session.exportAsynchronously {
        semaphore.signal()
    }
    semaphore.wait()

    if let error = session.error {
        throw error
    }

    guard session.status == .completed else {
        throw AudioFixtureError.exportIncomplete(session.status)
    }
}

private func makeSilentPCMFile(
    sampleRate: Double,
    durationSeconds: Double,
    channels: AVAudioChannelCount,
    fileExtension: String,
    interleaved: Bool = false
) throws -> URL {
    let format = try XCTUnwrap(
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: interleaved
        )
    )
    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
    buffer.frameLength = frameCount

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-\(UUID().uuidString)")
        .appendingPathExtension(fileExtension)

    let file: AVAudioFile
    if interleaved {
        file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: true
        )
    } else {
        file = try AVAudioFile(forWriting: url, settings: format.settings)
    }
    try file.write(from: buffer)
    return url
}
