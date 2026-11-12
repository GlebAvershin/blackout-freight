local FriendInvite = {}

function FriendInvite.crewLaunch(token)
	return "freight-west:" .. token
end

function FriendInvite.crewJoin(data, token)
	local inviter = data.ReferredByPlayerId
	return type(inviter) == "number" and inviter > 0 and type(token) == "string" and token ~= ""
		and data.LaunchData == FriendInvite.crewLaunch(token)
end

function FriendInvite.open(service, player, published, options)
	if not published then
		return "local"
	end
	local ok, allowed = pcall(service.CanSendGameInviteAsync, service, player)
	if not ok or not allowed then
		return "unavailable"
	end
	return pcall(service.PromptGameInvite, service, player, options) and "opened" or "unavailable"
end

return FriendInvite
