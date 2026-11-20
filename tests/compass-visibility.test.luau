local showArrow = require("../src/client/CompassVisibility")

for _, viewport in {{1280, 720}, {320, 568}} do
	local w, h = viewport[1], viewport[2]
	local left = math.min(72, w * 0.2)
	for _, edge in {
		function(d) return left + d, h / 2 end,
		function(d) return w - left - d, h / 2 end,
		function(d) return w / 2, h * 0.24 + d end,
		function(d) return w / 2, h * 0.86 - d end,
	} do
		local visible = false
		for _, sample in {{12, false}, {-1, true}, {1, true}, {-1, true}, {8, true}, {9, false}, {1, false}} do
			local x, y = edge(sample[1])
			visible = showArrow(visible, true, x, y, w, h)
			assert(visible == sample[2], "wrong arrow visibility at edge")
		end
	end
	assert(showArrow(false, false, w / 2, h / 2, w, h))
end
print("Compass edge transitions passed on desktop and phone")
