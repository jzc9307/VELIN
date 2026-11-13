import Foundation
import CoreGraphics

/// Tickets prevent an old animation completion from hiding a newly shown panel.
struct AssistantVisibilityState {
    enum Phase: Equatable { case hidden, showing, visible, hiding }
    private(set) var phase: Phase = .hidden
    private(set) var targetVisible = false
    private(set) var generation: UInt64 = 0

    mutating func request(visible: Bool) -> UInt64? {
        guard visible != targetVisible else { return nil }
        generation &+= 1
        targetVisible = visible
        phase = visible ? .showing : .hiding
        return generation
    }
    func isCurrent(_ ticket: UInt64) -> Bool { generation == ticket }
    @discardableResult mutating func complete(_ ticket: UInt64) -> Bool {
        guard isCurrent(ticket) else { return false }
        phase = targetVisible ? .visible : .hidden
        return true
    }
}

/// Keep the assistant's top edge fixed when content opens below the toolbar.
enum AssistantPanelGeometry {
    static func frame(current: CGRect, screen: CGRect, listening: Bool, expanded: Bool, image: Bool, error: Bool, warning: Bool) -> CGRect {
        let width = min(660, screen.width - 32)
        var contentHeight: CGFloat = 120
        if listening { contentHeight += warning ? 206 : 178 }
        if expanded { contentHeight += 300 }
        if image { contentHeight += 84 }
        if error { contentHeight += 56 }
        let height = min(contentHeight, screen.height - 32)
        let x = min(max(current.minX, screen.minX + 16), screen.maxX - width - 16)
        let y = min(max(current.maxY - height, screen.minY + 16), screen.maxY - height - 16)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
