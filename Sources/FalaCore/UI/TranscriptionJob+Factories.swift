extension TranscriptionJob {
    static func makeDefaultBatchTranscriberPool(config: AppConfig) -> BatchTranscriberPool {
        BatchTranscriberPool(
            whisperFactory: {
                makeWhisperBatchTranscriber(config: config)
            },
            parakeetFactory: {
                makeParakeetBatchTranscriber(config: config)
            }
        )
    }

    static func makeWhisperBatchTranscriber(config: AppConfig) -> BatchWhisperTranscriber {
        let disableNeuralEngine = HardwareInfo.isKnownToFreezeWhisperANE && !config.forceWhisperNeuralEngine
        let transcriber = Transcriber(
            modelName: config.activeWhisperModel,
            language: config.transcriptionLanguage,
            temperature: config.batchTemperature,
            prompt: "",
            disableNeuralEngine: disableNeuralEngine
        )
        return BatchWhisperTranscriber(
            loadState: {
                await transcriber.loadState()
            },
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

    static func makeParakeetBatchTranscriber(config: AppConfig) -> BatchPreloadableTranscriber {
        let transcriber = ParakeetTranscriber(
            runtime: DefaultParakeetRuntimeManager(model: config.parakeetModel),
            vocabularyProvider: {
                config.parakeetVocabularyStore
            }
        )
        return BatchPreloadableTranscriber(
            loadState: {
                await transcriber.loadState()
            },
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
