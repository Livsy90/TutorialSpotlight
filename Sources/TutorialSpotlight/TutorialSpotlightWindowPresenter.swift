import SwiftUI
import UIKit

/// The invisible UIKit view has exactly the GeometryReader's coordinate space.
/// Its actual window identifies the scene, without global/key-window lookups.
struct TutorialSpotlightWindowPresenter<ID: Hashable, Overlay: View>: UIViewRepresentable {
    @Binding var selection: ID?
    // Read the value in the SwiftUI container, so changing a plain @State binding
    // invalidates this presenter. Deferred UIKit callbacks cannot track that read.
    let selectedID: ID?
    let targets: [ID: TutorialSpotlightResolvedTarget]
    let configuration: TutorialSpotlightConfiguration<ID>
    let environment: EnvironmentValues
    let overlay: (ID, TutorialSpotlightActions) -> Overlay

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> TutorialSpotlightWindowAnchorView {
        let view = TutorialSpotlightWindowAnchorView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.onLayout = { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.scheduleUpdate(from: view)
        }
        return view
    }

    func updateUIView(_ view: TutorialSpotlightWindowAnchorView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.needsContentUpdate = true
        context.coordinator.scheduleUpdate(from: view)
    }

    static func dismantleUIView(_ view: TutorialSpotlightWindowAnchorView, coordinator: Coordinator) {
        view.onLayout = nil
        coordinator.isDismantled = true
        coordinator.dismiss()
    }

    @MainActor
    final class Coordinator {
        var parent: TutorialSpotlightWindowPresenter
        var needsContentUpdate = true
        var isDismantled = false
        private var updateScheduled = false
        private var window: UIWindow?
        private var host: TutorialSpotlightHostingController?
        private var backgroundObserver: NSObjectProtocol?
        private var disconnectObserver: NSObjectProtocol?
        private var lastFrames: [ID: CGRect] = [:]
        private var lastBounds: CGRect = .zero
        private var lastSafeBounds: CGRect = .zero
        private var lastSelection: ID?

        init(parent: TutorialSpotlightWindowPresenter) { self.parent = parent }

        func scheduleUpdate(from view: UIView) {
            guard !isDismantled, !updateScheduled else { return }
            updateScheduled = true
            // UIKit/SwiftUI layout callbacks must not mutate the hosting tree
            // synchronously, and multiple layout updates can be coalesced.
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self else { return }
                self.updateScheduled = false
                guard !self.isDismantled, let view else { return }
                self.update(from: view)
            }
        }

        private func update(from sourceView: UIView) {
            guard let selected = parent.selectedID,
                  parent.targets[selected] != nil,
                  let sourceWindow = sourceView.window,
                  let scene = sourceWindow.windowScene,
                  scene.activationState != .background,
                  scene.activationState != .unattached else {
                dismiss()
                return
            }

            if window?.windowScene !== scene {
                dismiss()
                // End editing only in the source window. The tutorial must not
                // leave its card behind the source keyboard or affect other scenes.
                sourceWindow.endEditing(true)
                let host = TutorialSpotlightHostingController(rootView: AnyView(EmptyView()))
                host.sourceController = sourceWindow.rootViewController
                if #available(iOS 16.4, *) {
                    // UIKit still supplies window safe insets for card placement;
                    // the SwiftUI canvas itself must cover the whole window.
                    host.safeAreaRegions = []
                }
                host.view.backgroundColor = .clear
                host.view.accessibilityViewIsModal = true
                host.onLayout = { [weak self, weak sourceView] in
                    guard let sourceView else { return }
                    self?.scheduleUpdate(from: sourceView)
                }
                let window = UIWindow(windowScene: scene)
                window.backgroundColor = .clear
                window.windowLevel = UIWindow.Level(rawValue: sourceWindow.windowLevel.rawValue + 1)
                window.rootViewController = host
                self.window = window
                self.host = host
                observeLifecycle(of: scene)
                needsContentUpdate = true
            }
            guard let window, let host else { return }
            if window.frame != scene.coordinateSpace.bounds {
                window.frame = scene.coordinateSpace.bounds
            }
            if host.view.frame != window.bounds {
                host.view.frame = window.bounds
            }
            host.view.layoutIfNeeded()

            let targets = parent.targets.mapValues {
                TutorialSpotlightResolvedTarget(
                    frame: host.view.convert(
                        sourceWindow.convert(sourceView.convert($0.frame, to: sourceWindow), to: window),
                        from: window
                    ),
                    spotlightShape: $0.spotlightShape
                )
            }
            let frames = targets.mapValues(\.frame)
            let bounds = host.view.bounds
            let safeBounds = bounds.inset(by: window.safeAreaInsets)
            guard needsContentUpdate || frames != lastFrames || bounds != lastBounds || safeBounds != lastSafeBounds else {
                return
            }
            let selectionChanged = selected != lastSelection
            needsContentUpdate = false
            lastFrames = frames
            lastBounds = bounds
            lastSafeBounds = safeBounds
            lastSelection = selected
            let parent = parent
            host.rootView = AnyView(
                // A flexible root anchors the canvas at (0, 0), including on
                // older systems where UIHostingController.safeAreaRegions is absent.
                GeometryReader { _ in
                    TutorialSpotlightOverlayView(
                        selection: parent.$selection,
                        targets: targets,
                        configuration: parent.configuration,
                        containerBounds: bounds,
                        safeBounds: safeBounds,
                        overlay: parent.overlay
                    )
                }
                .environment(\.colorScheme, parent.environment.colorScheme)
                .environment(\.dynamicTypeSize, parent.environment.dynamicTypeSize)
                .environment(\.locale, parent.environment.locale)
                .environment(\.layoutDirection, parent.environment.layoutDirection)
                .environment(\.legibilityWeight, parent.environment.legibilityWeight)
                .environment(\.font, parent.environment.font)
                .ignoresSafeArea()
            )
            // The source window remains key; the overlay never takes key status.
            window.isHidden = false
            if selectionChanged {
                DispatchQueue.main.asyncAfter(deadline: .now() + parent.configuration.animationDuration) { [weak host] in
                    guard let host, host.view.window != nil else { return }
                    UIAccessibility.post(notification: .screenChanged, argument: host.view)
                }
            }
        }

        private func observeLifecycle(of scene: UIWindowScene) {
            let center = NotificationCenter.default
            let close: @Sendable (Notification) -> Void = { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.parent.selection = nil
                    self?.dismiss()
                }
            }
            backgroundObserver = center.addObserver(
                forName: UIScene.didEnterBackgroundNotification, object: scene, queue: .main, using: close
            )
            disconnectObserver = center.addObserver(
                forName: UIScene.didDisconnectNotification, object: scene, queue: .main, using: close
            )
        }

        func dismiss() {
            host?.onLayout = nil
            window?.isHidden = true
            window?.rootViewController = nil
            window = nil
            host = nil
            for observer in [backgroundObserver, disconnectObserver].compactMap({ $0 }) {
                NotificationCenter.default.removeObserver(observer)
            }
            backgroundObserver = nil
            disconnectObserver = nil
            lastFrames = [:]
            lastBounds = .zero
            lastSafeBounds = .zero
            lastSelection = nil
        }
    }
}

final class TutorialSpotlightWindowAnchorView: UIView {
    var onLayout: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onLayout?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

private final class TutorialSpotlightHostingController: UIHostingController<AnyView> {
    weak var sourceController: UIViewController?
    var onLayout: (() -> Void)?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        sourceController?.supportedInterfaceOrientations ?? .all
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?()
    }
}
