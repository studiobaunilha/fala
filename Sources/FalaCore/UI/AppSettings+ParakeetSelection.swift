import Foundation

public extension AppSettings {
    func requestParakeetModelChange(_ model: ParakeetModel) {
        guard model != parakeetModel else { return }

        let didRestart = restartCoordinator.confirmAndRestart(
            title: L10n("Reinício necessário"),
            message: String(
                format: L10n("Trocar o modelo Parakeet de %@ para %@ exige reiniciar o app."),
                parakeetModel.displayName,
                model.displayName
            )
        ) { [weak self] in
            guard let self else { return }
            self.parakeetModel = model
            self.save()
        }
        if !didRestart {
            objectWillChange.send()
        }
    }
}
