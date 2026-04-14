import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class AppSettings {

    static let pollIntervalOptions: [TimeInterval] = [1, 2, 5, 10]
    static let historyCapacityOptions: [(label: String, value: Int)] = [
        ("1 分鐘 (60)", 60),
        ("2 分鐘 (120)", 120),
        ("5 分鐘 (300)", 300),
    ]

    var pollInterval:     Double = 2.0 { didSet { persist("pollInterval",     pollInterval) } }
    var historyCapacity:  Int    = 120 { didSet { persist("historyCapacity",  historyCapacity) } }
    var processCount:     Int    = 10  { didSet { persist("processCount",     processCount) } }
    var dashboardColumns: Int    = 3   { didSet { persist("dashboardColumns", dashboardColumns) } }

    var showCPU:     Bool = true { didSet { persist("showCPU",     showCPU) } }
    var showGPU:     Bool = true { didSet { persist("showGPU",     showGPU) } }
    var showMemory:  Bool = true { didSet { persist("showMemory",  showMemory) } }
    var showDisk:    Bool = true { didSet { persist("showDisk",    showDisk) } }
    var showNetwork: Bool = true { didSet { persist("showNetwork", showNetwork) } }

    var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            if launchAtLogin { try? SMAppService.mainApp.register() }
            else             { try? SMAppService.mainApp.unregister() }
        }
    }

    init() {
        let ud = UserDefaults.standard
        ud.register(defaults: [
            "pollInterval": 2.0,  "historyCapacity": 120, "processCount": 10, "dashboardColumns": 3,
            "showCPU": true, "showGPU": true, "showMemory": true, "showDisk": true, "showNetwork": true
        ])
        pollInterval     = ud.double (forKey: "pollInterval")
        historyCapacity  = ud.integer(forKey: "historyCapacity")
        processCount     = ud.integer(forKey: "processCount")
        dashboardColumns = ud.integer(forKey: "dashboardColumns")
        showCPU     = ud.bool(forKey: "showCPU")
        showGPU     = ud.bool(forKey: "showGPU")
        showMemory  = ud.bool(forKey: "showMemory")
        showDisk    = ud.bool(forKey: "showDisk")
        showNetwork = ud.bool(forKey: "showNetwork")
    }

    private func persist(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
