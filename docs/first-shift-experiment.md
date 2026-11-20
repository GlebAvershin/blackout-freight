# First-shift compass experiment

## Hypothesis and design

A camera-relative bearing should help new players turn toward a battery or airlock when the existing waypoint is outside the usable screen area. The primary metric is the share of eligible solo participants who personally deliver a battery within 90 seconds of enrollment. The candidate adds a localized arrow and distance while the waypoint is off-screen. Control uses the existing world waypoint. Pickups within 90 seconds diagnose where friction changes. Being caught at least once within the same window is the guardrail.

Enrollment occurs once per Roblox server visit when the player has a live character, a loaded journal with no endings, and has yet to pick up a battery in this visit. The standard Depot 07 shift must be live at Heat 1 with at least 90 seconds remaining. Daily challenges and special routes are outside the experiment. The server assigns the same bucket to an account across visits using the versioned hash. Studio previews the compass for every eligible visit. The compass disappears after the first personal delivery or once the window or shift ends. `Config.FirstShiftCompassEnabled` controls enrollment.

The sole decision-making cohort is a closed playtest with one monitored, unsupervised solo attempt per participant. Recruit before assignment, isolate solo servers, and allow an early exit to count as an exposed attempt without a delivery. Avoid sharing intervention details before joining. Stop enrollment at a fixed, preregistered cutoff and run the analysis once, after telemetry has settled. A late joiner can affect play for an initially solo player. Public solo/crew splits therefore use crew size at enrollment, and are suitable for descriptive monitoring. Rejoining can generate another exposure in the same arm.

## Telemetry contract

Roblox Custom Events → `FirstShiftCompassV1`, aggregation **Count**. Every call adds a value of 1. Studio and known internal accounts are filtered from the experiment cohorts by AnalyticsPolicy. No participant identifiers are added to the custom fields or the CSV.

| Field | Values |
| --- | --- |
| CustomField01 | `control`, `compass` |
| CustomField02 | `exposed`, `pickup_90`, `delivered_90`, `caught_90` |
| CustomField03 | `solo`, `crew`; internal smoke tests use `qa_solo`, `qa_crew` |

Events are server-side and deduplicated by stage within the enrolled shift. A pickup and delivery use the accepted battery action. Catches are reported for the full observation window, including after delivery if the shift is still live. Results from later shifts cannot satisfy earlier exposures. The metrics count eligible attempts, including players who leave. They do not measure retention or completion of all five deliveries.

Studio verifies the preview; event ingestion requires an eligible account in a published experience. In Creator Hub, confirm the event and custom field combinations with **View Events** after publishing to the intended environment. Use Explore with Count and filter variant, stage and segment over the same full window, including at least 90 seconds after the last enrollment. Roblox aggregates custom events daily, so wait for the last day to populate. Keep the controlled study isolated from unrelated public traffic. [Roblox Analytics documentation](https://create.roblox.com/docs/production/analytics/custom-events)

Filter **CustomField03** to `solo` or `crew` before exporting counts. Transpose totals to `segment,variant,event,count`, one row for each combination. Include a zero after confirming the cohort/event was genuinely empty. The schema checks refuse missing, duplicate or inconsistent counts. Never add unique-user counts across days.

The published closed test accepts explicit QA launches from its two internal accounts. Use the Roblox Player deep link `roblox://placeId=111633787401180&launchData=freight-qa-compass-v1` for treatment or replace `compass` with `control` for the baseline. A solo QA launch uses the standard Depot 07 map for its first eligible shift even when the account already has both endings. The experiment events keep their QA segment and ordinary analytics still excludes those accounts. [Verified live records](portfolio-release-2026-11-16.md)

## Analysis and decision rule

Use a 50:50 allocation, two-sided 95% Newcombe intervals for absolute rate differences, and an exact binomial sample-ratio check at 0.01. The planned minimum is 1,200 solo participants per arm. At a baseline of 60%, 80% power and two-sided alpha 0.05, a change to 68% requires roughly 564 per arm. A 25% baseline catch rate and 5-point noninferiority margin require about 1,178 per arm using a normal approximation at 80% power and a 97.5% one-sided bound. The planned sample uses the larger requirement, rounded up. These figures are design assumptions.

At the fixed look, consider rollout if the solo estimate is at least +8 percentage points, the lower delivery bound is above zero, and the upper catch bound is at most +5 points. Investigate assignment when the solo sample-ratio check fails or when the absolute exposure count difference divided by total exposures exceeds 5% in either segment. The latter is a descriptive instrumentation check applied before rounding. A segment with no exposures has no measured gap. Keep release windows distinct when comparing compass implementations. A smaller sample is inconclusive. The crew segment and pickup rate are exploratory.

```sh
uv sync --project analysis --locked --python 3.12 --group notebook
uv run --project analysis --locked python analysis/compass_report.py analysis/synthetic_compass_counts.csv --source synthetic
uv run --project analysis --locked --group notebook jupyter nbconvert --execute --to html analysis/first_shift_compass.ipynb --output-dir .tools
```

Use `--source playtest` for the controlled sample above and `--source production` for aggregate monitoring. The checked-in totals are synthetic, and the shipped notebook is a worked example. The analysis runs locally with DuckDB SQL, pandas, SciPy and statsmodels.
