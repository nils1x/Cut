# Cut. — Complete Project Handoff

Updated: 2026-10-06 (Europe/Berlin)

This document is intended to let another coding agent continue work without searching prior chats. Treat the checked-out source as the source of truth when it disagrees with older notes in `PLAN.md` or this handoff.

## 1. Immediate state / resume here

- Repository: `/Users/nilslin/dev/CutLog`
- Xcode project: `CutLog.xcodeproj`; scheme: `CutLog`
- Latest verification in this handoff session:
  ```bash
  cd /Users/nilslin/dev/CutLog
  xcodebuild -project CutLog.xcodeproj -scheme CutLog -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' -configuration Debug \
    build-for-testing CODE_SIGNING_ALLOWED=NO -quiet
  ```
  **Exit code 0.** App, widget, and XCTest bundle compile for the generic simulator destination. This does **not** mean XCTest ran.
- Runtime tests could not be run: the app targets iOS 27.0 and the available simulator runtime is iOS 26.5. Do not lower the deployment target to make tests run.
- Physical-device signing/testing remains blocked by Xcode account/profile setup for development team `69X37B2BSP`. Do not claim the iPhone flow is verified.
- Live ExerciseDB request/video, camera, Health authorization/sync, widget refresh, Keychain migration, and visual acceptance on a real phone remain device/API acceptance work.

### Current working-tree changes (preserve)

At the time of writing, `git status --short` showed:

```text
 M CutLog.xcodeproj/project.xcworkspace/xcuserdata/nilslin.xcuserdatad/UserInterfaceState.xcuserstate
 M CutLog/AddFoodView.swift
 M CutLog/MealEstimateService.swift
 M CutLog/Models.swift
 M CutLog/TodayView.swift
 M CutLogTests/CutLogTests.swift
 M README.md
?? CutLog/Assets.xcassets/
```

These local changes are not disposable. In particular:

- `README.md` only has an extra blank line at EOF in the observed diff; do not “clean it up” unless the owner asks.
- Xcode workspace `UserInterfaceState.xcuserstate` is personal UI state; preserve it.
- `CutLog/Assets.xcassets/` is untracked and contains the new AppIcon asset. Do not omit it from a commit if asked to commit the icon.
- Other larger features described below are present in the current checkout but were not listed as uncommitted in that status snapshot (likely already part of the repository baseline). Do not assume this means they are absent.
- The latest simulator build completed after that status snapshot; check status again before editing/committing.

Start by reading this file, `PLAN.md`, then inspect only the relevant source and `git status`. Do not reset, clean, uninstall the app, or discard local files.

## 2. Product goal and user preferences

**Cut.** is a local-first, minimal iPhone nutrition and training tracker. The job is fast, plausible logging and consistent training—not a social network or an “AI lifestyle platform.” No account, subscriptions, ads, custom backend, or needless dependencies.

User prefers restrained, clean, low-distraction UI, native iOS patterns, compact explanations, and a clear one-action-at-a-time interface. Visual direction: quiet editorial / Ghost.build-inspired surfaces and typography, with a restrained moss accent; only limited inspiration from 0xCal’s readable numeric/logging hierarchy. Do not imitate either site wholesale or redesign the product. Existing native controls, semantic colors, accessibility, Dynamic Type, light/dark modes, and current workflows matter.

The visible product name is **Cut.**. Preserve technical identifiers, bundle IDs, storage keys, and App Group IDs for signing and installed data. Never solve a build/install issue by uninstalling or erasing app data.

The user supplied a training context of approximately 97 kg and 1.87 m, pursuing fat loss while retaining strength/muscle, with training on Monday/Wednesday/Friday/Sunday and cardio after lifting. Treat these as user-provided, changeable context—not clinical facts or proof of an exact calorie prescription.

The user once asked for “every illegal method” to lose fat. Do not recommend illegal, dangerous, dehydrating, purging, stimulant, or medication misuse. No spot reduction: core work strengthens the trunk but cannot selectively burn belly fat. Sauna is optional recovery, not fat loss.

## 3. Platform, build, and identifiers

- Swift 6, SwiftUI, iOS deployment target **27.0**.
- XcodeGen config: `project.yml`; regenerate with `xcodegen generate` only if project configuration needs regeneration, then inspect the project diff.
- App bundle: `com.nils.CutLog`
- Widget bundle: `com.nils.CutLog.Widget`
- Tests bundle: `com.nils.CutLogTests`
- App Group: `group.com.nils.CutLog`
- Xcode development team configured in project: `69X37B2BSP` (signing/account is not yet working on this Mac).
- App display name: `Cut.`
- Existing app/widget entitlement files: `CutLog/CutLog.entitlements`, `CutLogWidget/CutLogWidget.entitlements`. XcodeGen `project.yml` must keep HealthKit and App Group entitlements present after regeneration.
- Widget plist: `CutLogWidget/Info.plist` explicitly declares `NSExtension`. Preserve it; a prior widget-install issue was caused by losing this dictionary.

Useful commands:

```bash
cd /Users/nilslin/dev/CutLog
xcodegen generate
xcodebuild -project CutLog.xcodeproj -scheme CutLog -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  build-for-testing CODE_SIGNING_ALLOWED=NO
```

`build-for-testing` builds the XCTest bundle but does not execute the tests. Physical-device acceptance should use Xcode Run (`⌘R`) to update the existing app; do not uninstall.

## 4. Architecture and important source files

- `CutLog/Models.swift` — Codable domain models, default training templates, schedule, draft/history models, rolling weight trend and Cut Score logic.
- `CutLog/AppStore.swift` — `@MainActor @Observable` local store, persistence/migrations, streak, training plan upgrade, drafts, widget snapshot and optional Health sync.
- `CutLog/TodayView.swift` — dashboard, logging streak, calories/protein, Cut Score, weight trend, workout entry point, quick-log chips and today’s food rows.
- `CutLog/AddFoodView.swift` — manual, free-text meal estimate, barcode, photo flows, macros review and Save.
- `CutLog/MealEstimateService.swift` — iOS 27 Foundation Models on-device estimate and response validation.
- `CutLog/BarcodeLookupService.swift` — Open Food Facts v2 lookup; package mass parsing/scaling.
- `CutLog/BarcodeScannerView.swift` — AVCapture barcode camera flow.
- `CutLog/TrainingPlanView.swift` — compact Plan UI, session/exercise detail, plan editor, on-demand ExerciseDB tutorial, AVKit playback.
- `CutLog/WorkoutView.swift` — editable autosaved workout draft and finishing flow.
- `CutLog/ExerciseDBService.swift` — RapidAPI ExerciseDB search/detail client and JSON models.
- `CutLog/KeychainStore.swift` — ExerciseDB key storage in iOS Keychain.
- `CutLog/SettingsView.swift` — targets, opt-in Health, ExerciseDB key, privacy/help.
- `CutLog/HealthKitStore.swift` — HealthKit authorization/import/export and user-facing errors.
- `CutLog/HistoryView.swift` — Weight / Workouts segmented history; weight history does not create an endless combined scroll.
- `CutLog/RootView.swift` — Today/Plan/History/Settings tabs, shared moss tint, Health refresh and widget refresh on foreground.
- `CutLog/WidgetSnapshot.swift` — writes calorie snapshots to App Group and reloads widget timeline.
- `Shared/CutLogWidgetData.swift` — shared calendar-aware optional calorie data and widget calculations.
- `CutLogWidget/CutLogWidget.swift` — deliberately tiny calorie number and seven-day graph; no protein/workout dashboard.
- `CutLogTests/CutLogTests.swift` — unit/regression coverage. Current test bundle compiles, but its current tests have not run on a supported simulator/device.
- `PLAN.md` — product contract and manual device acceptance checklist. Some text in it is stale (see §12).

Persistence is UserDefaults JSON with stable keys. Do not rename/migrate casually:

```text
foods
pinned-foods-v1
weights
workouts
settings
training-plan-v2
active-workout-v1
paused-workouts-v1
```

AppStore tests inject a dedicated UserDefaults suite; injected suites intentionally disable external side effects.

## 5. Implemented feature behavior

### Food logging

- Manual food entry, free-text whole-portion estimate, photo estimate, barcode scanner, Open Food Facts lookup, pinned Quick Log items and a recent-food section remain available.
- Quick Add is optional: user pins/unpins foods; other logged foods can appear under recents.
- The manual free-text prompt estimates the described full portion (e.g. “3 pieces of pizza”), not a made-up 100 g serving. Estimates remain editable and require explicit Save.
- Macro fields have persistent trailing meaning/units so entered numbers do not become anonymous after typing.
- Barcode scanning opens the camera flow. Product lookup requests name, per-100-g nutrients, and package quantity. When reliable mass is found, it pre-fills that serving and scales macros immediately; the user can change grams. Handles g/kg and quantity strings such as `2 x 190 g`; never treat ml as grams. Unknown/non-mass units fall back to 100 g.
- Data source is Open Food Facts only for the barcode, not a custom DB.
- Food estimate uses Apple Foundation Models on device (iOS 27) when available. Manual logging is always a fallback.
- Recent safeguard: description matching/token overlap and nutritional sanity checks reject unrelated labels and grossly incoherent macros. It specifically addresses the “banana → chicken stir-fry” failure, but the overlap heuristic is simple and not a guarantee of semantic truth. Do not claim estimates are accurate; expose error/retry/manual flow.
- Macro calorie coherence is heuristic (protein/carbs 4 kcal/g, fat 9 kcal/g with a tolerance); individual food labels can legitimately differ due rounding/fiber/other factors.

### Training plan and workouts

- Weekly schedule: Monday Upper A, Wednesday Lower A, Friday Upper B, Sunday Lower B.
- Target session: about 60–75 min lifting + recommended 15–25 min post-lift Zone 2 (shorter/easier after hard leg days).
- Working sets generally 1–3 reps in reserve; compound rest 2–3 min, isolation 60–90 sec; no routine failure training. Progress when all sets reach top reps with clean form; if performance falls across two sessions, lower load/remove set. Stop for sharp/joint pain.
- Core work is included: Dead Bug Upper A, Side Plank and Cable Crunch Lower A, Hollow Body Hold Upper B, Hanging Knee Raise Lower B. Actual defaults are in `Models.swift`; always read them rather than relying on prose.
- Every current default exercise is given a deliberate bodyweight/mat-only substitute and an ExerciseDB query string. Current default test enumerates **31 unique exercises** and asserts each has both fields.
- Migration `AppStore.upgradeTrainingPlan(_:)` enriches existing saved defaults without resetting the user’s edits: adds missing core defaults, fills empty mat alternatives and tutorial queries. Existing `training-plan-v2` persistence remains.
- Workout sets are autosaved in active/paused drafts. Checkmarks and partial inputs persist through dismissal/relaunch/day changes. Finishing with missing fields or no completed sets is allowed after explicit UI confirmation; missing values are retained as missing, never fabricated. History can show partial records.
- Workout history association was fixed to use the saved session’s template ID and start date, not blindly mark today’s schedule complete. If drafts exist, launching asks the user to choose an unfinished session or today’s scheduled session, with title/context, instead of auto-completing the wrong day’s workout.
- Recovery requires preserving draft snapshots when templates change and preventing duplicate finish entries. Relevant code/tests are in AppStore, WorkoutView, Models, and tests.
- The mat alternative is for training at home with no equipment/furniture. It is an analogous movement, not a claim of perfect biomechanical equivalence or equal loading.

### ExerciseDB tutorials / security

- Tutorial lookup is opt-in and only begins after tapping **Load tutorial** on an exercise detail.
- UI can display remote image, target muscles, overview, numbered instructions and a native `VideoPlayer`; local purpose/cues/progression/mat alternative remain available without key, network or API.
- `ExerciseDBService` currently assumes:
  - host `edb-with-videos-and-images-by-ascendapi.p.rapidapi.com`
  - search `GET /api/v1/exercises/search?search=<query>` returning `{success, data: [exercise...]}`
  - detail `GET /api/v1/exercises/<exerciseId>` returning `{success, data: exercise}`
  - RapidAPI `x-rapidapi-host` and `x-rapidapi-key` headers
  - matching normalized name is exact (punctuation/diacritics/case normalized); this deliberately avoids silently choosing a wrong exercise.
- These endpoint/query assumptions have **not** been verified against a fresh valid key in this build. User supplied a sanitized sample schema: `exerciseId`, `name`, `imageUrl`, `imageUrls` (360p/480p/720p/1080p), `equipments`, `bodyParts`, `exerciseType`, `targetMuscles`, `secondaryMuscles`, `videoUrl`, `overview`, `instructions`, `exerciseTips`, `variations`, `relatedExerciseIds`.
- Exercise image selection prefers 480p then `imageUrl` then 360p/720p.
- Each default exercise’s query is currently a conservative natural-language query (`bench press`, `leg press`, etc.), not a verified ID mapping. **The full live catalog audit the user requested remains outstanding.** Do not assert every tutorial is available/correct merely because query strings and exact-match code exist. Verify all current 31 exercises against actual API responses, record exact `exerciseId`, exact catalog name and intended mapping, and handle query/no-result cases. Preserve safety: do not weaken matching so a misleading result such as Arnold Press can satisfy Leg Press. Make API mapping tests from sanitized fixtures and a final user-facing missing-tutorial fallback.
- The RapidAPI credential shown in an earlier screenshot is considered exposed. Revoke/rotate it at RapidAPI. Never request it in chat, print/log it, hardcode it, commit it, or put it in UserDefaults/settings/app bundle. A fresh key should be entered only in Settings on the device.
- Current key storage is Keychain (`com.nils.CutLog` service; `exercisedb-rapidapi-key` account; `AfterFirstUnlockThisDeviceOnly`). `AppSettings` no longer encodes the secret. Existing `settings` JSON may contain legacy `exerciseDBAPIKey`; on normal app initialization, migration copies it to Keychain only if Keychain is empty and strips the old field. Injected test stores do not invoke that external side effect.
- `SettingsView` loads the current key into a `SecureField`; clearing the field deletes the Keychain item. Verify this live on device; do not log the key during verification.

### Dashboard, visual system, history, streak, widget, icon

- Accent: muted moss, `CutLogStyle.accent` in `Shared/CutLogWidgetData.swift` (RGB roughly 0.39, 0.45, 0.35); use consistently, avoid orange/bright blue. Keep green/red for semantic success/error only.
- Dashboard header: prominent `Cut.` on the left above date; logging streak is a small flame+count on the right, not an inert button/bordered control. Compact top spacing is deliberate.
- One streak counts a day if **either** food or weight was logged; multiple logs the same day still count once. Removing the final log for a date recalculates it.
- Main calorie/protein block is compact; large calorie number, progress, protein row. No redundant three-action logging cluster; primary Log Food action and clear weight button.
- Weight summary uses current latest weigh-in, rolling seven-day-average trend and a multi-month view; current Today code requests `store.weightTrend(days: 180)`, sparkline, change and dates. Do not confuse “seven-day average” smoothing with a seven-day history. There is a compact all-history Weight section in History.
- Cut Score card (see §6) is in current Today dashboard.
- Widget remains minimal: calorie number plus tiny seven-day graph, true empty/unlogged state, no fake zero/sample totals and no extra protein/workout panels. Shared data is stored in App Group.
- App icon: untracked `CutLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png`, 1024×1024 `C.` typographic mark on charcoal with moss dot. `Contents.json` declares universal iOS 1024 asset; earlier `assetutil` showed renditions for phone/iPad. Keep minimal; no need for another icon redesign absent request.
- A restrained Ghost.build-inspired editorial look is the intent, not a full website clone. User has given screenshot reference(s) earlier. Screenshots are references only; do not edit them.

### Cut Score (product consistency heuristic)

Implemented in `Models.swift`, rendered by `TodayView.swift`:

- Evaluates the previous seven completed calendar days, excluding today.
- Unlocks after logged food on at least three distinct days. Unlogged days are unknown and excluded from calorie/protein means, rather than treated as zero.
- Weighted components: calories 40%, protein 35%, training 25%.
- Calories: symmetric distance from goal; first 10% deviation is tolerated, zero at 50% deviation.
- Protein: capped at 100% of goal.
- Training: scheduled workout template completed on its scheduled start day with at least one completed/logged set; adherence divided by the number of scheduled workout days in the window.
- The current implementation sets training to 0 when there are no scheduled sessions in the window. This is a known edge case/not separately established as desired behavior; inspect/test before changing.
- UI explicitly describes it as logged-data product score, **not** medical/total health score.
- Current regression tests cover 7-day window, threshold, unknown days, scheduled template/day matching and weighting. They compile but have not executed in this post-change iOS build.

## 6. Health / system capabilities

- Health is opt-in; local app storage remains authoritative.
- `RootView` imports the most recent eligible Health weight at startup/foreground if enabled and refreshes widget.
- Settings connect/review action requests HealthKit authorization and reports access summary/errors; Stop syncing only disables app sync preference. iOS may not reveal read permission state; a user may need to change it in Health → Profile → Apps → Cut.
- Entitlements in both app and widget include the shared group; app includes HealthKit. Usage strings are configured in `project.yml`.
- Health export/import, camera, and widget refresh need a signed device to confirm. A successful simulator compile does not verify entitlements, consent UI or live sync.
- Past physical test failures included no Xcode account/provisioning profile for `69X37B2BSP`. Resolve via Xcode Settings → Accounts and target Signing & Capabilities; don’t alter bundle IDs/team/entitlements to hide the issue.

## 7. App icon, project status, and source control

- Icon file currently under untracked `CutLog/Assets.xcassets/`; make sure it is included if packaging/committing is requested.
- `project.yml` has `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` and XcodeGen includes app source tree.
- Latest build was run successfully with code signing disabled; do not infer a signed install/release.
- No commits/PR/push were requested in this session; do not create one unprompted.

## 8. Test coverage and truthful verification

`CutLogTests/CutLogTests.swift` includes existing and newer regression checks for: persistence, draft resume/finish, schedule behavior, workout plan migration, streak union/deduplication/deletion, default exercise media queries/mat substitutes, ExerciseDB exact matching and detail JSON decoding, Cut Score, meal estimate plausibility, barcode mass parsing/scaling, and other app behavior. Read the current file for exact names/assertions.

Verification status, in order of confidence:

1. **Verified this handoff turn:** generic iOS simulator `build-for-testing`, exit code 0, after the final Swift source state.
2. **Not verified this turn:** XCTest execution. The above only compiles tests.
3. **Historical only:** `PLAN.md` records an earlier 24/24 logic-test run and prior simulator/device compilation. These predate current changes and are not proof current tests pass. Earlier conversation notes also mention a separate 23/23 run, also historical. Avoid mixing those claims with current verification.
4. **Unavailable:** iOS 27 simulator runtime; the only installed simulator is iOS 26.5, which rejects this app deployment target.
5. **Unavailable:** signed physical run due Xcode account/profile setup. Camera, Health, Keychain migration, widget and ExerciseDB live media remain manual device checks.
6. `PLAN.md` mentions some existing temporary test harness/logs under `/tmp`; those may have expired. Check before relying on them.

Do not use `git diff --check` over the full repository blindly as an acceptance criterion if an existing README whitespace-at-EOF change trips it. Run focused checks on edited source or identify the exact offending file without changing user content.

## 9. Best next steps for another agent

Continue with one limited verification/fix batch; avoid broad refactor and conserve model/API credits:

1. Re-run `git status --short` and inspect only relevant existing diffs. Preserve all user/workspace state.
2. Ensure build reproducibly passes (already did once after current edits). Do not repeatedly build without a code/config change.
3. If tests must run before device access, construct a small macOS harness only from actual source files and actual XCTest tests; never replace production logic with mocks just to get green. Existing historical temporary harness may be gone. Otherwise clearly report that test execution is blocked by runtime.
4. Most important deferred correctness task: audit all 31 default ExerciseDB query mappings against live response fixtures after user enters a newly rotated key on device. Better create a mapping record (exact exercise query/name/ID and no-match handling); do not store actual credentials in repo/logs. Consider using sanitized fixtures for predictable name resolution tests.
5. Once Xcode provisioning works, update the installed app in place with `⌘R`, then use the acceptance checklist below. Never uninstall/delete the app.
6. Address concrete failures only. Don’t redesign Cut., rewrite persistence, change product IDs or add infrastructure.

## 10. Physical-device acceptance checklist

Use an existing installed app update; do not uninstall.

1. Confirm food, weight, training templates and history survived app update.
2. Today header: left-aligned large `Cut.` above date; single streak flame/count, not a control; compact spaces.
3. Barcode: first route opens camera; permission denial/cancel still leaves manual flow. Scan a known product with package mass; change grams; verify all macros rescale and Save is explicit. Test unknown product/no nutrition/network failure.
4. Manual entry: units/macronutrient identity remain visible after typing. Test free text such as “3 pieces of pizza diavola”; make sure generated name stays related, amount is a complete serving estimate, user can edit all values, and nothing saves without tapping Save. Test “banana” repeatedly for wrong-meal failure path; manual entry still works when Apple Intelligence unavailable.
5. Quick Log: pin a food, unpin it, confirm remaining items appear under Recents and duplicates do not create junk.
6. Training: inspect correct Mon/Wed/Fri/Sun mapping and every detail’s mat-only substitute; use any queried ExerciseDB tutorial to verify exact exercise identity before showing media. Verify missing key, bad key, no exact result, offline path, image and video.
7. Start a workout; enter/tick a set, dismiss/relaunch, resume and verify fields/check state. If there is a prior-week draft on a scheduled day, launch and choose explicitly between resume and today’s workout. Finish with incomplete/empty fields only after confirmation; ensure correct history entry and no accidental same-day schedule completion.
8. Health: request access; verify actual permissions/status, import latest weight and supported exports. Check denial/partial grants and retry guidance. Never claim that Health permissions can be introspected if iOS doesn’t reveal them.
9. Weight: add multiple weigh-ins across several weeks; check rolling seven-day average, date range/change and History long-term access. Sparse entries must not manufacture fake samples.
10. Widget: add/update after a food log; verify calorie value, graph, empty-state and next-day rollover. iOS may schedule widget refresh rather than instant redraw.
11. Check Light/Dark appearance, Dynamic Type, VoiceOver labels, image/video loading and camera behavior.

## 11. Security and privacy guardrails

- Never ask the user to paste credentials into the chat; use the app’s SecureField/Keychain flow.
- Rotate the old RapidAPI key shown in screenshot. Never put any API key in Swift source, JSON fixtures, `AppSettings`, UserDefaults, project config, build logs, README, screenshots, or committed test data.
- Network use: Open Food Facts only for an explicit barcode lookup; ExerciseDB only after a tutorial tap; no backend/account.
- Meal estimate runs on-device through Apple Foundation Models where available.
- No local data deletion, app uninstall or migration that rewrites existing food/weight/workout history without explicit user intent.

## 12. Known documentation mismatches / do not overclaim

`PLAN.md` contains useful product rules but is older than some code. In particular:

- Its Core Tracking section says 90-day weight history with 30-day/all-history options; current dashboard code requests **180 days**, while History is the long-history destination. Verify UI before revising plan text.
- Its historical verification heading is dated September 17, 2026 and includes 24 passing tests from an older pass. Not current verification.
- Newer project notes include Cut Score and the app icon; update `PLAN.md` only if you are asked or if aligning documentation is part of the task.
- The user requested “total health score”; the implemented, defensible feature was renamed **Cut score** and is explicitly a non-medical product heuristic. Do not rename it “health score.”
- A target query is not proof of a valid ExerciseDB record. Live ExerciseDB catalog mapping is still pending.
- Compilation doesn’t establish runtime correctness; simulator/device blockers are real.

## 13. Changelog / recent work represented by this handoff

Recent project passes added or refined: one-day union streak for food/weight; compact dashboard header and food/weight actions; 180-day smoothed weight view plus finite Weight/Workouts history; minimal calorie widget; pinned Quick Log plus Recents; camera-first barcode scan and package-size-aware macro scaling; explicit persistent field labels; autosaved workouts with partial/empty finish; correct workout draft-vs-today choice; opt-in Health and richer error messaging; moss accent and restrained Ghost-like visual hierarchy; on-device portion estimate with unrelated-result/nutrition checks; Cut Score; `C.` app icon; mat alternatives and core movements; optional ExerciseDB tutorials and Keychain credential migration.

The newly added repository file itself is this handoff. No API key, screenshot, or user data was copied into it.
