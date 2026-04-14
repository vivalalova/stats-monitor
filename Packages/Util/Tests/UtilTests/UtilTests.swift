import Testing
@testable import Util

@Suite("Util Tests")
struct UtilTests {

    // MARK: - formatBytes

    @Suite("formatBytes")
    struct FormatBytesTests {
        @Test("zero bytes returns 0 B")
        func zeroBytes() {
            #expect(formatBytes(0) == "0 B")
        }

        @Test("exact 1 KB")
        func oneKB() {
            #expect(formatBytes(1_024) == "1 KB")
        }

        @Test("exact 1 MB")
        func oneMB() {
            #expect(formatBytes(1_048_576) == "1 MB")
        }

        @Test("exact 1 GB")
        func oneGB() {
            #expect(formatBytes(1_073_741_824) == "1.0 GB")
        }

        @Test("fractional GB")
        func fractionalGB() {
            #expect(formatBytes(1_610_612_736) == "1.5 GB")
        }

        @Test("sub-KB rounds to 0 KB")
        func subKB() {
            #expect(formatBytes(512) == "0 KB")
        }
    }

    // MARK: - formatBytesCompact

    @Suite("formatBytesCompact")
    struct FormatBytesCompactTests {
        @Test("zero returns 0M")
        func zero() {
            #expect(formatBytesCompact(0) == "0M")
        }

        @Test("exact 1 MB")
        func oneMB() {
            #expect(formatBytesCompact(1_048_576) == "1M")
        }

        @Test("exact 1 GB")
        func oneGB() {
            #expect(formatBytesCompact(1_073_741_824) == "1.0G")
        }

        @Test("fractional GB")
        func fractionalGB() {
            #expect(formatBytesCompact(1_610_612_736) == "1.5G")
        }
    }

    // MARK: - formatThroughput

    @Suite("formatThroughput")
    struct FormatThroughputTests {
        @Test("zero returns 0 KB/s")
        func zero() {
            #expect(formatThroughput(0) == "0 KB/s")
        }

        @Test("exact 1 KB/s")
        func oneKBps() {
            #expect(formatThroughput(1_024) == "1 KB/s")
        }

        @Test("exact 1 MB/s")
        func oneMBps() {
            #expect(formatThroughput(1_048_576) == "1.0 MB/s")
        }

        @Test("fractional MB/s")
        func fractionalMBps() {
            #expect(formatThroughput(1_572_864) == "1.5 MB/s")
        }
    }

    // MARK: - ghzString

    @Suite("ghzString")
    struct GhzStringTests {
        @Test("zero returns 0M")
        func zero() {
            #expect(ghzString(0) == "0M")
        }

        @Test("sub-GHz returns MHz")
        func subGHz() {
            #expect(ghzString(500_000_000) == "500M")
        }

        @Test("exact 1 GHz")
        func oneGHz() {
            #expect(ghzString(1_000_000_000) == "1.0G")
        }

        @Test("Apple Silicon P-core frequency")
        func appleSiliconPCore() {
            #expect(ghzString(3_600_000_000) == "3.6G")
        }
    }
}
