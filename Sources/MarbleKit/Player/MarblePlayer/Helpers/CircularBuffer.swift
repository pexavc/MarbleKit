//
//  ObjectQueue.swift
//  MarbleKit.Player
//
// https://github.com/kingslay/KSPlayer/blob/develop/Sources/KSPlayer/MEPlayer/CircularBuffer.swift
//  Created by kintan on 2018/3/9.
//

import Foundation

public class CircularBuffer<Item: MarblePacketObjectQueueItem> {
    private var _buffer = ContiguousArray<Item?>()
//    private let semaphore = DispatchSemaphore(value: 0)
    private let condition = NSCondition()
    private var headIndex = UInt(0)
    private var tailIndex = UInt(0)
    private let expanding: Bool
    private let sorted: Bool
    private var destroyed = false
    @inline(__always) private var _count: Int { Int(tailIndex &- headIndex) }
    @inline(__always) public var count: Int {
        condition.lock()
        defer { condition.unlock() }
        return _count
    }

    public var maxCount: Int
    private var mask: UInt

    public init(initialCapacity: Int = 256, sorted: Bool = false, expanding: Bool = true) {
        self.expanding = expanding
        self.sorted = sorted
        let capacity = initialCapacity.nextPowerOf2()
        _buffer = ContiguousArray<Item?>(repeating: nil, count: capacity)
        maxCount = capacity
        mask = UInt(maxCount - 1)
        assert(_buffer.count == capacity)
    }

    public func push(_ value: Item) {
        condition.lock()
        defer { condition.unlock() }
        if destroyed {
            return
        }
        _buffer[Int(tailIndex & mask)] = value
        if sorted {
            // more effecient than system sort functions
            var index = tailIndex
            while index > headIndex {
                guard let item = _buffer[Int((index - 1) & mask)] else {
                    assertionFailure("value is nil of index: \((index - 1) & mask) headIndex: \(headIndex),tailIndex: \(tailIndex), bufferCount: \(_buffer.count),  mask: \(mask)")
                    break
                }
                if item.position <= _buffer[Int(index & mask)]!.position {
                    break
                }
                _buffer.swapAt(Int((index - 1) & mask), Int(index & mask))
                index -= 1
            }
        }
        tailIndex &+= 1
        if _count >= maxCount {
            if expanding {
                // No more room left for another append so grow the buffer now.
                _doubleCapacity()
            } else {
                condition.wait()
            }
        } else {
            // Theres only data left, empty allocations/noise
            if _count == 1 {
                condition.signal()
            }
        }
    }

    public func pop(wait: Bool = false, where predicate: ((Item) -> Bool)? = nil) -> Item? {
        condition.lock()
        defer { condition.unlock() }
        if destroyed {
            return nil
        }
        if headIndex == tailIndex {
            if wait {
                condition.wait()
                if destroyed || headIndex == tailIndex {
                    return nil
                }
            } else {
                return nil
            }
        }
        let index = Int(headIndex & mask)
        guard let item = _buffer[index] else {
            assertionFailure("value is nil of index: \(index) headIndex: \(headIndex),tailIndex: \(tailIndex), bufferCount: \(_buffer.count), mask: \(mask)")
            return nil
        }
        if let predicate, !predicate(item) {
            return nil
        } else {
            headIndex &+= 1
            _buffer[index] = nil
            if _count == maxCount >> 1 {
                condition.signal()
            }
            return item
        }
    }

    public func search(where predicate: (Item) -> Bool) -> Item? {
        condition.lock()
        defer { condition.unlock() }
        var i = headIndex
        while i < tailIndex {
            if let item = _buffer[Int(i & mask)] {
                if predicate(item) {
                    headIndex = i
                    return item
                }
            } else {
                assertionFailure("value is nil of index: \(i) headIndex: \(headIndex), tailIndex: \(tailIndex), bufferCount: \(_buffer.count), mask: \(mask)")
                return nil
            }
            i += 1
        }
        return nil
    }
    
    public func retrieve() -> [Item?] {
        condition.lock()
        defer { condition.unlock() }
        
        let buffer = self._buffer
        
        return Array(buffer)
    }

    public func flush() {
        condition.lock()
        defer { condition.unlock() }
        headIndex = 0
        tailIndex = 0
        if destroyed {
            _buffer.removeAll(keepingCapacity: true)
            _buffer.append(contentsOf: ContiguousArray<Item?>(repeating: nil, count: maxCount))
        }
        condition.broadcast()
    }

    public func shutdown() {
        destroyed = true
        flush()
    }

    private func _doubleCapacity() {
        var newBacking: ContiguousArray<Item?> = []
        let newCapacity = maxCount << 1 // Double the storage.
        precondition(newCapacity > 0, "Can't double capacity of \(_buffer.count)")
        assert(newCapacity % 2 == 0)
        newBacking.reserveCapacity(newCapacity)
        let head = Int(headIndex & mask)
        newBacking.append(contentsOf: _buffer[head ..< maxCount])
        if head > 0 {
            newBacking.append(contentsOf: _buffer[0 ..< head])
        }
        let repeatitionCount = newCapacity &- newBacking.count
        newBacking.append(contentsOf: repeatElement(nil, count: repeatitionCount))
        headIndex = 0
        tailIndex = UInt(newBacking.count &- repeatitionCount)
        _buffer = newBacking
        maxCount = newCapacity
        mask = UInt(maxCount - 1)
    }
}

extension FixedWidthInteger {
    /// Returns the next power of two.
    @inline(__always) func nextPowerOf2() -> Self {
        guard self != 0 else {
            return 1
        }
        return 1 << (Self.bitWidth - (self - 1).leadingZeroBitCount)
    }
}
