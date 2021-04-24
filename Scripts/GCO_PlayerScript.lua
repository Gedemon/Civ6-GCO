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

DEBUG_PLAYER_SCRIPT	= "PlayerScript"

function TogglePlayerDebug()
	DEBUG_PLAYER_SCRIPT = not DEBUG_PLAYER_SCRIPT
end



-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local _cached						= {}	-- cached table to reduce calculations
local OrganizationLevelCivics 		= {		-- Civics unlocking MilitaryOrganisationLevels
		[GameInfo.Technologies["TECH_MILITARY_TRADITION"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL1"].Index,
		[GameInfo.Technologies["TECH_MILITARY_TRAINING"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL2"].Index,
		[GameInfo.Technologies["TECH_MILITARY_ENGINEERING"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL3"].Index,
		[GameInfo.Technologies["TECH_MILITARY_TACTICS"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL4"].Index,
		[GameInfo.Technologies["TECH_NATIONALISM"].Index]			= GameInfo.MilitaryOrganisationLevels["LEVEL5"].Index,
		[GameInfo.Technologies["TECH_MOBILIZATION"].Index]			= GameInfo.MilitaryOrganisationLevels["LEVEL6"].Index,
		[GameInfo.Technologies["TECH_AMPHIBIOUS_WARFARE"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL7"].Index,
		[GameInfo.Technologies["TECH_RAPID_DEPLOYMENT"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL8"].Index,
}
local OrganizationLevelToSmaller 	= {		-- MilitaryOrganisationLevel to use when the Smaller Units Policy is active
		[GameInfo.MilitaryOrganisationLevels["LEVEL1"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL1B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL2"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL2B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL3"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL3B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL4"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL4B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL5"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL5B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL6"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL6B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL7"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL7B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL8"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL8B"].Index,
}
local OrganizationLevelToStandard 	= {		-- to get the normal MilitaryOrganisationLevel to use when the Smaller Units Policy is active
		[GameInfo.MilitaryOrganisationLevels["LEVEL1B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL1"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL2B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL2"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL3B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL3"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL4B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL4"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL5B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL5"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL6B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL6"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL7B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL7"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL8B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL8"].Index,
}
local smallerUnitsPolicyID 			= GameInfo.Policies["POLICY_SMALLER_UNITS"].Index

local PlayerFromCivilizationType	= {}	-- to get the PlayerID for a CivilizationType
-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------

local GCO 	= {}
local pairs = pairs
local Dprint, Dline, Dlog, Div
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 			= ExposedMembers.GCO
	LuaEvents		= GCO.LuaEvents
	Dprint 			= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline			= GCO.Dline					-- output current code line number to firetuner/log
	Dlog			= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	Div				= GCO.Div
	pairs 			= GCO.OrderedPairs
	print("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function SaveTables()
	Dprint( DEBUG_PLAYER_SCRIPT, "--------------------------- Saving PlayerData ---------------------------")
	GCO.SaveTableToSlot(ExposedMembers.PlayerData, "PlayerData")	
	Dprint( DEBUG_PLAYER_SCRIPT, "------------------------ Saving PlayerConfigData ------------------------")
	GCO.SaveTableToSlot(ExposedMembers.GCO.PlayerConfigData, "PlayerConfigData")
end
GameEvents.SaveTables.Add(SaveTables)

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.PlayerData 			= GCO.LoadTableFromSlot("PlayerData") or {}
	ExposedMembers.GCO.PlayerConfigData = GCO.LoadTableFromSlot("PlayerConfigData") or {}
	InitializePlayerFunctions()
	InitializePlayerData() -- after InitializePlayerFunctions
	SetPlayerDefines()
	
	LuaEvents.StartPlayerTurn.Add(DoPlayerTurn)
	LuaEvents.StartPlayerTurn.Add(CheckPlayerTurn)
end

function InitializePlayerData()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = Players[playerID]
		if player and not ExposedMembers.PlayerData[player:GetKey()] then
			player:InitializeData()
		end	
	end
end

function SetPlayerDefines()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = GCO.GetPlayer(playerID)
		if player then
			player:Define()
			local playerConfig	= player:GetConfig()
			PlayerFromCivilizationType[playerConfig:GetCivilizationTypeName()] = playerID
		end	
	end
end
--Events.LoadScreenClose.Add(SetPlayerDefines)

-----------------------------------------------------------------------------------------
-- PlayerData functions
-----------------------------------------------------------------------------------------
--[[
function UpdatePopulationNeeds(self)
	local era = self:GetEra()
	for row in GameInfo.PopulationNeeds() do
		if (not row.StartEra or (row.StartEra and GameInfo.Eras[row.StartEra].Index >= era)) and (not row.EndEra or (row.EndEra and GameInfo.Eras[row.EndEra].Index < era)) then
			local resourceID 	= GameInfo.Resources[row.ResourceType].Index
			local populationID 	= GameInfo.Resources[row.PopulationType].Index
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
		Debt			 	= 0,
		DebtUpdateTurn 		= Game.GetCurrentGameTurn(),
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

function GetConfig(self)
	return GCO.GetPlayerConfig(self:GetID())
end

function GetCache(self)
	local selfKey 	= self:GetKey()
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey]
end

function GetCached(self, key)
	local selfKey 	= self:GetKey()
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey][key]
end

function SetCached(self, key, value)
	local selfKey 	= self:GetKey()
	if not _cached[selfKey] then _cached[selfKey] = {} end
	_cached[selfKey][key] = value
end

function GetValue(self, key)
	local Data = self:GetData()
	if not Data then
		GCO.Warning("playerData is nil for " .. self:GetName(), self:GetKey())
		return
	end
	return Data[key]
end

function SetValue(self, key, value)
	local Data = self:GetData()
	if not Data then
		GCO.Error("playerData is nil for " .. self:GetName(), self:GetKey() .. "[NEWLINE]Trying to set ".. tostring(key) .." value to " ..tostring(value))
	end
	Data[key] = value
end

-----------------------------------------------------------------------------------------
-- General functions
-----------------------------------------------------------------------------------------	
function Define(self)

	--local DEBUG_PLAYER_SCRIPT = "debug"
	
	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, "Defining properties for "..Locale.Lookup(PlayerConfigurations[self:GetID()]:GetCivilizationShortDescription()), self:GetID())
	
	local playerConfig		= self:GetConfig()
	local civTypeName		= playerConfig:GetCivilizationTypeName()
	--local leaderTypeName	= playerConfig:GetLeaderTypeName()
	local governement		= self:GetCurrentGovernment()
	local civAdjective 		= playerConfig:GetValue("CivilizationAdjective") or GameInfo.Civilizations[civTypeName].Adjective
	local civName			= playerConfig:GetValue("CivilizationName") or GameInfo.Civilizations[civTypeName].Name
	local currentTurn		= Game.GetCurrentGameTurn()
	local currentYear		= GCO.GetTurnYear(currentTurn)
	local maxTurnsDiff 		= tonumber(GameInfo.GlobalParameters["LEADERS_REIGN_MAX_TURNS_DIFFERENCE"].Value)
	local maxYearsDiff		= GCO.GetTurnYear(currentTurn + maxTurnsDiff) - currentYear
	local genderPrefix		= { Male = "MALE_", Female = "FEMALE_" }
	local bestDiff			= maxYearsDiff + 1
	local rootName			= nil
	local leaderRow			= nil
	
	-- Check to update the player data for Tribe Culture
	-- GetTribePlayerCulture is not the same as GetCultureIDFromPlayerID, which return any cultureID, including majors, based on what's defined here for "CivilizationTypeName" while GetTribePlayerCulture returns only a TribeCultureID based on what's defined in GCO_AltHistScript.lua
	local cultureGroupID	= GCO.GetTribePlayerCulture(self:GetID()) 
	if cultureGroupID then
		civAdjective 		= GameInfo.CultureGroups[cultureGroupID].Adjective
		civName				= GameInfo.CultureGroups[cultureGroupID].Name
		civTypeName			= GameInfo.CultureGroups[cultureGroupID].CultureType
	end
	
	-- Get Governement RootName (= TypeName)
	if GameInfo.Governments[governement] and self:GetCities() and self:GetCities():GetCount() > 0 then
		rootName 	= GameInfo.Governments[governement].GovernmentType
	else -- Tribesmen
		rootName	= "GOVERNMENT_TRIBE"
	end
	Dprint( DEBUG_PLAYER_SCRIPT, "- Government rootName = ", rootName)

	-- Get leader
	Dprint( DEBUG_PLAYER_SCRIPT, "- loocking for Leader at year = ", currentYear, " maxYearsDiff = ", maxYearsDiff )
	for row in GameInfo.LeadersTimeLine() do
		if row.CivilizationType == civTypeName then
			Dprint( DEBUG_PLAYER_SCRIPT, "- Testing: ", row.LeaderName, row.StartDate, row.EndDate )
			if row.StartDate >= currentYear and row.EndDate <= currentYear then
				-- don't look further
				leaderRow	= row
				Dprint( DEBUG_PLAYER_SCRIPT, "  - VALIDATING LEADER: Current year is in Reign" )
				break
			end
			local diff = math.min( math.abs(row.StartDate - currentYear), math.abs(row.EndDate - currentYear) )
			if diff < bestDiff then
				Dprint( DEBUG_PLAYER_SCRIPT, "  - Marking as best Choice, with years diff = ", diff )
				leaderRow 	= row
				bestDiff	= diff
			else
				Dprint( DEBUG_PLAYER_SCRIPT, "  - Discarding, years diff is too high at ", diff )
			end
		end
	end
	
	-- Build LOC_NAMES
	local LeaderName		= nil -- Leader naming		ex: "Patriach {leaderName}" or "Patriach of {civName}"
	local ShortDescription	= nil -- Short naming		ex: "{civAdjective} tribesmen"
	local Description		= nil -- Long naming		ex: "Tribe of {civName}"
	local LOC_CIV_SPECIFIC	= nil -- temp var to test for Civilization Specific texts in the Localized DB 
	
	if leaderRow ~= nil then
		local LOC_LEADER	= "LOC_".. genderPrefix[leaderRow.Gender] .. rootName .. "_NAME"
		LOC_CIV_SPECIFIC	= "LOC_".. civTypeName .. "_".. genderPrefix[leaderRow.Gender] .. rootName .. "_NAME"
		LeaderName			= Locale.Lookup(LOC_CIV_SPECIFIC, leaderRow.LeaderName)
		if LeaderName == LOC_CIV_SPECIFIC then -- there was no localized civ-specific text found
			LeaderName		= Locale.Lookup(LOC_LEADER, leaderRow.LeaderName)
		end
	else
		local LOC_LEADER	= "LOC_UNKNOWN_" .. rootName .. "_NAME"
		LOC_CIV_SPECIFIC	= "LOC_".. civTypeName .. "_UNKNOWN_" .. rootName .. "_NAME"
		LeaderName			= Locale.Lookup(LOC_CIV_SPECIFIC, civName)
		if LeaderName == LOC_CIV_SPECIFIC then -- there was no localized civ-specific text found
			LeaderName		= Locale.Lookup(LOC_LEADER, civName)
		end
	end
		
	local LOC_SHORT		= "LOC_SHORT_".. rootName .. "_NAME"
	LOC_CIV_SPECIFIC	= "LOC_SHORT_".. civTypeName .. "_" .. rootName .. "_NAME"
	ShortDescription	= Locale.Lookup(LOC_CIV_SPECIFIC, civAdjective)
	if ShortDescription == LOC_CIV_SPECIFIC then -- there was no localized civ-specific text found
		ShortDescription	= Locale.Lookup(LOC_SHORT, civAdjective)
	end
		
	local LOC_LONG		= "LOC_LONG_".. rootName .. "_NAME"
	LOC_CIV_SPECIFIC	= "LOC_LONG_".. civTypeName .. "_" .. rootName .. "_NAME"
	Description			= Locale.Lookup(LOC_CIV_SPECIFIC, civName)
	if Description == LOC_CIV_SPECIFIC then -- there was no localized civ-specific text found
		Description		= Locale.Lookup(LOC_LONG, civName)
	end
	
	playerConfig:SetValue("LeaderName", 					LeaderName)
	playerConfig:SetValue("CivilizationShortDescription", 	ShortDescription)
	playerConfig:SetValue("CivilizationDescription", 		Description)
	playerConfig:SetValue("CivilizationName", 				civName)
	playerConfig:SetValue("CivilizationAdjective", 			civAdjective)
	playerConfig:SetValue("CivilizationTypeName",			civTypeName)
	
	PlayerFromCivilizationType[civTypeName]	= self:GetID()
	
	Dprint( DEBUG_PLAYER_SCRIPT, "- Setting Names : ", LeaderName, ShortDescription, Description)
	
	-- tests
	--[[
	playerConfig:SetValue("LeaderTypeName", 					"LEADER_FRANCE")
	playerConfig:SetValue("CivilizationTypeName", 			"CIVILIZATION_FRANCE")
	
	
	local PrimaryColor		= "COLOR_BLACK"
	local SecondaryColor	= "COLOR_WHITE"
	pPlayerConfig:SetValue("PrimaryColor", PrimaryColor)
	pPlayerConfig:SetValue("SecondaryColor", SecondaryColor)
	
	frontColor	= ColorStringToNumber(GameInfo.ColorsLegacy[PrimaryColor].Color)
	backColor	= ColorStringToNumber(GameInfo.ColorsLegacy[SecondaryColor].Color)
	
	borderOverlay:object = UILens.GetOverlay("CultureBorders")
	borderOverlay:SetBorderColors(playerID, backColor, frontColor)
	--]]
	
	self:UpdateUnitsFlags()
	self:UpdateCitiesBanners()
	Events.PlayerInfoChanged(self:GetID()) -- to force update in DiplomacyRibbon
end

function CanTrain(self, unitType) -- global check, used to show the unit in the build list, the tests for materiel/equipment and others limits are done at the city level 
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


-----------------------------------------------------------------------------------------
-- Empire Management functions
-----------------------------------------------------------------------------------------
-- Player function
function HasPolicyActive(self, policyID)
	return GCO.HasPolicyActive(self, policyID)
end

function GetActivePolicies(self)
	return GCO.GetActivePolicies(self)
end

function GetCurrentGovernment(self)
	return GCO.GetCurrentGovernment(self)
end

function GetTotalPopulation(self)
	local populationTotal		= 0
	local populationVariation	= 0
	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			populationTotal 	= populationTotal + city:GetTotalPopulation()
			populationVariation	= populationVariation + city:GetTotalPopulationVariation()
		end
	end
	return populationTotal, populationVariation
end

function GetTerritorySize(self)
	local territory		= 0
	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			--GCO.AttachCityFunctions(city)
			local cityPlots	= GCO.GetCityPlots(city)
			territory 		= territory + #cityPlots
		end
	end
	return territory
end

function GetTerritoryAdministrativeCost(self)

	local territorySize		= self:GetTerritorySize()
	local territoryCost		= territorySize/10
	local territorySurface	= territorySize*10000
	local landCostModifier	= self:GetModifiersForEffect("REDUCE_ADMINISTRATIVE_TERRITORY_COST")
	if landCostModifier then
		territoryCost	= territoryCost - (territoryCost * landCostModifier / 100)
	end

	return territoryCost, territorySurface
end

function GetTechAdministrativeFactor(self)
	return 1+(self:GetNumTechs()/7)
end

function GetCitiesAdministrativeFactor(self)
	return 1+(self:GetCities():GetCount()/1.75)
end

function GetUnitsAdministrativeFactor(self)
	return 1+(self:GetUnits():GetCount()/8)
end

function GetAdministrativeCost(self)
	return self:GetCached("AdministrativeCost") or self:SetAdministrativeCost()
end

function SetAdministrativeCost(self) -- must be updated each turn and on territory change & city change

	local PopulationBalance = self:GetTotalPopulation()
	local popSize			= math.floor(GCO.GetSizeAtPopulation(PopulationBalance))
	local citiesFactor		= self:GetCitiesAdministrativeFactor()
	local techFactor		= self:GetTechAdministrativeFactor()
	local territoryCost 	= self:GetTerritoryAdministrativeCost()
	local unitsFactor		= self:GetUnitsAdministrativeFactor()
	
	local empireCost	= math.floor((popSize + territoryCost) * techFactor * citiesFactor * unitsFactor)
	
	self:SetCached("AdministrativeCost", empireCost)
	return empireCost
end

function GetAdministrativeSupport(self)
	return self:GetCached("AdministrativeSupport") or self:SetAdministrativeSupport()
end

function SetAdministrativeSupport(self) -- must be updated each turn and on territory change & city change

	local AdminSupport		= {}
	AdminSupport.Resources	= 0
	AdminSupport.Yield		= 0
	local playerCities		= self:GetCities()
	local YieldID			= GameInfo.CustomYields["YIELD_ADMINISTRATION"].Index
	for i, city in playerCities:Members() do
		for resourceKey, value in pairs(city:GetResources()) do
			local resourceID = tonumber(resourceKey)
			local adminValue = GCO.GetAdministrativeResourceValue(resourceID)
			if adminValue then
				AdminSupport.Resources = AdminSupport.Resources + (value*adminValue)
			end
		end
		AdminSupport.Yield = AdminSupport.Yield + city:GetCustomYield(YieldID)
	end
	
	self:SetCached("AdministrativeSupport", AdminSupport)
	return AdminSupport
end

function GetAdministrativeEfficiency(self)
	local minEfficiency = 5 -- to do : rise with new Governement types
	local cost			= self:GetAdministrativeCost()
	local support		= GCO.TableSummation(self:GetAdministrativeSupport())
	return (support >= cost or cost == 0) and 100 or GCO.GetMaxPercentFromLowDiff(100, cost, support)--math.max(100 - ( cost / ( support + 1)), minEfficiency)
end

function GetAdministrationTooltip(self)

	local PopBalance, PopYield	= self:GetTotalPopulation()
	local popSize				= math.floor(GCO.GetSizeAtPopulation(PopBalance))
	local citiesFactor			= self:GetCitiesAdministrativeFactor()
	local landCost, landSurface = self:GetTerritoryAdministrativeCost()
	local empireCost			= self:GetAdministrativeCost()
	local techFactor			= self:GetTechAdministrativeFactor()
	local adminSupportTable		= self:GetAdministrativeSupport()
	local adminSupport			= GCO.TableSummation(adminSupportTable)
	local adminEfficiency		= self:GetAdministrativeEfficiency()
	local unitsFactor			= self:GetUnitsAdministrativeFactor()
	
	-- Modifiers
	local landModifier, list	= self:GetModifiersForEffect("REDUCE_ADMINISTRATIVE_TERRITORY_COST")
	local landModifierTextList	= GCO.GetModifierBulletList("REDUCE_ADMINISTRATIVE_TERRITORY_COST", list)
	
	local costString			= Locale.Lookup("LOC_TOP_PANEL_ADMINISTRATIVE_COST_TOOLTIP", adminEfficiency, empireCost, popSize, PopBalance, landCost, landSurface, citiesFactor, unitsFactor, techFactor)
	local supportString			= Locale.Lookup("LOC_TOP_PANEL_ADMINISTRATIVE_SUPPORT_TOOLTIP", adminSupport, adminSupportTable.Resources, adminSupportTable.Yield)
	local modifierString		= landModifierTextList:len() > 0 and "[NEWLINE][NEWLINE]"..Locale.Lookup("LOC_ACTIVE_MODIFIERS").."[NEWLINE]"..landModifierTextList or ""
	
	return costString.."[NEWLINE][NEWLINE]"..supportString..modifierString
	
end


-----------------------------------------------------------------------------------------
-- Modifiers
-----------------------------------------------------------------------------------------
function GetModifiersForEffect(self, eEffectType)
	local list		= {}
	local pTechs	= self:GetTechs()
	local bValid	= false
	local modifiers	= GCO.GetEffectModifiers(eEffectType)
	local value		= 0 -- to do: column for type of result: stacked (added) or best in <EffectsGCO>
	for i, row in ipairs(modifiers) do
		local data = GameInfo[row.Table] and GameInfo[row.Table][row.ObjectType]
		if row.Table == "Technologies" then
			bValid = pTechs:HasTech(data.Index)
		elseif row.Table == "Policies" then
			bValid = self:HasPolicyActive(data.Index)
		elseif row.Table == "Governments" then
			bValid = self:GetCurrentGovernment() == data.Index
		elseif row.Table == "Buildings" and row.IsGlobal then
			local playerCities = self:GetCities()
			if playerCities then
				for i, city in playerCities:Members() do
					bValid = city:GetBuildings():HasBuilding(data.Index)
				end
			end
		end
		
		if bValid then
			value = value + row.Value
			table.insert(list, {Type = row.ObjectType, Value = row.Value, Name = GameInfo[row.Table][row.ObjectType].Name})
		end
	end
	return value, list
end

-----------------------------------------------------------------------------------------
-- Army Management functions
-----------------------------------------------------------------------------------------
function IsObsoleteEquipment(self, equipmentTypeID)
	if not GCO.IsResourceEquipment(equipmentTypeID) then return false end
	local ObsoleteTech = EquipmentInfo[equipmentTypeID].ObsoleteTech
	if not ObsoleteTech then return false end
	local pScience = self:GetTechs()
	local iTech	= GameInfo.Technologies[ObsoleteTech].Index
	return pScience:HasTech(iTech)
end

function IsObsoleteResource(self, resourceID)
	local ObsoleteTech = GameInfo.Resources[resourceID].ObsoleteTech
	if not ObsoleteTech then return false end
	local pScience = self:GetTechs()
	local iTech	= GameInfo.Technologies[ObsoleteTech].Index
	return pScience:HasTech(iTech)
end

function GetPersonnelInCities(self) -- logistic support
	return self:GetCached("PersonnelInCities") or self:SetPersonnelInCities()
end

function SetPersonnelInCities(self) -- todo : update on city capture

	local personnel = 0
	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			personnel = personnel + city:GetPersonnel()
		end
	end
	
	self:SetCached("PersonnelInCities", personnel)
	return personnel
end

function GetPersonnelInUnits(self)
	local personnel = 0
	local playerUnits = self:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			personnel = personnel + unit:GetTotalPersonnel()
		end
	end
	return personnel
end

function GetLogisticPersonnelInActiveDuty(self)
	local maxActiveDutyPersonnel = 0
	for row in GameInfo.UnitPromotionClasses() do
		local promotionClassID 				= row.Index
		local logisticCost 					= self:GetLogisticCost(promotionClassID)
		if logisticCost > maxActiveDutyPersonnel then
			maxActiveDutyPersonnel	= logisticCost
		end
	end
	return math.min(maxActiveDutyPersonnel, self:GetPersonnelInCities())
end

function GetDraftedPercentage(self)
	local PopulationBalance = self:GetTotalPopulation()
	local ArmySize			= self:GetPersonnelInUnits() + self:GetLogisticPersonnelInActiveDuty() 
	return  ArmySize / PopulationBalance * 100
end

function GetMaxDraftedPercentage(self) -- the maximum percentage of population in the army
	local era 				= self:GetEra()
	local basePercentage	= GameInfo.Eras[era].ArmyMaxPercentOfPopulation
	local policies			= self:GetActivePolicies()
	if self:IsAtWar() then
		basePercentage = basePercentage + GameInfo.Eras[era].ArmyMaxPercentWarBoost
	end
	for _, policyID in ipairs(policies) do
		basePercentage = basePercentage + GameInfo.Policies[policyID].ArmyMaxPercentBoost
	end
	return basePercentage
end

function GetDraftEfficiencyPercent(self)
	local maxDraftedPercentage	= self:GetMaxDraftedPercentage()
	local draftedPercentage		= self:GetDraftedPercentage()
	return math.max(0, GCO.GetMaxPercentFromHighDiff(100, maxDraftedPercentage, draftedPercentage))
end

function GetLogisticCost(self, PromotionClassID)
	local LogisticCost = self:GetCached("LogisticCost") or self:SetLogisticCost()
	return LogisticCost[PromotionClassID] or 0
end

function SetLogisticCost(self) -- to do : update after units are killed for UI ?

	local LogisticCost	= {}
	local playerUnits = self:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			local PromotionClassID = unit:GetPromotionClassID()
			if PromotionClassID then
				LogisticCost[PromotionClassID] = (LogisticCost[PromotionClassID] or 0) + unit:GetLogisticCost()
			end
		end
	end
	--[[
	local logisticCost = 0
	local playerUnits = self:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			if PromotionClassID == unit:GetPromotionClassID() then
				logisticCost = logisticCost + unit:GetLogisticCost()
			end
		end
	end
	--]]
	self:SetCached("LogisticCost", LogisticCost)
	return LogisticCost
end

function GetLogisticSupport(self, PromotionClassID) -- the logistic support available from personnel in cities 
	local logisticSupport 		= self:GetPersonnelInCities()
	local promotionClassType 	= GameInfo.UnitPromotionClasses[PromotionClassID].PromotionClassType
	if promotionClassType == "PROMOTION_CLASS_SKIRMISHER" then
		logisticSupport = GCO.Round(logisticSupport * 0.1)
	elseif promotionClassType == "PROMOTION_CLASS_NAVAL_MELEE" or promotionClassType == "PROMOTION_CLASS_NAVAL_RANGED" then
		logisticSupport = GCO.Round(logisticSupport * 0.15)	
	end
	return logisticSupport
end

function GetArmyPersonnelPopulationRatio(self) -- the maximum percentage of population in the army
	local era 				= self:GetEra()
	return GameInfo.Eras[era].ArmyPersonnelPopulationRatio
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

function GetNumTechs(self)
	local numTech	= 0
	local pTechs	= self:GetTechs()
	for row in GameInfo.Technologies() do
		if pTechs:HasTech(row.Index) then
			numTech = numTech + 1
		end
	end
	return numTech
end

--Events
function OnResearchCompleted(playerID)
	local player = Players[playerID]
	local playerCities = player:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			if city:IsInitialized() then
				city:SetUnlockers()
			end
		end
	end	
end



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
	if self:IsBarbarian() then
		return math.floor((ExposedMembers.PlayerData[playerKey].OrganizationLevel or 0) / 2)
	else
		return ExposedMembers.PlayerData[playerKey].OrganizationLevel or 0
	end
end

function UpdateMilitaryOrganizationLevel(self)
	-- this function assume that a higher tech cost means better OrganizationLevel
	local bestTechID = nil
	local higherCost = 0
	local pScience = self:GetTechs()
	for techID, organizationLevelID in pairs(OrganizationLevelCivics) do
		if pScience:HasTech(techID) and pScience:GetResearchCost(techID) > higherCost then
			bestTechID = techID
			higherCost = pScience:GetResearchCost(techID)
		end
	end
	if bestTechID then	
		local organizationLevel	= OrganizationLevelCivics[bestTechID]
		if self:HasPolicyActive(smallerUnitsPolicyID) and OrganizationLevelToSmaller[organizationLevel] then
			organizationLevel = OrganizationLevelToSmaller[organizationLevel]
		end
		self:SetMilitaryOrganizationLevel(organizationLevel)
	end
end

function GetConscriptOrganizationLevel(self)

	local playerOrganizationLevel 	= self:GetMilitaryOrganizationLevel()
	local baseLevelID				= GameInfo.MilitaryOrganisationLevels["LEVEL0"].Index
	if self:HasPolicyActive(GameInfo.Policies["POLICY_SMALLER_UNITS"].Index) then
		baseLevelID = GameInfo.MilitaryOrganisationLevels["LEVEL0B"].Index
	end
	local organizationLevel	= math.max(baseLevelID , playerOrganizationLevel - 2)
	
	local policies	= self:GetActivePolicies()
	for _, policyID in ipairs(policies) do
		local policyType = GameInfo.Policies[policyID].PolicyType
		if policyType == "POLICY_CONSCRIPTION" or policyType == "POLICY_LEVEE_EN_MASSE" then 
			organizationLevel = math.max(baseLevelID , playerOrganizationLevel - 1)
		end
	end
	return organizationLevel
end


-- Events
function OnCivicCompleted(playerID, civicID) -- this function assume that Civics related to Military Organisation Levels are sequential (else the level could downgrade if a later civics is researched before an older)
	if OrganizationLevelCivics[civicID] then
		local player 			= Players[playerID]
		local organizationLevel	= OrganizationLevelCivics[civicID]
		if player:HasPolicyActive(smallerUnitsPolicyID) and OrganizationLevelToSmaller[organizationLevel] then
			organizationLevel = OrganizationLevelToSmaller[organizationLevel]
		end
		player:SetMilitaryOrganizationLevel(organizationLevel)
	end
end

function OnPolicyChanged(playerID, policyID)

	if policyID ~= smallerUnitsPolicyID then return end

	local player 			= Players[playerID]	
	local organizationLevel = player:GetMilitaryOrganizationLevel()
	
	if player:HasPolicyActive(smallerUnitsPolicyID) and OrganizationLevelToSmaller[organizationLevel] then
		organizationLevel = OrganizationLevelToSmaller[organizationLevel]
		player:SetMilitaryOrganizationLevel(organizationLevel)
	end
	
	if (not player:HasPolicyActive(smallerUnitsPolicyID)) and OrganizationLevelToStandard[organizationLevel] then
		organizationLevel = OrganizationLevelToStandard[organizationLevel]
		player:SetMilitaryOrganizationLevel(organizationLevel)
	end
end



-----------------------------------------------------------------------------------------
-- Treasury functions
-----------------------------------------------------------------------------------------

-- Proceed with a transaction (update player's gold)
function ProceedTransaction(self, accountType, value)

	--Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	--Dprint( DEBUG_PLAYER_SCRIPT, "Proceeding transaction for "..Locale.Lookup(PlayerConfigurations[self:GetID()]:GetCivilizationShortDescription()))
	local playerData 		= self:GetData()
	local turnKey 			= GCO.GetTurnKey()
	local playerTreasury	= self:GetTreasury()
	local goldBalance		= playerTreasury:GetGoldBalance()
	local currentBalance	= math.max(0, goldBalance) -- When negative, GoldBalance is set back to 0 at some point in Core, but it can be < 0 when processing transactions, so assume 0 when negative.
	local afterBalance		= currentBalance + value
	
	--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("transaction value") .. tostring(value))
	--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("realBalance") .. tostring(goldBalance))
	--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("virtualBalance") .. tostring(currentBalance))
	--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("afterBalance") .. tostring(afterBalance))

	if not playerData.Account[turnKey] then playerData.Account[turnKey] = {} end
	playerData.Account[turnKey][accountType] = (playerData.Account[turnKey][accountType] or 0) + value

	if afterBalance < 0 then
	
		--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Debt before") .. tostring(playerData.Debt))
		
		playerData.Debt = playerData.Debt + afterBalance
		
		--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Debt after") .. tostring(playerData.Debt))
		
		-- Core will add the base game income to the treasury before setting back the GoldBalance to 0
		-- To prevent any loss, we do not remove from the treasury what has been added to the debt
		value = value - afterBalance
		--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Value after") .. tostring(value))
	end	
	
	playerTreasury:ChangeGoldBalance(value)
	
	--Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
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

function UpdateDebt(self)

	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, "Updating Debt for "..Locale.Lookup(PlayerConfigurations[self:GetID()]:GetCivilizationShortDescription()))
	
	local playerData 		:table	= self:GetData()
	local playerTreasury	:table	= self:GetTreasury();
	local goldYield			:number = playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance()	
	local goldBalance		:number = playerTreasury:GetGoldBalance()
	local afterBalance		:number = goldBalance + goldYield
	
	Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("goldBalance") .. tostring(goldBalance))
	Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("goldYield") .. tostring(goldYield))	
	Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("afterBalance") .. tostring(afterBalance))
	
	if afterBalance < 0 then
	
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Debt before") .. tostring(playerData.Debt))
		
		playerData.Debt = playerData.Debt + goldYield
		
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Debt after") .. tostring(playerData.Debt))
		
	end
	
	if playerData.Debt < 0 and goldYield > 0 then
	
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Current Debt") .. tostring(playerData.Debt))
		
		local maxRepay			= math.min(goldYield, goldBalance) -- if gold yield is negative after adding the TransactionBalance, use all of the initial value for repayment as it may have been added to the gold balance after core has reset its value to 0
		local extraGoldYield 	= self:GetTransactionBalance()
		goldYield 				= goldYield + extraGoldYield
		
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("extraGoldYield") .. tostring(extraGoldYield))		
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("finalGoldYield") .. tostring(goldYield))	
		
		if goldYield > 0 then -- if gold yield is still positive, then gold balance was positive (and core did not reset it  to 0)
			maxRepay = math.min(goldYield / 2, goldBalance) -- 50% of net income used to repay the debt (to do: change by era/techs/policies)
		end

		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("maxRepay") .. tostring(maxRepay))
		
		if maxRepay > 0 then
		
			maxRepay = math.min(maxRepay, -playerData.Debt)
			Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("maxRepay") .. tostring(maxRepay))
			
			playerData.Debt = playerData.Debt + maxRepay
			self:ProceedTransaction(AccountType.Repay, -maxRepay)
			
			Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("New Debt") .. tostring(playerData.Debt))
			Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("New Balance") .. tostring(playerTreasury:GetGoldBalance()))
		end
	end
end

function OnTreasuryChanged(playerID, yield, balance)
	Dprint( DEBUG_PLAYER_SCRIPT, "OnTreasuryChanged", playerID, yield, balance)
	local player = Players[playerID]
	if player and player:IsTurnActive() then
		local playerData 	= player:GetData()
		local currentTurn	= Game.GetCurrentGameTurn()
		if playerData.DebtUpdateTurn ~= currentTurn then
			player:UpdateDebt()
			playerData.DebtUpdateTurn = currentTurn
		end
	end
end



-----------------------------------------------------------------------------------------
-- Diplomacy functions
-----------------------------------------------------------------------------------------

function IsAtWar(self)
	local playerDiplo = self:GetDiplomacy()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		if playerDiplo:IsAtWarWith( playerID ) then
			return true
		end
	end
	return false
end

function OnDiplomacyDeclareWar(attackerPlayerID, defenderPlayerID)

	local attacker 			= Players[attackerPlayerID]
	local defender 			= Players[defenderPlayerID]
	local attackerName		= Locale.Lookup(PlayerConfigurations[attackerPlayerID]:GetCivilizationShortDescription())
	local defenderName		= Locale.Lookup(PlayerConfigurations[defenderPlayerID]:GetCivilizationShortDescription())
	local defenderDiploAI 	= defender:GetAi_Diplomacy()
	local attackerDiploAI 	= attacker:GetAi_Diplomacy()
	local defenderDiplo		= defender:GetDiplomacy()
	local attackerDiplo		= attacker:GetDiplomacy()
	
	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, attackerName .. " Has declared war to " .. defenderName)
	
	Dprint( DEBUG_PLAYER_SCRIPT, "...Listing Allies of " .. defenderName)	
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		if playerID ~= attackerPlayerID and playerID ~= defenderPlayerID then
			if (defenderDiploAI:GetDiplomaticState(playerID) == "DIPLO_STATE_ALLIED") then
				local ally 		= Players[playerID]
				local allyName 	= Locale.Lookup(PlayerConfigurations[playerID]:GetCivilizationShortDescription())
				Dprint( DEBUG_PLAYER_SCRIPT, "......"..allyName)
				if (not attackerDiplo:IsAtWarWith( playerID )) then
					if attacker:CanDeclareWarOn( playerID ) then
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Receive DoW from " .. attackerName)
						attackerDiplo:DeclareWarOn(playerID)
						local allyMilitaryAI = ally:GetAi_Military()
						Dprint( DEBUG_PLAYER_SCRIPT, ".........allyMilitaryAI = ", allyMilitaryAI);
						allyMilitaryAI:PrepareForWarWith(attackerPlayerID);
						if ( allyMilitaryAI:HasOperationAgainst( attackerPlayerID, true ) ) then
							Dprint( DEBUG_PLAYER_SCRIPT, ".........Has Military operation against " .. attackerName)
						end
					else
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Can't receive DoW from " .. attackerName)
					end
				else
					Dprint( DEBUG_PLAYER_SCRIPT, ".........Already at war with " .. attackerName)
				end
			end
		end	
	end
	
	Dprint( DEBUG_PLAYER_SCRIPT, "...Listing Allies of " .. attackerName)	
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		if playerID ~= attackerPlayerID and playerID ~= defenderPlayerID then
			if (attackerDiploAI:GetDiplomaticState(playerID) == "DIPLO_STATE_ALLIED") then
				local ally 		= Players[playerID]
				local allyName 	= Locale.Lookup(PlayerConfigurations[playerID]:GetCivilizationShortDescription())
				local allyDiplo	= ally:GetDiplomacy()
				Dprint( DEBUG_PLAYER_SCRIPT, "......"..allyName)
				if (not allyDiplo:IsAtWarWith( defenderPlayerID )) then
					if ally:CanDeclareWarOn( defenderPlayerID ) then
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Can Declare War on " .. defenderName)
						local allyMilitaryAI = ally:GetAi_Military()
						Dprint( DEBUG_PLAYER_SCRIPT, ".........allyMilitaryAI = ", allyMilitaryAI);
						allyMilitaryAI:PrepareForWarWith(defenderPlayerID);
						if ( allyMilitaryAI:HasOperationAgainst( defenderPlayerID, true ) ) then
							Dprint( DEBUG_PLAYER_SCRIPT, ".........Has Military operation against " .. defenderName)
						end
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Declare War against " .. defenderName)
						allyDiplo:DeclareWarOn(defenderPlayerID)
					else
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Can't Declare War on " .. defenderName)
					end
				else
					Dprint( DEBUG_PLAYER_SCRIPT, ".........Already at war with " .. defenderName)
				end
			end
		end	
	end
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
	local playerConfig 	= PlayerConfigurations[self:GetID()]
	local cache 		= self:GetCache()
	cache.NumResource	= {} -- reset values
	local NumResource	= cache.NumResource
	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, "- Updating Data on new turn for "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
	
	if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then -- don't update on first turn (NewTurn is called on the first turn of a later era start)
		GCO.Warning("Aborting UpdateDataOnNewTurn for ".. Locale.Lookup(playerConfig:GetCivilizationShortDescription()) ..", this is the first turn !")
		return
	end

	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			city:UpdateDataOnNewTurn()
			for resourceKey, value in pairs(city:GetResources() or {}) do
				local resourceID		= tonumber(resourceKey)
				NumResource[resourceID] = (NumResource[resourceID] or 0) + value
			end
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

function UpdateDataOnLoad(self)
	local playerConfig 	= PlayerConfigurations[self:GetID()]
	local name 			= Locale.Lookup(playerConfig:GetCivilizationShortDescription())
	local cache 		= self:GetCache()
	cache.NumResource	= {} -- reset values
	local NumResource	= cache.NumResource
	GCO.StartTimer("UpdateCachedData for "..name)
	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, "- Updating Data on (re)Loading for "..name)

	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			city:UpdateTransferCities()
			city:UpdateExportCities()
			for resourceKey, value in pairs(city:GetResources() or {}) do
				local resourceID		= tonumber(resourceKey)
				NumResource[resourceID] = (NumResource[resourceID] or 0) + value
			end
		end
	end
	
	local playerUnits = self:GetUnits()
	if playerUnits then
		for j, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			--
		end
	end
	
	self:SetKnownTech()
	
	GCO.ShowTimer("UpdateCachedData for "..name)
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

local startTurnAutoSaveNum = 0

function DoPlayerTurn(playerID)
	local player = Players[playerID]
	if player and not player:HasStartedTurn() then
		GCO.Monitor(DoPlayerTurnP, {playerID}, "DoPlayerTurn")
	end
end

function DoPlayerTurnP( playerID )
	local DEBUG_PLAYER_SCRIPT	= "debug"
	--if (playerID == -1) then playerID = 0 end -- this is necessary when starting in AutoPlay
	
	local player = Players[playerID]
	if player and not player:HasStartedTurn() then
		GameEvents.PlayerTurnStartGCO.Call(playerID)
		local playerConfig						= GCO.GetPlayerConfig(playerID)
		GCO.PlayerTurnsDebugChecks[playerID]	= {}
		local playerName						= Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
		Dprint( DEBUG_PLAYER_SCRIPT, "---============================================================================================================================================================================---")
		Dprint( DEBUG_PLAYER_SCRIPT, "--- STARTING TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER # ".. tostring(playerID) .. " ( ".. tostring(playerName) .." )")
		Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
		
		-- Set cost before Cities turn
		player:SetAdministrativeCost()
		player:SetLogisticCost()
		
		-- May need that when launching a game with a later era start
		player:UpdateMilitaryOrganizationLevel()
		
		--
		--player:UpdatePopulationNeeds()
		
		GCO.StartTimer("DoUnitsTurn for ".. tostring(playerName))
		LuaEvents.DoUnitsTurn( playerID )
		GCO.ShowTimer("DoUnitsTurn for ".. tostring(playerName))
				
		GCO.StartTimer("DoTribesTurn for ".. tostring(playerName))
		LuaEvents.DoTribesTurn( playerID )
		GCO.ShowTimer("DoTribesTurn for ".. tostring(playerName))
		
		GCO.StartTimer("DoCitiesTurn for ".. tostring(playerName))
		LuaEvents.DoCitiesTurn( playerID )
		GCO.ShowTimer("DoCitiesTurn for ".. tostring(playerName))
		
		-- Set support after Cities turn	
		player:SetAdministrativeSupport()
		--
		player:SetPersonnelInCities()
		
		--
		LuaEvents.DoDiplomacyTurn( playerID )
		
		-- Call custom AI
		if not player:IsHuman() then
			if player:IsMajor() then
				GameEvents.InitializePlayerAI.Call(playerID, playerConfig:GetValue("TypeAI") or "DefaultAI")
			else
				GameEvents.InitializePlayerAI.Call(playerID, playerConfig:GetValue("TypeAI") or "TribeAI")
			end
			local AI = player:GetCached("AI")
			if AI and AI.DoTurn then
				AI:DoTurn()
				--GCO.Monitor(AI.DoTurn, {AI}, "Do AI Turn for ".. Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
			end
		end
		
		-- update flags after resources transfers
		player:Define()
		--player:UpdateUnitsFlags()
		--player:UpdateCitiesBanners()
		player:SetCurrentTurn()
		
		LuaEvents.ShowTimerLog(playerID)
		
		if playerID == Game.GetLocalPlayer() then		
			--GameEvents.SaveTables()
		end
		
		--if playerID == 0 then --and Automation.IsActive() then
		if playerID == Game.GetLocalPlayer() then		
		
			-- Making our own auto save...
			GameEvents.SaveTables.Call()
			startTurnAutoSaveNum = startTurnAutoSaveNum + 1
			if startTurnAutoSaveNum > 5 then startTurnAutoSaveNum = 1 end
			local saveGame = {};
			saveGame.Name = "GCO-StartTurnAutoSave"..tostring(startTurnAutoSaveNum)
			saveGame.Location = SaveLocations.LOCAL_STORAGE
			saveGame.Type= SaveTypes.SINGLE_PLAYER
			saveGame.IsAutosave = true
			saveGame.IsQuicksave = false
			GameEvents.SaveGameGCO.Call(saveGame)
		end
		
		GameEvents.PlayerTurnDoneGCO.Call(playerID)
	end
end


function CheckPlayerTurn(playerID)
	--local DEBUG_PLAYER_SCRIPT	= "debug"
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


-- can't use those, they makes the game crash at self.m_Instance.UnitIcon:SetToolTipString( Locale.Lookup(nameString) ) in UnitFlagManager, and some other unidentified parts of the code...
--GameEvents.PlayerTurnStarted.Add(DoPlayerTurn)
--GameEvents.PlayerTurnStarted.Add(CheckPlayerTurn)
--GameEvents.PlayerTurnStartComplete.Add(DoPlayerTurn)

function DoTurnForLocal()

	--local DEBUG_PLAYER_SCRIPT	= "debug"
	local playerID = Game.GetLocalPlayer()  -- The Error reported on that line is triggered by something else.
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint( DEBUG_PLAYER_SCRIPT, "-- Events.LocalPlayerTurnBegin -> Testing Start Turn for player#"..tostring(playerID))
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")

	-- In Network game we process all players turn at the same time in that case to try to prevent desync
	-- In that case AI units and cities update is done after the AI have processed their turn, not before
	if(GameConfiguration.IsNetworkMultiplayer()) then 
		for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
			LuaEvents.StartPlayerTurn(playerID)
		end
	else	
		local player = Players[playerID]
		if player and not player:HasStartedTurn() then	
			--DoPlayerTurn(playerID)
			--CheckPlayerTurn(playerID)
			LuaEvents.StartPlayerTurn(playerID)
		end
	end
end


function DoTurnForRemote( playerID )
	if(GameConfiguration.IsNetworkMultiplayer()) then return end
	--local DEBUG_PLAYER_SCRIPT	= "debug"
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint( DEBUG_PLAYER_SCRIPT, "-- Events.RemotePlayerTurnBegin -> Testing Start Turn for player#"..tostring(playerID))
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	--DoPlayerTurn(playerID)	
	--CheckPlayerTurn(playerID)
	LuaEvents.StartPlayerTurn(playerID)
end


--
function DoTurnForNextPlayerFromRemote( playerID )
	if(GameConfiguration.IsNetworkMultiplayer()) then return end
	--local DEBUG_PLAYER_SCRIPT	= "debug"

	repeat
		playerID = playerID + 1
		player = Players[playerID]
	until((player and player:WasEverAlive()) or playerID > 63)
	
	if playerID > 63 then playerID = 0 end
	
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint( DEBUG_PLAYER_SCRIPT, "-- Events.RemotePlayerTurnEnd -> Testing Start Turn for player#"..tostring(playerID))
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	LuaEvents.StartPlayerTurn(playerID)
end


function DoTurnForNextPlayerFromLocal( playerID )
	if(GameConfiguration.IsNetworkMultiplayer()) then return end
	--local DEBUG_PLAYER_SCRIPT	= "debug"
	if not playerID then playerID = 0 end
	repeat
		playerID = playerID + 1
		player = Players[playerID]
	until((player and player:WasEverAlive()) or playerID > 63)
	
	if playerID > 63 then playerID = 0 end
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint( DEBUG_PLAYER_SCRIPT, "-- Events.LocalPlayerTurnEnd -> Testing Start Turn for player#"..tostring(playerID))
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	LuaEvents.StartPlayerTurn(playerID)
end



-----------------------------------------------------------------------------------------
-- Events Functions
-----------------------------------------------------------------------------------------

function OnNewCityCreated(playerID, city)
	local player = GCO.GetPlayer(playerID)
	player:SetPersonnelInCities()
	player:SetAdministrativeSupport()
	player:SetAdministrativeCost()
end

function OnCapturedCityInitialized(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
	local originalPlayer	= GCO.GetPlayer(originalOwnerID)
	local newPlayer 		= GCO.GetPlayer(newOwnerID)
	--
	originalPlayer:SetPersonnelInCities()
	originalPlayer:SetAdministrativeSupport()
	originalPlayer:SetAdministrativeCost()
	--
	newPlayer:SetPersonnelInCities()
	newPlayer:SetAdministrativeSupport()
	newPlayer:SetAdministrativeCost()
end

GameEvents.CapturedCityInitialized.Add( OnCapturedCityInitialized )
GameEvents.NewCityCreated.Add(OnNewCityCreated)

function OnModifierChanged(playerID)
	local player = GetPlayer(playerID)
	if player then
		player:SetCached("AdministrativeCost", nil) -- force a refresh on next UI call, at this point in the code the change is not yet applied
	end
end
Events.GovernmentChanged.Add(OnModifierChanged)
Events.GovernmentPolicyChanged.Add(OnModifierChanged)

-----------------------------------------------------------------------------------------
-- Functions passed from UI Context
-----------------------------------------------------------------------------------------
function CanDeclareWarOn(self, playerID)
	return GCO.CanPlayerDeclareWarOn(self, playerID)
end

function HasOpenBordersFrom(self, playerID)
	return GCO.HasPlayerOpenBordersFrom(self, playerID)
end

function GetInfluenceMap(self)
	return GCO.GetPlayerInfluenceMap(self)
end

-----------------------------------------------------------------------------------------
-- Shared Functions
-----------------------------------------------------------------------------------------
function GetPlayer(playerID)
	local player= Players[playerID]
	if not player then
		if playerID == -1 then
			GCO.Warning("Calling GetPlayer for playerID# -1")
		else
			GCO.Error("player is nil in GetPlayer for playerID#", playerID)
		end
		return
	end
	InitializePlayerFunctions(player)
	return player
end

function GetPlayerIDFromCivilizationType(CivilizationType)
	return PlayerFromCivilizationType[CivilizationType]
end


-----------------------------------------------------------------------------------------
-- Initialize Player Functions
-----------------------------------------------------------------------------------------
function InitializePlayerFunctions(player) -- Note that those functions are limited to this file context
	if not player then player = Players[0] end
	local p = getmetatable(player).__index
	
	if p.IsInitializedForGCO == nil then
	
		p.GetKey									= GetKey
		p.GetData									= GetData
		p.GetConfig									= GetConfig
		p.GetCache									= GetCache
		p.GetCached									= GetCached
		p.SetCached									= SetCached
		p.GetValue									= GetValue
		p.SetValue									= SetValue
		p.InitializeData							= InitializeData
		p.Define									= Define
		--
		p.ProceedTransaction						= ProceedTransaction
		p.RecordTransaction							= RecordTransaction
		p.GetTransactionType						= GetTransactionType
		p.GetTransactionBalance						= GetTransactionBalance
		p.UpdateDebt								= UpdateDebt
		--
		p.IsResourceVisible							= IsResourceVisible
		p.HasPolicyActive							= HasPolicyActive
		p.GetActivePolicies							= GetActivePolicies
		p.GetCurrentGovernment						= GetCurrentGovernment
		--
		p.IsObsoleteEquipment						= IsObsoleteEquipment
		p.IsObsoleteResource						= IsObsoleteResource
		p.CanTrain									= CanTrain
		--
		p.SetMilitaryOrganizationLevel				= SetMilitaryOrganizationLevel
		p.GetMilitaryOrganizationLevel				= GetMilitaryOrganizationLevel
		p.UpdateMilitaryOrganizationLevel			= UpdateMilitaryOrganizationLevel
		p.GetConscriptOrganizationLevel				= GetConscriptOrganizationLevel
		--
		p.IsKnownTech								= IsKnownTech
		p.SetKnownTech								= SetKnownTech
		p.GetNumTechs								= GetNumTechs
		--
		p.UpdateUnitsFlags							= UpdateUnitsFlags
		p.UpdateCitiesBanners						= UpdateCitiesBanners
		--
		p.SetCurrentTurn							= SetCurrentTurn
		p.HasStartedTurn							= HasStartedTurn
		p.UpdateDataOnNewTurn						= UpdateDataOnNewTurn
		p.UpdateDataOnLoad							= UpdateDataOnLoad
		--
		--p.UpdatePopulationNeeds						= UpdatePopulationNeeds
		p.GetPopulationNeeds						= GetPopulationNeeds
		p.GetResourcesNeededForPopulations			= GetResourcesNeededForPopulations
		p.GetResourcesConsumptionRatioForPopulation = GetResourcesConsumptionRatioForPopulation
		--
		p.IsAtWar									= IsAtWar
		p.CanDeclareWarOn							= CanDeclareWarOn
		p.HasOpenBordersFrom						= HasOpenBordersFrom
		p.GetInfluenceMap							= GetInfluenceMap
		--
		p.GetTotalPopulation						= GetTotalPopulation
		p.GetTerritorySize							= GetTerritorySize
		--
		p.GetTerritoryAdministrativeCost			= GetTerritoryAdministrativeCost
		p.GetTechAdministrativeFactor				= GetTechAdministrativeFactor
		p.GetCitiesAdministrativeFactor				= GetCitiesAdministrativeFactor
		p.GetUnitsAdministrativeFactor				= GetUnitsAdministrativeFactor
		p.GetAdministrativeCost						= GetAdministrativeCost
		p.SetAdministrativeCost						= SetAdministrativeCost
		p.GetAdministrativeSupport					= GetAdministrativeSupport
		p.SetAdministrativeSupport					= SetAdministrativeSupport
		p.GetAdministrativeEfficiency				= GetAdministrativeEfficiency
		p.GetAdministrationTooltip					= GetAdministrationTooltip
		--
		p.GetModifiersForEffect						= GetModifiersForEffect
		--
		p.GetPersonnelInCities						= GetPersonnelInCities
		p.SetPersonnelInCities						= SetPersonnelInCities
		p.GetPersonnelInUnits						= GetPersonnelInUnits
		p.GetLogisticPersonnelInActiveDuty			= GetLogisticPersonnelInActiveDuty
		p.GetLogisticCost							= GetLogisticCost
		p.GetLogisticSupport						= GetLogisticSupport
		p.SetLogisticCost							= SetLogisticCost
		p.GetMaxDraftedPercentage					= GetMaxDraftedPercentage
		p.GetDraftedPercentage						= GetDraftedPercentage
		p.GetDraftEfficiencyPercent					= GetDraftEfficiencyPercent
		p.GetArmyPersonnelPopulationRatio			= GetArmyPersonnelPopulationRatio
		--
		p.IsInitializedForGCO			= true
	end
end



----------------------------------------------
-- Initialize
----------------------------------------------
function Initialize()
	-- Sharing Functions for other contexts
	if not ExposedMembers.GCO then ExposedMembers.GCO 	= {} end
	ExposedMembers.GCO.GetPlayer 						= GetPlayer
	ExposedMembers.GCO.GetPlayerIDFromCivilizationType	= GetPlayerIDFromCivilizationType
	ExposedMembers.GCO.InitializePlayerFunctions 		= InitializePlayerFunctions
	ExposedMembers.GCO.PlayerTurnsDebugChecks 			= {}
	ExposedMembers.PlayerScript_Initialized 			= true
	
	-- Register Events (order matters for same events)
	Events.ResearchCompleted.Add(OnResearchCompleted)
	Events.CivicCompleted.Add(OnCivicCompleted)	
	Events.GovernmentPolicyChanged.Add( OnPolicyChanged )
	Events.DiplomacyDeclareWar.Add(OnDiplomacyDeclareWar)
	Events.TreasuryChanged.Add(OnTreasuryChanged)
	--LuaEvents.StartPlayerTurn.Add(DoPlayerTurn)
	--LuaEvents.StartPlayerTurn.Add(CheckPlayerTurn)
	Events.LocalPlayerTurnBegin.Add( DoTurnForLocal )
	Events.RemotePlayerTurnBegin.Add( DoTurnForRemote )
	Events.RemotePlayerTurnEnd.Add( DoTurnForNextPlayerFromRemote )
	Events.LocalPlayerTurnEnd.Add( DoTurnForNextPlayerFromLocal )
end
Initialize()