import Foundation

typealias CostMatrix = [[Double]]

func solveTsp(costMatrix: CostMatrix) -> [Int] {
    if costMatrix.count <= 2 {
        return Array(0..<costMatrix.count)
    }

    return GreedySolver(costMatrix: costMatrix).solve()
}

private class GreedySolver {
    private let lastIdx: Int

    private var bestPerm: [Int]
    private var currentPerm: [Int]
    private var used: [Bool]

    private let costMatrix: CostMatrix

    init(costMatrix: CostMatrix) {
        lastIdx = costMatrix.count - 1

        bestPerm = Array(1..<lastIdx)
        currentPerm = Array(1..<lastIdx)
        used = Array(count: costMatrix.count, repeatedValue: false)

        self.costMatrix = costMatrix
    }

    func solve() -> [Int] {
        backtrack(0)

        var result = [0]
        result.appendContentsOf(bestPerm)
        result.append(lastIdx)
        return result
    }

    private func getPermCost(perm: [Int]) -> Double {
        var result = costMatrix[0][perm.first!] + costMatrix[perm.last!][lastIdx]
        for idx in 1..<perm.count {
            result += costMatrix[perm[idx - 1]][perm[idx]]
        }
        return result
    }

    private func backtrack(idx: Int) {
        if idx >= currentPerm.count {
            if getPermCost(currentPerm) < getPermCost(bestPerm) {
                bestPerm.removeAll()
                bestPerm.appendContentsOf(currentPerm)
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
