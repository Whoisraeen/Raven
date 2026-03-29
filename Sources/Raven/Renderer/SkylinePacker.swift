// MARK: - Skyline Packing

public struct SkylineNode: Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
}

public struct SkylinePacker: Sendable {
    public private(set) var width: Int
    public private(set) var height: Int
    public private(set) var nodes: [SkylineNode] = []

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.nodes = [SkylineNode(x: 0, y: 0, width: width)]
    }

    /// Resizes the available packing area.
    public mutating func resize(newWidth: Int, newHeight: Int) {
        if newWidth > width {
            // Append the new space
            if !nodes.isEmpty {
                nodes[nodes.count - 1].width += newWidth - width
            } else {
                nodes.append(SkylineNode(x: width, y: 0, width: newWidth - width))
            }
        }
        self.width = newWidth
        self.height = newHeight
    }

    /// Reset the packer to empty
    public mutating func clear() {
        self.nodes = [SkylineNode(x: 0, y: 0, width: width)]
    }

    /// Attempts to pack a rectangle of `w` x `h`.
    /// Returns (x, y) if successful, or nil if it doesn't fit.
    public mutating func pack(w: Int, h: Int) -> (x: Int, y: Int)? {
        guard w > 0 && h > 0 else { return (0, 0) }

        var bestY = Int.max
        var bestX = -1
        var bestIndex = -1
        var bestWidth = Int.max

        for i in 0..<nodes.count {
            let node = nodes[i]
            if node.x + w > width {
                continue
            }

            var maxY = node.y
            var overlapWidth = node.width
            var j = i

            while overlapWidth < w {
                j += 1
                if j == nodes.count { break }
                if nodes[j].y > maxY {
                    maxY = nodes[j].y
                }
                overlapWidth += nodes[j].width
            }

            if maxY + h > height {
                continue
            }

            if maxY < bestY || (maxY == bestY && node.width < bestWidth) {
                bestY = maxY
                bestX = node.x
                bestIndex = i
                bestWidth = node.width
            }
        }

        if bestX == -1 {
            return nil
        }

        let newNode = SkylineNode(x: bestX, y: bestY + h, width: w)
        nodes.insert(newNode, at: bestIndex)

        // The new node was inserted at bestIndex.
        // It spans [bestX, bestX + w].
        // The node following it (the original one) might need to be split or shrunk.
        let i = bestIndex + 1
        while i < nodes.count {
            let nodeX = nodes[i].x
            let nodeW = nodes[i].width
            let prevNode = nodes[i - 1]
            let prevEnd = prevNode.x + prevNode.width

            if nodeX < prevEnd {
                let shrink = prevEnd - nodeX
                if nodeW <= shrink {
                    nodes.remove(at: i)
                } else {
                    nodes[i].x += shrink
                    nodes[i].width -= shrink
                    break
                }
            } else {
                break
            }
        }

        merge()
        return (bestX, bestY)
    }

    private mutating func merge() {
        var i = 0
        while i < nodes.count - 1 {
            if nodes[i].y == nodes[i + 1].y {
                nodes[i].width += nodes[i + 1].width
                nodes.remove(at: i + 1)
            } else {
                i += 1
            }
        }
    }
}
