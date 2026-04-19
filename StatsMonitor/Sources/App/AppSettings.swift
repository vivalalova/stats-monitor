import Foundation
import Observation
import ServiceManagement

enum DashboardGridSizing {
    static let defaultColumnCount = 4
    static let columnRange = 3...6
}

@Observable
@MainActor
final class AppSettings {
    typealias LaunchAtLoginStateProvider = @MainActor () -> Bool
    typealias LaunchAtLoginHandler = @MainActor (Bool) -> Void

    static let defaultDashboardColumns = DashboardGridSizing.defaultColumnCount
    static let dashboardColumnRange = DashboardGridSizing.columnRange

    static let pollIntervalOptions: [TimeInterval] = [1, 2, 5, 10]
    static let historyCapacityOptions: [(label: String, value: Int)] = [
        ("1 min (60)", 60),
        ("2 min (120)", 120),
        ("5 min (300)", 300),
    ]

    private let defaults: UserDefaults
    private let launchAtLoginHandler: LaunchAtLoginHandler
    private var isHydrating = false

    var pollInterval:     Double = 2.0 { didSet { persist("pollInterval",     pollInterval) } }
    var historyCapacity:  Int    = 120 { didSet { persist("historyCapacity",  historyCapacity) } }
    var processCount:     Int    = 10  { didSet { persist("processCount",     processCount) } }
    var dashboardColumns: Int    = defaultDashboardColumns { didSet { persist("dashboardColumns", dashboardColumns) } }

    var showCPU:     Bool = true { didSet { persist("showCPU",     showCPU) } }
    var showGPU:     Bool = true { didSet { persist("showGPU",     showGPU) } }
    var showMemory:  Bool = true { didSet { persist("showMemory",  showMemory) } }
    var showDisk:    Bool = true { didSet { persist("showDisk",    showDisk) } }
    var showNetwork: Bool = true { didSet { persist("showNetwork", showNetwork) } }
    var showBattery: Bool = true { didSet { persist("showBattery", showBattery) } }
    var showThermal: Bool = true { didSet { persist("showThermal", showThermal) } }
    var showPower:   Bool = true { didSet { persist("showPower",   showPower) } }
    var showFans:    Bool = true { didSet { persist("showFans",    showFans) } }

    var showPowerPanel: Bool { showBattery || showPower }

    var launchAtLogin: Bool = false {
        didSet {
            guard !isHydrating else { return }
            launchAtLoginHandler(launchAtLogin)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginStateProvider: LaunchAtLoginStateProvider = { SMAppService.mainApp.status == .enabled },
        launchAtLoginHandler: @escaping LaunchAtLoginHandler = { enabled in
            if enabled { try? SMAppService.mainApp.register() }
            else       { try? SMAppService.mainApp.unregister() }
        }
    ) {
        self.defaults = defaults
        self.launchAtLoginHandler = launchAtLoginHandler

        isHydrating = true
        let ud = defaults
        ud.register(defaults: [
            "pollInterval": 2.0,  "historyCapacity": 120, "processCount": 10, "dashboardColumns": Self.defaultDashboardColumns,
            "showCPU": true, "showGPU": true, "showMemory": true, "showDisk": true, "showNetwork": true,
            "showBattery": true, "showThermal": true, "showPower": true, "showFans": true
        ])
        pollInterval     = ud.double (forKey: "pollInterval")
        historyCapacity  = ud.integer(forKey: "historyCapacity")
        processCount     = ud.integer(forKey: "processCount")
        dashboardColumns = Self.clampDashboardColumns(ud.integer(forKey: "dashboardColumns"))
        showCPU     = ud.bool(forKey: "showCPU")
        showGPU     = ud.bool(forKey: "showGPU")
        showMemory  = ud.bool(forKey: "showMemory")
        showDisk    = ud.bool(forKey: "showDisk")
        showNetwork = ud.bool(forKey: "showNetwork")
        showBattery = ud.bool(forKey: "showBattery")
        showThermal = ud.bool(forKey: "showThermal")
        showPower   = ud.bool(forKey: "showPower")
        showFans    = ud.bool(forKey: "showFans")
        launchAtLogin = launchAtLoginStateProvider()
        isHydrating = false
    }

    private func persist(_ key: String, _ value: Any) {
        guard !isHydrating else { return }
        defaults.set(value, forKey: key)
    }

    func setPowerPanelVisible(_ isVisible: Bool) {
        showBattery = isVisible
        showPower = isVisible
    }

    private static func clampDashboardColumns(_ value: Int) -> Int {
        min(max(value, dashboardColumnRange.lowerBound), dashboardColumnRange.upperBound)
    }
}
