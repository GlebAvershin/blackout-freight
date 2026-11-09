local FriendInvite = {}

function FriendInvite.open(service, player, published)
	if not published then
		return "local"
	end
	local ok, allowed = pcall(service.CanSendGameInviteAsync, service, player)
	if not ok or not allowed then
		return "unavailable"
	end
	return pcall(service.PromptGameInvite, service, player) and "opened" or "unavailable"
end

return FriendInvite
