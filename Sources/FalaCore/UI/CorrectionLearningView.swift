import SwiftUI

public struct CorrectionLearningView: View {
    public let originalWord: String
    public let correctedWord: String
    public let onSave: () -> Void
    public let onDismiss: () -> Void
    
    @State private var timerRemaining: Double = 6.0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    public init(
        originalWord: String,
        correctedWord: String,
        onSave: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.originalWord = originalWord
        self.correctedWord = correctedWord
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "text.badge.checkmark")
                    .foregroundColor(FalaColors.warning)
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n("Aprender correção?"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(L10n("De:"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .frame(width: 35, alignment: .leading)
                    Text(originalWord)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .strikethrough()
                }
                
                HStack(alignment: .top) {
                    Text(L10n("Para:"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .frame(width: 35, alignment: .leading)
                    Text(correctedWord)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FalaColors.warning)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                Divider()
                    .opacity(0.5)

                HStack {
                    Button(action: onDismiss) {
                        Text(L10n("Ignorar"))
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()

                    Button(action: onSave) {
                        Text(L10n("Salvar regra"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(FalaColors.warning)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))
            }

            GeometryReader { geo in
                Rectangle()
                    .fill(FalaColors.warning.opacity(0.5))
                    .frame(width: max(0, geo.size.width * (timerRemaining / 6.0)))
            }
            .frame(height: 2)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
        )
        .onReceive(timer) { _ in
            if timerRemaining > 0 {
                timerRemaining -= 0.1
            } else {
                onDismiss()
            }
        }
    }
}
