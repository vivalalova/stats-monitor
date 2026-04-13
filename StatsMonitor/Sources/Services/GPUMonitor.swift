import Foundation
import IOKit

struct GPUMonitor {
    func sample() -> GPUUsage {
        var deviceUtil: Double = 0
        var renderUtil: Double = 0

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

                if let val = perf["Device Utilization %"] as? Double {
                    deviceUtil = max(deviceUtil, val)
                } else if let val = perf["Device Utilization %"] as? Int {
                    deviceUtil = max(deviceUtil, Double(val))
                }

                if let val = perf["Renderer Utilization %"] as? Double {
                    renderUtil = max(renderUtil, val)
                } else if let val = perf["Renderer Utilization %"] as? Int {
                    renderUtil = max(renderUtil, Double(val))
                }
            }

            service = IOIteratorNext(iterator)
        }

        return GPUUsage(deviceUtilization: deviceUtil, renderUtilization: renderUtil)
    }
}
