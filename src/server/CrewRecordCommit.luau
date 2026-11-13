local CrewRecordCommit = {}

function CrewRecordCommit.await(writes, waitForChange)
	if #writes == 0 then return false end
	while true do
		local remaining = 0
		for _, write in writes do
			if write.failed then return false end
			if not write.committed then remaining += 1 end
		end
		if remaining == 0 then return true end
		waitForChange()
	end
end

return CrewRecordCommit
