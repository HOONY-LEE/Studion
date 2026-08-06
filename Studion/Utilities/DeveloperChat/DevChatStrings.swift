import Foundation

/// 번역된 문자열을 **조립해야 하는** 자리에서 쓴다.
///
/// `Text("어제")`처럼 뷰에 리터럴을 넘기면 SwiftUI가 문자열 카탈로그를 대신 찾아주지만,
/// "나: 안녕"이나 "어제 오전 10:30"처럼 결과가 `String`이어야 하는 경우엔 직접 꺼내야 한다.
///
/// 로케일을 인자로 받는 이유는 앱의 언어 설정(설정 탭에서 시스템과 다르게 고를 수 있다)을
/// 따라야 하기 때문이다. 시스템 로케일로 굳으면 언어 설정이 이 화면만 무시된다.
enum DevChatStrings {
    static func localized(_ key: String, locale: Locale) -> String {
        let bundle = Bundle.main
        let fallback = bundle.localizedString(forKey: key, value: key, table: nil)

        guard let code = locale.language.languageCode?.identifier,
              let path = bundle.path(forResource: code, ofType: "lproj"),
              let localeBundle = Bundle(path: path)
        else { return fallback }

        return localeBundle.localizedString(forKey: key, value: key, table: nil)
    }
}
