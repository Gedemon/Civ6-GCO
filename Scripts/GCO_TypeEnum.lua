--=====================================================================================--
--	FILE:	 GCO_TypeEnum.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_TypeEnum.lua...")


-----------------------------------------------------------------------------------------
-- Treasury
-----------------------------------------------------------------------------------------
AccountType	= {	-- ENUM for treasury changes (string as it it used as a key for saved table)

		Production 			= "1",	-- Expense for city Production
		Reinforce			= "2",	-- Expense for unit Reinforcement
		BuildingMaintenance	= "4",	-- Expense for buildings Maintenance (vanilla)
		UnitMaintenance		= "5",	-- Expense for units Maintenance (vanilla)
		DistrictMaintenance	= "6",	-- Expense for district Maintenance (vanilla)
		Repair				= "11",	-- Expense for healing city garrison or walls
		Repay				= "12",	-- Expense for repaying the debt
		
		ImportTaxes			= "7",	-- Income from Import Taxes
		ExportTaxes			= "8",	-- Income from Export Taxes
		Plundering			= "9",	-- Income from units Plundering
		CityTaxes			= "10",	-- Income from City Taxes (vanilla)
		UpperTaxes			= "13",	-- Income from Taxes on Upper Class
		MiddleTaxes			= "14",	-- Income from Taxes on Middle Class
}


-----------------------------------------------------------------------------------------
-- Trade
-----------------------------------------------------------------------------------------
TradeLevelType	= {	-- ENUM for trade route level types

		Limited 	= 1,	-- Trade Limited to non-luxury food
		Neutral		= 2,	-- No strategic resources or equipment trade
		Friend		= 3,	-- Trade All except equipment
		Allied		= 4,	-- Trade All
}


-----------------------------------------------------------------------------------------
-- Units
-----------------------------------------------------------------------------------------
UnitPersonnelType	= {	-- ENUM for trade route level types

		StandingArmy 	= 1,	-- Permanent units
		Conscripts		= 2,	-- Temporary units, built in city based on personnel/equipment available in the city
		Mercenary		= 3,	-- Temporary units, bought in city, not linked to any city
}


-----------------------------------------------------------------------------------------
-- Resources - to do : those are helpers, to move to mod utils with related functions
-----------------------------------------------------------------------------------------
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
local lumberMillsID		= GameInfo.Improvements["IMPROVEMENT_LUMBER_MILL"].Index
local plantationID		= GameInfo.Improvements["IMPROVEMENT_PLANTATION"].Index
IsImprovementForResource[lumberMillsID] 					= {[resourceWoodID] 	= true}
IsImprovementForResource[plantationID][resourcePlantsID] 	= true
ResourceImprovementID[resourceWoodID] 						= lumberMillsID
ResourceImprovementID[resourcePlantsID] 					= plantationID

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

-----------------------------------------------------------------------------------------
-- Equipment - to do : those are helpers, to move to mod utils with related functions ?
-----------------------------------------------------------------------------------------
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


-----------------------------------------------------------------------------------------
-- Activities & Employment
-----------------------------------------------------------------------------------------
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
	["ERA_ANCIENT"] 		= 1.80 , -- 1.80 = Max City pop Pow - 1.00 : this way the summation of all worked plots can't be > to the total city population (using pow 2.80) 
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
