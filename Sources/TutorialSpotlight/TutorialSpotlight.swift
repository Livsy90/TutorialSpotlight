import SwiftUI

public extension View {
    /// Applies an onboarding spotlight overlay to a common parent view.
    ///
    /// Mark focusable elements with `tutorialSpotlightSource(id:)`.
    func tutorialSpotlight<ID: Hashable, Overlay: View>(
        selection: Binding<ID?>,
        orderedIDs: [ID],
        spotlightPadding: CGFloat = 8,
        cornerRadius: CGFloat,
        animationDuration: TimeInterval = 0.25,
        dimmingOpacity: CGFloat = 0.58,
        spotlightEdgeBlurRadius: CGFloat = 0,
        @ViewBuilder overlay: @escaping (_ id: ID, _ actions: TutorialSpotlightActions) -> Overlay
    ) -> some View {
        tutorialSpotlight(
            selection: selection,
            orderedIDs: orderedIDs,
            spotlightPadding: spotlightPadding,
            spotlightShape: .rect(cornerRadius: cornerRadius),
            animationDuration: animationDuration,
            dimmingOpacity: dimmingOpacity,
            spotlightEdgeBlurRadius: spotlightEdgeBlurRadius,
            overlay: overlay
        )
    }

    /// Applies an onboarding spotlight overlay using a custom spotlight shape.
    ///
    /// Mark focusable elements with `tutorialSpotlightSource(id:)`.
    func tutorialSpotlight<ID: Hashable, Overlay: View>(
        selection: Binding<ID?>,
        orderedIDs: [ID],
        spotlightPadding: CGFloat = 8,
        spotlightShape: TutorialSpotlightShape = .rect(cornerRadius: 28),
        animationDuration: TimeInterval = 0.25,
        dimmingOpacity: CGFloat = 0.58,
        spotlightEdgeBlurRadius: CGFloat = 0,
        @ViewBuilder overlay: @escaping (_ id: ID, _ actions: TutorialSpotlightActions) -> Overlay
    ) -> some View {
        modifier(
            TutorialSpotlightContainerModifier(
                selection: selection,
                configuration: .init(
                    orderedIDs: orderedIDs,
                    spotlightPadding: spotlightPadding,
                    spotlightShape: spotlightShape,
                    animationDuration: animationDuration,
                    dimmingOpacity: dimmingOpacity,
                    spotlightEdgeBlurRadius: spotlightEdgeBlurRadius
                ),
                overlay: overlay
            )
        )
    }
    
    /// Marks a view as a spotlight target.
    func tutorialSpotlightSource<ID: Hashable>(id: ID) -> some View {
        modifier(TutorialSpotlightSourceModifier(id: id, spotlightShape: nil))
    }
    
    func tutorialSpotlightSourceContainer<ID: Hashable>(id: ID) -> some View {
        modifier(TutorialSpotlightSourceContainerModifier(id: id, spotlightShape: nil))
    }
    
    /// Marks a view as a spotlight target and overrides the spotlight shape for that target.
    func tutorialSpotlightSource<ID: Hashable>(
        id: ID,
        spotlightShape: TutorialSpotlightShape
    ) -> some View {
        modifier(
            TutorialSpotlightSourceModifier(
                id: id,
                spotlightShape: spotlightShape
            )
        )
    }
}

public struct TutorialSpotlightShape: Shape {
    private let makePath: @Sendable (CGRect) -> Path

    public init<S: Shape>(_ shape: S) {
        makePath = { rect in
            shape.path(in: rect)
        }
    }

    public func path(in rect: CGRect) -> Path {
        makePath(rect)
    }

    public static func rect(
        cornerRadius: CGFloat,
        style: RoundedCornerStyle = .continuous
    ) -> TutorialSpotlightShape {
        TutorialSpotlightShape(
            .rect(cornerRadius: cornerRadius, style: style)
        )
    }
    
    public static var rect: TutorialSpotlightShape {
        TutorialSpotlightShape(
            .rect
        )
    }

    public static var circle: TutorialSpotlightShape {
        TutorialSpotlightShape(.circle)
    }

    public static var capsule: TutorialSpotlightShape {
        TutorialSpotlightShape(.capsule)
    }
}

public struct TutorialSpotlightActions {
    /// Closes the spotlight flow and removes the overlay.
    public let dismiss: () -> Void

    /// Moves to the previous available spotlight item from `orderedIDs`.
    public let previous: () -> Void

    /// Advances to the next available spotlight item from `orderedIDs`.
    public let advance: () -> Void
}

private struct TutorialSpotlightConfiguration<ID: Hashable> {
    typealias Preferences = TutorialSpotlightPreferenceKey<ID>.Value

    let orderedIDs: [ID]
    let spotlightPadding: CGFloat
    let spotlightShape: TutorialSpotlightShape
    let animationDuration: TimeInterval
    let dimmingOpacity: CGFloat
    let spotlightEdgeBlurRadius: CGFloat

    let horizontalPadding: CGFloat = 16
    let verticalSpacing: CGFloat = 24
    let verticalPadding: CGFloat = 24

    func previousSelection(from selected: ID, preferences: Preferences) -> ID? {
        adjacentSelection(from: selected, preferences: preferences, direction: .backward)
    }

    func nextSelection(from selected: ID, preferences: Preferences) -> ID? {
        adjacentSelection(from: selected, preferences: preferences, direction: .forward)
    }

    private func adjacentSelection(
        from selected: ID,
        preferences: Preferences,
        direction: TutorialSpotlightDirection
    ) -> ID? {
        guard !orderedIDs.isEmpty, let startIndex = orderedIDs.firstIndex(of: selected) else {
            return nil
        }

        var index = startIndex
        
        while let nextIndex = nextIndex(after: index, direction: direction) {
            index = nextIndex
            let candidate = orderedIDs[index]

            if preferences[candidate] != nil {
                return candidate
            }
        }

        return nil
    }

    private func nextIndex(after index: Int, direction: TutorialSpotlightDirection) -> Int? {
        switch direction {
        case .forward:
            let nextIndex = orderedIDs.index(after: index)
            return nextIndex == orderedIDs.endIndex ? nil : nextIndex
        case .backward:
            return index == orderedIDs.startIndex ? nil : orderedIDs.index(before: index)
        }
    }
}

private enum TutorialSpotlightDirection {
    case forward
    case backward
}

private struct TutorialSpotlightSourceModifier<ID: Hashable>: ViewModifier {
    let id: ID
    let spotlightShape: TutorialSpotlightShape?

    func body(content: Content) -> some View {
        // Store the view bounds as an anchor so the container modifier can later
        // resolve the highlighted frame inside its own geometry context.
        content.anchorPreference(
            key: TutorialSpotlightPreferenceKey<ID>.self,
            value: .bounds
        ) { anchor in
            [
                id: .init(
                    anchor: anchor,
                    spotlightShape: spotlightShape
                )
            ]
        }
    }
}

private struct TutorialSpotlightSourceContainerModifier<ID: Hashable>: ViewModifier {
    let id: ID
    let spotlightShape: TutorialSpotlightShape?
    
    func body(content: Content) -> some View {
        content
            .transformAnchorPreference(
                key: TutorialSpotlightPreferenceKey<ID>.self,
                value: .bounds,
                transform: {$0[id] = .init(
                    anchor: $1,
                    spotlightShape: spotlightShape
                )}
            )
    }
}

private struct TutorialSpotlightContainerModifier<ID: Hashable, Overlay: View>: ViewModifier {
    @Binding var selection: ID?

    let configuration: TutorialSpotlightConfiguration<ID>
    let overlay: (ID, TutorialSpotlightActions) -> Overlay

    // This is the animated spotlight frame currently shown on screen.
    // It allows the cutout and border to move smoothly between targets.
    @State private var currentFrame: CGRect?

    // The overlay card is measured during layout so its position can be computed
    // from its actual rendered size rather than hardcoded dimensions.
    @State private var overlaySize: CGSize = .zero

    // The help overlay fades in after the spotlight settles to avoid jumpy motion
    // while the scroll view or target frame is still updating.
    @State private var overlayOpacity: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack {
            content
            // The content marks spotlight targets inside a named coordinate space.
            // That gives us a stable local frame for every registered anchor.
                .coordinateSpace(name: TutorialSpotlightCoordinateSpace.name)
        }
        // Read all registered spotlight source anchors and build the fullscreen overlay
        // on top of the original content.
        .overlayPreferenceValue(TutorialSpotlightPreferenceKey<ID>.self) { preferences in
            GeometryReader { proxy in
                ZStack {
                    Color.clear
                    
                    overlayContent(preferences: preferences, proxy: proxy)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    @ViewBuilder
    private func overlayContent(
        preferences: TutorialSpotlightPreferenceKey<ID>.Value,
        proxy: GeometryProxy
    ) -> some View {
        if let selected = selection, let target = preferences[selected] {
            // Resolve the selected anchor inside the container coordinate space.
            let targetFrame = proxy[target.anchor]
            let focusFrame = targetFrame.insetBy(
                dx: -configuration.spotlightPadding,
                dy: -configuration.spotlightPadding
            )

            // During the very first frame there is nothing to animate from, so use the
            // resolved frame immediately. After that we animate via `currentFrame`.
            let displayedFocusFrame = currentFrame ?? focusFrame

            // Expose imperative actions to the overlay content so it can either dismiss
            // the tutorial or advance through the ordered spotlight sequence.
            let actions = TutorialSpotlightActions(
                dismiss: {
                    withAnimation(.easeInOut(duration: configuration.animationDuration)) {
                        selection = nil
                    }
                },
                previous: {
                    updateSelection(
                        configuration.previousSelection(from: selected, preferences: preferences)
                    )
                },
                advance: {
                    updateSelection(
                        configuration.nextSelection(from: selected, preferences: preferences)
                    )
                }
            )

            let safeAreaInsets = proxy.safeAreaInsets
            let containerBounds = proxy.tutorialSpotlightContainerBounds
            let overlayFocusFrame = displayedFocusFrame.offsetBy(
                dx: safeAreaInsets.leading,
                dy: safeAreaInsets.top
            )
            
            ZStack(alignment: .topLeading) {
                // Draw a fullscreen dimming layer and punch out the spotlight region.
                // An optional blur softens the cutout edge for a flashlight effect.
                spotlightMask(
                    focusFrame: overlayFocusFrame,
                    spotlightShape: target.spotlightShape ?? configuration.spotlightShape
                )
                .onTapGesture { actions.dismiss() }
                
                // Render the caller-provided overlay card and measure it in the same
                // pass so we can place it above or below the spotlight accurately.
                overlay(selected, actions)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                    .opacity(overlayOpacity)
                    .frame(
                        maxWidth: min(
                            320,
                            containerBounds.width - (configuration.horizontalPadding * 2)
                        )
                    )
                    .background {
                        GeometryReader { overlayProxy in
                            Color.clear
                                .preference(
                                    key: TutorialSpotlightOverlaySizePreferenceKey.self,
                                    value: overlayProxy.size
                                )
                        }
                    }
                    .position(
                        overlayPosition(
                            for: overlayFocusFrame,
                            overlaySize: overlaySize,
                            in: containerBounds
                        )
                    )
                    .animation(nil, value: currentFrame)
                    .animation(nil, value: overlaySize)
                    .task(id: selected) {
                        await showOverlayWithDelay()
                    }
            }
            .frame(width: containerBounds.width, height: containerBounds.height)
            .offset(x: -safeAreaInsets.leading, y: -safeAreaInsets.top)
            .onAppear {
                // Initialize the animated frame when the overlay becomes visible.
                currentFrame = focusFrame
            }
            .onChange(of: focusFrame) { newValue in
                // Follow target movement, for example while scrolling or switching steps.
                currentFrame = newValue
            }
            .onPreferenceChange(TutorialSpotlightOverlaySizePreferenceKey.self) { newValue in
                overlaySize = newValue
            }
            // Animate target transitions and late size updates for a smoother presentation.
            .animation(.easeInOut(duration: configuration.animationDuration), value: selection)
            .animation(.easeInOut(duration: configuration.animationDuration), value: currentFrame)
            .animation(.easeInOut(duration: configuration.animationDuration), value: overlaySize)
            .onDisappear {
                currentFrame = nil
                overlaySize = .zero
                overlayOpacity = 0
            }
        } else {
            EmptyView()
        }
    }
    
    private func overlayPosition(
        for focusFrame: CGRect,
        overlaySize: CGSize,
        in container: CGRect
    ) -> CGPoint {
        // Keep a consistent margin around the overlay so it never touches screen edges.
        // Cap the overlay width to a readable maximum while still respecting
        // the available horizontal space inside the container.
        let maxOverlayWidth = min(320, container.width - (configuration.horizontalPadding * 2))

        // Use the measured overlay size when available. Fallback values are used
        // during the first layout pass, before SwiftUI reports the actual size.
        let measuredWidth = overlaySize.width > 0 ? overlaySize.width : maxOverlayWidth
        let measuredHeight = overlaySize.height > 0 ? overlaySize.height : 180
        let overlayWidth = min(measuredWidth, maxOverlayWidth)

        // Try to align the overlay horizontally with the highlighted target,
        // then clamp the center point so the card stays fully visible on screen.
        let centeredX = min(
            max(focusFrame.midX, container.minX + configuration.horizontalPadding + overlayWidth / 2),
            container.maxX - configuration.horizontalPadding - overlayWidth / 2
        )

        // The preferred placement is below the spotlight. We compute the Y center
        // by taking the target's bottom edge, adding vertical spacing, and then
        // shifting by half of the overlay height because `.position` works from center.
        let preferredBelowY = focusFrame.maxY + configuration.verticalSpacing + measuredHeight / 2

        // If the entire overlay still fits within the bottom safe area margin,
        // keep it below the spotlight because that is the primary visual layout.
        if preferredBelowY + measuredHeight / 2 <= container.maxY - configuration.verticalPadding {
            return CGPoint(x: centeredX, y: preferredBelowY)
        }

        // Otherwise, move the overlay above the spotlight using the same center-based
        // coordinate calculation.
        let preferredAboveY = focusFrame.minY - configuration.verticalSpacing - measuredHeight / 2

        // Clamp the final vertical position so the overlay remains fully inside
        // the visible container even when there is not enough room above either.
        let clampedY = min(
            max(preferredAboveY, container.minY + configuration.verticalPadding + measuredHeight / 2),
            container.maxY - configuration.verticalPadding - measuredHeight / 2
        )
        return CGPoint(x: centeredX, y: clampedY)
    }

    private func updateSelection(_ newSelection: ID?) {
        withAnimation(.easeInOut(duration: configuration.animationDuration)) {
            selection = newSelection
        }
    }

    private var overlayFadeAnimation: Animation {
        .easeInOut(duration: configuration.animationDuration * 1.1)
    }

    private var overlayFadeDelayNanoseconds: UInt64 {
        UInt64(configuration.animationDuration * 1_000_000_000)
    }

    @MainActor
    private func showOverlayWithDelay() async {
        overlayOpacity = 0

        try? await Task.sleep(nanoseconds: overlayFadeDelayNanoseconds)

        guard selection != nil else { return }

        withAnimation(overlayFadeAnimation) {
            overlayOpacity = 1
        }
    }

    private func spotlightMask(
        focusFrame: CGRect,
        spotlightShape: TutorialSpotlightShape
    ) -> some View {
        ZStack {
            Color.black.opacity(configuration.dimmingOpacity)

            spotlightShape
                .frame(width: focusFrame.width, height: focusFrame.height)
                .position(x: focusFrame.midX, y: focusFrame.midY)
                .blur(radius: configuration.spotlightEdgeBlurRadius)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .contentShape(.rect)
    }
}

private struct TutorialSpotlightPreferenceKey<ID: Hashable>: PreferenceKey {
    // Each spotlight source contributes a single anchor keyed by its logical ID.
    typealias Value = [ID: TutorialSpotlightTarget]

    static var defaultValue: Value { [:] }

    static func reduce(value: inout Value, nextValue: () -> Value) {
        // If the same ID appears multiple times, keep the most recent value.
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TutorialSpotlightTarget {
    let anchor: Anchor<CGRect>
    let spotlightShape: TutorialSpotlightShape?
}

private struct TutorialSpotlightOverlaySizePreferenceKey: PreferenceKey {
    // A simple preference channel used to bubble the measured overlay size upward.
    static var defaultValue: CGSize { .zero }
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private enum TutorialSpotlightCoordinateSpace {
    // Shared coordinate space name used by spotlight sources and the container.
    static let name = "tutorialSpotlightCoordinateSpace"
}

private extension GeometryProxy {
    var tutorialSpotlightContainerBounds: CGRect {
        CGRect(
            origin: .zero,
            size: CGSize(
                width: size.width + safeAreaInsets.leading + safeAreaInsets.trailing,
                height: size.height + safeAreaInsets.top + safeAreaInsets.bottom
            )
        )
    }
}

@available(iOS 16.0)
#Preview {
    struct TutorialSpotlightDemo: View {
        // Demo steps used to show how the spotlight moves through multiple targets.
        enum Step: String, CaseIterable {
            case profile
            case filters
            case price
            case checkout
            
            var title: String {
                switch self {
                case .profile: "Profile"
                case .filters: "Filters"
                case .price: "Price"
                case .checkout: "Checkout"
                }
            }
            
            var message: String {
                switch self {
                case .profile: "Here the user quickly gets to their profile and account settings."
                case .filters: "This block manages filters. It's usually the second step in onboarding."
                case .price: "Testing parent-child relationships."
                case .checkout: "The button completes the scenario. The final step may lead to payment or confirmation."
                }
            }
            
            var buttonTitle: String {
                switch self {
                case .checkout: "Finish"
                default: "Next"
                }
            }
        }
        
        enum SheetStep: String, CaseIterable {
            case title
            case action
            
            var title: String {
                switch self {
                case .title: "Sheet Header"
                case .action: "Primary Action"
                }
            }
            
            var message: String {
                switch self {
                case .title: "This title explains the purpose of the modal flow."
                case .action: "This button confirms the choice and closes the scenario."
                }
            }
            
            var buttonTitle: String {
                switch self {
                case .title: "Next"
                case .action: "Done"
                }
            }
        }
        
        // Start the preview with the first onboarding step already selected.
        @State private var selection: Step?
        
        @State private var showSheet: Bool = false
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Travel Planner")
                                .font(.largeTitle.bold())
                            
                            Text("Build a trip, fine-tune filters, and finish booking in a couple of taps.")
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                statCard(title: "12", subtitle: "Routes")
                                statCard(title: "5", subtitle: "Cities")
                                statCard(title: "3", subtitle: "Days")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        filterPanel
                            .tutorialSpotlightSourceContainer(id: Step.filters)
                        
                        Button("Show Sheet") {
                            showSheet.toggle()
                        }
                    }
                    .padding(24)
                }
                .background {
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.95, blue: 0.98),
                            Color(red: 0.88, green: 0.92, blue: 0.97),
                            Color(red: 0.83, green: 0.89, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
                .navigationTitle("Discover")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Register the toolbar button as a spotlight source.
                        profileButton
                            .tutorialSpotlightSource(
                                id: Step.profile,
                                spotlightShape: .circle
                            )
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    // Register the bottom call-to-action as another spotlight source.
                    checkoutButton
                        .tutorialSpotlightSource(id: Step.checkout)
                        .padding()
                }
            }
            .sheet(isPresented: $showSheet) {
                SheetSpotlightDemo()
            }
            // Attach the spotlight container to a common ancestor so it can resolve
            // every registered target and draw one shared overlay above the screen.
            .tutorialSpotlight(
                selection: $selection,
                orderedIDs: Step.allCases,
                spotlightEdgeBlurRadius: 8
            ) { id, actions in
                spotlightCard(for: id, actions: actions)
            }
        }
        
        private var profileButton: some View {
            Button {
                selection = .profile
            } label: {
                Image(systemName: "person.crop.circle.fill")
            }
        }
        
        private var filterPanel: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text("Smart Filters")
                    .font(.headline)
                
                HStack(spacing: 10) {
                    chip("Budget")
                    chip("Family")
                    chip("Food")
                }
                
                HStack(spacing: 14) {
                    filterMetric(title: "Price", value: "$420")
                        .tutorialSpotlightSource(id: Step.price)
                    filterMetric(title: "Rating", value: "4.8")
                    filterMetric(title: "Transit", value: "18 min")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .white.opacity(0.82),
                in: .rect(cornerRadius: 28)
            )
        }
        
        private var checkoutButton: some View {
            Button {
                selection = .checkout
            } label: {
                HStack {
                    Text("Continue")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.indigo, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: 24)
                )
            }
            .buttonStyle(.plain)
        }
        
        private func statCard(
            title: String,
            subtitle: String
        ) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .white.opacity(0.82),
                in: .rect(cornerRadius: 12)
            )
        }
        
        private func chip(_ title: String) -> some View {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.12), in: Capsule())
        }
        
        private func filterMetric(
            title: String,
            value: String
        ) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        private func spotlightCard(
            for step: Step,
            actions: TutorialSpotlightActions
        ) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(step.title)
                    .font(.title3.weight(.bold))
                
                Text(step.message)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Button("Skip") {
                        actions.dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Back") {
                        actions.previous()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button(step.buttonTitle) {
                        actions.advance()
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding(20)
            .background(.white, in: .rect(cornerRadius: 28))
            .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        }
    }

    struct ScrollViewSpotlightDemo: View {
        enum Step: String, CaseIterable {
            case hero
            case inspiration
            case budget
            case itinerary
            case reviews
            case checkout

            var title: String {
                switch self {
                case .hero: "Trip Overview"
                case .inspiration: "Inspiration Picks"
                case .budget: "Budget Controls"
                case .itinerary: "Itinerary Builder"
                case .reviews: "Traveler Reviews"
                case .checkout: "Checkout"
                }
            }

            var message: String {
                switch self {
                case .hero: "Start with a quick overview of the route, weather, and trip length."
                case .inspiration: "These curated cards help the user discover destinations worth opening."
                case .budget: "Adjust cost boundaries before building the final itinerary."
                case .itinerary: "This section groups the day-by-day plan and key activity blocks."
                case .reviews: "Long-form reviews often sit much lower in the screen hierarchy and need scrolling."
                case .checkout: "The sticky bottom action remains accessible after the user finishes reviewing content."
                }
            }

            var buttonTitle: String {
                switch self {
                case .checkout: "Finish"
                default: "Next"
                }
            }

            var scrollAnchor: UnitPoint {
                switch self {
                case .hero, .inspiration:
                    return .top
                case .budget, .itinerary:
                    return .center
                case .reviews:
                    return .bottom
                case .checkout:
                    return .bottom
                }
            }

            var requiresScrolling: Bool {
                self != .checkout
            }
        }

        @State private var selection: Step? = .hero

        var body: some View {
            NavigationStack {
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(spacing: 24) {
                            heroSection
                                .id(Step.hero)
                                .tutorialSpotlightSource(id: Step.hero)

                            inspirationSection
                                .id(Step.inspiration)
                                .tutorialSpotlightSource(id: Step.inspiration)

                            budgetSection
                                .id(Step.budget)
                                .tutorialSpotlightSource(id: Step.budget)

                            itinerarySection
                                .id(Step.itinerary)
                                .tutorialSpotlightSource(id: Step.itinerary)

                            reviewsSection
                                .id(Step.reviews)
                                .tutorialSpotlightSource(id: Step.reviews)
                        }
                        .padding(24)
                    }
                    .background {
                        LinearGradient(
                            colors: [
                                Color(red: 0.97, green: 0.93, blue: 0.88),
                                Color(red: 0.90, green: 0.93, blue: 0.89),
                                Color(red: 0.84, green: 0.90, blue: 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                    }
                    .navigationTitle("Scroll Demo")
                    .navigationBarTitleDisplayMode(.inline)
                    .safeAreaInset(edge: .bottom) {
                        checkoutBar
                            .tutorialSpotlightSource(id: Step.checkout)
                            .padding()
                    }
                    .onAppear {
                        scrollToSelection(using: reader, animated: false)
                    }
                    .onChange(of: selection) { _ in
                        scrollToSelection(using: reader)
                    }
                }
            }
            .tutorialSpotlight(
                selection: $selection,
                orderedIDs: Step.allCases,
                spotlightEdgeBlurRadius: 8
            ) { id, actions in
                spotlightCard(for: id, actions: actions)
            }
        }

        private var heroSection: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text("Northern Escape")
                    .font(.largeTitle.bold())

                Text("A long scrolling demo that automatically reveals the focused step as the tutorial advances.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    scrollStat(title: "7", subtitle: "Days")
                    scrollStat(title: "4", subtitle: "Stops")
                    scrollStat(title: "18", subtitle: "Spots")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var inspirationSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Inspiration Picks")
                    .font(.headline)

                ForEach(0..<3) { index in
                    HStack(alignment: .top, spacing: 14) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill([Color.orange.opacity(0.5), Color.teal.opacity(0.45), Color.indigo.opacity(0.4)][index])
                            .frame(width: 82, height: 82)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(["Copenhagen", "Reykjavik", "Tallinn"][index])
                                .font(.headline)
                            Text("Editorial route suggestion with a short summary and a clear next action.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(.white.opacity(0.8), in: .rect(cornerRadius: 22))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var budgetSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Budget Controls")
                    .font(.headline)

                VStack(spacing: 12) {
                    sliderRow(title: "Flights", value: "$420")
                    sliderRow(title: "Hotels", value: "$760")
                    sliderRow(title: "Food", value: "$220")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.8), in: .rect(cornerRadius: 26))
        }

        private var itinerarySection: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Itinerary Builder")
                    .font(.headline)

                ForEach(0..<4) { day in
                    HStack {
                        Text("Day \(day + 1)")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(["Harbor walk", "Museum route", "Train transfer", "Sauna evening"][day])
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)

                    if day < 3 {
                        Divider()
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.78), in: .rect(cornerRadius: 26))
        }

        private var reviewsSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Traveler Reviews")
                    .font(.headline)

                ForEach(0..<6) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review \(index + 1)")
                            .font(.subheadline.weight(.semibold))
                        Text("A longer text block helps push this spotlight target farther down the scroll view so the demo can prove the automatic scrolling behavior.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.white.opacity(0.74), in: .rect(cornerRadius: 20))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var checkoutBar: some View {
            Button {
                selection = .checkout
            } label: {
                HStack {
                    Text("Reserve Route")
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.mint, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: 24)
                )
            }
            .buttonStyle(.plain)
        }

        private func scrollStat(title: String, subtitle: String) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.72), in: .rect(cornerRadius: 16))
        }

        private func sliderRow(title: String, value: String) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(value)
                        .fontWeight(.semibold)
                }

                Capsule()
                    .fill(.gray.opacity(0.18))
                    .frame(height: 10)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.orange.gradient)
                            .frame(width: 140, height: 10)
                    }
            }
        }

        private func spotlightCard(
            for step: Step,
            actions: TutorialSpotlightActions
        ) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(step.title)
                    .font(.title3.weight(.bold))

                Text(step.message)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Close") {
                        actions.dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    if step != .hero {
                        Button("Back") {
                            actions.previous()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    Button(step.buttonTitle) {
                        actions.advance()
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding(20)
            .background(.white, in: .rect(cornerRadius: 28))
            .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        }

        private func scrollToSelection(
            using reader: ScrollViewProxy,
            animated: Bool = true
        ) {
            guard let selection, selection.requiresScrolling else { return }

            let update = {
                reader.scrollTo(selection, anchor: selection.scrollAnchor)
            }

            if animated {
                withAnimation(.easeInOut(duration: 0.3)) {
                    update()
                }
            } else {
                update()
            }
        }
    }
    
    struct SheetSpotlightDemo: View {
        @Environment(\.dismiss) private var dismiss
        @State private var selection: TutorialSpotlightDemo.SheetStep?
        
        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plan Summary")
                            .font(.title2.bold())
                            .tutorialSpotlightSource(id: TutorialSpotlightDemo.SheetStep.title)
                        
                        Text("Review the details in the sheet before confirming the selection.")
                            .foregroundStyle(.secondary)
                        
                        Button("Start tutorial") {
                            selection = .title
                        }
                    }
                    
                    VStack(spacing: 14) {
                        summaryRow(title: "Destination", value: "Lisbon")
                        summaryRow(title: "Dates", value: "May 12 - May 16")
                        summaryRow(title: "Guests", value: "2 adults")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: .rect(cornerRadius: 24))
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Confirm")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.blue.gradient, in: .rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .tutorialSpotlightSource(id: TutorialSpotlightDemo.SheetStep.action)
                }
                .padding(24)
                .navigationTitle("Booking")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
            .tutorialSpotlight(
                selection: $selection,
                orderedIDs: TutorialSpotlightDemo.SheetStep.allCases,
                spotlightEdgeBlurRadius: 10
            ) { id, actions in
                VStack(alignment: .leading, spacing: 16) {
                    Text(id.title)
                        .font(.headline)
                    
                    Text(id.message)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Button("Close") {
                            actions.dismiss()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Spacer()

                        if id != .title {
                            Button("Back") {
                                actions.previous()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        Button(id.buttonTitle) {
                            if id == .action {
                                dismiss()
                            } else {
                                actions.advance()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
                .padding(20)
                .background(.white, in: .rect(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
            }
        }
        
        private func summaryRow(title: String, value: String) -> some View {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.semibold)
            }
        }
    }
    
    return TabView {
        TutorialSpotlightDemo()
            .tabItem {
                Label("Basic", systemImage: "sparkles.rectangle.stack")
            }

        ScrollViewSpotlightDemo()
            .tabItem {
                Label("Scroll", systemImage: "arrow.up.and.down.text.horizontal")
            }
    }
}
