# TutorialSpotlight

`TutorialSpotlight` is a lightweight SwiftUI package for building onboarding flows with a spotlight effect. It dims the screen, cuts out the currently focused element, draws a visible highlight around it, and lets you attach custom instructional content that can dismiss or advance the tutorial.

<img src="https://github.com/Livsy90/TutorialSpotlight/blob/main/TutorialSpotlightDemo.gif">

The package is implemented as a pair of view modifiers:

- `tutorialSpotlight(...)` attaches the spotlight container to a common parent view.
- `tutorialSpotlightSource(id:)` registers individual views as spotlight targets.

## Requirements

- iOS 15.0+
- SwiftUI

## Installation

Add the package to your project with Swift Package Manager.

```
https://github.com/Livsy90/IntelligenceGlow.git
```

## Public API

```swift
public extension View {
    func tutorialSpotlight<ID: Hashable, Overlay: View>(
        selection: Binding<ID?>,
        orderedIDs: [ID],
        spotlightPadding: CGFloat = 8,
        cornerRadius: CGFloat = 28,
        @ViewBuilder overlay: @escaping (_ id: ID, _ actions: TutorialSpotlightActions) -> Overlay
    ) -> some View

    func tutorialSpotlightSource<ID: Hashable>(id: ID) -> some View
}

public struct TutorialSpotlightActions {
    public let dismiss: () -> Void
    public let advance: () -> Void
}
```

## How It Works

1. Mark each spotlight target with `tutorialSpotlightSource(id:)`.
2. Store the current step in a `@State` optional value.
3. Attach `tutorialSpotlight(...)` to a shared ancestor of all registered targets.
4. Render your own overlay card based on the active `id`.
5. Call `actions.advance()` to move to the next step, or `actions.dismiss()` to close the flow.

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
                .tutorialSpotlightSource(id: Step.profile)

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
            orderedIDs: Step.allCases
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

## Behavior Notes

- The spotlight overlay is shown only when `selection` matches a registered target.
- `orderedIDs` controls the sequence used by `actions.advance()`.
- Tapping the dimmed background dismisses the tutorial.
- The overlay card is automatically positioned below the highlighted element when possible, and moves above it when space is limited.
- The highlight frame animates when the selection changes or the target moves during layout updates.

## Best Practices

- Attach `tutorialSpotlight(...)` to a parent that contains all spotlight targets.
- Keep IDs unique within a single spotlight flow.
- Use a stable `orderedIDs` array so step navigation remains predictable.
- Start the flow by assigning the first step to `selection`.

## Preview Coverage

The package source includes previews demonstrating:

- A multi-step onboarding flow in a navigation-based screen
- A spotlight flow inside a presented sheet

These previews are a good starting point for adapting the component to your own UI.
