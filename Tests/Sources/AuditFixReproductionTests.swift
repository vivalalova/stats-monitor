import Testing
import Foundation
@testable import StatsMonitor

@Suite("Audit Fix Reproductions")
struct AuditFixReproductionTests {

    // MARK: - A2: battery health should read BatteryData nominal/design capacity

    @Test("A2 battery health reads BatteryData nominal/design capacity")
    func a2BatteryHealthReadsNestedBatteryData() {
        // Real macOS 27 M3 shape: top-level MaxCapacity is a 0-100 percentage with no
        // NominalChargeCapacity/DesignCapacity/AppleRawMaxCapacity at the top level —
        // those only exist inside the "BatteryData" sub-dictionary.
        let usage = BatteryMonitor.parseUsage(from: [
            "CurrentCapacity": 80,
            "MaxCapacity": 100,
            "IsCharging": false,
            "ExternalConnected": true,
            "CycleCount": 200,
            "TimeRemaining": 65535,
            "BatteryData": [
                "NominalChargeCapacity": 4030,
                "DesignCapacity": 4563,
            ],
        ])

        #expect(usage != nil)
        // Fixed behavior: health should reflect the real nominal/design capacities
        // (4030/4563 ≈ 88.3%), not the degenerate 100/100 = 100% the current top-level-only
        // parse produces.
        #expect((usage?.health ?? 100) < 99)
        #expect(usage?.maxCapacity != 100)
    }

    // MARK: - A3: GPU top apps should not show 100% on an app's first-ever sample

    @Test("A3 GPU top apps ignore unprimed pid instead of reporting spurious 100%")
    func a3GPUTopAppsIgnoreUnprimedPID() {
        let currentSnapshots = [
            GPUMonitor.AppUsageSnapshot(
                pid: 9001,
                name: "NewlyLaunchedApp",
                accumulatedGPUTime: 900_000_000, // 0.9s of lifetime GPU time, never sampled before
                commandQueueCount: 1
            ),
        ]

        let result = GPUMonitor.computeTopApps(
            currentSnapshots: currentSnapshots,
            previousTotalsByPID: [:], // pid never seen before — no baseline to diff against
            intervalSeconds: 1,
            processCount: 5
        )

        // Fixed behavior: an app with no prior sample has no valid delta and must not be
        // reported at all (certainly not near 100%).
        #expect(result.apps.isEmpty)
    }

    // MARK: - A6/D1: menu bar must always keep at least one entry point

    @Test("A6 menu bar keeps at least one item even when every panel toggle is off")
    @MainActor
    func a6MenuBarNeverFullyEmpty() {
        let settings = makeTestSettings()
        settings.showCPU = false
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        settings.showBattery = false
        settings.showPower = false
        settings.showThermal = false
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        defer { monitor.stop() }

        let items = monitor.menuBarItems(settings: settings)

        // Fixed behavior: with LSUIElement and no reopen path, the menu bar must always
        // retain at least one clickable entry point into the app.
        #expect(!items.isEmpty)
    }

    // MARK: - C7: crash report termination parsing on the real two-document .ips format

    @Test("C7 crash report termination parses real header+body .ips format")
    func c7CrashReportParsesRealTwoDocumentFormat() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("StatsMonitorCrashReportRealFormat-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        // Real .ips files are one header-line JSON document, a newline, then a full body
        // JSON document — the whole file is NOT a single valid JSON document.
        let header = #"{"app_name":"cc-status","timestamp":"2026-09-20 10:00:00.00 +0800","bug_type":"309"}"#
        let body = """
        {
          "exception" : { "type" : "EXC_CRASH", "signal" : "SIGABRT" },
          "termination" : { "flags" : 0, "code" : 6, "namespace" : "SIGNAL", "indicator" : "Abort trap: 6" }
        }
        """
        let content = header + "\n" + body
        let reportURL = directory.appendingPathComponent("StatsMonitor-2026-09-20-100000.ips")
        try content.write(to: reportURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_800_000_000)],
            ofItemAtPath: reportURL.path
        )

        let result = CrashReportReader.scan(appName: "StatsMonitor", directory: directory, limit: 1)

        guard case let .reports(reports) = result else {
            Issue.record("Expected reports, got \(result)")
            return
        }
        #expect(reports.count == 1)
        // Fixed behavior: termination must be recovered from the object-shaped
        // "termination" field in the real two-document format, not fall through to "N/A".
        let termination = reports.first?.termination ?? "N/A"
        #expect(termination != "N/A")
        #expect(
            termination.contains("SIGNAL") || termination.contains("6") || termination.contains("Abort trap")
        )
    }
}
