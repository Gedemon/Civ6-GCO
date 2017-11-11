--=====================================================================================--
--	FILE:	 PlayerScript.lua
--  Gedemon (2017)
--=====================================================================================--

print("Loading PlayerScript.lua...")

-----------------------------------------------------------------------------------------
-- Includes
-----------------------------------------------------------------------------------------
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


-----------------------------------------------------------------------------------------
-- Debug
-----------------------------------------------------------------------------------------

DEBUG_PLAYER_SCRIPT			= true

function TogglePlayerDebug()
	DEBUG_PLAYER_SCRIPT = not DEBUG_PLAYER_SCRIPT
end

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local _cached				= {}	-- cached table to reduce calculations


-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 	= ExposedMembers.GCO
	Dprint 	= GCO.Dprint
	print("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function SaveTables()
	print("--------------------------- Saving PlayerData ---------------------------")
	GCO.SaveTableToSlot(ExposedMembers.PlayerData, "PlayerData")
end
LuaEvents.SaveTables.Add(SaveTables)

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.PlayerData = GCO.LoadTableFromSlot("PlayerData") or {}
	InitializePlayerFunctions()
	InitializePlayerData() -- after InitializePlayerFunctions
end

function InitializePlayerData()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = Players[playerID]
		if player and not ExposedMembers.PlayerData[player:GetKey()] then
			player:InitializeData()
		end	
	end
end


-----------------------------------------------------------------------------------------
-- PlayerData functions
-----------------------------------------------------------------------------------------
--[[
function UpdatePopulationNeeds(self)
	local era = self:GetEra()
	for row in GameInfo.PopulationNeeds() do
		if (not row.StartEra or (row.StartEra and GameInfo.Eras[row.StartEra].Index >= era)) and (not row.EndEra or (row.EndEra and GameInfo.Eras[row.EndEra].Index < era)) then
			local resourceID 	= GameInfo.Resources[row.ResourceType].Index
			local populationID 	= GameInfo.Populations[row.PopulationType].Index
			-- Needs by population
			if not _cached.PopulationNeeds then _cached.PopulationNeeds = {} end
			if not _cached.PopulationNeeds[populationID] then _cached.PopulationNeeds[populationID] = {} end
			if not _cached.PopulationNeeds[populationID][resourceID] then _cached.PopulationNeeds[populationID][resourceID] = {} end
			if not _cached.PopulationNeeds[populationID][resourceID][row.AffectedType] then _cached.PopulationNeeds[populationID][resourceID][row.AffectedType] = {} end
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].NeededCalculFunction 	= loadstring(row.NeededCalculFunction)
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].EffectCalculFunction 	= loadstring(row.EffectCalculFunction)
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].OnlyBonus 				= row.OnlyBonus
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].OnlyPenalty 			= row.OnlyPenalty
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].MaxEffectValue 			= row.MaxEffectValue
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].Treshold 				= row.Treshold
			
			-- Needs by resources
			if not _cached.ResourcesNeeded then _cached.ResourcesNeeded = {} end
			if not _cached.ResourcesNeeded[resourceID] then _cached.ResourcesNeeded[resourceID] = {} end
			if not _cached.ResourcesNeeded[resourceID][populationID] then _cached.ResourcesNeeded[resourceID][populationID] = {} end
			if not _cached.ResourcesNeeded[resourceID][populationID][row.AffectedType] then _cached.ResourcesNeeded[resourceID][populationID][row.AffectedType] = {} end
			if not _cached.ResourcesNeeded[resourceID][populationID].Priority then -- use the higher priority value for the couple [resourceID][populationID]
				_cached.ResourcesNeeded[resourceID][populationID].Priority = row.Priority
			elseif row.Priority > _cached.ResourcesNeeded[resourceID][populationID].Priority then
				_cached.ResourcesNeeded[resourceID][populationID].Priority = row.Priority
			end
			if not _cached.ResourcesNeeded[resourceID][populationID].Ratio then -- use the higher Ratio value for the couple [resourceID][populationID]
				_cached.ResourcesNeeded[resourceID][populationID].Ratio = row.Ratio
			elseif row.Ratio > _cached.ResourcesNeeded[resourceID][populationID].Ratio then
				_cached.ResourcesNeeded[resourceID][populationID].Ratio = row.Ratio
			end
		end		 
	end
end

function GetPopulationNeeds(self, populationID)
	if not _cached.PopulationNeeds then self:UpdatePopulationNeeds() end
	return _cached.PopulationNeeds[populationID] or {}
end

function GetResourcesNeededForPopulations(self, resourceID)
	if not _cached.ResourcesNeeded then self:UpdatePopulationNeeds() end
	return _cached.ResourcesNeeded[resourceID] or {}
end

function GetResourcesConsumptionRatioForPopulation(self, resourceID, populationID)
	if not _cached.ResourcesNeeded then self:UpdatePopulationNeeds() end
	if not _cached.ResourcesNeeded[resourceID] then return 0 end
	if not _cached.ResourcesNeeded[resourceID][populationID] then return 0 end
	return _cached.ResourcesNeeded[resourceID][populationID].Ratio or 0
end
--]]

function InitializeData(self)
	local playerKey 	= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	ExposedMembers.PlayerData[playerKey] = {
		CurrentTurn 		= Game.GetCurrentGameTurn(),
		OrganizationLevel 	= 0,
		Account				= { [turnKey] = {} }, -- [turnKey] = {[AccountType] = value}
	}
end

function GetKey(self)
	return tostring(self:GetID())
end

function GetData(self)
	local playerKey  = tostring(self:GetKey())
	local playerData = ExposedMembers.PlayerData[playerKey]
	return playerData
end

-----------------------------------------------------------------------------------------
-- General functions
-----------------------------------------------------------------------------------------	

function CanTrain(self, unitType)
	local row 	= GameInfo.Units[unitType]
	
	if not row.CanTrain then return false end	
	if row.TraitType then return false end
	
	local tech 	= row.PrereqTech
	if tech then
		local techID = GameInfo.Technologies[tech].Index
		if not self:IsKnownTech(techID) then
			return false
		end
	end
	return true
end

function IsResourceVisible(self, resourceID)
	return GCO.IsResourceVisibleFor(self, resourceID)
end

function IsObsoleteEquipment(self, equipmentTypeID)
	if not GCO.IsResourceEquipment(equipmentTypeID) then return false end
	local ObsoleteTech = EquipmentInfo[equipmentTypeID].ObsoleteTech
	if not ObsoleteTech then return false end
	local pScience = self:GetTechs()
	local iTech	= GameInfo.Technologies[ObsoleteTech].Index
	return pScience:HasTech(iTech)
end


-----------------------------------------------------------------------------------------
-- Research functions
-----------------------------------------------------------------------------------------	
-- Player function
function IsKnownTech(self, techID)
	local selfID = self:GetID()
	if not _cached.KnownTech then self:SetKnownTech() end
	if not _cached.KnownTech[selfID] then self:SetKnownTech() end
	return _cached.KnownTech[selfID][techID]
end

function SetKnownTech(self)

	local selfID = self:GetID()
	if not _cached.KnownTech then _cached.KnownTech = {} end
	if not _cached.KnownTech[selfID] then _cached.KnownTech[selfID] = {} end
	
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		if player and player:IsMajor() and player:GetCities():GetCount() > 0 and self:GetDiplomacy():HasMet(iPlayer) then
			local pScience = player:GetTechs()
			for kTech in GameInfo.Technologies() do		
				local iTech	= kTech.Index
				if pScience:HasTech(iTech) then
					_cached.KnownTech[selfID][iTech] = true
				end
			end
		end
	end
end

--Events
function OnResearchCompleted(playerID)
	local player = Players[playerID]
	local playerCities = player:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			city:SetUnlockers()
		end
	end	
end
Events.ResearchCompleted.Add(OnResearchCompleted)


-----------------------------------------------------------------------------------------
-- Military Organization functions
-----------------------------------------------------------------------------------------
-- Player function
function SetMilitaryOrganizationLevel(self, OrganizationLevelID)
	local playerKey = self:GetKey()
	ExposedMembers.PlayerData[playerKey].OrganizationLevel = OrganizationLevelID
end

function GetMilitaryOrganizationLevel(self)
	local playerKey = self:GetKey()
	return ExposedMembers.PlayerData[playerKey].OrganizationLevel or 0
end

-- Events
local OrganizationLevelCivics = {
		[GameInfo.Civics["CIVIC_MILITARY_TRADITION"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL1"].Index,
		[GameInfo.Civics["CIVIC_MILITARY_TRAINING"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL2"].Index,
		[GameInfo.Civics["CIVIC_FEUDALISM"].Index]			= GameInfo.MilitaryOrganisationLevels["LEVEL3"].Index,
		[GameInfo.Civics["CIVIC_MERCENARIES"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL4"].Index,
		[GameInfo.Civics["CIVIC_NATIONALISM"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL5"].Index,
		[GameInfo.Civics["CIVIC_MOBILIZATION"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL6"].Index,
		[GameInfo.Civics["CIVIC_COLD_WAR"].Index]			= GameInfo.MilitaryOrganisationLevels["LEVEL7"].Index,
		[GameInfo.Civics["CIVIC_RAPID_DEPLOYMENT"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL8"].Index,
}
function OnCivicCompleted(playerID, civicID)
	if OrganizationLevelCivics[civicID] then
		local player = Players[playerID]
		player:SetMilitaryOrganizationLevel(OrganizationLevelCivics[civicID])
	end
end
Events.CivicCompleted.Add(OnCivicCompleted)


-----------------------------------------------------------------------------------------
-- Treasury functions
-----------------------------------------------------------------------------------------

-- Proceed with a transaction (update player's gold)
function ProceedTransaction(self, accountType, value)
	local playerData 		= self:GetData()
	local turnKey 			= GCO.GetTurnKey()
	local playerTreasury	= self:GetTreasury()
	if not playerData.Account[turnKey] then playerData.Account[turnKey] = {} end
	playerData.Account[turnKey][accountType] = (playerData.Account[turnKey][accountType] or 0) + value
	playerTreasury:ChangeGoldBalance(value)
end

-- Record a transaction already proceeded (do not update player's gold)
function RecordTransaction(self, accountType, value, turnKey) --turnKey optionnal
	local playerData 		= self:GetData()
	local turnKey 			= turnKey or GCO.GetTurnKey()
	if not playerData.Account[turnKey] then playerData.Account[turnKey] = {} end
	playerData.Account[turnKey][accountType] = (playerData.Account[turnKey][accountType] or 0) + value
end

function GetTransactionBalance(self, turnKey) --turnKey optionnal
	if not ExposedMembers.GCO_Initialized then return 0 end -- return 0 when called from UI scripts on load, before the mod's initialization
	local playerData 		= self:GetData()
	local turnKey 			= turnKey or GCO.GetTurnKey()
	if not playerData.Account[turnKey] then return 0 end
	return GCO.TableSummation(playerData.Account[turnKey])
end

function GetTransactionType(self, accountType, turnKey) --turnKey optionnal
	if not ExposedMembers.GCO_Initialized then return 0 end -- return 0 when called from UI scripts on load, before the mod's initialization
	local playerData 		= self:GetData()
	local turnKey 			= turnKey or GCO.GetTurnKey()
	if not playerData.Account[turnKey] then return 0 end
	return playerData.Account[turnKey][accountType] or 0
end

-----------------------------------------------------------------------------------------
-- Updates functions
-----------------------------------------------------------------------------------------

function UpdateUnitsFlags(self)
	local playerUnits = self:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do			
			LuaEvents.UnitsCompositionUpdated(self:GetID(), unit:GetID())
		end
	end
end

function UpdateCitiesBanners(self)
	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do			
			LuaEvents.CityCompositionUpdated(self:GetID(), city:GetID())
		end
	end
end

function UpdateDataOnNewTurn(self)
	local playerConfig = PlayerConfigurations[self:GetID()]
	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, "- Updating Data on new turn for "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()))

	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			city:UpdateDataOnNewTurn()
		end
	end
	
	local playerUnits = self:GetUnits()
	if playerUnits then
		for j, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			unit:UpdateDataOnNewTurn()
		end
	end
	
	self:SetKnownTech()
	
end


-----------------------------------------------------------------------------------------
-- DoTurn Functions
-----------------------------------------------------------------------------------------
function SetCurrentTurn(self)
	local playerKey = self:GetKey()
	ExposedMembers.PlayerData[playerKey].CurrentTurn = Game.GetCurrentGameTurn()
end

function HasStartedTurn(self)
	local playerKey = self:GetKey()
	return (ExposedMembers.PlayerData[playerKey].CurrentTurn == Game.GetCurrentGameTurn())
end

function DoPlayerTurn( playerID )
	if (playerID == -1) then playerID = 0 end -- this is necessary when starting in AutoPlay
	
	local player = Players[playerID]
	if player and not player:HasStartedTurn() then
		local playerConfig						= PlayerConfigurations[playerID]
		GCO.PlayerTurnsDebugChecks[playerID]	= {}
		
		print("---============================================================================================================================================================================---")
		print("--- STARTING TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER # ".. tostring(playerID) .. " ( ".. tostring(Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))) .." )")
		print("---============================================================================================================================================================================---")
		
		--player:UpdatePopulationNeeds()
		LuaEvents.DoUnitsTurn( playerID )
		LuaEvents.DoCitiesTurn( playerID )	
		
		-- update flags after resources transfers
		player:UpdateUnitsFlags()
		player:UpdateCitiesBanners()
		player:SetCurrentTurn()
		
		if playerID == Game.GetLocalPlayer() then		
			LuaEvents.SaveTables()
		end
	end
end
LuaEvents.StartPlayerTurn.Add(DoPlayerTurn)

function CheckPlayerTurn(playerID)
	local playerConfig	= PlayerConfigurations[playerID]
	local bNoError		= true
	if GCO.PlayerTurnsDebugChecks[playerID] then
		if not GCO.PlayerTurnsDebugChecks[playerID].UnitsTurn then
			GCO.ErrorWithLog("UNITS TURN UNFINISHED AT TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER #".. tostring(playerID) .. " ( ".. tostring(Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))) .." )")
			bNoError = false
		end
		if not GCO.PlayerTurnsDebugChecks[playerID].CitiesTurn then
			GCO.ErrorWithLog("CITIES TURN UNFINISHED AT TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER #".. tostring(playerID) .. " ( ".. tostring(Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))) .." )")
			bNoError = false
		end
		if bNoError then		
			Dprint( DEBUG_PLAYER_SCRIPT, "- 'DoTurn' completed for player ID#".. tostring(playerID) .. " - "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
		end
		GCO.PlayerTurnsDebugChecks[playerID] = nil
	end
end
LuaEvents.StartPlayerTurn.Add(CheckPlayerTurn)

-- can't use those, they makes the game crash at self.m_Instance.UnitIcon:SetToolTipString( Locale.Lookup(nameString) ) in UnitFlagManager, and some other unidentified parts of the code...
--GameEvents.PlayerTurnStarted.Add(DoPlayerTurn)
--GameEvents.PlayerTurnStarted.Add(CheckPlayerTurn)
--GameEvents.PlayerTurnStartComplete.Add(DoPlayerTurn)

function DoTurnForLocal() -- The Error reported on the line below is triggered by something else.
	local playerID = Game.GetLocalPlayer()
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	print("-- Events.LocalPlayerTurnBegin -> Testing Start Turn for player#"..tostring(playerID))
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	local player = Players[playerID]
	if player and not player:HasStartedTurn() then	
		--DoPlayerTurn(playerID)
		--CheckPlayerTurn(playerID)
		LuaEvents.StartPlayerTurn(playerID)
	end
end
Events.LocalPlayerTurnBegin.Add( DoTurnForLocal )

function DoTurnForRemote( playerID )
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	print("-- Events.RemotePlayerTurnBegin -> Testing Start Turn for player#"..tostring(playerID))
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	--DoPlayerTurn(playerID)	
	--CheckPlayerTurn(playerID)
	LuaEvents.StartPlayerTurn(playerID)
end
Events.RemotePlayerTurnBegin.Add( DoTurnForRemote )

--
function DoTurnForNextPlayerFromRemote( playerID )

	repeat
		playerID = playerID + 1
		player = Players[playerID]
	until((player and player:WasEverAlive()) or playerID > 63)
	
	if playerID > 63 then playerID = 0 end
	
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	print("-- Events.RemotePlayerTurnEnd -> Testing Start Turn for player#"..tostring(playerID))
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	LuaEvents.StartPlayerTurn(playerID)
end
Events.RemotePlayerTurnEnd.Add( DoTurnForNextPlayerFromRemote )

function DoTurnForNextPlayerFromLocal( playerID )
	if not playerID then playerID = 0 end
	repeat
		playerID = playerID + 1
		player = Players[playerID]
	until((player and player:WasEverAlive()) or playerID > 63)
	
	if playerID > 63 then playerID = 0 end
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	print("-- Events.LocalPlayerTurnEnd -> Testing Start Turn for player#"..tostring(playerID))
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	LuaEvents.StartPlayerTurn(playerID)
end
Events.LocalPlayerTurnEnd.Add( DoTurnForNextPlayerFromLocal )


-----------------------------------------------------------------------------------------
-- Events Functions
-----------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------
-- Shared Functions
-----------------------------------------------------------------------------------------
function GetPlayer(playerID)
	local player= Players[playerID]
	if not player then
		GCO.Error("player is nil in GetPlayer for playerID#", playerID)
		return
	end
	InitializePlayerFunctions(player)
	return player
end

-----------------------------------------------------------------------------------------
-- Initialize Player Functions
-----------------------------------------------------------------------------------------
function InitializePlayerFunctions(player) -- Note that those functions are limited to this file context
	if not player then player = Players[0] end
	local p = getmetatable(player).__index
	
	p.GetKey									= GetKey
	p.GetData									= GetData
	p.InitializeData							= InitializeData
	--
	p.ProceedTransaction						= ProceedTransaction
	p.RecordTransaction							= RecordTransaction
	p.GetTransactionType						= GetTransactionType
	p.GetTransactionBalance						= GetTransactionBalance
	--
	p.IsResourceVisible							= IsResourceVisible
	p.IsObsoleteEquipment						= IsObsoleteEquipment
	p.CanTrain									= CanTrain
	--
	p.SetMilitaryOrganizationLevel				= SetMilitaryOrganizationLevel
	p.GetMilitaryOrganizationLevel				= GetMilitaryOrganizationLevel
	--
	p.IsKnownTech								= IsKnownTech
	p.SetKnownTech								= SetKnownTech
	--
	p.UpdateUnitsFlags							= UpdateUnitsFlags
	p.UpdateCitiesBanners						= UpdateCitiesBanners
	--
	p.SetCurrentTurn							= SetCurrentTurn
	p.HasStartedTurn							= HasStartedTurn
	p.UpdateDataOnNewTurn						= UpdateDataOnNewTurn
	--
	--p.UpdatePopulationNeeds						= UpdatePopulationNeeds
	p.GetPopulationNeeds						= GetPopulationNeeds
	p.GetResourcesNeededForPopulations			= GetResourcesNeededForPopulations
	p.GetResourcesConsumptionRatioForPopulation = GetResourcesConsumptionRatioForPopulation
	
end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetPlayer 					= GetPlayer
	ExposedMembers.GCO.InitializePlayerFunctions 	= InitializePlayerFunctions
	ExposedMembers.GCO.PlayerTurnsDebugChecks 		= {}
	ExposedMembers.PlayerScript_Initialized 		= true
end
Initialize()