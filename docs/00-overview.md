# Native Integration — Self-Study Roadmap

Six tasks to take you from "never touched native code in Flutter" to owning platform channels, native modules, platform views, Pigeon-based plugins, and `dart:ffi`. Written for **you to work through manually** — these are study guides, not tickets. Every line of Kotlin, Swift, C, and channel code should be typed by your hands.

**Platforms:** Android (Kotlin) + iOS (Swift), both, every task.

---

## How each guide is structured

1. **Why this exists** — the problem the mechanism solves.
2. **Mental model** — how it actually works, connected to Flutter concepts you already know. Read this fully before coding; it's the teaching core.
3. **Build milestones** — an ordered sequence of small wins, each with a "done when." When you're stuck on what to do next, the next milestone is the answer.
4. **Hints** — exact API names and starter snippets (calibrated for "can read & tweak" Kotlin/Swift). Not full solutions.
5. **Gotchas** — ordered by how likely they are to bite. When something breaks, read these before Googling.
6. **Check your understanding** — questions to answer *from memory* after finishing. If you can't, revisit the mental model or experiment until you can. Send me your answers anytime and I'll check them.
7. **Stretch goals** — optional depth.

## How to study (this matters more than the content)

- **Type, don't paste.** Even the hint snippets. Muscle memory is half of native-integration fluency.
- **One platform end to end, then port.** Android usually iterates faster. The *porting* step is where you separate "Flutter's concept" from "the platform's API" — that separation is the actual skill.
- **Keep a journal.** One markdown note per task: what confused you, what the fix was, the exact error strings you hit. Future-you debugging at work will thank present-you.
- **Break it on purpose.** Several milestones ask you to trigger an error deliberately. Do them — knowing the failure signatures is worth as much as the happy path.
- **Full rebuild after native edits.** Hot reload/restart only swap Dart. Any Kotlin/Swift/Gradle/Podfile/C change → stop the app, `flutter run` again. This one fact explains most "why isn't my change showing up" moments; internalize it on day one.
- **Finish a task before peeking at solutions.** When stuck, order of escalation: gotchas list → official docs linked in the task → source code of the official plugin that does the same thing (listed per task — reading it is studying, using it is cheating) → ask me with your code and the error.

## The three projects

| Project | Tasks | What it is |
|---|---|---|
| `device_lab` (app) | 1–4 | A "Device Lab" utility app. Home screen lists modules; each task adds one screen. |
| `device_toolkit` (plugin) | 5 | Tasks 1–2 extracted into a reusable plugin, rebuilt with Pigeon. |
| `native_pixels` (FFI plugin) | 6 | An image-filter engine in C, bound with `dart:ffi`. |

One app for tasks 1–4 because that mirrors real work — you bolt native code onto an existing app, you don't greenfield one per feature — and you skip repeating setup. Tasks 5–6 are separate because building standalone packages *is* the lesson.

**Device Lab modules:** Device Info (T1) · Biometric Vault (T2) · Sensor Dashboard (T3) · Native Player (T4). Keep the Flutter side deliberately boring — a `ListView` home and one screen per module. Spend your effort on the bridge and the native side.

## The ladder

| # | File | You learn | Difficulty | Est. time |
|---|---|---|---|---|
| 1 | `01-method-channel-first-bridge.md` | `MethodChannel`, one-shot calls, codecs | ★☆☆☆☆ | 2–3 h |
| 2 | `02-arguments-errors-async.md` | Arguments, error contracts, async callbacks, threading | ★★☆☆☆ | 3–4 h |
| 3 | `03-event-channel-streams.md` | `EventChannel`, stream lifecycle | ★★★☆☆ | 3–4 h |
| 4 | `04-platform-views.md` | Embedding native UI, per-view channels | ★★★★☆ | 6–8 h |
| 5 | `05-pigeon-plugin.md` | Plugin packages, Pigeon codegen | ★★★★☆ | 6–8 h |
| 6 | `06-dart-ffi.md` | C interop, native memory, isolates | ★★★★★ | 6–8 h |

Pacing that has worked for others: 1–3 across a week of evenings, then one weekend each for 4, 5, and 6. Don't rush 4 — platform views reward patience.

## Ground rules

1. **No shortcut plugins.** `battery_plus`, `local_auth`, `sensors_plus`, `video_player` do exactly what tasks 1–4 ask. Don't add them. Their *source code*, however, is your best reference material when stuck.
2. **Real hardware when possible.** Simulators lie: iOS Simulator has no battery or accelerometer and fakes Face ID. Each task notes what works where — the iOS Simulator gaps are even used as teaching moments for error paths.

## Prerequisites

Flutter stable · Android Studio + emulator/device · Xcode + CocoaPods + simulator/device. Your "can read & tweak" Kotlin/Swift is enough; hints carry the syntax you'll need.

## The map you'll have at the end

| Tool | Reach for it when | Learned in |
|---|---|---|
| Raw platform channels | Calling platform SDK APIs (Kotlin/Swift) from an app | 1–3 |
| Platform views | Native UI you can't rebuild in Flutter (maps, players, WebViews, ads) | 4 |
| Pigeon | Channels at team scale — typed, generated, maintainable | 5 |
| `dart:ffi` | C/C++/Rust libraries, synchronous compute, hot paths | 6 |

Being able to fill in this table from experience — including *why* each row is true — is the goal of the whole curriculum.
