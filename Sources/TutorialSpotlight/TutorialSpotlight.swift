import SwiftUI

public extension View {
    /// Applies an onboarding spotlight overlay to a common parent view.
    ///
    /// Mark focusable elements with `tutorialSpotlightSource(id:)`.
    func tutorialSpotlight<ID: Hashable, Overlay: View>(
        selection: Binding<ID?>,
        orderedIDs: [ID],
        spotlightPadding: CGFloat = 8,
        cornerRadius: CGFloat = 28,
        @ViewBuilder overlay: @escaping (_ id: ID, _ actions: TutorialSpotlightActions) -> Overlay
    ) -> some View {
        modifier(
            TutorialSpotlightContainerModifier(
                selection: selection,
                orderedIDs: orderedIDs,
                spotlightPadding: spotlightPadding,
                cornerRadius: cornerRadius,
                overlay: overlay
            )
        )
    }
    
    /// Marks a view as a spotlight target.
    func tutorialSpotlightSource<ID: Hashable>(id: ID) -> some View {
        modifier(TutorialSpotlightSourceModifier(id: id))
    }
}

public struct TutorialSpotlightActions {
    /// Closes the spotlight flow and removes the overlay.
    public let dismiss: () -> Void
    
    /// Advances to the next spotlight item from `orderedIDs`.
    public let advance: () -> Void
}

private struct TutorialSpotlightSourceModifier<ID: Hashable>: ViewModifier {
    let id: ID
    
    func body(content: Content) -> some View {
        // Store the view bounds as an anchor so the container modifier can later
        // resolve the highlighted frame inside its own geometry context.
        content.anchorPreference(
            key: TutorialSpotlightPreferenceKey<ID>.self,
            value: .bounds
        ) { anchor in
            [id: anchor]
        }
    }
}

private struct TutorialSpotlightContainerModifier<ID: Hashable, Overlay: View>: ViewModifier {
    @Binding var selection: ID?
    
    let orderedIDs: [ID]
    let spotlightPadding: CGFloat
    let cornerRadius: CGFloat
    let overlay: (ID, TutorialSpotlightActions) -> Overlay
    
    // This is the animated spotlight frame currently shown on screen.
    // It allows the cutout and border to move smoothly between targets.
    @State private var currentFrame: CGRect = .zero
    
    // The overlay card is measured during layout so its position can be computed
    // from its actual rendered size rather than hardcoded dimensions.
    @State private var overlaySize: CGSize = .zero
    
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
        preferences: [ID: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        if let selected = selection, let anchor = preferences[selected] {
            // Resolve the selected anchor inside the container coordinate space.
            let targetFrame = proxy[anchor]
            let focusFrame = targetFrame.insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
            
            // During the very first frame there is nothing to animate from, so use the
            // resolved frame immediately. After that we animate via `currentFrame`.
            let displayedFocusFrame = currentFrame == .zero ? focusFrame : currentFrame
            
            // Expose imperative actions to the overlay content so it can either dismiss
            // the tutorial or advance through the ordered spotlight sequence.
            let actions = TutorialSpotlightActions(
                dismiss: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selection = nil
                    }
                },
                advance: {
                    guard let currentSelection = selection else { return }
                    guard let index = orderedIDs.firstIndex(of: currentSelection) else {
                        selection = nil
                        return
                    }
                    
                    let nextIndex = orderedIDs.index(after: index)
                    
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selection = nextIndex < orderedIDs.endIndex ? orderedIDs[nextIndex] : nil
                    }
                }
            )
            
            let safeAreaInsets = proxy.safeAreaInsets
            let containerBounds = CGRect(
                origin: .zero,
                size: CGSize(
                    width: proxy.size.width + safeAreaInsets.leading + safeAreaInsets.trailing,
                    height: proxy.size.height + safeAreaInsets.top + safeAreaInsets.bottom
                )
            )
            let overlayFocusFrame = displayedFocusFrame.offsetBy(
                dx: safeAreaInsets.leading,
                dy: safeAreaInsets.top
            )
            
            ZStack(alignment: .topLeading) {
                // Draw a fullscreen dimming layer with an even-odd cutout where the
                // highlighted control should remain visually visible.
                TutorialSpotlightCutoutShape(
                    focusFrame: overlayFocusFrame,
                    cornerRadius: cornerRadius
                )
                .fill(
                    .black.opacity(0.58),
                    style: FillStyle(eoFill: true)
                )
                .contentShape(.rect)
                .onTapGesture {
                    actions.dismiss()
                }
                
                // Add a visible border around the spotlighted element so the target
                // remains clearly identifiable against the dimmed background.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.95), lineWidth: 3)
                    .frame(width: overlayFocusFrame.width, height: overlayFocusFrame.height)
                    .position(x: overlayFocusFrame.midX, y: overlayFocusFrame.midY)
                    .shadow(color: .white.opacity(0.25), radius: 16)
                    .allowsHitTesting(false)
                
                // Render the caller-provided overlay card and measure it in the same
                // pass so we can place it above or below the spotlight accurately.
                overlay(selected, actions)
                    .frame(maxWidth: min(320, containerBounds.width - 32))
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
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
            .animation(.spring(duration: 0.32), value: selection)
            .animation(.spring(duration: 0.32), value: currentFrame)
            .animation(.spring(duration: 0.32), value: overlaySize)
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
        let horizontalPadding: CGFloat = 16
        let verticalSpacing: CGFloat = 24
        let verticalPadding: CGFloat = 24
        
        // Cap the overlay width to a readable maximum while still respecting
        // the available horizontal space inside the container.
        let maxOverlayWidth = min(320, container.width - (horizontalPadding * 2))
        
        // Use the measured overlay size when available. Fallback values are used
        // during the first layout pass, before SwiftUI reports the actual size.
        let measuredWidth = overlaySize.width > 0 ? overlaySize.width : maxOverlayWidth
        let measuredHeight = overlaySize.height > 0 ? overlaySize.height : 180
        let overlayWidth = min(measuredWidth, maxOverlayWidth)
        
        // Try to align the overlay horizontally with the highlighted target,
        // then clamp the center point so the card stays fully visible on screen.
        let centeredX = min(
            max(focusFrame.midX, container.minX + horizontalPadding + overlayWidth / 2),
            container.maxX - horizontalPadding - overlayWidth / 2
        )
        
        // The preferred placement is below the spotlight. We compute the Y center
        // by taking the target's bottom edge, adding vertical spacing, and then
        // shifting by half of the overlay height because `.position` works from center.
        let preferredBelowY = focusFrame.maxY + verticalSpacing + measuredHeight / 2
        
        // If the entire overlay still fits within the bottom safe area margin,
        // keep it below the spotlight because that is the primary visual layout.
        if preferredBelowY + measuredHeight / 2 <= container.maxY - verticalPadding {
            return CGPoint(x: centeredX, y: preferredBelowY)
        }
        
        // Otherwise, move the overlay above the spotlight using the same center-based
        // coordinate calculation.
        let preferredAboveY = focusFrame.minY - verticalSpacing - measuredHeight / 2
        
        // Clamp the final vertical position so the overlay remains fully inside
        // the visible container even when there is not enough room above either.
        let clampedY = min(
            max(preferredAboveY, container.minY + verticalPadding + measuredHeight / 2),
            container.maxY - verticalPadding - measuredHeight / 2
        )
        return CGPoint(x: centeredX, y: clampedY)
    }
}

private struct TutorialSpotlightPreferenceKey<ID: Hashable>: PreferenceKey {
    // Each spotlight source contributes a single anchor keyed by its logical ID.
    static var defaultValue: [ID: Anchor<CGRect>] { [:] }
    
    static func reduce(value: inout [ID: Anchor<CGRect>], nextValue: () -> [ID: Anchor<CGRect>]) {
        // If the same ID appears multiple times, keep the most recent value.
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TutorialSpotlightCutoutShape: Shape {
    let focusFrame: CGRect
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Add the full-screen rectangle first, then the rounded spotlight path.
        // The shape is later filled with even-odd rules so the inner path becomes a hole.
        path.addRect(rect)
        path.addPath(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .path(in: focusFrame)
        )
        return path
    }
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

@available(iOS 16.0)
#Preview {
    struct TutorialSpotlightDemo: View {
        // Demo steps used to show how the spotlight moves through multiple targets.
        enum Step: String, CaseIterable {
            case profile
            case filters
            case checkout
            
            var title: String {
                switch self {
                case .profile: "Profile"
                case .filters: "Filters"
                case .checkout: "Checkout"
                }
            }
            
            var message: String {
                switch self {
                case .profile: "Here the user quickly gets to their profile and account settings."
                case .filters: "This block manages filters. It's usually the second step in onboarding."
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
                            .tutorialSpotlightSource(id: Step.filters)
                        
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
                            .tutorialSpotlightSource(id: Step.profile)
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
                orderedIDs: Step.allCases
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
                orderedIDs: TutorialSpotlightDemo.SheetStep.allCases
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
    
    return TutorialSpotlightDemo()
}
