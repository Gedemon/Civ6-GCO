--=====================================================================================--
--	FILE:	 UnitScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading UnitScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local UnitHitPointsTable = {} -- cached table to store the required values of an unit components based on it's HP
local EverAliveZeroTable = {} -- cached table to initialize an empty table with civID as keys and 0 as initial values

local maxHP = GlobalParameters.COMBAT_MAX_HIT_POINTS -- 100

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO = {}
local CombatTypes = {}
function InitializeUtilityFunctions() 	-- get functions from other contexts
	if ExposedMembers.IsInitializedGCO and ExposedMembers.IsInitializedGCO() then
		GCO = ExposedMembers.GCO					-- contains functions from other contexts
		CombatTypes = ExposedMembers.CombatTypes 	-- need those in combat results
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
		InitializeTables()
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

function InitializeTables() -- tables that may require other context to be loaded (saved/loaded tables)
	LoadUnitTable()
	EverAliveZeroTable = GCO.CreateEverAliveTableWithDefaultValue(0)
end

function Initialize() -- Everything that can be initialized immediatly after loading this file(cached tables)
	CreateUnitHitPointsTable()
	ExposedMembers.UnitHitPointsTable = UnitHitPointsTable
end

-----------------------------------------------------------------------------------------
-- Unit composition
-----------------------------------------------------------------------------------------
local minCompLeftFactor = GameInfo.GlobalParameters["MIN_COMPONENT_LEFT_IN_UNIT_FACTOR"].Value -- Modded global parameters are not in GlobalParameters.NAME like vanilla parameters ?????
local maxCompLeftFactor = GameInfo.GlobalParameters["MAX_COMPONENT_LEFT_IN_UNIT_FACTOR"].Value
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
		local Vehicles = row.Vehicles
		local Horses = row.Horses
		local Materiel = row.Materiel
		for hp = 0, maxHP do
			UnitHitPointsTable[row.Index][hp] = {}
			if Personnel > 0 then UnitHitPointsTable[row.Index][hp].Personnel = GetNumComponentAtHP(Personnel, hp) else UnitHitPointsTable[row.Index][hp].Personnel = 0 end
			if Vehicles > 0 then UnitHitPointsTable[row.Index][hp].Vehicles = GetNumComponentAtHP(Vehicles, hp) else UnitHitPointsTable[row.Index][hp].Vehicles = 0 end
			if Horses > 0 then UnitHitPointsTable[row.Index][hp].Horses = GetNumComponentAtHP(Horses, hp) else UnitHitPointsTable[row.Index][hp].Horses = 0 end
			if Materiel > 0 then UnitHitPointsTable[row.Index][hp].Materiel = GetNumComponentAtHP(Materiel, hp) else UnitHitPointsTable[row.Index][hp].Materiel = 0 end
		end
	end
end

-----------------------------------------------------------------------------------------
-- Load/Save the tables
-----------------------------------------------------------------------------------------

-- Enum for faster serialization
local unitTableEnum = {

	unitID					= 1,
	playerID				= 2,
	unitType				= 3,
	MaterielPerVehicles		= 4,
	Personnel				= 5,
	Vehicles				= 6,
	Horses					= 7,
	Materiel				= 8,
	PersonnelReserve		= 9,
	VehiclesReserve			= 10,
	HorsesReserve			= 11,
	MaterielReserve			= 12,
	WoundedPersonnel		= 13,
	DamagedVehicles			= 14,
	Prisonners				= 15,
	FoodStock				= 16,
	PreviousFoodStock		= 17,
	TotalDeath				= 18,
	TotalVehiclesLost		= 19,
	TotalHorsesLost			= 20,
	TotalKill				= 21,
	TotalUnitsKilled		= 22,
	TotalShipSunk			= 23,
	TotalTankDestroyed		= 24,
	TotalAircraftKilled		= 25,
	Morale					= 26,
	MoraleVariation			= 27,
	LastCombatTurn			= 28,
	LastCombatResult		= 29,
	LastCombatType			= 30,
	Alive					= 31,
	TotalXP					= 32,
	CombatXP				= 33,
	SupplyLineCityKey		= 34,
	SupplyLineEfficiency	= 35,
	FuelStock				= 36,
	PreviousFuelStock		= 37,
	
	EndOfEnum				= 99
}                           

function SaveUnitTable()

	local UnitData = ExposedMembers.UnitData
	
	--print("--------------------------- Saving UnitData ---------------------------")

	-- 1/ direct but too slow ?
	--[[
	print("--------------------------- UnitData: Direct Save ---------------------------")
	GCO.StartTimer("Direct Save")
	GCO.SaveTableToSlot(UnitData, "UnitData")
	GCO.ShowTimer("Direct Save")
	--]]
	
	-- 2/ Use enums for shorter string
	---[[
	--print("--------------------------- UnitData: Save w/Enum ---------------------------")
	GCO.StartTimer("Save w/Enum")
	GCO.StartTimer("Pre-Save UnitTable")
	local t = {}
	for key, data in pairs(UnitData) do
		t[key] = {}
		for name, enum in pairs(unitTableEnum) do
			t[key][enum] = data[name]
		end
	end	
	GCO.ShowTimer("Pre-Save UnitTable")
	GCO.SaveTableToSlot(t, "UnitData")	
	GCO.ShowTimer("Save w/Enum")
	--]]
	
	-- 3/ Save short strings in multiple slots
	--[[
	print("--------------------------- UnitData: Multi-Save ---------------------------")	
	GCO.StartTimer("MultiSave")
	local UnitIndex = {}
	GCO.ToggleOutput()
	GCO.StartTimer("Pre-Save UnitTable")
	for key, data in pairs(UnitData) do
		GCO.SaveTableToSlot(UnitData[key], key)
		table.insert(UnitIndex, key)
	end
	GCO.ToggleOutput()
	GCO.ShowTimer("Pre-Save UnitTable")
	GCO.SaveTableToSlot(UnitIndex, "UnitIndex")
	GCO.ShowTimer("MultiSave")
	--]]	
	
	-- 4/ Save in each player slots
	--[[
	print("--------------------------- UnitData: Player Slots save ---------------------------")	
	GCO.StartTimer("Player Slots")
	local PlayerUnits = {}
	for key, data in pairs(UnitData) do
		if not PlayerUnits[tostring(data.playerID)] then PlayerUnits[tostring(data.playerID)] = {} end
		PlayerUnits[tostring(data.playerID)][key] = data
	end
	GCO.ToggleOutput()
	for playerID, data in pairs(PlayerUnits) do
		local playerConfig = PlayerConfigurations[tonumber(playerID)]
		local slot = playerConfig:GetCivilizationTypeName() .. "_UNITS"
		GCO.SaveTableToSlot(data, slot)
	end
	GCO.ToggleOutput()
	GCO.ShowTimer("Player Slots")
	--]]
	
end

function LoadUnitTable()

	-- 1/ direct but too slow ?
	--[[
	print("--------------------------- UnitData: Direct Load ---------------------------")
	--if not ExposedMembers.UnitData then ExposedMembers.UnitData = GCO.LoadTableFromSlot("UnitData") or {} end
	ExposedMembers.UnitData = GCO.LoadTableFromSlot("UnitData") or {}
	--ShowUnitData()
	--]]
	
	-- 2/ Use enums for shorter string
	---[[
	print("--------------------------- UnitData: Load w/Enum ---------------------------")
	local unitData = {}
	local loadedTable = GCO.LoadTableFromSlot("UnitData")
	GCO.StartTimer("Post-Load UnitTable")
	if loadedTable then
		for key, data in pairs(loadedTable) do
			unitData[key] = {}
			for name, enum in pairs(unitTableEnum) do
				unitData[key][name] = data[enum]
			end			
		end
		ExposedMembers.UnitData = unitData
		GCO.ShowTimer("Post-Load UnitTable")
	else
		ExposedMembers.UnitData = {}
	end
	--ShowUnitData()
	--]]
	
	-- 3/ Load short strings in multiple slots
	--[[
	print("--------------------------- UnitData: Multi-Load ---------------------------")		
	GCO.StartTimer("Multi-Load")
	ExposedMembers.UnitData = {}		
	GCO.StartTimer("Pre-Load UnitTable")
	local UnitIndex = GCO.LoadTableFromSlot("UnitIndex")		
	GCO.ShowTimer("Pre-Load UnitTable")
	GCO.ToggleOutput()
	if UnitIndex then
		for i, key in ipairs(UnitIndex) do
			ExposedMembers.UnitData[key] = GCO.LoadTableFromSlot(key)
		end
	end
	GCO.ToggleOutput()
	GCO.ShowTimer("Multi-Load")
	--ShowUnitData()
	--]]
	
	
	-- 4/ Load from player slots
	--[[
	print("--------------------------- UnitData: Load from Players Slots ---------------------------")		
	GCO.StartTimer("Players Slots Load")
	ExposedMembers.UnitData = {}
	GCO.ToggleOutput()
	for i, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local playerConfig = PlayerConfigurations[playerID]
		local slotName = playerConfig:GetCivilizationTypeName() .. "_UNITS"
		local unitTable = GCO.LoadTableFromSlot(slotName)
		for key, data in pairs(unitTable) do
			ExposedMembers.UnitData[key] = unitTable[key]
		end
	end	
	GCO.ToggleOutput()
	GCO.ShowTimer("Players Slots Load")

	--ShowUnitData()
	--]]
	
end

function SaveTables()
	SaveUnitTable()
end
LuaEvents.SaveTables.Add(SaveTables)

-- for debugging load/save
function ShowUnitData()
	for unitKey, data in pairs(ExposedMembers.UnitData) do
		print (unitKey, data)
		for k, v in pairs (data) do
			print ("-", k, v)
			if k == "Prisonners" then
				for id, num in pairs (v) do
					print ("-", "-", id, num)
				end			
			end
		end
	end
end

-----------------------------------------------------------------------------------------
-- Units Initialization
-----------------------------------------------------------------------------------------

function RegisterNewUnit(playerID, unit)

	local unitType = unit:GetType()
	local unitID = unit:GetID()
	local unitKey = GCO.GetUnitKey(unit)
	local hp = unit:GetMaxDamage() - unit:GetDamage()

	ExposedMembers.UnitData[unitKey] = {
		unitID 					= unitID,
		playerID 				= playerID,
		unitType 				= unitType,
		MaterielPerVehicles 	= GameInfo.Units[unitType].MaterielPerVehicles,
		-- "Frontline" : combat ready, units HP are restored only if there is enough reserve to move to frontline for all required components
		Personnel 				= UnitHitPointsTable[unitType][hp].Personnel,
		Vehicles 				= UnitHitPointsTable[unitType][hp].Vehicles,
		Horses 					= UnitHitPointsTable[unitType][hp].Horses,
		Materiel 				= UnitHitPointsTable[unitType][hp].Materiel,
		-- "Tactical Reserve" : ready to reinforce frontline, that's where reinforcements from cities, healed personnel and repaired Vehicles are affected first
		PersonnelReserve		= GCO.GetPersonnelReserve(unitType),
		VehiclesReserve			= GCO.GetVehiclesReserve(unitType),
		HorsesReserve			= GCO.GetHorsesReserve(unitType),
		MaterielReserve			= GCO.GetMaterielReserve(unitType),
		-- "Rear"
		WoundedPersonnel		= 0,
		DamagedVehicles			= 0,
		Prisonners				= GCO.CreateEverAliveTableWithDefaultValue(0), -- table with all civs in game (including Barbarians) to track Prisonners by nationality
		FoodStock 				= GCO.GetBaseFoodStock(unitType),
		PreviousFoodStock		= 0,
		FuelStock 				= GCO.GetBaseFuelStock(unitType),
		PreviousFuelStock		= 0,
		
		-- Statistics
		TotalDeath				= 0,
		TotalVehiclesLost		= 0,
		TotalHorsesLost			= 0,
		TotalKill				= 0,
		TotalUnitsKilled		= 0,
		TotalShipSunk			= 0,
		TotalTankDestroyed		= 0,
		TotalAircraftKilled		= 0,
		-- Others
		Morale 					= tonumber(GameInfo.GlobalParameters["MORALE_BASE_VALUE"].Value), -- 100
		MoraleVariation			= 0,
		LastCombatTurn			= 0,
		LastCombatResult		= 0,
		LastCombatType			= -1,
		Alive 					= true,
		TotalXP 				= unit:GetExperience():GetExperiencePoints(),
		CombatXP 				= 0,
		SupplyLineCityKey		= nil,
		SupplyLineEfficiency 	= 0,
	}
	SetUnitsupplyLine(unit)
	LuaEvents.NewUnitCreated()
end

function InitializeUnit(playerID, unitID)
	local unit = UnitManager.GetUnit(playerID, unitID)
	if unit then
		local unitKey = GCO.GetUnitKey(unit)

		if ExposedMembers.UnitData[unitKey] then
			-- unit already registered, don't add it again...
			print("  - ".. unit:GetName() .." is already registered")
			return
		end

		--print ("Initializing new unit (".. unit:GetName() ..") for player #".. tostring(playerID).. " id#" .. tostring(unit:GetID()))
		RegisterNewUnit(playerID, unit)
		--print("-------------------------------------")
	else
		print ("- WARNING : tried to initialize nil unit for player #".. tostring(playerID) .." (you can ignore this warning when launching a new game)")
	end

end
Events.UnitAddedToMap.Add( InitializeUnit )

-----------------------------------------------------------------------------------------
-- Damage received
-----------------------------------------------------------------------------------------

function OnCombat( combatResult )
	-- for console debugging...
	ExposedMembers.lastCombat = combatResult

	local attacker = combatResult[CombatResultParameters.ATTACKER]
	local defender = combatResult[CombatResultParameters.DEFENDER]

	local combatType = combatResult[CombatResultParameters.COMBAT_TYPE]

	attacker.IsUnit = attacker[CombatResultParameters.ID].type == ComponentType.UNIT
	defender.IsUnit = defender[CombatResultParameters.ID].type == ComponentType.UNIT

	-- We need to set some info before handling the change in the units composition
	if attacker.IsUnit then
		attacker.IsAttacker = true
		-- attach everything required by the update functions from the base CombatResultParameters
		attacker.FinalHP = attacker[CombatResultParameters.MAX_HIT_POINTS] - attacker[CombatResultParameters.FINAL_DAMAGE_TO]
		attacker.InitialHP = attacker.FinalHP + attacker[CombatResultParameters.DAMAGE_TO]
		attacker.IsDead = attacker[CombatResultParameters.FINAL_DAMAGE_TO] >= attacker[CombatResultParameters.MAX_HIT_POINTS]
		attacker.playerID = tostring(attacker[CombatResultParameters.ID].player) -- playerID is a key for Prisonners table
		attacker.unitID = attacker[CombatResultParameters.ID].id
		-- add information needed to handle casualties made to the other opponent (including unitKey)
		attacker = GCO.AddCombatInfoTo(attacker)
		--
		attacker.CanTakePrisonners = attacker.IsLandUnit and combatType == CombatTypes.MELEE and not attacker.IsDead
	end
	if defender.IsUnit then
		defender.IsDefender = true
		-- attach everything required by the update functions from the base CombatResultParameters
		defender.FinalHP = defender[CombatResultParameters.MAX_HIT_POINTS] - defender[CombatResultParameters.FINAL_DAMAGE_TO]
		defender.InitialHP = defender.FinalHP + defender[CombatResultParameters.DAMAGE_TO]
		defender.IsDead = defender[CombatResultParameters.FINAL_DAMAGE_TO] >= defender[CombatResultParameters.MAX_HIT_POINTS]
		defender.playerID = tostring(defender[CombatResultParameters.ID].player)
		defender.unitID = defender[CombatResultParameters.ID].id
		-- add information needed to handle casualties made to the other opponent (including unitKey)
		defender = GCO.AddCombatInfoTo(defender)
		--
		defender.CanTakePrisonners = defender.IsLandUnit and combatType == CombatTypes.MELEE and not defender.IsDead
	end

	-- Handle casualties
	if attacker.IsUnit then -- and attacker[CombatResultParameters.DAMAGE_TO] > 0 (we must fill data for even when the unit didn't take damage, else we'll have to check for nil entries before all operations...)
		if attacker.unit then
			if ExposedMembers.UnitData[attacker.unitKey] then
				attacker = GCO.AddFrontLineCasualtiesInfoTo(attacker) 		-- Set Personnel, Vehicles, Horses and Materiel casualties from the HP lost
				attacker = GCO.AddCasualtiesInfoByTo(defender, attacker) 	-- set detailed casualties (Dead, Captured, Wounded, Damaged, ...) from frontline Casualties and return the updated table
				if not attacker.IsDead then
					LuaEvents.UnitsCompositionUpdated(attacker.playerID, attacker.unitID) 	-- call to update flag
					GCO.ShowCasualtiesFloatingText(attacker)								-- visualize all casualties
				end
			end
		end
	end

	if defender.IsUnit then -- and defender[CombatResultParameters.DAMAGE_TO] > 0 (we must fill data for even when the unit didn't take damage, else we'll have to check for nil entries before all operations...)
		if defender.unit then
			if ExposedMembers.UnitData[defender.unitKey] then
				defender = GCO.AddFrontLineCasualtiesInfoTo(defender) 		-- Set Personnel, Vehicles, Horses and Materiel casualties from the HP lost
				defender = GCO.AddCasualtiesInfoByTo(attacker, defender) 	-- set detailed casualties (Dead, Captured, Wounded, Damaged, ...) from frontline Casualties and return the updated table
				if not defender.IsDead then
					LuaEvents.UnitsCompositionUpdated(defender.playerID, defender.unitID)	-- call to update flag
					GCO.ShowCasualtiesFloatingText(defender)								-- visualize all casualties
				end
			end
		end
	end

	-- Update some stats
	if attacker.IsUnit and defender.Dead then ExposedMembers.UnitData[attacker.unitKey].TotalKill = ExposedMembers.UnitData[attacker.unitKey].TotalKill + defender.Dead end
	if defender.IsUnit and attacker.Dead then ExposedMembers.UnitData[defender.unitKey].TotalKill = ExposedMembers.UnitData[defender.unitKey].TotalKill + attacker.Dead end

	if attacker.IsUnit and defender.IsUnit then
		local turn = Game.GetCurrentGameTurn()
		ExposedMembers.UnitData[attacker.unitKey].LastCombatTurn = turn
		ExposedMembers.UnitData[defender.unitKey].LastCombatTurn = turn

		ExposedMembers.UnitData[attacker.unitKey].LastCombatResult = defender[CombatResultParameters.DAMAGE_TO] - attacker[CombatResultParameters.DAMAGE_TO]
		ExposedMembers.UnitData[defender.unitKey].LastCombatResult = attacker[CombatResultParameters.DAMAGE_TO] - defender[CombatResultParameters.DAMAGE_TO]

		ExposedMembers.UnitData[attacker.unitKey].LastCombatType = combatType
		ExposedMembers.UnitData[defender.unitKey].LastCombatType = combatType
	end

	-- Plundering (with some bonuses to attack)
	if defender.IsLandUnit and combatType == CombatTypes.MELEE then -- and attacker.IsLandUnit (allow raiding on coast ?)

		if defender.IsDead then

			attacker.Prisonners = defender.Captured + ExposedMembers.UnitData[defender.unitKey].WoundedPersonnel -- capture all the wounded (to do : add prisonners drom enemy nationality here)
			attacker.MaterielGained = GCO.GetMaterielFromKillOfBy(defender, attacker)
			attacker.LiberatedPrisonners = GCO.GetTotalPrisonners(ExposedMembers.UnitData[defender.unitKey]) -- to do : recruit only some of the enemy prisonners and liberate own prisonners
			attacker.FoodGained = GCO.Round(ExposedMembers.UnitData[defender.unitKey].FoodStock * tonumber(GameInfo.GlobalParameters["COMBAT_ATTACKER_FOOD_KILL_PERCENT"].Value) /100)
			attacker.FoodGained = math.max(0, math.min(GCO.GetBaseFoodStock(attacker.unit:GetType()) - ExposedMembers.UnitData[attacker.unitKey].FoodStock, attacker.FoodGained ))

			-- Update composition
			ExposedMembers.UnitData[defender.unitKey].WoundedPersonnel 	= 0 -- Just to keep things clean...
			ExposedMembers.UnitData[defender.unitKey].FoodStock 		= ExposedMembers.UnitData[defender.unitKey].FoodStock 			- attacker.FoodGained -- Just to keep things clean...
			ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 	= ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 	+ attacker.MaterielGained
			ExposedMembers.UnitData[attacker.unitKey].PersonnelReserve 	= ExposedMembers.UnitData[attacker.unitKey].PersonnelReserve 	+ attacker.LiberatedPrisonners
			ExposedMembers.UnitData[attacker.unitKey].FoodStock 		= ExposedMembers.UnitData[attacker.unitKey].FoodStock 			+ attacker.FoodGained
			-- To do : prisonners by nationality
			ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID]	= ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID] + attacker.Prisonners

		else
			-- attacker
			attacker.Prisonners 	= defender.Captured
			attacker.MaterielGained = GCO.Round(defender.MaterielLost * tonumber(GameInfo.GlobalParameters["COMBAT_ATTACKER_MATERIEL_GAIN_PERCENT"].Value) /100)
			ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 				= ExposedMembers.UnitData[attacker.unitKey].MaterielReserve + attacker.MaterielGained
			ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID]	= ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID] + attacker.Prisonners

			-- defender
			defender.Prisonners 	= attacker.Captured
			defender.MaterielGained = GCO.Round(attacker.MaterielLost * tonumber(GameInfo.GlobalParameters["COMBAT_DEFENDER_MATERIEL_GAIN_PERCENT"].Value) /100)
			ExposedMembers.UnitData[defender.unitKey].MaterielReserve 				= ExposedMembers.UnitData[defender.unitKey].MaterielReserve + defender.MaterielGained
			ExposedMembers.UnitData[defender.unitKey].Prisonners[attacker.playerID]	= ExposedMembers.UnitData[defender.unitKey].Prisonners[attacker.playerID] + defender.Prisonners

		end

		-- Update unit's flag & visualize for attacker
		if not attacker.IsDead then
			GCO.ShowCombatPlunderingFloatingText(attacker)
			LuaEvents.UnitsCompositionUpdated(attacker.playerID, attacker.unitID)
		end

		-- Update unit's flag & visualize for defender
		if not defender.IsDead then
			GCO.ShowCombatPlunderingFloatingText(defender)
			LuaEvents.UnitsCompositionUpdated(defender.playerID, defender.unitID)
		end
	end
		
	if attacker.IsUnit and not attacker.IsDead then GCO.CheckComponentsHP(attacker.unit, "attacker after combat") end
	if defender.IsUnit and not defender.IsDead then GCO.CheckComponentsHP(defender.unit, "defender after combat") end
end
Events.Combat.Add( OnCombat )

-----------------------------------------------------------------------------------------
-- Healing
-----------------------------------------------------------------------------------------

function HealingUnits(playerID)

	local player = Players[playerID]
	local playerConfig = PlayerConfigurations[playerID]
	local playerUnits = player:GetUnits()
	if playerUnits then
		--print("-----------------------------------------------------------------------------------------")
		--print("Healing units for " .. tostring(playerConfig:GetCivilizationShortDescription()))

		local startTime = Automation.GetTime()

		-- stock units in a table from higher damage to lower
		local damaged = {}		-- List of damaged units needing reinforcements, ordered by healt left
		local healTable = {} 	-- This table store HP gained to apply en masse after all reinforcements are calculated (visual fix)
		for n = 0, maxHP do 	-- An unit can still be alive at 0 HP ?
			damaged[n] = {}
		end

		local maxTransfert = {}	-- maximum value of a component that can be used to heal in one turn
		local alreadyUsed = {}	-- materiel is used both to heal the unit (reserve -> front) and repair vehicules in reserve, up to a limit
		for i, unit in playerUnits:Members() do
			-- todo : check if the unit can heal (has a supply line, is not on water, ...)
			local hp = unit:GetMaxDamage() - unit:GetDamage()
			if hp < maxHP then
				table.insert(damaged[hp], unit)
				healTable[unit] = 0
			end
			maxTransfert[unit] = GCO.GetMaxTransfertTable(unit)
			alreadyUsed[unit] = {}
			alreadyUsed[unit].Materiel = 0
		end

		-- try to reinforce the selected units (move personnel, vehicule, horses, materiel from reserve to frontline)
		-- up to MAX_HP_HEALED (or an unit component limit), 1hp per loop
		local hasReachedLimit = {}
		for healHP = 1, GameInfo.GlobalParameters["MAX_HP_HEALED_FROM_RESERVE"].Value do -- to do : add limit by units in the loop
			for n = 0, maxHP do
				local unitTable = damaged[n]
				for j, unit in ipairs (unitTable) do
					if not hasReachedLimit[unit] then
						local hp = unit:GetMaxDamage() - unit:GetDamage()
						local key = GCO.GetUnitKey(unit)						
						if key then
							if (hp + healTable[unit] < maxHP) then
								local unitInfo = GameInfo.Units[unit:GetType()] -- GetType in script, GetUnitType in UI context...
								-- check here if the unit has enough reserves to get +1HP
								local reqPersonnel 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Personnel - UnitHitPointsTable[unitInfo.Index][hp].Personnel
								local reqVehicles 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Vehicles 	- UnitHitPointsTable[unitInfo.Index][hp].Vehicles
								local reqHorses 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Horses 	- UnitHitPointsTable[unitInfo.Index][hp].Horses
								local reqMateriel 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Materiel 	- UnitHitPointsTable[unitInfo.Index][hp].Materiel
if not ExposedMembers.UnitData[key] then print ("WARNING, no entry for " .. tostring(unit:GetName()) .. " id#" .. tostring(unit:GetID())) end
								-- unit limit (vehicles and horses are handled by personnel...)
								if reqPersonnel > tonumber(maxTransfert[unit].Personnel) or reqMateriel > tonumber(maxTransfert[unit].Materiel) then
									hasReachedLimit[unit] = true
									--print("- Reached healing limit for " .. unit:GetName() .. " at " .. tostring(healHP) ..", Requirements : Personnel = ".. tostring(reqPersonnel) .. ", Materiel = " .. tostring(reqMateriel))

								elseif  ExposedMembers.UnitData[key].PersonnelReserve >= reqPersonnel
								and 	ExposedMembers.UnitData[key].VehiclesReserve >= reqVehicles
								and 	ExposedMembers.UnitData[key].HorsesReserve >= reqHorses
								and 	ExposedMembers.UnitData[key].MaterielReserve >= reqMateriel
								then
									healTable[unit] = healTable[unit] + 1 -- store +1 HP for this unit
								end
							end
						end
					end
				end
			end
		end

		-- apply reinforcement from all passes to units in one call to SetDamage (fix visual display of one "+1" when the unit was getting possibly more)
		for unit, hp in pairs (healTable) do
			local key = GCO.GetUnitKey(unit)
			if key then

				local unitInfo = GameInfo.Units[unit:GetType()]
				local damage = unit:GetDamage()
				local initialHP = maxHP - damage
				local finalHP = initialHP + hp
				unit:SetDamage(damage-hp)

				-- update reserve and frontline...
				local reqPersonnel 	= UnitHitPointsTable[unitInfo.Index][finalHP].Personnel - UnitHitPointsTable[unitInfo.Index][initialHP].Personnel
				local reqVehicles 	= UnitHitPointsTable[unitInfo.Index][finalHP].Vehicles - UnitHitPointsTable[unitInfo.Index][initialHP].Vehicles
				local reqHorses 	= UnitHitPointsTable[unitInfo.Index][finalHP].Horses 	- UnitHitPointsTable[unitInfo.Index][initialHP].Horses
				local reqMateriel 	= UnitHitPointsTable[unitInfo.Index][finalHP].Materiel 	- UnitHitPointsTable[unitInfo.Index][initialHP].Materiel

				ExposedMembers.UnitData[key].PersonnelReserve 	= ExposedMembers.UnitData[key].PersonnelReserve - reqPersonnel
				ExposedMembers.UnitData[key].VehiclesReserve 	= ExposedMembers.UnitData[key].VehiclesReserve 	- reqVehicles
				ExposedMembers.UnitData[key].HorsesReserve 		= ExposedMembers.UnitData[key].HorsesReserve 	- reqHorses
				ExposedMembers.UnitData[key].MaterielReserve 	= ExposedMembers.UnitData[key].MaterielReserve 	- reqMateriel

				ExposedMembers.UnitData[key].Personnel 	= ExposedMembers.UnitData[key].Personnel 	+ reqPersonnel
				ExposedMembers.UnitData[key].Vehicles 	= ExposedMembers.UnitData[key].Vehicles 	+ reqVehicles
				ExposedMembers.UnitData[key].Horses 	= ExposedMembers.UnitData[key].Horses 		+ reqHorses
				ExposedMembers.UnitData[key].Materiel 	= ExposedMembers.UnitData[key].Materiel 	+ reqMateriel

				alreadyUsed[unit].Materiel = reqMateriel

				-- Visualize healing
				local healingData = {reqPersonnel = reqPersonnel, reqMateriel = reqMateriel, reqVehicles = reqVehicles, reqHorses = reqHorses, X = unit:GetX(), Y = unit:GetY() }
				GCO.ShowFontLineHealingFloatingText(healingData)

				LuaEvents.UnitsCompositionUpdated(playerID, unit:GetID()) -- call to update flag
				
				GCO.CheckComponentsHP(unit, "after Healing")
			end

		end

		-- try to heal wounded and repair Vehicles using materiel (move healed personnel and repaired Vehicles to reserve)
		for i, unit in playerUnits:Members() do
			local key = GCO.GetUnitKey(unit)
			if key then
				if ExposedMembers.UnitData[key] then
					-- wounded soldiers may die...
					local deads = GCO.Round(ExposedMembers.UnitData[key].WoundedPersonnel * 25/100) -- hardcoded, to do : era, promotions, support
					ExposedMembers.UnitData[key].WoundedPersonnel = ExposedMembers.UnitData[key].WoundedPersonnel - deads
					-- wounded soldiers may heal...
					local healed = math.ceil(ExposedMembers.UnitData[key].WoundedPersonnel * 25/100) -- hardcoded, to do : era, promotions, support (not rounded to heal last wounded)
					ExposedMembers.UnitData[key].WoundedPersonnel = ExposedMembers.UnitData[key].WoundedPersonnel - healed
					ExposedMembers.UnitData[key].PersonnelReserve = ExposedMembers.UnitData[key].PersonnelReserve + healed

					-- try to repair vehicles with materiel available left (= logistic/maintenance limit)
					local materielAvailable = maxTransfert[unit].Materiel - alreadyUsed[unit].Materiel
					local maxRepairedVehicles = GCO.Round(materielAvailable/(ExposedMembers.UnitData[key].MaterielPerVehicles* GameInfo.GlobalParameters["MATERIEL_PERCENTAGE_TO_REPAIR_VEHICLE"].Value/100))
					local repairedVehicules = 0
					if maxRepairedVehicles > 0 then
						repairedVehicules = math.min(maxRepairedVehicles, ExposedMembers.UnitData[key].DamagedVehicles)
						ExposedMembers.UnitData[key].DamagedVehicles = ExposedMembers.UnitData[key].DamagedVehicles - repairedVehicules
						ExposedMembers.UnitData[key].VehiclesReserve = ExposedMembers.UnitData[key].VehiclesReserve + repairedVehicules
					end

					-- Visualize healing
					local healingData = {deads = deads, healed = healed, repairedVehicules = repairedVehicules, X = unit:GetX(), Y = unit:GetY() }
					GCO.ShowReserveHealingFloatingText(healingData)

					LuaEvents.UnitsCompositionUpdated(playerID, unit:GetID()) -- call to update flag
				else
					print ("- WARNING : no entry in ExposedMembers.UnitData for unit ".. tostring(unit:GetName()) .." (key = ".. tostring(key) ..") in HealingUnits()")
				end
			else
				print ("- WARNING : key is nil for unit ".. tostring(unit) .." in HealingUnits()")
			end
		end

		local endTime = Automation.GetTime()
		--print("Healing units used " .. tostring(endTime-startTime) .. " seconds")
		--print("-----------------------------------------------------------------------------------------")
	end
end


-----------------------------------------------------------------------------------------
-- Supply Lines
-----------------------------------------------------------------------------------------
-- cf Worldinput.lua
--pathPlots, turnsList, obstacles = UnitManager.GetMoveToPath( kUnit, endPlotId )

function SupplyPathBlocked(pPlot, pPlayer)

	local ownerID = pPlot:GetOwner()
	local playerID = pPlayer:GetID()

	local aUnits = Units.GetUnitsInPlot(plot);
	for i, pUnit in ipairs(aUnits) do
		if pPlayer:GetDiplomacy():IsAtWarWith( pUnit:GetOwner() ) then return true end -- path blocked
	end
		
	if ( ownerID == playerID or ownerID == -1 ) then
		return false
	end

	if GCO.HasPlayerOpenBordersFrom(pPlayer, ownerID) then
		return false
	end	

	return true -- return true if the path is blocked...
end

function SetUnitsupplyLine(unit)
	local key = GCO.GetUnitKey(unit)
	local NoLinkToCity = true
	--local unitData = ExposedMembers.UnitData[key]
	local closestCity, distance = GCO.FindNearestPlayerCity( unit:GetOwner(), unit:GetX(), unit:GetY() )
	if closestCity then
		local cityPlot = Map.GetPlot(closestCity:GetX(), closestCity:GetY())
		--[[
		local pathPlots, turnsList, obstacles = GCO.GetMoveToPath( unit, cityPlot:GetIndex() ) -- can't be used as it takes unit stacking in account and return false if there is an unit in the city.
		if table.count(pathPlots) > 1 then
			local numTurns = turnsList[table.count( turnsList )]
			local efficiency = GCO.Round( 100 - math.pow(numTurns,2) )
			if efficiency > 50 then -- to do : allow players to change this value
				ExposedMembers.UnitData[key].SupplyLineCityKey = GCO.GetCityKey(closestCity)
				ExposedMembers.UnitData[key].SupplyLineCityOwner = closestCity:GetOwner()
				ExposedMembers.UnitData[key].SupplyLineEfficiency = efficiency
				NoLinkToCity = false
			end
		--]]
		local bShortestRoute = true
		local bIsPlotConnected = GCO.IsPlotConnected(Players[unit:GetOwner()], Map.GetPlot(unit:GetX(), unit:GetY()), cityPlot, "Land", bShortestRoute, nil, SupplyPathBlocked)
		local routeLength = GCO.GetRouteLength()
		if bIsPlotConnected then
			local efficiency = GCO.Round( 100 - math.pow(routeLength*0.85,2) )
			if efficiency > 50 then -- to do : allow players to change this value
				ExposedMembers.UnitData[key].SupplyLineCityKey = GCO.GetCityKey(closestCity)
				ExposedMembers.UnitData[key].SupplyLineEfficiency = efficiency
				NoLinkToCity = false
			else
				ExposedMembers.UnitData[key].SupplyLineCityKey = GCO.GetCityKey(closestCity)
				ExposedMembers.UnitData[key].SupplyLineEfficiency = 0
				NoLinkToCity = false
			end
		
		elseif distance == 0 then -- unit is on the city's plot...
			ExposedMembers.UnitData[key].SupplyLineCityKey = GCO.GetCityKey(closestCity)
			ExposedMembers.UnitData[key].SupplyLineEfficiency = 100
			NoLinkToCity = false
		end
	end
	
	if NoLinkToCity then
		ExposedMembers.UnitData[key].SupplyLineCityKey = nil
		ExposedMembers.UnitData[key].SupplyLineEfficiency = 0
	end
end

-----------------------------------------------------------------------------------------
-- Do Turn for Units
-----------------------------------------------------------------------------------------

function DoUnitFood(unit)

	local key = GCO.GetUnitKey(unit)
	local unitData = ExposedMembers.UnitData[key]

	-- Eat Food

	local foodEat = math.min(GCO.GetFoodConsumption(unitData), unitData.FoodStock)

	-- Get Food

	local foodGet = 0
	local iX = unit:GetX()
	local iY = unit:GetY()
	local adjacentRatio = tonumber(GameInfo.GlobalParameters["FOOD_COLLECTING_ADJACENT_PLOT_RATIO"].Value)
	local yieldFood = GameInfo.Yields["YIELD_FOOD"].Index
	local maxFoodStock = GCO.GetBaseFoodStock(unitData.unitType)
	-- Get food from the plot
	local plot = Map.GetPlot(iX, iY)
	if plot then
		foodGet = foodGet + (plot:GetYield(yieldFood) / (math.max(1, Units.GetUnitCountInPlot(plot))))
	end
	-- Get food from adjacent plots
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) and ((not adjacentPlot:IsOwned()) or adjacentPlot:GetOwner() == unit:GetOwner() ) then
			foodGet = foodGet + ((adjacentPlot:GetYield(yieldFood) / (1 + Units.GetUnitCountInPlot(adjacentPlot))) * adjacentRatio)
		end
	end
	foodGet = GCO.Round(foodGet)
	foodGet = math.max(0, math.min(maxFoodStock - unitData.FoodStock, foodGet))

	-- Update variation
	local foodVariation = foodGet - foodEat
	ExposedMembers.UnitData[key].PreviousFoodStock = unitData.FoodStock
	ExposedMembers.UnitData[key].FoodStock = unitData.FoodStock + foodVariation

	-- Visualize
	local foodData = { foodEat = foodEat, foodGet = foodGet, X = unit:GetX(), Y = unit:GetY() }
	GCO.ShowFoodFloatingText(foodData)
end

function DoUnitMorale(unit)
	local key = GCO.GetUnitKey(unit)
	local unitData = ExposedMembers.UnitData[key]
	local moraleVariation = 0
	moraleVariation = moraleVariation + GCO.GetMoraleFromFood(unitData)
	moraleVariation = moraleVariation + GCO.GetMoraleFromLastCombat(unitData)
	moraleVariation = moraleVariation + GCO.GetMoraleFromWounded(unitData)
	moraleVariation = moraleVariation + GCO.GetMoraleFromHP(unitData)

	local morale = math.max(0, math.min(ExposedMembers.UnitData[key].Morale + moraleVariation, tonumber(GameInfo.GlobalParameters["MORALE_BASE_VALUE"].Value)))
	ExposedMembers.UnitData[key].Morale = morale
	ExposedMembers.UnitData[key].MoraleVariation = moraleVariation

	local desertionRate, minPercentHP, minPercentReserve = 0
	if morale < tonumber(GameInfo.GlobalParameters["MORALE_BAD_PERCENT"].Value) then -- very low morale
		desertionRate 		= tonumber(GameInfo.GlobalParameters["MORALE_BAD_DESERTION_RATE"].Value) --3
		minPercentHP 		= tonumber(GameInfo.GlobalParameters["MORALE_BAD_MIN_PERCENT_HP"].Value) --50
		minPercentReserve 	= tonumber(GameInfo.GlobalParameters["MORALE_BAD_MIN_PERCENT_RESERVE"].Value) --25
	elseif morale < tonumber(GameInfo.GlobalParameters["MORALE_LOW_PERCENT"].Value) then -- low morale
		desertionRate 		= tonumber(GameInfo.GlobalParameters["MORALE_LOW_DESERTION_RATE"].Value) --1
		minPercentHP 		= tonumber(GameInfo.GlobalParameters["MORALE_LOW_MIN_PERCENT_HP"].Value) --75
		minPercentReserve 	= tonumber(GameInfo.GlobalParameters["MORALE_LOW_MIN_PERCENT_RESERVE"].Value) --50
	end
	if desertionRate > 0 then
		local HP = unit:GetMaxDamage() - unit:GetDamage()
		local unitType = unit:GetType()
		local personnelReservePercent = GCO.Round( ExposedMembers.UnitData[key].PersonnelReserve / GCO.GetPersonnelReserve(unitType) * 100)
		local desertionData = {Personnel = 0, Vehicles = 0, Horses = 0, Materiel = 0, GiveDamage = false, Show = false, X = unit:GetX(), Y = unit:GetY() }
		if HP > minPercentHP then
			local lostHP = math.max(1, GCO.Round(HP * desertionRate / 100))
			local finalHP = HP - desertionRate

			-- Get desertion number
			desertionData.Personnel = UnitHitPointsTable[unitType][HP].Personnel 	- UnitHitPointsTable[unitType][finalHP].Personnel
			desertionData.Vehicles 	= UnitHitPointsTable[unitType][HP].Vehicles 	- UnitHitPointsTable[unitType][finalHP].Vehicles
			desertionData.Horses 	= UnitHitPointsTable[unitType][HP].Horses		- UnitHitPointsTable[unitType][finalHP].Horses
			desertionData.Materiel	= UnitHitPointsTable[unitType][HP].Materiel 	- UnitHitPointsTable[unitType][finalHP].Materiel

			-- Remove deserters from frontline
			ExposedMembers.UnitData[key].Personnel 	= ExposedMembers.UnitData[key].Personnel  	- desertionData.Personnel
			ExposedMembers.UnitData[key].Vehicles  	= ExposedMembers.UnitData[key].Vehicles  	- desertionData.Vehicles
			ExposedMembers.UnitData[key].Horses		= ExposedMembers.UnitData[key].Horses	  	- desertionData.Horses
			ExposedMembers.UnitData[key].Materiel 	= ExposedMembers.UnitData[key].Materiel 	- desertionData.Materiel

			-- Store materiel, vehicles, horses
			ExposedMembers.UnitData[key].VehiclesReserve  	= ExposedMembers.UnitData[key].VehiclesReserve 	+ desertionData.Vehicles
			ExposedMembers.UnitData[key].HorsesReserve		= ExposedMembers.UnitData[key].HorsesReserve	+ desertionData.Horses
			ExposedMembers.UnitData[key].MaterielReserve 	= ExposedMembers.UnitData[key].MaterielReserve 	+ desertionData.Materiel

			desertionData.GiveDamage = true
			desertionData.Show = true

		end
		if personnelReservePercent > minPercentReserve then
			local lostPersonnel = math.max(1, GCO.Round(ExposedMembers.UnitData[key].PersonnelReserve * desertionRate / 100))

			-- Add desertion number
			desertionData.Personnel = desertionData.Personnel + lostPersonnel

			-- Remove deserters from reserve
			ExposedMembers.UnitData[key].PersonnelReserve 	= ExposedMembers.UnitData[key].PersonnelReserve	- lostPersonnel

			desertionData.Show = true

		end
		-- Visualize
		if desertionData.Show then
			GCO.ShowDesertionFloatingText(desertionData)
		end

		-- Set Damage
		if desertionData.GiveDamage then
			unit:SetDamage(unit:GetDamage() + desertionRate)
		end
	end
	GCO.CheckComponentsHP(unit, "after DoUnitMorale()")
end

function DoUnitFuel(unit)

	local key = GCO.GetUnitKey(unit)
	local unitData = ExposedMembers.UnitData[key]

	local fuelConsumption = math.min(GCO.GetFuelConsumption(unitData), unitData.FuelStock)

	-- Update variation
	ExposedMembers.UnitData[key].PreviousfuelStock = unitData.FuelStock
	ExposedMembers.UnitData[key].FuelStock = unitData.FuelStock - fuelConsumption

	-- Visualize
	local fuelData = { fuelConsumption = fuelConsumption, X = unit:GetX(), Y = unit:GetY() }
	GCO.ShowFuelConsumptionFloatingText(fuelData)
end

function UnitDoTurn(unit)
	local key = GCO.GetUnitKey(unit)
	if not ExposedMembers.UnitData[key] then
		return
	end
	local playerID = unit:GetOwner()
	DoUnitFood(unit)
	DoUnitMorale(unit)
	DoUnitFuel(unit)
	SetUnitsupplyLine(unit)
	LuaEvents.UnitsCompositionUpdated(playerID, unit:GetID())
end

function DoUnitsTurn( playerID )

	HealingUnits( playerID )

	local player = Players[playerID]
	local playerConfig = PlayerConfigurations[playerID]
	local playerUnits = player:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do
			UnitDoTurn(unit)
		end
	end
end
LuaEvents.DoUnitsTurn.Add( DoUnitsTurn )

-----------------------------------------------------------------------------------------
-- Initialize Unit Functions
-----------------------------------------------------------------------------------------

function InitializeUnitFunctions(playerID, unitID) -- Note that those are limited to this file context
	local unit = UnitManager.GetUnit(playerID, unitID)
	local u = getmetatable(unit).__index	
	u.GetKey						= GCO.GetUnitKey	
	Events.UnitAddedToMap.Remove(InitializeUnitFunctions)
end
Events.UnitAddedToMap.Add(InitializeUnitFunctions)

-----------------------------------------------------------------------------------------
-- Initialize after loading the file...
-----------------------------------------------------------------------------------------

Initialize()
