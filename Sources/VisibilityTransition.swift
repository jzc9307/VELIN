import Foundation

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
