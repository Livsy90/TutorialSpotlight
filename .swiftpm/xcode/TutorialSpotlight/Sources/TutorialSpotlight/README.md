# TutorialSpotlight

`TutorialSpotlight` is a lightweight SwiftUI package for building onboarding flows with a spotlight effect. It dims the screen, cuts out the currently focused element, draws a visible highlight around it, and lets you attach custom instructional content that can dismiss or advance the tutorial.

The package is implemented as a pair of view modifiers:

- `tutorialSpotlight(...)` attaches the spotlight container to a common parent view.
- `tutorialSpotlightSource(id:)` registers individual views as spotlight targets.

## Requirements

- iOS 17.0+
- Swift 6.2
- SwiftUI

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
        }
        .tutorialSpotlight(
            selection: $selection,
            orderedIDs: Step.allCases
        ) { step, actions in
            VStack(alignment: .leading, spacing: 16) {
                Text(String(describing: step))
                    .font(.headline)

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
        }
    }
}
```

## Behavior Notes

- The spotlight is visible only when `selection` matches a registered target.
- `orderedIDs` defines the order used by `actions.advance()`.
- Tapping the dimmed area dismisses the tutorial.
- The overlay card is positioned below the highlighted element when possible, otherwise above it.
- The highlighted frame animates when the selected target changes.

## Best Practices

- Attach `tutorialSpotlight(...)` to a parent that contains all spotlight targets.
- Keep IDs unique within a single flow.
- Use a stable `orderedIDs` array.
- Keep overlay content compact for smaller screens.
