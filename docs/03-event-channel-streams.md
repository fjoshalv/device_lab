# Task 3 — Streams: Live Sensor Dashboard

**Project:** `device_lab` · **Module:** Sensor Dashboard · **Difficulty:** ★★★☆☆ · **Est. time:** 3–4 h

## Why this exists

`MethodChannel` is request/response. Sensors, battery changes, connectivity, location — those are *continuous*, native-initiated flows, and polling them over a `MethodChannel` would be ugly and wasteful. `EventChannel` is the purpose-built tool: native pushes, Dart receives a `Stream`. The real subject of this task isn't sensors — it's **lifecycle**: streams that start when someone listens, stop when they cancel, and never leave a native listener running with nobody watching.

## Mental model (read before coding)

You have five years of `StreamController` in your fingers. Use them: **`EventChannel`'s platform-side `StreamHandler` is `StreamController(onListen:, onCancel:)` stretched across the bridge.**

| You already know (Dart) | Same idea, across the bridge |
|---|---|
| `StreamController(onListen: start, onCancel: stop)` | `StreamHandler.onListen` / `onCancel` (Kotlin & Swift) |
| `controller.add(event)` | `sink.success(event)` — Android `EventSink`, iOS `FlutterEventSink` |
| `controller.addError(e)` | `sink.error(code, msg, details)` → stream error in Dart |
| `controller.close()` | `sink.endOfStream()` / send `FlutterEndOfEventStream` → `onDone` |

The choreography: Dart calls `EventChannel('name').receiveBroadcastStream(args)` and gets a broadcast `Stream`. When the **first** Dart listener subscribes, the platform's `onListen(args, sink)` runs — that's your cue to start the sensor and keep the sink. When the **last** listener cancels, `onCancel` runs — your one and only cue to unregister the sensor. `onListen` and `onCancel` are resource brackets. Everything you acquire in one, you release in the other; forget the release and you've built a battery-draining leak that shows no error anywhere.

Under the hood it's still the same `BinaryMessenger` from Task 1 — `EventChannel` is just a different protocol on the same postal service, which is why the main-thread law from Task 2 applies unchanged: **`sink.success` must be called on the platform main thread.**

One more thing channels can't hide: **platforms disagree about data.** Android's accelerometer reports m/s² (≈9.81 on z at rest, gravity included); iOS reports g-units (≈1.0 at rest). Your Dart contract picks one unit — m/s² — and each platform converts *before* the sink. The Dart layer must never know which platform it's on; enforcing that at the boundary is the design habit this task drills.

## Build milestones

**M1 — Fake ticker (mechanics without sensors).** Channel `devicelab/accelerometer` — but don't touch sensors yet. In `onListen`, start a repeating timer natively (Android: `Handler(Looper.getMainLooper()).postDelayed` loop; iOS: `Timer.scheduledTimer`) emitting an incrementing int every 500 ms; stop it in `onCancel`. Dart: `receiveBroadcastStream().listen(print)`.
*Done when:* numbers tick in the Flutter console on both platforms, and stopping the subscription stops the native logs. You now understand `EventChannel` completely; everything after is sensor API details.

**M2 — Real accelerometer, Android.** Replace the timer with `SensorManager` + `SensorEventListener`: register in `onListen`, unregister in `onCancel`, emit `[x, y, z]` as a `List<Double>`. Add permanent log lines inside `onListen`/`onCancel` — they're your lifecycle proof for the rest of the task.
*Done when:* live values flow (emulator: Extended controls ▸ Virtual sensors ▸ move the phone) and leaving the screen prints the cancel log.

**M3 — iOS + unit normalization.** `CMMotionManager.startAccelerometerUpdates(to: .main)` in `onListen`, `stopAccelerometerUpdates()` in `onCancel`, **multiply by 9.81**. The manager must be a stored property — a local is deallocated when `onListen` returns and the stream silently dies. iOS Simulator has no accelerometer: make `onListen` return/emit an `UNAVAILABLE` error there and treat that as the milestone's test (the real-data check needs a physical iPhone).
*Done when:* a device at rest reads ≈9.8 magnitude on *both* platforms (unit proof), and the Simulator shows a clean error state in Dart.

**M4 — Subscription arguments.** `receiveBroadcastStream({'rate': 'ui' | 'game'})`; map natively to `SENSOR_DELAY_UI`/`SENSOR_DELAY_GAME` and `accelerometerUpdateInterval` 1/20 s vs 1/60 s. Args arrive as `onListen`'s first parameter.
*Done when:* switching rate visibly changes update frequency.

**M5 — Dashboard UI + lifecycle discipline.** Dart wrapper exposing `Stream<AccelReading>` (an `x,y,z` class). Screen: live numbers + a simple Flutter-drawn visualization (three bars is plenty). Pause/Resume button = cancel/resubscribe. Dispose cancels the subscription.
*Done when:* Pause prints the native cancel log, Resume prints listen (with args), navigating away prints cancel. If any of those logs is missing, you have the exact bug this task exists to teach.

## Hints

Dart:

```dart
class SensorsApi {
  static const _accel = EventChannel('devicelab/accelerometer');

  Stream<AccelReading> accelerometer({String rate = 'ui'}) =>
      _accel.receiveBroadcastStream({'rate': rate}).map((e) {
        final l = (e as List).cast<double>();
        return AccelReading(l[0], l[1], l[2]);
      });
}
```

Android handler shape (registered in `configureFlutterEngine` beside your Task 1–2 channels):

```kotlin
EventChannel(messenger, "devicelab/accelerometer").setStreamHandler(
  object : EventChannel.StreamHandler {
    private var listener: SensorEventListener? = null

    override fun onListen(args: Any?, sink: EventChannel.EventSink) {
      Log.d("DeviceLab", "accel onListen args=$args")
      val sm = getSystemService(SENSOR_SERVICE) as SensorManager
      val sensor = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        ?: return sink.error("UNAVAILABLE", "No accelerometer", null)
      val delay = if ((args as? Map<*, *>)?.get("rate") == "game")
        SensorManager.SENSOR_DELAY_GAME else SensorManager.SENSOR_DELAY_UI
      listener = object : SensorEventListener {
        override fun onSensorChanged(e: SensorEvent) =
          sink.success(e.values.map { it.toDouble() })      // already m/s²
        override fun onAccuracyChanged(s: Sensor?, a: Int) {}
      }
      sm.registerListener(listener, sensor, delay)
    }

    override fun onCancel(args: Any?) {
      Log.d("DeviceLab", "accel onCancel")
      val sm = getSystemService(SENSOR_SERVICE) as SensorManager
      listener?.let(sm::unregisterListener); listener = null
    }
  })
```

iOS — the queue does double duty (delivery *and* main-thread safety); note the property and the ×9.81:

```swift
class AccelStreamHandler: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()          // property, NOT a local

  func onListen(withArguments args: Any?,
                eventSink sink: @escaping FlutterEventSink) -> FlutterError? {
    guard motion.isAccelerometerAvailable else {
      return FlutterError(code: "UNAVAILABLE", message: "No accelerometer", details: nil)
    }
    motion.accelerometerUpdateInterval = 1.0 / 20.0   // derive from args
    motion.startAccelerometerUpdates(to: .main) { data, _ in
      guard let a = data?.acceleration else { return }
      sink([a.x * 9.81, a.y * 9.81, a.z * 9.81])
    }
    return nil
  }

  func onCancel(withArguments args: Any?) -> FlutterError? {
    motion.stopAccelerometerUpdates(); return nil
  }
}
```

## Gotchas (ordered by likelihood)

1. **Missing `onCancel` cleanup.** Nothing errors — the sensor just keeps running forever, invisibly. The #1 real-world `EventChannel` bug; your M2 log lines are the tripwire. If Pause doesn't print the cancel log, stop and fix before continuing.
2. **Emitting off the main thread.** Android default registration delivers on your (main) thread, iOS is safe because you chose `OperationQueue.main` — change either and you crash. Worth triggering once deliberately (emit from a `Thread {}`) to learn the error's face, then revert.
3. **iOS stream emits nothing, no error.** `CMMotionManager` was a local in `onListen` → deallocated → silence. Property.
4. **Args seem ignored.** They're delivered to `onListen` on the *first* subscription of the broadcast stream. Two simultaneous Dart listeners with different args don't get different rates — a real design limitation of one channel; know it exists.
5. **Hot restart leaves the sensor running.** Engine teardown doesn't reliably route through your `onCancel` during dev cycles. Full stop/rebuild while iterating on stream code.
6. **iOS magnitude ≈1.0 at rest.** You forgot ×9.81 — exactly what M3's check exists to catch.

## Check your understanding

1. Map each of these to its cross-bridge twin: `StreamController.onListen`, `controller.add`, `controller.addError`, `controller.close`.
2. Who *starts* the accelerometer — Dart, the engine, or your native code — and what exact event triggers it? Who stops it?
3. Three widgets listen to the same `receiveBroadcastStream` result. How many times does native `onListen` run? When does `onCancel` finally run?
4. Why did the iOS handler need `motion` as a property when the Android anonymous object could hold `listener` just fine? What was actually dying?
5. Your dashboard shows z ≈ 1.0 on iPhone and ≈ 9.8 on Pixel. Which layer failed, and why is "fix it in the Dart wrapper" the wrong answer under this curriculum's rules?
6. `MethodChannel` and `EventChannel` both ride the same `BinaryMessenger`. So what is `EventChannel`, really?

## Stretch goals

- Second stream: **battery state** — Android `BroadcastReceiver` on `ACTION_BATTERY_CHANGED`, iOS `NotificationCenter` + `UIDevice.batteryStateDidChangeNotification`. Different native source, identical handler pattern; the repetition is where it becomes permanent.
- Emit structured maps `{x, y, z, timestamp}` instead of lists.
- Graceful end-of-stream: a `stopAfterSeconds` arg, then `endOfStream` natively and observe Dart's `onDone` fire.

## Reading

- `EventChannel` API: https://api.flutter.dev/flutter/services/EventChannel-class.html
- Android sensors: https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview
- Core Motion: https://developer.apple.com/documentation/coremotion
- When stuck, study: `sensors_plus` source.
