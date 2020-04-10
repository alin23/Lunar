import Cocoa
import Foundation

func mapNumberSIMD(_ number: [Int16], fromLow: Int16, fromHigh: Int16, toLow: Int16, toHigh: Int16) -> [Int16] {
    let resultLow = number.firstIndex(where: { $0 > fromLow }) ?? 0
    let resultHigh = number.lastIndex(where: { $0 < fromHigh }) ?? (number.count - 1)
    let numbers = number[resultLow ... resultHigh]
    let lowerBound = [Int16](repeating: toLow, count: resultLow)
    let upperBound = [Int16](repeating: toHigh, count: resultHigh)

    let diff = (toHigh - toLow + 1)
    let fromDiff = (fromHigh - fromLow)
    var value = numbers.map { $0 - fromLow }
    value = value.map { $0 * diff }
    value = value.map { $0 / fromDiff }
    value = value.map { $0 + toLow }

    var result = lowerBound
    result.reserveCapacity(number.count)
    result.append(contentsOf: value)
    result.append(contentsOf: upperBound)
    return result
}

func mapNumber<T: Numeric & Comparable & FloatingPoint>(_ number: T, fromLow: T, fromHigh: T, toLow: T, toHigh: T) -> T {
    if fromLow == fromHigh {
        return number
    }

    if number >= fromHigh {
        return toHigh
    } else if number <= fromLow {
        return toLow
    } else if toLow < toHigh {
        let diff = (toHigh - toLow + 1)
        let fromDiff = fromHigh - fromLow
        return (number - fromLow) * diff / fromDiff + toLow
    } else {
        let diff = (toHigh - toLow - 1)
        let fromDiff = fromHigh - fromLow
        return (number - fromLow) * diff / fromDiff + toLow
    }
}

func mapNumber2<T: Numeric & Comparable & FloatingPoint>(_ number: T, fromLow: T, fromHigh: T, toLow: T, toHigh: T) -> T {
    if fromLow == fromHigh {
        return number
    }

    if number >= fromHigh {
        return toHigh
    } else if number <= fromLow {
        return toLow
    } else if toLow < toHigh {
        let diff = toHigh - toLow
        let fromDiff = fromHigh - fromLow
        return (number - fromLow) * diff / fromDiff + toLow
    } else {
        let diff = toHigh - toLow
        let fromDiff = fromHigh - fromLow
        return (number - fromLow) * diff / fromDiff + toLow
    }
}

print(mapNumber(0.8, fromLow: 0.10, fromHigh: 0.90, toLow: 0.0, toHigh: 1.0))
print(mapNumber(0.8, fromLow: 0.10, fromHigh: 0.60, toLow: 0.0, toHigh: 1.0))
print(mapNumber(80, fromLow: 0, fromHigh: 100, toLow: 0, toHigh: 255))
print(mapNumber(254, fromLow: 10, fromHigh: 255, toLow: 0, toHigh: 100))
print(mapNumber(1, fromLow: 10, fromHigh: 255, toLow: 0, toHigh: 100))
print(mapNumber(0, fromLow: 10, fromHigh: 255, toLow: 0, toHigh: 100))

print(mapNumber2(0.8, fromLow: 0.10, fromHigh: 0.90, toLow: 0.0, toHigh: 1.0))
print(mapNumber2(0.8, fromLow: 0.10, fromHigh: 0.60, toLow: 0.0, toHigh: 1.0))
print(mapNumber2(80, fromLow: 0, fromHigh: 100, toLow: 0, toHigh: 255))
print(mapNumber2(254, fromLow: 10, fromHigh: 255, toLow: 0, toHigh: 100))
print(mapNumber2(1, fromLow: 10, fromHigh: 255, toLow: 0, toHigh: 100))
print(mapNumber2(0, fromLow: 10, fromHigh: 255, toLow: 0, toHigh: 100))
