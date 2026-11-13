local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Profile = require(script.Parent.Profile)
local Service = {}
Service.__index = Service

function Service.new()
	local store
	if RunService:IsStudio() then
		local records = {}
		store = {UpdateAsync = function(_, key, callback)
			local value = callback(records[key])
			if value then records[key] = value end
			return value
		end}
	else
		store = DataStoreService:GetDataStore("FreightProfile_v1")
	end
	return setmetatable({store = store, sessions = {}, closing = false}, Service)
end

local function publish(player, data)
	player:SetAttribute("Scrap", data.scrap)
	player:SetAttribute("RankXP", data.rankXP)
	player:SetAttribute("CrewRank", 1 + math.floor(data.rankXP / 250))
end

function Service:join(player)
	if self.closing or self.sessions[player] then return end
	local session = {profile = Profile.new(self.store, HttpService:GenerateGUID(false)), busy = true}
	self.sessions[player] = session
	player:SetAttribute("ProfileStatus", "loading")
	task.spawn(function()
		local data
		for attempt = 1, 3 do
			data = session.profile:acquire(player.UserId)
			if data or session.leaving then break end
			task.wait(attempt * 2)
		end
		session.busy = false
		if session.leaving then
			if data then session.profile:release(player.UserId) end
			self.sessions[player] = nil
			return
		end
		if not data then player:SetAttribute("ProfileStatus", "unavailable"); return end
		session.ready = true
		publish(player, data)
		player:SetAttribute("ProfileStatus", RunService:IsStudio() and "local" or "ready")
		while not session.leaving and not self.closing do
			task.wait(30)
			if session.leaving or self.closing then break end
			if session.busy then continue end
			session.busy = true
			local refreshed = session.profile:refresh(player.UserId)
			session.busy = false
			if session.leaving then
				session.profile:release(player.UserId)
				self.sessions[player] = nil
				break
			end
			if not refreshed then
				session.ready = false
				player:SetAttribute("ProfileStatus", "unavailable")
				break
			end
		end
	end)
end

function Service:leave(player)
	local session = self.sessions[player]
	if not session or session.leaving then return end
	session.leaving = true
	if session.busy then return end -- The in-flight acquire handles release itself.
	for attempt = 1, 3 do
		if session.profile:release(player.UserId) then break end
		task.wait(attempt)
	end
	self.sessions[player] = nil
end

function Service:close()
	self.closing = true
	for player in self.sessions do task.spawn(function() self:leave(player) end) end
	local deadline = os.clock() + 25
	while next(self.sessions) and os.clock() < deadline do task.wait(0.1) end
end
return Service
