--=====================================================================================--
--	FILE:	 GCO_Script.lua
--  Gedemon (2017)
--=====================================================================================--

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

UnitHitPointsTable = {}

-----------------------------------------------------------------------------------------
-- Unit Table
-----------------------------------------------------------------------------------------
local maxHP = GlobalParameters.COMBAT_MAX_HIT_POINTS -- 100
local minCompLeftFactor = GlobalParameters.MIN_COMPONENT_LEFT_IN_UNIT_FACTOR -- 5
local maxCompLeftFactor = GlobalParameters.MAX_COMPONENT_LEFT_IN_UNIT_FACTOR -- 3
function GetNumComponentAtHP(maxNumComponent, HPLeft)
	local numComponent = 0
	local maxCompLeft100 = 0
	local minCompLeft100 = ((HPLeft * 100) * (maxNumComponent / maxHP) * (HPLeft / maxHP))
	if maxHP > maxNumComponent then
		maxCompLeft100 = math.min(HPLeft * 100, math.min(maxNumComponent * 100, (HPLeft * 100 / (maxNumComponent / maxHP))))
	else
		maxCompLeft100 = math.min(maxNumComponent * 100, HPLeft * 100 * ( maxNumComponent / maxHP))
	end	
	local numComponent100 = math.max( 100, ((( minCompLeft100 * minCompLeftFactor) + ( maxCompLeft100 * maxCompLeftFactor)) / ( minCompLeftFactor + maxCompLeftFactor )))
	numComponent = math.ceil(numComponent100 / 100)
	return numComponent
end


function CreateUnitHitPointsTable()
	for row in GameInfo.Units() do 
		UnitHitPointsTable[row.Index] = {}
		local Personnel = row.Personnel
		local Vehicules = row.Vehicules
		local Horses = row.Horses
		local Materiel = row.Materiel
		for hp = 1, maxHP do
			if Personnel > 0 then UnitHitPointsTable[row.Index][hp].Personnel = GetNumComponentAtHP(Personnel, hp) else UnitHitPointsTable[row.Index][hp].Personnel = 0 end
			if Vehicules > 0 then UnitHitPointsTable[row.Index][hp].Vehicules = GetNumComponentAtHP(Vehicules, hp) else UnitHitPointsTable[row.Index][hp].Vehicules = 0 end
			if Horses > 0 then UnitHitPointsTable[row.Index][hp].Horses = GetNumComponentAtHP(Horses, hp) else UnitHitPointsTable[row.Index][hp].Horses = 0 end
			if Materiel > 0 then UnitHitPointsTable[row.Index][hp].Materiel = GetNumComponentAtHP(Materiel, hp) else UnitHitPointsTable[row.Index][hp].Materiel = 0 end
		end
		--if row.Domain == "DOMAIN_SEA" then
		--	local unit = units:Create(row.Index, seaX, seaY)
	end
end


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
KillAllCS()