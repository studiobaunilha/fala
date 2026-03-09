import AVFoundation
import XCTest

func makeSilentAudioFile(
    sampleRate: Double,
    durationSeconds: Double,
    channels: AVAudioChannelCount = 1,
    fileExtension: String
) throws -> URL {
    let format = try XCTUnwrap(
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )
    )
    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
    buffer.frameLength = frameCount

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-\(UUID().uuidString)")
        .appendingPathExtension(fileExtension)

    let settings: [String: Any]
    if fileExtension == "m4a" {
        settings = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: 128_000
        ]
    } else {
        settings = format.settings
    }

    let file = try AVAudioFile(
        forWriting: url,
        settings: settings,
        commonFormat: .pcmFormatFloat32,
        interleaved: false
    )
    try file.write(from: buffer)
    return url
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
    let sourceURL = try makeSilentAudioFile(
        sampleRate: sampleRate,
        durationSeconds: durationSeconds,
        channels: channels,
        fileExtension: "wav"
    )
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-exported-\(UUID().uuidString)")
        .appendingPathExtension("m4a")

    let asset = AVURLAsset(url: sourceURL)
    let session = try XCTUnwrap(
        AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
    )
    session.outputURL = outputURL
    session.outputFileType = .m4a

    let completed = testCase.expectation(description: "AAC export")
    session.exportAsynchronously {
        completed.fulfill()
    }
    testCase.wait(for: [completed], timeout: 10)

    defer { try? FileManager.default.removeItem(at: sourceURL) }

    if let error = session.error {
        throw error
    }
    XCTAssertEqual(session.status, .completed)
    return outputURL
}
