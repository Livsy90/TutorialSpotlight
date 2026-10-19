import SwiftUI
import UIKit
import XCTest
@testable import TutorialSpotlight

/// These integration tests need an app-hosted test runner with a foreground scene.
/// The pure layout tests also run in an unhosted Swift package test runner.
@MainActor
final class TutorialSpotlightWindowTests: XCTestCase {
    func testWindowTracksSourceScenePreservesKeyAndReleasesOnDismiss() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.model.selection = .first
        await settle()
        let overlay = try XCTUnwrap(fixture.overlayWindow)
        XCTAssertTrue(overlay.windowScene === fixture.source.windowScene)
        XCTAssertTrue(fixture.source.isKeyWindow)
        XCTAssertFalse(overlay.isKeyWindow)
        XCTAssertTrue(overlay.rootViewController?.view.accessibilityViewIsModal == true)
        XCTAssertEqual(fixture.model.cardLocale, "ru")
        XCTAssertEqual(fixture.model.cardColorScheme, .dark)
        XCTAssertTrue(fixture.model.cardDynamicType == .accessibility3)
        XCTAssertEqual(fixture.model.cardAppearances, 1)

        // Moving the source must update geometry without rebuilding the card's identity.
        fixture.model.targetInset = 100
        await settle()
        XCTAssertEqual(fixture.model.cardAppearances, 1)
        fixture.model.actions?.advance()
        await settle()
        XCTAssertEqual(fixture.model.selection, .last)
        fixture.model.actions?.previous()
        await settle()
        XCTAssertEqual(fixture.model.selection, .first)

        fixture.model.actions?.dismiss()
        await settle()
        XCTAssertNil(fixture.overlayWindow)
        XCTAssertTrue(overlay.isHidden)
        XCTAssertNil(overlay.rootViewController)
        XCTAssertTrue(fixture.source.isKeyWindow)
    }

    func testReplayAndPresenterRemovalReleaseWindow() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        for _ in 0..<3 {
            fixture.model.selection = .first
            await settle()
            weak var overlay = fixture.overlayWindow
            XCTAssertNotNil(overlay)
            XCTAssertEqual(fixture.overlayWindows.count, 1)
            fixture.model.selection = nil
            await settle()
            XCTAssertNil(overlay)
            XCTAssertNil(fixture.overlayWindow)
        }
        fixture.model.selection = .last
        await settle()
        weak var overlay = fixture.overlayWindow
        fixture.model.showsPresenter = false
        await settle()
        XCTAssertNil(overlay)
        XCTAssertNil(fixture.overlayWindow)
    }

    func testSwitchingBetweenInlineAndWindowPreservesSelectionAndCleansUp() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.model.presentation = .inline
        fixture.model.selection = .first
        await settle()
        XCTAssertNil(fixture.overlayWindow)
        XCTAssertNotNil(fixture.model.actions)
        fixture.model.actions?.advance()
        await settle()
        XCTAssertEqual(fixture.model.selection, .last)

        fixture.model.presentation = .window
        await settle()
        weak var overlay = fixture.overlayWindow
        XCTAssertNotNil(overlay)
        fixture.model.presentation = .inline
        await settle()
        XCTAssertNil(overlay)
        XCTAssertEqual(fixture.model.selection, .last)
        XCTAssertTrue(fixture.source.isKeyWindow)
    }

    func testMaskCoversWindowAndCutoutMatchesSourceCoordinates() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.model.selection = .last
        await settle()
        let overlay = try XCTUnwrap(fixture.overlayWindow)
        let target = try XCTUnwrap(fixture.model.targetView)
        let sourceFrame = target.convert(target.bounds, to: fixture.source)
        let focusFrame = fixture.source.convert(sourceFrame, to: overlay)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(bounds: overlay.bounds, format: format).image { _ in
            overlay.drawHierarchy(in: overlay.bounds, afterScreenUpdates: true)
        }
        // A misplaced hosting root used to leave the trailing/bottom window edges
        // uncovered and shift the hole by half the source view's safe-area insets.
        let corner = CGPoint(x: overlay.bounds.maxX - 2, y: overlay.bounds.maxY - 2)
        XCTAssertGreaterThan(try alpha(in: image, at: corner), 100)
        XCTAssertLessThan(try alpha(in: image, at: CGPoint(x: focusFrame.midX, y: focusFrame.midY)), 20)
    }

    private func alpha(in image: UIImage, at point: CGPoint) throws -> UInt8 {
        let source = try XCTUnwrap(image.cgImage)
        let pixel = try XCTUnwrap(source.cropping(to: CGRect(x: point.x.rounded(.down), y: point.y.rounded(.down), width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes[3]
    }

    func testBackgroundingSourceSceneClearsSelection() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        fixture.model.selection = .first
        await settle()
        weak var overlay = fixture.overlayWindow
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: fixture.source.windowScene)
        await settle()
        XCTAssertNil(fixture.model.selection)
        XCTAssertNil(overlay)
    }

    func testPresentationDismissesSourceKeyboardWithoutTakingKeyStatus() async throws {
        let fixture = try Fixture { $0.showsTextField = true }
        defer { fixture.close() }
        await settle()
        let field = try XCTUnwrap(fixture.model.textField)
        XCTAssertTrue(field.becomeFirstResponder())
        await settle()
        XCTAssertTrue(field.isFirstResponder)
        let sourceView = try XCTUnwrap(fixture.source.rootViewController?.view)
        let keyboardWasVisible = sourceView.keyboardLayoutGuide.layoutFrame.height > 100

        fixture.model.selection = .first
        await settle()
        XCTAssertNotNil(fixture.overlayWindow)
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertTrue(fixture.source.isKeyWindow)
        if keyboardWasVisible {
            XCTAssertLessThan(sourceView.keyboardLayoutGuide.layoutFrame.height, 100)
        }
    }

    func testLongCardsStartAtTopWhenMovingForwardAndBackInBothModes() async throws {
        for presentation in [TutorialSpotlightPresentation.inline, .window] {
            let fixture = try Fixture {
                $0.usesLongCard = true
                $0.presentation = presentation
            }
            fixture.model.selection = .first
            await settle()
            let window = fixture.overlayWindow ?? fixture.source
            let firstScroll = try XCTUnwrap(findVerticalScroll(in: window))
            firstScroll.setContentOffset(CGPoint(x: 0, y: 250), animated: false)
            XCTAssertEqual(firstScroll.contentOffset.y, 250, accuracy: 1)
            fixture.model.actions?.advance()
            await settle()
            XCTAssertEqual(fixture.model.selection, .last)
            let nextScroll = try XCTUnwrap(findVerticalScroll(in: window))
            XCTAssertEqual(nextScroll.contentOffset.y, -nextScroll.adjustedContentInset.top, accuracy: 1)

            nextScroll.setContentOffset(CGPoint(x: 0, y: 250), animated: false)
            fixture.model.actions?.previous()
            await settle()
            XCTAssertEqual(fixture.model.selection, .first)
            let previousScroll = try XCTUnwrap(findVerticalScroll(in: window))
            XCTAssertEqual(previousScroll.contentOffset.y, -previousScroll.adjustedContentInset.top, accuracy: 1)
            fixture.close()
        }
    }

    private func findVerticalScroll(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height + 1 {
            return scroll
        }
        for child in view.subviews {
            if let scroll = findVerticalScroll(in: child) { return scroll }
        }
        return nil
    }

    private func settle() async { try? await Task.sleep(nanoseconds: 500_000_000) }

    @MainActor
    private final class Fixture {
        let model = WindowTestModel()
        let source: UIWindow
        private weak var originalKey: UIWindow?

        init(configure: (WindowTestModel) -> Void = { _ in }) throws {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else {
                throw XCTSkip("Requires an app-hosted test runner with a UIWindowScene")
            }
            originalKey = scene.windows.first(where: \.isKeyWindow)
            configure(model)
            source = UIWindow(windowScene: scene)
            source.frame = scene.coordinateSpace.bounds
            source.rootViewController = UIHostingController(rootView: WindowTestView(model: model))
            source.makeKeyAndVisible()
        }

        var overlayWindows: [UIWindow] {
            source.windowScene?.windows.filter {
                !$0.isHidden && $0.windowLevel > source.windowLevel && $0.rootViewController is UIHostingController<AnyView>
            } ?? []
        }
        var overlayWindow: UIWindow? { overlayWindows.first }
        func close() {
            source.isHidden = true
            source.rootViewController = nil
            originalKey?.makeKey()
        }
    }
}

private enum WindowTestStep: Hashable, CaseIterable { case first, last }

@MainActor
private final class WindowTestModel: ObservableObject {
    @Published var selection: WindowTestStep?
    @Published var showsPresenter = true
    @Published var presentation: TutorialSpotlightPresentation = .window
    @Published var targetInset: CGFloat = 0
    var actions: TutorialSpotlightActions?
    var cardLocale: String?
    var cardColorScheme: ColorScheme?
    var cardDynamicType: DynamicTypeSize?
    var cardAppearances = 0
    var usesLongCard = false
    var showsTextField = false
    weak var textField: UITextField?
    weak var targetView: UIView?
}

private struct WindowTestView: View {
    @ObservedObject var model: WindowTestModel
    var body: some View {
        TabView {
            if model.showsPresenter {
                NavigationView {
                    VStack {
                        if model.showsTextField {
                            WindowTestTextField(model: model).frame(height: 44)
                        }
                        Text("Calendar").padding().tutorialSpotlightSource(id: WindowTestStep.first)
                        Spacer()
                        HStack {
                            Spacer()
                            Button("+") {}.padding().background(.blue, in: Circle())
                                .background { WindowTestTargetProbe(model: model) }
                                .tutorialSpotlightSource(id: WindowTestStep.last, spotlightShape: .circle)
                        }
                        .padding(.trailing, model.targetInset)
                    }
                    .padding()
                    .navigationTitle("Tracker")
                }
                .navigationViewStyle(.stack)
                .tutorialSpotlight(
                    selection: $model.selection,
                    orderedIDs: WindowTestStep.allCases,
                    animationDuration: 0.01,
                    presentation: model.presentation
                ) { step, actions in
                    WindowTestCard(model: model, step: step, actions: actions)
                }
                .environment(\.locale, Locale(identifier: "ru"))
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, .accessibility3)
                .tabItem { Label("Tracker", systemImage: "checklist") }
            } else {
                Text("Presenter removed").tabItem { Label("Tracker", systemImage: "checklist") }
            }
            Text("Settings").tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

private struct WindowTestCard: View {
    let model: WindowTestModel
    let step: WindowTestStep
    let actions: TutorialSpotlightActions
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicType
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step == .first ? "Track Your Progress" : "Add a Tracker").font(.headline)
            Text("Create a new habit, activity, or goal to track.")
            if model.usesLongCard {
                ForEach(0..<30) { row in
                    Text("Instruction line \(row)")
                }
            }
            HStack {
                Button("Cancel", action: actions.dismiss)
                Spacer()
                Button("Back", action: actions.previous)
                Button("Next", action: actions.advance)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .onAppear {
            model.cardAppearances += 1
            record(actions)
        }
        .onChange(of: step) { _ in record(actions) }
    }
    private func record(_ actions: TutorialSpotlightActions) {
        model.actions = actions
        model.cardLocale = locale.identifier
        model.cardColorScheme = colorScheme
        model.cardDynamicType = dynamicType
    }
}

private struct WindowTestTargetProbe: UIViewRepresentable {
    let model: WindowTestModel
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        model.targetView = view
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {}
}

private struct WindowTestTextField: UIViewRepresentable {
    let model: WindowTestModel
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "Enter text"
        field.borderStyle = .roundedRect
        model.textField = field
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {}
}
