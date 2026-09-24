import Foundation

/// 依指定 locale（而非行程語系）取譯文。
///
/// SwiftUI 的 `LocalizedStringKey` 只認行程語系，AppKit alert 這類手動組字的文案需要能在測試裡
/// 釘死語言，所以走 `.lproj` bundle 直接查表。找不到對應語系就退回主 bundle（即 base localization）。
enum LocalizedCopy {
    static func string(_ key: String, locale: Locale) -> String {
        bundle(for: locale).localizedString(forKey: key, value: nil, table: nil)
    }

    /// 帶格式參數的譯文（如 `"Force Quit %@?"`）。
    static func string(_ key: String, locale: Locale, arguments: [any CVarArg]) -> String {
        String(format: string(key, locale: locale), locale: locale, arguments: arguments)
    }

    private static func bundle(for locale: Locale) -> Bundle {
        let localization = Bundle.preferredLocalizations(
            from: Bundle.main.localizations,
            forPreferences: [locale.identifier]
        ).first

        return localization
            .flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? .main
    }
}
