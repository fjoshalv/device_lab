# Task 1 — First Bridge: Device Info via MethodChannel

**Project:** `device_lab` · **Module:** Device Info · **Difficulty:** ★☆☆☆☆ · **Est. time:** 2–3 h

## Why this exists

Flutter can't read the battery level. Neither can Dart. That number lives behind platform APIs — `BatteryManager` on Android, `UIDevice` on iOS — and the only way to reach them is to write Kotlin/Swift and build a bridge to it. `MethodChannel` is that bridge for one-shot, request/response calls, and it's the foundation everything else in this curriculum stands on.

## Mental model (read before coding)

Think of the Flutter engine as sitting between two worlds: your Dart isolate and the host platform. They can't call each other's functions directly — different runtimes, different threads. What they *can* do is pass **messages** through the engine's `BinaryMessenger`, which works like a postal service: messages are addressed to a named channel, and whoever registered a handler for that name receives them.

A `MethodChannel` is a thin convention on top of that postal service:

```
Dart                                   Platform (Kotlin/Swift)
────                                   ───────────────────────
invokeMethod('getBatteryLevel')  ──►   handler receives call.method + call.arguments
        (Future is pending...)         does work
Future completes with value      ◄──   result.success(87)   ← exactly once
```

Three things fall out of this model, and they explain almost every behavior you'll see:

1. **The name is the contract.** Both sides construct a channel with the same string (`devicelab/device_info`). A one-character mismatch means the message is delivered to nobody → Dart gets a `MissingPluginException`. There's no compiler checking this — that pain is deliberate here; Task 5 (Pigeon) is the cure, and you'll appreciate it more for having felt this.
2. **Everything is async in Dart**, even if the native work is instant, because the request/response is a message round trip. `invokeMethod` always returns a `Future`.
3. **Data is serialized**, not shared. The `StandardMessageCodec` carries: `null`, `bool`, `int`, `double`, `String`, byte buffers (`Uint8List` etc.), `List`, `Map`. Nothing else. On the far side those become platform types — Dart `int` → Kotlin `Int`/`Long` (depending on size) / Swift `NSNumber`; `Map` → `HashMap` / `NSDictionary`. When you cast on either side, this table is what you're casting against.

Where does your native code live? For app-level integration (tasks 1–4) it goes where the engine is configured: `MainActivity.configureFlutterEngine` on Android, `AppDelegate.didFinishLaunchingWithOptions` on iOS. You'll graduate to proper plugin classes in Task 5.

## Build milestones

Work them in order; each is a small, verifiable win.

**M1 — Ping.** Create the `device_lab` app (home `ListView` + empty Device Info screen). Register channel `devicelab/device_info` on Android only, handling one method `ping` that returns the hardcoded string `"pong from Android"`. Call it from Dart on screen load and display the result.
*Done when:* the string appears in your Flutter UI. You've crossed the bridge.

**M2 — Ping, iOS.** Same channel, same method, in `AppDelegate.swift`, returning `"pong from iOS"`.
*Done when:* same screen, both platforms, different string. Notice what was identical (Dart side: nothing changed) and what wasn't — that's the pattern for every task.

**M3 — Real data.** Replace ping with two real methods: `getDeviceInfo` returning a `Map` (`model`, `osVersion`, plus `manufacturer` on Android / `systemName` on iOS) and `getBatteryLevel` returning an `int` 0–100. Android: `Build.*` constants, `BatteryManager`. iOS: `UIDevice`.
*Done when:* real values render on both platforms.

**M4 — Break it, twice, on purpose.** (a) From Dart, invoke a method name you never implemented; observe the `MissingPluginException`... then make native answer `result.notImplemented()` for unknown names and observe it's the *same* exception — now you know what that error means forever. (b) On iOS Simulator, `batteryLevel` is `-1`: detect it natively and reply with `result.error`/`FlutterError` code `"UNAVAILABLE"`, catch the `PlatformException` in Dart, show a friendly message.
*Done when:* both failure paths are handled and you've read both error messages carefully.

**M5 — Clean it up.** Wrap the channel in a `DeviceInfoApi` class; the UI imports that, never `package:flutter/services.dart`. Add a refresh button.
*Done when:* the screen's widget file has zero channel code in it.

## Hints

Dart wrapper (note `invokeMapMethod` — it deep-casts collections for you):

```dart
import 'package:flutter/services.dart';

class DeviceInfoApi {
  static const _ch = MethodChannel('devicelab/device_info');

  Future<Map<String, String>> getDeviceInfo() async =>
      (await _ch.invokeMapMethod<String, String>('getDeviceInfo'))!;

  Future<int> getBatteryLevel() async =>
      (await _ch.invokeMethod<int>('getBatteryLevel'))!;
}
```

Android — `MainActivity.kt`:

```kotlin
class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "devicelab/device_info")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getDeviceInfo" -> result.success(mapOf(
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "osVersion" to Build.VERSION.RELEASE,
          ))
          "getBatteryLevel" -> {
            val bm = getSystemService(BATTERY_SERVICE) as BatteryManager
            result.success(bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY))
          }
          else -> result.notImplemented()
        }
      }
  }
}
```

iOS — inside `application(_:didFinishLaunchingWithOptions:)`, before the `return`:

```swift
let controller = window?.rootViewController as! FlutterViewController
let channel = FlutterMethodChannel(
  name: "devicelab/device_info",
  binaryMessenger: controller.binaryMessenger)

channel.setMethodCallHandler { call, result in
  switch call.method {
  case "getBatteryLevel":
    UIDevice.current.isBatteryMonitoringEnabled = true
    let level = UIDevice.current.batteryLevel
    if level < 0 {
      result(FlutterError(code: "UNAVAILABLE",
                          message: "Battery level not available", details: nil))
    } else {
      result(Int(level * 100))
    }
  // "getDeviceInfo" — your turn: UIDevice.current.model / .systemName / .systemVersion
  default:
    result(FlutterMethodNotImplemented)
  }
}
```

## Gotchas (ordered by likelihood)

1. **Edited Kotlin/Swift, nothing changed.** Hot reload/restart never rebuilds native code. Stop, `flutter run` again. You will do this wrong at least once this week; that's normal.
2. **`MissingPluginException` on a method you did implement.** Channel-name typo (byte-for-byte match required), or the handler registration never ran (forgot `super.configureFlutterEngine`, or the code is in the wrong lifecycle method).
3. **Cast errors in Dart.** `invokeMethod` returns `dynamic`. For maps/lists use `invokeMapMethod`/`invokeListMethod`; for scalars, the generic `invokeMethod<int>` plus a null check.
4. **`result` called twice → "Reply already submitted" crash.** Impossible to trigger in this task's straight-line code, but say it out loud now: *every invocation answers exactly once.* Task 2 is built around this rule.
5. **iOS: crash unwrapping `rootViewController`.** Grab it inside `didFinishLaunchingWithOptions` (the template's structure) — earlier and the window may not exist.

## Check your understanding

Answer from memory; verify by experiment or the mental-model section. If any answer is shaky, you'll pay interest on it in Tasks 2–5.

1. Dart calls `invokeMethod('getBatteryLevel')` but native registered the channel as `devicelab/device-info` (dash, not underscore). What exactly happens, and what does Dart see?
2. Why does `invokeMethod` return a `Future` even when the native handler answers instantly and synchronously?
3. Name the complete set of Dart types the standard codec can carry. What do a Dart `Map` and `int` become in Kotlin?
4. Where, precisely, did your handler-registration code run in the app lifecycle — and why would putting it in a random Activity method later break?
5. You changed a Kotlin string and pressed hot restart. What does the app show, and why?

## Stretch goals

- Return the precise iOS hardware identifier (e.g. `iPhone16,1`) via `utsname` — your first taste of C from Swift, a wink at Task 6.
- Add `isPhysicalDevice` (Android: sniff `Build.FINGERPRINT` for `generic`; iOS: `#if targetEnvironment(simulator)`).
- **Reverse the arrow:** channels are symmetric — set a `setMethodCallHandler` on the Dart side and have native invoke `onNativeReady` into it during engine configuration. Ten minutes now, and Task 3's direction of flow will already feel familiar.

## Reading

- Platform channels (the one official page to read fully): https://docs.flutter.dev/platform-integration/platform-channels
- When stuck, study: `battery_plus` source on pub.dev.
