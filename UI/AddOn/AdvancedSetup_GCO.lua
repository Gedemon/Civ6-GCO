-- ===========================================================================
-- 	FILE:	 AdvancedSetup_GCO.lua
--  Gedemon (2021)
-- ===========================================================================

print("loading AdvancedSetup addon for GCO...")

-- ===========================================================================
-- Override HostGame to reserve Player Slots
-- ===========================================================================
function HostGame()

	local playerConfig = PlayerConfigurations[62]
	if playerConfig then
		local leaderType = "LEADER_BARB_PEACE"
		local leaderName = "LOC_CIVILIZATION_BARBARIAN_NAME"
		print(" - Reserving player slot#62 for ".. Locale.Lookup(leaderName) )
		playerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER)
		playerConfig:SetLeaderName(leaderName)
		playerConfig:SetLeaderTypeName(leaderType)
	end
	
	-- Start a normal game
	UI.PlaySound("Set_View_3D");
	Network.HostGame(ServerType.SERVER_TYPE_NONE);
end


