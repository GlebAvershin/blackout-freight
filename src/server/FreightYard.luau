local Rail = require(game:GetService("ReplicatedStorage").Freight.RailCycle)
local Yard = {}
local hiddenNames = {
	["Cargo container"]=true, ["Container lid"]=true, ["Cargo rib"]=true, ["Cargo reflector"]=true, ["Freight ID"]=true,
	["Service gantry"]=true, ["Overhead service duct"]=true, ["Gantry edge"]=true, ["Sector wayfinding"]=true,
	["Aisle light"]=true, ["Cell socket"]=true, ["Socket ring"]=true, ["Guide rail"]=true, ["Rail tie"]=true, ["Lane dash"]=true,
}
function Yard.build(world, Depot)
	local hidden = {}
	for _, child in world:GetChildren() do
		if hiddenNames[child.Name] then table.insert(hidden, child); child.Parent = nil end
	end
	local model = Instance.new("Model")
	model.Name = "Freight Yard"
	model.Parent = world
	local function part(name, size, position, color, solid)
		return Depot.part(model, name, size, CFrame.new(position), color, Enum.Material.Metal, solid)
	end
	local steel, dark = Color3.fromRGB(72,91,105), Color3.fromRGB(25,38,49)
	for _, z in {-8,-2} do part("Cross rail",Vector3.new(136,0.15,0.18),Vector3.new(0,0.1,z),steel,false) end
	for x=-66,66,4 do part("Rail sleeper",Vector3.new(0.8,0.12,9),Vector3.new(x,0.04,-5),dark,false) end
	for _, x in {-50,50} do
		for _, z in {-49,30} do
			part("Yard container",Vector3.new(13,4,17),Vector3.new(x,2,z),Color3.fromRGB(43,87,97),true)
			for rib=-6,6,3 do part("Container rib",Vector3.new(13.1,0.12,0.2),Vector3.new(x,3.6,z+rib),steel,false) end
		end
	end
	local lamps = {}
	for _, x in {-28,28} do
		for _, z in {-14,4} do
			part("Crossing post",Vector3.new(0.5,5,0.5),Vector3.new(x,2.5,z),steel,true)
			local lamp = part("Crossing signal",Vector3.new(1.5,0.8,0.3),Vector3.new(x,5,z),Depot.Cyan,false)
			lamp.Material = Enum.Material.Neon
			table.insert(lamps,lamp)
		end
		for z=-65,48,5 do
			if z < -13 or z > 3 then
				local guide = part("Yard guide",Vector3.new(0.25,0.05,1.8),Vector3.new(x,0.08,z),Depot.Cyan,false)
				guide.Material = Enum.Material.Neon
			end
		end
	end
	for _, x in {-35,35} do
		for _, z in {25,-42} do
			part("Yard light mast",Vector3.new(0.45,12,0.45),Vector3.new(x,6,z),steel,true)
			local fixture=part("Yard floodlight",Vector3.new(3,0.3,1),Vector3.new(x,12,z),Depot.Cyan,false)
			fixture.Material=Enum.Material.Neon
			local lamp=Instance.new("PointLight",fixture)
			lamp.Color,lamp.Range,lamp.Brightness=Color3.fromRGB(162,211,221),30,1
		end
	end
	local beam = part("Yard crane",Vector3.new(120,1,2),Vector3.new(0,19,-40),steel,false)
	for _, x in {-60,60} do part("Crane tower",Vector3.new(2,19,2),Vector3.new(x,9.5,-40),steel,true) end
	local sign = Instance.new("SurfaceGui",beam)
	sign.Face = Enum.NormalId.Back
	sign.CanvasSize = Vector2.new(1400,70)
	local title = Instance.new("TextLabel",sign)
	title.Size, title.BackgroundTransparency = UDim2.fromScale(1,1), 1
	title.Text, title.TextColor3, title.TextScaled = "07 / FREIGHT YARD", Depot.Amber, true
	title.Font = Enum.Font.GothamBold
	local positions = {Vector3.new(-26,0,35),Vector3.new(26,0,35),Vector3.new(0,0,18),
		Vector3.new(-40,0,-26),Vector3.new(0,0,-26),Vector3.new(40,0,-26),Vector3.new(-26,0,-55),Vector3.new(26,0,-55)}
	for _, p in positions do
		part("Yard socket",Vector3.new(3.1,1.3,2.8),p+Vector3.new(0,0.65,0),steel,true)
	end
	local train = Instance.new("Model",model)
	train.Name = "Passing freight"
	for car=0,2 do
		local body = Depot.part(train,"Freight car",Vector3.new(20,7,8),CFrame.new(-car*22,4,-5),
			car == 0 and Color3.fromRGB(192,111,47) or Color3.fromRGB(62,80,105),Enum.Material.Metal,false)
		body.CanQuery = false
		local stripe = Depot.part(train,"Train reflector",Vector3.new(18,0.2,0.1),body.CFrame*CFrame.new(0,1,4.06),Depot.Amber,Enum.Material.Neon,false)
		stripe.CanQuery = false
	end
	for car=0,2 do
		for _, axle in {-6,6} do
			for _, side in {-4.2,4.2} do
				local wheel=Depot.part(train,"Freight wheel",Vector3.new(0.45,1.5,1.5),
					CFrame.new(-car*22+axle,0.9,-5+side)*CFrame.Angles(0,math.pi/2,0),dark,Enum.Material.Metal,false)
				wheel.Shape=Enum.PartType.Cylinder
				wheel.CanQuery=false
			end
		end
	end
	for _, z in {-2,2} do
		local headlight=Depot.part(train,"Locomotive headlight",Vector3.new(0.12,1,1),
			CFrame.new(10.1,4,-5+z),Color3.fromRGB(255,230,174),Enum.Material.Neon,false)
		headlight.CanQuery=false
	end
	train.WorldPivot = CFrame.new(-22,4,-5)
	train:PivotTo(CFrame.new(-200,4,-5))
	local api = {positions = positions, model = model}
	local lastPhase, previousX
	function api.step(elapsed)
		local phase,x = Rail.at(elapsed)
		if phase ~= lastPhase then
			for _, lamp in lamps do lamp.Color = phase == "clear" and Depot.Cyan or Depot.Red end
			lastPhase = phase
		end
		-- Train pivot is its bounds center, 22 studs behind the first car.
		train:PivotTo(CFrame.new(x and x-22 or -220,4,-5))
		local previous = previousX
		previousX = x
		return phase, previous, x
	end
	function api.destroy()
		model:Destroy()
		for _, child in hidden do child.Parent = world end
	end
	return api
end
return Yard
