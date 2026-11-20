-- Keep the arrow until its world marker is safely inside the unobstructed HUD area.
return function(showing, onScreen, x, y, width, height)
	if not onScreen then return true end
	local margin = math.min(72, width * 0.2)
	local inset = if showing then 8 else 0
	return x <= margin + inset or x >= width - margin - inset
		or y <= height * 0.24 + inset or y >= height * 0.86 - inset
end
