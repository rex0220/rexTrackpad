import SwiftUI

/// The settings window: gesture assignments, sensitivity, browsers and permissions,
/// one tab each, sized so that nothing needs scrolling.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    /// The macOS gesture currently using a gesture, if any.
    let conflict: (TrackpadGesture) -> SystemGestureConflict?
    /// Whether any channel of a browser is installed (for a hint only).
    let isInstalled: (Browser) -> Bool
    @ObservedObject var permissions: PermissionsViewModel
    @ObservedObject var recentTaps: RecentTaps
    let close: () -> Void

    enum Tab: Hashable {
        case assignments
        case sensitivity
        case browsers
        case permissions
    }

    @State private var tab: Tab

    init(
        settings: SettingsStore,
        conflict: @escaping (TrackpadGesture) -> SystemGestureConflict?,
        isInstalled: @escaping (Browser) -> Bool,
        permissions: PermissionsViewModel,
        recentTaps: RecentTaps,
        close: @escaping () -> Void,
        initialTab: Tab = .assignments
    ) {
        self.settings = settings
        self.conflict = conflict
        self.isInstalled = isInstalled
        self.permissions = permissions
        self.recentTaps = recentTaps
        self.close = close
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $tab) {
                page(assignmentsTab)
                    .tabItem { Text("Assignments") }
                    .tag(Tab.assignments)
                page(sensitivityTab)
                    .tabItem { Text("Sensitivity") }
                    .tag(Tab.sensitivity)
                page(browsersTab)
                    .tabItem { Text("Browsers") }
                    .tag(Tab.browsers)
                page(PermissionsView(model: permissions))
                    .tabItem { Text("Permissions") }
                    .tag(Tab.permissions)
            }
            .font(.callout)
            .controlSize(.small)

            HStack {
                Spacer()
                Button("Close", action: close)
                    .keyboardShortcut(.cancelAction) // esc
            }
            .background(
                // ⌘W closes the window, as in other macOS apps.
                Button("Close", action: close)
                    .keyboardShortcut("w", modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)
            )
        }
        .padding(12)
        // Same size for every tab, so switching tabs does not resize the window. The
        // height includes the tab picker (≈ 50 pt) on top of the Assignments list.
        .frame(width: 560, height: 700, alignment: .top)
    }

    /// Tab contents start at the top instead of being centred vertically.
    private func page<Content: View>(_ content: Content) -> some View {
        content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Browsers

    private var browsersTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(Browser.allCases.enumerated()), id: \.element) { index, browser in
                        if index > 0 {
                            Divider()
                        }
                        HStack {
                            Toggle(browser.displayName, isOn: browserBinding(browser))
                            if !isInstalled(browser) {
                                Text("(not installed)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(6)
            }
            Text("Gestures only work while a checked browser is the frontmost app.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
    }

    private func browserBinding(_ browser: Browser) -> Binding<Bool> {
        Binding(
            get: { settings.isBrowserEnabled(browser) },
            set: { settings.setBrowser(browser, enabled: $0) }
        )
    }

    // MARK: - Assignments

    /// Gestures listed one per row; the three-finger taps are shown as a grid instead.
    private static let listedGestures: [TrackpadGesture] = {
        let grid = Set(TrackpadGesture.threeFingerTapGrid.joined())
        return TrackpadGesture.configurable.filter { !grid.contains($0) }
    }()

    private var assignmentsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox {
                tapGrid.padding(6)
            }
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
                    ForEach(Array(Self.listedGestures.enumerated()), id: \.element.identifier) { index, gesture in
                        if index > 0 {
                            Divider()
                        }
                        assignmentRow(for: gesture)
                    }
                }
                .padding(6)
            }

            if TrackpadGesture.configurable.contains(where: { blockedFeature(for: $0) != nil }) {
                Label {
                    Text("Gestures marked “Also used by macOS” are ignored, because macOS would react to them too. Change the macOS gesture in System Settings › Trackpad › More Gestures to use them.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Toggle("Avoid macOS gesture conflicts", isOn: binding(\.avoidsSystemGestureConflicts))
            Toggle("Show a symbol near the pointer when a gesture works", isOn: binding(\.showsGestureFeedback))

            HStack {
                Spacer()
                Button("Restore Default Gestures") { settings.resetGestureMapping() }
            }
        }
        .padding(8)
    }

    /// Three-finger taps, one cell per area of the trackpad.
    private var tapGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(TrackpadGesture.threeFingerTap.displayName)
                    .foregroundColor(blockedFeature(for: .threeFingerTap) == nil ? .primary : .secondary)
                Text("Where the fingers land")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let blocked = blockedFeature(for: .threeFingerTap) {
                    Label("Also used by macOS", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .help(String(localized: "Used by macOS: \(blocked.displayName)"))
                }
            }
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(TrackpadGesture.threeFingerTapGrid, id: \.first?.identifier) { row in
                    GridRow {
                        ForEach(row, id: \.identifier) { gesture in
                            tapCell(for: gesture)
                        }
                    }
                }
            }
        }
    }

    private func tapCell(for gesture: TrackpadGesture) -> some View {
        let unboundTitle = gesture.fallback.map { String(localized: "Same as \(Self.tapCellName($0))") }
            ?? String(localized: "None")
        return VStack(alignment: .leading, spacing: 2) {
            Text(Self.tapCellName(gesture))
                .font(.caption)
                .foregroundColor(.secondary)
            Picker(selection: assignment(for: gesture)) {
                Text(unboundTitle).tag(GestureAction?.none)
                Divider()
                ForEach(GestureAction.allBuiltIn, id: \.identifier) { action in
                    Text(action.displayName).tag(GestureAction?.some(action))
                }
            } label: {
                Text(gesture.displayName) // hidden; read by VoiceOver
            }
            .labelsHidden()
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
    }

    /// Short name of a grid cell ("Top-left corner", "Middle", …).
    private static func tapCellName(_ gesture: TrackpadGesture) -> String {
        if case .zoneTap(_, let zone) = gesture {
            return zone.displayName
        }
        return String(localized: "Middle")
    }

    private func assignmentRow(for gesture: TrackpadGesture) -> some View {
        // A side tap without its own action does whatever the plain tap does.
        let unboundTitle = gesture.fallback.map { String(localized: "Same as \($0.displayName)") }
            ?? String(localized: "None")
        let blocked = blockedFeature(for: gesture)

        return GridRow {
            Text(gesture.displayName)
                .foregroundColor(blocked == nil ? .primary : .secondary)
                .frame(width: 170, alignment: .leading)

            Group {
                if let blocked = blocked {
                    Label("Also used by macOS", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .help(String(localized: "Used by macOS: \(blocked.displayName)"))
                } else if case .circle(1, _) = gesture {
                    Text("Moves the pointer too")
                        .foregroundColor(.secondary)
                } else {
                    Text(verbatim: "")
                }
            }
            .font(.caption)
            .frame(width: 130, alignment: .leading)

            Picker(selection: assignment(for: gesture)) {
                Text(unboundTitle).tag(GestureAction?.none)
                Divider()
                ForEach(GestureAction.allBuiltIn, id: \.identifier) { action in
                    Text(action.displayName).tag(GestureAction?.some(action))
                }
            } label: {
                Text(gesture.displayName) // hidden; read by VoiceOver
            }
            .labelsHidden()
            .frame(width: 200)
        }
    }

    /// The macOS feature that makes this gesture inactive, if conflicts are avoided.
    private func blockedFeature(for gesture: TrackpadGesture) -> SystemGestureFeature? {
        settings.avoidsSystemGestureConflicts ? conflict(gesture)?.feature : nil
    }

    // MARK: - Sensitivity

    private var sensitivityTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            sliderGroup("Tap") {
                slider("Maximum duration", value: configuration(\.tapMaximumDuration), range: 0.15...0.60, format: "%.2f s")
                slider("Maximum movement", value: configuration(\.tapMaximumMovement), range: 0.02...0.10, format: "%.2f")
                slider("Side zone width", value: configuration(\.tapZoneEdge), range: 0.20...0.45, format: "%.2f")
                slider("Top / bottom zone height", value: configuration(\.tapZoneEdgeVertical), range: 0.15...0.45, format: "%.2f")
                tapZonePreview
            }
            sliderGroup("Swipe") {
                slider("Minimum distance", value: configuration(\.swipeMinimumDistance), range: 0.10...0.40, format: "%.2f")
                slider("Maximum duration", value: configuration(\.swipeMaximumDuration), range: 0.30...1.20, format: "%.2f s")
                slider("Direction strictness", value: configuration(\.swipeDirectionRatio), range: 1.2...4.0, format: "%.1f×")
            }
            sliderGroup("Circle") {
                slider("Minimum size", value: configuration(\.circleMinimumRadius), range: 0.02...0.15, format: "%.2f")
                slider("Required turn", value: configuration(\.circleMinimumTurn), range: 240...360, format: "%.0f°")
            }
            sliderGroup("Repeat protection") {
                slider("Cooldown after a gesture", value: configuration(\.cooldown), range: 0.10...1.00, format: "%.2f s")
            }
            HStack {
                Spacer()
                Button("Restore Default Sensitivity") { settings.resetGestureConfiguration() }
            }
        }
        .padding(8)
    }

    /// The tap grid drawn to scale, with the last few three-finger taps on it.
    private var tapZonePreview: some View {
        let configuration = settings.gestureConfiguration
        let taps = recentTaps.taps.filter { $0.gesture.fingerCount == 3 }
        return HStack(alignment: .top, spacing: 12) {
            TapZonePreview(configuration: configuration, taps: taps)
                .frame(width: 160, height: 100)
            VStack(alignment: .leading, spacing: 4) {
                Text("Tap with three fingers to see where taps land and which area they count as.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let last = taps.last {
                    HStack {
                        Text("Last tap: \(Self.tapCellName(last.gesture))")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button("Clear") { recentTaps.clear() }
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 2)
    }

    private func sliderGroup<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6, content: content)
                .padding(6)
        } label: {
            Text(title).font(.callout.weight(.semibold))
        }
    }

    private func assignment(for gesture: TrackpadGesture) -> Binding<GestureAction?> {
        Binding(
            get: { settings.gestureMapping.ownAction(for: gesture) },
            set: { action in
                var mapping = settings.gestureMapping
                mapping.bind(gesture, to: action)
                settings.gestureMapping = mapping
            }
        )
    }

    // MARK: - Helpers

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

/// A trackpad outline split into the 3 × 3 tap grid, with recent taps as dots
/// (the newest one highlighted).
private struct TapZonePreview: View {
    let configuration: GestureConfiguration
    let taps: [RecentTaps.Tap]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let x1 = configuration.tapZoneEdge * size.width
            let x2 = (1 - configuration.tapZoneEdge) * size.width
            let y1 = configuration.tapZoneEdgeVertical * size.height
            let y2 = (1 - configuration.tapZoneEdgeVertical) * size.height
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
                Path { path in
                    for x in [x1, x2] {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in [y1, y2] {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.6))
                ForEach(taps) { tap in
                    let isLast = tap.id == taps.last?.id
                    Circle()
                        .fill(Color.accentColor.opacity(isLast ? 1 : 0.35))
                        .frame(width: isLast ? 10 : 7, height: isLast ? 10 : 7)
                        // The trackpad's y grows upwards; the view's grows downwards.
                        .position(x: tap.position.x * size.width, y: (1 - tap.position.y) * size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
