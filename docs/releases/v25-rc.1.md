## Airlock receiver

Carry a battery back to the airlock. Each accepted delivery raises one cyan cassette. Five raised cassettes tell the crew to route power to Broadcast or Shelter. Reduced-motion clients show the final position immediately. The delivery cue follows the finish equipped by the carrier.

![Three of five charged cassettes in the Blender asset render](https://raw.githubusercontent.com/GlebAvershin/blackout-freight/v25-rc.1/assets/airlock-receiver/receiver.png)

## Downloads

- **Blackout-Freight-Studio.rbxl** opens in Roblox Studio. Select Play to generate Depot 07.
- **FirstShiftCompass-synthetic.hyper** opens as a Tableau data source. It contains the simulated onboarding experiment, with every row marked synthetic.
- **SHA256SUMS.txt** contains the digest for each download.

## Roblox closed test

Creator Hub recorded place version 25 on 20 November 2026 at 00:41 MSK. Before publication, 45 script and module sources were checked against the release candidate. Four differed from version 24 and were updated. [Place version history](https://create.roblox.com/dashboard/creations/experiences/10775560304/places/111633787401180/version-history)

| Environment | Observed result |
| --- | --- |
| Roblox Player on macOS, closed server | In one solo Depot 07 shift, each of five deliveries raised one cyan cassette. After the fifth, the HUD displayed both routes. Approaching each console showed `Send recording` and `Power shelter`, respectively. With five seconds left, the player activated Shelter. The victory screen showed `Shelter powered` and a personal best of 2:10. [Screenshots of all five deliveries, both prompts and victory](../playtest/v25-receiver.jpg) |
| Roblox Player on macOS, Broadcast and server change | In a separate solo Depot 07 shift the player delivered all five cells and activated `Send recording`. The victory HUD showed `Signal sent` and a new personal best of 2:00. After leaving and rejoining the same place, the Player log showed a different server (job IDs beginning `4a67ab4f` and `d615ad47`). The journal on the second server showed checkmarks for both `Evidence on air` and `Shelter powered`. The account already had both endings before the run. [Victory and journal screenshots](../playtest/v25-broadcast-journal.png) |
| Studio, one server and one client | The test positioned the avatar at the prompts and invoked the normal pickup and delivery handlers five times. After every delivery, the client checked the material and height of each of the five cassettes. Both route prompts stayed disabled through delivery four, then enabled on delivery five. Choosing Broadcast ended the shift in victory. |

[Original system audit](../audit-2026-11-20.md)
