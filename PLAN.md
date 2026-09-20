# Cut. — product contract

## Product
A local-first iPhone tracker for the loop that matters: log food, hit protein, train, move, repeat. It covers the useful job of calorie trackers without accounts, subscriptions, ads, a backend, or an algorithm pretending it knows your soul.

## Core tracking
1. **Today** — one compact calorie/protein/weight summary, a 90-day weight history (30 days / all history optional) smoothed by a trailing 7-day average, direct food actions, and one training card.
2. **Food** — manual entry, optional pinned Quick Log foods, unpinned recents, camera estimate, and Open Food Facts barcode lookup. Barcode scans use the package mass when Open Food Facts provides a usable gram/kg value, then keep the serving field editable; otherwise they safely default to 100 g. Every route ends in editable macros.
3. **Health** — optional Apple Health connection, requested only after tapping Connect. Local data remains authoritative.
4. **Widget** — remaining/over-target calories and a tiny seven-day calorie graph. No protein/workout panels, fake fallback data, or stale yesterday totals.

## Training plan
Goal: lose about 0.5–1.0% of body weight per week while preserving muscle. Fat loss comes from a sustainable calorie deficit; belly-fat targeting remains fictional DLC.

### Weekly rhythm

| Day | Session | Focus |
|---|---|---|
| Monday | Upper A | Chest, back, arms |
| Tuesday | Active recovery | Steps, sport, walk, bike |
| Wednesday | Lower A | Quads, hamstrings, core |
| Thursday | Active recovery | Steps, sport, walk, bike |
| Friday | Upper B | Shoulders, back, arms |
| Saturday | Active recovery | Steps, sport, walk, bike |
| Sunday | Lower B | Posterior chain, quads, core |

### Session rules
- 5–8 minutes easy warm-up cardio, plus warm-up sets before the first heavy movement.
- Strength work: roughly 60–75 minutes.
- Autosave weight, reps, RIR, and completion state while training. Finish at any point; missing fields stay missing and unchecked sets stay unchecked.
- Compound lifts: 2–3 minutes rest; isolation lifts: 60–90 seconds.
- Cardio follows lifting: 15–25 minutes Zone 2; shorten it after a hard leg day if fatigue is high.
- Sauna is optional recovery, not an invented calorie-burn multiplier. Hydrate afterwards.

### Progression
- Train mostly at 1–3 RIR; do not make regular failure sets the plan.
- When every set reaches the top of its range at target RIR with clean technique, add roughly 2–5% upper-body or 2.5–5% lower-body load next time.
- If performance falls clearly for two sessions, reduce load or remove a set.
- After 5–8 weeks or obvious accumulated fatigue, use a lighter week: 30–40% fewer sets and 2–3 RIR.

### Cut guidance
- Start provisionally at 2,400–2,500 kcal and 180–210 g protein daily.
- Weigh daily or at least four times weekly. The dashboard shows a rolling 7-day average; never change calories from one weigh-in.
- If the 14-day average stalls, first add 1,500–2,000 daily steps, then reduce 100–150 kcal if required.
- If loss exceeds 1% weekly and training, hunger, or sleep deteriorate hard, increase food slightly or reduce cardio.
- Aim for 7–9 hours sleep and build 7,000–10,000 steps across 2–4 additional days.

## Plan UX
The `Plan` tab intentionally shows only the next session, four compact weekday rows, and one concise cut rule. Tap a day to inspect that session; tap an exercise for cues, target muscles, progression, equipment alternatives, and a deliberate mat-only alternative. `Edit` saves a fully local, editable template.

Each default session includes direct core work: Dead Bug (Upper A), Cable Crunch + Side Plank (Lower A), Hollow Body Hold (Upper B), and Hanging Knee Raise (Lower B). Core training improves bracing and strength; it does not selectively burn belly fat.

ExerciseDB tutorials stay optional and on demand. A user-added RapidAPI key lives in the iPhone Keychain, never in source, app settings, or the app bundle. Opening **Load tutorial** may fetch a matching photo, target muscles, steps, and a native video player; the local exercise guidance remains usable if the key, network, or API is unavailable.

## Constraints
- No account, subscription, server, custom food database, social feed, or automatic calorie changes.
- Barcode lookup is the only required network request and uses Open Food Facts. ExerciseDB is an optional, user-triggered tutorial request.
- Apple Intelligence meal estimates run on-device where available and never block manual logging.
- Widget and HealthKit failures cannot block food or workout tracking.
- The display brand is `Cut.`; technical bundle IDs and App Group names remain `CutLog` for signing and installed-data stability.

## Current implementation pass — plan and acceptance checks

1. **Barcode first:** use one item-based food route; show the scanner as the initial content, not a second sheet. Explicit camera permission, cancel/manual fallback, and product review after scan. Verify first-tap routing by code/build and camera behavior on device.
2. **Legible food fields:** persistent trailing labels for kcal, serving grams, protein, carbs, and fat; numeric keyboard and VoiceOver labels. Barcode products prefill usable package mass in grams, including `kg` and multipacks, then rescale macros immediately when serving grams change; unknown/non-mass packages default safely to 100 g. Verify labels remain after typing and barcode rescaling still works.
3. **Resumable workouts:** persist a single active draft including the template snapshot and every set edit/checkmark. Resume across dismissal, relaunch, day changes, and template edits. Finish incomplete or empty sessions explicitly; retain partial inputs in history without inventing measurements. Verify round-trip persistence, partial/empty finish, legacy records, and duplicate finish protection.
4. **Minimal widget:** remaining/over calories plus seven dated calorie bars with goal reference; real empty state, midnight rollover, App Group storage, and timeline refresh. Verify old/missing data, over-goal values, calendar boundaries, and widget build.
5. **Compact dashboard:** combine calories, protein, and weight; default to 90 calendar days with 30-day/all-history alternatives. Seven days describes smoothing, not the display horizon. Show trend change and actual dates; no fake samples or automatic calorie changes. Verify daily deduplication, sparse samples, range boundaries, and long history.
6. **Health:** restore HealthKit and App Group entitlements in XcodeGen properties (the original entitlement files were empty; corrected properties now survive regeneration). Show real request errors, allow retry/review, distinguish sync preference from per-type permission, export only permitted data, and keep local saves independent of Health failures. Verify regenerated entitlements twice plus compiled app configuration; system authorization needs a signed device.

**Verification:** build app/widget and test bundle for iOS 27; run isolated model/store tests on the Mac if the iOS 27 simulator remains unavailable. Clearly separate executed logic tests from iPhone UI/Health/camera checks. Do not lower deployment target, change bundle IDs, or erase installed app data.

## Verification results — September 17, 2026

- Implemented all six changes above in this pass; technical identifiers and existing data keys remain unchanged.
- **24 XCTest regression cases executed, 0 failures** in the prior pass. The temporary macOS harness used for direct execution no longer exists; the current barcode package-mass change has dedicated regression cases and the iOS 27 test bundle compiles successfully. Run on macOS against symlinks to the actual `Models.swift`, `AppStore.swift`, `HealthKitStore.swift`, `WidgetSnapshot.swift`, shared widget data and the actual test suite. No mocked store/persistence implementation; injected temporary defaults disable external writes. This tests logic, not iPhone UI or system authorization.
- iOS 27 simulator app + widget + XCTest bundle: **TEST BUILD SUCCEEDED** (compilation only).
- iOS 27 generic physical-device app + widget: **BUILD SUCCEEDED**, unsigned. Non-blocking warning: interface-orientation configuration. No installation or device-data deletion performed.
- Ran XcodeGen twice and asserted HealthKit/App Group entitlements afterward. Inspected compiled app camera/Health usage strings, `Cut.` display name, unchanged bundle IDs, deployment target, and widget `NSExtension` dictionary.
- Test log: `/tmp/cut-logic-tests.log`. Temporary actual-source test harness: `/tmp/cut-logic-tests.2Ywte1`; rerun with `swift test --package-path /tmp/cut-logic-tests.2Ywte1` while it exists.
- Final build logs: `/tmp/cut-final-simulator-build.log` and `/tmp/cut-final-device-build.log`.
- **Not verified on iPhone:** real camera scan/permission denial, keyboard and Dynamic Type appearance, light/dark rendering, Health authorization/sync, live home-screen widget refresh. Only an iOS 26.5 simulator runtime is installed; the app remains iOS 27. Device signing/account configuration is separate from unsigned build success.

### Short device acceptance pass
1. In Xcode select the iPhone and use Run (`⌘R`) to update the existing app. Do not uninstall; local data should stay in place.
2. Today → Barcode: camera should be the first screen (with permission request if new). Scan a package, change serving grams, review macros, Save. Unknown/denied camera paths must leave manual entry available.
3. Today → Manual: fill every number; right-side Calories/Protein/Carbs/Fat labels and units remain visible.
4. Start a workout, enter one weight and tick one set, close and reopen the app. Resume must retain both. Finish with blank fields/skipped sets; check History. A new session must start empty.
5. Inspect the shared calorie/protein/weight summary. Weight defaults to 90 days; select 30 days or All time. Seven-day smoothing does not truncate history. Check both system appearances.
6. Settings → Connect Apple Health. Allow desired types; review the actual write-access count. Previously denied access may need changing in Health itself. If installation/signing fails, check Xcode account/team and the HealthKit/App Group capabilities; do not solve it by changing identifiers or deleting app data.
7. Open the app once after updating, then inspect the widget: calorie number + small graph only; missing dates are not sample data. Add food and check refresh, allowing for iOS scheduling.
8. Settings → Exercise tutorials: paste a newly rotated RapidAPI key. Open Plan → a workout → an exercise → Load tutorial. Confirm photo/steps/targets appear and the video opens. Clear the field, relaunch, and verify the tutorial now asks for a key; local cues and mat alternative must still work.

## Definition of done
- App builds for iOS 27.
- Food, weight, plan edits, and workout records survive relaunch.
- Monday/Wednesday/Friday/Sunday map to Upper A/Lower A/Upper B/Lower B.
- Each exercise stores muscle group, sets, reps, RIR target, rest, progression cue, equipment alternatives, a no-equipment mat alternative, and an ExerciseDB query.
- Each workout logs weight, reps, RIR, and completion per set.
- Dashboard trend is derived from daily rolling 7-day weight averages.
- Apple Health permission remains explicit and opt-in.
- Optional ExerciseDB media loads only after a user action and a valid key is present in Keychain; local training guidance never depends on it.
