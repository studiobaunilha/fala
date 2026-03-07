import Foundation

enum MLXRuntimeSupport {
    private static let bundleName = "mlx-swift_Cmlx.bundle"
    private static let metallibRelativePath = "Contents/Resources/default.metallib"

    static func ensureRuntimeAvailable(
        fileManager: FileManager = .default
    ) throws {
        guard defaultMetallibURL(fileManager: fileManager) != nil else {
            throw LLMError.mlxRuntimeUnavailable
        }
    }

    static func defaultMetallibURL(
        mainBundleURL: URL = Bundle.main.bundleURL,
        bundleResourceURLs: [URL] = Bundle.allBundles.compactMap(\.resourceURL),
        frameworkResourceURLs: [URL] = Bundle.allFrameworks.compactMap(\.resourceURL),
        fileManager: FileManager = .default
    ) -> URL? {
        let bundleRoots = uniqueURLs(
            [mainBundleURL] + bundleResourceURLs + frameworkResourceURLs
        )

        for root in bundleRoots {
            let bundledMetallib = root
                .appendingPathComponent(bundleName, isDirectory: true)
                .appendingPathComponent(metallibRelativePath)
            if fileManager.fileExists(atPath: bundledMetallib.path) {
                return bundledMetallib
            }
        }

        let directCandidates = uniqueURLs(
            bundleResourceURLs.map { $0.appendingPathComponent("default.metallib") }
                + frameworkResourceURLs.map { $0.appendingPathComponent("default.metallib") }
        )
        for candidate in directCandidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        return nil
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}
