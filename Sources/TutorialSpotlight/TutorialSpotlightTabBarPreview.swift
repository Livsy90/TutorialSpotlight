import SwiftUI

@available(iOS 16.0, *)
#Preview("Window above tab bar") {
    TutorialSpotlightTabBarPreview()
}

/// The modifier deliberately lives inside TabView: the separate window must cover
/// the system tab bar even though it is outside the modifier's SwiftUI subtree.
@available(iOS 16.0, *)
struct TutorialSpotlightTabBarPreview: View {
    private enum Step: Hashable, CaseIterable {
        case calendar
        case addTracker
    }

    @State private var selection: Step? = .addTracker

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("October").font(.title2.bold())
                            HStack {
                                ForEach(12..<19) { day in
                                    VStack(spacing: 10) {
                                        Circle().stroke(.blue.opacity(0.6), lineWidth: 4)
                                            .frame(width: 24, height: 24)
                                        Text("\(day)").font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(24)
                        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 30))
                        .tutorialSpotlightSource(id: Step.calendar, spotlightShape: .rect(cornerRadius: 30))

                        Text("Your trackers").font(.headline)
                        ForEach(["Morning walk", "Read a book", "Drink water"], id: \.self) { title in
                            Label(title, systemImage: "circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding()
                }
                .navigationTitle("Tracker")
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button {
                            selection = .calendar
                        } label: {
                            Label("Show Tips Again", systemImage: "questionmark.circle")
                        }
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .frame(width: 52, height: 52)
                        .background(.regularMaterial, in: Circle())
                        .accessibilityIdentifier("showTipsAgain")

                        Spacer()

                        Button {
                            selection = .addTracker
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(.black, in: Circle())
                        }
                        .accessibilityLabel("Add a Tracker")
                        .accessibilityIdentifier("addTracker")
                        .tutorialSpotlightSource(id: Step.addTracker, spotlightShape: .circle)
                    }
                    .padding()
                }
            }
            .tutorialSpotlight(
                selection: $selection,
                orderedIDs: Step.allCases,
                spotlightPadding: 12,
                spotlightEdgeBlurRadius: 4,
                presentation: .window
            ) { step, actions in
                VStack(alignment: .leading, spacing: 16) {
                    Text(step == .calendar ? "Track Your Progress" : "Add a Tracker")
                        .font(.title3.weight(.semibold))
                    Text(step == .calendar
                         ? "Each ring shows your progress for that day. Expand the calendar to switch between weekly and monthly views."
                         : "Create a new habit, activity, or goal to track.")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Button("Cancel", action: actions.dismiss)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: actions.previous) {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Back")
                        .disabled(step == .calendar)
                        .opacity(step == .calendar ? 0 : 1)
                        Button(action: step == .addTracker ? actions.dismiss : actions.advance) {
                            Image(systemName: step == .addTracker ? "checkmark" : "chevron.right")
                        }
                        .accessibilityLabel(step == .addTracker ? "Done" : "Next")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                .fixedSize(horizontal: false, vertical: true)
            }
            .tabItem { Label("Trackers", systemImage: "checklist") }

            NavigationStack { Text("Journal").navigationTitle("Journal") }
                .tabItem { Label("Journal", systemImage: "book.closed") }

            NavigationStack { Text("Settings").navigationTitle("Settings") }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
    }
}
