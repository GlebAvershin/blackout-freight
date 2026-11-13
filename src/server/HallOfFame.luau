local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Challenges = require(game:GetService("ReplicatedStorage").Freight.CrewChallenges)

local Hall = {}
Hall.__index = Hall

function Hall.new(world, depot, state)
	local board = depot.part(world, "Weekly Hall of Fame", Vector3.new(19, 7, 0.4),
		CFrame.new(16, 5.5, 70), Color3.fromRGB(13, 21, 32), Enum.Material.Metal)
	local surface = Instance.new("SurfaceGui")
	surface.CanvasSize = Vector2.new(720, 336)
	surface.LightInfluence = 0
	surface.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = depot.Cyan
	label.TextSize = 20
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Text = "HALL OF FAME / СТЕНА СЛАВЫ\nDAILY DEPOT 07 · HEAT 1"
	label.Parent = surface
	local self = setmetatable({label = label, state = state, studio = RunService:IsStudio(), localScores = {}, names = {}, pending = 0}, Hall)
	game:BindToClose(function()
		local deadline = os.clock() + 12
		while self.pending > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
	task.spawn(function()
		while board.Parent do
			self:refresh()
			task.wait(90)
		end
	end)
	return self
end

local function scope(week, size)
	return string.format("w%d_c%d", week, size)
end

function Hall:record(week, members, seconds)
	local ids = {}
	for player in members do table.insert(ids, player.UserId) end
	table.sort(ids)
	local key = table.concat(ids, "_")
	local bracket = scope(week, #ids)
	if self.studio then
		local scores = self.localScores[bracket] or {}
		scores[key] = math.min(scores[key] or seconds, seconds)
		self.localScores[bracket] = scores
		task.defer(function() self:refresh() end)
		return
	end
	if #key > 50 then return end
	-- Ordered stores accept an integer score. The sorted roster is the stable crew key.
	self.pending += 1
	task.spawn(function()
		for attempt = 1, 3 do
			local ok = pcall(function()
				DataStoreService:GetOrderedDataStore("FreightDailyWeekly_v1", bracket):UpdateAsync(key, function(old)
					return math.min(old or seconds, seconds)
				end)
			end)
			if ok then self.pending -= 1; return end
			if attempt < 3 then task.wait(2 ^ attempt) end
		end
		self.pending -= 1
		warn("Freight: weekly crew record could not be saved")
	end)
end

function Hall:crewName(key)
	local names = {}
	for id in string.gmatch(key, "%-?%d+") do
		local userId = tonumber(id)
		local player = Players:GetPlayerByUserId(userId)
		if player then self.names[id] = player.Name end
		if not self.names[id] and userId > 0 then
			local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			if ok then self.names[id] = name end
		end
		table.insert(names, self.names[id] or "#" .. id)
	end
	return table.concat(names, " + ")
end

function Hall:refresh()
	local week = Challenges.week(os.time())
	local lines = {"HALL OF FAME / СТЕНА СЛАВЫ", "DEPOT 07 · HEAT 1 · WEEK " .. week, ""}
	for size = 1, 4 do
		local bracket = scope(week, size)
		local ok, entries = pcall(function()
			if self.studio then
				local rows = {}
				for key, value in self.localScores[bracket] or {} do table.insert(rows, {key = key, value = value}) end
				table.sort(rows, function(a, b) return a.value < b.value or (a.value == b.value and a.key < b.key) end)
				return rows
			end
			return DataStoreService:GetOrderedDataStore("FreightDailyWeekly_v1", bracket):GetSortedAsync(true, 10):GetCurrentPage()
		end)
		local rows = {}
		if ok then
			for rank, entry in entries do
				if rank > 10 then break end
				table.insert(rows, string.format("%02d · %d:%02d · %s", rank, entry.value // 60,
					entry.value % 60, self:crewName(entry.key)))
			end
		end
		if ok then
			self.state:SetAttribute("WeeklyCrewTop" .. size, table.concat(rows, "\n"))
		elseif self.state:GetAttribute("WeeklyRankingWeek") ~= week then
			self.state:SetAttribute("WeeklyCrewTop" .. size, nil)
		end
		table.insert(lines, size .. "  /  " .. (rows[1] or (ok and "—" or "…")))
	end
	self.state:SetAttribute("WeeklyRankingWeek", week)
	self.label.Text = table.concat(lines, "\n")
end

return Hall
