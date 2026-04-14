import Foundation
import Observation
import ServiceManagement

// MARK: - AppSettings

/// 所有使用者偏好設定。@Observable 確保 SwiftUI 自動追蹤變更。
/// 每個 stored property 透過 didSet 同步至 UserDefaults。
@Observable
@MainActor
final class AppSettings {

    // MARK: - Poll Interval

    static let pollIntervalOptions: [TimeInterval] = [1, 2, 5, 10]

    var pollInterval: TimeInterval = {
        let v = UserDefaults.standard.double(forKey: "pollInterval")
        return v > 0 ? v : 2.0
    }() {
        didSet { UserDefaults.standard.set(pollInterval, forKey: "pollInterval") }
    }

    // MARK: - History Capacity

    static let historyCapacityOptions: [(label: String, value: Int)] = [
        ("1 分鐘 (60)", 60),
        ("2 分鐘 (120)", 120),
        ("5 分鐘 (300)", 300),
    ]

    var historyCapacity: Int = {
        let v = UserDefaults.standard.integer(forKey: "historyCapacity")
        return v > 0 ? v : 120
    }() {
        didSet { UserDefaults.standard.set(historyCapacity, forKey: "historyCapacity") }
    }

    // MARK: - Process Count

    var processCount: Int = {
        let v = UserDefaults.standard.integer(forKey: "processCount")
        return v > 0 ? v : 10
    }() {
        didSet { UserDefaults.standard.set(processCount, forKey: "processCount") }
    }

    // MARK: - Menu Bar Visibility

    var showCPU: Bool = (UserDefaults.standard.object(forKey: "showCPU") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showCPU, forKey: "showCPU") }
    }
    var showGPU: Bool = (UserDefaults.standard.object(forKey: "showGPU") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showGPU, forKey: "showGPU") }
    }
    var showMemory: Bool = (UserDefaults.standard.object(forKey: "showMemory") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showMemory, forKey: "showMemory") }
    }
    var showDisk: Bool = (UserDefaults.standard.object(forKey: "showDisk") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showDisk, forKey: "showDisk") }
    }
    var showNetwork: Bool = (UserDefaults.standard.object(forKey: "showNetwork") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showNetwork, forKey: "showNetwork") }
    }

    // MARK: - Dashboard Column Count

    var dashboardColumns: Int = {
        let v = UserDefaults.standard.integer(forKey: "dashboardColumns")
        return v > 0 ? v : 3
    }() {
        didSet { UserDefaults.standard.set(dashboardColumns, forKey: "dashboardColumns") }
    }

    // MARK: - Launch at Login

    /// 初始值從 SMAppService 讀取，setter 同步更新 SMAppService。
    var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
}
