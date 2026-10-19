import SwiftUI
import UIKit
import XCTest
@testable import TutorialSpotlight

/// Use plain @State rather than ObservableObject: objectWillChange would
/// redraw the parent and hide missing selection dependencies in the presenter.
@MainActor
final class TutorialSpotlightStateBindingTests: XCTestCase {
    func testStateOnlySelectionPresentsNavigatesDismissesAndReplaysWithoutNewLayout() async throws {
        let fixture = try Fixture(startsOnAppear: false)
        defer { fixture.close() }
        await settle()
        XCTAssertNil(fixture.overlay)

        let start = try XCTUnwrap(fixture.trigger.start)
        start()
        await settle()
        XCTAssertNotNil(fixture.overlay)
        XCTAssertEqual(fixture.trigger.visibleStep, .first)
        fixture.trigger.actions?.advance()
        await settle()
        XCTAssertEqual(fixture.trigger.visibleStep, .last)
        fixture.trigger.actions?.previous()
        await settle()
        XCTAssertEqual(fixture.trigger.visibleStep, .first)

        // Closing via the source @State must release the window too.
        weak var firstWindow = fixture.overlay
        let stop = try XCTUnwrap(fixture.trigger.stop)
        stop()
        await settle()
        XCTAssertNil(firstWindow)
        XCTAssertNil(fixture.overlay)

        start()
        await settle()
        XCTAssertNotNil(fixture.overlay)
        weak var replayWindow = fixture.overlay
        fixture.trigger.actions?.dismiss()
        await settle()
        XCTAssertNil(replayWindow)
        XCTAssertTrue(fixture.source.isKeyWindow)
    }

    func testStateSetOnFirstAppearanceShowsWindowWithoutReappearing() async throws {
        let fixture = try Fixture(startsOnAppear: true)
        defer { fixture.close() }
        await settle()
        XCTAssertNotNil(fixture.overlay)
        XCTAssertEqual(fixture.trigger.visibleStep, .first)
        XCTAssertTrue(fixture.source.isKeyWindow)
    }

    private func settle() async { try? await Task.sleep(nanoseconds: 500_000_000) }

    @MainActor
    private final class Fixture {
        let trigger = StateBindingTrigger()
        let source: UIWindow
        private weak var originalKey: UIWindow?

        init(startsOnAppear: Bool) throws {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else {
                throw XCTSkip("Requires an app-hosted test runner with a UIWindowScene")
            }
            originalKey = scene.windows.first(where: \.isKeyWindow)
            source = UIWindow(windowScene: scene)
            source.frame = scene.coordinateSpace.bounds
            source.rootViewController = UIHostingController(rootView: StateBindingTutorialView(
                trigger: trigger, startsOnAppear: startsOnAppear
            ))
            source.makeKeyAndVisible()
        }

        var overlay: UIWindow? {
            source.windowScene?.windows.first {
                !$0.isHidden && $0.windowLevel > source.windowLevel && $0.rootViewController is UIHostingController<AnyView>
            }
        }

        func close() {
            source.isHidden = true
            source.rootViewController = nil
            originalKey?.makeKey()
        }
    }
}

private enum StateBindingStep: Hashable, CaseIterable { case first, last }

@MainActor
private final class StateBindingTrigger {
    var start: (() -> Void)?
    var stop: (() -> Void)?
    var actions: TutorialSpotlightActions?
    var visibleStep: StateBindingStep?
}

private struct StateBindingTutorialView: View {
    let trigger: StateBindingTrigger
    let startsOnAppear: Bool
    @State private var selection: StateBindingStep?

    var body: some View {
        VStack {
            Text("First target").padding().tutorialSpotlightSource(id: StateBindingStep.first)
            Spacer()
            Text("Last target").padding().tutorialSpotlightSource(id: StateBindingStep.last)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tutorialSpotlight(
            selection: $selection, orderedIDs: StateBindingStep.allCases,
            animationDuration: 0.01, presentation: .window
        ) { step, actions in
            VStack {
                Text(step == .first ? "First hint" : "Last hint")
                Button("Next", action: actions.advance)
            }
            .padding()
            .background(.white)
            .onAppear {
                trigger.visibleStep = step
                trigger.actions = actions
            }
        }
        .onAppear {
            trigger.start = { selection = .first }
            trigger.stop = { selection = nil }
            if startsOnAppear { selection = .first }
        }
    }
}
