local RoleAction = {}
function RoleAction.mount(gui, player, state, shared, colors, add, t)
	local input = game:GetService("UserInputService")
	local remote = shared:WaitForChild("Preparation")
	local button = add("TextButton", gui, {Name = "RoleAbility", Visible = false, BackgroundColor3 = colors.ink,
		TextColor3 = colors.cyan, Font = Enum.Font.GothamBold, TextSize = 12, AutoLocalize = false})
	add("UICorner", button, {CornerRadius = UDim.new(0, 5)})
	local function activate()
		if button.Visible and button.Interactable then remote:FireServer("ability") end
	end
	button.Activated:Connect(activate)
	local connection = input.InputBegan:Connect(function(key, handled)
		if not handled and key.KeyCode == Enum.KeyCode.Q then activate() end
	end)
	gui.Destroying:Connect(function() connection:Disconnect() end)
	local api = {}
	function api.draw(compact, invite, menusOpen)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = root and root.Parent:FindFirstChildOfClass("Humanoid")
		local role = player:GetAttribute("CrewRole")
		local carrying = player:GetAttribute("Carrying") == true
		local outside = root and root.Position.Z < require(shared.Config).AirlockSafeZ
		button.Visible = state:GetAttribute("Phase") == "live" and humanoid ~= nil and humanoid.Health > 0
			and outside == true and not menusOpen and (role == "Lure" or (role == "Carrier" and carrying))
		if not button.Visible then return end
		invite.Visible = false
		button.Position, button.Size, button.AnchorPoint = invite.Position, invite.Size, invite.AnchorPoint
		local time = workspace:GetServerTimeNow()
		local readyAt = player:GetAttribute("AbilityReadyAt") or 0
		if role == "Lure" then readyAt = math.max(readyAt, state:GetAttribute("DecoyReadyAt") or 0) end
		local remaining = math.max(0, math.ceil(readyAt - time))
		local label = role == "Lure" and t("Lure", "Маяк") or t("Dash", "Рывок")
		button.Text = (compact and "" or "Q · ") .. label .. (remaining > 0 and " " .. remaining or "")
		button.Interactable = remaining == 0 and (role == "Carrier" or state:GetAttribute("DecoyReady") == true)
		button.TextColor3 = button.Interactable and colors.cyan or colors.muted
	end
	return api
end
return RoleAction
