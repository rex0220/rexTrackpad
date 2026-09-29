import SwiftUI

/// Minimal sensitivity settings. Gesture ↔ action bindings are edited from the menu.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Avoid macOS gesture conflicts", isOn: binding(\.avoidsSystemGestureConflicts))
                Text("Ignores gestures that macOS already uses (Mission Control, switching desktops, …) according to System Settings › Trackpad.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Tap") {
                slider("Maximum duration", value: configuration(\.tapMaximumDuration), range: 0.15...0.60, format: "%.2f s")
                slider("Maximum movement", value: configuration(\.tapMaximumMovement), range: 0.02...0.10, format: "%.2f")
                slider("Side zone width", value: configuration(\.tapZoneEdge), range: 0.20...0.45, format: "%.2f")
            }

            Section("Swipe") {
                slider("Minimum distance", value: configuration(\.swipeMinimumDistance), range: 0.10...0.40, format: "%.2f")
                slider("Maximum duration", value: configuration(\.swipeMaximumDuration), range: 0.30...1.20, format: "%.2f s")
                slider("Direction strictness", value: configuration(\.swipeDirectionRatio), range: 1.2...4.0, format: "%.1f×")
            }

            Section("Repeat protection") {
                slider("Cooldown after a gesture", value: configuration(\.cooldown), range: 0.10...1.00, format: "%.2f s")
            }

            HStack {
                Spacer()
                Button("Restore Defaults") { settings.resetGestureConfiguration() }
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: keyPath] }, set: { settings[keyPath: keyPath] = $0 })
    }

    private func configuration(_ keyPath: WritableKeyPath<GestureConfiguration, Double>) -> Binding<Double> {
        Binding(
            get: { settings.gestureConfiguration[keyPath: keyPath] },
            set: { newValue in
                var configuration = settings.gestureConfiguration
                configuration[keyPath: keyPath] = newValue
                settings.gestureConfiguration = configuration
            }
        )
    }

    private func slider(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        HStack {
            Text(title).frame(width: 170, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .monospacedDigit()
                .frame(width: 60, alignment: .trailing)
        }
    }
}
