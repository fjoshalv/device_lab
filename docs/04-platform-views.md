# Task 4 — Native UI: Embedded Video Player (Platform Views)

**Project:** `device_lab` · **Module:** Native Player · **Difficulty:** ★★★★☆ · **Est. time:** 6–8 h

## Why this exists

Everything so far moved *data* across the bridge. Sometimes you need to move *UI*: Google Maps, WebViews, ad SDKs, DRM video — native views you can't or shouldn't reimplement in Flutter. Platform views are the mechanism, and they're famously Flutter's sharpest edge: powerful, expensive, quirky. Understanding them deeply — including *when not to use them* — is senior-level Flutter knowledge, and it's exactly why this is the capstone of the app-side tasks.

## Mental model (read before coding)

Flutter normally owns every pixel: widgets → render tree → Skia/Impeller draws the whole frame. A platform view breaks that monopoly — the framework reserves a rectangle in its scene and composites a *real* `android.view.View` / `UIView` into it. Native view and Flutter painting must be layered together every frame, which is why platform views cost real performance and why Android has grown several composition strategies over the years (virtual displays, hybrid composition, texture-layer variants), each trading speed against fidelity (keyboard, accessibility, `SurfaceView`s). Don't memorize the current default — know the trade-offs exist and check the docs for your Flutter version when behavior surprises you.

The choreography has five pieces; keep this diagram beside you all task:

```
Dart                                        Native
────                                        ──────
AndroidView / UiKitView(                    1. PlatformViewFactory registered once
  viewType: 'devicelab/native_video', ───►     under that same viewType string
  creationParams: {'url': ...},             2. factory.create(context, viewId, params)
  creationParamsCodec: Standard...,            → constructs YOUR PlatformView instance
  onPlatformViewCreated: (id) { ... }       3. instance wraps the real View/UIView
)                                              and returns it via getView()/view()
        │                                   4. instance opens its OWN channel:
        └── open MethodChannel(                  'devicelab/native_video_<viewId>'
             'devicelab/native_video_$id')  5. dispose() ← release everything here
```

Three ideas carry the task:

1. **Factory → instances.** You register a *factory* once per `viewType`; every `AndroidView`/`UiKitView` in a widget tree asks it for a fresh instance. Both sides see the same `viewId` (Flutter hands it to `onPlatformViewCreated`; the factory receives it in `create`).
2. **Per-view channels.** A single shared channel can't tell two players apart. Suffixing the channel name with the shared `viewId` gives every embedded view a private control line — the standard idiom in every real platform-view plugin.
3. **`dispose()` is a contract.** Flutter tells you the view left the tree; releasing the media player, stopping audio, and unhooking the channel handler is *your* job. Skip it and audio plays over the next screen — the most audible bug in Flutter.

`creationParams` ride a codec (the same standard codec family) so initial config arrives *at construction time* — no awkward "create empty, then configure over the channel" dance.

## Build milestones

**M1 — Hello, native label (Android).** Before any video: a `PlatformView` wrapping a plain `TextView` ("Hello from Android"), a `PlatformViewFactory`, registration via `flutterEngine.platformViewsController.registry.registerViewFactory(...)`, and an `AndroidView(viewType: ...)` in a sized box in your Flutter screen.
*Done when:* native-rendered text sits inside your Flutter layout. All platform-view plumbing now exists with zero video complexity.

**M2 — Hello, native label (iOS).** `FlutterPlatformView` wrapping a `UILabel`, a factory implementing **`createArgsCodec`** (required even before you use params — do it now), registration via `self.registrar(forPlugin: "NativeVideo")` in `AppDelegate`, `UiKitView` in Dart (branch on `Platform.isIOS`).
*Done when:* same screen shows a native label on both platforms.

**M3 — creationParams.** The label's text comes from Dart: `creationParams: {'text': ...}` + `creationParamsCodec: const StandardMessageCodec()`; decode in the factory/view constructor.
*Done when:* changing the Dart string changes the native label. Config-at-birth: proven.

**M4 — Label → video.** Swap the `TextView` for a `VideoView` (Android) and the `UILabel` for a `UIView` hosting an `AVPlayerLayer` (iOS); `creationParams` now carry `{'url': ...}`. Use `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4` (or bundle a small asset — see Gotcha 6). Autoplay on ready.
*Done when:* video plays inside the Flutter screen on both platforms.

**M5 — Per-view controls.** Native: inside the view class, open `MethodChannel(messenger, "devicelab/native_video_$viewId")` handling `play`, `pause`, `seekTo(ms)`, `getPosition`, `getDuration`. Dart: bind the matching channel in `onPlatformViewCreated`, build a controls row (play/pause toggle, seek slider, position label; poll position with a periodic timer while playing).
*Done when:* Flutter buttons drive the native player and the slider tracks honestly.

**M6 — Prove the hard parts.** (a) *Compositing:* overlay a semi-transparent Flutter badge on the video via a `Stack` — Flutter pixels above native pixels is the whole point. (b) *Dispose:* release the player in `dispose()` (Android) / `deinit` (iOS), nil the channel handler; navigate away mid-playback → silence. (c) *Independence:* put **two** players on one screen; each obeys only its own controls.
*Done when:* all three checks pass. (b) failing is the classic; (c) failing means a channel-naming bug.

## Hints

Dart:

```dart
AndroidView(                                  // UiKitView on iOS
  viewType: 'devicelab/native_video',
  creationParams: {'url': widget.url},
  creationParamsCodec: const StandardMessageCodec(),
  onPlatformViewCreated: (id) =>
      controller.attach(MethodChannel('devicelab/native_video_$id')),
)
```

Android — factory + view in one file:

```kotlin
class NativeVideoFactory(private val messenger: BinaryMessenger) :
  PlatformViewFactory(StandardMessageCodec.INSTANCE) {          // codec to super!
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
    NativeVideoView(context, viewId, args as? Map<*, *>, messenger)
}

class NativeVideoView(context: Context, viewId: Int, args: Map<*, *>?,
                      messenger: BinaryMessenger) : PlatformView {
  private val video = VideoView(context).apply {
    setVideoURI(Uri.parse(args?.get("url") as String))
    setOnPreparedListener { it.start() }
  }
  private val channel = MethodChannel(messenger, "devicelab/native_video_$viewId").apply {
    setMethodCallHandler { call, result ->
      when (call.method) {
        "play" -> { video.start(); result.success(null) }
        "pause" -> { video.pause(); result.success(null) }
        "seekTo" -> { video.seekTo(call.argument<Int>("ms")!!); result.success(null) }
        "getPosition" -> result.success(video.currentPosition)
        "getDuration" -> result.success(video.duration)
        else -> result.notImplemented()
      }
    }
  }
  override fun getView(): View = video
  override fun dispose() { video.stopPlayback(); channel.setMethodCallHandler(null) }
}
```

Registration (in `configureFlutterEngine`):

```kotlin
flutterEngine.platformViewsController.registry.registerViewFactory(
  "devicelab/native_video",
  NativeVideoFactory(flutterEngine.dartExecutor.binaryMessenger))
```

iOS — the two pieces that trip everyone:

```swift
// 1. Without this, creationParams arrive as nil:
func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
  FlutterStandardMessageCodec.sharedInstance()
}

// 2. A UIView whose backing layer IS the player layer — no manual frame syncing:
class PlayerContainerView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
```

Registration in `AppDelegate`:

```swift
let registrar = self.registrar(forPlugin: "NativeVideo")!
registrar.register(NativeVideoFactory(messenger: registrar.messenger()),
                   withId: "devicelab/native_video")
```

iOS player bits: `AVPlayer(url:)`, `play()/pause()`, seek via `player.seek(to: CMTimeMake(value: ms, timescale: 1000))`, position `player.currentTime()`, duration `player.currentItem?.duration` — guard `isNumeric`; it's NaN until the item loads.

Layout: give the view an `AspectRatio(aspectRatio: 16/9)` inside the normal column — platform views need real constraints.

## Gotchas (ordered by likelihood)

1. **Audio continues after leaving the screen.** `dispose()`/`deinit` didn't release the player (or something retains the `AVPlayer`). The most common — and most audible — platform-view bug in production apps.
2. **iOS `creationParams` is nil.** Missing `createArgsCodec()`. Android mirror image: forgot `StandardMessageCodec.INSTANCE` in the factory's `super` call.
3. **"Trying to create a platform view of unregistered type."** Registration never ran on that platform, or the `viewType` strings differ.
4. **Controls drive the wrong player / nothing.** Channel-name mismatch — log the `viewId` on both sides once and compare.
5. **iOS duration NaN / early seek fails.** `AVPlayer` loads async; return 0 until ready and let Dart retry.
6. **Black rectangle on Android emulator.** Emulator video decoding is flaky with `VideoView`. Try a physical device, another emulator image, or a bundled asset before doubting your code.
7. **It feels heavier than the rest of your app.** It is — extra compositing every frame. That's the built-in lesson about when platform views are worth their price.

## Check your understanding

1. Walk the full birth of one embedded player: from `AndroidView` entering the widget tree to video pixels on screen — name every class involved on each side.
2. Why does each view instance need its own channel? What exactly ties the Dart-side channel name to the native-side one?
3. What are your `dispose()` responsibilities, and what does the user *hear* if you skip them?
4. The official `video_player` plugin renders via a `Texture` on Android instead of a platform view. Given the mental model, why might that be — and what does a Texture give up that your embedded `VideoView` has? (Write a short paragraph in your journal; we can compare answers.)
5. Two `UiKitView`s with the same `viewType` are on screen. How many factories exist? How many view instances? How many channels?

## Stretch goals

- Swap `VideoView` for **ExoPlayer (media3)** — production-grade Android video, and its `PlayerView` drops into the same `PlatformView` shell.
- Per-view **EventChannel** (`devicelab/native_video_events_<id>`) pushing position ticks + a `completed` event, replacing the Dart polling timer — Tasks 3 + 4 composed, exactly how real player plugins work.
- Read the Android composition-modes doc end to end; try the hybrid-composition API (`PlatformViewLink` + `AndroidViewSurface`) and journal what visibly changed.

## Reading

- Android platform views: https://docs.flutter.dev/platform-integration/android/platform-views
- iOS platform views: https://docs.flutter.dev/platform-integration/ios/platform-views
- When stuck, study: `webview_flutter` source — the canonical platform-view plugin.
