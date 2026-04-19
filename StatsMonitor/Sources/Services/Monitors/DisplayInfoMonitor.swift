import Foundation
import CoreGraphics

struct DisplayInfoMonitor: Sendable {
    func sample() -> DisplayInfo {
        let displayID = CGMainDisplayID()
        guard let mode = CGDisplayCopyDisplayMode(displayID) else {
            return .zero
        }
        let width = Int(mode.pixelWidth)
        let height = Int(mode.pixelHeight)
        let refresh = mode.refreshRate
        return DisplayInfo(widthPixels: width, heightPixels: height, refreshRateHz: refresh)
    }
}
