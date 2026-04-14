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

    // MARK: - RingBuffer

    @Suite("RingBuffer")
    struct RingBufferTests {
        @Test("empty buffer has count 0")
        func empty() {
            let r = RingBuffer<Int>(capacity: 5)
            #expect(r.count == 0)
            #expect(r.isEmpty)
        }

        @Test("partial fill preserves insertion order")
        func partialFill() {
            var r = RingBuffer<Int>(capacity: 5)
            r.append(1); r.append(2); r.append(3)
            #expect(Array(r) == [1, 2, 3])
            #expect(r.count == 3)
        }

        @Test("exactly at capacity")
        func exactCapacity() {
            var r = RingBuffer<Int>(capacity: 3)
            r.append(10); r.append(20); r.append(30)
            #expect(Array(r) == [10, 20, 30])
            #expect(r.count == 3)
        }

        @Test("overflow: 7 appends into capacity-5 yields last 5 in insertion order")
        func overflow() {
            var r = RingBuffer<Int>(capacity: 5)
            for i in 1...7 { r.append(i) }
            #expect(Array(r) == [3, 4, 5, 6, 7])
            #expect(r.count == 5)
        }

        @Test("Collection iteration order matches insertion order after wrap")
        func iterationOrder() {
            var r = RingBuffer<String>(capacity: 3)
            ["a", "b", "c", "d"].forEach { r.append($0) }
            #expect(r.map { $0 } == ["b", "c", "d"])
        }

        @Test("subscript access maps correctly after overflow")
        func subscriptAccess() {
            var r = RingBuffer<Double>(capacity: 4)
            [1.0, 2.0, 3.0, 4.0, 5.0].forEach { r.append($0) }
            #expect(r[0] == 2.0)
            #expect(r[3] == 5.0)
        }

        @Test("capacity 1: only retains last appended element")
        func capacityOne() {
            var r = RingBuffer<Int>(capacity: 1)
            for i in 1...5 { r.append(i) }
            #expect(Array(r) == [5])
            #expect(r.count == 1)
        }
    }
}
