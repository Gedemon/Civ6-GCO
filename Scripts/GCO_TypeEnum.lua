--=====================================================================================--
--	FILE:	 GCO_TypeEnum.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_TypeEnum.lua...")


--=====================================================================================--
-- Diplomacy Table Types
--=====================================================================================--
DiplomacyTypes	= {	-- ENUM for Diplomacy Table Types (string as it it used as a key for saved table)
		Deals		= "1",
		Treaties	= "2",
		State		= "3",
}


--=====================================================================================--
-- Gossips SubTypes
--=====================================================================================--

GossipsSubType	= {	-- ENUM for StatusMessage Subtypes - to do: loop on the Gossips table and get the first index from GroupType instead of using GossipType that may change in patches/mods
		Science			= GameInfo.Gossips["GOSSIP_ERA_CHANGED"].Index,
		Military		= GameInfo.Gossips["GOSSIP_CONQUER_CITY"].Index,
		Religion		= GameInfo.Gossips["GOSSIP_CREATE_PANTHEON"].Index,
		City			= GameInfo.Gossips["GOSSIP_CONSTRUCT_BUILDING"].Index,
		Culture			= GameInfo.Gossips["GOSSIP_CHANGE_GOVERNMENT"].Index,
		Diplomacy		= GameInfo.Gossips["GOSSIP_DELEGATION"].Index,
		Discover		= GameInfo.Gossips["GOSSIP_FIND_NATURAL_WONDER"].Index,
		Espionage		= GameInfo.Gossips["GOSSIP_SPY_SIPHON_FUNDS"].Index,
		GreatPerson		= GameInfo.Gossips["GOSSIP_GREATPERSON_CREATED"].Index,
		Settlement		= GameInfo.Gossips["GOSSIP_FOUND_CITY"].Index,
		Victory			= GameInfo.Gossips["GOSSIP_SPACE_RACE_PROJECT_COMPLETED"].Index,
}
--=====================================================================================--
-- Treasury
--=====================================================================================--
AccountType	= {	-- ENUM for treasury changes (string as it it used as a key for saved table)

		Production 			= "1",	-- Expense for city Production
		Reinforce			= "2",	-- Expense for unit Reinforcement
		BuildingMaintenance	= "4",	-- Expense for buildings Maintenance (vanilla)
		UnitMaintenance		= "5",	-- Expense for units Maintenance (vanilla)
		DistrictMaintenance	= "6",	-- Expense for district Maintenance (vanilla)
		Repair				= "11",	-- Expense for healing city garrison or walls
		Repay				= "12",	-- Expense for repaying the debt
		Recruit				= "15",	-- Expense for recruiting units
		
		ImportTaxes			= "7",	-- Income from Import Taxes
		ExportTaxes			= "8",	-- Income from Export Taxes
		Plundering			= "9",	-- Income from units Plundering
		CityTaxes			= "10",	-- Income from City Taxes (vanilla)
		UpperTaxes			= "13",	-- Income from Taxes on Upper Class
		MiddleTaxes			= "14",	-- Income from Taxes on Middle Class
}


--=====================================================================================--
-- Trade
--=====================================================================================--
TradeLevelType	= {	-- ENUM for trade route level types

		Limited 	= 1,	-- Trade Limited to non-luxury food
		Neutral		= 2,	-- No strategic resources or equipment trade
		Friend		= 3,	-- Trade All except equipment
		Allied		= 4,	-- Trade All
}


--=====================================================================================--
-- Units
--=====================================================================================--
UnitPersonnelType	= {	-- ENUM for type of Unit

		StandingArmy 	= 1,	-- Permanent units
		Conscripts		= 2,	-- Temporary units, built in city based on personnel/equipment available in the city
		Mercenary		= 3,	-- Temporary units, bought in city, not linked to any city
}


--=====================================================================================--
-- Cities
--=====================================================================================--

ProductionTypes = {
		UNIT		= 0,
		BUILDING	= 1,
		DISTRICT 	= 2
	}
	
SupplyRouteType	= {	-- ENUM for resource trade/transfer route types
		Trader 	= 1,
		Road	= 2,
		River	= 3,
		Coastal	= 4,
		Ocean	= 5,
		Airport	= 6
}
	
--=====================================================================================--
-- Resources - to do : those are helpers, to move to mod utils with related functions
--=====================================================================================--
IsImprovementForResource		= {} -- cached table to check if an improvement is meant for a resource
ResourceImprovementID			= {} -- cached table with improvementID meant for resourceID
for row in GameInfo.Improvement_ValidResources() do
	local improvementID = GameInfo.Improvements[row.ImprovementType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not IsImprovementForResource[improvementID] then IsImprovementForResource[improvementID] = {} end
	if not ResourceImprovementID[resourceID] then ResourceImprovementID[resourceID] = {} end
	IsImprovementForResource[improvementID][resourceID] = true
	ResourceImprovementID[resourceID] = improvementID
end
-- Special cases
local resourceWoodID	= GameInfo.Resources["RESOURCE_WOOD"].Index
local resourcePlantsID	= GameInfo.Resources["RESOURCE_PLANTS"].Index
local resourceClayID	= GameInfo.Resources["RESOURCE_CLAY"].Index
local lumberMillsID		= GameInfo.Improvements["IMPROVEMENT_LUMBER_MILL"].Index
local plantationID		= GameInfo.Improvements["IMPROVEMENT_PLANTATION"].Index
local quarryID			= GameInfo.Improvements["IMPROVEMENT_QUARRY"].Index
IsImprovementForResource[lumberMillsID] 					= {[resourceWoodID] 	= true}
IsImprovementForResource[plantationID][resourcePlantsID] 	= true
IsImprovementForResource[quarryID][resourceClayID] 			= true
ResourceImprovementID[resourceWoodID] 						= lumberMillsID
ResourceImprovementID[resourcePlantsID] 					= plantationID
ResourceImprovementID[resourceClayID] 						= quarryID

IsImprovementForFeature			= {} -- cached table to check if an improvement is meant for a feature
for row in GameInfo.Improvement_ValidFeatures() do
	local improvementID = GameInfo.Improvements[row.ImprovementType].Index
	local featureID 	= GameInfo.Features[row.FeatureType].Index
	if not IsImprovementForFeature[improvementID] then IsImprovementForFeature[improvementID] = {} end
	IsImprovementForFeature[improvementID][featureID] = true
end

FeatureResources				= {} -- cached table to list resources produced by a feature
for row in GameInfo.FeatureResourcesProduced() do
	local featureID		= GameInfo.Features[row.FeatureType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not FeatureResources[featureID] then FeatureResources[featureID] = {} end
	table.insert(FeatureResources[featureID], {[resourceID] = row.NumPerFeature})
end

TerrainResources				= {} -- cached table to list resources available on a terrain
for row in GameInfo.TerrainResourcesProduced() do
	local terrainID		= GameInfo.Terrains[row.TerrainType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not TerrainResources[terrainID] then TerrainResources[terrainID] = {} end
	table.insert(TerrainResources[terrainID], {[resourceID] = row.NumPerTerrain})
end

BaseImprovementMultiplier		= tonumber(GameInfo.GlobalParameters["RESOURCE_BASE_IMPROVEMENT_MULTIPLIER"].Value)

ResourceUseType	= {	-- ENUM for resource use types (string as it it used as a key for saved table)
		Collect 	= "1",	-- Resources from map (ref = PlotID)
		Consume		= "2",	-- Used by population or local industries (ref = PopulationType or buildingID or cityKey)
		Product		= "3",	-- Produced by buildings (industrie) (ref = buildingID)
		Import		= "4",	-- Received from foreign cities (ref = cityKey)
		Export		= "5",	-- Send to foreign cities (ref = cityKey)
		TransferIn	= "6",	-- Received from own cities (ref = cityKey)
		TransferOut	= "7",	-- Send to own cities (ref = cityKey)
		Supply		= "8",	-- Send to units (ref = unitKey)
		Pillage		= "9",	-- Received from units (ref = unitKey)
		OtherIn		= "10",	-- Received from undetermined source
		OtherOut	= "11",	-- Send to undetermined source
		Waste		= "12",	-- Destroyed (excedent, ...)
		Recruit		= "13",	-- Recruit Personnel
		Demobilize	= "14",	-- Personnel send back to civil life
		Stolen		= "15", -- Stolen by units (ref = unitKey)
}

ReferenceType = { 	-- ENUM for reference types used to determine resource uses
	Unit			= 1,
	City			= 2,
	Plot			= 3,
	Population		= 4,
	Building		= 5,
	PopOrBuilding	= 99,
}

ResourceUseTypeReference	= {	-- Helper to get the reference type for a specific UseType
	[ResourceUseType.Collect] 		= ReferenceType.Plot,
	[ResourceUseType.Consume] 		= ReferenceType.PopOrBuilding, -- special case, PopulationType (string) or BuildingID (number)
	[ResourceUseType.Product] 		= ReferenceType.Building,
	[ResourceUseType.Import] 		= ReferenceType.City,
	[ResourceUseType.Export] 		= ReferenceType.City,
	[ResourceUseType.TransferIn] 	= ReferenceType.City,
	[ResourceUseType.TransferOut] 	= ReferenceType.City,
	[ResourceUseType.Supply] 		= ReferenceType.Unit,
	[ResourceUseType.Pillage] 		= ReferenceType.Unit,
	[ResourceUseType.Recruit] 		= ReferenceType.Population,
	[ResourceUseType.Demobilize] 	= ReferenceType.Population,
	[ResourceUseType.Stolen] 		= ReferenceType.Unit,
}

ProductionSettingsType = { -- ENUM to save/get Buildings resources production settings 
	SingleToSingle	= "1",
	SingleToMulti	= "2",
	MultiToSingle	= "3",
	SingleFromList	= "4",
}

UnitEquipmentSettings = { -- ENUM to save/get Buildings resources production settings 
	Use			= nil, -- save time by limiting table size for serialization
	NoSupply	= "2",
	NoUse		= "3",
}

--=====================================================================================--
-- Equipment - to do : those are helpers, to move to mod utils with related functions ?
--=====================================================================================--
EquipmentInfo = {}	-- Helper to get equipment info from Resource ID
for row in GameInfo.Equipment() do
	local equipmentType = row.ResourceType
	local equipmentID	= GameInfo.Resources[equipmentType].Index
	EquipmentInfo[equipmentID] = row
end

promotionClassEquipmentClasses	= {}
for row in GameInfo.PromotionClassEquipmentClasses() do
	local equipmentClass	= row.EquipmentClass
	local promotionType		= row.PromotionClassType 
	local promotionID 		= GameInfo.UnitPromotionClasses[promotionType].Index
	if GameInfo.EquipmentClasses[equipmentClass] then
		local equipmentClassID 	= GameInfo.EquipmentClasses[equipmentClass].Index
		if not promotionClassEquipmentClasses[promotionID] then promotionClassEquipmentClasses[promotionID] = {} end
		promotionClassEquipmentClasses[promotionID][equipmentClassID] = {PercentageOfPersonnel = row.PercentageOfPersonnel, IsRequired = row.IsRequired}
	else
		-- can't use GCO.Error or GCO.Warning functions at this point
		print("WARNING: no equipment class in GameInfo.EquipmentClasses for "..tostring(row.EquipmentClass))
	end
end

militaryOrganization = {}
for row in GameInfo.MilitaryFormationStructures() do
	local promotionClassID 	= GameInfo.UnitPromotionClasses[row.PromotionClassType].Index
	local organizationRow	= GameInfo.MilitaryOrganisationLevels[row.OrganisationLevelType]
	if not militaryOrganization[organizationRow.Index] then 
		militaryOrganization[organizationRow.Index] = {}
		militaryOrganization[organizationRow.Index].SupplyLineLengthFactor 			= organizationRow.SupplyLineLengthFactor
		militaryOrganization[organizationRow.Index].MaxPersonnelPercentFromReserve 	= organizationRow.MaxPersonnelPercentFromReserve
		militaryOrganization[organizationRow.Index].MaxMaterielPercentFromReserve	= organizationRow.MaxMaterielPercentFromReserve
		militaryOrganization[organizationRow.Index].MaxHealingPerTurn 				= organizationRow.MaxHealingPerTurn
		militaryOrganization[organizationRow.Index].PromotionType 					= organizationRow.PromotionType -- that's the organization level promotion
	end
	militaryOrganization[organizationRow.Index][promotionClassID] = { 
		MilitaryFormationType 			= row.MilitaryFormationType,
		FrontLinePersonnel				= row.FrontLinePersonnel,
		ReservePersonnel 				= row.ReservePersonnel,
		PromotionType 					= row.PromotionType,	-- that's the promotion based on number of personnel
		SizeString 						= row.SizeString
	}
end


--=====================================================================================--
-- Activities & Employment
--=====================================================================================--
CityEmploymentPow 	= {
	["ERA_ANCIENT"] 		= 2.00 , --1.00 ,
	["ERA_CLASSICAL"] 		= 2.05 , --1.10 ,
	["ERA_MEDIEVAL"] 		= 2.12 , --1.25 ,
	["ERA_RENAISSANCE"] 	= 2.25 , --1.50 ,
	["ERA_INDUSTRIAL"] 		= 2.65 , --2.20 ,
	["ERA_MODERN"] 			= 2.70 , --2.30 ,
	["ERA_ATOMIC"] 			= 2.75 , --2.50 ,
	["ERA_INFORMATION"] 	= 2.80 , -- 2.8 is max city population
}
	
CityEmploymentFactor 	= {
	["ERA_ANCIENT"] 		= 500 ,
	["ERA_CLASSICAL"] 		= 550 ,
	["ERA_MEDIEVAL"] 		= 600 ,
	["ERA_RENAISSANCE"] 	= 650 ,
	["ERA_INDUSTRIAL"] 		= 800 ,
	["ERA_MODERN"] 			= 900 ,
	["ERA_ATOMIC"] 			= 950 ,
	["ERA_INFORMATION"] 	= 1000 ,
}

PlotEmploymentPow		= {
	["ERA_ANCIENT"] 		= 1.80 , -- 1.80 = Max City pop Pow - 1.00 : this way the summation of all worked plots can't be > to the total city population (using pow 2.80) <- but this is obsolete as we use urban population only to determine city size
	["ERA_CLASSICAL"] 		= 1.79 ,
	["ERA_MEDIEVAL"] 		= 1.77 ,
	["ERA_RENAISSANCE"] 	= 1.75 ,
	["ERA_INDUSTRIAL"] 		= 1.60 ,
	["ERA_MODERN"] 			= 1.55 ,
	["ERA_ATOMIC"] 			= 1.52 ,
	["ERA_INFORMATION"] 	= 1.50 ,
}
	
PlotEmploymentFactor 	= {
	["ERA_ANCIENT"] 		= 1000 ,
	["ERA_CLASSICAL"] 		= 950 ,
	["ERA_MEDIEVAL"] 		= 900 ,
	["ERA_RENAISSANCE"] 	= 850 ,
	["ERA_INDUSTRIAL"] 		= 700 ,
	["ERA_MODERN"] 			= 600 ,
	["ERA_ATOMIC"] 			= 550 ,
	["ERA_INFORMATION"] 	= 500 ,
}

PlotOutputFactor 	= {
	["ERA_ANCIENT"] 		= 0.50 ,
	["ERA_CLASSICAL"] 		= 0.65 ,
	["ERA_MEDIEVAL"] 		= 0.80 ,
	["ERA_RENAISSANCE"] 	= 1.00 ,
	["ERA_INDUSTRIAL"] 		= 2.00 ,
	["ERA_MODERN"] 			= 3.00 ,
	["ERA_ATOMIC"] 			= 4.00 ,
	["ERA_INFORMATION"] 	= 5.00 ,
}

-- For population repartition at city creation
BaseUrbanPercent 		= {
	["ERA_ANCIENT"] 		= 5 ,
	["ERA_CLASSICAL"] 		= 5 ,
	["ERA_MEDIEVAL"] 		= 7 ,
	["ERA_RENAISSANCE"] 	= 10 ,
	["ERA_INDUSTRIAL"] 		= 30 ,
	["ERA_MODERN"] 			= 50 ,
	["ERA_ATOMIC"] 			= 60 ,
	["ERA_INFORMATION"] 	= 70 ,
}


--=====================================================================================--
-- Custom Tooltips Tabs & Modes
--=====================================================================================--
resourceTabs			= {"LOC_CITYBANNER_TOOLTIP_STOCK_TAB", "LOC_CITYBANNER_TOOLTIP_PRODUCTION_TAB", "LOC_CITYBANNER_TOOLTIP_TRADE_TAB"}
resourceModes			= {"LOC_CITYBANNER_TOOLTIP_RESOURCE_SIMPLE_MOD", "LOC_CITYBANNER_TOOLTIP_RESOURCE_DETAILED_MOD", "LOC_CITYBANNER_TOOLTIP_RESOURCE_CONDENSED_MOD"}

scienceTabs				= {"LOC_CITYBANNER_TOOLTIP_SCIENCE_ALL_TAB", "LOC_CITYBANNER_TOOLTIP_SCIENCE_KNOWN_TAB", "LOC_CITYBANNER_TOOLTIP_SCIENCE_UNLOCKED_TAB", "LOC_CITYBANNER_TOOLTIP_SCIENCE_LOCKED_TAB"}
