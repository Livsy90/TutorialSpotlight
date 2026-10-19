import SwiftUI
import XCTest
@testable import TutorialSpotlight

final class TutorialSpotlightLayoutTests: XCTestCase {
    func testCardStaysInsideSafeAreaWithTrailingObstruction() {
        let content = TutorialSpotlightLayout.contentBounds(
            safeBounds: CGRect(x: 20, y: 60, width: 660, height: 460),
            insets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 80),
            layoutDirection: .leftToRight
        )
        let size = CGSize(width: 320, height: 190)
        let center = TutorialSpotlightLayout.cardPosition(
            focusFrame: CGRect(x: 640, y: 440, width: 44, height: 44),
            overlaySize: size, contentBounds: content
        )
        let card = CGRect(x: center.x - 160, y: center.y - 95, width: 320, height: 190)
        XCTAssertTrue(content.contains(card))
        XCTAssertLessThanOrEqual(card.maxX, content.maxX - 16)
        XCTAssertLessThanOrEqual(card.maxY, content.maxY - 24)
    }

    func testBottomTargetPlacesCardAbove() {
        let center = TutorialSpotlightLayout.cardPosition(
            focusFrame: CGRect(x: 300, y: 700, width: 48, height: 48),
            overlaySize: CGSize(width: 320, height: 200),
            contentBounds: CGRect(x: 0, y: 60, width: 390, height: 700)
        )
        XCTAssertEqual(center.y + 100, 700 - 24)
    }

    func testTopTargetPlacesCardBelow() {
        let center = TutorialSpotlightLayout.cardPosition(
            focusFrame: CGRect(x: 20, y: 65, width: 44, height: 44),
            overlaySize: CGSize(width: 320, height: 200),
            contentBounds: CGRect(x: 0, y: 60, width: 390, height: 700)
        )
        XCTAssertEqual(center.y - 100, 109 + 24)
    }

    func testDirectionalInsetsMirrorForRightToLeft() {
        let rect = TutorialSpotlightLayout.contentBounds(
            safeBounds: CGRect(x: 0, y: 0, width: 700, height: 500),
            insets: EdgeInsets(top: 10, leading: 20, bottom: 30, trailing: 80),
            layoutDirection: .rightToLeft
        )
        XCTAssertEqual(rect, CGRect(x: 80, y: 10, width: 600, height: 460))
    }

    func testExcessiveInsetsNeverProduceNegativeSizesOrNonfinitePositions() {
        let rect = TutorialSpotlightLayout.contentBounds(
            safeBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            insets: EdgeInsets(top: 200, leading: 200, bottom: 200, trailing: 200),
            layoutDirection: .leftToRight
        )
        XCTAssertEqual(rect.size, .zero)
        let center = TutorialSpotlightLayout.cardPosition(
            focusFrame: .zero, overlaySize: CGSize(width: 320, height: 900), contentBounds: rect
        )
        XCTAssertTrue(center.x.isFinite && center.y.isFinite)
    }

    func testNavigationSkipsUnavailableTargetsAndEndsAtNil() {
        let configuration = TutorialSpotlightConfiguration(
            orderedIDs: [0, 1, 2], spotlightPadding: 8, spotlightShape: .circle,
            animationDuration: 0.25, dimmingOpacity: 0.58, spotlightEdgeBlurRadius: 0,
            overlayContentInsets: EdgeInsets()
        )
        let targets = [0: TutorialSpotlightResolvedTarget(frame: .zero, spotlightShape: nil),
                       2: TutorialSpotlightResolvedTarget(frame: .zero, spotlightShape: nil)]
        XCTAssertEqual(configuration.nextSelection(from: 0, targets: targets), 2)
        XCTAssertEqual(configuration.previousSelection(from: 2, targets: targets), 0)
        XCTAssertNil(configuration.nextSelection(from: 2, targets: targets))
        XCTAssertNil(configuration.previousSelection(from: 0, targets: targets))
    }
}
