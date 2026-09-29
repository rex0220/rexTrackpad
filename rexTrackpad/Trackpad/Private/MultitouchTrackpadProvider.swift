import AppKit
import Darwin
import Foundation

// ============================================================================
//  ⚠️ PRIVATE API BOUNDARY ⚠️
//
//  This is the only file in rexTrackpad that uses MultitouchSupport.framework.
//  - The framework is loaded at runtime with dlopen(); nothing links against it,
//    so the app still launches (with monitoring "unavailable") if it disappears.
//  - Everything outside this file sees only `TrackpadInputProvider`,
//    `TrackpadFrame` and `TouchPoint`.
//  - The framework only *observes* contacts. It never consumes events, so macOS
//    gestures, clicks and scrolling keep working normally.
// ============================================================================

/// Runtime-resolved MultitouchSupport entry points.
private struct MultitouchFramework {
    static let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"

    let createDeviceList: RexMTDeviceCreateListFn
    let registerCallback: RexMTRegisterContactFrameCallbackFn
    let unregisterCallback: RexMTUnregisterContactFrameCallbackFn
    let startDevice: RexMTDeviceStartFn
    let stopDevice: RexMTDeviceStopFn
    let isBuiltIn: RexMTDeviceIsBuiltInFn?

    static func load() -> MultitouchFramework? {
        guard let handle = dlopen(path, RTLD_NOW) else {
            let reason = dlerror().map { String(cString: $0) } ?? "unknown error"
            Log.trackpad.error("dlopen MultitouchSupport failed: \(reason, privacy: .public)")
            return nil
        }

        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else {
                Log.trackpad.error("MultitouchSupport symbol missing: \(name, privacy: .public)")
                return nil
            }
            return unsafeBitCast(pointer, to: type)
        }

        guard
            let createDeviceList = symbol("MTDeviceCreateList", as: RexMTDeviceCreateListFn.self),
            let registerCallback = symbol("MTRegisterContactFrameCallback", as: RexMTRegisterContactFrameCallbackFn.self),
            let unregisterCallback = symbol("MTUnregisterContactFrameCallback", as: RexMTUnregisterContactFrameCallbackFn.self),
            let startDevice = symbol("MTDeviceStart", as: RexMTDeviceStartFn.self),
            let stopDevice = symbol("MTDeviceStop", as: RexMTDeviceStopFn.self)
        else {
            return nil
        }

        return MultitouchFramework(
            createDeviceList: createDeviceList,
            registerCallback: registerCallback,
            unregisterCallback: unregisterCallback,
            startDevice: startDevice,
            stopDevice: stopDevice,
            isBuiltIn: symbol("MTDeviceIsBuiltIn", as: RexMTDeviceIsBuiltInFn.self)
        )
    }
}

/// C callback registered with MultitouchSupport. Invoked on a framework-owned thread.
private let rexContactFrameCallback: RexMTContactCallback = { device, touches, touchCount, timestamp, _ in
    MultitouchTrackpadProvider.receiveFrame(device: device, touches: touches, touchCount: touchCount, timestamp: timestamp)
    return 0
}

/// `TrackpadInputProvider` backed by the private MultitouchSupport.framework.
final class MultitouchTrackpadProvider: TrackpadInputProvider {
    var onFrame: ((TrackpadFrame) -> Void)?
    var onStateChange: ((TrackpadInputState) -> Void)?

    private(set) var state: TrackpadInputState = .stopped {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }

    var framesReceived: UInt64 {
        statsLock.lock()
        defer { statsLock.unlock() }
        return frameCount
    }

    private lazy var framework: MultitouchFramework? = MultitouchFramework.load()
    private var deviceList: CFArray?
    private var devices: [RexMTDeviceRef] = []
    private let deviceWatcher = MultitouchDeviceWatcher()
    private var wakeObserver: NSObjectProtocol?
    private var restartWorkItem: DispatchWorkItem?

    private let statsLock = NSLock()
    private var frameCount: UInt64 = 0

    // The C callback cannot capture context, so frames are routed through the
    // single active provider.
    private static let activeLock = NSLock()
    private static weak var activeProvider: MultitouchTrackpadProvider?

    init() {}

    deinit {
        restartWorkItem?.cancel()
    }

    // MARK: - TrackpadInputProvider

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !state.isRunning else { return }

        guard let framework else {
            state = .unavailable(reason: "MultitouchSupport.framework could not be loaded")
            return
        }
        guard let rawList = framework.createDeviceList() else {
            state = .unavailable(reason: "No multitouch devices found")
            return
        }

        // Ownership of the returned array is undocumented; take it unretained so an
        // unexpected +0 return can never cause an over-release.
        let list = Unmanaged<CFArray>.fromOpaque(rawList).takeUnretainedValue()
        deviceList = list
        Self.setActive(self)

        var started: [RexMTDeviceRef] = []
        for index in 0..<CFArrayGetCount(list) {
            guard let value = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: value)
            framework.registerCallback(device, rexContactFrameCallback)
            framework.startDevice(device, 0)
            started.append(device)
            let builtIn = framework.isBuiltIn?(device) ?? false
            Log.trackpad.info("multitouch device started (built-in: \(builtIn, privacy: .public))")
        }
        devices = started
        installObservers()

        if started.isEmpty {
            state = .unavailable(reason: "No multitouch devices found")
            Log.trackpad.notice("trackpad monitoring started, but no devices were found")
        } else {
            state = .running(deviceCount: started.count)
            Log.trackpad.notice("trackpad monitoring started (\(started.count, privacy: .public) device(s))")
        }
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        restartWorkItem?.cancel()
        restartWorkItem = nil
        removeObservers()

        if let framework {
            for device in devices {
                framework.unregisterCallback(device, rexContactFrameCallback)
                framework.stopDevice(device)
            }
        }
        let wasRunning = !devices.isEmpty
        devices = []
        deviceList = nil
        Self.clearActive(self)

        if wasRunning {
            Log.trackpad.notice("trackpad monitoring stopped")
        }
        if case .unavailable = state {
            return
        }
        state = .stopped
    }

    // MARK: - Restart handling (sleep/wake, device hot-plug)

    private func installObservers() {
        deviceWatcher.onChange = { [weak self] in
            Log.trackpad.info("multitouch device added/removed; restarting")
            self?.scheduleRestart(after: 1.0)
        }
        deviceWatcher.start()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.trackpad.info("system woke; restarting trackpad monitoring")
            self?.scheduleRestart(after: 1.5)
        }
    }

    private func removeObservers() {
        deviceWatcher.stop()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
    }

    private func scheduleRestart(after delay: TimeInterval) {
        restartWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.stop()
            self.start()
        }
        restartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    // MARK: - Frame routing

    private static func setActive(_ provider: MultitouchTrackpadProvider) {
        activeLock.lock()
        activeProvider = provider
        activeLock.unlock()
    }

    private static func clearActive(_ provider: MultitouchTrackpadProvider) {
        activeLock.lock()
        if activeProvider === provider {
            activeProvider = nil
        }
        activeLock.unlock()
    }

    /// Called from `rexContactFrameCallback` on a MultitouchSupport thread.
    fileprivate static func receiveFrame(
        device: RexMTDeviceRef?,
        touches: UnsafePointer<RexMTTouch>?,
        touchCount: Int32,
        timestamp: Double
    ) {
        activeLock.lock()
        let provider = activeProvider
        activeLock.unlock()
        guard let provider, let handler = provider.onFrame else { return }

        var points: [TouchPoint] = []
        if let touches, touchCount > 0 {
            points.reserveCapacity(Int(touchCount))
            for index in 0..<Int(touchCount) {
                let raw = touches[index]
                guard let phase = TouchPoint.Phase(multitouchState: raw.state) else { continue }
                points.append(TouchPoint(
                    id: Int(raw.pathIndex),
                    position: CGPoint(x: CGFloat(raw.normalized.position.x), y: CGFloat(raw.normalized.position.y)),
                    phase: phase,
                    size: Double(raw.zTotal)
                ))
            }
        }

        provider.statsLock.lock()
        provider.frameCount &+= 1
        provider.statsLock.unlock()

        handler(TrackpadFrame(timestamp: timestamp, deviceID: Int(bitPattern: device), touches: points))
    }
}

private extension TouchPoint.Phase {
    /// Maps MultitouchSupport's contact state to the public `Phase`.
    init?(multitouchState: Int32) {
        switch multitouchState {
        case 3: self = .began
        case 4: self = .touching
        case 5: self = .ended
        case 1, 2, 6, 7: self = .hovering
        default: return nil
        }
    }
}
