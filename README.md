# TutorialSpotlight

`TutorialSpotlight` is a lightweight SwiftUI package for building onboarding flows with a spotlight effect. It dims the screen, cuts out the currently focused element, draws a visible highlight around it, and lets you attach custom instructional content that can dismiss or advance the tutorial.

<img src="https://github.com/Livsy90/TutorialSpotlight/blob/main/TutorialSpotlightDemo2.jpg" height="450">
<img src="https://github.com/Livsy90/TutorialSpotlight/blob/main/TutorialSpotlightDemo1.jpg" height="450">

The package is implemented as a pair of view modifiers:

- `tutorialSpotlight(...)` attaches the spotlight container to a common parent view.
- `tutorialSpotlightSource(id:)` registers individual views as spotlight targets.
- `tutorialSpotlightSource(id:spotlightShape:)` overrides the cutout shape for a specific target.

## Requirements

- iOS 15.0+
- SwiftUI

## Installation

Add the package to your project with Swift Package Manager.

```
https://github.com/Livsy90/TutorialSpotlight
```

## Public API

```swift
public extension View {
    func tutorialSpotlight<ID: Hashable, Overlay: View>(
        selection: Binding<ID?>,
        orderedIDs: [ID],
        spotlightPadding: CGFloat = 8,
        cornerRadius: CGFloat,
        animationDuration: TimeInterval = 0.25,
        dimmingOpacity: CGFloat = 0.58,
        spotlightEdgeBlurRadius: CGFloat = 0,
        @ViewBuilder overlay: @escaping (_ id: ID, _ actions: TutorialSpotlightActions) -> Overlay
    ) -> some View

    func tutorialSpotlight<ID: Hashable, Overlay: View>(
        selection: Binding<ID?>,
        orderedIDs: [ID],
        spotlightPadding: CGFloat = 8,
        spotlightShape: TutorialSpotlightShape = .rect(cornerRadius: 28),
        animationDuration: TimeInterval = 0.25,
        dimmingOpacity: CGFloat = 0.58,
        spotlightEdgeBlurRadius: CGFloat = 0,
        @ViewBuilder overlay: @escaping (_ id: ID, _ actions: TutorialSpotlightActions) -> Overlay
    ) -> some View

    func tutorialSpotlightSource<ID: Hashable>(id: ID) -> some View
    func tutorialSpotlightSource<ID: Hashable>(id: ID, spotlightShape: TutorialSpotlightShape) -> some View
}

public struct TutorialSpotlightShape: Shape {
    public init<S: Shape>(_ shape: S)
    public static func rect(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) -> TutorialSpotlightShape
    public static var rect: TutorialSpotlightShape { get }
    public static var circle: TutorialSpotlightShape { get }
    public static var capsule: TutorialSpotlightShape { get }
}

public struct TutorialSpotlightActions {
    public let dismiss: () -> Void
    public let previous: () -> Void
    public let advance: () -> Void
}
```

## How It Works

1. Mark each spotlight target with `tutorialSpotlightSource(id:)`.
2. Store the current step in a `@State` optional value.
3. Attach `tutorialSpotlight(...)` to a shared ancestor of all registered targets.
4. Render your own overlay card based on the active `id`.
5. Call `actions.previous()` or `actions.advance()` to move through the flow, or `actions.dismiss()` to close it.

## Example

```swift
import SwiftUI
import TutorialSpotlight

struct OnboardingDemoView: View {
    enum Step: Hashable, CaseIterable {
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
            case .profile: "Open account settings and personal details."
            case .filters: "Adjust the criteria before continuing."
            case .checkout: "Finish the flow with the primary action."
            }
        }
    }

    @State private var selection: Step? = .profile

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Button("Profile") {
                    selection = .profile
                }
                .tutorialSpotlightSource(id: Step.profile, spotlightShape: .circle)

                Button("Filters") {
                    selection = .filters
                }
                .tutorialSpotlightSource(id: Step.filters)

                Button("Continue") {
                    selection = .checkout
                }
                .tutorialSpotlightSource(id: Step.checkout)
            }
            .padding()
            .navigationTitle("Demo")
        }
        .tutorialSpotlight(
            selection: $selection,
            orderedIDs: Step.allCases,
            spotlightShape: .capsule,
            spotlightEdgeBlurRadius: 8
        ) { step, actions in
            VStack(alignment: .leading, spacing: 16) {
                Text(step.title)
                    .font(.headline)

                Text(step.message)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Skip") {
                        actions.dismiss()
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Back") {
                        actions.previous()
                    }
                    .buttonStyle(.plain)

                    Button("Next") {
                        actions.advance()
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding(20)
            .background(.white, in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        }
    }
}
```

## ScrollViewReader Example

Use `ScrollViewReader` when some spotlight targets can be off-screen. In this setup, the tutorial scrolls to the newly selected step before showing the next help card.

```swift
import SwiftUI
import TutorialSpotlight

struct ScrollingOnboardingView: View {
    enum Step: String, CaseIterable {
        case hero
        case budget
        case reviews
        case checkout

        var title: String {
            switch self {
            case .hero: "Overview"
            case .budget: "Budget"
            case .reviews: "Reviews"
            case .checkout: "Checkout"
            }
        }

        var message: String {
            switch self {
            case .hero: "Start with the route overview."
            case .budget: "Adjust the price limits before continuing."
            case .reviews: "This section can be far below the fold."
            case .checkout: "Finish with the sticky action at the bottom."
            }
        }

        var scrollAnchor: UnitPoint {
            switch self {
            case .hero: .top
            case .budget: .center
            case .reviews, .checkout: .bottom
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

                        budgetSection
                            .id(Step.budget)
                            .tutorialSpotlightSource(id: Step.budget)

                        reviewsSection
                            .id(Step.reviews)
                            .tutorialSpotlightSource(id: Step.reviews)
                    }
                    .padding(24)
                }
                .safeAreaInset(edge: .bottom) {
                    checkoutButton
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
        ) { step, actions in
            VStack(alignment: .leading, spacing: 16) {
                Text(step.title)
                    .font(.headline)

                Text(step.message)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Close") {
                        actions.dismiss()
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if step != .hero {
                        Button("Back") {
                            actions.previous()
                        }
                        .buttonStyle(.plain)
                    }

                    Button(step == .checkout ? "Finish" : "Next") {
                        actions.advance()
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding(20)
            .background(.white, in: .rect(cornerRadius: 24))
        }
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

    private var heroSection: some View {
        Text("Hero Section")
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(.white.opacity(0.8), in: .rect(cornerRadius: 24))
    }

    private var budgetSection: some View {
        Text("Budget Controls")
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(.white.opacity(0.8), in: .rect(cornerRadius: 24))
    }

    private var reviewsSection: some View {
        VStack(spacing: 12) {
            ForEach(0..<5) { index in
                Text("Review \(index + 1)")
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(.white.opacity(0.75), in: .rect(cornerRadius: 18))
            }
        }
    }

    private var checkoutButton: some View {
        Button("Reserve Route") {
            selection = .checkout
        }
        .buttonStyle(.borderedProminent)
    }
}
```

## Behavior Notes

- The spotlight overlay is shown only when `selection` matches a registered target.
- `orderedIDs` controls the sequence used by `actions.previous()` and `actions.advance()`.
- Step navigation skips IDs that are not currently registered in the view hierarchy.
- The default spotlight is a rounded rectangle, but you can supply any custom `Shape`.
- `spotlightEdgeBlurRadius` adds optional feathering around the cutout for a softer flashlight effect.
- Tapping the dimmed background dismisses the tutorial.
- The overlay card is automatically positioned below the highlighted element when possible, and moves above it when space is limited.
- The overlay content itself is not animated between steps; the card fades in after a short delay to avoid jitter during scrolling transitions.
- The highlight frame animates when the selection changes or the target moves during layout updates.

## Best Practices

- Attach `tutorialSpotlight(...)` to a parent that contains all spotlight targets.
- Keep IDs unique within a single spotlight flow.
- Use a stable `orderedIDs` array so step navigation remains predictable.
- Start the flow by assigning the first step to `selection`.

## Preview Coverage

The package source includes previews demonstrating:

- A multi-step onboarding flow in a navigation-based screen
- A long `ScrollView` onboarding flow that scrolls to off-screen targets with `ScrollViewReader`
- A spotlight flow inside a presented sheet

These previews are a good starting point for adapting the component to your own UI.
