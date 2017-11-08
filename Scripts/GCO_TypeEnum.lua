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
		ImportTaxes			= "7",	-- Income from Import Taxes
		ExportTaxes			= "8",	-- Income from Export Taxes
		Plundering			= "9",	-- Income from units Plundering
		CityTaxes			= "10",	-- Income from City Taxes (vanilla)
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

IsImprovementForFeature		= {} -- cached table to check if an improvement is meant for a feature
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

