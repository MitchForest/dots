public import SwiftUI

/// Left-aligned flow layout: children keep their natural size and wrap onto
/// new rows as the width runs out. Used for tag chips and similar runs of
/// small elements.
public struct DotsFlowLayout: Layout {
    private let itemSpacing: CGFloat
    private let rowSpacing: CGFloat

    public init(itemSpacing: CGFloat = 4, rowSpacing: CGFloat = 4) {
        self.itemSpacing = itemSpacing
        self.rowSpacing = rowSpacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + itemSpacing + size.width > width {
                totalHeight += rowHeight + rowSpacing
                maxWidth = max(maxWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? itemSpacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        maxWidth = max(maxWidth, rowWidth)
        totalHeight += rowHeight
        return CGSize(
            width: width.isFinite ? min(width, maxWidth) : maxWidth,
            height: totalHeight
        )
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let width = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + itemSpacing + size.width > width {
                y += rowHeight + rowSpacing
                x = 0
                rowHeight = 0
            }
            if x > 0 {
                x += itemSpacing
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}
