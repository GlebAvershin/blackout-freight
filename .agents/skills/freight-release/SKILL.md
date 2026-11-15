---
name: freight-release
description: Prepare or review a Blackout Freight Luau change, build its Roblox place, and verify its release evidence.
---

# Blackout Freight release review

1. Trace changed behavior from normal player input through the client HUD and server authority. Verify that server state changes only after validated actions. Review any changes to replicated Attributes, DataStores and analytics for compatibility.
2. Compile `src` and `tests` with `luau-compile --null src tests` and run each `tests/*.test.luau` with Luau CLI.
3. Build the candidate with `rojo build -o .tools/freight-candidate.rbxl` and verify it with `python3 scripts/check-release.py --artifact .tools/freight-candidate.rbxl --rojo rojo`.
4. Choose Studio runs that cover the changed paths. Use `python3 scripts/run-guidance-studio-qa.py` for onboarding and `python3 scripts/run-mobile-studio-qa.py .tools/freight-candidate.rbxl` for the two mobile orientations. Check the actual pass marker or observe the client and server in Studio.
5. Record the candidate SHA-256, test commands, pass markers and remaining live checks. A successful build and a live rollout are separate evidence.
