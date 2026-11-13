local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CrewPings = {}

function CrewPings.mount(gui, player, state, remote, colors, add, t)
	local marks = {}
	local kinds = {
		{id = "battery", title = t("Battery", "Батарея"), color = colors.cyan, tag = "FreightPickup"},
		{id = "danger", title = t("Danger", "Опасность"), color = colors.red, tag = "FreightSentinel"},
		{id = "here", title = t("Here", "Сюда"), color = colors.amber},
	}
	local byId = {}
	for _, kind in kinds do byId[kind.id] = kind end
	local function button(parent, name, text, color)
		local item = add("TextButton", parent, {
			Name = name, Text = text, TextSize = 12, Font = Enum.Font.GothamBold, AutoLocalize = false,
			BackgroundColor3 = colors.ink, TextColor3 = color, Selectable = true,
		})
		add("UICorner", item, {CornerRadius = UDim.new(0, 5)})
		return item
	end
	local toggle = button(gui, "CrewPingButton", t("Ping", "Метка"), colors.amber)
	toggle.AnchorPoint = Vector2.new(0.5, 0)
	toggle.Visible = false
	toggle.Size = UDim2.fromOffset(66, 44)
	local menu = add("Frame", gui, {
		Name = "CrewPingMenu", AnchorPoint = Vector2.new(0.5, 1), Visible = false,
		Size = UDim2.fromOffset(240, 44), BackgroundTransparency = 1,
	})
	local reticle = add("TextLabel", gui, {
		Name = "CrewPingAim", Text = "+", TextSize = 26, Font = Enum.Font.GothamBold,
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1, TextColor3 = colors.paper, Visible = false,
	})
	local function setOpen(open)
		menu.Visible, reticle.Visible = open, open
		toggle.Text = if open then t("Cancel", "Отмена") else t("Ping", "Метка")
	end
	local function aim(kind)
		local camera = workspace.CurrentCamera
		local character = player.Character
		if not camera or not character then return end
		local center = camera.ViewportSize / 2
		local ray = camera:ViewportPointToRay(center.X, center.Y)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.RespectCanCollide = true
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 70, params)
		if not kind.tag then return hit and hit.Position + hit.Normal * 0.3 end
		local best, bestDistance = nil, math.min(70, hit and hit.Distance + 4 or 70)
		for _, part in CollectionService:GetTagged(kind.tag) do
			if not part:IsDescendantOf(workspace) then continue end
			local offset = part.Position - ray.Origin
			local depth = offset:Dot(ray.Direction)
			if depth > 0 and depth < bestDistance and (offset - ray.Direction * depth).Magnitude < 6 then
				best, bestDistance = part.Position, depth
			end
		end
		return best
	end
	local feedbackUntil, readyAt = 0, 0
	local feedback
	for index, kind in kinds do
		local option = button(menu, kind.id, kind.title, kind.color)
		option.Position = UDim2.fromOffset((index - 1) * 82, 0)
		option.Size = UDim2.fromOffset(76, 44)
		option.Activated:Connect(function()
			if not menu.Visible then return end
			local position = aim(kind)
			setOpen(false)
			feedback = if position then t("Sending…", "Отправка…") else t("Aim again", "Наведи")
			feedbackUntil = os.clock() + 0.8
			if position then remote:FireServer(kind.id, position) end
		end)
	end
	local function activate()
		if toggle.Visible and toggle.Interactable then setOpen(not menu.Visible) end
	end
	toggle.Activated:Connect(activate)
	local inputConnection = UserInputService.InputBegan:Connect(function(input, handled)
		if not handled and input.KeyCode == Enum.KeyCode.G then activate() end
	end)
	gui.Destroying:Connect(function() inputConnection:Disconnect() end)
	local function clear(userId)
		local mark = marks[userId]
		if mark then mark.gui:Destroy(); marks[userId] = nil end
	end
	local function clearOthers()
		for userId in marks do if userId ~= player.UserId then clear(userId) end end
	end
	player:GetAttributeChangedSignal("FreightMuteCrewPings"):Connect(function()
		if player:GetAttribute("FreightMuteCrewPings") then clearOthers() end
	end)
	remote.OnClientEvent:Connect(function(userId, id, position, expiresAt)
		if state:GetAttribute("Phase") ~= "live" or (userId ~= player.UserId and player:GetAttribute("FreightMuteCrewPings")) then return end
		clear(userId)
		local kind = byId[id]
		local mark = add("BillboardGui", gui, {
			Name = "CrewPingMarker", Size = UDim2.fromOffset(84, 24),
			AlwaysOnTop = true, MaxDistance = 92,
		})
		-- A non-queryable client-side anchor works for both targets and floor positions.
		local anchor = add("Part", workspace, {
			Name = "CrewPingAnchor", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
			Transparency = 1, Position = position + Vector3.new(0, 1.4, 0),
		})
		mark.Adornee = anchor
		mark.Destroying:Connect(function() anchor:Destroy() end)
		local label = add("TextLabel", mark, {
			Size = UDim2.fromScale(1, 1), Text = "◇ " .. kind.title, TextSize = 12, Font = Enum.Font.GothamBold,
			TextColor3 = kind.color, BackgroundColor3 = colors.ink, BackgroundTransparency = 0.15, AutoLocalize = false,
		})
		add("UICorner", label, {CornerRadius = UDim.new(0, 5)})
		marks[userId] = {gui = mark, expiresAt = expiresAt}
		if userId == player.UserId then
			readyAt = expiresAt - 2
			feedbackUntil = 0
		end
	end)
	-- Use the same viewport center for the reticle and the camera ray, accounting for the safe inset.
	local render = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if reticle.Visible and camera then
			local center = camera.ViewportSize / 2 - gui.AbsolutePosition
			reticle.Position = UDim2.fromOffset(center.X, center.Y)
		end
	end)
	gui.Destroying:Connect(function() render:Disconnect() end)
	return function(dockY, compact, menusOpen)
		local time = workspace:GetServerTimeNow()
		local live = state:GetAttribute("Phase") == "live"
		for userId, mark in marks do
			if not live or mark.expiresAt <= time then clear(userId) end
		end
		toggle.Visible = live and not menusOpen and not player:GetAttribute("PilotingSentinel")
		if not toggle.Visible and menu.Visible then setOpen(false) end
		toggle.Interactable = menu.Visible or (time >= readyAt and os.clock() >= feedbackUntil)
		if not menu.Visible then
			local seconds = math.ceil(readyAt - time)
			toggle.Text = if seconds > 0 then t("Ping ", "Метка ") .. seconds
				elseif os.clock() < feedbackUntil then feedback
				else t("Ping", "Метка")
		end
		local position = if compact then UDim2.new(0.5, 0, dockY.Scale, dockY.Offset - 48) else UDim2.new(0.5, 0, 1, -54)
		local inline = compact and gui.AbsoluteSize.X >= 324 and gui.AbsoluteSize.Y < 350
		toggle.Position = position - UDim2.fromOffset(inline and menu.Visible and 123 or 0, 0)
		menu.Position = position + (if inline then UDim2.fromOffset(36, 44) else UDim2.fromOffset(0, -4))
	end
end

return CrewPings
