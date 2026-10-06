# Cut. — Redesign Plan

Status: plan only. No source changed.
Source of truth remains the checkout; `HANDOFF.md` §1 still applies (preserve working tree, never uninstall, iOS 27 target stays).

## 0. What this plan covers

1. Design system (tokens) shared by every screen.
2. Dashboard rebuild.
3. 30-day consistency chart, GitHub style.
4. Weight chart: 30-day window only.
5. Local food catalog with fuzzy search for fast relog.
6. Widget redesign.
7. Test suite.

Out of scope: product naming, bundle IDs, App Group, persistence keys for existing data, ExerciseDB, HealthKit, meal estimate logic, training plan content.

## 1. Design direction

References: `~/Downloads/616d35cd0945839e1e2e13c6b90ed815.jpg` (editorial dashboard, sage surface, big number, tick progress bar, macro row), `580ece9538cadcb1e1936063a77ba2d0.jpg` (compact metric cards, small segmented bars, score ring, 7-day bar sparkline), `57a1b2d97d9862e7017a16b2eb3bac3e.jpg` (food journal list with timeline dots, tab bar with accent FAB — borrow list rhythm and tab idea, reject the neon).

Keep: moss accent, monochrome surfaces, big tabular numbers, thin rules.
Reject: gradients, glow, neon, glass, shadow-heavy floating cards, gradient rings, pill soup.

### 1.1 Tokens

One place, `Shared/CutLogStyle.swift`, shared by app and widget (already the pattern via `CutLogWidgetData.swift`).

```swift
enum CutLogStyle {
    static let accent      = Color(red: 0.39, green: 0.45, blue: 0.35)   // unchanged
    static let surface     = Color(.secondary).opacity(0.06)
    static let surfaceHigh = Color(.secondary).opacity(0.11)
    static let hairline    = Color(.secondary).opacity(0.18)

    enum Radius { static let card: CGFloat = 14; static let control: CGFloat = 10; static let cell: CGFloat = 3 }
    enum Space  { static let xs: CGFloat = 4; static let s: CGFloat = 8; static let m: CGFloat = 12
                  static let l: CGFloat = 16; static let xl: CGFloat = 24 }
    enum Number {
        static let hero   = Font.system(size: 56, weight: .semibold, design: .default).monospacedDigit()
        static let metric = Font.system(size: 26, weight: .semibold).monospacedDigit()
        static let body   = Font.body
        static let label  = Font.caption.weight(.medium)
    }
}
```

Rules:
- `hero`/`metric` use the default (SF Pro) design, not `.rounded`. Rounded is part of the "easy Swift" look being removed.
- Colors only from `accent`, `hairline`, `surface`, semantic system colors, green/red for success/error only.
- No `.shadow`, no `.gradient`, no `.background(.ultraThinMaterial)` except where the system demands it (widget `containerBackground`).
- Light and dark both come from semantic colors, so no per-appearance color pairs.
- Reused shapes: `Card`, `MetricBar`, `SectionHeader`, `HairlineRule`, `NumberTile`. Four small views total, no view hierarchy for its own sake.

### 1.2 Type and density

- Section titles: `.caption.weight(.medium)` uppercase-ish (`textCase(.uppercase)` optional, decided during build), `.foregroundStyle(.secondary)`.
- Every numeric value `.monospacedDigit()` and `.contentTransition(.numericText())`.
- Body prose reduced. Delete: "Estimates the whole portion. Review before saving.", "7-day average · 6 months max", "Previous 7 days · based on logged data, not a health assessment.", "Rough beats imaginary." Keep one-line labels only. Non-medical disclaimer moves to a single Settings row + accessibility label on the score, not on the dashboard.

## 2. Dashboard rebuild

`CutLog/TodayView.swift` is replaced by a `VStack` of fixed sections inside one `ScrollView`. Order, top to bottom, no scroll-jacking:

1. **Header** — `Cut.` large bold left; date line secondary below. Streak: bare `flame.fill` + number, `.secondary`, no capsule, no background, not a button.
2. **Energy card** — the hero.
   - Row 1: `CALORIES` label (left) + today's date short (right, secondary).
   - Row 2: hero number `2.040` + muted `/ 2.450 kcal` trailing. Number is **consumed**, not remaining (reference 1). Over goal: number turns `.red` semantic, label switches to `over`.
   - Row 3: `MetricBar` — hairline track, filled with accent, no rounded cap animation, 2pt height, square ends. No chunky `ProgressView`.
   - Row 4: three columns, `P 154` / `C 154` / `F 154`, each with a 2pt micro-bar under it. Label grey, value primary, no `%`.
3. **Consistency chart** — new section, see §3.
4. **Cut score row** — one line: `Cut score` left, `74` + `/100` right, and a 3-segment micro-bar (calories / protein / training) instead of three stacked sub-columns. Locked state: `Log 3 days to unlock` as a single secondary line. Disclaimer moves out of the dashboard.
5. **Weight** — see §4.
6. **Training row** — flat row, hairline separated: session title (`.headline`), status word secondary (`Due today`, `Done`, `Rest`), chevron. Drop the 42pt accent circle; use a plain SF Symbol at `.title3` in `hairline` color, accent only when due.
7. **Today** — food rows + a single inline `+ Log food` row. The bordered prominent full-width button is removed; the primary action becomes a `+` in the section header plus a toolbar-free inline row, matching reference 3's rhythm without the neon FAB. If pinned foods exist, a compact two-line chip block sits directly above the list (max 4, horizontal scroll, no capsule fill — hairline border, `.surface` background).
8. Empty state: `ContentUnavailableView` unchanged in spirit, copy shortened to "Nothing logged".

`TodayView` keeps `LoggingStreakDisplay`, `CutScoreSummary`, `WeightSummary`, `WorkoutStatusCard`, `FoodRow` as private subviews in the same file, restructured. No new files for the dashboard.

## 3. 30-day consistency chart (GitHub style)

New view `ConsistencyChart` in `CutLog/ConsistencyChart.swift`. Lazy path: `LazyVGrid`/manual `HStack` of 7 columns × 5 rows of rounded squares — **not** SwiftUI `Charts`, which cannot do a contribution grid. `Charts` stays for the weight sparkline and widget bar chart.

Data: `[DayLog]` for the last 30 calendar days ending today, from `store.foods` + `store.weights`. Day state is `logged` (either food or weight), consistent with the existing streak rule in `AppStore.loggingStreak(for:)`. New single source of truth: `AppStore.consistencyDays(days: 30)` returns `[(date: Date, logged: Bool)]`; `loggingStreak` is refactored to consume it so chart and streak can never disagree. This is the one place the old inline streak logic moves.

Cell rules:
- Size 14pt, `Radius.cell` 3, spacing 3, columns = last 7 days, rows scroll up in time (oldest row on top). 30 days = 4 full rows + 5 cells.
- `logged`: `accent` fill.
- not logged: `surface` fill, no border.
- today: 1pt `hairline` stroke so the newest cell reads as current.
- future/out-of-range: `Color.clear`.
- Only 3 visual states. No heatmap, no intensity ramp, no gradients. Reference 1's tick bar is the same idea rotated.
- Header above chart: `30 days` on the right, secondary, no descriptive sentence.
- Tap a cell: nothing. The chart is read-only.
- Accessibility: `.accessibilityElement(children: .ignore)`, label "Logging consistency, last 30 days, X of 30 days logged", value listing day + logged/not.

## 4. Weight chart: 30-day window

Problem: `TodayView` calls `store.weightTrend(days: 180)`, so one stale >100-day entry drags the Y domain and the X range. Data must not be deleted — the user said the entry is inaccurate, not that history should be rewritten.

Change: `store.weightTrend(days: 30)`.

Additional fixes in `WeightSparkline`:
- Y domain already pads to a minimum 1 kg range. Also clamp the X domain to the 30-day window explicitly (`chartXScale(domain: start...end)`) so sparse data cannot stretch the line edge to edge. When only one point exists in the window, show the `One weigh-in` line, not a flat line.
- Remove the "7-day average · 6 months max" caption and the "Last weighed …" line. Replace with: change value + `30 days` label, both `.caption`, secondary.
- Chart height 56. Line 1.5pt, `accent` at 0.9, no fill area, no points, no grid.
- If the window has no entries but older entries exist: `No weigh-ins in 30 days` + the "Add weight" affordance. Do not extend the window to fill the card.
- `HistoryView` remains the all-history destination (unchanged behavior), so old entries stay reachable.

## 5. Local food catalog + fuzzy search

Goal: every logged food becomes searchable in-app so relogging is one action. No new dependency, no SQLite, no SwiftData migration.

### 5.1 Model

`FoodCatalogItem` in `Models.swift`:

```swift
struct FoodCatalogItem: Codable, Hashable, Identifiable {
    var id: String            // normalized key: lowercased name + rounded serving grams + barcode
    var name: String
    var calories, protein, carbs, fat: Int
    var servingGrams: Double?
    var barcode: String?
    var lastUsedAt: Date
    var useCount: Int
}
```

Persisted as one new key `food-catalog-v1`. Existing keys untouched. This is a derived cache, not a new source of truth: the log stays in `foods`.

### 5.2 Write path

`AppStore.addFood(_:)` upserts the catalog item. `AppStore.init` builds the catalog from existing `foods` if the key is absent (one-time backfill, counts by frequency, `lastUsedAt` by latest log). `AppStore.foodCatalog` is `private(set)`; tests can seed it by logging food. `deleteFood` never touches the catalog.

`foodKey(for:)` in `AppStore` is reused as the catalog id, so pinning and catalog agree on identity. Keep the existing 8-item `recentFoods` for the Quick Log area? No — §5.3 replaces it; delete `recentFoods` rather than keep two competing lists. `pinnedFoods` and `quickLogFoods` stay.

### 5.3 Fuzzy search

New file `CutLog/FoodSearch.swift`. Pure functions, no UI, fully testable.

Scoring per query `q` (lowercased, diacritics folded, whitespace split into tokens):
1. Exact full-name match → 1000.
2. Catalog name starts with `q` → 800 − length penalty.
3. Any name token starts with `q` → 600 − token index.
4. Substring of name → 400.
5. All query tokens appear as name-token prefixes → 300.
6. Any query token appears as a name-token prefix (partial) → 120.
7. Levenshtein distance ≤ 2 against any name token (normalized) → 80 − distance * 20.

Return matches sorted by score, then `lastUsedAt` descending, capped at 25. Empty query → items by `useCount` then `lastUsedAt`, capped 25.

Levenshtein: two-row DP, ~15 lines, stdlib only. No index, no tokenizer dependency.

### 5.4 UI

`AddFoodView` becomes:
- `.searchable(text: $search)` on the existing `NavigationStack`, bound to `store.searchFoods(query:)`. One search field, no custom text field.
- When `search` is empty: keep the camera/photo/barcode Section first, then pinned, then `Log again` (catalog by use count).
- When `search` is non-empty: results list only, each row `name` + `320 kcal · P 24 g`. Tap = **log immediately** (`store.addFood`) and dismiss. Long-press/context menu = "Add with portion…" which fills the form for editing grams.
- The `P/C/F` secondary line and the pin Menu stay on each row.
- `FoodEntry` records logged from a catalog item keep the catalog item's serving, so a 190 g bar re-logs as 190 g.

## 6. Widget redesign

`CutLogWidget/CutLogWidget.swift`, same shared data, same `Info.plist`.

`systemSmall`:
```
CAL · MON 6          <- label row, secondary, tabular
2.040                <- metric font, primary
/2.450 kcal          <- secondary
▁▃▅▂▆▇              <- 7 columns, 2pt wide bars, hairline when unlogged, accent for today
```
No "Cut." caption, no dashed goal rule, no "kcal · 7 days" caption. Unlogged day = 1pt hairline tick, so missing stays visibly missing without inventing zeros. Nothing logged at all → `—` and `Open Cut.` secondary. Zero means zero.

`systemMedium`: left column as above, right column = `P 154 / 190 g` with one micro-bar and a hairline vertical separator. No workout or score panel.

Keep: `RuleMark` goal line only on medium. Keep the midnight rollover entry and `.after` policy as-is. Keep both existing accessibility labels, rewritten to the new layout.

## 7. Phases and files

Phase A — tokens
- `Shared/CutLogStyle.swift` (new; move `CutLogStyle` out of `CutLogWidgetData.swift`)
- `Shared/CutLogWidgetData.swift` (remove moved enum)

Phase B — data
- `Models.swift`: add `FoodCatalogItem`
- `AppStore.swift`: catalog upsert, backfill, `searchFoods`, `consistencyDays(days:)`, streak refactor
- `CutLog/FoodSearch.swift` (new)

Phase C — dashboard
- `CutLog/TodayView.swift`: full restructure, `weightTrend(days: 30)`
- `CutLog/ConsistencyChart.swift` (new)

Phase D — food logging
- `CutLog/AddFoodView.swift`: searchable, immediate relog, remove Recents
- `CutLog/HistoryView.swift`: unchanged

Phase E — widget
- `CutLogWidget/CutLogWidget.swift`

Phase F — tests, §8

Build check after each phase:

```bash
cd /Users/nilslin/dev/CutLog
xcodebuild -project CutLog.xcodeproj -scheme CutLog -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  build-for-testing CODE_SIGNING_ALLOWED=NO -quiet
```

## 8. Test suite

Existing 40 tests in `CutLogTests/CutLogTests.swift` stay and must keep passing. New tests, grouped.

### 8.1 `FoodSearchTests`
- `testExactMatchOutranksPrefixMatchAndPrefixOutranksSubstring`
- `testQueryTokensMatchNameTokensInAnyOrder`
- `testEditDistanceToleratesSingleTypo` (`chikn` → `chicken breast`)
- `testEditDistanceRejectsUnrelatedWord` (`banana` does not match `stir-fry`) — the search analogue of the existing estimate safeguard
- `testDiacriticsAndCaseAreIgnored`
- `testEmptyQueryReturnsMostUsedFirst`
- `testResultsCapAtTwentyFive`

### 8.2 `FoodCatalogTests`
- `testLoggingFoodCreatesCatalogItemWithUseCount`
- `testCatalogSurvivesRelaunch` (injected suite, new store instance)
- `testCatalogBackfillsFromExistingFoodsWithoutKey`
- `testSameNameDifferentPortionGetsDistinctCatalogItems`
- `testSamePortionLoggedTwiceIncrementsUseCountNotItems`
- `testDeletingALogKeepsCatalogItem`
- `testSearchingCatalogLogsItemPortionUnchanged`

### 8.3 `ConsistencyChartTests`
- `testThirtyDayWindowEndsTodayAndStartsTwentyNineDaysBack`
- `testDayCountsAsLoggedWhenOnlyWeightWasLogged`
- `testMultipleLogsSameDayProduceOneDay`
- `testDeletingLastLogOfDayFlipsCellToUnlogged`
- `testStreakAndChartAgreeOnSameInput` — guards the refactor
- `testFutureDaysAreNotIncluded`

### 8.4 `WeightWindowTests`
- `testWeightTrendIgnoresEntriesOlderThanThirtyDays` — regression for the >100-day entry wrecking the chart
- `testSingleEntryInWindowDoesNotProduceFlatLine`
- `testEmptyWindowReturnsNoPointsAndNoCrash`
- `testSevenDayAverageStillSmoothsWithinWindow` (keeps existing rolling-average behavior)

### 8.5 `WidgetLayoutTests`
- `testWidgetShowsDashWhenNothingLogged` (no fake zero)
- `testWidgetRolloverKeepsSevenCalendarDays`
- `testWidgetProteinOnlyOnMediumFamily` (data-level: family selector returns data only for medium)
- `testWidgetUnloggedDayRendersTickNotBar`

### 8.6 Regression guards for the redesign
- `testCalorieNumberIsConsumedTotalNotRemaining`
- `testOverGoalSwitchesToOverLabelAndDoesNotNegativeNumber`
- `testPersistedKeysUnchangedAfterRedesign` — asserts the eight existing keys still round-trip, protecting installed data
- `testDesignTokensHaveNoRoundedFontDesign` — asserts the hero/metric fonts are not `.rounded`, cheap guard against the old look creeping back

### 8.7 Manual acceptance (device, after Xcode signing works)

1. Install update over existing app (`⌘R`). Foods, weights, workouts, plan, settings survive.
2. Dashboard: single screen, no scroll-jacking, consumed calorie number, over-goal state, 3 macro micro-bars.
3. Consistency chart: 30 cells, oldest row top, today outlined, matches streak, tap does nothing.
4. Weight chart: 30-day window; the >100-day entry no longer appears or rescales it; no caption above the chart.
5. Food search: type `piza` → pizza results; tap logs immediately; long-press edits portion; barcode re-logs same grams.
6. Widget small + medium, light/dark, empty state, rollover.
7. Dark mode, Dynamic Type at AX sizes, VoiceOver on dashboard and chart.

## 9. Risks

- **Test execution blocked.** App targets iOS 27.0, only iOS 26.5 runtime installed. `build-for-testing` compiles only. If tests must run, build a macOS harness from real source files only, no mocks replacing production logic.
- **Device signing blocked** for team `69X37B2BSP`. Widget layout, camera, Health and the visual pass need a signed device.
- **SwiftUI `Charts` X-domain**: if `chartXScale` still stretches a single point, drop to a plain `Path` sparkline instead of fighting the framework.
- **Searchability on a sheet** does not always present the search bar on first appearance; if it hides, use a plain `TextField` pinned at the top of the form. Decide during Phase D, do not build both.