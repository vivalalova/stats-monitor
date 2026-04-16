import Foundation
@testable import StatsMonitor

@MainActor
func makeTestDefaults() -> UserDefaults {
    let suiteName = "StatsMonitorTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Failed to create isolated test defaults for suite \(suiteName)")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@MainActor
func makeTestSettings(
    defaults: UserDefaults? = nil,
    launchAtLoginEnabled: Bool = false
) -> AppSettings {
    let isolatedDefaults = defaults ?? makeTestDefaults()
    return AppSettings(
        defaults: isolatedDefaults,
        launchAtLoginStateProvider: { launchAtLoginEnabled },
        launchAtLoginHandler: { _ in }
    )
}
