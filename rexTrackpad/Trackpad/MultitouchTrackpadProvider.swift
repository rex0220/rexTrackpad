import AppKit

// MARK: - Provider

/// Reads raw finger data from Apple's private `MultitouchSupport.framework`.
///
/// This is the **only** place in rexTrackpad that touches a private API.
/// - The framework is loaded at runtime with `dlopen`, so a missing or changed
///   framework makes `start()` return `false` instead of crashing.
/// - It only *observes* touches. No event is consumed, blocked or modified, so
///   normal pointer / scroll / system gestures keep working.
/// - No TCC permission (Accessibility / Input Monitoring) is required for reading.
final class MultitouchTrackpadProvider: TrackpadInputProvider {
    var onFrame: ((TrackpadFrame) -> Void)?
    private(set) var isRunning = false

    private var devices: CFArray?
    private var workspaceObservers: [NSObjectProtocol] = []
    private let deliveryQueue = DispatchQueue(label: "io.github.rex0220.rexTrackpad.trackpad")

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard openDevices() else { return false }
        isRunning = true
        observeWorkspace()
        Log.trackpad.info("trackpad monitoring started")
        return true
    }

    func stop() {
        guard isRunning else { return }
        closeDevices()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        isRunning = false
        Log.trackpad.info("trackpad monitoring stopped")
    }

    // MARK: Devices

    private func openDevices() -> Bool {
        guard let api = MultitouchAPI.shared else {
            Log.trackpad.error("MultitouchSupport.framework is unavailable")
            return false
        }
        guard let list = api.createDeviceList(), CFArrayGetCount(list) > 0 else {
            Log.trackpad.error("no multitouch device found")
            return false
        }

        MultitouchFrameRouter.shared.setHandler { [weak self] frame in
            guard let self = self else { return }
            self.deliveryQueue.async { self.onFrame?(frame) }
        }

        for index in 0..<CFArrayGetCount(list) {
            guard let device = CFArrayGetValueAtIndex(list, index) else { continue }
            let ref = UnsafeMutableRawPointer(mutating: device)
            api.registerContactFrameCallback(ref, multitouchContactCallback)
            _ = api.deviceStart(ref, 0)
        }
        devices = list
        Log.trackpad.info("opened \(CFArrayGetCount(list)) multitouch device(s)")
        return true
    }

    private func closeDevices() {
        guard let api = MultitouchAPI.shared, let list = devices else { return }
        for index in 0..<CFArrayGetCount(list) {
            guard let device = CFArrayGetValueAtIndex(list, index) else { continue }
            let ref = UnsafeMutableRawPointer(mutating: device)
            api.unregisterContactFrameCallback(ref, multitouchContactCallback)
            _ = api.deviceStop(ref)
        }
        MultitouchFrameRouter.shared.setHandler(nil)
        devices = nil
    }

    /// Multitouch devices stop delivering frames after sleep and fast user switching,
    /// so the device list is reopened when the session comes back.
    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification]
        workspaceObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.reopenDevices() }
            }
        }
    }

    private func reopenDevices() {
        guard isRunning else { return }
        Log.trackpad.info("reopening multitouch devices after wake")
        closeDevices()
        if !openDevices() {
            Log.trackpad.error("failed to reopen multitouch devices")
        }
    }
}

// MARK: - Frame routing

/// C callbacks cannot capture context, so frames are routed through this object.
private final class MultitouchFrameRouter {
    static let shared = MultitouchFrameRouter()

    private let lock = NSLock()
    private var handler: ((TrackpadFrame) -> Void)?

    func setHandler(_ handler: ((TrackpadFrame) -> Void)?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    /// Called on the framework's internal thread. Copies the data before returning.
    func handle(device: UnsafeMutableRawPointer?, touches: UnsafeMutableRawPointer?, count: Int, timestamp: Double) {
        lock.lock()
        let handler = self.handler
        lock.unlock()
        guard let handler = handler else { return }

        let frame = TrackpadFrame(
            deviceID: device.map { Int(bitPattern: $0) } ?? 0,
            timestamp: timestamp,
            touches: MultitouchRawTouch.parse(touches, count: count),
            isButtonPressed: NSEvent.pressedMouseButtons != 0
        )
        handler(frame)
    }
}

private let multitouchContactCallback: MultitouchAPI.ContactCallback = { device, touches, count, timestamp, _ in
    MultitouchFrameRouter.shared.handle(device: device, touches: touches, count: Int(count), timestamp: timestamp)
    return 0
}

// MARK: - Raw data layout

/// Memory layout of one touch record delivered by MultitouchSupport
/// (reverse engineered and stable since Mac OS X 10.5; Apple Silicon included):
///
///     offset  type     field
///      0      Int32    frame
///      8      Double   timestamp
///     16      Int32    identifier
///     20      Int32    state
///     24      Int32    fingerID
///     28      Int32    handID
///     32      Float    normalized.position.x
///     36      Float    normalized.position.y
///     40      Float    normalized.velocity.x
///     44      Float    normalized.velocity.y
///     48      Float    size (zDensity)
///     ...              angle, axes, absolute position, ...
///     96               (record size)
///
/// Fields are read by explicit offset rather than via a Swift struct, because
/// Swift does not guarantee C struct layout.
private enum MultitouchRawTouch {
    static let recordSize = 96
    static let identifierOffset = 16
    static let stateOffset = 20
    static let normalizedXOffset = 32
    static let normalizedYOffset = 36

    /// Touch states: 1 starting, 2 hovering, 3 making contact, 4 touching,
    /// 5 breaking contact, 6 lingering, 7 leaving. Only 3...5 are on the surface.
    static let touchingStates: ClosedRange<Int32> = 3...5

    /// Upper bound so a corrupted count can never read out of bounds of a sane buffer.
    static let maximumTouches = 20

    static func parse(_ base: UnsafeMutableRawPointer?, count: Int) -> [TouchPoint] {
        guard let base = base, count > 0 else { return [] }
        var result: [TouchPoint] = []
        result.reserveCapacity(min(count, maximumTouches))
        for index in 0..<min(count, maximumTouches) {
            let record = UnsafeRawPointer(base) + index * recordSize
            let state = record.load(fromByteOffset: stateOffset, as: Int32.self)
            guard touchingStates.contains(state) else { continue }
            result.append(TouchPoint(
                id: Int(record.load(fromByteOffset: identifierOffset, as: Int32.self)),
                x: Double(record.load(fromByteOffset: normalizedXOffset, as: Float.self)),
                y: Double(record.load(fromByteOffset: normalizedYOffset, as: Float.self))
            ))
        }
        return result
    }
}

// MARK: - Dynamic symbol loading

/// Function pointers resolved from MultitouchSupport.framework at runtime.
private struct MultitouchAPI {
    typealias DeviceRef = UnsafeMutableRawPointer
    typealias ContactCallback = @convention(c) (
        _ device: UnsafeMutableRawPointer?,
        _ touches: UnsafeMutableRawPointer?,
        _ count: Int32,
        _ timestamp: Double,
        _ frame: Int32
    ) -> Int32

    let createDeviceList: () -> CFArray?
    let registerContactFrameCallback: (DeviceRef, ContactCallback) -> Void
    let unregisterContactFrameCallback: (DeviceRef, ContactCallback) -> Void
    let deviceStart: (DeviceRef, Int32) -> Int32
    let deviceStop: (DeviceRef) -> Int32

    static let shared: MultitouchAPI? = MultitouchAPI()

    private init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY) else { return nil }

        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else {
                Log.trackpad.error("missing MultitouchSupport symbol \(name, privacy: .public)")
                return nil
            }
            return unsafeBitCast(pointer, to: type)
        }

        typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
        typealias Register = @convention(c) (DeviceRef, ContactCallback) -> Void
        typealias Start = @convention(c) (DeviceRef, Int32) -> Int32
        typealias Stop = @convention(c) (DeviceRef) -> Int32

        guard
            let createList = symbol("MTDeviceCreateList", as: CreateList.self),
            let register = symbol("MTRegisterContactFrameCallback", as: Register.self),
            let unregister = symbol("MTUnregisterContactFrameCallback", as: Register.self),
            let start = symbol("MTDeviceStart", as: Start.self),
            let stop = symbol("MTDeviceStop", as: Stop.self)
        else { return nil }

        createDeviceList = { createList()?.takeRetainedValue() }
        registerContactFrameCallback = { register($0, $1) }
        unregisterContactFrameCallback = { unregister($0, $1) }
        deviceStart = { start($0, $1) }
        deviceStop = { stop($0) }
    }
}
