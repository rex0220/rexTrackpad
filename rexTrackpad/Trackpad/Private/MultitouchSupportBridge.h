//
//  MultitouchSupportBridge.h
//  rexTrackpad
//
//  ⚠️ PRIVATE API — MultitouchSupport.framework is NOT a public Apple API.
//
//  These declarations describe the reverse-engineered, widely documented layout of
//  MultitouchSupport's contact data. They are written independently for rexTrackpad.
//  Nothing here is linked at build time: the functions are resolved at runtime with
//  dlopen/dlsym by MultitouchTrackpadProvider.swift, which is the ONLY file allowed
//  to use these types. If Apple changes the layout, only that file and this header
//  need to change.
//

#ifndef REX_MULTITOUCH_SUPPORT_BRIDGE_H
#define REX_MULTITOUCH_SUPPORT_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    float x;
    float y;
} RexMTPoint;

typedef struct {
    RexMTPoint position;
    RexMTPoint velocity;
} RexMTVector;

/// One contact. 96 bytes on 64-bit (arm64 / x86_64).
typedef struct {
    int32_t frame;
    double timestamp;
    int32_t pathIndex;      // stable per-contact identifier
    int32_t state;          // 1 starting, 2 hovering, 3 making touch, 4 touching, 5 breaking, 6 lingering, 7 leaving
    int32_t fingerID;
    int32_t handID;
    RexMTVector normalized; // 0...1, origin bottom-left
    float zTotal;           // contact size / capacitance
    int32_t unknown1;
    float angle;
    float majorAxis;
    float minorAxis;
    RexMTVector absolute;   // millimetres
    int32_t unknown2;
    int32_t unknown3;
    float zDensity;
} RexMTTouch;

typedef void *RexMTDeviceRef;

/// Contact-frame callback. The return value is ignored by the framework.
typedef int (*RexMTContactCallback)(RexMTDeviceRef device,
                                    const RexMTTouch *touches,
                                    int32_t touchCount,
                                    double timestamp,
                                    int32_t frame);

// Function signatures resolved with dlsym().
typedef void *(*RexMTDeviceCreateListFn)(void);  // returns CFArrayRef of MTDeviceRef
typedef void (*RexMTRegisterContactFrameCallbackFn)(RexMTDeviceRef device, RexMTContactCallback callback);
typedef void (*RexMTUnregisterContactFrameCallbackFn)(RexMTDeviceRef device, RexMTContactCallback callback);
typedef void (*RexMTDeviceStartFn)(RexMTDeviceRef device, int32_t mode);
typedef void (*RexMTDeviceStopFn)(RexMTDeviceRef device);
typedef bool (*RexMTDeviceIsBuiltInFn)(RexMTDeviceRef device);

#endif /* REX_MULTITOUCH_SUPPORT_BRIDGE_H */
