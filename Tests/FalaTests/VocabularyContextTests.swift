import XCTest
@testable import FalaCore

final class VocabularyContextTests: XCTestCase {
    func testDefaultRecognitionSnapshotKeepsOldHintsWhileFinalRulesRemainCurrent() {
        var captured = AppConfig()
        captured.replacementRules = [ReplacementRule(variants: ["Nico"], replacement: "Niko")]
        var current = captured
        current.replacementRules = [ReplacementRule(variants: ["Nico"], replacement: "Nicolau")]
        current.applyVocabularySnapshot(from: captured)
        XCTAssertEqual(current.effectiveVocabularyContext.store, captured.effectiveVocabularyContext.store)
        XCTAssertEqual(current.effectiveVocabularyContext.store.terms.map(\.text), ["Niko"])
        XCTAssertEqual(
            ReplacementRule.applyAll("comunico com Nico", rules: current.replacementRules), "comunico com Nicolau"
        )
    }

    func testLegacyAndDisabledContextsPreserveGlobalVocabulary() throws {
        var config = try JSONDecoder().decode(AppConfig.self, from: Data("{}".utf8))
        XCTAssertFalse(config.vocabularyContextsEnabled)
        XCTAssertNil(config.effectiveVocabularyContext.id)
        config.parakeetVocabularyTerms = [ParakeetVocabularyTerm(text: "Global")]
        config.replacementRules = [ReplacementRule(variants: ["jirah"], replacement: "JIRA")]
        let context = VocabularyContext(name: "Work", terms: [ParakeetVocabularyTerm(text: "Project")])
        config.vocabularyContexts = [context]
        config.selectedVocabularyContextID = context.id
        XCTAssertEqual(config.effectiveVocabularyContext.store, config.parakeetVocabularyStore)
        XCTAssertEqual(config.effectiveVocabularyContext.store.terms.map(\.text), ["Global", "JIRA"])
    }

    func testNamedContextExcludesGlobalHintsAndDoesNotChangePromptsOrFinalRules() {
        var config = AppConfig()
        config.vocabularyContextsEnabled = true
        config.parakeetVocabularyTerms = [ParakeetVocabularyTerm(text: "Global")]
        config.replacementRules = [ReplacementRule(variants: ["Nico"], replacement: "Niko")]
        let before = config.getEffectiveConfig(for: .custom)
        let context = VocabularyContext(name: "Work", terms: [
            ParakeetVocabularyTerm(text: "Project", aliases: ["project alias"])
        ])
        config.vocabularyContexts = [context]
        config.selectedVocabularyContextID = context.id
        XCTAssertEqual(config.effectiveVocabularyContext.store.terms, context.terms)
        XCTAssertEqual(config.getEffectiveConfig(for: .custom).prompt, before.prompt)
        XCTAssertEqual(config.getEffectiveConfig(for: .custom).provider, before.provider)
        XCTAssertEqual(
            ReplacementRule.applyAll("comunico com Nico", rules: config.replacementRules), "comunico com Niko"
        )
        config.vocabularyContexts[0].terms = []
        XCTAssertTrue(config.effectiveVocabularyContext.store.isEmpty)
    }

    func testSnapshotRetainsDeletedProfileAndIsNotPersisted() throws {
        var initial = AppConfig()
        initial.vocabularyContextsEnabled = true
        let context = VocabularyContext(name: "Project A", terms: [ParakeetVocabularyTerm(text: "Alpha")])
        initial.vocabularyContexts = [context]
        initial.selectedVocabularyContextID = context.id
        var current = initial
        current.vocabularyContexts = []
        current.llmProvider = "gemini"
        current.replacementRules = [ReplacementRule(variants: ["Nico"], replacement: "Nicolau")]
        XCTAssertNil(current.effectiveVocabularyContext.id)
        current.applyVocabularySnapshot(from: initial)
        XCTAssertEqual(current.effectiveVocabularyContext, initial.effectiveVocabularyContext)
        XCTAssertEqual(current.llmProvider, "gemini")
        XCTAssertEqual(current.replacementRules.first?.replacement, "Nicolau")
        let encoded = try JSONEncoder().encode(current)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(payload["capturedVocabularyContext"])
        let restored = try JSONDecoder().decode(AppConfig.self, from: encoded)
        XCTAssertNil(restored.capturedVocabularyContext)
        XCTAssertEqual(restored.vocabularyContexts, initial.vocabularyContexts)
    }

    @MainActor
    func testQueueSnapshotSurvivesProfileDeletionUntilNextRun() {
        var config = AppConfig()
        config.vocabularyContextsEnabled = true
        let context = VocabularyContext(name: "Project A", terms: [ParakeetVocabularyTerm(text: "Alpha")])
        config.vocabularyContexts = [context]
        config.selectedVocabularyContextID = context.id
        let settings = AppSettings(
            config: config, transcriber: Transcriber(modelName: config.activeWhisperModel), modelManager: ModelManager()
        )
        let job = TranscriptionJob(appSettings: settings)
        job.beginVocabularyRunSnapshot()
        settings.vocabularyContexts = []
        settings.selectedVocabularyContextID = nil
        XCTAssertEqual(job.preparationConfig().effectiveVocabularyContext.id, context.id)
        XCTAssertEqual(job.preparationConfig().effectiveVocabularyContext.name, "Project A")
        XCTAssertEqual(job.preparationConfig().effectiveVocabularyContext.store.terms, context.terms)
        job.endVocabularyRunSnapshot()
        job.beginVocabularyRunSnapshot()
        XCTAssertNil(job.preparationConfig().effectiveVocabularyContext.id)
        job.endVocabularyRunSnapshot()
    }

    @MainActor
    func testContextCRUDValidatesNamesNormalizesTermsAndFallsBackAfterDeletion() throws {
        let config = AppConfig()
        let settings = AppSettings(
            config: config, transcriber: Transcriber(modelName: config.activeWhisperModel), modelManager: ModelManager()
        )
        var persisted: [AppConfig] = []
        settings.persistVocabularyConfiguration = { persisted.append($0) }
        XCTAssertFalse(settings.createVocabularyContext(name: "  "))
        XCTAssertTrue(settings.createVocabularyContext(name: " Work "))
        let id = try XCTUnwrap(settings.selectedVocabularyContextID)
        XCTAssertFalse(settings.createVocabularyContext(name: "work"))
        let originalRevision = try XCTUnwrap(settings.vocabularyContexts.first?.revision)
        settings.setVocabularyTerms([
            ParakeetVocabularyTerm(text: " JIRA ", aliases: ["jirah", "JIRAH", ""]),
            ParakeetVocabularyTerm(text: "jira", aliases: ["jira tool"])
        ], contextID: id)
        XCTAssertEqual(settings.vocabularyContexts.first?.terms.count, 1)
        XCTAssertEqual(settings.vocabularyContexts.first?.terms.first?.aliases, ["jirah", "jira tool"])
        XCTAssertNotEqual(settings.vocabularyContexts.first?.revision, originalRevision)
        XCTAssertTrue(settings.renameVocabularyContext(id: id, name: "Project"))
        settings.deleteVocabularyContext(id: id)
        XCTAssertNil(settings.selectedVocabularyContextID)
        XCTAssertTrue(settings.vocabularyContexts.isEmpty)
        XCTAssertFalse(persisted.isEmpty)
        XCTAssertTrue(persisted.last?.vocabularyContexts.isEmpty == true)
    }
}
