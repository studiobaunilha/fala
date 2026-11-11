extension TranscriptionJob {
    func beginVocabularyRunSnapshot() {
        vocabularyRunConfig = appSettings.snapshotConfig()
    }

    func endVocabularyRunSnapshot() {
        vocabularyRunConfig = nil
    }

    var vocabularyContextDisplayName: String {
        (vocabularyRunConfig ?? appSettings.snapshotConfig()).effectiveVocabularyContext.displayName
    }
}
