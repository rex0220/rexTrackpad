#if DEBUG
import SwiftUI

/// Debug-only window: touch positions, finger count, direction, distance,
/// duration, recognizer state and recent events.
struct DebugMonitorView: View {
    @ObservedObject var monitor: DebugMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                TouchSurfaceView(contacts: monitor.diagnostics?.contacts ?? [])
                    .frame(width: 320, height: 200)

                VStack(alignment: .leading, spacing: 4) {
                    row("Fingers", "\(monitor.diagnostics?.contacts.count ?? 0) (max \(monitor.diagnostics?.maxFingers ?? 0))")
                    row("State", monitor.diagnostics?.state.displayName ?? "idle")
                    row("Duration", String(format: "%.3f s", monitor.diagnostics?.sessionDuration ?? 0))
                    row("Direction", directionText)
                    row("Translation", translationText)
                    row("Distance", distanceText)
                    Divider()
                    row("Last gesture", monitor.lastGesture)
                    Text(monitor.lastMetrics)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 300, alignment: .leading)
            }

            if let contacts = monitor.diagnostics?.contacts, !contacts.isEmpty {
                Text(contacts.map { String(format: "#%d (%.3f, %.3f)", $0.id, Double($0.position.x), Double($0.position.y)) }.joined(separator: "   "))
                    .font(.system(size: 11, design: .monospaced))
            }

            HStack {
                Text("Events").font(.headline)
                Spacer()
                Button("Clear") { monitor.clear() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(monitor.events.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(height: 220)
        }
        .padding(16)
        .frame(width: 660)
    }

    private var translation: CGVector? {
        monitor.diagnostics?.swipeTranslation
    }

    private var directionText: String {
        guard let t = translation, hypot(Double(t.dx), Double(t.dy)) > 0.01 else { return "—" }
        if abs(t.dx) >= abs(t.dy) {
            return t.dx > 0 ? "→ right" : "← left"
        }
        return t.dy > 0 ? "↑ up" : "↓ down"
    }

    private var translationText: String {
        guard let t = translation else { return "—" }
        return String(format: "dx %.3f  dy %.3f", Double(t.dx), Double(t.dy))
    }

    private var distanceText: String {
        guard let t = translation else { return "—" }
        return String(format: "%.3f", hypot(Double(t.dx), Double(t.dy)))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.secondary).frame(width: 90, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced))
        }
    }
}

/// Draws contacts on a trackpad-shaped surface (y = 0 at the bottom, as on the device).
private struct TouchSurfaceView: View {
    let contacts: [TouchPoint]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.4))
                ForEach(contacts, id: \.id) { contact in
                    Circle()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .overlay(Text("\(contact.id)").font(.system(size: 9)).foregroundColor(.white))
                        .position(
                            x: contact.position.x * proxy.size.width,
                            y: (1 - contact.position.y) * proxy.size.height
                        )
                }
            }
        }
    }
}
#endif
