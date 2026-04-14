/// A fixed-capacity circular buffer with O(1) append.
/// Elements are yielded in insertion order (oldest first).
public struct RingBuffer<Element>: RandomAccessCollection {
    private var storage: [Element]
    private var head: Int = 0
    public private(set) var count: Int = 0
    public let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        self.storage = []
        self.storage.reserveCapacity(capacity)
    }

    /// Appends an element. When full, the oldest element is evicted. O(1).
    public mutating func append(_ element: Element) {
        if count < capacity {
            storage.append(element)
            count += 1
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    // MARK: RandomAccessCollection

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(i: Int) -> Element {
        precondition(i >= 0 && i < count, "Index out of range")
        return storage[(head + i) % capacity]
    }

    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
}

extension RingBuffer: Sendable where Element: Sendable {}
