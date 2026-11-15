---
name: freight-experiment
description: Review the Blackout Freight compass A/B design, validate the Roblox event contract, or interpret a report.
---

# First-shift compass experiment

1. Read `docs/first-shift-experiment.md` for enrollment, outcome definitions and source eligibility. Check that each Luau call uses the documented variant, stage and cohort.
2. Use the MCP resource `freight://experiments/first-shift-compass-v1` and the `analyze_compass_demo` tool to retrieve the design and reproduce the simulated result. The same calculation runs through `analysis/compass_report.py`.
3. Identify the source, exposure counts and analysis unit before interpreting effects. For one-session solo playtests, check the allocation ratio, sample size, primary interval and catch-rate guardrail. Show rates and the percentage-point difference.
4. Record the decision and its supporting rows. Keep open production traffic descriptive when participants could rejoin or interact with other crews. Label synthetic results in any report.
