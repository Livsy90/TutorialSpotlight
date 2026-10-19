import SwiftUI

/// Geometry shared by both presenters. The mask uses the full container, while
/// the card is constrained to its safe content rectangle.
enum TutorialSpotlightLayout {
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 24
    static let verticalSpacing: CGFloat = 24

    static func contentBounds(
        safeBounds: CGRect,
        insets: EdgeInsets,
        layoutDirection: LayoutDirection
    ) -> CGRect {
        let left = max(0, layoutDirection == .leftToRight ? insets.leading : insets.trailing)
        let right = max(0, layoutDirection == .leftToRight ? insets.trailing : insets.leading)
        let top = max(0, insets.top)
        let bottom = max(0, insets.bottom)
        return CGRect(
            x: safeBounds.minX + min(left, safeBounds.width),
            y: safeBounds.minY + min(top, safeBounds.height),
            width: max(0, safeBounds.width - left - right),
            height: max(0, safeBounds.height - top - bottom)
        )
    }

    static func cardPosition(
        focusFrame: CGRect,
        overlaySize: CGSize,
        contentBounds: CGRect
    ) -> CGPoint {
        let maxWidth = min(320, max(0, contentBounds.width - horizontalPadding * 2))
        let width = overlaySize.width > 0 ? min(overlaySize.width, maxWidth) : maxWidth
        let height = overlaySize.height > 0 ? overlaySize.height : 180
        let minX = contentBounds.minX + horizontalPadding + width / 2
        let maxX = contentBounds.maxX - horizontalPadding - width / 2
        let minY = contentBounds.minY + verticalPadding + height / 2
        let maxY = contentBounds.maxY - verticalPadding - height / 2
        let x = clamp(focusFrame.midX, lower: minX, upper: maxX, fallback: contentBounds.midX)
        let below = focusFrame.maxY + verticalSpacing + height / 2
        let above = focusFrame.minY - verticalSpacing - height / 2
        let preferredY = below <= maxY ? below : above
        return CGPoint(
            x: x,
            y: clamp(preferredY, lower: minY, upper: maxY, fallback: contentBounds.midY)
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat, fallback: CGFloat) -> CGFloat {
        guard lower <= upper else { return fallback }
        return min(max(value, lower), upper)
    }
}
