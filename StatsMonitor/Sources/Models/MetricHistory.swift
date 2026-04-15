import Foundation
import Util

struct MetricHistory<Value> {
    private var buffer: RingBuffer<Value>

    init(capacity: Int) {
        buffer = RingBuffer(capacity: capacity)
    }

    var current: Value? { buffer.last }
    var values: [Value] { Array(buffer) }
    var capacity: Int { buffer.capacity }

    mutating func record(_ value: Value) {
        buffer.append(value)
    }
}

extension MetricHistory: Sendable where Value: Sendable {}
