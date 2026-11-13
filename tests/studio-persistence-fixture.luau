-- Separate processes exchange serialized fixture records, never production DataStores.
assert(game:GetService("RunService"):IsStudio())
local http = game:GetService("HttpService")
local args = game:GetService("StudioTestService"):GetTestArgs()
local serialized = type(args) == "string" and args:match("^PersistenceRestore:(.+)$")
local records = serialized and http:JSONDecode(serialized) or {profile = {}, journal = {}}
local function copy(value)
	return value ~= nil and http:JSONDecode(http:JSONEncode(value)) or nil
end
local function store(bucket)
	return {
		GetAsync = function(_, key) return copy(bucket[key]) end,
		UpdateAsync = function(_, key, callback)
			local value = callback(copy(bucket[key]))
			if value ~= nil then bucket[key] = copy(value) end
			return copy(value)
		end,
	}
end
local fixture = {profile = store(records.profile), journal = store(records.journal), restoring = serialized ~= nil}
function fixture.attach(profiles, journal)
	function fixture.snapshot()
		profiles:close()
		journal:flush()
		assert(next(profiles.sessions) == nil, "profile session did not drain")
		for _, value in records.profile do assert(value.owner == nil, "lease not released") end
		return "PersistenceRestore:" .. http:JSONEncode(records)
	end
end
return fixture
