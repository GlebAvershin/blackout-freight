local Rail = {Period = 22, WarningAt = 10, PassingAt = 14, TrackZ = -5}
function Rail.at(elapsed)
	local t = math.max(0, elapsed) % Rail.Period
	if t < Rail.WarningAt then return "clear", nil end
	if t < Rail.PassingAt then return "warning", nil end
	return "passing", -110 + (t - Rail.PassingAt) * 40
end
function Rail.hit(x, y, z, previous, current)
	if not current or y < -2 or y > 10 or math.abs(z - Rail.TrackZ) > 6 then return false end
	previous = previous or current
	for car = 0, 2 do
		local lo, hi = math.min(previous,current)-car*22-12, math.max(previous,current)-car*22+12
		if x >= lo and x <= hi then return true end
	end
	return false
end
function Rail.choose(votes, eligible)
	if not eligible or #votes == 0 then return "depot" end
	local yes = 0
	for _, vote in votes do if vote == "yard" then yes += 1 end end
	return yes > #votes / 2 and "yard" or "depot"
end
return Rail
