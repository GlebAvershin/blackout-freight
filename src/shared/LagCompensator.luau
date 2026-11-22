--!strict
--[[
    LagCompensator.luau
    Spatial Lag Compensation & Authoritative Server Rewind for
    Blackout Freight Sentinel Line-of-Sight & Battery Interactions.
]]

export type Vector2Record = {
    X: number,
    Y: number,
}

export type PlayerSpatialSnapshot = {
    PlayerId: number,
    Position: Vector2Record,
    InCover: boolean,
    IsCrouching: boolean,
    Tick: number,
    ServerTimestamp: number,
}

export type HistoryBuffer = { [number]: { [number]: PlayerSpatialSnapshot } } -- [tick][playerId]

local LagCompensator = {}
LagCompensator.__index = LagCompensator

local MAX_REWIND_SECONDS = 0.250 -- Clamped to 250ms max to prevent lag abuse
local SERVER_TICK_RATE = 60

function LagCompensator.new()
    local self = setmetatable({}, LagCompensator)
    self.History = {} :: HistoryBuffer
    self.CurrentTick = 0
    return self
end

-- Records world snapshot at each server tick
function LagCompensator:RecordSnapshot(snapshots: { [number]: PlayerSpatialSnapshot })
    self.CurrentTick += 1
    self.History[self.CurrentTick] = snapshots

    -- Prune snapshots older than 1.0 second (60 ticks)
    local pruneTick = self.CurrentTick - 60
    if self.History[pruneTick] then
        self.History[pruneTick] = nil
    end
end

-- Rewinds world to player's perceived view timestamp for raycast validation
function LagCompensator:GetRewoundSnapshot(
    playerId: number,
    clientOneWayLatencySeconds: number
): (PlayerSpatialSnapshot?, number)
    local clampedLatency = math.clamp(clientOneWayLatencySeconds, 0, MAX_REWIND_SECONDS)
    local ticksBack = math.round(clampedLatency * SERVER_TICK_RATE)
    local targetTick = math.max(1, self.CurrentTick - ticksBack)

    local tickData = self.History[targetTick]
    if tickData and tickData[playerId] then
        return tickData[playerId], targetTick
    end

    -- Fallback to current tick if history missing
    local currentData = self.History[self.CurrentTick]
    return (currentData and currentData[playerId]) or nil, self.CurrentTick
end

-- Authoritative line-of-sight check with lag compensation
function LagCompensator:EvaluateSentinelSightline(
    dronePos: Vector2Record,
    playerId: number,
    playerLatencySeconds: number
): (boolean, string)
    local snapshot, evaluatedTick = self:GetRewoundSnapshot(playerId, playerLatencySeconds)
    if not snapshot then
        return false, "NO_SNAPSHOT"
    end

    -- If player was safely behind cover at their view timestamp, they are NOT detected
    if snapshot.InCover then
        return false, "BLOCKED_BY_COVER_RECONCILED"
    end

    local dx = snapshot.Position.X - dronePos.X
    local dy = snapshot.Position.Y - dronePos.Y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= 15.0 then
        return true, "DETECTED_IN_REWOUND_FRAME"
    end

    return false, "OUT_OF_RANGE"
end

return LagCompensator
