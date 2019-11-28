import Foundation

class BoundedArray<T> {
    private var data: [T]
    let capacity: Int
    var last: T? {
        return data.last
    }

    init(capacity: Int) {
        data = []
        data.reserveCapacity(capacity)
        self.capacity = capacity
    }

    func push(_ element: T) {
        if data.count == capacity {
            data.removeFirst()
        }
        data.append(element)
    }

    func first(where condition: (T) -> Bool) -> T? {
        return data.first(where: condition)
    }

    func last(where condition: (T) -> Bool) -> T? {
        return data.last(where: condition)
    }
}
