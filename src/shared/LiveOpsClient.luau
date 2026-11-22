--!strict
--[[
    LiveOpsClient.luau
    Cross-Game LiveOps & LinUCB Dynamic Shop Client SDK for Blackout Freight.
    Connects Depot 07 tactical missions with shared cross-game contracts
    and non-predatory stealth cosmetic offerings.
]]

export type LiveOpsSeason = {
    SeasonId: string,
    Title: string,
    DurationDays: number,
    ActiveGames: { string },
    Status: string,
}

export type CrossGameContract = {
    ContractId: string,
    Title: string,
    Description: string,
    TargetGames: { string },
    GoalMetric: string,
    TargetValue: number,
    XpReward: number,
    TokenReward: number,
}

export type CosmeticRecommendation = {
    ArmId: string,
    Category: string,
    Style: string,
    PriceTokens: number,
    PredictedAffinityScore: number,
}

local LiveOpsClient = {}
LiveOpsClient.__index = LiveOpsClient

function LiveOpsClient.new(playerId: string)
    local self = setmetatable({}, LiveOpsClient)
    self.PlayerId = playerId
    self.CurrentSeason = {
        SeasonId = "SEASON_NORTHERN_EXPEDITION",
        Title = "Northern Expedition · Cross-Game Frontier",
        DurationDays = 45,
        ActiveGames = { "atlas", "soccer", "mosaic", "freight" },
        Status = "ACTIVE",
    }
    return self
end

function LiveOpsClient:GetSeason(): LiveOpsSeason
    return self.CurrentSeason
end

function LiveOpsClient:GetAvailableContracts(): { CrossGameContract }
    return {
        {
            ContractId = "CONTRACT_02",
            Title = "Shadow & Glass",
            Description = "Extract 3 batteries in Blackout Freight and clear 4 boards in Mosaic Pier",
            TargetGames = { "freight", "mosaic" },
            GoalMetric = "stealth_puzzles",
            TargetValue = 7,
            XpReward = 900,
            TokenReward = 200,
        },
        {
            ContractId = "CONTRACT_03",
            Title = "Grand Quad Master",
            Description = "Participate in matches across all 4 titles during active season",
            TargetGames = { "atlas", "soccer", "mosaic", "freight" },
            GoalMetric = "quad_matches",
            TargetValue = 4,
            XpReward = 1500,
            TokenReward = 400,
        },
    }
end

-- Simulates LinUCB recommendation scoring locally on player context vector
function LiveOpsClient:GetPersonalizedCosmetics(
    playerContext: { Velocity: number, BpTier: number, TokenBalance: number, Aesthetic: number }
): { CosmeticRecommendation }
    -- LinUCB weighting: tactical players prefer matte-carbon or night optics
    local isTactical = playerContext.Velocity < 0.4
    return {
        {
            ArmId = "freight_carbon_drone",
            Category = "Chassis",
            Style = "Tactical",
            PriceTokens = 350,
            PredictedAffinityScore = isTactical and 0.92 or 0.50,
        },
        {
            ArmId = "freight_amber_visor",
            Category = "Optics",
            Style = "Tactical",
            PriceTokens = 180,
            PredictedAffinityScore = 0.78,
        },
    }
end

return LiveOpsClient
