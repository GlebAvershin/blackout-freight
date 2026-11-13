assert(game:GetService("RunService"):IsStudio())
local test=game:GetService("StudioTestService")
task.delay(75,function() test:EndTest("TIMEOUT") end)
local function waitFor(f,label,seconds)
	local deadline=os.clock()+(seconds or 8)
	repeat if f() then return end; task.wait(0.05) until os.clock()>deadline
	error("TRACKER QA "..label)
end
local ok,err=xpcall(function()
	local Players=game:GetService("Players")
	local player=Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local state=game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("Shift")
	local world=workspace:WaitForChild("Blackout Freight • Depot 07")
	local server=game:GetService("ServerStorage")
	local press,prepare=server:WaitForChild("FreightTestAction"),server:WaitForChild("FreightTestPreparation")
	waitFor(function() return state:GetAttribute("Phase")=="live" and player.Character and player.Character:FindFirstChild("HumanoidRootPart") end,"spawn")
	assert(state:GetAttribute("SentinelVariant")=="Tracker" and state:GetAttribute("Heat")==2,"variant gate")
	assert(world.Sentinel.Eye.Color.B > world.Sentinel.Eye.Color.R,"tracker appearance")
	local root=player.Character.HumanoidRootPart
	root:SetNetworkOwner(nil)
	local function go(position)
		player.Character.Humanoid:MoveTo(Vector3.new(position.X,root.Position.Y,position.Z))
		waitFor(function() return (Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(position.X,0,position.Z)).Magnitude<2 end,"walk",12)
	end
	local function walkPrompt(p)
		go(p.Parent.WorldPosition+Vector3.new(0,0,p.ObjectText=="Power cell" and 3 or -3))
		task.wait(0.15); press:Invoke(p,player)
	end
	local cell
	for _,model in world:GetChildren() do
		if model.Name=="Power Cell" and model.PrimaryPart.Position.Z==35 and model.PrimaryPart.Position.X==-26 then
			cell=model:FindFirstChildWhichIsA("ProximityPrompt",true); break
		end
	end
	walkPrompt(assert(cell))
	waitFor(function() return player:GetAttribute("Tracked") end,"visible cargo acquired")
	local drone=world.Sentinel.PrimaryPart
	-- Temporary QA wall exercises the production raycast and target-selection path.
	local wall=Instance.new("Part")
	wall.Name="QA visibility blocker"
	wall.Anchored=true
	wall.Size=Vector3.new(160,30,0.4)
	wall.Position=Vector3.new(0,10,(drone.Position.Z+root.Position.Z)/2)
	wall.Parent=world
	waitFor(function() return state:GetAttribute("SentinelMode")=="search" end,"occlusion enters search",1)
	assert(not player:GetAttribute("Tracked") and drone.TrackingBeam.Attachment1==nil,"hidden carrier still locked")
	wall:Destroy()
	waitFor(function() return player:GetAttribute("Tracked") and state:GetAttribute("SentinelMode")=="hunt" end,"visibility reacquired",1)
	walkPrompt(world["Delivery console"]:FindFirstChildWhichIsA("ProximityPrompt",true))
	walkPrompt(world["01   BROADCAST"]:FindFirstChildWhichIsA("ProximityPrompt",true))
	waitFor(function() return state:GetAttribute("Phase")=="won" end,"finish")
	assert(state:GetAttribute("SentinelMode")=="patrol","memory reset at finish")
	prepare:Invoke(player,"heat",1)
	waitFor(function() return state:GetAttribute("Phase")=="live" end,"classic shift",24)
	assert(state:GetAttribute("SentinelVariant")=="Sentinel","classic fallback")
	assert(world.Sentinel.Eye.Color.R>world.Sentinel.Eye.Color.B,"classic appearance restored")
	print("YARD TRACKER QA PASS visibility, search, reacquire, delivery, phase reset, Heat 1 fallback")
	test:EndTest("PASS")
end,debug.traceback)
if not ok then warn(err); test:EndTest("FAIL "..tostring(err)) end
