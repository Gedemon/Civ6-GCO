--=====================================================================================--
--	FILE:	 UnitScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading UnitScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

-- This should be the first loading files, do some cleaning if Events.LeaveGameComplete hasn't fired on returning to main menu or loading a game.
ExposedMembers.SaveLoad_Initialized = nil
ExposedMembers.Utils_Initialized = nil

UnitHitPointsTable = {} -- cached table to store the required values of an unit components based on it's HP
--EverAliveZeroTable = {}	-- cached table to initialize an empty table with civID as keys and 0 as initial values 

local maxHP = GlobalParameters.COMBAT_MAX_HIT_POINTS -- 100

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

GCO = {}
CombatTypes = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if ExposedMembers.SaveLoad_Initialized and ExposedMembers.Utils_Initialized then -- can't use GameEvents.ExposedFunctionsInitialized.TestAll() because it will be called before all required test are added to the event...
		GCO = ExposedMembers.GCO					-- contains functions from other contexts
		CombatTypes = ExposedMembers.CombatTypes 	-- Need those in combat results
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
		InitializeTables()
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

function InitializeTables() -- Tables that may require other context to be loaded (saved/loaded tables)
	if not ExposedMembers.UnitData then ExposedMembers.UnitData = GCO.LoadTableFromSlot("UnitData") or {} end
	--EverAliveZeroTable = GCO.CreateEverAliveTableWithDefaultValue(0)
end

function Initialize() -- Everything that can be initialized immediatly after loading this file(cached tables)
	CreateUnitHitPointsTable()
	ExposedMembers.UnitHitPointsTable = UnitHitPointsTable
end

-----------------------------------------------------------------------------------------
-- Unit composition
-----------------------------------------------------------------------------------------
local minCompLeftFactor = GameInfo.GlobalParameters["MIN_COMPONENT_LEFT_IN_UNIT_FACTOR"].Value -- Modded global parameters are not in GlobalParameters ?????
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
-- Units Initialization
-----------------------------------------------------------------------------------------

function RegisterNewUnit(playerID, unit)

	local unitType = unit:GetType()
	local unitID = unit:GetID()
	local unitKey = GCO.GetUnitKey(unit)
	local hp = unit:GetMaxDamage() - unit:GetDamage()
	local reserveRatio = GameInfo.GlobalParameters["UNIT_RESERVE_RATIO"].Value --75

	ExposedMembers.UnitData[unitKey] = {
		UniqueID = unitKey.."-"..os.clock(), -- for linked statistics
		unitID = unitID,
		playerID = playerID,
		unitType = unitType,
		MaterielPerVehicles = GameInfo.Units[unitType].MaterielPerVehicles,
		-- "Frontline" : combat ready, units HP are restored only if there is enough reserve for all required components
		Personnel 			= UnitHitPointsTable[unitType][hp].Personnel,
		Vehicles 			= UnitHitPointsTable[unitType][hp].Vehicles,
		Horses 				= UnitHitPointsTable[unitType][hp].Horses,
		Materiel 			= UnitHitPointsTable[unitType][hp].Materiel,
		-- "Tactical Reserve" : ready to reinforce frontline, that's where reinforcements from cities, healed personnel and repaired Vehicles are affected first
		PersonnelReserve	= GCO.Round((UnitHitPointsTable[unitType][maxHP].Personnel * reserveRatio) / 1000) * 10,
		VehiclesReserve		= GCO.Round((UnitHitPointsTable[unitType][maxHP].Vehicles * reserveRatio) / 1000) *10,
		HorsesReserve		= GCO.Round((UnitHitPointsTable[unitType][maxHP].Horses * reserveRatio) / 1000) *10,
		MaterielReserve		= UnitHitPointsTable[unitType][maxHP].Materiel, -- full stock for materiel
		-- "Rear"
		WoundedPersonnel	= 0,
		DamagedVehicles		= 0,
		Prisonners			= GCO.CreateEverAliveTableWithDefaultValue(0), -- table with all civs in game (including Barbarians) to track Prisonners by nationality
		-- Statistics
		TotalDeath			= 0,
		TotalVehiclesLost	= 0,
		TotalHorsesLost		= 0,
		TotalKill			= 0,
		TotalUnitsKilled	= 0,
		TotalShipSunk		= 0,
		TotalTankDestroyed	= 0,
		TotalAircraftKilled	= 0,
		--
		Moral 				= 100,
		Alive 				= true,
		TotalXP 			= unit:GetExperience():GetExperiencePoints(),
		CombatXP 			= 0,
	}

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

		print ("Initializing new unit (".. unit:GetName() ..") for player #".. tostring(playerID))
		RegisterNewUnit(playerID, unit)
		print("-------------------------------------")
	else
		print ("- WARNING : tried to initialize nil unit for player #".. tostring(playerID))
	end

end
Events.UnitAddedToMap.Add( InitializeUnit )

-----------------------------------------------------------------------------------------
-- Damage received
-----------------------------------------------------------------------------------------

function ShowCasualtiesFloatingText(data)

	local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
	if (pLocalPlayerVis ~= nil) then
		if (pLocalPlayerVis:IsVisible(data.unit:GetX(), data.unit:GetY())) then
			local sText

			if data.PersonnelCasualties > 0 then
				sText = Locale.Lookup("LOC_FRONTLINE_PERSONNEL_CASUALTIES", data.PersonnelCasualties)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end
			if data.Dead + data.Captured + data.Wounded > 0 then
				sText = Locale.Lookup("LOC_FRONTLINE_PERSONNEL_CASUALTIES_DETAILS", data.Dead, data.Captured, data.Wounded)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end

			if data.VehiclesCasualties > 0 then
				sText = Locale.Lookup("LOC_FRONTLINE_VEHICLES_CASUALTIES", data.VehiclesCasualties)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end
			if data.VehiclesLost +data.DamagedVehicles > 0 then
				sText = Locale.Lookup("LOC_FRONTLINE_VEHICLES_CASUALTIES_DETAILS", data.VehiclesLost, data.DamagedVehicles)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end

			if data.HorsesLost > 0 then
				sText = Locale.Lookup("LOC_FRONTLINE_HORSES_CASUALTIES", data.HorsesLost)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end

			if data.MaterielLost > 0 then
				sText = Locale.Lookup("LOC_FRONTLINE_MATERIEL_CASUALTIES", data.MaterielLost)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end
		end
	end
end

function ShowCombatPlunderingFloatingText(data)

	local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
	if (pLocalPlayerVis ~= nil) then
		if (pLocalPlayerVis:IsVisible(data.unit:GetX(), data.unit:GetY())) then
			local sText

			if data.Prisonners > 0 then
				sText = Locale.Lookup("LOC_FRONTLINE_PRISONNERS_CAPTURED", data.Prisonners)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end

			if data.MaterielGained > 0 then
				sText = Locale.Lookup("LOC_FRONTLINE_MATERIEL_CAPTURED", data.MaterielGained)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end

			if data.LiberatedPrisonners and data.LiberatedPrisonners > 0 then -- LiberatedPrisonners is not nil only when the defender is dead...
				sText = Locale.Lookup("LOC_FRONTLINE_LIBERATED_PRISONNERS", data.LiberatedPrisonners)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, data.unit:GetX(), data.unit:GetY(), 0)
			end
		end
	end
end

function OnCombat( combatResult )
	-- for console debugging...
	ExposedMembers.lastCombat = combatResult

	local attacker = combatResult[CombatResultParameters.ATTACKER]
	local defender = combatResult[CombatResultParameters.DEFENDER]

	attacker.IsUnit = attacker[CombatResultParameters.ID].type == ComponentType.UNIT
	defender.IsUnit = defender[CombatResultParameters.ID].type == ComponentType.UNIT

	-- We need to set some info before handling the change in the units composition
	if attacker.IsUnit then
		attacker.IsAttacker = true
		attacker.FinalHP = attacker[CombatResultParameters.MAX_HIT_POINTS] - attacker[CombatResultParameters.FINAL_DAMAGE_TO]
		attacker.InitialHP = attacker.FinalHP + attacker[CombatResultParameters.DAMAGE_TO]
		attacker.IsDead = attacker[CombatResultParameters.FINAL_DAMAGE_TO] >= attacker[CombatResultParameters.MAX_HIT_POINTS]
		attacker.playerID = attacker[CombatResultParameters.ID].player
		attacker.unitID = attacker[CombatResultParameters.ID].id
		attacker = GCO.AddCombatInfoTo(attacker) -- Add information needed to handle casualties made to the other opponent
		attacker.CanTakePrisonners = attacker.IsLandUnit and combatResult[CombatResultParameters.COMBAT_TYPE] == CombatTypes.MELEE and not attacker.IsDead
	end
	if defender.IsUnit then
		defender.IsDefender = true
		defender.FinalHP = defender[CombatResultParameters.MAX_HIT_POINTS] - defender[CombatResultParameters.FINAL_DAMAGE_TO]
		defender.InitialHP = defender.FinalHP + defender[CombatResultParameters.DAMAGE_TO]
		defender.IsDead = defender[CombatResultParameters.FINAL_DAMAGE_TO] >= defender[CombatResultParameters.MAX_HIT_POINTS]
		defender.playerID = defender[CombatResultParameters.ID].player
		defender.unitID = defender[CombatResultParameters.ID].id
		defender = GCO.AddCombatInfoTo(defender) -- Add information needed to handle casualties made to the other opponent
		defender.CanTakePrisonners = defender.IsLandUnit and combatResult[CombatResultParameters.COMBAT_TYPE] == CombatTypes.MELEE and not defender.IsDead
	end

	-- Handle casualties
	if attacker.IsUnit then -- and attacker[CombatResultParameters.DAMAGE_TO] > 0 (we must fill data for even when the unit didn't take damage, else we'll have to check for nil entries before all operations...)
		if attacker.unit then
			if ExposedMembers.UnitData[attacker.unitKey] then
				attacker = GCO.AddFrontLineCasualtiesInfoTo(attacker) 		-- Set Personnel, Vehicles, Horses and Materiel casualties from the HP lost
				attacker = GCO.AddCasualtiesInfoByTo(defender, attacker) 	-- set detailed casualties (Dead, Captured, Wounded, Damaged, ...) from frontline Casualties and return the updated table
				if not attacker.IsDead then
					LuaEvents.UnitsCompositionUpdated(attacker.playerID, attacker.unitID) 	-- call to update flag
					ShowCasualtiesFloatingText(attacker)									-- visualize all casualties
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
					ShowCasualtiesFloatingText(defender)									-- visualize all casualties
				end
			end
		end
	end

	-- Update some stats
	if attacker.IsUnit and defender.Dead then ExposedMembers.UnitData[attacker.unitKey].TotalKill = ExposedMembers.UnitData[attacker.unitKey].TotalKill + defender.Dead end
	if defender.IsUnit and attacker.Dead then ExposedMembers.UnitData[defender.unitKey].TotalKill = ExposedMembers.UnitData[defender.unitKey].TotalKill + attacker.Dead end

	-- Plundering (with some bonuses to attack)
	if defender.IsLandUnit and combatResult[CombatResultParameters.COMBAT_TYPE] == CombatTypes.MELEE then -- and attacker.IsLandUnit (allow raiding on coast ?)

		if defender.IsDead then

			attacker.Prisonners = defender.Captured + ExposedMembers.UnitData[defender.unitKey].WoundedPersonnel -- capture all the wounded (to do : add prisonners drom enemy nationality here)
			attacker.MaterielGained = GCO.Round(defender.MaterielLost*50/100) + GCO.Round(ExposedMembers.UnitData[defender.unitKey].MaterielReserve*75/100) + GCO.Round(ExposedMembers.UnitData[defender.unitKey].DamagedVehicles * ExposedMembers.UnitData[defender.unitKey].MaterielPerVehicles*15/100) -- capture most materiel, convert some damaged Vehicles
			attacker.LiberatedPrisonners = GCO.GetTotalPrisonners(ExposedMembers.UnitData[defender.unitKey]) -- to do : recruit only some of the enemy prisonners and liberate own prisonners

			-- Update composition
			ExposedMembers.UnitData[defender.unitKey].WoundedPersonnel 	= 0 -- Just to keep things clean...
			ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 	= ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 	+ attacker.MaterielGained
			ExposedMembers.UnitData[attacker.unitKey].PersonnelReserve 	= ExposedMembers.UnitData[attacker.unitKey].PersonnelReserve 	+ attacker.LiberatedPrisonners
			-- To do : prisonners by nationality			
			ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID]	= ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID] + attacker.Prisonners

		else
			-- attacker
			attacker.Prisonners 	= defender.Captured
			attacker.MaterielGained = GCO.Round(defender.MaterielLost*50/100)
			ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 				= ExposedMembers.UnitData[attacker.unitKey].MaterielReserve + attacker.MaterielGained
			ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID]	= ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID] + attacker.Prisonners

			-- defender
			defender.Prisonners 	= attacker.Captured
			defender.MaterielGained = GCO.Round(attacker.MaterielLost*25/100)
			ExposedMembers.UnitData[defender.unitKey].MaterielReserve 				= ExposedMembers.UnitData[defender.unitKey].MaterielReserve + defender.MaterielGained
			ExposedMembers.UnitData[defender.unitKey].Prisonners[attacker.playerID]	= ExposedMembers.UnitData[defender.unitKey].Prisonners[attacker.playerID] + defender.Prisonners

		end

		-- Update unit's flag & visualize for attacker
		if not attacker.IsDead then
			ShowCombatPlunderingFloatingText(attacker)
			LuaEvents.UnitsCompositionUpdated(attacker.playerID, attacker.unitID)
		end

		-- Update unit's flag & visualize for defender
		if not defender.IsDead then
			ShowCombatPlunderingFloatingText(defender)
			LuaEvents.UnitsCompositionUpdated(defender.playerID, defender.unitID)
		end
	end
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
		print("-----------------------------------------------------------------------------------------")
		print("Healing units for " .. tostring(playerConfig:GetCivilizationShortDescription()))

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
						if (hp + healTable[unit] < maxHP) then
							local unitInfo = GameInfo.Units[unit:GetType()] -- GetType in script, GetUnitType in UI context...
							-- check here if the unit has enough reserves to get +1HP
							local reqPersonnel 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Personnel - UnitHitPointsTable[unitInfo.Index][hp].Personnel
							local reqVehicles 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Vehicles 	- UnitHitPointsTable[unitInfo.Index][hp].Vehicles
							local reqHorses 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Horses 	- UnitHitPointsTable[unitInfo.Index][hp].Horses
							local reqMateriel 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Materiel 	- UnitHitPointsTable[unitInfo.Index][hp].Materiel

							-- unit limit (vehicles and horses are handled by personnel...)
							if reqPersonnel > tonumber(maxTransfert[unit].Personnel) or reqMateriel > tonumber(maxTransfert[unit].Materiel) then
								hasReachedLimit[unit] = true
								print("- Reached healing limit for " .. unit:GetName() .. " at " .. tostring(healHP) ..", Requirements : Personnel = ".. tostring(reqPersonnel) .. ", Materiel = " .. tostring(reqMateriel))

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

		-- apply reinforcement from all passes to units in one call to SetDamage (fix visual display of one "+1" when the unit was getting possibly more)
		for unit, hp in pairs (healTable) do
			local key = GCO.GetUnitKey(unit)

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
			local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
			if (pLocalPlayerVis ~= nil) then
				if (pLocalPlayerVis:IsVisible(unit:GetX(), unit:GetY())) then
					local sText
					if reqPersonnel + reqMateriel > 0 then
						sText = Locale.Lookup("LOC_HEALING_PERSONNEL_MATERIEL", reqPersonnel, reqMateriel)
						Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
					end
					if reqVehicles > 0 then
						sText = Locale.Lookup("LOC_HEALING_VEHICLES", reqVehicles)
						Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
					end
					if reqHorses > 0 then
						sText = Locale.Lookup("LOC_HEALING_HORSES", reqHorses)
						Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
					end
				end
			end

			LuaEvents.UnitsCompositionUpdated(playerID, unit:GetID()) -- call to update flag

		end

		-- try to heal wounded and repair Vehicles using materiel (move healed personnel and repaired Vehicles to reserve)
		for i, unit in playerUnits:Members() do
			local key = GCO.GetUnitKey(unit)
			-- wounded soldiers may die...
			local deads = GCO.Round(ExposedMembers.UnitData[key].WoundedPersonnel * 25/100) -- hardcoded, to do : era, promotions, support
			ExposedMembers.UnitData[key].WoundedPersonnel = ExposedMembers.UnitData[key].WoundedPersonnel - deads
			-- wounded soldiers may heal...
			local healed = GCO.Round(ExposedMembers.UnitData[key].WoundedPersonnel * 25/100) -- hardcoded, to do : era, promotions, support
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
			local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
			if (pLocalPlayerVis ~= nil) then
				if (pLocalPlayerVis:IsVisible(unit:GetX(), unit:GetY())) then
					local sText
					if deads + healed > 0 then
						sText = Locale.Lookup("LOC_HEALING_WOUNDED", deads, healed)
						Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
					end
					if repairedVehicules > 0 then
						sText = Locale.Lookup("LOC_REPAIRING_VEHICLES", repairedVehicules)
						Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
					end
				end
			end

			LuaEvents.UnitsCompositionUpdated(playerID, unit:GetID()) -- call to update flag
		end

		local endTime = Automation.GetTime()
		print("Healing units used " .. tostring(endTime-startTime) .. " seconds")
		print("-----------------------------------------------------------------------------------------")
	end
end

function CheckForHealingOnPlayerTurnActivated( playerID, bFirstTime )
	if ( not bFirstTime) then
		return
	end
	local player = Players[playerID]
	if player:IsHuman() then
		HealingUnits(playerID)
		LuaEvents.SaveTables()
	end
end
Events.PlayerTurnActivated.Add( CheckForHealingOnPlayerTurnActivated )

function CheckForHealingOnRemotePlayerTurnBegin( playerID )
	local player = Players[playerID]
	if player:IsHuman() then
		return
	end
	HealingUnits(playerID)
end
Events.RemotePlayerTurnBegin.Add( CheckForHealingOnRemotePlayerTurnBegin )

-----------------------------------------------------------------------------------------
-- Save the tables
-----------------------------------------------------------------------------------------

function SaveTables()
	GCO.SaveTableToSlot(ExposedMembers.UnitData, "UnitData")
end
LuaEvents.SaveTables.Add(SaveTables)

-----------------------------------------------------------------------------------------
-- Initialize after loading the file...
-----------------------------------------------------------------------------------------

Initialize()


-----------------------------------------------------------------------------------------
-- Cleaning on exit
-----------------------------------------------------------------------------------------
function Cleaning()
	print ("Cleaning GCO stuff on LeaveGameComplete...")
	ExposedMembers.SaveLoad_Initialized = nil
	ExposedMembers.Utils_Initialized = nil
	ExposedMembers.UnitData = nil
	ExposedMembers.GCO = nil
	ExposedMembers.GetUnitKey = nil
	ExposedMembers.UI = nil
	ExposedMembers.CombatTypes = nil
	ExposedMembers.UnitHitPointsTable = nil
end
Events.LeaveGameComplete.Add(Cleaning)

-----------------------------------------------------------------------------------------
-- Testing...
-----------------------------------------------------------------------------------------
function TestA()
	print ("Calling TestA...")
end
function TestB()
	print ("Calling TestB...")
end
function TestC()
	print ("Calling TestC...")
end
--Events.LoadComplete.Add(TestA)
--Events.RequestSave.Add(TestB)
--Events.RequestLoad.Add(TestC)
--EndGameView