import Foundation
import IOKit

// MARK: - SMC Param Struct
// Flat layout exactly matching the AppleSMC kernel struct (80 bytes).
// Field offsets verified against the C ABI layout:
//   [0..3]  key
//   [4..9]  SMCVersion (major/minor/build/reserved/release)
//   [10..11] padding (align pLimitData to 4)
//   [12..27] SMCPLimitData (version/length/cpuPLimit/gpuPLimit/memPLimit)
//   [28..39] SMCKeyInfoData (dataSize/dataType/dataAttributes + 3 padding)
//   [40..43] result/status/data8 + 1 padding (align data32 to 4)
//   [44..47] data32
//   [48..79] bytes[32]

private struct SMCParamStruct {
    var key:                   UInt32 = 0
    var versMajor:             UInt8  = 0
    var versMinor:             UInt8  = 0
    var versBuild:             UInt8  = 0
    var versReserved:          UInt8  = 0
    var versRelease:           UInt16 = 0
    var _pad0:                 UInt16 = 0   // align pLimitData to 4
    var pLimitVersion:         UInt16 = 0
    var pLimitLength:          UInt16 = 0
    var cpuPLimit:             UInt32 = 0
    var gpuPLimit:             UInt32 = 0
    var memPLimit:             UInt32 = 0
    var keyInfoDataSize:       UInt32 = 0
    var keyInfoDataType:       UInt32 = 0
    var keyInfoDataAttributes: UInt8  = 0
    var _pad1:                 UInt8  = 0   // pad keyInfo to 12 bytes
    var _pad2:                 UInt8  = 0
    var _pad3:                 UInt8  = 0
    var result:                UInt8  = 0
    var status:                UInt8  = 0
    var data8:                 UInt8  = 0
    var _pad4:                 UInt8  = 0   // align data32 to 4
    var data32:                UInt32 = 0
    var bytes: (UInt8,UInt8,UInt8,UInt8, UInt8,UInt8,UInt8,UInt8,
                UInt8,UInt8,UInt8,UInt8, UInt8,UInt8,UInt8,UInt8,
                UInt8,UInt8,UInt8,UInt8, UInt8,UInt8,UInt8,UInt8,
                UInt8,UInt8,UInt8,UInt8, UInt8,UInt8,UInt8,UInt8) =
               (0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
                0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0)
}

// MARK: - SMCClient

/// Shared IOKit connection to the AppleSMC service.
/// `@unchecked Sendable` because `io_connect_t` (a Mach port) is a value type handle
/// that is safe to hold across isolation boundaries after init.
final class SMCClient: @unchecked Sendable {

    private var connection: io_connect_t = 0
    private(set) var isAvailable = false

    /// True when running on Apple Silicon (arm64); false on Intel x86_64.
    let isAppleSilicon: Bool

    init() {
        // Detect architecture once at startup
        var val: Int = 0
        var size = MemoryLayout<Int>.size
        isAppleSilicon = sysctlbyname("hw.optional.arm64", &val, &size, nil, 0) == 0 && val != 0

        // Verify struct layout at runtime
        assert(MemoryLayout<SMCParamStruct>.size == 80,
               "SMCParamStruct layout mismatch: \(MemoryLayout<SMCParamStruct>.size) != 80")

        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        if IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess {
            isAvailable = true
        }
    }

    deinit {
        if isAvailable { IOServiceClose(connection) }
    }

    // MARK: - Public API

    /// Reads an SMC key and decodes it as a Celsius temperature.
    /// Returns nil when the key is unavailable or the decoded value is outside –40…150 °C.
    func readTemperature(_ key: String) -> Double? {
        guard let (bytes, dataType) = readRaw(key),
              let celsius = Self.decodeNumeric(dataType: dataType, bytes: bytes) else { return nil }
        return (-40.0...150.0).contains(celsius) ? celsius : nil
    }

    /// Reads an SMC key decoded as fan RPM (Intel `fpe2`, Apple Silicon `flt `).
    func readFanRPM(_ key: String) -> Double? {
        guard let (bytes, dataType) = readRaw(key) else { return nil }
        return Self.decodeNumeric(dataType: dataType, bytes: bytes)
    }

    /// Decodes a numeric SMC value by its reported data type; nil for unsupported types.
    /// `sp78` / `fpe2` are big-endian fixed-point; `flt ` is a little-endian Float32.
    static func decodeNumeric(dataType: UInt32, bytes: [UInt8]) -> Double? {
        switch dataType {
        case fourCC("sp78") where bytes.count >= 2:
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256.0
        case fourCC("fpe2") where bytes.count >= 2:
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4.0
        case fourCC("flt ") where bytes.count >= 4:
            let bits = UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16
                     | UInt32(bytes[1]) << 8  | UInt32(bytes[0])
            let value = Float(bitPattern: bits)
            return value.isFinite ? Double(value) : nil
        default:
            return nil
        }
    }

    /// Reads an SMC key decoded as a single UInt8 (e.g. `FNum` for fan count).
    func readUInt8(_ key: String) -> UInt8? {
        guard let (bytes, _) = readRaw(key), !bytes.isEmpty else { return nil }
        return bytes[0]
    }

    /// Reads raw bytes for an SMC key along with its data type four-char code.
    func readKey(_ key: String) -> [UInt8]? {
        readRaw(key)?.bytes
    }

    // MARK: - Private

    private func readRaw(_ key: String) -> (bytes: [UInt8], dataType: UInt32)? {
        // Step 1: get key info (data size + type)
        var infoReq = SMCParamStruct()
        infoReq.key  = Self.fourCC(key)
        infoReq.data8 = 9  // kSMCGetKeyInfo
        guard let info = callSMC(infoReq), info.result == 0 else { return nil }

        let dataSize = Int(info.keyInfoDataSize)
        guard dataSize > 0, dataSize <= 32 else { return nil }

        // Step 2: read value
        var readReq = SMCParamStruct()
        readReq.key            = Self.fourCC(key)
        readReq.data8          = 5  // kSMCReadKey
        readReq.keyInfoDataSize = info.keyInfoDataSize
        guard let result = callSMC(readReq), result.result == 0 else { return nil }

        let bytes = withUnsafeBytes(of: result.bytes) { Array($0.prefix(dataSize)) }
        return (bytes, info.keyInfoDataType)
    }

    private func callSMC(_ input: SMCParamStruct) -> SMCParamStruct? {
        var inputCopy  = input
        var output     = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let ret = IOConnectCallStructMethod(
            connection, 2,          // selector 2 = kSMCHandleYPCEvent
            &inputCopy, MemoryLayout<SMCParamStruct>.stride,
            &output,    &outputSize
        )
        return ret == kIOReturnSuccess ? output : nil
    }

    static func fourCC(_ key: String) -> UInt32 {
        var code: UInt32 = 0
        for (i, byte) in key.utf8.prefix(4).enumerated() {
            code |= UInt32(byte) << UInt32((3 - i) * 8)
        }
        return code
    }
}
