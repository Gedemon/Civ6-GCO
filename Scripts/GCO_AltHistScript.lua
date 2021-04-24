--=====================================================================================--
--	FILE:	 GCO_AltHistScript.lua
--  Gedemon (2021)
--=====================================================================================--

print ("Loading GCO_AltHistScript.lua...")

-- ===================================================================================== --
-- Includes
-- ===================================================================================== --
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


-- ===================================================================================== --
-- Defines
-- ===================================================================================== --

local DEBUG_ALTHIST_SCRIPT 	= "AltHistScript"

local _cached			= {}	-- cached table to reduce calculations

local iBarbarianPlayer	= 63 -- GameDefines.MAX_PLAYERS - 1 <- would that be better ?


local fOrganizedTribeFactor		= tonumber(GameInfo.GlobalParameters["TRIBES_ORGANIZED_CIVILIZATION_FACTOR"].Value) 		-- 1.5
local fBarbariansTribeFactor	= tonumber(GameInfo.GlobalParameters["TRIBES_BARBARIANS_CIVILIZATION_FACTOR"].Value)		-- 1.75
local iMaxSettlementDistance	= tonumber(GameInfo.GlobalParameters["TRIBES_MAX_SETTLEMENT_DISTANCE_MAJOR"].Value)			-- 4
local iMaxBarbSettlementDist	= tonumber(GameInfo.GlobalParameters["TRIBES_MAX_SETTLEMENT_DISTANCE_BARBARIAN"].Value)		-- 6
local iPopRatioForVillage		= tonumber(GameInfo.GlobalParameters["TRIBES_POPULATION_FOR_VILLAGE_PERCENT"].Value)*0.01 	-- 8.5*0.01 = 0.085
local iBarbarianCollectRatio	= tonumber(GameInfo.GlobalParameters["TRIBES_BARBARIAN_COLLECT_RATIO"].Value) 				-- 0.25--
local iMajorCollectRatio		= tonumber(GameInfo.GlobalParameters["TRIBES_MAJOR_COLLECT_RATIO"].Value) 					-- 0.35--
local iMinPopulationLeft		= tonumber(GameInfo.GlobalParameters["TRIBES_MINIMAL_POPULATION_LEFT"].Value) 				-- 100
local iGoldPerLuxury			= tonumber(GameInfo.GlobalParameters["TRIBES_GOLD_PER_LUXURY_RESOURCE"].Value) 				-- 5 
local iMaxLuxuriesPerTurn		= tonumber(GameInfo.GlobalParameters["TRIBES_MAX_LUXURY_PER_TURN"].Value) 					-- 2 
local iPopConvertionRate		= tonumber(GameInfo.GlobalParameters["TRIBES_POPULATION_CONVERTION_RATE"].Value) 			-- 0.2
local iSlaveConvertionRate		= tonumber(GameInfo.GlobalParameters["TRIBES_SLAVE_CONVERTION_RATE"].Value) 				-- 0.4
local iAssimilationFactor		= tonumber(GameInfo.GlobalParameters["TRIBES_ASSIMILATION_CONVERTION_FACTOR"].Value) 		-- 3
local iNormalMaxConvertion		= tonumber(GameInfo.GlobalParameters["TRIBES_NORMAL_MAX_CONVERTION"].Value) 				-- 100
local iAssimilationConvertion	= tonumber(GameInfo.GlobalParameters["TRIBES_ASSIMILATION_MAX_CONVERTION"].Value) 			-- 300
local iPopConvertionPerLuxury	= tonumber(GameInfo.GlobalParameters["TRIBES_POP_CONVERTION_RATE_PER_LUX"].Value) 			-- 0.02
local iMinCulturePercentCity	= tonumber(GameInfo.GlobalParameters["TRIBES_MINIMAL_CULTURE_PERCENT_CITY"].Value)			-- 75
local iMinCulturePercentSettler	= tonumber(GameInfo.GlobalParameters["TRIBES_MINIMAL_CULTURE_PERCENT_SETTLER"].Value)		-- 45
local iForcedMigrationRate		= tonumber(GameInfo.GlobalParameters["TRIBES_FORCED_MIGRATION_RATE"].Value)					-- 0.05
local iStartingMigrationRate	= tonumber(GameInfo.GlobalParameters["TRIBES_STARTING_MIGRATION_POP_RATE"].Value)			-- 0.75
local iMinMaterielStock			= tonumber(GameInfo.GlobalParameters["TRIBES_MIN_MATERIEL_STOCK_RESERVE"].Value)			-- 30 -- overriden when specializing in equipment
local iMaxRouteDistance			= iMaxSettlementDistance + 2

local iNumSlavesForWorker		= nil 	-- defined in PostInitialize from unitEquipmentClasses[unitType][equipmentClassID]
local iPopulationForCaravan		= nil	--
local iPopulationForSettler		= nil	--

local TribeFoodConsumption 		= tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PERSONNEL_FACTOR"].Value)
local SlaveClassFoodConsumption = tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_SLAVE_CLASS_FACTOR"].Value)

local militaryOrganization		= militaryOrganization -- localize Global from GCO_TypeEnum.lua
local TribeOrganizationLevel	= GameInfo.MilitaryOrganisationLevels["LEVEL0"].Index

local UnitCreationType		= { -- to do : get base unit from Units table based on lower Cost for PromotionClass ?
	["CREATE_MELEE"] 		={ BaseUnitType = "UNIT_WARRIOR", 		PromotionClass = "PROMOTION_CLASS_MELEE"},
	["CREATE_RANGED"] 		={ BaseUnitType = "UNIT_SLINGER", 		PromotionClass = "PROMOTION_CLASS_RANGED"},
	["CREATE_SKIRMISHER"] 	={ BaseUnitType = "UNIT_SLINGER_SCOUT", PromotionClass = "PROMOTION_CLASS_SKIRMISHER"},

}

local foodResourceID 			= GameInfo.Resources["RESOURCE_FOOD"].Index
local materielResourceID		= GameInfo.Resources["RESOURCE_MATERIEL"].Index
local personnelResourceID		= GameInfo.Resources["RESOURCE_PERSONNEL"].Index
local slaveClassID 				= GameInfo.Resources["POPULATION_SLAVE"].Index


local yieldFood 				= GameInfo.Yields["YIELD_FOOD"].Index

local TribeImprovements	= {
	["IMPROVEMENT_GOODY_HUT"]           = true,
	["IMPROVEMENT_BARBARIAN_CAMP"]      = true,
	["IMPROVEMENT_GOODY_HUT_GCO"]       = true,
	["IMPROVEMENT_GOODY_HUT_HUNT"]      = true,
	["IMPROVEMENT_GOODY_HUT_FARM"]      = true,
	["IMPROVEMENT_BARBARIAN_CAMP_GCO"]	= true,
}

local kMajorContinents 			= {}
local kMajorStartPositions 		= {} 	-- [sCivType] = pStartPlot

local kCultureGroupPlots		= {} 	-- [GroupType] = {[plot1] = true, [plot2] = true, ...} -- List of possible plots for a culture group spawn, favorite method
local kCultureGroupContinent	= {}	-- ContinentID of the main major Civilization (backup placement)
local kCultureGroupEthnicity	= {}	-- List all culture groups that don't have a Continent or Plot list (last backup placement option)

local kTribePlayersPerEthnicity	= {}	-- [ethnicity] = {player1, player2, ...}


-- ===================================================================================== --
-- Initialize Functions
-- ===================================================================================== --

local GCO 	= {}
local pairs = pairs
local Dprint, Dline, Dlog, Div, LuaEvents
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO		-- contains functions from other contexts 
	LuaEvents	= GCO.LuaEvents
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	Div			= GCO.Divide
	pairs 		= GCO.OrderedPairs
	GameEvents.InitializeGCO.Remove( InitializeUtilityFunctions )
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.GCO.AltHistData = GCO.LoadTableFromSlot("AltHistData") or {}
	
	InitializeCultureGroupsMap()
	InitializeTribePlayers()
		
	LuaEvents.DoTribesTurn.Add( TribesTurn ) -- after InitializeUtilityFunctions to get LuaEvents
	LuaEvents.UnitMovementPathComplete.Add( OnUnitPathComplete )
	Events.UnitTeleported.Add( OnUnitTeleported ) -- also called when moving on a tile after defeating an enemy unit
	Events.TurnBegin.Add(OnNewTurn)	-- after Plots Do Turn 
	Events.ImprovementAddedToMap.Add(OnImprovementOwnerChanged) -- after loading data
	
	-- Initialize Worker's Slave required value
	local kWorkerEquipments = GCO.GetUnitEquipmentClasses(GameInfo.Units["UNIT_WORKER"].Index)
	local EquipmentClassID	= GameInfo.EquipmentClasses["EQUIPMENTCLASS_SLAVE"].Index
	iNumSlavesForWorker 	= kWorkerEquipments[EquipmentClassID].Quantity
	
	local kCaravanEquipment = GCO.GetUnitEquipmentClasses(GameInfo.Units["UNIT_CARAVAN"].Index)
	local EquipmentClassID	= GameInfo.EquipmentClasses["EQUIPMENTCLASS_CIVILIAN"].Index
	iPopulationForCaravan 	= kCaravanEquipment[EquipmentClassID].Quantity
	
	local kSettlerEquipment = GCO.GetUnitEquipmentClasses(GameInfo.Units["UNIT_SETTLER"].Index)
	local EquipmentClassID	= GameInfo.EquipmentClasses["EQUIPMENTCLASS_CIVILIAN"].Index
	iPopulationForSettler	= kSettlerEquipment[EquipmentClassID].Quantity
end

function OnLoadGameViewStateDone()
	InitializeTribesOnMap() -- must wait for all script files to be fully initialized, which isn't the case in PostInitialize
	
	-- Do a first turn for major civs to initiate Village data
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		TribesTurn( playerID )
	end
end
Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone ) -- Ready to start game

function SaveTables()
	Dprint("--------------------------- Saving AltHistData ---------------------------")

	GCO.StartTimer("Saving And Checking AltHistData")
	GCO.SaveTableToSlot(ExposedMembers.GCO.AltHistData, "AltHistData")
end
GameEvents.SaveTables.Add(SaveTables)


-- ===================================================================================== --
-- Generic Functions
-- ===================================================================================== --

function GetCached(key)
	return _cached[key]
end

function SetCached(key, value)
	_cached[key] = value
end

function GetValue(key)
	local Data = ExposedMembers.GCO.AltHistData
	if not Data then
		GCO.Warning("AltHistData is nil")
		return nil
	end
	return Data[key]
end

function SetValue(key, value)
	local Data = ExposedMembers.GCO.AltHistData
	if not Data then
		GCO.Error("AltHistData is nil[NEWLINE]Trying to set ".. tostring(key) .." value to " ..tostring(value))
	end
	Data[key] = value
end


-- ===================================================================================== --
-- Culture Groups
-- ===================================================================================== --

function InitializeCultureGroupsMap()

	--local DEBUG_ALTHIST_SCRIPT = "debug"
	
	Dprint( DEBUG_ALTHIST_SCRIPT, "- Initialize Culture Groups Map...")

	local iDefaultDistance = 10

	-- Get Major Start Positions
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
	
		local pPlayer 		= Players[playerID]
		local pStartPlot	= pPlayer:GetStartingPlot()
		if pStartPlot then
			local pPlayerConfig = PlayerConfigurations[playerID]
			local sCivType		= pPlayerConfig:GetCivilizationTypeName()
			local iContinent 	= pStartPlot:GetContinentType()
			
			kMajorContinents[sCivType] 		= iContinent
			kMajorStartPositions[sCivType] 	= pStartPlot
		end
	end
	
	for row in GameInfo.CultureGroups() do
	
		local sCultureType = row.CultureType
	
		if row.MajorCivilizations then
			local iX, iY		= 0, 0
			local iNumCiv 		= 0
			local tCivPlots		= {}
			local iMaxDistance	= 0
			local kGroupPlots	= nil
			for _, sCivType in ipairs(Split(row.MajorCivilizations, ",")) do
				local pStartPlot = kMajorStartPositions[sCivType]
				if pStartPlot then
					table.insert(tCivPlots, pStartPlot)					
				end
			end
			if #tCivPlots > 0 then
				if #tCivPlots > 1 then 
					-- if there is more than one civ, then the max distance in the max separation between civs
					for _, pStartPlot1 in ipairs(tCivPlots) do
						for _, pStartPlot2 in ipairs(tCivPlots) do
							if pStartPlot1 ~= pStartPlot2 then
								local iDistance = Map.GetPlotDistance(pStartPlot1:GetIndex(), pStartPlot2:GetIndex())
								if iDistance > iMaxDistance then
									iMaxDistance = iDistance
								end
							end
						end
					end
					
					-- Get only common plots
					local iRange = iMaxDistance * 0.85
					for i, pStartPlot in ipairs(tCivPlots) do
					
						local kPlots = {}
						for j, iPlotID in ipairs(GCO.GetPlotsInRange(pStartPlot, iRange)) do
							kPlots[iPlotID] = true
						end
						
						local kGroupPlotsCopy = {}
						if kGroupPlots then	-- Filter plots
							for iPlotID, _ in pairs(kGroupPlots) do
								kGroupPlotsCopy[iPlotID] = kPlots[iPlotID] -- true if common, nil if only in kGroupPlots
							end
							kGroupPlots = kGroupPlotsCopy
						else 				-- or Initialize 
							kGroupPlots = kPlots
						end
					end
					
				else
					-- just get the plots in range
					kGroupPlots = {}
					for j, iPlotID in ipairs(GCO.GetPlotsInRange(tCivPlots[1], iDefaultDistance)) do
						kGroupPlots[iPlotID] = true
					end					
				end
				
				if kGroupPlots then
					-- Set that group's available plots
					Dprint( DEBUG_ALTHIST_SCRIPT, "- Adding "..Indentation(Locale.Lookup(row.Name),15).." to kCultureGroupPlots table")
					
					kCultureGroupPlots[sCultureType] = kGroupPlots
				end
				--else
					-- Set the CultureGroup continent based on the primary Civ for backup placement
					Dprint( DEBUG_ALTHIST_SCRIPT, "- Adding "..Indentation(Locale.Lookup(row.Name),15).." to kCultureGroupContinent table (backup 1)")
					kCultureGroupContinent[sCultureType] = tCivPlots[1]:GetContinentType()
				--end
			end
			--if not (kCultureGroupPlots[sCultureType] or kCultureGroupContinent[sCultureType]) then
				-- place that group in the 2nd backup list (by Ethnicity)
				Dprint( DEBUG_ALTHIST_SCRIPT, "- Adding "..Indentation(Locale.Lookup(row.Name),15).." to kCultureGroupEthnicity table (backup 2)")
				kCultureGroupEthnicity[sCultureType] = row.Ethnicity
			--end
		end	
	end
end

function IsCultureGroupAvailableForPlot(sCultureType, pPlot)
	return kCultureGroupPlots[sCultureType] and kCultureGroupPlots[sCultureType][pPlot:GetIndex()]
end

function IsCultureGroupAvailableForContinent(sCultureType, iContinent)
	return kCultureGroupContinent[sCultureType] == iContinent
end

function IsCultureGroupAvailableForEthnicity(sCultureType, sEthnicity)
	return kCultureGroupEthnicity[sCultureType] == sEthnicity
end

function HasCultureGroupSpawned(cultureID)

	local cultureKey 		= tostring(cultureID)
	local kSpawnedCulture 	= GetValue("SpawnedCulture") or {}
	return kSpawnedCulture[cultureKey]
	
end

function SetCultureGroupSpawned(cultureID)
	local cultureKey 			= tostring(cultureID)
	local kSpawnedCulture 		= GetValue("SpawnedCulture") or {}
	kSpawnedCulture[cultureKey] = true
	SetValue("SpawnedCulture", kSpawnedCulture)
end

function IsTribeImprovement(improvementType)
	local row = GameInfo.Improvements[improvementType]
	return row and TribeImprovements[row.ImprovementType]
end


-- ===================================================================================== --
-- Tribes
-- ===================================================================================== --


function GetTribalVillageAt(plotID) -- return table: [plotKey] = { Owner = playerID, Type = improvementType, IsCentral = bool, CentralPlot = iPlotId, ProductionPlot = iPlotId, ProductionType = productionType, TurnsLeft = iTurns, State = sState, Counter = iNum  } -- State = disbanding after pillaging unless repaired, with counter going up 
	local plotKey	= tostring(plotID)
	local kVillages = GetAllTribalVillages()
	return kVillages[plotKey]
end

function SetTribalVillageAt(plotID) -- initialize or override the Tribal village entry at plotID
	local plotKey		= tostring(plotID)
	local kVillages 	= GetAllTribalVillages()
	kVillages[plotKey] 	= {}
	return kVillages[plotKey]
end

function RemoveTribalVillageAt(plotID) -- 
	local plotKey		= tostring(plotID)
	local kVillages 	= GetAllTribalVillages()
	local village		= kVillages[plotKey]
	if village and village.IsCentral then
		for _, otherPlotID in ipairs(GetSatelliteVillages(plotID)) do
			local otherVillage	= GetTribalVillageAt(otherPlotID)
			otherVillage.CentralPlot = nil
		end
	end
	
	kVillages[plotKey] 	= nil
end

function GetAllTribalVillages()
	local kVillages = GetValue("TribalVillages")
	if kVillages == nil then -- initialize
		kVillages = {}
		SetValue("TribalVillages", kVillages)
	end
	return kVillages
end

function GetPlayerTribalVillages(playerID)
	local kVillages = GetAllTribalVillages()
	local tList		= {}
	for plotKey, village in pairs(kVillages) do
	
		local pPlot = Map.GetPlotByIndex(tonumber(plotKey))
		if village.Owner ~= pPlot:GetImprovementOwner() then
			GCO.Error("Improvement Owner is not the Village Owner at ", pPlot:GetX(), pPlot:GetY(), ", improvement owner = ", pPlot:GetImprovementOwner(), ", village owner = ", village.Owner, ", improvement type ID = ", pPlot:GetImprovementType())
		end
	
		if village.Owner == playerID then
			table.insert(tList, plotKey)
		end
	end
	return tList
end

function GetSatelliteVillages(centralPlotID)
	local tSatellites	= {}
	local kVillages 	= GetAllTribalVillages()
	for plotKey, village in pairs(kVillages) do
		if village.CentralPlot == centralPlotID then
			table.insert(tSatellites, tonumber(plotKey))
		end
	end
	return tSatellites
end

function InitializeTribePlayers()
	--
	for i, iPlayer in ipairs(PlayerManager.GetAliveBarbarianIDs()) do
		if iPlayer ~= iBarbarianPlayer then
			print("GetAliveBarbarianIDs #",iPlayer)
			local CivType	= PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
			local ethnicity	= GameInfo.Civilizations[CivType].Ethnicity
			if not kTribePlayersPerEthnicity[ethnicity] then kTribePlayersPerEthnicity[ethnicity] = {} end
			table.insert(kTribePlayersPerEthnicity[ethnicity], iPlayer)
		end
	end
end

function SetTribePlayerCultureGroup(playerID, cultureID, bRemove)
	local cultureKey 				= tostring(cultureID)
	local playerKey 				= tostring(playerID)
	local kCultureTribePlayer		= GetValue("CultureTribePlayer") or {}
	local kTribePlayerCulture		= GetValue("TribePlayerCulture") or {}
	kCultureTribePlayer[cultureKey] = bRemove and nil or playerID
	kTribePlayerCulture[playerKey] 	= bRemove and nil or cultureID
	SetValue("CultureTribePlayer", kCultureTribePlayer)
	SetValue("TribePlayerCulture", kTribePlayerCulture)
end

function GetTribePlayerCulture(playerID)
	local playerKey 			= tostring(playerID)
	local kTribePlayerCulture 	= GetValue("TribePlayerCulture") or {}
	return kTribePlayerCulture[playerKey]
end

function GetCultureTribePlayer(cultureID)
	local cultureKey 			= tostring(cultureID)
	local kCultureTribePlayer 	= GetValue("CultureTribePlayer") or {}
	return kCultureTribePlayer[cultureKey]
end

function GetAvailableTribePlayerFor(cultureID)
	local ethnicity 	= GameInfo.CultureGroups[cultureID].Ethnicity
	local tListPlayer	= kTribePlayersPerEthnicity[ethnicity]
	if tListPlayer then
		for _, playerID in ipairs(tListPlayer) do
			if GetTribePlayerCulture(playerID) == nil then
				return playerID
			end
		end
	end
end

function InitializeTribePlayer(playerID, cultureID)

	local DEBUG_ALTHIST_SCRIPT = "debug"
	
	Dprint( DEBUG_ALTHIST_SCRIPT, "- Initializing Tribe Player : ", playerID, cultureID)

	SetTribePlayerCultureGroup(playerID, cultureID)

	local kColorInUse		= GetValue("ColorInUse") or {}
	local PrimaryColor		= "COLOR_BLACK"
	local SecondaryColor	= "COLOR_WHITE"
	local pPlayerConfig		= GCO.GetPlayerConfig(playerID)
	local pPlayer			= GCO.GetPlayer(playerID)
	
	pPlayer:Define() -- register CultureGroup for this player

	local tPossibleColors	= {}
	for row in GameInfo.ColorsLegacy() do
		if not kColorInUse[row.Type] then
			local tColor = Split(row.Color, ",")
			local r = tColor[1]
			local g = tColor[2]
			local b = tColor[3]
			local luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
			if luma >= 80 then
				table.insert(tPossibleColors, row.Type)
			end
		end
	end
	
	if #tPossibleColors > 0 then
		SecondaryColor = tPossibleColors[TerrainBuilder.GetRandomNumber(#tPossibleColors, "Random Tribe Color")+1]
		Dprint( DEBUG_ALTHIST_SCRIPT, "- Selected Color from pool : ", SecondaryColor, #tPossibleColors)
	end
	
	kColorInUse[SecondaryColor] = true
	pPlayerConfig:SetValue("PrimaryColor", PrimaryColor)
	pPlayerConfig:SetValue("SecondaryColor", SecondaryColor)
	
	SetValue("ColorInUse", kColorInUse)
	
	-- Initialize Gold at 250
	local pTreasury = pPlayer:GetTreasury()
	pTreasury:ChangeGoldBalance(250-pTreasury:GetGoldBalance()) -- to do: remove magic number
	
end

function ResetTribePlayer(playerID, cultureID)

	local bRemove = true
	SetTribePlayerCultureGroup(playerID, cultureID, bRemove)

	local kColorInUse			= GetValue("ColorInUse") or {}
	local pPlayerConfig			= GCO.GetPlayerConfig(playerID)
	local SecondaryColor			= pPlayerConfig:GetValue("SecondaryColor")
	kColorInUse[SecondaryColor]	= nil
	pPlayerConfig:SetValue("PrimaryColor", nil)
	pPlayerConfig:SetValue("SecondaryColor", nil)
	SetValue("ColorInUse", kColorInUse)
end

function TransferWithLinkedUnits(village)

	local DEBUG_ALTHIST_SCRIPT = "debug"
	
	local pPlot				= GCO.GetPlotByIndex(village.Plot)
	local plotKey			= tostring(pPlot:GetIndex())
	local LinkedUnits 		= {}
	local UnitsSupplyDemand = { Resources = {}, NeedResources = {}, PotentialResources = {}} -- NeedResources : Number of units requesting a resource type
	local Reinforcements 	= {Resources = {}, ResPerUnit = {}}	

	Dprint( DEBUG_ALTHIST_SCRIPT, "Transfer With Linked Units for ".. Locale.Lookup(GameInfo.Improvements[village.Type].Name).." at ", pPlot:GetX(), pPlot:GetY())
	
	-- Get all resources needed by linked units
	for unitKey, data in pairs(ExposedMembers.UnitData) do
		local efficiency = data.SupplyLineEfficiency
		if tostring(data.SupplyLineCityKey) == plotKey and efficiency > 0 then
			local unit = GCO.GetUnit(data.playerID, data.unitID)
			if unit and unit:GetOwner() == village.Owner then
				LinkedUnits[unitKey] = {NeedResources = {}}
				if unit:CanGetReinforcement() then
					local requirements 	= unit:GetRequirements()
					for resourceID, value in pairs(requirements.Resources) do
						if value > 0 then
							UnitsSupplyDemand.Resources[resourceID] 		= ( UnitsSupplyDemand.Resources[resourceID] 		or 0 ) + GCO.Round(value*efficiency/100)
							UnitsSupplyDemand.NeedResources[resourceID]		= ( UnitsSupplyDemand.NeedResources[resourceID] 	or 0 ) + 1
							LinkedUnits[unitKey].NeedResources[resourceID]	= true
						end
					end
				else -- Food is always a requirement
					local foodRequired = unit:GetNumResourceNeeded(foodResourceID)
					if foodRequired > 0 then
						UnitsSupplyDemand.Resources[foodResourceID] 		= ( UnitsSupplyDemand.Resources[foodResourceID] 	or 0 ) + GCO.Round(foodRequired*efficiency/100)
						UnitsSupplyDemand.NeedResources[foodResourceID]		= ( UnitsSupplyDemand.NeedResources[foodResourceID] or 0 ) + 1
						LinkedUnits[unitKey].NeedResources[foodResourceID]	= true
					end
				end
			end
		end
	end
	
	for resourceID, value in pairs(UnitsSupplyDemand.Resources) do
		Reinforcements.Resources[resourceID] 	= math.min(value, pPlot:GetStock(resourceID))
		Reinforcements.ResPerUnit[resourceID] 	= math.floor(Div(Reinforcements.Resources[resourceID],UnitsSupplyDemand.NeedResources[resourceID]))
		Dprint( DEBUG_ALTHIST_SCRIPT, "- Max transferable ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)).. " = ".. tostring(value), " for " .. tostring(UnitsSupplyDemand.NeedResources[resourceID]), " units, available = " .. tostring(pPlot:GetStock(resourceID)), ", send = ".. tostring(Reinforcements.Resources[resourceID]))
	end
	
	-- Share available resources to linked units
	local reqValue = {}
	for resourceID, value in pairs(Reinforcements.Resources) do
		local resLeft = value
		local maxLoop = 5
		local loop = 0
		while (resLeft > 0 and loop < maxLoop) do
			for unitKey, data in pairs(LinkedUnits) do
				local unit 			= GCO.GetUnitFromKey ( unitKey )
				if unit and (unit:CanGetReinforcement() or resourceID == foodResourceID) then -- we need to check again here, as we're iterating the full required resources table not a specific unit requirement
					if not reqValue[unit] then reqValue[unit] = {} end
					
					local efficiency = unit:GetSupplyLineEfficiency()
					
					if not reqValue[unit][resourceID] then reqValue[unit][resourceID] = math.floor(unit:GetNumResourceNeeded(resourceID)*efficiency/100) end
					if reqValue[unit][resourceID] > 0 then
					
						local send = math.min(Reinforcements.ResPerUnit[resourceID], reqValue[unit][resourceID], resLeft)

						resLeft = resLeft - send
						reqValue[unit][resourceID] = reqValue[unit][resourceID] - send

						unit:ChangeStock(resourceID, send)
						pPlot:ChangeStock(resourceID, -send)						
						
						Dprint( DEBUG_ALTHIST_SCRIPT, "  - send ".. tostring(send)," ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)) .." (@ ".. tostring(efficiency), " percent efficiency) to unit key#".. tostring(unit:GetKey()), Locale.Lookup(UnitManager.GetTypeName(unit)))
					end
				end
			end
			loop = loop + 1
		end
	end
	
	-- get excedental resources from units
	for unitKey, _ in pairs(LinkedUnits) do
		local unit = GCO.GetUnitFromKey ( unitKey )
		if unit then

			local unitExcedent 	= unit:GetAllSurplus()
			local unitData 		= ExposedMembers.UnitData[unitKey]
			if unitData then
				-- Send excedent back to city
				for resourceID, value in pairs(unitExcedent) do
					-- Special cases:
					-- 		+ we don't allow units to keep equipment surplus
					-- 		+ personnel is directly converted to population
					local maxStock		= pPlot:GetMaxStock(resourceID)
					local bIgnoreLimit	=  (resourceID == personnelResourceID) or GCO.IsResourceEquipment(resourceID)
					local toTransfert 	= bIgnoreLimit and value or math.min(maxStock - pPlot:GetStock(resourceID), value)

					if toTransfert > 0 then
						if resourceID == personnelResourceID then
							unit:GivePersonnelToPlot( pPlot, toTransfert)
						else
							unit:ChangeStock(resourceID, -toTransfert)
							pPlot:ChangeStock(resourceID, toTransfert)
						end
						
						Dprint( DEBUG_ALTHIST_SCRIPT, "  - received " .. tostring(toTransfert) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." from ".. Locale.Lookup(unit:GetName()) .." that had an excedent of ".. tostring(value))
					end
				end

				-- Send prisoners to improvement as slaves
				for playerKey, number in pairs(unitData.Prisoners) do
					if number > 0 then
						Dprint( DEBUG_ALTHIST_SCRIPT, "   - "..Indentation20(Locale.Lookup( PlayerConfigurations[tonumber(playerKey)]:GetPlayerName() ) .. " Prisoners to Slave ").." = ", number)
						pPlot:ChangeStock(slaveClassID, number)
					end
				end
			end
		end
	end
end

function GetTribeOutputFactor(pPlot)
	return GCO.GetRealSizeAtPopulation(pPlot:GetPopulation() + (pPlot:GetStock(slaveClassID)*1.5)) -- to do : remove magic number (slave prod. factor)
end


function GetPopulationMigrationPerTurnForVillage(pPlot, row)

	local population	= pPlot:GetPopulation()
	local required		= row.PopulationCost
	local buildTurns	= row.BaseTurns
	local popPerTurn	= math.floor(Div(required, buildTurns))
	local settlers		= math.min(population*0.5,math.max(population*iPopRatioForVillage, popPerTurn)) 
	return settlers
end

function OnNewTurn()
	TribesTurn( NO_PLAYER )
end

function TribesTurn( playerID )
	GCO.Monitor(TribesTurnP, {playerID}, "Tribes Turn Player#".. tostring(playerID))
end

function TribesTurnP( playerID )
	local DEBUG_ALTHIST_SCRIPT = playerID == 0 and "debug" or DEBUG_ALTHIST_SCRIPT
	
	Dprint( DEBUG_ALTHIST_SCRIPT, "- Do Tribal Village turn for Player#", playerID)
	
	local tVillages 		= GetPlayerTribalVillages(playerID)
	local resVisPlayerID	= playerID ~= NO_PLAYER and playerID or iBarbarianPlayer	-- to check resource visibility for unowned improvements
	local pPlayer			= playerID ~= NO_PLAYER and GCO.GetPlayer(playerID) or nil	-- need to keep pPlayer nil for future check
	local iDecayRate		= pPlayer and pPlayer:IsMajor() and 0.05 or 0.15			-- todo : remove magic numbers
	for _, plotKey in ipairs(tVillages) do
		local plotID 				= tonumber(plotKey)
		local pPlot					= GCO.GetPlotByIndex(plotID)
		local village				= GetTribalVillageAt(plotID)
		local bPillaged				= pPlot:IsPlotImprovementPillaged()
		village.Production			= {} -- reset production values
		village.MaterielProduced	= 0
		village.FoodProduced		= 0
		village.Pull				= {}
		village.Push				= {}
		
		Dprint( DEBUG_ALTHIST_SCRIPT, "  - Manage Village at ", pPlot:GetX(), pPlot:GetY(), GameInfo.Improvements[village.Type].ImprovementType)
		
		if village.PillagedCounter then
			Dprint( DEBUG_ALTHIST_SCRIPT, "   - Handling Pillaged Village, turns counter = ", village.PillagedCounter)
			-- to do : handle adjacent (hostile or not) units first
			--
			
			--
			village.PillagedCounter = village.PillagedCounter + 1
			-- remove or rest
			if village.PillagedCounter == 10 then -- to do: remove magic number
				-- to do: handle is being repaired
				if not (village.ProductionType == "VILLAGE_REBUILD" or village.ProductionType == "CENTER_CAPTURE") then
					village.PillagedCounter = nil
					local cultureID = pPlot:GetHighestCultureID()
					local ownerID	= GetCultureTribePlayer(cultureID)
					local pOwner	= ownerID and GCO.GetPlayer(ownerID) or nil
					
					-- Remove
					village.Owner = -1
					ImprovementBuilder.SetImprovementType(pPlot, -1)
					
					-- Restore
					if pOwner == nil and pPlot:GetPopulation() >= 1000 then -- to do: remove magic number
					
						local bCanRestore = true
						
						local aUnits = Units.GetUnitsInPlot(otherPlot);
						for i, pUnit in ipairs(aUnits) do
							if pUnit:GetOwner() ~= iBarbarianPlayer then
								bCanRestore = false
							end
						end
					
						if bCanRestore then
							-- Remove links
							if village.IsCentral then
								for _, otherPlotID in ipairs (GetSatelliteVillages(plotID)) do
									Dprint( DEBUG_ALTHIST_SCRIPT, "    - Removing link from Satellite village at plot #", otherPlotID)
									local otherVillage			= GetTribalVillageAt(otherPlotID)
									otherVillage.CentralPlot 	= nil
								end
							
							-- Find new central village <- to do : in ChangeImprovementOwner instead ?
							else
								local bIgnorePillaged	= true
								local newPlotID, dist	= GCO.FindNearestPlayerVillage( iBarbarianPlayer, pPlot:GetX(), pPlot:GetY(), bIgnorePillaged )
								village.CentralPlot		= dist <= iMaxBarbSettlementDist and newPlotID or nil
							end
							
							-- duplicate with ChangeImprovementOwner event ?
							village.ProductionType	= "PRODUCTION_EQUIPMENT"
							village.TurnsLeft		= nil
							village.Owner			= iBarbarianPlayer
							local iType 			= GameInfo.Improvements[village.Type].Index
							
							ImprovementBuilder.SetImprovementType(pPlot, iType, iBarbarianPlayer)
							
							local sUnitType = "UNIT_LIGHT_SPEARMAN" -- to do : GetGarrisonFor function
							Dprint( DEBUG_ALTHIST_SCRIPT, "    - Adding Garrison Unit on restored Village: ", sUnitType)
							local pUnit = UnitManager.InitUnit(iBarbarianPlayer, sUnitType, pPlot:GetX(), pPlot:GetY())
							if pUnit then
								local pUnitAbility 	= pUnit:GetAbility(); 
								local bResult 		= pUnitAbility:ChangeAbilityCount("ABILITY_NO_MOVEMENT", 1)
							end
						end
					
					-- Delete (original owner had enough time to recapture it, and can recreate it)
					else
						RemoveTribalVillageAt(plotID) 
						village = nil
					end
				end
			end
		else
		
			-- try to assign a central plot reference if missing
			if (not village.IsCentral) and village.CentralPlot == nil then
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - External village without CentralPlot, try to find a central village...")
				local newPlotID, dist	= GCO.FindNearestPlayerVillage( village.Owner, pPlot:GetX(), pPlot:GetY() )
				village.CentralPlot		= dist <= iMaxBarbSettlementDist and newPlotID or nil
			end
		
		end
		
		if village and ((not bPillaged) or (village.ProductionType == "VILLAGE_REBUILD") or (village.ProductionType == "CENTER_CAPTURE")) then -- village can be nil here if it has been removed while handling the pillaging counter
		
			-- Get variables
			local gameEra			= GCO.GetGameEra()
			local sEraType			= GameInfo.Eras[gameEra].EraType
			local bIsBarbarian		= pPlayer == nil and true or pPlayer:IsBarbarian() -- no player means "barbarian"
			local sImprovementType	= GameInfo.Improvements[village.Type].ImprovementType
			local sProductionType	= village.ProductionType or (bIsBarbarian and "PRODUCTION_EQUIPMENT") or "PRODUCTION_MATERIEL"
			local prodRow			= GameInfo.TribalVillageProductions[sProductionType]
			local kResourcesUsed	= {}
			local kProductions		= {}
			local fCollectRatio		= bIsBarbarian and iBarbarianCollectRatio or iMajorCollectRatio
			
			Dprint( DEBUG_ALTHIST_SCRIPT, "   - Era, IsBarbarian, ProductionType = ", sEraType, bIsBarbarian, sProductionType )
		
			if (not bPillaged) then
				-- Applay decay
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Apply decay rate ", iDecayRate)
				for resourceKey, value in pairs(pPlot:GetResources()) do
					local resourceID	= tonumber(resourceKey)
					local iDecay		= math.floor(pPlot:GetStock(resourceID)*iDecayRate)
					if iDecay > 0 then
						pPlot:ChangeStock(resourceID, -iDecay)
						Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), -iDecay)
					end
				end
				
				-- Gather resources
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Gather Resources...")
				local resourceValues = pPlot:GetBaseVisibleResources(resVisPlayerID)
				for __, adjacentPlotID in ipairs(GCO.GetAdjacentPlots(pPlot)) do
					local adjacentPlot = GCO.GetPlotByIndex(adjacentPlotID)
					if adjacentPlot then
						for resourceID, value in pairs(adjacentPlot:GetBaseVisibleResources(resVisPlayerID)) do
							resourceValues[resourceID] = (resourceValues[resourceID] or 0) + value
							Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), value)
						end
					end
				end
				-- Stock Resources
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Stock Gathered Resources...")
				for resourceID, value in pairs(resourceValues) do
					local iCurrentStock = pPlot:GetStock(resourceID)
					local iMaxAdded		= math.max(0, pPlot:GetMaxStock(resourceID) - iCurrentStock) -- in case there is an overstock don't allow negative value here
					local iAdded		= math.min(iMaxAdded, math.max(1,math.floor(value*fCollectRatio)))
					if iAdded > 0 then
						pPlot:ChangeStock(resourceID, iAdded)
						Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), iAdded)
					end
				end
			end
			
			-- Do Village production, turn based
			Dprint( DEBUG_ALTHIST_SCRIPT, "   - Check Turn Based production...") -- resources (equipment, materiel, ...) / special (gold, ...)
			if prodRow.BaseTurns then
				if village.TurnsLeft then
					Dprint( DEBUG_ALTHIST_SCRIPT, "   - Do Turn Based production, turns left = ", village.TurnsLeft) -- resources (equipment, materiel, ...) / special (gold, ...)
					village.TurnsLeft = village.TurnsLeft - 1
					
					if sProductionType == "VILLAGE_CREATE" then
						Dprint( DEBUG_ALTHIST_SCRIPT, "   - Creating Village, turn left = ", village.TurnsLeft)
						local destPlot	= Map.GetPlotByIndex(village.ProductionPlot)
						local roadPath	= pPlot:GetRoadPath(destPlot, "Land", iMaxRouteDistance) 
						if roadPath then
							local settlers		= GetPopulationMigrationPerTurnForVillage(pPlot, prodRow)
							local bRoutePlaced	= false
							local currentPlot	= pPlot
							Dprint( DEBUG_ALTHIST_SCRIPT, "     - Moving " .. tostring(settlers) .. " settlers (min="..tostring(popPerTurn)..") to created village ("..tostring(destPlot:GetX())..","..tostring(destPlot:GetY())..")")
							for num, plotIndex in ipairs(roadPath) do
								local routePlot = Map.GetPlotByIndex(plotIndex)
								if routePlot:GetRouteType() == RouteTypes.NONE and not bRoutePlaced then
									RouteBuilder.SetRouteType(routePlot, 1)
									--break -- 1 plot per turn
									bRoutePlaced = true
								end
									
								if num > 1 then -- 1 is the origin plot
									Dprint( DEBUG_ALTHIST_SCRIPT, "      - migrate through path plot #".. tostring(num) .." = ".. routePlot:GetX() ..",".. routePlot:GetY())
									currentPlot:MigrationTo(routePlot, settlers)
									currentPlot = routePlot
								end
							end
						end
						
					--
					elseif sProductionType == "VILLAGE_REBUILD" then
						village.CentralPlot = village.CentralPlot or GCO.FindNearestPlayerVillage( playerID, pPlot:GetX(), pPlot:GetY())
						if village.CentralPlot then
							Dprint( DEBUG_ALTHIST_SCRIPT, "   - Rebuilding Village, turn left = ", village.TurnsLeft)
							local centerPlot	= Map.GetPlotByIndex(village.CentralPlot)
							local roadPath		= centerPlot:GetRoadPath(pPlot, "Land", iMaxSettlementDistance + 1) 
							if roadPath then
								local settlers		= GetPopulationMigrationPerTurnForVillage(pPlot, prodRow)
								local bRoutePlaced	= false
								local currentPlot	= centerPlot
								Dprint( DEBUG_ALTHIST_SCRIPT, "     - Moving " .. tostring(settlers) .. " settlers (min="..tostring(popPerTurn)..") to repaired village ("..tostring(pPlot:GetX())..","..tostring(pPlot:GetY())..")")
								for num, plotIndex in ipairs(roadPath) do
									local routePlot = Map.GetPlotByIndex(plotIndex)
									if routePlot:GetRouteType() == RouteTypes.NONE and not bRoutePlaced then
										RouteBuilder.SetRouteType(routePlot, 1)
										--break -- 1 plot per turn
										bRoutePlaced = true
									end
									
									if num > 1 then -- 1 is the origin plot
										Dprint( DEBUG_ALTHIST_SCRIPT, "      - migrate through path plot #".. tostring(num) .." = ".. routePlot:GetX() ..",".. routePlot:GetY())
										currentPlot:MigrationTo(routePlot, settlers)
										currentPlot = routePlot
									end
								end
							end
							--
						else
							GCO.Error("Can't find Central Plot in TribesTurnP for:[NEWLINE]Type: ".. tostring(sProductionType).."[NEWLINE]PlayerID: "..tostring(playerID).."[NEWLINE]PlotID: "..tostring(plotID) .."[NEWLINE]Position: ",pPlot:GetX(), pPlot:GetY())
						end
						
					--
					elseif sProductionType == "CENTER_CAPTURE" then
						Dprint( DEBUG_ALTHIST_SCRIPT, "   - Capturing Center Village, turn left = ", village.TurnsLeft)
					end
					
					-- Handle production end
					if village.TurnsLeft == 0 then
					
						-- 
						if sProductionType == "VILLAGE_CREATE" then
							local destPlot	= Map.GetPlotByIndex(village.ProductionPlot)
							local roadPath	= pPlot:GetRoadPath(destPlot, "Land", iMaxRouteDistance) 
							if roadPath then
								for num, plotIndex in ipairs(roadPath) do
									local routePlot = Map.GetPlotByIndex(plotIndex)
									if routePlot:GetRouteType() == RouteTypes.NONE then
										RouteBuilder.SetRouteType(routePlot, 1)
									end
								end
							end
							-- Place default Village
							local iType = GameInfo.Improvements["IMPROVEMENT_GOODY_HUT_GCO"].Index
							ImprovementBuilder.SetImprovementType(destPlot, iType, playerID)
							local newVillage 			= SetTribalVillageAt(village.ProductionPlot)
							newVillage.CentralPlot		= plotID
							
						--
						elseif sProductionType == "VILLAGE_REBUILD" then
							village.CentralPlot = village.CentralPlot or GCO.FindNearestPlayerVillage( playerID, pPlot:GetX(), pPlot:GetY())
							if village.CentralPlot then
								local centerPlot	= Map.GetPlotByIndex(village.CentralPlot)
								local roadPath		= centerPlot:GetRoadPath(pPlot, "Land", iMaxRouteDistance) 
								if roadPath then
									for num, plotIndex in ipairs(roadPath) do
										local routePlot = Map.GetPlotByIndex(plotIndex)
										if routePlot:GetRouteType() == RouteTypes.NONE then
											RouteBuilder.SetRouteType(routePlot, 1)
										end
									end
								end
								--
								ImprovementBuilder.SetImprovementPillaged(pPlot, false)
								village.PillagedCounter	= nil
							else
								GCO.Error("Can't find Central Plot in TribesTurnP for:[NEWLINE]Type: ".. tostring(sProductionType).."[NEWLINE]PlayerID: "..tostring(playerID).."[NEWLINE]PlotID: "..tostring(plotID) .."[NEWLINE]Position: ",pPlot:GetX(), pPlot:GetY())
							end
							
						--
						elseif sProductionType == "CENTER_CAPTURE" then
							Dprint( DEBUG_ALTHIST_SCRIPT, "   - Capturing Center Village...")
							ImprovementBuilder.SetImprovementPillaged(pPlot, false)
							village.PillagedCounter	= nil
						end

						
						village.TurnsLeft 		= nil
						village.ProductionType 	= bIsBarbarian and "PRODUCTION_EQUIPMENT" or "PRODUCTION_MATERIEL"
					end
					
				else
					GCO.Error("TurnLeft is not set for a turn-based production type in TribesTurnP[NEWLINE]Type: ".. tostring(sProductionType).."[NEWLINE]PlayerID: "..tostring(playerID).."[NEWLINE]PlotID: "..tostring(plotID) .."[NEWLINE]Position: ",pPlot:GetX(), pPlot:GetY())
				end
			
			-- Do Village production, not turn based		
			else			
				-- Get possible resource productions
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Get possible resources production...")
				for row in GameInfo.TribalVillageResourcesConverted() do
	--Dline(row.ResourceType, row.MaxConverted, row.ResourceCreated, row.Ratio, sImprovementType, (sImprovementType == row.ImprovementType), sEraType, row.Era, (row.Era == nil or row.Era == sEraType), (sImprovementType == row.ImprovementType) and (row.Era == nil or row.Era == sEraType) )
					if (sImprovementType == row.ImprovementType) and (row.Era == nil or row.Era == sEraType) then --and (row.ProductionType == nil or row.ProductionType == sProductionType) then
						local bBarbarianCanProduce 		= not row.NoBarbarian
						local bCivilizationCanProduce	= not row.IsBarbarian
	--Dline("bBarbarianCanProduce", bBarbarianCanProduce, "bCivilizationCanProduce", bCivilizationCanProduce, "(bBarbarianCanProduce and bIsBarbarian) or (bCivilizationCanProduce and not bIsBarbarian)", (bBarbarianCanProduce and bIsBarbarian) or (bCivilizationCanProduce and not bIsBarbarian) )
						if (bBarbarianCanProduce and bIsBarbarian) or (bCivilizationCanProduce and not bIsBarbarian) then
							local requiredTechID	= row.RequiredTech and GameInfo.Technologies[row.RequiredTech].Index
							local bCanProduce		= true
							if requiredTechID then
								local pPlayerTechs = pPlayer and pPlayer:GetTechs()
	--Dline("techRequirement", row.RequiredTech, pPlayerTechs, pPlayerTechs and pPlayerTechs:HasTech(requiredTechID) )
								if not (pPlayerTechs and pPlayerTechs:HasTech(requiredTechID)) then
									bCanProduce = false
								end
							end
							
							if bCanProduce then							
								local resourceID 			= GameInfo.Resources[row.ResourceType].Index								
								kProductions[resourceID]	= kProductions[resourceID] or {}
								table.insert(kProductions[resourceID], row)
								Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), row.MaxConverted, row.ResourceCreated, row.Ratio, row.Era, row.IsBarbarian, row.NoBarbarian)
							end
						end
					end
				end
			end
			
			if (not bPillaged) then
				--
				-- Do resources production
				--
				local output = GetTribeOutputFactor(pPlot)
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Do resources production at output, population ", output ,pPlot:GetPopulation())
				for resourceKey, value in pairs(pPlot:GetResources()) do
					if value > 0 then
						local resourceID = tonumber(resourceKey)
						if kProductions[resourceID] then
						
							local prodFactor = 1
							
							if prodRow.ProductionType then
								if prodRow.ProductionType == sProductionType then
									prodFactor = 1.75 -- to do: remove magic number
								else
									prodFactor = 0.35 -- to do: remove magic number
								end
							end
						
							for _, row in ipairs(kProductions[resourceID]) do
							
								local minStock			= 0
								
								if (resourceID == materielResourceID) then
									if sProductionType ~= "PRODUCTION_EQUIPMENT" then
										minStock = iMinMaterielStock
									else
										minStock = math.ceil(iMinMaterielStock*0.35) -- to do: remove magic number
									end
								end
							
								local maxUsed			= math.max(0,(value - minStock))
								local resourcesUsed 	= math.min(maxUsed, math.ceil(row.MaxConverted * output * prodFactor))
								local numProduced		= math.floor(resourcesUsed * row.Ratio)
								
								if numProduced > 0 then
									local prodResourceID		= GameInfo.Resources[row.ResourceCreated].Index
									
									if pPlot:GetMaxStock(prodResourceID) > pPlot:GetStock(prodResourceID) then
									
										local resKey				= tostring(prodResourceID)
										kResourcesUsed[resourceID]	= math.max(kResourcesUsed[resourceID] or 0, resourcesUsed)
										village.Production[resKey]	= village.Production[resKey] or {}
										table.insert(village.Production[resKey], {ID=resourceID, Used=resourcesUsed, Produced=numProduced})
										pPlot:ChangeStock(prodResourceID, numProduced)
										Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[prodResourceID].Name), numProduced, "prod factor = ", prodFactor)
										
										if prodResourceID == materielResourceID then
											village.MaterielProduced = village.MaterielProduced + numProduced
										end
										
									else
										Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[prodResourceID].Name), "production aborted, overstock")									
									end
								end
							end
						end
					end
				end
				-- Remove resources used
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Remove resources used...")
				for resourceID, value in pairs(kResourcesUsed) do
					pPlot:ChangeStock(resourceID, -value)
					--Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), -value)
				end
				
				--
				-- Exchange with units
				--
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Exchange with units...")
				if village.IsCentral then
					TransferWithLinkedUnits(village)
				end
				
				--
				-- Exchange with central village
				--
				-- To do : find city instead of village if exists
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Exchange with central village...")
				if village.CentralPlot then
					local centralPlot 		= GCO.GetPlotByIndex(village.CentralPlot)
					local centralVillage	= GetTribalVillageAt(village.CentralPlot)
					if centralPlot and centralVillage then
						if centralVillage.Owner == village.Owner and not centralPlot:IsPlotImprovementPillaged() then
							for resourceKey, value in pairs(pPlot:GetResources()) do
								local resourceID 	= tonumber(resourceKey)
								local iExchange		= math.floor(value*0.35) -- to do: remove magic number
								pPlot:ChangeStock(resourceID, -iExchange)
								centralPlot:ChangeStock(resourceID, iExchange)
								--Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), -iExchange)
							end
						end
					else
						GCO.Error("Can't find Central Plot or centralVillage in TribesTurnP for Exchange[NEWLINE]PlayerID: "..tostring(playerID).."[NEWLINE]PlotID: "..tostring(plotID) .."[NEWLINE]Position: ",pPlot:GetX(), pPlot:GetY())
					end
				end
				
				--
				-- Eat/Growth
				--
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Calculate Growth...")
				
				local foodProduced			= pPlot:GetYield(yieldFood)
				
				pPlot:ChangeStock(foodResourceID, foodProduced)
			
				local totalPopulation		= pPlot:GetPopulation()
				local maxPopulation			= GCO.GetPopulationAtSize(pPlot:GetMaxSize())
				local totalSlaves			= pPlot:GetStock(slaveClassID)
				local foodConsumption1000 	= (totalPopulation * TribeFoodConsumption ) + (totalSlaves * SlaveClassFoodConsumption )
				local foodConsumption 		= math.max(1, math.ceil( foodConsumption1000 * 0.001 ))
				local foodNeeded 			= math.max(10, (foodConsumption - pPlot:GetStock(foodResourceID))*2) -- try to keep a minimal food stock of 10 for units
				village.FoodRequired		= foodConsumption
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Food Consumption, foodConsumption1000 = ", foodConsumption, foodConsumption1000)
				
				-- Convert Food
				if foodNeeded > 0 then
					local sortedFood	= {}
					for _, resourceID in ipairs(GCO.GetEdibleFoodList()) do
						if resourceID ~= foodResourceID then
							table.insert(sortedFood, {ResourceID = resourceID, DecayRate = GameInfo.Resources[resourceID].DecayRate or 0 })
						end
					end
					table.sort(sortedFood, function(a, b) return a.DecayRate > b.DecayRate; end)
					
					for _, row in ipairs(sortedFood) do
						local resourceID 	= row.ResourceID
						local used			= math.min(foodNeeded, pPlot:GetStock(resourceID))
						if used > 0 then
							pPlot:ChangeStock(foodResourceID, used)
							pPlot:ChangeStock(resourceID, -used)
							
							--Dprint( DEBUG_ALTHIST_SCRIPT, "   - Food prepared = " .. tostring(used) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name))
							
							foodNeeded 					= foodNeeded - used
							foodProduced				= foodProduced + used
							local resKey				= tostring(foodResourceID)
							village.Production[resKey]	= village.Production[resKey] or {}
							table.insert(village.Production[resKey], {ID=resourceID, Used=used, Produced=used})
						end
					end
				end
				
				village.FoodProduced	= foodProduced
				local availableFood 	= pPlot:GetStock(foodResourceID)
				
				if availableFood > foodConsumption then
					
					Dprint( DEBUG_ALTHIST_SCRIPT, "   - Food Eaten / Available =  ", foodConsumption,"/", availableFood)
					
					pPlot:ChangeStock(foodResourceID, -foodConsumption)
					
					local kCultures 	= pPlot:GetCultureTable()
					
					for cultureKey, value in pairs (kCultures) do
						local cultureID = tonumber(cultureKey)
						local growth 	= math.floor(value * 0.05) -- to do : remove magic number
						pPlot:ChangeCulture(cultureID, growth)	
						Dprint( DEBUG_ALTHIST_SCRIPT, "    - Growth ", growth, Locale.Lookup(GameInfo.CultureGroups[cultureID].Name))
					end
					
					village.Pull.Food = foodConsumption > 0 and Div(availableFood, foodConsumption)  or 999
					village.Push.Food = availableFood 	> 0 and Div(foodConsumption, availableFood)  or 999
				
				else
				
					pPlot:ChangeStock(foodResourceID, -availableFood)

					local factor 	= availableFood > 0 and Div(foodConsumption, availableFood) or 4 	-- to do : remove magic number
					local deathRate = math.min(0.2, 0.05 * factor) 										-- to do : remove magic number
					
					Dprint( DEBUG_ALTHIST_SCRIPT, "   - Food Eaten / Required, DeathRate =  ", availableFood,"/", foodConsumption, ",", deathRate)
					
					local kCultures 	= pPlot:GetCultureTable()
					
					for cultureKey, value in pairs (kCultures) do
						local cultureID = tonumber(cultureKey)
						local death 	= math.floor(value * deathRate) 
						pPlot:ChangeCulture(cultureID, -death)	
						Dprint( DEBUG_ALTHIST_SCRIPT, "    - Death ", death, Locale.Lookup(GameInfo.CultureGroups[cultureID].Name))
					end
					
					local iSlaves = pPlot:GetStock(slaveClassID)
					if iSlaves > 0 then
						local death 	= math.floor(iSlaves * deathRate) 
						pPlot:ChangeStock(slaveClassID, death)
						Dprint( DEBUG_ALTHIST_SCRIPT, "    - Death ", death, "Slaves")
					end
					
					village.Pull.Food = foodConsumption > 0 and Div(availableFood, foodConsumption)  or 999 -- + Div(maxPopulation, totalPopulation)) / 2)
					village.Push.Food = availableFood 	> 0 and Div(foodConsumption, availableFood)  or 999 -- + Div(totalPopulation, maxPopulation)) / 2)
					
				end
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "    - Food Migration (Push,Pull) ", village.Push.Food, village.Pull.Food)
				
				--
				-- Convert Culture
				--
				if village.IsCentral and playerID ~= iBarbarianPlayer then
					local bAssimilate		= sProductionType == "POPULATION_ASSIMILATION"
					local populationRate	= bAssimilate and iPopConvertionRate * iAssimilationFactor or iPopConvertionRate
					local maxConverted		= bAssimilate and iAssimilationConvertion or iNormalMaxConvertion
					local kCultures 		= pPlot:GetCultureTable()
					local newCultureID		= GCO.GetCultureIDFromPlayerID(playerID)
					local kGiven			= {}
					
					if newCultureID then
						
						if bAssimilate then
							for resourceKey, value in pairs(pPlot:GetResources()) do
								local resourceID = tonumber(resourceKey)
								if GCO.IsResourceLuxury(resourceID) and value > 0 then
									local iLuxuriesForGift	= math.min(value, iMaxLuxuriesPerTurn)
									populationRate 			= populationRate + (iLuxuriesForGift*iPopConvertionPerLuxury)
									kGiven[resourceID] 		= iLuxuriesForGift
								end
							end
							
							for resourceID, value in pairs(kGiven) do
								pPlot:ChangeStock(resourceID, -value)
							end
						end
						
						Dprint( DEBUG_ALTHIST_SCRIPT, "   - Convert Culture (populationRate, maxConverted) ", populationRate, maxConverted, sProductionType)
					
						for cultureKey, value in pairs (kCultures) do
							local cultureID = tonumber(cultureKey)
							if cultureID ~= newCultureID then
								local toConvert = math.min(maxConverted, math.floor(value * populationRate))
								pPlot:ChangeCulture(newCultureID, toConvert)
								pPlot:ChangeCulture(cultureID, -toConvert)
								--Dprint( DEBUG_ALTHIST_SCRIPT, "    - Convert ", toConvert, Locale.Lookup(GameInfo.CultureGroups[cultureID].Name)," to ", Locale.Lookup(GameInfo.CultureGroups[newCultureID].Name))
							end
						end
						if bAssimilate then
							local slaves 	= pPlot:GetStock(slaveClassID)
							local toConvert = math.floor(slaves * iSlaveConvertionRate)
							pPlot:ChangeStock(slaveClassID, -toConvert)
							pPlot:ChangeCulture(newCultureID, toConvert)
							--Dprint( DEBUG_ALTHIST_SCRIPT, "    - Convert ", toConvert ," Slaves to ", Locale.Lookup(GameInfo.CultureGroups[newCultureID].Name))
						end
					else
						GCO.Error("Can't find CultureID of centralVillage owner in TribesTurnP for convertion[NEWLINE]PlayerID: "..tostring(playerID).."[NEWLINE]PlotID: "..tostring(plotID) .."[NEWLINE]Position: ",pPlot:GetX(), pPlot:GetY())
					end
				end
				
				--
				-- Convert independents
				--
				local independents = pPlot:GetCulture(INDEPENDENT_CULTURE)
				if independents < pPlot:GetPopulation() and independents > 0 then -- there are other cultures than independents here, and there are some independents
					local kCultures 	= pPlot:GetCultureTable()
					local numCulture	= GCO.GetSize(kCultures) - 1
					local perCulture	= math.floor(Div(independents, numCulture))	
					for cultureKey, value in pairs (kCultures) do
						if cultureKey ~= INDEPENDENT_CULTURE then
							local cultureID = tonumber(cultureKey)
							pPlot:ChangeCulture(cultureID, perCulture)
							pPlot:ChangeCulture(INDEPENDENT_CULTURE, -perCulture)
							--Dprint( DEBUG_ALTHIST_SCRIPT, "    - Convert ", perCulture, "independents to ", Locale.Lookup(GameInfo.CultureGroups[cultureID].Name))
						end
					end
				end
				
				--
				-- Forced Migration
				--
				if village.IsCentral and (sProductionType == "POPULATION_EMIGRATION" or sProductionType == "POPULATION_IMMIGRATION") then
				--
				
					local ownCultureID		= GCO.GetCultureIDFromPlayerID(playerID)
					local tOtherVillages 	= GetPlayerTribalVillages(playerID)
					local tOtherPlots		= {}
					for _, otherPlotKey in ipairs(tOtherVillages) do
						local otherPlotID	= tonumber(otherPlotKey)
						local otherVillage	= GetTribalVillageAt(otherPlotID)
						if otherVillage.CentralPlot == plotID then
							table.insert(tOtherPlots, GCO.GetPlotByIndex(otherPlotID))
						end
					end
					if #tOtherPlots > 0 then
					
						if sProductionType == "POPULATION_EMIGRATION" then
						
							local kMigrants = {}
							for cultureKey, value in pairs (pPlot:GetCultureTable()) do
								local cultureID = tonumber(cultureKey)
								if cultureID ~= ownCultureID then
									kMigrants[cultureID] = math.floor(Div(value*iForcedMigrationRate, #tOtherPlots))
								end
							end
						
							for _, destPlot in ipairs(tOtherPlots) do
								Dprint( DEBUG_ALTHIST_SCRIPT, " - Forced Emigration to ("..tostring(destPlot:GetX())..","..tostring(destPlot:GetY())..")")
								for cultureID, migrants in pairs(kMigrants) do
									pPlot:ChangeCulture(cultureID, -migrants)
									destPlot:ChangeCulture(cultureID, migrants)
									Dprint( DEBUG_ALTHIST_SCRIPT, "  - Migrants ", migrants, Locale.Lookup(GameInfo.CultureGroups[cultureID].Name))
								end
							end
							
						-- IMMIGRATION
						else
						
							for _, destPlot in ipairs(tOtherPlots) do
								local supplyPath = destPlot:GetSupplyPath( pPlot, playerID)
								if path then
									local migrants = math.floor(destPlot:GetPopulation()*iForcedMigrationRate)
									Dprint( DEBUG_ALTHIST_SCRIPT, " - Forced Immigration of " .. tostring(migrants) .. " migrants from ("..tostring(destPlot:GetX())..","..tostring(destPlot:GetY())..")")
									local currentPlot	= destPlot
									for num, plotIndex in ipairs(roadPath) do
										if num > 1 then -- 1 is the origin plot
											local routePlot = Map.GetPlotByIndex(plotIndex)
											Dprint( DEBUG_ALTHIST_SCRIPT, "      - Forced migration through path plot #".. tostring(num) .." = ".. routePlot:GetX() ..",".. routePlot:GetY())
											currentPlot:MigrationTo(routePlot, settlers)
											currentPlot = routePlot
										end
									end
								else
									for cultureKey, value in pairs (destPlot:GetCultureTable()) do
										local cultureID = tonumber(cultureKey)
										local migrants 	= math.floor(value*iForcedMigrationRate)
										pPlot:ChangeCulture(cultureID, migrants)
										destPlot:ChangeCulture(cultureID, -migrants)
										Dprint( DEBUG_ALTHIST_SCRIPT, "  - Migrants ", migrants, Locale.Lookup(GameInfo.CultureGroups[cultureID].Name))
									end
								end
							end
						end
					
					end
				end
				
				--
				-- Produce Gold
				--
				if village.IsCentral and sProductionType == "PRODUCTION_GOLD" and pPlayer then
					local iLuxuries	= 0
					local kTraded	= {}
					for resourceKey, value in pairs(pPlot:GetResources()) do
						local resourceID = tonumber(resourceKey)
						if GCO.IsResourceLuxury(resourceID) and value > 0 then
							local iTraded		= math.min(value, iMaxLuxuriesPerTurn)
							iLuxuries			= iLuxuries + iTraded
							kTraded[resourceID] = iTraded
						end
					end
					for resourceID, value in pairs(kTraded) do
						pPlot:ChangeStock(resourceID, -value)
					end
					pPlayer:ProceedTransaction(AccountType.ExportTaxes, iLuxuries * iGoldPerLuxury) -- to do : add specific AccountType ?
				end
				
			else
				village.Pull = nil
			    village.Push = nil
			end
			
		end
		LuaEvents.TribeImprovementUpdated(playerID, plotID)
	end
end

function CheckVillageCapture(playerID, unitID, plotID)

local pPlot = GCO.GetPlotByIndex(plotID)

	local DEBUG_ALTHIST_SCRIPT = "debug"

	local village = GetTribalVillageAt(plotID)

	if village then
		Dline("CheckVillageCapture, village.Owner, playerID", village.Owner, playerID)
	end
	
	if village and village.Owner ~= playerID then
		local pPlayer 		= GCO.GetPlayer(playerID)
		local pPlayerDiplo	= pPlayer:GetDiplomacy()
		if village.Owner == NO_PLAYER or pPlayerDiplo:IsAtWarWith( village.Owner ) then
		
			local pPlot = GCO.GetPlotByIndex(plotID)
			local pUnit	= GCO.GetUnit(playerID, unitID)
			
			--if not pPlot:IsPlotImprovementPillaged() then
				Dprint( DEBUG_ALTHIST_SCRIPT, "--------------------------------------------------------------------")
				Dprint( DEBUG_ALTHIST_SCRIPT, "- Hostile unit entered a Village at ", pPlot:GetX(), pPlot:GetY(), Locale.Lookup(pUnit:GetName()) )
				
				local pLocalPlayerVis 	= PlayersVisibility[Game.GetLocalPlayer()]
				local bIsVisible		= (pLocalPlayerVis ~= nil) and (pLocalPlayerVis:IsVisible(pPlot:GetX(), pPlot:GetY()))
				local tCollectedString	= {}
				for resourceKey, value in pairs(pPlot:GetResources()) do
					if value > 0 then
						local resourceID = tonumber(resourceKey)
						Dprint( DEBUG_ALTHIST_SCRIPT, "   - Looting ", Locale.Lookup(GameInfo.Resources[resourceID].Name), value)
						pPlot:ChangeStock(resourceID, -value)
						pUnit:ChangeStock(resourceID, value)
						table.insert(tCollectedString, "+" .. tostring(value)..GCO.GetResourceIcon(resourceID))
					end
				end
				
				if bIsVisible and #tCollectedString > 0 then
					Game.AddWorldViewText(EventSubTypes.DAMAGE, table.concat(tCollectedString, ","), pPlot:GetX(), pPlot:GetY(), 0)
				end
				
				-- Capture Population
				local cultureGroupID 	= village.Owner == NO_PLAYER and pPlot:GetHighestCultureID() or GetTribePlayerCulture(village.Owner) or pPlot:GetHighestCultureID()
				local iMaxCaptured		= pUnit:GetFrontLinePersonnel() * 5 -- to do: remove magic number
				local iPopulation		= pPlot:GetCulture(cultureGroupID)
				local iCaptured			= math.floor(math.min(iMaxCaptured, iPopulation * 0.35 ))  -- to do: remove magic number
				local iEscaped			= iPopulation - iCaptured -- to do : move to other plots
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "- Plot Culture IDs (used, highest, tribePlayerCulture, playerID) ", cultureGroupID, pPlot:GetHighestCultureID(), GetTribePlayerCulture(village.Owner), village.Owner)
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Captured Slaves ", iCaptured)
					
				pUnit:ChangeStock(slaveClassID, iCaptured)
				pPlot:ChangeCulture(cultureGroupID, -iCaptured)
				--	
				if bIsVisible then
					local sCaptured = "+" .. tostring(iCaptured).." "..GCO.GetResourceIcon(slaveClassID).." "..Locale.Lookup(GameInfo.Resources[slaveClassID].Name)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sCaptured, pPlot:GetX(), pPlot:GetY(), 0)
				end
				--
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Delete old improvement...")
				ImprovementBuilder.SetImprovementType(pPlot, -1)
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Recreate improvement ", village.Type, playerID)
				local iType = GameInfo.Improvements[village.Type].Index
				ImprovementBuilder.SetImprovementType(pPlot, iType, playerID)
				village.Owner = playerID
				
				-- change central plot reference
				if not village.IsCentral then
					local newPlotID, dist	= GCO.FindNearestPlayerVillage( playerID, pPlot:GetX(), pPlot:GetY() )
					village.CentralPlot		= dist <= iMaxBarbSettlementDist and newPlotID or nil
print(newPlotID, dist, iMaxBarbSettlementDist, village.CentralPlot)
				end
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "   - Set Pillaged...")
				ImprovementBuilder.SetImprovementPillaged(pPlot, true)
				
				village.PillagedCounter = 0
				
				LuaEvents.UnitsCompositionUpdated(playerID, unitID)
				LuaEvents.TribeImprovementUpdated(playerID, plotID)
			--end
		end
	end
end

function OnUnitPathComplete(playerID, unitID, pathPlots)
	local DEBUG_ALTHIST_SCRIPT = "debug"
	Dprint( DEBUG_ALTHIST_SCRIPT, "- On Unit Path Complete : ", playerID, unitID, pathPlots)
	for pathIndex, plotID in ipairs(pathPlots) do
		if pathIndex > 1 then -- ignore starting position
			CheckVillageCapture(playerID, unitID, plotID)
		end
	end
end

function OnUnitTeleported(playerID, unitID, iX, iY)

	local DEBUG_ALTHIST_SCRIPT = "debug"
	Dprint( DEBUG_ALTHIST_SCRIPT, "- On Unit Teleported : ", playerID, unitID, iX, iY)
	
	local pPlot = Map.GetPlot(iX, iY)
	CheckVillageCapture(playerID, unitID, pPlot:GetIndex())

end

-- ===================================================================================== --
-- Map
-- ===================================================================================== --

function NoAdjacentVillage(pPlot)
	for i, adjacentPlotID in ipairs(GCO.GetAdjacentPlots(pPlot)) do
		local adjacentPlot = GCO.GetPlotByIndex(adjacentPlotID)
		if IsTribeImprovement(adjacentPlot:GetImprovementType()) then
			return false
		end
	end
	return true
end

function CanPlaceTribe(pPlot, iCheckRange, ignoredPlayerID)
	
	--local DEBUG_ALTHIST_SCRIPT = "debug"

	if pPlot and pPlot:GetResourceCount() == 0 and (not pPlot:IsImpassable()) and (not pPlot:IsNaturalWonder()) and (not pPlot:IsWater()) and pPlot:GetFeatureType() ~= GameInfo.Features["FEATURE_OASIS"].Index then
	
		if pPlot:GetImprovementType() ~= NO_IMPROVEMENT then
			return false
		end
		
		-- Check for being too close from somethings.
		local uniqueRange = iCheckRange or 4
		local plotX = pPlot:GetX();
		local plotY = pPlot:GetY();
		for i, iPlotID in ipairs(GCO.GetPlotsInRange(pPlot, uniqueRange)) do
			local otherPlot = GCO.GetPlotByIndex(iPlotID)
			if(otherPlot) then
				if IsTribeImprovement(otherPlot:GetImprovementType()) then
					if not (ignoredPlayerID and otherPlot:GetImprovementOwner() == ignoredPlayerID) then
						Dprint( DEBUG_ALTHIST_SCRIPT, "FAILED improvement ownership check for CanPlaceTribe: plotX, plotY, ImprovementOwner, ignoredPlayerID = ", plotX, plotY, otherPlot:GetImprovementOwner(), ignoredPlayerID)
						return false;
					end
				end
				if otherPlot:IsOwned() and not (ignoredPlayerID and otherPlot:GetOwner() == ignoredPlayerID) then
					Dprint( DEBUG_ALTHIST_SCRIPT, "FAILED plot ownership check for CanPlaceTribe: plotX, plotY, Owner, ignoredPlayerID = ", plotX, plotY, otherPlot:GetOwner(), ignoredPlayerID)
					return false
				end
				local aUnits = Units.GetUnitsInPlot(otherPlot);
				for i, pUnit in ipairs(aUnits) do
					local iOwner = pUnit:GetOwner()
					if Players[iOwner]:IsMajor() and not (ignoredPlayerID and iOwner == ignoredPlayerID)  then
						Dprint( DEBUG_ALTHIST_SCRIPT, "FAILED Unit ownership check for CanPlaceTribe: plotX, plotY, Owner, ignoredPlayerID = ", plotX, plotY, iOwner, ignoredPlayerID)
						return false
					end
				end
			end
		end
	
		return true
	else 
		return false
	end
end

function GetPotentialTribePlots(kFertilityParameters)

	local DEBUG_ALTHIST_SCRIPT = "debug"
	
	local potentialPlots 	= {}
	local minFertility		= 35 -- -250
	local g_iW, g_iH 		= Map.GetGridSize()

	for iX = 0, g_iW - 1 do
		for iY = 0, g_iH - 1 do
			local index = (iY * g_iW) + iX;
			pPlot = GCO.GetPlotByIndex(index)
			if pPlot:GetResourceCount() == 0 then
				local fertility = pPlot:GetPlotFertility(kFertilityParameters)
				if fertility > minFertility and CanPlaceTribe(pPlot) then
					--print("fertility = ", fertility)
					table.insert(potentialPlots, { PlotID = index, Fertility = fertility} )
				end
			end
		end
	end
	Dprint( DEBUG_ALTHIST_SCRIPT, "GetPotentialTribePlots returns "..tostring(#potentialPlots).." plots")
	
	table.sort (potentialPlots, function(a, b) return a.Fertility > b.Fertility; end);
	return potentialPlots
end

function InitializeTribeAt(kParameters)

	local DEBUG_ALTHIST_SCRIPT = "debug"
	
	local bNoDuplicate	= true
	
	local playerID 			= kParameters.PlayerID
	local cultureID			= kParameters.CultureID
	local sUnitType			= kParameters.GarrisonUnitType
	local pPlot 			= kParameters.Plot
	local iCentralPlot		= pPlot:GetIndex()
	local iRange			= kParameters.Range or 3
	local sImprovementType	= kParameters.ImprovementType or "IMPROVEMENT_BARBARIAN_CAMP_GCO"
	local iFertilityRange	= 1
	local iMinSettlements	= kParameters.MinSettlement or 0
	local iMaxSettlements	= kParameters.MaxSettlement or 0
	local iRandomRange		= math.max(0, iMaxSettlements - iMinSettlements)
	local iSettlements		= iRandomRange > 0 and iMinSettlements + TerrainBuilder.GetRandomNumber(iRandomRange, "GetNumTribeSettlements") or iMinSettlements
	local bPlaceRoutes		= kParameters.PlaceRoutes
	local iDeer				= GameInfo.Resources["RESOURCE_DEER"].Index
	local iIndepSettlements	= kParameters.IndSettlement
	local iIndepMinRange	= kParameters.IndepMinRange or iRange
	local iIndepMaxRange	= kParameters.IndepMaxRange or math.ceil(iRange*1.5)

	if cultureID == nil then
		cultureID = pPlot:GetBestCultureGroup(bNoDuplicate)
	end
	
	if playerID == nil then
		-- find available Tribe Player based on cultureID ethnicity
		
	end
	local pPlayer = playerID and GCO.GetPlayer(playerID)
	
	Dprint( DEBUG_ALTHIST_SCRIPT, "  - InitializeTribeAt : X, Y, playerID, cultureID, iRange, iMinSettlements, iMaxSettlements, iSettlements = ", pPlot:GetX(), pPlot:GetY(), playerID, cultureID, iRange, iMinSettlements, iMaxSettlements, iSettlements)
	
	-- Set central settlement
	pPlot:AddPopulationForTribalVillage(cultureID, bNoDuplicate)
	ImprovementBuilder.SetImprovementType(pPlot, GameInfo.Improvements[sImprovementType].Index, playerID)
	local village 			= SetTribalVillageAt(iCentralPlot)
	village.IsCentral		= true
	village.Owner			= playerID
	village.Type			= sImprovementType
	local bIsBarbarian		= pPlayer == nil and true or pPlayer:IsBarbarian() -- no player means "barbarian"
	village.ProductionType	= (bIsBarbarian and "PRODUCTION_EQUIPMENT") or "PRODUCTION_MATERIEL"
	
	if sUnitType then
		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Adding Garrison Unit : ", sUnitType)
		local pUnit = UnitManager.InitUnit(playerID, sUnitType, pPlot:GetX(), pPlot:GetY())
		if pUnit then
			local pUnitAbility 	= pUnit:GetAbility(); 
			local bResult 		= pUnitAbility:ChangeAbilityCount("ABILITY_NO_MOVEMENT", 1)
		end
	end
	
	-- Set satellite settlements
	if iSettlements > 0 then
		local tPotentialSettlements		= {}
		local tPotentialFarmers			= {}
		local tPotentialHunters			= {}
		local iCheckRange				= 4
		
		local kFertilityParameters					= {}
		kFertilityParameters.Range					= iFertilityRange
		kFertilityParameters.ProductionYieldWeight	= 1
		kFertilityParameters.FoodYieldWeight		= 5
		kFertilityParameters.StrategicYieldWeight	= 0
		kFertilityParameters.LuxuriesYieldWeight	= 2
		kFertilityParameters.CoastalLandFertility	= 25

		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Getting potentiel plots for satellite Settlements...")
		
		local tPlots	= GCO.GetPlotsInRange(pPlot, iRange)
		local iTested	= 0
		
		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Plots to test = ", #tPlots)
		
		for i, iPlotID in ipairs(tPlots) do
			local otherPlot = GCO.GetPlotByIndex(iPlotID)
			
			if CanPlaceTribe(otherPlot, iCheckRange, playerID) and otherPlot:GetArea():GetID() == pPlot:GetArea():GetID() then
				local iFertility = otherPlot:GetPlotFertility(kFertilityParameters)
				local iHunters	= 0
				local iFarmers	= 0
				for ii, adjacentPlotID in ipairs(GCO.GetAdjacentPlots(otherPlot)) do
					local adjacentPlot	= GCO.GetPlotByIndex(adjacentPlotID)
					local resourceID 	= adjacentPlot:GetResourceType()
					if GCO.IsResourceGranaryProduced(resourceID) then
						local farmValue = adjacentPlot:GetResourceCount()
						iFarmers = iFarmers + farmValue
						iHunters = iHunters - farmValue
					end
					if resourceID == iDeer then
						local huntValue = adjacentPlot:GetResourceCount() * 2
						iHunters = iHunters + huntValue
						iFarmers = iFarmers - huntValue
					end
					if GCO.IsFeatureForest() then
						iHunters = iHunters + 1
					end
				end
				if iFarmers >= 4 and iFarmers > iHunters then
					table.insert(tPotentialFarmers, { Plot = otherPlot, Fertility = iFertility * iFarmers} )
				elseif iHunters >= 4 and iHunters > iFarmers then
					table.insert(tPotentialHunters, { Plot = otherPlot, Fertility = iFertility * iHunters} )
				else
					table.insert(tPotentialSettlements, { Plot = otherPlot, Fertility = iFertility} )				
				end
			end
			iTested = iTested + 1
		end
		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Plots tested = ", iTested)
		
		table.sort (tPotentialFarmers, function(a, b) return a.Fertility > b.Fertility; end)
		table.sort (tPotentialHunters, function(a, b) return a.Fertility > b.Fertility; end)
		table.sort (tPotentialSettlements, function(a, b) return a.Fertility > b.Fertility; end)
		
		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Found : Farmers = ", #tPotentialFarmers, ", Hunters = ", #tPotentialHunters, ", Default Settlements = ", #tPotentialSettlements)
		
		local bLoop 	= true
		local toPlace	= iSettlements
		local iFarmer	= 1
		local iHunter	= 1
		local iSettler	= 1
		local tPlaced	= {}
		while(bLoop and toPlace > 0) do
			bLoop = false
			local farmRow	= tPotentialFarmers[iFarmer]
			local huntRow	= tPotentialHunters[iHunter]
			local settRow	= tPotentialSettlements[iSettler]
			local pSatPlot	= nil
			local iType		= nil
			
			if farmRow or huntRow or settRow then
				bLoop = true
			end
			
			if farmRow then
				iFarmer = iFarmer + 1
				if GCO.NoAdjacentImprovement(farmRow.Plot) then
					pSatPlot	= farmRow.Plot
					iType		= GameInfo.Improvements["IMPROVEMENT_GOODY_HUT_FARM"].Index
				end
			elseif huntRow then
				iHunter = iHunter + 1
				if GCO.NoAdjacentImprovement(huntRow.Plot) then
					pSatPlot	= huntRow.Plot
					iType		= GameInfo.Improvements["IMPROVEMENT_GOODY_HUT_HUNT"].Index
				end
			elseif settRow then
				iSettler = iSettler + 1
				if GCO.NoAdjacentImprovement(settRow.Plot) then
					pSatPlot	= settRow.Plot
					iType		= GameInfo.Improvements["IMPROVEMENT_GOODY_HUT_GCO"].Index
				end
			end
			
			if pSatPlot and iType then
				pSatPlot:AddPopulationForTribalVillage(cultureID, bNoDuplicate)
				ImprovementBuilder.SetImprovementType(pSatPlot, iType, playerID)
				
				local village 			= SetTribalVillageAt(pSatPlot:GetIndex())
				village.IsCentral		= false
				village.Owner			= playerID
				village.Type			= sImprovementType
				village.CentralPlot 	= iCentralPlot
				village.ProductionType	= (bIsBarbarian and "PRODUCTION_EQUIPMENT") or "PRODUCTION_MATERIEL"
				
				table.insert(tPlaced, { Plot = pSatPlot, Distance = Map.GetPlotDistance(pSatPlot:GetIndex(), pPlot:GetIndex())} )
				toPlace	= toPlace - 1
			end
		end
		
		if bPlaceRoutes then
			table.sort(tPlaced, function(a, b) return a.Distance < b.Distance; end)
			for _, row in ipairs(tPlaced) do
				local path = pPlot:GetRoadPath(row.Plot, "Land", 6)
				if path then
					for __, plotIndex in ipairs(path) do
						local routePlot = Map.GetPlotByIndex(plotIndex)
						RouteBuilder.SetRouteType(routePlot, 1) -- to do : select route type
					end
				end
			end
		end
	end
	
	if iIndepSettlements and iIndepSettlements > 0 then
	
		local tPotentialSettlements		= {}
		local iCheckRange				= 3
	
		local kFertilityParameters					= {}
		kFertilityParameters.Range					= iFertilityRange
		kFertilityParameters.ProductionYieldWeight	= 0 + TerrainBuilder.GetRandomNumber(3, "Random Fertility parameter")+1
		kFertilityParameters.FoodYieldWeight		= 0 + TerrainBuilder.GetRandomNumber(3, "Random Fertility parameter")+1
		kFertilityParameters.StrategicYieldWeight	= 0
		kFertilityParameters.LuxuriesYieldWeight	= 0 + TerrainBuilder.GetRandomNumber(3, "Random Fertility parameter")+1
		kFertilityParameters.CoastalLandFertility	= 5 + TerrainBuilder.GetRandomNumber(5, "Random Fertility parameter")+1
		kFertilityParameters.FreshWaterFertility	= 5 + TerrainBuilder.GetRandomNumber(5, "Random Fertility parameter")+1
		kFertilityParameters.RiverFertility			= 5 + TerrainBuilder.GetRandomNumber(5, "Random Fertility parameter")+1

		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Getting potentiel plots for independent Settlements...")
		
		local tPlots	= GCO.GetPlotsInRange(pPlot, iIndepMaxRange)
		local iTested	= 0
		
		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Plots to test = ", #tPlots)
		
		for i, iPlotID in ipairs(tPlots) do
			local otherPlot = GCO.GetPlotByIndex(iPlotID)
			if Map.GetPlotDistance(iPlotID, pPlot:GetIndex()) >= iIndepMinRange then
				if CanPlaceTribe(otherPlot, iCheckRange) and otherPlot:GetArea():GetID() == pPlot:GetArea():GetID() then
					local iFertility = otherPlot:GetPlotFertility(kFertilityParameters)
					table.insert(tPotentialSettlements, { Plot = otherPlot, Fertility = iFertility} )
				end
			end
		end
		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Plots tested = ", iTested)
		
		table.sort (tPotentialSettlements, function(a, b) return a.Fertility > b.Fertility; end)
		
		Dprint( DEBUG_ALTHIST_SCRIPT, "    - Found potentiel independent Settlements = ", #tPotentialSettlements)
		
		local bLoop 	= true
		local toPlace	= iIndepSettlements
		local iSettler	= 1
		while(bLoop and toPlace > 0) do
			bLoop = false
			local settRow	= tPotentialSettlements[iSettler]
			iSettler = iSettler + 1
			if settRow then
				bLoop = true
				if GCO.NoAdjacentImprovement(settRow.Plot) then
					local cultureID = settRow.Plot:GetBestCultureGroup(bNoDuplicate)
					settRow.Plot:AddPopulationForTribalVillage(cultureID, bNoDuplicate)
					ImprovementBuilder.SetImprovementType(settRow.Plot, GameInfo.Improvements["IMPROVEMENT_GOODY_HUT_GCO"].Index, -1)
					toPlace	= toPlace - 1
				end
			end
		end
	end
end

function InitializeTribesOnMap()
	
	if Game:GetProperty("TribeSettlementsInitialized") == 1 then -- only called once
		return
	end
	
	local DEBUG_ALTHIST_SCRIPT = "debug"
	
	Dprint( DEBUG_ALTHIST_SCRIPT, "--=================== INITIALIZE TRIBES ON MAP ===================--")
	
	-- Place Tribes on Major Civilizations Starting Positions
	Dprint( DEBUG_ALTHIST_SCRIPT, "- Placing Major Civilizations Tribes...")
	local kTribeParameters			= {}
	kTribeParameters.Range			= iMaxSettlementDistance
	--kTribeParameters.MinSettlement	= 3
	--kTribeParameters.MaxSettlement	= 3
	kTribeParameters.IndSettlement	= 2
	kTribeParameters.IndepMinRange	= iMaxSettlementDistance - 1
	kTribeParameters.IndepMaxRange	= iMaxSettlementDistance + 1
	kTribeParameters.PlaceRoutes	= true
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		Dprint( DEBUG_ALTHIST_SCRIPT, GCO.Separator)
		Dprint( DEBUG_ALTHIST_SCRIPT, " - Add Tribe settlements for Player #"..tostring(playerID))
		local pPlayer 		= Players[playerID]
		local pStartPlot	= pPlayer:GetStartingPlot()
		
		if pStartPlot then
			GCO.InitializePlotFunctions(pStartPlot)
			kTribeParameters.Plot 		= pStartPlot
			kTribeParameters.PlayerID 	= playerID
			InitializeTribeAt(kTribeParameters)
		end
	end
	
	-- Place Tribes with organized settlements
	Dprint( DEBUG_ALTHIST_SCRIPT, "- placing Organized Tribes...")

	local toPlace		= math.floor(PlayerManager.GetAliveMajorsCount() * fOrganizedTribeFactor) -- or stop when no Tribe player left ?
	local placed 		= 0
	local bNoDuplicate	= true
	
	local kTribeParameters				= {}
	kTribeParameters.Range				= 3
	kTribeParameters.MinSettlement		= 2
	kTribeParameters.MaxSettlement		= 4 
	kTribeParameters.PlaceRoutes		= true
	kTribeParameters.GarrisonUnitType	= "UNIT_LIGHT_SPEARMAN"
		
	local kFertilityParameters					= {}
	kFertilityParameters.Range					= 2
	kFertilityParameters.ProductionYieldWeight	= 1 + TerrainBuilder.GetRandomNumber(3, "Random Fertility parameter")+1
	kFertilityParameters.FoodYieldWeight		= 0 + TerrainBuilder.GetRandomNumber(2, "Random Fertility parameter")+1
	kFertilityParameters.StrategicYieldWeight	= 5 + TerrainBuilder.GetRandomNumber(5, "Random Fertility parameter")+1
	kFertilityParameters.LuxuriesYieldWeight	= 1 + TerrainBuilder.GetRandomNumber(2, "Random Fertility parameter")+1
	kFertilityParameters.FreshWaterFertility	= 0 + TerrainBuilder.GetRandomNumber(5, "Random Fertility parameter")+1
	
	for _, row in ipairs(GetPotentialTribePlots(kFertilityParameters)) do
		if placed < toPlace then
			local pPlot = GCO.GetPlotByIndex(row.PlotID)
			if CanPlaceTribe(pPlot) then -- At this point in code GetPotentialTribePlots() can't have checked that, as no tribe improvements are already placed
			
				local cultureID 	= pPlot:GetBestCultureGroup(bNoDuplicate)
				local tribePlayerID = cultureID and GetAvailableTribePlayerFor(cultureID)
				if tribePlayerID then
					Dprint( DEBUG_ALTHIST_SCRIPT, GCO.Separator)
					Dprint( DEBUG_ALTHIST_SCRIPT, " - Add Tribe settlements for Player #"..tostring(tribePlayerID), cultureID)
				
					InitializeTribePlayer(tribePlayerID, cultureID)
					
					placed = placed + 1
					kTribeParameters.Plot 		= pPlot
					kTribeParameters.CultureID	= cultureID
					kTribeParameters.PlayerID 	= tribePlayerID
					InitializeTribeAt(kTribeParameters)
				end
			end
		end
	end
	
	if placed < toPlace then
		Dprint( DEBUG_ALTHIST_SCRIPT, "- Not enough Tribe Player, asked for ", toPlace,", placed ",placed)
	end
	
	-- Place Barbarians settlements
	Dprint( DEBUG_ALTHIST_SCRIPT, "- Placing Barbarians Tribes...")
	local toPlace 	= (toPlace - placed) + (PlayerManager.GetAliveMajorsCount() * fBarbariansTribeFactor)
	local placed	= 0
	
	local kTribeParameters				= {}
	kTribeParameters.Range				= iMaxBarbSettlementDist
	kTribeParameters.MinSettlement		= 2
	kTribeParameters.MaxSettlement		= 4
	kTribeParameters.PlaceRoutes		= false
	kTribeParameters.GarrisonUnitType	= "UNIT_LIGHT_SPEARMAN"
		
	local kFertilityParameters					= {}
	kFertilityParameters.Range					= 4
	kFertilityParameters.ProductionYieldWeight	= 3 + TerrainBuilder.GetRandomNumber(2, "Random Fertility parameter")+1
	kFertilityParameters.FoodYieldWeight		= 1 + TerrainBuilder.GetRandomNumber(3, "Random Fertility parameter")+1
	kFertilityParameters.StrategicYieldWeight	= 3 + TerrainBuilder.GetRandomNumber(3, "Random Fertility parameter")+1
	kFertilityParameters.LuxuriesYieldWeight	= 0 + TerrainBuilder.GetRandomNumber(2, "Random Fertility parameter")+1
	kFertilityParameters.FreshWaterFertility	= 8 + TerrainBuilder.GetRandomNumber(8, "Random Fertility parameter")+1
	kFertilityParameters.RiverFertility			= 8 + TerrainBuilder.GetRandomNumber(8, "Random Fertility parameter")+1
	kFertilityParameters.CoastalLandFertility	= 9 + TerrainBuilder.GetRandomNumber(9, "Random Fertility parameter")+1
	
	for _, row in ipairs(GetPotentialTribePlots(kFertilityParameters)) do
		if placed < toPlace then
			local pPlot = GCO.GetPlotByIndex(row.PlotID)
			if CanPlaceTribe(pPlot) then -- At this point in code GetPotentialTribePlots() can't have checked that, as no tribe improvements are already placed

				Dprint( DEBUG_ALTHIST_SCRIPT, GCO.Separator)
				Dprint( DEBUG_ALTHIST_SCRIPT, "- Add Tribe settlements for barbarian")
				
				placed = placed + 1
				kTribeParameters.Plot 		= pPlot
				kTribeParameters.PlayerID 	= iBarbarianPlayer
				InitializeTribeAt(kTribeParameters)
			end
		end
	end
	
	-- Simulate a few turns of migration
	Dprint( DEBUG_ALTHIST_SCRIPT, GCO.Separator)
	Dprint( DEBUG_ALTHIST_SCRIPT, "- Simulating Migration for a few turns...")
	local iPlotCount	= Map.GetPlotCount()
	local iNumLoop 		= 25
	local tLandPlot		= {}
	
	for i = 0, iPlotCount - 1 do
		local plot = GCO.GetPlotByIndex(i)
		if not plot:IsWater() then
			table.insert(tLandPlot, plot)
		end
	end
	
	GCO.StartTimer("Simulating Migration")
	for iloop = 0, iNumLoop do
		Dprint( DEBUG_ALTHIST_SCRIPT, "- Migration loop #"..tostring(iloop))
		
		GCO.StartTimer("Setting Migration Values")
		for _, plot in ipairs(tLandPlot) do
			plot:SetMigrationValues()
		end
		GCO.ShowTimer("Setting Migration Values")
		
		if iloop == 0 then Dprint( DEBUG_ALTHIST_SCRIPT, "-  num. land plots = "..tostring(#tLandPlot)) end
		
		GCO.StartTimer("Doing Migration")
		for _, plot in ipairs(tLandPlot) do
			plot:DoMigration()
		end
		GCO.ShowTimer("Doing Migration")
	end
	GCO.ShowTimer("Simulating Migration")
	
	Game:SetProperty("TribeSettlementsInitialized", 1);
end

function OnImprovementOwnerChanged(iX, iY, iImprovementType, playerID, iA, iB)

	-- this reset improvement owner to -1 on reloading 1st turn ?

	--local DEBUG_ALTHIST_SCRIPT = "debug"
	---[[
	local pPlot		= GCO.GetPlot(iX, iY)
	local plotID 	= pPlot:GetIndex()
	local village	= GetTribalVillageAt(plotID) or SetTribalVillageAt(plotID)
	
	if village.Owner and village.Owner ~= playerID then -- captured, reset
		village.ProductionType	= nil
		village.TurnsLeft		= nil
		village.CentralPlot		= nil
	end
	
	village.Owner			= playerID
	village.Type			= iImprovementType
	village.Plot			= plotID
	local pPlayer			= Players[playerID]
	local bIsBarbarian		= pPlayer == nil and true or pPlayer:IsBarbarian() -- no player means "barbarian"
	village.ProductionType	= village.ProductionType or (bIsBarbarian and "PRODUCTION_EQUIPMENT") or "PRODUCTION_MATERIEL"
	
	Dprint( DEBUG_ALTHIST_SCRIPT, "- OnImprovementOwnerChanged at ", iX, iY, playerID, iImprovementType, iA, iB )
	Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", plotID, village, village.Type, village.Owner )
	Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", GetTribalVillageAt(plotID) )
	--]]
end


-- ===================================================================================== --
-- Actions & Productions
-- ===================================================================================== --

function CanCaravanSettle(pPlot, iPlayer)
	
	--local DEBUG_ALTHIST_SCRIPT = "debug"
	
	local bCanSettle 	= true
	local tReasonString	= {}
	local pPlayer		= GCO.GetPlayer(iPlayer)

	if pPlot and (not pPlot:IsImpassable()) and (not pPlot:IsNaturalWonder()) and (not pPlot:IsWater()) and pPlot:GetFeatureType() ~= GameInfo.Features["FEATURE_OASIS"].Index then
	
		if pPlot:GetImprovementType() ~= NO_IMPROVEMENT then
			table.insert(tReasonString, Locale.Lookup("LOC_MIGRATION_CANT_REPLACE_IMPROVEMENT"))
			bCanSettle = false
		end
		
		if pPlot:GetResourceCount() > 0 then
		
			bCanSettle 			= false
			local resourceID 	= pPlot:GetResourceType()
			
			if pPlayer:IsResourceVisible(resourceID) then
				local sResourceString = GCO.GetResourceIcon(resourceID) .. Locale.Lookup(GameInfo.Resources[resourceID].Name)
				table.insert(tReasonString, Locale.Lookup("LOC_MIGRATION_CANT_SETTLE_VISIBLE_RESOURCE", sResourceString))
			else
				table.insert(tReasonString, Locale.Lookup("LOC_MIGRATION_CANT_SETTLE_INVISIBLE_RESOURCE"))
			end
		end
		
		-- Check for being too close from somethings.
		local uniqueRange = 4
		local plotX = pPlot:GetX();
		local plotY = pPlot:GetY();
		for i, iPlotID in ipairs(GCO.GetPlotsInRange(pPlot, uniqueRange)) do
			local otherPlot = GCO.GetPlotByIndex(iPlotID)
			if(otherPlot) then
				if IsTribeImprovement(otherPlot:GetImprovementType()) then
					if otherPlot:GetImprovementOwner() ~= iPlayer then
						local village = GetTribalVillageAt(iPlotID)
						if village.Iscentral then
							table.insert(tReasonString, Locale.Lookup("LOC_MIGRATION_CANT_SETTLE_CLOSE_SETTLEMENT"))
							bCanSettle = false
						end
					end
				end
				if otherPlot:IsOwned() and otherPlot:GetOwner() == iPlayer then -- second check in case we continue to allow new settlements even after placing our first city 
					table.insert(tReasonString, Locale.Lookup("LOC_MIGRATION_CANT_SETTLE_CLOSE_TERRITORY"))
					bCanSettle = false
				end
				if otherPlot:IsCity() then
					table.insert(tReasonString, Locale.Lookup("LOC_MIGRATION_CANT_SETTLE_CLOSE_CITY"))
					bCanSettle = false
				end
			end
		end
	
		if not NoAdjacentVillage(pPlot) then
			table.insert(tReasonString, Locale.Lookup("LOC_MIGRATION_CANT_SETTLE_ADJACENT_SETTLEMENT"))
			bCanSettle = false
		end
	
	else 
		table.insert(tReasonString, Locale.Lookup("LOC_MIGRATION_CANT_SETTLE_HERE"))
		bCanSettle = false
	end
	return bCanSettle, table.concat(tReasonString, "[NEWLINE]")
end

function TribeCanDo(kParameters, row) -- bCanDo, bCanShow, sReason

	local sType 		= row.ProductionType or row.ActionType
	local pPlayer		= GCO.GetPlayer(kParameters.PlayerID)
	local village		= GetTribalVillageAt(kParameters.PlotID)
	local pVillagePlot	= GCO.GetPlotByIndex(kParameters.PlotID)
	local bCanDo		= true 
	local bCanShow		= true
	local tReasons		= {}
	local iDistance		= nil
	local centralPlotID	= (village.IsCentral and (not pVillagePlot:IsImprovementPillaged()) and kParameters.PlotID) or ((not pVillagePlot:IsImprovementPillaged()) and village.CentralPlot) or nil
	
	if centralPlotID == nil then
		centralPlotID, iDistance 	= GCO.FindNearestPlayerVillage( kParameters.PlayerID, pVillagePlot:GetX(), pVillagePlot:GetY())
	end
	
	if not centralPlotID then
		GCO.Error("Can't find centralPlot for TribeCanDo with [NEWLINE]Type: ".. tostring(sType).."[NEWLINE]PlayerID: "..tostring(kParameters.PlayerID).."[NEWLINE]PlotID: "..tostring(kParameters.PlotID) .."[NEWLINE]Position: ", pVillagePlot:GetX(), pVillagePlot:GetY())
	end
	
	local pCentralPlot 	= GCO.GetPlotByIndex(centralPlotID)
	local availablePop	= pCentralPlot:GetPopulation() - iMinPopulationLeft
	iDistance			= iDistance or (centralPlotID == kParameters.PlotID and 0) or (centralPlotID and Map.GetPlotDistance(kParameters.PlotID, centralPlotID))
	
	--
	-- Generic test
	-- 
	if row.IsCentral and not (village and village.IsCentral) then
		bCanDo		= false
		bCanShow	= false
		return bCanDo, bShow
	end
	
	if row.IsSatellite and village.CentralPlot == nil then --(centralPlotID ~= kParameters.PlotID) then
		bCanDo		= false
		bCanShow	= false
		return bCanDo, bShow
	end
	
	if row.IsBarbarian and not (pPlayer and pPlayer:IsBarbarian()) then
		bCanDo		= false
		bCanShow	= false
		return bCanDo, bShow
	end
	
	if row.NoBarbarian and (pPlayer and pPlayer:IsBarbarian()) then
		bCanDo		= false
		bCanShow	= false
		return bCanDo, bShow
	end
	
	-- Add the description if it exists before adding any Reasons disabling a task
	if row.Description then
		table.insert(tReasons, Locale.Lookup(row.Description))
	end
	
	if sType == village.ProductionType then
		bCanDo		= false
		table.insert(tReasons, Locale.Lookup("LOC_VILLAGE_PRODUCTION_ALREADY_SELECTED"))
	end
	
	--
	if pVillagePlot:IsImprovementPillaged() and not (sType == "VILLAGE_REBUILD" or sType == "CENTER_CAPTURE") then
		bCanDo	= false
		table.insert(tReasons, Locale.Lookup("LOC_NO_ACTION_VILLAGE_PILLAGED"))
	end
	
	if row.GoldCost and not (pPlayer and pPlayer:GetTreasury():GetGoldBalance() >= row.GoldCost) then
		bCanDo	= false
		if pPlayer then 
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_GOLD",row.GoldCost-pPlayer:GetTreasury():GetGoldBalance()))
		end
	end
	
	if row.MaterielCost and pCentralPlot:GetStock(materielResourceID) < row.MaterielCost then
		bCanDo	= false
		table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_MATERIEL",row.MaterielCost-pCentralPlot:GetStock(materielResourceID)))
	end
	
	-- Manually add Settler Population cost (defined from unitEquipmentClasses)
	if sType == "CREATE_CITY" or sType == "CREATE_SETTLER" then
		row.PopulationCost = iPopulationForSettler
	end
	
	if row.PopulationCost and availablePop < row.PopulationCost then
		bCanDo	= false
		table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_POPULATION",row.PopulationCost-availablePop))
	end
	
	-- 
	if sType == "VILLAGE_REBUILD" or sType == "CENTER_CAPTURE" then
		if not pVillagePlot:IsImprovementPillaged() then
			bCanDo		= false
			bCanShow	= false
			return bCanDo, bShow
		end
	end
	
	--
	-- Specific Tests
	--
	
	-- Create Units
	local UnitCreation = UnitCreationType[sType]
	if UnitCreation then
		
		local minRatio			= 0.5
		local promotionClassID	= GameInfo.UnitPromotionClasses[UnitCreation.PromotionClass].Index
		local unitOrganization	= militaryOrganization[TribeOrganizationLevel][promotionClassID]
		local minPersonnel 		= unitOrganization.FrontLinePersonnel * minRatio
		local plotEquipment		= {}
		row.PopulationCost 		= unitOrganization.FrontLinePersonnel
		
		for resourceKey, value in pairs(pCentralPlot:GetResources()) do
			local resourceID = tonumber(resourceKey)
			if GCO.IsResourceEquipment(resourceID) then
				plotEquipment[resourceID] = value
			end
		end
		
		if availablePop < minPersonnel then
			bCanDo	= false
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_POPULATION",minPersonnel-availablePop))
		elseif availablePop < unitOrganization.FrontLinePersonnel then
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_POPULATION_REQUIRED_FOR_UNIT_BELOW", availablePop, unitOrganization.FrontLinePersonnel))
		else
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_POPULATION_REQUIRED_FOR_UNIT_MAX", unitOrganization.FrontLinePersonnel, unitOrganization.FrontLinePersonnel))
		end		
		
		local unitID 			= GameInfo.Units[UnitCreation.BaseUnitType].Index
		local baseResTable 		= GCO.GetUnitConstructionOrResources(unitID, TribeOrganizationLevel)
		local unitEquipment		= GCO.GetAvailableEquipmentForUnitPromotionClassFromList(unitID, promotionClassID, unitOrganization.FrontLinePersonnel, plotEquipment, TribeOrganizationLevel)
		local recruitType		= GCO.GetUnitTypeFromEquipmentList(promotionClassID, unitEquipment, unitID, 50, TribeOrganizationLevel)
		local bUseRecruit		= false
		local bUseBaseunit		= true
		local tRecruitString	= {}
		local tBaseString	= {}
		if recruitType then
			--unitID = recruitType
			bUseRecruit			= true
			local resOrTable 	= GCO.GetUnitConstructionOrResources(recruitType, TribeOrganizationLevel)
			for equipmentClass, resourceTable in pairs(resOrTable) do
				local totalNeeded 		= resourceTable.Value
				local available			= GCO.GetNumEquipmentOfClassInList(equipmentClass, plotEquipment)
				if available < totalNeeded * 0.35 then
					bUseRecruit	= false
					break
				elseif available < totalNeeded then
					table.insert(tRecruitString, "[COLOR_OperationChance_Orange]"..Locale.Lookup("LOC_TRIBE_ACTION_RESOURCE_NEEDED_TOTAL", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, available, totalNeeded ).."[ENDCOLOR]")
				else
					table.insert(tRecruitString, Locale.Lookup("LOC_TRIBE_ACTION_RESOURCE_NEEDED_TOTAL", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, available, totalNeeded ))
				end
			end
		end
			
		if bUseRecruit then
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_ENOUGH_EQUIPMENT_RECRUIT", GameInfo.Units[recruitType].Name))
			for _, sEquipmentString in ipairs(tRecruitString) do 
				table.insert(tReasons, sEquipmentString)
			end
		else
		
			for equipmentClass, resourceTable in pairs(baseResTable) do
				local totalNeeded 		= resourceTable.Value
				local available			= GCO.GetNumEquipmentOfClassInList(equipmentClass, plotEquipment)
				if available < totalNeeded * 0.35 then
					bUseBaseunit	= false
					table.insert(tBaseString, "[COLOR_Civ6Red]"..Locale.Lookup("LOC_TRIBE_ACTION_RESOURCE_NEEDED_TOTAL", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, available, totalNeeded ).."[ENDCOLOR]")
				elseif available < totalNeeded then
					table.insert(tBaseString, "[COLOR_OperationChance_Orange]"..Locale.Lookup("LOC_TRIBE_ACTION_RESOURCE_NEEDED_TOTAL", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, available, totalNeeded ).."[ENDCOLOR]")
				else
					table.insert(tBaseString, Locale.Lookup("LOC_TRIBE_ACTION_RESOURCE_NEEDED_TOTAL", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, available, totalNeeded ))
				end
			end
			
			if not bUseBaseunit then
				bCanDo = false
				table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_EQUIPMENT_RECRUIT", GameInfo.Units[unitID].Name))
			else
				table.insert(tReasons, Locale.Lookup("LOC_TRIBE_ENOUGH_EQUIPMENT_RECRUIT", GameInfo.Units[unitID].Name))
			end
			
			for _, sEquipmentString in ipairs(tBaseString) do 
				table.insert(tReasons, sEquipmentString)
			end
		end

	--
	elseif sType == "VILLAGE_REBUILD" then
	
		local settlers	= GetPopulationMigrationPerTurnForVillage(pCentralPlot, row)
		table.insert(tReasons, Locale.Lookup("LOC_VILLAGE_POPULATION_MIGRATION_PER_TURN",settlers))
		
		if village.IsCentral then
			bCanDo		= false
			bCanShow	= false
			return bCanDo, bShow
		end
		
		if iDistance > iMaxSettlementDistance then -- to do
			bCanDo		= false
			table.insert(tReasons, Locale.Lookup("LOC_VILLAGE_TO_FAR_FOR_REBUILD",iDistance-iMaxSettlementDistance))
		end
		
	--
	elseif sType == "VILLAGE_CREATE" then
	
		local settlers	= GetPopulationMigrationPerTurnForVillage(pCentralPlot, row)
		table.insert(tReasons, Locale.Lookup("LOC_VILLAGE_POPULATION_MIGRATION_PER_TURN",settlers))
		
	--
	elseif sType == "PRODUCTION_GOLD" then
	
		local bHasEnoughLuxury 	= false
		local iLuxuries			= 0
		for resourceKey, value in pairs(pCentralPlot:GetResources()) do
			local resourceID = tonumber(resourceKey)
			if GCO.IsResourceLuxury(resourceID) and value > 0 then
				bHasEnoughLuxury	= true
				iLuxuries			= iLuxuries + math.min(value, iMaxLuxuriesPerTurn)
			end
		end
		if bHasEnoughLuxury then
			local iMaxGold = iGoldPerLuxury * iLuxuries
			table.insert(tReasons, Locale.Lookup("LOC_VILLAGE_MAX_GOLD_FROM_LUXURIES", iMaxGold))
		else
			bCanDo		= false
			table.insert(tReasons, Locale.Lookup("LOC_VILLAGE_NO_LUXURIES"))
		end
		
	--	
	elseif sType == "RESEARCH_SAILING" then

		if not pCentralPlot:IsCoastalLand() then
			bCanDo		= false
			bCanShow	= false
			return bCanDo, bShow
		end
	--	
	elseif sType == "RESEARCH_BRONZE_WORKING" then

		local copperID = GameInfo.Resources["RESOURCE_COPPER"].Index
		
		if pCentralPlot:GetStock(copperID) == 0 then
			bCanDo		= false
			bCanShow	= false
			return bCanDo, bShow
		end
	--	
	elseif sType == "RESEARCH_HORSEBACK_RIDING" then

		local horsesResourceID 	= GameInfo.Resources["RESOURCE_HORSES"].Index
		
		if pCentralPlot:GetStock(horsesResourceID) == 0 then
			bCanDo		= false
			bCanShow	= false
			return bCanDo, bShow
		end
		
	--	
	elseif sType == "START_MIGRATION" then
		
		if pCentralPlot:GetPopulation() < iPopulationForCaravan then
			bCanDo	= false
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_POPULATION",iPopulationForCaravan-pCentralPlot:GetPopulation()))
		end
		
	--	
	elseif sType == "CREATE_WORKER" then
	
		if pCentralPlot:GetStock(slaveClassID) < iNumSlavesForWorker then
			bCanDo	= false
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_SLAVES",iNumSlavesForWorker-pCentralPlot:GetStock(slaveClassID)))
		end
		
	--	
	elseif sType == "CREATE_CITY" then
	
		local cultureID	= GCO.GetCultureIDFromPlayerID(kParameters.PlayerID)
		
		if pCentralPlot:GetCulturePercent(cultureID) < iMinCulturePercentCity then
			bCanDo	= false
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_PERCENT_OF_ETHNIC_POPULATION",iMinCulturePercentCity-pCentralPlot:GetCulturePercent(cultureID), GameInfo.CultureGroups[cultureID].Adjective) )
		end
		
	--	
	elseif sType == "CREATE_SETTLER" then
	
		local cultureID	= GCO.GetCultureIDFromPlayerID(kParameters.PlayerID)
		if pCentralPlot:GetCulture(cultureID) < row.PopulationCost then
			bCanDo	= false
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_ETHNIC_POPULATION",row.PopulationCost-pCentralPlot:GetCulture(cultureID), GameInfo.CultureGroups[cultureID].Adjective) )
		end
		
		if pCentralPlot:GetCulturePercent(cultureID) < iMinCulturePercentSettler then
			bCanDo	= false
			table.insert(tReasons, Locale.Lookup("LOC_TRIBE_NO_ENOUGH_PERCENT_OF_ETHNIC_POPULATION",iMinCulturePercentSettler-pCentralPlot:GetCulturePercent(cultureID), GameInfo.CultureGroups[cultureID].Adjective) )
		end
	
	--	
	elseif sType == "POPULATION_EMIGRATION" or sType == "POPULATION_IMMIGRATION" then
		local tVillages 		= GetPlayerTribalVillages(kParameters.PlayerID)
		local bHasOtherVillage	= false
		for _, plotKey in ipairs(tVillages) do
		
			local otherVillage	= GetTribalVillageAt( tonumber(plotKey))
			if otherVillage.CentralPlot == centralPlotID then
				bHasOtherVillage = true
			end
		end
		
		if bHasOtherVillage == false then
			bCanDo		= false
			table.insert(tReasons, Locale.Lookup("LOC_VILLAGE_NO_OTHER_VILLAGE"))
		end
		
		
	--
	end
	
	
	return bCanDo, bCanShow, table.concat(tReasons, "[NEWLINE]")
end



-- ====================================================================================== --
-- Handle Player Commands
-- ====================================================================================== --

function OnPlayerTribeDo(iActor : number, kParameters : table)
	return GCO.Monitor(OnPlayerTribeDoP, {iActor, kParameters}, "OnPlayerTribeDo")
end

function OnPlayerTribeDoP(iActor : number, kParameters : table)
	
	local DEBUG_ALTHIST_SCRIPT = "debug"
	
	Dprint( DEBUG_ALTHIST_SCRIPT, "- OnPlayerTribeDo...")
	Dprint( DEBUG_ALTHIST_SCRIPT, iActor, kParameters.PlotID, kParameters.TargetID, kParameters.Type)

	kParameters.PlayerID	= iActor
	local bActionResult		= true
	local row 				= GameInfo.TribalVillageProductions[kParameters.Type] or GameInfo.TribalVillageActions[kParameters.Type]
	
	-- Special case
	if kParameters.Type == "CREATE_NEW_SETTLEMENT" then
	
		local pPlot = GCO.GetPlotByIndex(kParameters.PlotID)
		
		if CanCaravanSettle(pPlot, iActor) then
		
			local sImprovementType	= "IMPROVEMENT_BARBARIAN_CAMP_GCO"
			
			ImprovementBuilder.SetImprovementType(pPlot, GameInfo.Improvements[sImprovementType].Index, iActor)
			
			local pPlayer			= GCO.GetPlayer(iActor)
			local village 			= SetTribalVillageAt(kParameters.PlotID)
			village.IsCentral		= true
			village.Owner			= iActor
			village.Type			= sImprovementType
			local bIsBarbarian		= pPlayer:IsBarbarian()
			village.ProductionType	= (bIsBarbarian and "PRODUCTION_EQUIPMENT") or "PRODUCTION_MATERIEL"
			local pCaravanUnit		= GCO.GetUnit(iActor, kParameters.UnitID)
			local pPlayerUnits 		= pPlayer:GetUnits()
			
			pCaravanUnit:SetValue("SupplyLineCityKey", tostring(kParameters.PlotID)) -- Set this plot as the target plot when disbanding
			pCaravanUnit:Disband()
			pPlayerUnits:Destroy(pCaravanUnit)
			ExposedMembers.UnitData[pCaravanUnit:GetKey()] = nil
			pPlayer:SetValue("MigrationTurn", nil)
		else
			GCO.Error("PlayerTribeDo called with invalid or disabled Type[NEWLINE]Type: ".. tostring(kParameters.Type).."[NEWLINE]PlayerID: "..tostring(kParameters.PlayerID) .."[NEWLINE]PlotID: "..tostring(kParameters.PlotID))
		end
	--
	elseif TribeCanDo(kParameters, row) then
	
		local village	= GetTribalVillageAt(kParameters.PlotID)
		local pPlot		= GCO.GetPlotByIndex(kParameters.PlotID)
		
		-- Special case : Create Village
		if kParameters.Type == "VILLAGE_CREATE" then
			local pLocalPlayerVis 	= PlayersVisibility[iActor]
			local placementPlot 	= GCO.GetPlotByIndex(kParameters.TargetID)
			local roadPath			= pPlot:GetRoadPath(placementPlot, "Land", 6)
			local bCanPlace			= roadPath and CanPlaceTribe(placementPlot, 2, iActor) and GCO.NoAdjacentImprovement(placementPlot) and pLocalPlayerVis:IsRevealed(placementPlot:GetX(), placementPlot:GetY())
			if not bCanPlace then
				GCO.Error("PlayerTribeDo called with invalid village placement position[NEWLINE]Type: ".. tostring(kParameters.Type).."[NEWLINE]PlayerID: "..tostring(kParameters.PlayerID).."[NEWLINE]PlotID: "..tostring(kParameters.PlotID) .."[NEWLINE]Position: ",pPlot:GetX(), pPlot:GetY())
				return false
			end
			RouteBuilder.SetRouteType(placementPlot, 1) -- to do : select route type
		end
		
		if village == nil then
			GCO.Error("PlayerTribeDo called with invalid village position[NEWLINE]Type: ".. tostring(kParameters.Type).."[NEWLINE]PlayerID: "..tostring(kParameters.PlayerID).."[NEWLINE]PlotID: "..tostring(kParameters.PlotID) .."[NEWLINE]Position: ",pPlot:GetX(), pPlot:GetY())
			return
		end
		
		--
		-- Production
		--
		if row.ProductionType then
			village.ProductionPlot	= kParameters.TargetID -- can be nil
			village.ProductionType	= kParameters.Type
			village.TurnsLeft		= row.BaseTurns
			
		--
		-- Action
		--
		elseif row.ActionType then
		
			-- Create Unit
			local UnitCreation = UnitCreationType[kParameters.Type]
			if UnitCreation then
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "  - Creating new Unit ", UnitCreation.BaseUnitType)
			
				local promotionClassID	= GameInfo.UnitPromotionClasses[UnitCreation.PromotionClass].Index
				local unitOrganization	= militaryOrganization[TribeOrganizationLevel][promotionClassID]
				local plotPopulation	= pPlot:GetPopulation()
				local personnel 		= math.min(unitOrganization.FrontLinePersonnel, plotPopulation - iMinPopulationLeft) -- TribeCanDo should have already checked there is enough Population
				local resourceList		= {}
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "  - Full plot equipment list : ", UnitCreation.BaseUnitType)
				for resourceKey, value in pairs(pPlot:GetResources()) do
					local resourceID = tonumber(resourceKey)
					if GCO.IsResourceEquipment(resourceID) then
						resourceList[resourceID] = value
						Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), value)
					end
				end
				
				local unitID 				= GameInfo.Units[UnitCreation.BaseUnitType].Index
				local equipmentList			= GCO.GetAvailableEquipmentForUnitPromotionClassFromList(unitID, promotionClassID, personnel, resourceList, TribeOrganizationLevel)
				local sortedEquipmentList 	= GCO.SortEquipmentList(equipmentList)

				local unit = GCO.CreateUnitWithEquipmentList(unitID, iActor, pPlot:GetX(), pPlot:GetY(), personnel, sortedEquipmentList, TribeOrganizationLevel)
				if unit then
					-- << should this section be its own function ?
					unit:SetValue("HomeCityKey", tostring(kParameters.PlotID))
					unit:InitializeCultureFromPlot(pPlot)
					Dprint( DEBUG_ALTHIST_SCRIPT, "  - Unit creation equipment list : ", UnitCreation.BaseUnitType)
					for resourceKey, value in pairs(equipmentList) do
						local resourceID = tonumber(resourceKey)
						pPlot:ChangeStock(resourceID, -value)
						Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), value)
					end
					pPlot:MatchCultureToPopulation(plotPopulation - personnel)
					LuaEvents.TribeImprovementUpdated(iActor, kParameters.PlotID)
					if not kParameters.AI then
						LuaEvents.RefreshActionScreenGCO()
					end
					return true
					-- >>
				else
					GCO.Error("PlayerTribeDo failed to initialize unit[NEWLINE]Type: ".. tostring(kParameters.Type).."[NEWLINE]PlayerID: "..tostring(kParameters.PlayerID).."[NEWLINE]UnitType: "..tostring(UnitCreation.BaseUnitType) )
				end
				
			--	Create Worker
			elseif row.ActionType == "CREATE_WORKER" then
				local pUnit = UnitManager.InitUnit(iActor, "UNIT_WORKER", pPlot:GetX(), pPlot:GetY())
				--pUnit:InitializeCultureFromPlot(pPlot) -- slave does not belong to any culture group
				pPlot:ChangeStock(slaveClassID, -iNumSlavesForWorker)
				
			--	Start Migration
			elseif row.ActionType == "START_MIGRATION" then
				
				local pUnit = UnitManager.InitUnit(iActor, "UNIT_CARAVAN", pPlot:GetX(), pPlot:GetY())
				
				GCO.AttachUnitFunctions(pUnit)
				GCO.RegisterNewUnit(iActor, pUnit)
	
				pUnit:InitializeCultureFromPlot(pPlot)
				
				local plotMigrants	= math.max(math.floor(pPlot:GetPopulation()*iStartingMigrationRate), iPopulationForCaravan)
				
				Dprint( DEBUG_ALTHIST_SCRIPT, "- initializing Caravan with Migrants from Base Plot = ", plotMigrants)
				
				pUnit:GetPopulationFromPlot(pPlot, plotMigrants) -- handle both change in values (including culture percents) for the unit and the plot
				
				for resourceKey, value in pairs(pPlot:GetResources()) do
					local resourceID = tonumber(resourceKey)
					pUnit:ChangeStock(resourceID,value)
					pPlot:ChangeStock(resourceID,-value)
					Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), value)
				end
				
				ImprovementBuilder.SetImprovementPillaged(pPlot, true)
				village.PillagedCounter = 0
				LuaEvents.TribeImprovementUpdated(iActor, kParameters.PlotID)
				
				local tVillages 		= GetPlayerTribalVillages(iActor)
				for _, plotKey in ipairs(tVillages) do
					local otherPlotID	= tonumber(plotKey)
					local otherVillage	= GetTribalVillageAt(otherPlotID)
					if otherVillage.CentralPlot == kParameters.PlotID then
						local otherPlot 	= GCO.GetPlotByIndex(otherPlotID)
						local plotMigrants	= math.floor(otherPlot:GetPopulation()*iStartingMigrationRate)
						
						Dprint( DEBUG_ALTHIST_SCRIPT, "- Adding Migrants from Other Village = ", plotMigrants)
						
						pUnit:GetPopulationFromPlot(otherPlot, plotMigrants)
						
						for resourceKey, value in pairs(otherPlot:GetResources()) do
							local resourceID = tonumber(resourceKey)
							pUnit:ChangeStock(resourceID,value)
							otherPlot:ChangeStock(resourceID,-value)
							Dprint( DEBUG_ALTHIST_SCRIPT, "    - ", Locale.Lookup(GameInfo.Resources[resourceID].Name), value)
						end
						
						ImprovementBuilder.SetImprovementPillaged(otherPlot, true)
						otherVillage.PillagedCounter 	= 0
						otherVillage.CentralPlot 		= nil
						LuaEvents.TribeImprovementUpdated(iActor, otherPlotID)
					end
				end
				
				local pPlayer = GCO.GetPlayer(iActor)
				pPlayer:SetValue("MigrationTurn", Game.GetCurrentGameTurn())
				LuaEvents.UnitsCompositionUpdated(unitOwner, unitID)
				
			--	Create City
			elseif row.ActionType == "CREATE_CITY" then
				
				-- Remove Materiel used from the Plot
				pPlot:ChangeStock(materielResourceID, -row.MaterielCost)
				
				local pPlayer	= GCO.GetPlayer(iActor)
				local pCity		= pPlayer:GetCities():Create(pPlot:GetX(), pPlot:GetY())
				
				GCO.AttachCityFunctions(pCity)
				GCO.RegisterNewCity(iActor, pCity, 0) -- Immediatly register the city without extra population
				
				-- to do : remove village center, satellite should still use plotkey ?
				-- to do implement trade for village <-> city, resources from villages should not be free
				--GetSatelliteVillages(centralPlotID)
				RemoveTribalVillageAt(kParameters.PlotID) 
				
			--	Create Settler
			elseif row.ActionType == "CREATE_SETTLER" then
				
				-- Remove Materiel used from the Plot
				pPlot:ChangeStock(materielResourceID, -row.MaterielCost)
				
				local pUnit = UnitManager.InitUnit(iActor, "UNIT_SETTLER", pPlot:GetX(), pPlot:GetY())
				
				GCO.AttachUnitFunctions(pUnit)
				GCO.RegisterNewUnit(iActor, pUnit)
	
				pUnit:InitializeCultureFromPlot(pPlot)
				pUnit:GetPopulationFromPlot(pPlot, row.PopulationCost)
			end
		
		else
			GCO.Error("PlayerTribeDo called with undefined Type[NEWLINE]Type: ".. tostring(kParameters.Type).."[NEWLINE]PlayerID: "..tostring(kParameters.PlayerID).."[NEWLINE]ProductionType: "..tostring(row.ProductionType) .."[NEWLINE]ActionType: "..tostring(kParameters.ActionType))
			return false
		end
		
		-- Handle cost
		if row.GoldCost then
			local pPlayer = GCO.GetPlayer(iActor)
			pPlayer:ProceedTransaction(AccountType.Production, -row.GoldCost)
		end
		
		if not kParameters.AI then
			LuaEvents.RefreshActionScreenGCO()
		end
	else
		if not kParameters.AI then
			GCO.Error("PlayerTribeDo called with invalid or disabled Type[NEWLINE]Type: ".. tostring(kParameters.Type).."[NEWLINE]PlayerID: "..tostring(kParameters.PlayerID) .."[NEWLINE]PlotID: "..tostring(kParameters.PlotID))
		else
			return false
		end
	end
	return bActionResult
end
GameEvents.PlayerTribeDo.Add(OnPlayerTribeDo)

-- ===================================================================================== --
-- Initialize script
-- ===================================================================================== --
function Initialize()
	
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- 
	ExposedMembers.GCO.HasCultureGroupSpawned 	= HasCultureGroupSpawned
	ExposedMembers.GCO.SetCultureGroupSpawned 	= SetCultureGroupSpawned
	ExposedMembers.GCO.IsTribeImprovement		= IsTribeImprovement
	ExposedMembers.GCO.CanPlaceTribe			= CanPlaceTribe
	--
	ExposedMembers.GCO.IsCultureGroupAvailableForPlot		= IsCultureGroupAvailableForPlot
	ExposedMembers.GCO.IsCultureGroupAvailableForContinent	= IsCultureGroupAvailableForContinent
	ExposedMembers.GCO.IsCultureGroupAvailableForEthnicity	= IsCultureGroupAvailableForEthnicity
	ExposedMembers.GCO.GetTribePlayerCulture		 		= GetTribePlayerCulture
	--
	ExposedMembers.GCO.GetPlayerTribalVillages	= GetPlayerTribalVillages
	ExposedMembers.GCO.GetTribalVillageAt		= GetTribalVillageAt
	ExposedMembers.GCO.GetTribeOutputFactor		= GetTribeOutputFactor
	ExposedMembers.GCO.TribesTurn				= TribesTurn
	--
	ExposedMembers.GCO.TribeCanProduce			= TribeCanProduce
	ExposedMembers.GCO.TribeCanDoAction			= TribeCanDoAction
	ExposedMembers.GCO.TribeCanDo				= TribeCanDo
	ExposedMembers.GCO.CanCaravanSettle			= CanCaravanSettle
	ExposedMembers.GCO.OnPlayerTribeDo			= OnPlayerTribeDo
	
end
Initialize()