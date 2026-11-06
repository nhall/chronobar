import SwiftUI
import ChronobarCore

/// The Panel's column: its parts one under another, leading-aligned, like a `VStack`, except that the rows
/// (marked `Rows`) get only what the rest leaves of `available` points (`PanelHeight.rows`), and scroll
/// within that. Worked out in one layout pass, so the Panel's height doesn't chase its own measurements.
struct PanelStack: Layout {
    /// Marks the Panel's rows.
    struct Rows: LayoutValueKey {
        static let defaultValue = false
    }

    /// The most the column can be.
    var available: Double
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let heights = heights(width: proposal.width, subviews)
        let width = proposal.width
            ?? subviews.map { $0.sizeThatFits(ProposedViewSize(width: nil, height: nil)).width }.max() ?? 0
        return CGSize(width: width, height: heights.reduce(0, +) + gaps(subviews))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (subview, height) in zip(subviews, heights(width: bounds.width, subviews)) {
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + spacing
        }
    }

    private func gaps(_ subviews: Subviews) -> CGFloat {
        spacing * CGFloat(max(subviews.count - 1, 0))
    }

    /// Each part's own height, but the rows'.
    private func heights(width: CGFloat?, _ subviews: Subviews) -> [CGFloat] {
        let proposal = ProposedViewSize(width: width, height: nil)
        var heights = subviews.map { $0[Rows.self] ? 0 : $0.sizeThatFits(proposal).height }
        guard let rows = subviews.firstIndex(where: { $0[Rows.self] }) else { return heights }
        let natural = subviews[rows].sizeThatFits(proposal).height
        let rest = heights.reduce(0, +) + gaps(subviews)
        heights[rows] = PanelHeight.rows(natural: natural, rest: rest, available: available)
        return heights
    }
}
