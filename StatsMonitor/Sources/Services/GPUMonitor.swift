import Foundation
import IOKit

struct GPUMonitor {
    func sample() -> GPUUsage {
        var deviceUtil: Double = 0
        var renderUtil: Double = 0
        var engines: [String: Double] = [:]
        var vramUsed: UInt64 = 0

        let matchingDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return .zero
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }

            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {

                for (key, val) in perf where key.hasSuffix("Utilization %") {
                    let utilization: Double
                    if let d = val as? Double {
                        utilization = d
                    } else if let i = val as? Int {
                        utilization = Double(i)
                    } else {
                        continue
                    }

                    let label = key.replacingOccurrences(of: " Utilization %", with: "")
                    engines[label] = max(engines[label] ?? 0, utilization)

                    if key == "Device Utilization %" {
                        deviceUtil = max(deviceUtil, utilization)
                    } else if key == "Renderer Utilization %" {
                        renderUtil = max(renderUtil, utilization)
                    }
                }

                if let n = perf["In Use System Memory"] as? NSNumber {
                    vramUsed = max(vramUsed, n.uint64Value)
                }
            }

            service = IOIteratorNext(iterator)
        }

        return GPUUsage(deviceUtilization: deviceUtil, renderUtilization: renderUtil,
                        engines: engines, vramUsed: vramUsed)
    }
}
