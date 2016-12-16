import Foundation

typealias CostMatrix = [[Double]]

func solveTsp(_ costMatrix: CostMatrix) -> [Int] {
    if costMatrix.count <= 2 {
        return Array(0..<costMatrix.count)
    }

    if costMatrix.count <= 10 {
        return BacktrackingSolver(costMatrix: costMatrix).solve()
    }

    return GreedySolver(costMatrix: costMatrix).solve()
}

private class BacktrackingSolver {
    fileprivate let lastIdx: Int

    fileprivate var bestPerm: [Int]
    fileprivate var currentPerm: [Int]
    fileprivate var used: [Bool]

    fileprivate let costMatrix: CostMatrix

    init(costMatrix: CostMatrix) {
        lastIdx = costMatrix.count - 1

        bestPerm = Array(1..<lastIdx)
        currentPerm = Array(1..<lastIdx)
        used = Array(repeating: false, count: costMatrix.count)

        self.costMatrix = costMatrix
    }

    func solve() -> [Int] {
        backtrack(0)

        var result = [0]
        result.append(contentsOf: bestPerm)
        result.append(lastIdx)
        return result
    }

    fileprivate func getPermCost(_ perm: [Int]) -> Double {
        var result = costMatrix[0][perm.first!] + costMatrix[perm.last!][lastIdx]
        for idx in 1..<perm.count {
            result += costMatrix[perm[idx - 1]][perm[idx]]
        }
        return result
    }

    fileprivate func backtrack(_ idx: Int) {
        if idx >= currentPerm.count {
            if getPermCost(currentPerm) < getPermCost(bestPerm) {
                bestPerm.removeAll()
                bestPerm.append(contentsOf: currentPerm)
            }
            return
        }

        for elem in 1..<lastIdx {
            if !used[elem] {
                used[elem] = true
                currentPerm[idx] = elem
                backtrack(idx + 1)
                used[elem] = false
            }
        }
    }
}

private class GreedySolver {
    fileprivate let costMatrix: CostMatrix

    init(costMatrix: CostMatrix) {
        self.costMatrix = costMatrix
    }

    func solve() -> [Int] {
        var result = formPathCandidate()
        for _ in 1..<100000 {
            let candidate = formPathCandidate()
            if pathCost(costMatrix, path: candidate) < pathCost(costMatrix, path: result) {
                result = candidate
            }
        }
        return result
    }

    fileprivate func formInitialCycle() -> [Int] {
        var result = Array(1..<costMatrix.count - 1)

        var i = result.count - 1
        while i >= 1 {
            let j = Int(arc4random_uniform(UInt32(i + 1)))
            if i != j {
                swap(&result[i], &result[j])
            }
            i -= 1
        }

        return result
    }

    fileprivate func shouldReverseSegment(_ result: [Int], start: Int, end: Int) -> Bool {
        let getIthVertex = {
            i in (i >= result.count) ? self.costMatrix.count - 1 : result[i]
        }

        let prevToIthVertex = {
            i in (i == 0) ? 0 : getIthVertex(i - 1)
        }

        let (a, b, c, d) = (prevToIthVertex(start), getIthVertex(start), prevToIthVertex(end), getIthVertex(end))
        return costMatrix[a][c] + costMatrix[b][d] < costMatrix[a][b] + costMatrix[c][d]
    }

    fileprivate func improveCycle(_ result: inout [Int]) {
        while true {
            var reversed = false
            for length in (2...result.count).reversed() {
                var start = 0
                while start + length <= result.count {
                    let end = start + length
                    if shouldReverseSegment(result, start: start, end: end) {
                        result.replaceSubrange(start..<end, with: result[start..<end].reversed())
                        reversed = true
                    }
                    start += 1
                }
            }
            if !reversed {
                break
            }
        }
    }

    fileprivate func formPathCandidate() -> [Int] {
        var result = formInitialCycle()
        improveCycle(&result)

        result.insert(0, at: 0)
        result.append(costMatrix.count - 1)
        return result
    }
}

private func pathCost(_ costMatrix: CostMatrix, path: [Int]) -> Double {
    var result = 0.0
    for i in 1..<path.count {
        result += costMatrix[path[i - 1]][path[i]]
    }
    return result
}
