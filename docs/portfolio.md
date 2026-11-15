# Blackout Freight · Portfolio

**Role** · Solo developer of a 1–4 player co-op Roblox game. The crew scavenges batteries under pressure, powers the depot, and chooses between broadcasting evidence and supplying a shelter.

[Watch the v24 gameplay demo](../dist/blackout-freight-v24-demo.mp4) · [Download the Studio preview](https://raw.githubusercontent.com/GlebAvershin/blackout-freight/main/dist/Blackout%20Freight%20Portfolio%20Preview.rbxl) · [Open the analysis notebook](../analysis/first_shift_compass.ipynb)

The demo shows the first-shift compass pointing back to the airlock while the player carries a battery. The bearing disappears after delivery and the depot’s power increases to 1/5. Version 24 was published on November 16, 2026. The hosted Roblox experience is available to approved playtesters. The Studio preview is available to anyone with Roblox Studio. [Roblox experience](https://www.roblox.com/games/111633787401180/Blackout-Freight) · [Release and live QA evidence](portfolio-release-2026-11-16.md)

## Five-minute demo

1. Open the Portfolio Preview in Roblox Studio and select **Play**. Turn away from the first battery to see the HUD compass, then turn back to the waypoint. Press **E** at the battery and follow the amber airlock bearing after pickup.
2. Deliver a battery. The compass retires after the first delivery and the shift continues. Run **Server & Clients** to demonstrate shared objective, role abilities and crew pings.
3. Open the [first-shift notebook](../analysis/first_shift_compass.ipynb) for the worked experiment. The charts use synthetic counts. The [experiment contract](first-shift-experiment.md) describes the actual runtime telemetry and controlled playtest.

## AI-Native Software Engineer

- **Gameplay.** The Luau server owns round state, validation and experiment enrollment. The camera-relative compass is client-side UI. Studio previews the treatment, and the published runtime can allocate players consistently by account. [Runtime experiment](../src/server/FirstShiftExperiment.luau) · [Compass UI](../src/client/FirstShiftCompass.luau)
- **AI-assisted development.** The Codex implementation was checked against Luau unit tests, a real Studio client and reproducible analytics. Reusable skills cover release review and experiment interpretation. A Python stdio MCP server supplies the versioned event contract and runs the demo analysis as a read-only tool. [Release skill](../.agents/skills/freight-release/SKILL.md) · [Experiment skill](../.agents/skills/freight-experiment/SKILL.md) · [MCP server](../analysis/freight_mcp.py)
- **Verification.** GitHub Actions passed both the game and analytics jobs. It compiled and tested Luau, built the Roblox place with Rojo, ran Python and stdio MCP tests, and executed the notebook. The game also includes persistent progression, seasonal objectives, daily shifts, and scripted multiplayer Studio tests. [Passing CI run](https://github.com/GlebAvershin/blackout-freight/actions/runs/43774305789) · [CI workflow](../.github/workflows/verify.yml) · [Game overview](../README.md)

Version 24 passed 16 Luau suites, seven Python tests, and desktop and mobile Studio checks (638×241 landscape and 413×756 portrait). An independent Studio process reopened the published place and matched all 43 scripts to the Rojo project. [QA report](portfolio-release-2026-11-16.md)

## Product Analyst

- Defined success as a first delivery within 90 seconds and used the share of players caught within the same window as a guardrail. The design calls for one solo attempt per participant, a fixed sample, a sample-ratio mismatch check, and confidence intervals.
- Integrated server-side Roblox Analytics. Normalized the aggregate counts into a validated contract, used DuckDB SQL for the funnel and cohort rates, and used pandas, SciPy and statsmodels for the Jupyter analysis.
- Verified eight event records in Creator Hub from two internal QA sessions. Both control and compass recorded exposure, pickup, delivery, and catch. The analysis notebook uses a simulated cohort and excludes internal QA traffic from the participant analysis. Measuring the compass’s effect requires a controlled participant cohort. [Experiment contract](first-shift-experiment.md) · [Live event evidence](portfolio-release-2026-11-16.md)

## Run the local MCP demo

From the repository root, set up the locked environment and test the protocol:

```sh
uv sync --project analysis --locked --python 3.12
uv run --project analysis --locked python -m unittest discover -s analysis
```

Register the server in an installed client from the repository root. Each command uses the resolved interpreter and script paths.

```sh
codex mcp add blackout-freight -- "$PWD/analysis/.venv/bin/python" "$PWD/analysis/freight_mcp.py"
claude mcp add --transport stdio blackout-freight -- "$PWD/analysis/.venv/bin/python" "$PWD/analysis/freight_mcp.py"
```

Ask the agent to read `freight://experiments/first-shift-compass-v1`, call `analyze_compass_demo`, and explain whether there is evidence to roll out. The test client verifies the resource, tool discovery, and the structured result over stdio. [MCP SDK](https://github.com/modelcontextprotocol/python-sdk) · [Claude Code MCP](https://code.claude.com/docs/en/mcp#option-3-add-a-local-stdio-server)

## Project bullets for a CV

**AI-Native Software Engineer.** Built Blackout Freight, a 1–4 player Roblox co-op game. Shipped persistent progression and live events to closed testing. Used Codex to develop a first-shift compass with server-owned experimentation, reusable agent skills, a Python MCP server and automated Luau/Studio verification.

**Product Analyst.** Designed and instrumented a controlled Roblox onboarding experiment and verified event delivery for both variants in Roblox Analytics. Built a reproducible funnel and guardrail report with DuckDB SQL and Python in Jupyter, using synthetic data to demonstrate sample-ratio checks and confidence intervals.

[AI-Native Software Engineer (Games)](https://playrix.com/job/open/c%2B%2B-development/ai-native-software-engineer-games) · [Product Analyst (Game)](https://playrix.com/job/open/Analytics/product-analyst-game)
