import Foundation
import IOKit

/// Notifies when a multitouch device (e.g. a Magic Trackpad) is connected or disconnected.
///
/// Uses only public IOKit API. MultitouchSupport does not pick up new devices on its
/// own, so the provider restarts itself when this fires.
final class MultitouchDeviceWatcher {
    var onChange: (() -> Void)?

    private var port: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0

    deinit {
        stop()
    }

    func start() {
        guard port == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let watcher = Unmanaged<MultitouchDeviceWatcher>.fromOpaque(refcon).takeUnretainedValue()
            if MultitouchDeviceWatcher.drain(iterator) {
                watcher.onChange?()
            }
        }

        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification,
                                         IOServiceMatching("AppleMultitouchDevice"),
                                         callback, refcon, &addedIterator)
        // Draining arms the notification. Devices that already exist are ignored.
        _ = Self.drain(addedIterator)

        IOServiceAddMatchingNotification(port, kIOTerminatedNotification,
                                         IOServiceMatching("AppleMultitouchDevice"),
                                         callback, refcon, &removedIterator)
        _ = Self.drain(removedIterator)
    }

    func stop() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        if let port {
            IONotificationPortDestroy(port)
        }
        port = nil
    }

    /// Consumes all pending services. Returns whether there were any.
    private static func drain(_ iterator: io_iterator_t) -> Bool {
        var found = false
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            IOObjectRelease(service)
            found = true
        }
        return found
    }
}
