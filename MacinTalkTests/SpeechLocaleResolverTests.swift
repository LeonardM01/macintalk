import Foundation
import Testing
@testable import MacinTalk

struct SpeechLocaleResolverTests {
    @Test func prefersCurrentLocaleWhenSupported() async {
        let supported = [Locale(identifier: "en-US"), Locale(identifier: "hr-HR")]
        let resolution = await SpeechLocaleResolver.resolve(
            preferred: Locale(identifier: "en-US"),
            supportedLocales: supported
        )

        #expect(resolution.locale == supported[0])
        #expect(resolution.locale.identifier(.bcp47) == "en-US")
        #expect(resolution.isUsingFallback == false)
    }

    @Test func fallsBackToEnglishWhenCroatianUnsupported() async {
        let supported = [Locale(identifier: "en-US"), Locale(identifier: "en-GB")]
        let resolution = await SpeechLocaleResolver.resolve(
            preferred: Locale(identifier: "hr-HR"),
            supportedLocales: supported
        )

        #expect(resolution.locale == supported[0])
        #expect(resolution.locale.identifier(.bcp47) == "en-US")
        #expect(resolution.isUsingFallback == true)
    }

    @Test func usesCroatianWhenSupported() async {
        let supported = [Locale(identifier: "hr-HR"), Locale(identifier: "en-US")]
        let resolution = await SpeechLocaleResolver.resolve(
            preferred: Locale(identifier: "hr-HR"),
            supportedLocales: supported
        )

        #expect(resolution.locale == supported[0])
        #expect(resolution.locale.identifier(.bcp47) == "hr-HR")
        #expect(resolution.isUsingFallback == false)
    }

    @Test func emergencyFallbackUsesSupportedLocaleInstance() async {
        let supported = [Locale(identifier: "en-GB"), Locale(identifier: "de-DE")]
        let resolution = await SpeechLocaleResolver.resolve(
            preferred: Locale(identifier: "xx-YY"),
            supportedLocales: supported
        )

        #expect(resolution.locale == supported[0])
        #expect(resolution.isUsingFallback == true)
    }

    @Test func candidateLocalesIncludeCroatianVariants() {
        let candidates = SpeechLocaleResolver.candidateLocaleIDs(for: Locale(identifier: "hr-HR"))
        #expect(candidates.contains("hr-HR"))
        #expect(candidates.contains("hr"))
        #expect(candidates.contains("en-US"))
    }
}
