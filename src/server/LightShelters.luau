-- One server-owned shelter per technician. No client-supplied positions.
local Shelters = {}
function Shelters.new(world, Depot, Roles)
	local active = {}
	local api = {}
	function api.remove(player)
		local item = active[player]
		if item then item.part:Destroy(); active[player] = nil end
		player:SetAttribute("ShelterSetupUntil", 0)
	end
	function api.clear()
		for player in active do api.remove(player) end
	end
	function api.deploy(player, root, time)
		api.remove(player)
		local pos = root.Position
		local part = Depot.part(world, "Crew light shelter", Vector3.new(0.08,18,18),
			CFrame.new(pos.X,0.12,pos.Z) * CFrame.Angles(0,0,math.pi/2), Depot.Cyan, Enum.Material.Neon, false)
		part.Shape, part.CanQuery, part.Transparency = Enum.PartType.Cylinder, false, 0.85
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Depot.Cyan, 18, 0
		light.Parent = part
		local ready = time + Roles.Catalog.Technician.setup
		active[player] = {part=part, light=light, origin=pos, ready=ready,
			expires=ready+Roles.Catalog.Technician.duration, armed=false}
		player:SetAttribute("ShelterSetupUntil", ready)
	end
	function api.step(time, rootOf)
		for player, item in active do
			local root = rootOf(player)
			if not root or time >= item.expires or (not item.armed and (root.Position-item.origin).Magnitude > 3) then
				api.remove(player)
			elseif time >= item.ready and not item.armed then
				item.armed = true
				item.part.Transparency, item.light.Brightness = 0.65, 2
				player:SetAttribute("ShelterSetupUntil", 0)
			end
		end
	end
	function api.protects(position)
		for _, item in active do
			if item.armed and math.abs(position.Y-item.origin.Y) < 6
				and Vector2.new(position.X-item.origin.X,position.Z-item.origin.Z).Magnitude <= 9 then return true end
		end
		return false
	end
	return api
end
return Shelters
