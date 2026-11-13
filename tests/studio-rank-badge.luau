local function badgeWait(f,label)
	local deadline=os.clock()+12
	repeat if f() then return end; task.wait(0.05) until os.clock()>deadline
	error("RANK BADGE "..label)
end
badgeWait(function() return player.Character and player.Character:FindFirstChildOfClass("Humanoid") end,"character")
assert(not player.Character:FindFirstChild("Crew rank badge"),"rookie received badge")
for _, xp in {250,500,1000} do
	local expected=xp==250 and "2" or xp==500 and "3" or "5"
	player:SetAttribute("RankXP",xp) -- Visual fixture; no profile/currency write.
	badgeWait(function()
		local badge=player.Character:FindFirstChild("Crew rank badge")
		return badge and badge:FindFirstChildOfClass("SurfaceGui") and badge.SurfaceGui.TextLabel.Text==expected
	end,"earned badge")
	local badge=player.Character["Crew rank badge"]
	assert(badge.SurfaceGui.TextLabel.Text==expected,"badge tier")
	assert(not badge.CanCollide and badge.Massless and badge.WeldConstraint.Part0.Parent==player.Character,"badge physics")
	local count=0
	for _,child in player.Character:GetChildren() do if child.Name=="Crew rank badge" then count+=1 end end
	assert(count==1,"duplicate badge")
end
player:LoadCharacterAsync()
badgeWait(function() return player.Character and player.Character:FindFirstChild("Crew rank badge") end,"respawn restore")
assert(player.Character["Crew rank badge"].SurfaceGui.TextLabel.Text=="5")
player:SetAttribute("RankXP",0)
badgeWait(function() return not player.Character:FindFirstChild("Crew rank badge") end,"badge cleanup")
print("EXPANSION BADGE PASS tiers, noncolliding weld, unique badge, respawn, cleanup")
