# Cut. — Redesign Round 2

Status: plan only. No file changed.
Supersedes the visual parts of `PLAN_REDESIGN.md`. Its data work (food catalog, 30-day weight window, fuzzy search) shipped and stays.
Source of truth remains the checkout; `HANDOFF.md` §1 still applies.

## 0. Answering the direct questions first

**"I think you don't have vision and can't view images or websites."** Wrong on both counts. I read the three reference JPGs in `~/Downloads` in this session and described them (sage Ghost.build-style dashboard with tick bar; Nutrie metric cards; the neon streak tracker). I fetched the Nutrie App Store page and read its full description. You can give me references three ways:
- Drop JPEGs/PNGs anywhere and tell me the path. I read them directly.
- Paste an App Store URL. I get the marketing text but **not** the screenshot images.
- Paste a link to a GitHub repo or a blog post with code. I read those fully.
Screenshots from the App Store listing itself I cannot see. If you want me to see Nutrie's actual UI, screenshot it and drop the file in `~/Downloads` like last time.

**"Apply iOS design skills."** Loaded the `mobile-ios-design` skill. Read Apple's own iOS 26/27 material plus the Liquid Glass design gallery and the revised design resources. Concrete takeaways folded into §1.

**Nutrie reference, honestly:** its App Store text is generic (AI photo logging, macros, weight tracking). Nothing there is worth copying. Its only real design signal from the page is "clean, minimalist interface" as a marketing claim. The *other* Nutrie screenshot in your Downloads folder — the light one with the `Check / your health` header, `2.040` hero, tick progress bar, `Protein 154 Fats 154 Carbs 154` row, and the Breakfast card with a thumbnail and pencil button — that is a genuinely good reference and I am designing against it. Do not expect more from the store page.

**Open source, checked:** `HeatmapKit` (jacklv-coder), `SwiftUI-ContributionChart` (VIkill33), `AxisContribution` (jasudev), `contribution-graph-swiftui` (pruizlezcano). All are real, all MIT, all do what my hand-rolled grid already does. **Recommendation: add no dependency.** Our grid is 40 lines, needs four bespoke levels rather than a generic palette, and a package would add supply-chain surface for nothing. If the grid later grows month labels or scroll-to-week, revisit HeatmapKit. The useful thing I took from that research is their level model: first palette color = empty, remaining = progressively intense, thresholds explicit.

## 1. Design system

### 1.1 Color — kill the olive, add pastels

The moss accent is the single worst part of the current build. It reads muddy in light mode and dead in dark mode. Replace it.

Monochrome base stays semantic: `.primary`, `.secondary`, `.tertiary`, `Color(.secondary).opacity(...)`.

One new file, `Shared/CutLogPalette.swift`. Adaptive pairs via `@Environment(\.colorScheme)` at the view layer, or `Color(uiColor: UIColor { traits in ... })` for a value that adapts automatically with no environment plumbing. Use the latter — fewer call sites, no threading.

```swift
enum CutLogPalette {
    /// Empty / no data. Also the heatmap's level 0.
    static let track = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? .init(white: 1, alpha: 0.10) : .init(white: 0, alpha: 0.07)
    })
    /// Primary accent: warm apricot pastel. Replaces moss everywhere.
    static let apricot = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? .init(red: 1.00, green: 0.72, blue: 0.52) : .init(red: 0.85, green: 0.42, blue: 0.18)
    })
    /// Secondary accent: dusty periwinkle. Heatmap levels + protein.
    static let periwinkle = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? .init(red: 0.66, green: 0.71, blue: 0.95) : .init(red: 0.38, green: 0.44, blue: 0.82)
    })
    /// Tertiary: soft sage, training only. Never competes with apricot.
    static let sage = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? .init(red: 0.66, green: 0.78, blue: 0.64) : .init(red: 0.40, green: 0.55, blue: 0.38)
    })
    static let hairline = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? .init(white: 1, alpha: 0.12) : .init(white: 0, alpha: 0.10)
    })
    static let surface = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? .init(white: 1, alpha: 0.06) : .init(white: 0, alpha: 0.035)
    })
}
```

Rules that make this "pastel, minimal, accent only":
- **One accent per screen region.** Calories = apricot. Protein/training = periwinkle. Training = sage. Never two accents in the same component.
- Pastel means *low saturation fills with one saturated stroke or one saturated numeral*. Large areas stay near-neutral. A pastel is not a license to paint backgrounds.
- **Two colors maximum in the heatmap** (apricot levels + sage for training-only days). Three colors there would be noise.
- Semantic red stays `.red` and is used for exactly two things: over calorie goal, and destructive delete. Never for decoration.
- No gradients. No `.shadow`. No `.ultraThinMaterial` in app content. Liquid Glass applies to system chrome (nav bar, tab bar, sheets) automatically and for free; do not hand-roll glass.
- App icon: the untracked `C.` mark on charcoal still carries a moss dot. Recolour the dot to apricot or drop it. One-line change, do not redesign the mark.

`CutLogStyle.accent` is replaced by `CutLogPalette.apricot`. `MetricBar` default tint follows. Update `RootView`'s `.tint`.

### 1.2 Type and rhythm

Keep `.default` font design (already shipped, no `.rounded`).

```
hero    56 semibold monospaced   calories only, exactly one per screen
metric  26 semibold monospaced   section values
value   17 medium monospaced     row values
label   13 medium secondary      section + field labels
caption 12 secondary            dates, deltas, axis
```

New scale rules that fix the bloat complaint:
- **One `hero` per screen.** Everything else is `metric` or smaller. Calories are the only number big enough to shout.
- **Vertical rhythm is 8pt.** Cards get 16pt internal padding, 20pt between sections. No more arbitrary gaps; the current free-space problem is inconsistent spacing, not too much spacing.
- **Align section labels to the same left edge as values.** Today the labels, values, and bars each float at their own indent.

### 1.3 Reusable shapes

Deliberately five, in `Shared/CutLogStyle.swift`. Anything that gets a sixth is a sign of over-abstraction.

| Shape | Purpose |
|---|---|
| `Card` | flat surface, 16 radius, no shadow (exists) |
| `MetricBar` | hairline track, square ends (exists) |
| `SectionLabel` | uppercase-free 13pt secondary label + optional trailing accessory |
| `KeyValueRow` | label left, value right, hairline bottom — replaces hand-rolled rows |
| `StatTile` | value + label, no surface, for use *inside* a card |

No `hairlineBottom()` extension (not shipped, not needed). No view-model protocol, no `DesignSystem` struct wrapper, no theming layer.

## 2. Consistency chart — GitHub intensity levels

This is the biggest single change and it fixes "not thought through" more than anything else.

### 2.1 Data

New pure enum in `Models.swift`, next to `Consistency`:

```swift
struct ConsistencyDay: Identifiable, Equatable {
    enum Level: Int, CaseIterable { case none = 0, weightOnly = 1, food = 2, trained = 3, full = 4 }
    let date: Date
    let level: Level
    var id: Date { date }
}
```

Level assignment, in priority order:
- `full` — food logged **and** a scheduled workout completed that day (any set completed).
- `trained` — scheduled workout completed, no food.
- `food` — food logged, no workout.
- `weightOnly` — weight logged, no food, no workout.
- `none` — nothing.

Direction **confirmed by the owner: same as GitHub.** More things logged = more saturated cell. "Lighter" in the original brief meant "less visually heavy as a section", not a paler cell.

Level caps (each level = base color at one opacity, no interpolation):
- 0 → `palette.track`
- 1 → sage 0.35
- 2 → apricot 0.30
- 3 → apricot 0.60
- 4 → apricot 1.0

Two hues only. Training-only days are sage so a full week of lifting reads differently from a full week of eating, at a glance, without a legend.

The `loggingStreak` rule ("food or weight counts") is **unchanged** and stays in `AppStore`. A level-1 day still counts for the streak. Levels change color only, never streak semantics.

`AppStore.consistencyLevels(days: 30)` returns `[ConsistencyDay]`. It reuses the existing `Consistency.days` window and the existing `WorkoutSchedule.scheduledWorkout(on:)` + template/day matching from `CutScore`. No new workout-matching logic.

### 2.2 Layout

New `ConsistencyChart.swift` rewrite:
- 7 columns × 5 rows for 30 days, oldest row on top, today outlined with `hairline`.
- Cell 15pt, gap 3pt, corner radius 3 — fits 7×(15+3) = 126pt wide, which is what makes the side-by-side layout in §3 possible.
- **No legend.** The four-step ramp is self-evident; a legend is what made the current version feel fussy. The accessibility label carries the meaning for VoiceOver.
- Weekday axis labels: none. Month labels: none. 30 days doesn't need them.
- Interactive: tapping a cell does nothing. Read-only. (HeatmapKit's `onCellTap` is the feature we'd want if we ever add day detail, which is out of scope.)

## 3. Dashboard layout — two columns, one screen

The complaint is real: blocks float, gaps are arbitrary, the Cut score interrupts. Fix by making the dashboard a **fixed grid, not a stack of independent cards**.

```
Cut.                              🔥 12
Tuesday, 6 October

┌─────────────────────────────────────┐
│  2.040            │   CONSISTENCY   │
│  / 2.450 kcal     │   ▓▓▒▒░░▓       │
│  ▬▬▬▬▬▬▬░░░░      │   ▓▓▓░░▓▓       │
│  P 154  C 198  F 61│  ▓░▓▓▒▒▓       │
└─────────────────────────────────────┘
   calories block        30-day grid

┌─────────────────────────────────────┐
│  97.4 kg          │   Upper A        │
│  −0.3 kg · 30d    │   Due today  ›   │
│  ╱╲__╱╲___        │                  │
└─────────────────────────────────────┘
   weight + sparkline  training nudge

╭─────────────────────────────────╮
│         ＋  Log food            │   56pt, apricot, full width
╰─────────────────────────────────╯

  Breakfast              420 kcal
  ────────────────────────────────
  Lunch                   610 kcal
```

Rules:
- **Calories block and consistency grid sit side by side** in one card. Calories left at ~55% width, grid right. This is the "weight next to the streak widget" request, applied to the pair that earns the space. Height matches: grid is 5×18 = 90pt, so the left column uses `hero` + bar + macros in 90pt.
- **Weight and training sit side by side** in the next row, mirrored. Weight value `metric` + sparkline; training is a compact accent row, sage when due.
- **One card, two columns, 20pt between rows.** No orphaned single-width card anywhere except the log button.
- **Cut score is removed from the dashboard entirely.** See §4.
- Sparkline drops to 32pt height here; full-size chart lives in History.
- The 56pt Log food button: `.buttonStyle(.borderedProminent)`, `.tint(palette.apricot)`, `.controlSize(.large)`. Bigger as asked, and it is the only filled button on the screen.

Dropped: the `Calories` + date label row above the hero (the date is already in the header), the three-macro micro-bars (protein keeps a bar, carbs and fat do not — no goal to measure against, so a bar there is decoration).

### 3.1 Reminder to train, every app open

`RootView` gains a `@State private var pendingNudge: Bool`. On `scenePhase == .active` (and only when the app was backgrounded, so it does not fire on first launch before the user has seen it):

```swift
guard store.workoutIsDue, !store.settings.reminderEnabled || nudgeShownThisSession == false else { return }
```

Simplest honest implementation: `nudgeShownThisSession` resets when phase leaves `.active`.
- If `store.workoutIsDue` and the nudge has not fired this foreground session → `safeAreaInset(edge: .bottom)` on `TodayView` shows a slim sage bar: `Upper A is due today` + `Start` button + `chevron.forward` to the Plan tab. Tapping Start opens the workout sheet directly.
- If the user already trained today, the bar is not shown. Showing "you already trained" every morning is noise.
- The existing 6 PM local notification (`WorkoutReminder`) is **unchanged**. This is an in-app nudge, not a replacement, and it does not require notification permission.

`nudgeShownThisSession` is `@State`, never persisted. Persisting it would mean a user who ignores it for a week never sees it again, which is the opposite of the request.

## 4. Cut score relocation

Current state: a labeled row with three segments sitting between the energy card and weight, interrupting the read. It is a derived statistic about the *past week*, not a live value about *today*. That is why it feels bolted on.

**Move to Settings → "Cut score" section**, which already got the non-medical disclaimer last round. There it becomes:
- A `NavigationLink` to `CutScoreView`.
- `CutScoreView` shows the score `metric`, the three components as `KeyValueRow`s, the 7-day window in the nav title, and the disclaimer.
- Settings also gets a one-line summary under the link: `Last 7 days: 74/100` or `Log 3 days to unlock`.

`CutScore.calculate` is untouched. No new scoring logic. This is purely a move.

Rationale to state plainly: a dashboard should show today's state. The score is a weekly retrospective. Putting it on the dashboard cost it prominence and cost the dashboard clarity.

## 5. Widget — bigger, fewer things

Current widget wastes most of a 155×155pt small slot on a caption, a tiny number, and an 18pt bar row. Fix by scaling everything up and deleting labels.

### 5.1 Small

```
2.040                     <- 34pt semibold monospaced, primary
/ 2.450 kcal              <- 12pt secondary

▇▇▇▇▇▇▇▇▇▇▇▇▇▇            <- 28pt tall, 7 columns, goal-scaled
```

- Header row (`CAL` + weekday) **deleted**. The number needs no label.
- Number 26pt → 34pt.
- Bar row 18pt → 28pt.
- Unlogged day = 1pt tick at the bottom, still not a zero bar.
- Over goal: number turns `.red`, no extra "over" word. The number going red is the signal.
- Nothing logged at all: `—` at 34pt plus `Open Cut.` at 12pt secondary.

### 5.2 Medium

```
2.040        │  ▇▇▇▇▇▇▇▇▇▇▇▇▇▇
/ 2.450 kcal │  ▇▇▇▇▇▇▇▇▇▇▇▇▇▇
             │
P 154 g      │  ▇▇▇▇▇▇▇▇▇▇▇▇▇▇
▬▬▬▬▬▬▬░░░  │
```
- 0.5pt hairline divider, not a drawn `Rectangle`.
- Left column: number 30pt, goal caption, protein value, protein bar.
- Right column: 28pt bars filling the full height.
- No header row, no captions under the bars, no dashed goal rule.

### 5.3 Widget data

`CutLogWidgetData` unchanged from the last round (`proteinGoal`, `proteinToday`, `calories(on:)`, `protein`). No new fields, so no new decode risk.

`CutLogWidgetFamily` stays deleted. The small/medium split is a SwiftUI branch, which the widget already does.

## 6. Plan tab — make training significant

Currently the Plan tab leads with a card, then a "This week" list, then a rules card. Nothing about it says "this is the reason the app exists."

Restructure to:
1. **Hero session card** at top, 96pt tall minimum, sage accent when due, showing template title at `title2`, the muscle subtitle, estimated minutes, and a full-width `Start Upper A` `.borderedProminent` button tinted sage. Tapping the card body goes to detail; the button starts.
2. **Week strip** — a horizontal row of 4 compact day cells (Mon/Wed/Fri/Sun), each showing the short day, template initial, and a filled dot when complete. This is the "significant" part: the whole week visible at a glance without scrolling. Tapping a cell opens that template's detail. Today gets a ring.
3. **Plan rules** demoted to a collapsed `DisclosureGroup`.
4. `.navigationTitle` hidden, replaced by an in-content `Plan` label matching the Today header, for tab-to-tab consistency.

`PlanRuleCard` content unchanged. `TrainingPlanView` keeps every existing sheet (workout, detail, editor) and all workout-draft logic. **Zero behavior change here — this section is layout only.**

## 7. History tab — the main cleanup

Current problems: `Picker(.segmented)` + `List(.insetGrouped)` + `DisclosureGroup` per workout. Functional, generic, uninspired.

Target: **one scroll view, custom rows, calendar-grouped.**

### 7.1 Weight section
- Header row: current weight `metric`, delta over the selected range, `· 30 days` range chip.
- Range chips: `30d · 90d · All` — `Space.horizontal` segmented pills, hairline border, apricot when selected. Replaces "All weigh-ins" navigation into a second screen.
- Full-height sparkline at 140pt with the 7-day-average line and **no axis labels at all** — the range chip plus the delta carry the meaning. Y domain keeps the 1 kg minimum floor.
- Below: weigh-ins grouped by month, `Section`-like custom headers (`October`), rows via `KeyValueRow`. Month header is sticky-feeling because it's just bold secondary text in the same scroll; no `List` sticky pinning.
- Weight rows show date, value, and a per-row delta from the previous entry. Tapping a row opens `AddWeightView` pre-filled for edit (new capability, small).

### 7.2 Workouts section
- Header row: sessions this month + total volume, `metric`.
- Grouped by month. Each workout is a **flat row, not a `DisclosureGroup`**:
  - Line 1: template title, `.headline`, plus a `+` set-count chip.
  - Line 2: date · duration · `12 sets`.
  - The heavy set numbers (top set per exercise) appear on a single indented sub-line, only when present.
  - No chevron, no expansion animation, no nested list indentation.
- This kills the double-indent-inside-List-inside-Section problem that makes the current view feel cramped.

### 7.3 Structure

```swift
ScrollView {
    VStack(spacing: 24) {
        rangeChips              // weight only
        if weight: WeightHeroCard { sparkline } { month groups }
        else: WorkoutHeroCard { month groups }
    }
}
```

Both sections stay behind one top-level range/segment control, but the control moves from a system `Picker` to three hairline pills so it matches the new visual language. It stays in the navigation bar area via `.toolbar` placement `.principal` — no, keep it as the first row of the scroll so it scrolls away and gives the hero full width. Decide at build; leaning scroll-away.

Delete `AllWeightLogsView` — the `All` chip now shows everything inline.

## 8. Files and phases

```
Phase A  Shared/CutLogPalette.swift   (new)  apricot/periwinkle/sage/track/hairline/surface
         Shared/CutLogStyle.swift              accent -> apricot; add SectionLabel, KeyValueRow, StatTile
         CutLog/Assets.xcassets/               icon dot recolour
Phase B  CutLog/Models.swift                  ConsistencyDay + level assignment
         CutLog/AppStore.swift                consistencyLevels(days:)
         CutLog/ConsistencyChart.swift         5 levels, 15pt cells, no legend
Phase C  CutLog/TodayView.swift               two-column grid layout, log button 56pt, nudge
         CutLog/RootView.swift                tint, nudge state
Phase D  CutLog/CutScoreView.swift   (new)   score detail
         CutLog/SettingsView.swift            score link + summary
         CutLog/TodayView.swift               remove score row
Phase E  CutLogWidget/CutLogWidget.swift      34pt number, 28pt bars, no headers
Phase F  CutLog/TrainingPlanView.swift        hero card, week strip
Phase G  CutLog/HistoryView.swift             custom scroll, pills, month groups
         CutLog/AddWeightView.swift           pre-filled edit
Phase H  tests (§9)
```

`xcodegen generate` after Phase A and F (new files). Inspect `project.pbxproj` diff each time.

Build gate, after each phase:
```bash
xcodebuild -project CutLog.xcodeproj -scheme CutLog -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  build-for-testing CODE_SIGNING_ALLOWED=NO -quiet
```

## 9. Tests

Existing 76 tests must keep passing. `testDesignTokensAvoidRoundedFontDesign` stays. `testStreakAndChartAgreeOnTheSameInput` stays and is the guard that level colors never leak into streak semantics.

### 9.1 `ConsistencyLevelTests`
- `testLevelIsFullWhenFoodAndScheduledWorkoutBothComplete`
- `testLevelIsTrainedWhenWorkoutOnly`
- `testLevelIsFoodWhenFoodOnly`
- `testLevelIsWeightOnlyForWeightAlone`
- `testLevelIsNoneForUnloggedDay`
- `testUnscheduledWorkoutDoesNotRaiseLevel` — Tuesday squat is level 2 at most, never 3/4
- `testEveryLevelHasAPaletteEntryAndAllAreDistinct`
- `testLevelsUseAtMostTwoHues` — parses the palette table, fails if a third hue appears
- `testWeightOnlyDayStillCountsForStreak` — level 1 must not change streak math

### 9.2 `PaletteTests`
- `testPaletteHasNoMossRemaining` — asserts no token still carries the old `0.39, 0.45, 0.35` value
- `testAccentDiffersBetweenLightAndDark` — apricot must not be one flat value in both schemes
- `testSemanticRedIsNotUsedForDecoration` — source scan of `TodayView.swift` for `.red` outside the over-goal branch

### 9.3 `DashboardLayoutTests`
- `testNudgeShowsOnlyOnDueDayAndOnlyOncePerForeground`
- `testNudgeHiddenAfterTrainingToday`
- `testNudgeStateIsNotPersisted`
- `testTodayViewRendersExactlyOneHeroFont`

### 9.4 `HistoryTests`
- `testRangeChipsSelectThirtyNinetyAndAll`
- `testThirtyDayRangeExcludesOlderWeighIns` — the original >100-day-entry regression, now through the chip API
- `testMonthGroupingIsChronologicalDescending`
- `testWorkoutRowUsesLoggedSetsNotTemplateCount`
- `testWorkoutRowOmitsMissingFieldsRatherThanShowingZero`

### 9.5 `WidgetLayoutTests`
- `testWidgetBarsScaleToGoalNotBusiestDay` — exists
- `testUnloggedDayIsATickNotAZeroBar`
- `testNothingLoggedRendersDash`
- `testSmallFamilyExposesNoProtein`

### 9.6 Manual acceptance (needs signed device)
1. Light and dark mode side by side. Apricot reads as pastel, not neon; sage never competes.
2. Dashboard fits one screen on iPhone 17 Pro without scrolling the log button out of reach.
3. Consistency grid: 30 cells, 5 levels distinguishable, today outlined, no legend clutter.
4. Training nudge appears on a Mon/Wed/Fri/Sun due day, not on Tue, not after training.
5. Cut score reachable from Settings, gone from the dashboard.
6. History: range chips switch cleanly, month groups read well, no nested indentation.
7. Plan tab: week strip visible without scrolling.
8. Widget small + medium, light + dark, empty + populated + over-goal.

## 10. Risks

- **Level direction confirmed by the owner: same as GitHub.** More things logged = more saturated cell. Locked.
- **Test execution still blocked.** Target iOS 27.0, only iOS 26.5 runtime. `build-for-testing` compiles only. Use a macOS harness from real source files for pure logic — no mocks standing in for production code.
- **History rewrite is the largest surface.** Weight and workout rows both change. Nothing about persistence changes, so a rollback is a `git checkout` of one file.
- **`UIColor` dynamic providers and the widget.** Widgets render in both schemes; `UIColor` closures handle this, but it cannot be verified without a signed build. If the widget comes out with the wrong scheme color, fall back to `@Environment(\.colorScheme)` in the widget view only.
- **Two-column dashboard at AX sizes.** `.dynamicTypeSize` above `.accessibility1` will not fit two columns. Collapse to a single column at `.dynamicTypeSize.isAccessibilitySize` rather than truncating.
- **Do not add HeatmapKit.** Revisit only if the grid grows month labels, tooltips, or week-anchored scrolling.