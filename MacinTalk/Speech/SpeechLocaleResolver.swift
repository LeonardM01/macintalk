import Foundation
import Speech

struct SpeechLocaleResolution: Equatable, Sendable {
    let locale: Locale
    let preferredLocale: Locale
    let isUsingFallback: Bool

    var displayName: String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier(.bcp47)
    }
}

enum SpeechLocaleResolver {
    static func resolve(
        preferred: Locale = .current,
        supportedLocales: [Locale]? = nil
    ) async -> SpeechLocaleResolution {
        let supported: [Locale]
        if let supportedLocales {
            supported = supportedLocales
        } else {
            supported = await SpeechTranscriber.supportedLocales
        }
        let supportedIDs = Set(supported.map { $0.identifier(.bcp47) })
        let preferredID = preferred.identifier(.bcp47)

        let candidates = orderedUnique(candidateLocaleIDs(for: preferred))
        if let matchID = candidates.first(where: { supportedIDs.contains($0) }),
           let matchedLocale = supportedLocale(in: supported, matching: matchID) {
            let isFallback = matchID != preferredID
            return SpeechLocaleResolution(
                locale: matchedLocale,
                preferredLocale: preferred,
                isUsingFallback: isFallback
            )
        }

        let emergencyFallbackID = ["en-US", "en-GB", "en"].first(where: { supportedIDs.contains($0) })
            ?? supported.first?.identifier(.bcp47)
            ?? preferredID
        let emergencyLocale = supportedLocale(in: supported, matching: emergencyFallbackID)
            ?? supported.first
            ?? Locale(identifier: emergencyFallbackID)

        return SpeechLocaleResolution(
            locale: emergencyLocale,
            preferredLocale: preferred,
            isUsingFallback: true
        )
    }

    static func supportedLocale(in supported: [Locale], matching id: String) -> Locale? {
        supported.first { $0.identifier(.bcp47) == id }
    }

    static func candidateLocaleIDs(for preferred: Locale) -> [String] {
        var ids: [String] = []
        let preferredID = preferred.identifier(.bcp47)
        ids.append(preferredID)

        if let languageCode = preferred.language.languageCode?.identifier {
            ids.append(languageCode)
        }

        if preferredID.hasPrefix("hr") {
            ids.append(contentsOf: ["hr-HR", "hr"])
        }

        ids.append(contentsOf: ["en-US", "en-GB", "en"])
        return ids
    }

    static func orderedUnique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }
}
