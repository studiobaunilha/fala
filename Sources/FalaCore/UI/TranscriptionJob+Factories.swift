extension TranscriptionJob {
    static func makeDefaultBatchTranscriberPool(config: AppConfig) -> BatchTranscriberPool {
        BatchTranscriberPool(
            whisperFactory: {
                makeWhisperBatchTranscriber(config: config)
            },
            parakeetFactory: {
                makeParakeetBatchTranscriber()
            }
        )
    }

    static func makeWhisperBatchTranscriber(config: AppConfig) -> BatchWhisperTranscriber {
        let transcriber = Transcriber(
            modelName: config.activeWhisperModel,
            language: config.transcriptionLanguage,
            temperature: config.batchTemperature,
            prompt: ""
        )
        return BatchWhisperTranscriber(
            loadIfNeeded: { progress in
                try await transcriber.loadIfNeeded(progress: progress)
            },
            setModel: { modelName in
                await transcriber.setModel(modelName)
            },
            setConfig: { language, temperature, prompt in
                await transcriber.setConfig(
                    language: language,
                    temperature: temperature,
                    prompt: prompt
                )
            },
            transcribeSamples: { samples, task in
                try await transcriber.transcribe(samples: samples, task: task)
            },
            transcribeAudioPath: { audioPath, task, progress in
                try await transcriber.transcribe(
                    audioPath: audioPath,
                    task: task,
                    progress: progress
                )
            }
        )
    }

    static func makeParakeetBatchTranscriber() -> BatchPreloadableTranscriber {
        let transcriber = ParakeetTranscriber()
        return BatchPreloadableTranscriber(
            loadIfNeeded: { progress in
                try await transcriber.loadIfNeeded(progress: progress)
            },
            transcribeSamples: { samples, task in
                try await transcriber.transcribe(samples: samples, task: task)
            },
            transcribeAudioPath: { audioPath, task, progress in
                try await transcriber.transcribe(
                    audioPath: audioPath,
                    task: task,
                    progress: progress
                )
            }
        )
    }
}
