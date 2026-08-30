# Task 2 — Real Conversations: Biometric Vault

**Project:** `device_lab` · **Module:** Biometric Vault · **Difficulty:** ★★☆☆☆ · **Est. time:** 3–4 h

## Why this exists

Task 1's calls were toy-shaped: no inputs, instant answers. Real platform APIs are neither. They take configuration, they fail in a dozen platform-specific ways, and — the big one — they answer **later, via callbacks**. Biometric auth (`BiometricPrompt` on Android, `LAContext` on iOS) has all three properties, which makes it the perfect gym for the pattern behind ~90 % of production channel code: *arguments in, mapped errors out, one async result.*

## Mental model (read before coding)

**Arguments.** `invokeMethod('authenticate', {'reason': ..., 'allowDeviceCredential': ...})` — the second parameter rides the same codec as return values. Natively you unpack it: Kotlin `call.argument<String>("reason")`, Swift `call.arguments as? [String: Any]`.

**The result is a one-shot promise you carry into callback land.** In Task 1, the handler answered before returning. Here, the handler *starts* the native prompt and returns immediately — holding onto `result` — and some callback fires seconds later to resolve it. Picture `result` as a `Completer` you're handing to the OS:

```
Dart                         Native handler                    OS callbacks (later)
────                         ──────────────                    ────────────────────
invokeMethod('authenticate') start prompt, keep `result`  ───► onSucceeded  → result.success(true)
   Future pending........................................ ───► onError(code)→ result.error(mapped)
                                                          ───► onFailed     → (retryable: DO NOT reply)
```

Two laws govern this shape:

1. **Exactly one reply.** The OS may fire *multiple* callbacks per prompt (Android's `onAuthenticationFailed` fires on every bad fingerprint while the prompt stays open). Reply in a non-terminal callback and the eventual terminal one crashes with *"Reply already submitted."* You need discipline (only terminal callbacks reply) plus insurance (a `replied` flag).
2. **Reply on the platform's main thread.** Channel replies must happen on the main/UI thread of the platform side. Android's `BiometricPrompt` cooperates if you pass the main executor; iOS's `evaluatePolicy` deliberately does *not* — its reply arrives on a private queue, and you must hop with `DispatchQueue.main.async`. This is the single most-Googled crash in Flutter/iOS integration; today you learn it on purpose.

**Errors are an API you design.** Android reports failures as integer codes; iOS as `LAError` cases. Neither should leak to Dart. You define a small shared vocabulary and both platforms translate into it — that translation layer *is* the craft of channel design:

```
authenticate(reason: String, allowDeviceCredential: bool) -> bool
errors: NOT_AVAILABLE | NOT_ENROLLED | LOCKED_OUT | CANCELED | FAILED
checkAvailability() -> "available" | "notEnrolled" | "noHardware" | "unavailable"
```

Native `result.error(code, message, details)` surfaces in Dart as a thrown `PlatformException` with those fields — your wrapper catches it and converts to a typed result so the UI never sees a raw exception.

## Build milestones

**M0 — Write the contract.** Copy the block above into a comment atop your new `BiometricsApi` Dart file. Contract first, code second — the habit Pigeon will later formalize.

**M1 — Availability (the warm-up).** New channel `devicelab/biometrics`, method `checkAvailability`, no args, synchronous-ish, returns one of the four strings. Android: add `androidx.biometric:biometric:1.1.0` to `android/app/build.gradle`, use `BiometricManager.from(this).canAuthenticate(BIOMETRIC_WEAK or DEVICE_CREDENTIAL)`. iOS: `LAContext().canEvaluatePolicy(_, error:)`, inspect the `LAError`.
*Done when:* both platforms report correctly, and toggling enrollment (see hints for simulator/emulator setup) changes the answer.

**M2 — Authenticate, Android happy path.** `MainActivity` must become **`FlutterFragmentActivity`** (`BiometricPrompt` demands a `FragmentActivity`; nothing else changes). Pass `reason` from Dart into `PromptInfo`'s subtitle. Succeed → `result.success(true)`.
*Done when:* prompt shows *your Dart-supplied text*, and a matching fingerprint unlocks.

**M3 — Android error mapping + the one-shot rule.** Wire `onAuthenticationError` through a `mapErrorCode()` into your contract codes; leave `onAuthenticationFailed` empty. Then earn the scar deliberately: put a `result.success(false)` inside `onAuthenticationFailed`, fail a fingerprint twice, read the "Reply already submitted" crash, revert, add the `replied` flag.
*Done when:* cancel → CANCELED, repeated failures → eventually LOCKED_OUT, and you've seen the double-reply crash with your own eyes.

**M4 — iOS port + the thread hop.** `NSFaceIDUsageDescription` in `Info.plist`. Choose the policy from `allowDeviceCredential` (`.deviceOwnerAuthentication` vs `.deviceOwnerAuthenticationWithBiometrics`). Inside `evaluatePolicy`'s reply closure, wrap *everything* in `DispatchQueue.main.async`. Map `LAError` cases to your contract.
*Done when:* Face ID (simulator-enrolled) unlocks; cancel and not-enrolled paths produce the right codes; no thread warnings.

**M5 — Typed Dart + real UI.** Wrapper catches `PlatformException`, switches on `.code`, returns a sealed class/enum. Vault screen: locked state → Unlock button → native prompt → content; each error gets a *specific* human message ("No fingerprints enrolled — add one in Settings"). Availability from M1 gates the button *before* the user taps. Re-lock on leaving the screen.
*Done when:* every path in your contract is reachable from the UI and reads like a product, not a stack trace.

## Hints

Argument unpacking:

```kotlin
val reason = call.argument<String>("reason") ?: "Authenticate"
val allowCredential = call.argument<Boolean>("allowDeviceCredential") ?: false
```

```swift
let args = call.arguments as? [String: Any]
let reason = args?["reason"] as? String ?? "Authenticate"
```

Android skeleton — flag + terminal-only replies:

```kotlin
"authenticate" -> {
  var replied = false
  fun reply(block: () -> Unit) { if (!replied) { replied = true; block() } }

  val prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this),
    object : BiometricPrompt.AuthenticationCallback() {
      override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) =
        reply { result.success(true) }
      override fun onAuthenticationError(code: Int, msg: CharSequence) =
        reply { result.error(mapErrorCode(code), msg.toString(), null) }
      override fun onAuthenticationFailed() { /* retryable — stay silent */ }
    })

  val info = BiometricPrompt.PromptInfo.Builder()
    .setTitle("Device Lab").setSubtitle(reason)
    // EITHER setNegativeButtonText(...) OR setAllowedAuthenticators(BIOMETRIC_WEAK or DEVICE_CREDENTIAL) — never both
    .build()
  prompt.authenticate(info)
}
```

iOS — the hop:

```swift
let context = LAContext()
context.evaluatePolicy(policy, localizedReason: reason) { success, error in
  DispatchQueue.main.async {                       // ← the whole lesson, one line
    if success { result(true) }
    else { result(FlutterError(code: Self.mapError(error),
                               message: error?.localizedDescription, details: nil)) }
  }
}
```

Error codes worth mapping first: Android `ERROR_USER_CANCELED`/`ERROR_NEGATIVE_BUTTON` → CANCELED, `ERROR_LOCKOUT*` → LOCKED_OUT, `ERROR_NO_BIOMETRICS` → NOT_ENROLLED. iOS `.userCancel`/`.systemCancel` → CANCELED, `.biometryLockout` → LOCKED_OUT, `.biometryNotEnrolled` → NOT_ENROLLED, `.biometryNotAvailable` → NOT_AVAILABLE.

Fake biometrics: iOS Simulator → *Features ▸ Face ID ▸ Enrolled*, then *Matching/Non-matching Face*. Android emulator: enroll a fingerprint in Settings, trigger with `adb -e emu finger touch 1`.

## Gotchas (ordered by likelihood)

1. **"Reply already submitted."** You replied in `onAuthenticationFailed` or forgot the flag. M3 makes you meet this crash under lab conditions so it never surprises you in the field.
2. **iOS thread crash/warning on reply.** Missing `DispatchQueue.main.async` around `result(...)` inside the `evaluatePolicy` closure.
3. **Android crash the instant the prompt opens.** `MainActivity` still extends `FlutterActivity`; it needs `FlutterFragmentActivity`.
4. **`IllegalArgumentException` building `PromptInfo`.** `setNegativeButtonText` and `DEVICE_CREDENTIAL` authenticators are mutually exclusive — branch on `allowDeviceCredential`.
5. **Face ID silently no-ops on a real iPhone.** Missing `NSFaceIDUsageDescription`.
6. **Availability lies on Android.** Use the overload taking explicit authenticator flags; the no-arg `canAuthenticate()` is deprecated and misleading on newer OS versions.

## Check your understanding

1. Trace `reason` from your Dart string literal to pixels inside the native prompt — every hop.
2. Why must `onAuthenticationFailed` never call `result`, while `onAuthenticationError` must? What distinguishes them?
3. Your handler function returns *before* the user touches the sensor. Who is keeping the Dart `Future` alive, and what eventually completes it?
4. Why does iOS force you to `DispatchQueue.main.async` while your Android code needed no explicit hop? (Hint: what did you pass as the prompt's second constructor argument?)
5. A teammate's UI does `catch (e) { showError(e.toString()) }` around your API. What did they break in your design, and what should they get instead?

## Stretch goals

- Native→Dart eventing: after each attempt, native invokes `onAuthAttempt(success: bool)` on the channel; log attempts live in the Flutter UI. (Task 3's direction of flow, hand-rolled.)
- `cancelAuthentication` method (`BiometricPrompt.cancelAuthentication()` / `LAContext.invalidate()`) driven by a Dart-side timeout.
- On LOCKED_OUT, auto-offer the device-credential path with a countdown.

## Reading

- Android biometric guide: https://developer.android.com/identity/sign-in/biometric-auth
- Apple LocalAuthentication: https://developer.apple.com/documentation/localauthentication
- When stuck, study: `local_auth` plugin source.
