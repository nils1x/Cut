# Cut. — product contract

## Product
A local-first iPhone tracker for the loop that matters: log food, hit protein, train, move, repeat. It covers the useful job of calorie trackers without accounts, subscriptions, ads, a backend, or an algorithm pretending it knows your soul.

## Core tracking
1. **Today** — calories, protein, 7-day weight-average trend, direct barcode/photo/manual food actions, and one training card.
2. **Food** — manual entry, recent foods, camera estimate, and Open Food Facts barcode lookup. Every route ends in editable macros.
3. **Health** — optional Apple Health connection, requested only after tapping Connect. Local data remains authoritative.
4. **Widget** — read-only calories, protein, and workout status from the existing App Group snapshot.

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
- Log every set with weight, reps, RIR, and completion state.
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
The `Plan` tab intentionally shows only the next session, four compact weekday rows, and one concise cut rule. Tap a day to inspect that session; tap an exercise for cues, targets, alternatives, and progression. `Edit` saves a fully local, editable template. There are no exercise photos by design.

## Constraints
- No account, subscription, server, custom food database, social feed, or automatic calorie changes.
- Barcode lookup is the only required network request and uses Open Food Facts.
- Apple Intelligence meal estimates run on-device where available and never block manual logging.
- Widget and HealthKit failures cannot block food or workout tracking.
- The display brand is `Cut.`; technical bundle IDs and App Group names remain `CutLog` for signing and installed-data stability.

## Definition of done
- App builds for iOS 27.
- Food, weight, plan edits, and workout records survive relaunch.
- Monday/Wednesday/Friday/Sunday map to Upper A/Lower A/Upper B/Lower B.
- Each exercise stores muscle group, sets, reps, RIR target, rest, progression cue, and alternatives.
- Each workout logs weight, reps, RIR, and completion per set.
- Dashboard trend is derived from daily rolling 7-day weight averages.
- Apple Health permission remains explicit and opt-in.
