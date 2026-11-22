import Foundation
import CoreGraphics

public struct ResizeEdges: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let left = ResizeEdges(rawValue: 1)
    public static let right = ResizeEdges(rawValue: 2)
    public static let top = ResizeEdges(rawValue: 4)
    public static let bottom = ResizeEdges(rawValue: 8)
}

public enum ResizeGeometry {
    /// Bottom-left coordinates, as used by AppKit. The opposite edge stays fixed.
    public static func resize(_ frame: CGRect, edges: ResizeEdges, dx: CGFloat, dy: CGFloat,
                              minimum: CGSize, within bounds: CGRect) -> CGRect {
        let minW = min(minimum.width, bounds.width)
        let minH = min(minimum.height, bounds.height)
        var left = frame.minX, right = frame.maxX, bottom = frame.minY, top = frame.maxY
        if edges.contains(.left) { left = max(bounds.minX, min(frame.minX + dx, right - minW)) }
        if edges.contains(.right) { right = min(bounds.maxX, max(frame.maxX + dx, left + minW)) }
        if edges.contains(.bottom) { bottom = max(bounds.minY, min(frame.minY + dy, top - minH)) }
        if edges.contains(.top) { top = min(bounds.maxY, max(frame.maxY + dy, bottom + minH)) }
        return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }
}
