import SwiftUI

extension SettingsView {
    @ViewBuilder
    var aboutView: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                Spacer().frame(height: 20)
                
                // App Icon
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                
                // App Name & Version
                VStack(spacing: 4) {
                    Text("Fala Pro")
                        .font(.system(size: 32, weight: .bold))
                    
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Versão \(version) (\(build))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                    .frame(width: 200)
                
                // Studio Baunilha Banner
                VStack(spacing: 8) {
                    Text("Desenvolvido por")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Studio Baunilha")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Inteligência Artificial para Mac, construída com paixão e performance.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)
                }
                
                // Links
                HStack(spacing: 16) {
                    if let url = URL(string: "https://studio.baunilha.dev") {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Website")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    
                    if let githubUrl = URL(string: "https://github.com/studiobaunilha") {
                        Link(destination: githubUrl) {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                Text("GitHub")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.top, 8)
                
                Spacer()
                
                Text(
                    "© \(Calendar.current.component(.year, from: Date())) " +
                    "Studio Baunilha. Todos os direitos reservados."
                )
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
        }
    }
}
