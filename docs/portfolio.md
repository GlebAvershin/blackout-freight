# Blackout Freight · Portfolio

**Role** · Solo developer of a 1–4 player co-op Roblox game. The crew scavenges batteries under pressure, powers the depot, and chooses between broadcasting evidence and supplying a shelter.

[Play in Roblox, subject to closed-test access](https://www.roblox.com/games/111633787401180/Blackout-Freight) · [Download the local Studio preview](../dist/Blackout%20Freight%20Portfolio%20Preview.rbxl) · [Watch the core loop](../dist/blackout-freight-chase-gameplay.mp4)

## Five-minute demo

1. Open the Portfolio Preview in Roblox Studio and select **Play**. Turn away from the first battery to see the HUD compass, then turn back to the waypoint. Press **E** at the battery and follow the amber airlock bearing after pickup.
2. Deliver a battery. The compass retires after the first delivery and the shift continues. Run **Server & Clients** to demonstrate shared objective, role abilities and crew pings.
3. Open the [first-shift notebook](../analysis/first_shift_compass.ipynb) for the worked experiment. The charts use synthetic counts. The [experiment contract](first-shift-experiment.md) describes the actual runtime telemetry and controlled playtest.

## AI-Native Software Engineer

- **Gameplay.** The Luau server owns round state, validation and experiment enrollment. The camera-relative compass is client-side UI. Studio previews the treatment, and the published runtime can allocate players consistently by account. [Runtime experiment](../src/server/FirstShiftExperiment.luau) · [Compass UI](../src/client/FirstShiftCompass.luau)
- **AI-assisted development.** The Codex implementation was checked against Luau unit tests, a real Studio client and reproducible analytics. Reusable skills cover release review and experiment interpretation. A Python stdio MCP server supplies the versioned event contract and runs the demo analysis as a read-only tool. [Release skill](../.agents/skills/freight-release/SKILL.md) · [Experiment skill](../.agents/skills/freight-experiment/SKILL.md) · [MCP server](../analysis/freight_mcp.py)
- **Verification.** GitHub Actions is configured to compile and test Luau, build an RBXL, validate Python and the MCP protocol, and execute the notebook. The existing game includes persistent progression, seasonal objectives, daily shifts, and scripted multiplayer Studio tests. [CI workflow](../.github/workflows/verify.yml) · [Game overview](../README.md)

The local candidate passed 16 Luau suites, seven Python tests, and the desktop and mobile Studio checks (638×241 landscape and 413×756 portrait). A solo Studio fixture captured the exposure, pickup and delivery calls from the server. Rojo reproduced the candidate byte for byte. GitHub Actions configuration passed local validation with actionlint.

## Product Analyst

- Defined a first-delivery metric and catch guardrail, scoped the randomized test to one solo attempt per participant, and specified a fixed sample, SRM check and confidence intervals.
- Integrated server-side Roblox Analytics. Normalized the aggregate counts into a validated contract, used DuckDB SQL for the funnel and cohort rates, and used pandas, SciPy and statsmodels for the Jupyter analysis.
- Closed-test v24 has live telemetry. Creator Hub received all four stages for each variant in internal QA. The notebook uses a simulated cohort to illustrate the statistical workflow. Measuring the live effect requires a controlled participant cohort. [Release and live evidence](portfolio-release-2026-11-16.md)

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

**Product Analyst.** Designed and instrumented a controlled onboarding experiment for a Roblox game. Built a reproducible funnel and guardrail report with DuckDB SQL and Python in Jupyter, including sample-ratio checks and confidence intervals. Validated the pipeline on synthetic data.

[AI-Native Software Engineer (Games)](https://playrix.com/job/open/c%2B%2B-development/ai-native-software-engineer-games) · [Product Analyst (Game)](https://playrix.com/job/open/Analytics/product-analyst-game)
