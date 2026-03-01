import SwiftUI
import KeyboardShortcuts

// MARK: – Supporting types

struct LanguageOption: Identifiable {
    let id: String  // BCP-47 code, or "auto"
    let name: String
}

// MARK: – View Model

/// Observable settings state. Changes are saved to disk and applied to the
/// Transcriber immediately so they take effect on the next dictation.
@MainActor
public final class AppSettings: ObservableObject {

    @Published public var dictationModel: String
    @Published public var batchModel: String
    @Published public var language: String

    public let modelManager: ModelManager
    private let transcriber: Transcriber

    // swiftlint:disable trailing_comma
    static let languages: [LanguageOption] = [
        LanguageOption(id: "auto", name: "Auto-detectar"),
        LanguageOption(id: "pt", name: "Português"),
        LanguageOption(id: "en", name: "English"),
        LanguageOption(id: "es", name: "Español"),
        LanguageOption(id: "fr", name: "Français"),
        LanguageOption(id: "de", name: "Deutsch"),
        LanguageOption(id: "it", name: "Italiano"),
        LanguageOption(id: "ja", name: "日本語"),
        LanguageOption(id: "zh", name: "中文"),
        LanguageOption(id: "ko", name: "한국어"),
        LanguageOption(id: "ru", name: "Русский"),
        LanguageOption(id: "ar", name: "العربية"),
    ]
    // swiftlint:enable trailing_comma

    public init(
        config: AppConfig,
        transcriber: Transcriber,
        modelManager: ModelManager
    ) {
        self.dictationModel = config.dictationModel
        self.batchModel = config.batchModel
        self.language = config.language
        self.transcriber = transcriber
        self.modelManager = modelManager
    }

    /// Persists current values and updates the Transcriber without requiring a restart.
    public func save() {
        var config = AppConfig.load()
        config.dictationModel = dictationModel
        config.batchModel = batchModel
        config.language = language
        config.save()
        Task { await transcriber.setModel(dictationModel) }
        Task { await transcriber.setLanguage(language) }
    }
}

// MARK: – Settings View

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        Form {
            Section("Atalho") {
                KeyboardShortcuts.Recorder("Ditado", name: .startDictation)
            }

            Section("Modelos") {
                ForEach(knownModels) { model in
                    ModelRow(
                        model: model,
                        manager: modelManager,
                        isDictation: settings.dictationModel == model.id,
                        isBatch: settings.batchModel == model.id
                    )
                }
            }

            Section("Modelo Ativo") {
                downloadedModelPicker("Ditado", selection: $settings.dictationModel)
                downloadedModelPicker("Batch / CLI", selection: $settings.batchModel)
            }

            Section("Idioma de Transcrição") {
                Picker("Idioma", selection: $settings.language) {
                    ForEach(AppSettings.languages) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: WindowSize.settingsWidth, minHeight: WindowSize.settingsHeight)
        .onChange(of: settings.dictationModel) { settings.save() }
        .onChange(of: settings.batchModel) { settings.save() }
        .onChange(of: settings.language) { settings.save() }
    }

    @ViewBuilder
    private func downloadedModelPicker(
        _ label: String,
        selection: Binding<String>
    ) -> some View {
        let downloaded = knownModels.filter { modelManager.isDownloaded($0.id) }
        Picker(label, selection: selection) {
            ForEach(downloaded) { model in
                Text("\(model.label)  \(model.estimatedSize)").tag(model.id)
            }
        }
    }
}

// MARK: – Model Row

private struct ModelRow: View {
    let model: ModelInfo
    @ObservedObject var manager: ModelManager
    let isDictation: Bool
    let isBatch: Bool

    private var isDownloaded: Bool { manager.isDownloaded(model.id) }
    private var progress: Double? { manager.downloads[model.id] }
    private var isActive: Bool { isDictation || isBatch }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.sm) {
                    Text(model.label)
                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(SussurroColors.success)
                            .font(Typography.caption)
                    }
                }
                HStack(spacing: Spacing.md) {
                    Text(sizeLabel).font(Typography.caption).foregroundStyle(SussurroColors.textSecondary)
                    if isDictation {
                        RoleBadge.dictation
                    }
                    if isBatch {
                        RoleBadge.batch
                    }
                }
            }

            Spacer()

            if let progress {
                ProgressView(value: progress)
                    .frame(width: 80)
                    .controlSize(.small)
                Text("\(Int(progress * 100))%")
                    .font(Typography.caption).monospacedDigit()
                    .foregroundStyle(SussurroColors.textSecondary)
                    .frame(width: 32, alignment: .trailing)
            } else if isDownloaded {
                Button(role: .destructive) {
                    try? manager.delete(model.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(isActive)
                .help(isActive ? "Não é possível apagar o modelo ativo" : "Apagar modelo")
            } else {
                Button {
                    manager.download(model.id)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help("Baixar modelo")
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var sizeLabel: String {
        manager.diskSize(for: model.id) ?? model.estimatedSize
    }
}
