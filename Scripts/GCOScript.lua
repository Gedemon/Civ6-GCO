--=====================================================================================--
--	FILE:	 GCO_Script.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_Script.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------
-- Remove CS on game start
-----------------------------------------------------------------------------------------
function KillAllCS()

	if Game.GetCurrentGameTurn() > GameConfiguration.GetStartTurn() then -- only called on first turn
		return
	end
	
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		if not(player:IsMajor()) then
			local playerUnits = player:GetUnits()
			if playerUnits then
				for i, unit in playerUnits:Members() do
					playerUnits:Destroy(unit)
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------
-- Initialize script
-----------------------------------------------------------------------------------------
function Initialize()
	KillAllCS()
end
Initialize()